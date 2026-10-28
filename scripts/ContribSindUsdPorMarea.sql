/* ACCIÓN SOCIAL Y CAPACITACIÓN POR MAREA (SOM y SSI del convenio 729/15): USD 40 por cierre de marea.
   Meta4 (enero 2026, 78 cierres): OTR_CONTR_A_PAG = 40 USD x TC de la marea (56.200 con 1.405, 56.600 con 1.415); dentro van
   CAPACIT_SOMU y PR_ACSOC_SOMU, 7,50 USD cada uno. La planilla CONTRIBUCIONES EMPRESA.xlsx dice 7,50 + 7,50; se sigue a Meta4
   mientras dure el paralelo. SSI (sin sindicato) paga lo del sindicato que corresponde al convenio: en 729/15 paga como SOM.
   Se modela con ejes, sin código nuevo:
     1. Valor Atributo SINDICATO: Sufijo Parámetro = código en SOM y SSI.
     2. Parámetro CONTRIB_SIND_USD (eje SINDICATO) con una vigencia por sindicato en el convenio 729/15, Moneda USD.
     3. Concepto 7092 (Contribución Patronal, sólo CIERRE_MAREA), molde del 7090. Los vigentes llevan Cód. Variable TC = TC_COMPRADOR: el motor convierte los USD a pesos y la fórmula NO vuelve a multiplicar (primero salió 56.600 x 1.415).
   Rollback: borrar el concepto 7092, el parámetro y sus dos vigentes, y vaciar el Sufijo de SOM y SSI.
   Después: publicar (el comparador excluye el 7092), reiniciar el servicio y recalcular. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;

UPDATE dbo.[ArbuTest$Valor Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Sufijo Parámetro] = [Código], [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [Cód_ Tipo Atributo] = N'SINDICATO' AND [Código] IN (N'SOM', N'SSI') AND [Sufijo Parámetro] = N'';
SELECT @@ROWCOUNT AS Sufijos_esperado_2;

SELECT [Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],[$systemCreatedBy],[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3] INTO #pb FROM dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'PCT_ART';
UPDATE #pb SET [Código] = N'CONTRIB_SIND_USD', [Nombre Variable] = N'CONTRIB_SIND_USD', [Descripción] = N'Acción social y capacitación por cierre de marea, en USD',
    [Notas] = N'Eje: SINDICATO; una vigencia por convenio. Meta4: OTR_CONTR_A_PAG en cierres de marea (SOM y SSI en 729/15).', [Cód_ Tipo Atributo 1] = N'SINDICATO', [Cód_ Tipo Atributo 2] = N'', [Cód_ Tipo Atributo 3] = N'', [$systemId] = NEWID();
INSERT dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3])
SELECT [Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],SYSUTCDATETIME(),[$systemCreatedBy],SYSUTCDATETIME(),[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3] FROM #pb
WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Código] = N'CONTRIB_SIND_USD');
SELECT @@ROWCOUNT AS Cabecera_esperado_1;

SELECT TOP 1 [$systemCreatedBy],[$systemModifiedBy] INTO #pv FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro] = N'PCT_ART' AND [Vigencia Desde] = '20260101';
DECLARE @molde TABLE(cod nvarchar(40), s1 nvarchar(10));
INSERT @molde VALUES (N'CONTRIB_SIND_USD_SOM_729/15', N'SOM'), (N'CONTRIB_SIND_USD_SSI_729/15', N'SSI');
INSERT dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([Cód_ Parámetro Base],[Cód_ Parámetro],[Vigencia Desde],[Descripción],[Valor],[Moneda],[En Uso],[Notas],[No_ Empleado],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy],[Cód_ Convenio],[Cód_ Categoría],[Nivel],[Cód_ Variable TC],[Sufijo Atributo 1],[Sufijo Atributo 2],[Sufijo Atributo 3])
SELECT N'CONTRIB_SIND_USD', m.cod, '20260101', N'', 40, N'USD', 0, N'Meta4: 40 USD x TC de la marea en el cierre', N'', NEWID(), SYSUTCDATETIME(), p.[$systemCreatedBy], SYSUTCDATETIME(), p.[$systemModifiedBy], N'729/15', N'', 1, N'', m.s1, N'', N''
FROM @molde m CROSS JOIN #pv p
WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Cód_ Parámetro] = m.cod AND x.[Vigencia Desde] = '20260101');
SELECT @@ROWCOUNT AS Vigentes_esperado_2;

SELECT * INTO #cp FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'7090' AND [Vigencia Desde] = '20260101';
UPDATE #cp SET [Código] = N'7092', [Descripción] = N'Acción social y capacitación por marea', [Nombre Impresión] = N'',
    [Fórmula] = N'ROUND(CONTRIB_SIND_USD, PRECISION_REDONDEO)', [Condición] = N'CONTRIB_SIND_USD > 0',
    [Tipos Liq_ Aplicables] = N'CIERRE_MAREA', [Orden Cálculo] = 941, [$systemId] = NEWID();
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name <> 'timestamp');
DECLARE @sqlc nvarchar(max) = N'INSERT dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cc + N') SELECT ' + @cc + N' FROM #cp WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Código] = N''7092'')';
EXEC (@sqlc);
SELECT @@ROWCOUNT AS Concepto_esperado_1;
SELECT [Código], [Tipo Concepto], [Orden Cálculo], [Condición], [Tipos Liq_ Aplicables], [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'7092';
COMMIT;
