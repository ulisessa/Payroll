namespace UAS.Payroll;

enum 50307 "Aplica Tipo Liq. Concepto"
{
    Extensible = true;

    value(0; Todos) { Caption = ' '; }
    value(1; Regular) { Caption = 'Regular'; }
    value(2; Aguinaldo) { Caption = 'Aguinaldo'; }
    value(3; Vacaciones) { Caption = 'Vacaciones'; }
    value(4; "Liquidación Final") { Caption = 'Liquidación Final'; }
    value(5; Reliquidación) { Caption = 'Reliquidación'; }
    value(6; Devengados) { Caption = 'Devengados'; }
    value(7; "Cierre Marea") { Caption = 'Cierre Marea'; }
}
