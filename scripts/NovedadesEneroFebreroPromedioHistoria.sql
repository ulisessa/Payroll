/* NOVEDADES DE ENERO Y FEBRERO PARA QUE LA NUEVA HISTORIA DE BASE_PROMEDIO NO CAMBIE LO QUE META4 PAGÓ.
   scripts/BasePromedioHistoricaReconstruccion.sql puso en la historia de julio a diciembre de 2025 todas las corridas de la fase vigente. Seis liquidaciones de enero y febrero de 2026 coincidían con Meta4 con
   la historia anterior, porque Meta4 las liquidó sin las corridas de remuneración cero / parciales de octubre: si se recalculan con la historia nueva dejan de coincidir. Se fija lo que Meta4 pagó con novedades de importe
   (reemplazan a la fórmula), con la fecha de arranque de cada liquidación, sin tipo de liquidación:
     VACACIONES 3553: 00191 (enero) 2.493.907,25 | 00965 (enero) 2.073.813,22 | 02745 (enero) 2.026.249,64 | 03090 (enero) 1.026.074,80 | 03207 (febrero) 6.154.291,89.
     LIQ_FINAL de 04047 (febrero): la novedad 10939 de 12 días del 3973 pasa a importe 5.409.996,71 (el SAC 3974, 450.833,06, sale por fórmula como 3973 / 12).
   Las novedades nuevas quedan Pendientes: valen al recalcular. Lo ya calculado no cambia.
   Rollback: borrar las cinco novedades con Observaciones "Meta4 (importe fijado por la historia nueva)%" y volver la 10939 a Cantidad 12 / Importe 0.
   Después: reiniciar el servicio. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Observaciones LIKE N'Meta4 (importe fijado por la historia nueva)%')
BEGIN PRINT 'Ya existen las novedades'; ROLLBACK; RETURN; END;
DECLARE @tpl int = 11604;
DECLARE @nv TABLE (emp nvarchar(20), nombre nvarchar(100), conv nvarchar(20), cat nvarchar(20), per nvarchar(6), fecha date, imp decimal(18,2), obs nvarchar(250));
INSERT @nv
SELECT l.[No_ Empleado], l.[Nombre Empleado], l.[Cód_ Convenio], l.[Cód_ Categoría], l.[Cód_ Período], CAST(l.[Cobertura Desde] AS date), x.imp,
       N'Meta4 (importe fijado por la historia nueva): vacaciones de ' + x.mes + N', el importe que pagó Meta4'
FROM dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
JOIN (VALUES (N'00191',N'202601',CAST(2493907.25 AS decimal(18,2)),N'enero'),(N'00965',N'202601',CAST(2073813.22 AS decimal(18,2)),N'enero'),(N'02745',N'202601',CAST(2026249.64 AS decimal(18,2)),N'enero'),
             (N'03090',N'202601',CAST(1026074.80 AS decimal(18,2)),N'enero'),(N'03207',N'202602',CAST(6154291.89 AS decimal(18,2)),N'febrero')) x(emp,per,imp,mes) ON x.emp=l.[No_ Empleado] AND x.per=l.[Cód_ Período]
WHERE l.[Cód_ Tipo Liq_]='VACACIONES';
SELECT COUNT(*) AS Novedades_esperado_5 FROM @nv;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
DECLARE @emp nvarchar(20), @nombre nvarchar(100), @conv nvarchar(20), @cat nvarchar(20), @per nvarchar(6), @fecha date, @imp decimal(18,2), @obs nvarchar(250);
DECLARE @cs nvarchar(max), @sql nvarchar(max);
DECLARE cur CURSOR FOR SELECT emp,nombre,conv,cat,per,fecha,imp,obs FROM @nv;
OPEN cur; FETCH cur INTO @emp,@nombre,@conv,@cat,@per,@fecha,@imp,@obs;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @cs = (SELECT STRING_AGG(CASE c.name
      WHEN N'No_ Empleado' THEN N'@emp' WHEN N'Nombre Empleado' THEN N'@nombre' WHEN N'Cód_ Convenio' THEN N'@conv' WHEN N'Cód_ Categoría' THEN N'@cat' WHEN N'Cód_ Período' THEN N'@per'
      WHEN N'Fecha' THEN N'@fecha' WHEN N'Cód_ Concepto' THEN N'''3553''' WHEN N'Importe' THEN N'@imp' WHEN N'Cantidad' THEN N'0' WHEN N'Observaciones' THEN N'@obs'
      WHEN N'Estado' THEN N'0' WHEN N'No_ Liquidación' THEN N'''''' WHEN N'Motivo No Aplicada' THEN N'''''' WHEN N'Cód_ Tipo Liq_' THEN N'''''' WHEN N'No_ Proyecto' THEN N''''''
      ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
  SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs + @sys + N' FROM ' + @T + N' WHERE [No_ Movimiento]=' + CAST(@tpl AS nvarchar(20)) + N';';
  EXEC sp_executesql @sql, N'@emp nvarchar(20),@nombre nvarchar(100),@conv nvarchar(20),@cat nvarchar(20),@per nvarchar(6),@fecha date,@imp decimal(18,2),@obs nvarchar(250)', @emp,@nombre,@conv,@cat,@per,@fecha,@imp,@obs;
  FETCH cur INTO @emp,@nombre,@conv,@cat,@per,@fecha,@imp,@obs;
END
CLOSE cur; DEALLOCATE cur;

UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET Cantidad = 0, Importe = 5409996.71, [$systemModifiedAt]=SYSUTCDATETIME(),
   Observaciones = N'Meta4 (importe fijado por la historia nueva): 3973 de 12 días a 450.833,06 por día'
WHERE [No_ Movimiento]=10939 AND [No_ Empleado]=N'04047' AND [Cód_ Concepto]=N'3973' AND Cantidad=12;
SELECT @@ROWCOUNT AS Novedad_04047_esperado_1;
SELECT n.[No_ Movimiento] m,n.[No_ Empleado] e,n.[Cód_ Período] p,n.[Cód_ Concepto] c,CONVERT(varchar(10),n.Fecha,120) f,CAST(n.Importe AS decimal(14,2)) i,CAST(n.Cantidad AS decimal(8,2)) q,n.Estado s FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.Observaciones LIKE N'Meta4 (importe fijado por la historia nueva)%' ORDER BY 1;
COMMIT;
