namespace UAS.Payroll;

// Buffer del árbol de liquidaciones. Siempre temporal: no se persiste nada.
//
// A diferencia del árbol de parámetros —donde la jerarquía ya estaba en los datos y alcanzaba con
// ordenar por la clave primaria— acá los niveles son AGRUPACIONES: período, tipo de liquidación y
// proyecto no son registros de "Liquidación", son encabezados que hay que materializar.
//
// "Clave Orden" es la que ordena el árbol, armada por prefijos. Los tramos no son los códigos sino
// claves de orden: el mes va con la fecha invertida —para que el más reciente quede arriba—, la fecha
// derecha —para leer el mes en orden cronológico— y el tipo con su Orden de liquidación adelante:
//
//   79738999                                         ← mes         (Enero 2026)
//   79738999|20260131                                ← fecha       (Sáb 31/01/2026)
//   79738999|20260131|0002_REGULAR                   ← tipo        (2. REGULAR)
//   79738999|20260131|0002_REGULAR|PN-ADM-PTOMDY     ← proyecto
//   79738999|20260131|0002_REGULAR|PN-ADM-PTOMDY|LIQ-0001286  ← liquidación
//
// Un prefijo siempre ordena antes que las cadenas que lo extienden, así que el padre queda arriba de
// sus hijos sin ninguna columna de ordenamiento adicional.
table 110007 "Árbol Liquidaciones Buffer"
{
    Caption = 'Árbol de Liquidaciones';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; "Clave Orden"; Code[100])
        {
            Caption = 'Clave Orden';
            DataClassification = CustomerContent;
        }
        field(2; Nivel; Integer)
        {
            Caption = 'Nivel';
            DataClassification = CustomerContent;
            // 0 mes · 1 fecha · 2 tipo · 3 proyecto · 4 liquidación (3 si no se agrupa por proyecto)
        }
        field(3; Descripción; Text[150])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(4; "No. Liquidación"; Code[20])
        {
            Caption = 'No. Liquidación';
            DataClassification = CustomerContent;
            // Vacío en los nodos de agrupación.
        }
        field(5; "Cód. Período"; Code[10])
        {
            Caption = 'Cód. Período';
            DataClassification = CustomerContent;
        }
        field(20; "Filtro Período"; Text[250])
        {
            Caption = 'Filtro Período';
            DataClassification = CustomerContent;
            // Los códigos de período que abarca el nodo, separados por "|" y listos para un SetFilter.
            //
            // Hace falta porque el nodo raíz agrupa por MES y un mes puede tener más de un código
            // —el mensual y el del aguinaldo, por ejemplo—. Con un solo "Cód. Período" el alcance de
            // las acciones de lote se quedaría con uno y operaría sobre la mitad de lo que el nodo
            // muestra, que es la peor forma de equivocarse en un Calcular masivo.
        }
        field(15; "Fecha Liquidación"; Date)
        {
            Caption = 'Fecha Liquidación';
            DataClassification = CustomerContent;
            // La fecha del nodo de fecha y de todo lo que cuelga de él. En los niveles de arriba
            // —el mes— queda en blanco, porque abarca varias.
        }
        field(6; "Cód. Tipo Liq."; Code[20])
        {
            Caption = 'Tipo Liquidación';
            DataClassification = CustomerContent;
        }
        field(7; "No. Proyecto"; Code[20])
        {
            Caption = 'No. Proyecto (Marea)';
            DataClassification = CustomerContent;
        }
        field(8; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            DataClassification = CustomerContent;
        }
        field(9; "Nombre Empleado"; Text[100])
        {
            Caption = 'Nombre Empleado';
            DataClassification = CustomerContent;
        }
        field(10; Estado; Enum "Estado Liq.")
        {
            Caption = 'Estado';
            DataClassification = CustomerContent;
        }
        field(11; Cantidad; Integer)
        {
            Caption = 'Liquidaciones';
            DataClassification = CustomerContent;
            // En los nodos, cuántas cuelgan debajo. En las hojas queda en 0: el número repetido en
            // cada línea sería ruido.
        }
        field(12; "Total Haberes"; Decimal)
        {
            Caption = 'Total Haberes';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(13; "Total Descuentos"; Decimal)
        {
            Caption = 'Total Descuentos';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(14; "Neto a Pagar"; Decimal)
        {
            Caption = 'Neto a Pagar';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
    }

    keys
    {
        key(PK; "Clave Orden") { Clustered = true; }
    }
}
