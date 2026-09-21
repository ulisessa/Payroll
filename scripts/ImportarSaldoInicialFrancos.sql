/* ============================================================================
   Carga del SALDO INICIAL DE FRANCOS al 31/12/2025
   Origen: "Saldo francos 31-12-25.xlsx"  ·  Destino: Saldo Inicial Francos Liq.

   214 filas en el archivo, de las cuales 74 tienen saldo > 0 y suman 4.279 días.
   Las de saldo 0 NO se cargan: una fila en cero no es un lote, y "Aplicar" la
   rechazaría de todas formas (ValidarFila corta con Días = 0).

   ESTO NO APLICA NADA. Deja las filas en la hoja de carga, sin tocar el ledger
   de francos. Aplicarlas —que es lo que genera los lotes— se hace después desde
   la página "Saldo Inicial de Francos", con su botón, y es reversible.

   --------------------------------------------------------------------------
   DE DÓNDE SALE CADA DATO

   CATEGORÍA: del PUESTO del archivo, traducido a código en el bloque 1.b.
      NO de los atributos del empleado. Es una decisión con consecuencia directa
      en plata: el lote se paga al valor de SU categoría, y el saldo se ganó en
      el puesto que dice el papel, no en el encuadre que el tripulante tiene hoy.
      Los dos difieren en 19 de los 74 casos — cinco Marineros de Cubierta que
      figuran como Marineros de Planta, dos Primeros Pescadores como Marineros,
      un Mozo como Marinero de Cubierta.

   CONVENIO: de los ATRIBUTOS del empleado vigentes al 31/12/2025. El archivo no
      lo trae, y es el único dato que no está. El bloque 2.e verifica que el par
      (convenio del atributo + categoría del archivo) exista de verdad como
      Categoría CCT; si no existe, esa fila no se carga y aparece listada.

   FECHA DE DEVENGO: 31/12/2025 para todos. Es el saldo a esa fecha; no hay forma
      de saber en qué categoría se ganó cada día de los 4.279. Todos los lotes
      iniciales quedan entonces en el mismo lugar de la cola FIFO, y detrás de
      cualquier franco que el sistema devengue a partir de 2026 — que es lo
      correcto: primero se consume lo más viejo.

   LEGAJO: el archivo los trae con 3 y 4 dígitos (191, 4526) y BC los tiene con 5
      (00191, 04526). Se rellenan con ceros a la izquierda.
   ========================================================================== */


/* ---------------------------------------------------------------------------
   BLOQUE 0 — Confirmar los nombres reales de las tablas en SQL.
   Ya verificados el 17/9/2026 contra ArbuTest; si cambia la empresa o el id de
   la extensión, hay que ajustarlos en todo el script.
--------------------------------------------------------------------------- */
SELECT name
FROM   sys.tables
WHERE  name LIKE '%Saldo Inicial Francos%'
    OR name LIKE '%Atributo Entidad Liq%'
    OR name LIKE '%Categor_a CCT%'
ORDER  BY name;
GO


/* ---------------------------------------------------------------------------
   BLOQUE 1 — Tabla puente con el contenido del Excel.
   Las filas se cargan con ImportarSaldoInicialFrancos_Datos.sql, que trae las
   214 como INSERT y evita el asistente de importación.
--------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.MIG_SaldoFrancos') IS NOT NULL
    DROP TABLE dbo.MIG_SaldoFrancos;
GO

CREATE TABLE dbo.MIG_SaldoFrancos (
    [Legajo]              nvarchar(20)  NULL,
    [Apellido_y_Nombres]  nvarchar(200) NULL,
    [CUIL]                nvarchar(20)  NULL,
    [Ingreso]             nvarchar(20)  NULL,
    [Puesto]              nvarchar(100) NULL,
    [Estado]              nvarchar(50)  NULL,
    [Buque]               nvarchar(20)  NULL,
    [Saldo francos]       nvarchar(20)  NULL
);
GO


/* ---------------------------------------------------------------------------
   BLOQUE 1.b — Traducción del PUESTO del archivo a código de categoría.

   Va como tabla y no como CASE a propósito: es una decisión de negocio, se lee
   de un vistazo, y corregir una línea no obliga a releer una consulta.

   NO se hace por descripción automáticamente. Los textos no coinciden —el
   archivo dice "Jefe de Máquinas" y la categoría se llama "Jefe de Maquinas",
   sin acento; dice "Cocinero" y la categoría es "Primer Cocinero"— así que un
   match por texto dejaría afuera justo a los que parecen iguales, y peor: podría
   emparejar mal a los que se parecen entre sí.

   Los once puestos son los que efectivamente tienen saldo > 0 en el archivo.
   REVISÁ EL PAR DE LA ÚLTIMA FILA: "Primer Oficial de Máquinas" es el único que
   no tiene una categoría con el mismo título; OF04 se llama "Primer Maquinista".
--------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.MIG_PuestoCategoria') IS NOT NULL
    DROP TABLE dbo.MIG_PuestoCategoria;
GO

CREATE TABLE dbo.MIG_PuestoCategoria (
    [Puesto]    nvarchar(100) NOT NULL PRIMARY KEY,
    [Categoria] nvarchar(20)  NOT NULL
);
GO

INSERT INTO dbo.MIG_PuestoCategoria ([Puesto], [Categoria]) VALUES
    (N'Capitán',                     N'OF01'),
    (N'Cocinero',                    N'MR02'),
    (N'Contramaestre Argentino',     N'MR01'),
    (N'Contramaestre de Frío',       N'MR07'),
    (N'Engrasador',                  N'MR04'),
    (N'Jefe de Máquinas',            N'OF02'),
    (N'Marinero de Cubierta',        N'MR05'),
    (N'Marinero de Planta',          N'MR08'),
    (N'Mozo',                        N'MR03'),
    (N'Primer Pescador',             N'MR00'),
    (N'Primer Oficial de Máquinas',  N'OF04');
GO


/* ---------------------------------------------------------------------------
   BLOQUE 2 — Controles. NINGUNO de estos escribe nada.
   Correlos todos antes del bloque 3 y no sigas con ninguno que dé filas.
--------------------------------------------------------------------------- */

-- 2.a  Resumen contra el archivo: 214 / 74 / 4.279 / 0.
SELECT COUNT(*)                                                       AS Filas,
       SUM(CASE WHEN TRY_CONVERT(decimal(18,2), [Saldo francos]) > 0
                THEN 1 ELSE 0 END)                                    AS ConSaldo,
       SUM(CASE WHEN TRY_CONVERT(decimal(18,2), [Saldo francos]) > 0
                THEN TRY_CONVERT(decimal(18,2), [Saldo francos]) END) AS TotalDias,
       SUM(CASE WHEN TRY_CONVERT(decimal(18,2), [Saldo francos]) IS NULL
                THEN 1 ELSE 0 END)                                    AS SaldoNoNumerico
FROM   dbo.MIG_SaldoFrancos;
GO

-- 2.b  Legajos con saldo que NO existen en BC. Cada uno es un tripulante cuyos
--      francos se pierden en la carga. Tiene que dar CERO.
SELECT m.[Legajo],
       RIGHT('00000' + LTRIM(RTRIM(m.[Legajo])), 5) AS LegajoBC,
       m.[Apellido_y_Nombres],
       m.[Saldo francos]
FROM   dbo.MIG_SaldoFrancos m
WHERE  TRY_CONVERT(decimal(18,2), m.[Saldo francos]) > 0
   AND NOT EXISTS (SELECT 1 FROM dbo.[ArbuTest$Employee$437dbf0e-84ff-417a-965d-ed2bb9650972] e
                   WHERE  e.[No_] = RIGHT('00000' + LTRIM(RTRIM(m.[Legajo])), 5))
ORDER  BY m.[Legajo];
GO

-- 2.c  Puestos con saldo que NO están en la tabla de traducción. Cada uno es un
--      grupo entero de tripulantes que quedaría afuera. Tiene que dar CERO.
SELECT m.[Puesto], COUNT(*) AS Tripulantes,
       SUM(TRY_CONVERT(decimal(18,2), m.[Saldo francos])) AS Dias
FROM   dbo.MIG_SaldoFrancos m
WHERE  TRY_CONVERT(decimal(18,2), m.[Saldo francos]) > 0
   AND NOT EXISTS (SELECT 1 FROM dbo.MIG_PuestoCategoria p WHERE p.[Puesto] = m.[Puesto])
GROUP  BY m.[Puesto]
ORDER  BY 2 DESC;
GO

-- 2.d  Empleados con saldo SIN convenio vigente al 31/12/2025 en sus atributos.
--      Sin convenio no se puede armar el par, así que no se cargan. Tiene que
--      dar CERO; si da filas, hay que cargarles el atributo primero.
WITH Conv AS (
    SELECT a.[Cód_ Entidad] AS Legajo, a.[Cód_ Valor] AS Valor,
           ROW_NUMBER() OVER (PARTITION BY a.[Cód_ Entidad]
                              ORDER BY a.[Vigencia Desde] DESC) AS rn
    FROM   dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
    JOIN   dbo.[ArbuTest$Tipo Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]   t
           ON t.[Código] = a.[Cód_ Tipo Atributo]
    WHERE  a.[Tipo Entidad] = 0 AND t.[Espejo De] = 1     -- 1 = espejo de Convenio Colectivo
      AND  a.[Vigencia Desde] <= '2025-12-31'
      AND (a.[Vigencia Hasta] = '1753-01-01' OR a.[Vigencia Hasta] >= '2025-12-31')
)
SELECT RIGHT('00000' + LTRIM(RTRIM(m.[Legajo])), 5) AS LegajoBC,
       m.[Apellido_y_Nombres], m.[Puesto], m.[Saldo francos]
FROM   dbo.MIG_SaldoFrancos m
LEFT   JOIN Conv cv ON cv.Legajo = RIGHT('00000' + LTRIM(RTRIM(m.[Legajo])), 5) AND cv.rn = 1
WHERE  TRY_CONVERT(decimal(18,2), m.[Saldo francos]) > 0
   AND cv.Valor IS NULL
ORDER  BY m.[Legajo];
GO

-- 2.e  EL CONTROL QUE IMPORTA AHORA: pares (convenio del atributo + categoría
--      del archivo) que NO existen como Categoría CCT.
--
--      Aparece cuando el tripulante está encuadrado en un convenio que no tiene
--      esa categoría — un mensualizado que embarcó, por ejemplo. Esas filas no
--      se pueden cargar: el lote no tendría con qué valuarse. Tiene que dar CERO.
WITH Conv AS (
    SELECT a.[Cód_ Entidad] AS Legajo, a.[Cód_ Valor] AS Valor,
           ROW_NUMBER() OVER (PARTITION BY a.[Cód_ Entidad]
                              ORDER BY a.[Vigencia Desde] DESC) AS rn
    FROM   dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
    JOIN   dbo.[ArbuTest$Tipo Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]   t
           ON t.[Código] = a.[Cód_ Tipo Atributo]
    WHERE  a.[Tipo Entidad] = 0 AND t.[Espejo De] = 1
      AND  a.[Vigencia Desde] <= '2025-12-31'
      AND (a.[Vigencia Hasta] = '1753-01-01' OR a.[Vigencia Hasta] >= '2025-12-31')
)
SELECT RIGHT('00000' + LTRIM(RTRIM(m.[Legajo])), 5) AS LegajoBC,
       m.[Apellido_y_Nombres], m.[Puesto], p.[Categoria], cv.Valor AS Convenio,
       m.[Saldo francos] AS Dias
FROM   dbo.MIG_SaldoFrancos m
JOIN   dbo.MIG_PuestoCategoria p ON p.[Puesto] = m.[Puesto]
JOIN   Conv cv ON cv.Legajo = RIGHT('00000' + LTRIM(RTRIM(m.[Legajo])), 5) AND cv.rn = 1
WHERE  TRY_CONVERT(decimal(18,2), m.[Saldo francos]) > 0
   AND NOT EXISTS (
           SELECT 1 FROM dbo.[ArbuTest$Categoría CCT$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
           WHERE  c.[Cód_ Convenio] = cv.Valor AND c.[Código] = p.[Categoria])
ORDER  BY m.[Puesto], m.[Legajo];
GO

-- 2.f  Informativo, no bloqueante: dónde la categoría del ARCHIVO difiere de la
--      que el empleado tiene cargada como atributo. Son los casos en que esta
--      carga le va a valuar los francos a un valor distinto del de su encuadre
--      actual — que es exactamente lo que se decidió que corresponde, pero
--      conviene tener la lista a mano por si alguien pregunta.
WITH Atrib AS (
    SELECT a.[Cód_ Entidad] AS Legajo, t.[Espejo De] AS Espejo, a.[Cód_ Valor] AS Valor,
           ROW_NUMBER() OVER (PARTITION BY a.[Cód_ Entidad], t.[Espejo De]
                              ORDER BY a.[Vigencia Desde] DESC) AS rn
    FROM   dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
    JOIN   dbo.[ArbuTest$Tipo Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]   t
           ON t.[Código] = a.[Cód_ Tipo Atributo]
    WHERE  a.[Tipo Entidad] = 0 AND t.[Espejo De] = 2     -- 2 = espejo de Categoría CCT
      AND  a.[Vigencia Desde] <= '2025-12-31'
      AND (a.[Vigencia Hasta] = '1753-01-01' OR a.[Vigencia Hasta] >= '2025-12-31')
)
SELECT RIGHT('00000' + LTRIM(RTRIM(m.[Legajo])), 5) AS LegajoBC,
       m.[Apellido_y_Nombres], m.[Puesto], p.[Categoria] AS CategoriaQueSeCarga,
       ct.Valor AS CategoriaDelAtributo, m.[Saldo francos] AS Dias
FROM   dbo.MIG_SaldoFrancos m
JOIN   dbo.MIG_PuestoCategoria p ON p.[Puesto] = m.[Puesto]
LEFT   JOIN Atrib ct ON ct.Legajo = RIGHT('00000' + LTRIM(RTRIM(m.[Legajo])), 5) AND ct.rn = 1
WHERE  TRY_CONVERT(decimal(18,2), m.[Saldo francos]) > 0
   AND ISNULL(ct.Valor, '') <> p.[Categoria]
ORDER  BY m.[Puesto], m.[Legajo];
GO


/* ---------------------------------------------------------------------------
   BLOQUE 3 — La carga. Sólo después de que 2.b, 2.c, 2.d y 2.e den cero.

   Es IDEMPOTENTE: el NOT EXISTS contra la clave primaria deja correrlo dos veces
   sin duplicar, y NO pisa una fila existente por si alguien corrigió alguna a
   mano.
--------------------------------------------------------------------------- */
WITH Conv AS (
    SELECT a.[Cód_ Entidad] AS Legajo, a.[Cód_ Valor] AS Valor,
           ROW_NUMBER() OVER (PARTITION BY a.[Cód_ Entidad]
                              ORDER BY a.[Vigencia Desde] DESC) AS rn
    FROM   dbo.[ArbuTest$Atributo Entidad Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] a
    JOIN   dbo.[ArbuTest$Tipo Atributo Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]   t
           ON t.[Código] = a.[Cód_ Tipo Atributo]
    WHERE  a.[Tipo Entidad] = 0 AND t.[Espejo De] = 1
      AND  a.[Vigencia Desde] <= '2025-12-31'
      AND (a.[Vigencia Hasta] = '1753-01-01' OR a.[Vigencia Hasta] >= '2025-12-31')
),
Origen AS (
    SELECT RIGHT('00000' + LTRIM(RTRIM(m.[Legajo])), 5)          AS LegajoBC,
           cv.Valor                                              AS Convenio,
           p.[Categoria]                                         AS Categoria,
           TRY_CONVERT(decimal(18,2), m.[Saldo francos])         AS Dias,
           LEFT(m.[Apellido_y_Nombres], 100)                     AS Nombre,
           LEFT('Saldo al 31/12/2025. Puesto en el archivo: '
                + ISNULL(m.[Puesto], '') + '. Buque: '
                + ISNULL(m.[Buque], '') + '.', 250)              AS Obs
    FROM   dbo.MIG_SaldoFrancos m
    JOIN   dbo.MIG_PuestoCategoria p ON p.[Puesto] = m.[Puesto]
    JOIN   Conv cv ON cv.Legajo = RIGHT('00000' + LTRIM(RTRIM(m.[Legajo])), 5) AND cv.rn = 1
    WHERE  TRY_CONVERT(decimal(18,2), m.[Saldo francos]) > 0
      AND  EXISTS (SELECT 1 FROM dbo.[ArbuTest$Categoría CCT$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
                   WHERE c.[Cód_ Convenio] = cv.Valor AND c.[Código] = p.[Categoria])
)
INSERT INTO dbo.[ArbuTest$Saldo Inicial Francos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
       ([No_ Empleado], [Cód_ Convenio], [Cód_ Categoría], [Fecha Devengo],
        [Días], [Nombre Empleado], [Observaciones], [Aplicado],
        [No_ Liquidación Generada], [No_ Línea Generada], [Valor Franco Estimado])
SELECT o.LegajoBC, o.Convenio, o.Categoria, '2025-12-31',
       o.Dias, o.Nombre, o.Obs, 0,
       '', 0, 0
FROM   Origen o
WHERE  NOT EXISTS (
           SELECT 1
           FROM   dbo.[ArbuTest$Saldo Inicial Francos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] s
           WHERE  s.[No_ Empleado]   = o.LegajoBC
             AND  s.[Cód_ Convenio]  = o.Convenio
             AND  s.[Cód_ Categoría] = o.Categoria
             AND  s.[Fecha Devengo]  = '2025-12-31');
GO


/* ---------------------------------------------------------------------------
   BLOQUE 4 — Verificación. Tiene que dar 74 filas y 4.279 días.
   Si da menos, la diferencia está en 2.b, 2.d o 2.e: son los que quedaron fuera.
--------------------------------------------------------------------------- */
SELECT COUNT(*) AS Filas, SUM([Días]) AS TotalDias
FROM   dbo.[ArbuTest$Saldo Inicial Francos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE  [Fecha Devengo] = '2025-12-31';
GO

-- 4.b  Reparto por categoría, que es lo que decide el valor de cada lote.
--      Contra el recuento por puesto del archivo:
--      Marinero de Planta 17 · Marinero de Cubierta 17 · Engrasador 15 ·
--      Jefe de Máquinas 8 · Mozo 5 · Primer Pescador 3 · 1er Of. Máquinas 2 ·
--      Contramaestre Argentino 2 · Cocinero 2 · Capitán 2 · Contram. de Frío 1
SELECT s.[Cód_ Convenio], s.[Cód_ Categoría], c.[Descripción],
       COUNT(*) AS Tripulantes, SUM(s.[Días]) AS Dias
FROM   dbo.[ArbuTest$Saldo Inicial Francos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] s
LEFT   JOIN dbo.[ArbuTest$Categoría CCT$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
       ON c.[Cód_ Convenio] = s.[Cód_ Convenio] AND c.[Código] = s.[Cód_ Categoría]
WHERE  s.[Fecha Devengo] = '2025-12-31'
GROUP  BY s.[Cód_ Convenio], s.[Cód_ Categoría], c.[Descripción]
ORDER  BY COUNT(*) DESC;
GO

/* ---------------------------------------------------------------------------
   BLOQUE 5 — Diferencias entre lo cargado y el archivo.

   Nació de un caso concreto: el bloque 4 dio las 74 filas esperadas pero 4.288
   días en vez de 4.279. Los recuentos por categoría cerraban todos, así que no
   sobraba ninguna fila — los 9 días de más estaban DENTRO de una.

   La causa es el NOT EXISTS del bloque 3: hace la carga idempotente, pero eso
   mismo significa que una fila que ya existía con esa clave NO se pisa. Si venía
   de una prueba anterior o de una carga a mano, queda con su valor viejo y la
   cuenta total no cierra. Es el precio de no sobrescribir, y es el correcto —
   pero hay que poder verlo.
--------------------------------------------------------------------------- */
WITH Archivo AS (
    SELECT RIGHT('00000' + LTRIM(RTRIM(m.[Legajo])), 5)  AS LegajoBC,
           p.[Categoria]                                 AS Categoria,
           TRY_CONVERT(decimal(18,2), m.[Saldo francos]) AS DiasArchivo,
           m.[Apellido_y_Nombres]                        AS Nombre,
           m.[Puesto]                                    AS Puesto
    FROM   dbo.MIG_SaldoFrancos m
    JOIN   dbo.MIG_PuestoCategoria p ON p.[Puesto] = m.[Puesto]
    WHERE  TRY_CONVERT(decimal(18,2), m.[Saldo francos]) > 0
)
SELECT COALESCE(a.LegajoBC, s.[No_ Empleado])  AS LegajoBC,
       a.Nombre, a.Puesto,
       a.Categoria                             AS CategoriaArchivo,
       s.[Cód_ Categoría]                      AS CategoriaCargada,
       a.DiasArchivo,
       s.[Días]                                AS DiasCargados,
       s.[Días] - a.DiasArchivo                AS Diferencia,
       s.[Aplicado],
       s.[Observaciones]
FROM   Archivo a
FULL   JOIN dbo.[ArbuTest$Saldo Inicial Francos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] s
       ON  s.[No_ Empleado]  = a.LegajoBC
       AND s.[Cód_ Categoría] = a.Categoria
       AND s.[Fecha Devengo] = '2025-12-31'
WHERE  s.[No_ Empleado] IS NULL          -- está en el archivo y no se cargó
    OR a.LegajoBC       IS NULL          -- está cargado y no está en el archivo
    OR s.[Días] <> a.DiasArchivo         -- está en los dos, con distinto saldo
ORDER  BY 1;
GO

-- 5.b  Para corregir SOLO las que difieren, una vez revisadas una por una.
--      Deliberadamente NO está dentro del bloque 3: pisar saldos en masa es
--      justo lo que el NOT EXISTS evita. Descomentalo cuando sepas qué estás
--      pisando, y nunca sobre filas ya aplicadas — para ésas hay que revertir
--      primero desde la página, o el ledger queda diciendo otra cosa.
/*
WITH Archivo AS (
    SELECT RIGHT('00000' + LTRIM(RTRIM(m.[Legajo])), 5)  AS LegajoBC,
           p.[Categoria]                                 AS Categoria,
           TRY_CONVERT(decimal(18,2), m.[Saldo francos]) AS DiasArchivo
    FROM   dbo.MIG_SaldoFrancos m
    JOIN   dbo.MIG_PuestoCategoria p ON p.[Puesto] = m.[Puesto]
    WHERE  TRY_CONVERT(decimal(18,2), m.[Saldo francos]) > 0
)
UPDATE s
SET    s.[Días] = a.DiasArchivo
FROM   dbo.[ArbuTest$Saldo Inicial Francos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] s
JOIN   Archivo a ON a.LegajoBC = s.[No_ Empleado] AND a.Categoria = s.[Cód_ Categoría]
WHERE  s.[Fecha Devengo] = '2025-12-31'
  AND  s.[Aplicado] = 0
  AND  s.[Días] <> a.DiasArchivo;
*/
