/* COTIZACIÓN DEL EURO DE MARZO DE 2026 (90212 Y 90302, SUELDO NETO EN EUR). Sigue a scripts/CotizacionEURFebrero2026.sql.
   Sin fila de EUR para marzo, BC tomaba la última (1/2: 1.705) y Meta4 liquidó marzo con 1.640: LIQUIDO / EUR = 9.840.000 / 6.000 (90212) y 3.280.000 / 2.000 (90302), contra 10.230.000 y 3.410.000 de BC
   (+389.996 y +129.993 de neto; +628.183 y +163.685 de bruto en el comparador). Se carga la fila del EUR desde el 1/3/2026 con 1.640 (comprador y vendedor), copia de la del 1/2.
   Abril y mayo NO se cargan: Meta4 muestra 1.690 (90302) y 1.764,01 (90212) en abril, y 1.685 en mayo; las cotizaciones las publica quien liquida.
   Rollback: borrar la fila EUR del 2026-03-01. Después: reiniciar el servicio y recalcular marzo de 90212 y 90302. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Currency Exchange Rate$437dbf0e-84ff-417a-965d-ed2bb9650972]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Currency Exchange Rate$437dbf0e-84ff-417a-965d-ed2bb9650972] WHERE [Currency Code]=N'EUR' AND [Starting Date]='20260301')
BEGIN PRINT 'Ya existe la cotización del EUR del 2026-03-01'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Starting Date' THEN N'''20260301'''
    WHEN N'Relational Exch_ Rate Amount' THEN N'1640' WHEN N'Relational Adjmt Exch Rate Amt' THEN N'1640' ELSE QUOTENAME(c.name) END, ',')
  FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs
  + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @T + N' WHERE [Currency Code]=N''EUR'' AND [Starting Date]=''20260201'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Insertada_esperado_1;
SELECT TOP 3 CONVERT(varchar(10),[Starting Date],120) d, [Exchange Rate Amount] a, [Relational Exch_ Rate Amount] r, [Adjustment Exch_ Rate Amount] adj, [Relational Adjmt Exch Rate Amt] radj
FROM dbo.[ArbuTest$Currency Exchange Rate$437dbf0e-84ff-417a-965d-ed2bb9650972] WHERE [Currency Code]=N'EUR' AND [Starting Date]<='20260301' ORDER BY [Starting Date] DESC;
COMMIT;
