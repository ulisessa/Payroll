namespace UAS.Payroll;

/// <summary>
/// Estado de una fila de staging. Pendiente es el único estado que el proceso vuelve a mirar solo;
/// Error requiere una acción explícita (reprocesar) para que nadie descubra tarde que algo se
/// estuvo reintentando en silencio durante una semana.
/// </summary>
enum 50329 "Estado Sinc NAV"
{
    Extensible = true;

    value(0; Pendiente) { Caption = 'Pendiente'; }
    value(1; Procesado) { Caption = 'Procesado'; }
    value(2; Error) { Caption = 'Error'; }
    value(3; Omitido) { Caption = 'Omitido'; }
}
