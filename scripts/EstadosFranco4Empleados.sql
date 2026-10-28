/* ESTADOS DE FRANCO PARTIDOS EN FR + OR (22/10/2026). La comparación día por día de los estados de abril de BC contra M4T_HIST_ESTADOS_EMPL (289 empleados) dio 4 con diferencias en estados operativos: 02452, 03957, 04419 y 04933.
   En Meta4 el estado FR sigue corrido; en BC el FR estaba cortado y el resto del tramo era un OR sin proyecto, creado a mano ese día (12:03-12:27 UTC del 22/10; 20:16 del 21/10 el de 04419): no lo migró Meta4 ni lo crea ningún código.
   Eso hacía que BC pagara menos días de franco (1063): 02452 1 día contra 3 de Meta4; 04933 1 contra 7; 03957 6 contra 7; 04419 29 contra 30 días de francos, y el "sueldo a órdenes" (1073) de 02452 que Meta4 no paga.
   Estado anterior (rollback): 02452 FR 28/4-28/4 + OR (sin proyecto) 29/4-14/5; 04933 FR 24/4-24/4 + OR 25/4-6/5; 03957 FR 24/4-29/4 + OR 30/4-13/5; 04419 FR 2/4-29/4 + OR 30/4-30/4. El FR conserva su proyecto de nómina.
   Cambio: el FR toma el fin de Meta4 (02452 14/5; 04933 6/5; 03957 13/5; 04419 30/4) y se borra la fila OR sin proyecto. Después: reiniciar el servicio y recalcular la REGULAR de abril de los cuatro. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @E nvarchar(300)=N'dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @x TABLE (emp nvarchar(20), fr_ini date, fr_fin date, or_ini date, or_fin date);
INSERT @x VALUES ('02452','20260428','20260514','20260429','20260514'),('04933','20260424','20260506','20260425','20260506'),('03957','20260424','20260513','20260430','20260513'),('04419','20260402','20260430','20260430','20260430');
/* 1. se borran las OR sin proyecto del tramo partido (sólo las de hoy y ayer, nunca la OR migrada) */
DELETE e FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e JOIN @x x ON x.emp=e.[No_ Empleado] AND e.[Cód_ Estado]='OR' AND e.[Fecha Inicio]=x.or_ini AND e.[Fecha Fin]=x.or_fin AND e.[No_ Proyecto]='' AND e.[$systemCreatedAt]>='20261021';
SELECT @@ROWCOUNT AS or_borradas_esperado_4;
/* 2. el FR toma el fin de Meta4 */
UPDATE e SET e.[Fecha Fin]=x.fr_fin, e.[$systemModifiedAt]=SYSUTCDATETIME() FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e JOIN @x x ON x.emp=e.[No_ Empleado] AND e.[Cód_ Estado]='FR' AND e.[Fecha Inicio]=x.fr_ini;
SELECT @@ROWCOUNT AS fr_actualizados_esperado_4;
SELECT e.[No_ Empleado] emp,e.[Cód_ Estado] est,CONVERT(varchar(10),e.[Fecha Inicio],120) i,CONVERT(varchar(10),e.[Fecha Fin],120) f,e.[No_ Proyecto] pr FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] e WHERE e.[No_ Empleado] IN ('02452','04933','03957','04419') AND e.[Fecha Fin]>='20260401' OR (e.[No_ Empleado] IN ('02452','04933','03957','04419') AND e.[Fecha Fin]='17530101') ORDER BY 1,3;
COMMIT;
