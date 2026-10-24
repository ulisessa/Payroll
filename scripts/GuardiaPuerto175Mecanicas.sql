/* GUARDIA DE PUERTO DE LOS OFICIALES DE 175/75 (OF02 y OF04): COEFICIENTE 1,4 Y TAREAS MECÁNICAS, SALVO CON BUQUE (TIPOACTIVIDAD = 1).
   Meta4 (enero a junio de 2026): paga el 2013 con coeficiente 1,4 y el adicional de tareas mecánicas (2073) a los oficiales de 175/75 en guardia sin
   navegación (00794, 03196, 04582, 01073, 02450: 8 casos). 04455, mismo convenio, categoría y puesto que 04582, cobra con coeficiente 1 y sin 2073
   en su guardia de enero porque esa regular tiene buque: TIPOACTIVIDAD = 1, la misma condición que ya corta el 2073 en BC. 03039, 00406, 04710,
   02744, 04313 y 04320 son excepciones manuales de Meta4 (incidencias del 2073 en cero y, en 03039, 2013 escrito a mano; ya migrado como novedad).
   Cuatro cambios, sin código:
     1. COEF_GUARDIA_PUERTO_175/75_OF02 y _OF04 = 1,4 (nivel convenio + categoría) desde el 1/2/2026 (desde el 1/1 rompía a 04455 en enero: la fórmula vieja del 2013 no mira TIPOACTIVIDAD).
     2. 2013: vigencia nueva 2026-02-01 con IF(TIPOACTIVIDAD = 1, 1, IFZERO(COEF_GUARDIA_PUERTO, 1)); la 2026-01-01 se cierra el 31/1 (enero no cambia).
     3. Lista blanca del 2073: 175/75 con OF04 (el PCT_TAR_MEC_175/75_OF04 = 15 ya existía; faltaba la fila). 03196 cobraba 0 contra 779.667 de Meta4.
     4. Se borran los coeficientes por empleado de 04582 y 03196 (cargados antes de entender la regla). 00794 queda.
   Rollback: borrar las dos filas COEF_..._175/75_OF02/OF04 y la fila OF04 del 2073, borrar la vigencia 2026-02-01 del 2013 y reabrir la anterior
   (Vigencia Hasta = 1753-01-01), y volver a cargar COEF_GUARDIA_PUERTO_04582 y _03196 (1,4 desde 2026-02-01).
   Después: reiniciar el servicio y recalcular las regulares de febrero de 04582 y 03196. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;

-- 1. Coeficientes por convenio + categoría
SELECT c.cat, v.* INTO #t FROM (VALUES (N'OF02'), (N'OF04')) c(cat) CROSS JOIN dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v WHERE v.[Cód_ Parámetro] = N'COEF_GUARDIA_PUERTO_175/75';
SELECT COUNT(*) AS moldes_esperado_2 FROM #t;
DECLARE @cols nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name NOT IN ('timestamp','$systemId','Cód_ Parámetro','Cód_ Categoría','Nivel','Vigencia Desde','Notas'));
DECLARE @sql nvarchar(max) = N'INSERT dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cols + N',[$systemId],[Cód_ Parámetro],[Cód_ Categoría],[Nivel],[Vigencia Desde],[Notas]) SELECT ' + @cols + N', NEWID(), N''COEF_GUARDIA_PUERTO_175/75_'' + t.cat, t.cat, 2, ''20260201'', N''Meta4: guardia de puerto sin buque de 175/75 paga el 2013 con 1,4 (TIPOACTIVIDAD = 1 lo anula en el 2013).'' FROM #t t WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Cód_ Parámetro] = N''COEF_GUARDIA_PUERTO_175/75_'' + t.cat AND x.[Vigencia Desde] = ''20260101'')';
EXEC (@sql);
SELECT @@ROWCOUNT AS Coef_esperado_2;

-- 2. Concepto 2013: vigencia nueva 2026-02-01
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'2013' AND [Vigencia Desde]='20260201')
BEGIN PRINT 'Ya existe la vigencia 2026-02-01 del 2013'; ROLLBACK; RETURN; END;
DECLARE @old nvarchar(max) = (SELECT [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'2013' AND [Vigencia Desde]='20260101');
DECLARE @quitar nvarchar(100) = N'IFZERO(COEF_GUARDIA_PUERTO, 1)';
IF CHARINDEX(@quitar, @old) = 0 BEGIN PRINT 'No se encontró IFZERO(COEF_GUARDIA_PUERTO, 1)'; ROLLBACK; RETURN; END;
DECLARE @f nvarchar(max) = REPLACE(@old, @quitar, N'IF(TIPOACTIVIDAD = 1, 1, IFZERO(COEF_GUARDIA_PUERTO, 1))');
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
   WHEN N'Vigencia Desde' THEN N'''20260201'''
   WHEN N'Vigencia Hasta' THEN N'''17530101'''
   WHEN N'Fórmula' THEN N'@f'
   ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql2 nvarchar(max) = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @T + N' WHERE [Código]=N''2013'' AND [Vigencia Desde]=''20260101'';';
EXEC sp_executesql @sql2, N'@f nvarchar(max)', @f = @f;
SELECT @@ROWCOUNT AS Insertada_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260131', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Código]=N'2013' AND [Vigencia Desde]='20260101' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerrada_esperado_1;

-- 3. Lista blanca del 2073: OF04
SELECT * INTO #w FROM dbo.[ArbuTest$Concepto CCT Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto]=N'2073' AND [Cód_ Convenio]=N'175/75' AND [Cód_ Categoría]=N'OF02';
UPDATE #w SET [Cód_ Categoría]=N'OF04', [$systemId]=NEWID();
DECLARE @cw nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Concepto CCT Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name <> 'timestamp');
DECLARE @sqlw nvarchar(max) = N'INSERT dbo.[ArbuTest$Concepto CCT Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cw + N') SELECT ' + @cw + N' FROM #w w WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto CCT Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Cód_ Concepto]=N''2073'' AND x.[Cód_ Convenio]=N''175/75'' AND x.[Cód_ Categoría]=N''OF04'')';
EXEC (@sqlw);
SELECT @@ROWCOUNT AS Lista_blanca_esperado_1;

-- 4. Coeficientes por empleado redundantes
DELETE FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro] IN (N'COEF_GUARDIA_PUERTO_04582', N'COEF_GUARDIA_PUERTO_03196');
SELECT @@ROWCOUNT AS Borradas_esperado_2;

SELECT [Cód_ Parámetro],[Valor],[Nivel],CONVERT(varchar(10),[Vigencia Desde],120) d FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base]=N'COEF_GUARDIA_PUERTO' ORDER BY 1;
SELECT [Vigencia Desde],[Vigencia Hasta],LEN([Fórmula]) len_f FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'2013' ORDER BY 1;
COMMIT;
