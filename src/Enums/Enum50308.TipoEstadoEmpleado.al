namespace UAS.Payroll;

enum 50308 "Tipo Estado Empleado"
{
    Extensible = true;

    value(0; Normal) { Caption = 'Normal'; }
    value(1; Alta) { Caption = 'Alta'; }
    value(2; Baja) { Caption = 'Baja'; }
    value(3; Vacaciones) { Caption = 'Vacaciones'; }
}
