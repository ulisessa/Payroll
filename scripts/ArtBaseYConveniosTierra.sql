/*
    ART: BASE Y CONVENIOS (enero 2026, conciliación contra Meta4).

    1. La base de ART de Meta4 (REM_IMPO_ART_ST) es BASE_SS_TRAB + BASE_SS_VAC + NO_REMUNERATIVO: cierra
       en 325 de 329 empleados (el resto son centavos). Ni la de Ganancias ni la de obra social: la
       remunerativa más TODO lo no remunerativo. Reemplaza la fórmula del 7050 (vigencia 2026-01-01).
    2. Concepto CCT Vigente restringe qué convenios reciben cada concepto. El 7053 (suma fija de ART)
       sólo estaba para 175/75, 729/15, 768/19 y ESP: los empleados de FA, 372/04 y 130/75 no tenían
       línea y Meta4 sí les carga los 1.602. Se agregan.
    3. El 7055 (tarea diferencial) sólo estaba para 175/75 y ESP: aunque se cargue PCT_TAR_DIF_729/15 y
       _768/19, sin esta fila el concepto no corre para esos convenios. Se agregan.

    Las filas nuevas se copian de la de 729/15 del 7053 (misma vigencia, sin categoría).
    Después de aplicar: reiniciar el service tier y recalcular enero.
*/
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;

UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Fórmula] = N'round((BASE_SS_TRAB + BASE_SS_VAC + NO_REMUNERATIVO) * PCT_ART, PRECISION_REDONDEO)', [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [Código] = N'7050' AND [Vigencia Desde] = '20260101';
SELECT @@ROWCOUNT AS Formula7050_esperado_1;

DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto CCT Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @nuevas TABLE(concepto nvarchar(20), convenio nvarchar(20));
INSERT @nuevas VALUES (N'7053', N'FA'), (N'7053', N'372/04'), (N'7053', N'130/75'), (N'7055', N'729/15'), (N'7055', N'768/19');
DECLARE @cp nvarchar(20), @cv nvarchar(20), @cs nvarchar(max), @sql nvarchar(max);
DECLARE cur CURSOR FOR SELECT concepto, convenio FROM @nuevas;
OPEN cur; FETCH cur INTO @cp, @cv;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @cs = (SELECT STRING_AGG(CASE c.name
            WHEN N'Cód_ Concepto' THEN N'N''' + @cp + N''''
            WHEN N'Cód_ Convenio' THEN N'N''' + @cv + N''''
            ELSE QUOTENAME(c.name) END, ',')
        FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
    SET @sql = N'IF NOT EXISTS (SELECT 1 FROM ' + @T + N' WHERE [Cód_ Concepto] = N''' + @cp + N''' AND [Cód_ Convenio] = N''' + @cv + N''' AND [Cód_ Categoría] = N'''' AND [Vigencia Desde] = ''20260101'')
INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @T + N' WHERE [Cód_ Concepto] = N''7053'' AND [Cód_ Convenio] = N''729/15'' AND [Cód_ Categoría] = N'''' AND [Vigencia Desde] = ''20260101'';';
    EXEC (@sql);
    FETCH cur INTO @cp, @cv;
END
CLOSE cur; DEALLOCATE cur;

SELECT [Cód_ Concepto], [Cód_ Convenio], [Cód_ Categoría], Excluye FROM dbo.[ArbuTest$Concepto CCT Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto] IN (N'7053', N'7055') ORDER BY 1, 2;
COMMIT;
