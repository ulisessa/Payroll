/*
    MAPEO — puesto de Meta4 (M4T_PUESTOS) -> categoría del CCT de BC.

    PARA QUÉ. El puesto es el eje que valoriza la PRODUCCIÓN; la categoría del CCT
    valoriza el sueldo. Son listas distintas en Meta4 y la misma lista en BC, así que
    el historial de puestos por empleado se va a guardar usando códigos de categoría.
    Ver el script hermano ExplorarPuestosMeta4.sql, que trae los datos de Oracle.

    CÓMO SE ARMÓ. Cruzando las descripciones, normalizadas (minúsculas, sin acentos,
    sin puntuación). De los 22 puestos embarcados, 14 dan coincidencia EXACTA. Las
    otras 8 se decidieron a mano y están marcadas abajo con el motivo, porque el
    cruce automático por subcadena se equivoca de forma creíble: puso
    "Contramaestre Argentino" -> MR09 porque "Segundo Contramaestre Argentino" contiene
    esa cadena. Un mapeo de nómina no se deja en manos de un LIKE.

    LOS PUESTOS DE PLANTA EN TIERRA NO ESTÁN ACÁ. Las familias PP, PZ, PD, PN, PM, PF,
    PE, PV, PC, PG, CM, MAE y ADM no embarcan, no cobran producción de marea y su
    convenio no es 729/15. Quedan fuera del alcance de este mapeo.

    LA CATEGORÍA CUELGA DEL CONVENIO. La clave de "Categoría CCT" es (convenio, código)
    y OF01 es Capitán tanto en 175/75 como en 768/19. Este mapeo devuelve SOLO el
    CÓDIGO; el convenio lo sigue resolviendo el atributo CONVENIO a esa fecha, que ya
    está migrado y que para los oficiales sale de la flota del buque, no de Meta4.

    QUÉ PASA CON UN PUESTO SIN MAPEO. Nada: el concepto cae de vuelta en la categoría
    del CCT, que es el comportamiento de hoy. Por eso dejar los cuatro puestos
    españoles sin equivalente es seguro y no hay que inventarles un código.
*/

IF OBJECT_ID('tempdb..#MapaPuesto') IS NOT NULL DROP TABLE #MapaPuesto;

-- COLLATE DATABASE_DEFAULT EN LAS COLUMNAS QUE SE COMPARAN CONTRA TABLAS DE BC. Sin
-- eso, la columna hereda la collation de tempdb y el JOIN contra Categoría CCT falla
-- con "Cannot resolve the collation conflict between Modern_Spanish_CI_AS and
-- Modern_Spanish_100_CI_AS": la collation la define la BASE de BC, no el servidor.
CREATE TABLE #MapaPuesto (
    IdPuesto     nvarchar(10)  COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY,
    DescMeta4    nvarchar(60)  NOT NULL,
    CatBC        nvarchar(10)  COLLATE DATABASE_DEFAULT NULL,  -- NULL = sin equivalente, cae en la del CCT
    Certeza      nvarchar(10)  NOT NULL,   -- exacta | decidida | sin mapeo
    -- nvarchar(max) a propósito: los motivos son prosa y ya truncaron dos veces. Un
    -- INSERT que se pasa de largo no llena la columna a medias, aborta la sentencia
    -- ENTERA y deja la tabla vacía, y entonces todos los controles devuelven NULL sin
    -- que nada diga "el mapeo no se cargó".
    Motivo       nvarchar(max) NULL);

INSERT INTO #MapaPuesto (IdPuesto, DescMeta4, CatBC, Certeza, Motivo) VALUES
-- Las 14 exactas: la descripción de Meta4 y la de BC coinciden palabra por palabra.
('CB01','Capitán',                          'OF01','exacta',   NULL),
('CB02','Patrón de Pesca',                  'FE01','exacta',   NULL),
('CB03','Primer Oficial de Cubierta',       'OF03','exacta',   NULL),
('CB04','Primer Pescador',                  'MR00','exacta',   NULL),
('CB07','Marinero de Cubierta',             'MR05','exacta',   NULL),
('CB10','Segundo Oficial de Cubierta',      'OF05','exacta',   NULL),
('MQ01','Jefe de Máquinas',                 'OF02','exacta',   NULL),
('MQ02','Garantía de Máquinas',             'FE02','exacta',   NULL),
('MQ04','Segundo Oficial de Máquinas',      'OF06','exacta',   NULL),
('MQ05','Engrasador',                       'MR04','exacta',   NULL),
('PT02','Marinero de Planta',               'MR08','exacta',   NULL),
('PT04','Contramaestre de Frío',            'MR07','exacta',   NULL),
('ME02','Mozo',                             'MR03','exacta',   NULL),
('ME03','Enfermero',                        'MR06','exacta',   NULL),

-- Decididas a mano, con evidencia en los datos y no por parecido de texto.
('CB06','Contramaestre Argentino',          'MR01','decidida',
 'BC acorta la descripción a "Contramaestre". Comprobado con datos: el recibo de Meta4 imprime "Contramaestre Argentino" para 03957 y 03961, y el atributo CATEGORIA de los dos en BC es MR01. NO es MR09, que es el segundo.'),
('CB09','Segundo Contramaestre Arg.',       'MR09','decidida',
 'Misma descripción con "Arg." abreviado. Es el par de CB06: uno es el contramaestre y el otro el segundo.'),
('ME01','Cocinero',                         'MR02','decidida',
 'BC lo llama "Primer Cocinero". Comprobado: 04798 embarcó como COCINERO en el rol A28/59, el recibo lo imprime como Primer Cocinero y le pagó producción a índice 85, que es MR02.'),
('MQ03','Primer Oficial de Máquinas',       'OF04','confirmada',
 'CONFIRMADO POR EL USUARIO EL 18/9/2026. Ya estaba determinado por la estructura: la lista de oficiales alterna rama y rango —impares cubierta OF01/OF03/OF05, pares máquinas OF02/OF04/OF06, cada par en el orden jefe/primero/segundo—; en la rama de máquinas MQ01->OF02 y MQ04->OF06 son coincidencias EXACTAS, y el único hueco entre esas dos anclas es el "primero". BC lo llama "Primer Maquinista" en vez de "Primer Oficial de Máquinas". Ver el control 3.c.'),

-- Sin equivalente en BC. Los cuatro son tripulación española y el convenio ESP sólo
-- tiene FE01, FE02 y FE03; hoy FE03 no lo usa NADIE y ESP tiene 4 empleados activos en
-- total. Son históricos: se dejan sin mapear a propósito.
('CB05','Contramaestre de Cubierta Español', NULL,'sin mapeo',
 'El candidato sería FE03 "Contramaestre Español", pero PT01 también, y ESP tiene un solo código de contramaestre. Sin nadie activo, no vale la pena elegir a ciegas.'),
('PT01','Contramaestre de Planta Español',   NULL,'sin mapeo',
 'Mismo caso que CB05: los dos competirían por FE03.'),
('PT03','Control de Calidad Español',        NULL,'sin mapeo',
 'No existe en el convenio ESP de BC.'),
('CB08','Marinero Español',                  NULL,'sin mapeo',
 'No existe en el convenio ESP de BC.');

-- 0. CONTROL · EL MAPEO SE CARGÓ ENTERO. Va primero porque si el INSERT de arriba
--    aborta —por ejemplo, porque un motivo se pasa de largo— la tabla queda VACÍA y
--    todos los controles de abajo devuelven cero filas o NULL, que se lee igual que
--    "no hay problemas". Tiene que dar 22, 18 y 4.
SELECT COUNT(*) AS Puestos,
       SUM(CASE WHEN CatBC IS NOT NULL THEN 1 ELSE 0 END) AS ConCategoria,
       SUM(CASE WHEN CatBC IS NULL THEN 1 ELSE 0 END)     AS SinMapeo
FROM   #MapaPuesto;

-- 1. EL MAPEO, con la descripción que BC tiene para la categoría destino. Sirve de
--    control: si una fila trae CatBC y la descripción sale NULL, el código no existe.
SELECT m.IdPuesto, m.DescMeta4, m.CatBC, m.Certeza,
       (SELECT TOP 1 c.[Descripción]
        FROM   dbo.[ArbuTest$Categoría CCT$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
        WHERE  c.[Código] = m.CatBC)                       AS DescBC,
       (SELECT COUNT(DISTINCT c.[Cód_ Convenio])
        FROM   dbo.[ArbuTest$Categoría CCT$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
        WHERE  c.[Código] = m.CatBC)                       AS EnCuantosConvenios,
       m.Motivo
FROM   #MapaPuesto m
ORDER  BY CASE m.Certeza WHEN 'exacta'     THEN 1
                         WHEN 'confirmada' THEN 2
                         WHEN 'decidida'   THEN 3
                         ELSE 4 END, m.IdPuesto;

-- 2. CONTROL · TODA CATEGORÍA DESTINO TIENE QUE EXISTIR EN BC.
--    Tiene que dar 0 filas.
SELECT m.IdPuesto, m.CatBC, 'la categoría no existe en Categoría CCT' AS Problema
FROM   #MapaPuesto m
WHERE  m.CatBC IS NOT NULL
  AND  NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Categoría CCT$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
                   WHERE c.[Código] = m.CatBC);

-- 3. CONTROL · NINGUNA CATEGORÍA RECIBE DOS PUESTOS DISTINTOS. Si pasara, dos puestos
--    con índices distintos colapsarían en el mismo precio y la producción saldría mal
--    justamente en la gente que el mapeo debía separar.
--    Tiene que dar 0 filas.
SELECT m.CatBC, COUNT(*) AS Puestos,
       STUFF((SELECT ', ' + x.IdPuesto FROM #MapaPuesto x
              WHERE x.CatBC = m.CatBC ORDER BY x.IdPuesto FOR XML PATH('')),1,2,'') AS Cuales
FROM   #MapaPuesto m
WHERE  m.CatBC IS NOT NULL
GROUP  BY m.CatBC HAVING COUNT(*) > 1;

-- 3.b CONTROL · LA CATEGORÍA DESTINO TIENE QUE EXISTIR EN LOS DOS CONVENIOS DE
--     OFICIALES. Como la clave es (convenio, código), un oficial que cambia de flota
--     cambia de convenio, y si el código no existe en el convenio nuevo el par no
--     resuelve. Hoy da UNA fila: OF06 "Segundo Oficial de Máquinas" está en 768/19 y no
--     en 175/75, así que un MQ04 embarcado en un tangonero se queda sin categoría.
--     No lo arregla este script —es un alta en Categoría CCT— pero tiene que estar a la
--     vista antes de migrar.
SELECT DISTINCT m.IdPuesto, m.CatBC, 'falta en 175/75' AS Problema
FROM   #MapaPuesto m
WHERE  m.CatBC LIKE 'OF%'
  AND  EXISTS (SELECT 1 FROM dbo.[ArbuTest$Categoría CCT$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
               WHERE c.[Código] = m.CatBC AND c.[Cód_ Convenio] = '768/19')
  AND  NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Categoría CCT$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
                   WHERE c.[Código] = m.CatBC AND c.[Cód_ Convenio] = '175/75');

-- 3.c CONTROL · LA ESCALERA DE OFICIALES, que es lo que sostiene MQ03 -> OF04 sin
--     tener que preguntarle a nadie. Las seis categorías de 768/19 tienen que alternar
--     rama —impares cubierta, pares máquinas— y recorrer los tres rangos en orden.
--     Si eso se cumple, la posición de cada puesto de Meta4 en su propia escalera
--     determina la categoría, y MQ03 sólo puede ser OF04.
--     Tienen que salir 6 filas, alternando CUBIERTA/MÁQUINAS y con Rango 1,1,2,2,3,3.
SELECT c.[Código] AS Cat, c.[Descripción] AS Descripcion,
       CASE WHEN CAST(RIGHT(c.[Código],2) AS int) % 2 = 1 THEN 'CUBIERTA' ELSE 'MÁQUINAS' END AS Rama,
       CASE WHEN c.[Descripción] LIKE 'Capitan%' OR c.[Descripción] LIKE 'Jefe%' THEN 1
            WHEN c.[Descripción] LIKE 'Primer%'                                  THEN 2
            WHEN c.[Descripción] LIKE 'Segundo%'                                 THEN 3
            ELSE 0 END AS Rango,
       (SELECT TOP 1 m.IdPuesto FROM #MapaPuesto m WHERE m.CatBC = c.[Código]) AS PuestoMeta4
FROM   dbo.[ArbuTest$Categoría CCT$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
WHERE  c.[Cód_ Convenio] = '768/19'
ORDER  BY c.[Código];

-- 4. CONTROL DE PUNTA A PUNTA CONTRA LA MAREA A28/59.
--
--    Los puestos son DATO DE META4 —consulta 3 de ExplorarPuestosMeta4.sql, corrida el
--    18/9/2026— y los importes son DATO DEL RECIBO, así que el control no es circular:
--    cierra la cadena entera puesto -> categoría -> VALOR_CAL_ENT -> producción contra
--    lo que la empresa efectivamente pagó.
--
--    Dio 26 de 26 al centavo, incluidos los seis en los que el puesto y la categoría
--    del CCT difieren. Y de paso resolvió la duda de COLMAN (04169): el rol de entrada
--    lo llama CONTRA / PLANTA igual que a MOLINA, pero su puesto en Meta4 es PT02
--    Marinero de Planta, índice 70 — que es lo que le pagaron. La columna CARGO del rol
--    describe la tarea a bordo, NO el puesto de nómina. No había nada que reclamar.
--
--    Tiene que dar 26 filas con Coincide = 'sí'.
;WITH Real_ AS (
    SELECT * FROM (VALUES
        ('03753','PT02',10000), ('03772','MQ05',10714), ('03774','PT04',11429),
        ('03957','CB04',14286), ('03961','CB06',12143), ('04066','CB07',10714),
        ('04091','PT02',10000), ('04105','CB07',10714), ('04169','PT02',10000),
        ('04274','PT02',10000), ('04301','PT02',10000), ('04368','PT02',10000),
        ('04517','PT02',10000), ('04648','PT02',10000), ('04669','MQ05',10714),
        ('04683','PT02',10000), ('04733','PT02',10000), ('04734','PT02',10000),
        ('04738','PT02',10000), ('04789','ME02',11429), ('04798','ME01',12143),
        ('04880','PT02',10000), ('04913','CB04',14286), ('04914','CB07',10714),
        ('04915','CB07',10714), ('04918','PT02',10000)) v(Leg, Puesto, TonRecibo))
SELECT r.Leg, r.Puesto, m.DescMeta4, m.CatBC AS CategoriaDelMapeo,
       CAST(v.[Valor] AS decimal(18,2)) AS TonDelMapeo,
       r.TonRecibo,
       CAST(633.639 * v.[Valor] AS decimal(18,2)) AS ProduccionCalculada,
       CASE WHEN v.[Valor] = r.TonRecibo THEN 'sí' ELSE 'NO' END AS Coincide
FROM   Real_ r
JOIN   #MapaPuesto m ON m.IdPuesto = r.Puesto
LEFT   JOIN dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] v
       ON  v.[Cód_ Parámetro Base] = 'VALOR_CAL_ENT' AND v.[Cód_ Convenio] = '729/15'
       AND v.[Cód_ Categoría] = m.CatBC AND v.[Vigencia Desde] = '2026-01-01'
ORDER  BY CASE WHEN v.[Valor] = r.TonRecibo THEN 1 ELSE 0 END, r.Leg;
GO
