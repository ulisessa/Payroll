/* NOVEDADES DE LAS TRES FINALES DE MARZO 2026 (04850, 90308, 90315): FECHA DENTRO DE LA COBERTURA.
   Las indemnizaciones (3903, 3913, 3923, 3943) y la bonificación (4033) estaban cargadas con fecha 25/3 y las finales cubren
   del 1/3 al 10/3 (04850), 13/3 (90308) y 12/3 (90315): la novedad quedaba fuera de la cobertura y ninguna final la tomaba (Meta4 sí la paga: unos 59,5 M de bruto).
   Cambio: Fecha = Cobertura Hasta de la final del empleado (la fecha de baja). Sólo toca novedades Pendientes (Estado 0) sin liquidación asignada.
   Rollback: volver Fecha a 2026-03-25 en los movimientos 10590, 5546, 5278, 10929, 5544.
   Después: reiniciar el servicio (SQL directo deja la caché rancia) y recalcular las tres finales. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
UPDATE n SET n.Fecha = l.[Cobertura Hasta], n.[$systemModifiedAt] = SYSUTCDATETIME()
FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n
JOIN dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l ON l.[No_ Empleado]=n.[No_ Empleado] AND l.[Cód_ Período]=n.[Cód_ Período] AND l.[Cód_ Tipo Liq_]='LIQ_FINAL'
WHERE n.[No_ Movimiento] IN (10590,5546,5278,10929,5544) AND n.Estado=0 AND n.[No_ Liquidación]='' AND n.Fecha='20260325';
SELECT @@ROWCOUNT AS Actualizadas_esperado_5;
SELECT n.[No_ Movimiento] m,n.[No_ Empleado] e,n.[Cód_ Concepto] c,CONVERT(varchar(10),n.Fecha,120) f FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n WHERE n.[No_ Movimiento] IN (10590,5546,5278,10929,5544);
COMMIT;
