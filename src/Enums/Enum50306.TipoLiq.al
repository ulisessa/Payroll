namespace UAS.Payroll;

enum 50306 "Tipo Liq."
{
    Extensible = true;
    AssignmentCompatibility = true;

    value(0; Regular) { Caption = 'Regular'; }
    value(1; Aguinaldo) { Caption = 'Aguinaldo'; }
    value(2; Vacaciones) { Caption = 'Vacaciones'; }
    value(3; "Liquidación Final") { Caption = 'Liquidación Final'; }
    value(4; Reliquidación) { Caption = 'Reliquidación'; }
    value(5; Devengados) { Caption = 'Devengados'; }
    value(6; "Cierre Marea") { Caption = 'Cierre Marea'; }
}
