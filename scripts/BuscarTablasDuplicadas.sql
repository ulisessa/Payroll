/*
    ¿HAY DOS TABLAS PARA EL MISMO OBJETO?

    Este proyecto ya perdió datos por renumeración de IDs: una tabla cambia de número, BC dropea
    la vieja y crea la nueva vacía, y el nombre del archivo AL no lo delata. Si además quedó una
    tabla huérfana con el mismo nombre lógico, cualquier consulta que la busque con LIKE puede
    estar leyendo la equivocada.

    Síntoma que motivó esto: el historial de fórmulas muestra 14 filas que se cortan el 22/08/2026,
    y una edición posterior no aparece — pero la fórmula sí se guardó.

    Sólo LEE.
*/

USE [Migr2013R2];
GO
SET NOCOUNT ON;
GO

DECLARE @Empresa sysname = N'ArbuTest';

-- 1. Todas las tablas de la empresa cuyo nombre lógico se repite. Si alguna aparece dos veces,
--    hay una huérfana de una renumeración y las consultas por LIKE son ambiguas.
;WITH t AS (
    SELECT name,
           -- <Empresa>$<Nombre Lógico>$<GUID de extensión>
           SUBSTRING(name,
                     LEN(@Empresa) + 2,
                     LEN(name) - LEN(@Empresa) - 1 - (CHARINDEX('$', REVERSE(name)))) AS NombreLogico,
           create_date, modify_date, object_id
    FROM sys.tables
    WHERE name LIKE @Empresa + N'$%$%'
)
SELECT NombreLogico, COUNT(*) AS Cuantas,
       MIN(create_date) AS PrimeraCreacion, MAX(create_date) AS UltimaCreacion
FROM t
GROUP BY NombreLogico
HAVING COUNT(*) > 1
ORDER BY NombreLogico;

-- 2. Detalle de las tablas del historial y del concepto, con fecha de creación y filas.
--    Si create_date es posterior al 22/08/2026, la tabla se recreó y perdió lo que tenía.
SELECT t.name AS Tabla,
       t.create_date AS Creada,
       SUM(p.rows) AS Filas
FROM sys.tables t
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
WHERE t.name LIKE @Empresa + N'$Historial%'
   OR t.name LIKE @Empresa + N'$Concepto Liquidaci%'
GROUP BY t.name, t.create_date
ORDER BY t.name;

-- 3. Tablas de la extensión creadas en los últimos 30 días: son las que se dropearon y
--    recrearon (vacías) en alguna publicación reciente.
SELECT t.name AS Tabla, t.create_date AS Creada, SUM(p.rows) AS Filas
FROM sys.tables t
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
WHERE t.name LIKE @Empresa + N'$%'
  AND t.create_date > DATEADD(DAY, -30, GETDATE())
GROUP BY t.name, t.create_date
ORDER BY t.create_date DESC;
GO
