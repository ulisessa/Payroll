namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;
using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
using Microsoft.Foundation.NoSeries;

codeunit 50018 "Proceso Liq. Por Lotes"
{
    // Batch creation and calculation of liquidations.
    // Called from Job Card actions (per-project) and from Lanzador Liquidaciones page (multi-project).

    procedure CrearPorProyecto(var Job: Record Job; CodPeriodo: Code[10]; TipoLiq: Enum "Tipo Liq."): Integer
    var
        Periodo: Record "Período Liquidación";
        Personal: Record "Personal Proyecto";
        Creadas: Integer;
    begin
        Periodo.Get(CodPeriodo);
        if Periodo.Estado = Periodo.Estado::Cerrado then
            Error(ErrPeriodoCerrado, CodPeriodo);

        AplicarFiltroPersonal(Personal, Job, TipoLiq);
        if not Personal.FindSet() then
            exit(0);

        repeat
            if not LiqExiste(Personal."No. Empleado", Personal."No. Proyecto", CodPeriodo, TipoLiq) then begin
                InsertarLiquidacion(Personal, CodPeriodo, TipoLiq);
                Creadas += 1;
            end;
        until Personal.Next() = 0;

        exit(Creadas);
    end;

    procedure CrearPorPeriodo(CodPeriodo: Code[10]; TipoLiq: Enum "Tipo Liq."; TipoProyecto: Integer): Integer
    var
        Periodo: Record "Período Liquidación";
        Job: Record Job;
        Creadas: Integer;
    begin
        Periodo.Get(CodPeriodo);
        if Periodo.Estado = Periodo.Estado::Cerrado then
            Error(ErrPeriodoCerrado, CodPeriodo);

        AplicarFiltroJobs(Job, TipoLiq, Periodo, TipoProyecto);
        if not Job.FindSet() then begin
            Message(MsgNinguno);
            exit(0);
        end;

        repeat
            Creadas += CrearPorProyecto(Job, CodPeriodo, TipoLiq);
        until Job.Next() = 0;

        exit(Creadas);
    end;

    procedure CalcularPorPeriodo(CodPeriodo: Code[10]; TipoLiq: Enum "Tipo Liq."): Integer
    var
        Liq: Record "Liquidación";
        Motor: Codeunit "Motor Liquidación";
        Calculadas: Integer;
    begin
        Liq.SetRange("Cód. Período", CodPeriodo);
        Liq.SetRange("Tipo Liquidación", TipoLiq);
        Liq.SetFilter(Estado, '%1|%2|%3', Liq.Estado::Borrador, Liq.Estado::Calculada, Liq.Estado::Aprobada);
        if not Liq.FindSet(true) then
            exit(0);
        repeat
            Motor.LiquidarRecord(Liq);
            Calculadas += 1;
        until Liq.Next() = 0;
        exit(Calculadas);
    end;

    local procedure AplicarFiltroJobs(var Job: Record Job; TipoLiq: Enum "Tipo Liq."; Periodo: Record "Período Liquidación"; TipoProyecto: Integer)
    begin
        Job.Reset();

        // TipoProyecto: 0=Todos, 1=Productivo, 2=Improductivo (matches Job.Tipo option ordinals)
        if TipoProyecto > 0 then
            Job.SetRange(Tipo, TipoProyecto);

        case TipoLiq of
            TipoLiq::"Cierre Marea":
                // Voyages whose return date falls within the period
                Job.SetRange("Ending Date", Periodo."Fecha Desde", Periodo."Fecha Hasta");
            else begin
                // Devengados, Regular and all others: open jobs started before period end
                Job.SetRange(Status, Job.Status::Open);
                Job.SetFilter("Starting Date", '<=%1', Periodo."Fecha Hasta");
            end;
        end;
    end;

    local procedure AplicarFiltroPersonal(var Personal: Record "Personal Proyecto"; var Job: Record Job; TipoLiq: Enum "Tipo Liq.")
    begin
        Personal.Reset();
        Personal.SetRange("No. Proyecto", Job."No.");
        case TipoLiq of
            TipoLiq::"Cierre Marea":
                // Discharge before voyage start → excluded; still active or discharged on/after start → included.
                Personal.SetFilter("Fecha Baja", '%1|>=%2', 0D, Job."Starting Date");
            else
                Personal.SetRange("Fecha Baja", 0D);
        end;
    end;

    local procedure LiqExiste(EmpNo: Code[20]; JobNo: Code[20]; CodPeriodo: Code[10]; TipoLiq: Enum "Tipo Liq."): Boolean
    var
        Liq: Record "Liquidación";
    begin
        Liq.SetRange("No. Empleado", EmpNo);
        Liq.SetRange("No. Proyecto", JobNo);
        Liq.SetRange("Cód. Período", CodPeriodo);
        Liq.SetRange("Tipo Liquidación", TipoLiq);
        exit(not Liq.IsEmpty());
    end;

    local procedure InsertarLiquidacion(Personal: Record "Personal Proyecto"; CodPeriodo: Code[10]; TipoLiq: Enum "Tipo Liq.")
    var
        Liq: Record "Liquidación";
        Emp: Record Employee;
        Periodo: Record "Período Liquidación";
    begin
        Liq.Init();
        Liq."No." := NextLiqNo();
        Liq."No. Empleado" := Personal."No. Empleado";
        if Emp.Get(Personal."No. Empleado") then
            Liq."Nombre Empleado" := CopyStr(Emp."First Name" + ' ' + Emp."Last Name", 1, MaxStrLen(Liq."Nombre Empleado"));
        Liq."No. Proyecto" := Personal."No. Proyecto";
        Liq."Cód. Período" := CodPeriodo;
        Liq."Cód. Convenio" := Personal."Cód. Convenio";
        Liq."Cód. Categoría" := Personal."Cód. Categoría";
        if Periodo.Get(CodPeriodo) then
            Liq."Fecha Liquidación" := Periodo."Fecha Hasta"
        else
            Liq."Fecha Liquidación" := WorkDate();
        Liq."Tipo Liquidación" := TipoLiq;
        Liq.Estado := Liq.Estado::Borrador;
        Liq.Insert(true);
    end;

    procedure NextLiqNo(): Code[20]
    var
        HRSetup: Record "Human Resources Setup";
        NoSeries: Codeunit "No. Series";
    begin
        HRSetup.Get();
        if HRSetup."Cód. Serie Liq." = '' then
            Error(ErrSerieNoConfigurada);
        exit(NoSeries.GetNextNo(HRSetup."Cód. Serie Liq.", WorkDate(), true));
    end;

    var
        ErrPeriodoCerrado: Label 'El período %1 está cerrado.';
        ErrSerieNoConfigurada: Label 'La serie de numeración de liquidaciones no está configurada. Vaya a Configuración de RR.HH. y complete el campo "Serie Núm. Liquidaciones".';
        MsgNinguno: Label 'No se encontraron proyectos con personal activo para el período y tipo indicados.';
}
