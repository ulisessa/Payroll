/* ASIGNACIONES A LOS PROYECTOS DE PILOTAJE DE ABRIL DE 2026: SOBRABA UNA Y FALTABAN TRES. Pedido del usuario (22/10/2026); paralelo contra la corrida de pilotaje de Meta4 (TP_IMPUT 12, 21/4/2026, 40 empleados).
   Sobra: 02924, asignado a PN-802-260423 el 22/10 a las 00:25 (hora de BC) pero sin pilotaje en Meta4: no estuvo embarcado en abril (estado OR, órdenes, del 6 al 27/4 en PN-115-NOMINA). Se borra esa asignación.
   Faltan (cobraron la corrida de pilotaje de Meta4 y su marea de abril tiene el buque indicado; sus estados PI del 24 y 25/4 están en la nómina del mismo buque):
     03777  marea PP-802-000009 (buque 802)            -> PN-802-260423
     04518  marea PP-128-000062 (buque 128, A28)       -> PN-128-260424
     04906  marea PP-801-000009 (buque 801)            -> PN-801-260423
   Fechas de la asignación = las de los demás tripulantes del mismo proyecto de pilotaje (PN-128-260424: 24 al 25/4; PN-801-260423 y PN-802-260423: 23 al 25/4). Quedan 13 + 14 + 13 = 40 asignados, los mismos 40 de Meta4.
   Rollback: borrar las tres asignaciones nuevas y reinsertar la de 02924 (PN-802-260423, alta 23/4, baja 25/4, buque 802, marea 260423, sin observaciones).
   Después: reiniciar el servicio. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @P nvarchar(300) = N'dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_ Empleado] IN ('03777','04518','04906') AND [No_ Proyecto] IN ('PN-128-260424','PN-801-260423','PN-802-260423'))
BEGIN PRINT 'Ya aplicado'; ROLLBACK; RETURN; END;
DELETE FROM dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_ Empleado]='02924' AND [No_ Proyecto]='PN-802-260423';
SELECT @@ROWCOUNT AS Borradas_esperado_1;
DECLARE @cc nvarchar(max), @sql nvarchar(max);
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@P) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'No_ Empleado'));
DECLARE @alta TABLE (emp nvarchar(20), proy nvarchar(20));
INSERT @alta VALUES ('03777','PN-802-260423'),('04518','PN-128-260424'),('04906','PN-801-260423');
DECLARE @emp nvarchar(20), @proy nvarchar(20);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT emp, proy FROM @alta;
OPEN cur; FETCH NEXT FROM cur INTO @emp, @proy;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @sql = N'INSERT ' + @P + N' ([No_ Empleado],' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT TOP 1 @e,' + @cc
    + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @P + N' WHERE [No_ Proyecto]=@p ORDER BY [No_ Empleado];';
  EXEC sp_executesql @sql, N'@e nvarchar(20), @p nvarchar(20)', @e=@emp, @p=@proy;
  FETCH NEXT FROM cur INTO @emp, @proy;
END
CLOSE cur; DEALLOCATE cur;
SELECT p.[No_ Proyecto] pr, COUNT(*) asignados, MIN(CONVERT(varchar(10),p.[Fecha Alta Asignación],120)) alta, MAX(CONVERT(varchar(10),p.[Fecha Baja],120)) baja FROM dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] p WHERE p.[No_ Proyecto] IN ('PN-128-260424','PN-801-260423','PN-802-260423') GROUP BY p.[No_ Proyecto];
SELECT p.[No_ Empleado] e, p.[No_ Proyecto] pr, p.Buque, p.Marea FROM dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] p WHERE p.[No_ Empleado] IN ('03777','04518','04906','02924') AND p.[No_ Proyecto] LIKE 'PN-%2604%';
COMMIT;
