namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;

codeunit 50019 "Gestión Liquidación"
{
    // Single point of truth for Liquidación state transitions.
    // Pages (Lista, Ficha) call these procedures so validation, confirmation
    // and side-effects stay consistent across UI entry points.

    procedure Aprobar(var Liq: Record "Liquidación")
    var
        LinLiq: Record "Línea Liquidación";
        GestPrest: Codeunit "Gestión Préstamos";
    begin
        if Liq.Estado <> Liq.Estado::Calculada then
            Error(ErrSoloCalculada);
        Registro.Iniciar("Tipo Proceso Liq."::Aprobación, Liq);
        Liq.Estado := Liq.Estado::Aprobada;
        Liq.Modify(true);
        LinLiq.SetRange("No. Liquidación", Liq."No.");
        LinLiq.ModifyAll(Estado, Liq.Estado::Aprobada);
        GestPrest.MarcarCuotasAplicadas(Liq."No.", Liq."Fecha Liquidación");
        Registro.InfoImporte("Categoría Registro Liq."::Estado, RegAprobadaTxt, '', Liq."Total Haberes");
        Registro.Finalizar();
    end;

    /// <summary>
    /// Permite reabrir aunque haya liquidaciones posteriores. Solo para el recálculo en cadena.
    /// </summary>
    /// <remarks>
    /// La cadena reabre los posteriores para poder borrarles las líneas, que es exactamente lo que
    /// el control prohíbe; sin esta puerta el único proceso que arregla la situación sería el único
    /// que no puede correr. Se prende sobre la instancia del codeunit, así que no se filtra a ningún
    /// otro llamador.
    /// </remarks>
    procedure PermitirFueraDeOrden(Permitir: Boolean)
    begin
        FPermitirFueraDeOrden := Permitir;
    end;

    /// <summary>
    /// ¿Se puede reabrir sin romper el orden? Deja en Posterior la primera que lo impide.
    /// </summary>
    /// <remarks>
    /// Para los procesos de lote, que necesitan SALTEAR la que no se puede en vez de cortar: en una
    /// reapertura masiva —un período entero, un nodo del árbol— es normal que alguna tenga
    /// posteriores, y abortar por la primera dejaría el resto sin reabrir.
    /// </remarks>
    procedure PuedeReabrir(var Liq: Record "Liquidación"; var Posterior: Record "Liquidación"): Boolean
    var
        Cadena: Codeunit "Recálculo En Cadena Liq.";
    begin
        exit(not Cadena.PrimeraPosterior(Liq, Posterior));
    end;

    /// <remarks>
    /// Reabrir no es solo cambiar un estado: devuelve las novedades a disponibles y desmarca las
    /// cuotas de préstamo aplicadas. Con una liquidación posterior ya calculada, esas novedades y
    /// esas cuotas quedan sueltas y el próximo cálculo del empleado —el de la posterior— se las
    /// lleva puestas: la misma cuota descontada dos veces, la misma novedad liquidada dos veces.
    ///
    /// Además las líneas siguen ahí, en Borrador, y los acumuladores anuales y del período excluyen
    /// Borrador: la posterior pasa a leer una base distinta de la que leyó cuando se calculó.
    ///
    /// Es el mismo criterio que el control de orden del motor, del otro lado de la transición:
    /// aquél no deja CALCULAR una liquidación con posteriores, éste no deja REABRIRLA.
    /// </remarks>
    local procedure ValidarSinPosteriores(var Liq: Record "Liquidación")
    var
        Posterior: Record "Liquidación";
    begin
        if FPermitirFueraDeOrden then
            exit;
        if PuedeReabrir(Liq, Posterior) then
            exit;
        Error(ErrPosterioresAlReabrir,
            Liq."No.", Liq."Cód. Período", Posterior."No.", Posterior."Cód. Período", Posterior."Fecha Liquidación");
    end;

    procedure ReabrirPorNumero(Numero: Code[20])
    var
        Liq: Record "Liquidación";
    begin
        Liq.Get(Numero);
        Reabrir(Liq);
    end;

    /// <summary>Reabre consumidores antes que sus devengos; deja bloqueos externos pendientes.</summary>
    procedure ReabrirPeriodoPorCodigo(Codigo: Code[20])
    var
        Revertidas: Integer;
        Bloqueadas: Integer;
    begin
        ReabrirPeriodo(Codigo, Revertidas, Bloqueadas);
        if Bloqueadas > 0 then
            Error('Quedan %1 liquidaciones bloqueadas por dependencias fuera del período. No se reabrió el período.', Bloqueadas);
    end;

    procedure ReabrirPeriodo(Codigo: Code[20]; var Revertidas: Integer; var Bloqueadas: Integer)
    var
        Liq: Record "Liquidación";
        Numeros: List of [Code[20]];
    begin
        Liq.LockTable();
        Liq.SetRange("Cód. Período", Codigo);
        Liq.SetRange(Estado, Liq.Estado::Calculada);
        if Liq.FindSet() then repeat
            Numeros.Add(Liq."No.");
        until Liq.Next() = 0;
        ReabrirSeleccion(Numeros, Revertidas, Bloqueadas);
    end;

    /// <summary>Respeta exactamente las claves seleccionadas y las dependencias del ledger.</summary>
    procedure ReabrirSeleccion(Numeros: List of [Code[20]]; var Revertidas: Integer; var Bloqueadas: Integer)
    var
        Motivos: List of [Text];
    begin
        ReabrirSeleccion(Numeros, Revertidas, Bloqueadas, Motivos);
    end;

    /// <summary>Igual, y además dice POR QUÉ quedó bloqueada cada una que no se pudo reabrir.</summary>
    procedure ReabrirSeleccion(Numeros: List of [Code[20]]; var Revertidas: Integer; var Bloqueadas: Integer; var Motivos: List of [Text])
    var
        Liq: Record "Liquidación";
        Posterior: Record "Liquidación";
        Cuenta: Codeunit "Cuenta Corriente Francos";
        Pendientes: List of [Code[20]];
        Revisar: List of [Code[20]];
        Numero: Code[20];
        Consumidor: Code[20];
        Avance: Boolean;
    begin
        Revertidas := 0;
        Bloqueadas := 0;
        Liq.LockTable();
        foreach Numero in Numeros do
            if Liq.Get(Numero) then
                if Liq.Estado = Liq.Estado::Calculada then
                    if not Pendientes.Contains(Numero) then Pendientes.Add(Numero);
        repeat
            Avance := false;
            Clear(Revisar);
            foreach Numero in Pendientes do Revisar.Add(Numero);
            foreach Numero in Revisar do begin
                Liq.Get(Numero);
                if PuedeReabrir(Liq, Posterior) then
                    if Cuenta.PuedeRevertir(Numero, Consumidor) then begin
                        Reabrir(Liq);
                        Pendientes.Remove(Numero);
                        Revertidas += 1;
                        Avance := true;
                    end;
            end;
        until (Pendientes.Count() = 0) or not Avance;
        Bloqueadas := Pendientes.Count();

        // El motivo de cada bloqueada, nombrando al estorbo. El mensaje genérico decía "posteriores o
        // consumos de francos" y obligaba a adivinar cuál era: a un mensualizado, que no tiene
        // francos, le sonaba a error.
        Clear(Motivos);
        foreach Numero in Pendientes do
            if Liq.Get(Numero) then
                if not PuedeReabrir(Liq, Posterior) then
                    Motivos.Add(StrSubstNo(MotBloqueoPosterior, Liq."No.", Posterior."No.", Posterior."Cód. Período"))
                else
                    if not Cuenta.PuedeRevertir(Numero, Consumidor) then
                        Motivos.Add(StrSubstNo(MotBloqueoFrancos, Liq."No.", Consumidor));
    end;

    procedure Reabrir(var Liq: Record "Liquidación")
    var
        CuentaFrancos: Codeunit "Cuenta Corriente Francos";
        LinLiq: Record "Línea Liquidación";
        GestPrest: Codeunit "Gestión Préstamos";
        GestNov: Codeunit "Gestión Novedades Liq.";
        Periodo: Record "Período Liquidación";
        Job: Record Job;
        TipoLiqRec: Record "Tipo Liquidación";
        Param: Record "Parámetro";
        ParamVig: Record "Parámetro Vigente";
        Claves: Codeunit "Claves Parámetro Liq.";
        UsedVarNames: List of [Text];
        Entries: List of [Text];
        // Qué variables usó cada una de las otras liquidaciones activas. Se arma una sola vez.
        UsosPorLiq: Dictionary of [Code[20], List of [Text]];
        Entry: Text;
        VarName: Text;
        FechaRef: Date;
        CodEfectivo: Code[50];
        VigDesde: Date;
    begin
        if Liq.Estado <> Liq.Estado::Calculada then
            Error(ErrSoloCalculadaReabrir);
        ValidarSinPosteriores(Liq);
        CuentaFrancos.Revertir(Liq."No.");
        Registro.Iniciar("Tipo Proceso Liq."::Reapertura, Liq);
        Liq.Estado := Liq.Estado::Borrador;
        Liq.Modify(true);
        LinLiq.SetRange("No. Liquidación", Liq."No.");
        LinLiq.ModifyAll(Estado, Liq.Estado::Borrador);
        GestPrest.RevertirCuotasLiquidacion(Liq."No.");
        // Las novedades vuelven a quedar disponibles: si no, quedan marcadas Aplicada contra un
        // cálculo que se acaba de deshacer y el recálculo no las volvería a tomar.
        // RevertirAprobacion no hace esto a propósito: ahí la liquidación sigue Calculada y sus
        // incidencias siguen siendo válidas.
        GestNov.RevertirLiquidacion(Liq."No.");

        // Se cierra el registro acá y no al final del procedimiento: la liberación de parámetros
        // "En Uso" que sigue tiene varios exit tempranos, y con ellos el Finalizar quedaría sin
        // ejecutar en la mayoría de los casos.
        Registro.Info("Categoría Registro Liq."::Estado, RegReabiertaTxt);
        Registro.Finalizar();

        // Camino rápido: el registro de uso de parámetros. Dos consultas indexadas por variable, sin
        // leer una sola línea de otra liquidación. Las liquidaciones calculadas ANTES de que
        // existiera esa tabla no tienen filas, y ésas siguen por el camino viejo — el de los tokens
        // embebidos en el texto— hasta que se recalculen.
        if LiberarEnUsoPorRegistro(Liq) then
            exit;

        // Collect all VAR: token names logged in this liquidation's lines
        LinLiq.SetRange("No. Liquidación", Liq."No.");
        if LinLiq.FindSet() then
            repeat
                Entries := LinLiq."Fuente Parámetros".Split('|');
                foreach Entry in Entries do
                    if Entry.StartsWith('VAR:') then begin
                        VarName := CopyStr(Entry, 5);
                        if (VarName <> '') and not UsedVarNames.Contains(VarName) then
                            UsedVarNames.Add(VarName);
                    end;
            until LinLiq.Next() = 0;

        if UsedVarNames.Count() = 0 then exit;
        if not Periodo.Get(Liq."Cód. Período") then exit;
        // Must match the reference date the motor used, so the En Uso release targets the
        // exact parameter version that was locked. Cierre Marea uses the arrival date.
        FechaRef := Periodo."Fecha Hasta";
        if TipoLiqRec.EsArribo(Liq."Cód. Tipo Liq.") then
            if (Liq."No. Proyecto" <> '') and Job.Get(Liq."No. Proyecto") and (Job."Ending Date" <> 0D) then
                FechaRef := Job."Ending Date";

        // Una sola lectura de las líneas ajenas, ANTES del bucle de variables. Sin esto, cada
        // variable volvía a leer las líneas de todas las liquidaciones activas para buscar su token:
        // con cuarenta variables, la tabla entera se leía cuarenta veces, y el costo crecía con cada
        // liquidación calculada que hubiera en la base. Reabrir terminaba siendo más lento que
        // calcular, que es el trabajo de verdad.
        CargarUsosDeOtrasLiquidaciones(Liq."No.", UsosPorLiq);

        // Release EnUso on the exact version used, only if no other active liq still references it
        foreach VarName in UsedVarNames do begin
            Param.SetRange("Nombre Variable", VarName);
            if Param.FindFirst() then begin
                CodEfectivo := Claves.ResolverEnTabla(
                    Param.Código, Liq."No. Empleado", Liq."Cód. Convenio", Liq."Cód. Categoría", FechaRef);

                ParamVig.SetRange("Cód. Parámetro Base", Param.Código);
                ParamVig.SetRange("Cód. Parámetro", CodEfectivo);
                ParamVig.SetFilter("Vigencia Desde", '<=%1', FechaRef);
                if ParamVig.FindLast() and ParamVig."En Uso" then begin
                    VigDesde := ParamVig."Vigencia Desde";
                    if not IsVersionUsedByOtherLiq(Param, CodEfectivo, VigDesde, VarName, Liq."No.", UsosPorLiq) then begin
                        ParamVig."En Uso" := false;
                        ParamVig.Modify();
                    end;
                end;
            end;
        end;
    end;

    /// <summary>
    /// Libera el "En Uso" usando el registro de uso de parámetros. False si esta liquidación no
    /// tiene registro —fue calculada antes de que la tabla existiera— y hay que usar el camino viejo.
    /// </summary>
    /// <remarks>
    /// Por cada versión que usó esta liquidación, la pregunta "¿queda alguien más usándola?" es un
    /// IsEmpty sobre la clave (Cód. Parámetro, Vigencia Desde, No. Liquidación), excluyéndose a sí
    /// misma. Se filtra además por liquidaciones ACTIVAS: una en Borrador no bloquea nada, y sus
    /// filas de uso se borran al reabrirla, pero el filtro cubre cualquier fila huérfana.
    /// </remarks>
    local procedure LiberarEnUsoPorRegistro(var Liq: Record "Liquidación"): Boolean
    var
        Uso: Record "Uso Parámetro Liq.";
        UsoOtra: Record "Uso Parámetro Liq.";
        OtraLiq: Record "Liquidación";
        ParamVig: Record "Parámetro Vigente";
        CtxBuilder: Codeunit "Contexto Liquidación";
        SigueEnUso: Boolean;
        EstadoActivo: Dictionary of [Code[20], Boolean];
        Activa: Boolean;
    begin
        Uso.SetRange("No. Liquidación", Liq."No.");
        if Uso.IsEmpty() then
            exit(false);

        // Una liquidación usa cientos de versiones y las otras se repiten en casi todas: el estado de
        // cada una se lee UNA vez y no un Get por cada fila de uso de cada versión.
        Uso.FindSet();
        repeat
            SigueEnUso := false;
            UsoOtra.SetCurrentKey("Cód. Parámetro", "Vigencia Desde", "No. Liquidación");
            UsoOtra.SetRange("Cód. Parámetro", Uso."Cód. Parámetro");
            UsoOtra.SetRange("Vigencia Desde", Uso."Vigencia Desde");
            UsoOtra.SetFilter("No. Liquidación", '<>%1', Liq."No.");
            if UsoOtra.FindSet() then
                repeat
                    if not EstadoActivo.Get(UsoOtra."No. Liquidación", Activa) then begin
                        Activa := OtraLiq.Get(UsoOtra."No. Liquidación") and
                            (OtraLiq.Estado in [OtraLiq.Estado::Calculada, OtraLiq.Estado::Aprobada, OtraLiq.Estado::Contabilizada]);
                        EstadoActivo.Add(UsoOtra."No. Liquidación", Activa);
                    end;
                    SigueEnUso := Activa;
                until (UsoOtra.Next() = 0) or SigueEnUso;

            if not SigueEnUso then
                if ParamVig.Get(Uso."Cód. Parámetro Base", Uso."Cód. Parámetro", Uso."Vigencia Desde") then
                    if ParamVig."En Uso" then begin
                        ParamVig."En Uso" := false;
                        ParamVig.Modify();
                    end;
        until Uso.Next() = 0;

        // El registro de esta liquidación deja de valer: vuelve a Borrador y ya no bloquea nada.
        CtxBuilder.BorrarUsoParametros(Liq."No.");
        exit(true);
    end;

    /// <summary>
    /// Qué variables usó cada liquidación activa distinta de ExcludeNo, leyendo sus líneas UNA vez.
    /// </summary>
    /// <remarks>
    /// Es el índice invertido que le falta a la liberación del "En Uso". El dato que se necesita —si
    /// tal liquidación usó tal variable— vive dentro de un texto (`Fuente Parámetros`), así que no se
    /// puede filtrar en SQL: hay que leer las líneas y partirlas. Lo que sí se puede es leerlas una
    /// sola vez para todas las variables, en lugar de una vez por variable.
    /// </remarks>
    local procedure CargarUsosDeOtrasLiquidaciones(ExcludeNo: Code[20]; var UsosPorLiq: Dictionary of [Code[20], List of [Text]])
    var
        OtraLiq: Record "Liquidación";
        OtraLin: Record "Línea Liquidación";
        Nombres: List of [Text];
        Entries: List of [Text];
        Entry: Text;
        Nombre: Text;
    begin
        Clear(UsosPorLiq);
        OtraLiq.SetFilter("No.", '<>%1', ExcludeNo);
        OtraLiq.SetFilter(Estado, '%1|%2|%3',
            OtraLiq.Estado::Calculada, OtraLiq.Estado::Aprobada, OtraLiq.Estado::Contabilizada);
        if not OtraLiq.FindSet() then
            exit;
        repeat
            Clear(Nombres);
            // De cada línea solo interesa el texto de trazabilidad; el resto de la fila —importes,
        // descripciones, fórmulas— no se mira.
        OtraLin.SetLoadFields("Fuente Parámetros");
        OtraLin.SetRange("No. Liquidación", OtraLiq."No.");
            if OtraLin.FindSet() then
                repeat
                    Entries := OtraLin."Fuente Parámetros".Split('|');
                    foreach Entry in Entries do
                        if Entry.StartsWith('VAR:') then begin
                            Nombre := CopyStr(Entry, 5);
                            if (Nombre <> '') and not Nombres.Contains(Nombre) then
                                Nombres.Add(Nombre);
                        end;
                until OtraLin.Next() = 0;
            UsosPorLiq.Add(OtraLiq."No.", Nombres);
        until OtraLiq.Next() = 0;
    end;

    // Returns true if any other active (Calculada|Aprobada|Contabilizada) liquidation
    // references VAR:VarName AND its Período would resolve to the same ParamVig version
    // (same CodEfectivo + VigDesde), meaning this version must stay locked.
    //
    // El "referencia la variable" ya no se busca releyendo líneas: lo responde el índice que arma
    // CargarUsosDeOtrasLiquidaciones de una sola pasada.
    local procedure IsVersionUsedByOtherLiq(
        Param: Record "Parámetro";
        CodEfectivo: Code[50];
        VigDesde: Date;
        VarName: Text;
        ExcludeNo: Code[20];
        var UsosPorLiq: Dictionary of [Code[20], List of [Text]]): Boolean
    var
        OtraLiq: Record "Liquidación";
        OtraPeriodo: Record "Período Liquidación";
        OtraJob: Record Job;
        TipoLiqRec: Record "Tipo Liquidación";
        OtraParamVig: Record "Parámetro Vigente";
        Claves: Codeunit "Claves Parámetro Liq.";
        OtraCodEfectivo: Code[50];
        OtraFechaRef: Date;
    begin
        OtraLiq.SetFilter("No.", '<>%1', ExcludeNo);
        OtraLiq.SetFilter(Estado, '%1|%2|%3',
            OtraLiq.Estado::Calculada, OtraLiq.Estado::Aprobada, OtraLiq.Estado::Contabilizada);
        if not OtraLiq.FindSet() then exit(false);
        repeat
            // Filtro barato primero: si esta liquidación nunca usó la variable, no hay por qué
            // resolverle la clave del parámetro ni volver a leerle las líneas.
            if UsoLaVariable(UsosPorLiq, OtraLiq."No.", VarName) then begin
            OtraCodEfectivo := Claves.ResolverEnTabla(
                Param.Código, OtraLiq."No. Empleado", OtraLiq."Cód. Convenio", OtraLiq."Cód. Categoría",
                OtraLiq."Fecha Liquidación");

            if OtraCodEfectivo = CodEfectivo then begin
                OtraFechaRef := 0D;
                if OtraPeriodo.Get(OtraLiq."Cód. Período") then
                    OtraFechaRef := OtraPeriodo."Fecha Hasta";
                if TipoLiqRec.EsArribo(OtraLiq."Cód. Tipo Liq.") then
                    if (OtraLiq."No. Proyecto" <> '') and OtraJob.Get(OtraLiq."No. Proyecto") and (OtraJob."Ending Date" <> 0D) then
                        OtraFechaRef := OtraJob."Ending Date";

                if OtraFechaRef > 0D then begin
                    OtraParamVig.SetRange("Cód. Parámetro Base", Param.Código);
                    OtraParamVig.SetRange("Cód. Parámetro", OtraCodEfectivo);
                    OtraParamVig.SetFilter("Vigencia Desde", '<=%1', OtraFechaRef);
                    // Ya sabemos que esta liquidación usó la variable —lo dijo el índice—, así que
                    // si además coincide la versión del parámetro, está en uso.
                    if OtraParamVig.FindLast() and (OtraParamVig."Vigencia Desde" = VigDesde) then
                        exit(true);
                end;
            end;
            end;
        until OtraLiq.Next() = 0;
        exit(false);
    end;

    local procedure UsoLaVariable(var UsosPorLiq: Dictionary of [Code[20], List of [Text]]; LiqNo: Code[20]; VarName: Text): Boolean
    var
        Nombres: List of [Text];
    begin
        if not UsosPorLiq.ContainsKey(LiqNo) then
            exit(false);
        Nombres := UsosPorLiq.Get(LiqNo);
        exit(Nombres.Contains(VarName));
    end;

    /// <summary>Libera marcas sin consumidores del empleado y de las versiones generales.</summary>
    /// <remarks>
    /// Se ejecuta después de guardar el estado Calculada y reconstruir el registro de usos.
    /// No depende de que la marca apareciera en la corrida anterior: también encuentra huérfanas.
    /// El registro identifica la versión exacta. Para liquidaciones anteriores a ese registro,
    /// conservar una marca ante un token histórico es deliberadamente conservador.
    /// </remarks>
    procedure ReconciliarEnUso(NoEmpleado: Code[20]): Integer
    begin
        exit(ReconciliarEnUso(NoEmpleado, ''));
    end;

    procedure ReconciliarEnUso(NoEmpleado: Code[20]; NoLiquidacionActual: Code[20]): Integer
    var
        ParamVig: Record "Parámetro Vigente";
        Candidatas: Record "Parámetro Vigente" temporary;
        Pendientes: Record "Parámetro Vigente" temporary;
        VersionesConfirmadas: Record "Parámetro Vigente" temporary;
        Uso: Record "Uso Parámetro Liq.";
        DocumentosPrecargados: Dictionary of [Code[20], Boolean];
        NombresPorBase: Dictionary of [Code[20], Text];
        HistoricoPorEmpleado: Dictionary of [Code[20], Dictionary of [Text, Boolean]];
        LiquidacionesHistoricas: Dictionary of [Code[20], Boolean];
        BaseActual: Code[20];
        PrecargarTestigos: Boolean;
        CantidadPendientes: Integer;
        Liberadas: Integer;
    begin
        // La precarga bloquea primero su cabecera y sus usos, antes de leer los valores,
        // como el cálculo/reapertura. Las demás versiones buscan un consumidor activo.
        Uso.LockTable();
        CargarVersionesDeLiquidacionActiva(NoEmpleado, NoLiquidacionActual, Uso, VersionesConfirmadas);
        ParamVig.LockTable();
        ParamVig.SetRange("En Uso", true);
        ParamVig.SetFilter("No. Empleado", '%1|%2', '', NoEmpleado);
        if ParamVig.FindSet() then
            repeat
                Candidatas := ParamVig;
                Candidatas.Insert();
                if not VersionesConfirmadas.Get(ParamVig."Cód. Parámetro Base", ParamVig."Cód. Parámetro", ParamVig."Vigencia Desde") then begin
                    Pendientes.Init();
                    Pendientes."Cód. Parámetro Base" := ParamVig."Cód. Parámetro Base";
                    Pendientes."Cód. Parámetro" := ParamVig."Cód. Parámetro";
                    Pendientes."Vigencia Desde" := ParamVig."Vigencia Desde";
                    Pendientes.Insert(false);
                    CantidadPendientes += 1;
                end;
            until ParamVig.Next() = 0;

        if CantidadPendientes = 0 then
            exit(0);

        // No modificar el campo filtrado durante el recorrido de la tabla real.
        // Las cachés viven sólo esta llamada: el siguiente cálculo puede crear usos o cambiar
        // estados. No se guarda un «sin uso» entre liquidaciones, ni se toca su trazabilidad.
        // El cursor no cambia mientras los testigos eliminan versiones de Pendientes.
        // La clave agrupa cada base en un tramo: una carga sin aporte adicional desactiva
        // sólo sus próximas precargas. Las candidatas restantes siempre pasan por TOP1.
        Candidatas.SetCurrentKey("Cód. Parámetro Base", "Cód. Parámetro", "Vigencia Desde");
        if Candidatas.FindSet() then begin
            BaseActual := Candidatas."Cód. Parámetro Base";
            PrecargarTestigos := true;
            repeat
                if BaseActual <> Candidatas."Cód. Parámetro Base" then begin
                    BaseActual := Candidatas."Cód. Parámetro Base";
                    PrecargarTestigos := true;
                end;
                if Pendientes.Get(Candidatas."Cód. Parámetro Base", Candidatas."Cód. Parámetro", Candidatas."Vigencia Desde") then begin
                    // La consulta exacta decide esta versión aunque sea la última. Retirarla
                    // antes del lector permite contar sólo candidatas adicionales pendientes.
                    Pendientes.Delete(false);
                    CantidadPendientes -= 1;
                    if not TieneUsoExactoActivo(Candidatas, Uso, Pendientes, CantidadPendientes, DocumentosPrecargados, PrecargarTestigos) then
                        if not TieneUsoHistoricoCacheado(Candidatas, NombresPorBase, HistoricoPorEmpleado, LiquidacionesHistoricas) then begin
                            ParamVig.Get(Candidatas."Cód. Parámetro Base", Candidatas."Cód. Parámetro", Candidatas."Vigencia Desde");
                            ParamVig."En Uso" := false;
                            ParamVig.Modify();
                            Liberadas += 1;
                        end;
                end;
                if CantidadPendientes = 0 then
                    exit(Liberadas);
            until Candidatas.Next() = 0;
        end;
        exit(Liberadas);
    end;

    local procedure CargarVersionesDeLiquidacionActiva(NoEmpleado: Code[20]; NoLiquidacionActual: Code[20]; var Uso: Record "Uso Parámetro Liq."; var VersionesActuales: Record "Parámetro Vigente" temporary)
    var
        Liq: Record "Liquidación";
    begin
        if NoLiquidacionActual = '' then
            exit;

        // La cabecera debe seguir activa mientras se usan estas respuestas positivas.
        // Uso ya tiene LockTable en el llamador; no se aceptan lecturas sucias ni se conserva
        // esta precarga entre documentos. El motor llama después de guardar Calculada.
        Liq.ReadIsolation := IsolationLevel::UpdLock;
        Liq.SetLoadFields(Estado, "No. Empleado");
        if not Liq.Get(NoLiquidacionActual) then
            exit;
        if Liq."No. Empleado" <> NoEmpleado then
            exit;
        if not (Liq.Estado in [Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada]) then
            exit;

        CargarVersionesRegistradas(NoLiquidacionActual, Uso, VersionesActuales);
    end;

    local procedure CargarVersionesRegistradas(NoLiquidacion: Code[20]; var Uso: Record "Uso Parámetro Liq."; var VersionesConfirmadas: Record "Parámetro Vigente" temporary)
    begin
        // El llamador ya confirmó y bloqueó la cabecera activa. Restablecer filtros/clave
        // y pedir UpdLock explícito conserva sus usos hasta terminar la transacción.
        // Sólo se lee este documento por su PK, sin buscar otros recibos.
        Uso.Reset();
        Uso.ReadIsolation := IsolationLevel::UpdLock;
        Uso.SetRange("No. Liquidación", NoLiquidacion);
        Uso.SetLoadFields("Cód. Parámetro Base", "Cód. Parámetro", "Vigencia Desde");
        if Uso.FindSet() then
            repeat
                // La PK temporal conserva los tres componentes sin concatenaciones ni
                // ambigüedad entre nombres de variable, bases, claves o vigencias.
                if not VersionesConfirmadas.Get(Uso."Cód. Parámetro Base", Uso."Cód. Parámetro", Uso."Vigencia Desde") then begin
                    VersionesConfirmadas.Init();
                    VersionesConfirmadas."Cód. Parámetro Base" := Uso."Cód. Parámetro Base";
                    VersionesConfirmadas."Cód. Parámetro" := Uso."Cód. Parámetro";
                    VersionesConfirmadas."Vigencia Desde" := Uso."Vigencia Desde";
                    VersionesConfirmadas.Insert(false);
                end;
            until Uso.Next() = 0;
    end;

    local procedure ConfirmarPendientesDeTestigo(NoLiquidacion: Code[20]; var Uso: Record "Uso Parámetro Liq."; var Pendientes: Record "Parámetro Vigente" temporary; var CantidadPendientes: Integer): Integer
    var
        Confirmadas: Integer;
    begin
        // La query ya confirmó y protegió la cabecera. Sólo interesan triples exactas aún
        // pendientes: no almacenar versiones ajenas, duplicadas o ya resueltas por otro recibo.
        Uso.Reset();
        Uso.ReadIsolation := IsolationLevel::UpdLock;
        Uso.SetRange("No. Liquidación", NoLiquidacion);
        Uso.SetLoadFields("Cód. Parámetro Base", "Cód. Parámetro", "Vigencia Desde");
        if Uso.FindSet() then
            repeat
                if Pendientes.Get(Uso."Cód. Parámetro Base", Uso."Cód. Parámetro", Uso."Vigencia Desde") then begin
                    Pendientes.Delete(false);
                    CantidadPendientes -= 1;
                    Confirmadas += 1;
                    // AL no cortocircuita: salir antes de Next evita avanzar sin candidatas.
                    if CantidadPendientes = 0 then
                        exit(Confirmadas);
                end;
            until Uso.Next() = 0;
        exit(Confirmadas);
    end;

    local procedure TieneUsoExactoActivo(Version: Record "Parámetro Vigente"; var Uso: Record "Uso Parámetro Liq."; var Pendientes: Record "Parámetro Vigente" temporary; var CantidadPendientes: Integer; var DocumentosPrecargados: Dictionary of [Code[20], Boolean]; var PrecargarTestigos: Boolean): Boolean
    var
        UsosActivos: Query "Versiones Parámetro En Uso";
        Resultado: Boolean;
        DocumentoTestigo: Code[20];
    begin
        // SQL resuelve la unión y se detiene en el primer consumidor activo. No traer cada uso
        // a AL para hacer un Get de cabecera, ni contar todos los recibos que comparten versión.
        UsosActivos.SetRange(CodigoBase, Version."Cód. Parámetro Base");
        UsosActivos.SetRange(ClaveParametro, Version."Cód. Parámetro");
        UsosActivos.SetRange(VigenciaDesde, Version."Vigencia Desde");
        UsosActivos.Open();
        Resultado := UsosActivos.Read();
        if Resultado then
            DocumentoTestigo := UsosActivos.NumeroLiquidacion;
        UsosActivos.Close();

        // El testigo ya quedó activo y protegido por ReadExclusive en la query. Sus demás usos
        // acreditan otras versiones sin otra consulta de existencia. No se filtra el empleado
        // de la cabecera: el contrato exacto acepta cualquier consumidor activo de esa versión.
        // Sólo positivos y sólo esta llamada; una ausencia sigue pasando por el TOP1 original.
        if Resultado then
            if PrecargarTestigos then
                if CantidadPendientes > 0 then
                    if not DocumentosPrecargados.ContainsKey(DocumentoTestigo) then begin
                        // Cero aporte cambia sólo la política de lectura de esta base, nunca
                        // una respuesta de existencia. El próximo TOP1 se mantiene intacto.
                        if ConfirmarPendientesDeTestigo(DocumentoTestigo, Uso, Pendientes, CantidadPendientes) = 0 then
                            PrecargarTestigos := false;
                        DocumentosPrecargados.Add(DocumentoTestigo, true);
                    end;
        exit(Resultado);
    end;

    local procedure TieneUsoHistoricoCacheado(Version: Record "Parámetro Vigente"; var NombresPorBase: Dictionary of [Code[20], Text]; var HistoricoPorEmpleado: Dictionary of [Code[20], Dictionary of [Text, Boolean]]; var LiquidacionesHistoricas: Dictionary of [Code[20], Boolean]): Boolean
    var
        Param: Record "Parámetro";
        Nombre: Text;
    begin
        if not NombresPorBase.Get(Version."Cód. Parámetro Base", Nombre) then begin
            Nombre := Version."Cód. Parámetro Base";
            Param.SetLoadFields("Nombre Variable");
            if Param.Get(Version."Cód. Parámetro Base") then
                if Param."Nombre Variable" <> '' then
                    Nombre := Param."Nombre Variable";
            NombresPorBase.Add(Version."Cód. Parámetro Base", Nombre);
        end;
        if TieneNombreHistoricoCacheado(Version."No. Empleado", Nombre, HistoricoPorEmpleado, LiquidacionesHistoricas) then
            exit(true);
        if Nombre <> Version."Cód. Parámetro Base" then
            exit(TieneNombreHistoricoCacheado(Version."No. Empleado", Version."Cód. Parámetro Base", HistoricoPorEmpleado, LiquidacionesHistoricas));
        exit(false);
    end;

    local procedure TieneNombreHistoricoCacheado(NoEmpleado: Code[20]; Nombre: Text; var HistoricoPorEmpleado: Dictionary of [Code[20], Dictionary of [Text, Boolean]]; var LiquidacionesHistoricas: Dictionary of [Code[20], Boolean]): Boolean
    var
        PorNombre: Dictionary of [Text, Boolean];
        Resultado: Boolean;
    begin
        if Nombre = '' then
            exit(false);
        if HistoricoPorEmpleado.Get(NoEmpleado, PorNombre) then
            if PorNombre.Get(Nombre, Resultado) then
                exit(Resultado);

        // El histórico no identifica vigencia ni clave derivada. Su respuesta sólo depende
        // del nombre y del empleado de la LÍNEA; para una versión general no filtra empleado.
        Resultado := BuscarNombreHistoricoSinRegistro(NoEmpleado, Nombre, LiquidacionesHistoricas);
        PorNombre.Add(Nombre, Resultado);
        if HistoricoPorEmpleado.ContainsKey(NoEmpleado) then
            HistoricoPorEmpleado.Set(NoEmpleado, PorNombre)
        else
            HistoricoPorEmpleado.Add(NoEmpleado, PorNombre);
        exit(Resultado);
    end;

    local procedure BuscarNombreHistoricoSinRegistro(NoEmpleado: Code[20]; Nombre: Text; var LiquidacionesHistoricas: Dictionary of [Code[20], Boolean]): Boolean
    var
        Linea: Record "Línea Liquidación";
        Entradas: List of [Text];
        Entrada: Text;
        Coincide: Boolean;
    begin
        Linea.SetLoadFields("No. Liquidación", "Fuente Parámetros");
        if NoEmpleado <> '' then
            Linea.SetRange("No. Empleado", NoEmpleado);
        // Sustituir antes de aplicar el filtro: SetFilter con '*%1*' puede buscar el %1 literal.
        Linea.SetFilter("Fuente Parámetros", StrSubstNo('*%1*', 'VAR:' + Nombre));
        if Linea.FindSet() then
            repeat
                Coincide := false;
                Entradas := Linea."Fuente Parámetros".Split('|');
                foreach Entrada in Entradas do
                    if (Entrada = 'VAR:' + Nombre) or (Entrada = 'VAR:' + Nombre + '_ESFCY') then
                        Coincide := true;
                if Coincide then
                    if EsLiquidacionHistoricaActiva(Linea."No. Liquidación", LiquidacionesHistoricas) then
                        exit(true);
            until Linea.Next() = 0;
        exit(false);
    end;

    local procedure EsLiquidacionHistoricaActiva(Numero: Code[20]; var LiquidacionesHistoricas: Dictionary of [Code[20], Boolean]): Boolean
    var
        Liq: Record "Liquidación";
        Uso: Record "Uso Parámetro Liq.";
        Resultado: Boolean;
    begin
        if LiquidacionesHistoricas.Get(Numero, Resultado) then
            exit(Resultado);
        Liq.SetLoadFields(Estado);
        if Liq.Get(Numero) then
            if Liq.Estado in [Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada] then begin
                Uso.SetRange("No. Liquidación", Numero);
                // Cualquier uso registrado excluye TODO el recibo del respaldo histórico,
                // aunque sea de otro parámetro: esa corrida ya declara sus versiones exactas.
                Resultado := Uso.IsEmpty();
            end;
        LiquidacionesHistoricas.Add(Numero, Resultado);
        exit(Resultado);
    end;

    procedure TieneUsoActivo(Version: Record "Parámetro Vigente"): Boolean
    var
        Uso: Record "Uso Parámetro Liq.";
        Liq: Record "Liquidación";
        Param: Record "Parámetro";
        Nombre: Text;
    begin
        Uso.SetCurrentKey("Cód. Parámetro", "Vigencia Desde", "No. Liquidación");
        Uso.SetRange("Cód. Parámetro Base", Version."Cód. Parámetro Base");
        Uso.SetRange("Cód. Parámetro", Version."Cód. Parámetro");
        Uso.SetRange("Vigencia Desde", Version."Vigencia Desde");
        if Uso.FindSet() then
            repeat
                if Liq.Get(Uso."No. Liquidación") then
                    if Liq.Estado in [Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada] then
                        exit(true);
            until Uso.Next() = 0;

        Nombre := Version."Cód. Parámetro Base";
        if Param.Get(Version."Cód. Parámetro Base") then
            if Param."Nombre Variable" <> '' then
                Nombre := Param."Nombre Variable";
        if TieneUsoHistoricoSinRegistro(Version, Nombre) then
            exit(true);
        // También protege el nombre antiguo cuando se vació/renombró la cabecera.
        if Nombre <> Version."Cód. Parámetro Base" then
            exit(TieneUsoHistoricoSinRegistro(Version, Version."Cód. Parámetro Base"));
        exit(false);
    end;

    local procedure TieneUsoHistoricoSinRegistro(Version: Record "Parámetro Vigente"; Nombre: Text): Boolean
    var
        Linea: Record "Línea Liquidación";
        Liq: Record "Liquidación";
        Uso: Record "Uso Parámetro Liq.";
        Entradas: List of [Text];
        Entrada: Text;
        Coincide: Boolean;
    begin
        if Nombre = '' then
            exit(false);
        Linea.SetLoadFields("No. Liquidación", "Fuente Parámetros");
        if Version."No. Empleado" <> '' then
            Linea.SetRange("No. Empleado", Version."No. Empleado");
        // Sustituir antes de aplicar el filtro: SetFilter con '*%1*' puede buscar el %1 literal.
        Linea.SetFilter("Fuente Parámetros", StrSubstNo('*%1*', 'VAR:' + Nombre));
        if Linea.FindSet() then
            repeat
                Coincide := false;
                Entradas := Linea."Fuente Parámetros".Split('|');
                foreach Entrada in Entradas do
                    if (Entrada = 'VAR:' + Nombre) or (Entrada = 'VAR:' + Nombre + '_ESFCY') then
                        Coincide := true;
                if Coincide then
                    if Liq.Get(Linea."No. Liquidación") then
                        if Liq.Estado in [Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada] then begin
                            Uso.SetRange("No. Liquidación", Liq."No.");
                            // Una corrida con registro usa sus versiones exactas, no una resolución
                            // actual que puede haber cambiado desde que se calculó.
                            if Uso.IsEmpty() then
                                exit(true);
                        end;
            until Linea.Next() = 0;
        exit(false);
    end;

    procedure RevertirAprobacion(var Liq: Record "Liquidación"): Boolean
    begin
        if Liq.Estado <> Liq.Estado::Aprobada then
            Error(ErrSoloAprobada);
        if not Confirm(MsgConfirmarRevertir, false) then
            exit(false);
        RevertirAprobacionSinConfirmar(Liq);
        exit(true);
    end;

    /// <summary>Revierte la aprobación sin preguntar: la usa la reversión en lote, que ya pidió su propia confirmación.</summary>
    procedure RevertirAprobacionSinConfirmar(var Liq: Record "Liquidación")
    var
        LinLiq: Record "Línea Liquidación";
        GestPrest: Codeunit "Gestión Préstamos";
    begin
        Registro.Iniciar("Tipo Proceso Liq."::"Reversión Aprobación", Liq);
        Liq.Estado := Liq.Estado::Calculada;
        Liq.Modify(true);
        LinLiq.SetRange("No. Liquidación", Liq."No.");
        LinLiq.ModifyAll(Estado, Liq.Estado::Calculada);
        GestPrest.RevertirCuotasLiquidacion(Liq."No.");
        Registro.Info("Categoría Registro Liq."::Estado, RegRevertidaTxt);
        Registro.Finalizar();
    end;

    var
        Registro: Codeunit "Registro Procesos Liq.";
        FPermitirFueraDeOrden: Boolean;
        RegAprobadaTxt: Label 'Liquidación aprobada. Las cuotas de préstamo asociadas quedaron marcadas como aplicadas.';
        RegReabiertaTxt: Label 'Liquidación reabierta a Borrador. Se revirtieron cuotas de préstamo y se liberaron las novedades aplicadas.';
        RegRevertidaTxt: Label 'Aprobación revertida: la liquidación volvió a Calculada.';
        ErrSoloCalculada: Label 'Solo se pueden aprobar liquidaciones en estado Calculada.';
        ErrSoloCalculadaReabrir: Label 'Solo se puede reabrir una liquidación en estado Calculada.';
        ErrSoloAprobada: Label 'Solo se puede revertir una liquidación en estado Aprobada.';
        MotBloqueoPosterior: Label '%1: el empleado tiene calculada la liquidación posterior %2 (período %3)', Comment = '%1=liquidación, %2=posterior, %3=período de la posterior';
        MotBloqueoFrancos: Label '%1: sus francos los consume la liquidación %2, que no está en la selección', Comment = '%1=liquidación, %2=consumidora';
        ErrPosterioresAlReabrir: Label 'No se puede reabrir %1 (período %2) porque el empleado ya tiene liquidado el período %4 en la liquidación %3, del %5.\\Reabrir libera las novedades aplicadas y desmarca las cuotas de préstamo de esta liquidación: con una posterior ya calculada, el próximo cálculo del empleado se las vuelve a llevar —la misma cuota descontada dos veces, la misma novedad liquidada dos veces—. Además las líneas quedan en Borrador, y los acumuladores anuales y del período no cuentan Borrador.\\Usá "Recalcular en cadena" para rehacer ésta y todas las posteriores en orden.', Comment = '%1=liq actual, %2=período actual, %3=liq posterior, %4=período posterior, %5=fecha';
        MsgConfirmarRevertir: Label 'Esta liquidación ya fue aprobada. ¿Confirma que desea revertir la aprobación y volver al estado Calculada?';
}
