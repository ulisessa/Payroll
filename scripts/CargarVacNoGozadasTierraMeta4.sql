/* VACACIONES NO GOZADAS DE TIERRA: DÍAS DE META4 EN CORRIDAS MENSUALES (TP_IMPUT 1), febrero a julio 2026.
   Completa CargarVacNoGozadasMeta4.sql, que sólo leía corridas TP 14 (liquidación final). El personal de tierra (90xxx)
   cobra sus vacaciones no gozadas en la corrida mensual de Meta4 (TP 1): 90331 en febrero (1 día, 46.231,80 = 1.155.795 / 25),
   90308/90315 en marzo, 90362 en abril, 90406 en mayo. Sin la novedad el 3973 de su LIQ_FINAL queda en cero
   (CANT_INCIDENCIA = 0). Mismo criterio que el script original: una novedad Pendiente por corrida, no pisa existentes.
   Rollback: DELETE ... WHERE [Observaciones] = 'Vacaciones no gozadas - días de Meta4 (paralelo, tierra)'. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
SELECT h.[Año]*100+h.[Mes] per, h.[No_ Empleado] emp, CAST(h.[Fecha Imputación] AS date) fecha, v.Valor dias
INTO #n
FROM dbo.[ArbuTest$Hist_ Liq_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
JOIN dbo.[ArbuTest$Valor Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v ON v.[No_ Entrada] = h.[No_ Entrada]
JOIN dbo.[ArbuTest$Columna Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c ON c.[No_] = v.[No_ Columna]
WHERE h.[Año] = 2026 AND h.[Mes] BETWEEN 2 AND 7 AND h.[Tipo Imputación] = 1 AND c.[Nombre Columna] = 'DIAS_VAC_NO_GOZ' AND v.Valor <> 0;
SELECT COUNT(*) AS candidatas_esperado_5 FROM #n;

INSERT dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 ([Cód_ Período],[Fecha],[Cód_ Tipo Liq_],[Cód_ Convenio],[Cód_ Categoría],[No_ Empleado],[Nombre Empleado],[No_ Proyecto],[Cód_ Concepto],[Cantidad],[Unidad Cantidad],[Valor Unitario],[Importe],[Observaciones],[Estado],[No_ Liquidación],[Motivo No Aplicada],[Recurrente],[Períodos Restantes],[Novedad Origen],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT CAST(n.per AS nvarchar(10)), n.fecha, N'LIQ_FINAL', N'', N'', n.emp, LEFT(ISNULL(e.[First Name] + N' ' + e.[Last Name], N''), 100), N'', N'3973', n.dias, N'DIA', 0, 0,
       N'Vacaciones no gozadas - días de Meta4 (paralelo, tierra)', 0, N'', N'', 0, 0, 0, NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000', SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM #n n
LEFT JOIN dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e ON e.[No_] = n.emp COLLATE DATABASE_DEFAULT
WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[No_ Empleado] = n.emp COLLATE DATABASE_DEFAULT AND x.[Cód_ Período] = CAST(n.per AS nvarchar(10)) COLLATE DATABASE_DEFAULT AND x.[Cód_ Concepto] = N'3973');
SELECT @@ROWCOUNT AS insertadas;
COMMIT;
