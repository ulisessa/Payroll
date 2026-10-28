namespace UAS.Payroll;

// Buffer temporal del "dónde se usa": cada lugar del motor que nombra un símbolo.
//
// Un símbolo —un concepto, un acumulador, un parámetro, una fuente de datos, una variable de
// sistema, un atributo— puede estar nombrado en la fórmula de un concepto, en su condición, en su
// Variable Cantidad o Base, en el filtro de una fuente de datos, en una fracción de acumulador o en
// la definición de una variable de sistema. Buscarlo a mano son siete lugares distintos y es
// exactamente lo que no se revisa entero cuando hay apuro.
//
// LA COLUMNA QUE JUSTIFICA LA VISTA ES "Lee antes de estar listo". Este motor falla en silencio
// cuando una fórmula lee algo que todavía no se calculó: devuelve cero y paga de menos sin un solo
// error. Y para un ACUMULADOR el umbral no es su propio orden sino el de su último aportante: el
// acumulador existe desde el principio, pero no está completo hasta que aportó el último. Ese caso
// —3813 contra BASE_PROMEDIO, 3973 contra el suyo— costó medio día de SQL cada vez.
table 110064 "Uso Símbolo Liq."
{
    Caption = 'Dónde se usa';
    TableType = Temporary;
    DataClassification = CustomerContent;

    fields
    {
        field(1; "No. Línea"; Integer)
        {
            Caption = 'No. línea';
        }
        field(2; Símbolo; Code[50])
        {
            Caption = 'Símbolo';
        }
        // Qué clase de objeto lo nombra: un concepto, una fuente de datos, un acumulador.
        field(3; "Tipo Uso"; Text[30])
        {
            Caption = 'Tipo';
        }
        field(4; "Cód. Objeto"; Code[50])
        {
            Caption = 'Lo usa';
        }
        field(5; "Descripción Objeto"; Text[100])
        {
            Caption = 'Descripción';
        }
        // El campo concreto donde aparece: Fórmula, Condición, Variable Cantidad…
        field(6; Campo; Text[30])
        {
            Caption = 'En el campo';
        }
        field(7; "Orden Cálculo"; Integer)
        {
            Caption = 'Orden de quien lo usa';
        }
        // El orden a partir del cual el símbolo ya tiene su valor definitivo. Para un concepto es su
        // propio Orden Cálculo; para un acumulador, el del último concepto que le aporta.
        field(8; "Orden Símbolo Listo"; Integer)
        {
            Caption = 'Orden en que el símbolo está listo';
        }
        // Quien lo usa corre ANTES de que el símbolo esté listo: va a leer cero, o de menos.
        //
        // Sólo tiene sentido entre conceptos, que son los que tienen orden. Para un parámetro o una
        // fuente de datos queda en falso: se resuelven antes del bucle y están siempre disponibles.
        field(9; "Lee Antes de Estar Listo"; Boolean)
        {
            Caption = 'Lee antes de estar listo';
        }
        field(10; Fragmento; Text[250])
        {
            Caption = 'Fragmento';
        }
        // Vigente HOY, decidido por las fechas. El campo Activo de Concepto está marcado para quitar
        // porque no tiene efecto en el cálculo: la baja se expresa con Vigencia Hasta.
        field(11; Vigente; Boolean)
        {
            Caption = 'Vigente';
        }
        field(12; "Vigencia Desde"; Date)
        {
            Caption = 'Vigencia desde';
        }
        field(13; "Vigencia Hasta"; Date)
        {
            Caption = 'Vigencia hasta';
        }
    }

    keys
    {
        key(PK; "No. Línea")
        {
            Clustered = true;
        }
        key(Orden; "Tipo Uso", "Orden Cálculo", "Cód. Objeto") { }
    }
}
