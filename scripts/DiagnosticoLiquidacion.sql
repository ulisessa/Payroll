/*
    DIAGNÓSTICO DE UNA LIQUIDACIÓN — de dónde sale cada peso

    Para comparar contra el recibo cuando el total no cierra. Sólo LEE, no modifica nada.

    Ajustar @Nombre (y opcionalmente @Periodo) abajo y ejecutar entero.

    Los nombres de tabla se descubren en sys.tables: dependen del GUID de la extensión, y BC
    convierte el punto final del nombre AL en "_" ("Liq." -> "Liq_").
*/

USE [Migr2013R2];
GO
SET NOCOUNT ON;
GO

DECLARE @Empresa sysname       = N'ArbuTest';
DECLARE @Nombre  nvarchar(100) = N'%Re%';        -- fragmento del nombre del empleado
DECLARE @Periodo nvarchar(20)  = N'%';           -- p.ej. N'%2026-01%'; '%' = todos
DECLARE @NoEmpleado nvarchar(20) = N'%';       -- alternativa al nombre: los de grossing-up son 90016, 90212, 90302, 90361

DECLARE @TLiq sysname, @TLin sysname, @TDet sysname, @sql nvarchar(max);

-- "_" es comodín de un carácter: cubre tanto "Liquidación" como "Liquidacion".
SELECT @TLiq = QUOTENAME(name) FROM sys.tables WHERE name LIKE @Empresa + N'$Liquidaci_n$%';
SELECT @TLin = QUOTENAME(name) FROM sys.tables WHERE name LIKE @Empresa + N'$L_nea Liquidaci_n$%';
SELECT @TDet = QUOTENAME(name) FROM sys.tables WHERE name LIKE @Empresa + N'$Detalle Variable L_nea Liq%';

SELECT @TLiq AS TablaLiquidacion, @TLin AS TablaLineas, @TDet AS TablaDetalle;

IF @TLiq IS NULL OR @TLin IS NULL OR @TDet IS NULL
BEGIN
    SELECT name AS TablasCandidatas FROM sys.tables WHERE name LIKE N'%iquidaci%';
    RAISERROR(N'No se encontraron las tablas. Revisar la variable Empresa contra la lista de arriba.',16,1);
    RETURN;
END;

-------------------------------------------------------------------------------
-- 1. Cabeceras. El total de la cabecera se compara contra la suma de las líneas:
--    si no coinciden, la cabecera quedó desactualizada y el problema es otro.
-------------------------------------------------------------------------------
SET @sql = N'
SELECT h.[No_], h.[Nombre Empleado], h.[Cód_ Período], h.[Cód_ Tipo Liq_],
       h.[Fecha Liquidación], h.[Cobertura Desde], h.[Cobertura Hasta],
       h.[Total Haberes]      AS HaberesCabecera,
       (SELECT ISNULL(SUM(l.[Importe]),0) FROM [dbo].' + @TLin + N' l
         WHERE l.[No_ Liquidación] = h.[No_] AND l.[Tipo Concepto] IN (0,1))
                              AS HaberesSumaLineas,
       h.[Total Descuentos], h.[Neto a Pagar]
FROM [dbo].' + @TLiq + N' h
WHERE h.[Nombre Empleado] LIKE @n AND h.[No_ Empleado] LIKE @e AND h.[Cód_ Período] LIKE @p
ORDER BY h.[Cód_ Período], h.[No_];';
EXEC sp_executesql @sql, N'@n nvarchar(100), @e nvarchar(20), @p nvarchar(20)', @Nombre, @NoEmpleado, @Periodo;

-------------------------------------------------------------------------------
-- 2. Subtotal por tipo de concepto.
-------------------------------------------------------------------------------
SET @sql = N'
SELECT h.[No_], h.[Cód_ Período],
       CASE l.[Tipo Concepto] WHEN 0 THEN ''0 Haber Remunerativo''
                              WHEN 1 THEN ''1 Haber No Remunerativo''
                              WHEN 2 THEN ''2 Descuento Empleado''
                              WHEN 3 THEN ''3 Contribución Patronal''
                              WHEN 4 THEN ''4 Retención''
                              WHEN 5 THEN ''5 Seguridad Social''
                              WHEN 6 THEN ''6 Informativo''
                              ELSE CAST(l.[Tipo Concepto] AS nvarchar(10)) END AS Tipo,
       COUNT(*) AS Lineas, SUM(l.[Importe]) AS Importe
FROM [dbo].' + @TLiq + N' h
JOIN [dbo].' + @TLin + N' l ON l.[No_ Liquidación] = h.[No_]
WHERE h.[Nombre Empleado] LIKE @n AND h.[No_ Empleado] LIKE @e AND h.[Cód_ Período] LIKE @p
GROUP BY h.[No_], h.[Cód_ Período], l.[Tipo Concepto]
ORDER BY h.[No_], Tipo;';
EXEC sp_executesql @sql, N'@n nvarchar(100), @e nvarchar(20), @p nvarchar(20)', @Nombre, @NoEmpleado, @Periodo;

-------------------------------------------------------------------------------
-- 3. El detalle: concepto por concepto, con la fórmula ya evaluada.
--    Esta es la que se compara línea a línea contra el recibo.
-------------------------------------------------------------------------------
SET @sql = N'
SELECT h.[No_], h.[Cód_ Período], l.[Orden Cálculo], l.[Cód_ Concepto],
       l.[Descripción Concepto], l.[Tipo Concepto],
       l.[Cantidad], l.[Base Cálculo], l.[Importe],
       LEFT(l.[Fórmula Evaluada], 200) AS FormulaEvaluada,
       LEFT(l.[Fórmula Aplicada], 120) AS FormulaOriginal
FROM [dbo].' + @TLiq + N' h
JOIN [dbo].' + @TLin + N' l ON l.[No_ Liquidación] = h.[No_]
WHERE h.[Nombre Empleado] LIKE @n AND h.[No_ Empleado] LIKE @e AND h.[Cód_ Período] LIKE @p
ORDER BY h.[No_], l.[Orden Cálculo], l.[No_ Línea];';
EXEC sp_executesql @sql, N'@n nvarchar(100), @e nvarchar(20), @p nvarchar(20)', @Nombre, @NoEmpleado, @Periodo;

-------------------------------------------------------------------------------
-- 4. Valor que tomó cada variable. Acá es donde se ve si una Fuente Datos trae
--    un número absurdo por leer sin filtrar.
-------------------------------------------------------------------------------
SET @sql = N'
SELECT DISTINCT h.[No_], d.[Nombre Variable], d.[Valor], LEFT(d.[Detalle],100) AS Detalle
FROM [dbo].' + @TLiq + N' h
JOIN [dbo].' + @TDet + N' d ON d.[No_ Liquidación] = h.[No_]
WHERE h.[Nombre Empleado] LIKE @n AND h.[No_ Empleado] LIKE @e AND h.[Cód_ Período] LIKE @p
ORDER BY h.[No_], d.[Nombre Variable];';
EXEC sp_executesql @sql, N'@n nvarchar(100), @e nvarchar(20), @p nvarchar(20)', @Nombre, @NoEmpleado, @Periodo;
-------------------------------------------------------------------------------
-- 5. GROSSING-UP en una sola fila. Las cuentas que tienen que cerrar:
--      NETO_GARANTIZADO = NETO_GU * (1 + DIAS_VAC_INICIO / 150)     <- fórmula del concepto NETO_GARANT
--      ES_GROSSING_UP   = 1                                          <- si es 0, el concepto 3553
--                                                                       toma la rama SIN grossing-up
--                                                                       y paga sobre los básicos
--      Neto a Pagar     = NETO_GARANTIZADO convertido a pesos        <- el objetivo al que converge
-------------------------------------------------------------------------------
SET @sql = N'
SELECT h.[No_], h.[No_ Empleado], h.[Nombre Empleado], h.[Cód_ Período],
       MAX(CASE WHEN d.[Nombre Variable] = ''ES_GROSSING_UP''   THEN d.[Valor] END) AS ES_GROSSING_UP,
       MAX(CASE WHEN d.[Nombre Variable] = ''NETO_GU''          THEN d.[Valor] END) AS NETO_GU,
       MAX(CASE WHEN d.[Nombre Variable] = ''NETO_GARANTIZADO'' THEN d.[Valor] END) AS NETO_GARANTIZADO,
       MAX(CASE WHEN d.[Nombre Variable] = ''COMPLEMENTO_GU''   THEN d.[Valor] END) AS COMPLEMENTO_GU,
       MAX(CASE WHEN d.[Nombre Variable] = ''DIAS_VAC_INICIO''  THEN d.[Valor] END) AS DIAS_VAC_INICIO,
       MAX(CASE WHEN d.[Nombre Variable] = ''DIAS_VAC''         THEN d.[Valor] END) AS DIAS_VAC,
       MAX(CASE WHEN d.[Nombre Variable] = ''DIAS_ORD_PERIODO'' THEN d.[Valor] END) AS DIAS_ORD_PERIODO,
       MAX(CASE WHEN d.[Nombre Variable] = ''TC_CERCANO''       THEN d.[Valor] END) AS TC_CERCANO,
       h.[Total Haberes], h.[Neto a Pagar]
FROM [dbo].' + @TLiq + N' h
LEFT JOIN [dbo].' + @TDet + N' d ON d.[No_ Liquidación] = h.[No_]
WHERE h.[Nombre Empleado] LIKE @n AND h.[No_ Empleado] LIKE @e AND h.[Cód_ Período] LIKE @p
GROUP BY h.[No_], h.[No_ Empleado], h.[Nombre Empleado], h.[Cód_ Período],
         h.[Total Haberes], h.[Neto a Pagar]
ORDER BY h.[No_];';
EXEC sp_executesql @sql, N'@n nvarchar(100), @e nvarchar(20), @p nvarchar(20)', @Nombre, @NoEmpleado, @Periodo;

-------------------------------------------------------------------------------
-- 6. Los conceptos de vacaciones y grossing-up, aislados.
--    3553 = Vacaciones. Su fórmula ramifica sobre ES_GROSSING_UP.
-------------------------------------------------------------------------------
SET @sql = N'
SELECT h.[No_], h.[No_ Empleado], l.[Cód_ Concepto], l.[Descripción Concepto],
       l.[Tipo Concepto], l.[Cantidad], l.[Base Cálculo], l.[Importe],
       LEFT(l.[Fórmula Evaluada], 300) AS FormulaEvaluada
FROM [dbo].' + @TLiq + N' h
JOIN [dbo].' + @TLin + N' l ON l.[No_ Liquidación] = h.[No_]
WHERE h.[Nombre Empleado] LIKE @n AND h.[No_ Empleado] LIKE @e AND h.[Cód_ Período] LIKE @p
  AND (l.[Cód_ Concepto] IN (''3553'',''NETO_GARANT'')
       OR l.[Fórmula Aplicada] LIKE ''%COMPLEMENTO_GU%''
       OR l.[Fórmula Aplicada] LIKE ''%DIAS_VAC%'')
ORDER BY h.[No_], l.[Orden Cálculo];';
EXEC sp_executesql @sql, N'@n nvarchar(100), @e nvarchar(20), @p nvarchar(20)', @Nombre, @NoEmpleado, @Periodo;

GO
