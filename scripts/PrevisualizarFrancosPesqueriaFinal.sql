SET NOCOUNT ON;
;WITH L AS (
 SELECT [No_ Liquidación],[No_ Empleado],
 SUM(CASE WHEN [Cód_ Concepto]='1063' THEN Importe ELSE 0 END) Franco,
 SUM(CASE WHEN [Cód_ Concepto]='1063' THEN Cantidad ELSE 0 END) Dias,
 MAX(CASE WHEN [Cód_ Concepto]='COEF_PESQUERIA' THEN Importe END) Coef,
 MAX(CASE WHEN [Cód_ Concepto]='BASE_PROMEDIO' THEN Importe END) Base,
 SUM(CASE WHEN [Cód_ Concepto]='3813' THEN Importe ELSE 0 END) SAC,
 SUM(CASE WHEN [Cód_ Concepto]='2803' THEN Importe ELSE 0 END) Indemnizacion
 FROM [ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 WHERE [Cód_ Período]='202601' AND [Cód_ Tipo Liq_]='LIQ_FINAL'
 GROUP BY [No_ Liquidación],[No_ Empleado]
), M AS (
 SELECT h.[No_ Empleado],SUM(CASE WHEN c.[Cód_ Concepto BC]='1063' THEN v.Valor ELSE 0 END) FrancoM4,
 SUM(CASE WHEN c.[Cód_ Concepto BC]='3554' THEN v.Valor ELSE 0 END) NRM4
 FROM [ArbuTest$Hist_ Liq_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
 JOIN [ArbuTest$Valor Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v ON v.[No_ Entrada]=h.[No_ Entrada]
 JOIN [ArbuTest$Columna Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c ON c.[No_]=v.[No_ Columna]
 WHERE h.Año=2026 AND h.Mes=1 AND h.[Tipo Imputación]=14 GROUP BY h.[No_ Empleado]
)
SELECT L.[No_ Empleado],Dias DiasAntes,Dias DiasDespues,Coef,Franco FrancoCompleto,
 CASE WHEN Coef=1 THEN Franco ELSE ROUND(Franco*Coef,4) END Nuevo1063,ROUND(Franco*(1-Coef),4) Nuevo3554,
 ROUND(Franco*Coef,2)-ROUND(M.FrancoM4,2) Diferencia1063,
 ROUND(Franco*(1-Coef),2)-ROUND(M.NRM4,2) Diferencia3554,
 Base BaseAntes,CASE WHEN Coef=1 THEN Base ELSE Base+ROUND(Franco*Coef,4)-Franco+ROUND(Franco*(1-Coef),4) END BaseDespues,
 SAC SACConservado,Indemnizacion IndemnizacionConservada
 FROM L LEFT JOIN M ON M.[No_ Empleado]=L.[No_ Empleado] ORDER BY L.[No_ Empleado];

