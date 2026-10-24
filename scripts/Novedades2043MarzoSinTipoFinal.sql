/* GRATIFICACIÓN POR TRABAJOS EN PUERTO (2043) DE MARZO: CINCO NOVEDADES QUE NO SE APLICABAN.
   02784, 04560, 04606, 04496 y 04164 tenían la novedad del 2043 (488.963,78 / 398.385,55 / 379.399,81 / 348.121,81 / 205.049,37) cargada con Tipo de liquidación = LIQ_FINAL, y ninguno de los
   cinco tiene final en marzo: sólo REGULAR (las bajas, si las hay, son de abril o mayo). Quedaban Pendientes y BC pagaba cero. En Meta4 son pagas del 12 y el 24/3 (tipo de imputación 15,
   paga separada), y las otras 55 novedades del 2043 de marzo entraron en la REGULAR con el tipo en blanco o REGULAR.
   Cambio: Cód. Tipo Liq. en blanco en esas cinco (la novedad vale para cualquier liquidación del empleado cuya cobertura contenga la fecha: 12/3 y 24/3, dentro de marzo).
   Rollback: volver Cód. Tipo Liq. a LIQ_FINAL en los movimientos 10565, 10731, 10747, 10788 y 10794.
   Después: reiniciar el servicio y recalcular la REGULAR de marzo de los cinco. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Cód_ Tipo Liq_] = N'', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [No_ Movimiento] IN (10565,10731,10747,10788,10794) AND [Cód_ Concepto]=N'2043' AND [Cód_ Período]=N'202603' AND [Cód_ Tipo Liq_]=N'LIQ_FINAL' AND Estado=0;
SELECT @@ROWCOUNT AS Novedades_esperado_5;
COMMIT;
