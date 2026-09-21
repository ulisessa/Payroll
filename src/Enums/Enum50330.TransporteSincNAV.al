namespace UAS.Payroll;

/// <summary>
/// Cómo se traen las filas del origen hasta las tablas de staging.
/// </summary>
/// <remarks>
/// Los dos transportes llenan EXACTAMENTE las mismas tablas de staging y no tocan nada más: lo que
/// aplica sobre Job, Employee y las descargas sigue siendo "Sinc NAV Liq." en los dos casos. Por eso
/// se puede cambiar de uno al otro por empresa y volver atrás sin migrar datos.
///
/// Diferencias que importan al elegir:
///   · SQL necesita un linked server (una vez, con el DBA) y detecta cambios por rowversion. NO
///     detecta bajas: un DELETE en NAV no deja rastro en ningún rowversion.
///   · Web Services no necesita nada del lado de SQL, pero pide una instancia de service tier con
///     NavUserPassword porque el HttpClient de AL no habla NTLM. Detecta cambios y BAJAS por el
///     Change Log de NAV, que es a la vez su reloj.
/// </remarks>
enum 50330 "Transporte Sinc NAV"
{
    Extensible = true;

    value(0; "SQL (linked server)") { Caption = 'SQL (linked server)'; }
    value(1; "Web Services") { Caption = 'Web Services (OData)'; }
}
