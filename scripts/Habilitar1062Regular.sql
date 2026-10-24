/* 1062 (devengo de francos) en REGULAR. Antes: CIERRE_MAREA|LIQ_FINAL.
   Los días en GP/DQ/PI de una regular no generaban lote y el franco que sigue se quedaba sin saldo
   ("La matriz pide N días de franco y faltan M"). La rama de tierra de la fórmula
   (COEF_FRANCOS * DIAS_DEVENGA_FRANCOS_COBERTURA) ya existe. Corrige la vigencia 2026-01-01.
   Revertir: SET [Tipos Liq_ Aplicables] = 'CIERRE_MAREA|LIQ_FINAL'. Recalcular enero y febrero. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Tipos Liq_ Aplicables] = N'CIERRE_MAREA|LIQ_FINAL|REGULAR', [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [Código] = N'1062' AND [Vigencia Desde] = '20260101' AND [Tipos Liq_ Aplicables] = N'CIERRE_MAREA|LIQ_FINAL';
SELECT @@ROWCOUNT AS esperado_1;
SELECT [Código], [Tipos Liq_ Aplicables] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'1062' AND [Vigencia Desde] = '20260101';
COMMIT;
