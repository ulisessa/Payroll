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

    procedure Reabrir(var Liq: Record "Liquidación")
    var
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
    begin
        Uso.SetRange("No. Liquidación", Liq."No.");
        if Uso.IsEmpty() then
            exit(false);

        Uso.FindSet();
        repeat
            SigueEnUso := false;
            UsoOtra.SetCurrentKey("Cód. Parámetro", "Vigencia Desde", "No. Liquidación");
            UsoOtra.SetRange("Cód. Parámetro", Uso."Cód. Parámetro");
            UsoOtra.SetRange("Vigencia Desde", Uso."Vigencia Desde");
            UsoOtra.SetFilter("No. Liquidación", '<>%1', Liq."No.");
            if UsoOtra.FindSet() then
                repeat
                    if OtraLiq.Get(UsoOtra."No. Liquidación") then
                        if OtraLiq.Estado in [OtraLiq.Estado::Calculada, OtraLiq.Estado::Aprobada, OtraLiq.Estado::Contabilizada] then
                            SigueEnUso := true;
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

    procedure RevertirAprobacion(var Liq: Record "Liquidación"): Boolean
    var
        LinLiq: Record "Línea Liquidación";
        GestPrest: Codeunit "Gestión Préstamos";
    begin
        if Liq.Estado <> Liq.Estado::Aprobada then
            Error(ErrSoloAprobada);
        if not Confirm(MsgConfirmarRevertir, false) then
            exit(false);
        Registro.Iniciar("Tipo Proceso Liq."::"Reversión Aprobación", Liq);
        Liq.Estado := Liq.Estado::Calculada;
        Liq.Modify(true);
        LinLiq.SetRange("No. Liquidación", Liq."No.");
        LinLiq.ModifyAll(Estado, Liq.Estado::Calculada);
        GestPrest.RevertirCuotasLiquidacion(Liq."No.");
        Registro.Info("Categoría Registro Liq."::Estado, RegRevertidaTxt);
        Registro.Finalizar();
        exit(true);
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
        ErrPosterioresAlReabrir: Label 'No se puede reabrir %1 (período %2) porque el empleado ya tiene liquidado el período %4 en la liquidación %3, del %5.\\Reabrir libera las novedades aplicadas y desmarca las cuotas de préstamo de esta liquidación: con una posterior ya calculada, el próximo cálculo del empleado se las vuelve a llevar —la misma cuota descontada dos veces, la misma novedad liquidada dos veces—. Además las líneas quedan en Borrador, y los acumuladores anuales y del período no cuentan Borrador.\\Usá "Recalcular en cadena" para rehacer ésta y todas las posteriores en orden.', Comment = '%1=liq actual, %2=período actual, %3=liq posterior, %4=período posterior, %5=fecha';
        MsgConfirmarRevertir: Label 'Esta liquidación ya fue aprobada. ¿Confirma que desea revertir la aprobación y volver al estado Calculada?';
}
