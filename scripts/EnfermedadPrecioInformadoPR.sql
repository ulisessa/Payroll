/* ENFERMEDAD: PRECIO INFORMADO (4057 / PR_ENFERMEDAD) EN LUGAR DE NOVEDADES DE IMPORTE EN EL 4110.
   Meta4 no corrige el importe: informa el PRECIO DIARIO en una novedad del 4057 y las pagas siguientes de la misma licencia lo recuperan por PR_ENFERMEDAD (PRE_ENFER).
   Las 21 novedades de importe del 4110 que igualaban el recibo (enero: 8, febrero: 5, marzo a junio: 8; recaídas de intervalo breve y 03986, ver
   Vault/07 Lecciones/enfermedad-regla-original-meta4.md) pasan a ser lo que son: el precio de Meta4.
   Cambios, todos datos (nada de tablas nuevas):
     1. Concepto informativo 4057 "Precio diario de enfermedad (Meta4 4057)", sin fórmula (molde 2041), vigencia desde 2026-01-01.
     2. Fuente de datos PRECIO_ENF_INF (molde IND_GUARDIA_2041): suma el Valor Unitario de las novedades 4057 del empleado en el período (tabla 110038, campo 14).
     3. 4110: vigencias nuevas 2026-01-04..2026-01-31 y 2026-02-04..abierta (copias de 2026-01-03 y 2026-02-03, con sus 8 fracciones; las anteriores se cierran el 3/1 y el 3/2):
        el precio de TIPOEMPL=2 es IF(PRECIO_ENF_INF > 0, PRECIO_ENF_INF * 30, #PROM_ENF_MES): si hay precio informado manda; si no, el promedio de siempre. Coeficiente y días no cambian.
     4. 21 novedades 4057 (Cantidad 1, Importe 0, Valor Unitario = PRE_ENFER de Meta4 del empleado y mes) y las 21 novedades 4110 de importe pasan a Anulada con No. Liquidación vacío.
   Las 4 novedades 4110 de enero ya anuladas (02670, 02854, 04185, 04216) no se tocan: la fórmula sola da exacto.
   Rollback: borrar las novedades 4057, la fuente PRECIO_ENF_INF, el concepto 4057 y las vigencias 2026-01-04/2026-02-04 del 4110 (con fracciones), reabrir las del 3/1 y el 3/2
   (Hasta 2026-01-31 y 1753-01-01) y volver las novedades 4110 a Pendiente.
   Después: reiniciar el servicio y recalcular enero (8) y febrero (5) de los empleados con novedad. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @F nvarchar(300) = N'dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sql nvarchar(max);
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE ([Código]=N'4057') OR ([Código]=N'4110' AND [Vigencia Desde] IN ('20260104','20260204')))
BEGIN PRINT 'Ya existe el 4057 o una vigencia 2026-01-04/2026-02-04 del 4110'; ROLLBACK; RETURN; END;

-- 1. Concepto 4057 (molde 2041)
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @c57 nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Código' THEN N'N''4057''' WHEN N'Descripción' THEN N'N''Precio diario de enfermedad (Meta4 4057)''' WHEN N'Vigencia Desde' THEN N'''20260101'''
   ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @c57 + @sys + N' FROM ' + @T + N' WHERE [Código]=N''2041'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Concepto_4057_esperado_1;

-- 2. Fuente PRECIO_ENF_INF (molde IND_GUARDIA_2041, campo valor 14 = Valor Unitario)
SELECT * INTO #f FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]=N'IND_GUARDIA_2041';
UPDATE #f SET [Nombre Variable]=N'PRECIO_ENF_INF', [Descripción]=N'Precio diario de enfermedad informado (novedad 4057, como PR_ENFERMEDAD de Meta4)', [No_ Campo Valor]=14, [$systemId]=NEWID();
DECLARE @cf nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name <> 'timestamp');
EXEC (N'INSERT dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cf + N') SELECT ' + @cf + N' FROM #f');
INSERT dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Nombre Variable],[No_ Campo],[Filtro Valor]) VALUES
 (N'PRECIO_ENF_INF', 7, N'{EMP_NO}'), (N'PRECIO_ENF_INF', 10, N'4057'), (N'PRECIO_ENF_INF', 2, N'{PERIODO}');
INSERT dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Nombre Variable],[No_ Campo],[Filtro Valor]) VALUES (N'PRECIO_ENF_INF', 20, N'<>Anulada'); -- una novedad Anulada no informa precio (el Estado no estaba filtrado)

-- 3. 4110: dos vigencias nuevas (fórmula y Variable Base con el precio informado) + fracciones
DECLARE @fc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @fs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'@d' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'@d' WHEN N'Vigencia Hasta' THEN N'@h' WHEN N'Fórmula' THEN N'@fnew' WHEN N'Variable Base' THEN N'@vbnew' ELSE QUOTENAME(c.name) END, ',')
        FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
CREATE TABLE #v (desde date, hasta date, molde date);
INSERT #v VALUES ('20260104', '20260131', '20260103'), ('20260204', '17530101', '20260203');
DECLARE @d date, @h date, @m date, @old nvarchar(max), @vb nvarchar(max), @fnew nvarchar(max), @vbnew nvarchar(max);
DECLARE @nuevo nvarchar(200) = N'IF(PRECIO_ENF_INF > 0, PRECIO_ENF_INF * 30, #PROM_ENF_MES)';
DECLARE cur CURSOR FOR SELECT desde, hasta, molde FROM #v;
OPEN cur; FETCH cur INTO @d, @h, @m;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @old = (SELECT [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'4110' AND [Vigencia Desde]=@m);
  SET @vb = (SELECT [Variable Base] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'4110' AND [Vigencia Desde]=@m);
  IF (LEN(@old) - LEN(REPLACE(@old, N'#PROM_ENF_MES *', N''))) <> LEN(N'#PROM_ENF_MES *') BEGIN PRINT 'La fórmula del molde no tiene exactamente un "#PROM_ENF_MES *"'; ROLLBACK; RETURN; END;
  SET @fnew = REPLACE(@old, N'#PROM_ENF_MES *', @nuevo + N' *');
  SET @vbnew = REPLACE(@vb, N'#PROM_ENF_MES', @nuevo);
  SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs + @sys + N' FROM ' + @T + N' WHERE [Código]=N''4110'' AND [Vigencia Desde]=@m;';
  EXEC sp_executesql @sql, N'@d date, @h date, @m date, @fnew nvarchar(max), @vbnew nvarchar(max)', @d=@d, @h=@h, @m=@m, @fnew=@fnew, @vbnew=@vbnew;
  SET @sql = N'INSERT ' + @F + N' (' + @fc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @fs + @sys + N' FROM ' + @F + N' WHERE [Cód_ Concepto]=N''4110'' AND [Vigencia Desde]=@m;';
  EXEC sp_executesql @sql, N'@d date, @m date', @d=@d, @m=@m;
  UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]=@m, [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=N'4110' AND [Vigencia Desde]=@m;
  FETCH cur INTO @d, @h, @m;
END
CLOSE cur; DEALLOCATE cur;
SELECT [Vigencia Desde], [Vigencia Hasta], LEFT([Variable Base], 90) vb FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'4110' AND [Vigencia Desde]>='20260103' ORDER BY 1;
SELECT [Vigencia Desde], COUNT(*) fracciones FROM dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto]=N'4110' AND [Vigencia Desde] IN ('20260104','20260204') GROUP BY [Vigencia Desde];

-- 4. Novedades 4057 (precio de Meta4) y baja de las novedades de importe del 4110
SELECT * INTO #n FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto]=N'4110' AND Estado <> 2;
SELECT COUNT(*) AS Novedades_4110_a_convertir_esperado_21 FROM #n;
UPDATE n SET [Cód_ Concepto]=N'4057', [Cantidad]=1, [Unidad Cantidad]=N'', [Valor Unitario]=p.Pre, [Importe]=0, [Estado]=0, [No_ Liquidación]=N'', [Motivo No Aplicada]=N'',
             [Observaciones]=N'Meta4 4057: precio diario informado (PR_ENFERMEDAD)', [$systemId]=NEWID()
FROM #n n CROSS APPLY (SELECT MAX(v.Valor) Pre FROM dbo.[ArbuTest$Hist_ Liq_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
  JOIN dbo.[ArbuTest$Valor Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v ON v.[No_ Entrada]=h.[No_ Entrada]
  JOIN dbo.[ArbuTest$Columna Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c ON c.[No_]=v.[No_ Columna] AND c.[Nombre Columna]=N'PRE_ENFER'
  WHERE h.[No_ Empleado]=n.[No_ Empleado] AND h.Año*100+h.Mes=CAST(n.[Cód_ Período] AS int) AND v.Valor<>0) p;
IF EXISTS (SELECT 1 FROM #n WHERE [Valor Unitario] IS NULL OR [Valor Unitario] <= 0) BEGIN PRINT 'Hay novedades sin precio de Meta4'; ROLLBACK; RETURN; END;
DECLARE @nc nvarchar(max) = N'[Cód_ Período],[Fecha],[Cód_ Tipo Liq_],[Cód_ Convenio],[Cód_ Categoría],[No_ Empleado],[Nombre Empleado],[No_ Proyecto],[Cód_ Concepto],[Cantidad],[Unidad Cantidad],[Valor Unitario],[Importe],[Observaciones],[Estado],[No_ Liquidación],[Motivo No Aplicada],[Recurrente],[Períodos Restantes],[Novedad Origen],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]';
EXEC (N'INSERT dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @nc + N') SELECT ' + @nc + N' FROM #n');
SELECT @@ROWCOUNT AS Novedades_4057_insertadas_esperado_21;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET Estado=2, [No_ Liquidación]=N'', [Motivo No Aplicada]=N'', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Cód_ Concepto]=N'4110' AND Estado<>2;
SELECT @@ROWCOUNT AS Novedades_4110_anuladas_esperado_21;
SELECT [Cód_ Período], COUNT(*) n, MIN([Valor Unitario]) pmin FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto]=N'4057' GROUP BY [Cód_ Período] ORDER BY 1;
COMMIT;
