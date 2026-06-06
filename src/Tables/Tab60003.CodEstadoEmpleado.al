namespace UAS.Payroll;

table 60003 "Cód. Estado Empleado"
{
    Caption = 'Cód. Estado Empleado';
    DataClassification = CustomerContent;
    LookupPageId = "Cód. Estados Empleado";
    DrillDownPageId = "Cód. Estados Empleado";

    fields
    {
        field(1; Código; Code[20])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(3; "Tipo Empleado"; Enum "Aplica A Liq.")
        {
            Caption = 'Tipo Empleado';
            DataClassification = CustomerContent;
        }
        field(4; Activo; Boolean)
        {
            Caption = 'Activo';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(5; "Tipo Estado"; Enum "Tipo Estado Empleado")
        {
            Caption = 'Tipo Estado';
            DataClassification = CustomerContent;
            // Alta: opens an employment period for seniority calculation.
            // Baja: closes the current employment period.
            // Vacaciones: triggers auto-calculation of Fecha Fin when entered in state history.
            // Normal: all other states (Enfermedad, Suspensión, etc.) — included in seniority automatically.
        }
    }

    keys
    {
        key(PK; Código)
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Código, Descripción, "Tipo Empleado") { }
    }
}
