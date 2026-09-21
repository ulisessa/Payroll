/*
    PASO 2 de 2 — se ejecuta en la conexión **BC** (SQL Server).

    Toma dbo.MIG_AtributosM4 (cargada con MigrarAtributosCCT_1_Meta4_Oracle.sql) y la convierte en
    filas de "Atributo Entidad Liq." (Tab110005), que es de donde el motor saca el par
    convenio/categoría al liquidar.

    LAS TRES COSAS QUE HACE, y ninguna es opcional:

    1. TRADUCE EL CONVENIO. Meta4 usa códigos de dos letras (MR, OF, FE) y BC el número de CCT
       (729/15, 175/75, ESP). La categoría NO se traduce: los códigos embarcados son idénticos en
       los dos lados porque el catálogo de BC se construyó desde Meta4.

    2. RESUELVE EL PADRE DE LA CATEGORÍA. La clave de "Categoría CCT" es (convenio, código) —OF01
       es Capitán en 175/75 y también en 768/19— así que el atributo de categoría guarda el
       convenio en "Cód. Valor Padre". Y el padre tiene que ser el vigente A ESA FECHA: el bloque 2
       cruza las dos vigencias y PARTE la categoría cuando el convenio cambia en el medio. Sin eso,
       un empleado que pasó de MR a OF quedaría con su categoría vieja colgando del convenio nuevo.

    3. NORMALIZA LAS VIGENCIAS. La tabla rechaza superposiciones (ValidarNoSuperponeConAnterior) y
       Meta4 no garantiza que FEC_FIN sea anterior al FEC_INICIO siguiente. Se recalcula el cierre
       igual que en la migración de estados: el día antes del siguiente, respetando el fin de Meta4
       cuando es anterior.

    POR QUÉ POR SQL Y NO POR AL
       El OnInsert de la tabla hace seis cosas —valida intervalo, sincroniza contigüidad, resuelve
       el padre, recalcula el valor numérico— y con 21.000 filas eso es inviable por página. Lo que
       el trigger calcularía se calcula acá, campo por campo, y el bloque 4 verifica que dé lo
       mismo. Los dos campos derivados son:
         · "Cód. Valor Padre"  → el convenio vigente al inicio de la vigencia (ResolverValorPadre).
         · "Valor Numérico"    → el del "Valor Atributo Liq." correspondiente, porque los dos tipos
           son de Tipo Dato Lista (RecalcularValorNumerico). Es el único campo que lee Fuente Datos.

    ORDEN: bloques 1 a 3 (leen), después el 4 (inserta) y el 5 (verifica).
*/

-- ╔══════════════════════════════════════════════════════════════════════════════════════════╗
-- ║  CONEXIÓN: BC  (SQL Server)                                                              ║
-- ╚══════════════════════════════════════════════════════════════════════════════════════════╝
SELECT 'Conexión correcta: SQL Server — base ' + DB_NAME() AS GUARDIAN;

------------------------------------------------------------------------------------------------
-- 0. LA REGLA DE LOS OFICIALES, y dónde debería vivir a futuro
--
--    BC tiene DOS convenios de oficiales embarcados con las mismas cinco categorías OF01..OF05:
--        175/75  CAPECA   -> TANGONEROS
--        768/19  AACPyPP  -> POTEROS
--    Meta4 tiene uno solo, "OF". La distinción no está en el convenio: está en el BUQUE.
--
--        buque 101 a 119          -> tangonero -> 175/75
--        el resto (126..129, 801, 802) -> potero -> 768/19
--
--    Esa regla está escrita en el 2.b.2 como un rango numérico, y es deuda: el lugar donde debería
--    vivir es un atributo TIPO_BUQUE sobre la ENTIDAD BUQUE. "Entidad Liq." (Tab110008) ya existe
--    con el código del valor de dimensión, y "Atributo Entidad Liq." acepta Tipo Entidad = Buque,
--    así que el modelo lo soporta hoy. Con el atributo cargado, esto pasa a ser un JOIN y deja de
--    ser un número mágico — y sirve para cualquier otra regla del CCT que difiera entre flotas,
--    que probablemente haya más de una.
--
--    Mientras tanto, el rango numérico tiene dos límites que conviene conocer:
--      · Un buque nuevo fuera del rango cae en potero por defecto, sin avisar.
--      · Si algún buque cambió de arte alguna vez, acá no se puede expresar: haría falta una
--        vigencia, que es justamente lo que el atributo daría gratis.
--
--    Esta consulta muestra qué buques aparecen en los estados y cómo los clasifica la regla. Vale
--    la pena mirarla una vez: si aparece un código que no esperabas, lo estás clasificando igual.
------------------------------------------------------------------------------------------------
SELECT j.[Global Dimension 1 Code] AS Buque,
       CASE WHEN TRY_CAST(j.[Global Dimension 1 Code] AS int) IS NULL THEN 'NO ES BUQUE (no numérico)'
            WHEN TRY_CAST(j.[Global Dimension 1 Code] AS int) BETWEEN 101 AND 119 THEN 'TANGONERO -> 175/75'
            ELSE 'POTERO -> 768/19' END AS Flota,
       COUNT(*) AS Estados
FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = ee.[No_ Proyecto]
WHERE ee.[Tipo Entidad] = 0 AND ee.[No_ Proyecto] <> ''
GROUP BY j.[Global Dimension 1 Code]
ORDER BY 2, 1;

------------------------------------------------------------------------------------------------
-- 1. LA TABLA PUENTE
------------------------------------------------------------------------------------------------
IF OBJECT_ID('dbo.MIG_AtributosM4') IS NULL
    CREATE TABLE dbo.MIG_AtributosM4 (
        TIPO        varchar(10),      -- 'CONVENIO' | 'CATEGORIA'
        LEGAJO      varchar(20),
        FEC_INICIO  date,
        FEC_FIN     date,
        VALOR_M4    varchar(20),
        COMENT      varchar(250)
    );
-- Para rehacer la carga:  TRUNCATE TABLE dbo.MIG_AtributosM4;

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_MIG_AtributosM4' AND object_id = OBJECT_ID('dbo.MIG_AtributosM4'))
    CREATE INDEX IX_MIG_AtributosM4 ON dbo.MIG_AtributosM4 (LEGAJO, TIPO, FEC_INICIO);

SELECT TIPO,
       COUNT(*)               AS Filas,
       COUNT(DISTINCT LEGAJO) AS Legajos,
       MIN(FEC_INICIO)        AS Desde,
       MAX(FEC_INICIO)        AS Hasta
FROM dbo.MIG_AtributosM4
GROUP BY TIPO;
-- Esperado: CONVENIO 11.269 / 6.490 · CATEGORIA 9.768 / 4.819.

-- 1.b DOBLE CARGA. Mismo guardián que en la migración de estados, y por el mismo motivo: no falla,
--     deja vigencias duplicadas que aparecen mucho después como superposición.
SELECT COUNT(*) AS CombinacionesDuplicadas
FROM  (SELECT TIPO, LEGAJO, FEC_INICIO
       FROM   dbo.MIG_AtributosM4
       GROUP  BY TIPO, LEGAJO, FEC_INICIO
       HAVING COUNT(*) > 1) x;

------------------------------------------------------------------------------------------------
-- 2. TRADUCCIÓN
------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Atributos') IS NOT NULL DROP TABLE #Atributos;
IF OBJECT_ID('tempdb..#Conv')  IS NOT NULL DROP TABLE #Conv;
IF OBJECT_ID('tempdb..#Cat')   IS NOT NULL DROP TABLE #Cat;
IF OBJECT_ID('tempdb..#Flota') IS NOT NULL DROP TABLE #Flota;
IF OBJECT_ID('tempdb..#ConvBase') IS NOT NULL DROP TABLE #ConvBase;
IF OBJECT_ID('tempdb..#ConvOF') IS NOT NULL DROP TABLE #ConvOF;
-- Intermedia del 2.b.3. Se borra sola ahí, pero si el bloque queda a mitad de camino sobrevive, y
-- la corrida siguiente falla en el SELECT INTO con un mensaje que no dice por qué.
IF OBJECT_ID('tempdb..#ConvFinal') IS NOT NULL DROP TABLE #ConvFinal;

-- 2.a EQUIVALENCIA DE CONVENIOS.
--
--     Meta4 usa códigos de dos letras y BC el número de CCT. La categoría NO se traduce: los
--     códigos embarcados son idénticos en los dos lados porque el catálogo de BC se construyó
--     desde Meta4.
--
--     OF NO ESTÁ ACÁ, y es la parte interesante: el convenio de los oficiales no es un valor fijo
--     sino que DEPENDE DEL BUQUE —CAPECA para tangoneros, AACPyPP para poteros— y por lo tanto de
--     la fecha. Lo resuelve el 2.b.2. Un convenio que no figure ni acá ni allá deja al empleado
--     entero fuera de la migración, convenio Y categoría: media identidad es peor que ninguna.
DECLARE @Equiv TABLE (M4 varchar(20) PRIMARY KEY, BC varchar(20));
INSERT INTO @Equiv (M4, BC) VALUES
    ('MR', '729/15'),                  -- Marinería Embarcados     -> SOMU-CAPECA
    ('FE', 'ESP'),                     -- Fuera de Conv. Españoles -> Sin CCT Embarcado España
    ('EC', '130/75'),                  -- Empleados de Comercio    -> Comercio
    -- JO Y FA SE MAPEAN A SÍ MISMOS. Ninguno de los dos tiene un CCT vigente al que llevarlo: JO
    -- —jornalizados de planta— ya no existe en la empresa, y 372/04 es STIA mensualizados, otro
    -- régimen. FA es "Fuera de Convenio Argentinos" y el equivalente de BC sería ADM, que tiene
    -- tres categorías contra 58 cargos FA*; y ADM tampoco es un CCT, es exactamente lo mismo que
    -- FA con otro nombre. Se crean en BC con el mismo código para que el historial se lea sin
    -- traducción. REQUIEREN, ANTES del bloque 4: Convenio Colectivo JO y FA, y sus categorías —
    -- las que liste el bloque 3.a, que es la lista de trabajo real.
    ('JO', 'JO'),                      -- Jornalizado Alimentación -> JO (histórico, sin CCT vivo)
    ('FA', 'FA');                      -- Fuera de Convenio Arg.   -> FA (sin CCT)

-- 2.b.0 LAS VIGENCIAS DE CONVENIO, NORMALIZADAS SOBRE EL HISTORIAL COMPLETO.
--
--       EL ORDEN IMPORTA Y ES LA PARTE FÁCIL DE EQUIVOCAR: el cierre de cada vigencia se calcula
--       mirando TODAS las del empleado, incluidas las de convenios que después no se migran. Si se
--       filtrara primero por los mapeados, el LEAD saltaría por encima de los tramos descartados y
--       cerraría la vigencia anterior donde empieza la SIGUIENTE MAPEADA, no donde realmente
--       terminó.
--
--       Pasó, y el bloque 3.d lo mostró: el legajo 00017 con una vigencia de 2000-10-24 a
--       2005-04-25 y la siguiente arrancando el 2001-06-06. Cuatro años de superposición, porque
--       entre medio tenía un tramo de otro convenio que el filtro había sacado antes de tiempo.
--
--       El cierre se recalcula igual que en la migración de estados: el día antes del siguiente,
--       pero respetando el fin de Meta4 cuando es ANTERIOR —ahí hay un hueco deliberado, no un
--       error—. '1753-01-01' es la fecha en blanco de BC.
IF OBJECT_ID('tempdb..#ConvBase') IS NOT NULL DROP TABLE #ConvBase;
SELECT m.LEGAJO,
       m.VALOR_M4                                  AS ValorM4,
       m.FEC_INICIO                                AS Desde,
       CAST(NULL AS date)                          AS Hasta,
       m.FEC_FIN                                   AS FinM4,
       LEAD(m.FEC_INICIO) OVER (PARTITION BY m.LEGAJO ORDER BY m.FEC_INICIO) AS Siguiente
INTO   #ConvBase
FROM   dbo.MIG_AtributosM4 m
WHERE  m.TIPO = 'CONVENIO';

UPDATE #ConvBase
   SET Hasta = CASE
                 WHEN Siguiente IS NULL                                         THEN COALESCE(FinM4, '1753-01-01')
                 WHEN FinM4 IS NOT NULL AND FinM4 < DATEADD(day, -1, Siguiente) THEN FinM4
                 ELSE DATEADD(day, -1, Siguiente)
               END;

-- 2.b.1 LOS CONVENIOS DE EQUIVALENCIA DIRECTA. Todo menos OF.
SELECT b.LEGAJO,
       e.BC               AS ValorBC,
       b.Desde,
       b.Hasta,
       CAST(NULL AS date) AS FinM4,
       CAST(NULL AS date) AS Siguiente
INTO   #Conv
FROM   #ConvBase b
JOIN   @Equiv e ON e.M4 = b.ValorM4;

-- 2.b.2 LOS OFICIALES: EL CONVENIO SALE DE LA FLOTA, NO DE META4.
--
--       BC tiene dos convenios de oficiales embarcados con las mismas cinco categorías OF01..OF05:
--           175/75  CAPECA    -> TANGONEROS, buques 101 a 119
--           768/19  AACPyPP   -> POTEROS,    el resto (126..129, 801, 802)
--       Meta4 tiene uno solo, "OF", así que la distinción no está en el dato de convenio: está en
--       el buque. Y la tripulación rota mucho —hay activos con ocho buques distintos en seis
--       años—, así que un oficial que pasa de un tangonero a un potero CAMBIA de convenio ese día.
--
--       La línea de tiempo de flota se deriva de los ESTADOS: cada estado apunta a un proyecto, el
--       proyecto al buque por la dimensión 1, y el número del buque dice la flota. Los estados
--       consecutivos de la misma flota se colapsan en un tramo (gaps and islands), así que un
--       oficial que hizo cinco mareas seguidas en tangoneros tiene UN tramo, no cinco.
--
--       Los estados sin proyecto —los ~33.000 de mareas viejas que no existen como Job— no cortan
--       el tramo: no dicen nada sobre la flota, y cortar ahí inventaría un cambio que no hubo.
--       PPM tampoco entra: es un puerto, no un buque, y su código no es numérico.
WITH PorDia AS (
    -- Un estado por legajo y día. Dos estados el mismo día en flotas distintas es un dato
    -- contradictorio; MIN lo resuelve de forma determinista en vez de dejarlo al azar del plan.
    SELECT ee.[No_ Empleado] AS Legajo,
           ee.[Fecha Inicio] AS Desde,
           MIN(CASE WHEN TRY_CAST(j.[Global Dimension 1 Code] AS int) BETWEEN 101 AND 119
                    THEN '175/75' ELSE '768/19' END) AS Convenio
    FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    JOIN   [dbo].[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
           ON j.[No_] = ee.[No_ Proyecto]
    WHERE  ee.[Tipo Entidad] = 0
      AND  ee.[No_ Proyecto] <> ''
      AND  TRY_CAST(j.[Global Dimension 1 Code] AS int) IS NOT NULL
    GROUP  BY ee.[No_ Empleado], ee.[Fecha Inicio]
),
Marcada AS (
    SELECT *, CASE WHEN Convenio = LAG(Convenio) OVER (PARTITION BY Legajo ORDER BY Desde)
                   THEN 0 ELSE 1 END AS Cambia
    FROM   PorDia
),
Islas AS (
    SELECT Legajo, Convenio, Desde,
           SUM(Cambia) OVER (PARTITION BY Legajo ORDER BY Desde ROWS UNBOUNDED PRECEDING) AS Isla
    FROM   Marcada
),
Tramos AS (
    SELECT Legajo, Convenio, MIN(Desde) AS Desde
    FROM   Islas GROUP BY Legajo, Convenio, Isla
)
SELECT Legajo, Convenio, Desde,
       COALESCE(DATEADD(day, -1, LEAD(Desde) OVER (PARTITION BY Legajo ORDER BY Desde)),
                '1753-01-01') AS Hasta
INTO   #Flota
FROM   Tramos;

-- Las vigencias OF salen de #ConvBase, que YA está normalizado contra el historial completo. Si se
-- volvieran a leer del puente filtrando por 'OF', el LEAD saltaría por encima de los tramos MR o FE
-- que el oficial haya tenido en el medio y los cerraría de más — el mismo error que el 2.b.0
-- describe para el otro lado.
IF OBJECT_ID('tempdb..#ConvOF') IS NOT NULL DROP TABLE #ConvOF;
SELECT b.LEGAJO, b.Desde, b.Hasta
INTO   #ConvOF
FROM   #ConvBase b
WHERE  b.ValorM4 = 'OF';

-- La intersección. Cada vigencia OF se corta en los bordes de los tramos de flota.
INSERT INTO #Conv (LEGAJO, ValorBC, Desde, Hasta, FinM4, Siguiente)
SELECT o.LEGAJO,
       f.Convenio,
       CASE WHEN f.Desde > o.Desde THEN f.Desde ELSE o.Desde END,
       CASE WHEN (CASE WHEN f.Hasta = '1753-01-01' THEN '9999-12-31' ELSE f.Hasta END)
               <  (CASE WHEN o.Hasta = '1753-01-01' THEN '9999-12-31' ELSE o.Hasta END)
            THEN f.Hasta ELSE o.Hasta END,
       NULL, NULL
FROM   #ConvOF o
JOIN   #Flota f
       ON  f.Legajo = o.LEGAJO
       AND f.Desde <= (CASE WHEN o.Hasta = '1753-01-01' THEN '9999-12-31' ELSE o.Hasta END)
       AND o.Desde <= (CASE WHEN f.Hasta = '1753-01-01' THEN '9999-12-31' ELSE f.Hasta END);

-- 2.b.3 TRAMOS DE FLOTA CONSECUTIVOS CON EL MISMO CONVENIO.
--       La intersección puede partir una vigencia OF en dos pedazos que terminan con el MISMO
--       convenio —pasó de un tangonero a otro tangonero— y eso sería una vigencia partida sin
--       motivo. Se vuelven a pegar: el historial tiene que reflejar cambios de convenio, no
--       cambios de barco.
WITH Ord AS (
    SELECT LEGAJO, ValorBC, Desde, Hasta,
           CASE WHEN ValorBC = LAG(ValorBC) OVER (PARTITION BY LEGAJO ORDER BY Desde)
                 AND Desde = DATEADD(day, 1, LAG(Hasta) OVER (PARTITION BY LEGAJO ORDER BY Desde))
                THEN 0 ELSE 1 END AS Abre
    FROM   #Conv
),
Islas AS (
    SELECT *, SUM(Abre) OVER (PARTITION BY LEGAJO ORDER BY Desde ROWS UNBOUNDED PRECEDING) AS Isla
    FROM   Ord
),
Pegados AS (
    SELECT LEGAJO, ValorBC, MIN(Desde) AS Desde,
           CASE WHEN MAX(CASE WHEN Hasta = '1753-01-01' THEN 1 ELSE 0 END) = 1
                THEN '1753-01-01' ELSE MAX(Hasta) END AS Hasta
    FROM   Islas GROUP BY LEGAJO, ValorBC, Isla
)
SELECT * INTO #ConvFinal FROM Pegados;

DROP TABLE #Conv;
SELECT LEGAJO, ValorBC, Desde, Hasta,
       CAST(NULL AS date) AS FinM4, CAST(NULL AS date) AS Siguiente
INTO   #Conv
FROM   #ConvFinal;
DROP TABLE #ConvFinal;

-- 2.c LAS VIGENCIAS DE CATEGORÍA, normalizadas igual.
SELECT m.LEGAJO,
       m.VALOR_M4                                  AS ValorBC,   -- el código NO se traduce
       m.FEC_INICIO                                AS Desde,
       CAST(NULL AS date)                          AS Hasta,
       m.FEC_FIN                                   AS FinM4,
       LEAD(m.FEC_INICIO) OVER (PARTITION BY m.LEGAJO ORDER BY m.FEC_INICIO) AS Siguiente
INTO   #Cat
FROM   dbo.MIG_AtributosM4 m
WHERE  m.TIPO = 'CATEGORIA';

UPDATE #Cat
   SET Hasta = CASE
                 WHEN Siguiente IS NULL                                         THEN COALESCE(FinM4, '1753-01-01')
                 WHEN FinM4 IS NOT NULL AND FinM4 < DATEADD(day, -1, Siguiente) THEN FinM4
                 ELSE DATEADD(day, -1, Siguiente)
               END;

-- 2.d EL CRUCE. Acá está la parte que no es mecánica.
--
--     El convenio va tal cual —ya resuelto, incluidos los oficiales—. La categoría se INTERSECA
--     contra el convenio: cada tramo de categoría se corta en los bordes de los tramos de
--     convenio, y cada pedazo lleva como padre el convenio de ESE pedazo. Un empleado que pasó de
--     MR a OF con la misma categoría cargada de punta a punta termina con dos filas de categoría,
--     una colgada de cada convenio. Sin eso, OF01 colgado de 729/15 no existe y no resuelve.
--
--     Una categoría sin convenio que la cubra no entra. No es un descarte silencioso: el bloque
--     3.c la lista, y significa que Meta4 tiene la categoría fuera del período en que esa persona
--     tuvo un convenio migrable.
SELECT CAST('CONVENIO' AS varchar(20))  AS TipoAtributo,
       c.LEGAJO                         AS Legajo,
       c.Desde                          AS Desde,
       c.Hasta                          AS Hasta,
       c.ValorBC                        AS Valor,
       CAST('' AS varchar(20))          AS ValorPadre
INTO   #Atributos
FROM   #Conv c
UNION ALL
SELECT 'CATEGORIA',
       t.LEGAJO,
       -- La intersección de los dos intervalos. '1753-01-01' representa "abierto", así que para
       -- comparar se lo reemplaza por una fecha máxima y se vuelve a traducir al final.
       CASE WHEN v.Desde > t.Desde THEN v.Desde ELSE t.Desde END,
       CASE WHEN (CASE WHEN v.Hasta = '1753-01-01' THEN '9999-12-31' ELSE v.Hasta END)
               <  (CASE WHEN t.Hasta = '1753-01-01' THEN '9999-12-31' ELSE t.Hasta END)
            THEN v.Hasta ELSE t.Hasta END,
       t.ValorBC,
       v.ValorBC
FROM   #Cat t
JOIN   #Conv v
       ON  v.LEGAJO = t.LEGAJO
       AND v.Desde <= (CASE WHEN t.Hasta = '1753-01-01' THEN '9999-12-31' ELSE t.Hasta END)
       AND t.Desde <= (CASE WHEN v.Hasta = '1753-01-01' THEN '9999-12-31' ELSE v.Hasta END);

SELECT TipoAtributo, COUNT(*) AS Filas, COUNT(DISTINCT Legajo) AS Legajos
FROM   #Atributos GROUP BY TipoAtributo;

-- 2.e OFICIALES SIN FLOTA CONOCIDA. Son los que el 2.b.2 no pudo resolver: tienen vigencias OF en
--     Meta4 pero ningún estado con un buque identificable, así que no hay de dónde sacar si son
--     de tangoneros o de poteros. No entran —ni el convenio ni su categoría— y quedan acá.
SELECT COUNT(DISTINCT o.LEGAJO) AS OficialesSinFlota
FROM   #ConvOF o
WHERE  NOT EXISTS (SELECT 1 FROM #Flota f WHERE f.Legajo = o.LEGAJO);

------------------------------------------------------------------------------------------------
-- 3. PRE-VUELO — todo tiene que dar CERO filas
------------------------------------------------------------------------------------------------

-- 3.a EL PAR (convenio, categoría) QUE NO EXISTE EN BC. Es el bloqueante principal: el INSERT entra
--     por SQL y no ejecuta ValidarValorExiste, así que un par inexistente entra igual y revienta
--     recién al liquidar. Acá caen también los dos empleados con el dato inconsistente en Meta4
--     —convenio MR con categoría OF01, convenio DE con categoría MR05—.
--
--     ADEMÁS DE CONTROL, ES LA LISTA DE TRABAJO DEL CATÁLOGO. Se migra el historial COMPLETO, no
--     sólo lo de los activos, así que hacen falta todas las categorías que alguna vez se usaron —no
--     las 18 de FA que están vigentes hoy, sino las 58—. Y no es sólo el personal de tierra: Meta4
--     tiene FE04 (Marinero Español) y FE05 (Control de Calidad) que BC no tiene, aunque nadie los
--     use desde 2017.
--
--     Correr esto ANTES de crear nada: devuelve exactamente qué falta y cuánta gente afecta, y así
--     se cargan de una vez en vez de descubrirlas de a una. Si alguna sale con un solo empleado y
--     fecha de los noventa, también es válido no crearla y dejar esa fila afuera —el bloque 4 no la
--     inserta— siempre que sea una decisión y no una sorpresa.
SELECT a.TipoAtributo, a.ValorPadre, a.Valor, COUNT(*) AS Filas, COUNT(DISTINCT a.Legajo) AS Legajos
FROM   #Atributos a
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Valor Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v
                   WHERE v.[Cód_ Tipo Atributo] = a.TipoAtributo
                     AND v.[Cód_ Valor Padre]   = a.ValorPadre
                     AND v.[Código]             = a.Valor)
GROUP  BY a.TipoAtributo, a.ValorPadre, a.Valor
ORDER  BY 4 DESC;

-- 3.b LEGAJOS QUE NO EXISTEN COMO EMPLOYEE. Meta4 tiene 6.490 con convenio y BC 4.806 empleados.
SELECT COUNT(DISTINCT a.Legajo) AS LegajosInexistentes, COUNT(*) AS Filas
FROM   #Atributos a
WHERE  NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] emp
                   WHERE emp.[No_] = a.Legajo);

-- 3.c CATEGORÍAS QUE NINGÚN CONVENIO CUBRE. No entran; acá se ve quiénes y cuántas.
SELECT COUNT(*) AS TramosSinConvenio, COUNT(DISTINCT t.LEGAJO) AS Legajos
FROM   #Cat t
WHERE  NOT EXISTS (SELECT 1 FROM #Conv v
                   WHERE v.LEGAJO = t.LEGAJO
                     AND v.Desde <= (CASE WHEN t.Hasta = '1753-01-01' THEN '9999-12-31' ELSE t.Hasta END)
                     AND t.Desde <= (CASE WHEN v.Hasta = '1753-01-01' THEN '9999-12-31' ELSE v.Hasta END));

-- 3.d SUPERPOSICIONES DENTRO DEL MISMO TIPO. La tabla las rechaza; por SQL entrarían igual y
--     ValorParaLiquidacion elegiría una de las dos sin criterio. Tiene que dar CERO.
WITH Ord AS (
    SELECT TipoAtributo, Legajo, Desde, Hasta,
           LEAD(Desde) OVER (PARTITION BY TipoAtributo, Legajo ORDER BY Desde) AS Siguiente
    FROM   #Atributos
)
SELECT TipoAtributo, Legajo, Desde, Hasta, Siguiente
FROM   Ord
WHERE  Siguiente IS NOT NULL
  AND  Hasta <> '1753-01-01'
  AND  Hasta >= Siguiente
ORDER  BY TipoAtributo, Legajo, Desde;

-- 3.e VIGENCIAS INVERTIDAS: fin anterior al inicio. Salen de la intersección cuando los dos
--     intervalos se tocan en un solo día por los bordes. Tiene que dar CERO.
SELECT COUNT(*) AS VigenciasInvertidas
FROM   #Atributos
WHERE  Hasta <> '1753-01-01' AND Hasta < Desde;

-- 3.f CHOQUES CON LO QUE YA ESTÁ CARGADO (103 convenios y 95 categorías al 13/9/2026).
SELECT a.TipoAtributo,
       CASE WHEN at.[Cód_ Valor] = a.Valor THEN 'Ya cargada, mismo valor'
            ELSE 'CHOQUE: mismo inicio, valor distinto' END AS Tipo,
       COUNT(*) AS Filas
FROM   #Atributos a
JOIN   [dbo].[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] at
       ON  at.[Tipo Entidad]       = 0
       AND at.[Cód_ Entidad]       = a.Legajo
       AND at.[Cód_ Tipo Atributo] = a.TipoAtributo
       AND at.[Vigencia Desde]     = a.Desde
GROUP  BY a.TipoAtributo,
         CASE WHEN at.[Cód_ Valor] = a.Valor THEN 'Ya cargada, mismo valor'
              ELSE 'CHOQUE: mismo inicio, valor distinto' END;

------------------------------------------------------------------------------------------------
-- 3.g LA CARGA DE ARRANQUE QUE HAY QUE SACAR ANTES DE INSERTAR
--
--     Al 13/9/2026 había 198 atributos de empleado cargados a mano: 103 de convenio y 95 de
--     categoría. Mirando quién y cuándo los creó, casi todos salieron de UNA tanda el 15/8/2026 a
--     las 21:30, y el resto de a uno entre el 16 y el 24 de agosto. Todos con "Vigencia Desde"
--     2026-01-01 y sin cerrar. Es la carga mínima que se hizo para poder probar la liquidación,
--     no historia real: el 3.f encontró apenas TRES que coinciden en fecha con una vigencia de
--     Meta4.
--
--     POR QUÉ NO ALCANZA CON EL "NOT EXISTS" DEL BLOQUE 4. Ese filtro compara por fecha de inicio,
--     así que sólo frena esas tres. Las otras 195 tienen una fecha que no corresponde a ningún
--     cambio real, entrarían a convivir con el historial migrado y se superpondrían con él.
--     ValorParaLiquidacion hace FindLast sobre la vigencia que empezó antes de la fecha de
--     referencia: ganaría la de fecha más tardía, que es la inventada, y sin que nada lo señale.
--
--     POR QUÉ NO SE BORRAN TODAS. Los legajos 80xxx y 90xxx no están en Meta4 —la numeración de
--     allá llega hasta 04xxx y 30xxx— así que son administrativos que existen SÓLO en BC. Su
--     carga manual es el único dato que tienen. Borrarla los deja sin par y sin liquidar.
--
--     La regla es borrar sólo las de la gente cuyo historial está por entrar. Para los demás, la
--     carga de arranque sigue siendo lo mejor que hay.
------------------------------------------------------------------------------------------------

-- 3.g.1 Cuántas se borrarían y cuántas se conservan. Mirar ANTES de borrar.
--
--       La clasificación va en una CTE. Repetir el CASE con su EXISTS en el GROUP BY es el Msg 144
--       ("Cannot use an aggregate or a subquery in an expression used for the group by list"), que
--       en esta migración ya apareció cuatro veces: SQL Server no lo acepta ni aunque el CASE sea
--       idéntico al del SELECT.
WITH Clasificada AS (
    SELECT at.[Cód_ Tipo Atributo] AS Tipo,
           at.[Cód_ Entidad]       AS Legajo,
           CASE WHEN EXISTS (SELECT 1 FROM #Atributos a WHERE a.Legajo = at.[Cód_ Entidad])
                THEN 'Se borra: el historial de Meta4 la reemplaza'
                ELSE 'Se conserva: el legajo no está en Meta4' END AS Destino
    FROM [dbo].[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] at
    WHERE at.[Tipo Entidad] = 0
      AND at.[Cód_ Tipo Atributo] IN ('CONVENIO','CATEGORIA')
)
SELECT Destino, Tipo, COUNT(*) AS Filas, COUNT(DISTINCT Legajo) AS Legajos
FROM   Clasificada
GROUP  BY Destino, Tipo
ORDER  BY Destino, Tipo;

-- 3.g.2 EL BORRADO. Descomentar después de mirar el 3.g.1, y correrlo en la MISMA transacción que
--       el bloque 4: entre el DELETE y el INSERT esa gente no tiene par, y si algo falla en el
--       medio y se comitea igual, quedan peor que antes de empezar.
/*
DELETE at
FROM [dbo].[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] at
WHERE at.[Tipo Entidad] = 0
  AND at.[Cód_ Tipo Atributo] IN ('CONVENIO','CATEGORIA')
  AND EXISTS (SELECT 1 FROM #Atributos a WHERE a.Legajo = at.[Cód_ Entidad]);

PRINT 'Atributos de arranque borrados: ' + CAST(@@ROWCOUNT AS varchar(10));
*/

------------------------------------------------------------------------------------------------
-- 4. LA INSERCIÓN — descomentar después de que el bloque 3 dé cero
--
--     ORDEN OBLIGATORIO: primero los convenios, después las categorías. No por el INSERT en sí
--     —entra todo junto— sino porque si algo falla a mitad y se comitea igual, un convenio sin su
--     categoría deja a la persona liquidando con el básico equivocado, mientras que una categoría
--     sin convenio no resuelve y el motor avisa. Se prefiere el error visible.
--
--     OJO CON LA TRANSACCIÓN ABIERTA: entre el INSERT y el COMMIT, BC no puede guardar nada que
--     toque esta tabla, y el usuario ve un error que no menciona a SQL por ningún lado.
------------------------------------------------------------------------------------------------
SELECT @@TRANCOUNT AS TransaccionesAbiertasEnEstaSesion;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

/*
BEGIN TRANSACTION;

INSERT INTO [dbo].[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    -- Sin [Descripción Valor] ni [Tipo Dato]: son FlowFields y no existen como columna.
    ([Tipo Entidad], [Cód_ Entidad], [Cód_ Tipo Atributo], [Vigencia Desde], [Vigencia Hasta],
     [Cód_ Valor], [Cód_ Valor Padre], [Valor Decimal], [Valor Texto], [Valor Fecha],
     [Valor Numérico],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT 0,                                  -- Tipo Entidad = Empleado
       a.Legajo,
       a.TipoAtributo,
       a.Desde,
       a.Hasta,
       a.Valor,
       a.ValorPadre,
       0, '', '1753-01-01',
       -- Lo que haría RecalcularValorNumerico: los dos tipos son de Tipo Dato Lista, así que el
       -- número sale del valor del catálogo. Queda CONGELADO a propósito — si mañana cambia el
       -- número del valor, una liquidación vieja se recalcula con el que efectivamente usó.
       ISNULL(v.[Valor Numérico], 0),
       NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
                SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM   #Atributos a
JOIN   [dbo].[ArbuTest$Valor Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v
       ON  v.[Cód_ Tipo Atributo] = a.TipoAtributo
       AND v.[Cód_ Valor Padre]   = a.ValorPadre
       AND v.[Código]             = a.Valor
WHERE  EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] emp
               WHERE emp.[No_] = a.Legajo)
  AND  (a.Hasta = '1753-01-01' OR a.Hasta >= a.Desde)
  AND  NOT EXISTS (SELECT 1 FROM [dbo].[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] at
                   WHERE at.[Tipo Entidad]       = 0
                     AND at.[Cód_ Entidad]       = a.Legajo
                     AND at.[Cód_ Tipo Atributo] = a.TipoAtributo
                     AND at.[Vigencia Desde]     = a.Desde);

PRINT 'Atributos insertados: ' + CAST(@@ROWCOUNT AS varchar(10));

-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/

------------------------------------------------------------------------------------------------
-- 5. VERIFICACIÓN POSTERIOR
------------------------------------------------------------------------------------------------

-- 5.a Lo que quedó cargado.
SELECT [Cód_ Tipo Atributo], COUNT(*) AS Filas, COUNT(DISTINCT [Cód_ Entidad]) AS Legajos
FROM [dbo].[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE [Tipo Entidad] = 0
GROUP BY [Cód_ Tipo Atributo];

-- 5.b EL CONTROL QUE IMPORTA: cuántos empleados con fase de alta abierta resuelven hoy su par.
--     Es la pregunta que originó todo esto. Los que no resuelvan no liquidan.
WITH Activos AS (
    SELECT DISTINCT f.[No_ Empleado] AS Legajo
    FROM [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] f
    WHERE f.[Fecha Baja] = '1753-01-01'
),
Resuelve AS (
    SELECT a.Legajo,
           MAX(CASE WHEN at.[Cód_ Tipo Atributo] = 'CONVENIO'  THEN 1 ELSE 0 END) AS TieneConvenio,
           MAX(CASE WHEN at.[Cód_ Tipo Atributo] = 'CATEGORIA' THEN 1 ELSE 0 END) AS TieneCategoria
    FROM   Activos a
    LEFT JOIN [dbo].[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] at
           ON  at.[Tipo Entidad]   = 0
           AND at.[Cód_ Entidad]   = a.Legajo
           AND at.[Vigencia Desde] <= CAST(GETDATE() AS date)
           AND (at.[Vigencia Hasta] = '1753-01-01' OR at.[Vigencia Hasta] >= CAST(GETDATE() AS date))
    GROUP  BY a.Legajo
)
SELECT CASE WHEN TieneConvenio = 1 AND TieneCategoria = 1 THEN 'Resuelve el par completo'
            WHEN TieneConvenio = 1                        THEN 'Convenio sí, categoría no'
            ELSE                                               'NO RESUELVE — no liquida' END AS Situacion,
       COUNT(*) AS Legajos
FROM   Resuelve
GROUP  BY CASE WHEN TieneConvenio = 1 AND TieneCategoria = 1 THEN 'Resuelve el par completo'
               WHEN TieneConvenio = 1                        THEN 'Convenio sí, categoría no'
               ELSE                                               'NO RESUELVE — no liquida' END;
-- Antes de esta migración: 103 y 95 sobre ~330 activos. Después tiene que quedar sólo el personal
-- de tierra en "NO RESUELVE" — los 108 de FA, JO y CA que esperan al paso 5.b.

-- 5.c Superposiciones en la tabla real. Tiene que dar CERO.
WITH Ord AS (
    SELECT [Cód_ Entidad] AS Legajo, [Cód_ Tipo Atributo] AS Tipo,
           [Vigencia Desde] AS Desde, [Vigencia Hasta] AS Hasta,
           LEAD([Vigencia Desde]) OVER (PARTITION BY [Cód_ Entidad], [Cód_ Tipo Atributo]
                                        ORDER BY [Vigencia Desde]) AS Siguiente
    FROM [dbo].[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    WHERE [Tipo Entidad] = 0
)
SELECT Tipo, Legajo, Desde, Hasta, Siguiente
FROM   Ord
WHERE  Siguiente IS NOT NULL AND Hasta <> '1753-01-01' AND Hasta >= Siguiente
ORDER  BY Tipo, Legajo, Desde;

-- 5.d Categorías cuyo padre no es el convenio vigente a esa fecha. Tiene que dar CERO: es lo que
--     el trigger habría garantizado con ResolverValorPadre.
SELECT TOP 50 cat.[Cód_ Entidad], cat.[Vigencia Desde], cat.[Cód_ Valor] AS Categoria,
       cat.[Cód_ Valor Padre] AS PadreGuardado,
       (SELECT TOP 1 conv.[Cód_ Valor]
        FROM [dbo].[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] conv
        WHERE conv.[Tipo Entidad] = 0
          AND conv.[Cód_ Entidad] = cat.[Cód_ Entidad]
          AND conv.[Cód_ Tipo Atributo] = 'CONVENIO'
          AND conv.[Vigencia Desde] <= cat.[Vigencia Desde]
          AND (conv.[Vigencia Hasta] = '1753-01-01' OR conv.[Vigencia Hasta] >= cat.[Vigencia Desde])
        ORDER BY conv.[Vigencia Desde] DESC) AS PadreVigente
FROM [dbo].[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] cat
WHERE cat.[Tipo Entidad] = 0 AND cat.[Cód_ Tipo Atributo] = 'CATEGORIA'
  AND cat.[Cód_ Valor Padre] <> ISNULL((SELECT TOP 1 conv.[Cód_ Valor]
        FROM [dbo].[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] conv
        WHERE conv.[Tipo Entidad] = 0
          AND conv.[Cód_ Entidad] = cat.[Cód_ Entidad]
          AND conv.[Cód_ Tipo Atributo] = 'CONVENIO'
          AND conv.[Vigencia Desde] <= cat.[Vigencia Desde]
          AND (conv.[Vigencia Hasta] = '1753-01-01' OR conv.[Vigencia Hasta] >= cat.[Vigencia Desde])
        ORDER BY conv.[Vigencia Desde] DESC), '');
