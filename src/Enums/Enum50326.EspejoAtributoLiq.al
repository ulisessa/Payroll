namespace UAS.Payroll;

// Maestro del que un atributo copia sus valores permitidos, en vez de que se carguen a mano.
//
// El enum y no un ID de tabla genérico: cada maestro tiene su propia forma —de dónde sale el código,
// de dónde el padre, de dónde el número— y sobre todo su propio juego de triggers, que es lo que
// mantiene el espejo al día. Un mapeo genérico por RecordRef ahorraría el case pero no los triggers,
// que hay que escribir igual en cada tabla origen. Agregar un maestro nuevo es un valor acá y una
// rama en Espejo Atributos Liq.
enum 50326 "Espejo Atributo Liq."
{
    Extensible = false;

    value(0; Ninguno) { Caption = 'Ninguno (valores cargados a mano)'; }
    value(1; "Convenio Colectivo") { Caption = 'Convenio Colectivo'; }
    value(2; "Categoría CCT") { Caption = 'Categoría CCT'; }

    // Copia el MISMO maestro que "Categoría CCT" —los puestos de a bordo se expresan con códigos de
    // categoría— pero es un espejo aparte y no el mismo, porque el par se resuelve buscando el tipo
    // POR su espejo: con los dos tipos declarando "Categoría CCT", ese FindFirst devolvería cualquiera
    // de los dos y el encuadre del empleado y su puesto se pisarían entre sí según el orden alfabético
    // de los códigos. Son dos ejes distintos —la categoría paga el sueldo, el puesto paga la
    // producción— y necesitan poder distinguirse.
    value(3; Puesto) { Caption = 'Categoría CCT (usada como puesto)'; }
}
