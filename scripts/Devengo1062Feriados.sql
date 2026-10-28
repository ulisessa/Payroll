/* 1062 (devengo de francos) según el CCT: Art. 48 del 729/15 y Art. 33 del 768/19.
   Coeficiente por día de enrolamiento, fracción >= 0,5 hacia arriba (entero), y cada feriado nacional
   a bordo suma UN DÍA COMPLETO extra, en navegación y en puerto. Antes llevaba un "+1" fijo (que sólo
   acertaba en enero, que tuvo un feriado) y redondeaba a 4 decimales.
   Fórmula anterior:
     IF(DIAS_ENROLAMIENTO > 0, ROUND(COEF_FRANCOS * DIAS_ENROLAMIENTO + 1, PRECISION_REDONDEO),
        ROUND(COEF_FRANCOS * DIAS_DEVENGA_FRANCOS_COBERTURA, PRECISION_REDONDEO))
   Corrige la vigencia 2026-01-01. Recalcular enero y febrero. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Fórmula] = N'IF(
    DIAS_ENROLAMIENTO > 0,
    ROUND(COEF_FRANCOS * DIAS_ENROLAMIENTO, 1) + DIAS_FERIADOS_MAREA,
    ROUND(COEF_FRANCOS * DIAS_DEVENGA_FRANCOS_COBERTURA, 1) + DIAS_FERIADOS_GUARDIA
)', [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [Código] = N'1062' AND [Vigencia Desde] = '20260101';
SELECT @@ROWCOUNT AS esperado_1;
COMMIT;
