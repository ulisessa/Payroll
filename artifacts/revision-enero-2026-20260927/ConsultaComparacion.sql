-- SQL Server. Comparación de lectura; sólo materializa tablas temporales de sesión.

SET LOCK_TIMEOUT 5000;
SELECT h.[No_] AS Liq,h.[No_ Empleado] AS Emp,h.[No_ Proyecto] AS Proyecto,h.[Cód_ Tipo Liq_] AS Tipo,h.[Cód_ Convenio] AS Convenio,h.[Cód_ Categoría] AS Categoria,h.Estado,h.[Cobertura Desde] AS Desde,h.[Cobertura Hasta] AS Hasta,h.[Total Haberes] AS Haberes,h.[Total Descuentos] AS Descuentos,h.[Neto a Pagar] AS Neto,
 SUM(CASE WHEN l.[Cód_ Concepto]='REMUNERATIVO_BRUTO' THEN l.Importe ELSE 0 END) AS Rem,
 SUM(CASE WHEN l.[Cód_ Concepto]='NO_REMUNERATIVO' THEN l.Importe ELSE 0 END) AS NoRem,
 SUM(CASE WHEN l.[Cód_ Concepto]='REMUNERATIVO_BRUTO' THEN 1 ELSE 0 END) AS NRem,
 COUNT(l.[No_ Línea]) AS Lineas,MAX(l.[$systemModifiedAt]) AS Modificado
INTO #bc
FROM dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
LEFT JOIN dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l ON l.[No_ Liquidación]=h.[No_]
WHERE h.[Fecha Liquidación]>='20260101' AND h.[Fecha Liquidación]<'20260201' AND h.[Cód_ Tipo Liq_]<>'HIST_REMUN'
GROUP BY h.[No_],h.[No_ Empleado],h.[No_ Proyecto],h.[Cód_ Tipo Liq_],h.[Cód_ Convenio],h.[Cód_ Categoría],h.Estado,h.[Cobertura Desde],h.[Cobertura Hasta],h.[Total Haberes],h.[Total Descuentos],h.[Neto a Pagar];

SELECT h.[No_ Entrada] AS Entry,h.[No_ Empleado] AS Emp,h.[Tipo Imputación] AS TP,h.[Contador Liq_] AS Contador,h.[No_ Marea Meta4] AS Marea,h.[Cód_ Buque Meta4] AS Buque,h.[Cód_ Convenio Meta4] AS Convenio,h.[Fecha Pago] AS Pago,h.[Fecha Imputación] AS Imputacion,h.[Fecha Alta Empleado] AS Alta,
MAX(CASE WHEN v.[No_ Columna]=484 THEN v.Valor END) AS BrutoAcum,
SUM(CASE WHEN v.[No_ Columna]=169 THEN v.Valor ELSE 0 END) AS Descuentos,
SUM(CASE WHEN v.[No_ Columna]=90 THEN v.Valor ELSE 0 END) AS Neto
INTO #m4
FROM dbo.[ArbuTest$Hist_ Liq_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
LEFT JOIN dbo.[ArbuTest$Valor Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v ON v.[No_ Entrada]=h.[No_ Entrada] AND v.[No_ Columna] IN(484,169,90)
WHERE h.[Año]=2026 AND h.[Mes]=1
GROUP BY h.[No_ Entrada],h.[No_ Empleado],h.[Tipo Imputación],h.[Contador Liq_],h.[No_ Marea Meta4],h.[Cód_ Buque Meta4],h.[Cód_ Convenio Meta4],h.[Fecha Pago],h.[Fecha Imputación],h.[Fecha Alta Empleado];

SELECT m.Entry,m.BrutoAcum-COALESCE(LAG(m.BrutoAcum) OVER(PARTITION BY Emp ORDER BY Contador,Entry),0) AS BrutoDelta
INTO #delta FROM #m4 m WHERE m.BrutoAcum IS NOT NULL;
SELECT b.Emp,b.Bruto AS BCBruto,b.Descuentos AS BCDesc,b.Neto AS BCNeto,b.Liquidaciones,b.NRem,b.Proyectos,b.Tipos,m.Bruto AS M4Bruto,m.Descuentos AS M4Desc,m.Neto AS M4Neto,m.Corridas,
b.Bruto-COALESCE(m.Bruto,0) AS DifBruto,b.Descuentos-COALESCE(m.Descuentos,0) AS DifDesc,b.Neto-COALESCE(m.Neto,0) AS DifNeto
INTO #cmp
FROM (SELECT Emp,SUM(Rem+NoRem) AS Bruto,SUM(Descuentos) AS Descuentos,SUM(Neto) AS Neto,COUNT(*) AS Liquidaciones,SUM(NRem) AS NRem,STRING_AGG(CONVERT(nvarchar(max),Proyecto),N'|') AS Proyectos,STRING_AGG(CONVERT(nvarchar(max),Tipo),N'|') AS Tipos FROM #bc GROUP BY Emp) b
LEFT JOIN (SELECT m.Emp,SUM(COALESCE(d.BrutoDelta,0)) AS Bruto,SUM(m.Descuentos) AS Descuentos,SUM(m.Neto) AS Neto,COUNT(*) AS Corridas FROM #m4 m LEFT JOIN #delta d ON d.Entry=m.Entry GROUP BY m.Emp) m ON m.Emp=b.Emp;
SELECT * FROM #bc ORDER BY Emp,Liq;
SELECT m.*,COALESCE(d.BrutoDelta,0) AS BrutoDelta FROM #m4 m LEFT JOIN #delta d ON d.Entry=m.Entry ORDER BY m.Emp,m.Contador,m.Entry;
SELECT * FROM #cmp ORDER BY ABS(DifNeto) DESC;
SELECT 'BC' AS Fuente,COUNT(*) AS Filas,COUNT(DISTINCT Emp) AS Empleados,SUM(Rem+NoRem) AS Bruto,SUM(Descuentos) AS Descuentos,SUM(Neto) AS Neto FROM #bc
UNION ALL SELECT 'M4',COUNT(*),COUNT(DISTINCT Emp),SUM(d.BrutoDelta),SUM(m.Descuentos),SUM(m.Neto) FROM #m4 m LEFT JOIN #delta d ON d.Entry=m.Entry
UNION ALL SELECT 'M4 empleadosBC',COUNT(*),COUNT(DISTINCT m.Emp),SUM(d.BrutoDelta),SUM(m.Descuentos),SUM(m.Neto) FROM #m4 m LEFT JOIN #delta d ON d.Entry=m.Entry WHERE EXISTS(SELECT 1 FROM #bc b WHERE b.Emp=m.Emp);
SELECT CASE WHEN ABS(DifBruto)<=0.01 THEN '0_centavo' WHEN ABS(DifBruto)<100 THEN '1_menos100' WHEN ABS(DifBruto)<10000 THEN '2_menos10000' ELSE '3_10000omas' END AS RangoBruto,COUNT(*) AS Empleados,SUM(DifBruto) AS DifBruto,SUM(DifNeto) AS DifNeto FROM #cmp GROUP BY CASE WHEN ABS(DifBruto)<=0.01 THEN '0_centavo' WHEN ABS(DifBruto)<100 THEN '1_menos100' WHEN ABS(DifBruto)<10000 THEN '2_menos10000' ELSE '3_10000omas' END;
SELECT * FROM #bc WHERE NRem<>1;
SELECT Emp,Contador,COUNT(*) AS N FROM #m4 GROUP BY Emp,Contador HAVING COUNT(*)>1;
SELECT COUNT(*) AS OcultasSoloDif FROM #cmp WHERE DifBruto=0 AND (DifDesc<>0 OR DifNeto<>0);
