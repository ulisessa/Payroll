namespace UAS.Payroll;

table 60006 "Categoría CCT"
{
    Caption = 'Categoría CCT';
    DataClassification = CustomerContent;
    LookupPageId = "Categorías CCT";
    DrillDownPageId = "Categorías CCT";

    fields
    {
        field(1; "Cód. Convenio"; Code[20])
        {
            Caption = 'Cód. Convenio';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Convenio Colectivo".Código;
        }
        field(2; Código; Code[20])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(3; Descripción; Text[100])
        {
            Caption = 'Descripción';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(4; "% Escala"; Decimal)
        {
            Caption = '% Escala';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 4;
            MinValue = 0;
            MaxValue = 999.9999;
        }
        field(5; Observaciones; Text[250])
        {
            Caption = 'Observaciones';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Cód. Convenio", Código)
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Código, Descripción, "% Escala") { }
    }
}
