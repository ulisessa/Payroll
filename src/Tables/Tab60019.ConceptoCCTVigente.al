namespace UAS.Payroll;

table 60019 "Concepto CCT Vigente"
{
    Caption = 'Convenios Aplicables al Concepto';
    DataClassification = CustomerContent;
    // Defines which CCT agreements (and, opcionalmente, categorías dentro de ese convenio)
    // un concepto aplica, versionado por fecha.
    // If NO records exist for a concept at a given date → applies to ALL CCTs.
    // If INCLUSION records exist → applies ONLY to the listed CCTs.
    // Una fila con "Excluye" invierte el sentido: dice a qué convenio NO aplica. Gana sobre
    // cualquier inclusión, y si SOLO hay exclusiones el concepto sigue aplicando a todo lo demás
    // (ver CCTAplicaAConcepto y ExcluidoPorCCT en "Motor Liquidación").
    // El versionado es POR CONVENIO: para cada convenio manda su propia fila con la Vigencia
    // Desde más reciente <= fecha de liquidación. Agregar una vigencia nueva para un convenio
    // NO revoca la vigencia todavía válida de los demás convenios del mismo concepto.
    // Dentro de un convenio restringido, "Cód. Categoría" en blanco = aplica a TODAS las
    // categorías de ese convenio; una fila con categoría puntual restringe solo a esa.
    // Para cada categoría vale la última vigencia del convenio que la NOMBRE —sea por su código o
    // por una fila en blanco—, no la última vigencia a secas: una vigencia nueva agrega y
    // actualiza, y no revoca lo que no menciona. Para sacarle un concepto a una categoría hay que
    // cargar una fila con "Excluye"; omitirla de la vigencia nueva no alcanza, a propósito. Antes
    // sí alcanzaba, y una carga que enumeró las categorías de otro convenio dejó a los OF04 del
    // 175/75 sin sueldo, sin antigüedad y sin francos desde el 1/1/2026, sin un solo aviso.

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
        field(5; Excluye; Boolean)
        {
            Caption = 'Excluye';
            DataClassification = CustomerContent;
            // Da vuelta el sentido de la fila: en vez de "aplica a este convenio", dice "NO aplica a
            // este convenio". Existe porque el modelo de inclusión sola no sabe decir "a todos menos
            // a uno": había que enumerar los demás, y entonces un convenio nuevo entraba sin que
            // nadie lo decidiera — en silencio, que es como se paga de más.
            //
            // Una exclusión activa GANA sobre cualquier inclusión, y no participa del versionado por
            // convenio: es una capa aparte. Para volver a incluir un convenio excluido se borra la
            // fila, no se agrega una vigencia posterior.
            //
            // Esto es también lo que hace que sacar un concepto SIEMPRE sea explícito: desde que la
            // resolución por categoría busca hacia atrás la última vigencia que la nombra, omitirla
            // de una vigencia nueva ya no la deja afuera. La contracara es que una exclusión no
            // tiene fecha de fin: si alguna vez hace falta "excluida durante 2026 y de vuelta en
            // 2027", hay que darle vigencia propia acá, no resolverlo por omisión.
        }
    }

    keys
    {
        key(PK; "Cód. Concepto", "Vigencia Desde", "Cód. Convenio", "Cód. Categoría") { Clustered = true; }
        key(K2; "Cód. Convenio", "Vigencia Desde") { }
    }
}
