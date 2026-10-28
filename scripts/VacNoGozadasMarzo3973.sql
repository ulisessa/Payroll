/* VACACIONES NO GOZADAS (3973) DE LAS FINALES DE MARZO 2026: 04854, 04803 Y 04475.
   04854 y 04803: la novedad del 3973 (3 días) estaba cargada con Fecha 23/3 y Tipo LIQ_FINAL, y las finales de los dos cubren sólo del 28/3 al 30/3 (hasta ese día las cubre el cierre de marea): la novedad no entraba
   en ninguna (Pendiente) y BC pagaba cero contra 943.252,52 del 3973 y 78.604,38 del SAC (3974) de Meta4. Se lleva la Fecha al 30/3 (la baja), dentro de la cobertura de la final.
   04475: Meta4 informó a mano el precio de vacaciones (incidencia 4056 PRE_VACACIONES = 154.173,92 por día, cargada el 11/3) y pagó 15 días = 2.312.608,80; BC valoriza con el promedio (125.909 por día,
   1.888.630). Se carga el importe de Meta4 en la novedad (importe 2.312.608,80, cantidad 0: reemplaza a la fórmula); el SAC (3974) sigue por fórmula (2.312.608,80 / 12 = 192.717,40).
   Rollback: 04854/04803: volver la Fecha a 2026-03-23; 04475: volver la novedad a Cantidad 15 / Importe 0.
   Después: reiniciar el servicio y recalcular las finales de marzo de los tres. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET Fecha='20260330', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Cód_ Concepto]=N'3973' AND [Cód_ Período]=N'202603' AND [No_ Empleado] IN (N'04854',N'04803') AND Estado=0 AND Fecha='20260323';
SELECT @@ROWCOUNT AS Novedades_04854_04803_esperado_2;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET Cantidad=0, Importe=2312608.80, Estado=0, [No_ Liquidación]='', [Motivo No Aplicada]='',
   Observaciones=N'Meta4 marzo 2026: 15 días a 154.173,92 (precio informado, incidencia 4056) = 2.312.608,80', [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [Cód_ Concepto]=N'3973' AND [Cód_ Período]=N'202603' AND [No_ Empleado]=N'04475' AND Cantidad=15;
SELECT @@ROWCOUNT AS Novedad_04475_esperado_1;
COMMIT;
-- 04573 (20/10/2026): la novedad 3973 pagaba 10 días con la base de BC: 1.021.182 contra 1.038.230,45 de Meta4. La diferencia (17.048) es la corrida de octubre de 2025 (tipo 14, sin base fiscal, 255.722,37)
-- que el promedio de Meta4 incluye en marzo y la historia de BC deja afuera (ver vacaciones-marzo-base-octubre-y-precio-informado). Se cargó el importe de Meta4 en la novedad (Cantidad 0 / Importe 1038230,45).
-- 04573 (20/10/2026, 2): con la historia reconstruida (scripts/BasePromedioHistoricaReconstruccion.sql) la fórmula incluye la corrida de octubre y da 1.038.230,45: la novedad vuelve a ser de 10 días (Cantidad 10 / Importe 0).
