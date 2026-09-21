namespace UAS.Payroll;

// Con qué convenio y categoría se resuelve un concepto.
//
// Casi todos usan el de la entidad —el encuadre del empleado, con su historial— y por eso es el
// valor cero: un concepto que nadie tocó se comporta como siempre. La excepción son los conceptos
// que se pagan por la asignación y no por el encuadre: la producción de una marea se liquida con el
// convenio y la categoría con los que el tripulante se embarcó, aunque su encuadre sea otro.
enum 50327 "Par CCT Liq."
{
    Extensible = false;

    value(0; Entidad) { Caption = 'El del empleado (atributos)'; }

    // El valor 1 era "El de la asignación al proyecto", y se eliminó el 18/9/2026 junto con los
    // campos Cód. Convenio y Cód. Categoría de Personal Proyecto, que era de donde salía. El número
    // NO se reutiliza: hay liquidaciones calculadas cuyo registro de fórmula aplicada se leyó con
    // ese par, y reciclar el 1 para otra cosa haría que ese histórico dijera algo distinto de lo
    // que pasó.
    //
    // El PUESTO con el que el empleado navega. Mismo eje que aquél —la producción— pero tomado de
    // donde el dato realmente vive: un historial de vigencias sobre la ficha, que no hay que
    // reconfirmar en cada asignación a proyecto.
    //
    // CAMBIA SOLO LA CATEGORÍA, no el convenio. El puesto no lleva convenio, y el del oficial sale
    // de la flota del buque: pisarlo acá rompería el encuadre. Si el empleado no tiene puesto
    // vigente a la fecha de referencia, el concepto se evalúa con el par de la cabecera, que es el
    // comportamiento de siempre.
    value(2; Puesto) { Caption = 'El puesto del empleado (atributos)'; }
}
