/*
    BASE_PROMEDIO PASA A SER SIEMPRE EL TOTAL (como TOT_PROMEDIOS de Meta4).

    Hoy el acumulador mezcla dos criterios: la historia migrada (HIST_REMUN) lo trae TOTAL y los recibos
    que calcula el motor sólo la parte remunerativa, porque el 3554 (acuerdo sindical no remunerativo,
    el 70% del 729/15) aporta únicamente a BASE_PROMEDIO_NR. Vacaciones y SAC leen BASE_PROMEDIO y quedan
    cortas (00900 en febrero: 170.228 de menos sobre 35 días, exactamente el NR de enero / 6 / 25 * 35).

    CAMBIOS (todo vigencia nueva; las vigentes se cierran, no se pisan)
      1. Fracción 3554 → BASE_PROMEDIO 100%, desde 2026-01-02.
      2. AJ_PROM_PESQUERIA (sólo LIQ_FINAL) se cierra el 2026-01-01: reconstruía con la MISMA fórmula
         del 3554 la parte que no entraba en BASE_PROMEDIO; ahora entra el 3554 y quedaría doble.
      3. PROM_AUS_MES (base REMUNERATIVA de accidente; el NR se paga aparte en 4160/4165): nueva
         vigencia 2026-01-03 con (PROM_AUS_n - AUS_NO_REM_ACT_n), que da lo mismo que antes.
      4. PROM_ENF_MES: nueva vigencia 2026-02-04 sin ENF_NR (ENF_BASE ya trae el total).
    NO se tocan: PROM_AUS_MES_NR, las fuentes, 3813/3973 (leen #BASE_PROMEDIO: pasan al total, es lo
    buscado) ni MEJOR_REM_SEM (el SAC pasa a tomar el total, aceptado por el usuario el 14/10/2026).

    DESPUÉS: reiniciar el service tier y RECALCULAR ENERO EN CADENA (los recibos guardados tienen
    BASE_PROMEDIO sin la parte NR) y recién después las vacaciones de febrero.
*/
SET XACT_ABORT ON; SET NOCOUNT ON;
DECLARE @C nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @F nvarchar(300) = N'dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';

PRINT '== PREVISUALIZACIÓN';
EXEC (N'SELECT [Código], CONVERT(varchar(10),[Vigencia Desde],23) Desde, CONVERT(varchar(10),[Vigencia Hasta],23) Hasta FROM ' + @C +
      N' WHERE [Código] IN (''PROM_AUS_MES'',''PROM_ENF_MES'',''AJ_PROM_PESQUERIA'') AND [Vigencia Desde] >= ''20260101'' ORDER BY 1,2');

BEGIN TRAN;
SELECT [Código] Cpt, [Vigencia Desde] Vig, [Vigencia Hasta] Hasta, CAST([Orden Cálculo] AS int) Orden, CAST([Fórmula] AS nvarchar(4000)) Formula
INTO #Antes FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890];

-- 1. Fracción nueva.
DECLARE @fc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @fs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260102''' WHEN N'Cód_ Acumulador' THEN N'N''BASE_PROMEDIO''' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'INSERT ' + @F + N' (' + @fc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
 SELECT ' + @fs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
 FROM ' + @F + N' WHERE [Cód_ Concepto] = N''3554'' AND [Cód_ Acumulador] = N''BASE_PROMEDIO_NR'' AND [Vigencia Desde] = ''20260101'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Fracciones_esperado_1;

-- 2. AJ_PROM_PESQUERIA cerrado.
SET @sql = N'UPDATE ' + @C + N' SET [Vigencia Hasta] = ''20260101'', [$systemModifiedAt] = SYSUTCDATETIME() WHERE [Código] = N''AJ_PROM_PESQUERIA'' AND [Vigencia Desde] = ''20260101'' AND [Vigencia Hasta] = ''17530101'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS AJ_cerrado_esperado_1;

-- 3 y 4. Copias de PROM_AUS_MES (2026-01-02 a 2026-01-03) y PROM_ENF_MES (2026-02-03 a 2026-02-04).
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@C) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs1 nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260103''' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@C) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs2 nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260204''' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@C) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
SET @sql = N'INSERT ' + @C + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs1 + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @C + N' WHERE [Código] = N''PROM_AUS_MES'' AND [Vigencia Desde] = ''20260102'' AND [Vigencia Hasta] = ''17530101'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS PromAus_esperado_1;
SET @sql = N'INSERT ' + @C + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs2 + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @C + N' WHERE [Código] = N''PROM_ENF_MES'' AND [Vigencia Desde] = ''20260203'' AND [Vigencia Hasta] = ''17530101'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS PromEnf_esperado_1;
SET @sql = N'UPDATE ' + @C + N' SET [Vigencia Hasta] = ''20260102'', [$systemModifiedAt] = SYSUTCDATETIME() WHERE [Código] = N''PROM_AUS_MES'' AND [Vigencia Desde] = ''20260102'';
 UPDATE ' + @C + N' SET [Vigencia Hasta] = ''20260203'', [$systemModifiedAt] = SYSUTCDATETIME() WHERE [Código] = N''PROM_ENF_MES'' AND [Vigencia Desde] = ''20260203'';
 UPDATE ' + @C + N' SET [Fórmula] = N''IF(MESES_AUS >= 12, (PROM_AUS_12 - AUS_NO_REM_ACT_12) / MAX(1, MESES_PROM_AUS_12), (PROM_AUS_6 - AUS_NO_REM_ACT_6) / MAX(1, MESES_PROM_AUS_6))'', [$systemModifiedAt] = SYSUTCDATETIME() WHERE [Código] = N''PROM_AUS_MES'' AND [Vigencia Desde] = ''20260103'';
 UPDATE ' + @C + N' SET [Fórmula] = N''IF(DIV_PROM_LIC>0,ENF_BASE/IFZERO(DIV_PROM_LIC,1),0)'', [$systemModifiedAt] = SYSUTCDATETIME() WHERE [Código] = N''PROM_ENF_MES'' AND [Vigencia Desde] = ''20260204'';';
EXEC (@sql);

-- CONTROLES (todos 0)
EXEC (N'SELECT COUNT(*) AS VigenciasSolapadas FROM ' + @C + N' a JOIN ' + @C + N' b ON a.[Código] = b.[Código] AND a.[Vigencia Desde] < b.[Vigencia Desde] AND (a.[Vigencia Hasta] = ''17530101'' OR a.[Vigencia Hasta] >= b.[Vigencia Desde]) WHERE a.[Código] IN (''PROM_AUS_MES'',''PROM_ENF_MES'',''AJ_PROM_PESQUERIA'')');
EXEC (N'SELECT COUNT(*) AS OtrosConceptosTocados FROM #Antes a JOIN ' + @C + N' c ON c.[Código] = a.Cpt AND c.[Vigencia Desde] = a.Vig WHERE a.Cpt NOT IN (''PROM_AUS_MES'',''PROM_ENF_MES'',''AJ_PROM_PESQUERIA'') AND (c.[Orden Cálculo] <> a.Orden OR c.[Vigencia Hasta] <> a.Hasta OR CAST(c.[Fórmula] AS nvarchar(4000)) <> a.Formula)');
EXEC (N'SELECT COUNT(*) AS ENF_NR_residual FROM ' + @C + N' WHERE [Vigencia Hasta] = ''17530101'' AND [Fórmula] LIKE N''%ENF_NR%''');
COMMIT;
