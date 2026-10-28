/* ESTADOS DE 04495 DE MARZO 2026: DEVOLVERLOS A LOS DEL HISTORIAL DE META4.
   M4T_HIST_ESTADOS_EMPL de 04495: FR 11/12/2025 al 8/2/2026; AU9 9/2 al 1/3; FR desde el 2/3 (abierto). BC tenía además un tramo AU9 del 2/3 al 22/3 (movimiento 341595, "Meta4 AUSENTISMOS: vacaciones 02-22/03;
   pago 22 días original", cargado el 16/10/2026 para que BC reprodujera el pago de 22 días) y el franco recién desde el 23/3 (movimiento 57776). Con esos estados BC pagaba 9 días de franco en marzo
   (506.086,80) y 14 de antigüedad contra los 30 días de Meta4 (SUELDO_FRANCO 1.686.956,00 y ANTIGUEDAD 98.405,72).
   Decisión del usuario (20/10/2026): devolver los estados a los de Meta4.
   Cambio: borrar el movimiento 341595 (AU9 2/3 al 22/3) y llevar el inicio del franco (movimiento 57776) al 2/3/2026.
   Consecuencia a resolver aparte: la vacación de marzo (3553, 21 días, novedad 11603 por 1.826.164,11) ya no tiene un AU9 en marzo que la genere; la liquidación VACACIONES de marzo hay que mantenerla/crearla a mano.
   Rollback: reinsertar el movimiento 341595 (AU9, 2026-03-02 al 2026-03-22, proyecto PN-MAY-NOMINA, con esa observación) y volver el inicio del 57776 al 2026-03-23.
   Después: reiniciar el servicio y recalcular marzo de 04495. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
SELECT [No_ Mov_] mov, [Cód_ Estado] est, CONVERT(varchar(10),[Fecha Inicio],120) ini, CONVERT(varchar(10),[Fecha Fin],120) fin FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_ Empleado]=N'04495' AND [Fecha Inicio]>='20260201' ORDER BY [Fecha Inicio];
DELETE FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_ Mov_]=341595 AND [No_ Empleado]=N'04495' AND [Cód_ Estado]=N'AU9' AND [Fecha Inicio]='20260302';
SELECT @@ROWCOUNT AS Borradas_esperado_1;
UPDATE dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Fecha Inicio]='20260302', [$systemModifiedAt]=SYSUTCDATETIME() WHERE [No_ Mov_]=57776 AND [No_ Empleado]=N'04495' AND [Cód_ Estado]=N'FR' AND [Fecha Inicio]='20260323';
SELECT @@ROWCOUNT AS Actualizadas_esperado_1;
SELECT [No_ Mov_] mov, [Cód_ Estado] est, CONVERT(varchar(10),[Fecha Inicio],120) ini, CONVERT(varchar(10),[Fecha Fin],120) fin FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_ Empleado]=N'04495' AND [Fecha Inicio]>='20260201' ORDER BY [Fecha Inicio];
COMMIT;
