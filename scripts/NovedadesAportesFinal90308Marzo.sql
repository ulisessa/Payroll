/* APORTES DE LA FINAL DE 90308 (6000, 6010, 6030): IGUALAR A META4 CON NOVEDADES.
   90308 (FA, baja el 13/3) cobra una base de aportes que supera el tope SIPA prorrateado. BC prorratea el tope por los días de alta del mes comercial (DIAS_ALTA_30 = 13: 4.045.590,45 x 13 / 30 = 1.753.089,18) y Meta4 por 14
   (CANT_DIAS_TOPE = 14 con DIAS_ALTA = 13: 1.887.942,21 = REMUN_IMPO). Diferencia de base 134.853,03: jubilación 11 % 207.673,64 contra 192.839,81 (+14.833,83), ley 19032 y obra social 3 % 56.638,27 contra 52.592,68 (+4.045,59 c/u).
   El mismo +1 aparece en 90315 (baja el 12/3: DIAS_ALTA 12, CANT_DIAS_TOPE 13), donde el tope no corta y no se nota; en las finales procesadas en la corrida del 11/3 (04020, 04669...) los dos valores coinciden. Es una regla de Meta4 para las bajas
   liquidadas en la corrida mensual (concepto 551, sin una fórmula que lo explique con dos casos). Decisión del usuario (20/10/2026, "seguí con 90308"): se iguala el caso con tres novedades de importe (reemplazan a la fórmula),
   con lo que pagó Meta4. Fecha 13/3 (última del tramo de la final), sin tipo de liquidación, Pendientes. No se cambia la fórmula.
   Rollback: borrar las novedades con Observaciones "Meta4 marzo 2026 (aportes de la final de 90308 con un día más de tope)%". Después: reiniciar el servicio y recalcular la LIQ_FINAL de marzo de 90308. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Observaciones LIKE N'Meta4 marzo 2026 (aportes de la final de 90308 con un día más de tope)%')
BEGIN PRINT 'Ya existen las novedades'; ROLLBACK; RETURN; END;
DECLARE @tpl int = 11604;
DECLARE @nv TABLE (emp nvarchar(20), con nvarchar(20), fecha date, imp decimal(18,2), tl nvarchar(20), nombre nvarchar(100), conv nvarchar(20), cat nvarchar(20), per nvarchar(6), obs nvarchar(250));
INSERT @nv (emp,con,fecha,imp,tl,nombre,conv,cat,per,obs)
SELECT x.emp, x.con, x.fecha, x.imp, x.tl,
  ISNULL((SELECT TOP 1 n.[Nombre Empleado] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.[No_ Empleado]=x.emp ORDER BY n.[No_ Movimiento] DESC), N''),
  ISNULL((SELECT TOP 1 n.[Cód_ Convenio] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.[No_ Empleado]=x.emp ORDER BY n.[No_ Movimiento] DESC), N''),
  ISNULL((SELECT TOP 1 n.[Cód_ Categoría] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.[No_ Empleado]=x.emp ORDER BY n.[No_ Movimiento] DESC), N''),
  CONVERT(varchar(6), x.fecha, 112), N'Meta4 marzo 2026 (aportes de la final de 90308 con un día más de tope): incidencia ' + x.con + N' del ' + CONVERT(nvarchar(10), x.fecha, 103)
FROM (VALUES (N'90308',N'6000',CAST('20260313' AS date),CAST(207673.64 AS decimal(18,2)),N''),
 (N'90308',N'6010',CAST('20260313' AS date),CAST(56638.27 AS decimal(18,2)),N''),
 (N'90308',N'6030',CAST('20260313' AS date),CAST(56638.27 AS decimal(18,2)),N'')) x(emp,con,fecha,imp,tl);
SELECT COUNT(*) AS Novedades_esperado_3 FROM @nv;
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
SELECT n.[Cód_ Concepto] c, CONVERT(varchar(7),n.Fecha,120) mes, n.Estado s, COUNT(*) n, SUM(n.Importe) imp FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.Observaciones LIKE N'Meta4 marzo 2026 (aportes de la final de 90308 con un día más de tope)%' GROUP BY n.[Cód_ Concepto], CONVERT(varchar(7),n.Fecha,120), n.Estado ORDER BY 1,2;
COMMIT;



