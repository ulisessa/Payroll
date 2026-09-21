namespace UAS.Payroll;

/// <summary>
/// Resuelve la descripción de un concepto, cacheada por código.
/// </summary>
/// <remarks>
/// Las páginas que muestran el nombre del concepto al lado del código lo resolvían en su
/// OnAfterGetRecord: una consulta a Concepto Liquidación por cada fila dibujada. En una lista de
/// novedades o incidencias con cientos de filas eso es un N+1 que se nota al desplazarse, y encima
/// repetido —la misma lista suele traer el mismo concepto muchas veces—.
///
/// El caché vive lo que vive la variable. Declarándola como global de la página dura lo que la
/// página, que es exactamente lo que se quiere: si alguien corrige la descripción de un concepto
/// mientras la lista está abierta, se ve al reabrirla en vez de quedar pegada para el resto de la
/// sesión.
/// </remarks>
codeunit 110039 "Descripción Concepto Liq."
{
    var
        FCache: Dictionary of [Code[20], Text[100]];

    /// <summary>
    /// Descripción de la versión más reciente del concepto, o vacío si el código no existe.
    /// </summary>
    /// <remarks>
    /// Los códigos que no existen también se cachean: una novedad con un concepto borrado hacía
    /// una consulta por fila para volver a no encontrar nada.
    /// </remarks>
    procedure Descripcion(CodConcepto: Code[20]): Text[100]
    var
        Concepto: Record "Concepto Liquidación";
        Desc: Text[100];
    begin
        if CodConcepto = '' then
            exit('');
        if FCache.ContainsKey(CodConcepto) then
            exit(FCache.Get(CodConcepto));

        // FindLast sobre las vigencias del código: la descripción que se muestra es la de la
        // versión más nueva, igual que hacían las páginas antes de centralizarlo acá.
        Concepto.SetRange(Código, CodConcepto);
        Concepto.SetLoadFields(Concepto.Descripción);
        if Concepto.FindLast() then
            Desc := Concepto.Descripción;

        FCache.Add(CodConcepto, Desc);
        exit(Desc);
    end;
}
