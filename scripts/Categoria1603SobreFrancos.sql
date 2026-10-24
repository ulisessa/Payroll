/* CATEGORÍA SUPERIOR (1603) EN LAS LIQUIDACIONES FINALES: LA BASE INCLUYE LA INDEMNIZACIÓN DE FRANCOS NO GOZADOS (2803).
   Febrero de 2026, finales con 1603: 04751 (BC 56.025, Meta4 356.584) y 04139 (BC 41.019, Meta4 169.830). Meta4 aplica la diferencia de escala 75/70 a
   1083 + 1053 + 1063 + 2803: para 04751 (724.246,6 + 5.464,7 + 54.647,1 + 4.207.826) x (0,75 / 0,70 - 1) = 356.584, y para 04139 (2803 = 1.803.354)
   la diferencia es 128.811 = 0,0714286 x 1.803.354. El 3813 (SAC de egreso) lo confirma: su diferencia (25.046 y 10.734) es exactamente la del 1603 / 12.
   Cambio: vigencia nueva 2026-02-02 del 1603 con "+ IF(TIPO_LIQ = 'LIQ_FINAL', #2803, 0)" sumado a la base (en las dos apariciones) y orden de cálculo 401
   para las finales (Fórmula Orden Cálculo IF(TIPO_LIQ = 'LIQ_FINAL', 401, 170)): el 2803 corre en el 400 y el 1603 estaba en el 170, antes. Los lectores de los
   acumuladores del 1603 entre el 171 y el 400 son PROM_ENF_MES, 4110, 4120 y 4125 (ausentismo), que no leen sus aportes en una final. La vigencia anterior se cierra el 1/2.
   Rollback: borrar la vigencia 2026-02-02 del 1603 y reabrir la anterior (Vigencia Hasta = 1753-01-01).
   Después: reiniciar el servicio y recalcular las finales de febrero de 04751 y 04139. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'1603' AND [Vigencia Desde]='20260202')
BEGIN PRINT 'Ya existe la vigencia 2026-02-02 del 1603'; ROLLBACK; RETURN; END;
DECLARE @old nvarchar(max) = (SELECT [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'1603' AND [Vigencia Desde]='20260101');
DECLARE @quitar nvarchar(200) = N'IF(TIPO_LIQ = ''LIQ_FINAL'', #1063 / IFZERO(#COEF_PESQUERIA, 1), #1063)';
IF CHARINDEX(@quitar, @old) = 0 BEGIN PRINT 'No se encontró el término del 1063'; ROLLBACK; RETURN; END;
DECLARE @f nvarchar(max) = REPLACE(@old, @quitar, @quitar + N' + IF(TIPO_LIQ = ''LIQ_FINAL'', #2803, 0)');
DECLARE @orden nvarchar(max) = N'IF(TIPO_LIQ = ''LIQ_FINAL'', 401, 170)';
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
   WHEN N'Vigencia Desde' THEN N'''20260202'''
   WHEN N'Vigencia Hasta' THEN N'''17530101'''
   WHEN N'Fórmula' THEN N'@f'
   WHEN N'Fórmula Orden Cálculo' THEN N'@orden'
   ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @T + N' WHERE [Código]=N''1603'' AND [Vigencia Desde]=''20260101'';';
EXEC sp_executesql @sql, N'@f nvarchar(max), @orden nvarchar(max)', @f = @f, @orden = @orden;
SELECT @@ROWCOUNT AS Insertada_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260201', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Código]=N'1603' AND [Vigencia Desde]='20260101' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerrada_esperado_1;
SELECT [Vigencia Desde],[Vigencia Hasta],[Orden Cálculo],[Fórmula Orden Cálculo],LEN([Fórmula]) len_f FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'1603' ORDER BY 1;
COMMIT;
