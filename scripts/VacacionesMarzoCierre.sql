/* VACACIONES DE MARZO 2026: LAS DOS QUE QUEDABAN (02937 Y 04495).
   02937: Meta4 pagó 35 días (1.273.066,71 = 35 x 36.373,33, con el mismo promedio de BC: 5.456.000 / 6 / 25). BC pagaba 30: sus vacaciones son AU9 del 2/3 al 31/3 (30 días) y después una licencia por enfermedad
   (AU1 del 1/4 al 26/5) las corta; los 5 días que faltan se toman del 27/5 al 31/5 (AU9). Meta4 paga todos los días de las vacaciones al arrancar, aunque una enfermedad las parta: es el mismo caso
   que el "1 residual" de 04495. Se carga una novedad de 35 días (importe 0: la fórmula valoriza la cantidad), con la fecha de arranque del tramo, sin tipo de liquidación, Pendiente.
   04495: queda +1.884 sobre Meta4 (0,1 %) por una base de 13.458 de más en el promedio. Se deja la novedad 11603 con el importe de Meta4 (1.826.164,11) en lugar de valorizar 21 días.
   Rollback: borrar la novedad de 02937 (Observaciones "Meta4 marzo 2026 (vacaciones): 35 días...") y volver la 11603 a Cantidad 21 / Importe 0.
   Después: reiniciar el servicio y recalcular las VACACIONES de marzo de 02937 y 04495. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE Observaciones LIKE N'Meta4 marzo 2026 (vacaciones): 35 días%')
BEGIN PRINT 'Ya existe la novedad de 02937'; ROLLBACK; RETURN; END;
DECLARE @emp nvarchar(20), @nombre nvarchar(100), @conv nvarchar(20), @cat nvarchar(20), @fecha date;
SELECT @emp=l.[No_ Empleado], @nombre=l.[Nombre Empleado], @conv=l.[Cód_ Convenio], @cat=l.[Cód_ Categoría], @fecha=CAST(l.[Cobertura Desde] AS date)
FROM dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l WHERE l.[Cód_ Período]='202603' AND l.[Cód_ Tipo Liq_]='VACACIONES' AND l.[No_ Empleado]='02937';
IF @emp IS NULL BEGIN PRINT 'No hay VACACIONES de 02937 en marzo'; ROLLBACK; RETURN; END;
DECLARE @obs nvarchar(250) = N'Meta4 marzo 2026 (vacaciones): 35 días (30 del 2 al 31/3 + 5 del 27 al 31/5, cortadas por una licencia); valorizar por fórmula';
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
    WHEN N'No_ Empleado' THEN N'@emp' WHEN N'Nombre Empleado' THEN N'@nombre' WHEN N'Cód_ Convenio' THEN N'@conv' WHEN N'Cód_ Categoría' THEN N'@cat'
    WHEN N'Fecha' THEN N'@fecha' WHEN N'Cód_ Concepto' THEN N'''3553''' WHEN N'Importe' THEN N'0' WHEN N'Cantidad' THEN N'35' WHEN N'Observaciones' THEN N'@obs'
    WHEN N'Estado' THEN N'0' WHEN N'No_ Liquidación' THEN N'''''' WHEN N'Motivo No Aplicada' THEN N'''''' WHEN N'Cód_ Tipo Liq_' THEN N'''''' WHEN N'No_ Proyecto' THEN N''''''
    ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.is_identity = 0 AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs + @sys + N' FROM ' + @T + N' WHERE [No_ Movimiento]=11604;';
EXEC sp_executesql @sql, N'@emp nvarchar(20),@nombre nvarchar(100),@conv nvarchar(20),@cat nvarchar(20),@fecha date,@obs nvarchar(250)', @emp,@nombre,@conv,@cat,@fecha,@obs;
SELECT @@ROWCOUNT AS Novedad_02937_esperado_1;

UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET Cantidad = 0, Importe = 1826164.11, Observaciones = N'Meta4 marzo 2026 (vacaciones): importe de Meta4 (21 días, 1.826.164,11)', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [No_ Movimiento]=11603 AND [No_ Empleado]=N'04495';
SELECT @@ROWCOUNT AS Novedad_04495_esperado_1;
SELECT n.[No_ Movimiento] m,n.[No_ Empleado] e,n.[Cód_ Concepto] c,CONVERT(varchar(10),n.Fecha,120) f,CAST(n.Importe AS decimal(14,2)) i,CAST(n.Cantidad AS decimal(8,2)) q,n.Estado s,n.[No_ Liquidación] nl FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.[No_ Empleado] IN ('02937','04495') AND n.[Cód_ Período]='202603' AND n.[Cód_ Concepto]='3553' ORDER BY 1;
COMMIT;

-- NOTA (20/10/2026): el importe fijo de 04495 se sacó el mismo día: el +1.884 era una base de febrero vieja (la REGULAR de febrero se recalculó después de la vacación de marzo); con febrero al día la fórmula da 1.826.164,11 con 21 días. La novedad 11603 quedó en Cantidad 21 / Importe 0.

-- NOTA (20/10/2026, 2): a pedido del usuario se volvió a cargar el importe de Meta4 (1.826.164,11) en la 11603 (Cantidad 0 / Importe 1826164,11).
