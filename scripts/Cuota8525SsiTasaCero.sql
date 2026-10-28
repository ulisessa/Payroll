/* CUOTA SINDICAL DE VACACIONES (8525): QUIEN ES SSI NO PAGA LA TASA DEL CONVENIO. VIGENCIA DEL 1/3/2026 (LA CREADA POR Condicion6013y8525PorBase.sql).
   02854 (SSI, 729/15): su VACACIONES de marzo descontaba el 8525 (4 %: 314.792,19) Y el aporte solidario 8563 (317.630,56, cargado por novedad para la cohorte SSI: 02854, 04913, 04914 y 04915). Meta4 descuenta una sola cosa:
   TOT_CTA_SIND = 314.792,19 en la corrida de vacaciones y 2.838,37 en la regular (el 4 % del bruto de cada una, el aporte solidario). Quedaba +255.357 de descuentos: 314.792,19 del 8525 de más y -59.435 de impuesto,
   porque el 8525 sobrante sumaba a CUOTA_SINDICAL_RET y bajaba la retención.
   Causa: el 8525 usaba IF(PCT_SINDICATO > 0, PCT_SINDICATO, PCT_CUOTA_SIND): el SSI tiene afiliación con tasa cero, y con "PCT_SINDICATO > 0" cae a la tasa del convenio (4 %). El 8522 ya lo resolvía con TIENE_SINDICATO
   (afiliación con tasa cero distinta de ausencia del atributo; ver sin-sindicato-paga-segun-convenio y febrero-2026-netos-contribuciones-aplicados).
   Cambio: en la vigencia del 1/3/2026 del 8525 (creada hoy y en uso sólo por el recálculo de 04495 y 02854), IF(PCT_SINDICATO > 0, ...) -> IF(TIENE_SINDICATO > 0, ...), igual que el 8522. Sin cambio de vigencia: es la misma del 1/3.
   Quedan con el mismo patrón el 8523 (cuota sindical SAC) y el 4754 (informativa del SAC devengado), sin caso medido: no se tocan.
   Rollback: volver a IF(PCT_SINDICATO > 0, ...) en la vigencia del 2026-03-01 del 8525.
   Después: reiniciar el servicio y recalcular la VACACIONES de marzo de 02854 (y la de 04495 por si acaso). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
   SET [Fórmula]=REPLACE([Fórmula], N'IF(PCT_SINDICATO > 0, PCT_SINDICATO, PCT_CUOTA_SIND)', N'IF(TIENE_SINDICATO > 0, PCT_SINDICATO, PCT_CUOTA_SIND)'), [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [Código]=N'8525' AND [Vigencia Desde]='20260301' AND [Fórmula] LIKE N'%IF(PCT_SINDICATO > 0, PCT_SINDICATO, PCT_CUOTA_SIND)%';
SELECT @@ROWCOUNT AS Actualizada_esperado_1;
SELECT [Código] c, CONVERT(varchar(10),[Vigencia Desde],120) d, [Fórmula] f FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'8525' AND [Vigencia Desde]='20260301';
COMMIT;
