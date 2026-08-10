namespace UAS.Payroll;

table 60028 "Detalle Acumulador Liq."
{
    Caption = 'Detalle Acumulador Liquidación';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Cód. Concepto"; Code[20])
        {
            Caption = 'Cód. Concepto';
            DataClassification = CustomerContent;
        }
        field(2; "Descripción Concepto"; Text[100])
        {
            Caption = 'Descripción Concepto';
            DataClassification = CustomerContent;
        }
        field(3; "Importe Concepto"; Decimal)
        {
            Caption = 'Importe Concepto';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(4; Porcentaje; Decimal)
        {
            Caption = '% Aplicado';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 4;
        }
        field(5; Restar; Boolean)
        {
            Caption = 'Restar';
            DataClassification = CustomerContent;
        }
        field(6; "Importe Aportado"; Decimal)
        {
            Caption = 'Importe Aportado';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
    }

    keys
    {
        key(PK; "Cód. Concepto") { Clustered = true; }
    }
}
