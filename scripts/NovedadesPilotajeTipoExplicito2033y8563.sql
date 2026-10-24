/* PILOTAJE DE ABRIL (22/10/2026): 2033 DE 03664 DUPLICADO, 2033 DE 04455 QUE META4 NO PAGA Y CONTRIBUCIÓN SOLIDARIA (8563) CONSUMIDA POR EL CIERRE.
   1. 03664: la novedad 10884 (2033, 684.800, "Meta4 2033", fecha 21/4) quedó con tipo REGULAR y la pagó la regular, y el pilotaje calculaba además la fórmula (474.118): 1.158.918 contra 684.800 de Meta4.
      Las planillas CLC no traen nada del pilotaje; su "Garantía de Máquinas" (15.000 USD) es la garantía de producción. Los 684.800 son una incidencia manual de Meta4 como las otras seis (la coincidencia
      con 1.370.000 - 685.200 es un número redondo cargado a mano), y las incidencias reemplazan a la fórmula. Se tipa PILOTAJE (no se toca el importe).
   2. 04455: Meta4 no pagó 2033 en la corrida de pilotaje (ni incidencia ni fórmula) y la fórmula de BC da 650.690. Se carga una novedad de importe CERO, tipo PILOTAJE, que apaga la fórmula (se copia de la 4878).
   3. 8563 (contribución solidaria SOMU, concepto sin fórmula que se carga por novedades de Meta4): las tres novedades del 21/4 de 04913, 04914 y 04915 (10576, 10811, 10755: 29.454,77 y 22.091,08 x 2) son
      de la corrida de pilotaje (tp12) y las tomó el cierre porque no tenían tipo. Se tipan PILOTAJE; las de las corridas del 13/4 y 20/4 siguen en el cierre y la del 25/4 en la regular.
   Rollback: Tipo Liq. en blanco en 10884 (era REGULAR), 10576, 10811, 10755 (blanco); borrar la novedad nueva de 04455 (Observaciones "Meta4 abril 2026 (2033 pilotaje): sin incidencia").
   Después: reiniciar el servicio y recalcular abril en orden (cierre, pilotaje, regular). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @N nvarchar(300) = N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Observaciones] LIKE N'Meta4 abril 2026 (2033 pilotaje): sin incidencia%')
BEGIN PRINT 'Ya aplicado'; ROLLBACK; RETURN; END;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Cód_ Tipo Liq_]='PILOTAJE', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [No_ Movimiento]=10884 AND [Cód_ Concepto]='2033' AND [Cód_ Tipo Liq_]='REGULAR';
SELECT @@ROWCOUNT AS c2033_03664_esperado_1;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Cód_ Tipo Liq_]='PILOTAJE', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [No_ Movimiento] IN (10576,10811,10755) AND [Cód_ Concepto]='8563' AND [Cód_ Tipo Liq_]='';
SELECT @@ROWCOUNT AS c8563_esperado_3;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@N) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
      WHEN N'No_ Empleado' THEN N'''04455''' WHEN N'Nombre Empleado' THEN N'ISNULL((SELECT TOP 1 x.[Nombre Empleado] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[No_ Empleado]=''04455'' ORDER BY x.[No_ Movimiento] DESC),N'''')'
      WHEN N'Cód_ Convenio' THEN N'''175/75''' WHEN N'Cód_ Categoría' THEN N'''OF02'''
      WHEN N'Importe' THEN N'0' WHEN N'Cantidad' THEN N'0' WHEN N'Observaciones' THEN N'N''Meta4 abril 2026 (2033 pilotaje): sin incidencia, importe cero para apagar la fórmula'''
      WHEN N'Estado' THEN N'0' WHEN N'No_ Liquidación' THEN N'''''' WHEN N'Motivo No Aplicada' THEN N'''''' WHEN N'Cód_ Tipo Liq_' THEN N'''PILOTAJE''' WHEN N'No_ Proyecto' THEN N''''''
      ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@N) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'INSERT ' + @N + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs
  + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @N + N' WHERE [No_ Movimiento]=4878;';
EXEC sp_executesql @sql;
SELECT [No_ Movimiento] mv,[No_ Empleado] e,[Cód_ Concepto] c,[Importe] i,[Cód_ Tipo Liq_] tl,[Cód_ Convenio] cv,[Cód_ Categoría] ct,CONVERT(varchar(10),[Fecha],120) f,[Estado] est FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_ Empleado]='04455' AND [Cód_ Concepto]='2033';
COMMIT;
