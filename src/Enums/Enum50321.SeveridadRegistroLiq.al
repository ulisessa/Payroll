namespace UAS.Payroll;

enum 50321 "Severidad Registro Liq."
{
    Extensible = false;

    // El orden importa: el resultado del proceso es la severidad MÁXIMA de sus entradas, así que
    // los valores tienen que ir de menos a más grave.
    value(0; Información) { Caption = 'Información'; }
    value(1; Advertencia) { Caption = 'Advertencia'; }
    value(2; Error) { Caption = 'Error'; }
}
