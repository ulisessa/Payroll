namespace UAS.Payroll;

enum 50315 "Estado Novedad Liq."
{
    Extensible = false;

    // Pendiente → todavía no entró en ninguna liquidación (o se recalculó y volvió a quedar libre).
    // Aplicada  → se materializó como Incidencia en la liquidación de "No. Liquidación".
    // Anulada   → excluida a mano; nunca se aplica ni se copia ni se recurre.
    value(0; "Pendiente") { Caption = 'Pendiente'; }
    value(1; "Aplicada") { Caption = 'Aplicada'; }
    value(2; "Anulada") { Caption = 'Anulada'; }
}
