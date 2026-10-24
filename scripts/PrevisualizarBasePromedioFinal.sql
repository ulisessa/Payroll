SET NOCOUNT ON;
;WITH Datos AS (
 SELECT l.[No_ Liquidación],l.[No_ Empleado],l.Importe Actual,
 MAX(CASE WHEN d.[Nombre Variable]='#BASE_PROMEDIO' THEN d.Valor END) BaseActual,
 MAX(CASE WHEN d.[Nombre Variable]='BASE_SAC_SEMESTRE' THEN d.Valor END) Semestre,
 MAX(CASE WHEN d.[Nombre Variable]='#COEF_PESQUERIA' THEN d.Valor END) Coeficiente
 FROM [ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l JOIN [ArbuTest$Detalle Variable Línea Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] d ON d.[No_ Liquidación]=l.[No_ Liquidación] AND d.[No_ Línea]=l.[No_ Línea]
 WHERE l.[Cód_ Período]='202601' AND l.[Cód_ Tipo Liq_]='LIQ_FINAL' AND l.[Cód_ Concepto]='3813'
 GROUP BY l.[No_ Liquidación],l.[No_ Empleado],l.Importe
), Puerto AS (
 SELECT [No_ Liquidación],SUM(CASE WHEN [Cód_ Concepto] IN ('1013','1073','1076','1083','1053','1543','1547','1023','2043') THEN Importe ELSE 0 END) + SUM(CASE WHEN [Cód_ Concepto]='1603' THEN Importe ELSE 0 END) * SUM(CASE WHEN [Cód_ Concepto] IN ('1013','1083','1543','1053','1547','1076') THEN Importe ELSE 0 END) / COALESCE(NULLIF(SUM(CASE WHEN [Cód_ Concepto] IN ('1013','1083','1543','1053','1547','1076','1063') THEN Importe ELSE 0 END),0),1) BasePuerto FROM [ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Período]='202601' AND [Cód_ Concepto] IN ('1013','1073','1076','1083','1053','1543','1547','1023','2043','1603','1063') GROUP BY [No_ Liquidación]
), M4 AS (
 SELECT h.[No_ Empleado],SUM(v.Valor) SAC FROM [ArbuTest$Hist_ Liq_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h JOIN [ArbuTest$Valor Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v ON v.[No_ Entrada]=h.[No_ Entrada] JOIN [ArbuTest$Columna Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c ON c.[No_]=v.[No_ Columna]
 WHERE h.Año=2026 AND h.Mes=1 AND c.[Cód_ Concepto BC]='3813' GROUP BY h.[No_ Empleado]
)
SELECT d.[No_ Liquidación],d.[No_ Empleado],d.Coeficiente,d.BaseActual,
 a.AjusteBase,d.BaseActual+a.AjusteBase BasePropuesta,d.Actual SACActual,
 ROUND((d.Semestre+d.BaseActual+a.AjusteBase)/12*d.Coeficiente,4) SACPropuesto,m.SAC Meta4,
 ROUND((d.Semestre+d.BaseActual+a.AjusteBase)/12*d.Coeficiente,2)-ROUND(m.SAC,2) DiferenciaCentavos
FROM Datos d LEFT JOIN Puerto p ON p.[No_ Liquidación]=d.[No_ Liquidación]
LEFT JOIN M4 m ON m.[No_ Empleado]=d.[No_ Empleado]
CROSS APPLY (SELECT COALESCE(p.BasePuerto,0)/NULLIF(d.Coeficiente,0)*(1-d.Coeficiente) AjusteBase) a;
SELECT [Cód_ Concepto],[Vigencia Desde],Porcentaje,[Invertir Signo] FROM [ArbuTest$Fracción Acumulador$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Acumulador]='BASE_PROMEDIO' AND [Cód_ Concepto] IN ('1083','2043','3554','1063');

