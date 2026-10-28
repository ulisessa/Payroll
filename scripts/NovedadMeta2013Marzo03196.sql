/* 2013 DE 03196 EN MARZO DE 2026: IGUALAR A META4 CON UNA NOVEDAD (TC DE LA CORRIDA DEL 18/3).
   Meta4 pagó los 20 días de guardia de puerto de 03196 en una corrida aparte del 18/3 y valuó el garantizado al TC de ese día (1.360): 4.065 USD / 30 x 20 x 1.360 x 1,4 = 5.159.840 - 1.147.500 = 4.012.340.
   BC calcula la regular al TC del mes (1.355) y da 3.993.370 (-18.970). Decisión del usuario (20/10/2026): igualarlo con una novedad.
   Novedad de importe (reemplaza a la fórmula), fecha 18/3, sin tipo de liquidación, Pendiente. El 2073 (15 % de 1083 + 2013 + antigüedad de los días de GP, ver Vigencia2073AntiguedadSinFrancos.sql) lee este importe: queda en 773.976 como Meta4.
   Rollback: borrar la novedad con Observaciones "Meta4 marzo 2026 (2013 de 03196 a TC 1.360)%". Después: reiniciar el servicio y recalcular la REGULAR de marzo de 03196. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Observaciones LIKE N'Meta4 marzo 2026 (2013 de 03196 a TC 1.360)%')
BEGIN PRINT 'Ya existen las novedades'; ROLLBACK; RETURN; END;
DECLARE @tpl int = 11604;
DECLARE @nv TABLE (emp nvarchar(20), con nvarchar(20), fecha date, imp decimal(18,2), tl nvarchar(20), nombre nvarchar(100), conv nvarchar(20), cat nvarchar(20), per nvarchar(6), obs nvarchar(250));
INSERT @nv (emp,con,fecha,imp,tl,nombre,conv,cat,per,obs)
SELECT x.emp, x.con, x.fecha, x.imp, x.tl,
  ISNULL((SELECT TOP 1 n.[Nombre Empleado] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.[No_ Empleado]=x.emp ORDER BY n.[No_ Movimiento] DESC), N''),
  ISNULL((SELECT TOP 1 n.[Cód_ Convenio] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.[No_ Empleado]=x.emp ORDER BY n.[No_ Movimiento] DESC), N''),
  ISNULL((SELECT TOP 1 n.[Cód_ Categoría] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.[No_ Empleado]=x.emp ORDER BY n.[No_ Movimiento] DESC), N''),
  CONVERT(varchar(6), x.fecha, 112), N'Meta4 marzo 2026 (2013 de 03196 a TC 1.360): incidencia ' + x.con + N' del ' + CONVERT(nvarchar(10), x.fecha, 103)
FROM (VALUES (N'03196',N'2013',CAST('20260318' AS date),CAST(4012340.00 AS decimal(18,2)),N'')) x(emp,con,fecha,imp,tl);
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
SELECT n.[Cód_ Concepto] c, CONVERT(varchar(7),n.Fecha,120) mes, n.Estado s, COUNT(*) n, SUM(n.Importe) imp FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.Observaciones LIKE N'Meta4 marzo 2026 (2013 de 03196 a TC 1.360)%' GROUP BY n.[Cód_ Concepto], CONVERT(varchar(7),n.Fecha,120), n.Estado ORDER BY 1,2;
COMMIT;



