/* 2803 DE LAS CUATRO FINALES CON FERIADO OMITIDO POR META4 (22/10/2026). Segunda parte de NovedadesFinalesAbrilFeriadoOmitidoMeta4.sql: el 2803 repite en su fórmula el devengo del último tramo (ROUND(COEF_FRANCOS * DIAS_DEVENGA_FRANCOS_COBERTURA, 1) + DIAS_FERIADOS_GUARDIA) y no lee el 1062, así que ignora la novedad de devengo: pagaba 32 días contra 30 de Meta4. Se carga novedad por importe con el 2803 de Meta4. Rollback: borrar las novedades con Observaciones que empiezan por Meta4 omitió el feriado de guardia (final de abril 2026): indemnización. Después: recalcular las cuatro finales. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @N nvarchar(300) = N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Observaciones] LIKE N'Meta4 omitió el feriado de guardia (final de abril 2026): indemnización%')
BEGIN PRINT 'Ya aplicado'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@N) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max), @cs nvarchar(max);
DECLARE @Lista TABLE (emp varchar(20), concepto varchar(10), importe decimal(18,4));
INSERT @Lista VALUES ('03104','2803',1686956),('03791','2803',1927949),('04046','2803',449854.93),('04802','2803',1911883.47);
DECLARE @emp varchar(20), @con varchar(10), @imp decimal(18,4);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT emp, concepto, importe FROM @Lista;
OPEN cur; FETCH NEXT FROM cur INTO @emp, @con, @imp;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @cs = (SELECT STRING_AGG(CASE c.name
      WHEN N'No_ Empleado' THEN N'h.[No_ Empleado]' WHEN N'Nombre Empleado' THEN N'h.[Nombre Empleado]'
      WHEN N'Cód_ Convenio' THEN N'h.[Cód_ Convenio]' WHEN N'Cód_ Categoría' THEN N'h.[Cód_ Categoría]'
      WHEN N'Cód_ Concepto' THEN N'''' + @con + N'''' WHEN N'Importe' THEN CAST(@imp AS nvarchar(30)) WHEN N'Cantidad' THEN N'0'
      WHEN N'Fecha' THEN N'h.[Fecha Liquidación]' WHEN N'Cód_ Período' THEN N'h.[Cód_ Período]'
      WHEN N'Observaciones' THEN N'N''Meta4 omitió el feriado de guardia (final de abril 2026): ' + CASE WHEN @con = '1023' THEN N'indemnización 2803 igual a la de Meta4 (la fórmula recalcula el devengo del último tramo con los feriados y no lee el 1062).' ELSE N'' END + N''''
      WHEN N'Estado' THEN N'0' WHEN N'No_ Liquidación' THEN N'''''' WHEN N'Motivo No Aplicada' THEN N'''''' WHEN N'Cód_ Tipo Liq_' THEN N'''LIQ_FINAL''' WHEN N'No_ Proyecto' THEN N''''''
      ELSE N'n.' + QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@N) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
  SET @sql = N'INSERT ' + @N + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs
    + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @N
    + N' n CROSS JOIN dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h WHERE n.[No_ Movimiento]=9741 AND h.[No_ Empleado]=''' + @emp + N''' AND h.[Cód_ Tipo Liq_]=''LIQ_FINAL'' AND h.[Cód_ Período]=''202604'';';
  EXEC sp_executesql @sql;
  FETCH NEXT FROM cur INTO @emp, @con, @imp;
END
CLOSE cur; DEALLOCATE cur;
SELECT [No_ Movimiento] mv,[No_ Empleado] e,[Cód_ Concepto] c,[Importe] i,[Cantidad] q,[Cód_ Tipo Liq_] tl,[Cód_ Convenio] cv,[Cód_ Categoría] ct,CONVERT(varchar(10),[Fecha],120) f,[Estado] est FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Observaciones] LIKE N'Meta4 omitió el feriado de guardia (final de abril 2026)%' ORDER BY 2,3;
COMMIT;
