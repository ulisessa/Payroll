/* CONTRIBUCIÓN SOLIDARIA DEL STIA (convenio 372/04): $4 por mes + 2,5% de la suma no remunerativa, más 8% si la obra
   social es ADOS Trelew (603100). Meta4 la lleva en C_SINDICATO (dentro de OTR_CONTR_A_PAG) y CNT_STIA_CHBT.
   Verificado en enero y febrero de 2026 con los 12 empleados del convenio (11 STI + 90440, que figura SSI):
     5.004 = 4 + 2,5% x 200.000 (suma no remunerativa) en 7 empleados; 21.004 = 4 + 10,5% x 200.000 en los 5 con ADOS.
   Depende del convenio, no del sindicato: SSI y STI pagan igual. Se modela sin código nuevo:
     1. Valor Atributo OBRA_SOCIAL 603100: Sufijo Parámetro = ADOS.
     2. Parámetros CONTRIB_STIA_FIJO (sin ejes) y PCT_CONTRIB_NR (eje OBRA_SOCIAL), vigentes del convenio 372/04.
        PCT_CONTRIB_NR_372/04 = 2,5 y PCT_CONTRIB_NR_ADOS_372/04 = 10,5 (2,5 + 8).
     3. Concepto 7093 (Contribución Patronal), molde del 7090, sin MES_: el fijo son $4 y la suma no remunerativa sólo viene
        en la liquidación regular.
   Rollback: borrar el concepto 7093, los dos parámetros con sus vigentes y vaciar el Sufijo de OBRA_SOCIAL 603100.
   Después: publicar (el comparador excluye el 7093), reiniciar el servicio y recalcular. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;

UPDATE dbo.[ArbuTest$Valor Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Sufijo Parámetro] = N'ADOS', [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [Cód_ Tipo Atributo] = N'OBRA_SOCIAL' AND [Código] = N'603100' AND [Sufijo Parámetro] = N'';
SELECT @@ROWCOUNT AS Sufijo_esperado_1;

SELECT [Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],[$systemCreatedBy],[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3] INTO #pb FROM dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'PCT_ART';
UPDATE #pb SET [Código] = N'CONTRIB_STIA_FIJO', [Nombre Variable] = N'CONTRIB_STIA_FIJO', [Descripción] = N'Aporte fijo mensual del STIA',
    [Notas] = N'Convenio 372/04. Meta4: C_SINDICATO.', [Cód_ Tipo Atributo 1] = N'', [Cód_ Tipo Atributo 2] = N'', [Cód_ Tipo Atributo 3] = N'', [$systemId] = NEWID();
INSERT dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3])
SELECT [Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],SYSUTCDATETIME(),[$systemCreatedBy],SYSUTCDATETIME(),[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3] FROM #pb
WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Código] = N'CONTRIB_STIA_FIJO');
SELECT @@ROWCOUNT AS Cabecera_fijo_esperado_1;

UPDATE #pb SET [Código] = N'PCT_CONTRIB_NR', [Nombre Variable] = N'PCT_CONTRIB_NR', [Descripción] = N'Contribución solidaria sobre la suma no remunerativa',
    [Notas] = N'Eje: OBRA_SOCIAL (ADOS suma 8%). Convenio 372/04. Meta4: CNT_STIA_CHBT.', [Cód_ Tipo Atributo 1] = N'OBRA_SOCIAL', [$systemId] = NEWID();
INSERT dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3])
SELECT [Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],SYSUTCDATETIME(),[$systemCreatedBy],SYSUTCDATETIME(),[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3] FROM #pb
WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Código] = N'PCT_CONTRIB_NR');
SELECT @@ROWCOUNT AS Cabecera_pct_esperado_1;

SELECT TOP 1 [$systemCreatedBy],[$systemModifiedBy] INTO #pv FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro] = N'PCT_ART' AND [Vigencia Desde] = '20260101';
DECLARE @molde TABLE(base nvarchar(30), cod nvarchar(40), s1 nvarchar(10), valor decimal(38,10));
INSERT @molde VALUES (N'CONTRIB_STIA_FIJO', N'CONTRIB_STIA_FIJO_372/04', N'', 4),
                     (N'PCT_CONTRIB_NR',    N'PCT_CONTRIB_NR_372/04',    N'', 2.5),
                     (N'PCT_CONTRIB_NR',    N'PCT_CONTRIB_NR_ADOS_372/04', N'ADOS', 10.5);
INSERT dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([Cód_ Parámetro Base],[Cód_ Parámetro],[Vigencia Desde],[Descripción],[Valor],[Moneda],[En Uso],[Notas],[No_ Empleado],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy],[Cód_ Convenio],[Cód_ Categoría],[Nivel],[Cód_ Variable TC],[Sufijo Atributo 1],[Sufijo Atributo 2],[Sufijo Atributo 3])
SELECT m.base, m.cod, '20260101', N'', m.valor, N'', 0, N'Contribución solidaria STIA (Meta4: C_SINDICATO / CNT_STIA_CHBT)', N'', NEWID(), SYSUTCDATETIME(), p.[$systemCreatedBy], SYSUTCDATETIME(), p.[$systemModifiedBy], N'372/04', N'', 1, N'', m.s1, N'', N''
FROM @molde m CROSS JOIN #pv p
WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Cód_ Parámetro] = m.cod AND x.[Vigencia Desde] = '20260101');
SELECT @@ROWCOUNT AS Vigentes_esperado_3;

SELECT * INTO #cp FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'7090' AND [Vigencia Desde] = '20260101';
UPDATE #cp SET [Código] = N'7093', [Descripción] = N'Contribución solidaria STIA', [Nombre Impresión] = N'',
    [Fórmula] = N'ROUND(CONTRIB_STIA_FIJO + PCT_CONTRIB_NR / 100 * NO_REMUNERATIVO, PRECISION_REDONDEO)', [Condición] = N'PCT_CONTRIB_NR > 0',
    [Tipos Liq_ Aplicables] = N'REGULAR|LIQ_FINAL|RELIQUIDACION', [Orden Cálculo] = 942, [$systemId] = NEWID();
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name <> 'timestamp');
DECLARE @sqlc nvarchar(max) = N'INSERT dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cc + N') SELECT ' + @cc + N' FROM #cp WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Código] = N''7093'')';
EXEC (@sqlc);
SELECT @@ROWCOUNT AS Concepto_esperado_1;
SELECT [Código], [Tipo Concepto], [Orden Cálculo], [Condición], [Tipos Liq_ Aplicables], [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'7093';
COMMIT;
