namespace UAS.Payroll;

table 60013 "Tabla Escalonada"
{
    Caption = 'Tabla Escalonada';
    DataClassification = CustomerContent;
    // Header for bracket/range tables (e.g. 4th-category withholding, social security caps).
    // Each (Código, Vigencia Desde) pair is a complete, immutable version of the table.
    // To update: insert a new header + new detail lines with a later "Vigencia Desde".

    fields
    {
        field(1; Código; Code[20])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; "Vigencia Desde"; Date)
        {
            Caption = 'Vigencia Desde';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(3; Descripción; Text[100])
        {
            Caption = 'Descripción';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(4; "Cant. Tramos"; Integer)
        {
            Caption = 'Cant. Tramos';
            FieldClass = FlowField;
            CalcFormula = Count("Tabla Escalonada Det." WHERE(Código = FIELD(Código), "Vigencia Desde" = FIELD("Vigencia Desde")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; Código, "Vigencia Desde")
        {
            Clustered = true;
        }
    }

    trigger OnDelete()
    var
        Det: Record "Tabla Escalonada Det.";
    begin
        Det.SetRange(Código, Código);
        Det.SetRange("Vigencia Desde", "Vigencia Desde");
        Det.DeleteAll(true);
    end;
}
