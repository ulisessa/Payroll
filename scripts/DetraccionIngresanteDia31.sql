/* DETRACCIÓN (5802 -> CNT_RED_SUELDO) DE UN INGRESANTE EN UN MES DE 31 DÍAS: CUENTA EL DÍA 31. VIGENCIA DESDE EL 1/3/2026.
   El 5802 da los días sobre los que se prorratea la detracción de SIPA (CNT_RED_SUELDO = DED_CONT_PATR x días / 30). Usaba DIAS_ALTA_30, que saltea el día 31 a propósito (es el mes comercial de 30: así se verificó la deducción por ausencias).
   Para la detracción Meta4 hace otra cuenta: días calendario de alta hasta el fin de mes, con tope 30 (DIAS_ALTA de Meta4: 04751 con alta el 25/3 = 7, BC 6; 04139 desde el 22/3 = 10, BC 9; 03183 desde el 2/3 = 30, BC 29).
   Cada día de menos son 233,46 de detracción menos descontada de la base y 42,01 de más en las contribuciones (18 empleados en marzo).
   Cambio: vigencia nueva del 5802 desde el 1/3/2026, abierta (la del 1/2 se cierra el 28/2). En la rama de REGULAR / DEVENGADOS / LIQ_FINAL de un embarcado, DIAS_ALTA_30 pasa a
        DIAS_ALTA_30 + IF(TIPO_LIQ <> 'LIQ_FINAL' AND DIAS_MES = 31 AND DIAS_ALTA_30 > 0 AND DIAS_ALTA_30 < 30, 1, 0)
   Es decir, +1 sólo con período de 31 días, alta parcial (el que está todo el mes ya tiene 30) y liquidación que no es final (una final cierra con baja y no se sabe si el 31 fue de alta). En meses de 30 o 28 días no cambia nada.
   No se tocó DIAS_ALTA_30, que usan el 4703 y los topes SIPA y está verificado así. Sólo lo usa CNT_RED_SUELDO (5811 lo lee de ahí).
   Rollback: borrar la fila del 2026-03-01 y reabrir la del 2026-02-01 (Vigencia Hasta 1753-01-01).
   Después: reiniciar el servicio y recalcular marzo de los 18 ingresantes: 03183 04001 04046 04137 04139 04347 04393 04487 04496 04542 04606 04672 04751 04928 04929 04930 04931 04932 (y 04560 y 04848, que pueden moverse). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @C nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'5802' AND [Vigencia Desde]='20260301')
BEGIN PRINT 'Ya existe'; ROLLBACK; RETURN; END;
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sysc nvarchar(200) = N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]';
DECLARE @cc nvarchar(max), @sql nvarchar(max);
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@C) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Vigencia Hasta', N'Fórmula'));
SET @sql = N'INSERT ' + @C + N' ([Vigencia Desde],[Vigencia Hasta],[Fórmula],' + @cc + @sysc + N') SELECT ''20260301'',''17530101'',
   REPLACE([Fórmula], N''DIAS_ALTA_30, CNT_DIAS_PAGADOS'', N''DIAS_ALTA_30 + IF(TIPO_LIQ <> ''''LIQ_FINAL'''' AND DIAS_MES = 31 AND DIAS_ALTA_30 > 0 AND DIAS_ALTA_30 < 30, 1, 0), CNT_DIAS_PAGADOS''),' + @cc + @sys
  + N' FROM ' + @C + N' WHERE [Código]=N''5802'' AND [Vigencia Desde]=''20260201'' AND [Vigencia Hasta]=''17530101'';';
EXEC sp_executesql @sql;
SELECT @@ROWCOUNT AS Alta_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260228', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]=N'5802' AND [Vigencia Desde]='20260201' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerrada_esperado_1;
SELECT CONVERT(varchar(10),[Vigencia Desde],120) d,CONVERT(varchar(10),[Vigencia Hasta],120) h,[Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'5802' ORDER BY 1;
COMMIT;
