namespace UAS.Payroll;

table 60032 "Tipo Liq. Selección Buffer"
{
    // Scratch buffer genérico de selección con tilde: lo usan las herramientas masivas de conceptos
    // ("Conceptos por Tipo Liq." con Tipo Liquidación, "Convenios por Concepto" con Convenio
    // Colectivo) para que el usuario marque varias filas sin persistir la selección en ningún lado
    // (siempre vía páginas con SourceTableTemporary).
    Caption = 'Tipo Liq. Selección Buffer';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; Código; Code[20])
        {
            Caption = 'Código';
            DataClassification = SystemMetadata;
        }
        field(2; Descripción; Text[100])
        {
            // Text[100] para que entren también las descripciones de Concepto Liquidación, que usa
            // la herramienta "Conceptos por Convenio" (Tipo Liquidación y Convenio son más cortas).
            Caption = 'Descripción';
            DataClassification = SystemMetadata;
        }
        field(3; Marcado; Boolean)
        {
            Caption = 'Marcado';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; Código) { Clustered = true; }
    }
}
