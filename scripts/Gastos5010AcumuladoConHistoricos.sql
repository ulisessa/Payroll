/* 5010 DESDE EL 1/3/2026: LOS GASTOS HISTÓRICOS (GASTOS_IG4_HIST) VUELVEN A ENTRAR.
   La vigencia del 1/3 (DeduccionGananciasAcumuladaPorMes.sql) reemplazó DEDUC_GANANCIAS por DEDUC_GANANCIAS_ACUM, pero los GAS_DOM_HIST / GAS_MED_HIST / GAS_EDU_HIST no vivían en la variable sino en el concepto virtual
   DEDUC_GANANCIAS (= GASTOS_IG4_BASE + GASTOS_IG4_HIST / (MES_ANUAL * (1 + 1/12))), que la fórmula nueva ya no lee. En marzo el 5010 dejó de deducir esos gastos (90184: +174.680; también 90454 y todo el que tenga un GAS_*_HIST).
   Cambio: en la vigencia del 1/3 (la creó el script anterior hace horas y ningún resultado conciliado depende de ella) el término acumulado pasa a
        ((MNI_ANUAL + DESP_4CAT_ANUAL) * MES_ANUAL + DEDUC_GANANCIAS_ACUM + GASTOS_IG4_HIST / (1 + 1 / 12))
   La primera aparición se divide por (1 + 1/12) y la segunda ("/ 12") suma el doceavo: el total es GASTOS_IG4_HIST, igual que con el concepto virtual. La rama LIQ_FINAL no cambia.
   Rollback: sacar "+ GASTOS_IG4_HIST / (1 + 1 / 12)" de las dos apariciones.
   Después: reiniciar el servicio y recalcular marzo (las que tienen GAS_*_HIST: 90184, 90454, ...). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @C nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'5010' AND [Vigencia Desde]='20260301' AND [Fórmula] LIKE N'%GASTOS_IG4_HIST%')
BEGIN PRINT 'Ya aplicado'; ROLLBACK; RETURN; END;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Fórmula] = REPLACE([Fórmula], N'DEDUC_GANANCIAS_ACUM)', N'DEDUC_GANANCIAS_ACUM + GASTOS_IG4_HIST / (1 + 1 / 12))'), [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Código]=N'5010' AND [Vigencia Desde]='20260301';
SELECT @@ROWCOUNT AS Actualizada_esperado_1;
SELECT (LEN([Fórmula])-LEN(REPLACE([Fórmula],N'GASTOS_IG4_HIST','')))/15 AS apariciones_esperado_2 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'5010' AND [Vigencia Desde]='20260301';
COMMIT;
