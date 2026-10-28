/* 1/1: Meta4 NO suma el feriado de guardia en el devengo del último tramo de tres finales de enero que cobraban
   igual que Meta4 hasta que el 2803 empezó a sumar DIAS_FERIADOS_GUARDIA (Devengo2803Feriados.sql): 04775 y 04900
   (GP del 1 al 2) y 04925 (GP del 1 al 14). La regla de Meta4 no se entiende (el feriado sí cuenta en 83 finales con
   marea y en finales sin marea de febrero), así que se ajusta por novedad de IMPORTE con el valor de Meta4. El 2804
   (#2803 / 12) sigue solo. Pendiente mientras dura el paralelo. Rollback: borrar las novedades con la observación
   '1/1: Meta4 no suma el feriado de guardia (paralelo)'. Después: reiniciar el servicio y recalcular esas tres finales. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
INSERT dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 ([Cód_ Período],[Fecha],[Cód_ Tipo Liq_],[Cód_ Convenio],[Cód_ Categoría],[No_ Empleado],[Nombre Empleado],[No_ Proyecto],[Cód_ Concepto],[Cantidad],[Unidad Cantidad],[Valor Unitario],[Importe],[Observaciones],[Estado],[No_ Liquidación],[Motivo No Aplicada],[Recurrente],[Períodos Restantes],[Novedad Origen],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT N'202601', n.fecha, N'LIQ_FINAL', N'', N'', n.emp, LEFT(e.[First Name] + N' ' + e.[Last Name], 100), N'', N'2803', 0, N'', 0, n.importe,
       N'1/1: Meta4 no suma el feriado de guardia (paralelo)', 0, N'', N'', 0, 0, 0, NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000', SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM (VALUES (N'04775', CAST('20260108' AS date), CAST(3474295.67 AS decimal(38,2))),
             (N'04900', CAST('20260107' AS date), CAST(3132561.67 AS decimal(38,2))),
             (N'04925', CAST('20260116' AS date), CAST(1480847.33 AS decimal(38,2)))) n(emp, fecha, importe)
JOIN dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e ON e.[No_] = n.emp
WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[No_ Empleado] = n.emp AND x.[Cód_ Período] = N'202601' AND x.[Cód_ Concepto] = N'2803');
SELECT @@ROWCOUNT AS esperado_3;
SELECT [No_ Empleado], [Fecha], [Cód_ Concepto], [Importe], [Estado] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto] = N'2803' AND [Cód_ Período] = N'202601';
COMMIT;
