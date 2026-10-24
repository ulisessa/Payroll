/* NOVEDADES DE LAS FINALES DE 04185 Y 04020 (MARZO 2026): DEJARLAS COMO EN META4.
   Con el ajuste de Francos de la final (20/10/2026) las dos finales calculan. Quedan dos diferencias de criterio con Meta4, que paga lo que se carga como incidencia y no lo que dicen los estados:
     04185: los 3 días de Órdenes (8 al 10/3) los paga BC como 1076 (70.289,80) y Meta4 no los pagó; además cuentan en la antigüedad (1053): BC 28.115,92, Meta4 19.681,14.
     04020: el día de Órdenes (13/3) lo paga BC como 1076 (23.429,93) y Meta4 lo pagó como puerto (incidencia DIAS_PUERTO 1 -> 1083 = 67.749,97).
   Decisión del usuario: igualar a Meta4 con novedades. Se cargan cuatro, con fecha en el último día de cobertura de cada final (la baja), sin tipo de liquidación, Pendientes:
     04185 / 1076:  cero explícito (importe 0, cantidad 0): el concepto no paga y la fórmula ni se evalúa.
     04185 / 1053:  importe 19.681,14 (reemplaza a la fórmula).
     04020 / 1076:  cero explícito.
     04020 / 1083:  importe 67.749,97 (reemplaza a la fórmula).
   (No. Movimiento es una columna de identidad: no se inserta, la numera la base.)
   Rollback: borrar esas cuatro novedades (Observaciones que empiezan con "Meta4 marzo 2026 (final)") y recalcular las dos finales.
   Después: reiniciar el servicio y recalcular las finales de marzo de 04185 y 04020. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Observaciones LIKE N'Meta4 marzo 2026 (final)%')
BEGIN PRINT 'Ya existen las novedades'; ROLLBACK; RETURN; END;
DECLARE @tpl int = 5278; -- novedad ya cargada de una final de marzo, sirve de molde
IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_ Movimiento]=@tpl) BEGIN PRINT 'Falta el molde'; ROLLBACK; RETURN; END;

DECLARE @nv TABLE (emp nvarchar(20), nombre nvarchar(100), conv nvarchar(20), cat nvarchar(20), fecha date, conc nvarchar(20), imp decimal(18,2), obs nvarchar(250));
INSERT @nv
SELECT l.[No_ Empleado], l.[Nombre Empleado], l.[Cód_ Convenio], l.[Cód_ Categoría], CAST(l.[Cobertura Hasta] AS date), x.conc, x.imp, x.obs
FROM dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
JOIN (VALUES (N'04185',N'1076',CAST(0 AS decimal(18,2)),N'Meta4 marzo 2026 (final): los 3 días de Órdenes (8 al 10/3) no se pagaron'),
             (N'04185',N'1053',CAST(19681.14 AS decimal(18,2)),N'Meta4 marzo 2026 (final): antigüedad sin los días de Órdenes'),
             (N'04020',N'1076',CAST(0 AS decimal(18,2)),N'Meta4 marzo 2026 (final): el día de Órdenes (13/3) se pagó como puerto'),
             (N'04020',N'1083',CAST(67749.97 AS decimal(18,2)),N'Meta4 marzo 2026 (final): 1 día de puerto (incidencia DIAS_PUERTO)')) x(emp,conc,imp,obs) ON x.emp=l.[No_ Empleado]
WHERE l.[Cód_ Período]='202603' AND l.[Cód_ Tipo Liq_]='LIQ_FINAL';
SELECT COUNT(*) AS Novedades_esperado_4 FROM @nv;

DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
DECLARE @emp nvarchar(20), @nombre nvarchar(100), @conv nvarchar(20), @cat nvarchar(20), @fecha date, @conc nvarchar(20), @imp decimal(18,2), @obs nvarchar(250);
DECLARE @cs nvarchar(max), @sql nvarchar(max);
DECLARE cur CURSOR FOR SELECT emp,nombre,conv,cat,fecha,conc,imp,obs FROM @nv;
OPEN cur; FETCH cur INTO @emp,@nombre,@conv,@cat,@fecha,@conc,@imp,@obs;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @cs = (SELECT STRING_AGG(CASE c.name
      WHEN N'No_ Empleado' THEN N'@emp'
      WHEN N'Nombre Empleado' THEN N'@nombre'
      WHEN N'Cód_ Convenio' THEN N'@conv'
      WHEN N'Cód_ Categoría' THEN N'@cat'
      WHEN N'Fecha' THEN N'@fecha'
      WHEN N'Cód_ Concepto' THEN N'@conc'
      WHEN N'Importe' THEN N'@imp'
      WHEN N'Observaciones' THEN N'@obs'
      ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
  SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs + @sys + N' FROM ' + @T + N' WHERE [No_ Movimiento]=' + CAST(@tpl AS nvarchar(20)) + N';';
  EXEC sp_executesql @sql, N'@emp nvarchar(20),@nombre nvarchar(100),@conv nvarchar(20),@cat nvarchar(20),@fecha date,@conc nvarchar(20),@imp decimal(18,2),@obs nvarchar(250)', @emp,@nombre,@conv,@cat,@fecha,@conc,@imp,@obs;
  FETCH cur INTO @emp,@nombre,@conv,@cat,@fecha,@conc,@imp,@obs;
END
CLOSE cur; DEALLOCATE cur;
SELECT n.[No_ Movimiento] m,n.[No_ Empleado] e,n.[Cód_ Concepto] c,CONVERT(varchar(10),n.Fecha,120) f,CAST(n.Importe AS decimal(14,2)) i,CAST(n.Cantidad AS decimal(8,2)) q,n.Estado s,n.[No_ Liquidación] nl FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.Observaciones LIKE N'Meta4 marzo 2026 (final)%' ORDER BY 1;
COMMIT;
-- NOTA: el molde (movimiento 5278) está Aplicado y con el No. de liquidación de la final de 04850: la copia hereda esos dos campos y hay que dejarlos Pendiente y sin liquidación.
-- Se corrigió a mano con: UPDATE ... SET Estado=0, [No_ Liquidación]='', [Motivo No Aplicada]='' WHERE Observaciones LIKE N'Meta4 marzo 2026 (final)%'
