/* LICENCIA POR MATERNIDAD (AU3): EL DESCUENTO DE DÍAS (4135) SALE DEL ESTADO, EN BASE 30 COMO META4.
   90452, FA55: AU3 del 29/1 al 28/4. En Meta4 enero paga 2.156.000 (2.310.000 menos 2 días: 4135 = -154.000, incidencia 530 = 2) y
   febrero y marzo no pagan nada (sin liquidación). En BC el 4135 no tenía fórmula —sólo novedad— y febrero pagaba el sueldo entero (+2.310.000).
   Los 2 días de enero son el mes comercial de 30: el 29 y el 30 cuentan, el 31 no. Febrero, todo el mes en AU3: 30 días.
   Se copia la fuente DIAS_ENFERMEDAD_30 (días en base 30 de los estados de un código) para AU3 y el 4135 pasa a calcularse:
     4135 = -ROUND(#1003 / 30 * DIAS_MATERNIDAD_30, PRECISION_REDONDEO)   (condición DIAS_MATERNIDAD_30 > 0)
   Vigencia nueva 2026-02-01 (la 2026-01-01 se cierra el 31/1): enero queda con su novedad de importe de Meta4 y no se descuenta dos veces.
   Rollback: borrar la fuente DIAS_MATERNIDAD_30 con sus filtros, la fila 2026-02-01 del 4135 y reabrir la de 2026-01-01 (Vigencia Hasta = 1753-01-01).
   Después: reiniciar el servicio y recalcular la regular de febrero de 90452 (LIQ-00053494). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
-- 1. Fuente de datos DIAS_MATERNIDAD_30 (copia de DIAS_ENFERMEDAD_30 con el código AU3)
IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]=N'DIAS_MATERNIDAD_30')
BEGIN
  SELECT * INTO #f FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]=N'DIAS_ENFERMEDAD_30';
  UPDATE #f SET [Nombre Variable]=N'DIAS_MATERNIDAD_30', [Descripción]=N'Días de licencia por maternidad (AU3) del período, en base 30', [$systemId]=NEWID();
  DECLARE @cf nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name <> 'timestamp');
  EXEC (N'INSERT dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cf + N') SELECT ' + @cf + N' FROM #f');
  INSERT dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Nombre Variable],[No_ Campo],[Filtro Valor])
  SELECT N'DIAS_MATERNIDAD_30', [No_ Campo], CASE WHEN [No_ Campo]=3 THEN N'AU3' ELSE [Filtro Valor] END
  FROM dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]=N'DIAS_ENFERMEDAD_30' ORDER BY [No_ Línea];
END
SELECT [No_ Campo], [Filtro Valor] FROM dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]=N'DIAS_MATERNIDAD_30' ORDER BY [No_ Línea];

-- 2. Concepto 4135: vigencia nueva 2026-02-01
DECLARE @T nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'4135' AND [Vigencia Desde]='20260201')
BEGIN PRINT 'Ya existe la vigencia 2026-02-01 del 4135'; ROLLBACK; RETURN; END;
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
   WHEN N'Vigencia Desde' THEN N'''20260201'''
   WHEN N'Vigencia Hasta' THEN N'''17530101'''
   WHEN N'Fórmula' THEN N'N''-ROUND(#1003 / 30 * DIAS_MATERNIDAD_30, PRECISION_REDONDEO)'''
   WHEN N'Condición' THEN N'N''DIAS_MATERNIDAD_30 > 0'''
   ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@T) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'INSERT ' + @T + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @T + N' WHERE [Código]=N''4135'' AND [Vigencia Desde]=''20260101'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Insertada_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='20260131', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Código]=N'4135' AND [Vigencia Desde]='20260101' AND [Vigencia Hasta]='17530101';
SELECT @@ROWCOUNT AS Cerrada_esperado_1;
SELECT [Vigencia Desde],[Vigencia Hasta],[Tipo Concepto],[Orden Cálculo],[Condición],[Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'4135' ORDER BY 1;
COMMIT;
