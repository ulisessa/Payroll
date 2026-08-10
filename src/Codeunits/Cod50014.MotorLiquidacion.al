namespace UAS.Payroll;

using Microsoft.Finance.Currency;
using Microsoft.HumanResources.Employee;
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

    procedure LiquidarRecord(var Liq: Record "Liquidación")
    var
        Periodo: Record "Período Liquidación";
        Job: Record Job;
        PersProy: Record "Personal Proyecto";
        TipoLiqRec: Record "Tipo Liquidación";
        EstadoMgt: Codeunit "Gestión Estado Empleado";
        CtxBuilder: Codeunit "Contexto Liquidación";
        Evaluador: Codeunit "Evaluador Fórmula";
        ValidationCtx: Dictionary of [Text, Decimal];
        Ctx: Dictionary of [Text, Decimal];
        FechaRef: Date;
    begin
        // CalcularPorPeriodo reutiliza una sola instancia del motor para todo el lote: si una
        // liquidación anterior falló dentro de ConvergerGrossingUp, el flag podría quedar activo
        // y la siguiente se calcularía sin auditoría. Arranca siempre limpio.
        FIteracionGU := false;

        if Liq.Estado = Liq.Estado::Contabilizada then
            Error(ErrEstadoInvalido);

        Periodo.Get(Liq."Cód. Período");
        if Periodo.Estado = Periodo.Estado::Cerrado then
            Error(ErrPeriodoCerrado);

        // Re-sync the employee-derived snapshot from the current project assignment so that
        // recalculating an existing liquidation reflects convenio/categoría changes exactly as
        // recreating it would. Only for project-based liquidations (mareas, etc.).
        if (Liq."No. Proyecto" <> '') and PersProy.Get(Liq."No. Empleado", Liq."No. Proyecto") then begin
            Liq."Cód. Convenio" := PersProy."Cód. Convenio";
            Liq."Cód. Categoría" := PersProy."Cód. Categoría";
        end;

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

        // If the employee is enjoying francos and the balance runs out within this period, materialize the
        // transition to the next state (Francos → Órdenes) before reading states, so DIAS_FRANCOS_PERIODO
        // counts only the covered days and the rest falls into the next state.
        EstadoMgt.AjustarEstadoFrancos(Liq."No. Empleado", FechaRef);

        EstadoMgt.ValidarEstadoExiste(Liq."No. Empleado", FechaRef);
        ValidarAsignacionProyecto(Liq."No. Empleado", Liq."No. Proyecto");

        // Phase 1: validate all formulas with a dry-run context (LiqNo = '' prevents DB writes).
        // Any formula error is reported here before data is touched.
        CtxBuilder.Init(
            Liq."No. Empleado", Liq."No. Proyecto", Liq."Cód. Período",
            FechaRef, Liq."Cód. Convenio", Liq."Cód. Categoría",
            '', Liq."Cód. Tipo Liq.");
        CtxBuilder.BuildContext(ValidationCtx);
        InjectGUVariables(ValidationCtx);
        InjectZonaDesfavorable(Liq, FechaRef, ValidationCtx);
        Evaluador.Init(ValidationCtx, FechaRef);
        ValidarFormulas(Liq, FechaRef, ValidationCtx, Evaluador);

        // Phase 2: full calculation — only reached if Phase 1 passes.
        CtxBuilder.Init(
            Liq."No. Empleado", Liq."No. Proyecto", Liq."Cód. Período",
            FechaRef, Liq."Cód. Convenio", Liq."Cód. Categoría",
            Liq."No.", Liq."Cód. Tipo Liq.");
        // AplicarCuotasEnLiquidacion solo actúa si el estado es Borrador — pero un recálculo
        // por lote (CalcularPorPeriodo) puede llegar acá con una liquidación ya Calculada o
        // Aprobada. Sin esto, las cuotas de préstamo pendientes se saltean en silencio en
        // cualquier recálculo que no pase primero por "Reabrir".
        Liq.Estado := Liq.Estado::Borrador;
        Liq.Modify();
        DeleteLineas(Liq."No.");
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
        CtxBuilder.BuildContext(Ctx);
        InjectGUVariables(Ctx);
        InjectZonaDesfavorable(Liq, FechaRef, Ctx);
        Evaluador.Init(Ctx, FechaRef);
        RunConceptos(Liq, FechaRef, Ctx, CtxBuilder, Evaluador);
        if Ctx.ContainsKey('ES_GROSSING_UP') and (Ctx.Get('ES_GROSSING_UP') = 1) then
            ConvergerGrossingUp(Liq, FechaRef, Ctx, CtxBuilder, Evaluador);
        if Ctx.ContainsKey('BASE_IG4') then
            Liq."Haberes Ordinarios Gravados" := Ctx.Get('BASE_IG4');
        UpdateTotals(Liq);
        SaveResumenVariables(Liq."No.", Ctx);
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
        CodEstado: Record "Cód. Estado Empleado";
        EstadoMgt: Codeunit "Gestión Estado Empleado";
        EstadoEmp: Record "Estado Empleado";
        TipoEmpleado: Enum "Aplica A Liq.";
        Importe: Decimal;
        Errores: Text;
    begin
        EstadoMgt.GetEstado(Liq."No. Empleado", FechaRef, EstadoEmp);
        if CodEstado.Get(EstadoEmp."Cód. Estado") then
            TipoEmpleado := CodEstado."Tipo Empleado"
        else
            TipoEmpleado := TipoEmpleado::Todos;

        SelectConceptos(Concepto, TipoEmpleado, FechaRef, Liq."Cód. Tipo Liq.");
        EnsureConceptCaches(FechaRef);

        if not Concepto.FindSet() then exit;
        repeat
            if FLatestVersionMap.ContainsKey(Concepto.Código) and
               (Concepto."Vigencia Desde" = FLatestVersionMap.Get(Concepto.Código)) and
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
        CodEstado: Record "Cód. Estado Empleado";
        EstadoMgt: Codeunit "Gestión Estado Empleado";
        EstadoEmp: Record "Estado Empleado";
        TipoEmpleado: Enum "Aplica A Liq.";
        Incid: Record "Incidencia Liquidación";
        Importe: Decimal;
        ImporteConsumoFranco: Decimal;
        CreateLine: Boolean;
        EsIncidencia: Boolean;
        ConceptLog: Text;
        FullParamLog: Text;
    begin
        EstadoMgt.GetEstado(Liq."No. Empleado", FechaRef, EstadoEmp);
        if CodEstado.Get(EstadoEmp."Cód. Estado") then
            TipoEmpleado := CodEstado."Tipo Empleado"
        else
            TipoEmpleado := TipoEmpleado::Todos;

        SelectConceptos(Concepto, TipoEmpleado, FechaRef, Liq."Cód. Tipo Liq.");

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
            // Solo versión/acumulador son bloqueos duros. CCT y Tipo Liq. se evalúan más abajo,
            // pero SOLO para la vía de fórmula — una incidencia manual puede disparar aunque el
            // concepto normalmente no aplique a este convenio/tipo, y así corre en su Orden
            // Cálculo real en vez de quedar relegada al final (ver WriteIncidenciasRestantes).
            if not (FLatestVersionMap.ContainsKey(Concepto.Código) and
               (Concepto."Vigencia Desde" = FLatestVersionMap.Get(Concepto.Código)) and
               not Concepto."Es Acumulador")
            then begin
                // version/accumulator filter: skip entirely
            end else begin
                CreateLine := false;
                EsIncidencia := false;
                if Incid.Get(Liq."No.", Concepto.Código) then
                    if Incid.Importe <> 0 then begin
                        Importe := Abs(Incid.Importe);
                        CreateLine := true;
                        EsIncidencia := true;
                    end;

                if (not CreateLine) and
                   CCTAplicaAConcepto(Concepto, Liq."Cód. Convenio", Liq."Cód. Categoría", FechaRef) and
                   ConceptoAplicaATipoLiq(Concepto, Liq."Cód. Tipo Liq.") and
                   CondicionOk(Evaluador, Concepto)
                then begin
                    if not Evaluador.TryEvalFormula(Concepto.Fórmula, Importe) then
                        Error(ErrConceptoFalló, Concepto.Código, GetLastErrorText());
                    Importe := Abs(Importe);
                    CreateLine := true;
                end;

                if CreateLine then
                    // Franco consumption: expand into one valued line per lot category (FIFO), instead of a
                    // single line. The formula result (Importe) is the number of días to consume.
                    if Concepto."Rol Franco" = Concepto."Rol Franco"::Consumo then begin
                        ImporteConsumoFranco := GenerarLineasConsumoFranco(Liq, Concepto, Importe);
                        if Ctx.ContainsKey(Concepto.Código) then
                            Ctx.Set(Concepto.Código, ImporteConsumoFranco)
                        else
                            Ctx.Add(Concepto.Código, ImporteConsumoFranco);
                    end else begin
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
                    LinLiq.Importe := Importe;
                    if EsIncidencia and (Incid.Cantidad <> 0) then begin
                        LinLiq.Cantidad := Incid.Cantidad;
                        LinLiq."Unidad Cantidad" := Incid."Unidad Cantidad";
                        LinLiq."Base Cálculo" := Incid."Valor Unitario";
                    end else if (Concepto."Variable Cantidad" <> '') and Ctx.ContainsKey(Concepto."Variable Cantidad") then begin
                        LinLiq.Cantidad := Ctx.Get(Concepto."Variable Cantidad");
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
                    if not (EsIncidencia and (Incid.Cantidad <> 0)) and
                       (Concepto."Variable Base" <> '') and Ctx.ContainsKey(Concepto."Variable Base")
                    then
                        LinLiq."Base Cálculo" := Ctx.Get(Concepto."Variable Base");
                    LinLiq."Orden Cálculo" := Concepto."Orden Cálculo";
                    LinLiq."Fórmula Aplicada" := Concepto.Fórmula;
                    // BuildFormulaEvaluada es solo presentación y no toca el estado del evaluador
                    // (TryGetConceptoRefValue lee la memo, no la escribe), así que saltearla en una
                    // iteración intermedia de GU no cambia ningún importe. Se mantiene ANTES del
                    // Flush para no alterar el contenido de ConceptLog.
                    if not FIteracionGU then
                        LinLiq."Fórmula Evaluada" := BuildFormulaEvaluada(Concepto.Fórmula, Ctx, Evaluador);
                    LinLiq."Vigencia Concepto" := Concepto."Vigencia Desde";
                    // El Flush corre SIEMPRE: resetea el log y los vars resueltos por concepto.
                    ConceptLog := Evaluador.FlushConceptLog();
                    // Se anota qué acumuladores leyó este concepto ANTES de que aporte a los suyos:
                    // el orden importa, y una lectura previa a un aporte posterior es justamente el
                    // error que se quiere detectar.
                    RegistrarLecturasAcumuladores(ConceptLog, Concepto.Código, Concepto."Orden Cálculo");
                    if not FIteracionGU then begin
                        if FullParamLog <> '' then FullParamLog += '|';
                        FullParamLog += ConceptLog;
                        LinLiq."Fuente Parámetros" := CtxBuilder.GetParamLog() + '|' + ConceptLog;
                    end;
                    LinLiq.Insert(true);

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
                            DetGan.Descripción := CopyStr(Concepto."Etiqueta Det. Ganancias", 1, MaxStrLen(DetGan.Descripción));
                            DetGan."Importe Total" := Importe;
                            DetGan.Orden := Concepto."Orden Cálculo";
                            DetGan.Insert();
                        end;

                        WriteVariableDetail(Liq."No.", LinLiq."No. Línea", ConceptLog, Ctx);
                    end;

                    VerificarOrdenAporte(Concepto.Código, Concepto."Orden Cálculo");
                    UpdateAccumulatorsFromCache(
                        Concepto.Código, Importe, FFracAccumList, FFracAccumPct, Ctx);
                    Evaluador.UpdateContext(Ctx);
                end;
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

    // Expands a franco-consumption concept into one Línea Liquidación per lot category, valued via FIFO
    // (each slice at its own category's VALOR_FRANCO). DiasSolicitados = the concept's formula result.
    // Returns the total Importe across all slices, so RunConceptos can expose it via #CÓDIGO.
    local procedure GenerarLineasConsumoFranco(var Liq: Record "Liquidación"; Concepto: Record "Concepto Liquidación"; DiasSolicitados: Decimal) ImporteTotal: Decimal
    var
        TempSlice: Record "Línea Liquidación" temporary;
        LinLiq: Record "Línea Liquidación";
        CatCCT: Record "Categoría CCT";
        FrancosMgt: Codeunit "Gestión Francos";
        EtiquetaCat: Text;
    begin
        FrancosMgt.CalcularConsumoDesglosado(Liq."No. Empleado", DiasSolicitados, Liq."Fecha Liquidación", Liq."No.", TempSlice);
        if not TempSlice.FindSet() then exit;
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
            LinLiq.Insert(true);
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
        Incid: Record "Incidencia Liquidación";
        Concepto: Record "Concepto Liquidación";
        LinLiq: Record "Línea Liquidación";
        ExistingLine: Record "Línea Liquidación";
    begin
        Incid.SetRange("No. Liquidación", Liq."No.");
        if not Incid.FindSet() then exit;
        repeat
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
                        LinLiq.Importe := Abs(Incid.Importe);
                        if Incid.Cantidad <> 0 then begin
                            LinLiq.Cantidad := Incid.Cantidad;
                            LinLiq."Unidad Cantidad" := Incid."Unidad Cantidad";
                            LinLiq."Base Cálculo" := Incid."Valor Unitario";
                        end;
                        LinLiq."Orden Cálculo" := Concepto."Orden Cálculo";
                        LinLiq."Vigencia Concepto" := Concepto."Vigencia Desde";
                        LinLiq.Insert(true);

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
        Concepto.SetRange(Activo, true);
        if not Concepto.FindSet() then
            exit;
        repeat
            if LatestVersionMap.ContainsKey(Concepto.Código) and
               (Concepto."Vigencia Desde" = LatestVersionMap.Get(Concepto.Código)) and
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
                LinLiq.Insert(true);
            end;
        until Concepto.Next() = 0;
    end;

    local procedure SelectConceptos(
        var Concepto: Record "Concepto Liquidación";
        TipoEmpleado: Enum "Aplica A Liq.";
        FechaRef: Date;
        TipoLiq: Code[20])
    begin
        Concepto.Reset();
        Concepto.SetRange(Activo, true);
        Concepto.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        if TipoEmpleado <> TipoEmpleado::Todos then
            Concepto.SetFilter("Aplica A", '%1|%2', Concepto."Aplica A"::Todos, TipoEmpleado);
        Concepto.SetCurrentKey("Orden Cálculo", Código);
    end;

    local procedure ConceptoAplicaATipoLiq(Concepto: Record "Concepto Liquidación"; TipoLiq: Code[20]): Boolean
    begin
        if Concepto."Tipos Liq. Aplicables" = '' then
            exit(true);
        exit(('|' + Concepto."Tipos Liq. Aplicables" + '|').Contains('|' + TipoLiq + '|'));
    end;

    // ── Pre-build caches (called once per liquidation, before the concept loop) ──

    // Builds (once per FechaRef) the concept caches shared by ValidarFormulas, RunConceptos,
    // and every GU iteration. Subsequent calls with the same FechaRef are no-ops.
    local procedure EnsureConceptCaches(FechaRef: Date)
    var
        Concepto: Record "Concepto Liquidación";
    begin
        if FConceptCacheLoaded and (FConceptCacheFecha = FechaRef) then
            exit;
        Clear(FLatestVersionMap);
        Clear(FFracAccumList);
        Clear(FFracAccumPct);
        Clear(FAccumCodes);
        BuildLatestVersionCache(FechaRef, FLatestVersionMap);
        BuildFractionCache(FechaRef, FFracAccumList, FFracAccumPct);
        Concepto.SetRange("Es Acumulador", true);
        Concepto.SetRange(Activo, true);
        if Concepto.FindSet() then
            repeat
                FAccumCodes.Add(Concepto.Código);
            until Concepto.Next() = 0;
        FConceptCacheFecha := FechaRef;
        FConceptCacheLoaded := true;
    end;

    local procedure BuildLatestVersionCache(FechaRef: Date; var LatestMap: Dictionary of [Code[20], Date])
    var
        Concepto: Record "Concepto Liquidación";
    begin
        Concepto.Reset();
        Concepto.SetRange(Activo, true);
        Concepto.SetFilter("Vigencia Desde", '<=%1', FechaRef);
        if not Concepto.FindSet() then exit;
        repeat
            if not LatestMap.ContainsKey(Concepto.Código) then
                LatestMap.Add(Concepto.Código, Concepto."Vigencia Desde")
            else
                if Concepto."Vigencia Desde" > LatestMap.Get(Concepto.Código) then
                    LatestMap.Set(Concepto.Código, Concepto."Vigencia Desde");
        until Concepto.Next() = 0;
    end;

    // Returns true if this concept applies to CodConvenio at FechaRef.
    // Fast path via the "Vigencia CCT Más Reciente" MaxFlowField: when 0D there are
    // no restrictions for the concept at all and the lookup short-circuits.
    // When restrictions exist, two indexed lookups (FindLast + Get) resolve the
    // applicability for FechaRef without scanning the table.
    local procedure CCTAplicaAConcepto(var Concepto: Record "Concepto Liquidación"; CodConvenio: Code[20]; CodCategoria: Code[20]; FechaRef: Date): Boolean
    var
        CCTVig: Record "Concepto CCT Vigente";
        VigenciaAplicable: Date;
    begin
        Concepto.CalcFields("Vigencia CCT Más Reciente");
        if Concepto."Vigencia CCT Más Reciente" = 0D then
            exit(true);

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

        // La vigencia se guarda ANTES de cualquier Get: un Get fallido deja el registro en blanco,
        // así que leer CCTVig."Vigencia Desde" para el segundo Get daría 0D y el fallback por
        // convenio nunca encontraría nada (el concepto quedaba silenciosamente sin aplicar).
        // Dentro de un mismo convenio sí manda la vigencia más reciente: así una versión nueva
        // puede restringir a categorías puntuales reemplazando a la anterior.
        VigenciaAplicable := CCTVig."Vigencia Desde";

        // Coincidencia exacta de convenio+categoría gana; si no existe, una fila de "todo el
        // convenio" (categoría en blanco) también aplica. Si ninguna existe, no aplica.
        if CCTVig.Get(Concepto.Código, VigenciaAplicable, CodConvenio, CodCategoria) then
            exit(true);
        exit(CCTVig.Get(Concepto.Código, VigenciaAplicable, CodConvenio, ''));
    end;

    // Single-pass build of fraction cache, sorted by Concepto+Vigencia.
    // For each concept, finds the latest vigencia per accumulator pair and caches
    // the percentage. A concept can feed multiple accumulators with independent vigencias.
    local procedure BuildFractionCache(FechaRef: Date;
        var AccumList: Dictionary of [Code[20], Text];
        var AccumPct: Dictionary of [Text, Decimal])
    var
        Fraccion: Record "Fracción Acumulador";
        AccumKey: Text;
        PctConSigno: Decimal;
        BestVig: Dictionary of [Text, Date];
    begin
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
                if Fraccion.Restar then PctConSigno := -PctConSigno;
                if AccumPct.ContainsKey(AccumKey) then
                    AccumPct.Set(AccumKey, PctConSigno)
                else
                    AccumPct.Add(AccumKey, PctConSigno);

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

        Lin.SetRange("Tipo Concepto", Lin."Tipo Concepto"::"Deducción Remunerativa");
        Lin.CalcSums(Importe);
        Liq."Total Haberes" -= Lin.Importe;

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

    local procedure DeleteLineas(LiqNo: Code[20])
    var
        Lin: Record "Línea Liquidación";
        Det: Record "Detalle Variable Línea Liq.";
        Resumen: Record "Resumen Variable Liq.";
        DetGan: Record "Detalle Ganancias Liq.";
    begin
        Det.SetRange("No. Liquidación", LiqNo);
        Det.DeleteAll();
        Resumen.SetRange("No. Liquidación", LiqNo);
        Resumen.DeleteAll();
        DetGan.SetRange("No. Liquidación", LiqNo);
        DetGan.DeleteAll();
        Lin.SetRange("No. Liquidación", LiqNo);
        // DeleteAll(false) a propósito: el OnDelete de "Línea Liquidación" solo borra los
        // Detalle Variable de la línea, y el DeleteAll de arriba ya los borró TODOS de una
        // sola vez para esta liquidación. Con DeleteAll(true) se pagaba un DeleteAll extra
        // por línea, y eso se multiplica por cada iteración de Grossing Up.
        // Si algún día el OnDelete hace algo más que borrar detalles, esto tiene que volver
        // a ser DeleteAll(true).
        Lin.DeleteAll(false);
    end;

    local procedure WriteVariableDetail(
        LiqNo: Code[20];
        LineNo: Integer;
        ConceptLog: Text;
        var Ctx: Dictionary of [Text, Decimal])
    var
        Det: Record "Detalle Variable Línea Liq.";
        Entries: List of [Text];
        Entry: Text;
        VarName: Text;
        CtxKey: Text;
    begin
        if ConceptLog = '' then exit;
        Entries := ConceptLog.Split('|');
        foreach Entry in Entries do
            if Entry.StartsWith('VAR:') then begin
                VarName := CopyStr(Entry, 5);
                // @CÓDIGO y #CÓDIGO no viven en Ctx bajo su nombre con prefijo — el prefijo solo
                // distingue el LOG ("se usó @2403"/"se usó #2403"); el valor real está en Ctx bajo
                // el código pelado. Se muestra el nombre CON prefijo para que quede claro cuál de
                // los dos mecanismos se usó.
                CtxKey := VarName;
                if CtxKey.StartsWith('@') or CtxKey.StartsWith('#') then
                    CtxKey := CopyStr(CtxKey, 2);
                if (VarName <> '') and Ctx.ContainsKey(CtxKey) then begin
                    Clear(Det);
                    Det."No. Liquidación" := LiqNo;
                    Det."No. Línea" := LineNo;
                    Det."Nombre Variable" := CopyStr(VarName, 1, MaxStrLen(Det."Nombre Variable"));
                    Det.Valor := Ctx.Get(CtxKey);
                    if Det.Insert() then;
                end;
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
    begin
        Formula := Formula.ToUpper().Trim();
        Len := StrLen(Formula);
        Pos := 1;
        while Pos <= Len do begin
            C := Formula[Pos];
            if IsIdentStartChar(C) then begin
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
                if Token.StartsWith('@') then
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

    local procedure IsIdentStartChar(C: Char): Boolean
    begin
        exit(((C >= 'A') and (C <= 'Z')) or (C = '_') or (C = '@') or (C = '#'));
    end;

    local procedure IsIdentChar(C: Char): Boolean
    begin
        exit(((C >= 'A') and (C <= 'Z')) or ((C >= '0') and (C <= '9')) or (C = '_'));
    end;

    local procedure IsPercentageVariable(Token: Text): Boolean
    begin
        exit(Token.StartsWith('PCT_') or Token.Contains('_PCT') or Token.Contains('PORC'));
    end;

    local procedure IsFormulaKeyword(Token: Text): Boolean
    begin
        exit(Token in ['MAX', 'MIN', 'ROUND', 'ABS', 'IF', 'DIV', 'TRAMO', 'AND', 'OR', 'NOT']);
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
    local procedure SaveResumenVariables(LiqNo: Code[20]; var Ctx: Dictionary of [Text, Decimal])
    var
        Resumen: Record "Resumen Variable Liq.";
        VarName: Text;
        Valor: Decimal;
        MostrarEnRecibo: Boolean;
    begin
        foreach VarName in Ctx.Keys() do begin
            Valor := Ctx.Get(VarName);
            if (Valor <> 0) and not EsConceptoNoAcumulador(VarName) then begin
                Clear(Resumen);
                Resumen."No. Liquidación" := LiqNo;
                Resumen."Nombre Variable" := CopyStr(VarName, 1, MaxStrLen(Resumen."Nombre Variable"));
                Resumen.Valor := Valor;
                Resumen.Etiqueta := CopyStr(ResolveEtiquetaResumen(VarName, MostrarEnRecibo), 1, MaxStrLen(Resumen.Etiqueta));
                Resumen."Mostrar en Recibo" := MostrarEnRecibo;
                if not Resumen.Insert() then
                    Resumen.Modify();
            end;
        end;
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

        Param.SetRange("Nombre Variable", NombreCode);
        if Param.FindFirst() then
            exit(Param.Descripción);

        Concepto.SetRange(Código, NombreCode);
        Concepto.SetRange("Es Acumulador", true);
        if Concepto.FindFirst() then
            exit(Concepto.Descripción);

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
        // Zona is a property of the voyage: the whole crew shares the project's zone. Falls back to the
        // employee's default when the project leaves it at 0 (e.g. non-marea assignments).
        if (Liq."No. Proyecto" <> '') and Job.Get(Liq."No. Proyecto") and (Job."Zona Desfavorable" > 0) then
            Zona := Job."Zona Desfavorable"
        else
            if Emp.Get(Liq."No. Empleado") then
                Zona := Emp."Zona Desfavorable";

        if Ctx.ContainsKey('COD_ZONA') then Ctx.Set('COD_ZONA', Zona) else Ctx.Add('COD_ZONA', Zona);

        if Emp.Get(Liq."No. Empleado") then
            if (Emp."Fecha Jubilación" <> 0D) and (Emp."Fecha Jubilación" <= FechaRef) then
                EsJub := 1;
        if Ctx.ContainsKey('ES_JUBILADO') then Ctx.Set('ES_JUBILADO', EsJub) else Ctx.Add('ES_JUBILADO', EsJub);
    end;

    // Injects the three GU context variables before RunConceptos.
    // Always present so the GU concept formula (COMPLEMENTO_GU) and its condition
    // (ES_GROSSING_UP > 0) resolve correctly regardless of whether GU is active.
    local procedure InjectGUVariables(var Ctx: Dictionary of [Text, Decimal])
    var
        EsGU: Decimal;
        NetoGU: Decimal;
    begin
        if Ctx.ContainsKey('NETO_GU') then
            if Ctx.Get('NETO_GU') > 0 then begin
                EsGU := 1;
                NetoGU := Ctx.Get('NETO_GU');
            end;

        if Ctx.ContainsKey('ES_GROSSING_UP') then Ctx.Set('ES_GROSSING_UP', EsGU) else Ctx.Add('ES_GROSSING_UP', EsGU);
        if Ctx.ContainsKey('NETO_GARANTIZADO') then Ctx.Set('NETO_GARANTIZADO', NetoGU) else Ctx.Add('NETO_GARANTIZADO', NetoGU);
        if Ctx.ContainsKey('COMPLEMENTO_GU') then Ctx.Set('COMPLEMENTO_GU', 0) else Ctx.Add('COMPLEMENTO_GU', 0);
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
        CurrExchRate: Record "Currency Exchange Rate";
        MonedaGU: Code[10];
        NetoObjetivo: Decimal;
        NetoActual: Decimal;
        Delta: Decimal;
        NuevoComplemento: Decimal;
        Iter: Integer;
        PasadasSinAuditoria: Integer;
    begin
        NetoObjetivo := Ctx.Get('NETO_GARANTIZADO');
        if Ctx.ContainsKey('DIAS_VAC_INICIO') then
            if Ctx.Get('DIAS_VAC_INICIO') > 0 then
                NetoObjetivo := NetoObjetivo + NetoObjetivo * Ctx.Get('DIAS_VAC_INICIO') / 150;
        MonedaGU := CtxBuilder.GetMoneda();
        if MonedaGU <> '' then
            NetoObjetivo := CurrExchRate.ExchangeAmtFCYToLCY(
                FechaRef, MonedaGU, NetoObjetivo,
                CurrExchRate.ExchangeRate(FechaRef, MonedaGU));
        // Las iteraciones intermedias se descartan enteras en el DeleteLineas de la vuelta
        // siguiente, así que escribir su auditoría (Fórmula Evaluada, Detalle Variable, Detalle
        // Ganancias, Fuente Parámetros, En Uso) es trabajo puro de descarte. Se suprime durante la
        // convergencia y se escribe una sola vez, al final, sobre el resultado que efectivamente
        // queda. Ningún importe depende de esos datos — ver los guardas de FIteracionGU en
        // RunConceptos.
        FIteracionGU := true;
        for Iter := 1 to 20 do begin
            NetoActual := CalcNetoDesdeBD(Liq."No.");
            Delta := NetoObjetivo - NetoActual;
            if Abs(Delta) <= 0.01 then
                break;
            NuevoComplemento := Ctx.Get('COMPLEMENTO_GU') + Delta;
            if NuevoComplemento < 0 then NuevoComplemento := 0;
            Ctx.Set('COMPLEMENTO_GU', NuevoComplemento);
            Evaluador.UpdateContext(Ctx);
            ResetAccumuladores(Ctx);
            DeleteLineas(Liq."No.");
            RunConceptos(Liq, FechaRef, Ctx, CtxBuilder, Evaluador);
            PasadasSinAuditoria += 1;
        end;
        FIteracionGU := false;

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
            Evaluador.UpdateContext(Ctx);
            ResetAccumuladores(Ctx);
            DeleteLineas(Liq."No.");
            RunConceptos(Liq, FechaRef, Ctx, CtxBuilder, Evaluador);
        end;
    end;

    // Computes the current neto from the already-written Línea Liquidación rows.
    local procedure CalcNetoDesdeBD(LiqNo: Code[20]): Decimal
    var
        Lin: Record "Línea Liquidación";
        TotalHaberes: Decimal;
        TotalDesc: Decimal;
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

        Lin.SetRange("Tipo Concepto", Lin."Tipo Concepto"::"Deducción Remunerativa");
        Lin.CalcSums(Importe);
        TotalHaberes -= Lin.Importe;

        Lin.SetFilter("Tipo Concepto", '%1|%2|%3',
            Lin."Tipo Concepto"::Retención,
            Lin."Tipo Concepto"::"Descuento Empleado",
            Lin."Tipo Concepto"::"Seguridad Social");
        Lin.CalcSums(Importe);
        TotalDesc := Lin.Importe;

        exit(TotalHaberes - TotalDesc);
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
        FConceptCacheLoaded: Boolean;
        FConceptCacheFecha: Date;
        FLatestVersionMap: Dictionary of [Code[20], Date];
        FFracAccumList: Dictionary of [Code[20], Text];
        FFracAccumPct: Dictionary of [Text, Decimal];
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
        ErrPeriodoCerrado: Label 'El período %1 está cerrado. No se puede reliquidar.';
        ErrConceptoFalló: Label 'Error al calcular el concepto %1: %2';
        ErrFormulasInvalidas: Label 'Las siguientes fórmulas contienen errores. Corrija antes de calcular:\%1';
        ErrSinAsignacionProyecto: Label 'El empleado %1 no está asignado al proyecto %2. Asígnelo en Personal Proyecto antes de liquidar.';
        FAdvertencias: Text;
        // true mientras ConvergerGrossingUp está iterando: RunConceptos saltea todo el trabajo de
        // auditoría/presentación, que se descarta en el DeleteLineas de la iteración siguiente.
        // Ver ConvergerGrossingUp para la pasada final que sí lo escribe.
        FIteracionGU: Boolean;
        GestionPrestamos: Codeunit "Gestión Préstamos";
        GestionNovedades: Codeunit "Gestión Novedades Liq.";
        Registro: Codeunit "Registro Procesos Liq.";
        RegCalculadaTxt: Label 'Liquidación calculada (%1, período %2).';
}
