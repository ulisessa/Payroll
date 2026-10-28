/* 2803 (indemnización de francos no gozados): el devengo del último tramo que se suma en la fórmula
   usa la misma regla que el 1062 (CCT Art. 48 del 729/15 y Art. 33 del 768/19): entero con la fracción
   >= 0,5 hacia arriba, más un día por feriado a bordo en tierra (DIAS_FERIADOS_GUARDIA).
   Antes: ROUND(COEF_FRANCOS * DIAS_DEVENGA_FRANCOS_COBERTURA, PRECISION_REDONDEO) * VALOR_FRANCO_DIA
   Sin esto, al pasar el 1062 a la regla del convenio las finales de enero quedaron un día abajo
   (04190 y 04807: -53.158,67 = un día de valor) y las de febrero 2,5 días abajo (04726).
   Corrige la vigencia 2026-01-01. Recalcular las finales de enero y febrero. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Fórmula] = REPLACE([Fórmula], N'ROUND(COEF_FRANCOS * DIAS_DEVENGA_FRANCOS_COBERTURA, PRECISION_REDONDEO) * VALOR_FRANCO_DIA',
                                   N'(ROUND(COEF_FRANCOS * DIAS_DEVENGA_FRANCOS_COBERTURA, 1) + DIAS_FERIADOS_GUARDIA) * VALOR_FRANCO_DIA'),
    [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [Código] = N'2803' AND [Vigencia Desde] = '20260101'
  AND CHARINDEX(N'ROUND(COEF_FRANCOS * DIAS_DEVENGA_FRANCOS_COBERTURA, PRECISION_REDONDEO) * VALOR_FRANCO_DIA', [Fórmula]) > 0;
SELECT @@ROWCOUNT AS esperado_1;
SELECT [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'2803' AND [Vigencia Desde] = '20260101';
COMMIT;
