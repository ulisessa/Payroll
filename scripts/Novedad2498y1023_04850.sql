/* REEMPLAZADO por scripts/Baja2498MitadMarea.sql (regla de baja a mitad de marea): las dos novedades se borraron el 15/10/2026. */
/* 04850 (729/15, HF801): META4 LO LIQUIDA COMO CIERRE DE MAREA AL BAJARSE EN LA MAREA 8 (17 AL 27/2, ENFERMEDAD DESDE EL 28/2).
   Meta4 (cont. 5, tipo de imputacion 10): produccion 2498 de 634.800 y feriado 1023 de 96.658 (con la produccion repartida en los 11 dias de ese tramo:
   634.800 / 11 = 57.709). BC lo liquida como DEVENGADOS y no paga 2498 (38.949 de feriado). Diferencia 692.510 de bruto (634.800 + 57.709 menos 1 de redondeo).
   Es el unico de HF801 en febrero al que Meta4 le liquida produccion en el tramo de la marea 8. Hace falta una regla de relevo/baja mid-marea (que una asignacion que
   termina antes del arribo dispare un cierre); hasta decidirla, se ajusta por novedad de IMPORTE con el valor de Meta4. Pendiente mientras dura el paralelo.
   Rollback: borrar las dos novedades con la observacion '04850: Meta4 cierra su marea 8 al bajarse (paralelo)'. Despues: reiniciar el servicio y recalcular
   el devengado LIQ-00053255. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
INSERT dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 ([Cód_ Período],[Fecha],[Cód_ Tipo Liq_],[Cód_ Convenio],[Cód_ Categoría],[No_ Empleado],[Nombre Empleado],[No_ Proyecto],[Cód_ Concepto],[Cantidad],[Unidad Cantidad],[Valor Unitario],[Importe],[Observaciones],[Estado],[No_ Liquidación],[Motivo No Aplicada],[Recurrente],[Períodos Restantes],[Novedad Origen],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT N'202602', n.fecha, N'DEVENGADOS', N'', N'', n.emp, LEFT(e.[First Name] + N' ' + e.[Last Name], 100), N'', n.concepto, 0, N'', 0, n.importe,
       N'04850: Meta4 cierra su marea 8 al bajarse (paralelo)', 0, N'', N'', 0, 0, 0, NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000', SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM (VALUES (N'04850', CAST('20260227' AS date), N'2498', CAST(634800.00 AS decimal(38,2))),
             (N'04850', CAST('20260227' AS date), N'1023', CAST(96658.00 AS decimal(38,2)))) n(emp, fecha, concepto, importe)
JOIN dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e ON e.[No_] = n.emp
WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[No_ Empleado] = n.emp AND x.[Cód_ Período] = N'202602' AND x.[Cód_ Concepto] = n.concepto);
SELECT @@ROWCOUNT AS esperado_2;
SELECT [No_ Empleado], [Fecha], [Cód_ Concepto], [Importe], [Estado] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_ Empleado] = N'04850' AND [Cód_ Período] = N'202602' AND [Cód_ Concepto] IN (N'2498', N'1023');
COMMIT;
