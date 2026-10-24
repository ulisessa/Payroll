/* APORTES SOBRE EL SAC DE EGRESO (6002, 6012, 6034): EL TOPE/12 SÓLO CORRE SI LA BASE DEL MES LLEGA AL TOPE.
   Febrero 2026, finales: 04751 (SAC 329.210) y 04139 (SAC 291.405). Meta4 aporta el SAC entero (JUBILACION_SAC 36.213 = 11% x 329.209; 04139: 32.054 = 11% x 291.405);
   BC lo topaba siempre a (base sin SAC topeada)/12 = 108.101 y daba 11.891 (04139: 7.732). Los aportes mensuales (6000/6010/6030) ya coinciden al peso.
   En enero los dos finales con tope (04190, 04807) sí quedan topados a tope/12 en Meta4, y los demás no llegan al tope: la regla que cierra los 8 finales de enero
   (scripts/PrevisualizarDescuentosFinal.sql, misma diferencia que antes en 90448) y los 2 de febrero es: si BASE_SS sin SAC + lo aportado en el mes < tope prorrateado,
   el SAC aporta entero; si no, MIN(SAC, tope prorrateado/12), como hasta ahora.
   Cambio: vigencia nueva 2026-02-01 de 6002, 6012 y 6034 (la 2026-01-01 se cierra el 31/1), reemplazando en la rama LIQ_FINAL
   MIN(MAX(0, X), TOPE) / 12 por IF(MAX(0, X) < TOPE, #3813 + #3823, TOPE / 12) (TOPE = TOPE_SIPA o TOPE_SIPA_OS por DIAS_ALTA_30/30).
   Rollback: borrar las vigencias 2026-02-01 y reabrir las anteriores (Vigencia Hasta = 1753-01-01).
   Después: reiniciar el servicio y recalcular las finales de febrero de 04751 y 04139. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @X nvarchar(300) = N'BASE_SS_TRAB + BASE_SS_VAC - #3813 - #3823 + PERIODO_BASE_SS_TRAB + PERIODO_BASE_SS_VAC';
DECLARE @cod nvarchar(10), @tope nvarchar(20), @f nvarchar(max), @old nvarchar(max), @viejo nvarchar(500), @nuevo nvarchar(500), @cs nvarchar(max), @sql nvarchar(max);
DECLARE cur CURSOR FOR SELECT N'6002', N'TOPE_SIPA' UNION ALL SELECT N'6012', N'TOPE_SIPA' UNION ALL SELECT N'6034', N'TOPE_SIPA_OS';
OPEN cur; FETCH cur INTO @cod, @tope;
WHILE @@FETCH_STATUS = 0
BEGIN
  IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=@cod AND [Vigencia Desde]='20260201')
  BEGIN PRINT 'Ya existe la vigencia 2026-02-01 de ' + @cod; ROLLBACK; RETURN; END;
  SET @old = (SELECT [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=@cod AND [Vigencia Desde]='20260101');
  SET @viejo = N'MIN(MAX(0, ' + @X + N'), ' + @tope + N' * DIAS_ALTA_30 / 30) / 12';
  SET @nuevo = N'IF(MAX(0, ' + @X + N') < ' + @tope + N' * DIAS_ALTA_30 / 30, #3813 + #3823, ' + @tope + N' * DIAS_ALTA_30 / 30 / 12)';
  IF CHARINDEX(@viejo, @old) = 0 BEGIN PRINT 'No se encontró el término del tope en ' + @cod; ROLLBACK; RETURN; END;
  SET @f = REPLACE(@old, @viejo, @nuevo);
  SET @cs = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260201''' WHEN N'Vigencia Hasta' THEN N'''17530101''' WHEN N'Fórmula' THEN N'@f' ELSE QUOTENAME(c.name) END, ',')
             FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
  SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @T + N' WHERE [Código]=@cod AND [Vigencia Desde]=''20260101'';';
  EXEC sp_executesql @sql, N'@f nvarchar(max), @cod nvarchar(10)', @f = @f, @cod = @cod;
  UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260131', [$systemModifiedAt]=SYSUTCDATETIME()
   WHERE [Código]=@cod AND [Vigencia Desde]='20260101' AND [Vigencia Hasta]='17530101';
  FETCH cur INTO @cod, @tope;
END
CLOSE cur; DEALLOCATE cur;
SELECT [Código],[Vigencia Desde],[Vigencia Hasta],LEN([Fórmula]) len_f FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (N'6002',N'6012',N'6034') ORDER BY 1,2;
COMMIT;
