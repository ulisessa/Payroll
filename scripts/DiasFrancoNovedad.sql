/* DIAS_FRANCO: días de franco cargados a mano (la incidencia 1061 de Meta4). Concepto informativo, sin fórmula,
   condición 0 y fuera del recibo (mismo molde que FECHA_TC); la novedad nunca se materializa y suma en
   DIAS_FRANCOS_PERIODO. Se carga la de 04047: 5 días en la final de febrero (Meta4, 24/2, fecha 11/2).
   Después de aplicar: reiniciar el service tier y recalcular la final de febrero de 04047. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @C nvarchar(300) = N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@C) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @cs nvarchar(max) = (SELECT STRING_AGG(CASE c.name
        WHEN N'Código' THEN N'N''DIAS_FRANCO'''
        WHEN N'Descripción' THEN N'N''Días de franco cargados a mano (novedad)'''
        ELSE QUOTENAME(c.name) END, ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@C) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%');
DECLARE @sql nvarchar(max) = N'IF NOT EXISTS (SELECT 1 FROM ' + @C + N' WHERE [Código] = N''DIAS_FRANCO'')
INSERT ' + @C + N' (' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT ' + @cs + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000''
FROM ' + @C + N' WHERE [Código] = N''FECHA_TC'';';
EXEC (@sql);
SELECT @@ROWCOUNT AS Concepto_esperado_1;

INSERT dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 ([Cód_ Período],[Fecha],[Cód_ Tipo Liq_],[Cód_ Convenio],[Cód_ Categoría],[No_ Empleado],[Nombre Empleado],[No_ Proyecto],[Cód_ Concepto],[Cantidad],[Unidad Cantidad],[Valor Unitario],[Importe],[Observaciones],[Estado],[No_ Liquidación],[Motivo No Aplicada],[Recurrente],[Períodos Restantes],[Novedad Origen],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT N'202602', '20260211', N'LIQ_FINAL', N'', N'', N'04047', LEFT(e.[First Name] + N' ' + e.[Last Name], 100), N'', N'DIAS_FRANCO', 5, N'DIA', 0, 0, N'Días de franco - incidencia 1061 de Meta4 (paralelo)', 0, N'', N'', 0, 0, 0, NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000', SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e WHERE e.[No_] = N'04047'
  AND NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[No_ Empleado] = N'04047' AND x.[Cód_ Período] = N'202602' AND x.[Cód_ Concepto] = N'DIAS_FRANCO');
SELECT @@ROWCOUNT AS Novedad_esperado_1;
SELECT [Código],[Condición],[Imprime en Recibo],[Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'DIAS_FRANCO';
COMMIT;
