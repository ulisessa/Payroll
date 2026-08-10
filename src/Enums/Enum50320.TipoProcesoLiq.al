namespace UAS.Payroll;

enum 50320 "Tipo Proceso Liq."
{
    Extensible = true;

    value(0; Cálculo) { Caption = 'Cálculo'; }
    value(1; Aprobación) { Caption = 'Aprobación'; }
    value(2; Reapertura) { Caption = 'Reapertura'; }
    value(3; "Reversión Aprobación") { Caption = 'Reversión de Aprobación'; }
    value(4; Eliminación) { Caption = 'Eliminación'; }
    value(5; "Creación") { Caption = 'Creación'; }
    value(6; "Importación Novedades") { Caption = 'Importación de Novedades'; }
}
