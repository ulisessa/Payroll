---
aliases: ["SIFT sobre clave única"]
tipo: leccion
tema: rendimiento
tags: [leccion, rendimiento, reference]
actualizado: 2026-10-19
---

# SIFT sobre clave única

> [!warning] Falla en silencio
> SumIndexFields en una clave única crea una vista indexada con una fila por registro; es costo puro y nadie la lee

`SumIndexFields` en una clave **única** —la primaria, típicamente— produce una vista
indexada que agrupa por esa clave, o sea **una fila por registro**. No ahorra ninguna
suma: sumar ahí cuesta lo mismo que sumar la tabla. Pero se mantiene en cada Insert y
cada Delete, y mantener una vista indexada es la escritura más cara que hay en SQL
Server.

Medido en `Línea Liquidación` (21/9/2026, ventana de 90 h con varios cálculos completos
de enero): `VSIFT$PK` tenía **0 lecturas contra 1.020.888 mantenimientos** y 104.588
filas, exactamente el row count de la tabla. Las otras tres SIFT de la misma tabla —K2,
K4, K5, todas con clave no única— tenían más de un millón de seeks cada una. Lo mismo en
`Detalle Ganancias Liq.`: 0 lecturas, 12.208 mantenimientos.

**Primer inventario** (no demuestra por sí solo quién lee la vista):

```sql
SELECT v.name, s.user_seeks+s.user_scans+s.user_lookups AS lecturas, s.user_updates, ps.row_count
FROM sys.views v
JOIN sys.indexes i ON i.object_id=v.object_id AND i.index_id=1
JOIN sys.dm_db_partition_stats ps ON ps.object_id=v.object_id AND ps.index_id=1
LEFT JOIN sys.dm_db_index_usage_stats s ON s.object_id=v.object_id AND s.index_id=1 AND s.database_id=DB_ID()
WHERE v.name LIKE '%VSIFT%';
```

Si `row_count` de la vista ≈ el de la tabla, la SIFT no agrupa nada. Sacar
`SumIndexFields` de esa clave es un cambio de esquema: hay que publicar con
sincronización.

Cuidado con el recíproco: una SIFT con clave no única sólo aporta valor si hay lectores
que la aprovechen. Los campos sumados deben estar en una misma SIFT y los campos filtrados
deben pertenecer a su clave, según la [documentación de CalcSums](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/optimize-sql-al-database-methods-and-performance-on-server).

La revisión del 19/10 confirmó que los seeks también pueden venir del **mantenimiento de la
vista dentro del INSERT/DELETE**. No usar su contador como prueba de consultas de negocio:
examinar el tipo de statement y su plan. K4/K5 ya no tenían lectores observados en la caché
examinada y el código actual suma los acumulados en memoria; K2 sí conservaba SELECT de totales.
Se implementó desactivar `MaintainSIFTIndex` sólo en K4/K5, conservando claves e índices
ordinarios. La publicación con Synchronize del 19/10 confirmó ese esquema. El perfil posterior
Session25(1), sobre la misma población y tipos que Session26, redujo la inserción de 101,177
a 90,285 s y el borrado de 18,288 a 7,431 s. La media SQL del INSERT bajó 26,10 % en las
ventanas observadas; no es un porcentaje de ahorro global ni una prueba A/B controlada.
El contraste SQL previo de todas las sumas actuales dio cero diferencias; sigue pendiente
la comparación integral de resultados y trazas regeneradas entre versiones.
Ver [[Rendimiento y caché del cálculo]].

## Relacionado

- Tema: `rendimiento` (ver [[_Convenciones del vault]])
