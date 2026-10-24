/* CUOTA ALIMENTARIA DE 04848 EN MARZO DE 2026: LA NOVEDAD CAÍA FUERA DE LA COBERTURA.
   Meta4 retuvo 42.504,75 de cuota alimentaria (8893) en la corrida del 25/3. La novedad migrada (movimiento 5251) tiene Fecha 25/3, pero 04848 sólo tiene la liquidación DEVENGADOS que cubre del 27 al 31/3: la fecha queda antes de
   la cobertura y el motor no la toma (queda en Estado 0, sin liquidación). Sin ella BC descuenta 42.505 menos que Meta4 (descuentos 36.304,78 contra 78.809,54; con la novedad 78.809,53).
   Cambio: Fecha de la novedad 5251 al 31/3/2026 (dentro de la cobertura). Importe y Tipo Liq. no cambian.
   Rollback: volver la Fecha al 2026-03-25.
   Después: reiniciar el servicio y recalcular la DEVENGADOS de marzo de 04848. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Fecha]='20260331', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [No_ Movimiento]=5251 AND [No_ Empleado]='04848' AND [Cód_ Concepto]=N'8893' AND [Fecha]='20260325' AND [Estado]=0;
SELECT @@ROWCOUNT AS Actualizada_esperado_1;
COMMIT;
