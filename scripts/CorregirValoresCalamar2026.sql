/*
    CORRECCIÓN — VALOR_CAL_* : 18 valores cargados con el cociente redondeado.

    FUENTE: "Valores  producción calamar campaña 2026.xlsx", hoja única. Es un
    archivo de 25 celdas y se explica solo:

        B3 = ROUND((F3/70*100),0)   PRIMER PESCADOR                  MR00
        C3 = ROUND((F3/70*85),0)    CONTRAMAESTRE · COCINERO         MR01 MR02
        D3 = ROUND((F3/70*80),0)    CONTRAM. FRÍO · ENFERMERO · MOZO MR07 MR06 MR03
        E3 = ROUND((F3/70*75),0)    ENGRASADOR · MARINERO CUBIERTA   MR04 MR05
        F3 = 10000                  MARINERO PLANTA                  MR08

        F3 ENTERO 10000 · F4 REJO SUCIO 6400 · F5 VAINA 18303

    Toda la tabla son TRES números y el índice 100/85/80/75/70 —el mismo de
    tangoneros—. Y de paso el archivo contesta algo que veníamos deduciendo: la
    columna D nombra explícitamente a ENFERMERO y CONTRAMAESTRE FRÍO junto con
    MOZO, así que MR06 y MR07 van con MR03. MR09 también: quedó cargado con el
    índice 80.

    EL ERROR. Los 30 valores ya estaban cargados con vigencia 2026-01-01, pero 18
    no coinciden con el Excel. Quien los cargó multiplicó por el cociente
    redondeado a cuatro decimales en vez de por la fracción exacta, y no redondeó:

        6400  x 1,4286 = 9143,04       el Excel dice ROUND(6400/70*100,0)  = 9143
        18303 x 1,4286 = 26147,6658    el Excel dice ROUND(18303/70*100,0) = 26147

    Los 12 que sí coinciden son los de ENTERO, donde con base 10.000 el redondeo
    cae igual por casualidad. Las diferencias van de -0,17 a +0,67 pesos por
    tonelada: es plata despreciable, pero es un número que no sale de ninguna
    fuente y que nadie va a poder explicar dentro de seis meses.

    IMPACTO. Estos parámetros SÍ están en uso —26 fórmulas los leen— y hay 29
    liquidaciones en estado Calculada del 29/1/2026 que los usaron. Hay que
    recalcularlas. Las 74 Aprobadas son del 31/12/2025, anteriores a esta
    vigencia, así que no las toca. No hay ninguna Contabilizada.
*/

-- 1. PREVISUALIZACIÓN.
CREATE TABLE #Esc (Cat varchar(10) COLLATE Modern_Spanish_100_CI_AS, Idx int);
INSERT INTO #Esc VALUES ('MR00',100),('MR01',85),('MR02',85),('MR03',80),
                        ('MR06',80),('MR07',80),('MR09',80),('MR04',75),('MR05',75),('MR08',70);
CREATE TABLE #Base (Par varchar(20) COLLATE Modern_Spanish_100_CI_AS, B decimal(20,4));
INSERT INTO #Base VALUES ('VALOR_CAL_ENT',10000),('VALOR_CAL_REJ',6400),('VALOR_CAL_VAI',18303);

SELECT pv.[Cód_ Parámetro] AS Codigo, pv.[Valor] AS EnLaBase,
       ROUND(bs.B / 70.0 * e.Idx, 0) AS SegunElExcel,
       CAST(pv.[Valor] - ROUND(bs.B / 70.0 * e.Idx, 0) AS decimal(12,4)) AS Dif
FROM   dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pv
JOIN   #Esc  e  ON e.Cat  = pv.[Cód_ Categoría]
JOIN   #Base bs ON bs.Par = pv.[Cód_ Parámetro Base]
WHERE  pv.[Cód_ Convenio] = '729/15'
  AND  ABS(pv.[Valor] - ROUND(bs.B / 70.0 * e.Idx, 0)) >= 0.005
ORDER  BY 1;

DROP TABLE #Esc; DROP TABLE #Base;
GO

/*
-- 2. LA CORRECCIÓN.
BEGIN TRAN;

CREATE TABLE #Esc (Cat varchar(10) COLLATE Modern_Spanish_100_CI_AS, Idx int);
INSERT INTO #Esc VALUES ('MR00',100),('MR01',85),('MR02',85),('MR03',80),
                        ('MR06',80),('MR07',80),('MR09',80),('MR04',75),('MR05',75),('MR08',70);
CREATE TABLE #Base (Par varchar(20) COLLATE Modern_Spanish_100_CI_AS, B decimal(20,4));
INSERT INTO #Base VALUES ('VALOR_CAL_ENT',10000),('VALOR_CAL_REJ',6400),('VALOR_CAL_VAI',18303);

UPDATE pv
SET    pv.[Valor]             = ROUND(bs.B / 70.0 * e.Idx, 0),
       pv.[Notas]             = LEFT(ISNULL(pv.[Notas],'')
                                + ' Corregido 17/9/2026 al valor del Excel de campaña: ROUND(base/70*indice,0).', 250),
       pv.[$systemModifiedAt] = SYSUTCDATETIME(),
       pv.[$systemModifiedBy] = '00000000-0000-0000-0000-000000000000'
FROM   dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pv
JOIN   #Esc  e  ON e.Cat  = pv.[Cód_ Categoría]
JOIN   #Base bs ON bs.Par = pv.[Cód_ Parámetro Base]
WHERE  pv.[Cód_ Convenio] = '729/15'
  AND  ABS(pv.[Valor] - ROUND(bs.B / 70.0 * e.Idx, 0)) >= 0.005;

-- Esperado: 18.
SELECT @@ROWCOUNT AS ValoresCorregidos;

-- CONTROL 1 · LOS 30 COINCIDEN CON EL EXCEL. Tiene que dar 30 y 0.
SELECT SUM(CASE WHEN pv.[Valor] = ROUND(bs.B/70.0*e.Idx,0) THEN 1 ELSE 0 END) AS Coinciden,
       SUM(CASE WHEN pv.[Valor] <> ROUND(bs.B/70.0*e.Idx,0) THEN 1 ELSE 0 END) AS Difieren
FROM   dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pv
JOIN   #Esc  e  ON e.Cat  = pv.[Cód_ Categoría]
JOIN   #Base bs ON bs.Par = pv.[Cód_ Parámetro Base]
WHERE  pv.[Cód_ Convenio] = '729/15';

-- CONTROL 2 · LAS BASES NO SE MOVIERON. Marinero de Planta tiene que seguir
-- valiendo 10000 / 6400 / 18303, que son los tres números del Excel. Tiene que
-- dar 3 y 0.
SELECT SUM(CASE WHEN pv.[Valor] = bs.B THEN 1 ELSE 0 END) AS BasesIntactas,
       SUM(CASE WHEN pv.[Valor] <> bs.B THEN 1 ELSE 0 END) AS BasesMovidas
FROM   dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pv
JOIN   #Base bs ON bs.Par = pv.[Cód_ Parámetro Base]
WHERE  pv.[Cód_ Convenio] = '729/15' AND pv.[Cód_ Categoría] = 'MR08';

-- CONTROL 3 · NINGÚN VALOR SE MOVIÓ MÁS DE UN PESO. Es una corrección de
-- redondeo; si algo saltó más que eso, la base o el índice están mal. Tiene
-- que dar 0.
SELECT COUNT(*) AS SaltoDeMasDeUnPeso
FROM   dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pv
JOIN   #Esc  e  ON e.Cat  = pv.[Cód_ Categoría]
JOIN   #Base bs ON bs.Par = pv.[Cód_ Parámetro Base]
WHERE  pv.[Cód_ Convenio] = '729/15'
  AND  pv.[Notas] LIKE '%Corregido 17/9/2026 al valor del Excel de campaña%'
  AND  ABS(pv.[Valor] - ROUND(bs.B / 70.0 * e.Idx, 0)) > 1;

DROP TABLE #Esc; DROP TABLE #Base;
-- COMMIT;   -- o ROLLBACK;
*/

-- 3. DESPUÉS: recalcular las 29 liquidaciones Calculadas del 29/1/2026, que se
--    computaron con los valores viejos. Esto las lista.
SELECT l.[No_ Empleado] AS Emp, l.[No_ Proyecto] AS Proy, l.[Fecha Liquidación] AS Fecha
FROM   dbo.[ArbuTest$Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] l
WHERE  l.[Estado] = 1
ORDER  BY 2, 1;
GO
