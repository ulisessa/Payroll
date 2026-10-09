---
tipo: referencia
tags: [motor, rendimiento, cache]
fuente: [src/Codeunits/Cod50014.MotorLiquidacion.al, src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Codeunits/Cod50015.EvaluadorFormula.al, src/Codeunits/Cod50069.EjecutorLiquidacion.al, REVISION_RENDIMIENTO_2026-09-18.md]
actualizado: 2026-10-04
---

# Rendimiento y caché del cálculo

El costo de liquidar es de **muchas lecturas repetidas y muchas escrituras que se borran**: un lote de
cientos de liquidaciones, cada una con decenas de fuentes de datos y cientos de conceptos, y las de
grossing-up recalculan la lista entera hasta 21 veces. Esta nota reúne **qué cachés existen, cuánto viven y
qué hay que respetar al tocarlas**. Los números de abajo salen de los comentarios del código y de
`REVISION_RENDIMIENTO_2026-09-18.md`; no hay una medición nueva.

## Mapa de cachés

| Caché | Dónde | Vida | Qué evita |
|---|---|---|---|
| Versión vigente por concepto (`FLatestVersionMap`, `FUltimaVersionMap`) y fracciones (`FFracAccumList/Pct/Vig`, `FAccumCodes`) | Motor, `EnsureConceptCaches` | por `FechaRef` (misma fecha = no-op); reutilizada entre las vueltas de GU | re-escanear `Concepto Liquidación`/`Fracción Acumulador` por vuelta |
| Aplicabilidad CCT (`FCCTAplicabilidad`) | Motor, `CCTAplicaAConcepto` | una liquidación (`ReiniciarCachesLiquidacion`) | `CalcFields`, `FindLast`, `Get` y exclusiones por concepto y por vuelta de GU; registra también los **negativos** |
| Par del puesto (`FParPuestoCargado`…) | Motor | una liquidación | resolver período y puesto por concepto marcado |
| Incidencias (`FIncidencias`, temporal) | Motor, `CargarIncidencias` | una liquidación | un `Get` a la base por concepto por pasada |
| Cascada de parámetros (`BuildParametroCache`) | Contexto | un `LoadParametros` | **un** recorrido de `Parámetro Vigente` en vez de un `FindLast` por parámetro |
| Valores por par convenio/categoría (`FParClave1/2`, `FParValores1/2`) | Contexto, `UsarParCCT` | una liquidación; **dos ranuras** | reconstruir la cascada completa dos veces por concepto marcado (con 15 conceptos marcados y 50 liquidaciones: 1.500 reconstrucciones) |
| Acumulados históricos (`FAcumAnual`, `FAcumPeriodo`, `FEstaLiq`) | Contexto, `CargarAcumHistorico` | hasta el próximo `Init` | un `CalcSums` **por concepto** de la fracción (100 conceptos = 100 consultas; en el perfil de la 1.0.0.497: 3,41 s en el período y 2,06 s en el anual sobre 27,4 s de cálculo). Ahora **un** recorrido por empleado con `SetLoadFields` de dos campos |
| Fechas de inicio y fin efectivo (`FFinEfCache`, `FFinEfMapa`, `FFinEfOrden`) | Contexto | una liquidación | consultas por fila del agregado (orden n² por fuente y empleado) y N×M comparaciones. Ver [[Fuentes de datos]] |
| Calendario (`FCalDateOverride`, `FCalWeekRule`) | Contexto, `EnsureCalendarioCache` | por `(calendario, año)` | ~730 consultas por liquidación para contar días hábiles/feriados |
| Validación de códigos de atributo (`FCodigosValidos`) | Evaluador | una liquidación (`Init`) | 2 lecturas por cada evaluación de una comparación por código |
| `TRAMO`: versión, resultado y log (`FTramoVigCache`, `FTramoResultCache`, `FTramoLogCache`) | Evaluador | una liquidación (`Init`) | `FindLast` repetidos; el log se **re-emite** desde la caché para que cada línea lo tenga |
| Memo de `@CÓDIGO` (`FLastConceptoRefValues`) | Evaluador | una evaluación de nivel superior | explosión combinatoria de referencias anidadas y recomputar la fórmula para mostrar `Fórmula Evaluada` |
| Contexto de **nombres** para validar | Contexto, `BuildContextParaValidacion` | fase 1 | pagar una liquidación completa para descartarla |

## Estrategias de escritura

- **Grossing-up sin auditoría intermedia** (`FIteracionGU`): las vueltas descartables no escriben `Fórmula Evaluada`, `Detalle Variable`, `Detalle Ganancias`, `Fuente Parámetros`, `En Uso`, controles de orden; la **pasada final** sí. Con 2 o más vueltas (lo normal: 5–8) gana. Ver [[Grossing-up y tipo de cambio]].
- **`DeleteAll(false)`** de líneas: el `OnDelete` sólo borra detalles, que ya se borraron de una vez (`BorrarDetalleVariables`); con `DeleteAll(true)` se pagaba un `DeleteAll` extra por línea y por vuelta. **Si algún día `OnDelete` de `Línea Liquidación` hace algo más, vuelve a ser `DeleteAll(true)`.**
- **Buffers temporales y `Insert` sin consumir el retorno** en `Detalle Variable`/`Resumen`: resuelve colisiones en memoria (la primera gana) y deja que el runtime agrupe las escrituras.
- **`SetLoadFields`** donde sólo hacen falta pocos campos: cache de versiones (3 campos), fracciones (5), acumulados históricos (2), fechas de inicio (1), `FiltrarPosteriores` (1). Cuidado: leer después un campo no cargado recarga la fila y el ahorro se pierde.
- **Funciones separadas** (`BorrarDetalleVariables`, `BorrarResumenVariables`…) para que el perfilador atribuya el tiempo a cada tabla.
- **Una sola lectura de ajenas** al reabrir (`CargarUsosDeOtrasLiquidaciones`) o el camino rápido por `Uso Parámetro Liq.`.
- **Validación sin valores**: ver arriba. Lo que se pierde es detectar con la fase 1 los errores que dependen del valor.

## Reglas para no romper nada al optimizar

1. Una caché **por liquidación** tiene que reiniciarse en `Init`/`ReiniciarCachesLiquidacion`: arrastrar datos entre empleados da importes de otra persona **sin error**.
2. Si algún día se **recalcula un acumulador a mitad de la corrida** (como ya hace `RecargarPctEscala` con `PCT_ESCALA`), hay que llamar `InvalidarAcumulados()` antes; es público y con nombre para que se encuentre desde donde haría falta.
3. **No cachear resultados dependientes del contexto**, de `@`, `#`, condiciones o acumuladores (las cachés de sintaxis serían una segunda etapa).
4. **Preservar** orden de cálculo, incidencias que fuerzan conceptos fuera del convenio, versiones y exclusiones, alternancia par base/puesto, filtros token, equivalencias de campos heredados.
5. Verificar con **equivalencia funcional** (comparar por empleado y concepto: importes, bases, redondeos, acumuladores, neto, cobertura, fórmulas, detalle de Ganancias, parámetros usados) y mejora **medida**. Compilar no demuestra equivalencia. Hay pruebas: `Test Cache Liquidacion` (110047), `Test Correcciones Rend. Liq.` (110046), `Test Escritura Auditoria` (110048), `Test Fin Efectivo Liq.` (110045).

> [!warning] Las cachés del motor **no** se comparten entre liquidaciones de un lote
> Los comentarios del motor dicen que las cachés viven "entre cada empleado de un lote que reutiliza una
> instancia del motor". En la ruta real eso **no ocurre**: `LiquidarConRegistro` ejecuta
> `Ejecutor Liquidación`, cuyo `OnRun` declara su **propio** `Motor Liquidación` local; y `LiquidarRecord`
> declara su propio `Contexto Liquidación`. Cada liquidación reconstruye `EnsureConceptCaches`, las
> fracciones y los parámetros. Es el punto 6 de `REVISION_RENDIMIENTO_2026-09-18.md`; sigue vigente.

## Qué ya se hizo y qué sigue abierto (de la revisión del 18/9/2026, contrastado con el código del 4/10)

| Propuesta | Estado en el código |
|---|---|
| 1. Fin efectivo una vez por fecha | **Hecho** (`OrdenarFechas`, `ConstruirMapaFinEfectivo`, mapa + respaldo por recorrido, prueba) |
| 2. Datos constantes por liquidación (incidencias, par, aplicabilidad CCT) | **Hecho** (buffer `FIncidencias`, `FCCTAplicabilidad`, par del puesto cacheado) |
| 3. Francos: filtrar/agregar en la base (`TotalConsumido` recorre y filtra después) | *No re-verificado* |
| 4. Agregaciones históricas e índices | **Parcial**: `CargarAcumHistorico` agrupa por empleado; la clave de `Línea Liquidación` sigue sin cubrir todos los filtros. Ver [[indices-missing-index-nocturnos]] y [[sift-sobre-clave-unica]] |
| 5. `SetLoadFields` en fuentes dinámicas | **Parcial**: `GetFechasInicioFuente` sí; los agregados `SUM`/`MIN`/`MAX` de `ResolveFuente` cargan el registro entero |
| 6. Instantánea de configuración por lote | **Abierto** (ver advertencia) |
| 7. Grossing-up con buffers temporales en vez de líneas físicas | **Abierto**; **y** la revisión decía que no había error al no converger: hoy sí lo hay |
| 8. Etiquetas del resumen, repintado de progreso, matriz de control de marea | **Abierto** |

La revisión también advierte que el perfil `PerformanceProfile_Session9.alcpuprofile` (8/9/2026, v1.0.0.411) concentraba muestras en `ResolveFuente` y `CalcFinEfectivo`, y que **sin un perfil nuevo no se puede prometer un porcentaje de aceleración**.

## Del lado de SQL

La escritura del cálculo es **churn de filas** (insertar y borrar líneas y detalle por vuelta): `Línea Liquidación` llegó a 35 índices no agrupados y 1.156 MB de índices contra 174 MB de datos; los `missing_index_*` los crea alguien a mano y se pagan en cada escritura; una **vista indexada (SIFT) sobre una clave única** crea una fila por registro. Ver [[indices-missing-index-nocturnos]], [[sift-sobre-clave-unica]] y [[sql-directo-deja-cache-rancia]].

## Relacionado

[[Ciclo de cálculo de una liquidación]] · [[Contexto de liquidación y variables]] · [[Evaluador de fórmulas - sintaxis]] · [[Procesos por lotes y progreso]]
