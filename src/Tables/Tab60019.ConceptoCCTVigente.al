namespace UAS.Payroll;

table 60019 "Concepto CCT Vigente"
{
    Caption = 'Convenios Aplicables al Concepto';
    DataClassification = CustomerContent;
    // Defines which CCT agreements a concept applies to, versioned by date.
    // If NO records exist for a concept at a given date → applies to ALL CCTs.
    // If records exist → applies ONLY to the listed CCTs for that vigencia.
    // A "version" is the set of rows sharing the same (Cód. Concepto, Vigencia Desde).

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
        field(3; "Cód. Convenio"; Code[20])
        {
            Caption = 'Cód. Convenio';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Convenio Colectivo".Código;
        }
    }

    keys
    {
        key(PK; "Cód. Concepto", "Vigencia Desde", "Cód. Convenio") { Clustered = true; }
        key(K2; "Cód. Convenio", "Vigencia Desde") { }
    }
}
