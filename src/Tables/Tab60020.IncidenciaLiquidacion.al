namespace UAS.Payroll;

table 60020 "Incidencia Liquidación"
{
    Caption = 'Incidencia Liquidación';
    DataClassification = CustomerContent;
    // Stores manual amounts for concepts that require per-liquidation data entry
    // (adjustments, retroactives, gratifications, etc.).
    //
    // In FuenteDatos, reference via token {LIQ_NO} to filter by current liquidation:
    //   Filtro 1: "No. Liquidación" = {LIQ_NO}
    //   Filtro 2: "Cód. Concepto"  = <literal concept code>
    //   Función: LOOKUP, Campo: Importe
    //   → Nombre Variable: INCID_<concept code>

    fields
    {
        field(1; "No. Liquidación"; Code[20])
        {
            Caption = 'No. Liquidación';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Liquidación"."No.";
        }
        field(2; "Cód. Concepto"; Code[20])
        {
            Caption = 'Cód. Concepto';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Concepto Liquidación".Código;
        }
        field(3; Importe; Decimal)
        {
            Caption = 'Importe';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(4; Observaciones; Text[250])
        {
            Caption = 'Observaciones';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "No. Liquidación", "Cód. Concepto") { Clustered = true; }
    }
}
