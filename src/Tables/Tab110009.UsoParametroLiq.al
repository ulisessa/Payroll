namespace UAS.Payroll;

// Qué versión de qué parámetro usó cada liquidación. Una fila por liquidación y variable.
//
// Existe para poder preguntar lo inverso —"¿alguna otra liquidación activa sigue usando esta
// versión?"— con una consulta indexada. Ese dato ya estaba, pero embebido como tokens `VAR:` dentro
// del texto "Fuente Parámetros" de cada línea, y ahí solo se podía responder leyendo las líneas de
// todas las liquidaciones y partiendo cadenas: reabrir una liquidación terminaba siendo más lento
// que calcularla, y el costo crecía con cada liquidación calculada en la base.
//
// "Fuente Parámetros" sigue existiendo y no lo reemplaza: ese texto es la auditoría legible de una
// línea —qué vio la fórmula cuando se calculó— y se lee de a una línea por vez. Esta tabla es el
// índice para la pregunta inversa, que es la que se hacía a escala.
table 110009 "Uso Parámetro Liq."
{
    Caption = 'Uso de Parámetro por Liquidación';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "No. Liquidación"; Code[20])
        {
            Caption = 'No. Liquidación';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Liquidación"."No.";
        }
        field(2; "Nombre Variable"; Code[30])
        {
            Caption = 'Nombre Variable';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(3; "Cód. Parámetro Base"; Code[20])
        {
            Caption = 'Cód. Parámetro Base';
            DataClassification = CustomerContent;
        }
        field(4; "Cód. Parámetro"; Code[50])
        {
            Caption = 'Clave Derivada';
            DataClassification = CustomerContent;
            // La clave efectiva que resolvió la cascada de sufijos para esta liquidación.
        }
        field(5; "Vigencia Desde"; Date)
        {
            Caption = 'Vigencia Desde';
            DataClassification = CustomerContent;
            // La versión concreta que se usó. Es lo que hay que dejar bloqueada mientras esta
            // liquidación siga viva.
        }
    }

    keys
    {
        key(PK; "No. Liquidación", "Nombre Variable") { Clustered = true; }
        // La pregunta inversa, que es la razón de ser de esta tabla: quién más usa esta versión.
        key(Version; "Cód. Parámetro", "Vigencia Desde", "No. Liquidación") { }
    }
}
