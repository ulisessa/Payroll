namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Foundation.NoSeries;
using Microsoft.HumanResources.Setup;

table 50579 "Préstamo Empleado"
{
    Caption = 'Préstamo / Anticipo';
    DataClassification = CustomerContent;
    LookupPageId = "Lista Préstamos Empleado";
    DrillDownPageId = "Lista Préstamos Empleado";

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = Employee."No.";

            trigger OnValidate()
            var
                Emp: Record Employee;
            begin
                if Emp.Get("No. Empleado") then
                    "Nombre Empleado" := Emp."First Name" + ' ' + Emp."Last Name"
                else
                    "Nombre Empleado" := '';
            end;
        }
        field(3; "Nombre Empleado"; Text[100])
        {
            Caption = 'Nombre Empleado';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(4; Tipo; Enum "Tipo Préstamo Emp.")
        {
            Caption = 'Tipo';
            DataClassification = CustomerContent;
        }
        field(5; Fecha; Date)
        {
            Caption = 'Fecha';
            DataClassification = CustomerContent;
        }
        field(6; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(7; "Importe Total"; Decimal)
        {
            Caption = 'Importe Total';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
            MinValue = 0;
        }
        field(8; "Cant. Cuotas"; Integer)
        {
            Caption = 'Cant. Cuotas';
            DataClassification = CustomerContent;
            MinValue = 1;
            InitValue = 1;
        }
        field(9; "Cód. Concepto Descuento"; Code[20])
        {
            Caption = 'Concepto de Descuento';
            DataClassification = CustomerContent;
            TableRelation = "Concepto Liquidación".Código;
        }
        field(10; "Total Aplicado"; Decimal)
        {
            Caption = 'Total Aplicado';
            FieldClass = FlowField;
            CalcFormula = Sum("Cuota Préstamo".Importe WHERE("No. Préstamo" = FIELD("No."), Estado = CONST(Aplicada)));
            Editable = false;
            DecimalPlaces = 2 : 2;
        }
        field(11; Observaciones; Text[250])
        {
            Caption = 'Observaciones';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "No.") { Clustered = true; }
        key(K2; "No. Empleado") { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "No.", "No. Empleado", "Nombre Empleado", Tipo, "Importe Total") { }
    }

    trigger OnInsert()
    var
        HRSetup: Record "Human Resources Setup";
        NoSeries: Codeunit "No. Series";
    begin
        if "No." = '' then begin
            HRSetup.Get();
            HRSetup.TestField("Cód. Serie Préstamos");
            "No." := NoSeries.GetNextNo(HRSetup."Cód. Serie Préstamos", Today(), true);
        end;
        if Fecha = 0D then Fecha := Today();
    end;

    trigger OnDelete()
    var
        Cuota: Record "Cuota Préstamo";
    begin
        Cuota.SetRange("No. Préstamo", "No.");
        Cuota.SetRange(Estado, Cuota.Estado::Aplicada);
        if not Cuota.IsEmpty() then
            Error(ErrTieneAplicadas);
        Cuota.SetRange(Estado);
        Cuota.DeleteAll();
    end;

    var
        ErrTieneAplicadas: Label 'No se puede eliminar un préstamo con cuotas ya aplicadas en liquidaciones.';
}
