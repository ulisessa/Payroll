/* NOVEDADES FECHA_TC DE ENERO Y FEBRERO DE 2026 PARA LOS CINCO SUELDOS EN DIVISA (90016, 90251, 90361 en USD; 90212, 90302 en EUR).
   El tipo de cambio de estos sueldos es el del día en que Meta4 CORTÓ el proceso, no el último día del mes (ver Vault/01 Arquitectura y motor/Tokens de filtro de fuentes de datos.md,
   {FECHA_TC}); la infraestructura estaba lista (concepto FECHA_TC, fuentes TC_COMPRADOR / TC_VENDEDOR con <={FECHA_TC}) pero no había ninguna novedad cargada, así que BC cotizaba al último día
   del período. Febrero: Meta4 liquidó a 1.425 (USD vendedor del 26/2), BC a 1.420 (la del 27/2): 90016 quedaba 83.642 abajo en el sueldo (neto objetivo de 9.000 USD x 5 de diferencia con el
   grossing-up) y 90251 28.750 abajo (5.750 USD x 5).
   Fechas de corte (las de la nota del código: 27/1, 26/2, 27/3): enero 27/1 (la cotización de enero ya coincidía: 1.465 del 27 al 30), febrero 26/2. Marzo (27/3) y siguientes los carga quien liquida.
   Formato: concepto FECHA_TC, período del mes, Fecha = día de cotización, tipo de liquidación en blanco (vale para todas las del empleado en el período), Cantidad e Importe 0, Estado Pendiente
   (queda Pendiente a propósito: nunca se materializa).
   Rollback: borrar las novedades con observación 'FECHA_TC corte del proceso de Meta4'.
   Después: reiniciar el servicio y recalcular febrero (y enero) de los cinco. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
INSERT dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 ([Cód_ Período],[Fecha],[Cód_ Tipo Liq_],[Cód_ Convenio],[Cód_ Categoría],[No_ Empleado],[Nombre Empleado],[No_ Proyecto],[Cód_ Concepto],[Cantidad],[Unidad Cantidad],[Valor Unitario],[Importe],[Observaciones],[Estado],[No_ Liquidación],[Motivo No Aplicada],[Recurrente],[Períodos Restantes],[Novedad Origen],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT d.per, d.fecha, N'', N'', N'', d.emp, LEFT(e.[First Name] + N' ' + e.[Last Name], 100), N'', N'FECHA_TC', 0, N'', 0, 0, N'FECHA_TC corte del proceso de Meta4', 0, N'', N'', 0, 0, 0,
       NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000', SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM (VALUES (N'202601', CAST('20260127' AS date)), (N'202602', CAST('20260226' AS date))) p(per, fecha)
CROSS JOIN (VALUES (N'90016'), (N'90251'), (N'90361'), (N'90212'), (N'90302')) m(emp)
CROSS APPLY (SELECT p.per per, p.fecha fecha, m.emp emp) d
JOIN dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e ON e.[No_] = d.emp
WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[No_ Empleado] = d.emp AND x.[Cód_ Concepto] = N'FECHA_TC' AND x.[Cód_ Período] = d.per);
SELECT @@ROWCOUNT AS Novedades_esperado_10;
SELECT [Cód_ Período], [No_ Empleado], CONVERT(varchar(10), [Fecha], 120) fecha, [Estado] FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto] = N'FECHA_TC' ORDER BY 1, 2;
COMMIT;
