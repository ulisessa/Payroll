/* NOVEDADES DE ABRIL QUE EL PILOTAJE SE LLEVÓ POR LA FECHA (22/10/2026). Las novedades con fecha 25/4 y sin tipo ni proyecto las tomó la liquidación de PILOTAJE (su ventana, 24-25/4, cubre el 25/4); las novedades no miran
   "Tipos Liq. Aplicables". Según Meta4 (M4_ACUMULADO_RL..RL5 por TP_IMPUT), 19 son de la corrida mensual (tp1) y 6 de la de pilotaje (tp12):
     tp1  -> Tipo Liq. REGULAR : 2013 (3855 5446), 2043 (10739 10609 10654 10612 10804), 8563 (10578 10813 10756), 8850 (6212 6490 6811 6947 6979 7341 7531), 8893 (3024 5255).
     tp12 -> Tipo Liq. PILOTAJE: 2033 (4878 5128 5333 5445), 8893 (3023 5254).
   Valores anteriores: Tipo Liq. en blanco en las 25. Con tipo explícito la fecha ya no filtra (NovedadAplica, desde el 3/10).
   Rollback: Tipo Liq. en blanco. Después: reiniciar el servicio, recalcular el PILOTAJE de abril y crear/calcular el REGULAR de esos 11 empleados (01477 03664 04105 04526 04659 04677 04848 04913 04914 04915 04921). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Cód_ Tipo Liq_]='REGULAR', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [No_ Movimiento] IN (3855,5446,10739,10609,10654,10612,10804,10578,10813,10756,6212,6490,6811,6947,6979,7341,7531,3024,5255) AND [Cód_ Período]='202604' AND [Cód_ Tipo Liq_]='';
SELECT @@ROWCOUNT AS regular_esperado_19;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Cód_ Tipo Liq_]='PILOTAJE', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [No_ Movimiento] IN (4878,5128,5333,5445,3023,5254) AND [Cód_ Período]='202604' AND [Cód_ Tipo Liq_]='';
SELECT @@ROWCOUNT AS pilotaje_esperado_6;
COMMIT;
