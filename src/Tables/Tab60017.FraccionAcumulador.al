namespace UAS.Payroll;

table 60017 "Fracción Acumulador"
{
    Caption = 'Fracción Acumulador';
    DataClassification = CustomerContent;
    // Defines how a concept's calculated amount feeds accumulators.
    // Each row is independent: 100 % → BASE_SS and 100 % → BASE_IG4 both receive the full amount.
    // Restar = true flips the sign, so the amount is subtracted from the accumulator instead of added.
    // Versioned by Vigencia Desde so CCT agreement changes are tracked historically.

    fields
    {
        field(1; "Cód. Concepto"; Code[20])
        {
            Caption = 'Cód. Concepto';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Concepto Liquidación".Código;
        }
        field(2; "Vigencia Desde"; Date)
        {
            Caption = 'Vigencia Desde';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(3; "Cód. Acumulador"; Code[20])
        {
            Caption = 'Cód. Acumulador';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Concepto Liquidación".Código WHERE("Es Acumulador" = CONST(true));
        }
        field(4; Porcentaje; Decimal)
        {
            Caption = '% del importe';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 4;
            MinValue = 0;
            MaxValue = 100;
        }
        field(6; Restar; Boolean)
        {
            Caption = 'Restar';
            DataClassification = CustomerContent;
            InitValue = false;
        }
        field(5; Descripción; Text[50])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Cód. Concepto", "Vigencia Desde", "Cód. Acumulador") { Clustered = true; }
        key(K2; "Cód. Acumulador", "Vigencia Desde") { }
    }

}
