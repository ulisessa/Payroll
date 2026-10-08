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
        field(5; Detalle; Text[250])
        {
            Caption = 'Detalle';
            // Solo para las filas que no son una variable de configuración y por lo tanto no tienen
            // dónde ir a buscar su descripción: hoy, las consultas TRAMO. Ahí guarda en qué tramo
            // cayó la base y con qué monto fijo y porcentaje se resolvió. Para una variable común
            // queda vacío y la descripción sale del catálogo, como siempre.
        }
        // Snapshot de la escala aplicada.
        field(6; "Tabla Tramo"; Code[20]) { Caption = 'Tabla aplicada'; }
        field(7; "Base Tramo"; Decimal) { Caption = 'Base imponible'; }
        field(8; "Límite Tramo"; Decimal) { Caption = 'Límite inferior'; }
        field(9; "Fijo Tramo"; Decimal) { Caption = 'Importe fijo'; }
        field(10; "Porcentaje Tramo"; Decimal) { Caption = 'Porcentaje sobre excedente'; }
        field(11; "Vigencia Tramo"; Date) { Caption = 'Vigencia de la escala'; }
        field(12; "Snapshot Tramo"; Boolean) { Caption = 'Escala conservada'; }
        field(13; "Código Atributo"; Text[100]) { Caption = 'Código de atributo utilizado'; }
    }

    keys
    {
        key(PK; "No. Liquidación", "No. Línea", "Nombre Variable")
        {
            Clustered = true;
        }
    }
}
