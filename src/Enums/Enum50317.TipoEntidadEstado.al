namespace UAS.Payroll;

enum 50317 "Tipo Entidad Estado"
{
    Extensible = true;
    // Discriminator for the shared state history: an entry belongs to an employee or a vessel.

    value(0; Empleado) { Caption = 'Empleado'; }
    value(1; Buque) { Caption = 'Buque'; }
}
