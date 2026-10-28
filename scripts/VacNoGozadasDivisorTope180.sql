/* VACACIONES NO GOZADAS (3973): EL DIVISOR DEL PROMEDIO TOPA EN 180 DÍAS (6 períodos de 30), COMO META4.
   BC divide por los DÍAS de prestación de la ventana (DIAS_PREST_PROM_VAC) * 30. Con ventana parcial cierra al
   centavo (94, 80, 121, 64, 107, 37, 59, 67, 76, 132, 170 días: PROM_6_ULT_MES de Meta4 = base / días * 30).
   Con la ventana de seis meses COMPLETOS (ago-ene = 184 días reales) Meta4 divide por 6 períodos = 180:
   04047, 67.624.958,82 / 180 * 30 = 11.270.826,47 = su PROM_6_ULT_MES; BC daba 11.025.811 (184).
   Regla: divisor = MIN(DIAS_PREST_PROM_VAC, 180). Ninguna ventana de seis meses tiene menos de 181 días, así que el
   tope sólo actúa cuando la ventana está completa. Los casos de enero (todos parciales) no cambian.
   Fórmula anterior (vigencia 2026-01-02, abierta):
     round(IF(VAC_PROMEDIO > 0, (SUMA_REM_VAC + IF(VENT_PROM_ES_MES_ACTUAL > 0, #BASE_PROMEDIO, 0))
           / IF(DIAS_PREST_PROM_VAC > 0, DIAS_PREST_PROM_VAC, 30) * 30,
           #1003 + #1053 + #4573 + #2703 + #2103) / 25 * CANT_INCIDENCIA, PRECISION_REDONDEO)
   Nueva VIGENCIA 2026-02-01 (no se pisa la vigente; la anterior se cierra el 2026-01-31). Fracciones y CCT se heredan
   solos (vigencias independientes). Recalcular: la final de 04047 (LIQ-00053201) y las demás finales de febrero.
   Rollback: DELETE de la fila 2026-02-01 y UPDATE de [Vigencia Hasta] = '17530101' en la 2026-01-02. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'3973' AND [Vigencia Desde]='20260201')
BEGIN PRINT 'Ya existe la vigencia 2026-02-01'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
   WHEN N'Vigencia Desde' THEN N'''20260201'''
   WHEN N'Vigencia Hasta' THEN N'''17530101'''
   WHEN N'Fórmula' THEN N'N''round(IF(VAC_PROMEDIO > 0, (SUMA_REM_VAC + IF(VENT_PROM_ES_MES_ACTUAL > 0, #BASE_PROMEDIO, 0)) / IF(DIAS_PREST_PROM_VAC > 0, MIN(DIAS_PREST_PROM_VAC, 180), 30) * 30, #1003 + #1053 + #4573 + #2703 + #2103) / 25 * CANT_INCIDENCIA, PRECISION_REDONDEO)'''
   ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @T + N' WHERE [Código]=N''3973'' AND [Vigencia Desde]=''20260102'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Insertada_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Vigencia Hasta]='20260131', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Código]=N'3973' AND [Vigencia Desde]='20260102' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerrada_esperado_1;
SELECT [Vigencia Desde],[Vigencia Hasta],[Tipos Liq_ Aplicables],[Orden Cálculo],LEFT([Fórmula],200) f FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'3973' ORDER BY 1;
COMMIT;
