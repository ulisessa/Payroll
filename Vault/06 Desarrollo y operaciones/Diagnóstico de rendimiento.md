---
tipo: referencia
tags: [desarrollo, rendimiento, indices, sql, grossing-up]
fuente: [REVISION_RENDIMIENTO_2026-09-18.md, scripts/Indices_Linea_Liquidacion.sql, scripts/DepurarIndicesLiq20260921.ps1, scripts/CapturarSQLMotor.ps1, scripts/CompararEneroMotor.ps1, scripts/RestaurarFiltrosFuenteDatos.sql, PerformanceProfile_Session9.alcpuprofile]
actualizado: 2026-10-04
---

# Diagnóstico de rendimiento

Resumen de lo que se midió y de lo que se propuso sobre la velocidad del cálculo de liquidaciones. Detalle completo: `REVISION_RENDIMIENTO_2026-09-18.md` (versión 1.0.0.470, 293 archivos AL barridos; **revisión estática, no se ejecutó nada en BC**).

> [!note] Regla de oro
> Aceptar una optimización **sólo con equivalencia funcional y mejora medida** sobre datos representativos. Compilar no demuestra equivalencia de cálculo ([[Tests automatizados]]).

## Mediciones reales

| Hallazgo | Número | Cómo se halló |
|---|---|---|
| Sin los 76 filtros de Fuente Datos, una liquidación tardó **123 s** | `ResolveFuente` 65,5 s · `CalcFinEfectivo` 26,6 s · `RunConceptos` **0,22 s** (el cálculo real) | Performance Profiler (`PerformanceProfile_Session9.alcpuprofile`, 8/9/2026, versión 1.0.0.411). Arreglo: `scripts/RestaurarFiltrosFuenteDatos.sql` ([[Backup y restauración - cómo reaplicar]]) |
| `Línea Liquidación` llegó a **35 índices no agrupados** (6 declarados en AL) y 1.156 MB de índices contra 174 MB de datos | Insertar + borrar filas = **45 %** del tiempo ocupado del cálculo | DMV de uso de índices ([[indices-missing-index-nocturnos]]) |
| Vista indexada de SIFT sobre la clave primaria | `VSIFT$PK`: **0 lecturas** contra 1.020.888 mantenimientos; 104.588 filas = row count de la tabla | [[sift-sobre-clave-unica]] |
| Bajar 2 de 37 estructuras | 0,7 % del tiempo | La palanca es lineal y modesta por índice |

## Índices `missing_index_*`

331 índices, **37,7 GB**, que no declara ningún AL; los crea a mano `ARBUMASA\admulises` desde SSMS aplicando las recomendaciones de `sys.dm_db_missing_index_*`, buena parte generadas por consultas de análisis de una sola vez (comparación con Meta4). Hacia el 2/10/2026 ya no es nocturno; `Línea Liquidación` quedó con **8 índices** (6 AL + `$systemId` + 1 `missing_index`) y `Detalle Variable` con 3.

Criterio de baja: **medido, nunca estético** — cero `user_seeks + user_scans + user_lookups` en una ventana que incluya cálculos completos (`sys.dm_os_sys_info.sqlserver_start_time` dice cuánto lleva acumulando). **Generar la reversa antes de bajar.**

### Herramientas
- `scripts/Indices_Linea_Liquidacion.sql` — **sólo lee**. 6 pasos: desde cuándo acumula SQL estadísticas; qué hay y cuánto cuesta; candidatos sin lecturas; script de **reversa** generado desde el catálogo (columnas, `INCLUDE`, filtro); el `DROP` va comentado en el paso 4; quién los vuelve a crear (traza por defecto, `EventClass = 46`).
- `scripts/DepurarIndicesLiq20260921.ps1` — dos modos. Sin parámetros **prepara** (escribe `indexes-before.json`, `restore.sql`, `drops.sql`, `selection.csv` en `scripts/diagnostico-sql-20260921/`; no cambia nada). Con `-Apply` **baja** en una transacción (`LOCK_TIMEOUT 5000`), después de verificar que el `restore.sql` guardado coincide con el estado actual, y verifica que cada reemplazo siga presente. Sólo baja un índice si **otro que lo cubre** (misma clave prefijo + columnas) queda.
- Corrida del **21/9/2026**: 6 índices bajados (44 → 38), cada uno cubierto por un reemplazo (`missing_index_419_418`→`…964_963` con 12.569 lecturas y 607.804 escrituras; otros 5 con 0–1 lecturas y ~130 mil escrituras). Según la lección, ese día se dieron de baja **11** en total (2 redundantes y 9 sin lecturas en 90 h); no se pudo reconciliar esa cifra con los 6 de `result.json`.
- Pendientes (2/10/2026): bajar a mano `missing_index_361_360` (Detalle Variable: 29 seeks vs 6,4 M escrituras) y `missing_index_5916_5915` (copia entera de la tabla: 4 claves + 30 `INCLUDE`, 357 MB; se reemplazó por la clave K7 declarada en AL con `IncludedFields`; bajarlo **después** de ver seeks en `$K7`). **La palanca de índices está agotada**; lo que queda es el churn de filas (borrar y reinsertar).

> [!warning] Cualquier cambio de `SumIndexFields` o de claves es cambio de esquema
> Hay que publicar con sincronización ([[Publicar en BC (no usar RAD)]]). Una SIFT con clave **no única** sí sirve, pero sólo si el `CalcSums` filtra por un prefijo de la clave (ver el comentario de K2 en `Tab60012.LineaLiquidacion.al`, donde `Es Devengo` va en el medio justamente para eso; [[acumuladores-orden-calculo]]).

## Captura del motor en SQL

`scripts/CapturarSQLMotor.ps1 -Seconds N` (10–900, default 600) crea una **sesión de Extended Events** con nombre único `CodexPayroll_<guid>`: `sql_statement_completed` + `sp_statement_completed` de la base actual, sólo sentencias ≥ 10 ms que mencionen `ArbuTest…Liquidaci`, con target `ring_buffer`. Cada 2 s vuelca el buffer a `events-NNNN.xml` y los *waits* de requests activas a `waits-NNNN.json` dentro de `scripts/captura-motor-<fecha>/`; al final exporta `events-final.xml` **antes** de parar (parar destruye el buffer) y borra la sesión en el `finally`. Comentario del propio script: los snapshots se solapan → deduplicar; mirar `droppedCount` antes de afirmar completitud. Hay tres capturas del 21/9/2026 en el repo (10 KB cada una, sin datos sensibles a simple vista).

## Equivalencia: `CompararEneroMotor.ps1`

`pwsh scripts/CompararEneroMotor.ps1 -Phase Before|After` guarda, para las **519 liquidaciones de enero 2026** (exige exactamente 519), un **hash SHA-256 por fila** de cinco tablas (`Liquidación`, `Línea Liquidación`, `Detalle Variable Línea Liq.`, `Resumen Variable Liq.`, `Detalle Ganancias Liq.`), excluyendo columnas de sistema y el número de entrada de Ganancias, en `scripts/comparacion-enero-2026/<Fase>.json` (≈16,8 MB). Se niega a sobrescribir (`Ya existe…; conservar la referencia`). Es el mecanismo para afirmar «una optimización no cambió importes»: correr `Before`, aplicar el cambio, recalcular enero, correr `After`; el propio script imprime por tabla si `Identical`. `After.json` y `Before.json` del 21/9 tienen **exactamente** el mismo tamaño (16.797.993 bytes), consistente con una baja de índices sin efecto funcional; **sin verificar** que se hizo la comparación campo a campo.

## Prioridades de la revisión del 18/9/2026 (no implementadas al escribir esa nota)

| # | Prioridad | Propuesta | Dónde |
|---|---|---|---|
| 1 | Alta | Resolver el **fin efectivo** una sola vez por fecha (mapa inicio → siguiente inicio − 1 día en vez de recorrer la lista por fila: N × M) | `Cod50016.ContextoLiquidacion.al`, `CalcFinEfectivo` (hoy línea ~2577; el equivalente rápido ya está probado en `Test Fin Efectivo Liq.`) |
| 2 | Alta | Preparar datos **constantes por liquidación**: incidencias en buffer, par de puesto una vez, aplicabilidad de CCT memorizada (incluyendo negativos) | `Cod50014.MotorLiquidacion.al` (`Incid.Get`, `AplicarParDeConcepto`, `CCTAplicaAConcepto`) |
| 3 | Alta | **Francos**: filtrar y agregar en la base (`SetFilter` por conceptos, `CalcSums`) en vez de recorrer líneas | `Cod50053.GestionFrancos.al` (`TotalConsumido`, `TotalPorRolHasta`, `TotalDevengado`) |
| 4 | Alta/Media | Alinear **agregaciones históricas con índices** (K4/K5 no cubren todos los filtros); no crear índices por intuición: cada alta/baja de grossing-up los mantiene | `Cod50016` líneas ~755–903; `Tab60012.LineaLiquidacion.al` |
| 5 | Media | `SetLoadFields` en fuentes dinámicas (SUM/MIN/MAX por `RecordRef`) | `Cod50016` ~1950 |
| 6 | Media | Instantánea de configuración **por lote y fecha** (el motor exterior no es el que arma las cachés: `Ejecutor Liquidación` declara su propio `Motor`) | `Cod50069.EjecutorLiquidacion.al` |
| 7 | Estructural | **Grossing-up con resultados temporales**: hasta 20 iteraciones que insertan líneas físicas; evaluar en buffers y persistir una vez | `Cod50014` ~2012, `ConvergerGrossingUp` (`Cod50014`, línea ~2255 hoy) |
| 8 | Secundarias | Etiquetas de recibo, repintado de diálogo, matriz de marea, caché de sintaxis | varios |

Qué **preservar** (cualquier optimización): orden de cálculo, incidencias que fuerzan conceptos fuera del convenio, versiones y exclusiones, tolerancia de **0,01** y límite de iteraciones del grossing-up, auditoría (`SaveResumenVariables` guarda valores para recibos y no se debe saltear), y la transacción independiente por liquidación ([[codeunit-run-necesita-commit]]). **No** compartir contexto, saldos, incidencias o valores de empleado entre liquidaciones. Mejoras ya presentes que conviene conservar: validación por nombres sin construir valores, cachés de versiones y fracciones, caché de fin efectivo, de TRAMO y calendarios, supresión de auditoría intermedia en grossing-up, borrado masivo con limpieza explícita del detalle, índices de sumas por liquidación.

> [!warning] Discrepancias a revisar
> - La revisión es del 18/9 y la **versión** analizada era la 1.0.0.470; hoy es la 565. Varias referencias de línea (`:2082`, `:400`…) ya no coinciden. Otros cambios posteriores: `Test Fin Efectivo Liq.` (prueba de equivalencia del mapa, ítem 1) y el control `AgruparConEntradaAbierta` indican que parte del ítem 1 pudo haberse implementado; **sin verificar**.
> - La revisión dice que no hay prueba integral del motor; sigue siendo cierto ([[Tests automatizados]]).

## Antes de buscar el problema en el AL

1. ¿Están los filtros de Fuente Datos? (`EstadoConfiguracion.sql`, bloque 3).
2. ¿Cuántas estructuras se mantienen por fila en `Línea Liquidación` y `Detalle Variable Línea Liq.`? (`Indices_Linea_Liquidacion.sql`).
3. ¿Hay una vista indexada con `VSIFT$PK`? ([[sift-sobre-clave-unica]]).
4. Perfilar con el profiler de VS Code (configuración **AL: Attach session**, `executionContext: DebugAndProfile`) y mirar el reparto; `ResolveFuente` alto = faltan filtros.
5. Recién ahí tocar el motor, y con la comparación `Before`/`After`.

Contexto de tiempos de lote y del dialogo de progreso: [[progreso-singleinstance-sucio]], [[orden-calculo-del-lote]].
