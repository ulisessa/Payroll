/* 8542 CAJA COMPENSADORA, 8543 FONDO DE DESEMPLEO Y 8593 CUOTA EXTRAORDINARIA ACCIÓN SOCIAL CAP: TAMBIÉN SOBRE LAS VACACIONES.
   01541 (CAP, febrero 2026): Meta4 retiene sobre la liquidación de vacaciones 3.033.487,58 de caja compensadora (8 % de 37.918.594), 94.796,49 de fondo de desempleo (0,25 %) y
   1.019.587,67 de acción social CAP (3 % de la base menos el tope de SIPA); BC retenía 0 en la liquidación de vacaciones y sólo 5.411 / 169 / 0 en la regular (diferencia de neto
   +2.667.636). Causa: las tres fórmulas leen BASE_SINDICAL, que en una liquidación de vacaciones está en cero: la base de vacaciones vive en BASE_SINDICAL_VAC (la que lee el 8525,
   alimentada sólo por el 3553). Meta4 cobra los tres sobre la suma de ambas. Total del mes de 8593 en Meta4: 1.019.587,67 + 2.029,15 = 1.021.616,82 = 3 % x (37.986.232 - 3.932.339).
   Cambio (vigencia nueva 2026-01-02 de los tres, la 2026-01-01 se cierra el mismo día; enero y febrero quedan cubiertos):
     8542  round((BASE_SINDICAL + BASE_SINDICAL_VAC) * PCT_CAJA_COMPENSADORA / 100, PRECISION_REDONDEO)
     8543  IF(PCT_SINDICATO = 'CAP', round((BASE_SINDICAL + BASE_SINDICAL_VAC) * PCT_FDO_DESEMPLEO / 100, PRECISION_REDONDEO), 0)
     8593  IF(PCT_SINDICATO = 'CAP', round(MAX(0, BASE_SINDICAL + BASE_SINDICAL_VAC + MES_BASE_SINDICAL + MES_BASE_SINDICAL_VAC - TOPE_SIPA) * PCT_CUOTA_EXT_CAP / 100, PRECISION_REDONDEO) - MES_CUOTA_EXT_CAP, 0)
   Variable de sistema nueva MES_BASE_SINDICAL_VAC (PERIODO_ACUM sobre BASE_SINDICAL_VAC, copia de MES_BASE_SINDICAL): el tope de SIPA es mensual y se agota entre vacaciones y regular. El reparto del
   8593 entre las dos liquidaciones depende de cuál corre primero (BC: vacaciones, Orden 30, y luego regular); el total del mes es el de Meta4.
   Rollback: borrar las vigencias 2026-01-02 de los tres conceptos (con sus fracciones), reabrir las 2026-01-01 (Hasta 1753-01-01) y borrar la variable MES_BASE_SINDICAL_VAC.
   Después: reiniciar el servicio y recalcular enero y febrero de los empleados con vacaciones y estos conceptos (01541 en febrero). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @F nvarchar(300) = N'dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @V nvarchar(300) = N'dbo.[ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sql nvarchar(max);
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (N'8542', N'8543', N'8593') AND [Vigencia Desde]='20260102')
 OR EXISTS (SELECT 1 FROM dbo.[ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]=N'MES_BASE_SINDICAL_VAC')
BEGIN PRINT 'Ya existe una vigencia 2026-01-02 de estos conceptos o la variable MES_BASE_SINDICAL_VAC'; ROLLBACK; RETURN; END;

-- Variable de sistema nueva (molde MES_BASE_SINDICAL)
DECLARE @vc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@V) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @vs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Nombre Variable' THEN N'N''MES_BASE_SINDICAL_VAC''' WHEN N'Descripción' THEN N'N''Base sindical de vacaciones ya liquidada en otras liquidaciones del mes''' WHEN N'Cód_ Acumulador' THEN N'N''BASE_SINDICAL_VAC'''
    ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@V) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
SET @sql = N'INSERT ' + @V + N' (' + @vc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @vs + @sys + N' FROM ' + @V + N' WHERE [Nombre Variable]=N''MES_BASE_SINDICAL'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Variable_esperado_1;

-- Conceptos
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260102''' WHEN N'Fórmula' THEN N'@fnew' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @fc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @fs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260102''' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
CREATE TABLE #n (cod nvarchar(20) COLLATE DATABASE_DEFAULT, formula nvarchar(max) COLLATE DATABASE_DEFAULT, viejo nvarchar(max) COLLATE DATABASE_DEFAULT);
INSERT #n VALUES
 (N'8542', N'round((BASE_SINDICAL + BASE_SINDICAL_VAC) * PCT_CAJA_COMPENSADORA / 100, PRECISION_REDONDEO)', N'round(BASE_SINDICAL * PCT_CAJA_COMPENSADORA / 100, PRECISION_REDONDEO)'),
 (N'8543', N'IF(PCT_SINDICATO = ''CAP'', round((BASE_SINDICAL + BASE_SINDICAL_VAC) * PCT_FDO_DESEMPLEO / 100, PRECISION_REDONDEO), 0)', N'IF(PCT_SINDICATO = ''CAP'', round(BASE_SINDICAL * PCT_FDO_DESEMPLEO / 100, PRECISION_REDONDEO), 0)'),
 (N'8593', N'IF(PCT_SINDICATO = ''CAP'', round(MAX(0, BASE_SINDICAL + BASE_SINDICAL_VAC + MES_BASE_SINDICAL + MES_BASE_SINDICAL_VAC - TOPE_SIPA) * PCT_CUOTA_EXT_CAP / 100, PRECISION_REDONDEO) - MES_CUOTA_EXT_CAP, 0)',
           N'IF(PCT_SINDICATO = ''CAP'', round(MAX(0, BASE_SINDICAL + MES_BASE_SINDICAL - TOPE_SIPA) * PCT_CUOTA_EXT_CAP / 100, PRECISION_REDONDEO) - MES_CUOTA_EXT_CAP, 0)');
-- la fórmula vigente debe ser exactamente la que se espera reemplazar
IF EXISTS (SELECT 1 FROM #n n WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c WHERE c.[Código]=n.cod AND c.[Vigencia Desde]='20260101' AND c.[Vigencia Hasta]='17530101' AND c.[Fórmula]=n.viejo))
BEGIN PRINT 'La fórmula vigente de algún concepto no es la esperada'; ROLLBACK; RETURN; END;
DECLARE @cod nvarchar(20), @fnew nvarchar(max);
DECLARE cur CURSOR FOR SELECT cod, formula FROM #n;
OPEN cur; FETCH cur INTO @cod, @fnew;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs + @sys + N' FROM ' + @T + N' WHERE [Código]=@cod AND [Vigencia Desde]=''20260101'';';
  EXEC sp_executesql @sql, N'@cod nvarchar(20), @fnew nvarchar(max)', @cod=@cod, @fnew=@fnew;
  SET @sql = N'INSERT ' + @F + N' (' + @fc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @fs + @sys + N' FROM ' + @F + N' WHERE [Cód_ Concepto]=@cod AND [Vigencia Desde]=''20260101'';';
  EXEC sp_executesql @sql, N'@cod nvarchar(20)', @cod=@cod;
  UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260101', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=@cod AND [Vigencia Desde]='20260101';
  FETCH cur INTO @cod, @fnew;
END
CLOSE cur; DEALLOCATE cur;
SELECT [Código], [Vigencia Desde], [Vigencia Hasta], LEFT([Fórmula], 110) f FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (N'8542', N'8543', N'8593') AND [Vigencia Desde]>='20260101' ORDER BY 1, 2;
SELECT [Cód_ Concepto] c, [Vigencia Desde] d, COUNT(*) fracciones FROM dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto] IN (N'8542', N'8543', N'8593') AND [Vigencia Desde]>='20260101' GROUP BY [Cód_ Concepto], [Vigencia Desde] ORDER BY 1, 2;
COMMIT;
