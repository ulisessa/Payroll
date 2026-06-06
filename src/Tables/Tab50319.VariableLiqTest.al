namespace UAS.Payroll;

table 50319 "Variable Liq. Test"
{
    Caption = 'Variable Test Liquidación';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; Nombre; Text[100])
        {
            Caption = 'Variable';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; Valor; Decimal)
        {
            Caption = 'Valor';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 6;
        }
        field(3; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(4; Tipo; Text[20])
        {
            Caption = 'Tipo';
            DataClassification = CustomerContent;
            // 'Parámetro', 'Sistema', 'Fuente Datos', 'Acumulador'
        }
    }

    keys
    {
        key(PK; Nombre) { Clustered = true; }
        key(K2; Tipo, Nombre) { }
    }
}
