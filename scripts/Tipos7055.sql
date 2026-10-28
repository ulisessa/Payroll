/* 7055 (tarea diferencial): Tipos Liq. Aplicables vacío = no corre en VACACIONES (tipo con
   "Sólo Conceptos Declarados"). Se le pone la misma lista que al 7050. Vigencia 2026-01-01. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE c SET c.[Tipos Liq_ Aplicables] = s.[Tipos Liq_ Aplicables], c.[$systemModifiedAt] = SYSUTCDATETIME()
FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
JOIN dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] s ON s.[Código] = N'7050' AND s.[Vigencia Desde] = '20260101'
WHERE c.[Código] = N'7055' AND c.[Vigencia Desde] = '20260101';
SELECT @@ROWCOUNT AS esperado_1;
SELECT [Código], [Tipos Liq_ Aplicables] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN (N'7050', N'7055') AND [Vigencia Desde] = '20260101';
COMMIT;
