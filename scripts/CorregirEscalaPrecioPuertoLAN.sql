/*
    CORRECCIÓN — PRECIO_PUERTO_LAN de SOMU: cinco categorías fuera de escala.

    QUÉ ES LA ESCALA. El básico de SOMU no se carga categoría por categoría: sale
    del básico de Marinero de Planta por un índice. La fórmula está escrita en el
    propio Excel de tangoneros, en las celdas B58:B62 de la hoja "Det valores":

        B58 = +B62/70*100     ← PRIMER PESCADOR
        B59 = +B62/70*85      ← COCINERO / CONTRAMAESTRE
        B60 = +B62/70*80      ← MOZO / CONTRAMAESTRE FRÍO
        B61 = +B62/70*75      ← MARINERO DE CUBIERTA / ENGRASADOR
        B62 = 747844          ← MARINERO DE PLANTA, el único número cargado a mano

    O sea: 100 / 85 / 80 / 75 / 70 sobre la base de Marinero de Planta. Y las
    columnas PUERTO, FRANCOS y ÓRDENES son múltiplos del básico (×2,891, ×2,4 y
    ×1,5), así que arrastran el mismo índice.

    EL CONTROL. Verificar cada valor contra esa escala —y no contra otra tabla—
    encuentra los errores sin depender de ninguna fuente externa: un parámetro de
    SOMU cuyo cociente contra MR08 no sea 100/85/80/75/70 está mal por dentro,
    sea cual sea el número base.

    Corrido sobre TODOS los parámetros de 729/15 con vigencia 2026, da cinco
    celdas, todas en PRECIO_PUERTO_LAN y todas de menos:

      2026-01-01  MR01 Contramaestre      índice 58,79 en vez de 85
      2026-01-01  MR02 Primer Cocinero    índice 58,79 en vez de 85
      2026-05-01  MR00 Primer Pescador    índice 75    en vez de 100
      2026-05-01  MR06 Enfermero          índice 75    en vez de 80
      2026-05-01  MR07 Contram. de Frío   índice 70    en vez de 80

    En mayo el Primer Pescador —el tope de la escala— quedó cobrando lo mismo que
    un Marinero de Cubierta, y el Contramaestre de Frío lo mismo que un Marinero
    de Planta. Ninguna otra familia de parámetros ni ninguna otra vigencia tiene
    el problema.

    NO HAY LIQUIDACIONES AFECTADAS: hoy ninguna fórmula consume PRECIO_PUERTO_LAN
    —las pruebas van por poteros, que usan _CAL—, así que esto se arregla antes de
    que cueste plata y no después.

    LO QUE ESTA CORRECCIÓN NO TOCA. Sólo repara el índice DENTRO de cada vigencia,
    tomando como base el MR08 que ya está cargado. No decide cuál es el valor base
    correcto, que es una pregunta abierta aparte: para mayo hay tres números
    distintos dando vueltas para el mismo concepto (2.162.017 en el Excel,
    2.162.552 en PRECIO_PUERTO pelado y 2.265.375 en PRECIO_PUERTO_LAN). Eso lo
    tiene que zanjar nómina; mientras tanto, la escala queda coherente.
*/

-- 1. PREVISUALIZACIÓN. Correr esto solo primero.
CREATE TABLE #Esc (Cat varchar(10) COLLATE Modern_Spanish_100_CI_AS, Idx decimal(10,4));
INSERT INTO #Esc VALUES ('MR00',100),('MR01',85),('MR02',85),('MR03',80),
                        ('MR06',80),('MR07',80),('MR04',75),('MR05',75),('MR08',70);

SELECT pv.[Cód_ Parámetro] AS Codigo, pv.[Vigencia Desde] AS Vig, e.Idx AS IndiceCCT,
       pv.[Valor] AS ValorHoy,
       CAST(ROUND(b.Base * e.Idx / 70.0, 0) AS decimal(20,0)) AS DeberiaSer,
       CAST(ROUND(pv.[Valor] / NULLIF(b.Base,0) * 70.0, 2) AS decimal(10,2)) AS IndiceQueTieneHoy,
       CAST(ROUND(b.Base * e.Idx / 70.0, 0) - pv.[Valor] AS decimal(20,0)) AS Diferencia
FROM   dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pv
JOIN   #Esc e ON e.Cat = pv.[Cód_ Categoría]
CROSS  APPLY (SELECT MAX(x.[Valor]) AS Base
              FROM   dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x
              WHERE  x.[Cód_ Parámetro Base] = pv.[Cód_ Parámetro Base]
                AND  x.[Cód_ Convenio]       = pv.[Cód_ Convenio]
                AND  x.[Vigencia Desde]      = pv.[Vigencia Desde]
                AND  x.[Cód_ Categoría]      = 'MR08') b
WHERE  pv.[Cód_ Convenio] = '729/15'
  AND  pv.[Vigencia Desde] >= '2026-01-01'
  -- SOLO los parametros que derivan del basico. Los PCT_ no: son porcentajes,
  -- planos por categoria (PCT_DOLAR_PROD 78, PCT_TRAB_ESP 0,20) o con escala
  -- propia (PCT_PROD sale de 0,0105/0,0100/0,0090/0,0085, no del basico).
  -- Sin este filtro el control marca 18 y trece son falsos positivos.
  AND  pv.[Cód_ Parámetro Base] NOT LIKE 'PCT[_]%'
  AND  ABS(pv.[Valor] / NULLIF(b.Base,0) - e.Idx / 70.0) >= 0.001
ORDER  BY 2, 1;

DROP TABLE #Esc;
GO

/*
-- 2. LA CORRECCIÓN.
BEGIN TRAN;

CREATE TABLE #Esc (Cat varchar(10) COLLATE Modern_Spanish_100_CI_AS, Idx decimal(10,4));
INSERT INTO #Esc VALUES ('MR00',100),('MR01',85),('MR02',85),('MR03',80),
                        ('MR06',80),('MR07',80),('MR04',75),('MR05',75),('MR08',70);

-- El plan se anota ANTES de tocar nada. Si se recalculara sobre la marcha, cada
-- UPDATE cambiaría la base de los siguientes.
SELECT pv.[Cód_ Parámetro] AS Codigo, pv.[Vigencia Desde] AS Vig,
       pv.[Valor] AS ValorViejo,
       CAST(ROUND(b.Base * e.Idx / 70.0, 0) AS decimal(38,20)) AS ValorNuevo
INTO   #Plan
FROM   dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pv
JOIN   #Esc e ON e.Cat = pv.[Cód_ Categoría]
CROSS  APPLY (SELECT MAX(x.[Valor]) AS Base
              FROM   dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x
              WHERE  x.[Cód_ Parámetro Base] = pv.[Cód_ Parámetro Base]
                AND  x.[Cód_ Convenio]       = pv.[Cód_ Convenio]
                AND  x.[Vigencia Desde]      = pv.[Vigencia Desde]
                AND  x.[Cód_ Categoría]      = 'MR08') b
WHERE  pv.[Cód_ Convenio] = '729/15'
  AND  pv.[Vigencia Desde] >= '2026-01-01'
  -- SOLO los parametros que derivan del basico. Los PCT_ no: son porcentajes,
  -- planos por categoria (PCT_DOLAR_PROD 78, PCT_TRAB_ESP 0,20) o con escala
  -- propia (PCT_PROD sale de 0,0105/0,0100/0,0090/0,0085, no del basico).
  -- Sin este filtro el control marca 18 y trece son falsos positivos.
  AND  pv.[Cód_ Parámetro Base] NOT LIKE 'PCT[_]%'
  AND  ABS(pv.[Valor] / NULLIF(b.Base,0) - e.Idx / 70.0) >= 0.001;

-- Esperado: 5.
SELECT COUNT(*) AS ACorregir FROM #Plan;

-- CONTROL DE DIRECCIÓN, antes de escribir: las cinco están de MENOS. Si alguna
-- bajara, la escala que estoy usando no es la correcta. Tiene que dar 0.
SELECT COUNT(*) AS AlgunaBajaria FROM #Plan WHERE ValorNuevo < ValorViejo;

UPDATE pv
SET    pv.[Valor]              = p.ValorNuevo,
       pv.[Notas]              = LEFT(ISNULL(pv.[Notas],'')
                                 + ' Corregido 17/9/2026: estaba fuera de la escala 100/85/80/75/70 del CCT.', 250),
       pv.[$systemModifiedAt]  = SYSUTCDATETIME(),
       pv.[$systemModifiedBy]  = '00000000-0000-0000-0000-000000000000'
FROM   dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pv
JOIN   #Plan p ON p.Codigo = pv.[Cód_ Parámetro] AND p.Vig = pv.[Vigencia Desde];

-- Esperado: 5.
SELECT @@ROWCOUNT AS ValoresCorregidos;

-- CONTROL 1 · NO QUEDA NADA FUERA DE ESCALA. Tiene que dar 0.
SELECT COUNT(*) AS SiguenFueraDeEscala
FROM   dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pv
JOIN   #Esc e ON e.Cat = pv.[Cód_ Categoría]
CROSS  APPLY (SELECT MAX(x.[Valor]) AS Base
              FROM   dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] x
              WHERE  x.[Cód_ Parámetro Base] = pv.[Cód_ Parámetro Base]
                AND  x.[Cód_ Convenio]       = pv.[Cód_ Convenio]
                AND  x.[Vigencia Desde]      = pv.[Vigencia Desde]
                AND  x.[Cód_ Categoría]      = 'MR08') b
WHERE  pv.[Cód_ Convenio] = '729/15' AND pv.[Vigencia Desde] >= '2026-01-01'
  AND  pv.[Cód_ Parámetro Base] NOT LIKE 'PCT[_]%'
  AND  ABS(pv.[Valor] / NULLIF(b.Base,0) - e.Idx / 70.0) >= 0.001;

-- CONTROL 2 · NO SE TOCÓ NINGUNA BASE. El MR08 de cada vigencia tiene que haber
-- quedado igual que antes, porque es de donde sale todo lo demás. Tiene que dar 0.
SELECT COUNT(*) AS BasesTocadas
FROM   #Plan WHERE Codigo LIKE '%MR08';

DROP TABLE #Plan; DROP TABLE #Esc;
-- COMMIT;   -- o ROLLBACK;
*/
