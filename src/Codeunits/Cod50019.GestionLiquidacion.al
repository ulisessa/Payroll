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
        UsedVarNames: List of [Text];
        Entries: List of [Text];
        Entry: Text;
        VarName: Text;
        FechaRef: Date;
        CodEfectivo: Code[50];
        VigDesde: Date;
    begin
        if Liq.Estado <> Liq.Estado::Calculada then
            Error(ErrSoloCalculadaReabrir);
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

        // Release EnUso on the exact version used, only if no other active liq still references it
        foreach VarName in UsedVarNames do begin
            Param.SetRange("Nombre Variable", VarName);
            if Param.FindFirst() then begin
                if Param."Sufijo Empleado" then
                    CodEfectivo := Param.Código + '_' + Liq."No. Empleado"
                else if Param."Sufijo CCT" then
                    CodEfectivo := Param.Código + '_' + Liq."Cód. Convenio" + '_' + Liq."Cód. Categoría"
                else if Param."Sufijo Convenio" then
                    CodEfectivo := Param.Código + '_' + Liq."Cód. Convenio"
                else
                    CodEfectivo := Param.Código;

                ParamVig.SetRange("Cód. Parámetro Base", Param.Código);
                ParamVig.SetRange("Cód. Parámetro", CodEfectivo);
                ParamVig.SetFilter("Vigencia Desde", '<=%1', FechaRef);
                if ParamVig.FindLast() and ParamVig."En Uso" then begin
                    VigDesde := ParamVig."Vigencia Desde";
                    if not IsVersionUsedByOtherLiq(Param, CodEfectivo, VigDesde, VarName, Liq."No.") then begin
                        ParamVig."En Uso" := false;
                        ParamVig.Modify();
                    end;
                end;
            end;
        end;
    end;

    // Returns true if any other active (Calculada|Aprobada|Contabilizada) liquidation
    // references VAR:VarName AND its Período would resolve to the same ParamVig version
    // (same CodEfectivo + VigDesde), meaning this version must stay locked.
    local procedure IsVersionUsedByOtherLiq(
        Param: Record "Parámetro";
        CodEfectivo: Code[50];
        VigDesde: Date;
        VarName: Text;
        ExcludeNo: Code[20]): Boolean
    var
        OtraLiq: Record "Liquidación";
        OtraPeriodo: Record "Período Liquidación";
        OtraJob: Record Job;
        TipoLiqRec: Record "Tipo Liquidación";
        OtraLinLiq: Record "Línea Liquidación";
        OtraParamVig: Record "Parámetro Vigente";
        OtraCodEfectivo: Code[50];
        OtraFechaRef: Date;
        Entries: List of [Text];
        Entry: Text;
        VarFound: Boolean;
    begin
        OtraLiq.SetFilter("No.", '<>%1', ExcludeNo);
        OtraLiq.SetFilter(Estado, '%1|%2|%3',
            OtraLiq.Estado::Calculada, OtraLiq.Estado::Aprobada, OtraLiq.Estado::Contabilizada);
        if not OtraLiq.FindSet() then exit(false);
        repeat
            if Param."Sufijo Empleado" then
                OtraCodEfectivo := Param.Código + '_' + OtraLiq."No. Empleado"
            else if Param."Sufijo CCT" then
                OtraCodEfectivo := Param.Código + '_' + OtraLiq."Cód. Convenio" + '_' + OtraLiq."Cód. Categoría"
            else if Param."Sufijo Convenio" then
                OtraCodEfectivo := Param.Código + '_' + OtraLiq."Cód. Convenio"
            else
                OtraCodEfectivo := CodEfectivo;

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
                    if OtraParamVig.FindLast() and (OtraParamVig."Vigencia Desde" = VigDesde) then begin
                        VarFound := false;
                        OtraLinLiq.SetRange("No. Liquidación", OtraLiq."No.");
                        if OtraLinLiq.FindSet() then
                            repeat
                                Entries := OtraLinLiq."Fuente Parámetros".Split('|');
                                foreach Entry in Entries do
                                    if Entry = 'VAR:' + VarName then
                                        VarFound := true;
                            until OtraLinLiq.Next() = 0;
                        if VarFound then exit(true);
                    end;
                end;
            end;
        until OtraLiq.Next() = 0;
        exit(false);
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
        RegAprobadaTxt: Label 'Liquidación aprobada. Las cuotas de préstamo asociadas quedaron marcadas como aplicadas.';
        RegReabiertaTxt: Label 'Liquidación reabierta a Borrador. Se revirtieron cuotas de préstamo y se liberaron las novedades aplicadas.';
        RegRevertidaTxt: Label 'Aprobación revertida: la liquidación volvió a Calculada.';
        ErrSoloCalculada: Label 'Solo se pueden aprobar liquidaciones en estado Calculada.';
        ErrSoloCalculadaReabrir: Label 'Solo se puede reabrir una liquidación en estado Calculada.';
        ErrSoloAprobada: Label 'Solo se puede revertir una liquidación en estado Aprobada.';
        MsgConfirmarRevertir: Label 'Esta liquidación ya fue aprobada. ¿Confirma que desea revertir la aprobación y volver al estado Calculada?';
}
