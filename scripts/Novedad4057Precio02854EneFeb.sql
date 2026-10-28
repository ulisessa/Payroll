/* PRECIO DIARIO DE ENFERMEDAD (4057) DE 02854 EN ENERO Y FEBRERO DE 2026.
   Meta4 paga la enfermedad con un precio diario informado: PRE_ENFER = 135.153,34 (incidencia 4057 del 25/1) x 26 días x 30 % en enero (1.054.196,05) y x 5 días en febrero (675.766,70).
   El 4110 de BC usa PRECIO_ENF_INF (fuente: suma del Valor Unitario de las novedades 4057 del empleado en el período, ignora las Anuladas) y, sin precio, el promedio PROM_ENF_MES (4.242.019,92 -> 141.400,66 por día).
   02854 no tenía novedad 4057: su enero se igualaba con la novedad 9431 (4110 por importe, "Diferencia sin causa identificada al 28/9/2026"), anulada el 16/10 al pasar al precio informado, y febrero nunca se igualó.
   Resultado: 4110 de BC 1.102.925,18 (enero, +48.729,13) y 707.003,32 (febrero, +31.236,62); esa diferencia se arrastra a descuentos, Ganancias y contribuciones desde enero. Es el único empleado con diferencia de 4110 entre enero y marzo (64 de 66 casos mes-empleado coinciden).
   Cambio: dos novedades 4057 (enero y febrero) con Valor Unitario 135.153,34, copia de las de 01961 (mismo molde, Estado Pendiente). Marzo no tiene días de enfermedad.
   Rollback: borrar las dos novedades (Observaciones 'Meta4 4057: precio diario informado (PR_ENFERMEDAD)' de 02854).
   Después: reiniciar el servicio y recalcular en cadena enero, febrero y marzo de 02854. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @N nvarchar(300) = N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_ Empleado]='02854' AND [Cód_ Concepto]=N'4057' AND [Cód_ Período] IN ('202601','202602'))
BEGIN PRINT 'Ya existen'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max), @sql nvarchar(max), @i int = 0;
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@N) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.is_identity = 0 AND c.name NOT IN (N'No_ Empleado', N'Nombre Empleado', N'Valor Unitario', N'Estado', N'No_ Liquidación'));
DECLARE @molde TABLE (mov int, per char(6));
INSERT @molde VALUES (11519,'202601'),(11523,'202602');
DECLARE @mov int;
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT mov FROM @molde;
OPEN cur; FETCH NEXT FROM cur INTO @mov;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @sql = N'INSERT ' + @N + N' ([No_ Empleado],[Nombre Empleado],[Valor Unitario],[Estado],[No_ Liquidación],' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ''02854'', (SELECT TOP 1 CONCAT(e.[First Name],'' '',e.[Last Name]) FROM dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e WHERE e.[No_]=''02854''), 135153.34, 0, '''', ' + @cc
     + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @N + N' WHERE [No_ Movimiento]=' + CAST(@mov AS nvarchar(20)) + N' AND [Cód_ Concepto]=N''4057'';';
  EXEC sp_executesql @sql;
  SET @i += @@ROWCOUNT;
  FETCH NEXT FROM cur INTO @mov;
END
CLOSE cur; DEALLOCATE cur;
SELECT @i AS Altas_esperado_2;
SELECT n.[No_ Movimiento] mov,n.[Cód_ Período] p,CONVERT(varchar(10),n.Fecha,120) f,CAST(n.[Valor Unitario] AS decimal(18,2)) vu,CAST(n.Estado AS int) est FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.[No_ Empleado]='02854' AND n.[Cód_ Concepto]='4057';
COMMIT;
