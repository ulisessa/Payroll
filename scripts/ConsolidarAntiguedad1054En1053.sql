/*
    CONSOLIDAR 1054 "Antigüedad mensuales" EN 1053 "Antigüedad".

    Hoy 1054 sólo paga a un empleado (90157, convenio 130/75). 372/04 ya se consolidó en 1053:
    rama IF(CONVENIO = '372/04', ...) en la fórmula y 'Fórmula Orden Cálculo' =
    IF(CONVENIO = '372/04', 50, 100). Este script hace lo mismo con 130/75.

    POR QUÉ EL ORDEN. 2103 (orden 55) lee #1053 + #1054. 1053 corre en el 100 para la tripulación
    y 1054 en el 50. Si 130/75 pasara a 1053 con orden 100, 2103 dejaría de ver su antigüedad sin
    ningún error. La salida es la que ya existe: el orden de 1053 sale de una fórmula POR
    CONVENIO, y 130/75 se suma a 372/04 con 50. La TRIPULACIÓN SIGUE EN 100: no se mueve.

    TODO ES VIGENCIA NUEVA desde 2026-01-02 (misma fecha que usó la fracción de BASE_AUSENTISMO);
    las vigencias 2026-01-01 se cierran el 2026-01-01 y no se pisan.
      · 1053   fórmula con rama 130/75 + 'Fórmula Orden Cálculo' con 130/75 → 50
      · 2103, 3553, 3973, 4743   sin el '+ #1054'
      · 1054   se cierra el 2026-01-01 (queda su historia)
      · Concepto CCT Vigente   (1053, 130/75) desde 2026-01-02

    EFECTOS A TENER EN CUENTA
      · 130/75 pasa a alimentar BASE_AUSENTISMO y BASE_FERIADO (las fracciones de 1053 las
        tienen; las de 1054 no). Cambia el promedio de ausentismo/feriado de ese convenio.
      · Las liquidaciones ya calculadas con la vigencia 2026-01-01 no se tocan hasta recalcular.
      · SQL directo: reiniciar el service tier (o publicar) para que BC vea los cambios.
*/
SET XACT_ABORT ON;
SET NOCOUNT ON;

DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @CCT nvarchar(300) = N'dbo.[ArbuTest$Concepto CCT Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';

-- 1. PREVISUALIZACIÓN ---------------------------------------------------------------------
PRINT '== Vigencias que se tocan';
EXEC (N'SELECT [Código], CONVERT(varchar(10),[Vigencia Desde],23) Desde, CONVERT(varchar(10),[Vigencia Hasta],23) Hasta, [Orden Cálculo] Orden, LEN([Fórmula]) LongFormula
        FROM ' + @T + N' WHERE [Código] IN (''1053'',''1054'',''2103'',''3553'',''3973'',''4743'') AND [Vigencia Desde] >= ''20260101'' ORDER BY 1,2');

IF OBJECT_ID('tempdb..#Nuevas') IS NOT NULL DROP TABLE #Nuevas;
CREATE TABLE #Nuevas (Cod nvarchar(40) COLLATE DATABASE_DEFAULT PRIMARY KEY);
INSERT #Nuevas VALUES (N'1053'),(N'2103'),(N'3553'),(N'3973'),(N'4743');

-- 2. APLICACIÓN (transacción; se confirma sólo si los controles dan 0) ----------------------
BEGIN TRAN;

-- Foto del resto de los conceptos, para el control de "no se tocó a nadie más".
SELECT [Código] Cpt, [Vigencia Desde] Vig, [Orden Cálculo] Orden, CAST([Fórmula] AS nvarchar(4000)) Formula, [Vigencia Hasta] Hasta
INTO #Antes FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890];

-- 2.1 Copiar las vigencias 2026-01-01 de los cinco conceptos como vigencias 2026-01-02 (abiertas).
DECLARE @cols nvarchar(max) = (
    SELECT STRING_AGG(QUOTENAME(c.name), ',')
    FROM sys.columns c
    WHERE c.object_id = OBJECT_ID(@T) AND c.name NOT IN ('timestamp') AND c.name NOT LIKE '$system%');
-- Lo mismo, pero con la vigencia nueva en lugar de la copiada (la PK es Código + Vigencia Desde).
DECLARE @sel nvarchar(max) = (
    SELECT STRING_AGG(CASE WHEN c.name = N'Vigencia Desde' THEN N'''20260102''' ELSE QUOTENAME(c.name) END, ',')
    FROM sys.columns c
    WHERE c.object_id = OBJECT_ID(@T) AND c.name NOT IN ('timestamp') AND c.name NOT LIKE '$system%');

DECLARE @sql nvarchar(max) = N'
INSERT ' + @T + N' (' + @cols + N', [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT ' + @sel + N', NEWID(), SYSUTCDATETIME(), ''00000000-0000-0000-0000-000000000000'', SYSUTCDATETIME(), ''00000000-0000-0000-0000-000000000000''
FROM ' + @T + N' WHERE [Código] IN (SELECT Cod FROM #Nuevas) AND [Vigencia Desde] = ''20260101'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Insertadas_Esperado_5;

-- 2.2 Cerrar las originales el 2026-01-01.
SET @sql = N'UPDATE ' + @T + N' SET [Vigencia Hasta] = ''20260101'', [$systemModifiedAt] = SYSUTCDATETIME()
 WHERE ([Código] IN (SELECT Cod FROM #Nuevas) OR [Código] = ''1054'') AND [Vigencia Desde] = ''20260101'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Cerradas_Esperado_6;

-- 2.3 1053: rama 130/75 y orden por convenio.
SET @sql = N'UPDATE ' + @T + N' SET
   [Fórmula] = N''IF(CONVENIO = ''''130/75'''', round(@AÑOS_ANTIGUEDAD * (BASICO * PCT_ANTIG), PRECISION_REDONDEO), '' + [Fórmula] + N'')'',
   [Fórmula Orden Cálculo] = N''IF(CONVENIO = ''''372/04'''', 50, IF(CONVENIO = ''''130/75'''', 50, 100))'',
   [$systemModifiedAt] = SYSUTCDATETIME()
 WHERE [Código] = ''1053'' AND [Vigencia Desde] = ''20260102'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Formula1053_Esperado_1;

-- 2.4 Los cuatro consumidores: sin el '+ #1054'.
SET @sql = N'UPDATE ' + @T + N' SET [Fórmula] = REPLACE(REPLACE([Fórmula], N'' + #1054'', N''''), N''+ #1054'', N''''), [$systemModifiedAt] = SYSUTCDATETIME()
 WHERE [Código] IN (''2103'',''3553'',''3973'',''4743'') AND [Vigencia Desde] = ''20260102'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Consumidores_Esperado_4;

-- 2.5 CCT: 130/75 aplica a 1053 desde 2026-01-02.
SET @sql = N'INSERT ' + @CCT + N' ([Cód_ Concepto],[Vigencia Desde],[Cód_ Convenio],[Cód_ Categoría],Excluye,[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
 VALUES (N''1053'',''20260102'',N''130/75'',N'''',0,NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'');';
EXEC (@sql);

-- CONTROLES (todos tienen que dar 0) ---------------------------------------------------------
EXEC (N'SELECT COUNT(*) AS Quedan1054EnFormulas FROM ' + @T + N'
        WHERE [Vigencia Desde] = ''20260102'' AND [Código] <> ''1054'' AND [Fórmula] LIKE N''%#1054%'' ');
EXEC (N'SELECT COUNT(*) AS VigenciasSolapadas FROM ' + @T + N' a JOIN ' + @T + N' b
        ON a.[Código] = b.[Código] AND a.[Vigencia Desde] < b.[Vigencia Desde]
        AND (a.[Vigencia Hasta] = ''17530101'' OR a.[Vigencia Hasta] >= b.[Vigencia Desde])
        WHERE a.[Código] IN (''1053'',''1054'',''2103'',''3553'',''3973'',''4743'')');
EXEC (N'SELECT COUNT(*) AS OtrosConceptosTocados FROM #Antes a JOIN ' + @T + N' c
        ON c.[Código] = a.Cpt AND c.[Vigencia Desde] = a.Vig
        WHERE a.Cpt NOT IN (''1053'',''1054'',''2103'',''3553'',''3973'',''4743'')
          AND (c.[Orden Cálculo] <> a.Orden OR c.[Vigencia Hasta] <> a.Hasta OR CAST(c.[Fórmula] AS nvarchar(4000)) <> a.Formula)');
EXEC (N'SELECT LEN([Fórmula]) AS LongFormula1053_ConLimite4096 FROM ' + @T + N' WHERE [Código] = ''1053'' AND [Vigencia Desde] = ''20260102''');

COMMIT;
-- ROLLBACK;
IF OBJECT_ID(N'tempdb..#Antes') IS NOT NULL DROP TABLE #Antes;
