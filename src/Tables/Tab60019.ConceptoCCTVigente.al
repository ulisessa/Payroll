namespace UAS.Payroll;

table 60019 "Concepto CCT Vigente"
{
    Caption = 'Convenios Aplicables al Concepto';
    DataClassification = CustomerContent;
    // Defines which CCT agreements (and, opcionalmente, categorías dentro de ese convenio)
    // un concepto aplica, versionado por fecha.
    // If NO records exist for a concept at a given date → applies to ALL CCTs.
    // If records exist → applies ONLY to the listed CCTs.
    // El versionado es POR CONVENIO: para cada convenio manda su propia fila con la Vigencia
    // Desde más reciente <= fecha de liquidación. Agregar una vigencia nueva para un convenio
    // NO revoca la vigencia todavía válida de los demás convenios del mismo concepto.
    // Dentro de un convenio restringido, "Cód. Categoría" en blanco = aplica a TODAS las
    // categorías de ese convenio; una fila con categoría puntual restringe solo a esa. Ahí sí
    // la vigencia más reciente DE ESE CONVENIO reemplaza a la anterior, de modo que una versión
    // nueva puede acotar el concepto a categorías puntuales.

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
        field(4; "Cód. Categoría"; Code[20])
        {
            Caption = 'Cód. Categoría';
            DataClassification = CustomerContent;
            TableRelation = "Categoría CCT".Código WHERE("Cód. Convenio" = FIELD("Cód. Convenio"));
            // Vacío = aplica a todas las categorías del convenio. Cargada = restringe solo a esa.
        }
    }

    keys
    {
        key(PK; "Cód. Concepto", "Vigencia Desde", "Cód. Convenio", "Cód. Categoría") { Clustered = true; }
        key(K2; "Cód. Convenio", "Vigencia Desde") { }
    }
}
