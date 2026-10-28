/*
    TAREA DIFERENCIAL (7055 <-> PAT_REG_DIF de Meta4), enero 2026.

    Meta4 contribuye el 2% sobre BASE_SS_TRAB + BASE_SS_VAC en TODOS los empleados de los tres
    convenios de navegación (729/15, 768/19, 175/75) y en ninguno de tierra. Con ese criterio cierra al
    peso en 271 de 271: 15.823.222 + 4.655.530 + 7.164.373 = 27.643.126.
    BC tenía dos huecos:
      1. El parámetro PCT_TAR_DIF sólo existía para 175/75 (y ESP): faltan 729/15 y 768/19.
      2. El 7055 usaba sólo BASE_SS_TRAB: las liquidaciones de vacaciones quedaban sin contribución.

    Se corrige la vigencia 2026-01-01 del concepto (no puede haber dos con el mismo Desde) y se
    agregan los dos parámetros copiando la fila de 175/75.
    Después de aplicar: reiniciar el service tier y recalcular enero.
*/
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;

DECLARE @P nvarchar(300) = N'dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@P) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @conv TABLE(cv nvarchar(20));
INSERT @conv VALUES (N'729/15'), (N'768/19');
DECLARE @cv nvarchar(20), @cs nvarchar(max), @sql nvarchar(max);
DECLARE cur CURSOR FOR SELECT cv FROM @conv;
OPEN cur; FETCH cur INTO @cv;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @cs = (SELECT STRING_AGG(CASE c.name
            WHEN N'Cód_ Parámetro' THEN N'N''PCT_TAR_DIF_' + @cv + N''''
            WHEN N'Cód_ Convenio' THEN N'N''' + @cv + N''''
            ELSE QUOTENAME(c.name) END, ',')
        FROM sys.columns c WHERE c.object_id = OBJECT_ID(@P) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
    SET @sql = N'IF NOT EXISTS (SELECT 1 FROM ' + @P + N' WHERE [Cód_ Parámetro] = N''PCT_TAR_DIF_' + @cv + N''' AND [Vigencia Desde] = ''20260101'')
INSERT ' + @P + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @P + N' WHERE [Cód_ Parámetro] = N''PCT_TAR_DIF_175/75'' AND [Vigencia Desde] = ''20260101'';';
    EXEC (@sql);
    FETCH cur INTO @cv;
END
CLOSE cur; DEALLOCATE cur;

UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Fórmula] = N'ROUND(PCT_TAR_DIF * (BASE_SS_TRAB + BASE_SS_VAC), 0.0001)', [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [Código] = N'7055' AND [Vigencia Desde] = '20260101';
SELECT @@ROWCOUNT AS Concepto_esperado_1;

SELECT [Cód_ Parámetro], [Cód_ Convenio], [Valor], [En Uso] FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro] LIKE N'PCT_TAR_DIF%' ORDER BY 1;
COMMIT;
