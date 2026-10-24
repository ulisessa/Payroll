/* ANULADO (16/10/2026): ver scripts/Acsoc4757EnVacaciones.sql, que lo revierte; el hueco era el 4757 y no el 4754.
   4754 CUOTA SINDICAL SOBRE EL SAC DEVENGADO: TAMBIÉN LA CAJA COMPENSADORA, EL FONDO DE DESEMPLEO Y LA ACCIÓN SOCIAL CAP.
   El 4754 es la deducción informativa de Ganancias de lo que el sindicato retiene sobre el SAC devengado. Meta4 (C_SINDICAL_SAC_MES) aplica al SAC devengado / 12 la tasa efectiva de TODOS los
   descuentos sindicales del mes: cuota (2,5 %) + caja compensadora (PCT_CAJA_COMPENSADORA) + fondo de desempleo (PCT_FDO_DESEMPLEO, sólo CAP) + acción social CAP (la tasa efectiva del 8593,
   que depende del tope de SIPA). 01541, febrero: vacaciones 3.159.882 x 13,439 % = 424.653 (2,5 + 8 + 0,25 + 2,689, con 2,689 = 1.019.587,67 / 37.918.594 x 100) y regular 5.636 x 13,75 % = 775 (la
   acción social vuelve a ser el 3 % entero porque el tope ya estaba agotado). BC usaba sólo el 2,5 % (78.997 y 140) y el impuesto de 01541 quedaba 29.797 arriba de Meta4.
   Cambio (vigencia nueva 2026-01-02 del 4754 con sus fracciones; la 2026-01-01 se cierra el mismo día): a la tasa que ya suma la cuota y el centro de capacitación se agrega
     + PCT_CAJA_COMPENSADORA
     + IF(PCT_SINDICATO = 'CAP', PCT_FDO_DESEMPLEO + (round(MAX(0, BASE_SINDICAL + BASE_SINDICAL_VAC + MES_BASE_SINDICAL + MES_BASE_SINDICAL_VAC - TOPE_SIPA) * PCT_CUOTA_EXT_CAP / 100, PRECISION_REDONDEO)
                                                       - MES_CUOTA_EXT_CAP) * 100 / IFZERO(BASE_SINDICAL + BASE_SINDICAL_VAC, 1), 0)
   La acción social se calcula con los mismos términos que el 8593 y no se lee con #8593: el 8593 corre en el orden 740 y el 4754 en el 928... el orden no importa porque no se lee el concepto.
   Rollback: borrar la vigencia 2026-01-02 del 4754 (con sus fracciones) y reabrir la 2026-01-01 (Hasta 1753-01-01).
   Después: reiniciar el servicio y recalcular febrero de 01541 (vacaciones y regular). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @F nvarchar(300) = N'dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sql nvarchar(max);
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'4754' AND [Vigencia Desde]='20260102')
BEGIN PRINT 'Ya existe la vigencia 2026-01-02 del 4754'; ROLLBACK; RETURN; END;
DECLARE @old nvarchar(max) = (SELECT [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'4754' AND [Vigencia Desde]='20260101' AND [Vigencia Hasta]='17530101');
DECLARE @viejo nvarchar(200) = N'+ IF(PCT_SINDICATO = ''PAT'', PCT_CENTRO_CAPACIT, 0)';
IF @old IS NULL OR (LEN(@old) - LEN(REPLACE(@old, @viejo, N''))) <> LEN(@viejo) BEGIN PRINT 'La fórmula vigente del 4754 no tiene exactamente un término del centro de capacitación'; ROLLBACK; RETURN; END;
DECLARE @nuevo nvarchar(max) = @viejo
  + N' + PCT_CAJA_COMPENSADORA + IF(PCT_SINDICATO = ''CAP'', PCT_FDO_DESEMPLEO + (round(MAX(0, BASE_SINDICAL + BASE_SINDICAL_VAC + MES_BASE_SINDICAL + MES_BASE_SINDICAL_VAC - TOPE_SIPA) * PCT_CUOTA_EXT_CAP / 100, PRECISION_REDONDEO) - MES_CUOTA_EXT_CAP) * 100 / IFZERO(BASE_SINDICAL + BASE_SINDICAL_VAC, 1), 0)';
DECLARE @fnew nvarchar(max) = REPLACE(@old, @viejo, @nuevo);
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260102''' WHEN N'Fórmula' THEN N'@fnew' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs + @sys + N' FROM ' + @T + N' WHERE [Código]=N''4754'' AND [Vigencia Desde]=''20260101'' AND [Vigencia Hasta]=''17530101'';';
EXEC sp_executesql @sql, N'@fnew nvarchar(max)', @fnew=@fnew;
DECLARE @fc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @fs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260102''' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
SET @sql = N'INSERT ' + @F + N' (' + @fc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @fs + @sys + N' FROM ' + @F + N' WHERE [Cód_ Concepto]=N''4754'' AND [Vigencia Desde]=''20260101'';';
EXEC (@sql);
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260101', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=N'4754' AND [Vigencia Desde]='20260101';
SELECT [Código], [Vigencia Desde], [Vigencia Hasta], LEN([Fórmula]) len_f FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'4754' ORDER BY 2;
SELECT [Vigencia Desde], COUNT(*) fracciones FROM dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto]=N'4754' GROUP BY [Vigencia Desde] ORDER BY 1;
COMMIT;
