namespace UAS.Payroll;

table 60024 "Resumen Variable Liq."
{
    Caption = 'Resumen Variable Liquidación';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "No. Liquidación"; Code[20])
        {
            Caption = 'No. Liquidación';
            TableRelation = "Liquidación"."No.";
            DataClassification = CustomerContent;
        }
        field(2; "Nombre Variable"; Code[30])
        {
            Caption = 'Nombre Variable';
            DataClassification = CustomerContent;
        }
        field(3; Etiqueta; Text[100])
        {
            Caption = 'Etiqueta';
            DataClassification = CustomerContent;
        }
        field(4; Valor; Decimal)
        {
            Caption = 'Valor';
            DataClassification = CustomerContent;
        }
        field(6; "Valor Texto"; Text[250])
        {
            Caption = 'Valor Texto';
            DataClassification = CustomerContent;
            // El valor tal como está en origen, cuando la fuente declara un tipo que no es número.
            // "Valor" sigue teniendo la proyección numérica que usó la fórmula: los dos conviven,
            // porque son dos preguntas distintas — con qué calculó y qué hay que imprimir.
        }
        field(5; "Mostrar en Recibo"; Boolean)
        {
            Caption = 'Mostrar en Recibo';
            DataClassification = CustomerContent;
            // Copiado desde la fuente al guardar, para que el recibo impreso pueda
            // filtrar y mostrar solo lo destinado a imprimirse (no lo de solo auditoría).
        }
    }

    keys
    {
        key(PK; "No. Liquidación", "Nombre Variable") { Clustered = true; }
    }

    /// <summary>
    /// Qué mostrarle a la persona: el valor original si la fuente no era numérica, el número si no.
    /// </summary>
    procedure ValorParaMostrar(): Text
    begin
        if "Valor Texto" <> '' then
            exit("Valor Texto");
        exit(Format(Valor, 0, '<Precision,2:2><Standard Format,0>'));
    end;
}
