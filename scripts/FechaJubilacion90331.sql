/* 90331: jubilada desde el 06/01/2025 (su obra social pasó a 000000 ese día; confirmado por el usuario el 15/10/2026).
   Meta4 no le cobra 7010, 7030, 7060 ni 7070 (condición ES_JUBILADO = 0, que sale de Fecha Jubilación de la ficha):
   en enero BC se los cobraba, 132.017,08 de diferencia en contribuciones. Dato maestro, como el de 90016.
   Rollback: dejarla en 1753-01-01. Después: reiniciar el servicio y recalcular enero (y febrero). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972$ext]
SET [Fecha Jubilación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] = '20250106'
WHERE [No_] = N'90331' AND [Fecha Jubilación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] < '20000101';
SELECT @@ROWCOUNT AS esperado_1;
SELECT [No_], CONVERT(varchar(10), [Fecha Jubilación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890], 23) fj FROM dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972$ext] WHERE [No_] IN (N'90331', N'90016');
COMMIT;
