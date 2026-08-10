namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;
using Microsoft.HumanResources.Employee;
using Microsoft.HumanResources.Setup;
using Microsoft.Foundation.NoSeries;

codeunit 50050 "Proceso Liq. Por Lote"
{
    // Batch creation and calculation of liquidations.
    // Called from Job Card actions (per-project) and from Lanzador Liquidaciones page (multi-project).

    procedure CrearPorProyecto(var Job: Record Job; CodPeriodo: Code[10]; TipoLiq: Code[20]): Integer
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

    // Creates Cierre Marea liquidations for a voyage, deriving the reporting period from the
    // voyage arrival date (project Ending Date). No period prompt: a tide settles at arrival.
    procedure CrearCierreMarea(var Job: Record Job): Integer
    var
        TipoLiqRec: Record "Tipo Liquidación";
        CodPeriodo: Code[10];
    begin
        if Job."Ending Date" = 0D then
            Error(ErrSinArribo, Job."No.");
        CodPeriodo := DerivarPeriodoPorFecha(Job."Ending Date");
        exit(CrearPorProyecto(Job, CodPeriodo, TipoLiqRec.CodigoArribo()));
    end;

    // Returns the period whose [Fecha Desde, Fecha Hasta] range contains the given date.
    local procedure DerivarPeriodoPorFecha(Fecha: Date): Code[10]
    var
        Periodo: Record "Período Liquidación";
    begin
        Periodo.SetFilter("Fecha Desde", '<=%1', Fecha);
        Periodo.SetFilter("Fecha Hasta", '>=%1', Fecha);
        if not Periodo.FindFirst() then
            Error(ErrSinPeriodo, Fecha);
        exit(Periodo.Código);
    end;

    // Creates Regular liquidations (per-employee, no project) for employees who were in a Francos state
    // during the period. Francos are enjoyed in port between mareas, so these employees have no project
    // assignment and are not reached by the project-based creation. Skips employees who already have a
    // Regular for the period (e.g. a project-based one).
    procedure CrearRegularEmpleadosEnFrancos(CodPeriodo: Code[10]): Integer
    var
        Periodo: Record "Período Liquidación";
        Estado: Record "Estado Empleado";
        CodEst: Record "Cód. Estado Empleado";
        TipoLiqRec: Record "Tipo Liquidación";
        CodTipoLiq: Code[20];
        Procesados: List of [Code[20]];
        Creadas: Integer;
    begin
        Periodo.Get(CodPeriodo);
        if Periodo.Estado = Periodo.Estado::Cerrado then
            Error(ErrPeriodoCerrado, CodPeriodo);

        CodTipoLiq := TipoLiqRec.CodigoFrancosPuerto();
        if CodTipoLiq = '' then exit(0);

        Estado.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        Estado.SetRange("Tipo Entidad", Estado."Tipo Entidad"::Empleado);
        Estado.SetFilter("Fecha Inicio", '<=%1', Periodo."Fecha Hasta");
        if Estado.FindSet() then
            repeat
                if not Procesados.Contains(Estado."No. Empleado") then
                    if CodEst.Get(Estado."Cód. Estado") and (CodEst."Tipo Estado" = CodEst."Tipo Estado"::Francos) then
                        if Estado.FechaFinEfectiva() >= Periodo."Fecha Desde" then begin
                            Procesados.Add(Estado."No. Empleado");
                            if not LiqExisteEmpleado(Estado."No. Empleado", CodPeriodo, CodTipoLiq) then begin
                                InsertarLiquidacionEmpleado(Estado."No. Empleado", CodPeriodo, CodTipoLiq);
                                Creadas += 1;
                            end;
                        end;
            until Estado.Next() = 0;

        exit(Creadas);
    end;

    procedure CrearPorPeriodo(CodPeriodo: Code[10]; TipoLiq: Code[20]; TipoProyecto: Integer): Integer
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

    procedure CalcularPorPeriodo(CodPeriodo: Code[10]; TipoLiq: Code[20]): Integer
    var
        Liq: Record "Liquidación";
        Motor: Codeunit "Motor Liquidación";
        Registro: Codeunit "Registro Procesos Liq.";
        Progress: Dialog;
        Calculadas: Integer;
        Total: Integer;
    begin
        Liq.SetRange("Cód. Período", CodPeriodo);
        Liq.SetRange("Cód. Tipo Liq.", TipoLiq);
        Liq.SetFilter(Estado, '%1|%2|%3', Liq.Estado::Borrador, Liq.Estado::Calculada, Liq.Estado::Aprobada);
        Total := Liq.Count();
        if Total = 0 then
            exit(0);
        Progress.Open(DlgCalculando);
        // Toda la corrida comparte sesión: desde cualquier registro se puede ver el lote completo.
        Registro.IniciarSesion();
        Liq.FindSet(true);
        repeat
            Calculadas += 1;
            Progress.Update(1, Liq."Nombre Empleado");
            Progress.Update(2, Calculadas);
            Progress.Update(3, Total);
            // Sin relanzar: una liquidación que falla queda anotada en su registro y el lote sigue,
            // en vez de abortar y perder todo lo calculado hasta ese punto.
            if Motor.LiquidarConRegistro(Liq) then;
        until Liq.Next() = 0;
        Registro.CerrarSesion();
        Progress.Close();
        exit(Calculadas);
    end;

    local procedure AplicarFiltroJobs(var Job: Record Job; TipoLiq: Code[20]; Periodo: Record "Período Liquidación"; TipoProyecto: Integer)
    var
        TipoLiqRec: Record "Tipo Liquidación";
    begin
        Job.Reset();

        // TipoProyecto: 0=Todos, 1=Productivo, 2=Improductivo (matches Job.Tipo option ordinals)
        if TipoProyecto > 0 then
            Job.SetRange(Tipo, TipoProyecto);

        if TipoLiqRec.EsArribo(TipoLiq) then
            // Voyages whose return date falls within the period
            Job.SetRange("Ending Date", Periodo."Fecha Desde", Periodo."Fecha Hasta")
        else begin
            // Devengados, Regular and all others: open jobs started before period end
            Job.SetRange(Status, Job.Status::Open);
            Job.SetFilter("Starting Date", '<=%1', Periodo."Fecha Hasta");
        end;
    end;

    local procedure AplicarFiltroPersonal(var Personal: Record "Personal Proyecto"; var Job: Record Job; TipoLiq: Code[20])
    var
        TipoLiqRec: Record "Tipo Liquidación";
    begin
        Personal.Reset();
        Personal.SetRange("No. Proyecto", Job."No.");
        if TipoLiqRec.EsArribo(TipoLiq) then
            // Discharge before voyage start → excluded; still active or discharged on/after start → included.
            Personal.SetFilter("Fecha Baja", '%1|>=%2', 0D, Job."Starting Date")
        else
            Personal.SetRange("Fecha Baja", 0D);
    end;

    local procedure LiqExiste(EmpNo: Code[20]; JobNo: Code[20]; CodPeriodo: Code[10]; TipoLiq: Code[20]): Boolean
    var
        Liq: Record "Liquidación";
    begin
        Liq.SetRange("No. Empleado", EmpNo);
        Liq.SetRange("No. Proyecto", JobNo);
        Liq.SetRange("Cód. Período", CodPeriodo);
        Liq.SetRange("Cód. Tipo Liq.", TipoLiq);
        exit(not Liq.IsEmpty());
    end;

    // Any liquidation of this type for the employee+period, regardless of project (avoids a duplicate
    // project-less liquidation when a project-based one already covers the employee this period).
    local procedure LiqExisteEmpleado(EmpNo: Code[20]; CodPeriodo: Code[10]; TipoLiq: Code[20]): Boolean
    var
        Liq: Record "Liquidación";
    begin
        Liq.SetRange("No. Empleado", EmpNo);
        Liq.SetRange("Cód. Período", CodPeriodo);
        Liq.SetRange("Cód. Tipo Liq.", TipoLiq);
        exit(not Liq.IsEmpty());
    end;

    // Creates a project-less liquidation for an employee. Convenio/categoría come from the employee's most
    // recent project assignment as of the period (the CCT they are enrolled under) — a blank convenio would
    // filter out every CCT-restricted concept. Falls back to the employee card.
    local procedure InsertarLiquidacionEmpleado(EmpNo: Code[20]; CodPeriodo: Code[10]; TipoLiq: Code[20])
    var
        Liq: Record "Liquidación";
        Emp: Record Employee;
        Periodo: Record "Período Liquidación";
        Convenio: Code[20];
        Categoria: Code[20];
    begin
        Periodo.Get(CodPeriodo);
        ConvenioUltimaAsignacion(EmpNo, Periodo."Fecha Hasta", Convenio, Categoria);

        Liq.Init();
        Liq."No." := NextLiqNo();
        Liq."No. Empleado" := EmpNo;
        if Emp.Get(EmpNo) then begin
            Liq."Nombre Empleado" := CopyStr(Emp."First Name" + ' ' + Emp."Last Name", 1, MaxStrLen(Liq."Nombre Empleado"));
            if Convenio = '' then Convenio := Emp."Cód. Convenio";
            if Categoria = '' then Categoria := Emp."Cód. Categoría";
        end;
        Liq."Cód. Convenio" := Convenio;
        Liq."Cód. Categoría" := Categoria;
        Liq."Cód. Período" := CodPeriodo;
        if Periodo."Fecha Hasta" <> 0D then
            Liq."Fecha Liquidación" := Periodo."Fecha Hasta"
        else
            Liq."Fecha Liquidación" := WorkDate();
        Liq."Cód. Tipo Liq." := TipoLiq;
        Liq.Estado := Liq.Estado::Borrador;
        Liq.Insert(true);
    end;

    // Convenio/categoría of the employee's latest project assignment with Fecha Alta on/before FechaTope.
    local procedure ConvenioUltimaAsignacion(EmpNo: Code[20]; FechaTope: Date; var Convenio: Code[20]; var Categoria: Code[20])
    var
        PersProy: Record "Personal Proyecto";
        UltimaAlta: Date;
    begin
        Convenio := '';
        Categoria := '';
        PersProy.SetRange("No. Empleado", EmpNo);
        PersProy.SetFilter("Fecha Alta Asignación", '<=%1', FechaTope);
        if PersProy.FindSet() then
            repeat
                if PersProy."Fecha Alta Asignación" >= UltimaAlta then begin
                    UltimaAlta := PersProy."Fecha Alta Asignación";
                    Convenio := PersProy."Cód. Convenio";
                    Categoria := PersProy."Cód. Categoría";
                end;
            until PersProy.Next() = 0;
    end;

    local procedure InsertarLiquidacion(Personal: Record "Personal Proyecto"; CodPeriodo: Code[10]; TipoLiq: Code[20])
    var
        Liq: Record "Liquidación";
        Emp: Record Employee;
        Periodo: Record "Período Liquidación";
        Job: Record Job;
        TipoLiqRec: Record "Tipo Liquidación";
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
        // A Cierre Marea settles at the voyage arrival date; other types at period end.
        if TipoLiqRec.EsArribo(TipoLiq) and Job.Get(Personal."No. Proyecto") and (Job."Ending Date" <> 0D) then
            Liq."Fecha Liquidación" := Job."Ending Date"
        else
            if Periodo.Get(CodPeriodo) then
                Liq."Fecha Liquidación" := Periodo."Fecha Hasta"
            else
                Liq."Fecha Liquidación" := WorkDate();
        Liq."Cód. Tipo Liq." := TipoLiq;
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
        DlgCalculando: Label 'Calculando liquidaciones...\\Empleado: #1########\\Progreso: #2### de #3###';
        ErrPeriodoCerrado: Label 'El período %1 está cerrado.';
        ErrSerieNoConfigurada: Label 'La serie de numeración de liquidaciones no está configurada. Vaya a Configuración de RR.HH. y complete el campo "Serie Núm. Liquidaciones".';
        MsgNinguno: Label 'No se encontraron proyectos con personal activo para el período y tipo indicados.';
        ErrSinArribo: Label 'El proyecto %1 no tiene fecha de arribo (Ending Date). Cargue la fecha de llegada a puerto antes de crear el Cierre de Marea.';
        ErrSinPeriodo: Label 'No existe un período de liquidación que contenga la fecha de arribo %1. Cree el período de ese mes primero.';
}
