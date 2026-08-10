namespace UAS.Payroll;

enum 50319 "Rol Franco Liq."
{
    Extensible = true;
    // Marks a concept's role in the franco (compensatory day-off) FIFO ledger, so the franco engine can
    // find accrual and consumption lines among Línea Liquidación without relying on hard-coded codes.

    value(0; Ninguno) { Caption = 'Ninguno'; }
    value(1; Devengo) { Caption = 'Devengo'; }   // accrues franco days (Es Devengo line, sealed with category)
    value(2; Consumo) { Caption = 'Consumo'; }   // pays francos enjoyed (FIFO-valued at each lot's category)
}
