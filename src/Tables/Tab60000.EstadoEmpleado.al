namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

table 60000 "Estado Empleado"
{
    Caption = 'Estado Empleado';
    DataClassification = CustomerContent;
    LookupPageId = "Estados Empleado";
    DrillDownPageId = "Estados Empleado";

    fields
    {
        field(1; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = Employee."No.";
        }
        field(2; "Fecha Inicio"; Date)
        {
            Caption = 'Fecha Inicio';
            NotBlank = true;
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                AutoCalcFechaFin();
            end;
        }
        field(3; "Cód. Estado"; Code[20])
        {
            Caption = 'Cód. Estado';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Cód. Estado Empleado".Código;

            trigger OnValidate()
            begin
                AutoCalcFechaFin();
            end;
        }
        field(4; "Fecha Fin"; Date)
        {
            Caption = 'Fecha Fin';
            DataClassification = CustomerContent;
        }
        field(5; "Descripción Estado"; Text[100])
        {
            Caption = 'Descripción Estado';
            FieldClass = FlowField;
            CalcFormula = Lookup("Cód. Estado Empleado".Descripción WHERE(Código = FIELD("Cód. Estado")));
            Editable = false;
        }
        field(6; Observaciones; Text[250])
        {
            Caption = 'Observaciones';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "No. Empleado", "Fecha Inicio")
        {
            Clustered = true;
        }
        key(K2; "No. Empleado", "Fecha Fin")
        {
        }
    }

    trigger OnInsert()
    begin
        TestField("No. Empleado");
        TestField("Fecha Inicio");
        TestField("Cód. Estado");
        ValidarSinSolapamiento();
    end;

    trigger OnModify()
    begin
        ValidarSinSolapamiento();
        ValidarNoHayLiquidacionesBloqueantes("No. Empleado", "Fecha Inicio", "Fecha Fin");
    end;

    trigger OnDelete()
    begin
        ValidarNoHayLiquidacionesBloqueantes("No. Empleado", "Fecha Inicio", "Fecha Fin");
    end;

    trigger OnRename()
    var
        EstadoPrev: Record "Estado Empleado";
        FechaMin: Date;
    begin
        // xRec."Fecha Inicio" = old PK date, "Fecha Inicio" = new PK date
        FechaMin := xRec."Fecha Inicio";
        if "Fecha Inicio" < FechaMin then FechaMin := "Fecha Inicio";
        ValidarNoHayLiquidacionesBloqueantes("No. Empleado", FechaMin, "Fecha Fin");

        // Adjust the previous neighbor's Fecha Fin to new Fecha Inicio - 1
        EstadoPrev.SetRange("No. Empleado", "No. Empleado");
        EstadoPrev.SetFilter("Fecha Inicio", '<%1', "Fecha Inicio");
        if EstadoPrev.FindLast() then begin
            EstadoPrev."Fecha Fin" := "Fecha Inicio" - 1;
            EstadoPrev.Modify(true);
        end;
    end;

    local procedure ValidarNoHayLiquidacionesBloqueantes(EmpNo: Code[20]; FechaDesde: Date; FechaHasta: Date)
    var
        Liq: Record "Liquidación";
        Periodo: Record "Período Liquidación";
        FechaFinEfectiva: Date;
    begin
        FechaFinEfectiva := FechaHasta;
        if FechaFinEfectiva = 0D then
            FechaFinEfectiva := DMY2Date(31, 12, 9999);

        Liq.SetRange("No. Empleado", EmpNo);
        Liq.SetFilter(Estado, '<>%1', Liq.Estado::Borrador);
        if not Liq.FindSet() then exit;
        repeat
            if Periodo.Get(Liq."Cód. Período") then
                if (Periodo."Fecha Hasta" >= FechaDesde) and
                   (Periodo."Fecha Desde" <= FechaFinEfectiva)
                then
                    Error(ErrLiquidacionesBloqueantes, Liq."Cód. Período", Liq."No.", Format(Liq.Estado));
        until Liq.Next() = 0;
    end;

    local procedure AutoCalcFechaFin()
    var
        CodEst: Record "Cód. Estado Empleado";
        EstadoMgt: Codeunit "Gestión Estado Empleado";
    begin
        if ("No. Empleado" = '') or ("Fecha Inicio" = 0D) or ("Cód. Estado" = '') then
            exit;
        if not CodEst.Get("Cód. Estado") then
            exit;
        if CodEst."Tipo Estado" = CodEst."Tipo Estado"::Vacaciones then
            "Fecha Fin" := "Fecha Inicio" + EstadoMgt.CalcDiasVacaciones("No. Empleado", "Fecha Inicio") - 1;
    end;

    local procedure ValidarSinSolapamiento()
    var
        EstadoEmp: Record "Estado Empleado";
        FechaFinEfectiva: Date;
    begin
        FechaFinEfectiva := "Fecha Fin";
        if FechaFinEfectiva = 0D then
            FechaFinEfectiva := DMY2Date(31, 12, 9999);

        EstadoEmp.SetRange("No. Empleado", "No. Empleado");
        EstadoEmp.SetFilter("Fecha Inicio", '<>%1', "Fecha Inicio");
        if EstadoEmp.FindSet() then
            repeat
                if EstadoEmp."Fecha Fin" = 0D then begin
                    if EstadoEmp."Fecha Inicio" < FechaFinEfectiva then
                        Error(ErrSolapamiento);
                end else
                    if (EstadoEmp."Fecha Inicio" < FechaFinEfectiva) and
                       (EstadoEmp."Fecha Fin" >= "Fecha Inicio")
                    then
                        Error(ErrSolapamiento);
            until EstadoEmp.Next() = 0;
    end;

    var
        ErrSolapamiento: Label 'El período del estado se solapa con un estado existente del empleado.';
        ErrLiquidacionesBloqueantes: Label 'Existe una liquidación no revertida para el período %1 (Liq. %2, estado: %3). Revertí la liquidación antes de modificar el historial de estados.';
}
