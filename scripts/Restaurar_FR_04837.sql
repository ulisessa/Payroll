/* 04837: Meta4 tiene FR del 13/02 al 07/03 (M4T_HIST_ESTADOS_EMPL), igual al saldo de 23 días. BC lo cortó
   el 13/10 a las 02:05 (AjustarEstadoFrancos, saldo todavía mal) y creó un OR sin proyecto del 15/02 al 07/03.
   Se devuelve el FR a su fin original y se borra el OR. Respaldo: respaldo-francos-20261013/estados_04837.json */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @E nvarchar(300) = N'dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DELETE FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_ Empleado] = N'04837' AND [Cód_ Estado] = N'OR' AND [Fecha Inicio] = '20260215' AND [Fecha Fin] = '20260307' AND [No_ Proyecto] = N'';
SELECT @@ROWCOUNT AS OR_borrado_esperado_1;
UPDATE dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Fecha Fin] = '20260307', [$systemModifiedAt] = SYSUTCDATETIME() WHERE [No_ Empleado] = N'04837' AND [Cód_ Estado] = N'FR' AND [Fecha Inicio] = '20260213' AND [Fecha Fin] = '20260214';
SELECT @@ROWCOUNT AS FR_esperado_1;
SELECT [Cód_ Estado], CONVERT(varchar(10),[Fecha Inicio],23) fi, CONVERT(varchar(10),[Fecha Fin],23) ff, [No_ Proyecto] FROM dbo.[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_ Empleado] = N'04837' AND [Fecha Inicio] >= '20260212' AND [Fecha Inicio] <= '20260315' ORDER BY [Fecha Inicio];
COMMIT;
