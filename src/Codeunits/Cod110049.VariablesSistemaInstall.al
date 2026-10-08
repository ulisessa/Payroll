namespace UAS.Payroll;

/// <summary>
/// Siembra el catálogo de Variables de Sistema al instalar y al actualizar la extensión.
/// </summary>
/// <remarks>
/// Hasta el 23/9/2026 la siembra existía sólo como acción de la página Variables de Sistema, y había
/// que acordarse de correrla. No acordarse no da un error de instalación: da un error EN EL CÁLCULO,
/// meses después y en la primera liquidación que usa la variable nueva —"Variable desconocida en la
/// fórmula"— cuando ya nadie asocia el síntoma con un publish. Pasó con MESES_PROM_AUS_12.
///
/// Sembrar es idempotente y sólo agrega lo que falta, así que correrla en cada upgrade es seguro y
/// deja el catálogo al día sin intervención. Mismo esquema que "Tipo Liq. Install"/"Tipo Liq. Upgrade".
/// </remarks>
codeunit 110049 "Variables Sistema Install"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        Gestion: Codeunit "Gestión Variables Sistema";
    begin
        Gestion.Sembrar();
    end;
}
