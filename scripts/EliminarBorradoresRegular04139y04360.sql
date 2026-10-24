/* ELIMINAR LAS REGULARES EN BORRADOR DE MARZO DE 04139 Y 04360 (LIQ-00059432 Y LIQ-00059411).
   Se crearon el 20/10/2026 a las 00:01, cuando la DEVENGADOS de 04139 (22 al 31/3) y las VACACIONES de 04360 (2 al 31/3) ya se habían llevado todos los días de marzo: no tienen días propios y no se pueden calcular
   (error "no le queda ningún día propio"). Sin líneas, sin cobertura, en Borrador. BC ya coincide con Meta4 en los dos con las liquidaciones que existen (04360: 2.824.259; 04139: 438.550 contra 1.438.551, que son
   1.000.000 de anticipo). Sólo tienen 8 filas en Registro Proceso Liq. (el fallo de cálculo), que se dejan como historial.
   Rollback: no hay (borrado de dos cabeceras vacías); se pueden volver a crear con Crear y calcular, y vuelven a quedar vacías.
   Después: reiniciar el servicio (SQL directo deja la caché rancia). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DELETE FROM dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_] IN (N'LIQ-00059432', N'LIQ-00059411') AND Estado=0 AND [Cód_ Tipo Liq_]=N'REGULAR' AND [Cód_ Período]=N'202603'
  AND NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l WHERE l.[No_ Liquidación]=[No_]);
SELECT @@ROWCOUNT AS Eliminadas_esperado_2;
COMMIT;
