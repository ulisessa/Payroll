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
            // Vacaciones: its effective window is capped at the LCT day entitlement when counting DIAS_VAC_PERIODO.
            // Normal: all other states (Enfermedad, Suspensión, etc.) — included in seniority automatically.
        }
        field(6; "Ámbito"; Enum "Ámbito Estado")
        {
            Caption = 'Ámbito';
            DataClassification = CustomerContent;
            // Whether this state applies to employees, vessels, or both. Vessels use a subset.
        }
        field(7; "Estado Siguiente"; Code[20])
        {
            Caption = 'Estado Siguiente';
            DataClassification = CustomerContent;
            TableRelation = "Cód. Estado Empleado".Código;
            // Auto-transition target: when this state's condition ends (e.g. francos balance used up),
            // the entity moves to this state. Blank = terminal (stays until a new state is set).
        }
        field(8; "Devenga Francos"; Boolean)
        {
            Caption = 'Devenga Francos';
            DataClassification = CustomerContent;
            // Productive/embarked state: its calendar days on a marea count toward DIAS_ENROLAMIENTO,
            // the base for the franco accrual. Francos are enjoyed later in a "Tipo Estado = Francos" state.
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
