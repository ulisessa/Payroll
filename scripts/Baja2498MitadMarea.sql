/* BAJA A MITAD DE MAREA: LA PRODUCCIÓN HASTA EL DÍA DE DESEMBARQUE SE LIQUIDA EN EL DEVENGADO DE LA BAJA, Y EL CIERRE DESCUENTA LO YA PAGADO.
   04850 (HF801, marea 8): asignación del 17 al 27/2 (baja por enfermedad). Meta4 lo cierra al bajarse (cont. 5, tipo de imputación 10) y paga producción
   634.800 y feriado 96.658; BC lo cobraba recién en el cierre de la marea 8 (marzo). El diario de a bordo del tramo 17-27/2 suma 63.480 kg x 10.000 por
   tonelada (MR08, entero) = 634.800, exacto: la rama no completa del 2498 ya funciona con DIARIO_KN_* y {ASIG_DESDE}..{ASIG_HASTA}.
   Cambios, todos datos:
     1. Fuente BAJA_EN_COBERTURA (Personal Proyecto, tabla 60009): cuenta las asignaciones del empleado en el proyecto cuya Fecha Baja cae en la cobertura.
     2. Fuente PROD_DEV_PREV (Línea Liquidación, tabla 60012): suma el 2498 ya liquidado a ese empleado en ese proyecto en DEVENGADOS no Borrador.
     3. 2498: vigencia nueva 2026-02-01 (la 2026-01-01 se cierra el 31/1): se liquida también en DEVENGADOS cuando TIPOACTIVIDAD = 1 y hay baja en la cobertura
        (Condición TIPO_LIQ = 'CIERRE_MAREA' OR (BAJA_EN_COBERTURA > 0 AND TIPOACTIVIDAD = 1)), y el cierre resta PROD_DEV_PREV.
     4. Se borran las dos novedades que ajustaban 04850 en febrero (2498 y 1023). El 1023 de 96.658 sale solo: 38.949 + 634.800 / DIAS_ENROLAMIENTO (11).
   Rollback: borrar las dos fuentes con sus filtros y la fila 2026-02-01 del 2498, reabrir la anterior y volver a cargar las novedades de scripts/Novedad2498y1023_04850.sql.
   Después: reiniciar el servicio y recalcular el devengado LIQ-00053255 de 04850. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
-- 1. BAJA_EN_COBERTURA (molde MAREA_COMPLETA)
IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]=N'BAJA_EN_COBERTURA')
BEGIN
  SELECT * INTO #f1 FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]=N'MAREA_COMPLETA';
  UPDATE #f1 SET [Nombre Variable]=N'BAJA_EN_COBERTURA', [Descripción]=N'Asignaciones del empleado en la marea dadas de baja dentro de la cobertura (baja a mitad de marea)', [$systemId]=NEWID();
  DECLARE @cf nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name <> 'timestamp');
  EXEC (N'INSERT dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cf + N') SELECT ' + @cf + N' FROM #f1');
  INSERT dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Nombre Variable],[No_ Campo],[Filtro Valor]) VALUES
   (N'BAJA_EN_COBERTURA', 1, N'{EMP_NO}'), (N'BAJA_EN_COBERTURA', 2, N'{JOB_NO}'), (N'BAJA_EN_COBERTURA', 6, N'{PERIODO_DESDE}..{FECHA_REF}');
END
-- 2. PROD_DEV_PREV (molde A_CUENTA_MAREA)
IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]=N'PROD_DEV_PREV')
BEGIN
  SELECT * INTO #f2 FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]=N'A_CUENTA_MAREA';
  UPDATE #f2 SET [Nombre Variable]=N'PROD_DEV_PREV', [Descripción]=N'Producción (2498) ya liquidada en devengados de la marea (baja a mitad de marea)', [Id_ Tabla]=60012, [No_ Campo Valor]=7, [Función Agregado]=0, [$systemId]=NEWID();
  DECLARE @cf2 nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name <> 'timestamp');
  EXEC (N'INSERT dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cf2 + N') SELECT ' + @cf2 + N' FROM #f2');
  INSERT dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Nombre Variable],[No_ Campo],[Filtro Valor]) VALUES
   (N'PROD_DEV_PREV', 16, N'{EMP_NO}'), (N'PROD_DEV_PREV', 18, N'{JOB_NO}'), (N'PROD_DEV_PREV', 3, N'2498'), (N'PROD_DEV_PREV', 30, N'DEVENGADOS'), (N'PROD_DEV_PREV', 22, N'<>0');
END
SELECT [Nombre Variable], [No_ Campo], [Filtro Valor] FROM dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable] IN (N'BAJA_EN_COBERTURA', N'PROD_DEV_PREV') ORDER BY 1, [No_ Línea];

-- 3. Concepto 2498: vigencia nueva 2026-02-01
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'2498' AND [Vigencia Desde]='20260201')
BEGIN PRINT 'Ya existe la vigencia 2026-02-01 del 2498'; ROLLBACK; RETURN; END;
DECLARE @old nvarchar(max) = (SELECT [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'2498' AND [Vigencia Desde]='20260101');
DECLARE @f nvarchar(max) = N'(' + @old + N') - IF(TIPO_LIQ = ''CIERRE_MAREA'', PROD_DEV_PREV, 0)';
DECLARE @cond nvarchar(max) = N'TIPO_LIQ = ''CIERRE_MAREA'' OR (BAJA_EN_COBERTURA > 0 AND TIPOACTIVIDAD = 1)';
DECLARE @tipos nvarchar(max) = N'CIERRE_MAREA|DEVENGADOS';
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
   WHEN N'Vigencia Desde' THEN N'''20260201'''
   WHEN N'Vigencia Hasta' THEN N'''17530101'''
   WHEN N'Fórmula' THEN N'@f'
   WHEN N'Condición' THEN N'@cond'
   WHEN N'Tipos Liq_ Aplicables' THEN N'@tipos'
   ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @T + N' WHERE [Código]=N''2498'' AND [Vigencia Desde]=''20260101'';';
EXEC sp_executesql @sql, N'@f nvarchar(max), @cond nvarchar(max), @tipos nvarchar(max)', @f = @f, @cond = @cond, @tipos = @tipos;
SELECT @@ROWCOUNT AS Insertada_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260131', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Código]=N'2498' AND [Vigencia Desde]='20260101' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerrada_esperado_1;

-- 4. Novedades puntuales de 04850 que ya no hacen falta
DELETE FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_ Empleado]=N'04850' AND [Cód_ Período]=N'202602' AND [Cód_ Concepto] IN (N'2498', N'1023') AND [Observaciones] LIKE N'04850:%';
SELECT @@ROWCOUNT AS Novedades_borradas_esperado_2;
SELECT [Vigencia Desde],[Vigencia Hasta],[Tipos Liq_ Aplicables],[Condición],LEN([Fórmula]) len_f FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'2498' ORDER BY 1;
COMMIT;
