/* PROVINCIA DEL EMPLEADO Y APORTE 8/1000 (LEY 3270, CHUBUT).
   Meta4 liquida AP_PAT_LEY_3270 / C_CHUBUT (conceptos 6143 y 9276): 0,8% de la base SS (BASE_SS_TRAB + BASE_SS_VAC,
   sin restar la detracción) a los empleados de tierra de Chubut, no tripulantes. Va dentro de OTR_CONTR_A_PAG, o sea
   fuera de TOT_CONT_SUSS (enero 2026: 36 empleados, 1.017.160,56; febrero: 35, 1.049.225,68).
   La zona desfavorable no alcanza: 5 empleados de zona 69 trabajan en Santa Cruz y no lo pagan.
   Se modela sin código nuevo:
     1. Tipo de atributo PROVINCIA (lista, clase EMPLEADO) y su catálogo; el Sufijo Parámetro es el código.
     2. Carga: la provincia de la ficha (County) para todo empleado con liquidación 2026 (BAI = Buenos Aires,
        CFE = Capital Federal); manda la evidencia de Meta4: quien pagó C_CHUBUT en enero o febrero es CHU, y los
        cinco de zona 69 que no lo pagan (90068, 90315, 90396, 90397, 90441) son SCR.
        La ficha refleja el domicilio, no la planta: sólo es confiable para el personal de tierra.
     3. Parámetro PCT_LEY_3270 (eje PROVINCIA) con PCT_LEY_3270_CHU = 0,8 desde 1/1/2026.
     4. Concepto 7091 (Contribución Patronal), molde del 7090; los tripulantes (TIPOEMPL = 2) dan cero.
   Rollback: borrar el concepto 7091, el parámetro PCT_LEY_3270 con su vigente, las vigencias de atributo
   PROVINCIA, sus valores y el tipo.
   Después: reiniciar el servicio y recalcular. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;

DECLARE @cero uniqueidentifier = '00000000-0000-0000-0000-000000000000';

-- 1a. Tipo de atributo
IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Tipo Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'PROVINCIA')
    INSERT dbo.[ArbuTest$Tipo Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        ([Código],[Descripción],[Tipo Dato],[Tipo Entidad],[Obligatorio],[Nombre Variable],[Cód_ Clase],[Cód_ Tipo Atributo Padre],[Espejo De],[Padre Según el Valor],[Mostrar en Recibo],[Etiqueta Recibo],[Publicar Última Marea],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
    VALUES (N'PROVINCIA', N'Provincia', 2, 0, 0, N'PROVINCIA', N'EMPLEADO', N'', N'', 0, 0, N'', 0, NEWID(), SYSUTCDATETIME(), @cero, SYSUTCDATETIME(), @cero);
SELECT COUNT(*) AS Tipo_esperado_1 FROM dbo.[ArbuTest$Tipo Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'PROVINCIA';

-- 1b. Catálogo
CREATE TABLE #prov (cod nvarchar(20) COLLATE DATABASE_DEFAULT, nom nvarchar(100) COLLATE DATABASE_DEFAULT);
INSERT #prov VALUES (N'CHU', N'Chubut'), (N'SCR', N'Santa Cruz'), (N'BUE', N'Buenos Aires'), (N'CABA', N'Ciudad Autónoma de Buenos Aires'),
    (N'COR', N'Corrientes'), (N'ERI', N'Entre Ríos'), (N'MIS', N'Misiones'), (N'SFE', N'Santa Fe'), (N'MEN', N'Mendoza'),
    (N'CHA', N'Chaco'), (N'LPA', N'La Pampa'), (N'LRI', N'La Rioja'), (N'SLU', N'San Luis'), (N'CBA', N'Córdoba'),
    (N'CAT', N'Catamarca'), (N'TUC', N'Tucumán');
INSERT dbo.[ArbuTest$Valor Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([Cód_ Tipo Atributo],[Cód_ Valor Padre],[Código],[Descripción],[Valor Numérico],[Sufijo Parámetro],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT N'PROVINCIA', N'', p.cod, p.nom, 0, p.cod, NEWID(), SYSUTCDATETIME(), @cero, SYSUTCDATETIME(), @cero
FROM #prov p WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Valor Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v WHERE v.[Cód_ Tipo Atributo] = N'PROVINCIA' AND v.[Código] = p.cod);
SELECT @@ROWCOUNT AS Valores_esperado_16;

-- 2. Provincia de cada empleado con liquidación 2026
CREATE TABLE #asig (emp nvarchar(20) COLLATE DATABASE_DEFAULT, cod nvarchar(20) COLLATE DATABASE_DEFAULT, desde datetime);
INSERT #asig
SELECT e.[No_],
       CASE e.County WHEN N'Chubut' THEN N'CHU' WHEN N'Santa Cruz' THEN N'SCR' WHEN N'Buenos Aires' THEN N'BUE' WHEN N'BAI' THEN N'BUE'
            WHEN N'Capital Federal' THEN N'CABA' WHEN N'CFE' THEN N'CABA' WHEN N'Corrientes' THEN N'COR' WHEN N'Entre Ríos' THEN N'ERI'
            WHEN N'Misiones' THEN N'MIS' WHEN N'Santa Fe' THEN N'SFE' WHEN N'Mendoza' THEN N'MEN' WHEN N'Chaco' THEN N'CHA'
            WHEN N'La Pampa' THEN N'LPA' WHEN N'La Rioja' THEN N'LRI' WHEN N'San Luis' THEN N'SLU' WHEN N'Córdoba' THEN N'CBA'
            WHEN N'Catamarca' THEN N'CAT' WHEN N'Tucuman' THEN N'TUC' END,
       CASE WHEN e.[Employment Date] > '17530101' AND e.[Employment Date] < '20260101' THEN e.[Employment Date] ELSE '20000101' END
FROM dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e
WHERE e.[No_] IN (SELECT [No_ Empleado] FROM dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Período] LIKE N'2026%');

-- Evidencia de Meta4: pagó C_CHUBUT en enero o febrero => Chubut
UPDATE a SET cod = N'CHU'
FROM #asig a WHERE a.emp COLLATE DATABASE_DEFAULT IN (
    SELECT h.[No_ Empleado] FROM dbo.[ArbuTest$Hist_ Liq_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] h
    JOIN dbo.[ArbuTest$Valor Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v ON v.[No_ Entrada] = h.[No_ Entrada]
    JOIN dbo.[ArbuTest$Columna Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c ON c.[No_] = v.[No_ Columna]
    WHERE h.[Año] = 2026 AND h.[Mes] IN (1, 2) AND c.[Nombre Columna] = N'C_CHUBUT' AND v.Valor <> 0);
SELECT @@ROWCOUNT AS Chubut_por_Meta4;
UPDATE #asig SET cod = N'SCR' WHERE emp IN (N'90068', N'90315', N'90396', N'90397', N'90441');
SELECT @@ROWCOUNT AS SantaCruz_esperado_5;

INSERT dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([Tipo Entidad],[Cód_ Entidad],[Cód_ Tipo Atributo],[Vigencia Desde],[Vigencia Hasta],[Cód_ Valor],[Valor Decimal],[Valor Texto],[Valor Fecha],[Valor Numérico],[Cód_ Valor Padre],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT 0, a.emp, N'PROVINCIA', a.desde, '17530101', a.cod, 0, N'', '17530101', 0, N'', NEWID(), SYSUTCDATETIME(), @cero, SYSUTCDATETIME(), @cero
FROM #asig a WHERE a.cod IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Tipo Entidad] = 0 AND x.[Cód_ Entidad] = a.emp COLLATE DATABASE_DEFAULT AND x.[Cód_ Tipo Atributo] = N'PROVINCIA');
SELECT @@ROWCOUNT AS Vigencias_insertadas;
SELECT a.cod, COUNT(*) AS n FROM #asig a GROUP BY a.cod ORDER BY 2 DESC;

-- 3. Parámetro PCT_LEY_3270 (copia de PCT_ART) y su valor para Chubut
SELECT [Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],[$systemCreatedBy],[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3] INTO #pb FROM dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'PCT_ART';
UPDATE #pb SET [Código] = N'PCT_LEY_3270', [Nombre Variable] = N'PCT_LEY_3270', [Descripción] = N'Aporte 8/1000 Ley 3270 (Chubut) sobre la base SS',
    [Notas] = N'Eje: PROVINCIA. Meta4: AP_PAT_LEY_3270 / C_CHUBUT.', [Cód_ Tipo Atributo 1] = N'PROVINCIA', [Cód_ Tipo Atributo 2] = N'', [Cód_ Tipo Atributo 3] = N'', [$systemId] = NEWID();
INSERT dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ([Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3])
SELECT [Código],[Descripción],[Notas],[Nombre Variable],[Sufijo CCT],[$systemId],SYSUTCDATETIME(),[$systemCreatedBy],SYSUTCDATETIME(),[$systemModifiedBy],[Sufijo Empleado],[Antigüedad Máxima Vigencia],[Sufijo Convenio],[Edad Máxima Familiar],[Cód_ Tipo Atributo 1],[Cód_ Tipo Atributo 2],[Cód_ Tipo Atributo 3] FROM #pb
WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Código] = N'PCT_LEY_3270');
SELECT @@ROWCOUNT AS Cabecera_esperado_1;

IF NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro] = N'PCT_LEY_3270_CHU' AND [Vigencia Desde] = '20260101')
    INSERT dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
        ([Cód_ Parámetro Base],[Cód_ Parámetro],[Vigencia Desde],[Descripción],[Valor],[Moneda],[En Uso],[Notas],[No_ Empleado],[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy],[Cód_ Convenio],[Cód_ Categoría],[Nivel],[Cód_ Variable TC],[Sufijo Atributo 1],[Sufijo Atributo 2],[Sufijo Atributo 3])
    SELECT TOP 1 N'PCT_LEY_3270', N'PCT_LEY_3270_CHU', '20260101', N'', 0.8, N'', 0, N'Aporte 8/1000 Ley 3270 (Meta4: AP_PAT_LEY_3270)', N'', NEWID(), SYSUTCDATETIME(), [$systemCreatedBy], SYSUTCDATETIME(), [$systemModifiedBy], N'', N'', 0, N'', N'CHU', N'', N''
    FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro] = N'PCT_ART' AND [Vigencia Desde] = '20260101';
SELECT [Cód_ Parámetro], [Valor], [Sufijo Atributo 1] FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base] = N'PCT_LEY_3270';

-- 4. Concepto 7091, molde del 7090
SELECT * INTO #cp FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'7090' AND [Vigencia Desde] = '20260101';
UPDATE #cp SET [Código] = N'7091', [Descripción] = N'Aporte 8/1000 Ley 3270 Chubut', [Nombre Impresión] = N'',
    [Fórmula] = N'IF(TIPOEMPL = 2, 0, ROUND(PCT_LEY_3270 / 100 * (BASE_SS_TRAB + BASE_SS_VAC), PRECISION_REDONDEO))',
    [Orden Cálculo] = 940, [$systemId] = NEWID();
DECLARE @cc nvarchar(max) = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]') AND c.name <> 'timestamp');
DECLARE @sqlc nvarchar(max) = N'INSERT dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] (' + @cc + N') SELECT ' + @cc + N' FROM #cp WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x WHERE x.[Código] = N''7091'')';
EXEC (@sqlc);
SELECT @@ROWCOUNT AS Concepto_esperado_1;
SELECT [Código], [Tipo Concepto], [Orden Cálculo], [Condición], [Tipos Liq_ Aplicables], [Fórmula] FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] = N'7091';
COMMIT;
