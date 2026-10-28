/* DETRACCIÓN DE UN INGRESANTE EN UN MES DE 31 DÍAS, TAMBIÉN EN ENERO DE 2026 (extensión de DetraccionIngresanteDia31.sql).
   La vigencia de enero del 5802 tenía la misma fórmula que febrero y enero también tiene 31 días. Medido contra Meta4: 5 ingresantes de REGULAR/DEVENGADOS con +42,01 de contribuciones y un día de menos en la detracción
   (04486 7 días y Meta4 8; 04703 29 y 30; 04855 2 y 3; 04901 17 y 18; 04926 7 y 8). Decisión del usuario (21/10/2026): extender el arreglo a enero.
   Cambio: se edita en el lugar la fórmula de la vigencia 1/1-31/1 del 5802 (no se crea otra: ya estaba cerrada y sólo rige enero), con el mismo "+ IF(TIPO_LIQ <> 'LIQ_FINAL' AND DIAS_MES = 31 AND DIAS_ALTA_30 > 0 AND DIAS_ALTA_30 < 30, 1, 0)".
   Rollback: sacar ese término de la fórmula de la vigencia de enero.
   Después: reiniciar el servicio y recalcular enero de 04486, 04703, 04855, 04901 y 04926 (y mirar que los demás de enero no se muevan). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Fórmula] = REPLACE([Fórmula], N'DIAS_ALTA_30, CNT_DIAS_PAGADOS', N'DIAS_ALTA_30 + IF(TIPO_LIQ <> ''LIQ_FINAL'' AND DIAS_MES = 31 AND DIAS_ALTA_30 > 0 AND DIAS_ALTA_30 < 30, 1, 0), CNT_DIAS_PAGADOS'), [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Código]=N'5802' AND [Vigencia Desde]='20260101' AND [Vigencia Hasta]='20260131' AND [Fórmula] NOT LIKE N'%DIAS_MES = 31%';
SELECT @@ROWCOUNT AS Actualizada_esperado_1;
SELECT CONVERT(varchar(10),[Vigencia Desde],120) d,CONVERT(varchar(10),[Vigencia Hasta],120) h,(LEN([Fórmula])-LEN(REPLACE([Fórmula],N'DIAS_MES = 31','')))/13 AS con_regla FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'5802' ORDER BY 1;
COMMIT;
