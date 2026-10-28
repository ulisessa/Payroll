/* Sólo lectura. Usa la traza de ejecución, no el acumulador final (que ya incluye el feriado).
   Contrasta la exclusión de antigüedad de francos del promedio de feriado de LIQ_FINAL.
   No exportar resultados con datos personales al vault. */
SET NOCOUNT ON;
;WITH Dias AS (
 SELECT d.[No_ Liquidación],
 MAX(CASE WHEN d.[Nombre Variable]='DIAS_FRANCOS_PERIODO' THEN d.Valor END) Francos,
 MAX(CASE WHEN d.[Nombre Variable]='DIAS_GP_PERIODO' THEN d.Valor END) GP,
 MAX(CASE WHEN d.[Nombre Variable]='DIAS_PROYECTO' THEN d.Valor END) Proyecto,
 MAX(CASE WHEN d.[Nombre Variable]='DIAS_PUERTO' THEN d.Valor END) Puerto,
 MAX(CASE WHEN d.[Nombre Variable]='DIAS_ORD_PERIODO' THEN d.Valor END) Ordinarios,
 MAX(l.Importe) Antiguedad
 FROM [ArbuTest$Detalle Variable Línea Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] d
 JOIN [ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l ON l.[No_ Liquidación]=d.[No_ Liquidación] AND l.[No_ Línea]=d.[No_ Línea]
 WHERE l.[Cód_ Período]='202601' AND l.[Cód_ Concepto]='1053'
 GROUP BY d.[No_ Liquidación]
), Feriado AS (
 SELECT l.[No_ Liquidación],l.[No_ Empleado],l.Importe Actual,l.[Cód_ Tipo Liq_] Tipo,
 MAX(CASE WHEN d.[Nombre Variable]='BASE_FERIADO' THEN d.Valor END) Base,
 MAX(CASE WHEN d.[Nombre Variable]='DIAS_MAREA' THEN d.Valor END) Marea,
 MAX(CASE WHEN d.[Nombre Variable]='DIAS_GP_PERIODO' THEN d.Valor END) GP,
 COALESCE(MAX(CASE WHEN d.[Nombre Variable]='DIAS_FERIADOS_MAREA' THEN d.Valor END),0)+COALESCE(MAX(CASE WHEN d.[Nombre Variable]='DIAS_FERIADOS_GUARDIA' THEN d.Valor END),0) Feriados
 FROM [ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
 JOIN [ArbuTest$Detalle Variable Línea Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] d ON d.[No_ Liquidación]=l.[No_ Liquidación] AND d.[No_ Línea]=l.[No_ Línea]
 WHERE l.[Cód_ Período]='202601' AND l.[Cód_ Concepto]='1023'
 GROUP BY l.[No_ Liquidación],l.[No_ Empleado],l.Importe,l.[Cód_ Tipo Liq_]
)
SELECT f.[No_ Liquidación],f.Tipo,
CAST(f.Actual AS decimal(18,4)) Actual,
CAST(p.Propuesto AS decimal(18,4)) Propuesto,
CAST(p.Propuesto-f.Actual AS decimal(18,4)) Diferencia,
CASE WHEN f.Actual=0 AND p.Propuesto<>0 THEN 'REVISAR INCIDENCIA CERO: NO REEMPLAZAR' ELSE 'Formula; requiere recalculo BC' END Control
FROM Feriado f LEFT JOIN Dias d ON d.[No_ Liquidación]=f.[No_ Liquidación]
CROSS APPLY (SELECT ROUND((f.Base-CASE WHEN f.Tipo='LIQ_FINAL' THEN COALESCE(d.Antiguedad*d.Francos/NULLIF(d.Francos+d.GP+d.Proyecto+d.Puerto+d.Ordinarios,0),0) ELSE 0 END)/COALESCE(NULLIF(f.Marea+f.GP,0),30),4)*f.Feriados Propuesto) p
WHERE ABS(p.Propuesto-f.Actual)>0.005;
