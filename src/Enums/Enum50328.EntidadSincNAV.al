namespace UAS.Payroll;

/// <summary>
/// Cada entidad que se trae de NAV 2013R2.
/// </summary>
/// <remarks>
/// El ORDEN DE PROCESO no es el orden de los valores: está escrito a mano en
/// "Sinc NAV Liq.".ProcesarTodo, y ahí "Valor Dimension" va PRIMERO aunque su ordinal sea el
/// último. Tiene que ser así: el ordinal se guarda en "Ctrl Sinc NAV".Entidad y en el script T-SQL
/// (WHERE [Entidad] = 0..4), así que renumerar para reordenar rompería las filas de control y las
/// marcas de agua ya guardadas. El ordinal es identidad; el orden es otra cosa.
///
/// La dependencia real: un valor de dimensión tiene que existir antes que el proyecto que lo usa
/// —si no, Job.Validate del buque o de la marea falla y la fila queda en Error—, y un proyecto
/// antes que su descarga.
/// </remarks>
enum 50328 "Entidad Sinc NAV"
{
    Extensible = true;

    value(0; Empleado) { Caption = 'Empleado'; }
    value(1; Proyecto) { Caption = 'Proyecto (Marea)'; }
    value(2; "Descarga Cabecera") { Caption = 'Descarga - Cabecera'; }
    value(3; "Descarga Linea") { Caption = 'Descarga - Líneas'; }
    value(4; "Valor Dimension") { Caption = 'Valor de Dimensión'; }
    value(5; "Informe Cap Cabecera") { Caption = 'Informe del Capitán - Cabecera'; }
    value(6; "Informe Cap Linea") { Caption = 'Informe del Capitán - Líneas'; }
    value(7; "Dia Abordo Cabecera") { Caption = 'Diario de Abordo - Cabecera'; }
    value(8; "Dia Abordo Linea") { Caption = 'Diario de Abordo - Líneas'; }
}
