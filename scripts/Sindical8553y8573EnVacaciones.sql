/* 8553 (centro de capacitación, PAT) y 8573 (aporte solidario FTIA) en VACACIONES.
   Ambos se calculan sobre BASE_SINDICAL, pero la liquidación de Vacaciones acumula en BASE_SINDICAL_VAC (3553 -> 
   BASE_SINDICAL_VAC al 100%): ahí BASE_SINDICAL vale 0 y los dos salían en cero. Meta4 los cobra también sobre las
   vacaciones: 01591 109.382,30 y 02452 64.740,07 en el 8553 (1% de 10.938.229,95 y de 6.474.007) y 90440 14.959,68 en el
   8573 (2% de 747.983,63), exactamente las diferencias de enero. Con la suma, en las demás liquidaciones no cambia nada
   (BASE_SINDICAL_VAC vale 0 fuera de las vacaciones). Corrige la vigencia 2026-01-01.
   Fórmulas anteriores:
     8553: IF(PCT_SINDICATO = 'PAT', round(BASE_SINDICAL * PCT_CENTRO_CAPACIT / 100, PRECISION_REDONDEO), 0)
     8573: ROUND(BASE_SINDICAL * 2 / 100, PRECISION_REDONDEO)
   Después: reiniciar el servicio y recalcular las liquidaciones de Vacaciones de enero. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Fórmula] = N'IF(PCT_SINDICATO = ''PAT'', round((BASE_SINDICAL + BASE_SINDICAL_VAC) * PCT_CENTRO_CAPACIT / 100, PRECISION_REDONDEO), 0)', [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [Código] = N'8553' AND [Vigencia Desde] = '20260101' AND [Fórmula] LIKE N'IF(PCT_SINDICATO = ''PAT'', round(BASE_SINDICAL *%';
SELECT @@ROWCOUNT AS F8553_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Fórmula] = N'ROUND((BASE_SINDICAL + BASE_SINDICAL_VAC) * 2 / 100, PRECISION_REDONDEO)', [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [Código] = N'8573' AND [Vigencia Desde] = '20260101' AND [Fórmula] = N'ROUND(BASE_SINDICAL * 2 / 100, PRECISION_REDONDEO)';
SELECT @@ROWCOUNT AS F8573_esperado_1;
COMMIT;
