namespace UAS.Payroll;

enum 50323 "Tipo Cambio Fórmula"
{
    Extensible = false;

    value(0; Alta) { Caption = 'Alta'; }
    value(1; Modificación) { Caption = 'Modificación'; }
    value(2; Eliminación) { Caption = 'Eliminación'; }
    // Reescritura de la MISMA fórmula en forma canónica: cambian los espacios y los saltos de línea,
    // no lo que calcula. Va como tipo aparte y no como Modificación porque son dos preguntas
    // distintas: "quién tocó este número" y "por qué este texto se ve distinto al de la planilla".
    // Confundirlas en un solo tipo haría que la primera —la que importa— se pierda entre las otras.
    value(3; Formato) { Caption = 'Formato'; }
}
