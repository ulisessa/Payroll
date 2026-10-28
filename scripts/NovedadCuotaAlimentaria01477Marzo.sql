/* CUOTA ALIMENTARIA DE 01477 EN MARZO DE 2026: IGUALAR LO RETENIDO EN META4.
   La incidencia 8893 de Meta4 del 19/3 vale 3.890.693,08 (M4T_VAL_INCIDENCIA, última actualización 31/3), pero la corrida del 19/3 retuvo 4.020.709,40 (M4_ACUMULADO_RL2/RL4: CUOTA_ALIMENT / CTA_ALIM). La del 25/3 devolvió 91.740,32
   (incidencia -91.740,32, novedad 3018). Retenido neto en Meta4: 3.928.969,08. BC, con la incidencia tal cual, retiene 3.798.952,76: -130.016,32 de descuentos, que es toda la diferencia de 01477 (el resto coincide).
   El valor de la incidencia cambió después de liquidar (se editó el 31/3); lo que se descontó en la corrida fue 4.020.709,40. Siguiendo el criterio de igualar a Meta4 con una novedad, la 3017 pasa a 4.020.709,40.
   Rollback: volver el Importe de la novedad 3017 a 3.890.693,08.
   Después: recalcular el CIERRE_MAREA de marzo de 01477 (no hace falta reiniciar el servicio: la novedad se lee de la tabla en cada cálculo, pero si el valor no cambia, reiniciar). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Importe]=4020709.40, [Observaciones]=N'Meta4 8893 (corrida 19/3 retuvo 4.020.709,40; la incidencia quedó en 3.890.693,08)', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [No_ Movimiento]=3017 AND [No_ Empleado]='01477' AND [Cód_ Concepto]=N'8893' AND [Importe]=3890693.08;
SELECT @@ROWCOUNT AS Actualizada_esperado_1;
COMMIT;
