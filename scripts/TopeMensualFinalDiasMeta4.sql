/* TOPE MENSUAL DE SIPA / OBRA SOCIAL DE LAS FINALES: DÍAS DE ALTA DEL MES AL ESTILO META4 (CORRIGE scripts/TopeSipaFinalPorDiasDelSemestre.sql EN LA PARTE MENSUAL).
   La corrección de la tarde (tope mensual por DIAS_ALTA_SEMESTRE) estaba mal para el aporte MENSUAL: sólo el SAC se topa por los días del semestre (TOPE x DIAS_SAC / 360, eso queda).
   Evidencia, 04047 (final, baja el 11/2, cobertura 1 a 11/2): Meta4 REMU_IMPO_OS_ST = 1.704.013 = 3.932.339,08 x 13 / 30, con 13 días, no 11 y no 42: obra social 3 % = 51.120 (BC daba 80.525
   con 42/30 y sin tope efectivo). La jubilación (base 1.030.326) no llega al tope y coincidía en cualquier caso. Los 13 días son los de Meta4: DIAS_ALTA = 30 - DIAS_POST_BAJA, con post-baja =
   último día calendario del mes - día de baja (28 - 11 = 17 -> 13); 04751 (baja el 12/2) muestra DIAS_ALTA 14 y DIAS_POST_BAJA 16. En enero (31 días) el cálculo no cambia: 04190 = 26.
   BC cuenta con DIAS_ALTA_30 sólo los días hasta la baja (11 en 04047): en meses de menos de 30 días faltan los (30 - días del mes) que Meta4 suma.
   Cambio (vigencia nueva 2026-02-03 de 6000, 6010 y 6030; las 2026-02-02 se cierran el 2/2): en la rama LIQ_FINAL, primera aparición,
     TOPE * DIAS_ALTA_SEMESTRE / 30   ->   TOPE * MIN(30, DIAS_ALTA_30 + MAX(0, 30 - DIAS_MES)) / 30
   (MAX(0, 30 - DIAS_MES) vale 2 en febrero y 0 en los meses de 30 y 31 días). El SAC (6002, 6012, 6034) no se toca.
   Rollback: borrar las vigencias 2026-02-03 de los tres conceptos (con fracciones) y reabrir las 2026-02-02 (Hasta 1753-01-01).
   Después: reiniciar el servicio y recalcular las finales de febrero. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @F nvarchar(300) = N'dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sql nvarchar(max);
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (N'6000',N'6010',N'6030') AND [Vigencia Desde]='20260203')
BEGIN PRINT 'Ya existe una vigencia 2026-02-03 de estos conceptos'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260203''' WHEN N'Fórmula' THEN N'@fnew' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @fc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @fs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260203''' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
CREATE TABLE #c (cod nvarchar(20) COLLATE DATABASE_DEFAULT, tope nvarchar(20) COLLATE DATABASE_DEFAULT);
INSERT #c VALUES (N'6000', N'TOPE_SIPA'), (N'6010', N'TOPE_SIPA'), (N'6030', N'TOPE_SIPA_OS');
DECLARE @cod nvarchar(20), @tope nvarchar(20), @old nvarchar(max), @fnew nvarchar(max), @viejo nvarchar(200), @nuevo nvarchar(300), @pos int;
DECLARE cur CURSOR FOR SELECT cod, tope FROM #c;
OPEN cur; FETCH cur INTO @cod, @tope;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @old = (SELECT [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=@cod AND [Vigencia Desde]='20260202' AND [Vigencia Hasta]='17530101');
  IF @old IS NULL BEGIN PRINT 'Falta la vigencia abierta 2026-02-02 de ' + @cod; ROLLBACK; RETURN; END;
  SET @viejo = @tope + N' * DIAS_ALTA_SEMESTRE / 30';
  SET @nuevo = @tope + N' * MIN(30, DIAS_ALTA_30 + MAX(0, 30 - DIAS_MES)) / 30';
  SET @pos = CHARINDEX(@viejo, @old);
  IF @pos = 0 BEGIN PRINT 'No se encontró el tope por semestre en ' + @cod; ROLLBACK; RETURN; END;
  SET @fnew = STUFF(@old, @pos, LEN(@viejo), @nuevo);
  SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs + @sys + N' FROM ' + @T + N' WHERE [Código]=@cod AND [Vigencia Desde]=''20260202'' AND [Vigencia Hasta]=''17530101'';';
  EXEC sp_executesql @sql, N'@cod nvarchar(20), @fnew nvarchar(max)', @cod=@cod, @fnew=@fnew;
  SET @sql = N'INSERT ' + @F + N' (' + @fc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @fs + @sys + N' FROM ' + @F + N' WHERE [Cód_ Concepto]=@cod AND [Vigencia Desde]=''20260202'';';
  EXEC sp_executesql @sql, N'@cod nvarchar(20)', @cod=@cod;
  UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260202', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=@cod AND [Vigencia Desde]='20260202' AND [Vigencia Hasta]='17530101';
  FETCH cur INTO @cod, @tope;
END
CLOSE cur; DEALLOCATE cur;
SELECT [Código], [Vigencia Desde], [Vigencia Hasta], CHARINDEX(N'MIN(30, DIAS_ALTA_30 + MAX(0, 30 - DIAS_MES))', [Fórmula]) pos FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (N'6000',N'6010',N'6030') AND [Vigencia Desde]>='20260202' ORDER BY 1, 2;
SELECT [Cód_ Concepto] c, [Vigencia Desde] d, COUNT(*) fracciones FROM dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto] IN (N'6000',N'6010',N'6030') AND [Vigencia Desde]>='20260202' GROUP BY [Cód_ Concepto], [Vigencia Desde] ORDER BY 1, 2;
COMMIT;
