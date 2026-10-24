namespace UAS.Payroll;

/// <summary>
/// A qué columna del reporte de SICOSS aporta el importe de un concepto.
/// </summary>
/// <remarks>
/// Existe porque "Grupo Costo Laboral" NO ALCANZA, y eso se ve en los datos: el 6000 (jubilación del
/// empleado) y el 6010 (ley 19032 del empleado) están los dos en el grupo Seguridad Social con Tipo
/// Concepto 5, y el 7000 (jubilación patronal), el 7060 (asignaciones familiares) y el 7070 (fondo
/// nacional de empleo) están los tres en el grupo Seguridad Social con Tipo Concepto 3. SICOSS los
/// declara en columnas separadas, así que agrupar por rubro los fusiona y el reporte no puede
/// reconstruirlos. El grupo del costo laboral dice de qué RUBRO es el costo; esto dice en qué
/// CASILLERO de la declaración entra.
///
/// Es un eje aparte y no un refinamiento del grupo: un concepto nuevo de obra social que no se
/// declare —una diferencia interna, por ejemplo— tiene grupo Obra Social y columna en blanco.
///
/// EL BLANCO NO SE IGNORA EN SILENCIO: el reporte lista en su hoja de Avisos todo concepto de
/// Descuento, Contribución, Retención o Seguridad Social que haya liquidado importe sin columna
/// asignada, con su total. Sin eso, agregar un concepto de aportes y olvidarse de mapearlo bajaría
/// la declaración sin que nada avise.
/// </remarks>
enum 50334 "Columna SICOSS Liq."
{
    Extensible = false;

    value(0; " ") { Caption = ' '; }
    // ── Aportes y retenciones del empleado: hoja TOTALES ──────────────────────
    value(1; "Aporte Jubilación") { Caption = 'Aporte Jubilación (JUBILACION)'; }
    value(2; "Aporte INSSJP") { Caption = 'Aporte INSSJP (LEY_19032)'; }
    value(3; "Aporte Obra Social") { Caption = 'Aporte Obra Social (OBRA_SOCIAL)'; }
    value(4; "Aporte Adicional OS") { Caption = 'Aporte Adicional Obra Social (ADIC_OBS)'; }
    value(5; "Cuota Sindical") { Caption = 'Cuota Sindical (SINDICATO)'; }
    value(6; "Impuesto a las Ganancias") { Caption = 'Impuesto a las Ganancias (IMPUESTO)'; }
    // ── Contribuciones patronales: hoja CNT ───────────────────────────────────
    value(10; "Contribución Jubilación") { Caption = 'Contribución Jubilación (JUB)'; }
    value(11; "Contribución INSSJP") { Caption = 'Contribución INSSJP (INS)'; }
    value(12; "Contribución Asig. Familiares") { Caption = 'Contribución Asig. Familiares (AFM)'; }
    value(13; "Contribución FNE") { Caption = 'Contribución Fondo Nac. de Empleo (FNE)'; }
    value(14; "Contribución Obra Social") { Caption = 'Contribución Obra Social (OBS)'; }
    value(15; "Contribución ART") { Caption = 'Contribución ART (ART)'; }
    value(16; "Contribución SCVO") { Caption = 'Seguro de Vida Obligatorio (SVCO)'; }
    value(17; "Contribución Tarea Diferencial") { Caption = 'Contribución Tarea Diferencial (DIFERENCIAL)'; }
    // "No se declara" NO ES LO MISMO QUE EL BLANCO, y la diferencia es la que hace útil a la hoja de
    // Avisos: el blanco significa "nadie decidió todavía" y el reporte lo lista; esto significa
    // "alguien lo miró y no va", y el reporte lo saltea. Sin los dos valores la lista de avisos queda
    // dominada por los anticipos, los embargos y los gastos —que nunca van a tener columna porque
    // SICOSS no tiene dónde ponerlos— y los que sí faltan se vuelven invisibles entre ellos.
    value(99; "No se declara") { Caption = 'No se declara en SICOSS'; }
}
