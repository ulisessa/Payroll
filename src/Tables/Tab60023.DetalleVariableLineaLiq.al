namespace UAS.Payroll;

table 60023 "Detalle Variable Línea Liq."
{
    Caption = 'Detalle Variable Línea Liquidación';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "No. Liquidación"; Code[20])
        {
            Caption = 'No. Liquidación';
            TableRelation = "Liquidación"."No.";
        }
        field(2; "No. Línea"; Integer)
        {
            Caption = 'No. Línea';
        }
        field(3; "Nombre Variable"; Text[50])
        {
            Caption = 'Variable';
        }
        field(4; Valor; Decimal)
        {
            Caption = 'Valor';
            DecimalPlaces = 0 : 6;
        }
    }

    keys
    {
        key(PK; "No. Liquidación", "No. Línea", "Nombre Variable")
        {
            Clustered = true;
        }
    }
}
