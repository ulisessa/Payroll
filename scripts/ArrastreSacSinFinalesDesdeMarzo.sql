/* GANANCIAS: EL ARRASTRE DE SAC DEVENGADO SIN LAS FINALES, DESDE EL 1/3/2026.
   YTD_SAC_DEV suma el SAC devengado (4750) de todas las liquidaciones del año. Una LIQ_FINAL ya liquida el SAC del empleado, y Meta4 no lo vuelve a contar en la base de Ganancias de las liquidaciones siguientes.
   Para febrero existían dos conceptos virtuales (SAC_DEV_YTD_BASE, orden 0, conserva el valor original; YTD_SAC_DEV, orden 1 = #SAC_DEV_YTD_BASE - SAC_DEV_FINAL_HIST, que resta el 4750 de las LIQ_FINAL del año) con vigencia
   sólo en febrero, y la nota de febrero pedía contrastar la cohorte antes de extenderlos. En marzo la cohorte es de 7 empleados con final y liquidación posterior: 04139, 04486, 04751, 04775, 04803, 04854 y 04889.
   04775 (final en enero, alta el 2/2) lo mostró: BC sumaba el 4750 de enero (112.252,17) y quedaba 13.470,26 de impuesto por encima de Meta4 (12 % del tramo 3 de la escala de marzo).
   Cambio: vigencia nueva desde el 1/3/2026, abierta, de los dos conceptos (copia de las de febrero, ya cerradas al 28/2).
   Rollback: borrar las dos filas del 2026-03-01.
   Después: reiniciar el servicio y recalcular marzo de los 7 empleados. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @C nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (N'YTD_SAC_DEV',N'SAC_DEV_YTD_BASE') AND [Vigencia Desde]='20260301')
BEGIN PRINT 'Ya existe'; ROLLBACK; RETURN; END;
DECLARE @sys nvarchar(400) = N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''';
DECLARE @sysc nvarchar(200) = N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]';
DECLARE @cc nvarchar(max), @sql nvarchar(max);
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@C) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Vigencia Hasta'));
SET @sql = N'INSERT ' + @C + N' ([Vigencia Desde],[Vigencia Hasta],' + @cc + @sysc + N') SELECT ''20260301'',''17530101'',' + @cc + @sys
  + N' FROM ' + @C + N' WHERE [Código] IN (N''YTD_SAC_DEV'',N''SAC_DEV_YTD_BASE'') AND [Vigencia Desde]=''20260201'';';
EXEC sp_executesql @sql;
SELECT @@ROWCOUNT AS Altas_esperado_2;
SELECT [Código],CONVERT(varchar(10),[Vigencia Desde],120) d,CONVERT(varchar(10),[Vigencia Hasta],120) h,[Orden Cálculo],[Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (N'YTD_SAC_DEV',N'SAC_DEV_YTD_BASE') ORDER BY 1,2;
COMMIT;
