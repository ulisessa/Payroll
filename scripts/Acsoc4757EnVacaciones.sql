/* REVIERTE LA CORRECCIÓN DEL 4754 Y CORRIGE EL 4757 (ACCIÓN SOCIAL CAP SOBRE EL SAC DEVENGADO) CON LA BASE DE VACACIONES.
   Cometí un error al leer el 4754 de Meta4: BC ya reparte lo que Meta4 junta en C_SINDICAL_SAC_MES en cuatro conceptos informativos: 4754 (cuota, 2,5 %), 4755 (caja compensadora),
   4756 (fondo de desempleo) y 4757 (acción social CAP). Al meter caja y fondo en el 4754 se contaban dos veces (CUOTA_SINDICAL_RET de 01541 subió 260.691 y el impuesto bajó 91.405 de más).
   El hueco real era sólo el 4757, que en las vacaciones de 01541 daba 0 (usa BASE_SINDICAL, que en esa liquidación es cero) y debía dar 84.967: 3.159.882 x 2,689 % (la tasa efectiva del 8593).
   Cambio:
     1. 4754: se borra la vigencia 2026-01-02 (con sus fracciones) y se reabre la 2026-01-01 (Hasta 1753-01-01), como estaba.
     2. 4757: vigencia nueva 2026-01-02 (la 2026-01-01 se cierra el mismo día) con
          IF(PCT_SINDICATO = 'CAP', round(BASE_SAC_DEV * (round(MAX(0, BASE_SINDICAL + BASE_SINDICAL_VAC + MES_BASE_SINDICAL + MES_BASE_SINDICAL_VAC - TOPE_SIPA) * PCT_CUOTA_EXT_CAP / 100, PRECISION_REDONDEO)
                                                          - MES_CUOTA_EXT_CAP) / IFZERO(BASE_SINDICAL + BASE_SINDICAL_VAC, 1), PRECISION_REDONDEO), 0)
        o sea el SAC devengado por la tasa efectiva que el 8593 cobró en el mes (acción social / base sindical), sin variable propia de lo ya liquidado.
   Rollback: borrar la vigencia 2026-01-02 del 4757 (con fracciones) y reabrir la 2026-01-01; el 4754 vuelve a la vigencia 2026-01-02 sólo si se repite scripts/Sindical4754ConCajaFondoAcSoc.sql (no recomendado).
   Después: reiniciar el servicio y recalcular febrero de 01541 (vacaciones y regular). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @F nvarchar(300) = N'dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sql nvarchar(max);
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'4757' AND [Vigencia Desde]='20260102')
BEGIN PRINT 'Ya existe la vigencia 2026-01-02 del 4757'; ROLLBACK; RETURN; END;
-- 1. Revertir el 4754
IF (SELECT COUNT(*) FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'4754' AND [Vigencia Desde]='20260102') <> 1
BEGIN PRINT 'No está la vigencia 2026-01-02 del 4754 para revertir'; ROLLBACK; RETURN; END;
DELETE FROM dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto]=N'4754' AND [Vigencia Desde]='20260102';
DELETE FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'4754' AND [Vigencia Desde]='20260102';
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='17530101', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=N'4754' AND [Vigencia Desde]='20260101';
SELECT @@ROWCOUNT AS Reabierta_4754_esperado_1;
-- 2. 4757
DECLARE @fnew nvarchar(max) = N'IF(PCT_SINDICATO = ''CAP'', round(BASE_SAC_DEV * (round(MAX(0, BASE_SINDICAL + BASE_SINDICAL_VAC + MES_BASE_SINDICAL + MES_BASE_SINDICAL_VAC - TOPE_SIPA) * PCT_CUOTA_EXT_CAP / 100, PRECISION_REDONDEO) - MES_CUOTA_EXT_CAP) / IFZERO(BASE_SINDICAL + BASE_SINDICAL_VAC, 1), PRECISION_REDONDEO), 0)';
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260102''' WHEN N'Fórmula' THEN N'@fnew' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs + @sys + N' FROM ' + @T + N' WHERE [Código]=N''4757'' AND [Vigencia Desde]=''20260101'' AND [Vigencia Hasta]=''17530101'';';
EXEC sp_executesql @sql, N'@fnew nvarchar(max)', @fnew=@fnew;
SELECT @@ROWCOUNT AS Vigencia_4757_esperado_1;
DECLARE @fc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @fs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260102''' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
SET @sql = N'INSERT ' + @F + N' (' + @fc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @fs + @sys + N' FROM ' + @F + N' WHERE [Cód_ Concepto]=N''4757'' AND [Vigencia Desde]=''20260101'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Fracciones_4757_esperado_1_o_mas;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260101', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=N'4757' AND [Vigencia Desde]='20260101';
SELECT [Código],[Vigencia Desde],[Vigencia Hasta],LEN([Fórmula]) len_f FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (N'4754',N'4757') AND [Vigencia Desde]>='20260101' ORDER BY 1,2;
COMMIT;
