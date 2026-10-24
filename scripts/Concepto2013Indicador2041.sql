/* 2013: EL FACTOR 1,4 DE LA GUARDIA DE PUERTO DEPENDE DEL INDICADOR 2041 DE META4 (IND_GUARDIA_2041), NO DE TIPOACTIVIDAD.
   Se reemplaza IF(TIPOACTIVIDAD = 1, 1, IFZERO(COEF_GUARDIA_PUERTO, 1)) por IF(IND_GUARDIA_2041 > 0, IFZERO(COEF_GUARDIA_PUERTO, 1), 1).
   Vigencia nueva 2026-02-03 (la 2026-02-02 se cierra el 2/2). El coeficiente pasa a nivel convenio: COEF_GUARDIA_PUERTO_175/75 = 1,4 desde 2026-02-01
   (el del 1/5 queda), y se borran los de categoría OF02 y OF04 (cargados con la aproximación por TIPOACTIVIDAD). 00794 sigue con el suyo desde el 1/1.
   Requiere scripts/Indicador2041.sql. Rollback: borrar la vigencia 2026-02-03, reabrir la del 2/2 y volver a cargar los coeficientes OF02 y OF04 (1,4 desde 2026-02-01).
   Después: reiniciar el servicio y recalcular las regulares de febrero de 04582, 03196 y 00794. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'2013' AND [Vigencia Desde]='20260203')
BEGIN PRINT 'Ya existe la vigencia 2026-02-03 del 2013'; ROLLBACK; RETURN; END;
DECLARE @old nvarchar(max) = (SELECT [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'2013' AND [Vigencia Desde]='20260202');
DECLARE @quitar nvarchar(200) = N'IF(TIPOACTIVIDAD = 1, 1, IFZERO(COEF_GUARDIA_PUERTO, 1))';
IF CHARINDEX(@quitar, @old) = 0 BEGIN PRINT 'No se encontró el factor con TIPOACTIVIDAD'; ROLLBACK; RETURN; END;
DECLARE @f nvarchar(max) = REPLACE(@old, @quitar, N'IF(IND_GUARDIA_2041 > 0, IFZERO(COEF_GUARDIA_PUERTO, 1), 1)');
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
   WHEN N'Vigencia Desde' THEN N'''20260203'''
   WHEN N'Vigencia Hasta' THEN N'''17530101'''
   WHEN N'Fórmula' THEN N'@f'
   ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @T + N' WHERE [Código]=N''2013'' AND [Vigencia Desde]=''20260202'';';
EXEC sp_executesql @sql, N'@f nvarchar(max)', @f = @f;
SELECT @@ROWCOUNT AS Insertada_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260202', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Código]=N'2013' AND [Vigencia Desde]='20260202' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerrada_esperado_1;

-- Coeficiente a nivel convenio desde el 1/2 (molde: el de 175/75 del 1/5)
SELECT * INTO #p FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro]=N'COEF_GUARDIA_PUERTO_175/75' AND [Vigencia Desde]='20260501';
UPDATE #p SET [Vigencia Desde]='20260201', [$systemId]=NEWID();
DECLARE @cp nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name <> 'timestamp');
EXEC (N'INSERT dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cp + N') SELECT ' + @cp + N' FROM #p p WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Cód_ Parámetro]=p.[Cód_ Parámetro] AND x.[Vigencia Desde]=''20260201'')');
SELECT @@ROWCOUNT AS Coef_convenio_esperado_1;
DELETE FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro] IN (N'COEF_GUARDIA_PUERTO_175/75_OF02', N'COEF_GUARDIA_PUERTO_175/75_OF04');
SELECT @@ROWCOUNT AS Borrados_esperado_2;
SELECT [Cód_ Parámetro],[Valor],[Nivel],CONVERT(varchar(10),[Vigencia Desde],120) d FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base]=N'COEF_GUARDIA_PUERTO' ORDER BY 1,4;
COMMIT;
