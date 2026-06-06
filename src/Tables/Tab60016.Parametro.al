namespace UAS.Payroll;

table 60016 "Parámetro"
{
    Caption = 'Parámetro';
    DataClassification = CustomerContent;
    LookupPageId = "Parámetros";
    DrillDownPageId = "Parámetros";

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
        field(3; Notas; Text[250])
        {
            Caption = 'Notas';
            DataClassification = CustomerContent;
        }
        field(4; "Nombre Variable"; Code[30])
        {
            Caption = 'Nombre Variable';
            DataClassification = CustomerContent;
            // Variable name exposed in the formula context. Blank = not auto-loaded.
        }
        field(5; "Sufijo CCT"; Boolean)
        {
            Caption = 'Sufijo Convenio/Categoría';
            DataClassification = CustomerContent;
            // When true the effective lookup key = Código + '_' + CodConvenio + '_' + CodCategoria.
            // Use for per-CCT basic salaries (e.g. 'BASICO_FC_GER').
            trigger OnValidate()
            begin
                if "Sufijo CCT" then
                    "Sufijo Empleado" := false;
            end;
        }
        field(6; "Sufijo Empleado"; Boolean)
        {
            Caption = 'Sufijo Empleado';
            DataClassification = CustomerContent;
            // When true the effective lookup key = Código + '_' + EmployeeNo.
            // Use for per-employee salaries (e.g. 'BASICO_EMP001').
            trigger OnValidate()
            begin
                if "Sufijo Empleado" then
                    "Sufijo CCT" := false;
            end;
        }
    }

    keys
    {
        key(PK; Código) { Clustered = true; }
    }

    trigger OnDelete()
    var
        Vigente: Record "Parámetro Vigente";
    begin
        // Match both exact code and derived keys (e.g. BASICO_175/75_CAPITAN)
        Vigente.SetFilter("Cód. Parámetro", Código + '*');
        Vigente.SetRange("En Uso", true);
        if not Vigente.IsEmpty() then
            Error(ErrTieneEnUso);
        Vigente.SetRange("En Uso");
        Vigente.DeleteAll();
    end;

    var
        ErrTieneEnUso: Label 'No se puede eliminar el parámetro porque tiene valores que fueron utilizados en liquidaciones registradas.';
}
