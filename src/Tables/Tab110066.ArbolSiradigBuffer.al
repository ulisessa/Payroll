namespace UAS.Payroll;

// Buffer del árbol de importaciones SIRADIG. Siempre temporal: no se persiste nada.
//
// Los niveles son AGRUPACIONES —período, estado— que no son registros de "Importación SIRADIG", así que
// hay que materializarlos. "Clave Orden" los ordena por prefijos, igual que el árbol de liquidaciones:
//
//   973974                            ← mes de presentación (el más reciente arriba: 999999 - 202601)
//   973974|1                          ← estado    (lo pendiente de procesar primero)
//   973974|1|0000000055               ← importación
//
// Un prefijo siempre ordena antes que las cadenas que lo extienden, así que el padre queda arriba de sus
// hijos sin ninguna columna de ordenamiento adicional.
table 110066 "Árbol SIRADIG Buffer"
{
    Caption = 'Árbol de Importaciones SIRADIG';
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
            // 0 mes de presentación · 1 estado · 2 importación
        }
        field(3; Descripción; Text[150])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(4; "No. Importación"; Integer)
        {
            Caption = 'No. Importación';
            DataClassification = CustomerContent;
            // Cero en los nodos de agrupación.
        }
        field(5; "Período"; Integer)
        {
            Caption = 'Período';
            DataClassification = CustomerContent;
            // El período de la declaración (el año fiscal), que la hoja trae de la importación.
        }
        field(6; "Estado Alcance"; Integer)
        {
            Caption = 'Estado Alcance';
            DataClassification = CustomerContent;
            // Ordinal del estado que acota el nodo; -1 = todos (el nodo de período).
            InitValue = -1;
        }
        field(7; Cantidad; Integer)
        {
            Caption = 'Importaciones';
            DataClassification = CustomerContent;
        }
        field(8; Pendientes; Integer)
        {
            Caption = 'Pendientes';
            DataClassification = CustomerContent;
        }
        field(9; "Con Errores"; Integer)
        {
            Caption = 'Con errores';
            DataClassification = CustomerContent;
        }
        field(10; Procesadas; Integer)
        {
            Caption = 'Procesadas';
            DataClassification = CustomerContent;
        }
        field(11; "CUIL Empleado"; Code[20])
        {
            Caption = 'CUIL Empleado';
            DataClassification = CustomerContent;
        }
        field(12; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            DataClassification = CustomerContent;
        }
        field(13; "Nro. Presentación"; Integer)
        {
            Caption = 'Nro. Presentación';
            DataClassification = CustomerContent;
        }
        field(14; "Fecha Presentación"; Date)
        {
            Caption = 'Fecha Presentación';
            DataClassification = CustomerContent;
        }
        field(15; "Deducciones Importadas"; Integer)
        {
            Caption = 'Deducciones Importadas';
            DataClassification = CustomerContent;
        }
        field(16; "Cargas Familia Importadas"; Integer)
        {
            Caption = 'Cargas de Familia Importadas';
            DataClassification = CustomerContent;
        }
        field(17; Estado; Enum "Estado Importación SIRADIG")
        {
            Caption = 'Estado';
            DataClassification = CustomerContent;
        }
        field(18; "Mensajes Error"; Text[500])
        {
            Caption = 'Mensajes Error';
            DataClassification = CustomerContent;
        }
        field(19; "Fecha Desde"; Date)
        {
            Caption = 'Fecha Desde';
            DataClassification = CustomerContent;
            // Primer día del mes de presentación que abarca el nodo. Con "Fecha Hasta" en blanco también,
            // el nodo reúne las importaciones sin fecha de presentación.
        }
        field(20; "Fecha Hasta"; Date)
        {
            Caption = 'Fecha Hasta';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Clave Orden") { Clustered = true; }
    }
}
