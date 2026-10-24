/* SAC DE EGRESO DE UN FA (3813): LA MEJOR REMUNERACIÓN DEL SEMESTRE NO INCLUYE LAS VACACIONES.
   90315 (FA31, LIQ_FINAL de marzo): Meta4 EGRESO_EXTRA_1 = 376.227,58 = PR_AGUINALDO 953.816,40 x DIAS_SAC 71 / 180 (U_EGRESO_PAGA_1 0,3944); BC 446.456,73 = 2.263.724,26 / 2 x 71 / 180 (-70.229 de bruto).
   La rama AD (tierra) de 3605 es max(mejor TOTAL_P_SAC_ADM de 6 meses, 3601 del mes) / 2. El 3601 "Total para SAC adm" (ID_TOTAL 60 de M4SYS_TOTALES; bit 60 de SALIDA_TOTAL de M4SYS_HIST_NORMAS) suma los
   conceptos de sueldo y adicionales (1003, 1005, 1053, 1413, 2103, 2703, 3573, 4135...) y NO incluye la vacación (3553) ni su descuento (4743) ni las ausencias (4703): 1.589.694 + 317.938,80 = 1.907.632,80 todos los meses.
   BC usaba como mejor mes BASE_SAC - 4703, y en enero 90315 cobró vacaciones: 1.907.632,80 + 2.136.548,74 - 1.780.457,28 + 4703 = 2.263.724,26 (356.091,46 de vacación neta de más).
   Cambio (datos, sin código): la variable de sistema MEJOR_REM_SAC_SEMESTRE (cálculo MEJOR_MES_ACUM_SEMESTRE) pasa a leer el acumulador BASE_AUSENTISMO (1003, 1053, 2103, 2703: el sueldo y sus adicionales, sin vacación
   ni ausencias) sin restar ningún concepto. En 90331 (febrero) y 90308 (marzo), las otras dos finales FA, BASE_AUSENTISMO es igual a BASE_SAC - 4703 mes por mes: no cambian.
   Rollback: Cód. Acumulador = BASE_SAC y Cód. Concepto = 4703 en la variable MEJOR_REM_SAC_SEMESTRE.
   Después: reiniciar el servicio y recalcular la LIQ_FINAL de marzo de 90315. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
   SET [Cód_ Acumulador]=N'BASE_AUSENTISMO', [Cód_ Concepto]=N'', [Descripción]=N'Mejor mes del semestre de BASE_AUSENTISMO (sin vacación ni ausencias), sin la liquidación en curso', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Nombre Variable]=N'MEJOR_REM_SAC_SEMESTRE' AND [Cód_ Acumulador]=N'BASE_SAC' AND [Cód_ Concepto]=N'4703';
SELECT @@ROWCOUNT AS Actualizada_esperado_1;
SELECT [Nombre Variable] v, [Cód_ Cálculo] c, [Cód_ Acumulador] a, [Cód_ Concepto] k FROM dbo.[ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]=N'MEJOR_REM_SAC_SEMESTRE';
COMMIT;
