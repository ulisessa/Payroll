namespace UAS.Payroll;

/// <summary>Si la línea de estado habilita la liquidación o la impide.</summary>
enum 50332 "Modo Estado Tipo Liq."
{
    Extensible = true;
    Caption = 'Modo';

    value(0; Exige) { Caption = 'Exige'; }
    value(1; Excluye) { Caption = 'Excluye'; }
}
