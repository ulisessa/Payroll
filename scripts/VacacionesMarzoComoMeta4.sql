/* VACACIONES DE MARZO 2026 (3553): DEJARLAS COMO EN META4.
   Diferencias de marzo en el 3553 (9 empleados):
   A. Base histórica de octubre de 2025 (01937, 02737, 02854, 03660, 04207, 04706): el promedio de vacaciones suma 6 meses de TOT_PROMEDIOS por fecha de imputación (septiembre a febrero). En BC los meses
      coinciden con Meta4 salvo octubre de 2025: el HIST_REMUN de ese mes tiene BASE_PROMEDIO por debajo del bruto (HIST_REMUN_BRUTO, que SÍ coincide con el TOT_PROMEDIOS de Meta4); Meta4 promedia el
      total del mes. Se pone BASE_PROMEDIO = TOT_PROMEDIOS de octubre de Meta4 en esas 6 líneas (HIST_REMUN, período 202510). Diferencias: 2.441.180,04 / 94.631,07 / 2.249.035,89 / 2.174.496,13 / 973.539,15 / 1.094.696,64.
   B. Precio informado a mano en Meta4 (03073 y 04706): Meta4 tiene una incidencia 4056 PRE_VACACIONES cargada el 27/3 (234.681,04 y 77.285,50 por día) que pisa el promedio. Se cargan dos novedades de importe
      sobre el 3553 (reemplazan a la fórmula): 03073 = 8.213.836,40 (35 días) y 04706 = 1.081.997,00 (14 días).
   C. 04495: la novedad 11603 pagaba 22 días de vacaciones ("1 residual + 21") y Meta4 pagó 21 (1.826.164,11 = 21 x 86.960,20). Se deja en 21 días.
   Respaldo de las 6 líneas del punto A: exportadas antes de correr (scratchpad de la sesión, backup_base_promedio_oct2025.psv).
   Rollback: A) volver BASE_PROMEDIO de esas 6 líneas a los valores del respaldo; B) borrar las dos novedades con Observaciones "Meta4 marzo 2026 (vacaciones)..."; C) volver la 11603 a 22 días.
   Después: reiniciar el servicio y recalcular las VACACIONES de marzo de los 9 empleados (y su Regular si cambia algo). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
-- A. BASE_PROMEDIO de octubre de 2025
DECLARE @a TABLE (emp nvarchar(20), nuevo decimal(18,2));
INSERT @a VALUES (N'01937',4831935.52),(N'02737',2600263.77),(N'02854',5291112.09),(N'03660',5440469.62),(N'04207',4826629.94),(N'04706',1737823.61);
UPDATE l SET l.Importe = a.nuevo, l.[$systemModifiedAt] = SYSUTCDATETIME()
FROM dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l JOIN @a a ON a.emp = l.[No_ Empleado]
WHERE l.[Cód_ Período]='202510' AND l.[Cód_ Tipo Liq_]='HIST_REMUN' AND l.[Cód_ Concepto]='BASE_PROMEDIO' AND l.Importe < a.nuevo;
SELECT @@ROWCOUNT AS Lineas_base_promedio_esperado_6;

-- B. Novedades de importe sobre el 3553
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Observaciones LIKE N'Meta4 marzo 2026 (vacaciones)%')
BEGIN PRINT 'Ya existen las novedades de vacaciones'; ROLLBACK; RETURN; END;
DECLARE @tpl int = 11604; -- molde: una novedad de importe de este lote
DECLARE @nv TABLE (emp nvarchar(20), nombre nvarchar(100), conv nvarchar(20), cat nvarchar(20), fecha date, imp decimal(18,2), obs nvarchar(250));
INSERT @nv
SELECT l.[No_ Empleado], l.[Nombre Empleado], l.[Cód_ Convenio], l.[Cód_ Categoría], CAST(l.[Cobertura Desde] AS date), x.imp, x.obs
FROM dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
JOIN (VALUES (N'03073',CAST(8213836.40 AS decimal(18,2)),N'Meta4 marzo 2026 (vacaciones): precio informado 234.681,04 por día x 35 días (incidencia 4056)'),
             (N'04706',CAST(1081997.00 AS decimal(18,2)),N'Meta4 marzo 2026 (vacaciones): precio informado 77.285,50 por día x 14 días (incidencia 4056)')) x(emp,imp,obs) ON x.emp=l.[No_ Empleado]
WHERE l.[Cód_ Período]='202603' AND l.[Cód_ Tipo Liq_]='VACACIONES';
SELECT COUNT(*) AS Novedades_esperado_2 FROM @nv;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
DECLARE @emp nvarchar(20), @nombre nvarchar(100), @conv nvarchar(20), @cat nvarchar(20), @fecha date, @imp decimal(18,2), @obs nvarchar(250);
DECLARE @cs nvarchar(max), @sql nvarchar(max);
DECLARE cur CURSOR FOR SELECT emp,nombre,conv,cat,fecha,imp,obs FROM @nv;
OPEN cur; FETCH cur INTO @emp,@nombre,@conv,@cat,@fecha,@imp,@obs;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @cs = (SELECT STRING_AGG(CASE c.name
      WHEN N'No_ Empleado' THEN N'@emp' WHEN N'Nombre Empleado' THEN N'@nombre' WHEN N'Cód_ Convenio' THEN N'@conv' WHEN N'Cód_ Categoría' THEN N'@cat'
      WHEN N'Fecha' THEN N'@fecha' WHEN N'Cód_ Concepto' THEN N'''3553''' WHEN N'Importe' THEN N'@imp' WHEN N'Cantidad' THEN N'0' WHEN N'Observaciones' THEN N'@obs'
      WHEN N'Estado' THEN N'0' WHEN N'No_ Liquidación' THEN N'''''' WHEN N'Motivo No Aplicada' THEN N'''''' WHEN N'Cód_ Tipo Liq_' THEN N'''''' WHEN N'No_ Proyecto' THEN N''''''
      ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
  SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs + @sys + N' FROM ' + @T + N' WHERE [No_ Movimiento]=' + CAST(@tpl AS nvarchar(20)) + N';';
  EXEC sp_executesql @sql, N'@emp nvarchar(20),@nombre nvarchar(100),@conv nvarchar(20),@cat nvarchar(20),@fecha date,@imp decimal(18,2),@obs nvarchar(250)', @emp,@nombre,@conv,@cat,@fecha,@imp,@obs;
  FETCH cur INTO @emp,@nombre,@conv,@cat,@fecha,@imp,@obs;
END
CLOSE cur; DEALLOCATE cur;

-- C. 04495: 21 días
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET Cantidad = 21, Observaciones = N'Meta4 marzo: 21 días de vacaciones (2 al 22/3); valorizar por fórmula. Antes 22 (1 residual del tramo anterior que Meta4 no pagó).', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [No_ Movimiento]=11603 AND [No_ Empleado]=N'04495' AND Cantidad=22;
SELECT @@ROWCOUNT AS Novedad_04495_esperado_1;
SELECT n.[No_ Movimiento] m,n.[No_ Empleado] e,n.[Cód_ Concepto] c,CONVERT(varchar(10),n.Fecha,120) f,CAST(n.Importe AS decimal(14,2)) i,CAST(n.Cantidad AS decimal(8,2)) q,n.Estado s,n.[No_ Liquidación] nl FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.Observaciones LIKE N'Meta4 marzo 2026 (vacaciones)%' OR n.[No_ Movimiento]=11603 ORDER BY 1;
COMMIT;

-- NOTA (20/10/2026): de las seis líneas del punto A sólo quedan corregidas 01937, 02737, 02854, 03660 y 04207; la de 04706 se revirtió (scripts/BasePromedioHistoricaRevertir.sql) porque su vacación va por el precio informado. Ver la lección vacaciones-marzo-base-octubre-y-precio-informado.
