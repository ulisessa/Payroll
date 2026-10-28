/*
    COMPLETAR LAS NOVEDADES QUE META4 LIQUIDÓ Y BC NO TIENE, DE FEBRERO EN ADELANTE.

    Alcance: conceptos SIN fórmula (los que se pagan por novedad) con columna mapeada en Meta4
    ("Cód. Concepto BC" en Columna Hist. Meta4), en las corridas de Meta4 de 2026 mes >= 2, sin las de
    anticipo (TP_IMPUT 4). Se inserta una novedad por (empleado, corrida, concepto) SÓLO donde BC no
    tiene NINGUNA novedad vigente (no anulada) de ese concepto en ese período: lo que ya está cargado
    —completo o distinto— no se toca.

    EXCLUIDOS A PROPÓSITO
      · 5498 REDONDEO: lo calcula el motor.
      · 4135: el signo está al revés (BC tiene 56 líneas contra 1 de Meta4): otro problema.
    LA FECHA es la de pago de la corrida de Meta4 (como las ya migradas: Observaciones = 'Meta4 <cpt>').
    EL TIPO DE LIQUIDACIÓN, por TP_IMPUT de la corrida: 3 → VACACIONES, 10 → CIERRE_MAREA,
    14/15 → LIQ_FINAL, y 1 → REGULAR SÓLO si el empleado tiene una Regular ese mes en BC (en febrero);
    en meses sin liquidaciones queda en blanco. Con el tipo en blanco manda la fecha, y eso ya nos
    hizo caer en el recibo equivocado (ver la lección "Tipo Liq. y Fecha se pelean").
    Entran como Pendientes (Estado 0): se materializan al calcular. SQL directo: reiniciar service tier.
*/
SET XACT_ABORT ON; SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#nuevas') IS NOT NULL DROP TABLE #nuevas;
;WITH sinformula AS (
    SELECT DISTINCT [Código] cpt FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    WHERE LEN(LTRIM(RTRIM([Fórmula]))) = 0 AND [Vigencia Hasta] = '17530101' AND [Código] NOT IN ('5498','4135')),
m4 AS (
    SELECT m.[Año] anio, m.[Mes] mes, m.[No_ Empleado] emp, m.[Tipo Imputación] tp, m.[Fecha Pago] pago, col.[Cód_ Concepto BC] cpt, SUM(v.Valor) val
    FROM dbo.[ArbuTest$Hist_ Liq_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] m
    JOIN dbo.[ArbuTest$Valor Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v ON v.[No_ Entrada] = m.[No_ Entrada]
    JOIN dbo.[ArbuTest$Columna Hist_ Meta4$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] col ON col.[No_] = v.[No_ Columna]
    WHERE m.[Año] = 2026 AND m.[Mes] >= 2 AND m.[Tipo Imputación] <> 4 AND v.Valor <> 0
      AND col.[Cód_ Concepto BC] IN (SELECT cpt COLLATE DATABASE_DEFAULT FROM sinformula)
    GROUP BY m.[Año], m.[Mes], m.[No_ Empleado], m.[Tipo Imputación], m.[Fecha Pago], col.[Cód_ Concepto BC])
SELECT m4.*, CONCAT(m4.anio, RIGHT(CONCAT('0', m4.mes), 2)) periodo,
       CASE WHEN m4.tp = 3 THEN N'VACACIONES' WHEN m4.tp = 10 THEN N'CIERRE_MAREA' WHEN m4.tp IN (14, 15) THEN N'LIQ_FINAL'
            WHEN m4.tp = 1 AND EXISTS (SELECT 1 FROM dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] r
                 WHERE r.[No_ Empleado] = m4.emp AND r.[Cód_ Tipo Liq_] = N'REGULAR' AND r.[Cód_ Período] = CONCAT(m4.anio, RIGHT(CONCAT('0', m4.mes), 2))) THEN N'REGULAR'
            ELSE N'' END tipoliq
INTO #nuevas
FROM m4
WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] n
                  WHERE n.[No_ Empleado] = m4.emp AND n.[Cód_ Concepto] = m4.cpt AND n.Estado <> 2
                    AND n.[Cód_ Período] = CONCAT(m4.anio, RIGHT(CONCAT('0', m4.mes), 2)));

PRINT '== PREVISUALIZACIÓN: novedades a crear por concepto y mes';
SELECT cpt, periodo, COUNT(*) n, CAST(SUM(val) AS bigint) importe FROM #nuevas GROUP BY cpt, periodo ORDER BY cpt, periodo;
PRINT '== Empleados que no existen en Employee (no se cargan)';
SELECT DISTINCT emp FROM #nuevas WHERE NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e WHERE e.[No_] = #nuevas.emp COLLATE DATABASE_DEFAULT);

BEGIN TRAN;
INSERT dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([Cód_ Período],[Fecha],[Cód_ Tipo Liq_],[Cód_ Convenio],[Cód_ Categoría],[No_ Empleado],[Nombre Empleado],[No_ Proyecto],[Cód_ Concepto],
     [Cantidad],[Unidad Cantidad],[Valor Unitario],[Importe],[Observaciones],[Estado],[No_ Liquidación],[Motivo No Aplicada],[Recurrente],[Períodos Restantes],[Novedad Origen],
     [$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy])
SELECT n.periodo, n.pago, n.tipoliq, N'', N'', n.emp,
       LEFT(LTRIM(RTRIM(CONCAT(e.[First Name], ' ', e.[Last Name]))), 100), N'', n.cpt,
       0, N'', 0, n.val, CONCAT(N'Meta4 ', n.cpt), 0, N'', N'', 0, 0, 0,
       NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000', SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM #nuevas n JOIN dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e ON e.[No_] = n.emp COLLATE DATABASE_DEFAULT;
SELECT @@ROWCOUNT AS Insertadas;

-- CONTROLES (tienen que dar 0): (1) filas repetidas DENTRO de lo que se acaba de armar; (2) novedades nuevas que
-- chocan con una ya existente del mismo empleado, concepto y período.
SELECT COUNT(*) AS RepetidasEntreLasNuevas FROM (SELECT emp, cpt, periodo, pago, tipoliq FROM #nuevas GROUP BY emp, cpt, periodo, pago, tipoliq HAVING COUNT(*) > 1) d;
SELECT COUNT(*) AS ChocanConExistentes FROM #nuevas n JOIN dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x
  ON x.[No_ Empleado] = n.emp AND x.[Cód_ Concepto] = n.cpt AND x.[Cód_ Período] = n.periodo AND x.Estado <> 2 AND x.[No_ Movimiento] <= (SELECT MAX([No_ Movimiento]) FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]) - (SELECT COUNT(*) FROM #nuevas);
COMMIT;
