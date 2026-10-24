/* OTRAS CONTRIBUCIONES A PAGAR (OTR_CONTR_A_PAG de Meta4) POR SINDICATO: ASO, CON y PAT.
   Meta4 incluye en TOT_CONTRIB, además de la parte SICOSS, el concepto 9650 "Otr contr a pagar" (= C_SINDICATO,
   9272), que depende del SINDICATO del empleado (enero 2026, 151 empleados, 22,74 M):
     ASO ... 849.000 fijo por mes
     CON ... 200.000 en buques tangoneros (TIPOACTIVIDAD LAN), 1.216.900 en poteros (CAL)  [FARM_CON_NAV, 6303]
     PAT ... 1,0000% de la base total remunerativa + no remunerativa (= base de ART)       [FARMACIA_PAT, 6323]
   SOM, SSI, STI y FEC pagan porcentajes que varían dentro del sindicato y no se entienden con los datos:
   quedan sin modelar (~5,5 M).
   Se modela con el mecanismo de ejes de los parámetros, sin código nuevo:
     1. Valor Atributo SINDICATO: Sufijo Parámetro = código (ASO, CON, PAT).
     2. Parámetros CONTRIB_SIND_FIJO (ejes SINDICATO y TIPOACTIVIDAD) y PCT_CONTRIB_SIND (eje SINDICATO).
     3. Concepto 7090 (Contribución Patronal), mismo molde que el 7053: el fijo se cobra una vez por mes con
        MES_CONTRIB_SIND (lo ya liquidado del 7090 en el período).
   Rollback: borrar el concepto 7090, la variable MES_CONTRIB_SIND, los parámetros y las dos cabeceras nuevas, y vaciar
   el Sufijo Parámetro de ASO, CON y PAT.
   Después: reiniciar el servicio y recalcular. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;

-- 1. Sufijo de parámetro de los valores del atributo SINDICATO
UPDATE dbo.[ArbuTest$Valor Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
SET [Sufijo Parámetro] = [Código], [$systemModifiedAt] = SYSUTCDATETIME()
WHERE [Cód_ Tipo Atributo] = N'SINDICATO' AND [Código] IN (N'ASO', N'CON', N'PAT') AND [Sufijo Parámetro] = N'';
SELECT @@ROWCOUNT AS Sufijos_esperado_3;

-- 2a. Cabeceras de parámetro (copia de PCT_ART)
SELECT [Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],[$systemCreatedBy],[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3] INTO #pb FROM dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'PCT_ART';
UPDATE #pb SET [Código] = N'CONTRIB_SIND_FIJO', [Nombre Variable] = N'CONTRIB_SIND_FIJO', [Descripción] = N'Contribución fija mensual por sindicato (otras contribuciones a pagar)',
    [Notas] = N'Ejes: SINDICATO y TIPOACTIVIDAD. Meta4: OTR_CONTR_A_PAG / C_SINDICATO.', [Cód_ Tipo Atributo 1] = N'SINDICATO', [Cód_ Tipo Atributo 2] = N'TIPOACTIVIDAD', [$systemId] = NEWID();
INSERT dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3])
SELECT [Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],SYSUTCDATETIME(),[$systemCreatedBy],SYSUTCDATETIME(),[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3] FROM #pb
WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Código] = N'CONTRIB_SIND_FIJO');
SELECT @@ROWCOUNT AS Cabecera_fijo_esperado_1;

DELETE FROM #pb;
INSERT #pb ([Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],[$systemCreatedBy],[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3]) SELECT [Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],[$systemCreatedBy],[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3] FROM dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'PCT_ART';
UPDATE #pb SET [Código] = N'PCT_CONTRIB_SIND', [Nombre Variable] = N'PCT_CONTRIB_SIND', [Descripción] = N'Porcentaje de contribución por sindicato sobre la base total (otras contribuciones a pagar)',
    [Notas] = N'Eje: SINDICATO. Meta4: FARMACIA_PAT (PAT = 1%).', [Cód_ Tipo Atributo 1] = N'SINDICATO', [Cód_ Tipo Atributo 2] = N'', [$systemId] = NEWID();
INSERT dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3])
SELECT [Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],SYSUTCDATETIME(),[$systemCreatedBy],SYSUTCDATETIME(),[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3] FROM #pb
WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Código] = N'PCT_CONTRIB_SIND');
SELECT @@ROWCOUNT AS Cabecera_pct_esperado_1;

-- 2b. Valores (Parámetro Vigente), copia de la fila 2026 de PCT_ART
SELECT TOP 1 [$systemCreatedBy],[$systemModifiedBy] INTO #pv FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro] = N'PCT_ART' AND [Vigencia Desde] = '20260101';
DECLARE @molde TABLE(base nvarchar(30), cod nvarchar(30), s1 nvarchar(10), s2 nvarchar(10), valor decimal(38,10));
INSERT @molde VALUES (N'CONTRIB_SIND_FIJO', N'CONTRIB_SIND_FIJO_ASO',     N'ASO', N'',    849000),
                     (N'CONTRIB_SIND_FIJO', N'CONTRIB_SIND_FIJO_CON_LAN', N'CON', N'LAN', 200000),
                     (N'CONTRIB_SIND_FIJO', N'CONTRIB_SIND_FIJO_CON_CAL', N'CON', N'CAL', 1216900),
                     (N'PCT_CONTRIB_SIND',  N'PCT_CONTRIB_SIND_PAT',      N'PAT', N'',    1);
SELECT TOP 1 * INTO #molde1 FROM #pv;
DECLARE @b nvarchar(30), @c nvarchar(30), @s1 nvarchar(10), @s2 nvarchar(10), @v decimal(38,10);
DECLARE cur CURSOR FOR SELECT base, cod, s1, s2, valor FROM @molde;
OPEN cur; FETCH cur INTO @b, @c, @s1, @s2, @v;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro] = @c AND [Vigencia Desde] = '20260101')
    BEGIN
        INSERT dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
            ([Cód_ Parámetro Base],[Cód_ Parámetro],[Vigencia Desde],[Descripción],[Valor],[Moneda],[En Uso],[Notas],[No_ Empleado],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy],[Cód_ Convenio],[Cód_ Categoría],[Nivel],[Cód_ Variable TC],[Sufijo Atributo 1],[Sufijo Atributo 2],[Sufijo Atributo 3])
        SELECT @b, @c, '20260101', N'', @v, N'', 0, N'Otras contribuciones a pagar (Meta4: OTR_CONTR_A_PAG)', N'', NEWID(), SYSUTCDATETIME(), [$systemCreatedBy], SYSUTCDATETIME(), [$systemModifiedBy], N'', N'', 0, N'', @s1, @s2, N'' FROM #molde1;
    END
    FETCH cur INTO @b, @c, @s1, @s2, @v;
END
CLOSE cur; DEALLOCATE cur;
SELECT [Cód_ Parámetro], [Valor], [Sufijo Atributo 1], [Sufijo Atributo 2] FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base] IN (N'CONTRIB_SIND_FIJO', N'PCT_CONTRIB_SIND') ORDER BY 1;

-- 3. Variable del mes (copia de MES_VALOR_ART_FIJO)
SELECT * INTO #vs FROM dbo.[ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable] = N'MES_VALOR_ART_FIJO';
UPDATE #vs SET [Nombre Variable] = N'MES_CONTRIB_SIND', [Cód_ Concepto] = N'7090', [Descripción] = N'Otras contribuciones sindicales ya liquidadas en otras liquidaciones del mes', [$systemId] = NEWID();
DECLARE @cv nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name <> 'timestamp');
DECLARE @sqlv nvarchar(max) = N'INSERT dbo.[ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cv + N') SELECT ' + @cv + N' FROM #vs WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Variable Sistema Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Nombre Variable] = N''MES_CONTRIB_SIND'')';
EXEC (@sqlv);
SELECT @@ROWCOUNT AS Variable_esperado_1;

-- 4. Concepto 7090, molde del 7053
SELECT * INTO #cp FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'7053' AND [Vigencia Desde] = '20260101';
UPDATE #cp SET [Código] = N'7090', [Descripción] = N'Otras contribuciones sindicales y de farmacia', [Nombre Impresión] = N'',
    [Fórmula] = N'ROUND(IF(CONTRIB_SIND_FIJO > 0, CONTRIB_SIND_FIJO - MES_CONTRIB_SIND, 0) + PCT_CONTRIB_SIND / 100 * (BASE_SS_TRAB + BASE_SS_VAC + NO_REMUNERATIVO), PRECISION_REDONDEO)',
    [Orden Cálculo] = 939, [$systemId] = NEWID();
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name <> 'timestamp');
DECLARE @sqlc nvarchar(max) = N'INSERT dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cc + N') SELECT ' + @cc + N' FROM #cp WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Código] = N''7090'')';
EXEC (@sqlc);
SELECT @@ROWCOUNT AS Concepto_esperado_1;

SELECT [Código], [Tipo Concepto], [Orden Cálculo], [Condición], [Tipos Liq_ Aplicables], [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'7090';
COMMIT;
