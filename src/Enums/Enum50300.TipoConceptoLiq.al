namespace UAS.Payroll;

enum 50300 "Tipo Concepto Liq."
{
    Extensible = false;

    value(0; "Haber Remunerativo") { Caption = 'Haber Remunerativo'; }
    value(1; "Haber No Remunerativo") { Caption = 'Haber No Remunerativo'; }
    value(2; "Descuento Empleado") { Caption = 'Descuento Empleado'; }
    value(3; "Contribución Patronal") { Caption = 'Contribución Patronal'; }
    value(4; "Retención") { Caption = 'Retención'; }
    value(5; "Seguridad Social") { Caption = 'Seguridad Social'; }
    value(6; "Informativo") { Caption = 'Informativo'; }
    // El ordinal 7 era "Deducción Remunerativa" y se eliminó. Existía para expresar un haber
    // remunerativo de signo negativo, cuando los importes se guardaban siempre positivos y el signo
    // salía entero del Tipo Concepto; desde que el importe de Línea Liquidación lleva su propio
    // signo, es un Haber Remunerativo con importe negativo y no hace falta un tipo aparte.
    //
    // El 7 queda LIBRE PERO QUEMADO: no reutilizarlo para un valor nuevo. "Tipo Concepto" está
    // desnormalizado en Línea Liquidación, así que cualquier línea vieja que no se haya recalculado
    // todavía sigue guardando ese ordinal, y reasignarlo la haría aparecer como otra cosa.
}
