/* 03073: DOS MESES DEL HISTÓRICO DE ENFERMEDAD QUE LA MIGRACIÓN DEJÓ AFUERA (NOVIEMBRE Y DICIEMBRE DE 2024).
   El precio de enero de 03073 se ancla correctamente en noviembre de 2024 a octubre de 2025 (divisor 12), pero BC no tiene noviembre ni diciembre de 2024: tenían TOT_REM_IMP = 0 y
   TOT_PROMEDIOS > 0 y la migración los descartó por ese criterio. Juntos explican el 12,1129 % que el 4110 de enero quedaba abajo de Meta4 (PRE_ENFER 139.708,8444).
   Se incorporan igual que los otros tres meses omitidos (02737 y 03986, scripts/CorregirBaseEnfermedadFebrero.sql): una cabecera HIST_REMUN informativa (Estado 2, importes
   económicos en cero, sin proyecto ni vínculos) con una única línea AJ_HIST_AUS = TOT_PROMEDIOS original de Meta4 del vínculo del 18/6/2002 (tipos de imputación 1,10,11,12,13,14,15,3):
   202411 = 3.046.106,70 y 202412 = 3.046.106,52. No se inventa un pago histórico; no cambia BASE_PROMEDIO ni la fórmula, el ancla o el divisor.
   Moldes: cabecera = LIQ-00018774 (HIST_REMUN 202410 de 03073) y línea = la AJ_HIST_AUS de AUS-02737-202411.
   Rollback: borrar las cabeceras AUS-03073-202411 y AUS-03073-202412 con su única línea.
   Después: reiniciar el servicio; la novedad 4057 de 03073 de enero se anula (el precio ya sale solo) y se recalcula enero de 03073. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @Cab nvarchar(300) = N'dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @Lin nvarchar(300) = N'dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @Col nvarchar(max), @Pro nvarchar(max), @Sql nvarchar(max);
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE No_ IN (N'AUS-03073-202411', N'AUS-03073-202412'))
BEGIN PRINT 'Ya existen las cabeceras de 03073'; ROLLBACK; RETURN; END;
IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE No_=N'LIQ-00018774' AND [No_ Empleado]=N'03073')
 OR NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_ Liquidación]=N'AUS-02737-202411' AND [Cód_ Concepto]=N'AJ_HIST_AUS')
BEGIN PRINT 'Faltan los moldes'; ROLLBACK; RETURN; END;

CREATE TABLE #d (doc nvarchar(20) COLLATE DATABASE_DEFAULT, per nvarchar(10) COLLATE DATABASE_DEFAULT, aj decimal(38,20));
INSERT #d VALUES (N'AUS-03073-202411', N'202411', 3046106.70), (N'AUS-03073-202412', N'202412', 3046106.52);

-- Cabeceras (misma proyección que el script de febrero)
SELECT @Col = STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(name)), N',') WITHIN GROUP (ORDER BY column_id),
  @Pro = STRING_AGG(CONVERT(nvarchar(max), CASE
    WHEN name=N'No_' THEN N'd.doc'
    WHEN name=N'Cód_ Período' THEN N'd.per'
    WHEN name=N'Fecha Liquidación' THEN N'CONVERT(datetime,EOMONTH(CONVERT(date,d.per+N''01'',112)))'
    WHEN name=N'Estado' THEN N'2'
    WHEN name=N'Cód_ Tipo Liq_' THEN N'N''HIST_REMUN'''
    WHEN name IN (N'No_ Proyecto',N'No_ Liq_ Origen',N'No_ Serie',N'No_ Series') THEN N'N'''''
    WHEN name IN (N'Cobertura Desde',N'Cobertura Hasta') THEN N'CONVERT(datetime,''17530101'')'
    WHEN name=N'$systemId' THEN N'NEWID()'
    WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'GETUTCDATE()'
    WHEN name IN (N'$systemCreatedBy',N'$systemModifiedBy') THEN N'CONVERT(uniqueidentifier,''00000000-0000-0000-0000-000000000000'')'
    WHEN system_type_id IN (106,108,60,122) THEN N'0'
    ELSE N'h.'+QUOTENAME(name) END), N',') WITHIN GROUP (ORDER BY column_id)
FROM sys.columns WHERE object_id=OBJECT_ID(@Cab) AND system_type_id<>189 AND is_identity=0 AND is_computed=0;
SET @Sql = N'INSERT '+@Cab+N' ('+@Col+N') SELECT '+@Pro+N' FROM '+@Cab+N' h CROSS JOIN #d d WHERE h.No_=N''LIQ-00018774'';';
EXEC sys.sp_executesql @Sql;
SELECT @@ROWCOUNT AS Cabeceras_esperado_2;

-- Líneas AJ_HIST_AUS (No_ Línea es identidad)
SELECT @Col = STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(name)), N',') WITHIN GROUP (ORDER BY column_id),
  @Pro = STRING_AGG(CONVERT(nvarchar(max), CASE
    WHEN name=N'No_ Liquidación' THEN N'd.doc'
    WHEN name=N'Cód_ Período' THEN N'd.per'
    WHEN name=N'No_ Empleado' THEN N'N''03073'''
    WHEN name=N'Importe' THEN N'd.aj'
    WHEN name=N'Fecha Liquidación' THEN N'CONVERT(datetime,EOMONTH(CONVERT(date,d.per+N''01'',112)))'
    WHEN name=N'$systemId' THEN N'NEWID()'
    WHEN name IN (N'$systemCreatedAt',N'$systemModifiedAt') THEN N'GETUTCDATE()'
    ELSE N'l.'+QUOTENAME(name) END), N',') WITHIN GROUP (ORDER BY column_id)
FROM sys.columns WHERE object_id=OBJECT_ID(@Lin) AND system_type_id<>189 AND is_identity=0 AND is_computed=0;
SET @Sql = N'INSERT '+@Lin+N' ('+@Col+N') SELECT '+@Pro+N' FROM '+@Lin+N' l CROSS JOIN #d d WHERE l.[No_ Liquidación]=N''AUS-02737-202411'' AND l.[Cód_ Concepto]=N''AJ_HIST_AUS'';';
EXEC sys.sp_executesql @Sql;
SELECT @@ROWCOUNT AS Lineas_esperado_2;

-- Control: cabecera sin vínculos económicos, una sola línea informativa por documento, importe = payload
IF EXISTS (SELECT 1 FROM #d d
   LEFT JOIN dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h ON h.No_=d.doc
   OUTER APPLY (SELECT COUNT(*) n, SUM(Importe) imp, SUM(CASE WHEN [Tipo Concepto]<>6 OR [Es Devengo]<>0 OR [Imprime en Recibo]<>0 OR [Cód_ Concepto]<>N'AJ_HIST_AUS' THEN 1 ELSE 0 END) mal
                FROM dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_ Liquidación]=d.doc) l
   WHERE h.No_ IS NULL OR h.Estado<>2 OR h.[Total Haberes]<>0 OR h.[Total Descuentos]<>0 OR h.[Neto a Pagar]<>0 OR h.[No_ Proyecto]<>N'' OR h.[No_ Empleado]<>N'03073'
      OR l.n<>1 OR l.mal<>0 OR ABS(l.imp-d.aj)>0.0001)
BEGIN PRINT 'Falló el control de las cabeceras informativas'; ROLLBACK; RETURN; END;

-- La novedad 4057 de enero de 03073 ya no hace falta: el precio sale de los doce meses completos
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET Estado=2, [No_ Liquidación]=N'', [Motivo No Aplicada]=N'', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [No_ Empleado]=N'03073' AND [Cód_ Concepto]=N'4057' AND [Cód_ Período]=N'202601' AND Estado<>2;
SELECT @@ROWCOUNT AS Novedad_4057_anulada_esperado_1;
SELECT d.doc, h.[Cód_ Tipo Liq_], h.Estado, l.[Cód_ Concepto], l.Importe FROM #d d JOIN dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h ON h.No_=d.doc
 JOIN dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l ON l.[No_ Liquidación]=d.doc;
COMMIT;
