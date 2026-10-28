/* ART (7050): la base de Meta4 (REM_IMPO_ART_ST) coincide con la de obra social, no con BASE_LRT (hallazgo 19).
   Corrige la vigencia 2026-01-01. Recalcular enero después. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Fórmula]=N'round((BASE_OS_TRAB + BASE_OS_VAC) * PCT_ART, PRECISION_REDONDEO)', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]='7050' AND [Vigencia Desde]='20260101';
SELECT @@ROWCOUNT AS esperado_1;
COMMIT;
