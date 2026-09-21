/*
    QUÉ TABLAS DE LA EXTENSIÓN QUEDARON VACÍAS, Y CUÁLES FUERON RECREADAS
    Se ejecuta contra la base de BC (SQL Server).

    Para cuándo sirve: después de una publicación que se llevó datos por delante. En BC las tablas de
    una extensión se llaman '<Empresa>$<Tabla>$<AppId>', así que se pueden listar todas juntas sin
    nombrarlas una por una — y con la fecha de creación al lado, que es la prueba: una tabla con
    create_date de hoy fue DROPEADA y vuelta a crear, no se vació sola.

    El sospechoso habitual es .vscode/rad.json. Ese archivo es el rastro de una publicación RAD
    anterior y arrastra una lista 'Removed' con objetos que sí existen en el código fuente. Publicar
    en modo RAD con esa lista dropea esas tablas, con sus datos, sin preguntar y sin avisar. Hoy esa
    lista incluye Cód. Estado Empleado, Parámetro, Parámetro Vigente, Variable Sistema, Período
    Liquidación, Incidencia Liquidación, Tabla Escalonada y Fracción Acumulador, entre otras.
*/

DECLARE @AppId nvarchar(50) = N'd4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890';

-- 1. Todo el esquema de la extensión, lo vacío primero. Una tabla de configuración en cero que ayer
--    tenía datos es el hallazgo; una tabla de movimientos en cero puede ser normal.
SELECT
    t.name                                  AS Tabla,
    SUM(p.rows)                             AS Filas,
    t.create_date                           AS Creada,
    t.modify_date                           AS Modificada
FROM sys.tables t
JOIN sys.partitions p
  ON p.object_id = t.object_id
 AND p.index_id IN (0, 1)
WHERE t.name LIKE '%$' + @AppId
GROUP BY t.name, t.create_date, t.modify_date
ORDER BY SUM(p.rows), t.name;

-- 2. Las recreadas en las últimas 24 horas. Si acá aparece algo, no hubo pérdida de datos por un
--    borrado: hubo un DROP TABLE de la publicación.
SELECT t.name AS Tabla, t.create_date AS Creada, SUM(p.rows) AS Filas
FROM sys.tables t
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE t.name LIKE '%$' + @AppId
  AND t.create_date > DATEADD(hour, -24, SYSDATETIME())
GROUP BY t.name, t.create_date
ORDER BY t.create_date DESC;

-- 3. Las dos que importan para las fases, en concreto.
SELECT 'Estado Empleado' AS Tabla, COUNT(*) AS Filas
FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]
UNION ALL
SELECT 'Cód. Estado Empleado', COUNT(*)
FROM [dbo].[ArbuTest$Cód_ Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890];
-- Estados con filas y códigos en cero = el historial está intacto y lo que falta es el catálogo que
-- lo interpreta. Los dos en cero = se perdió también el historial, y hay que volver a migrar.

-- 4. Si los estados sobrevivieron: qué códigos usan, para saber cuáles hay que recrear.
SELECT ee.[Cód_ Estado] AS Codigo, COUNT(*) AS Filas,
       MIN(ee.[Fecha Inicio]) AS Desde, MAX(ee.[Fecha Inicio]) AS Hasta
FROM [dbo].[ArbuTest$Estado Empleado$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] ee
WHERE ee.[Tipo Entidad] = 0
GROUP BY ee.[Cód_ Estado]
ORDER BY COUNT(*) DESC;
-- Esta lista es la que hay que volver a dar de alta en Cód. Estados Empleado, con su Tipo Estado
-- correcto: los que abren fase como Alta, los que la cierran como Baja. Sin eso, ninguna fase existe
-- y la antigüedad de toda la plantilla es cero — sin un solo error en pantalla.

-- 5. LA FOTO MÁS ÚTIL: cuántas tablas se crearon en cada momento.
--
--    Casi todas las tablas de la extensión comparten la fecha del despliegue en que nacieron. Una
--    publicación que dropea y recrea deja un grupito con fecha distinta y muy posterior — y eso salta
--    a la vista acá sin tener que saber de antemano qué tabla mirar. Las filas de abajo, las más
--    recientes, son las sospechosas.
SELECT
    CONVERT(char(16), t.create_date, 120) AS Momento,
    COUNT(*)                              AS Tablas,
    SUM(pr.Filas)                         AS FilasEnTotal
FROM sys.tables t
CROSS APPLY (SELECT SUM(p.rows) AS Filas FROM sys.partitions p
             WHERE p.object_id = t.object_id AND p.index_id IN (0, 1)) pr
WHERE t.name LIKE '%$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890'
GROUP BY CONVERT(char(16), t.create_date, 120)
ORDER BY Momento DESC;

-- 6. Y el detalle de las que nacieron en el último grupo, con sus filas. Una tabla de configuración
--    recreada hoy y con 0 filas es una pérdida de datos; recreada hoy y con filas significa que BC
--    la recreó y le devolvió el contenido, que es lo que hace una sincronización normal cuando la
--    estructura cambia.
SELECT t.name AS Tabla, t.create_date AS Creada, SUM(p.rows) AS Filas
FROM sys.tables t
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE t.name LIKE '%$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890'
  AND t.create_date >= DATEADD(hour, -6, SYSDATETIME())
GROUP BY t.name, t.create_date
ORDER BY SUM(p.rows), t.name;
