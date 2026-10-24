/* A CUENTA DE FUTUROS AUMENTOS (2083 FRANCOS Y 2013 PUERTO): RESTAR LA ANTIGÜEDAD DE LOS DÍAS PROPIOS Y NO LA DE TODA LA LIQUIDACIÓN.
   Meta4 liquida los días de GP (marea) en una corrida aparte; en su REGULAR el 1053 sólo trae la antigüedad de los días de franco, y eso es lo único que resta el 2083. BC liquida todo el mes en la REGULAR y el
   #1053 incluía la antigüedad de los días de GP: 03039 (-150.000), 03196 (-127.500) y 00406 (-172.500) cobraban menos que en Meta4 (recibos de 03039: 2083 = 165.916,67 contra 15.916,67).
   Cambio: vigencia nueva desde el 1/3/2026 (la anterior se cierra el 28/2) donde cada "a cuenta" resta #1053 * (días propios) / (días que cuenta el 1053):
     2083: #1053 -> #1053 * DIAS_FRANCOS_PERIODO / IFZERO(DIAS_PROYECTO + DIAS_PUERTO + DIAS_GP_PERIODO + DIAS_FRANCOS_PERIODO + DIAS_ORD_PERIODO, 1)
     2013: #1053 -> #1053 * DIAS_GP_PERIODO     / IFZERO(DIAS_PROYECTO + DIAS_PUERTO + DIAS_GP_PERIODO + DIAS_FRANCOS_PERIODO + DIAS_ORD_PERIODO, 1)
   Es exacto mientras el 1053 use un solo precio, porcentaje y coeficiente para todos los días de la liquidación (hoy es así). Si el 1053 pasa a tener un precio por tramo, hay que cambiarlo.
   Rollback: borrar las dos vigencias del 2026-03-01 y volver el "Vigencia Hasta" de las vigencias del 2083 (2026-01-01) y del 2013 (2026-02-03) a 1753-01-01.
   Después: reiniciar el servicio y recalcular marzo (las REGULAR). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN ('2083','2013') AND [Vigencia Desde]='20260301')
BEGIN PRINT 'Ya existen las vigencias'; ROLLBACK; RETURN; END;
DECLARE @dias nvarchar(200) = N'IFZERO(DIAS_PROYECTO + DIAS_PUERTO + DIAS_GP_PERIODO + DIAS_FRANCOS_PERIODO + DIAS_ORD_PERIODO, 1)';
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Fórmula', N'Vigencia Hasta'));
DECLARE @sql nvarchar(max);
SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[Vigencia Desde],[Vigencia Hasta],[Fórmula],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) '
 + N'SELECT ' + @cc + N',''20260301'',''17530101'', REPLACE([Fórmula], N''#1053'', @rep),NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @T
 + N' WHERE [Código]=@c AND [Vigencia Desde]=@d;';
DECLARE @r1 nvarchar(400) = N'(#1053 * DIAS_FRANCOS_PERIODO / ' + @dias + N')';
DECLARE @r2 nvarchar(400) = N'(#1053 * DIAS_GP_PERIODO / ' + @dias + N')';
EXEC sp_executesql @sql, N'@rep nvarchar(400),@c nvarchar(20),@d date', @r1, N'2083', '20260101';
SELECT @@ROWCOUNT AS Altas_2083_esperado_1;
EXEC sp_executesql @sql, N'@rep nvarchar(400),@c nvarchar(20),@d date', @r2, N'2013', '20260203';
SELECT @@ROWCOUNT AS Altas_2013_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260228', [$systemModifiedAt]=SYSUTCDATETIME() WHERE ([Código]='2083' AND [Vigencia Desde]='20260101') OR ([Código]='2013' AND [Vigencia Desde]='20260203');
SELECT @@ROWCOUNT AS Cerradas_esperado_2;
SELECT [Código] c, CONVERT(varchar(10),[Vigencia Desde],120) d, CONVERT(varchar(10),[Vigencia Hasta],120) h, (LEN([Fórmula])-LEN(REPLACE([Fórmula],N'DIAS_FRANCOS_PERIODO / IFZERO',N'')))/29 n_fr, (LEN([Fórmula])-LEN(REPLACE([Fórmula],N'DIAS_GP_PERIODO / IFZERO',N'')))/24 n_gp FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN ('2083','2013') AND [Vigencia Desde]>='20260101' ORDER BY 1,2;
COMMIT;
