/* TOPE SIPA DE LOS APORTES (6000, 6010, 6030): SE PRORRATEA POR LOS DÍAS PAGADOS, SIN LOS DE MATERNIDAD. VIGENCIA DESDE EL 1/3/2026.
   90451 (licencia por maternidad AU3 desde el 12/3, paga la maternidad en otro concepto: la deducción 4135 de -3.762.000): Meta4 prorratea el tope por CANT_DIAS_TOPE = 11 (30 menos los 19 días de maternidad en base 30) y corta la base
   en 4.045.590,45 x 11 / 30 = 1.483.383,17: jubilación 163.172,15, ley 19032 y obra social 44.501,50. BC la prorrateaba por DIAS_ALTA_30 = 30 (el empleado está de alta todo el mes) y calculaba sobre 2.178.000: 239.580 y 65.340 (+127.925 de aportes).
   Fórmula 551 de Meta4: los días que se pagan en un concepto aparte (maternidad, accidente, ART) no cuentan para el tope.
   Cambio: vigencia nueva desde el 1/3/2026 (la del 3/2 se cierra el 28/2) donde la rama mensual usa (DIAS_ALTA_30 - DIAS_MATERNIDAD_30) en lugar de DIAS_ALTA_30; la rama de LIQ_FINAL no cambia.
   Sin maternidad en el mes las dos cuentas dan lo mismo. Sólo se evidenció la maternidad; accidente y ART, que Meta4 también excluye, quedan sin tocar (sin caso medido).
   Rollback: borrar las tres vigencias del 2026-03-01 y volver el "Vigencia Hasta" de las del 2026-02-03 a 1753-01-01.
   Después: reiniciar el servicio y recalcular la REGULAR de marzo de 90451 (y de cualquier empleado con maternidad en el mes). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @TC nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN ('6000','6010','6030') AND [Vigencia Desde]='20260301')
BEGIN PRINT 'Ya existen las vigencias'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@TC) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Vigencia Hasta', N'Fórmula'));
DECLARE @sql nvarchar(max) = N'INSERT ' + @TC + N' ([Vigencia Desde],[Vigencia Hasta],[Fórmula],' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ''20260301'',''17530101'',
   REPLACE(REPLACE([Fórmula], N''DIAS_ALTA_30'', N''(DIAS_ALTA_30 - DIAS_MATERNIDAD_30)''), N''(DIAS_ALTA_30 - DIAS_MATERNIDAD_30) + MAX(0'', N''DIAS_ALTA_30 + MAX(0''),' + @cc
  + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @TC + N' WHERE [Código] IN (N''6000'',N''6010'',N''6030'') AND [Vigencia Desde]=''20260203'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Altas_esperado_3;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260228', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código] IN ('6000','6010','6030') AND [Vigencia Desde]='20260203' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerradas_esperado_3;
SELECT [Código] c, CONVERT(varchar(10),[Vigencia Desde],120) d, CONVERT(varchar(10),[Vigencia Hasta],120) h,
  (LEN([Fórmula])-LEN(REPLACE([Fórmula],N'DIAS_MATERNIDAD_30','')))/18 n_mat, (LEN([Fórmula])-LEN(REPLACE([Fórmula],N'DIAS_ALTA_30 + MAX(0','')))/20 n_final
FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN ('6000','6010','6030') AND [Vigencia Desde]>='20260203' ORDER BY 1,2;
COMMIT;
