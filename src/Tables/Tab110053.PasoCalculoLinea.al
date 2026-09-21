namespace UAS.Payroll;

/// <summary>
/// Un paso del cálculo de una línea de liquidación. SIEMPRE TEMPORAL: la arma
/// "Detalle Cálculo Línea" re-evaluando la fórmula guardada, y se descarta al
/// cerrar la página.
///
/// No se persiste a propósito. Guardarla obligaría a escribirla en cada cálculo
/// —para todas las líneas de todas las liquidaciones, por si alguien la mira— y
/// a mantenerla sincronizada. Reconstruirla cuesta una evaluación de una fórmula
/// sobre valores que ya están en la base, y no puede quedar desactualizada.
/// </summary>
table 110053 "Paso Cálculo Línea"
{
    Caption = 'Paso de Cálculo';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; "No. Paso"; Integer)
        {
            Caption = 'No. Paso';
            DataClassification = CustomerContent;
        }
        field(2; Nivel; Integer)
        {
            Caption = 'Nivel';
            DataClassification = CustomerContent;
            // Profundidad de anidamiento, EMPEZANDO EN CERO: 0 es la suma más externa de la
            // fórmula, 1 una suma que vive dentro de una función —el caso de ganancias, cuya
            // cadena está adentro de TRAMO(...)—, y así.
            //
            // Arranca en cero porque es lo que espera IndentationColumn: la página se dibuja como
            // árbol y el cliente usa este número para sangrar y para plegar cada rama. El nivel
            // crudo del parser no sirve tal cual —depende de cuántas funciones haya alrededor—,
            // así que se normaliza restándole el mínimo al armar la tabla.
        }
        field(3; Orden; Integer)
        {
            Caption = 'Orden';
            DataClassification = CustomerContent;
        }
        field(4; Signo; Text[1])
        {
            Caption = 'Signo';
            DataClassification = CustomerContent;
        }
        field(5; Término; Text[250])
        {
            Caption = 'Término';
            DataClassification = CustomerContent;
            // El trozo de la fórmula tal como está escrito.
        }
        field(6; Descripción; Text[250])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
            // Qué es el término en castellano, cuando se lo puede averiguar: la descripción del
            // concepto acumulador, la del parámetro o la de la variable de sistema.
        }
        field(7; Valor; Decimal)
        {
            Caption = 'Valor';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 4;
        }
        field(8; Acumulado; Decimal)
        {
            Caption = 'Acumulado';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 4;
            // El total corriente. Es lo que convierte una lista de valores en un paso a paso:
            // se ve cómo se va armando la base, término a término.
        }
        field(9; Detalle; Text[250])
        {
            Caption = 'Detalle';
            DataClassification = CustomerContent;
            // Texto de auditoría cuando el término lo tiene — el caso típico es TRAMO, que deja
            // escrito qué tramo aplicó, de qué vigencia y con qué porcentaje.
        }
        field(10; "Es Total"; Boolean)
        {
            Caption = 'Es Total';
            DataClassification = CustomerContent;
            // Marca la fila final, la que compara lo reconstruido contra el importe guardado.
        }
        field(11; "Es Subtotal"; Boolean)
        {
            Caption = 'Es Subtotal';
            DataClassification = CustomerContent;
            // Cierra un bloque anidado. Existe para que la columna Acumulado no cambie de sujeto
            // en silencio al pasar de una cadena de sumas a otra.
        }
    }

    keys
    {
        key(PK; "No. Paso") { Clustered = true; }
    }
}
