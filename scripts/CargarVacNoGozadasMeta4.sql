/* VACACIONES NO GOZADAS: DÍAS DE META4 COMO NOVEDADES (paralelo, febrero a julio 2026).
   El 3973 de BC es promedio / 25 * CANT_INCIDENCIA y no calcula los días: salen de una novedad. Para enero
   se cargaron 8 a mano copiando DIAS_VAC_NO_GOZ de Meta4; esto hace lo mismo para febrero en adelante, con
   las corridas de liquidación final (Tipo Imputación 14) de Hist. Liq. Meta4. Una novedad por corrida,
   Pendiente, con la fecha de imputación de Meta4. No pisa las existentes (mismo empleado, período y fecha).
   Cuando termine el paralelo, los días tendrán que salir del saldo de vacaciones y esto se borra:
   DELETE ... WHERE [Observaciones] LIKE 'Vacaciones no gozadas - días de Meta4 (paralelo)%'. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @N nvarchar(300) = N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';

SELECT ROW_NUMBER() OVER (ORDER BY h.[Año], h.[Mes], h.[No_ Empleado], h.[Fecha Imputación]) rn,
       h.[Año]*100+h.[Mes] per, h.[No_ Empleado] emp, CAST(h.[Fecha Imputación] AS date) fecha, v.Valor dias
INTO #n
FROM dbo.[ArbuTest$Hist_ Liq_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
JOIN dbo.[ArbuTest$Valor Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v ON v.[No_ Entrada] = h.[No_ Entrada]
JOIN dbo.[ArbuTest$Columna Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c ON c.[No_] = v.[No_ Columna]
WHERE h.[Año] = 2026 AND h.[Mes] BETWEEN 2 AND 7 AND h.[Tipo Imputación] = 14 AND c.[Nombre Columna] = 'DIAS_VAC_NO_GOZ' AND v.Valor <> 0;

INSERT dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 ([Cód_ Período],[Fecha],[Cód_ Tipo Liq_],[Cód_ Convenio],[Cód_ Categoría],[No_ Empleado],[Nombre Empleado],[No_ Proyecto],[Cód_ Concepto],[Cantidad],[Unidad Cantidad],[Valor Unitario],[Importe],[Observaciones],[Estado],[No_ Liquidación],[Motivo No Aplicada],[Recurrente],[Períodos Restantes],[Novedad Origen],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT CAST(n.per AS nvarchar(10)), n.fecha, N'LIQ_FINAL', N'', N'', n.emp, LEFT(ISNULL(e.[First Name] + N' ' + e.[Last Name], N''), 100), N'', N'3973', n.dias, N'DIA', 0, 0,
       N'Vacaciones no gozadas - días de Meta4 (paralelo)', 0, N'', N'', 0, 0, 0, NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000', SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM #n n
LEFT JOIN dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e ON e.[No_] = n.emp COLLATE DATABASE_DEFAULT
WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[No_ Empleado] = n.emp COLLATE DATABASE_DEFAULT AND x.[Cód_ Período] = CAST(n.per AS nvarchar(10)) COLLATE DATABASE_DEFAULT AND x.[Cód_ Concepto] = N'3973' AND x.[Fecha] = n.fecha);
SELECT @@ROWCOUNT AS insertadas;

SELECT [Cód_ Período] p, COUNT(*) n, SUM(Cantidad) dias, SUM(CASE WHEN [Nombre Empleado] = N'' THEN 1 ELSE 0 END) sin_nombre FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto] = N'3973' GROUP BY [Cód_ Período] ORDER BY 1;
COMMIT;
