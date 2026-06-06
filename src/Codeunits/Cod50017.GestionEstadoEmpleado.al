namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

codeunit 50017 "Gestión Estado Empleado"
{
    // Enforces the no-gap, no-overlap invariant on Estado Empleado.
    // All state changes must go through SetEstado — never insert directly.

    procedure SetEstado(EmployeeNo: Code[20]; StateCode: Code[20]; StartDate: Date)
    var
        EstadoEmp: Record "Estado Empleado";
        EstadoCubierto: Record "Estado Empleado";
        CodEstado: Record "Cód. Estado Empleado";
        FechaFinNuevo: Date;
    begin
        if EmployeeNo = '' then Error(ErrEmpleado);
        if StartDate = 0D then Error(ErrFechaVacia);
        CodEstado.Get(StateCode);

        // Check whether StartDate falls within an existing closed state
        EstadoCubierto.SetRange("No. Empleado", EmployeeNo);
        EstadoCubierto.SetFilter("Fecha Inicio", '<=%1', StartDate);
        EstadoCubierto.SetFilter("Fecha Fin", '>=%1', StartDate);  // excludes open states (Fecha Fin = 0D)
        if EstadoCubierto.FindFirst() then begin
            ValidarNoHayLiquidacionesBloqueantes(EmployeeNo, StartDate, EstadoCubierto."Fecha Fin");
            if not Confirm(QstInsertarEnHistorial, false,
                           StartDate,
                           EstadoCubierto."Cód. Estado",
                           EstadoCubierto."Fecha Inicio",
                           EstadoCubierto."Fecha Fin",
                           StartDate - 1,
                           StateCode)
            then
                exit;
            FechaFinNuevo := EstadoCubierto."Fecha Fin";
            if EstadoCubierto."Fecha Inicio" = StartDate then
                EstadoCubierto.Delete(true)
            else begin
                EstadoCubierto."Fecha Fin" := StartDate - 1;
                EstadoCubierto.Modify(true);
            end;
        end else begin
            // No closed state covers StartDate — check the open (active) state
            EstadoEmp.SetRange("No. Empleado", EmployeeNo);
            EstadoEmp.SetRange("Fecha Fin", 0D);
            if EstadoEmp.FindFirst() then begin
                if StartDate = EstadoEmp."Fecha Inicio" then begin
                    // Replacing the open state at the same start date
                    ValidarNoHayLiquidacionesBloqueantes(EmployeeNo, StartDate, 0D);
                    if not Confirm(QstReemplazarEstadoActual, false,
                                   EstadoEmp."Cód. Estado",
                                   StartDate,
                                   StateCode)
                    then
                        exit;
                    EstadoEmp.Delete(true);
                end else if StartDate > EstadoEmp."Fecha Inicio" then begin
                    // Normal: extend timeline by closing the open state
                    EstadoEmp."Fecha Fin" := StartDate - 1;
                    EstadoEmp.Modify(true);
                end else
                    Error(ErrFecha, EstadoEmp."Fecha Inicio");
            end;
            FechaFinNuevo := 0D;
        end;

        // For vacation states, always compute the end date from seniority entitlement.
        if CodEstado."Tipo Estado" = CodEstado."Tipo Estado"::Vacaciones then
            FechaFinNuevo := StartDate + CalcDiasVacaciones(EmployeeNo, StartDate) - 1;

        Clear(EstadoEmp);
        EstadoEmp."No. Empleado" := EmployeeNo;
        EstadoEmp."Fecha Inicio" := StartDate;
        EstadoEmp."Cód. Estado" := StateCode;
        EstadoEmp."Fecha Fin" := FechaFinNuevo;
        EstadoEmp.Insert(true);
    end;

    procedure GetEstado(EmployeeNo: Code[20]; AsOfDate: Date; var EstadoEmp: Record "Estado Empleado"): Boolean
    begin
        EstadoEmp.SetRange("No. Empleado", EmployeeNo);
        EstadoEmp.SetFilter("Fecha Inicio", '<=%1', AsOfDate);
        // Fecha Fin = 0D (open) OR Fecha Fin >= AsOfDate
        EstadoEmp.SetFilter("Fecha Fin", '%1|>=%2', 0D, AsOfDate);
        exit(EstadoEmp.FindLast());
    end;

    procedure GetEstadoActual(EmployeeNo: Code[20]; var EstadoEmp: Record "Estado Empleado"): Boolean
    begin
        EstadoEmp.SetRange("No. Empleado", EmployeeNo);
        EstadoEmp.SetRange("Fecha Fin", 0D);
        exit(EstadoEmp.FindFirst());
    end;

    procedure TieneEstado(EmployeeNo: Code[20]): Boolean
    var
        EstadoEmp: Record "Estado Empleado";
    begin
        EstadoEmp.SetRange("No. Empleado", EmployeeNo);
        exit(not EstadoEmp.IsEmpty());
    end;

    procedure ValidarEstadoExiste(EmployeeNo: Code[20]; AsOfDate: Date)
    var
        EstadoEmp: Record "Estado Empleado";
    begin
        if not GetEstado(EmployeeNo, AsOfDate, EstadoEmp) then
            Error(ErrSinEstado, EmployeeNo, AsOfDate);
    end;

    // Returns total completed years of service as of FechaRef.
    // Sums all Alta→Baja periods plus Antigüedad Reconocida, then calculates full anniversary years.
    procedure CalcAntiguedadAlFecha(EmployeeNo: Code[20]; FechaRef: Date): Decimal
    var
        Emp: Record Employee;
        EstadoEmp: Record "Estado Empleado";
        CodEst: Record "Cód. Estado Empleado";
        FechaInicioEmpleo: Date;
        FechaVirtual: Date;
        TotalDias: Integer;
        DiasReconocidos: Integer;
        AnosCompletos: Integer;
        InEmpleo: Boolean;
    begin
        if not Emp.Get(EmployeeNo) then exit(0);

        EstadoEmp.SetRange("No. Empleado", EmployeeNo);
        EstadoEmp.SetCurrentKey("No. Empleado", "Fecha Inicio");
        EstadoEmp.SetFilter("Fecha Inicio", '<=%1', FechaRef);
        if EstadoEmp.FindSet() then
            repeat
                if CodEst.Get(EstadoEmp."Cód. Estado") then
                    case CodEst."Tipo Estado" of
                        CodEst."Tipo Estado"::Alta:
                            begin
                                InEmpleo := true;
                                FechaInicioEmpleo := EstadoEmp."Fecha Inicio";
                            end;
                        CodEst."Tipo Estado"::Baja:
                            if InEmpleo then begin
                                TotalDias += EstadoEmp."Fecha Inicio" - FechaInicioEmpleo;
                                InEmpleo := false;
                            end;
                    end;
            until EstadoEmp.Next() = 0;

        if InEmpleo then
            TotalDias += FechaRef - FechaInicioEmpleo;

        if (TotalDias = 0) and (Emp."Employment Date" <> 0D) then
            TotalDias := FechaRef - Emp."Employment Date";

        DiasReconocidos := Round(Emp."Antigüedad Reconocida" * 365.25, 1, '<');
        TotalDias += DiasReconocidos;

        if TotalDias <= 0 then exit(0);

        FechaVirtual := FechaRef - TotalDias;
        AnosCompletos := Date2DMY(FechaRef, 3) - Date2DMY(FechaVirtual, 3);
        if (Date2DMY(FechaRef, 2) < Date2DMY(FechaVirtual, 2)) or
           ((Date2DMY(FechaRef, 2) = Date2DMY(FechaVirtual, 2)) and
            (Date2DMY(FechaRef, 1) < Date2DMY(FechaVirtual, 1)))
        then
            AnosCompletos -= 1;
        exit(AnosCompletos);
    end;

    // Returns the number of vacation days the employee is entitled to per Art. 150 LCT,
    // based on seniority as of Dec 31 of the year in which FechaInicio falls (Art. 164 LCT).
    procedure CalcDiasVacaciones(EmployeeNo: Code[20]; FechaInicio: Date): Integer
    var
        Anios: Decimal;
        Fecha31Dic: Date;
    begin
        Fecha31Dic := DMY2Date(31, 12, Date2DMY(FechaInicio, 3));
        Anios := CalcAntiguedadAlFecha(EmployeeNo, Fecha31Dic);
        case true of
            Anios < 5:  exit(14);
            Anios < 10: exit(21);
            Anios < 20: exit(28);
            else        exit(35);
        end;
    end;

    local procedure ValidarNoHayLiquidacionesBloqueantes(EmployeeNo: Code[20]; FechaDesde: Date; FechaHasta: Date)
    var
        Liq: Record "Liquidación";
        Periodo: Record "Período Liquidación";
    begin
        Liq.SetRange("No. Empleado", EmployeeNo);
        Liq.SetFilter(Estado, '<>%1', Liq.Estado::Borrador);
        if not Liq.FindSet() then exit;
        repeat
            if Periodo.Get(Liq."Cód. Período") then
                if (Periodo."Fecha Hasta" >= FechaDesde) and
                   ((FechaHasta = 0D) or (Periodo."Fecha Desde" <= FechaHasta))
                then
                    Error(ErrLiquidacionesBloqueantes, Liq."Cód. Período", Liq."No.", Format(Liq.Estado));
        until Liq.Next() = 0;
    end;

    var
        ErrEmpleado: Label 'Debe especificar un empleado.';
        ErrFechaVacia: Label 'Debe especificar la fecha de inicio del nuevo estado.';
        ErrFecha: Label 'La fecha de inicio del nuevo estado debe ser posterior a la fecha de inicio del estado actual (%1).';
        ErrSinEstado: Label 'El empleado %1 no tiene un estado definido para la fecha %2.';
        ErrLiquidacionesBloqueantes: Label 'Existe una liquidación no revertida para el período %1 (Liq. %2, estado: %3). Revertí la liquidación antes de modificar el historial de estados.';
        QstInsertarEnHistorial: Label 'La fecha %1 ya está cubierta por el estado %2 (del %3 al %4). Si confirmás, ese estado quedará del %3 al %5 y el estado %6 comenzará el %1. ¿Confirmás?';
        QstReemplazarEstadoActual: Label 'El estado actual %1 (activo desde %2) será reemplazado por %3 con la misma fecha de inicio. ¿Confirmás el reemplazo?';
}
