/* COTIZACIÓN DEL EURO DE ABRIL DE 2026 (90212 Y 90302, SUELDO NETO EN EUR). Currency Exchange Rate del EUR sólo tiene una fila entre el 1/3/2026 (1.640) y el 17/9/2026, así que abril usaba 1.640.
   Meta4 liquidó abril con 1.690: el LÍQUIDO de 90302 es 3.380.000 = 2.000 x 1.690 (BC daba 3.280.000) y esos +100.000 de neto explican su bruto (+151.718 con la tasa marginal de Ganancias).
   Se cargan dos filas, copia de la del 1/3: 1/4/2026 con 1.690 (comprador y vendedor, que conviven en la misma fila) y 1/5/2026 con 1.640, para que mayo en adelante siga con el valor que tenía (no se conoce el de Meta4).
   Rollback: borrar las filas EUR del 2026-04-01 y 2026-05-01.
   Después: reiniciar el servicio y recalcular la regular de abril de 90212 y 90302 (y el cierre si lo tuvieran). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Currency Exchange Rate$437dbf0e-84ff-417a-965d-ed2bb9650972]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Currency Exchange Rate$437dbf0e-84ff-417a-965d-ed2bb9650972] WHERE [Currency Code]=N'EUR' AND [Starting Date] IN ('20260401','20260501'))
BEGIN PRINT 'Ya existe la cotización del EUR de abril o mayo'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max), @cs nvarchar(max), @i int = 0;
DECLARE @F TABLE (fecha varchar(8), tc varchar(10));
INSERT @F VALUES ('20260401','1690'),('20260501','1640');
DECLARE @fecha varchar(8), @tc varchar(10);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT fecha, tc FROM @F;
OPEN cur; FETCH NEXT FROM cur INTO @fecha, @tc;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @cs = (SELECT STRING_AGG(CASE c.name WHEN N'Starting Date' THEN N'''' + @fecha + N''''
      WHEN N'Relational Exch_ Rate Amount' THEN @tc WHEN N'Relational Adjmt Exch Rate Amt' THEN @tc ELSE QUOTENAME(c.name) END, ',')
    FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
  SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs
    + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @T + N' WHERE [Currency Code]=N''EUR'' AND [Starting Date]=''20260301'';';
  EXEC (@sql);
  FETCH NEXT FROM cur INTO @fecha, @tc;
END
CLOSE cur; DEALLOCATE cur;
SELECT CONVERT(varchar(10),[Starting Date],120) d, [Exchange Rate Amount] a, [Relational Exch_ Rate Amount] r, [Adjustment Exch_ Rate Amount] adj, [Relational Adjmt Exch Rate Amt] radj
FROM dbo.[ArbuTest$Currency Exchange Rate$437dbf0e-84ff-417a-965d-ed2bb9650972] WHERE [Currency Code]=N'EUR' AND [Starting Date] BETWEEN '20260301' AND '20260601' ORDER BY [Starting Date];
COMMIT;
