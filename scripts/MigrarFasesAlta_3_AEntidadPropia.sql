/*
    MUEVE LAS ALTAS Y BAJAS DEL HISTORIAL DE ESTADOS A SU PROPIA TABLA.
    Se ejecuta en la conexión de BC (SQL Server). Una sola vez.

    POR QUÉ

    Hasta ahora el alta y la baja eran dos filas de "Estado Empleado". Eso mete dos cosas
    ortogonales en una tabla que admite UN estado por empleado por fecha, y las hace competir por el
    mismo día: el día que alguien ingresa y embarca, Meta4 registra el alta Y el estado operativo, y
    las dos son ciertas. En la migración de estados de enero de 2026 eso fueron 153 choques, y no
    por datos sucios — por el modelo. Meta4 lo tiene separado desde siempre, en dos tablas.

    Desde la versión que acompaña a este script:
      · "Fase Alta Empleado"  → los tramos de relación laboral. De acá sale la antigüedad.
      · "Estado Empleado"     → qué hacía la persona cada día, con su proyecto. Y RECHAZA
                                activamente los códigos de tipo Alta y Baja.

    QUÉ HACE ESTE SCRIPT
      1. Aparea cada alta con la baja que la cierra, con el mismo criterio que usaba el cálculo de
         antigüedad: una Alta abre, la primera Baja posterior cierra, y lo del medio no interrumpe.
      2. Inserta las fases.
      3. Borra del historial las filas de alta y de baja.
      4. Recalcula la contigüidad de lo que queda, porque al sacar filas del medio los cierres de
         las vecinas quedan apuntando a una fila que ya no está.

    ORDEN: bloques 1 a 3 sólo leen. El 4 inserta, el 5 borra, el 6 recalcula. Cada uno con su
    COMMIT a mano.

    ANTES DE EMPEZAR: publicar la extensión con la tabla "Fase Alta Empleado". Si no existe, el
    bloque 1 lo dice y no se puede seguir.
*/

SELECT 'Conexión correcta: SQL Server — base ' + DB_NAME() AS GUARDIAN;

DECLARE @EE  sysname = N'ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @CE  sysname = N'ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';
DECLARE @FA  sysname = N'ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';

IF OBJECT_ID(QUOTENAME(@FA)) IS NULL
    THROW 50020, 'No existe la tabla "Fase Alta Empleado". Falta publicar la extensión con el cambio de modelo antes de correr esto.', 1;

------------------------------------------------------------------------------------------------
-- 1. QUÉ HAY PARA MOVER
------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Mov') IS NOT NULL DROP TABLE #Mov;

SELECT ee.[No_ Mov_]      AS NoMov,
       ee.[No_ Empleado]  AS Legajo,
       ee.[Fecha Inicio]  AS Fecha,
       ee.[Cód_ Estado]   AS CodEstado,
       ee.[Observaciones] AS Coment,
       ce.[Tipo Estado]   AS Tipo          -- 1 = Alta, 2 = Baja
INTO   #Mov
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN   [dbo].[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ce
       ON ce.[Código] = ee.[Cód_ Estado]
WHERE  ee.[Tipo Entidad] = 0
  AND  ce.[Tipo Estado] IN (1, 2);

SELECT Tipo, COUNT(*) AS Filas, COUNT(DISTINCT Legajo) AS Legajos,
       MIN(Fecha) AS Desde, MAX(Fecha) AS Hasta
FROM   #Mov GROUP BY Tipo ORDER BY Tipo;
-- Tipo 1 = altas, Tipo 2 = bajas. Al 13/9/2026: 9610 altas sobre 4788 legajos (desde 1990) y
-- 9280 bajas sobre 4631. Es el historial COMPLETO, no sólo el año en curso — unas dos fases por
-- persona, que es lo esperable en pesca, donde el reingreso es la norma y no la excepción.

------------------------------------------------------------------------------------------------
-- 2. EL APAREO — cada alta con la baja que la cierra
--
--    Una baja cierra el alta MÁS RECIENTE que la precede, y nunca una que esté después del alta
--    siguiente. Sin ese segundo límite, un reingreso hace que la baja vieja cierre la fase nueva.
------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Fases') IS NOT NULL DROP TABLE #Fases;

WITH Altas AS (
    SELECT m.*,
           ROW_NUMBER() OVER (PARTITION BY m.Legajo ORDER BY m.Fecha, m.NoMov) AS NoFase,
           LEAD(m.Fecha) OVER (PARTITION BY m.Legajo ORDER BY m.Fecha, m.NoMov) AS ProxAlta
    FROM   #Mov m WHERE m.Tipo = 1
)
SELECT a.Legajo,
       a.NoFase,
       a.Fecha       AS FechaAlta,
       a.CodEstado   AS MotivoAlta,
       a.Coment      AS ComentAlta,
       b.Fecha       AS FechaBaja,
       b.CodEstado   AS MotivoBaja,
       b.Coment      AS ComentBaja
INTO   #Fases
FROM   Altas a
OUTER APPLY (
    SELECT TOP 1 x.Fecha, x.CodEstado, x.Coment
    FROM   #Mov x
    WHERE  x.Legajo = a.Legajo
      AND  x.Tipo   = 2
      AND  x.Fecha >= a.Fecha
      AND  (a.ProxAlta IS NULL OR x.Fecha < a.ProxAlta)
    ORDER  BY x.Fecha, x.NoMov
) b;

SELECT COUNT(*)                                          AS Fases,
       SUM(CASE WHEN FechaBaja IS NULL THEN 1 ELSE 0 END) AS Abiertas,
       SUM(CASE WHEN FechaBaja IS NOT NULL THEN 1 ELSE 0 END) AS Cerradas
FROM   #Fases;

------------------------------------------------------------------------------------------------
-- 3. PRE-VUELO — las tres cosas que la tabla nueva NO acepta. Todas tienen que dar CERO.
------------------------------------------------------------------------------------------------

-- 3.a Bajas que no cerraron ninguna fase: quedan huérfanas y se PIERDEN al borrar el historial.
--     El cálculo viejo también las ignoraba, así que esto no cambia ningún número — pero conviene
--     saber cuáles son antes de borrarlas, porque después no hay de dónde sacarlas.
SELECT m.Legajo, m.Fecha, m.CodEstado
FROM   #Mov m
WHERE  m.Tipo = 2
  AND  NOT EXISTS (SELECT 1 FROM #Fases f
                   WHERE f.Legajo = m.Legajo AND f.FechaBaja = m.Fecha)
ORDER  BY m.Legajo, m.Fecha;

-- 3.b Fases con la baja anterior al alta. La tabla las rechaza: darían días negativos.
SELECT * FROM #Fases WHERE FechaBaja IS NOT NULL AND FechaBaja < FechaAlta ORDER BY Legajo, NoFase;

-- 3.c Fases superpuestas del mismo legajo. La tabla las rechaza: contarían dos veces los días
--     compartidos y darían una antigüedad mayor que la vida laboral de la persona.
SELECT a.Legajo, a.NoFase AS Fase, a.FechaAlta, a.FechaBaja,
       b.NoFase AS ChocaCon, b.FechaAlta AS AltaOtra, b.FechaBaja AS BajaOtra
FROM   #Fases a
JOIN   #Fases b
       ON b.Legajo = a.Legajo AND b.NoFase > a.NoFase
      AND a.FechaAlta <= ISNULL(b.FechaBaja, '9999-12-31')
      AND b.FechaAlta <= ISNULL(a.FechaBaja, '9999-12-31')
ORDER  BY a.Legajo, a.NoFase;

------------------------------------------------------------------------------------------------
-- 3.d REPARACIÓN — fases anidadas y la baja que quedó suelta por culpa de ellas
--
--     QUÉ PASÓ, confirmado contra el origen el 13/9/2026. Meta4 tiene, para dos legajos, una fase
--     corta ENTERAMENTE CONTENIDA dentro de otra más larga:
--
--         80696:  26/6/2022 → 28/9/2023   y   30/6/2022 → 23/9/2022
--         80709:   8/1/2022 → 21/3/2023   y    3/7/2022 → 23/9/2022
--
--     No es una relación laboral paralela: el motivo de las cortas es el 12, "Finalización de
--     contrato", y son un artefacto de carga de Meta4. Dos casos en 9610.
--
--     POR QUÉ ROMPE DOS BLOQUES A LA VEZ. El apareo del bloque 2 busca la baja ANTES del alta
--     siguiente, para que un reingreso no quede cerrado por la baja vieja. Con una fase anidada esa
--     regla se da vuelta: la baja de la larga está después del alta de la corta, así que la larga
--     queda abierta (y se superpone, 3.c) y su baja queda sin dueño (3.a). Los dos síntomas son el
--     mismo hecho.
--
--     LA REPARACIÓN VA POR REGLA Y NO POR LEGAJO. Escribir los dos números a mano arreglaría hoy y
--     fallaría en silencio si mañana aparece un tercero. La regla es: una fase contenida en otra se
--     descarta, y después la que quedó abierta toma la primera baja suya que nadie haya usado.
------------------------------------------------------------------------------------------------

-- 3.d.1 Descartar las fases contenidas en otra del mismo legajo.
DELETE f
FROM   #Fases f
WHERE  EXISTS (SELECT 1 FROM #Fases o
               WHERE o.Legajo  = f.Legajo
                 AND o.NoFase <> f.NoFase
                 AND o.FechaAlta <= f.FechaAlta
                 AND ISNULL(o.FechaBaja, '9999-12-31') >= ISNULL(f.FechaBaja, '9999-12-31'));

-- 3.d.2 La fase que quedó abierta toma la primera baja del legajo que no esté ya usada por otra.
--       El NOT EXISTS es el que hace que esto NO toque las 332 fases legítimamente abiertas: para
--       ésas no hay ninguna baja suelta posterior a su alta, así que el CROSS APPLY no devuelve
--       nada y la fila no se actualiza.
UPDATE f
   SET f.FechaBaja  = b.Fecha,
       f.MotivoBaja = b.CodEstado,
       f.ComentBaja = b.Coment
FROM   #Fases f
CROSS APPLY (
    SELECT TOP 1 m.Fecha, m.CodEstado, m.Coment
    FROM   #Mov m
    WHERE  m.Legajo = f.Legajo
      AND  m.Tipo   = 2
      AND  m.Fecha >= f.FechaAlta
      AND  NOT EXISTS (SELECT 1 FROM #Fases f2
                       WHERE f2.Legajo = m.Legajo AND f2.FechaBaja = m.Fecha)
    ORDER  BY m.Fecha
) b
WHERE  f.FechaBaja IS NULL;

-- 3.d.3 Después de reparar, 3.a, 3.b y 3.c tienen que dar CERO. Volvé a correrlos.
SELECT COUNT(*)                                           AS Fases,
       SUM(CASE WHEN FechaBaja IS NULL THEN 1 ELSE 0 END)  AS Abiertas,
       SUM(CASE WHEN FechaBaja IS NOT NULL THEN 1 ELSE 0 END) AS Cerradas
FROM   #Fases;
-- Esperado: 9608 fases (dos menos que antes), 330 abiertas, 9278 cerradas.

------------------------------------------------------------------------------------------------
-- 4. INSERTAR LAS FASES — descomentar después de que 3.b y 3.c den cero
------------------------------------------------------------------------------------------------
SELECT @@TRANCOUNT AS TransaccionesAbiertasEnEstaSesion;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

/*
BEGIN TRANSACTION;

INSERT INTO [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
    ([No_ Empleado], [No_ Fase], [Fecha Alta], [Cód_ Motivo Alta], [Comentario Alta],
     [Fecha Baja], [Cód_ Motivo Baja], [Comentario Baja], [Días], [Abierta],
     [$systemId], [$systemCreatedAt], [$systemCreatedBy], [$systemModifiedAt], [$systemModifiedBy])
SELECT
    f.Legajo,
    f.NoFase,
    f.FechaAlta,
    ISNULL(f.MotivoAlta, ''),
    ISNULL(f.ComentAlta, ''),
    -- '1753-01-01' es como BC guarda una fecha en blanco: fase abierta.
    ISNULL(f.FechaBaja, '1753-01-01'),
    ISNULL(f.MotivoBaja, ''),
    ISNULL(f.ComentBaja, ''),
    CASE WHEN f.FechaBaja IS NULL THEN 0 ELSE DATEDIFF(day, f.FechaAlta, f.FechaBaja) END,
    CASE WHEN f.FechaBaja IS NULL THEN 1 ELSE 0 END,
    NEWID(), SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000',
             SYSUTCDATETIME(), '00000000-0000-0000-0000-000000000000'
FROM #Fases f;

PRINT 'Fases insertadas: ' + CAST(@@ROWCOUNT AS varchar(10));
-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/

------------------------------------------------------------------------------------------------
-- 5. BORRAR DEL HISTORIAL las filas de alta y de baja — después del COMMIT del bloque 4
--
--    A partir de acá el historial queda sólo con estados operativos, que es lo que la tabla exige
--    de ahora en más: intentar volver a insertar un ALT ahí da error.
------------------------------------------------------------------------------------------------
/*
BEGIN TRANSACTION;

DELETE ee
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN   #Mov m ON m.NoMov = ee.[No_ Mov_];

PRINT 'Filas de alta/baja borradas del historial: ' + CAST(@@ROWCOUNT AS varchar(10));
-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/

------------------------------------------------------------------------------------------------
-- 6. RECALCULAR LA CONTIGÜIDAD DE LO QUE QUEDA — después del COMMIT del bloque 5
--
--    Al sacar filas del medio, las vecinas quedaron cerradas contra una fila que ya no existe: un
--    estado que terminaba el día antes del alta ahora tiene que llegar hasta el día antes del
--    estado que sigue de verdad. Es idempotente.
------------------------------------------------------------------------------------------------
/*
BEGIN TRANSACTION;

WITH Hist AS (
    SELECT ee.[No_ Mov_] AS NoMov,
           COALESCE(DATEADD(day, -1, LEAD(ee.[Fecha Inicio]) OVER (PARTITION BY ee.[No_ Empleado]
                                                                   ORDER BY ee.[Fecha Inicio])),
                    '1753-01-01') AS FinCorrecto
    FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    WHERE ee.[Tipo Entidad] = 0
)
UPDATE ee
   SET ee.[Fecha Fin]         = h.FinCorrecto,
       ee.[$systemModifiedAt] = SYSUTCDATETIME()
FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN Hist h ON h.NoMov = ee.[No_ Mov_]
WHERE ee.[Fecha Fin] <> h.FinCorrecto;

PRINT 'Fechas Fin corregidas: ' + CAST(@@ROWCOUNT AS varchar(10));
-- COMMIT TRANSACTION;  /  ROLLBACK TRANSACTION;
*/

------------------------------------------------------------------------------------------------
-- 7. VERIFICACIÓN
------------------------------------------------------------------------------------------------

-- 7.a No tiene que quedar NINGUNA alta ni baja en el historial de estados.
SELECT ee.[Cód_ Estado], ce.[Tipo Estado], COUNT(*) AS Filas
FROM   [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
JOIN   [dbo].[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ce
       ON ce.[Código] = ee.[Cód_ Estado]
WHERE  ee.[Tipo Entidad] = 0 AND ce.[Tipo Estado] IN (1, 2)
GROUP  BY ee.[Cód_ Estado], ce.[Tipo Estado];

-- 7.b Las fases que quedaron.
SELECT COUNT(*) AS Fases, COUNT(DISTINCT [No_ Empleado]) AS Legajos,
       SUM(CASE WHEN [Abierta] = 1 THEN 1 ELSE 0 END) AS Abiertas
FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890];

-- 7.c Más de una fase abierta por empleado. Tiene que dar CERO: dos tramos abiertos suman los
--     mismos días dos veces.
SELECT [No_ Empleado], COUNT(*) AS Abiertas
FROM   [dbo].[ArbuTest$Fase Alta Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
WHERE  [Abierta] = 1
GROUP  BY [No_ Empleado] HAVING COUNT(*) > 1;

-- 7.d Huecos en el historial que quedó. Tiene que dar CERO.
WITH H AS (
    SELECT ee.[No_ Empleado] AS Legajo, ee.[Fecha Inicio] AS Inicio, ee.[Fecha Fin] AS Fin,
           LEAD(ee.[Fecha Inicio]) OVER (PARTITION BY ee.[No_ Empleado] ORDER BY ee.[Fecha Inicio]) AS Sig
    FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
    WHERE ee.[Tipo Entidad] = 0
)
SELECT * FROM H WHERE Sig IS NOT NULL AND Fin <> DATEADD(day, -1, Sig) ORDER BY Legajo, Inicio;
