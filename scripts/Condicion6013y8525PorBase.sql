/* LEY 19032 VACACIONES (6013) Y CUOTA SINDICAL VACACIONES (8525): CONDICIÓN POR LA BASE Y NO POR LOS DÍAS DE ESTADO. VIGENCIA DESDE EL 1/3/2026.
   04495 (729/15): su VACACIONES de marzo se paga con la novedad del 3553 por 1.826.164,11 (el concepto vale por incidencia, no sólo por días: condición del 3553 = CANT_INCIDENCIA > 0 OR DIAS_VAC_INICIO > 0) y su historia de
   estados de Meta4 no tiene días de vacaciones en marzo: DIAS_VAC_INICIO = 0. BC descontaba la jubilación de vacaciones (6003, condición BASE_SS_VAC > 0: 200.878,05) pero no la Ley 19032 (6013, 3 %: 54.784,92) ni la cuota
   sindical (8525, 4 %: 73.046,56), que Meta4 sí descuenta: -127.831 de descuentos, exactamente esos dos importes.
   Cambio: vigencia nueva desde el 1/3/2026 (las del 1/1 se cierran el 28/2) con
     6013: (DIAS_VAC_INICIO > 0) and (ES_JUBILADO = 0)  ->  (BASE_SS_VAC > 0) and (ES_JUBILADO = 0)
     8525: DIAS_VAC_INICIO > 0                          ->  BASE_SINDICAL_VAC > 0
   Mismo criterio que el 6003: la vacación existe si hay base, haya o no días de estado. No cambia a nadie que ya tuviera días de vacaciones (tienen base).
   No se tocan el 6037 (adicional obra social vacaciones) ni el 8810 (descuento de anticipo de vacaciones), que tienen la misma condición pero no hay evidencia de Meta4 sobre ellos.
   Rollback: borrar las dos vigencias del 2026-03-01 y volver el "Vigencia Hasta" de las del 2026-01-01 a 1753-01-01.
   Después: reiniciar el servicio y recalcular la VACACIONES de marzo de 04495. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @TC nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN ('6013','8525') AND [Vigencia Desde]='20260301')
BEGIN PRINT 'Ya existen las vigencias'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@TC) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Vigencia Hasta', N'Condición'));
DECLARE @sql nvarchar(max) = N'INSERT ' + @TC + N' ([Vigencia Desde],[Vigencia Hasta],[Condición],' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ''20260301'',''17530101'',@cond,' + @cc
  + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @TC + N' WHERE [Código]=@c AND [Vigencia Desde]=''20260101'';';
EXEC sp_executesql @sql, N'@cond nvarchar(max),@c nvarchar(20)', N'(BASE_SS_VAC > 0) and (ES_JUBILADO = 0)', N'6013';
EXEC sp_executesql @sql, N'@cond nvarchar(max),@c nvarchar(20)', N'BASE_SINDICAL_VAC > 0', N'8525';
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260228', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código] IN ('6013','8525') AND [Vigencia Desde]='20260101' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerradas_esperado_2;
SELECT [Código] c, CONVERT(varchar(10),[Vigencia Desde],120) d, CONVERT(varchar(10),[Vigencia Hasta],120) h, [Condición] cond FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN ('6013','8525') ORDER BY 1,2;
COMMIT;
