SET NOCOUNT ON;
;WITH L AS (
 SELECT [No_ Liquidación], [No_ Empleado],
 MAX(CASE WHEN [Cód_ Concepto]='BASE_SS_TRAB' THEN Importe END) SS,
 MAX(CASE WHEN [Cód_ Concepto]='BASE_OS_TRAB' THEN Importe END) OS,
 MAX(CASE WHEN [Cód_ Concepto]='BASE_SINDICAL' THEN Importe END) Sind,
 SUM(CASE WHEN [Cód_ Concepto] IN ('3813','3823') THEN Importe ELSE 0 END) Sac,
 MAX(CASE WHEN [Cód_ Concepto]='COEF_PESQUERIA' THEN Importe END) Coef,
 SUM(CASE WHEN [Cód_ Concepto]='3973' THEN Importe ELSE 0 END) Vac
 FROM [ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 WHERE [Cód_ Período]='202601' AND [Cód_ Tipo Liq_]='LIQ_FINAL' GROUP BY [No_ Liquidación],[No_ Empleado]
), D AS (
 SELECT l.[No_ Liquidación],
 MAX(CASE WHEN d.[Nombre Variable]='PERIODO_BASE_SS_TRAB' THEN d.Valor END) PrevSS,
 MAX(CASE WHEN d.[Nombre Variable]='MES_BASE_OS_TRAB' THEN d.Valor END) PrevOS,
 MAX(CASE WHEN d.[Nombre Variable]='TOPE_SIPA' THEN d.Valor END) Tope,
 MAX(CASE WHEN d.[Nombre Variable]='TOPE_SIPA_OS' THEN d.Valor END) TopeOS,
 MAX(CASE WHEN d.[Nombre Variable]='PCT_JUB' THEN d.Valor END) Jub,
 MAX(CASE WHEN d.[Nombre Variable]='PCT_19032' THEN d.Valor END) Ley,
 MAX(CASE WHEN d.[Nombre Variable]='PCT_OS' THEN d.Valor END) PctOS,
 MAX(CASE WHEN d.[Nombre Variable]='PCT_CUOTA_SIND' THEN d.Valor END) PctSind
 FROM [ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
 JOIN [ArbuTest$Detalle Variable Línea Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] d ON l.[No_ Liquidación]=d.[No_ Liquidación] AND l.[No_ Línea]=d.[No_ Línea]
 WHERE l.[Cód_ Período]='202601' AND l.[Cód_ Tipo Liq_]='LIQ_FINAL' GROUP BY l.[No_ Liquidación]
), M AS (
 SELECT h.[No_ Empleado],c.[Cód_ Concepto BC] Codigo,SUM(v.Valor) Importe
 FROM [ArbuTest$Hist_ Liq_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
 JOIN [ArbuTest$Valor Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v ON v.[No_ Entrada]=h.[No_ Entrada]
 JOIN [ArbuTest$Columna Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c ON c.[No_]=v.[No_ Columna]
 WHERE h.Año=2026 AND h.Mes=1 AND (h.[Tipo Imputación] IN (14,15) OR (h.[No_ Empleado]='90448' AND h.[Tipo Imputación]=1))
 AND c.[Nombre Columna] IN ('JUBILACION','LEY_19032','OBRA_SOCIAL','C_SINDIC_VOL','JUBILACION_SAC','LEY_19032_SAC','OBRA_SOCIAL_SAC','C_SINDICAL_SAC')
 GROUP BY h.[No_ Empleado],c.[Cód_ Concepto BC]
)
SELECT L.[No_ Empleado],x.Codigo,ROUND(x.Propuesta,2) Propuesta,ROUND(COALESCE(M.Importe,0),2) Meta4,
 ROUND(x.Propuesta,2)-ROUND(COALESCE(M.Importe,0),2) Diferencia
FROM L JOIN D ON D.[No_ Liquidación]=L.[No_ Liquidación]
JOIN [ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h ON h.[No_]=L.[No_ Liquidación]
CROSS APPLY(SELECT CASE WHEN L.[No_ Empleado]='90448' THEN ROUND(L.Vac*0.1,4) ELSE 0 END Adicional,
 CASE WHEN L.Coef<1 THEN ROUND(ROUND(L.Sac,2)/NULLIF(L.Coef,0)*(1-L.Coef),2) ELSE 0 END SacNR,
 DATEDIFF(day,h.[Cobertura Desde],h.[Cobertura Hasta])+1 Dias,
 ROUND(L.Sac + CASE WHEN L.[No_ Empleado]='90448' THEN ROUND(L.Vac*0.1,4)*(DATEDIFF(day,h.[Cobertura Desde],h.[Cobertura Hasta])+1)/30/12 ELSE 0 END,4) SacNuevo) a
CROSS APPLY(SELECT COALESCE(D.PrevSS,0) PrevSS,COALESCE(D.PrevOS,0) PrevOS,
 CASE WHEN L.SS-L.Sac+a.Adicional+COALESCE(D.PrevSS,0) < D.Tope*a.Dias/30 THEN L.SS-L.Sac+a.Adicional+COALESCE(D.PrevSS,0) ELSE D.Tope*a.Dias/30 END BaseSS,
 CASE WHEN L.OS-L.Sac+a.Adicional+a.SacNR+COALESCE(D.PrevOS,0) < D.TopeOS*a.Dias/30 THEN L.OS-L.Sac+a.Adicional+a.SacNR+COALESCE(D.PrevOS,0) ELSE D.TopeOS*a.Dias/30 END BaseOS) b
CROSS APPLY(SELECT CASE WHEN b.BaseSS/12<a.SacNuevo THEN b.BaseSS/12 ELSE a.SacNuevo END BaseSac) s
CROSS APPLY(VALUES
 ('6000',(b.BaseSS-CASE WHEN b.PrevSS<D.Tope THEN b.PrevSS ELSE D.Tope END)*D.Jub/100),
 ('6010',(b.BaseSS-CASE WHEN b.PrevSS<D.Tope THEN b.PrevSS ELSE D.Tope END)*D.Ley/100),
 ('6030',(b.BaseOS-CASE WHEN b.PrevOS<D.TopeOS THEN b.PrevOS ELSE D.TopeOS END)*D.PctOS/100),
 ('8522',(L.Sind-L.Sac+a.Adicional+a.SacNR)*D.PctSind/100),
 ('6002',s.BaseSac*D.Jub/100),('6012',s.BaseSac*D.Ley/100),('6034',s.BaseSac*D.PctOS/100),('8523',a.SacNuevo*D.PctSind/100)
) x(Codigo,Propuesta)
LEFT JOIN M ON M.[No_ Empleado]=L.[No_ Empleado] AND M.Codigo=x.Codigo
ORDER BY L.[No_ Empleado],x.Codigo;

