/* TOPE DE SIPA DE LAS LIQUIDACIONES FINALES: SE PRORRATEA POR LOS DÍAS DE ALTA DEL SEMESTRE (DIAS_SAC DE META4), NO POR LOS DEL MES.
   04766 (final, baja el 6/2/2026, 37 días de alta desde el 1/1): Meta4 aporta el 11 % de 966.000 (106.260) en el mes y el SAC sobre 3.932.339,08 x 37 / 360 = 404.155 (jubilación 44.457,
   ley 19032 y obra social 12.124 c/u). BC prorrateaba con los 6 días de febrero (DIAS_ALTA_30): 86.511 en el mes y 7.209 / 1.966 / 1.966 en el SAC (diferencia de neto 88.085, sin contar el
   anticipo). Verificado contra Meta4 (columna DIAS_SAC): 04766 = 37, 04751 = 43, 04139 = 40, 04190 = 26, 04807 = 28. Con DIAS_SAC el SAC de enero también cierra (04190: 3.823.372,95 x 26 / 360 = 276.133 -> 30.374,57;
   04807: x 28 / 360 -> 32.711,08), y 04751 / 04139 quedan sin tope (SAC menor al cupo), como ya cerraban con la regla anterior.
   Cambio (vigencia nueva 2026-02-02 de seis conceptos; la abierta desde 2026-02-01 se cierra el 1/2; enero no se toca):
     6000, 6010, 6030 (rama LIQ_FINAL, sólo la primera aparición): TOPE * DIAS_ALTA_30 / 30  ->  TOPE * DIAS_ALTA_SEMESTRE / 30
     6002, 6012, 6034: MIN(#3813 + #3823, IF(MAX(0, X) < TOPE * DIAS_ALTA_30 / 30, #3813 + #3823, TOPE * DIAS_ALTA_30 / 30 / 12))  ->  MIN(#3813 + #3823, TOPE * DIAS_ALTA_SEMESTRE / 360)
   Variable de sistema nueva DIAS_ALTA_SEMESTRE (Cod50016 / Cod50077 / Tab60018): requiere publicar la extensión.
   Rollback: borrar las vigencias 2026-02-02 de los seis conceptos (con fracciones), reabrir las 2026-02-01 (Hasta 1753-01-01) y borrar la variable.
   Después: publicar, reiniciar el servicio y recalcular las finales de febrero. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @F nvarchar(300) = N'dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @V nvarchar(300) = N'dbo.[ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sql nvarchar(max);
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (N'6000',N'6010',N'6030',N'6002',N'6012',N'6034') AND [Vigencia Desde]='20260202')

BEGIN PRINT 'Ya existe una vigencia 2026-02-02 de estos conceptos'; ROLLBACK; RETURN; END;

-- Variable de sistema (molde DIAS_ALTA_30)
DECLARE @vc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@V) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @vs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Nombre Variable' THEN N'N''DIAS_ALTA_SEMESTRE''' WHEN N'Cód_ Cálculo' THEN N'N''DIAS_ALTA_SEMESTRE'''
    WHEN N'Descripción' THEN N'N''Días calendario de alta desde el inicio del semestre hasta el cierre del período (DIAS_SAC de Meta4)''' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@V) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
SET @sql = N'INSERT ' + @V + N' (' + @vc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @vs + @sys + N' FROM ' + @V + N' WHERE [Nombre Variable]=N''DIAS_ALTA_30'' AND NOT EXISTS (SELECT 1 FROM ' + @V + N' WHERE [Nombre Variable]=N''DIAS_ALTA_SEMESTRE'');';   -- el sembrado de la instalación (Cod50077) ya la crea
EXEC (@sql);
SELECT @@ROWCOUNT AS Variable_esperado_1;

DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260202''' WHEN N'Fórmula' THEN N'@fnew' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @fc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @fs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260202''' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @X nvarchar(300) = N'BASE_SS_TRAB + BASE_SS_VAC - #3813 - #3823 + PERIODO_BASE_SS_TRAB + PERIODO_BASE_SS_VAC';
CREATE TABLE #c (cod nvarchar(20) COLLATE DATABASE_DEFAULT, tope nvarchar(20) COLLATE DATABASE_DEFAULT, tipo int);   -- tipo 1 = mensual (primera aparición), 2 = SAC (snippet)
INSERT #c VALUES (N'6000', N'TOPE_SIPA', 1), (N'6010', N'TOPE_SIPA', 1), (N'6030', N'TOPE_SIPA_OS', 1), (N'6002', N'TOPE_SIPA', 2), (N'6012', N'TOPE_SIPA', 2), (N'6034', N'TOPE_SIPA_OS', 2);
DECLARE @cod nvarchar(20), @tope nvarchar(20), @tipo int, @old nvarchar(max), @fnew nvarchar(max), @viejo nvarchar(600), @nuevo nvarchar(600), @pos int;
DECLARE cur CURSOR FOR SELECT cod, tope, tipo FROM #c;
OPEN cur; FETCH cur INTO @cod, @tope, @tipo;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @old = (SELECT [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=@cod AND [Vigencia Desde]='20260201' AND [Vigencia Hasta]='17530101');
  IF @old IS NULL BEGIN PRINT 'Falta la vigencia abierta 2026-02-01 de ' + @cod; ROLLBACK; RETURN; END;
  IF @tipo = 1
  BEGIN
    SET @viejo = @tope + N' * DIAS_ALTA_30 / 30';
    SET @pos = CHARINDEX(@viejo, @old);
    IF @pos = 0 BEGIN PRINT 'No se encontró el tope prorrateado en ' + @cod; ROLLBACK; RETURN; END;
    SET @fnew = STUFF(@old, @pos, LEN(@viejo), @tope + N' * DIAS_ALTA_SEMESTRE / 30');
  END
  ELSE
  BEGIN
    SET @viejo = N'IF(MAX(0, ' + @X + N') < ' + @tope + N' * DIAS_ALTA_30 / 30, #3813 + #3823, ' + @tope + N' * DIAS_ALTA_30 / 30 / 12)';
    SET @nuevo = @tope + N' * DIAS_ALTA_SEMESTRE / 360';
    IF CHARINDEX(@viejo, @old) = 0 BEGIN PRINT 'No se encontró el tope del SAC en ' + @cod; ROLLBACK; RETURN; END;
    SET @fnew = REPLACE(@old, @viejo, @nuevo);
  END;
  IF @fnew = @old OR CHARINDEX(N'DIAS_ALTA_SEMESTRE', @fnew) = 0 BEGIN PRINT 'La fórmula no cambió en ' + @cod; ROLLBACK; RETURN; END;
  SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs + @sys + N' FROM ' + @T + N' WHERE [Código]=@cod AND [Vigencia Desde]=''20260201'' AND [Vigencia Hasta]=''17530101'';';
  EXEC sp_executesql @sql, N'@cod nvarchar(20), @fnew nvarchar(max)', @cod=@cod, @fnew=@fnew;
  SET @sql = N'INSERT ' + @F + N' (' + @fc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @fs + @sys + N' FROM ' + @F + N' WHERE [Cód_ Concepto]=@cod AND [Vigencia Desde]=''20260201'';';
  EXEC sp_executesql @sql, N'@cod nvarchar(20)', @cod=@cod;
  UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260201', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=@cod AND [Vigencia Desde]='20260201' AND [Vigencia Hasta]='17530101';
  FETCH cur INTO @cod, @tope, @tipo;
END
CLOSE cur; DEALLOCATE cur;
SELECT [Código], [Vigencia Desde], [Vigencia Hasta], (LEN([Fórmula])-LEN(REPLACE([Fórmula],N'DIAS_ALTA_SEMESTRE',N'')))/18 n_semestre FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (N'6000',N'6010',N'6030',N'6002',N'6012',N'6034') AND [Vigencia Desde]>='20260201' ORDER BY 1, 2;
SELECT [Cód_ Concepto] c, [Vigencia Desde] d, COUNT(*) fracciones FROM dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto] IN (N'6000',N'6010',N'6030',N'6002',N'6012',N'6034') AND [Vigencia Desde]>='20260201' GROUP BY [Cód_ Concepto], [Vigencia Desde] ORDER BY 1, 2;
COMMIT;
