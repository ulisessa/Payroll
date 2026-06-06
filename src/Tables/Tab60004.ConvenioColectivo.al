namespace UAS.Payroll;

table 60004 "Convenio Colectivo"
{
    Caption = 'Convenio Colectivo';
    DataClassification = CustomerContent;
    LookupPageId = "Convenios Colectivos";
    DrillDownPageId = "Convenios Colectivos";

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
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(3; "No. CCT"; Text[30])
        {
            Caption = 'No. CCT';
            DataClassification = CustomerContent;
        }
        field(4; Sindicato; Text[100])
        {
            Caption = 'Sindicato';
            DataClassification = CustomerContent;
        }
        field(5; Cámara; Text[100])
        {
            Caption = 'Cámara';
            DataClassification = CustomerContent;
        }
        field(6; Observaciones; Text[250])
        {
            Caption = 'Observaciones';
            DataClassification = CustomerContent;
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
        fieldgroup(DropDown; Código, Descripción, "No. CCT") { }
    }
}
