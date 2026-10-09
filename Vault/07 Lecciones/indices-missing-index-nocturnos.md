---
aliases: ["Los missing_index_* son nocturnos y a mano"]
tipo: leccion
tema: rendimiento
tags: [leccion, rendimiento, project]
origen: 4b151484-1884-4407-a1bb-01b9ea3741c8
actualizado: 2026-10-02
---

# Los missing_index_* son nocturnos y a mano

Los missing_index_* de Migr2013R2 los crea alguien a mano casi todas las noches; son el peaje de escritura del cálculo

En `Migr2013R2` hay **331 índices llamados `missing_index_*`, 37,7 GB**, que no los
declara ningún AL. Los crea **a mano `ARBUMASA\admulises` desde SSMS**, aplicando las
recomendaciones de `sys.dm_db_missing_index_*`. La traza por defecto los fecha casi
todas las noches cerca de las 23:00: 68 el 18/9/2026, 47 el 19/9, 4 el 20/9.

**Por qué importa:** buena parte de esas recomendaciones las genera SQL por consultas de
análisis de una sola vez —las de la comparación con Meta4, por ejemplo— y quedan como
peaje permanente sobre las tablas que más se escriben. `Línea Liquidación` llegó a 35
índices no agrupados (sólo 6 declarados en AL) y **1.156 MB de índices contra 174 MB de
datos**, con insertar + borrar filas explicando el 45 % del tiempo ocupado del cálculo.

**Cómo aplicar:** antes de buscar el problema en el AL, mirar cuántas estructuras se
mantienen por fila. El criterio para dar de baja es medido, nunca estético: cero
`user_seeks + user_scans + user_lookups` en una ventana que incluya cálculos completos
(`sys.dm_os_sys_info.sqlserver_start_time` dice cuánto lleva acumulando). Generar
siempre la reversa desde el catálogo antes de la baja.

**Escala medida:** dar de baja 2 de 37 estructuras dio 0,7 % del tiempo ocupado. Es
lineal y modesto por índice — el número grande sale de bajar muchos, o de sacar una
vista indexada inútil, ver [[sift-sobre-clave-unica]].

El 21/9/2026 se dieron de baja 11 en total: 2 redundantes y 9 sin lecturas en 90 h.

**Actualización 2/10/2026:** ya no es nocturno. La traza muestra tandas manuales de
`admulises` (136 el 18/9, 94 el 19/9, 8 el 20/9, 2 el 30/9); desde la limpieza casi no se
crearon. `Línea Liquidación` quedó con 8 índices (6 AL + $systemId + 1 missing_index) y
`Detalle Variable` con 3. Con ventana de 346 h no queda ninguno con cero lecturas: la
palanca de índices está agotada. Quedan dos a bajar a mano: `missing_index_361_360` en
Detalle Variable (29 seeks vs 6,4 M escrituras) y `missing_index_5916_5915`, que es una
copia entera de la tabla (4 claves + 30 INCLUDE, 357 MB) y se reemplazó por la clave K7
declarada en AL (con IncludedFields); bajar el missing recién después de ver seeks en $K7.
La escritura del cálculo está ahora en el churn de filas (borrar y reinsertar), no en índices.

## Relacionado

- [[sift-sobre-clave-unica]]
