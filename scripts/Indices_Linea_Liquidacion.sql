/*
  Índices no usados en las tablas del cálculo — Migr2013R2
  Sólo LEE el catálogo: no crea ni borra nada. El DROP queda en el paso 4, comentado.
  Correr en SSMS contra Migr2013R2.
*/
USE [Migr2013R2];
GO

/* ---- 0. ¿Desde cuándo acumula SQL las estadísticas? ----------------------------------------
   Los contadores de sys.dm_db_index_usage_stats se reinician con cada reinicio del servicio.
   Si el reinicio es reciente o no incluye cálculos completos, un "0 lecturas" no prueba nada. */
SELECT sqlserver_start_time,
       DATEDIFF(HOUR, sqlserver_start_time, SYSDATETIME()) AS horas_acumuladas
FROM sys.dm_os_sys_info;
GO

/* ---- 1. Qué hay y cuánto cuesta ----------------------------------------------------------
   Tablas a revisar: cambiá el LIKE si querés otras (Detalle Variable, Incidencia, etc.). */
SELECT t.name                                   AS tabla,
       i.name                                   AS indice,
       i.type_desc,
       i.is_primary_key,
       i.is_unique,
       CAST(SUM(ps.used_page_count) * 8 / 1024.0 AS DECIMAL(12,1)) AS mb,
       MAX(us.user_seeks)   AS seeks,
       MAX(us.user_scans)   AS scans,
       MAX(us.user_lookups) AS lookups,
       MAX(us.user_updates) AS updates,           -- lo que cuesta mantenerlo
       MAX(us.last_user_seek)   AS ult_seek,
       MAX(us.last_user_scan)   AS ult_scan
FROM sys.tables t
JOIN sys.indexes i             ON i.object_id = t.object_id AND i.type > 0
JOIN sys.dm_db_partition_stats ps ON ps.object_id = i.object_id AND ps.index_id = i.index_id
LEFT JOIN sys.dm_db_index_usage_stats us
       ON us.database_id = DB_ID() AND us.object_id = i.object_id AND us.index_id = i.index_id
WHERE t.name LIKE '%Línea Liquidación%'
   OR t.name LIKE '%Detalle Variable Línea Liq%'
GROUP BY t.name, i.name, i.type_desc, i.is_primary_key, i.is_unique
ORDER BY t.name, mb DESC;
GO

/* ---- 2. Candidatos a baja: sin ninguna lectura y no son PK/únicos --------------------------
   Los que no aparecen en usage_stats (NULL) tampoco se leyeron desde el reinicio. */
SELECT t.name AS tabla, i.name AS indice,
       CAST(SUM(ps.used_page_count) * 8 / 1024.0 AS DECIMAL(12,1)) AS mb,
       ISNULL(MAX(us.user_updates), 0) AS escrituras_pagadas,
       CASE WHEN i.name LIKE 'missing_index%' THEN 'a mano (no está en el AL)' ELSE 'declarado en AL' END AS origen
FROM sys.tables t
JOIN sys.indexes i             ON i.object_id = t.object_id AND i.type > 0
JOIN sys.dm_db_partition_stats ps ON ps.object_id = i.object_id AND ps.index_id = i.index_id
LEFT JOIN sys.dm_db_index_usage_stats us
       ON us.database_id = DB_ID() AND us.object_id = i.object_id AND us.index_id = i.index_id
WHERE (t.name LIKE '%Línea Liquidación%' OR t.name LIKE '%Detalle Variable Línea Liq%')
  AND i.is_primary_key = 0 AND i.is_unique = 0 AND i.type_desc = 'NONCLUSTERED'
GROUP BY t.name, i.name
HAVING ISNULL(MAX(us.user_seeks), 0) + ISNULL(MAX(us.user_scans), 0) + ISNULL(MAX(us.user_lookups), 0) = 0
ORDER BY escrituras_pagadas DESC;
GO

/* ---- 3. Script de REVERSA — guardalo ANTES de borrar nada ---------------------------------
   Genera el CREATE INDEX de cada candidato desde el catálogo (columnas, INCLUDE, filtro). */
;WITH cand AS (
    SELECT i.object_id, i.index_id, i.name, i.filter_definition
    FROM sys.indexes i
    JOIN sys.tables t ON t.object_id = i.object_id
    LEFT JOIN sys.dm_db_index_usage_stats us
           ON us.database_id = DB_ID() AND us.object_id = i.object_id AND us.index_id = i.index_id
    WHERE (t.name LIKE '%Línea Liquidación%' OR t.name LIKE '%Detalle Variable Línea Liq%')
      AND i.type_desc = 'NONCLUSTERED' AND i.is_primary_key = 0 AND i.is_unique = 0
      AND ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0) + ISNULL(us.user_lookups, 0) = 0
)
SELECT 'CREATE NONCLUSTERED INDEX ' + QUOTENAME(c.name) + ' ON '
     + QUOTENAME(OBJECT_SCHEMA_NAME(c.object_id)) + '.' + QUOTENAME(OBJECT_NAME(c.object_id)) + ' ('
     + STUFF((SELECT ', ' + QUOTENAME(col.name) + CASE WHEN ic.is_descending_key = 1 THEN ' DESC' ELSE '' END
              FROM sys.index_columns ic JOIN sys.columns col ON col.object_id = ic.object_id AND col.column_id = ic.column_id
              WHERE ic.object_id = c.object_id AND ic.index_id = c.index_id AND ic.is_included_column = 0
              ORDER BY ic.key_ordinal FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, '') + ')'
     + ISNULL(' INCLUDE (' + STUFF((SELECT ', ' + QUOTENAME(col.name)
              FROM sys.index_columns ic JOIN sys.columns col ON col.object_id = ic.object_id AND col.column_id = ic.column_id
              WHERE ic.object_id = c.object_id AND ic.index_id = c.index_id AND ic.is_included_column = 1
              ORDER BY ic.index_column_id FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, '') + ')', '')
     + ISNULL(' WHERE ' + c.filter_definition, '') + ';' AS script_reversa,
       'DROP INDEX ' + QUOTENAME(c.name) + ' ON '
     + QUOTENAME(OBJECT_SCHEMA_NAME(c.object_id)) + '.' + QUOTENAME(OBJECT_NAME(c.object_id)) + ';' AS script_baja
FROM cand c;
GO

/* ---- 4. Baja: pegá acá las líneas script_baja del paso 3, de a pocas y midiendo ------------ */
-- DROP INDEX [missing_index_...] ON [dbo].[...];

/* ---- 5. Quién los vuelve a crear: eventos de CREATE INDEX en la traza por defecto ----------- */
DECLARE @tr NVARCHAR(260) = (SELECT TOP 1 path FROM sys.traces WHERE is_default = 1);
SELECT CAST(StartTime AS DATE) AS dia, LoginName, COUNT(*) AS indices_creados
FROM sys.fn_trace_gettable(@tr, DEFAULT)
WHERE EventClass = 46 AND ObjectName LIKE 'missing_index%'      -- Object:Created
GROUP BY CAST(StartTime AS DATE), LoginName
ORDER BY dia DESC;
GO
