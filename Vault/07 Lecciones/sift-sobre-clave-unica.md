---
aliases: ["SIFT sobre clave única"]
tipo: leccion
tema: rendimiento
tags: [leccion, rendimiento, reference]
actualizado: 2026-10-04
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

**Cómo verificarlo** (no hace falta leer el AL, lo dice la DMV):

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

Cuidado con el recíproco: una SIFT con clave no única **sí** sirve, pero sólo si el
`CalcSums` filtra por un prefijo de la clave. Ver [[acumuladores-orden-calculo]] y el
comentario de K2 en Tab60012, donde `Es Devengo` va en el medio justamente para eso.

## Relacionado

- Tema: `rendimiento` (ver [[_Convenciones del vault]])
