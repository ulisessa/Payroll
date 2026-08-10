namespace UAS.Payroll;

enum 50318 "Ámbito Estado"
{
    Extensible = true;
    // Which entity types a state code applies to. Vessels use a subset; employees can use more.

    value(0; Empleado) { Caption = 'Empleado'; }
    value(1; Buque) { Caption = 'Buque'; }
    value(2; Ambos) { Caption = 'Ambos'; }
}
