/* NOVEDADES DE ABRIL A JUNIO DE 2026 QUE META4 TIENE COMO INCIDENCIAS Y BC NO.
   Se compararon las incidencias de M4T_VAL_INCIDENCIA de abril a junio (2.949) con las novedades de BC por empleado + concepto (con 1582→1583, 4420→4423, 4430→4433) + fecha. Se cargan las que faltan y son de
   conceptos que BC maneja como novedad: 1022 (78, 13/4), 2073 (24, ceros explícitos e importes), 1062 (3, 23/4), 2083 (2 ceros, 23/4), 1053 (1, 25/6) y 4057 (1, 25/6, precio informado).
   No se migran los días (1061, 1071, 1081...), los precios/bases ni los resultados derivados (2003, 5010...), como en las cargas anteriores.
   Cada una: importe de Meta4 (cero = cero explícito, el concepto no paga), cantidad 0, con la fecha de la incidencia, Pendiente. Tipo de liquidación: CIERRE_MAREA para 1022 (como las 103 de febrero y marzo), en blanco el resto.
   Rollback: borrar las novedades con Observaciones "Meta4 abril-junio 2026%".
   Después: reiniciar el servicio. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Observaciones LIKE N'Meta4 abril-junio 2026%')
BEGIN PRINT 'Ya existen las novedades'; ROLLBACK; RETURN; END;
DECLARE @tpl int = 11604;
DECLARE @nv TABLE (emp nvarchar(20), con nvarchar(20), fecha date, imp decimal(18,2), tl nvarchar(20), nombre nvarchar(100), conv nvarchar(20), cat nvarchar(20), per nvarchar(6), obs nvarchar(250));
INSERT @nv (emp,con,fecha,imp,tl,nombre,conv,cat,per,obs)
SELECT x.emp, x.con, x.fecha, x.imp, x.tl,
  ISNULL((SELECT TOP 1 n.[Nombre Empleado] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.[No_ Empleado]=x.emp ORDER BY n.[No_ Movimiento] DESC), N''),
  ISNULL((SELECT TOP 1 n.[Cód_ Convenio] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.[No_ Empleado]=x.emp ORDER BY n.[No_ Movimiento] DESC), N''),
  ISNULL((SELECT TOP 1 n.[Cód_ Categoría] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.[No_ Empleado]=x.emp ORDER BY n.[No_ Movimiento] DESC), N''),
  CONVERT(varchar(6), x.fecha, 112), N'Meta4 abril-junio 2026: incidencia ' + x.con + N' del ' + CONVERT(nvarchar(10), x.fecha, 103)
FROM (VALUES (N'03062',N'1022',CAST('20260413' AS date),CAST(93569.87 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'03481',N'1022',CAST('20260413' AS date),CAST(69547.10 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'03487',N'1022',CAST('20260413' AS date),CAST(116386.16 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'03753',N'1022',CAST('20260413' AS date),CAST(73485.83 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'03772',N'1022',CAST('20260413' AS date),CAST(80825.55 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'03774',N'1022',CAST('20260413' AS date),CAST(86216.34 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'03777',N'1022',CAST('20260413' AS date),CAST(98927.86 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'03856',N'1022',CAST('20260413' AS date),CAST(96936.32 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'03957',N'1022',CAST('20260413' AS date),CAST(115141.44 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'03961',N'1022',CAST('20260413' AS date),CAST(90371.27 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04066',N'1022',CAST('20260413' AS date),CAST(78231.85 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04091',N'1022',CAST('20260413' AS date),CAST(73017.23 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04105',N'1022',CAST('20260413' AS date),CAST(79738.05 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04139',N'1022',CAST('20260413' AS date),CAST(75209.40 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04169',N'1022',CAST('20260413' AS date),CAST(73017.23 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04233',N'1022',CAST('20260413' AS date),CAST(78423.67 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04274',N'1022',CAST('20260413' AS date),CAST(73017.23 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04286',N'1022',CAST('20260413' AS date),CAST(78892.27 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04301',N'1022',CAST('20260413' AS date),CAST(72548.63 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04368',N'1022',CAST('20260413' AS date),CAST(72080.03 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04450',N'1022',CAST('20260413' AS date),CAST(83522.22 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04517',N'1022',CAST('20260413' AS date),CAST(72080.03 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04518',N'1022',CAST('20260413' AS date),CAST(71142.84 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04524',N'1022',CAST('20260413' AS date),CAST(77486.47 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04526',N'1022',CAST('20260413' AS date),CAST(77729.77 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04586',N'1022',CAST('20260413' AS date),CAST(94091.25 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04591',N'1022',CAST('20260413' AS date),CAST(83020.15 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04612',N'1022',CAST('20260413' AS date),CAST(76549.28 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04648',N'1022',CAST('20260413' AS date),CAST(71142.84 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04659',N'1022',CAST('20260413' AS date),CAST(88557.58 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04664',N'1022',CAST('20260413' AS date),CAST(87486.50 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04677',N'1022',CAST('20260413' AS date),CAST(86388.18 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04683',N'1022',CAST('20260413' AS date),CAST(70674.24 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04714',N'1022',CAST('20260413' AS date),CAST(65530.54 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04722',N'1022',CAST('20260413' AS date),CAST(76549.28 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04733',N'1022',CAST('20260413' AS date),CAST(70674.24 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04734',N'1022',CAST('20260413' AS date),CAST(70674.24 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04738',N'1022',CAST('20260413' AS date),CAST(70674.24 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04744',N'1022',CAST('20260413' AS date),CAST(76080.68 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04770',N'1022',CAST('20260413' AS date),CAST(76080.68 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04771',N'1022',CAST('20260413' AS date),CAST(76080.68 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04787',N'1022',CAST('20260413' AS date),CAST(76080.68 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04789',N'1022',CAST('20260413' AS date),CAST(80236.37 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04809',N'1022',CAST('20260413' AS date),CAST(60693.84 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04822',N'1022',CAST('20260413' AS date),CAST(73699.99 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04823',N'1022',CAST('20260413' AS date),CAST(69365.35 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04825',N'1022',CAST('20260413' AS date),CAST(87276.38 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04830',N'1022',CAST('20260413' AS date),CAST(69821.56 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04833',N'1022',CAST('20260413' AS date),CAST(81513.94 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04834',N'1022',CAST('20260413' AS date),CAST(60693.84 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04838',N'1022',CAST('20260413' AS date),CAST(76080.68 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04839',N'1022',CAST('20260413' AS date),CAST(65530.54 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04840',N'1022',CAST('20260413' AS date),CAST(65530.54 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04841',N'1022',CAST('20260413' AS date),CAST(61162.44 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04845',N'1022',CAST('20260413' AS date),CAST(75612.08 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04848',N'1022',CAST('20260413' AS date),CAST(60199.77 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04849',N'1022',CAST('20260413' AS date),CAST(60693.84 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04851',N'1022',CAST('20260413' AS date),CAST(60693.84 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04853',N'1022',CAST('20260413' AS date),CAST(60693.84 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04855',N'1022',CAST('20260413' AS date),CAST(65028.47 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04874',N'1022',CAST('20260413' AS date),CAST(60693.84 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04877',N'1022',CAST('20260413' AS date),CAST(60693.84 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04880',N'1022',CAST('20260413' AS date),CAST(70205.64 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04906',N'1022',CAST('20260413' AS date),CAST(60693.84 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04913',N'1022',CAST('20260413' AS date),CAST(100294.67 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04914',N'1022',CAST('20260413' AS date),CAST(75219.42 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04915',N'1022',CAST('20260413' AS date),CAST(75219.42 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04916',N'1022',CAST('20260413' AS date),CAST(60693.84 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04919',N'1022',CAST('20260413' AS date),CAST(81011.87 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04922',N'1022',CAST('20260413' AS date),CAST(75612.08 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04923',N'1022',CAST('20260413' AS date),CAST(73699.99 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04926',N'1022',CAST('20260413' AS date),CAST(75612.08 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04928',N'1022',CAST('20260413' AS date),CAST(60199.77 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04929',N'1022',CAST('20260413' AS date),CAST(60199.77 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04930',N'1022',CAST('20260413' AS date),CAST(64499.13 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04931',N'1022',CAST('20260413' AS date),CAST(60199.77 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04932',N'1022',CAST('20260413' AS date),CAST(73100.03 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'04933',N'1022',CAST('20260413' AS date),CAST(70205.64 AS decimal(18,2)),N'CIERRE_MAREA'),
             (N'02937',N'1053',CAST('20260625' AS date),CAST(-27498.56 AS decimal(18,2)),N''),
             (N'04163',N'1062',CAST('20260423' AS date),CAST(141780.00 AS decimal(18,2)),N''),
             (N'04455',N'1062',CAST('20260423' AS date),CAST(165600.00 AS decimal(18,2)),N''),
             (N'04836',N'1062',CAST('20260423' AS date),CAST(141780.00 AS decimal(18,2)),N''),
             (N'00406',N'2073',CAST('20260418' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'00406',N'2073',CAST('20260524' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'00406',N'2073',CAST('20260601' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'00406',N'2073',CAST('20260613' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'00406',N'2073',CAST('20260619' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'02153',N'2073',CAST('20260524' AS date),CAST(13998.63 AS decimal(18,2)),N''),
             (N'03039',N'2073',CAST('20260518' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'03039',N'2073',CAST('20260601' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'03039',N'2073',CAST('20260607' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'03039',N'2073',CAST('20260613' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'03196',N'2073',CAST('20260524' AS date),CAST(11872.65 AS decimal(18,2)),N''),
             (N'04313',N'2073',CAST('20260518' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'04313',N'2073',CAST('20260601' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'04313',N'2073',CAST('20260607' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'04313',N'2073',CAST('20260613' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'04320',N'2073',CAST('20260524' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'04320',N'2073',CAST('20260601' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'04320',N'2073',CAST('20260613' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'04320',N'2073',CAST('20260619' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'04710',N'2073',CAST('20260412' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'04710',N'2073',CAST('20260524' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'04710',N'2073',CAST('20260601' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'04710',N'2073',CAST('20260613' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'04710',N'2073',CAST('20260619' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'04163',N'2083',CAST('20260423' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'04836',N'2083',CAST('20260423' AS date),CAST(0.00 AS decimal(18,2)),N''),
             (N'02937',N'4057',CAST('20260625' AS date),CAST(46084.52 AS decimal(18,2)),N'')) x(emp,con,fecha,imp,tl);
SELECT COUNT(*) AS Novedades_esperado_109 FROM @nv;
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
SELECT n.[Cód_ Concepto] c, CONVERT(varchar(7),n.Fecha,120) mes, n.Estado s, COUNT(*) n, SUM(n.Importe) imp FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.Observaciones LIKE N'Meta4 abril-junio 2026%' GROUP BY n.[Cód_ Concepto], CONVERT(varchar(7),n.Fecha,120), n.Estado ORDER BY 1,2;
COMMIT;
