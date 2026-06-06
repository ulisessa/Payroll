namespace UAS.Payroll;

enum 50303 "Tabla Origen Liq."
{
    // Extensible = true allows future extensions to register new data sources
    // without modifying this enum.
    Extensible = true;

    value(0; "Línea Descarga") { Caption = 'Línea Descarga'; }
    value(1; "Diario Abordo Lín.") { Caption = 'Diario Abordo Lín.'; }
    value(2; "Proyecto") { Caption = 'Proyecto (Marea)'; }
    value(3; "Parámetro Vigente") { Caption = 'Parámetro Vigente'; }
}
