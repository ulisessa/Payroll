namespace UAS.Payroll;

table 60033 "Diag. Fuente Datos Buffer"
{
    // Scratch buffer for the Fuente Datos diagnostic tool (used only via a SourceTableTemporary page).
    Caption = 'Diag. Fuente Datos Buffer';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Nombre Variable"; Code[30])
        {
            Caption = 'Nombre Variable';
            DataClassification = SystemMetadata;
        }
        field(2; "No. Línea"; Integer)
        {
            Caption = 'No. Línea';
            DataClassification = SystemMetadata;
        }
        field(3; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = SystemMetadata;
        }
        field(4; "Id. Tabla"; Integer)
        {
            Caption = 'Id. Tabla';
            DataClassification = SystemMetadata;
        }
        field(5; "Nombre Tabla"; Text[250])
        {
            Caption = 'Nombre Tabla';
            DataClassification = SystemMetadata;
        }
        field(6; Origen; Text[50])
        {
            Caption = 'Campo Roto';
            DataClassification = SystemMetadata;
        }
        field(7; "No. Campo"; Integer)
        {
            Caption = 'No. Campo (inexistente)';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Nombre Variable", "No. Línea") { Clustered = true; }
    }
}
