/* TOPE SIPA DE LOS APORTES SOBRE SAC DEVENGADO (4751, 4752, 4753): TAMBIÉN SIN LOS DÍAS DE MATERNIDAD. VIGENCIA DESDE EL 1/3/2026.
   Continuación de TopeAportesSinMaternidad6000.sql. Aquel script corrigió 6000/6010/6030 pero los aportes sobre el SAC devengado siguieron prorrateando el tope sólo por DIAS_ALTA_30.
   90451 (maternidad desde el 12/3, 11 días pagados): Meta4 calcula JUB_SAC_MES = MIN(2.178.000; 4.045.590,45 x 11 / 30 = 1.483.383,17) x 11 % / 12 = 13.597,68 y LEY/OBRA 3.708,46; BC daba 19.965 y 5.445.
   Esos 9.840,40 de más se restaban de la base de Ganancias (YTD_SS_SAC_DEV) y bajaban el impuesto 1.869,67 (x19 %): el último resto de 90451 en marzo (-1.869,68).
   Cambio: vigencia nueva desde el 1/3/2026 (la del 1/2 se cierra el 28/2) donde la rama mensual usa (DIAS_ALTA_30 - DIAS_MATERNIDAD_30); la rama de LIQ_FINAL no cambia. Sin maternidad en el mes las dos cuentas dan lo mismo.
   Rollback: borrar las tres vigencias del 2026-03-01 y volver el "Vigencia Hasta" de las del 2026-02-01 a 1753-01-01.
   Después: reiniciar el servicio y recalcular la REGULAR de marzo de 90451 (y de cualquier empleado con maternidad en el mes). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @TC nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN ('4751','4752','4753') AND [Vigencia Desde]='20260301')
BEGIN PRINT 'Ya existen las vigencias'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@TC) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Vigencia Hasta', N'Fórmula'));
DECLARE @sql nvarchar(max) = N'INSERT ' + @TC + N' ([Vigencia Desde],[Vigencia Hasta],[Fórmula],' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ''20260301'',''17530101'',
   REPLACE([Fórmula], N''DIAS_ALTA_30'', N''(DIAS_ALTA_30 - DIAS_MATERNIDAD_30)''),' + @cc
  + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @TC + N' WHERE [Código] IN (N''4751'',N''4752'',N''4753'') AND [Vigencia Desde]=''20260201'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Altas_esperado_3;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260228', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código] IN ('4751','4752','4753') AND [Vigencia Desde]='20260201' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerradas_esperado_3;
SELECT [Código],CONVERT(varchar(10),[Vigencia Desde],120) d,CONVERT(varchar(10),[Vigencia Hasta],120) h,(LEN([Fórmula])-LEN(REPLACE([Fórmula],N'DIAS_MATERNIDAD_30','')))/18 AS n_mat FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN ('4751','4752','4753') ORDER BY 1,2;
COMMIT;
