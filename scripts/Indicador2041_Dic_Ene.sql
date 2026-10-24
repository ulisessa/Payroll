/* INDICADOR 2041 DE META4 (GUARDIA DE PUERTO: FACTOR 1,4 DEL 2013): NOVEDADES DE CANTIDAD 1 DE FEBRERO A JUNIO DE 2026.
   Meta4 guarda el indicador 2041 como una incidencia mensual de valor 1 por empleado (M4T_VAL_INCIDENCIA, concepto 2041, en la fecha de la liquidacion):
   54 incidencias de febrero a junio de 2026. El 2013 lleva el factor 1,4 sólo cuando el indicador vale 1; la aproximacion por TIPOACTIVIDAD
   deja de usarse. Formato de la novedad: período del mes, tipo REGULAR, concepto 2041, Cantidad 1, Valor Unitario e Importe 0, Fecha de la incidencia,
   observación 'Meta4 2041'. Se agrega el concepto informativo 2041 (sin fórmula) y la fuente de datos IND_GUARDIA_2041 (suma la Cantidad de las novedades
   2041 del empleado en el período: tabla 110038, campos 7 Empleado, 10 Concepto, 2 Período; valor 12 Cantidad).
   Rollback: borrar las novedades con observación 'Meta4 2041', la fuente IND_GUARDIA_2041 con sus filtros y el concepto 2041.
   Después: reiniciar el servicio. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
-- 1. Concepto informativo 2041 (molde NETO_GARANT)
IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'2041')
BEGIN
  SELECT * INTO #c FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'NETO_GARANT' AND [Vigencia Desde]='20260201';
  UPDATE #c SET [Código]=N'2041', [Descripción]=N'Indicador guardia de puerto (Meta4 2041)', [Nombre Impresión]=N'', [Fórmula]=N'', [Condición]=N'', [Orden Cálculo]=1, [$systemId]=NEWID();
  DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name <> 'timestamp');
  EXEC (N'INSERT dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cc + N') SELECT ' + @cc + N' FROM #c');
END
SELECT COUNT(*) AS Concepto_esperado_1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]=N'2041';

-- 2. Fuente de datos IND_GUARDIA_2041 (molde A_CUENTA_MAREA)
IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]=N'IND_GUARDIA_2041')
BEGIN
  SELECT * INTO #f FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]=N'A_CUENTA_MAREA';
  UPDATE #f SET [Nombre Variable]=N'IND_GUARDIA_2041', [Descripción]=N'Indicador de guardia de puerto de Meta4 (2041) del período', [Id_ Tabla]=110038, [No_ Campo Valor]=12, [Función Agregado]=0, [$systemId]=NEWID();
  DECLARE @cf nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name <> 'timestamp');
  EXEC (N'INSERT dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cf + N') SELECT ' + @cf + N' FROM #f');
  INSERT dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Nombre Variable],[No_ Campo],[Filtro Valor]) VALUES
   (N'IND_GUARDIA_2041', 7, N'{EMP_NO}'), (N'IND_GUARDIA_2041', 10, N'2041'), (N'IND_GUARDIA_2041', 2, N'{PERIODO}');
END
SELECT [No_ Campo], [Filtro Valor] FROM dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]=N'IND_GUARDIA_2041' ORDER BY [No_ Línea];

-- 3. Novedades
INSERT dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
 ([Cód_ Período],[Fecha],[Cód_ Tipo Liq_],[Cód_ Convenio],[Cód_ Categoría],[No_ Empleado],[Nombre Empleado],[No_ Proyecto],[Cód_ Concepto],[Cantidad],[Unidad Cantidad],[Valor Unitario],[Importe],[Observaciones],[Estado],[No_ Liquidación],[Motivo No Aplicada],[Recurrente],[Períodos Restantes],[Novedad Origen],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT LEFT(CONVERT(varchar(8), n.fecha, 112), 6), n.fecha, N'REGULAR', N'', N'', n.emp, LEFT(e.[First Name] + N' ' + e.[Last Name], 100), N'', N'2041', 1, N'', 0, 0,
       N'Meta4 2041', 0, N'', N'', 0, 0, 0, NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000', SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM (VALUES
  (N'03196', CAST('20251206' AS date)),
  (N'03455', CAST('20251206' AS date)),
  (N'04833', CAST('20251206' AS date)),
  (N'00794', CAST('20251212' AS date)),
  (N'01073', CAST('20251212' AS date)),
  (N'04121', CAST('20251212' AS date)),
  (N'04455', CAST('20251212' AS date)),
  (N'04495', CAST('20251212' AS date)),
  (N'04911', CAST('20251212' AS date)),
  (N'04526', CAST('20251224' AS date)),
  (N'04833', CAST('20251224' AS date)),
  (N'04889', CAST('20251224' AS date)),
  (N'00794', CAST('20251225' AS date)),
  (N'03325', CAST('20251225' AS date)),
  (N'03774', CAST('20251225' AS date)),
  (N'03916', CAST('20251225' AS date)),
  (N'04139', CAST('20251225' AS date)),
  (N'04190', CAST('20251225' AS date)),
  (N'04351', CAST('20251225' AS date)),
  (N'04573', CAST('20251225' AS date)),
  (N'04659', CAST('20251225' AS date)),
  (N'04726', CAST('20251225' AS date)),
  (N'04750', CAST('20251225' AS date)),
  (N'04751', CAST('20251225' AS date)),
  (N'04768', CAST('20251225' AS date)),
  (N'04775', CAST('20251225' AS date)),
  (N'04900', CAST('20251225' AS date)),
  (N'04907', CAST('20251225' AS date)),
  (N'04916', CAST('20251225' AS date)),
  (N'04918', CAST('20251225' AS date)),
  (N'04920', CAST('20251225' AS date)),
  (N'04925', CAST('20251225' AS date)),
  (N'04190', CAST('20260106' AS date)),
  (N'04775', CAST('20260106' AS date)),
  (N'04900', CAST('20260106' AS date)),
  (N'04925', CAST('20260112' AS date)),
  (N'00794', CAST('20260125' AS date)),
  (N'02792', CAST('20260125' AS date)),
  (N'03325', CAST('20260125' AS date)),
  (N'03916', CAST('20260125' AS date)),
  (N'03985', CAST('20260125' AS date)),
  (N'04096', CAST('20260125' AS date)),
  (N'04139', CAST('20260125' AS date)),
  (N'04351', CAST('20260125' AS date)),
  (N'04382', CAST('20260125' AS date)),
  (N'04573', CAST('20260125' AS date)),
  (N'04703', CAST('20260125' AS date)),
  (N'04726', CAST('20260125' AS date)),
  (N'04750', CAST('20260125' AS date)),
  (N'04751', CAST('20260125' AS date)),
  (N'04768', CAST('20260125' AS date)),
  (N'04901', CAST('20260125' AS date)),
  (N'04907', CAST('20260125' AS date)),
  (N'04920', CAST('20260125' AS date))) n(emp, fecha)
JOIN dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e ON e.[No_] = n.emp
WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[No_ Empleado] = n.emp AND x.[Cód_ Concepto] = N'2041' AND x.[Cód_ Período] = LEFT(CONVERT(varchar(8), n.fecha, 112), 6));
SELECT @@ROWCOUNT AS Novedades_insertadas;
SELECT [Cód_ Período], COUNT(*) n FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto]=N'2041' GROUP BY [Cód_ Período] ORDER BY 1;
COMMIT;
