namespace UAS.Payroll;

// Tipo de dato de un atributo. Define qué columna de "Atributo Entidad Liq." se completa y cómo se
// proyecta a número para que una fórmula pueda usarlo.
enum 50325 "Tipo Dato Atributo Liq."
{
    Extensible = false;

    // Valor libre en "Valor Decimal". La proyección numérica es el valor mismo.
    value(0; Decimal) { Caption = 'Decimal'; }
    value(1; Entero) { Caption = 'Entero'; }

    // Validado contra "Valor Atributo Liq.": el usuario elige de una lista y el número que ve la
    // fórmula sale del valor elegido. Es la forma preferida para todo lo que decide un cálculo —
    // un código validado por relación de tabla no se rompe en silencio como un literal suelto.
    value(2; Lista) { Caption = 'Lista de valores'; }

    // Se guardan y se muestran. A la fórmula llegan por Fuente de Datos declarada con el mismo tipo:
    // el texto como bandera 1/0 (o con COUNT y filtro, para preguntar por un valor puntual) y la
    // fecha como días hasta la fecha de referencia.
    value(3; Texto) { Caption = 'Texto'; }
    value(4; Fecha) { Caption = 'Fecha'; }
}
