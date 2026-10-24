/* 1534 PREMIO ADICIONAL ESPECIAL: DEBE CORRER DESPUÉS DEL 1023 (SUELDO DE FERIADO), QUE LEE CON #1023.
   04724, devengado del 13 al 28/2: BC pagaba 1534 +142.318 y 2003 -140.320 contra Meta4 (el bruto del mes quedaba +1.997). El 1534 resta #1023 (el feriado, 142.318) pero corría en el orden 159, o en el 451 en la
   rama sin grossing-up; el 1023 corre en el 470 (se movió de 450 a 470), así que #1023 valía cero en el 1534 y el premio absorbía el feriado dos veces: lo pagaba el 1023 y lo pagaba de más el 1534.
   Es el desorden que el control de precedencia ya había listado el 28/9 (1534 orden 159 -> #1023 orden 450).
   Cambio (vigencia nueva 2026-02-04 del 1534, la 2026-02-03 se cierra el 3/2; la fórmula no cambia): Fórmula Orden Cálculo
        IF(APLICA_PROD_FIJO > 0 AND TIPOACTIVIDAD = 1 AND PCT_PROD_CAPECA > 0, 471, 159)
   en lugar de IF(APLICA_PROD_FIJO > 0 AND TIPOACTIVIDAD = 1 AND NETO_GU_MAREA = 0 AND ES_GROSSING_UP = 0 AND PCT_PROD_CAPECA > 0, 451, 159): sin la guarda del grossing-up, porque la rama con #1023
   también aplica al que lo tiene, y 471 en vez de 451, justo después del 1023. Los lectores del 1534 entre el 160 y el 470 son los de ausentismo (4110, 4120, 4125, PROM_ENF_MES), que leen su base
   histórica, y el 3813 (orden 470), que sólo corre en finales donde el 1534 no aplica. La rama tangonero (TIPOACTIVIDAD distinto de 1) también lee #1023 y sigue en el 159: sin verificar contra Meta4.
   Rollback: borrar la vigencia 2026-02-04 del 1534 (con fracciones) y reabrir la 2026-02-03 (Hasta 1753-01-01).
   Después: reiniciar el servicio y recalcular el cierre y el devengado de febrero de 04724 y de quien tenga 1534 y 1023 en la misma liquidación. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @F nvarchar(300) = N'dbo.[ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sql nvarchar(max);
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'1534' AND [Vigencia Desde]='20260204')
BEGIN PRINT 'Ya existe la vigencia 2026-02-04 del 1534'; ROLLBACK; RETURN; END;
IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'1534' AND [Vigencia Desde]='20260203' AND [Vigencia Hasta]='17530101'
   AND [Fórmula Orden Cálculo]=N'IF(APLICA_PROD_FIJO > 0 AND TIPOACTIVIDAD = 1 AND NETO_GU_MAREA = 0 AND ES_GROSSING_UP = 0 AND PCT_PROD_CAPECA > 0, 451, 159)')
BEGIN PRINT 'La vigencia abierta 2026-02-03 del 1534 no es la esperada'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260204''' WHEN N'Fórmula Orden Cálculo' THEN N'N''IF(APLICA_PROD_FIJO > 0 AND TIPOACTIVIDAD = 1 AND PCT_PROD_CAPECA > 0, 471, 159)''' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
SET @sql = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @cs + @sys + N' FROM ' + @T + N' WHERE [Código]=N''1534'' AND [Vigencia Desde]=''20260203'' AND [Vigencia Hasta]=''17530101'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Vigencia_esperado_1;
DECLARE @fc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @fs nvarchar(max) = (SELECT STRING_AGG(CASE c.name WHEN N'Vigencia Desde' THEN N'''20260204''' ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@F) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
SET @sql = N'INSERT ' + @F + N' (' + @fc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ' + @fs + @sys + N' FROM ' + @F + N' WHERE [Cód_ Concepto]=N''1534'' AND [Vigencia Desde]=''20260203'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Fracciones_esperado_8;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260203', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=N'1534' AND [Vigencia Desde]='20260203';
SELECT [Código],[Vigencia Desde],[Vigencia Hasta],[Fórmula Orden Cálculo] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'1534' AND [Vigencia Desde]>='20260203' ORDER BY 2;
COMMIT;
