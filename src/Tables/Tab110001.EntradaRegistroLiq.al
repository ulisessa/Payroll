namespace UAS.Payroll;

table 110001 "Entrada Registro Liq."
{
    Caption = 'Entrada de Registro';
    DataClassification = CustomerContent;
    // Cada cosa que pasó durante una operación: un error, una advertencia o una acción realizada.

    fields
    {
        field(1; "No. Registro"; Integer)
        {
            Caption = 'No. Registro';
            DataClassification = CustomerContent;
            TableRelation = "Registro Proceso Liq."."No. Registro";
        }
        field(2; "No. Línea"; Integer)
        {
            Caption = 'No. Línea';
            DataClassification = CustomerContent;
        }
        field(10; Severidad; Enum "Severidad Registro Liq.")
        {
            Caption = 'Severidad';
            DataClassification = CustomerContent;
        }
        field(11; Categoría; Enum "Categoría Registro Liq.")
        {
            Caption = 'Categoría';
            DataClassification = CustomerContent;
        }
        field(12; Mensaje; Text[250])
        {
            Caption = 'Mensaje';
            DataClassification = CustomerContent;
        }
        field(13; Detalle; Text[2048])
        {
            Caption = 'Detalle';
            DataClassification = CustomerContent;
            // Texto largo cuando lo hay: el error del evaluador con su expresión, la lista completa
            // de conceptos afectados, etc.
        }
        field(14; "Cód. Concepto"; Code[20])
        {
            Caption = 'Cód. Concepto';
            DataClassification = CustomerContent;
            TableRelation = "Concepto Liquidación".Código;
        }
        field(15; "Nombre Variable"; Code[30])
        {
            Caption = 'Variable';
            DataClassification = CustomerContent;
        }
        field(16; "Fecha Hora"; DateTime)
        {
            Caption = 'Fecha Hora';
            DataClassification = CustomerContent;
        }
        field(17; Importe; Decimal)
        {
            Caption = 'Importe';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 6;
            AutoFormatType = 0;
        }
    }

    keys
    {
        key(PK; "No. Registro", "No. Línea") { Clustered = true; }
        key(K2; "No. Registro", Severidad) { }
        key(K3; "Cód. Concepto") { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Severidad, Categoría, Mensaje) { }
    }
}
