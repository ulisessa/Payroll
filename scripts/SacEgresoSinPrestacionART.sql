/* SAC DE EGRESO SIN LA PRESTACIÓN DE LA ART (04047, accidentado, final de febrero 2026).
   El 3813 es (BASE_SAC_SEMESTRE + #BASE_PROMEDIO ...) / 12, y BASE_PROMEDIO suma las prestaciones de la ART
   (4121, 4124, 4125, 4165), que no son remuneración del empleador ni integran el SAC: Meta4 paga 24.477,35
   (= 293.728,14 / 12, sólo 1053 + 1063) y BC 1.195.221,36. El resto de las finales (11 casos) cierra al centavo.
   Se resta la prestación del semestre con una Fuente de Datos del mismo molde que SUMA_REM_VAC pero con la
   ventana {SEM_DESDE}..{SEM_HASTA}, y la de la final con #4125 y #4165 (órdenes 385 y 395, antes que el 3813 en
   el 470; el 4121 y el 4124 son 615 y 685 y correrían después: quedan sin restar en la final misma).
   Fórmula anterior:
     ROUND((BASE_SAC_SEMESTRE + #BASE_PROMEDIO - IF(TIPO_LIQ = 'LIQ_FINAL' AND #3573 <> 0, ROUND(#3973 * 0.1,
     PRECISION_REDONDEO) * (1 - DIAS_ALTA_30 / 30), 0)) / 12 * #COEF_PESQUERIA, PRECISION_REDONDEO)
   Corrige la vigencia 2026-01-01. Recalcular: la regular de enero y después la final de febrero. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;

DECLARE @F nvarchar(300) = N'dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
        WHEN N'Nombre Variable' THEN N'N''PRESTACION_ART_SEM'''
        WHEN N'Descripción' THEN N'N''Prestación de la ART del semestre en curso (no integra el SAC de egreso)'''
        ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'IF NOT EXISTS (SELECT 1 FROM ' + @F + N' WHERE [Nombre Variable] = N''PRESTACION_ART_SEM'')
INSERT ' + @F + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @F + N' WHERE [Nombre Variable] = N''SUMA_REM_VAC'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Fuente_esperado_1;

CREATE TABLE #f(linea int, campo int, valor nvarchar(100));
INSERT #f VALUES (10, 16, N'{EMP_NO}'), (20, 23, N'{SEM_DESDE}..{SEM_HASTA}'), (30, 3, N'4121|4124|4125|4165'), (40, 22, N'<>0'), (50, 1, N'<>{LIQ_NO}');
IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable] = N'PRESTACION_ART_SEM')
    INSERT dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Nombre Variable],[No_ Campo],[Filtro Valor],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
    SELECT N'PRESTACION_ART_SEM', campo, valor, NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000', SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000' FROM #f ORDER BY linea;
SELECT @@ROWCOUNT AS Filtros_esperado_5;

UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Fórmula] = N'ROUND((BASE_SAC_SEMESTRE - PRESTACION_ART_SEM + #BASE_PROMEDIO - #4125 - #4165 - IF(TIPO_LIQ = ''LIQ_FINAL'' AND #3573 <> 0, ROUND(#3973 * 0.1, PRECISION_REDONDEO) * (1 - DIAS_ALTA_30 / 30), 0)) / 12 * #COEF_PESQUERIA, PRECISION_REDONDEO)',
    [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [Código] = N'3813' AND [Vigencia Desde] = '20260101' AND [Fórmula] LIKE N'ROUND((BASE_SAC_SEMESTRE + #BASE_PROMEDIO%';
SELECT @@ROWCOUNT AS Formula3813_esperado_1;

SELECT f.[Nombre Variable], f.[No_ Línea], f.[No_ Campo], f.[Filtro Valor] FROM dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f WHERE f.[Nombre Variable] = N'PRESTACION_ART_SEM' ORDER BY 2;
COMMIT;
