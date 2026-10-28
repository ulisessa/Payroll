/* COMPLETAR EL TC VENDEDOR DEL USD DESPUÉS DE PEGAR UNA LISTA DE COTIZACIONES (23/10/2026). Al pegar valores en la tabla de tipos de cambio BC copia "Valor T.C. relacionada" (comprador) en
   "Valor T.C. ajustes relacionada" (vendedor): las filas pegadas quedan con vendedor = comprador. En el USD el vendedor es siempre comprador + 50 (175 filas del 2/1 al 21/9/2026 lo cumplen; las del 19 al 21/10 quedaron en 0).
   Este script pone vendedor = comprador + @Spread en las filas del USD desde @Desde donde hoy son iguales. Con @Aplicar = 0 sólo lista lo que cambiaría. El EUR no entra: su vendedor es igual al comprador.
   Rollback: poner de nuevo vendedor = comprador en las filas listadas. */
SET NOCOUNT ON;
DECLARE @Aplicar bit = 0, @Desde date = '20260101', @Spread decimal(18,4) = 50, @Moneda nvarchar(10) = N'USD';
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Currency Exchange Rate$437dbf0e-84ff-417a-965d-ed2bb9650972]';
SELECT CONVERT(varchar(10),[Starting Date],120) d, [Relational Exch_ Rate Amount] comprador, [Relational Adjmt Exch Rate Amt] vendedor_hoy, [Relational Exch_ Rate Amount] + @Spread vendedor_nuevo
FROM dbo.[ArbuTest$Currency Exchange Rate$437dbf0e-84ff-417a-965d-ed2bb9650972]
WHERE [Currency Code] = @Moneda AND [Starting Date] >= @Desde AND [Relational Adjmt Exch Rate Amt] = [Relational Exch_ Rate Amount] ORDER BY [Starting Date];
IF @Aplicar = 1
BEGIN
  UPDATE dbo.[ArbuTest$Currency Exchange Rate$437dbf0e-84ff-417a-965d-ed2bb9650972]
     SET [Relational Adjmt Exch Rate Amt] = [Relational Exch_ Rate Amount] + @Spread
   WHERE [Currency Code] = @Moneda AND [Starting Date] >= @Desde AND [Relational Adjmt Exch Rate Amt] = [Relational Exch_ Rate Amount];
  SELECT @@ROWCOUNT AS filas_actualizadas;
END
