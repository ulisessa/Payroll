---
aliases: ["Los missing_index_* son nocturnos y a mano"]
tipo: leccion
tema: rendimiento
tags: [leccion, rendimiento, project]
origen: 4b151484-1884-4407-a1bb-01b9ea3741c8
actualizado: 2026-10-19
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

## Evaluación del 18/10/2026

La conclusión del 2/10 era válida para aquel inventario. La captura actual vuelve a
mostrar un índice manual que copia toda Línea Liquidación:
"<Name of Missing Index, sysname,>". Ocupaba 1.169,64 MB y en una segunda captura
con cambios concurrentes de datos llegó a 1.523,66 MB. Está en uso; no se dio de baja.

Los planes capturados muestran lecturas completas de 35 columnas en la cuenta de
francos y en fuentes SUM de enfermedad. La alternativa propuesta conserva las cuatro
claves y cubre sólo importes, cantidades, concepto, vigencia y campos automáticos,
sin copiar textos de fórmulas y parámetros. Se estima en 60–80 MB para el volumen
capturado; no se creó físicamente ni se midió su rendimiento.

Antes de sustituirlo hay que reducir la proyección de esos lectores y comparar la
carga en una copia aislada. Retirar columnas del índice conserva las trazas en la
tabla, pero con los SELECT actuales puede añadir accesos a la fila original.
Ver [[Rendimiento y caché del cálculo]] y las capturas en
artifacts/indices-20261018/. Ninguna escritura ni DDL se ejecutó en la BD.

**Aplicación posterior del 18/10, autorizada por el usuario:** se creó el candidato
IX_LineaLiquidacion_EmpleadoEstado_Compacto. Ocupa 55,36 MB con 288.518 filas;
en esa captura el ancho permanecía habilitado y ocupaba 1.653,23 MB. Coinciden conteo y sumas exactas
de importes/cantidades leídos por ambos índices. No se retiró el original ni se
publicaron cambios AL. En esa etapa el reemplazo y la mejora en el cálculo seguían pendientes
de validar; ver [[Rendimiento y caché del cálculo]].

## Lectores parciales y comparación SQL posterior (18–19/10/2026)

Se publicaron lecturas parciales en `Cuenta Corriente Francos.Total`, `Matriz` y la rama `SUM` de
`ResolveFuente`. Se conservan filtros, orden, conversión y trazas; los textos completos siguen
guardados en la tabla. El paquete 1.0.0.673, PackageId `98A651B5-9DCE-4D10-868F-05F01C772B9D`,
se verificó contra las 361 fuentes AL compiladas. La selección aislada ejecutó **38 pruebas:
37 aprobadas y una falla preexistente visible** en `FiltroConApostrofesYOperadores`. Pasan las
ocho regresiones nuevas. La selección exige empresa `TEST_`, incluye 6 pruebas de rendimiento,
22 de caché y 10 de francos, y excluye cinco históricas que requieren datos de ArbuTest.
Las 69 tablas controladas de la empresa aislada conservaron conteos y máximo rowversion.
Ver [[Tests automatizados]].

La comparación SQL de sólo lectura sí se completó: **96 consultas**, seis muestras, cuatro
repeticiones alternadas y cuatro variantes de proyección/índice. Los hashes de claves, campos
usados y orden coincidieron; no se observaron cambios de filas o rowversions durante las
comparaciones. Las lecturas lógicas acumuladas en doce ejecuciones por variante y familia bajan
de **6.144 a 276** para francos y de **9.704 a 388** para el patrón SUM de enfermedad.
La consulta parcial sobre el ancho conserva las lecturas anteriores; el compacto reduce ese costo.

Los planes de las consultas parciales sin hint eligen el compacto mediante `Index Seek`, sin
`Key Lookup`, aunque mantienen los ordenamientos. Son planes compilados asociados a las
ejecuciones, sin contadores por operador. El ensayo no ejecutó AL, no midió escrituras ni valida
las tres ventanas dinámicas de `ENF_BASE`, `ENF_BASE_12` y `ENF_BASE_6`. No se deriva un porcentaje
de mejora del cálculo completo de estos resultados.

El compacto se amplió a catorce columnas incluidas para cubrir los cuatro campos de origen
adicionales de Matriz; ocupa **74,60 MiB**. La sonda AL de sólo lectura pasó en ArbuTest con seis
documentos, 18 pares SUM, 24 pares Total, 36 trazas y doce lecturas de Matriz. Es una comprobación
de estabilidad y del camino publicado; no sustituye la comparación independiente ni mide el motor.

**El índice ancho se retiró el 19/10 a las 08:33:41 UTC.** Ocupaba 1.688,97 MiB usados y
1.690,09 MiB reservados; el compacto queda con 74,60 MiB usados y 74,63 MiB reservados.
Se conservó el DDL exacto de reconstrucción. El control anterior/posterior mantuvo 293.993 filas
y máximo rowversion 17.053.973.210. La sonda AL posterior volvió a pasar en 0,879 s con los
mismos conteos de lecturas y trazas; no es una medición del cálculo completo. La suite sigue
en **37/38**, con ocho regresiones nuevas aprobadas y la falla preexistente visible. Evidencia en
`artifacts/indices-20261018/lectores/`: `benchmark-results.json`, `plans-summary.json`,
`continuacion-20261019/compact-expansion-result.json`, `publication-result.json`,
`suite-38-revision2.json`, `empresa-aislada-post-tests.json` y `sonda-indice-ampliado.json`
(los cinco últimos dentro de `continuacion-20261019`), además de
`continuacion-20261019/wide-index-removal-result.json` y `sonda-post-retiro.json` de esa carpeta.

El control posterior completó 27 consultas y nueve planes reales, con seis comparaciones iguales
en campos, orden y rowversions. La paginación parcial usa el compacto sin lookup; la consulta
completa de `Inicializar` usa K4 y PK con lookup, sin ejecutar su método AL ni reconstruir datos.
Otros siete planes compilados de consultas observadas durante la sonda AL posterior usan sólo
el compacto, sin lookup, para SUM, Total y Matriz. La captura final confirma el ancho ausente,
el compacto activo y las filas/rowversion conservadas. Ver
`artifacts/indices-20261018/lectores/post-retirement-reader-summary.json`. Este resultado permite
atribuir la reducción de estructura y lecturas a los caminos medidos; no un porcentaje del motor completo.

## Relacionado

- [[sift-sobre-clave-unica]]
