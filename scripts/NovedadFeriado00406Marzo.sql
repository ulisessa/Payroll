/* FERIADO (1023) DE 00406 EN MARZO DE 2026: IGUALAR A META4 CON UNA NOVEDAD.
   Meta4 liquidó el feriado en la corrida del 25/3 con 67.500 (base 1.552.500 = 1083 1.380.000 + antigüedad 172.500 de los 23 días de GP / 23); los 8 días de franco se pagaron en una corrida aparte (4/3), así que su antigüedad (60.000)
   no entró en la base. BC liquida todo en la regular y su base sí la incluye: 70.108,70 (+2.608,70). Detalle en «El feriado y los francos en otra corrida» (Hallazgos abiertos). Se iguala con una novedad de importe (reemplaza a la fórmula)
   por pedido del usuario (20/10/2026): fecha 25/3, sin tipo de liquidación, Pendiente. No se cambia la fórmula: en febrero Meta4 pagó francos y feriado en la misma corrida y BC coincide con la base completa.
   Junto con la novedad del 2083 (NovedadFranco00406Marzo.sql) y el 1063, que no se puede tocar por novedad, es todo lo que se puede igualar en 00406.
   Rollback: borrar la novedad con Observaciones "Meta4 marzo 2026 (feriado de 00406 sin la antigüedad del franco)%". Después: reiniciar el servicio y recalcular la REGULAR de marzo de 00406. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Observaciones LIKE N'Meta4 marzo 2026 (feriado de 00406 sin la antigüedad del franco)%')
BEGIN PRINT 'Ya existen las novedades'; ROLLBACK; RETURN; END;
DECLARE @tpl int = 11604;
DECLARE @nv TABLE (emp nvarchar(20), con nvarchar(20), fecha date, imp decimal(18,2), tl nvarchar(20), nombre nvarchar(100), conv nvarchar(20), cat nvarchar(20), per nvarchar(6), obs nvarchar(250));
INSERT @nv (emp,con,fecha,imp,tl,nombre,conv,cat,per,obs)
SELECT x.emp, x.con, x.fecha, x.imp, x.tl,
  ISNULL((SELECT TOP 1 n.[Nombre Empleado] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.[No_ Empleado]=x.emp ORDER BY n.[No_ Movimiento] DESC), N''),
  ISNULL((SELECT TOP 1 n.[Cód_ Convenio] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.[No_ Empleado]=x.emp ORDER BY n.[No_ Movimiento] DESC), N''),
  ISNULL((SELECT TOP 1 n.[Cód_ Categoría] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.[No_ Empleado]=x.emp ORDER BY n.[No_ Movimiento] DESC), N''),
  CONVERT(varchar(6), x.fecha, 112), N'Meta4 marzo 2026 (feriado de 00406 sin la antigüedad del franco): incidencia ' + x.con + N' del ' + CONVERT(nvarchar(10), x.fecha, 103)
FROM (VALUES (N'00406',N'1023',CAST('20260325' AS date),CAST(67500.00 AS decimal(18,2)),N'')) x(emp,con,fecha,imp,tl);
SELECT COUNT(*) AS Novedades_esperado_1 FROM @nv;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
DECLARE @emp nvarchar(20), @con nvarchar(20), @fecha date, @imp decimal(18,2), @tl nvarchar(20), @nombre nvarchar(100), @conv nvarchar(20), @cat nvarchar(20), @per nvarchar(6), @obs nvarchar(250);
DECLARE @cs nvarchar(max), @sql nvarchar(max);
DECLARE cur CURSOR FOR SELECT emp,con,fecha,imp,tl,nombre,conv,cat,per,obs FROM @nv;
OPEN cur; FETCH cur INTO @emp,@con,@fecha,@imp,@tl,@nombre,@conv,@cat,@per,@obs;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @cs = (SELECT STRING_AGG(CASE c.name
      WHEN N'No_ Empleado' THEN N'@emp' WHEN N'Nombre Empleado' THEN N'@nombre' WHEN N'Cód_ Convenio' THEN N'@conv' WHEN N'Cód_ Categoría' THEN N'@cat' WHEN N'Cód_ Período' THEN N'@per'
      WHEN N'Fecha' THEN N'@fecha' WHEN N'Cód_ Concepto' THEN N'@con' WHEN N'Importe' THEN N'@imp' WHEN N'Cantidad' THEN N'0' WHEN N'Observaciones' THEN N'@obs'
      WHEN N'Estado' THEN N'0' WHEN N'No_ Liquidación' THEN N'''''' WHEN N'Motivo No Aplicada' THEN N'''''' WHEN N'Cód_ Tipo Liq_' THEN N'@tl' WHEN N'No_ Proyecto' THEN N''''''
      ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
  SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs + @sys + N' FROM ' + @T + N' WHERE [No_ Movimiento]=' + CAST(@tpl AS nvarchar(20)) + N';';
  EXEC sp_executesql @sql, N'@emp nvarchar(20),@con nvarchar(20),@fecha date,@imp decimal(18,2),@tl nvarchar(20),@nombre nvarchar(100),@conv nvarchar(20),@cat nvarchar(20),@per nvarchar(6),@obs nvarchar(250)', @emp,@con,@fecha,@imp,@tl,@nombre,@conv,@cat,@per,@obs;
  FETCH cur INTO @emp,@con,@fecha,@imp,@tl,@nombre,@conv,@cat,@per,@obs;
END
CLOSE cur; DEALLOCATE cur;
SELECT n.[Cód_ Concepto] c, CONVERT(varchar(7),n.Fecha,120) mes, n.Estado s, COUNT(*) n, SUM(n.Importe) imp FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.Observaciones LIKE N'Meta4 marzo 2026 (feriado de 00406 sin la antigüedad del franco)%' GROUP BY n.[Cód_ Concepto], CONVERT(varchar(7),n.Fecha,120), n.Estado ORDER BY 1,2;
COMMIT;



