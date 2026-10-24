/* COTIZACIÓN DEL EURO DE FEBRERO DE 2026 (90212 Y 90302, SUELDO NETO EN EUR).
   Los dos tripulantes con parámetros en EUR (BASICO y NETO_GU a TC_VENDEDOR) salían con el neto de enero en febrero: en Currency Exchange Rate del EUR no hay filas entre el
   14/1/2026 (1.770) y el 17/9/2026, así que "la última con Starting Date <= fecha" daba 1.770. Meta4 liquidó febrero con 1.705: LIQUIDO / EUR = 10.230.000 / 6.000 (90212) y
   3.410.000 / 2.000 (90302), y enero con 1.770 (10.620.000 / 6.000 y 3.540.000 / 2.000). BC daba neto 10.619.997 y 3.539.998. La diferencia de 90212 (+390.000 de neto, +628.184 de bruto)
   es sólo esto.
   Se carga la fila del EUR desde el 1/2/2026 con 1.705 (comprador y vendedor, que conviven en la misma fila), copia de la del 14/1. Enero no cambia (la última fila <= 31/1 sigue siendo la del 14/1).
   Marzo en adelante NO se carga: Meta4 muestra 1.640 en marzo y 1.685 en mayo, pero abril y junio mezclan otros conceptos; las cotizaciones las publica quien liquida.
   Rollback: borrar la fila EUR del 2026-02-01.
   Después: reiniciar el servicio y recalcular febrero de 90212 y 90302. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Currency Exchange Rate$437dbf0e-84ff-417a-965d-ed2bb9650972]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Currency Exchange Rate$437dbf0e-84ff-417a-965d-ed2bb9650972] WHERE [Currency Code]=N'EUR' AND [Starting Date]='20260201')
BEGIN PRINT 'Ya existe la cotización del EUR del 2026-02-01'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Starting Date' THEN N'''20260201'''
    WHEN N'Relational Exch_ Rate Amount' THEN N'1705' WHEN N'Relational Adjmt Exch Rate Amt' THEN N'1705' ELSE QUOTENAME(c.name) END, ',')
  FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs
  + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @T + N' WHERE [Currency Code]=N''EUR'' AND [Starting Date]=''20260114'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Insertada_esperado_1;
SELECT TOP 3 CONVERT(varchar(10),[Starting Date],120) d, [Exchange Rate Amount] a, [Relational Exch_ Rate Amount] r, [Adjustment Exch_ Rate Amount] adj, [Relational Adjmt Exch Rate Amt] radj
FROM dbo.[ArbuTest$Currency Exchange Rate$437dbf0e-84ff-417a-965d-ed2bb9650972] WHERE [Currency Code]=N'EUR' AND [Starting Date]<='20260301' ORDER BY [Starting Date] DESC;
COMMIT;
