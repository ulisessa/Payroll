namespace UAS.Payroll;

using Microsoft.Finance.Currency;
using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
using Microsoft.Projects.Project.Job;

codeunit 50014 "Motor Liquidación"
{
    // Orchestrates the full liquidation calculation for one employee/period.
    //
    // Call sequence:
    //   Motor.Liquidar(LiqNo) — runs on an existing Liquidación in Borrador state
    //
    // Performance:
    //   • Concept caches (FLatestVersionMap, FFracAccumList/FFracAccumPct, FAccumCodes)
    //     are built once by EnsureConceptCaches and memoized per FechaRef, so the up-to-20
    //     GU convergence iterations and every employee in a same-period batch reuse them
    //     instead of re-scanning Concepto Liquidación / Fracción Acumulador each time.
    //   • CCT applicability is resolved per-concept against a MaxFlowField on
    //     Concepto Liquidación ("Vigencia CCT Más Reciente"); unrestricted concepts
    //     cost a single CalcFields, restricted ones cost ~3 indexed lookups total.

    procedure Liquidar(LiqNo: Code[20])
    var
        Liq: Record "Liquidación";
    begin
        Liq.Get(LiqNo);
        LiquidarRecord(Liq);
    end;

    /// <summary>
    /// Calcula dejando registro del proceso. Devuelve false si falló, sin relanzar el error.
    /// </summary>
    /// <remarks>
    /// Se ejecuta vía Codeunit.Run y NO con [TryFunction]: un TryFunction no puede escribir en la
    /// base ("Una llamada a la función 'MODIFY' no se permite..."), y liquidar es todo escritura.
    /// Codeunit.Run abre su propio ámbito de transacción, así que cuando el cálculo falla la
    /// plataforma revierte lo que hizo el ejecutor y devuelve false acá — con el llamador todavía
    /// en condiciones de escribir el registro del error y confirmarlo aparte (FinalizarConError).
    ///
    /// Ojo con el uso en lote: como no relanza, el proceso puede seguir con la liquidación
    /// siguiente en vez de abortar todo. Es deliberado — 199 liquidaciones correctas no deberían
    /// perderse por una que falla — pero significa que el llamador tiene que mirar el resultado.
    /// </remarks>
    procedure LiquidarConRegistro(var Liq: Record "Liquidación"): Boolean
    var
        Registro: Codeunit "Registro Procesos Liq.";
        Ejecutor: Codeunit "Ejecutor Liquidación";
    begin
        Registro.Iniciar("Tipo Proceso Liq."::Cálculo, Liq);

        // Obligatorio, no una precaución: la plataforma solo permite USAR EL VALOR DE RETORNO de
        // Codeunit.Run cuando la transacción no tiene escrituras pendientes ("Codeunit.Run solo se
        // permite en transacciones de escritura si no se usa el valor de retorno"). En un lote, la
        // liquidación anterior siempre dejó escrituras, así que sin esto falla de la segunda en
        // adelante. Efecto buscado, además: cada liquidación queda en su propia transacción, que es
        // lo que permite que una que falla no se lleve puestas a las demás.
        Commit();

        if Ejecutor.Run(Liq) then begin
            Registro.Finalizar();
            // El ejecutor trabajó sobre su propia instancia del registro: se relee para que el
            // llamador vea el estado y los totales que quedaron realmente guardados.
            if Liq.Get(Liq."No.") then;
            exit(true);
        end;
        Registro.FinalizarConError(GetLastErrorText());
        // Lo que el cálculo fallido dejó en memoria ya no existe en la base: se descarta releyendo,
        // si no el llamador podría mostrar o guardar valores de un cálculo que se revirtió.
        if Liq.Get(Liq."No.") then;
        exit(false);
    end;

    /// <summary>Calcula una liquidación, fase por fase.</summary>
    /// <remarks>
    /// ESTÁ PARTIDO EN FASES PARA PODER PERFILARLO. Antes eran ciento sesenta líneas seguidas, y el
    /// profiler de AL atribuye las muestras al PROCEDIMIENTO en el que caen: todo lo que estaba
    /// escrito acá adentro —preparar la cabecera, materializar préstamos y novedades, armar el
    /// contexto, cerrar— se acumulaba en un único `LiquidarRecord` carísimo del que no se podía
    /// sacar qué parte costaba. Sólo se distinguía lo que ya era una llamada aparte.
    ///
    /// Ahora cada fase es un frame con nombre, así que el árbol del `.alcpuprofile` se lee solo. El
    /// orden y las llamadas son exactamente los de antes: esto no cambia ningún importe.
    ///
    /// Las fases comparten el `CtxBuilder` y el `Evaluador` A PROPÓSITO, y por eso viajan por `var`:
    /// la validación los inicializa con un contexto de nombres y el cálculo los reinicializa con el
    /// de valores. Son la misma instancia en las dos pasadas, como siempre lo fueron.
    /// </remarks>
    procedure LiquidarRecord(var Liq: Record "Liquidación")
    var
        CtxBuilder: Codeunit "Contexto Liquidación";
        Evaluador: Codeunit "Evaluador Fórmula";
        Ctx: Dictionary of [Text, Decimal];
        FechaRef: Date;
    begin
        // CalcularPorPeriodo reutiliza una sola instancia del motor para todo el lote: si una
        // liquidación anterior falló dentro de ConvergerGrossingUp, el flag podría quedar activo
        // y la siguiente se calcularía sin auditoría. Arranca siempre limpio.
        FIteracionGU := false;
        ReiniciarCachesLiquidacion();

        FechaRef := FasePrepararCabecera(Liq);
        FaseValidarFormulas(Liq, FechaRef, CtxBuilder, Evaluador);
        FasePrepararDatos(Liq);
        FaseArmarContexto(Liq, FechaRef, CtxBuilder, Evaluador, Ctx);
        FaseCorrerConceptos(Liq, FechaRef, Ctx, CtxBuilder, Evaluador);
        FaseConverger(Liq, FechaRef, Ctx, CtxBuilder, Evaluador);
        FaseCerrar(Liq, Ctx, CtxBuilder);
    end;

    /// <summary>Fase 0: precondiciones, fecha de referencia, cobertura y encuadre de la cabecera.</summary>
    local procedure FasePrepararCabecera(var Liq: Record "Liquidación") FechaRef: Date
    var
        Periodo: Record "Período Liquidación";
        Job: Record Job;
        TipoLiqRec: Record "Tipo Liquidación";
        EstadoMgt: Codeunit "Gestión Estado Empleado";
        CoberturaTramos: Codeunit "Cobertura Tramos Liq.";
        ParCCT: Codeunit "Convenio Categoría Liq.";
        ConvenioEntidad: Code[20];
        CategoriaEntidad: Code[20];
    begin
        if Liq.Estado = Liq.Estado::Contabilizada then
            Error(ErrEstadoInvalido);

        Periodo.Get(Liq."Cód. Período");
        if Periodo.Estado = Periodo.Estado::Cerrado then
            Error(ErrPeriodoCerrado);
        Periodo.ErrorSiCreado();

        // Reference date for the whole calculation. Monthly liquidations settle at period end;
        // a Cierre Marea settles at the voyage arrival date (project Ending Date), so all
        // date-sensitive lookups (parameter/value vigencias, TC, estados, YTD) use that date.
        // The período stays as a reporting container only.
        FechaRef := Periodo."Fecha Hasta";
        if TipoLiqRec.EsArribo(Liq."Cód. Tipo Liq.") then
            if (Liq."No. Proyecto" <> '') and Job.Get(Liq."No. Proyecto") and (Job."Ending Date" <> 0D) then
                FechaRef := Job."Ending Date";

        // Align the header date with the effective reference date.
        if Liq."Fecha Liquidación" <> FechaRef then
            Liq."Fecha Liquidación" := FechaRef;

        // Qué días cubre queda guardado en la cabecera: es lo que permite ver que un mes con dos
        // mareas liquidadas igual tiene días sin liquidar.
        Liq.CalcularCobertura();
        // Y el reparto fino, en tramos: la cabecera guarda el envolvente, pero quien manda para
        // contar días son los tramos, que son los que permiten decir "del 1 al 4 y del 26 al 31".
        // Va ANTES de armar el contexto, porque el contexto los lee para acotar las variables de
        // período — si se recalcularan después, la liquidación se calcularía con el reparto viejo.
        CoberturaTramos.Recalcular(Liq);

        ValidarOrdenCronologico(Liq, Periodo);

        // El par de la cabecera se resincroniza en cada cálculo, para que recalcular una liquidación
        // existente refleje los cambios igual que recrearla. Sale de los ATRIBUTOS del empleado a la
        // fecha de referencia, que es su encuadre con historial.
        //
        // Antes salía de la asignación al proyecto, y con eso una marea liquidaba TODOS sus conceptos
        // con la categoría del embarque. Ahora esa categoría se usa solo en los conceptos que lo
        // pidan expresamente ("Convenio/Categoría a usar" = el de la asignación).
        //
        // Sin atributos cargados a esa fecha se respeta lo que la liquidación ya traía: en una base a
        // medio migrar, eso es el par de la ficha o el de la asignación, que es lo que había antes.
        if ParCCT.ParDeEntidad(Liq."No. Empleado", FechaRef, Periodo."Fecha Desde", Periodo."Fecha Hasta", ConvenioEntidad, CategoriaEntidad) then begin
            Liq."Cód. Convenio" := ConvenioEntidad;
            Liq."Cód. Categoría" := CategoriaEntidad;
        end;

        // If the employee is enjoying francos and the balance runs out within this period, materialize the
        // transition to the next state (Francos → Órdenes) before reading states, so DIAS_FRANCOS_PERIODO
        // counts only the covered days and the rest falls into the next state.
        EstadoMgt.AjustarEstadoFrancos(Liq."No. Empleado", FechaRef);

        EstadoMgt.ValidarEstadoExiste(Liq."No. Empleado", FechaRef);
        ValidarAsignacionProyecto(Liq."No. Empleado", Liq."No. Proyecto");
    end;

    /// <summary>Fase 1: valida las fórmulas con un contexto de nombres, antes de tocar un solo dato.</summary>
    /// <remarks>
    /// `LiqNo` va vacío a propósito: impide que el contexto escriba en la base. Cualquier error de
    /// fórmula se reporta acá, con la liquidación todavía intacta.
    /// </remarks>
    local procedure FaseValidarFormulas(var Liq: Record "Liquidación"; FechaRef: Date; var CtxBuilder: Codeunit "Contexto Liquidación"; var Evaluador: Codeunit "Evaluador Fórmula")
    var
        ValidationCtx: Dictionary of [Text, Decimal];
    begin
        CtxBuilder.Init(
            Liq."No. Empleado", Liq."No. Proyecto", Liq."Cód. Período",
            FechaRef, Liq."Cód. Convenio", Liq."Cód. Categoría",
            '', Liq."Cód. Tipo Liq.", Liq."Cobertura Desde");
        // Contexto de NOMBRES, sin resolver valores: la validación busca fórmulas mal escritas,
        // funciones inexistentes y variables no definidas, y nada de eso depende de cuánto vale cada
        // una. Construirlo entero acá era pagar una liquidación completa para descartarla, porque el
        // contexto de verdad se arma después de materializar préstamos y novedades.
        CtxBuilder.BuildContextParaValidacion(ValidationCtx);
        InjectGUVariables(ValidationCtx);
        InjectZonaDesfavorable(Liq, FechaRef, ValidationCtx);
        Evaluador.Init(ValidationCtx, FechaRef);
        // Con valores ficticios, los errores que dependen del VALOR —dividir por una variable en
        // cero, pedir el tramo de un importe que todavía no existe— no dicen nada de la fórmula. Se
        // silencian solo durante esta fase; lo estructural se sigue reportando.
        Evaluador.SetModoValidacion(true);
        ValidarFormulas(Liq, FechaRef, ValidationCtx, Evaluador);
        Evaluador.SetModoValidacion(false);
    end;

    /// <summary>Fase 2: deja la liquidación en blanco y materializa préstamos, novedades e incidencias.</summary>
    /// <remarks>
    /// Sólo se llega acá si la validación pasó. Es la primera fase que ESCRIBE: de acá en adelante
    /// la liquidación anterior ya no existe.
    /// </remarks>
    local procedure FasePrepararDatos(var Liq: Record "Liquidación")
    begin
        // AplicarCuotasEnLiquidacion solo actúa si el estado es Borrador — pero un recálculo
        // por lote (CalcularPorPeriodo) puede llegar acá con una liquidación ya Calculada o
        // Aprobada. Sin esto, las cuotas de préstamo pendientes se saltean en silencio en
        // cualquier recálculo que no pase primero por "Reabrir".
        Liq.Estado := Liq.Estado::Borrador;
        Liq.Modify();
        DeleteLineas(Liq."No.", false);
        // Reset loan state from any previous calculation run before rebuilding it
        GestionPrestamos.LimpiarParaRecalculo(Liq."No.");
        // Same for novedades, and before the loan pass: leftover incidencias from the previous run
        // would otherwise get the loan installment added on top of them.
        GestionNovedades.LimpiarParaRecalculo(Liq."No.");
        // Auto-generate incidencias for pending loan installments (Borrador only)
        GestionPrestamos.AplicarCuotasEnLiquidacion(Liq);
        // Materialize the novedades loaded before this liquidation existed. Runs after the loan pass
        // so a loan-generated incidencia counts as manual: the novedad is skipped instead of doubled.
        GestionNovedades.AplicarEnLiquidacion(Liq);
        CargarIncidencias(Liq."No.");
    end;

    /// <summary>Fase 3: arma el contexto de valores y deja el evaluador listo.</summary>
    /// <remarks>
    /// Es la fase cara del cálculo —resuelve parámetros, fuentes de datos, atributos y acumulados—
    /// y la que más conviene mirar en el perfil. Va después de materializar préstamos y novedades
    /// porque las variables de período cuentan lo que esas pasadas acaban de escribir.
    /// </remarks>
    local procedure FaseArmarContexto(var Liq: Record "Liquidación"; FechaRef: Date; var CtxBuilder: Codeunit "Contexto Liquidación"; var Evaluador: Codeunit "Evaluador Fórmula"; var Ctx: Dictionary of [Text, Decimal])
    var
        CodigosAtributos: Dictionary of [Text, Text];
    begin
        CtxBuilder.Init(
            Liq."No. Empleado", Liq."No. Proyecto", Liq."Cód. Período",
            FechaRef, Liq."Cód. Convenio", Liq."Cód. Categoría",
            Liq."No.", Liq."Cód. Tipo Liq.", Liq."Cobertura Desde");
        CtxBuilder.BuildContext(Ctx);
        InjectGUVariables(Ctx);
        InjectZonaDesfavorable(Liq, FechaRef, Ctx);
        Evaluador.Init(Ctx, FechaRef);
        CtxBuilder.GetCodigosAtributos(CodigosAtributos);
        Evaluador.SetCodigosAtributos(CodigosAtributos);
    end;

    /// <summary>Fase 4: resuelve el neto garantizado y corre los conceptos.</summary>
    local procedure FaseCorrerConceptos(var Liq: Record "Liquidación"; FechaRef: Date; var Ctx: Dictionary of [Text, Decimal]; var CtxBuilder: Codeunit "Contexto Liquidación"; var Evaluador: Codeunit "Evaluador Fórmula")
    begin
        // Después de Evaluador.Init porque evalúa una fórmula, y antes de RunConceptos porque los
        // conceptos ramifican sobre ES_GROSSING_UP (ej. 3553 y 4743).
        ResolverNetoGarantizado(FechaRef, Ctx, Evaluador);
        Progreso.Paso(TxtPasoConceptos);
        RunConceptos(Liq, FechaRef, Ctx, CtxBuilder, Evaluador);
    end;

    /// <summary>Fase 5: si hay neto garantizado, itera el complemento hasta alcanzarlo.</summary>
    /// <remarks>
    /// En el perfil es la fase que delata una liquidación cara: rehace la lista entera de conceptos
    /// una vez por vuelta, y la convergencia tarda entre cinco y ocho.
    /// </remarks>
    local procedure FaseConverger(var Liq: Record "Liquidación"; FechaRef: Date; var Ctx: Dictionary of [Text, Decimal]; var CtxBuilder: Codeunit "Contexto Liquidación"; var Evaluador: Codeunit "Evaluador Fórmula")
    begin
        // If anidado y no `and`: mismo motivo que EsVersionEnUso — sin cortocircuito garantizado, el
        // Get corre igual. Hoy InjectGUVariables siempre siembra la clave, así que no explota; queda
        // así para que no dependa de eso.
        if Ctx.ContainsKey(VarEsGrossingUp()) then
            if Ctx.Get(VarEsGrossingUp()) = 1 then
                ConvergerGrossingUp(Liq, FechaRef, Ctx, CtxBuilder, Evaluador);
    end;

    /// <summary>Fase 6: totales, resumen de variables, estado final y avisos.</summary>
    local procedure FaseCerrar(var Liq: Record "Liquidación"; var Ctx: Dictionary of [Text, Decimal]; var CtxBuilder: Codeunit "Contexto Liquidación")
    begin
        GuardarHaberesGravados(Liq, Ctx);
        UpdateTotals(Liq);
        SaveResumenVariables(Liq."No.", Ctx, CtxBuilder);
        Liq.Estado := Liq.Estado::Calculada;
        Liq.Modify(true);
        AcumularAdvertencias(Liq."No.", CtxBuilder.GetAdvertenciasParametros());
        // Avisos de la última pasada de RunConceptos (las intermedias de grossing-up se descartan
        // junto con sus líneas, ver el Clear al inicio del bucle).
        AcumularAdvertencias(Liq."No.", FAvisosOrden);

        // Lo mismo al registro, pero una entrada por aviso y con su categoría: así se puede filtrar
        // "mostrame todos los problemas de orden de cálculo del período" en vez de leer un bloque
        // de texto que se pierde al cerrar el mensaje.
        Registro.AgregarTexto(
            "Severidad Registro Liq."::Advertencia, "Categoría Registro Liq."::Parámetro,
            CtxBuilder.GetAdvertenciasParametros());
        RegistrarAvisosOrdenEnLog();
        Registro.InfoImporte(
            "Categoría Registro Liq."::General,
            StrSubstNo(RegCalculadaTxt, Liq."Cód. Tipo Liq.", Liq."Cód. Período"), '', Liq."Total Haberes");
    end;

    // Accumulates parameter-staleness warnings across one or more LiquidarRecord calls
    // (e.g. a batch "Calcular Selección") so the caller can show a single consolidated
    // message instead of interrupting the batch once per liquidación.
    local procedure AcumularAdvertencias(LiqNo: Code[20]; Advertencias: Text)
    begin
        if Advertencias = '' then exit;
        if FAdvertencias <> '' then
            FAdvertencias += '\\';
        FAdvertencias += StrSubstNo('%1:\%2', LiqNo, Advertencias);
    end;

    procedure GetAdvertencias(): Text
    begin
        exit(FAdvertencias);
    end;

    procedure LimpiarAdvertencias()
    begin
        FAdvertencias := '';
    end;

    /// <summary>
    /// Impide calcular una liquidación cuando el empleado ya tiene líneas de un período posterior.
    /// </summary>
    /// <remarks>
    /// El motor mira hacia atrás sin techo. TotalConsumido, en el ledger de francos, cuenta TODO el
    /// consumo del empleado sin filtro de fecha; los acumuladores anuales y el YTD de Ganancias hacen
    /// lo mismo. Recalcular marzo con abril ya liquidado hace que marzo vea el consumo de abril como
    /// si ya hubiera ocurrido: el recorrido FIFO se saltea lotes que en marzo estaban disponibles y
    /// marzo se paga con los lotes equivocados, o directamente no encuentra saldo. El número que sale
    /// no es el que ese mes habría dado en su momento, y nada lo delata.
    ///
    /// Se compara contra el fin del PERÍODO y no contra la fecha de referencia: dentro de un mismo
    /// período conviven la Regular, los Devengados y el Cierre de Marea —éste fechado el día de
    /// arribo, o sea antes que las otras— y entre ellas no hay un orden establecido. Comparar por
    /// fecha bloquearía el Cierre de Marea por existir la Regular del mismo mes, que es trabajo
    /// normal.
    ///
    /// El control mira LÍNEAS y no cabeceras, y no cuenta las que están en BORRADOR: una liquidación
    /// posterior que existe pero no se calculó —o que se reabrió— no aporta a ningún acumulador y no
    /// tiene por qué frenar el trabajo del mes anterior. Los criterios completos, y por qué son
    /// éstos, están en "Recálculo En Cadena Liq.".FiltrarPosteriores, que es de donde salen: la regla
    /// se define una sola vez para que el control, la reapertura y la cadena no puedan discrepar.
    ///
    /// Queda un caso al descubierto y conviene saberlo: una posterior reabierta CONSERVA sus líneas,
    /// y el ledger de francos las cuenta igual —lee líneas sin mirar el estado, a diferencia de los
    /// acumuladores—. Si esas líneas consumían francos, el cálculo de la anterior ve esos lotes como
    /// tomados. Para eso está "Recalcular en cadena", que las borra antes de rehacer.
    /// </remarks>
    local procedure ValidarOrdenCronologico(var Liq: Record "Liquidación"; Periodo: Record "Período Liquidación")
    var
        LiqPosterior: Record "Liquidación";
        Cadena: Codeunit "Recálculo En Cadena Liq.";
    begin
        if not Cadena.PrimeraPosterior(Liq, LiqPosterior) then
            exit;

        Error(
            ErrOrdenCronologico,
            Liq."No.", Periodo.Código, LiqPosterior."No.", LiqPosterior."Cód. Período", LiqPosterior."Fecha Liquidación");
    end;

    /// <summary>
    /// Borra las líneas y la auditoría de una liquidación sin recalcularla.
    /// </summary>
    /// <remarks>
    /// La necesita el recálculo en cadena: para poder rehacer un período viejo hay que sacar del
    /// medio las líneas de los posteriores, y son justamente esas líneas las que el control de orden
    /// no deja pasar. Es la misma limpieza con la que arranca cada cálculo, expuesta aparte.
    /// </remarks>
    procedure LimpiarLineas(LiqNo: Code[20])
    begin
        DeleteLineas(LiqNo, false);
    end;

    local procedure ValidarAsignacionProyecto(EmployeeNo: Code[20]; JobNo: Code[20])
    var
        Personal: Record "Personal Proyecto";
    begin
        // Project-less liquidations (e.g. Regular for francos enjoyed in port, between mareas) have no
        // Personal Proyecto assignment — nothing to validate.
        if JobNo = '' then
            exit;
        if not Personal.Get(EmployeeNo, JobNo) then
            Error(ErrSinAsignacionProyecto, EmployeeNo, JobNo);
    end;

    local procedure ValidarFormulas(
        var Liq: Record "Liquidación";
        FechaRef: Date;
        var Ctx: Dictionary of [Text, Decimal];
        var Evaluador: Codeunit "Evaluador Fórmula")
    var
        Concepto: Record "Concepto Liquidación";
        TipoEmpleado: Enum "Aplica A Liq.";
        Importe: Decimal;
        Errores: Text;
    begin
        TipoEmpleado := TipoEmpleadoDe(Liq);

        SelectConceptos(Concepto, TipoEmpleado, FechaRef, Liq."Cód. Tipo Liq.");
        EnsureConceptCaches(FechaRef);

        if not Concepto.FindSet() then exit;
        repeat
            if EsVersionEnUso(FLatestVersionMap, Concepto.Código, Concepto."Vigencia Desde") and
               CCTAplicaAConcepto(Concepto, Liq."Cód. Convenio", Liq."Cód. Categoría", FechaRef) and
               ConceptoAplicaATipoLiq(Concepto, Liq."Cód. Tipo Liq.") and
               not Concepto."Es Acumulador" and
               (Concepto.Fórmula <> '')
            then
                if not Evaluador.TryEvalFormula(Concepto.Fórmula, Importe) then begin
                    if Errores <> '' then Errores += '\';
                    Errores += StrSubstNo(ErrConceptoFalló, Concepto.Código, GetLastErrorText());
                end;
        until Concepto.Next() = 0;

        if Errores <> '' then
            Error(ErrFormulasInvalidas, Errores);
    end;

    internal procedure ReiniciarCachesLiquidacion()
    begin
        // Estas instantáneas sólo viven durante una liquidación, incluso al reutilizar el motor.
        Clear(FCCTAplicabilidad);
        FParPuestoCargado := false;
        FParPuestoExiste := false;
        Clear(FConvenioPuesto);
        Clear(FCategoriaPuesto);
        FIncidencias.Reset();
        FIncidencias.DeleteAll(false);
    end;

    internal procedure CompartirIncidencias(var Destino: Record "Incidencia Liquidación" temporary)
    begin
        Destino.Copy(FIncidencias, true);
    end;

    internal procedure CargarIncidencias(LiqNo: Code[20])
    var
        Incidencia: Record "Incidencia Liquidación";
    begin
        FIncidencias.Reset();
        FIncidencias.DeleteAll(false);
        Incidencia.SetRange("No. Liquidación", LiqNo);
        if Incidencia.FindSet() then
            repeat
                FIncidencias := Incidencia;
                FIncidencias.Insert(false);
            until Incidencia.Next() = 0;
    end;

    local procedure RunConceptos(
        var Liq: Record "Liquidación";
        FechaRef: Date;
        var Ctx: Dictionary of [Text, Decimal];
        var CtxBuilder: Codeunit "Contexto Liquidación";
        var Evaluador: Codeunit "Evaluador Fórmula")
    var
        Concepto: Record "Concepto Liquidación";
        LinLiq: Record "Línea Liquidación";
        DetGan: Record "Detalle Ganancias Liq.";
        TipoEmpleado: Enum "Aplica A Liq.";
        Incid: Record "Incidencia Liquidación" temporary;
        Importe: Decimal;
        ImporteConsumoFranco: Decimal;
        CantIncidencia: Decimal;
        CantIncidenciaPrevia: Decimal;
        CreateLine: Boolean;
        EsIncidencia: Boolean;
        TieneIncidencia: Boolean;
        ParAlterno: Boolean;
        ConvenioEval: Code[20];
        CategoriaEval: Code[20];
        ConceptLog: Text;
        FormulaEvaluadaFranco: Text;
        FullParamLog: Text;
    begin
        CompartirIncidencias(Incid);
        TipoEmpleado := TipoEmpleadoDe(Liq);

        SelectConceptosParaCalculo(Concepto, FechaRef);

        // Concept caches — memoized per FechaRef (see EnsureConceptCaches); reused across GU iterations
        EnsureConceptCaches(FechaRef);

        // Se reinicia por pasada: una convergencia de grossing-up vuelve a correr todo el bucle, y
        // los avisos de la pasada anterior describirían líneas que ya se borraron. Queda vigente el
        // de la última pasada, que es la que produce las líneas definitivas.
        Clear(FAcumLeidoEnOrden);
        Clear(FAcumLeidoPorConcepto);
        Clear(FAcumAporteTardioOrden);
        Clear(FAcumAporteTardioCodigo);
        Clear(FAcumAportesTardios);
        FAvisosOrden := '';

        if not Concepto.FindSet() then
            exit;

        repeat
            // Se lee primero la incidencia porque decide si el concepto se recorre: una incidencia
            // manual entra aunque el concepto no le aplique a este empleado ni a este convenio, y
            // tiene que hacerlo EN SU ORDEN CÁLCULO. Relegada al final —que es lo que hacía cuando
            // el tipo de empleado la dejaba fuera del recorrido— su aporte al acumulador llega
            // después de que los conceptos que leen ese acumulador ya lo leyeron, y el resultado es
            // un importe corto sin ningún error a la vista.
            TieneIncidencia := false;
            CantIncidencia := 0;
            if Incid.Get(Liq."No.", Concepto.Código) then begin
                // Tres lecturas distintas de una misma incidencia:
                //   importe <> 0                → el importe cargado reemplaza a la fórmula
                //   importe = 0 y cantidad <> 0 → la fórmula valoriza la cantidad (horas extras)
                //   importe = 0 y cantidad = 0  → es un CERO EXPLÍCITO: apaga el concepto
                //
                // El tercer caso antes era indistinguible de "no hay incidencia", así que una
                // novedad cargada en cero para forzar que un concepto no pague quedaba marcada como
                // Aplicada y la fórmula lo calculaba igual, sin un solo aviso. Una novedad con todo
                // en cero no puede querer decir otra cosa que "este concepto no paga": si lo que se
                // quiere es que la fórmula corra, no se carga la novedad.
                TieneIncidencia := (Incid.Importe <> 0) or (Incid.Cantidad = 0);
                CantIncidencia := Incid.Cantidad;
            end;

            // Tercer modo de carga, además de "con importe" (reemplaza a la fórmula) y "sin nada":
            // una incidencia que trae solo la CANTIDAD y deja que la fórmula la valorice. Es la forma
            // natural de cargar horas extras —21 horas, y el concepto sabe cuánto vale la hora— y
            // hasta acá era invisible: con Importe 0 el concepto se calculaba como si la incidencia
            // no existiera, y la línea salía con cantidad 0 sin ningún aviso.
            //
            // El UpdateContext solo cuando el valor CAMBIA: copia el diccionario entero, y hacerlo en
            // cada concepto de cada pasada de grossing-up es trabajo puro de descarte (la enorme
            // mayoría de los conceptos no tiene incidencia y el valor se queda en 0).
            if CantIncidencia <> CantIncidenciaPrevia then begin
                Ctx.Set(VarCantIncidenciaTok, CantIncidencia);
                Evaluador.UpdateContext(Ctx);
                CantIncidenciaPrevia := CantIncidencia;
            end;

            // Solo el acumulador es un bloqueo duro. CCT y Tipo Liq. se evalúan más abajo, pero SOLO
            // para la vía de fórmula.
            //
            // La versión: normalmente tiene que ser la que está en uso. Con una incidencia cargada
            // alcanza con que sea la ÚLTIMA versión del concepto —aunque esté discontinuada—, porque
            // si no el concepto no se recorre y su incidencia termina escribiéndose fuera de orden.
            // Se compara contra un mapa y no contra la fila para que un concepto con dos versiones
            // discontinuadas no genere dos líneas.
            if not ((EsVersionEnUso(FLatestVersionMap, Concepto.Código, Concepto."Vigencia Desde") or
                     (TieneIncidencia and EsVersionEnUso(FUltimaVersionMap, Concepto.Código, Concepto."Vigencia Desde"))) and
               not Concepto."Es Acumulador" and
               (AplicaAlTipoEmpleado(Concepto, TipoEmpleado) or TieneIncidencia))
            then begin
                // version/accumulator/tipo-empleado filter: skip entirely
            end else begin
                CreateLine := false;
                EsIncidencia := false;
                // Los conceptos que se pagan por el embarque y no por el encuadre se evalúan con el
                // par de la asignación al proyecto. Va ANTES de las comprobaciones y no solo antes de
                // la fórmula: la restricción por CCT también tiene que mirar ese par, si no un
                // concepto restringido al convenio del buque quedaría descartado por el encuadre del
                // empleado y no llegaría a evaluarse nunca.
                ParAlterno := AplicarParDeConcepto(Concepto, Liq, FechaRef, ConvenioEval, CategoriaEval, Ctx, CtxBuilder, Evaluador);
                if TieneIncidencia then begin
                    // Se respeta el signo cargado. Acá el importe lo puso una persona: si tipeó
                    // un negativo es porque quiso un negativo, y el Abs que había antes le
                    // descartaba la intención sin avisar.
                    Importe := Incid.Importe;
                    CreateLine := true;
                    EsIncidencia := true;
                end;

                if (not CreateLine) and
                   CCTAplicaAConcepto(Concepto, ConvenioEval, CategoriaEval, FechaRef) and
                   ConceptoAplicaATipoLiq(Concepto, Liq."Cód. Tipo Liq.") and
                   CondicionOk(Evaluador, Concepto)
                then begin
                    if not Evaluador.TryEvalFormula(Concepto.Fórmula, Importe) then
                        Error(ErrConceptoFalló, Concepto.Código, GetLastErrorText());
                    // El importe conserva el signo que da la fórmula. Ver la nota de cabecera de
                    // Línea Liquidación: el signo dejó de salir del Tipo Concepto.
                    CreateLine := true;
                end;

                if CreateLine then
                    // Franco consumption: expand into one valued line per lot category (FIFO), instead of a
                    // single line. The formula result (Importe) is the number of días to consume.
                    if Concepto."Rol Franco" = Concepto."Rol Franco"::Consumo then begin
                        // Esta rama hacía SOLO las líneas y se salteaba todo el cierre del concepto.
                        // Cuatro consecuencias, de la más visible a la más cara:
                        //   · Las líneas quedaban sin Detalle Variable, sin Fórmula Evaluada y sin
                        //     Fuente Parámetros: el drill-down abría una grilla vacía.
                        //   · El log del evaluador no se vaciaba, así que las variables de este
                        //     concepto se le pegaban al SIGUIENTE, que las mostraba como propias.
                        //   · No se llamaba a UpdateAccumulatorsFromCache: si el concepto tenía
                        //     fracciones configuradas —y siendo remunerativo normalmente las tiene—
                        //     su importe no entraba a ninguna base, y jubilación, obra social y las
                        //     contribuciones se calculaban sin él.
                        //   · No se refrescaba el contexto del evaluador, así que un #CÓDIGO de un
                        //     concepto posterior leía el valor viejo.
                        //
                        // BuildFormulaEvaluada va ANTES del Flush, por el mismo motivo que en la otra
                        // rama: es lo único que podría agregarle entradas al log del concepto.
                        if not FIteracionGU then
                            FormulaEvaluadaFranco := BuildFormulaEvaluada(Concepto.Fórmula, Ctx, Evaluador);
                        // El Flush va antes de generar las líneas porque es lo que cierra el concepto:
                        // el log ya está completo cuando la fórmula terminó de evaluarse.
                        ConceptLog := Evaluador.FlushConceptLog();
                        RegistrarLecturasAcumuladores(ConceptLog, Concepto.Código, Concepto."Orden Cálculo");
                        if not FIteracionGU then begin
                            if FullParamLog <> '' then FullParamLog += '|';
                            FullParamLog += ConceptLog;
                        end;

                        ImporteConsumoFranco :=
                            GenerarLineasConsumoFranco(Liq, Concepto, Importe, ConceptLog, FormulaEvaluadaFranco, FechaRef, Ctx, CtxBuilder, Evaluador);
                        if Ctx.ContainsKey(Concepto.Código) then
                            Ctx.Set(Concepto.Código, ImporteConsumoFranco)
                        else
                            Ctx.Add(Concepto.Código, ImporteConsumoFranco);

                        VerificarOrdenAporte(Concepto.Código, Concepto."Orden Cálculo");
                        // El importe EN PLATA, no el resultado de la fórmula: acá la fórmula devuelve
                        // días de franco y lo que aporta a las bases es lo que se paga por ellos.
                        UpdateAccumulatorsFromCache(
                            Concepto.Código, ImporteConsumoFranco, FFracAccumList, FFracAccumPct, Ctx);
                        Evaluador.UpdateContext(Ctx);
                    end else begin
                    PrepararLineaConcepto(LinLiq, Liq, Concepto, Incid, Importe, EsIncidencia, ConvenioEval, CategoriaEval, FechaRef, Ctx, Evaluador);
                    // El Flush corre SIEMPRE: resetea el log y los vars resueltos por concepto.
                    ConceptLog := Evaluador.FlushConceptLog();
                    // Se anota qué acumuladores leyó este concepto ANTES de que aporte a los suyos:
                    // el orden importa, y una lectura previa a un aporte posterior es justamente el
                    // error que se quiere detectar.
                    RegistrarLecturasAcumuladores(ConceptLog, Concepto.Código, Concepto."Orden Cálculo");
                    if not FIteracionGU then begin
                        if FullParamLog <> '' then FullParamLog += '|';
                        FullParamLog += ConceptLog;
                        // CopyStr como en el otro punto de escritura: el log de un concepto de
                        // Ganancias ya venía largo y las entradas de TRAMO —que ahora describen el
                        // tramo aplicado— lo estiran más. Pasarse de los 2048 sería un error de
                        // ejecución en pleno cálculo por un campo que es de auditoría.
                        LinLiq."Fuente Parámetros" := CopyStr(CtxBuilder.GetParamLog() + '|' + ConceptLog, 1, MaxStrLen(LinLiq."Fuente Parámetros"));
                    end;
                    InsertarLineaLiquidacion(LinLiq);

                    // Deja el Importe ya calculado de ESTE concepto en Ctx bajo su propio código,
                    // para que #CÓDIGO (referenciado por conceptos posteriores en el Orden Cálculo)
                    // pueda leerlo sin reevaluar la fórmula, a diferencia de @CÓDIGO.
                    if Ctx.ContainsKey(Concepto.Código) then
                        Ctx.Set(Concepto.Código, LinLiq.Importe)
                    else
                        Ctx.Add(Concepto.Código, LinLiq.Importe);

                    // Detalle Ganancias y Detalle Variable son auditoría pura: nada del cálculo los
                    // lee de vuelta, y DeleteLineas los borra al arrancar la iteración siguiente.
                    if not FIteracionGU then begin
                        if Concepto."Etiqueta Det. Ganancias" <> '' then begin
                            Clear(DetGan);
                            DetGan."No. Liquidación" := Liq."No.";
                            DetGan.Tipo := DetGan.Tipo::Paso;
                            DetGan.Código := Concepto.Código;
                            DetGan.Descripción := CopyStr(Concepto."Etiqueta Det. Ganancias", 1, MaxStrLen(DetGan.Descripción));
                            DetGan."Importe Total" := Importe;
                            DetGan.Orden := Concepto."Orden Cálculo";
                            DetGan.Insert();
                        end;

                        WriteVariableDetail(Liq."No.", LinLiq."No. Línea", ConceptLog, Ctx, Evaluador);
                    end;

                    VerificarOrdenAporte(Concepto.Código, Concepto."Orden Cálculo");
                    UpdateAccumulatorsFromCache(
                        Concepto.Código, Importe, FFracAccumList, FFracAccumPct, Ctx);
                    Evaluador.UpdateContext(Ctx);
                end;

                // Deja el contexto como estaba para el concepto siguiente. Va acá, al cierre del
                // cuerpo del bucle, y no pegado a la evaluación: entre medio hay caminos que se
                // saltean la fórmula —una incidencia manual, un concepto que no aplica— y todos
                // tienen que devolver el par igual.
                if ParAlterno then
                    RestaurarParBase(Liq, ConvenioEval, CategoriaEval, Ctx, CtxBuilder, Evaluador);
            end;
        until Concepto.Next() = 0;

        WriteIncidenciasRestantes(Liq, FechaRef, FFracAccumList, FFracAccumPct, Ctx);
        WriteAccumulatorLines(Liq, FechaRef, Ctx, FLatestVersionMap);
        ConstruirAvisosOrden();
        // FullParamLog queda vacío en iteraciones intermedias de GU (ver arriba); marcar "En Uso"
        // es idempotente y la pasada final lo hace igual.
        if not FIteracionGU then
            CtxBuilder.MarkEnUso(FullParamLog);
    end;

    /// <summary>
    /// Deja el contexto resolviendo con el par que le corresponde a este concepto. True si lo cambió.
    /// </summary>
    /// <remarks>
    /// Devuelve además en ConvenioEval/CategoriaEval el par efectivo, que se usa tanto para la
    /// restricción por CCT como para estampar la línea. Si el concepto no pide el par de la
    /// asignación, o la liquidación no tiene proyecto, o el empleado no está asignado a ese proyecto,
    /// o el par de la asignación coincide con el del empleado, no hay nada que cambiar: se devuelve
    /// el de la cabecera y false.
    /// </remarks>
    local procedure PrepararLineaConcepto(var LinLiq: Record "Línea Liquidación"; Liq: Record "Liquidación"; Concepto: Record "Concepto Liquidación"; Incid: Record "Incidencia Liquidación" temporary; Importe: Decimal; EsIncidencia: Boolean; ConvenioEval: Code[20]; CategoriaEval: Code[20]; FechaRef: Date; var Ctx: Dictionary of [Text, Decimal]; var Evaluador: Codeunit "Evaluador Fórmula")
    begin
        Clear(LinLiq);
        LinLiq."No. Liquidación" := Liq."No.";
        LinLiq."No. Empleado" := Liq."No. Empleado";
        LinLiq."Cód. Período" := Liq."Cód. Período";
        LinLiq."No. Proyecto" := Liq."No. Proyecto";
        LinLiq."Cód. Tipo Liq." := Liq."Cód. Tipo Liq.";
        // El par CON EL QUE SE CALCULÓ, que en los conceptos marcados no es el de la
        // cabecera. La línea es el comprobante de su propio cálculo: si guardara el de
        // la cabecera, un importe de producción liquidado con la categoría del embarque
        // quedaría documentado con la del encuadre y no habría forma de explicarlo.
        LinLiq."Cód. Convenio" := ConvenioEval;
        LinLiq."Cód. Categoría" := CategoriaEval;
        LinLiq.Estado := LinLiq.Estado::Calculada;
        LinLiq."Fecha Liquidación" := Liq."Fecha Liquidación";
        LinLiq."Cód. Concepto" := Concepto.Código;
        LinLiq."Descripción Concepto" := Concepto.Descripción;
        LinLiq."Nombre Impresión" := Concepto."Nombre Impresión";
        LinLiq."Tipo Concepto" := Concepto."Tipo Concepto";
        LinLiq."Grupo Costo Laboral" := Concepto."Grupo Costo Laboral";
        LinLiq."Imprime en Recibo" := Concepto."Imprime en Recibo";
        LinLiq."Es Devengo" := Concepto."Es Devengo";
        LinLiq.Importe := Importe;
        if EsIncidencia and (Incid.Cantidad <> 0) then begin
            LinLiq.Cantidad := Incid.Cantidad;
            LinLiq."Unidad Cantidad" := Incid."Unidad Cantidad";
            LinLiq."Base Cálculo" := Incid."Valor Unitario";
        end else if Concepto."Variable Cantidad" <> '' then begin
            LinLiq.Cantidad := ResolverExpresionLinea(Concepto."Variable Cantidad", Ctx, FechaRef, Evaluador);
            LinLiq."Unidad Cantidad" := Concepto."Unidad Cantidad";
        end;
        // Franco accrual lot: the formula result is the number of franco DAYS earned. The FIFO
        // ledger consumes days, so store it as Cantidad; the lot carries no amount (valued only
        // when consumed). Sealed with the liquidation's convenio/categoría/marea (set above).
        if Concepto."Rol Franco" = Concepto."Rol Franco"::Devengo then begin
            LinLiq.Cantidad := Importe;
            LinLiq."Unidad Cantidad" := Concepto."Unidad Cantidad";
            LinLiq.Importe := 0;
        end;
        if not (EsIncidencia and (Incid.Cantidad <> 0)) and (Concepto."Variable Base" <> '') then
            LinLiq."Base Cálculo" := ResolverExpresionLinea(Concepto."Variable Base", Ctx, FechaRef, Evaluador);
        LinLiq."Orden Cálculo" := Concepto."Orden Cálculo";
        LinLiq."Fórmula Aplicada" := Concepto.Fórmula;
        // BuildFormulaEvaluada es solo presentación y no toca el estado del evaluador
        // (TryGetConceptoRefValue lee la memo, no la escribe), así que saltearla en una
        // iteración intermedia de GU no cambia ningún importe. Se mantiene ANTES del
        // Flush para no alterar el contenido de ConceptLog.
        if not FIteracionGU then
            LinLiq."Fórmula Evaluada" := BuildFormulaEvaluada(Concepto.Fórmula, Ctx, Evaluador);
        LinLiq."Vigencia Concepto" := Concepto."Vigencia Desde";
        LinLiq."Vigencias Distribución" := DescribirDistribucion(Concepto.Código);
    end;

    local procedure InsertarLineaLiquidacion(var LinLiq: Record "Línea Liquidación")
    begin
        LinLiq.Insert(true);
    end;

    local procedure AplicarParDeConcepto(
        Concepto: Record "Concepto Liquidación";
        Liq: Record "Liquidación";
        FechaRef: Date;
        var ConvenioEval: Code[20];
        var CategoriaEval: Code[20];
        var Ctx: Dictionary of [Text, Decimal];
        var CtxBuilder: Codeunit "Contexto Liquidación";
        var Evaluador: Codeunit "Evaluador Fórmula"): Boolean
    var
        ParCCT: Codeunit "Convenio Categoría Liq.";
        Periodo: Record "Período Liquidación";
        ConvenioProy: Code[20];
        CategoriaProy: Code[20];
    begin
        ConvenioEval := Liq."Cód. Convenio";
        CategoriaEval := Liq."Cód. Categoría";

        case Concepto."Par CCT a Usar" of
            Concepto."Par CCT a Usar"::Puesto:
                begin
                    // El rango del período es la red de ParDePuesto, igual que en ParDeEntidad. Si el
                    // período no existe queda en blanco y sólo se busca la vigente a FechaRef, que es
                    // la resolución principal: la red es un extra, no un requisito.
                    if not FParPuestoCargado then begin
                        if not Periodo.Get(Liq."Cód. Período") then
                            Clear(Periodo);
                        FParPuestoExiste := ParCCT.ParDePuesto(Liq."No. Empleado", FechaRef,
                            Periodo."Fecha Desde", Periodo."Fecha Hasta", FConvenioPuesto, FCategoriaPuesto);
                        FParPuestoCargado := true;
                    end;
                    // El puesto trae EL PAR ENTERO, convenio incluido, y se usa tal cual. Acá se
                    // conservaba el convenio de la cabecera, lo que sólo funciona mientras el puesto
                    // cae en el mismo convenio que el encuadre: un oficial de 768/19 que navega de
                    // Pesca tiene el puesto FE01, que es de ESP, y cruzarlos daba (768/19, FE01) —
                    // un par inexistente que no rompe nada y devuelve ceros.
                    if not FParPuestoExiste then
                        exit(false);
                    ConvenioProy := FConvenioPuesto;
                    CategoriaProy := FCategoriaPuesto;
                end;
            else
                exit(false);
        end;

        if (ConvenioProy = ConvenioEval) and (CategoriaProy = CategoriaEval) then
            exit(false);

        ConvenioEval := ConvenioProy;
        CategoriaEval := CategoriaProy;
        CtxBuilder.UsarParCCT(ConvenioProy, CategoriaProy, Ctx);
        Evaluador.UpdateContext(Ctx);
        exit(true);
    end;

    local procedure RestaurarParBase(
        Liq: Record "Liquidación";
        var ConvenioEval: Code[20];
        var CategoriaEval: Code[20];
        var Ctx: Dictionary of [Text, Decimal];
        var CtxBuilder: Codeunit "Contexto Liquidación";
        var Evaluador: Codeunit "Evaluador Fórmula")
    begin
        CtxBuilder.UsarParCCT(Liq."Cód. Convenio", Liq."Cód. Categoría", Ctx);
        Evaluador.UpdateContext(Ctx);
        ConvenioEval := Liq."Cód. Convenio";
        CategoriaEval := Liq."Cód. Categoría";
    end;

    // Expands a franco-consumption concept into one Línea Liquidación per lot category, valued via FIFO
    // (each slice at its own category's VALOR_FRANCO). DiasSolicitados = the concept's formula result.
    // Returns the total Importe across all slices, so RunConceptos can expose it via #CÓDIGO.
    local procedure GenerarLineasConsumoFranco(
        var Liq: Record "Liquidación";
        Concepto: Record "Concepto Liquidación";
        DiasSolicitados: Decimal;
        ConceptLog: Text;
        FormulaEvaluada: Text;
        FechaRef: Date;
        var Ctx: Dictionary of [Text, Decimal];
        var CtxBuilder: Codeunit "Contexto Liquidación";
        var Evaluador: Codeunit "Evaluador Fórmula") ImporteTotal: Decimal
    var
        TempSlice: Record "Línea Liquidación" temporary;
        LinLiq: Record "Línea Liquidación";
        CatCCT: Record "Categoría CCT";
        FrancosMgt: Codeunit "Gestión Francos";
        TiposCambioFrancos: Dictionary of [Text, Decimal];
        Saldo: Decimal;
        EtiquetaCat: Text;
        Distribucion: Text;
    begin
        // Esta es OTRA instancia de Gestión Francos, local a este procedimiento: no ve lo que el
        // contexto le publicó a la suya. Sin esto, el desglose por lote valuaría un precio en divisa
        // como si fueran pesos —o cortaría, que es lo que hace desde que la conversión es
        // obligatoria—. Las cotizaciones ya están resueltas; sólo hay que pedírselas.
        CtxBuilder.GetTiposCambioFrancos(TiposCambioFrancos);
        FrancosMgt.PublicarTiposCambio(TiposCambioFrancos);

        // LA FÓRMULA DE UN CONCEPTO DE CONSUMO DEVUELVE DÍAS, NO PESOS, y esta guarda existe porque
        // confundirlo no daba error: daba el saldo entero.
        //
        // El 1063 "Sueldo de franco" tenía round(DIAS_FRANCOS_PERIODO * VALOR_FRANCO * COEF_TANGONERO)
        // —o sea plata— y eso entraba acá como días solicitados: 1 × 56.955,67 × 0,3 = 17.086,70 días.
        // CalcularConsumoDesglosado recorre los lotes FIFO hasta agotar lo pedido, no encuentra 17.086
        // francos, entrega los 10 que había y no dice nada. El recibo mostró 569.556,70 —el saldo
        // completo del tripulante— con toda la apariencia de estar bien calculado.
        //
        // POR QUÉ PEDIR DE MÁS ES SIEMPRE UN ERROR Y NO UN CASO DE NEGOCIO: una liquidación final
        // paga exactamente el saldo, no más; y cuando el empleado toma más francos de los que tiene,
        // AjustarEstadoFrancos (Cod50017) ya cortó el estado de Francos el día que se le acabaron,
        // así que DIAS_FRANCOS_PERIODO llega acotado. Si aun así se pide de más, o la fórmula
        // devuelve otra cosa, o el saldo inicial no está cargado.
        Saldo := FrancosMgt.SaldoFrancos(Liq."No. Empleado", Liq."No.");
        if DiasSolicitados > Saldo then
            Error(ErrConsumoMayorQueSaldo, Concepto.Código, DiasSolicitados, Saldo, Liq."No. Empleado", Concepto.Fórmula);

        FrancosMgt.CalcularConsumoDesglosado(Liq."No. Empleado", DiasSolicitados, Liq."Fecha Liquidación", Liq."No.", TempSlice);
        if not TempSlice.FindSet() then exit;

        // La auditoría es la MISMA para todas las tajadas —una sola fórmula, un solo contexto—, así
        // que se arma una vez y se copia. Cada línea la lleva igual porque el liquidador abre la que
        // tiene delante y espera ver con qué se calculó, no que una la tenga y las otras no.
        if not FIteracionGU then
            Distribucion := DescribirDistribucion(Concepto.Código);

        repeat
            Clear(LinLiq);
            // Label the slice with the lot's category code + name (e.g. "MRUT - Marinero").
            EtiquetaCat := TempSlice."Cód. Categoría";
            if CatCCT.Get(TempSlice."Cód. Convenio", TempSlice."Cód. Categoría") and (CatCCT.Descripción <> '') then
                EtiquetaCat := TempSlice."Cód. Categoría" + ' - ' + CatCCT.Descripción;
            LinLiq."No. Liquidación" := Liq."No.";
            LinLiq."No. Empleado" := Liq."No. Empleado";
            LinLiq."Cód. Período" := Liq."Cód. Período";
            LinLiq."No. Proyecto" := Liq."No. Proyecto";
            LinLiq."Cód. Tipo Liq." := Liq."Cód. Tipo Liq.";
            LinLiq.Estado := LinLiq.Estado::Calculada;
            LinLiq."Fecha Liquidación" := Liq."Fecha Liquidación";
            LinLiq."Cód. Concepto" := Concepto.Código;
            LinLiq."Descripción Concepto" := CopyStr(Concepto.Descripción + ' (' + EtiquetaCat + ')', 1, MaxStrLen(LinLiq."Descripción Concepto"));
            LinLiq."Nombre Impresión" := CopyStr(Concepto."Nombre Impresión" + ' (' + EtiquetaCat + ')', 1, MaxStrLen(LinLiq."Nombre Impresión"));
            LinLiq."Tipo Concepto" := Concepto."Tipo Concepto";
            LinLiq."Grupo Costo Laboral" := Concepto."Grupo Costo Laboral";
            LinLiq."Imprime en Recibo" := Concepto."Imprime en Recibo";
            LinLiq."Es Devengo" := Concepto."Es Devengo";
            // The lot's own convenio/categoría (may differ from the employee's current) → shows the price basis.
            LinLiq."Cód. Convenio" := TempSlice."Cód. Convenio";
            LinLiq."Cód. Categoría" := TempSlice."Cód. Categoría";
            LinLiq.Cantidad := TempSlice.Cantidad;
            LinLiq."Unidad Cantidad" := Concepto."Unidad Cantidad";
            LinLiq.Importe := TempSlice.Importe;
            LinLiq."Orden Cálculo" := Concepto."Orden Cálculo";
            LinLiq."Fórmula Aplicada" := Concepto.Fórmula;
            LinLiq."Vigencia Concepto" := Concepto."Vigencia Desde";
            if Concepto."Variable Base" <> '' then
                LinLiq."Base Cálculo" := ResolverExpresionLinea(Concepto."Variable Base", Ctx, FechaRef, Evaluador);
            if not FIteracionGU then begin
                LinLiq."Fórmula Evaluada" := CopyStr(FormulaEvaluada, 1, MaxStrLen(LinLiq."Fórmula Evaluada"));
                LinLiq."Vigencias Distribución" := CopyStr(Distribucion, 1, MaxStrLen(LinLiq."Vigencias Distribución"));
                LinLiq."Fuente Parámetros" := CopyStr(CtxBuilder.GetParamLog() + '|' + ConceptLog, 1, MaxStrLen(LinLiq."Fuente Parámetros"));
            end;
            InsertarLineaLiquidacion(LinLiq);
            if not FIteracionGU then
                WriteVariableDetail(Liq."No.", LinLiq."No. Línea", ConceptLog, Ctx, Evaluador);
            ImporteTotal += TempSlice.Importe;
        until TempSlice.Next() = 0;
    end;

    local procedure WriteIncidenciasRestantes(
        var Liq: Record "Liquidación";
        FechaRef: Date;
        var FracAccumList: Dictionary of [Code[20], Text];
        var FracAccumPct: Dictionary of [Text, Decimal];
        var Ctx: Dictionary of [Text, Decimal])
    var
        Incid: Record "Incidencia Liquidación" temporary;
        Concepto: Record "Concepto Liquidación";
        LinLiq: Record "Línea Liquidación";
        ExistingLine: Record "Línea Liquidación";
    begin
        CompartirIncidencias(Incid);
        Incid.SetRange("No. Liquidación", Liq."No.");
        if not Incid.FindSet() then exit;
        repeat
            // Una incidencia de solo CANTIDAD no se puede rescatar acá: su importe lo produce la
            // fórmula del concepto, y si el concepto no generó línea es porque no se evaluó —no
            // aplica a este convenio, a este tipo de liquidación, o su condición dio falso—. No hay
            // número que escribir, pero sí hay algo que decir: alguien cargó 21 horas y no se pagaron.
            // Sin este aviso desaparecían sin dejar rastro, que es exactamente el modo de fallar que
            // esta vía vino a corregir.
            if (Incid.Importe = 0) and (Incid.Cantidad <> 0) then begin
                ExistingLine.SetRange("No. Liquidación", Liq."No.");
                ExistingLine.SetRange("Cód. Concepto", Incid."Cód. Concepto");
                if ExistingLine.IsEmpty() then
                    Registro.AdvertirVariable(
                        "Categoría Registro Liq."::General,
                        StrSubstNo(RegIncidSinLineaTxt, Incid."Cód. Concepto", Incid.Cantidad),
                        '', Incid."Cód. Concepto");
            end;

            if Incid.Importe <> 0 then begin
                ExistingLine.SetRange("No. Liquidación", Liq."No.");
                ExistingLine.SetRange("Cód. Concepto", Incid."Cód. Concepto");
                if ExistingLine.IsEmpty() then begin
                    Concepto.SetRange(Código, Incid."Cód. Concepto");
                    Concepto.SetFilter("Vigencia Desde", '<=%1', FechaRef);
                    if Concepto.FindLast() then begin
                        Clear(LinLiq);
                        LinLiq."No. Liquidación" := Liq."No.";
                        LinLiq."No. Empleado" := Liq."No. Empleado";
                        LinLiq."Cód. Período" := Liq."Cód. Período";
                        LinLiq."No. Proyecto" := Liq."No. Proyecto";
                        LinLiq."Cód. Tipo Liq." := Liq."Cód. Tipo Liq.";
                        LinLiq."Cód. Convenio" := Liq."Cód. Convenio";
                        LinLiq."Cód. Categoría" := Liq."Cód. Categoría";
                        LinLiq.Estado := LinLiq.Estado::Calculada;
                        LinLiq."Fecha Liquidación" := Liq."Fecha Liquidación";
                        LinLiq."Cód. Concepto" := Concepto.Código;
                        LinLiq."Descripción Concepto" := Concepto.Descripción;
                        LinLiq."Nombre Impresión" := Concepto."Nombre Impresión";
                        LinLiq."Tipo Concepto" := Concepto."Tipo Concepto";
                        LinLiq."Grupo Costo Laboral" := Concepto."Grupo Costo Laboral";
                        LinLiq."Imprime en Recibo" := Concepto."Imprime en Recibo";
                        LinLiq."Es Devengo" := Concepto."Es Devengo";
                        // Se respeta el signo cargado, igual que en RunConceptos.
                        LinLiq.Importe := Incid.Importe;
                        if Incid.Cantidad <> 0 then begin
                            LinLiq.Cantidad := Incid.Cantidad;
                            LinLiq."Unidad Cantidad" := Incid."Unidad Cantidad";
                            LinLiq."Base Cálculo" := Incid."Valor Unitario";
                        end;
                        LinLiq."Orden Cálculo" := Concepto."Orden Cálculo";
                        LinLiq."Vigencia Concepto" := Concepto."Vigencia Desde";
                        LinLiq."Vigencias Distribución" := DescribirDistribucion(Concepto.Código);
                        InsertarLineaLiquidacion(LinLiq);

                        // Esta línea se escribe DESPUÉS de todo el bucle, así que su aporte llega
                        // tarde por definición, sin importar el Orden Cálculo que diga el concepto.
                        // Se registra explícitamente porque el control normal compara órdenes y acá
                        // el orden miente: la línea dice 165 y el aporte entró último.
                        RegistrarAporteFueraDeOrden(Concepto.Código, FracAccumList);
                        UpdateAccumulatorsFromCache(
                            Concepto.Código, LinLiq.Importe, FracAccumList, FracAccumPct, Ctx);
                    end;
                end;
            end;
        until Incid.Next() = 0;
    end;

    local procedure WriteAccumulatorLines(
        var Liq: Record "Liquidación";
        FechaRef: Date;
        var Ctx: Dictionary of [Text, Decimal];
        var LatestVersionMap: Dictionary of [Code[20], Date])
    var
        Concepto: Record "Concepto Liquidación";
        LinLiq: Record "Línea Liquidación";
        Valor: Decimal;
    begin
        Concepto.SetRange("Es Acumulador", true);
        // Sin filtro de Activo ni de fecha: las dos cosas ya están resueltas en LatestVersionMap, y
        // la línea siguiente exige coincidencia exacta con la versión que ganó.
        if not Concepto.FindSet() then
            exit;
        repeat
            if EsVersionEnUso(LatestVersionMap, Concepto.Código, Concepto."Vigencia Desde") and
               Ctx.ContainsKey(Concepto.Código)
            then begin
                Valor := Ctx.Get(Concepto.Código);
                Clear(LinLiq);
                LinLiq."No. Liquidación" := Liq."No.";
                LinLiq."No. Empleado" := Liq."No. Empleado";
                LinLiq."Cód. Período" := Liq."Cód. Período";
                LinLiq."No. Proyecto" := Liq."No. Proyecto";
                LinLiq."Cód. Tipo Liq." := Liq."Cód. Tipo Liq.";
                LinLiq."Cód. Convenio" := Liq."Cód. Convenio";
                LinLiq."Cód. Categoría" := Liq."Cód. Categoría";
                LinLiq.Estado := LinLiq.Estado::Calculada;
                LinLiq."Fecha Liquidación" := Liq."Fecha Liquidación";
                LinLiq."Cód. Concepto" := Concepto.Código;
                LinLiq."Descripción Concepto" := Concepto.Descripción;
                LinLiq."Nombre Impresión" := Concepto."Nombre Impresión";
                LinLiq."Tipo Concepto" := LinLiq."Tipo Concepto"::Informativo;
                LinLiq."Imprime en Recibo" := false;
                LinLiq.Importe := Valor;
                LinLiq."Orden Cálculo" := Concepto."Orden Cálculo";
                LinLiq."Vigencia Concepto" := Concepto."Vigencia Desde";
                LinLiq."Fórmula Evaluada" := Format(Valor);
                InsertarLineaLiquidacion(LinLiq);
            end;
        until Concepto.Next() = 0;
    end;

    /// <summary>
    /// Qué población encuadra a este empleado: sale del CONVENIO, no del estado del día.
    /// </summary>
    /// <remarks>
    /// ANTES SALÍA DEL ESTADO —CodEstado."Tipo Empleado" del estado vigente a FechaRef— y eso se
    /// rompe con cualquier estado compartido. Un tripulante de vacaciones está en AU9, que usa todo
    /// el mundo; AU9 dice "Todos"; y "Todos" en SelectConceptos NO ES un tipo, es la ausencia de
    /// filtro. Resultado: al tripulante le entraban todos los conceptos de mensualizado. El legajo
    /// 00191 —CCT 729/15, Primer Cocinero— cobró "Antigüedad mensuales" en enero de 2026 por esto.
    ///
    /// El tipo de empleado no puede depender de en qué estado amaneció esa persona. Depende de su
    /// encuadre, y el encuadre es el convenio.
    ///
    /// El convenio que se usa es el de la CABECERA, resuelto por ParDeEntidad al abrir el cálculo,
    /// y no el par alterno que algún concepto pueda imponer: que un concepto se valorice bajo otro
    /// CCT no convierte a la persona en otra cosa.
    ///
    /// Sin convenio configurado devuelve Todos, que no filtra. Es el comportamiento permisivo de
    /// antes y es el que corresponde ante la duda: un concepto de más se ve en el recibo, uno de
    /// menos no lo nota nadie.
    /// </remarks>
    local procedure TipoEmpleadoDe(Liq: Record "Liquidación"): Enum "Aplica A Liq."
    var
        Convenio: Record "Convenio Colectivo";
        Ninguno: Enum "Aplica A Liq.";
    begin
        if Liq."Cód. Convenio" = '' then
            exit(Ninguno::Todos);
        if not Convenio.Get(Liq."Cód. Convenio") then
            exit(Ninguno::Todos);
        exit(Convenio."Tipo Empleado");
    end;

    local procedure SelectConceptos(
        var Concepto: Record "Concepto Liquidación";
        TipoEmpleado: Enum "Aplica A Liq.";
        FechaRef: Date;
        TipoLiq: Code[20])
    begin
        Concepto.Reset();
        // Sin filtro de Activo: la baja la resuelve FLatestVersionMap, que ya excluye al concepto
        // cuya versión vigente está dada de baja. RunConceptos descarta toda línea que no coincida
        // con el mapa, así que ese es el único punto donde se decide.
        Concepto.FiltrarVigentesA(FechaRef);
        if TipoEmpleado <> TipoEmpleado::Todos then
            Concepto.SetFilter("Aplica A", '%1|%2', Concepto."Aplica A"::Todos, TipoEmpleado);
        Concepto.SetCurrentKey("Orden Cálculo", Código);
    end;

    /// <summary>
    /// El recorrido del CÁLCULO: los mismos conceptos, pero sin descartar por tipo de empleado.
    /// </summary>
    /// <remarks>
    /// El filtro de "Aplica A" se saca del SetFilter y se evalúa adentro del bucle, porque un
    /// concepto que no le aplica al empleado igual tiene que RECORRERSE si trae una incidencia
    /// cargada a mano. Filtrado de entrada, esa incidencia no encontraba su lugar en el bucle y caía
    /// en WriteIncidenciasRestantes, que corre después de todo: su aporte al acumulador llegaba al
    /// final, después de que los conceptos que leen ese acumulador ya lo habían leído.
    ///
    /// Y no se notaba: la línea queda estampada con el Orden Cálculo del concepto —165, digamos—
    /// mientras que su aporte entró último. Mirando la liquidación, el orden parece correcto.
    ///
    /// La validación de fórmulas (fase 1) sigue usando SelectConceptos con el filtro puesto: ahí no
    /// hay que validar la fórmula de un concepto que no le aplica a este empleado.
    /// </remarks>
    local procedure SelectConceptosParaCalculo(var Concepto: Record "Concepto Liquidación"; FechaRef: Date)
    begin
        Concepto.Reset();
        Concepto.FiltrarVigentesA(FechaRef);
        Concepto.SetCurrentKey("Orden Cálculo", Código);
    end;

    local procedure AplicaAlTipoEmpleado(Concepto: Record "Concepto Liquidación"; TipoEmpleado: Enum "Aplica A Liq."): Boolean
    begin
        // Misma regla que el SetFilter de SelectConceptos: "Todos" de cualquiera de los dos lados no
        // restringe nada.
        if TipoEmpleado = TipoEmpleado::Todos then
            exit(true);
        if Concepto."Aplica A" = Concepto."Aplica A"::Todos then
            exit(true);
        exit(Concepto."Aplica A" = TipoEmpleado);
    end;

    /// <summary>
    /// ¿Este concepto corre en este tipo de liquidación?
    /// </summary>
    /// <remarks>
    /// LA LISTA DEL CONCEPTO ES BLANCA Y VACÍA SIGNIFICA "TODOS", que está bien para el caso normal
    /// —un concepto que no declara nada aplica en todas partes— pero NO permite decir lo contrario:
    /// "en VACACIONES corren SOLAMENTE estos". Para eso habría que ir a los 185 conceptos que hoy no
    /// declaran tipo y sacarles VACACIONES uno por uno.
    ///
    /// Por eso el tipo puede invertir la regla con "Sólo Conceptos Declarados": marcado, corre
    /// únicamente los conceptos que lo nombran, y el vacío deja de ser un comodín. Cinco asignaciones
    /// en vez de ciento ochenta y cinco.
    ///
    /// LO QUE PASABA SIN ESTO: la liquidación de Vacaciones recalculaba el RECIBO ENTERO. En enero de
    /// 2026, 133 empleados cobraron dos veces el SAC devengado, la ART, las contribuciones
    /// patronales, la jubilación, la cuota sindical, el acuerdo del Dto 633/18 y hasta Ganancias —una
    /// vez en su Regular y otra en su Vacaciones—. En Meta4 una corrida de vacaciones paga UN
    /// devengo, VACACIONES, y nada más.
    /// </remarks>
    local procedure ConceptoAplicaATipoLiq(Concepto: Record "Concepto Liquidación"; TipoLiq: Code[20]): Boolean
    var
        TipoLiqRec: Record "Tipo Liquidación";
        Declarado: Boolean;
    begin
        Declarado := ('|' + Concepto."Tipos Liq. Aplicables" + '|').Contains('|' + TipoLiq + '|');
        // LOS INFORMATIVOS NO SE RESTRINGEN NUNCA. No pagan: alimentan acumuladores y bases, y son
        // lo que los conceptos que sí pagan leen después. Bloquearlos dejaría las bases en cero y el
        // recibo saldría mal por un camino que no tiene nada que ver con lo que se quiso acotar.
        if Concepto."Tipo Concepto" = Concepto."Tipo Concepto"::Informativo then
            exit((Concepto."Tipos Liq. Aplicables" = '') or Declarado);
        if TipoLiqRec.Get(TipoLiq) then
            if TipoLiqRec."Sólo Conceptos Declarados" then
                exit(Declarado);
        if Concepto."Tipos Liq. Aplicables" = '' then
            exit(true);
        exit(Declarado);
    end;

    // ── Pre-build caches (called once per liquidation, before the concept loop) ──

    // Builds (once per FechaRef) the concept caches shared by ValidarFormulas, RunConceptos,
    // and every GU iteration. Subsequent calls with the same FechaRef are no-ops.
    local procedure EnsureConceptCaches(FechaRef: Date)
    var
        Concepto: Record "Concepto Liquidación";
        CodigoConcepto: Code[20];
    begin
        if FConceptCacheLoaded and (FConceptCacheFecha = FechaRef) then
            exit;
        Clear(FLatestVersionMap);
        Clear(FFracAccumList);
        Clear(FFracAccumPct);
        Clear(FFracAccumVig);
        Clear(FAccumCodes);
        BuildLatestVersionCache(FechaRef, FLatestVersionMap);
        BuildFractionCache(FechaRef, FFracAccumList, FFracAccumPct, FFracAccumVig);

        // Es acumulador el concepto cuya VERSIÓN VIGENTE a la fecha lo declara así. Antes se
        // recorrían todas las vigencias sin filtro de fecha, de modo que un concepto que recién pasa
        // a ser acumulador el año que viene ya contaba hoy, y uno que dejó de serlo seguía contando.
        // WriteAccumulatorLines sí resolvía por versión, así que las dos mitades no coincidían.
        // FLatestVersionMap ya trae solo versiones activas y vigentes a FechaRef.
        foreach CodigoConcepto in FLatestVersionMap.Keys() do
            if Concepto.Get(CodigoConcepto, FLatestVersionMap.Get(CodigoConcepto)) then
                if Concepto."Es Acumulador" then
                    FAccumCodes.Add(CodigoConcepto);
        FConceptCacheFecha := FechaRef;
        FConceptCacheLoaded := true;
    end;

    /// <summary>
    /// True si esta versión del concepto es la que el mapa eligió para la fecha de referencia.
    /// </summary>
    /// <remarks>
    /// El ContainsKey y el Get van en sentencias SEPARADAS, nunca encadenados con `and` en una sola
    /// expresión: AL no garantiza cortocircuito, así que el Get se evalúa igual aunque el
    /// ContainsKey haya dado false, y tira "la clave proporcionada no estaba presente en el
    /// diccionario".
    ///
    /// Estuvo latente mucho tiempo sin explotar porque SelectConceptos y BuildLatestVersionCache
    /// usaban el MISMO filtro de Activo: todo lo que devolvía el bucle estaba sí o sí en el mapa.
    /// Al pasar la baja a resolverse por fecha, el mapa empezó a excluir al concepto discontinuado
    /// mientras el bucle lo sigue devolviendo — y ahí la falta de cortocircuito se cobró la deuda.
    /// </remarks>
    local procedure EsVersionEnUso(var Mapa: Dictionary of [Code[20], Date]; CodConcepto: Code[20]; VigenciaDesde: Date): Boolean
    begin
        if not Mapa.ContainsKey(CodConcepto) then
            exit(false);
        exit(VigenciaDesde = Mapa.Get(CodConcepto));
    end;

    local procedure BuildLatestVersionCache(FechaRef: Date; var LatestMap: Dictionary of [Code[20], Date])
    var
        Concepto: Record "Concepto Liquidación";
        Ganadora: Record "Concepto Liquidación";
        CodigoConcepto: Code[20];
    begin
        Concepto.Reset();
        // Solo el intervalo de vigencia entra al filtro. La baja del concepto se decide después,
        // sobre la versión ganadora, en VigenteA: es la diferencia entre "este concepto está dado
        // de baja" y "esta versión no existe", que es lo que significaba filtrar por Activo acá.
        Concepto.FiltrarVigentesA(FechaRef);
        // Solo se leen los tres campos que decide este cache. Concepto arrastra fórmula, condición y
        // descripciones largas que acá no se miran.
        Concepto.SetLoadFields(Código, "Vigencia Desde", "Vigencia Hasta");
        if not Concepto.FindSet() then exit;
        repeat
            if not LatestMap.ContainsKey(Concepto.Código) then
                LatestMap.Add(Concepto.Código, Concepto."Vigencia Desde")
            else
                if Concepto."Vigencia Desde" > LatestMap.Get(Concepto.Código) then
                    LatestMap.Set(Concepto.Código, Concepto."Vigencia Desde");
        until Concepto.Next() = 0;

        // Copia ANTES de descartar las discontinuadas: es "la última versión de cada concepto,
        // vigente o no". La usa el bucle para dejar entrar una incidencia cargada sobre un concepto
        // dado de baja — se paga porque alguien la cargó a mano, pero se paga EN SU ORDEN, que es lo
        // que antes no pasaba: caía en WriteIncidenciasRestantes y aportaba al acumulador último.
        Clear(FUltimaVersionMap);
        foreach CodigoConcepto in LatestMap.Keys() do
            FUltimaVersionMap.Add(CodigoConcepto, LatestMap.Get(CodigoConcepto));

        // Keys() devuelve una lista propia, así que sacar del diccionario mientras se recorre es seguro.
        foreach CodigoConcepto in LatestMap.Keys() do
            if Ganadora.Get(CodigoConcepto, LatestMap.Get(CodigoConcepto)) then
                if not Ganadora.VigenteA(FechaRef) then
                    LatestMap.Remove(CodigoConcepto);
    end;

    // Returns true if this concept applies to CodConvenio at FechaRef.
    // Fast path via the "Vigencia CCT Más Reciente" MaxFlowField: when 0D there are
    // no restrictions for the concept at all and the lookup short-circuits.
    // When restrictions exist, two indexed lookups (FindLast + Get) resolve the
    // applicability for FechaRef without scanning the table.
    internal procedure CCTAplicaAConcepto(var Concepto: Record "Concepto Liquidación"; CodConvenio: Code[20]; CodCategoria: Code[20]; FechaRef: Date): Boolean
    var
        Clave: Text;
        Resultado: Boolean;
    begin
        // Longitudes explícitas: los códigos pueden contener el separador.
        Clave := StrSubstNo('%1:%2%3:%4%5:%6%7:%8',
            StrLen(Concepto.Código), Concepto.Código,
            StrLen(CodConvenio), CodConvenio, StrLen(CodCategoria), CodCategoria,
            Format(Concepto."Vigencia Desde", 0, 9), Format(FechaRef, 0, 9));
        if FCCTAplicabilidad.Get(Clave, Resultado) then
            exit(Resultado);
        Resultado := ResolverCCTAplicaAConcepto(Concepto, CodConvenio, CodCategoria, FechaRef);
        FCCTAplicabilidad.Add(Clave, Resultado);
        exit(Resultado);
    end;

    local procedure ResolverCCTAplicaAConcepto(var Concepto: Record "Concepto Liquidación"; CodConvenio: Code[20]; CodCategoria: Code[20]; FechaRef: Date): Boolean
    var
        CCTVig: Record "Concepto CCT Vigente";
        Fila: Record "Concepto CCT Vigente";
        VigenciaAplicable: Date;
    begin
        Concepto.CalcFields("Vigencia CCT Más Reciente");
        if Concepto."Vigencia CCT Más Reciente" = 0D then
            exit(true);

        // Las exclusiones se resuelven PRIMERO y ganan sobre cualquier inclusión. Son una capa
        // aparte del versionado por convenio: ver la nota del campo "Excluye".
        if ExcluidoPorCCT(Concepto.Código, CodConvenio, CodCategoria, FechaRef) then
            exit(false);

        // De acá en adelante solo cuentan las inclusiones. Si no hay ninguna activa, el concepto
        // aplica a todo lo que no se haya excluido — que es el caso "a todos menos a uno", donde la
        // única fila cargada es una exclusión.
        CCTVig.SetRange(Excluye, false);
        CCTVig.SetRange("Cód. Concepto", Concepto.Código);
        CCTVig.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        if CCTVig.IsEmpty() then
            exit(true); // restrictions exist but none active yet at FechaRef

        // El versionado es POR CONVENIO, no por lote completo: cada convenio conserva su propia
        // vigencia vigente. Cargar una vigencia nueva para un convenio (ej. 175/75 desde 2026) no
        // revoca la vigencia todavía válida de otro (ej. ESP desde 2023) — antes se consultaba
        // solo el lote más reciente del concepto y eso hacía desaparecer en silencio a los demás
        // convenios.
        CCTVig.SetRange("Cód. Convenio", CodConvenio);
        if not CCTVig.FindLast() then
            exit(false); // hay restricciones activas y este convenio no está entre ellas

        // DENTRO DEL CONVENIO SE BUSCA HACIA ATRÁS hasta la última vigencia que NOMBRE a esta
        // categoría. Una vigencia nueva agrega y actualiza; no revoca lo que no menciona.
        //
        // Antes mandaba sólo la más reciente, y eso convertía una omisión en una baja silenciosa: la
        // vigencia 2026 del 175/75 se cargó enumerando OF01 y OF02 —la lista de categorías de OTRO
        // convenio—, y con eso los OF04 se quedaron sin sueldo de navegación, sin antigüedad, sin
        // francos y sin cuota sindical desde el 1/1/2026. No hay línea en cero ni error: el concepto
        // no se evalúa. Cuatro empleados con el recibo entero vacío y ni un aviso.
        //
        // Lo que se resigna es poder restringir por omisión: para sacarle un concepto a una
        // categoría hay que cargar una fila con "Excluye", que es explícita y se ve. Es el precio
        // justo — un acuerdo paritario agrega conceptos y cambia importes; quitarle uno a una
        // categoría es excepcional y merece quedar escrito.
        //
        // La vigencia se guarda ANTES de cualquier Get: un Get fallido deja el registro en blanco,
        // así que leer CCTVig."Vigencia Desde" después daría 0D.
        repeat
            VigenciaAplicable := CCTVig."Vigencia Desde";

            // Coincidencia exacta de convenio+categoría gana; si no existe, una fila de "todo el
            // convenio" (categoría en blanco) también aplica.
            //
            // El Get NO respeta el filtro de Excluye —ignora todos los filtros—, así que se lee la
            // bandera de la fila encontrada en vez de darla por inclusión. Hoy no puede ser una
            // exclusión (ExcluidoPorCCT ya miró esas mismas dos claves), pero atarlo al filtro de
            // arriba es la clase de suposición que se rompe cuando alguien toca el orden de las
            // líneas. Va en una variable aparte para no perder la posición del recorrido.
            if Fila.Get(Concepto.Código, VigenciaAplicable, CodConvenio, CodCategoria) then
                exit(not Fila.Excluye);
            if Fila.Get(Concepto.Código, VigenciaAplicable, CodConvenio, '') then
                exit(not Fila.Excluye);

            // Esta vigencia no habló de esta categoría: sigue valiendo lo que dijo la anterior.
            CCTVig.SetFilter("Vigencia Desde", '<%1', VigenciaAplicable);
        until not CCTVig.FindLast();

        // Ninguna vigencia del convenio nombró nunca a esta categoría.
        exit(false);
    end;

    /// <summary>
    /// ¿Hay una exclusión activa de este convenio (o de esta categoría dentro de él) a esta fecha?
    /// </summary>
    /// <remarks>
    /// La exclusión del convenio entero (categoría en blanco) y la de una categoría puntual conviven:
    /// alcanza con que cualquiera de las dos esté activa. No hay versionado que resolver porque una
    /// exclusión no se revoca con una vigencia posterior sino borrando la fila.
    /// </remarks>
    local procedure ExcluidoPorCCT(CodConcepto: Code[20]; CodConvenio: Code[20]; CodCategoria: Code[20]; FechaRef: Date): Boolean
    var
        CCTVig: Record "Concepto CCT Vigente";
    begin
        CCTVig.SetRange("Cód. Concepto", CodConcepto);
        CCTVig.SetRange(Excluye, true);
        CCTVig.SetRange("Cód. Convenio", CodConvenio);
        CCTVig.SetFilter("Cód. Categoría", '%1|%2', '', CodCategoria);
        CCTVig.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        exit(not CCTVig.IsEmpty());
    end;

    // Single-pass build of fraction cache, sorted by Concepto+Vigencia.
    // For each concept, finds the latest vigencia per accumulator pair and caches
    // the percentage. A concept can feed multiple accumulators with independent vigencias.
    local procedure BuildFractionCache(FechaRef: Date;
        var AccumList: Dictionary of [Code[20], Text];
        var AccumPct: Dictionary of [Text, Decimal];
        var AccumVig: Dictionary of [Text, Date])
    var
        Fraccion: Record "Fracción Acumulador";
        AccumKey: Text;
        PctConSigno: Decimal;
        BestVig: Dictionary of [Text, Date];
    begin
        Fraccion.SetLoadFields("Cód. Concepto", "Cód. Acumulador", "Vigencia Desde", Porcentaje, "Invertir Signo");
        Fraccion.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        if not Fraccion.FindSet() then exit;

        // Pass 1: find the latest vigencia per (concept, accumulator) pair
        repeat
            AccumKey := Fraccion."Cód. Concepto" + '~' + Fraccion."Cód. Acumulador";
            if not BestVig.ContainsKey(AccumKey) then
                BestVig.Add(AccumKey, Fraccion."Vigencia Desde")
            else
                if Fraccion."Vigencia Desde" > BestVig.Get(AccumKey) then
                    BestVig.Set(AccumKey, Fraccion."Vigencia Desde");
        until Fraccion.Next() = 0;

        // Pass 2: build caches using only the latest vigencia per pair
        Fraccion.FindSet();
        repeat
            AccumKey := Fraccion."Cód. Concepto" + '~' + Fraccion."Cód. Acumulador";
            if Fraccion."Vigencia Desde" = BestVig.Get(AccumKey) then begin
                PctConSigno := Fraccion.Porcentaje;
                if Fraccion."Invertir Signo" then PctConSigno := -PctConSigno;
                if AccumPct.ContainsKey(AccumKey) then
                    AccumPct.Set(AccumKey, PctConSigno)
                else
                    AccumPct.Add(AccumKey, PctConSigno);

                // La vigencia que ganó se guarda junto al porcentaje: es lo que después se estampa
                // en la línea para poder auditar con qué distribución se acumuló.
                if AccumVig.ContainsKey(AccumKey) then
                    AccumVig.Set(AccumKey, Fraccion."Vigencia Desde")
                else
                    AccumVig.Add(AccumKey, Fraccion."Vigencia Desde");

                if not AccumList.ContainsKey(Fraccion."Cód. Concepto") then
                    AccumList.Add(Fraccion."Cód. Concepto", Fraccion."Cód. Acumulador")
                else begin
                    if not ('|' + AccumList.Get(Fraccion."Cód. Concepto") + '|').Contains('|' + Fraccion."Cód. Acumulador" + '|') then
                        AccumList.Set(Fraccion."Cód. Concepto",
                            AccumList.Get(Fraccion."Cód. Concepto") + '|' + Fraccion."Cód. Acumulador");
                end;
            end;
        until Fraccion.Next() = 0;
    end;

    // ── Control de orden de cálculo (red de seguridad en tiempo de cálculo) ────
    //
    // El acumulador se suma a medida que los conceptos corren en Orden Cálculo, así que quien lo lee
    // ve el subtotal acumulado hasta su punto, no el total. Configurado al revés, la liquidación
    // sale con un importe menor SIN ningún error y sin nada visible: el drill-down del acumulador se
    // arma al final, con todos los aportes, así que ni siquiera se nota la diferencia.
    //
    // El control estático (Cod50067) encuentra esto sin liquidar, leyendo las fórmulas. Acá se cubre
    // lo que ese análisis no puede ver: una lectura indirecta vía @CÓDIGO, que reevalúa otro
    // concepto y resuelve el acumulador sin nombrarlo en la fórmula propia.

    local procedure RegistrarLecturasAcumuladores(ConceptLog: Text; CodConcepto: Code[20]; Orden: Integer)
    var
        Entries: List of [Text];
        Entry: Text;
        VarName: Text;
    begin
        if FIteracionGU or (ConceptLog = '') then
            exit;
        Entries := ConceptLog.Split('|');
        foreach Entry in Entries do
            if Entry.StartsWith('VAR:') then begin
                VarName := CopyStr(Entry, 5);
                // @CÓDIGO/#CÓDIGO se registran con prefijo en el log; el acumulador vive bajo el
                // código pelado (ver WriteVariableDetail).
                if VarName.StartsWith('@') or VarName.StartsWith('#') then
                    VarName := CopyStr(VarName, 2);
                if FAccumCodes.Contains(CopyStr(VarName, 1, 20)) then
                    if not FAcumLeidoEnOrden.ContainsKey(VarName) then begin
                        // Solo la PRIMERA lectura: es la que marca hasta dónde tienen que haber
                        // llegado los aportes.
                        FAcumLeidoEnOrden.Add(VarName, Orden);
                        FAcumLeidoPorConcepto.Add(VarName, CodConcepto);
                    end;
            end;
    end;

    local procedure VerificarOrdenAporte(CodConcepto: Code[20]; Orden: Integer)
    var
        AccumCodes: List of [Text];
        AccumCode: Text;
    begin
        if FIteracionGU then
            exit;
        if not FFracAccumList.ContainsKey(CodConcepto) then
            exit;
        AccumCodes := FFracAccumList.Get(CodConcepto).Split('|');
        foreach AccumCode in AccumCodes do
            if FAcumLeidoEnOrden.ContainsKey(AccumCode) then
                if AporteLlegaTarde(AccumCode, CodConcepto, Orden) then
                    RegistrarAporteTardio(AccumCode, CodConcepto, Orden);
    end;

    // Con el mismo Orden Cálculo el motor resuelve por Código (SelectConceptos ordena por
    // "Orden Cálculo", Código), así que un empate NO es necesariamente un problema: depende de si el
    // código del que aporta cae antes o después del que lee. Comparar solo el orden marcaba como
    // conflicto la mitad de los empates que en realidad corren bien, y además marcaba al concepto
    // que lee y aporta al mismo acumulador contra sí mismo.
    local procedure AporteLlegaTarde(AccumCode: Text; CodConcepto: Code[20]; Orden: Integer): Boolean
    var
        OrdenLectura: Integer;
    begin
        OrdenLectura := FAcumLeidoEnOrden.Get(AccumCode);
        if Orden > OrdenLectura then
            exit(true);
        if Orden < OrdenLectura then
            exit(false);
        exit(CodConcepto > FAcumLeidoPorConcepto.Get(AccumCode));
    end;

    // Se acumula por ACUMULADOR, no por aporte. Un acumulador leído temprano suele tener una decena
    // de aportes posteriores, y un aviso por cada uno sepulta al resto: son todos el mismo problema
    // y se resuelven con la misma decisión de orden.
    /// <summary>
    /// Marca como tardío el aporte de un concepto escrito fuera del bucle, para cada acumulador que
    /// alimente y que alguien ya haya leído.
    /// </summary>
    /// <remarks>
    /// El orden que se registra es deliberadamente altísimo: no representa un Orden Cálculo real,
    /// representa "después de todo". Sin eso, la comparación normal de órdenes daría que el aporte
    /// llegó temprano —el concepto puede estar configurado en el orden 165— y el aviso no saldría,
    /// que es exactamente lo que hacía que este caso pasara inadvertido.
    /// </remarks>
    local procedure RegistrarAporteFueraDeOrden(CodConcepto: Code[20]; var AccumList: Dictionary of [Code[20], Text])
    var
        AccumCodes: List of [Text];
        AccumCode: Text;
    begin
        if FIteracionGU then
            exit;
        if not AccumList.ContainsKey(CodConcepto) then
            exit;
        AccumCodes := AccumList.Get(CodConcepto).Split('|');
        foreach AccumCode in AccumCodes do
            if FAcumLeidoEnOrden.ContainsKey(AccumCode) then
                RegistrarAporteTardio(AccumCode, CodConcepto, 999999999);
    end;

    local procedure RegistrarAporteTardio(AccumCode: Text; CodConcepto: Code[20]; Orden: Integer)
    begin
        if not FAcumAporteTardioOrden.ContainsKey(AccumCode) then begin
            FAcumAporteTardioOrden.Add(AccumCode, Orden);
            FAcumAporteTardioCodigo.Add(AccumCode, CodConcepto);
            FAcumAportesTardios.Add(AccumCode, 1);
            exit;
        end;
        FAcumAportesTardios.Set(AccumCode, FAcumAportesTardios.Get(AccumCode) + 1);
        // Se guarda el último aporte: es el que marca hasta dónde hay que mover la lectura.
        if Orden > FAcumAporteTardioOrden.Get(AccumCode) then begin
            FAcumAporteTardioOrden.Set(AccumCode, Orden);
            FAcumAporteTardioCodigo.Set(AccumCode, CodConcepto);
        end;
    end;

    // Las mismas advertencias que el texto del Message, pero como entradas con el acumulador y el
    // concepto en sus propios campos: en el registro son columnas filtrables, y el mensaje se acorta
    // porque no tiene que repetir lo que ya dice cada columna.
    //
    // Se registra desde LiquidarRecord y no desde ConstruirAvisosOrden: RunConceptos corre dos veces
    // con auditoría activa cuando hay grossing-up (la pasada inicial y la final), y anotar en cada
    // una duplicaría todas las advertencias.
    local procedure RegistrarAvisosOrdenEnLog()
    var
        AccumCode: Text;
    begin
        foreach AccumCode in FAcumAporteTardioOrden.Keys() do
            Registro.AdvertirVariable(
                "Categoría Registro Liq."::"Orden Cálculo",
                StrSubstNo(
                    AvisoOrdenCortoTxt,
                    FAcumLeidoEnOrden.Get(AccumCode),
                    FAcumAportesTardios.Get(AccumCode),
                    FAcumAporteTardioCodigo.Get(AccumCode),
                    FAcumAporteTardioOrden.Get(AccumCode)),
                CopyStr(AccumCode, 1, 30),
                FAcumLeidoPorConcepto.Get(AccumCode));
    end;

    local procedure ConstruirAvisosOrden()
    var
        AccumCode: Text;
    begin
        FAvisosOrden := '';
        foreach AccumCode in FAcumAporteTardioOrden.Keys() do begin
            if FAvisosOrden <> '' then
                FAvisosOrden += '\';
            FAvisosOrden += StrSubstNo(
                AvisoOrdenTxt,
                AccumCode,
                FAcumLeidoPorConcepto.Get(AccumCode),
                FAcumLeidoEnOrden.Get(AccumCode),
                FAcumAportesTardios.Get(AccumCode),
                FAcumAporteTardioCodigo.Get(AccumCode),
                FAcumAporteTardioOrden.Get(AccumCode));
        end;
    end;

    /// <summary>
    /// Sello de auditoría de la distribución: "ACUMULADOR:AAAAMMDD" por cada acumulador que este
    /// concepto alimenta, con la vigencia de la fracción que efectivamente se aplicó.
    /// </summary>
    /// <remarks>
    /// Se arma desde el cache, sin ir a la base. Formato de fecha fijo y sin separadores para que no
    /// dependa del idioma de la sesión: el sello tiene que poder compararse entre instalaciones.
    /// </remarks>
    local procedure DescribirDistribucion(CodConcepto: Code[20]): Text[250]
    var
        AccumCodes: List of [Text];
        AccumCode: Text;
        AccumKey: Text;
        Sello: TextBuilder;
    begin
        if not FFracAccumList.ContainsKey(CodConcepto) then
            exit('');
        AccumCodes := FFracAccumList.Get(CodConcepto).Split('|');
        foreach AccumCode in AccumCodes do begin
            AccumKey := CodConcepto + '~' + AccumCode;
            if FFracAccumVig.ContainsKey(AccumKey) then begin
                if Sello.Length() > 0 then
                    Sello.Append('|');
                Sello.Append(AccumCode + ':' + Format(FFracAccumVig.Get(AccumKey), 0, '<Year4><Month,2><Day,2>'));
            end;
        end;
        exit(CopyStr(Sello.ToText(), 1, 250));
    end;

    local procedure UpdateAccumulatorsFromCache(
        CodConcepto: Code[20];
        Importe: Decimal;
        var AccumList: Dictionary of [Code[20], Text];
        var AccumPct: Dictionary of [Text, Decimal];
        var Ctx: Dictionary of [Text, Decimal])
    var
        AccumCodes: List of [Text];
        AccumCode: Text;
        AccumKey: Text;
        UpdCurrList: Text;
    begin
        if not AccumList.ContainsKey(CodConcepto) then exit;
        UpdCurrList := AccumList.Get(CodConcepto);
        if UpdCurrList = '' then exit;
        AccumCodes := UpdCurrList.Split('|');
        foreach AccumCode in AccumCodes do begin
            AccumKey := CodConcepto + '~' + AccumCode;
            if AccumPct.ContainsKey(AccumKey) and Ctx.ContainsKey(AccumCode) then
                Ctx.Set(AccumCode, Ctx.Get(AccumCode) + Importe * AccumPct.Get(AccumKey) / 100);
        end;
    end;

    local procedure UpdateTotals(var Liq: Record "Liquidación")
    var
        Lin: Record "Línea Liquidación";
    begin
        Lin.SetRange("No. Liquidación", Liq."No.");
        Lin.SetRange("Es Devengo", false);

        Lin.SetRange("Tipo Concepto", Lin."Tipo Concepto"::"Haber Remunerativo");
        Lin.CalcSums(Importe);
        Liq."Total Haberes" := Lin.Importe;

        Lin.SetRange("Tipo Concepto", Lin."Tipo Concepto"::"Haber No Remunerativo");
        Lin.CalcSums(Importe);
        Liq."Total Haberes" += Lin.Importe;

        Lin.SetRange("Tipo Concepto", Lin."Tipo Concepto"::"Descuento Empleado");
        Lin.CalcSums(Importe);
        Liq."Total Descuentos" := Lin.Importe;

        Lin.SetRange("Tipo Concepto", Lin."Tipo Concepto"::Retención);
        Lin.CalcSums(Importe);
        Liq."Total Descuentos" += Lin.Importe;

        Lin.SetRange("Tipo Concepto", Lin."Tipo Concepto"::"Seguridad Social");
        Lin.CalcSums(Importe);
        Liq."Total Descuentos" += Lin.Importe;

        Lin.SetRange("Tipo Concepto", Lin."Tipo Concepto"::"Contribución Patronal");
        Lin.CalcSums(Importe);
        Liq."Total Contribuciones" := Lin.Importe;

        Liq."Neto a Pagar" := Liq."Total Haberes" - Liq."Total Descuentos";
    end;

    local procedure CondicionOk(var Evaluador: Codeunit "Evaluador Fórmula"; var Concepto: Record "Concepto Liquidación"): Boolean
    var
        Result: Boolean;
    begin
        if Concepto.Condición.Trim() = '' then
            exit(true);
        if not Evaluador.TryEvalCondicion(Concepto.Condición, Result) then
            Error(ErrConceptoFalló, Concepto.Código, GetLastErrorText());
        exit(Result);
    end;

    /// <param name="ConservarDeducciones">
    /// Las filas Familiar y Gasto del Detalle Ganancias las escribe CalcDeduccionesGanancias, que
    /// corre UNA sola vez —al armar el contexto— y queda memoizada: las cargas de familia y los
    /// gastos deducibles son valores anuales que no dependen de los importes de la liquidación.
    /// Un borrado que las incluya las borra PARA SIEMPRE, porque nadie las vuelve a escribir. Eso
    /// dejaba a toda liquidación con grossing-up sin el desglose de deducciones —justo las que más
    /// falta hace auditar, porque el complemento absorbe cualquier error de deducción sin que se
    /// note—. Las filas Paso sí se rehacen en cada pasada de RunConceptos y hay que borrarlas.
    /// </param>
    local procedure DeleteLineas(LiqNo: Code[20]; ConservarDeducciones: Boolean)
    begin
        // Funciones separadas para que el perfilador atribuya el tiempo a cada tabla.
        // Se conserva el orden y la transacción del borrado original.
        BorrarDetalleVariables(LiqNo);
        BorrarResumenVariables(LiqNo);
        BorrarDetalleGanancias(LiqNo, ConservarDeducciones);
        BorrarLineasLiquidacion(LiqNo);
    end;

    local procedure BorrarDetalleVariables(LiqNo: Code[20])
    var
        Det: Record "Detalle Variable Línea Liq.";
    begin
        Det.SetRange("No. Liquidación", LiqNo);
        Det.DeleteAll();
    end;

    local procedure BorrarResumenVariables(LiqNo: Code[20])
    var
        Resumen: Record "Resumen Variable Liq.";
    begin
        Resumen.SetRange("No. Liquidación", LiqNo);
        Resumen.DeleteAll();
    end;

    local procedure BorrarDetalleGanancias(LiqNo: Code[20]; ConservarDeducciones: Boolean)
    var
        DetGan: Record "Detalle Ganancias Liq.";
    begin
        DetGan.SetRange("No. Liquidación", LiqNo);
        if ConservarDeducciones then
            DetGan.SetRange(Tipo, DetGan.Tipo::Paso);
        DetGan.DeleteAll();
    end;

    local procedure BorrarLineasLiquidacion(LiqNo: Code[20])
    var
        Lin: Record "Línea Liquidación";
    begin
        Lin.SetRange("No. Liquidación", LiqNo);
        // DeleteAll(false) a propósito: el OnDelete de "Línea Liquidación" solo borra los
        // Detalle Variable de la línea, y BorrarDetalleVariables ya los borró TODOS de una
        // sola vez para esta liquidación. Con DeleteAll(true) se pagaba un DeleteAll extra
        // por línea, y eso se multiplica por cada iteración de Grossing Up.
        // Si algún día el OnDelete hace algo más que borrar detalles, esto tiene que volver
        // a ser DeleteAll(true).
        Lin.DeleteAll(false);
    end;

    /// <summary>
    /// Resuelve "Variable Cantidad" y "Variable Base": un nombre de variable, o una expresión.
    /// </summary>
    /// <remarks>
    /// El camino rápido es el de siempre: si el texto ES una clave del contexto, se lee y listo. Solo
    /// cuando no lo es se lo trata como fórmula. Así el caso normal —un nombre— no paga nada, y el
    /// nuevo —PCT_ANTIG_SOMU*100, o BASICO/30*DIAS_MAREA— funciona sin obligar a inventar un concepto
    /// auxiliar cuya única razón de existir era ponerle nombre a una cuenta de dos términos.
    ///
    /// Se evalúa con un evaluador APARTE y no con el del concepto en curso: ése lleva el log de
    /// variables usadas y la memo de las referencias @, y meterle una expresión de presentación en el
    /// medio ensuciaría la auditoría de la línea con variables que el importe nunca usó.
    ///
    /// En modo tolerante, a propósito: cantidad y base son lo que MUESTRA el recibo, no lo que se
    /// paga. Una expresión mal escrita ahí no puede cortar una liquidación entera; queda en cero,
    /// igual que quedaba antes un nombre inexistente. Lo que sí cambió es que ahora el error se
    /// detecta antes: los dos campos validan su sintaxis al cargarlos.
    /// </remarks>
    local procedure ResolverExpresionLinea(Texto: Text; var Ctx: Dictionary of [Text, Decimal]; FechaRef: Date; var Evaluador: Codeunit "Evaluador Fórmula"): Decimal
    var
        Eval: Codeunit "Evaluador Fórmula";
        Codigos: Dictionary of [Text, Text];
        Valor: Decimal;
    begin
        if Texto = '' then
            exit(0);
        if Ctx.ContainsKey(Texto) then
            exit(Ctx.Get(Texto));
        Eval.Init(Ctx, FechaRef);
        Evaluador.GetCodigosAtributos(Codigos);
        Eval.SetCodigosAtributos(Codigos);
        Eval.SetLenientMode(true);
        if not Eval.TryEvalFormula(Texto, Valor) then
            exit(0);
        exit(Valor);
    end;

    internal procedure WriteVariableDetail(
        LiqNo: Code[20];
        LineNo: Integer;
        ConceptLog: Text;
        var Ctx: Dictionary of [Text, Decimal];
        var Evaluador: Codeunit "Evaluador Fórmula")
    var
        Det: Record "Detalle Variable Línea Liq." temporary;
        DetPersistido: Record "Detalle Variable Línea Liq.";
        Entries: List of [Text];
        Entry: Text;
        VarName: Text;
        CtxKey: Text;
        Valor: Decimal;
        Tramos: Dictionary of [Text, Boolean];
        CodigosGuardados: Dictionary of [Text, Text];
        CodigoGuardado: Text;
    begin
        if ConceptLog = '' then exit;
        Evaluador.GetCodigosAtributos(CodigosGuardados);
        Entries := ConceptLog.Split('|');
        foreach Entry in Entries do begin
            if Entry.StartsWith('TRAMO:') then
                WriteTramoDetail(LiqNo, LineNo, Entry, Tramos, Det);
            if Entry.StartsWith('VAR:') then begin
                VarName := CopyStr(Entry, 5);
                // @CÓDIGO y #CÓDIGO no viven en Ctx bajo su nombre con prefijo — el prefijo solo
                // distingue el LOG ("se usó @2403"/"se usó #2403"); el valor real está en Ctx bajo
                // el código pelado. Se muestra el nombre CON prefijo para que quede claro cuál de
                // los dos mecanismos se usó.
                CtxKey := VarName;
                if CtxKey.StartsWith('@') or CtxKey.StartsWith('#') then
                    CtxKey := CopyStr(CtxKey, 2);

                // De dónde sale el valor, en orden:
                //
                //   1. El contexto, que es donde vive todo lo normal —parámetros, fuentes de datos,
                //      variables de sistema— y también el importe de un concepto YA calculado, que
                //      es lo que lee #CÓDIGO.
                //   2. La memo del evaluador, para @CÓDIGO. Un @ no lee un importe calculado: evalúa
                //      el otro concepto en el momento, así que su resultado no está en el contexto
                //      salvo que ese concepto además haya generado su propia línea. Y muchas veces
                //      no la genera —2499 aplica solo a Cierre de Marea, pero 2003 lo referencia
                //      igual—, con lo cual la fila del concepto no se escribía y en la vista
                //      aparecían sus variables internas sin ninguna que dijera cuánto dio.
                //
                // Y si no está en ninguna de las dos, la fila se escribe igual con cero. Antes se
                // salteaba: la variable desaparecía de la auditoría sin dejar rastro, que es
                // justamente lo que uno va a buscar cuando un importe no cierra. Un cero visible
                // dice algo —el concepto referenciado no aplicó—; una fila ausente no dice nada.
                Valor := 0;
                if Ctx.ContainsKey(CtxKey) then
                    Valor := Ctx.Get(CtxKey)
                else
                    if VarName.StartsWith('@') then
                        if not Evaluador.TryGetConceptoRefValue(CtxKey, Valor) then
                            Valor := 0;

                if VarName <> '' then begin
                    Det.Init();
                    Det."No. Liquidación" := LiqNo;
                    Det."No. Línea" := LineNo;
                    Det."Nombre Variable" := CopyStr(VarName, 1, MaxStrLen(Det."Nombre Variable"));
                    Det.Valor := Valor;
                    if CodigosGuardados.Get(VarName, CodigoGuardado) then
                        Det."Código Atributo" := CopyStr(CodigoGuardado, 1, MaxStrLen(Det."Código Atributo"));
                    if Det.Insert() then;
                end;
            end;
        end;
        // Resolver colisiones en memoria conserva la primera variable y los sufijos TRAMO.
        // No consumir el retorno del Insert SQL permite al runtime agrupar las escrituras.
        if Det.FindSet() then
            repeat
                DetPersistido := Det;
                DetPersistido.Insert();
            until Det.Next() = 0;
    end;

    /// <summary>
    /// Escribe una consulta TRAMO como una fila más del detalle de variables de la línea.
    /// </summary>
    /// <remarks>
    /// TRAMO es la única parte de una fórmula cuyo resultado no se veía en ningún lado: la fórmula
    /// evaluada muestra la llamada con su base pero no lo que devolvió, así que un importe de
    /// ganancias o de un tope escalonado había que rehacerlo a mano contra la tabla para saber si
    /// estaba bien. La fila lleva el valor devuelto y, en Detalle, en qué tramo cayó.
    ///
    /// El nombre repetido se desambigua con un sufijo: la misma tabla se consulta más de una vez en
    /// una línea con bases distintas —la anualizada y la del mes—, y con un solo nombre el segundo
    /// Insert fallaba en silencio y esa consulta desaparecía. La entrada IDÉNTICA, en cambio, se
    /// saltea: es la misma consulta resuelta dos veces, no dos consultas.
    /// </remarks>
    local procedure WriteTramoDetail(LiqNo: Code[20]; LineNo: Integer; Entry: Text; var Tramos: Dictionary of [Text, Boolean]; var Det: Record "Detalle Variable Línea Liq." temporary)
    var
        Campos: List of [Text];
        Nombre: Text;
        Valor: Decimal;
        Intento: Integer;
    begin
        if Tramos.ContainsKey(Entry) then
            exit;
        Tramos.Add(Entry, true);

        Campos := CopyStr(Entry, StrLen('TRAMO:') + 1).Split('~');
        if Campos.Count < 3 then
            exit;
        if not Evaluate(Valor, Campos.Get(2), 9) then
            exit;

        Nombre := StrSubstNo(TxtTramoVar, Campos.Get(1));
        Det.Init();
        Det."No. Liquidación" := LiqNo;
        Det."No. Línea" := LineNo;
        Det."Nombre Variable" := CopyStr(Nombre, 1, MaxStrLen(Det."Nombre Variable"));
        Det.Valor := Valor;
        Det.Detalle := CopyStr(Campos.Get(3), 1, MaxStrLen(Det.Detalle));
        if Campos.Count() >= 8 then begin
            Det."Tabla Tramo" := CopyStr(Campos.Get(1), 1, MaxStrLen(Det."Tabla Tramo"));
            Det."Snapshot Tramo" :=
                Evaluate(Det."Base Tramo", Campos.Get(4), 9) and
                Evaluate(Det."Límite Tramo", Campos.Get(5), 9) and
                Evaluate(Det."Fijo Tramo", Campos.Get(6), 9) and
                Evaluate(Det."Porcentaje Tramo", Campos.Get(7), 9) and
                Evaluate(Det."Vigencia Tramo", Campos.Get(8), 9);
        end;
        while not Det.Insert() do begin
            Intento += 1;
            if Intento > 9 then
                exit;
            Det."Nombre Variable" := CopyStr(Nombre + ' #' + Format(Intento + 1), 1, MaxStrLen(Det."Nombre Variable"));
        end;
    end;

    // Replaces each identifier token in Formula with its current value from Ctx.
    // Function names (MAX, MIN, etc.) and keywords are kept verbatim.
    // Numbers, operators, and parentheses pass through unchanged.
    local procedure BuildFormulaEvaluada(Formula: Text; var Ctx: Dictionary of [Text, Decimal]; var Evaluador: Codeunit "Evaluador Fórmula"): Text
    var
        Result: Text;
        Pos: Integer;
        Len: Integer;
        C: Char;
        Start: Integer;
        Token: Text;
        CachedVal: Decimal;
        Codigos: Dictionary of [Text, Text];
        Codigo: Text;
        Resto: Text;
    begin
        Evaluador.GetCodigosAtributos(Codigos);
        Formula := Formula.ToUpper().Trim();
        Len := StrLen(Formula);
        Pos := 1;
        while Pos <= Len do begin
            C := Formula[Pos];
            if C = 39 then begin
                Start := Pos;
                Pos += 1;
                while Pos <= Len do begin
                    if Formula[Pos] = 39 then begin
                        if (CopyStr(Formula, Pos, 2) = '''''') then
                            Pos += 1
                        else
                            break;
                    end;
                    Pos += 1;
                end;
                Pos += 1;
                Result += CopyStr(Formula, Start, Pos - Start);
            end else if IsIdentStartChar(C) then begin
                Start := Pos;
                // '@' y '#' no cumplen IsIdentChar (solo IsIdentStartChar) — hay que avanzar Pos
                // más allá del prefijo ANTES del while de abajo, o su condición falla en la
                // primera vuelta, Pos nunca avanza, Token queda vacío, y el while de afuera repite
                // sobre el mismo carácter para siempre (loop infinito real, no de performance).
                if (C = '@') or (C = '#') then
                    Pos += 1;
                while (Pos <= Len) and IsIdentChar(Formula[Pos]) do
                    Pos += 1;
                Token := CopyStr(Formula, Start, Pos - Start);
                Resto := CopyStr(Formula, Pos).Trim();
                if Resto.StartsWith('<>') then
                    Resto := CopyStr(Resto, 3).Trim()
                else if Resto.StartsWith('=') then
                    Resto := CopyStr(Resto, 2).Trim();
                if Resto.StartsWith('''') and Codigos.Get(Token, Codigo) then
                    Result += '''' + Codigo.Replace('''', '''''') + ''''
                else if Token.StartsWith('@') then
                    // @CÓDIGO no vive en Ctx — se resuelve evaluando el concepto referenciado,
                    // igual que hace el motor de fórmulas, para mostrar el valor real en vez
                    // de dejar el texto "@2498" sin expandir. Se reutiliza el valor que el
                    // motor ya calculó durante la evaluación real (misma corrida) para evitar
                    // recalcular la fórmula referenciada desde cero.
                    if Evaluador.TryGetConceptoRefValue(CopyStr(Token, 2), CachedVal) then
                        Result += FormatVarValue(CachedVal)
                    else
                        Result += FormatVarValue(Evaluador.ResolveConceptoRefPublic(CopyStr(Token, 2)))
                else if Token.StartsWith('#') then
                    // #CÓDIGO lee Ctx[CÓDIGO] directamente (RunConceptos lo dejó ahí si ese
                    // concepto ya corrió en esta liquidación); 0 si todavía no, igual que en la
                    // evaluación real.
                    if Ctx.ContainsKey(CopyStr(Token, 2)) then
                        Result += FormatVarValue(Ctx.Get(CopyStr(Token, 2)))
                    else
                        Result += FormatVarValue(0)
                else if not IsFormulaKeyword(Token) and Ctx.ContainsKey(Token) then
                    if IsPercentageVariable(Token) then
                        Result += FormatPercentValue(Ctx.Get(Token))
                    else
                        Result += FormatVarValue(Ctx.Get(Token))
                else
                    Result += Token;
            end else begin
                Result += CopyStr(Formula, Pos, 1);
                Pos += 1;
            end;
        end;
        exit(CopyStr(Result, 1, 500));
    end;

    // El mismo juego de caracteres que el tokenizador del evaluador (Cod50015), incluidas las letras
    // del español: si acá se cortara un identificador donde allá no, el texto de auditoría mostraría
    // una fórmula distinta de la que se calculó.
    local procedure IsIdentStartChar(C: Char): Boolean
    begin
        exit(((C >= 'A') and (C <= 'Z')) or EsLetraEspañola(C) or (C = '_') or (C = '@') or (C = '#'));
    end;

    local procedure IsIdentChar(C: Char): Boolean
    begin
        exit(((C >= 'A') and (C <= 'Z')) or ((C >= '0') and (C <= '9')) or EsLetraEspañola(C) or (C = '_'));
    end;

    local procedure EsLetraEspañola(C: Char): Boolean
    begin
        exit(C in ['Ñ', 'ñ', 'Á', 'á', 'É', 'é', 'Í', 'í', 'Ó', 'ó', 'Ú', 'ú', 'Ü', 'ü']);
    end;

    local procedure IsPercentageVariable(Token: Text): Boolean
    begin
        exit(Token.StartsWith('PCT_') or Token.Contains('_PCT') or Token.Contains('PORC'));
    end;

    local procedure IsFormulaKeyword(Token: Text): Boolean
    begin
        // Espejo del case de CallFunction (Cod50015). REDONDEAR, PISO y TECHO faltaban: existen en
        // el evaluador desde antes y acá nunca se agregaron. Hoy el efecto es inocuo —el nombre no
        // está en Ctx, así que cae en el else y se imprime tal cual— pero deja de serlo el día que
        // alguien nombre una variable igual que una función.
        exit(Token in ['MAX', 'MIN', 'ROUND', 'REDONDEAR', 'PISO', 'TECHO', 'ABS', 'IF', 'IFZERO', 'CASE', 'DIV', 'TRAMO', 'ERROR', 'AND', 'OR', 'NOT']);
    end;

    local procedure FormatVarValue(Val: Decimal): Text
    begin
        if Val = Round(Val, 1) then
            exit(Format(Val, 0, '<Sign><Integer>'))
        else
            exit(Format(Round(Val, 0.000001)));
    end;

    local procedure FormatPercentValue(Val: Decimal): Text
    begin
        // Values ≤ 1 are stored as fractions (e.g. PCT_ESCALA = 0,85 → 85%); values > 1 are already whole
        // percents (e.g. PCT_DOLAR_PROD = 78 → 78%). Avoids rendering 78 as 7800%.
        if Abs(Val) <= 1 then
            exit(Format(Round(Val * 100, 0.000001)) + '%');
        exit(Format(Round(Val, 0.000001)) + '%');
    end;

    // Audit trail: persists every context variable with a non-zero value (parámetros,
    // variables sistema, fuentes de datos, acumuladores) so it's visible in la ficha de
    // Liquidación (Acumuladores Anuales) without requiring per-variable configuration.
    // "Mostrar en Recibo" stays curated: only Fuente Datos / Variable Sistema records
    // explicitly flagged print on the PDF.
    internal procedure SaveResumenVariables(LiqNo: Code[20]; var Ctx: Dictionary of [Text, Decimal]; var CtxBuilder: Codeunit "Contexto Liquidación")
    var
        Resumen: Record "Resumen Variable Liq." temporary;
        ResumenPersistido: Record "Resumen Variable Liq.";
        ValoresTexto: Dictionary of [Text, Text];
        VarName: Text;
        Valor: Decimal;
        Texto: Text;
        MostrarEnRecibo: Boolean;
    begin
        CtxBuilder.GetValoresTexto(ValoresTexto);
        foreach VarName in Ctx.Keys() do begin
            Valor := Ctx.Get(VarName);
            Texto := '';
            if ValoresTexto.ContainsKey(VarName) then
                Texto := ValoresTexto.Get(VarName);

            // La condición mira el texto además del número. Una fuente de tipo Texto o Fecha puede
            // proyectar legítimamente a 0 —una fecha que cae justo en la fecha de referencia, por
            // ejemplo— y con la condición vieja se perdía del resumen y del recibo justo el valor
            // que interesaba mostrar.
            if ((Valor <> 0) or (Texto <> '')) and not EsConceptoNoAcumulador(VarName) then begin
                Resumen.Init();
                Resumen."No. Liquidación" := LiqNo;
                Resumen."Nombre Variable" := CopyStr(VarName, 1, MaxStrLen(Resumen."Nombre Variable"));
                Resumen.Valor := Valor;
                Resumen."Valor Texto" := CopyStr(Texto, 1, MaxStrLen(Resumen."Valor Texto"));
                Resumen.Etiqueta := CopyStr(ResolveEtiquetaResumen(VarName, MostrarEnRecibo), 1, MaxStrLen(Resumen.Etiqueta));
                Resumen."Mostrar en Recibo" := MostrarEnRecibo;
                if not Resumen.Insert() then
                    Resumen.Modify();
            end;
        end;
        // La clave Code[30] normaliza y trunca nombres: ante colisiones gana el último,
        // igual que el Insert/Modify original. DeleteLineas ya limpió el resumen anterior.
        if Resumen.FindSet() then
            repeat
                ResumenPersistido := Resumen;
                ResumenPersistido.Insert();
            until Resumen.Next() = 0;
    end;

    // Los códigos de concepto NO acumulador quedan en Ctx solo para que #CÓDIGO pueda leerlos
    // (ver RunConceptos) — ya están materializados en su propia Línea Liquidación, así que se
    // excluyen acá para no insertar una fila redundante por cada concepto calculado (multiplicaba
    // las escrituras por liquidación y era la causa real del bloqueo/lentitud reportado).
    local procedure EsConceptoNoAcumulador(VarName: Text): Boolean
    var
        CodConcepto: Code[20];
    begin
        CodConcepto := CopyStr(VarName, 1, 20);
        exit(FLatestVersionMap.ContainsKey(CodConcepto) and not FAccumCodes.Contains(CodConcepto));
    end;

    // Looks up a human-readable label for VarName across the four possible sources
    // (Fuente Datos, Variable Sistema, Parámetro, Concepto acumulador), in that priority
    // order. Falls back to the raw variable name when none match. Only Fuente Datos /
    // Variable Sistema carry a "Mostrar en Recibo" flag; everything else defaults to false.
    local procedure ResolveEtiquetaResumen(VarName: Text; var MostrarEnRecibo: Boolean): Text
    var
        FuenteDatos: Record "Fuente Datos Liquidación";
        VarSistema: Record "Variable Sistema Liq.";
        TipoAtr: Record "Tipo Atributo Liq.";
        Param: Record "Parámetro";
        Concepto: Record "Concepto Liquidación";
        NombreCode: Code[30];
    begin
        MostrarEnRecibo := false;
        NombreCode := CopyStr(VarName, 1, MaxStrLen(NombreCode));

        if FuenteDatos.Get(NombreCode) then begin
            MostrarEnRecibo := FuenteDatos."Mostrar en Recibo";
            if FuenteDatos."Etiqueta Recibo" <> '' then
                exit(FuenteDatos."Etiqueta Recibo");
            exit(FuenteDatos.Descripción);
        end;

        if VarSistema.Get(NombreCode) then begin
            MostrarEnRecibo := VarSistema."Mostrar en Recibo";
            if VarSistema."Etiqueta Recibo" <> '' then
                exit(VarSistema."Etiqueta Recibo");
            exit(VarSistema.Descripción);
        end;

        // Los atributos son la tercera fuente que puede pedir recibo. Se busca por NOMBRE DE
        // VARIABLE y no por código: son dos campos distintos y pueden diferir —TIPOEMPLEADO expone
        // TIPOEMPL—, así que un Get por la clave primaria no encontraría nada y el atributo saldría
        // en el resumen con el nombre crudo de la variable como etiqueta.
        TipoAtr.SetRange("Nombre Variable", NombreCode);
        if TipoAtr.FindFirst() then begin
            MostrarEnRecibo := TipoAtr."Mostrar en Recibo";
            if TipoAtr."Etiqueta Recibo" <> '' then
                exit(TipoAtr."Etiqueta Recibo");
            exit(TipoAtr.Descripción);
        end;

        Param.SetRange("Nombre Variable", NombreCode);
        if Param.FindFirst() then
            exit(Param.Descripción);

        // El código de concepto es Code[20] y este nombre viene de un Code[30]: filtrar con un
        // nombre más largo corta con "the length of the string is 23, but it must be less than or
        // equal to 20". Y un nombre de más de 20 no es un caso raro — cualquier parámetro cuyo
        // nombre pase de 14 caracteres lo produce solo, porque el motor le arma el compañero
        // <VAR>_ESFCY. PRECIO_PUERTO_LAN son 17, y su _ESFCY son 23.
        //
        // Se saltea en vez de recortar: un nombre de 23 no puede ser el código de un concepto de 20,
        // así que recortarlo sólo lograría encontrar OTRO concepto y devolver su descripción como
        // etiqueta de esta variable. El error era ruidoso; ése sería silencioso.
        if StrLen(NombreCode) <= MaxStrLen(Concepto.Código) then begin
            Concepto.SetRange(Código, CopyStr(NombreCode, 1, MaxStrLen(Concepto.Código)));
            Concepto.SetRange("Es Acumulador", true);
            if Concepto.FindFirst() then
                exit(Concepto.Descripción);
        end;

        exit(VarName);
    end;

    // ── Grossing Up ───────────────────────────────────────────────────────────

    local procedure InjectZonaDesfavorable(var Liq: Record "Liquidación"; FechaRef: Date; var Ctx: Dictionary of [Text, Decimal])
    var
        Job: Record Job;
        Emp: Record Employee;
        Zona: Decimal;
        EsJub: Decimal;
    begin
        // La zona sale de la CONFIGURACIÓN si alguien la definió: una Fuente de Datos (o un
        // parámetro) llamada COD_ZONA ya dejó su valor en el contexto, y acá no se pisa. Ese es el
        // camino para que la zona salga del atributo con historial —vigente a la fecha de la
        // liquidación— en vez del entero sin fecha de la ficha, sin tocar ninguna fórmula: el
        // nombre de la variable no cambia.
        //
        // La guarda no es cosmética: esta inyección corre DESPUÉS de BuildContext, así que sin ella
        // el Set sobrescribía la fuente en silencio y la configuración no tenía ningún efecto.
        //
        // Sin nada configurado, el comportamiento es el de siempre y queda como red: la zona es una
        // propiedad de la marea —toda la dotación comparte la del proyecto— y cae a la ficha del
        // empleado cuando el proyecto la deja en 0 (asignaciones que no son de marea).
        if not Ctx.ContainsKey('COD_ZONA') then begin
            if (Liq."No. Proyecto" <> '') and Job.Get(Liq."No. Proyecto") and (Job."Zona Desfavorable" > 0) then
                Zona := Job."Zona Desfavorable"
            else
                if Emp.Get(Liq."No. Empleado") then
                    Zona := Emp."Zona Desfavorable";
            Ctx.Add('COD_ZONA', Zona);
        end;

        if Emp.Get(Liq."No. Empleado") then
            if (Emp."Fecha Jubilación" <> 0D) and (Emp."Fecha Jubilación" <= FechaRef) then
                EsJub := 1;
        if Ctx.ContainsKey('ES_JUBILADO') then Ctx.Set('ES_JUBILADO', EsJub) else Ctx.Add('ES_JUBILADO', EsJub);

        // La cantidad de la incidencia del concepto que se esté calculando. Se siembra acá —en las
        // DOS fases, la de validación y la real— para que una fórmula que la use no falle con
        // "variable desconocida" antes de llegar a calcularse. RunConceptos le pone el valor de cada
        // concepto; fuera de ese bucle vale 0.
        if not Ctx.ContainsKey(VarCantIncidenciaTok) then
            Ctx.Add(VarCantIncidenciaTok, 0);
    end;

    // Siembra en cero las tres variables de grossing-up antes de RunConceptos.
    // Tienen que existir siempre —aunque no haya GU— para que la fórmula del concepto de
    // complemento (COMPLEMENTO_GU) y su condición (ES_GROSSING_UP > 0) resuelvan igual, y para que
    // el Evaluador pueda leerlas por nombre sin dar "Variable desconocida".
    //
    // El VALOR del objetivo ya no se decide acá: lo resuelve ResolverNetoGarantizado a partir del
    // concepto configurado, después de que el Evaluador esté inicializado. Antes este
    // procedimiento leía un parámetro llamado NETO_GU, y ese nombre era el único lugar desde donde
    // se podía encender el grossing-up.
    local procedure InjectGUVariables(var Ctx: Dictionary of [Text, Decimal])
    begin
        if Ctx.ContainsKey(VarEsGrossingUp()) then Ctx.Set(VarEsGrossingUp(), 0) else Ctx.Add(VarEsGrossingUp(), 0);
        if Ctx.ContainsKey(VarNetoGarantizado()) then Ctx.Set(VarNetoGarantizado(), 0) else Ctx.Add(VarNetoGarantizado(), 0);
        if Ctx.ContainsKey(VarComplementoGU()) then Ctx.Set(VarComplementoGU(), 0) else Ctx.Add(VarComplementoGU(), 0);
    end;

    /// <summary>
    /// Resuelve el neto objetivo del grossing-up evaluando la fórmula del concepto configurado en
    /// "Concepto Neto Garantizado (Grossing-up)" de Config. Recursos Humanos, y enciende
    /// ES_GROSSING_UP si dio mayor que cero.
    /// </summary>
    /// <remarks>
    /// Antes esta regla vivía en AL: el motor leía un parámetro NETO_GU y le sumaba el proporcional
    /// de vacaciones con una Fuente de Datos DIAS_VAC_INICIO y el divisor 150 —el diferencial del
    /// Art. 155 LCT entre pagar a /25 y a /30—. Eran dos nombres de configuración y una regla de
    /// negocio escritos en el código: renombrar cualquiera de los dos dejaba el objetivo mal
    /// calculado EN SILENCIO, porque el ContainsKey daba false y el cálculo seguía de largo.
    ///
    /// Ahora la fórmula vive en un concepto y hereda todo lo que el sistema ya sabe hacer con
    /// fórmulas: vigencias, historial, el editor con su catálogo, y ValidarFormulas. Y un nombre
    /// que ya no existe deja de ser un cero silencioso: el Evaluador corta con "Variable
    /// desconocida en la fórmula".
    ///
    /// El concepto tiene que ser de tipo Informativo. CalcNetoDesdeBD suma haberes, retenciones,
    /// descuentos y seguridad social; un Informativo emite su línea —auditable, con su detalle de
    /// variables, y queda registrado con qué objetivo convergió cada liquidación— sin mover el neto
    /// que el bucle está tratando de alcanzar.
    ///
    /// Su fórmula no puede referenciar COMPLEMENTO_GU: el objetivo se movería en cada iteración y
    /// el bucle no convergería. Se corta con error en vez de iterar 20 veces para nada.
    /// </remarks>
    local procedure ResolverNetoGarantizado(
        FechaRef: Date;
        var Ctx: Dictionary of [Text, Decimal];
        var Evaluador: Codeunit "Evaluador Fórmula")
    var
        HRSetup: Record "Human Resources Setup";
        Concepto: Record "Concepto Liquidación";
        NetoObjetivo: Decimal;
    begin
        if not HRSetup.Get() then
            exit;
        if HRSetup."Cód. Concepto Neto Garantizado" = '' then
            exit;

        Concepto.SetRange(Código, HRSetup."Cód. Concepto Neto Garantizado");
        Concepto.FiltrarVigentesA(FechaRef);
        if not Concepto.FindLast() then
            exit;
        if not Concepto.VigenteA(FechaRef) then
            exit;
        if Concepto.Fórmula = '' then
            exit;

        if StrPos(Concepto.Fórmula.ToUpper(), VarComplementoGU()) > 0 then
            Error(ErrNetoGarantAutorreferente, Concepto.Código);

        NetoObjetivo := Evaluador.EvalFormula(Concepto.Fórmula);
        if NetoObjetivo <= 0 then
            exit;

        Ctx.Set(VarNetoGarantizado(), NetoObjetivo);
        Ctx.Set(VarEsGrossingUp(), 1);
        Evaluador.UpdateContext(Ctx);
    end;

    /// <summary>
    /// Vuelca a la cabecera el acumulado de haberes gravados, desde el acumulador configurado en
    /// "Acumulador Haberes Gravados" de Config. Recursos Humanos.
    /// </summary>
    /// <remarks>
    /// El motor tenía BASE_IG4 escrito por nombre. Es un acumulador que define quien configura, no
    /// un nombre del motor: renombrarlo dejaba "Haberes Ordinarios Gravados" en cero y los informes
    /// de Ganancias partiendo de una base vacía, sin que nada avisara.
    /// </remarks>
    local procedure GuardarHaberesGravados(var Liq: Record "Liquidación"; var Ctx: Dictionary of [Text, Decimal])
    var
        HRSetup: Record "Human Resources Setup";
    begin
        if not HRSetup.Get() then
            exit;
        if HRSetup."Cód. Acum. Haberes Gravados" = '' then
            exit;
        if Ctx.ContainsKey(HRSetup."Cód. Acum. Haberes Gravados") then
            Liq."Haberes Ordinarios Gravados" := Ctx.Get(HRSetup."Cód. Acum. Haberes Gravados");
    end;

    // Iterative convergence loop: adjusts COMPLEMENTO_GU until Neto ≈ Neto Garantizado.
    // Each iteration adds the remaining delta to the complement (monotonic convergence).
    // At 35 % marginal rate (Argentine top bracket) delta shrinks by ~35 % per iteration;
    // 20 iterations are enough to reach $0.01 tolerance from any starting point.
    local procedure ConvergerGrossingUp(
        var Liq: Record "Liquidación";
        FechaRef: Date;
        var Ctx: Dictionary of [Text, Decimal];
        var CtxBuilder: Codeunit "Contexto Liquidación";
        var Evaluador: Codeunit "Evaluador Fórmula")
    var
        MonedaGU: Code[10];
        NetoObjetivo: Decimal;
        NetoActual: Decimal;
        Delta: Decimal;
        NuevoComplemento: Decimal;
        Iter: Integer;
        PasadasSinAuditoria: Integer;
        Convergio: Boolean;
        MejorComplemento: Decimal;
        MejorExceso: Decimal;
        HayMejor: Boolean;
        ToleranciaExceso: Decimal;
        NetoPrevio: Decimal;
        TipoCambio: Decimal;
        HRSetup: Record "Human Resources Setup";
    begin
        // El objetivo ya viene resuelto por ResolverNetoGarantizado, que evaluó la fórmula del
        // concepto configurado. Acá sólo se convierte de moneda si corresponde: el proporcional de
        // vacaciones del Art. 155 pasó a ser parte de esa fórmula.
        //
        // LA CONVERSIÓN VA POR EL VENDEDOR, igual que las fórmulas. Antes usaba ExchangeAmtFCYToLCY,
        // que es la conversión estándar de BC y toma "Relational Exch. Rate Amount" —el comprador—.
        // Un neto garantizado de USD 11.100 salía 15.706.500 en vez de 16.261.500 y arrastraba toda
        // la liquidación: sueldo, vacaciones, aportes e impuesto. No se ve como error porque el
        // grossing-up converge igual, sólo que a un neto que no es el pactado.
        //
        // Y CON "Convertir Param. por TC" ENCENDIDA NO SE CONVIERTE NADA ACÁ. El parámetro en divisa
        // —NETO_GU, NETO_GU_MAREA— ya entró al contexto convertido a pesos por su "Cód. Variable TC",
        // así que la fórmula de NETO_GARANT devuelve el objetivo en pesos y multiplicar de nuevo lo
        // llevaría al cuadrado del tipo de cambio. La bandera queda de un solo lado: o convierte el
        // contexto, o convierte el motor, nunca los dos.
        //
        // No se borra el camino viejo porque la bandera es una llave de paso: si algo sale mal en
        // producción se apaga, y entonces esta conversión tiene que volver a correr.
        NetoObjetivo := Ctx.Get(VarNetoGarantizado());
        if not HRSetup.Get() then
            Clear(HRSetup);
        MonedaGU := '';
        if not HRSetup."Convertir Param. por TC" then
            MonedaGU := CtxBuilder.GetMoneda();
        if MonedaGU <> '' then begin
            TipoCambio := TipoCambioVendedor(MonedaGU, FechaRef);
            if TipoCambio = 0 then
                Error(ErrSinCotizacionGU, Liq."No.", MonedaGU, FechaRef);
            NetoObjetivo := Round(NetoObjetivo * TipoCambio, 0.01);
        end;
        // Las iteraciones intermedias se descartan enteras en el DeleteLineas de la vuelta
        // siguiente, así que escribir su auditoría (Fórmula Evaluada, Detalle Variable, Detalle
        // Ganancias, Fuente Parámetros, En Uso) es trabajo puro de descarte. Se suprime durante la
        // convergencia y se escribe una sola vez, al final, sobre el resultado que efectivamente
        // queda. Ningún importe depende de esos datos — ver los guardas de FIteracionGU en
        // RunConceptos.
        // El escalón con el que se mide todo lo de abajo: el redondeo más grueso que puede aplicar
        // un concepto. Con PRECISION_REDONDEO en 1 el neto se mueve de a un peso, y dos netos que
        // difieren en menos que eso son el mismo neto para la liquidación.
        ToleranciaExceso := 0.01;
        if Ctx.ContainsKey('PRECISION_REDONDEO') then
            if Ctx.Get('PRECISION_REDONDEO') > ToleranciaExceso then
                ToleranciaExceso := Ctx.Get('PRECISION_REDONDEO');

        FIteracionGU := true;
        for Iter := 1 to MaxIteracionesGrossingUp() do begin
            // La señal a la ventana de progreso va acá y no solo al entrar a la liquidación: una de
            // Grossing Up rehace la lista entera de conceptos hasta el límite de iteraciones, y sin nada que se mueva
            // durante esos segundos el lote parece colgado —y colgado en el nombre anterior, que es
            // el último que la pantalla alcanzó a pintar—.
            Progreso.Paso(StrSubstNo(TxtPasoGU, Iter, MaxIteracionesGrossingUp()));
            NetoActual := CalcNetoDesdeBD(Liq."No.");
            Delta := NetoObjetivo - NetoActual;
            if NetoGarantizadoSatisfecho(NetoObjetivo, NetoActual, Ctx.Get(VarComplementoGU())) then begin
                Convergio := true;
                break;
            end;
            // Se guarda el iterado que más se acerca al garantizado SIN quedar por debajo. El neto
            // no es continuo en el complemento: con PRECISION_REDONDEO en 1 hay conceptos que
            // redondean a peso entero, así que el neto avanza a saltos y el objetivo exacto puede
            // sencillamente no ser alcanzable. Cuando eso pasa el bucle oscila entre los dos
            // escalones que rodean al objetivo y agota las vueltas por unos centavos. Ver el
            // rescate de más abajo: este candidato es el que se termina usando.
            if NetoActual >= NetoObjetivo then
                if (not HayMejor) or (NetoActual - NetoObjetivo < MejorExceso) then begin
                    HayMejor := true;
                    MejorExceso := NetoActual - NetoObjetivo;
                    MejorComplemento := Ctx.Get(VarComplementoGU());
                end;
            NuevoComplemento := Ctx.Get(VarComplementoGU()) + Delta;
            // ROMPER EL ESTANCAMIENTO. Cuando falta menos que un escalón, sumar el déficit mueve el
            // complemento pero no mueve el neto: el redondeo se come el ajuste y la vuelta siguiente
            // encuentra exactamente el mismo déficit. Así el bucle camina en el lugar y agota las
            // vueltas sin haber probado nunca un complemento del otro lado del objetivo, que es el
            // que el rescate necesita. Se empuja un escalón entero para garantizar que el neto
            // efectivamente salte; si se pasa, el rescate se queda con el salto más chico.
            if (Iter > 1) and (Delta > 0) and (NetoActual = NetoPrevio) then
                NuevoComplemento += ToleranciaExceso;
            NetoPrevio := NetoActual;
            if NuevoComplemento < 0 then NuevoComplemento := 0;
            Ctx.Set(VarComplementoGU(), NuevoComplemento);
            Evaluador.UpdateContext(Ctx);
            ResetAccumuladores(Ctx);
            DeleteLineas(Liq."No.", true);
            RunConceptos(Liq, FechaRef, Ctx, CtxBuilder, Evaluador);
            PasadasSinAuditoria += 1;
        end;
        FIteracionGU := false;

        // SALIR POR AGOTAR LAS VUELTAS NO ES HABER TERMINADO. El chequeo del bucle está arriba, así
        // que después de la última vuelta nunca se vuelve a mirar el neto: hasta acá, una liquidación que
        // no convergía se guardaba igual, con un neto que no es el garantizado y sin una sola señal.
        // Es la clase de error que se descubre cuando alguien cobra de menos.
        //
        // Se recontrola antes de acusar, porque el ajuste de la última vuelta pudo haber convergido y el
        // bucle no llegó a verlo. Ese CalcNetoDesdeBD extra sólo corre cuando no hubo break.
        //
        // Va ANTES de la pasada final auditada: si esto falla, la liquidación no se guarda, y rehacer
        // las líneas con toda su auditoría para tirarlas es trabajo puro de descarte.
        if not Convergio then begin
            NetoActual := CalcNetoDesdeBD(Liq."No.");
            Delta := NetoObjetivo - NetoActual;
            if NetoActual >= NetoObjetivo then
                if (not HayMejor) or (NetoActual - NetoObjetivo < MejorExceso) then begin
                    HayMejor := true;
                    MejorExceso := NetoActual - NetoObjetivo;
                    MejorComplemento := Ctx.Get(VarComplementoGU());
                end;
            Convergio := NetoGarantizadoSatisfecho(NetoObjetivo, NetoActual, Ctx.Get(VarComplementoGU()));
        end;

        // RESCATE POR ESCALÓN DE REDONDEO. Agotar las vueltas no siempre es un error de
        // configuración: si NINGÚN complemento produce exactamente el neto garantizado —porque el
        // neto salta de a un escalón— el bucle no puede converger por más vueltas que le demos, y
        // frenar ahí dejaba la liquidación sin calcular por dos centavos. Por eso subir el límite
        // de iteraciones no alcanza: no es que converja lento, es que el punto fijo no existe.
        //
        // El garantizado es un PISO, así que el desempate va siempre hacia arriba: se toma el
        // complemento que dejó el neto inmediatamente por encima del objetivo, nunca uno que lo
        // deje por debajo —ni siquiera por un centavo: eso sería pagar de menos un neto que está
        // garantizado—. Y se acepta sólo si el exceso entra en un escalón de redondeo; si sobra
        // más que eso, el problema no es el redondeo y el Error de abajo sigue vivo para avisarlo.
        if not Convergio then
            if HayMejor then
                if MejorExceso <= ToleranciaExceso then begin
                    Ctx.Set(VarComplementoGU(), MejorComplemento);
                    NetoActual := NetoObjetivo + MejorExceso;
                    Delta := -MejorExceso;
                    Convergio := true;
                    // El Ctx ya no es el que dejó la última iteración: la pasada final tiene que
                    // rehacer las líneas con ESTE complemento y no con aquel.
                    if PasadasSinAuditoria = 0 then
                        PasadasSinAuditoria := 1;
                end;

        if not Convergio then
            Error(ErrGUNoConverge, Liq."No.", NetoObjetivo, NetoActual, Delta, MaxIteracionesGrossingUp());

        // Pasada final: mismo Ctx (COMPLEMENTO_GU ya convergido) y mismo estado de base que la
        // última iteración, así que reconstruye líneas idénticas — esta vez con la auditoría
        // completa. Si convergió en el primer chequeo no corrió ninguna iteración y las líneas
        // originales de LiquidarRecord ya están auditadas: no hace falta.
        //
        // Cuesta una pasada extra frente al esquema anterior. Con 1 sola iteración es un empate
        // o una pérdida chica; con 2+ (el caso normal, la convergencia tarda ~5-8 vueltas) gana
        // claro, porque cada iteración intermedia deja de insertar una fila de Detalle Variable
        // por variable y por línea.
        if PasadasSinAuditoria > 0 then begin
            Progreso.Paso(TxtPasoGUFinal);
            Evaluador.UpdateContext(Ctx);
            ResetAccumuladores(Ctx);
            DeleteLineas(Liq."No.", true);
            RunConceptos(Liq, FechaRef, Ctx, CtxBuilder, Evaluador);
        end;
    end;

    // El garantizado es un piso: se acepta un neto superior sin complemento.
    // Con complemento positivo se exige convergencia para no conservar un exceso del ajuste.
    /// <summary>
    /// La cotización con la que se liquida: el tipo de cambio VENDEDOR a la fecha, en la orientación
    /// en que se lee ("cuántos pesos vale un dólar").
    /// </summary>
    /// <remarks>
    /// Las dos cotizaciones del día conviven en la misma fila de Currency Exchange Rate: el comprador
    /// en "Relational Exch. Rate Amount" y el vendedor en "Relational Adjmt Exch Rate Amt" —que es el
    /// campo de ajuste de BC, acá reutilizado como segunda cotización—. La Fuente de Datos
    /// TC_VENDEDOR apunta a ese mismo campo, así que el motor y las fórmulas leen lo mismo.
    ///
    /// No se usa ExchangeAmtFCYToLCY ni ExchangeRate: ambos resuelven contra el comprador y no hay
    /// forma de pedirles el otro. El precio de no usarlos es no resolver cadenas de moneda relacional
    /// —que acá no existen: todas las cotizaciones son contra la moneda local—.
    /// </remarks>
    internal procedure TipoCambioVendedor(Moneda: Code[10]; Fecha: Date): Decimal
    var
        CurrExchRate: Record "Currency Exchange Rate";
    begin
        if Moneda = '' then
            exit(1);
        CurrExchRate.SetRange("Currency Code", Moneda);
        CurrExchRate.SetRange("Starting Date", 0D, Fecha);
        if not CurrExchRate.FindLast() then
            exit(0);
        // El divisor casi siempre es 1, pero es parte de la cotización: "USD 100 = 145.000" se carga
        // con 100 en el importe de ajuste. Ignorarlo daría la cotización multiplicada por 100.
        if CurrExchRate."Adjustment Exch. Rate Amount" = 0 then
            exit(0);
        exit(CurrExchRate."Relational Adjmt Exch Rate Amt" / CurrExchRate."Adjustment Exch. Rate Amount");
    end;

    /// <summary>
    /// Lee de Config. RRHH los tres nombres de variable del grossing-up y sus dos constantes.
    /// </summary>
    /// <remarks>
    /// EN BLANCO SIGNIFICA EL VALOR DE SIEMPRE, y por eso el default se asigna antes de mirar la
    /// configuración: sin tocar nada, el motor se comporta igual que cuando estos cinco valores
    /// estaban a fuego. Un cero en los numéricos se trata como blanco — cero iteraciones no
    /// convergería nunca y tolerancia cero no cerraría jamás, así que no son configuraciones
    /// válidas sino el campo sin cargar.
    /// </remarks>
    local procedure CargarConfigGU()
    var
        HRSetup: Record "Human Resources Setup";
    begin
        if FGUConfigCargada then
            exit;
        FGUConfigCargada := true;

        // Los únicos tres literales que quedan en el motor, y tienen que seguir siendo literales:
        // son el default, no una lectura. Un buscar-y-reemplazar sobre los nombres los convirtió
        // una vez en llamadas a los accesores de más abajo, que devolvían vacío porque la bandera
        // ya estaba en true. No los toques.
        FGUVarEs := 'ES_GROSSING_UP';
        FGUVarNeto := 'NETO_GARANTIZADO';
        FGUVarComp := 'COMPLEMENTO_GU';
        FGUMaxIter := 20;
        FGUTolerancia := 1;

        if not HRSetup.Get() then
            exit;
        if HRSetup."Cód. Var. Es Grossing-Up" <> '' then
            FGUVarEs := HRSetup."Cód. Var. Es Grossing-Up";
        if HRSetup."Cód. Var. Neto Garantizado" <> '' then
            FGUVarNeto := HRSetup."Cód. Var. Neto Garantizado";
        if HRSetup."Cód. Var. Complemento GU" <> '' then
            FGUVarComp := HRSetup."Cód. Var. Complemento GU";
        if HRSetup."Máx. Iter. Grossing-Up" > 0 then
            FGUMaxIter := HRSetup."Máx. Iter. Grossing-Up";
        if HRSetup."Tolerancia Grossing-Up" > 0 then
            FGUTolerancia := HRSetup."Tolerancia Grossing-Up";
    end;

    internal procedure VarEsGrossingUp(): Code[60]
    begin
        CargarConfigGU();
        exit(FGUVarEs);
    end;

    internal procedure VarNetoGarantizado(): Code[60]
    begin
        CargarConfigGU();
        exit(FGUVarNeto);
    end;

    internal procedure VarComplementoGU(): Code[60]
    begin
        CargarConfigGU();
        exit(FGUVarComp);
    end;

    internal procedure MaxIteracionesGrossingUp(): Integer
    begin
        CargarConfigGU();
        exit(FGUMaxIter);
    end;

    internal procedure ToleranciaGrossingUp(): Decimal
    begin
        CargarConfigGU();
        exit(FGUTolerancia);
    end;

    internal procedure NetoGarantizadoSatisfecho(NetoObjetivo: Decimal; NetoActual: Decimal; Complemento: Decimal): Boolean
    begin
        // Tolerancia absoluta, inclusive, sobre el neto calculado. La segunda condición es el caso
        // de borde donde no hay nada que ajustar: con el complemento en cero y el neto YA por
        // encima del objetivo, iterar sólo lo alejaría.
        exit((Abs(NetoObjetivo - NetoActual) <= ToleranciaGrossingUp()) or
             ((Complemento = 0) and (NetoActual > NetoObjetivo)));
    end;

    // Computes the current neto from the already-written Línea Liquidación rows.
    local procedure CalcNetoDesdeBD(LiqNo: Code[20]): Decimal
    var
        Lin: Record "Línea Liquidación";
        HRSetup: Record "Human Resources Setup";
        TotalHaberes: Decimal;
        TotalDesc: Decimal;
        Excluido: Decimal;
        DevHaberes: Decimal;
        DevDesc: Decimal;
    begin
        Lin.SetRange("No. Liquidación", LiqNo);
        Lin.SetRange("Es Devengo", false);

        Lin.SetFilter("Tipo Concepto", '%1|%2',
            Lin."Tipo Concepto"::"Haber Remunerativo",
            Lin."Tipo Concepto"::"Haber No Remunerativo");
        Lin.CalcSums(Importe);
        TotalHaberes := Lin.Importe;

        Lin.SetFilter("Tipo Concepto", '%1|%2|%3',
            Lin."Tipo Concepto"::Retención,
            Lin."Tipo Concepto"::"Descuento Empleado",
            Lin."Tipo Concepto"::"Seguridad Social");
        Lin.CalcSums(Importe);
        TotalDesc := Lin.Importe;

        // SE DEVUELVE AL NETO lo que el acumulador configurado junta. Son descuentos que ya se
        // restaron arriba pero que NO deben pesar en la convergencia: el anticipo de llegada es
        // plata ya entregada, no algo que se deje de ganar, así que compensarlo con más bruto
        // termina pagando dos veces. Ver el campo en Config. RRHH.
        //
        // La línea del acumulador es de Tipo Concepto 6 --como todas las de acumulador--, así que
        // no entró en ninguna de las dos sumas de arriba y sumarla acá no duplica nada.
        if HRSetup.Get() then
            if HRSetup."Cód. Acum. Excl. Neto GU" <> '' then begin
                Lin.SetRange("Tipo Concepto");
                Lin.SetRange("Cód. Concepto", HRSetup."Cód. Acum. Excl. Neto GU");
                Lin.CalcSums(Importe);
                Excluido := Lin.Importe;
            end;

        exit(TotalHaberes - TotalDesc + Excluido);
    end;

    // Resets all accumulator concepts in Ctx to 0 before a GU re-run. Also resets every OTHER
    // concept's own code (seeded there so #CÓDIGO can read it — see RunConceptos) since GU
    // convergence re-runs RunConceptos from scratch each iteration; without this, a #CÓDIGO read
    // early in iteration 2+ could see a stale Importe left over from iteration 1, before that
    // concept's line is rebuilt in the current pass. Uses the caches from EnsureConceptCaches to
    // avoid a table scan per iteration.
    local procedure ResetAccumuladores(var Ctx: Dictionary of [Text, Decimal])
    var
        ConceptCode: Code[20];
    begin
        foreach ConceptCode in FLatestVersionMap.Keys() do
            if Ctx.ContainsKey(ConceptCode) then
                Ctx.Set(ConceptCode, 0);
    end;

    var
        // Concept-level caches memoized per FechaRef. Both maps are pure functions of
        // FechaRef and the Concepto/Fracción table state, so they stay valid across every
        // GU convergence iteration AND across every employee in a same-period batch
        // (CalcularPorPeriodo reuses one Motor instance). Rebuilt only when FechaRef changes.
        FIncidencias: Record "Incidencia Liquidación" temporary;
        FCCTAplicabilidad: Dictionary of [Text, Boolean];
        FParPuestoCargado: Boolean;
        FParPuestoExiste: Boolean;
        FConvenioPuesto: Code[20];
        FCategoriaPuesto: Code[20];
        FConceptCacheLoaded: Boolean;
        FConceptCacheFecha: Date;
        FLatestVersionMap: Dictionary of [Code[20], Date];
        // La última versión de cada concepto a la fecha, INCLUIDAS las discontinuadas. Solo la usa el
        // bucle para las incidencias; nada más debe resolver por acá.
        FUltimaVersionMap: Dictionary of [Code[20], Date];
        FFracAccumList: Dictionary of [Code[20], Text];
        FFracAccumPct: Dictionary of [Text, Decimal];
        FFracAccumVig: Dictionary of [Text, Date];
        FAccumCodes: List of [Code[20]];
        // Control de orden de cálculo: primera lectura de cada acumulador en la pasada actual.
        FAcumLeidoEnOrden: Dictionary of [Text, Integer];
        FAcumLeidoPorConcepto: Dictionary of [Text, Code[20]];
        FAcumAporteTardioOrden: Dictionary of [Text, Integer];
        FAcumAporteTardioCodigo: Dictionary of [Text, Code[20]];
        FAcumAportesTardios: Dictionary of [Text, Integer];
        FAvisosOrden: Text;
        AvisoOrdenTxt: Label 'Orden de cálculo: %2 lee %1 en el orden %3, pero %1 todavía recibe %4 aporte(s) más tarde (el último es %5, en el orden %6). El importe de %2 quedó calculado sobre un acumulador incompleto. Corré el Control de Orden de Cálculo para ver la lista completa.';
        // Versión corta para el registro: el acumulador y el concepto que lee van en sus columnas.
        AvisoOrdenCortoTxt: Label 'Leído en el orden %1, pero recibe %2 aporte(s) más tarde (el último, %3, en el orden %4). Quedó calculado sobre un acumulador incompleto.';
        ErrEstadoInvalido: Label 'No se puede recalcular una liquidación contabilizada.';
        ErrOrdenCronologico: Label 'No se puede calcular %1 (período %2) porque el empleado ya tiene líquidado el período %4 en la liquidación %3, del %5.\\El cálculo mira hacia atrás: francos, acumuladores anuales y Ganancias leen todo lo que ya esté liquidado, sin importar la fecha. Si se recalcula este período con los posteriores hechos, sale un número distinto del que habría dado en su momento.\\Usá "Recalcular en cadena" para rehacer éste y todos los posteriores en orden.', Comment = '%1=liq actual, %2=período actual, %3=liq posterior, %4=período posterior, %5=fecha';
        Progreso: Codeunit "Progreso Liq.";
        TxtTramoVar: Label 'TRAMO(%1)', Locked = true;
        TxtPasoConceptos: Label 'Calculando conceptos...';
        RegIncidSinLineaTxt: Label 'Se cargó una cantidad de %2 en el concepto %1 pero el concepto no generó línea: no aplica a esta liquidación (convenio, tipo de liquidación o condición) o no tiene fórmula. Esa cantidad NO se pagó.', Comment = '%1=código de concepto, %2=cantidad cargada';
        VarCantIncidenciaTok: Label 'CANT_INCIDENCIA', Locked = true;
        TxtPasoGU: Label 'Grossing Up: iteración %1 de %2', Comment = '%1=número de iteración, %2=límite';
        TxtPasoGUFinal: Label 'Grossing Up: pasada final con auditoría';
        ErrPeriodoCerrado: Label 'El período %1 está cerrado. No se puede reliquidar.';
        ErrConceptoFalló: Label 'Error al calcular el concepto %1: %2';
        ErrGUNoConverge: Label 'El grossing-up de %1 no convergió en %5 iteraciones. Neto garantizado: %2; calculado: %3; diferencia: %4. No se guardó la liquidación. Revisá la fórmula del neto garantizado y los descuentos sobre el complemento.', Comment = '%1=No. liquidación, %2=neto objetivo, %3=neto alcanzado, %4=diferencia, %5=límite';
        ErrSinCotizacionGU: Label 'El neto garantizado de %1 está en %2 y no hay cotización de %2 al %3.\\Sin cotización el objetivo del grossing-up no se puede pasar a pesos, y calcular con cero pagaría un neto de cero. Cargá la cotización —con el vendedor en el importe de ajuste— y volvé a calcular.', Comment = '%1=No. liquidación, %2=moneda, %3=fecha';
        ErrNetoGarantAutorreferente: Label 'El concepto %1 está configurado como Neto Garantizado del grossing-up, pero su fórmula referencia COMPLEMENTO_GU.\\El objetivo del grossing-up tiene que ser fijo: si depende del complemento, se mueve en cada iteración y el cálculo no cierra nunca.\\Quitá COMPLEMENTO_GU de la fórmula, o elegí otro concepto en Config. Recursos Humanos.', Comment = '%1 = código de concepto';
        ErrFormulasInvalidas: Label 'Las siguientes fórmulas contienen errores. Corrija antes de calcular:\%1';
        ErrSinAsignacionProyecto: Label 'El empleado %1 no está asignado al proyecto %2. Asígnelo en Personal Proyecto antes de liquidar.';
        ErrConsumoMayorQueSaldo: Label 'El concepto %1 pide consumir %2 días de franco y el empleado %4 tiene %3.\\La fórmula de un concepto de consumo de francos devuelve DÍAS, no importe: el precio lo pone el motor, tomando el valor del franco de la categoría de cada lote. Si la fórmula multiplica por VALOR_FRANCO, el resultado en pesos entra acá como cantidad de días y se termina pagando todo el saldo.\\Fórmula actual: %5', Comment = '%1=concepto; %2=días pedidos; %3=saldo disponible; %4=legajo; %5=fórmula';
        FAdvertencias: Text;
        // true mientras ConvergerGrossingUp está iterando: RunConceptos saltea todo el trabajo de
        // auditoría/presentación, que se descarta en el DeleteLineas de la iteración siguiente.
        // Ver ConvergerGrossingUp para la pasada final que sí lo escribe.
        FIteracionGU: Boolean;
        // Configuración del grossing-up, leída una vez por corrida. Los accesores la piden a
        // CargarConfigGU, que es idempotente: el bucle de convergencia toca estos nombres hasta
        // veinte veces por liquidación y no tiene sentido volver a Config. RRHH cada vez.
        FGUConfigCargada: Boolean;
        FGUVarEs: Code[60];
        FGUVarNeto: Code[60];
        FGUVarComp: Code[60];
        FGUMaxIter: Integer;
        FGUTolerancia: Decimal;
        GestionPrestamos: Codeunit "Gestión Préstamos";
        GestionNovedades: Codeunit "Gestión Novedades Liq.";
        Registro: Codeunit "Registro Procesos Liq.";
        RegCalculadaTxt: Label 'Liquidación calculada (%1, período %2).';
}
