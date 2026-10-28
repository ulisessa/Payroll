namespace UAS.Payroll;

/// <summary>
/// De qué lado del asiento de sueldos va el saldo de un rubro.
/// </summary>
/// <remarks>
/// El importe del rubro viaja CON SIGNO y el lado dice cómo leerlo: un rubro de Debe con saldo
/// positivo debita, uno de Haber con saldo positivo acredita, y un saldo negativo invierte el lado.
/// Así un descuento de días (un haber negativo) baja el gasto sin que haga falta un rubro aparte.
/// </remarks>
enum 50335 "Lado Asiento Liq."
{
    Extensible = false;

    value(0; Debe) { Caption = 'Debe'; }
    value(1; Haber) { Caption = 'Haber'; }
}
