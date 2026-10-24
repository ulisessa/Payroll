/* ADICIONAL TAREAS MECÁNICAS (2073) DE MARZO: TRES CEROS EXPLÍCITOS DE META4 QUE NO ESTABAN MIGRADOS.
   00406, 03039 y 04710 tienen en Meta4 la incidencia 2073 = 0 cargada en marzo (18/3 y 25/3), junto con la guardia en puerto (2013) como importe: el liquidador apagó a mano el 15 % de tareas mecánicas.
   BC lo pagaba por fórmula (1.331.294 / 793.377 / 104.812; +2.229.483 sobre Meta4). En febrero ya se había cargado el cero de 03039 (novedad aplicada); los de marzo no estaban.
   Cambio: tres novedades de cero explícito (importe 0, cantidad 0: el concepto no paga y la fórmula ni se evalúa) con la fecha de la incidencia de Meta4, sin tipo de liquidación, Pendientes.
   Rollback: borrar las tres novedades con Observaciones "Meta4 marzo 2026 (2073)%".
   Después: reiniciar el servicio y recalcular la REGULAR de marzo de los tres. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Observaciones LIKE N'Meta4 marzo 2026 (2073)%')
BEGIN PRINT 'Ya existen las novedades'; ROLLBACK; RETURN; END;
DECLARE @tpl int = 11604;
DECLARE @nv TABLE (emp nvarchar(20), nombre nvarchar(100), conv nvarchar(20), cat nvarchar(20), per nvarchar(6), fecha date, obs nvarchar(250));
INSERT @nv
SELECT l.[No_ Empleado], l.[Nombre Empleado], l.[Cód_ Convenio], l.[Cód_ Categoría], l.[Cód_ Período], x.fecha, N'Meta4 marzo 2026 (2073): cero explícito, incidencia 2073 = 0 cargada el ' + CONVERT(nvarchar(10), x.fecha, 103)
FROM dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
JOIN (VALUES (N'03039',CAST('20260318' AS date)),(N'00406',CAST('20260325' AS date)),(N'04710',CAST('20260325' AS date))) x(emp,fecha) ON x.emp=l.[No_ Empleado]
WHERE l.[Cód_ Período]='202603' AND l.[Cód_ Tipo Liq_]='REGULAR';
SELECT COUNT(*) AS Novedades_esperado_3 FROM @nv;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
DECLARE @emp nvarchar(20), @nombre nvarchar(100), @conv nvarchar(20), @cat nvarchar(20), @per nvarchar(6), @fecha date, @obs nvarchar(250);
DECLARE @cs nvarchar(max), @sql nvarchar(max);
DECLARE cur CURSOR FOR SELECT emp,nombre,conv,cat,per,fecha,obs FROM @nv;
OPEN cur; FETCH cur INTO @emp,@nombre,@conv,@cat,@per,@fecha,@obs;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @cs = (SELECT STRING_AGG(CASE c.name
      WHEN N'No_ Empleado' THEN N'@emp' WHEN N'Nombre Empleado' THEN N'@nombre' WHEN N'Cód_ Convenio' THEN N'@conv' WHEN N'Cód_ Categoría' THEN N'@cat' WHEN N'Cód_ Período' THEN N'@per'
      WHEN N'Fecha' THEN N'@fecha' WHEN N'Cód_ Concepto' THEN N'''2073''' WHEN N'Importe' THEN N'0' WHEN N'Cantidad' THEN N'0' WHEN N'Observaciones' THEN N'@obs'
      WHEN N'Estado' THEN N'0' WHEN N'No_ Liquidación' THEN N'''''' WHEN N'Motivo No Aplicada' THEN N'''''' WHEN N'Cód_ Tipo Liq_' THEN N'''''' WHEN N'No_ Proyecto' THEN N''''''
      ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
  SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs + @sys + N' FROM ' + @T + N' WHERE [No_ Movimiento]=' + CAST(@tpl AS nvarchar(20)) + N';';
  EXEC sp_executesql @sql, N'@emp nvarchar(20),@nombre nvarchar(100),@conv nvarchar(20),@cat nvarchar(20),@per nvarchar(6),@fecha date,@obs nvarchar(250)', @emp,@nombre,@conv,@cat,@per,@fecha,@obs;
  FETCH cur INTO @emp,@nombre,@conv,@cat,@per,@fecha,@obs;
END
CLOSE cur; DEALLOCATE cur;
SELECT n.[No_ Movimiento] m,n.[No_ Empleado] e,CONVERT(varchar(10),n.Fecha,120) f,CAST(n.Importe AS decimal(14,2)) i,CAST(n.Cantidad AS decimal(8,2)) q,n.Estado s,n.[No_ Liquidación] nl FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.Observaciones LIKE N'Meta4 marzo 2026 (2073)%' ORDER BY 1;
COMMIT;
