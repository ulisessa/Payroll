namespace UAS.Payroll;

// Qué tipo de dato devuelve una Fuente de Datos.
//
// El contexto de cálculo es un Dictionary of [Text, Decimal] y eso no cambia: la fórmula siempre ve
// un número. Lo que este enum agrega es que la fuente ADEMÁS conserve el valor en su tipo original,
// para auditarlo y para imprimirlo en el recibo. Un atributo "Obra Social" tiene que salir impreso
// como "126205 - OSECAC", no como el número con el que la fórmula lo distingue.
enum 50324 "Tipo Dato Fuente Liq."
{
    Extensible = false;

    value(0; Decimal) { Caption = 'Decimal'; }
    value(1; Texto) { Caption = 'Texto'; }
    value(2; Fecha) { Caption = 'Fecha'; }
}
