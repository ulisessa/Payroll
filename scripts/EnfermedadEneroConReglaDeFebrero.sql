/* ENFERMEDAD: ENERO CON LA REGLA DE FEBRERO (PROM_ENF_MES, TOT_PROMEDIOS DEL VÍNCULO ACTUAL).
   El 4110 de enero (vigencia 2026-01-02) lee #PROM_AUS_MES, la mezcla vieja de BASE_PROMEDIO; febrero (2026-02-03) lee #PROM_ENF_MES. Por eso había 12 novedades de 4110
   en enero ("Diferencia sin causa identificada"): con el precio de Meta4 (PRE_ENFER, 12 meses de TOT_PROMEDIOS anclados en el mes de inicio del episodio) x los días de BC x
   el coeficiente 0,3 de enero, los 12 importes daban exacto (medido en SQL el 15/10/2026). Los días de BC estaban bien; el desvío era el precio.
   Cambio (vigencias nuevas, la de enero no se pisa):
     1. PROM_ENF_MES: vigencia 2026-01-03..2026-01-31, copia de la abierta (2026-02-04).
     2. 4110: vigencia 2026-01-03..2026-01-31, copia de la abierta (2026-02-03) con sus 8 fracciones de acumulador; la 2026-01-02 se cierra el mismo 2/1.
     3. Las 12 novedades de 4110 de 202601 pasan a Anulada Y SE LES VACÍA No. Liquidación (no se borran). Si sólo se cambia el Estado, LimpiarParaRecalculo las encuentra por No. Liquidación y las devuelve a Pendiente al recalcular.
   Rollback: borrar las vigencias 2026-01-03 de 4110 (con fracciones) y PROM_ENF_MES, reabrir la 2026-01-02 del 4110 (Hasta 2026-01-31) y volver las novedades a Pendiente.
   Después: reiniciar el servicio y recalcular enero de los 12 empleados (01607, 01767, 01961, 02449, 02670, 02737, 02854, 02924, 03073, 03986, 04185, 04216). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @F nvarchar(300) = N'dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (N'4110', N'PROM_ENF_MES') AND [Vigencia Desde]='20260103')
BEGIN PRINT 'Ya existe una vigencia 2026-01-03'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260103''' WHEN N'Vigencia Hasta' THEN N'''20260131''' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sql nvarchar(max) = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs + @sys
  + N' FROM ' + @T + N' WHERE [Código]=N''PROM_ENF_MES'' AND [Vigencia Desde]=''20260204'' UNION ALL SELECT ' + @cs + @sys + N' FROM ' + @T + N' WHERE [Código]=N''4110'' AND [Vigencia Desde]=''20260203'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Conceptos_insertados_esperado_2;
-- fracciones del 4110
DECLARE @fc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @fs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260103''' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
SET @sql = N'INSERT ' + @F + N' (' + @fc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @fs + @sys + N' FROM ' + @F + N' WHERE [Cód_ Concepto]=N''4110'' AND [Vigencia Desde]=''20260203'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Fracciones_insertadas_esperado_8;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260102', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=N'4110' AND [Vigencia Desde]='20260102' AND [Vigencia Hasta]='20260131';
SELECT @@ROWCOUNT AS Cerrada_esperado_1;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET Estado=2, [No_ Liquidación]=N'', [Motivo No Aplicada]=N'', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Cód_ Concepto]=N'4110' AND [Cód_ Período]=N'202601' AND Estado<>2;
SELECT @@ROWCOUNT AS Novedades_anuladas_esperado_12;
SELECT [Código],[Vigencia Desde],[Vigencia Hasta],[Variable Base] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (N'4110',N'PROM_ENF_MES') AND [Vigencia Desde]>='20260102' ORDER BY 1,2;
COMMIT;
