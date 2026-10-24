/* ENFERMEDAD (4110) DE 02670, 04216 Y 00191 (ENERO A MARZO): FIJAR LO QUE PAGÓ META4 CON LA HISTORIA NUEVA.
   Al reconstruir BASE_PROMEDIO de julio a diciembre de 2025 (scripts/BasePromedioHistoricaReconstruccion.sql) cambió el promedio de 12 meses de la enfermedad de estos tres empleados y el 4110 de BC dejó de coincidir
   con Meta4 (02670: +201.550 / +606.817 / +671.833; 04216: +29.704 / +145.917 / +161.551; 00191: +89.493 / +65.086 en febrero y marzo). Meta4 liquidó esos meses con la historia sin las corridas de remuneración
   cero / parciales de octubre y diciembre (en 02670 además informó el precio: incidencia 4057 = 207.568,94). Se fija lo que pagó Meta4 con novedades de importe (reemplazan a la fórmula), con la fecha de arranque de la REGULAR,
   sin tipo de liquidación, Pendientes:
     02670: enero 1.930.391,14 | febrero 5.811.930,32 | marzo 6.434.637,14
     04216: enero 798.042,64   | febrero 3.920.209,44 | marzo 4.340.231,88
     00191:                      febrero 1.681.299,63 | marzo 1.222.763,37
   Enero de 02670 y 04216: se reactivan las novedades 9429 y 9436, que estaban Anuladas desde el 28/9 ("Diferencia sin causa identificada") con esos mismos importes. Las otras seis son nuevas.
   Rollback: borrar las seis novedades nuevas (Observaciones "Meta4 (importe fijado por la historia nueva): enfermedad%") y volver la 9429 y la 9436 a Estado 2 (Anulada).
   Después: reiniciar el servicio y recalcular enero a marzo de 02670 y 04216 y febrero y marzo de 00191 (las REGULAR). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Observaciones LIKE N'Meta4 (importe fijado por la historia nueva): enfermedad%')
BEGIN PRINT 'Ya existen las novedades'; ROLLBACK; RETURN; END;

UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET Estado=0, [No_ Liquidación]='', [Motivo No Aplicada]='', Observaciones=N'Meta4 (importe fijado por la historia nueva): enfermedad de enero', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [No_ Movimiento] IN (9429,9436) AND Estado=2 AND [Cód_ Concepto]=N'4110';
SELECT @@ROWCOUNT AS Reactivadas_esperado_2;

DECLARE @tpl int = 11604;
DECLARE @nv TABLE (emp nvarchar(20), nombre nvarchar(100), conv nvarchar(20), cat nvarchar(20), per nvarchar(6), fecha date, imp decimal(18,2), obs nvarchar(250));
INSERT @nv
SELECT l.[No_ Empleado], l.[Nombre Empleado], l.[Cód_ Convenio], l.[Cód_ Categoría], l.[Cód_ Período], CAST(l.[Cobertura Desde] AS date), x.imp, N'Meta4 (importe fijado por la historia nueva): enfermedad de ' + x.mes
FROM dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
JOIN (VALUES (N'02670',N'202602',CAST(5811930.32 AS decimal(18,2)),N'febrero'),(N'02670',N'202603',CAST(6434637.14 AS decimal(18,2)),N'marzo'),
             (N'04216',N'202602',CAST(3920209.44 AS decimal(18,2)),N'febrero'),(N'04216',N'202603',CAST(4340231.88 AS decimal(18,2)),N'marzo'),
             (N'00191',N'202602',CAST(1681299.63 AS decimal(18,2)),N'febrero'),(N'00191',N'202603',CAST(1222763.37 AS decimal(18,2)),N'marzo')) x(emp,per,imp,mes) ON x.emp=l.[No_ Empleado] AND x.per=l.[Cód_ Período]
WHERE l.[Cód_ Tipo Liq_]='REGULAR';
SELECT COUNT(*) AS Novedades_esperado_6 FROM @nv;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
DECLARE @emp nvarchar(20), @nombre nvarchar(100), @conv nvarchar(20), @cat nvarchar(20), @per nvarchar(6), @fecha date, @imp decimal(18,2), @obs nvarchar(250);
DECLARE @cs nvarchar(max), @sql nvarchar(max);
DECLARE cur CURSOR FOR SELECT emp,nombre,conv,cat,per,fecha,imp,obs FROM @nv;
OPEN cur; FETCH cur INTO @emp,@nombre,@conv,@cat,@per,@fecha,@imp,@obs;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @cs = (SELECT STRING_AGG(CASE c.name
      WHEN N'No_ Empleado' THEN N'@emp' WHEN N'Nombre Empleado' THEN N'@nombre' WHEN N'Cód_ Convenio' THEN N'@conv' WHEN N'Cód_ Categoría' THEN N'@cat' WHEN N'Cód_ Período' THEN N'@per'
      WHEN N'Fecha' THEN N'@fecha' WHEN N'Cód_ Concepto' THEN N'''4110''' WHEN N'Importe' THEN N'@imp' WHEN N'Cantidad' THEN N'0' WHEN N'Observaciones' THEN N'@obs'
      WHEN N'Estado' THEN N'0' WHEN N'No_ Liquidación' THEN N'''''' WHEN N'Motivo No Aplicada' THEN N'''''' WHEN N'Cód_ Tipo Liq_' THEN N'''''' WHEN N'No_ Proyecto' THEN N''''''
      ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
  SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs + @sys + N' FROM ' + @T + N' WHERE [No_ Movimiento]=' + CAST(@tpl AS nvarchar(20)) + N';';
  EXEC sp_executesql @sql, N'@emp nvarchar(20),@nombre nvarchar(100),@conv nvarchar(20),@cat nvarchar(20),@per nvarchar(6),@fecha date,@imp decimal(18,2),@obs nvarchar(250)', @emp,@nombre,@conv,@cat,@per,@fecha,@imp,@obs;
  FETCH cur INTO @emp,@nombre,@conv,@cat,@per,@fecha,@imp,@obs;
END
CLOSE cur; DEALLOCATE cur;
SELECT n.[No_ Movimiento] m,n.[No_ Empleado] e,n.[Cód_ Período] p,CONVERT(varchar(10),n.Fecha,120) f,CAST(n.Importe AS decimal(14,2)) i,n.Estado s,n.[No_ Liquidación] nl FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.Observaciones LIKE N'Meta4 (importe fijado por la historia nueva): enfermedad%' ORDER BY 2,3;
COMMIT;
