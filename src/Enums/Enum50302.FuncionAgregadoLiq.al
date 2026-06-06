namespace UAS.Payroll;

enum 50302 "Función Agregado Liq."
{
    Extensible = false;

    value(0; "SUM") { Caption = 'Suma'; }
    value(1; "COUNT") { Caption = 'Cantidad'; }
    value(2; "MAX") { Caption = 'Máximo'; }
    value(3; "MIN") { Caption = 'Mínimo'; }
    value(4; "LOOKUP") { Caption = 'Búsqueda directa'; }
    value(5; "DIAS_OVERLAP") { Caption = 'Días solapados'; }
    value(6; "DURACION_INICIO") { Caption = 'Duración desde inicio'; }
    value(7; "DURACION_ANIO") { Caption = 'Duración en el año'; }
}
