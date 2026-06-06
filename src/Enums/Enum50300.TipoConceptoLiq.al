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
}
