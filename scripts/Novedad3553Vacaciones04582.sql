/* VACACIONES DE 04582 EN FEBRERO DE 2026: META4 PAGA LOS 14 DIAS DEL BLOQUE, BC SOLO LOS 7 QUE EMPIEZAN EN EL MES.
   El estado AU9 de 04582 esta partido por la guardia: 2/2 al 8/2 (7 dias), 6/3 al 11/3 (6) y 2/4 (1). DIAS_VAC_INICIO cuenta los dias de los AU9 que
   EMPIEZAN en el periodo (7) y Meta4 pago los 14 de una vez el 3553 de febrero (6.111.053 = 65.475.571,16 / 6 / 25 x 14) y nada en marzo ni abril.
   Se ajusta por novedad de IMPORTE con el valor de Meta4. OJO: en marzo y abril BC va a volver a pagar 6 y 1 dias del mismo bloque; ahi hay que
   cargar novedad de importe cero. Pendiente mientras dura el paralelo. Rollback: borrar la novedad con la observacion
   'Vacaciones: Meta4 paga los 14 dias del bloque en febrero (paralelo)'. Despues: reiniciar el servicio y recalcular las vacaciones LIQ-00053195. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
INSERT dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 ([Cód_ Período],[Fecha],[Cód_ Tipo Liq_],[Cód_ Convenio],[Cód_ Categoría],[No_ Empleado],[Nombre Empleado],[No_ Proyecto],[Cód_ Concepto],[Cantidad],[Unidad Cantidad],[Valor Unitario],[Importe],[Observaciones],[Estado],[No_ Liquidación],[Motivo No Aplicada],[Recurrente],[Períodos Restantes],[Novedad Origen],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT N'202602', n.fecha, N'VACACIONES', N'', N'', n.emp, LEFT(e.[First Name] + N' ' + e.[Last Name], 100), N'', N'3553', 0, N'', 0, n.importe,
       N'Vacaciones: Meta4 paga los 14 dias del bloque en febrero (paralelo)', 0, N'', N'', 0, 0, 0, NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000', SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM (VALUES (N'04582', CAST('20260202' AS date), CAST(6111053.00 AS decimal(38,2)))) n(emp, fecha, importe)
JOIN dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e ON e.[No_] = n.emp
WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[No_ Empleado] = n.emp AND x.[Cód_ Período] = N'202602' AND x.[Cód_ Concepto] = N'3553');
SELECT @@ROWCOUNT AS esperado_1;
SELECT [No_ Empleado], [Fecha], [Cód_ Concepto], [Importe], [Estado] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto] = N'3553' AND [Cód_ Período] = N'202602';
COMMIT;
