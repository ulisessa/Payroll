---
tipo: referencia
tags: [motor, rendimiento, cache]
fuente: [src/Codeunits/Cod50014.MotorLiquidacion.al, src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Codeunits/Cod50015.EvaluadorFormula.al, src/Codeunits/Cod50069.EjecutorLiquidacion.al, REVISION_RENDIMIENTO_2026-09-18.md]
actualizado: 2026-10-20
---

# Rendimiento y caché del cálculo

El costo de liquidar es de **muchas lecturas repetidas y muchas escrituras que se borran**: un lote de
cientos de liquidaciones, cada una con decenas de fuentes de datos y cientos de conceptos, y las de
grossing-up recalculan la lista entera hasta 21 veces. Esta nota reúne **qué cachés existen, cuánto viven y
qué hay que respetar al tocarlas**. Las cifras históricas salen de los comentarios del código y de
`REVISION_RENDIMIENTO_2026-09-18.md`. La revisión del 18/10 agrega capturas SQL, el tamaño físico de
un índice compacto y una comparación de sus lecturas; todavía no mide el tiempo total del motor.

## Lectura parcial de fracciones (18/10/2026)

`CalcImporteAnualPorAcumulador` (`YTD_ACUM`) y `CalcImportePeriodoPorAcumulador`
(`PERIODO_ACUM`) declaran `Fraccion.SetLoadFields("Cód. Concepto", "Invertir Signo")`
antes de `FindSet`. El cambio reduce los campos solicitados a `Fracción Acumulador`, una lectura
que usaba el registro completo aunque sólo consultaba esos dos campos. Los campos que el runtime
necesita para claves y filtros pueden añadirse a la selección. No se agregó un índice.

Se conserva el recorrido ascendente por K2 (`Cód. Acumulador`, `Vigencia Desde`) y la **primera fila
encontrada por concepto**, incluidos los signos de esa fila. También se conservan los filtros de
acumulador y fecha, la exclusión de Borrador, el alcance por empleado y período y la deduplicación de
conceptos. Esta lectura histórica no selecciona la última fracción como la distribución corriente.
El anual incluye las líneas propias que correspondan; el del período las excluye. Las tres cachés
siguen viviendo hasta `Init` o `InvalidarAcumulados`: si se escriben líneas y se necesita renovar el
anual, el llamador debe invalidar antes. No se cambian fórmulas, importes ni escrituras de trazas.

El proyecto **1.0.0.673 compiló sin errores**, incluidas dos regresiones nuevas de
`Test Cache Liquidacion` sobre vigencias/signos/filtros y renovación de la liquidación propia.
La revisión inicial sólo las compiló. El 19/10 ambas regresiones **pasaron en la empresa aislada
`TEST_ORDEN_20261017`**, dentro de la selección de 38 pruebas descrita abajo. ArbuTest continúa
siendo operativa y no recibió fixtures. Esto valida los escenarios ensayados, no una mejora de
tiempo del cálculo. Ver [[Tests automatizados]].

## Lectores de francos y fuentes SUM publicados (19/10/2026)

`Cuenta Corriente Francos.Total` solicita `Cantidad`, `Cód. Concepto`, `Vigencia Concepto` y
`Fecha Liquidación`. Las claves que usa para identificar cada línea siguen disponibles por la
lectura automática del runtime. Se conservan los filtros, el orden, la resolución del rol por
vigencia y fecha, la exclusión del documento y la deduplicación de líneas ya asentadas.

`Matriz` carga esos cuatro campos y `No. Proyecto`, `Cód. Convenio`, `Cód. Categoría` y
`Cód. Período`, usados por `CopiarOrigen` y el buffer temporal. Conserva el origen, la selección
de lotes y su identificador de trazabilidad; no modifica las fórmulas ni las trazas guardadas.

En `ResolveFuente`, sólo la rama `SUM` prepara una lectura parcial del campo de valor canónico.
Se mantiene la suma en AL, en el mismo orden y con la misma conversión; no se sustituye por un
`SUM` SQL. Los filtros y la traza `FDS` permanecen en su lugar. Un campo sin configurar o inexistente
no anticipa un error sobre un conjunto vacío; si `SetLoadFields` no acepta el campo, se conserva
la lectura completa. `MIN`, `MAX` y los restantes agregados no forman parte de este cambio.

La versión **1.0.0.673** se publicó con PackageId
`98A651B5-9DCE-4D10-868F-05F01C772B9D`; los **361 objetos AL** recuperados por ese identificador
coinciden con las fuentes congeladas que produjeron el paquete. La suite aislada terminó con
**37 de 38 pruebas aprobadas**: pasan las ocho regresiones nuevas; permanece visible el fallo
previo `FiltroConApostrofesYOperadores`, ajeno a las lecturas parciales. No se declara la suite
completa aprobada. Las 69 tablas controladas conservaron conteos y máximo rowversion después
de las pruebas. La sonda de sólo lectura en ArbuTest también terminó correctamente; su repetición
comprueba estabilidad, no equivale a comparar recibos completos. Ver [[Tests automatizados]].
Evidencia en `artifacts/indices-20261018/lectores/continuacion-20261019/`: `publication-result.json`,
`suite-38-revision2.json`, `empresa-aislada-post-tests.json`, `sonda-indice-ampliado.json` y
`metadata-publicada-98a651b5-9dce-4d10-868f-05f01c772b9d/metadata-comparacion.json`.

## Mapa de cachés

**Actualización del 20/10:** el fallo de filtro citado en la captura del 19/10 se corrigió después
mediante selección literal de códigos, preservando la ruta OR para los conceptos numéricos.
La nueva selección aislada terminó con **56/56 aprobadas**, sin modificar fórmulas ni recibos.
No se repitió el benchmark ni se atribuye a esta corrección una mejora de tiempo.
Ver [[Francos - ledger FIFO]] y [[Tests automatizados]].

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
| 5. `SetLoadFields` en fuentes dinámicas | **Parcial**: `GetFechasInicioFuente` y `SUM` publicados; las nuevas regresiones SUM pasan en empresa aislada. `MIN`/`MAX` conservan lectura completa |
| 6. Instantánea de configuración por lote | **Abierto** (ver advertencia) |
| 7. Grossing-up con buffers temporales en vez de líneas físicas | **Abierto**; **y** la revisión decía que no había error al no converger: hoy sí lo hay |
| 8. Etiquetas del resumen, repintado de progreso, matriz de control de marea | **Abierto** |

La revisión también advierte que el perfil `PerformanceProfile_Session9.alcpuprofile` (8/9/2026, v1.0.0.411) concentraba muestras en `ResolveFuente` y `CalcFinEfectivo`, y que **sin un perfil nuevo no se puede prometer un porcentaje de aceleración**.

## Del lado de SQL

La escritura del cálculo es **churn de filas** (insertar y borrar líneas y detalle por vuelta): `Línea Liquidación` llegó a 35 índices no agrupados y 1.156 MB de índices contra 174 MB de datos; los `missing_index_*` los crea alguien a mano y se pagan en cada escritura; una **vista indexada (SIFT) sobre una clave única** crea una fila por registro. Ver [[indices-missing-index-nocturnos]], [[sift-sobre-clave-unica]] y [[sql-directo-deja-cache-rancia]].

### Evaluación del índice ancho de Línea Liquidación (18/10/2026)

El índice manual llamado literalmente `<Name of Missing Index, sysname,>` cubre las **35 columnas**
de la tabla. En la captura inicial ocupaba **1.169,64 MB**, con 212.454 filas; en la última captura,
**1.523,66 MB**, con 268.076 filas. La base estaba cambiando entre lecturas: son fotografías de
momentos distintos, no un antes/después de una intervención. Los datos están en
`artifacts/indices-20261018/existing-indexes.json` y `narrow-index-size-sample.json` de esa carpeta.

Cinco variantes de consultas de BC encontradas en los planes seleccionan las 35 columnas. Sus
patrones corresponden a `CuentaCorrienteFrancos.Total` y a agregados `SUM` de `ResolveFuente`; la configuración de
`ENF_BASE`, `ENF_BASE_12` y `ENF_BASE_6` coincide con el segundo patrón. Esa atribución procede de
comparar consultas, código y configuración; no se capturó una traza que enlazara cada ejecución AL
con su consulta SQL. Evidencia: `wide-index-consumers.json`, `query-sources.json` y
`dynamic-source-consumer.json` en `artifacts/indices-20261018/`.

El candidato conserva las cuatro claves actuales, en este orden: `No. Empleado`, `Estado`,
`No. Liquidación`, `Fecha Liquidación`. Propone incluir `Cód. Concepto`, `Vigencia Concepto`,
`Cantidad`, `Importe`, `timestamp` y los cinco campos de sistema (`$systemId`, `$systemCreatedAt`,
`$systemCreatedBy`, `$systemModifiedAt`, `$systemModifiedBy`), sin los textos grandes de fórmulas,
trazas y descripciones. La propuesta se conserva en
`artifacts/indices-20261018/propuesta-indice-linea.sql`; **no se creó ni se eliminó un índice**.

La estimación es **60–80 MB para 268.076 filas**. Parte de una muestra de 3.030 filas con
151,09 bytes medios de los campos seleccionados, más 17 bytes de `Importe`, y añade margen para
la estructura del índice y la ocupación de páginas. Es un modelo de tamaño, no la medición de un
índice construido ni una prueba A/B. No permite inferir cuánto tardaría menos una liquidación.

Antes de aplicar DDL hace falta reducir la proyección de **ambas rutas**, `CuentaCorrienteFrancos.Total` y los
agregados de `ResolveFuente`, y comprobar el SQL y el plan que realmente genere BC. Después hay
que evaluar el candidato en una copia aislada, comparar lecturas, escrituras y tiempos, y verificar
importes y trazas contra la referencia. La reducción de campos de `Fracción Acumulador` descrita
arriba no resuelve esa proyección de `Línea Liquidación`. En esta revisión no hubo creación o baja
de índices, publicación ni ejecución de pruebas sobre la empresa operativa.

### Aplicación en ArbuTest por pedido del usuario (18/10/2026)

Se creó IX_LineaLiquidacion_EmpleadoEstado_Compacto (index_id 39) en
Migr2013R2, tabla Línea Liquidación de ArbuTest. La creación tardó 1,95 segundos.
SQL Server es Standard 2022: se usó creación offline, MAXDOP=1, espera de bloqueos
limitada a cinco segundos y una conexión dedicada, sin transacción explícita.
No había consultas activas en las capturas anterior y posterior.

El tamaño físico medido es **55,36 MB para 288.518 filas**, frente a **1.653,23 MB**
del índice ancho. Se verificaron las cuatro claves y las diez columnas incluidas.
En esa etapa el índice anterior quedó habilitado: la creación del compacto todavía no
liberaba su espacio ni eliminaba su mantenimiento. El retiro posterior del 19/10 se
documenta al final de esta sección.

El conteo, la suma exacta de importes, la suma exacta de cantidades y el máximo
rowversion coincidieron leyendo ambos índices; la lectura del índice ancho antes
y después permaneció estable. Es un control agregado, no una comparación de
recibos, trazas ni rendimiento de una liquidación completa. No se recalcularon
recibos, no se ejecutaron fixtures y no se publicó la app.

La reducción de campos de los lectores de francos y fuentes SUM se preparó después de esta
creación y se publicó el 19/10 con la validación descrita arriba. La medición del cálculo completo
y la revisión de los demás consumidores siguen siendo independientes de esta creación.
Evidencias: artifacts/indices-20261018/aplicacion/create-result.json y verification.json.
La propuesta anterior conserva su fecha y el carácter de evaluación inicial.

### Comparación SQL de los lectores (18/10/2026)

Se ejecutaron **96 consultas de sólo lectura** en ArbuTest: seis muestras, cuatro repeticiones
y cuatro variantes (proyección completa con índice ancho, parcial con ancho, parcial con
compacto y parcial sin forzar índice). Se alternó el orden de las variantes, conservando filtros,
tipos de parámetros, orden por PK y `OPTION(FAST 50)`, y se leyeron todas las filas. No hubo DDL,
limpieza de caché ni ejecución AL en este benchmark.

Los hashes de las claves y los campos usados por AL coincidieron, con el mismo orden. También
coincidieron las claves y rowversions observadas; no se detectaron cambios concurrentes entre
las lecturas comparadas. Esto no descarta cambios transitorios entre observaciones.

| Familia | Filas de las tres muestras | Lecturas lógicas: completa/ancho | Lecturas lógicas: parcial/compacto o automático |
|---|---|---:|---:|
| `Total` de francos | 122, 278 y 947 | 6.144 | 276 |
| Patrón `SUM` de enfermedad | 1, 10 y 15 | 9.704 | 388 |

Cada cifra de lecturas suma doce ejecuciones de la variante correspondiente. La familia de
enfermedad usó una ventana fija del 01/03/2025 al 28/02/2026: reproduce el patrón compartido por
`ENF_BASE`, `ENF_BASE_12` y `ENF_BASE_6`, pero no valida las tres resoluciones de fechas en AL.
La proyección parcial forzando el índice ancho mantuvo las mismas lecturas que la completa;
la combinación de proyección e índice compacto es la que reduce ese costo.

Los planes compilados recuperados de caché, asociados a las ejecuciones sin hint, usan
**sólo `IX_LineaLiquidacion_EmpleadoEstado_Compacto`, mediante `Index Seek`, sin `Key Lookup`**
en ambas familias. Conservan el ordenamiento final y el `TopN Sort` de los dos intervalos.
No contienen contadores de ejecución por operador. Los tiempos SQL y de cliente incluyen
transporte y consumo del resultado; no son una medición del motor ni de su costo de escritura.

Durante este benchmark el índice ancho permaneció habilitado. La publicación y las pruebas
posteriores se describen arriba; su retiro del 19/10 se registra más abajo, con el DDL exacto de
reconstrucción conservado. No se afirma un porcentaje de aceleración del cálculo completo.
Evidencia: `artifacts/indices-20261018/lectores/benchmark-results.json`, `plans.json` y
`plans-summary.json`.

### Cobertura de Matriz y ampliación del compacto (19/10/2026)

El compacto se amplió de diez a catorce columnas incluidas para cubrir también `Matriz`:
`No. Proyecto`, `Cód. Convenio`, `Cód. Categoría` y `Cód. Período`. Conserva las cuatro claves;
ocupa **74,60 MiB**, medidos después de la ampliación, que tardó 2,22 segundos. Este tamaño
no es directamente comparable con capturas de otros días si cambió el volumen de la tabla.
La sonda del paquete publicado completó seis documentos, 18 pares SUM, 24 pares Total,
36 trazas y doce lecturas de Matriz en 1,53 segundos. Ese tiempo corresponde a la sonda,
no a una liquidación completa. En esa comprobación el índice ancho todavía estaba habilitado.
Evidencia: `continuacion-20261019/compact-expansion-result.json` y `sonda-indice-ampliado.json`
dentro de la carpeta de lectores.

### Retiro del índice ancho y control posterior (19/10/2026)

El índice `<Name of Missing Index, sysname,>` se retiró correctamente a las **08:33:41 UTC**.
Antes ocupaba **1.688,97 MiB usados y 1.690,09 MiB reservados**. El compacto (index_id 39)
permanece con **74,60 MiB usados y 74,63 MiB reservados**; el ancho ya no recibe mantenimiento
en cada escritura. El DDL de reconstrucción quedó conservado y su hash figura en la evidencia.

El control anterior/posterior mantuvo exactamente **293.993 filas** y máximo rowversion
**17.053.973.210**. La sonda AL de sólo lectura volvió a completar los seis documentos, 18 pares
SUM (18 resultados no cero), 24 pares Total, 36 trazas y doce lecturas de Matriz en **0,879 s**.
Son controles de los lectores y de conservación de la tabla, no un recálculo completo de nómina
ni una estimación de su aceleración. La suite aislada conserva su resultado **37/38**, con las
ocho regresiones nuevas aprobadas y el fallo preexistente de códigos literales visible.
Evidencia: `artifacts/indices-20261018/lectores/continuacion-20261019/wide-index-removal-result.json`
y `sonda-post-retiro.json` de la misma carpeta.

El control SQL posterior completó **27 consultas y nueve planes de ejecución reales**: las seis
comparaciones de muestras conservaron campos, orden y hashes de claves/rowversions. La paginación
parcial usa el compacto sin `Key Lookup`; la lectura completa de `Inicializar` usa K4 más acceso
a la PK con lookup. Se reprodujo esa consulta, **no se ejecutó `Inicializar` en AL ni se reconstruyeron
movimientos**. Además, siete planes de las consultas emitidas por la sonda AL posterior muestran
SUM con 13 columnas, Total con 14 y Matriz con 18: todos usan exclusivamente el compacto, sin
lookup. Estos siete son planes compilados de consultas observadas, distintos de los nueve planes
reales del ensayo SQL. A las 08:40 UTC seguían ausentes el ancho y los cambios de filas/rowversion,
con el compacto activo y el mismo paquete instalado. Resumen y límites en
`artifacts/indices-20261018/lectores/post-retirement-reader-summary.json`; fuentes en
`post-retirement-reader-validation.json`, `al-probe-post-retirement-plans.json` y
`post-retirement-final-state.json` de esa carpeta.

## Perfil posterior al retiro: Session9 del 19/10/2026

Se comparó el archivo de **Descargas**, `PerformanceProfile_Session9.alcpuprofile` (versión
1.0.0.673), con `PerformanceProfile_Session4(2).alcpuprofile` del 14/10 (1.0.0.655).
No confundir el Session9 nuevo con el archivo homónimo antiguo de la raíz del proyecto.

**Son cargas diferentes, por lo que no hay un porcentaje demostrado de mejora del motor.**
El usuario no podía confirmar el alcance; una consulta de sólo lectura a `Registro Proceso Liq.`
encontró una sesión de cálculo completa dentro de cada intervalo del perfil. La asociación es
por operación y contención temporal, no por igualdad entre el identificador de sesión funcional
y el identificador de sesión del servidor del perfil.

| Registro del lote asociado | Anterior, 14/10 | Nuevo, 19/10 |
|---|---:|---:|
| Período | Enero 2026 | Marzo 2026 |
| Liquidaciones procesadas | 570 | 469 |
| Empleados distintos | 329 | 346 |
| Desde el inicio de la primera hasta el fin de la última operación | 540,460 s | 591,547 s |
| Suma de duraciones registradas por operación | 539,174 s | 590,828 s |
| Operaciones con errores registrados | 0 | 3, de tipo Regular |

También cambió la mezcla de tipos: Regular 318→246; Vacaciones 64→30; Devengados 90→90;
Cierre de marea 90→89; Liquidación final 8→14. No se certificaron importes ni se investigó la
causa de los tres errores en este análisis de rendimiento.

La duración de **captura** pasó de 567,201 a 612,766 s. El tiempo asignado a muestras pasó de
547,293 a 598,709 s. Se sumó `timeDeltas[i]` al nodo `samples[i]`, agrupando los tiempos propios
por objeto y función entre todas sus rutas. Los tiempos inclusivos usan la unión de descendientes
y no se suman a sus hijos. `hitCount` no se interpreta como cantidad de liquidaciones ni consultas.
El nuevo perfil conserva 44,085 s en ramas desconectadas, 6,684 s de Idle explícito y 14,057 s
del intervalo de captura sin asignación a muestras; no se reasignan automáticamente al motor.

| Función, tiempo propio muestreado | Anterior | Nuevo |
|---|---:|---:|
| `InsertarLineaLiquidacion` | 114,736 s | 94,513 s |
| `ResolveFuente` | 29,349 s | 43,121 s |
| `BorrarLineasLiquidacion` | 29,063 s | 26,929 s |
| `ResolverCCTAplicaAConcepto` | 19,510 s | 21,203 s |
| `WriteVariableDetail` | 23,521 s | 19,116 s |
| `CuentaCorrienteFrancos.Total` | 16,686 s | 18,028 s |

La baja de 17,63 % en el tiempo agregado de insertar líneas coincide con 17,72 % menos
liquidaciones procesadas; no demuestra por sí sola una inserción más rápida. Además, cada tipo
puede escribir distintas cantidades de líneas y hacer distintas iteraciones de grossing-up.

La conciliación conserva un costo importante: `ReconciliarEnUso` pasa de **54,897 a 74,735 s
inclusivos**. En el nuevo perfil, **68,797 s propios** pertenecen a `TieneUsoExactoActivo`.
La versión anterior usaba `TieneUsoActivo`: su desaparición del perfil no equivale a eliminar
ese trabajo. El código perfilado sigue consultando una versión por vez, incluidas las generales,
al cerrar cada liquidación. El primer candidato a optimizar es aceptar sin otra consulta las
claves exactas cuyo uso ya demuestra el documento recién Calculado, conservando el control de
las demás candidatas y el respaldo histórico. Esa precarga positiva **se implementó en el código
el 19/10**, después de analizar el perfil; fue publicada ese día y su primera medición es Session26,
analizada debajo. Usa la PK
exacta en un temporal local y no guarda respuestas negativas entre documentos. El overload de
un argumento conserva el recorrido anterior. Ver [[Parámetros y vigencias]].

La publicación completa en BC252 quedó confirmada por el Package ID exacto
`39854D29-6104-444D-9F98-E22790CA039A` y la suite de parámetros pasó 26/26 en una empresa
aislada. Esto valida las regresiones de conciliación; no mide la reducción del tiempo del lote.
Evidencia en `artifacts/publicacion-conciliacion-20261019/`.

La comprobación de alcance sobre diez documentos **actuales** de enero encontró 2.842
candidatas y 344 coincidencias exactas ya acreditadas por el propio documento: permite evitar
el 12,10 % de esas consultas de existencia, agregando una lectura de cabecera y una del conjunto
de usos por documento. Es una muestra acotada por tipo, no una estimación representativa del
lote ni una medición de tiempos. Las identidades de documentos registradas en los perfiles ya
no tienen cabeceras/usos en el estado actual; no se extrapola esta muestra a aquellas corridas.
Las dos lecturas de control coincidieron. Evidencia y consulta reproducible en
`artifacts/conciliacion-positivos-20261019/current-january-positives.json`.

Después quedan la escritura de líneas y las fuentes dinámicas. De los 94,513 s de inserción,
30,659 s cuelgan de grossing-up, pero incluyen su pasada final: no son todos eliminables.
`ResolveFuente` tiene 52,187 s inclusivos y reúne varios agregados; el perfil no separa el costo
de SUM del de las ramas aún completas. Se observa el helper `PrepararLecturaParcialSuma`,
confirmando que se recorrió el código nuevo, sin inferir por eso el índice utilizado por SQL.

Ambos perfiles contienen el refresco `Cargar`/`Construir` que la página ejecuta después de
`Lotes.Calcular`. Hay evidencia de retorno de la acción, pero no de éxito de cada recibo; tampoco
corresponde inferir un corte automático sólo porque la captura dura cerca de diez minutos.
Para medir la mejora atribuible hace falta repetir el mismo conjunto sobre datos y configuración
equivalentes, con control de resultados y trazas, además del tiempo total.

Evidencia en `artifacts/perfiles-20261019/`: `comparison-session4-2-vs-session9.json`,
`session9-summary.json`, `baseline-session4-2-summary.json`, `process-scope-confirmed.json`
y su consulta SQL. La metodología de tiempos se contrastó con el editor AL instalado y la
[documentación del profiler](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-al-profiler-overview).

## Primer perfil de la precarga: Session26 del 19/10/2026

Comparación contra Session9 del mismo día. La precarga nueva aparece efectivamente en el árbol:
`CargarVersionesDeLiquidacionActiva` consume 0,403 s. La conciliación completa, **incluyendo esa
precarga**, pasa de **74,735 a 69,787 s**: 4,948 s menos, **6,62 % de reducción observada**.
`TieneUsoExactoActivo` baja de 68,797 a 63,058 s; el trabajo propio restante de conciliación sube
de 5,938 a 6,326 s. No sumar el costo del helper a los 69,787 s: ya está incluido.

Es una mejora acotada: las consultas exactas restantes todavía explican el **90,36 %** de la
conciliación. El perfil no informa cuántas consultas se evitaron; `hitCount` no cuenta consultas
ni liquidaciones. El resultado es compatible con el alcance reducido de los positivos propios,
pero no demuestra por sí solo la causalidad ni una mejora global del motor de ese porcentaje.

| Tiempo muestreado | Session9 | Session26 |
|---|---:|---:|
| Insertar líneas, propio | 94,513 s | **101,177 s** |
| Conciliación completa, inclusivo | 74,735 s | **69,787 s** |
| Resolver fuentes, inclusivo | 52,187 s | 45,717 s |
| Cuenta corriente de francos, inclusivo | 28,393 s | 34,678 s |
| Escribir detalle de variables, propio | 19,116 s | 22,477 s |
| Borrar líneas, propio | 26,929 s | 18,288 s |

Los tiempos inclusivos contienen sus descendientes y no deben sumarse entre funciones que se
llaman. La escritura individual de líneas es el mayor costo propio; el helper contiene
`LinLiq.Insert(true)`. Antes de cambiar esa escritura, medir las consultas SQL, índices y esperas
que la sostienen: el muestreo AL no separa esas causas. No se propone quitar trazabilidad ni
desactivar triggers a partir de este perfil.

### Comparabilidad y tiempo del lote

El registro funcional asociado a Session26 está completamente dentro de su captura y tiene todos
sus fines informados. Ambos lotes son de marzo, pero cambió la ruta: Session9 calcula existentes
desde el árbol; Session26 ejecuta **Crear y calcular** desde Períodos. En el perfil nuevo hay
31,920 s atribuidos a la acción fuera del motor conectado, incluidos 6,352 s en `BarrerVacias`.

| Registro de cálculo | Session9 | Session26 |
|---|---:|---:|
| Liquidaciones | 469 | 470 |
| Empleados distintos | 346 | 348 |
| Operaciones con errores | 3 | 4 |
| Suma de duraciones registradas | 590,828 s | 565,447 s |
| Primer inicio a último fin | 591,547 s | 591,934 s |

El intervalo completo del lote **prácticamente no mejora**. La suma de duraciones baja 25,381 s
(4,30 % descriptivo), pero el tiempo entre operaciones pasa de 0,719 a 26,487 s, sin causa atribuida
por este control. Cierre de Marea (89), Devengados (90) y Vacaciones (30) conservan exactamente
sus conjuntos empleado/período/tipo. Final incorpora dos y Regular comparte 244, quita dos y
agrega uno. No es una repetición controlada de los mismos datos y configuración. La nueva corrida
registra dos errores de Final y dos de Regular; sus causas e importes quedan fuera de este análisis.

La captura Session26 dura 924,961 s y termina **329,347 s después del último cálculo registrado**.
Asigna 659,817 s a muestras: 55,152 s son Idle explícito y 48,880 s están en 70 raíces desconectadas
de la acción principal. Quedan 265,144 s sin atribución; no se los identifica automáticamente como
SQL, bloqueo o espera de usuario. El árbol alcanza el informe de avisos posterior al cálculo.
Por eso comparar los 924,961 s de captura contra los 612,766 s anteriores daría una conclusión falsa
sobre el motor. El subárbol conectado `LiquidarConRegistro` baja de 547,336 a 523,864 s, también
descriptivo y sin reasignarle las ramas desconectadas.

Evidencia reproducible en `artifacts/perfil-posconciliacion-20261019/`: perfiles originales,
`analyze-profiles.cjs`, `comparison-analysis.json`, `compared-process-scope.json`, consultas SQL
y revisión independiente. Sólo se leyeron archivos y datos; no hubo cambios AL, publicación,
pruebas ni recálculos operativos en este análisis.

## Medición SQL de la inserción de líneas: 19/10/2026

Repetición realizada por el usuario en ArbuTest, observada con una sesión temporal de Extended
Events sobre la tabla exacta de líneas y con contadores SQL antes/después. No se modificaron AL,
índices, configuración ni datos de nómina desde las herramientas de medición. La captura empezó
a las 19:00:38 UTC, terminó a las 19:12:07 UTC y se eliminó a las 19:12:09; el catálogo posterior
confirmó que no quedó creada ni ejecutándose. Query Store estaba desactivado, sin historia SQL
para reconstruir Session26.

El registro funcional contiene una sesión de marzo: **470 liquidaciones intentadas, 348 empleados
y 4 operaciones con errores** (dos Final y dos Regular). Suma 603,915 s registrados y abarca
632,556 s, desde 19:01:07.840 hasta 19:11:40.397 UTC. Coinciden las cantidades con Session26;
eso no prueba identidad de resultados ni equivalencia del estado inicial. Esta repetición mide
la versión existente, no una optimización nueva.

### Coste SQL medido

El plan del INSERT conserva hash, plan, fecha de compilación y generación entre el inventario
de las 18:59:56 y el cierre de las 19:12:23 UTC. Su contador pasa de 364.155 a 484.589 ejecuciones.
La última ejecución, 19:11:40.167 UTC, precede por 230 ms al último fin del lote.

| Contador del plan, diferencia entre lecturas | Resultado |
|---|---:|
| INSERT ejecutados | **120.434** |
| Tiempo SQL transcurrido acumulado | **42,604323 s** |
| CPU SQL acumulada | 42,502646 s |
| Tiempo SQL medio por ejecución | **0,353757 ms** |
| Lecturas lógicas | 12.221.607 |
| Escrituras lógicas | 123.906 |
| Lecturas físicas | 19 |

Son ejecuciones del plan durante la ventana, incluidas pasadas transitorias de grossing-up y
posible trabajo revertido; **no son 120.434 líneas finales**. Los nueve índices de la tabla
registran también 120.434 inserciones de hoja cada uno. No se encontraron otros lotes en el
registro funcional de la ventana, pero los SPID del pool de BC no identifican por sí solos al
usuario/lote. Se verificó una sola entrada coincidente de caché; no se conserva un plan_handle
inicial para excluir exhaustivamente otras variantes o entradas expulsadas.

En las doce estructuras observadas, los contadores de espera por locks de fila/página no
aumentaron. Las esperas por latch de página sumaron 65 ms y por IO latch, 41 ms. Tampoco hubo
bloqueos en las 18 muestras de requests que coincidieron con el INSERT. Esto no mide todas las
esperas de la conexión, el flush del log al confirmar ni el tiempo del service tier.

La captura de eventos retuvo 109.972 INSERT de tres sesiones BC (54, 53 y 57). Se excluyeron
213 eventos del propio observador. El ring procesó 120.661 eventos, pero 10.476 se sobrescribieron
antes de la lectura: `droppedCount=0` y `truncated=0` **no garantizan cobertura completa**.
Por eso los totales anteriores proceden de los contadores del plan, no de sumar los eventos
retenidos. En esa muestra, mediana 0,348 ms, p95 0,471 ms y p99 0,651 ms; no extrapolarlos al
conjunto completo. El analizador valida todos los deltas y documenta la diferencia de ventanas.

Los **101,177 s** atribuidos a insertar líneas por Session26 son de un perfil AL anterior.
Restarles los 42,604 s SQL de esta repetición no mide la red ni el service tier: faltaría un perfil
AL simultáneo y comparable. Tampoco puede asignarse una parte de esos 42,604 s a un índice
concreto mediante el plan estimado.

### Mejora identificada: mantenimiento SIFT de K4 y K5

El INSERT mantiene nueve índices de tabla y tres vistas acumuladas SIFT: K2, K4 y K5. Su plan
contiene un seek y una actualización para cada vista. Esos seeks forman parte del mantenimiento;
los millones de seeks de sus estadísticas **no prueban millones de consultas de negocio**.
En la caché examinada, K4/K5 sólo aparecen dentro de INSERT/DELETE; K2 también aparece en tres
planes SELECT. La revisión está limitada a planes presentes y lotes que nombran la tabla/vistas;
no demuestra ausencia de consumidores ocasionales o externos.

La mejora propuesta es establecer **`MaintainSIFTIndex = false` sólo en K4 y K5**, conservando
ambas claves, `SumIndexFields = Importe`, sus índices ordinarios y **K2 sin cambios**. Así se evita
actualizar dos vistas en cada escritura. Las sumas AL siguen disponibles por lectura de la tabla,
como documenta [Microsoft](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/properties/devenv-maintainsiftindex-property);
una lectura que dependiera de esas vistas podría hacerse más lenta.

La propuesta coincide con los lectores actuales: los acumuladores anual/período recorren líneas
y suman en memoria; `YTD_LINEAS` filtra Estado, ausente de K4/K5. Las 21 fuentes activas sobre
la tabla 60012 son 19 SUM(Importe), una SUM(Cantidad) y una MAX(Importe), sin COUNT. Todas filtran
concepto, también ausente de esas SIFT. **K2 se conserva** porque acelera totales y neto dentro de
grossing-up y tiene lectores SQL observados. Esto justifica ensayar el cambio; todavía no mide
su ahorro ni sustituye una comparación de resultados.

Cambiar sólo `Insert(true)` a `Insert(false)` no habilita inserciones agrupadas: el campo
`No. Línea` tiene `AutoIncrement = true`, uno de los impedimentos documentados para
[buffered inserts](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/optimize-sql-bulk-inserts).
SQL devuelve timestamp y número de línea mediante OUTPUT en el mismo INSERT, sin una segunda
consulta de identidad. El motor necesita ese número inmediatamente para enlazar el detalle.
Cambiar numeración o mantener las pasadas de grossing-up sólo en memoria requeriría una revisión
más amplia de concurrencia, referencias y lectores del acumulado que cambia durante el cálculo.

Antes de aplicar K4/K5: comparar en un entorno aislado el mismo lote sobre estados iniciales
equivalentes; comprobar líneas, importes, totales, acumulados anual/período, convergencia GU,
vigencias y detalle de variables, normalizando sólo IDs/timestamps técnicos y verificando sus
relaciones. Medir cálculo completo, INSERT, DELETE y consultas agregadas; comprobar que siguen
los índices ordinarios y K2 y desaparecen únicamente las dos vistas previstas. Incluir lectores
ocasionales; la suite de conciliación por sí sola no cubre este cambio. No ejecutar fixtures ni
pruebas con rollback en ArbuTest operativo.

La medición terminó antes de implementar el cambio descrito debajo. No se promete
un porcentaje de ahorro sin comparar ambas versiones. Evidencia numérica y consultas
reproducibles en `artifacts/insercion-lineas-20261019/`: `insert-measurement-analysis.json`,
`counter-snapshot-after.json`, `process-scope-after.json`, `plan-review-insert.json`,
`plan-review-consumers.json` y `live-capture-cleanup.json`. No se guardaron parámetros SQL,
legajos ni importes salariales en esta medición.

### Implementación K4/K5 y comprobaciones previas a publicar

El 19/10, por pedido del usuario, `Tab60012.LineaLiquidacion.al` agrega únicamente
`MaintainSIFTIndex = false` a K4 y K5. Se conservan `SumIndexFields = Importe`, los índices
ordinarios, K2 completo, PK, `AutoIncrement`, todos los campos y el trigger que enlaza el detalle.
La comparación automatizada contra la copia anterior confirma que, al excluir comentarios y
esas dos propiedades, el contenido ejecutable es idéntico. El paquete compilado contiene
exactamente la fuente actual y sus 364 archivos AL coinciden con el proyecto.

La compilación de fuentes en una carpeta limpia terminó sin errores. La compilación inicial
desde la raíz encontró copias históricas dentro de `.snapshots`; ese resultado se descartó.
Permanecen advertencias preexistentes: 27 AL0432, una AL1029 y una AL0482 por la imagen HideList.
`app.json` sigue idéntico, versión 1.0.0.673; `rad.json` estaba ausente.

Se compararon **todas las agrupaciones existentes** de cada SIFT con la suma independiente
desde la tabla base, sin redondear ni exportar legajos/importes:

| Clave | Grupos comparados | Líneas representadas | Diferencias de suma/conteo o grupos faltantes |
|---|---:|---:|---:|
| K4 | 19.092 | 293.460 | **0** |
| K5 | 17.209 | 293.460 | **0** |
| K2, control conservado | 25.297 | 293.460 | **0** |

`NOEXPAND` obliga a leer cada vista y `EXPAND VIEWS` evita que SQL sustituya la suma base por
la misma SIFT que se está contrastando. El plan real confirmó tres lecturas de PK y tres de
vistas. Conteo y máximo rowversion fueron iguales antes/después. Es una observación estable
con READ COMMITTED, no una transacción snapshot: ambas opciones de versionado están desactivadas.
El hash `0x690B0CDCED3D77C4` pertenece a este ensayo; excluirlo de futuras búsquedas de consumidores
operativos de K4/K5, porque ahora sí aparecerá como SELECT en la caché.

**Alcance de la validación:** equivalencia exacta de sumas y conteos sobre los datos actuales,
conservación estructural de cálculo/trazas y compilación. No se ejecutaron CalcSums AL ni un
recálculo completo con las vistas desactivadas, ni se regeneraron trazas para compararlas.
El servidor sólo tiene BC252 apuntando a Migr2013R2; la empresa TEST_ORDEN comparte el esquema.
No hay una instancia Payroll A/B separada disponible. Una comparación integral aislada exige
otra base e instancia; no se alteró la instalación operativa para simular ese aislamiento.

**Estado: publicado con Synchronize el 19/10/2026 a las 16:28:51 de Argentina**, por pedido
del usuario, sin cambiar la versión 1.0.0.673. Se confirmó el Package ID exacto
`4BA4BB2F-883A-4B62-8C02-B9DEE6C09E21` y HTTP 200. El paquete publicado corresponde a las
375 entradas verificadas antes de compilar (364 fuentes AL); SHA256
`6491E6CB199D727C603F76C7C204B8B5D1A5A34B4D0E58BA675330E5FA383E3F`.

El control posterior confirmó que desaparecieron sólo las vistas SIFT K4/K5 de Línea:
K2 conserva definición e índice, y los 35 campos y nueve índices ordinarios conservan
columnas, INCLUDE, opciones y compresión. Las 22 tablas físicas controladas conservaron
conteos y máximos rowversion, incluidas las 293.460 líneas y las tablas de trazabilidad.
Esos indicadores no equivalen a comparar íntegramente cada contenido. No se ejecutaron
cálculos ni pruebas AL durante la publicación. El usuario completó después la corrida de
Session25(1), analizada debajo; sigue pendiente una comparación integral de resultados y trazas.

Publicación y controles reproducibles en `artifacts/publicacion-k4-k5-20261019/`:
`publication-result.json`, `verification-summary.json`, `preflight.json` y `postflight.json`.
Evidencia en `artifacts/k4-k5-sift-20261019/`: `source-contract-check.json`, `compile-result.json`,
`comparar-grupos-sift-base-result.json` y la consulta reproducible. El inventario del entorno
está en `artifacts/insercion-lineas-20261019/isolated-environment-inventory.json`.

## Perfil posterior a K4/K5: Session25(1) del 19/10/2026

El nuevo perfil corresponde a la corrida iniciada después de publicar la desactivación de
SIFT K4/K5. Se compara con **Session26**, anterior al cambio, y se complementa con la caché SQL
del INSERT. El paquete instalado sigue siendo `4BA4BB2F-883A-4B62-8C02-B9DEE6C09E21`.

### Alcance y duración del lote

Ambas corridas usan **Crear y calcular** desde Períodos y contienen exactamente los mismos
348 empleados y las mismas 470 claves empleado/período/tipo de marzo: 89 Cierre de Marea,
90 Devengados, 16 Final, 245 Regular y 30 Vacaciones. Los documentos se recrearon: no comparten
números de liquidación. Coinciden las cuatro claves empleado/período/tipo con error
(dos Final y dos Regular); no se compararon sus mensajes o causas. Esto no prueba identidad de datos iniciales, configuración, cachés,
carga del servidor, importes finales ni trazabilidad regenerada.

| Tiempo registrado | Session26 | Session25(1) | Reducción observada |
|---|---:|---:|---:|
| Primer inicio a último fin | 591,934 s | **569,926 s** | **22,008 s / 3,72 %** |
| Suma de duraciones de las operaciones | 565,447 s | 544,247 s | 21,200 s / 3,75 % |
| Motor conectado en el perfil | 523,864 s | 503,251 s | 20,613 s / 3,93 % |

La nueva corrida abarca 19:38:38.850–19:48:08.777 UTC. Ambas sesiones están completas dentro
de sus respectivos perfiles. El tiempo de grabación baja de 924,961 a 801,972 s, pero incluye
329,347 y 228,787 s posteriores al último cálculo, respectivamente. **No usar esa diferencia
como mejora del motor**. El perfil nuevo atribuye 676,992 s, incluidos 94,441 s de Idle y
49,833 s en 73 raíces desconectadas; quedan 124,980 s sin atribuir. Esas categorías no permiten
inferir tiempo SQL, bloqueos o espera de usuario.

### Dónde mejora y qué sigue costando

| Función | Session26 | Session25(1) | Variación |
|---|---:|---:|---:|
| Insertar líneas, propio | 101,177 s | **90,285 s** | **−10,77 %** |
| Borrar líneas, propio | 18,288 s | **7,431 s** | **−59,37 %** |
| Conciliación de parámetros, inclusivo | 69,787 s | 69,033 s | −1,08 % |
| Resolver fuentes, inclusivo | 45,717 s | 46,941 s | +2,68 % |
| Cuenta corriente de francos, inclusivo | 34,678 s | 37,806 s | +9,02 % |
| Resolver aplicación de CCT, inclusivo | 27,747 s | 29,798 s | +7,39 % |
| Escribir detalle de variables, propio | 22,477 s | 18,909 s | −15,87 % |

Insertar y borrar juntos bajan **21,750 s**, de 119,465 a 97,715 s (18,21 %). La inserción
continúa como mayor costo propio del motor; el helper sólo ejecuta `LinLiq.Insert(true)`.
La conciliación sigue siendo la siguiente operación concentrada: 60,277 de sus 69,033 s están
en `TieneUsoExactoActivo`, que todavía consulta por cada candidata no cubierta por la precarga.
Conviene medir y reducir esas consultas restantes antes de rediseñar numeración o trazabilidad.
Las variaciones menores de funciones no modificadas no se atribuyen a K4/K5. Los tiempos
inclusivos contienen a sus descendientes: no sumarlos indiscriminadamente. `hitCount` sigue
siendo muestreo, no cantidad de inserciones, consultas ni liquidaciones.

### Contraste SQL después de sincronizar

El INSERT conserva query hash `0x5568F086BB7E77AF`, pero tiene plan nuevo
`0xA227D4D4C9779C48`, compilado a las 19:38:40.070 UTC y ejecutado por última vez a las
19:48:08.580 UTC. El catálogo y el plan confirman **sólo SIFT K2**, con los nueve índices
ordinarios conservados, incluidos K4/K5. No se infiere el coste de cada operador de su plan estimado.

| Contador SQL | Medición anterior a K4/K5 | Caché del plan posterior |
|---|---:|---:|
| Ejecuciones INSERT | 120.434 | 120.434 |
| Tiempo SQL acumulado | 42,604323 s | **31,483534 s** |
| Tiempo SQL medio | 0,353757 ms | **0,261417 ms** |
| CPU acumulada | 42,502646 s | 31,356948 s |
| Lecturas lógicas | 12.221.607 | 8.072.431 |

Se observa **26,10 % menos tiempo SQL por INSERT** y 33,95 % menos lecturas lógicas.
La medición anterior es la repetición instrumentada de las 19:01–19:11 UTC, no Session26.
La posterior es un acumulado desde compilación, sin lectura inicial ni filtro por sesión AL;
sus fechas y 120.434 ejecuciones son compatibles con esta corrida, pero no prueban atribución
exclusiva. Tampoco se controlaron cachés o carga concurrente. El plan más simple y las dos
mediciones respaldan el beneficio; no confundir el 26,10 % de SQL con ahorro global del lote.
No restar SQL a AL para diagnosticar red o service tier.

Evidencia reproducible en `artifacts/perfil-post-k4-k5-20261019/`: los dos perfiles originales,
analizador, `comparison-analysis.json`, `compared-process-scope.json`,
`sql-insert-plan-result.json`, consultas de sólo lectura y revisión independiente.
Este análisis no modificó código, esquema ni datos de nómina. El perfil mide rendimiento;
no sustituye la comparación de resultados y trazabilidad entre versiones.

## Conciliación por recibos testigo (19/10/2026, instalada y probada)

Se implementó en `Gestión Liquidación` la reutilización de usos de un **recibo testigo**.
La precarga propia permanece. Para cada versión todavía desconocida, el mismo TOP1 exacto
devuelve un consumidor activo; se carga una vez su conjunto de usos por número de documento
y se agregan sus triples base/clave/vigencia al temporal local. Las siguientes candidatas
ya acreditadas evitan otra consulta. Una ausencia conserva TOP1 y respaldo histórico.
No se cambia la query 110000, el punto de llamada del motor, los estados, las fórmulas,
la escritura de usos/trazas ni los `Commit`. Tampoco se conservan respuestas entre llamadas.

La cabecera testigo queda protegida por el `ReadExclusive` existente. El lector parcial
restablece filtros/clave y pide `UpdLock` sobre los usos de ese documento. Es una precarga
positiva; no se deduce ausencia de consumidores de un mapa anterior. El aislamiento de
la query y su duración se documentan en
[ReadState](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/properties/devenv-readstate-property).
El cambio agrega lectura/bloqueos de las demás filas de uso del testigo, y requiere comprobar
concurrencia al probarlo; no se afirma que el patrón de bloqueo sea idéntico.

### Comprobación SQL de sólo lectura

La simulación sobre **15 documentos actuales**, tres por cada uno de los cinco tipos,
comparó 5.094 candidatas contra un EXISTS independiente: **5.094 coincidencias, cero diferencias**.
Todos esos casos resultaron positivos; el respaldo histórico, ausencias y transiciones se
cubren mediante las pruebas AL, posteriormente aprobadas (30/30). Conteos y máximos rowversion
de versiones, usos y cabeceras fueron iguales al comenzar y terminar; no es aislamiento snapshot.

| Trabajo posterior a la precarga propia | Antes | Testigos |
|---|---:|---:|
| Consultas exactas TOP1 | 4.567 | 1.402 |
| Lecturas adicionales de usos por testigo | 0 | 1.402 |
| **Consultas combinadas** | **4.567** | **2.804** |

Se evitan **1.763 consultas, 38,60 %** en ese tramo, contando el coste de las nuevas lecturas.
No presentar la baja aislada del TOP1 como ahorro total. Si se incluyen las 30 lecturas comunes
de cabecera/usos propios, el conteo pasa de 4.597 a 2.834 (38,35 %). Por llamada se leen
92–95 testigos, con 3.542–3.664 filas de uso. Hay 531 cargas que no aportan otra triple nueva
además de la que motivó el TOP1: es trabajo adicional real y el beneficio depende del reparto
de versiones entre documentos.

La simulación ejecuta SELECT con READ COMMITTED y autocommit; no reproduce la transacción
AL ni sus bloqueos. TOP1 no especifica orden y el plan puede elegir otro testigo, cambiando
la cobertura. Los tiempos de cliente incluyen el transporte y la materialización .NET,
no el motor AL; **no se proyecta este porcentaje a los 69,033 s del perfil ni al lote**.
Los contadores IO/CPU/tiempo SQL del arnés de testigos no quedaron capturados de forma
verificable y figuran como no disponibles; sus ceros iniciales no se usan como medición.
La optimización está instalada; la primera comparación de una corrida completa figura más abajo.

Se descartó agrupar todos los consumidores con COUNT: en la misma muestra 339–343 versiones
se expandían a unas 54.000 filas de uso por llamada, casi toda la tabla. Con UPDLOCK habría
ampliado las lecturas y bloqueos a cabeceras que el TOP1 puede evitar. No quedó esa query en
el código ni se modificó el esquema.

### Estado de la entrega

Compilación limpia de **364 fuentes, cero errores**, con las 29 advertencias preexistentes.
`app.json` sigue en 1.0.0.673. Se agregaron cuatro pruebas; **30/30 aprobadas** en la empresa
aislada `TEST_ORDEN_20261017` (4,08 s), con sus 65 tablas sin cambios por conteos y máximos
rowversion. La comparación de fuentes contra la publicación K4/K5 deja sólo tres archivos AL
diferentes para esta optimización: Gestión Liquidación, Test Uso Parametros
y su runner. Histórico/oráculo, query, permisos, tablas, fórmulas y trazas quedan sin cambios.
La revisión independiente no encontró defectos funcionales en el diff. El paquete de prueba
se eliminó y `rad.json` estaba ausente.

El paquete activo `B3169B4B-9C28-4C44-824B-B3DE5292B4ED` ya contenía la optimización al
atender el pedido de publicación, junto con cambios de SIRADIG. Se verificaron los 361 objetos
AL instalados contra el workspace (sólo normalización de BOM y saltos de línea), sin diferencias.
No se hizo otro POST ni se reemplazó esa entrega por el snapshot anterior. El paquete permaneció
estable durante las pruebas. Esto verifica disponibilidad y regresión funcional; el rendimiento
del lote completo se compara en la sección siguiente y la concurrencia sigue sin certificarse.
Evidencia: `artifacts/publicacion-testigos-conciliacion-20261019/`.

Evidencia en `artifacts/conciliacion-usos-conjunto-20261019/`: `witness-measurement.json`,
consultas y simulación reproducibles, `compile-result.json`, `compile-inputs.json`,
`source-contract-check.json` y `review-final.json`. La medición exploratoria del agrupado
queda separada en `measurement.json`; no corresponde al diseño entregado.

## Perfil posterior a recibos testigo (19/10/2026)

Se compararon **Session25(1)**, anterior a la optimización, y **Session4(4)**, el perfil más
reciente. SQL confirma marzo 202603 en ambos: mismos 348 empleados, mismas 470 claves
empleado/período/tipo, sin duplicados, y las mismas cuatro claves con error (dos Final y dos
Regular). Los números de documento se recrearon. Las dos sesiones están completas dentro de
sus perfiles. **Session4(3) es enero**: 570 documentos, 329 empleados y dos errores; sus
28,276 s de conciliación no se usan como mejora frente al lote de marzo.

| Medida | Antes | Después | Diferencia observada |
|---|---:|---:|---:|
| Rango del proceso, primer inicio a último fin | 569,926 s | 559,406 s | −10,520 s / −1,85 % |
| Suma de duraciones registradas | 544,247 s | 533,981 s | −10,266 s / −1,89 % |
| Conciliación, árbol inclusivo | 69,033 s | 62,504 s | −6,529 s / −9,46 % |
| Conciliación y lectores, propios sin solapamiento | 69,033 s | 64,011 s | −5,022 s / −7,27 % |
| Insertar líneas, propio | 90,285 s | 88,897 s | −1,387 s / −1,54 % |
| Resolver fuentes, inclusivo | 46,941 s | 47,056 s | +0,116 s |
| Cuenta corriente de francos, inclusivo | 37,806 s | 31,159 s | −6,647 s |
| Aplicación de CCT, inclusivo | 29,798 s | 26,846 s | −2,952 s |
| Detalle de variables, propio | 18,909 s | 18,303 s | −0,606 s |

**La mejora existe, pero parte del trabajo pasó al lector de usos.** `TieneUsoExactoActivo`
baja de 60,277 a 20,449 s propios; su hijo `CargarVersionesRegistradas` añade 34,908 s.
La precarga del documento propio consume otros 0,401 s y el cuerpo de conciliación 6,747 s:
en conjunto forman los 62,504 s inclusivos. Hay además 1,506 s del lector como raíz
desconectada. La suma disjunta de las cuatro funciones da 64,011 s sin inventar el padre de
esa raíz. Por eso ni el 66,08 % de reducción del helper exacto ni el 38,60 % de consultas de
la simulación equivalen a la mejora completa de conciliación.

La inserción sigue como mayor costo propio individual, **88,897 s**. La conciliación con
sus lectores sigue siendo el siguiente bloque concentrado, seguido de fuentes (47,056 s).
El próximo paso dentro de conciliación es medir lecturas y cobertura adicional por testigo:
el lector concentra ahora más tiempo que la consulta exacta. Cualquier cambio de selección
de testigos o de caché debe conservar la validación de cabecera activa, el alcance de cada
llamada, las claves completas, los bloqueos, las ausencias y la trazabilidad.

El reloj de captura pasa de 801,972 a 582,075 s, pero incluye 94,441 y 6,435 s de Idle y
124,980 y 4,150 s sin atribuir. **No es la duración del cálculo.** Los tiempos de funciones
son muestreo ponderado; no son CPU pura, cantidad de consultas ni llamadas. No sumar tiempos
inclusivos de padres e hijos. La coincidencia del alcance y de claves con error no certifica
igualdad de datos iniciales, configuración, importes o trazas. Tampoco se controlaron cachés
ni carga concurrente: las reducciones son observadas, no una atribución causal completa.

El paquete observado al analizar es `944A05F2-F010-4F96-A899-0F1B3F6E788C`, versión
1.0.0.673; esa observación no reconstruye qué paquete estaba activo en cada instante pasado.
Ambos perfiles nuevos contienen la ruta del lector de testigos. El workspace conserva
Gestión Liquidación y Motor Liquidación del cambio revisado; hay cambios posteriores en
SIRADIG y permisos. No se modificaron AL, esquema ni datos operativos en este análisis.

Evidencia reproducible: `artifacts/perfil-post-testigos-20261019/`, con los tres perfiles y
sus hashes, `summary.json`, análisis `latest/` e `intermediate/`, `scope-comparison.json`,
scripts de sólo lectura y `review-profile.json` independiente.

## Aporte útil de testigos y precarga adaptativa (19/10/2026, publicado y 35/35)

Se midió cuántas **candidatas todavía pendientes** resuelve cada testigo, excluyendo la
versión que el TOP1 ya había demostrado. Las versiones nuevas ajenas al conjunto de candidatas
no cuentan como beneficio. La primera captura se descartó: otra corrida estaba modificando
usos y cabeceras. SNAPSHOT y RCSI estaban deshabilitados; no se alteró esa configuración ni se
bloqueó el cálculo para medir.

Se obtuvo después una captura con conteos y máximos rowversion iguales antes y después,
agrupando los TOP1 parametrizados para reducir las idas y vueltas. Se ejecutaron **479 TOP1
reales**, uno por triple distinta, y un EXISTS independiente. La misma selección se reutilizó
en una simulación en memoria de los **470 documentos presentes del lote de marzo**, con
159.520 evaluaciones de candidatas. Cuatro documentos no tenían precarga propia activa;
simular 470 llamadas no prueba que el motor ejecutara FaseCerrar 470 veces. Es una comparación
de políticas sobre el estado observado, no una reproducción de la evolución de aquel lote.

En la política anterior, de **43.993 cargas**, **18.089 (41,12 %)** no resuelven ninguna
pendiente adicional y **7.318 (16,63 %)** resuelven sólo una. En total cubren 98.398 candidatas
adicionales: media 2,24 por carga, mediana 1. Cargar más triples no siempre significa resolver
trabajo pendiente. Se conserva el detalle por cada carga, tipo y base en los artefactos.

### Cambio implementado

`Pendientes` es un temporal local con PK completa, separado del cursor `Candidatas`. La actual
se retira antes de su TOP1; conserva consulta exacta e histórico incluso si era la última.
El lector de testigos sólo elimina pendientes confirmadas y termina al vaciarse el conjunto.
Una carga real con **cero aporte adicional** desactiva las próximas precargas disparadas por
esa base durante la llamada. Cada candidata desconocida conserva su TOP1; la política se
reinicia al cambiar de base. No hay decisiones negativas cacheadas ni caché entre liquidaciones.

| Trabajo modelado para los 470 documentos | Anterior | Adaptativa |
|---|---:|---:|
| Consultas exactas TOP1 | 43.993 | 47.619 |
| Lecturas adicionales de testigos | 43.993 | 28.572 |
| Consultas comunes de precarga propia | 936 | 936 |
| **Consultas combinadas** | **88.922** | **77.127** |
| Filas de uso ofrecidas por las lecturas adicionales | 1.694.499 | 1.174.809 |
| Candidatas confirmadas por precarga de testigos | 98.398 | 94.772 |
| Cargas sin aporte adicional | 18.089 | 5.840 |

El balance incluye las **3.626 consultas exactas adicionales** al perder algunas oportunidades
de precarga: se evitan 15.421 lectores y quedan **11.795 consultas menos (13,26 %)**. Las filas
ofrecidas por los lectores modelados bajan **519.690 (30,67 %)**. En esta muestra coinciden
con las recorridas; no se atribuye ahorro adicional al corte temprano ni al prefetch.
Esto **no** son 88.922 consultas realmente ejecutadas ni una reducción de segundos medida.

El subconjunto de **466 documentos con precarga propia válida** también mejora: 88.166 →
76.475 consultas y 1.680.047 → 1.164.657 filas modeladas. Cada llamada simulada ahorra
22–29 consultas (mediana 26); ninguna empeora. Sus 158.164 evaluaciones coinciden con EXISTS.
La mediana de pendientes adicionales confirmadas por carga pasa de 1 a 2. Este subconjunto
se define por el estado observado y no demuestra cuántas llamadas reales hubo a FaseCerrar.

Se descartó leer sólo la base de la candidata: aquí no aportó ninguna pendiente adicional y
subió el modelo a 255.022 consultas. Omitir solamente la última carga ahorró 470 consultas;
por sí solo no resuelve el coste observado. La política adaptativa preserva la cobertura de
otras bases que sí aportan los testigos útiles.

Las cuatro políticas dieron **cero falsos positivos y cero falsos negativos** en 159.520
evaluaciones contra EXISTS. Todas las candidatas de esta muestra tenían consumo exacto;
no presentar ese contraste como validación de negativos, histórico o concurrencia. Los 35
tests AL incluyen esos contratos y pasaron en la empresa aislada. La consulta,
el orden de precarga propia, los campos parciales y aislamientos permanecen; el patrón exacto
de locks puede variar al sustituir lectores por TOP1 adicionales. No se modifican fórmulas,
resultados, registros de uso ni trazas, y no se agregan `Commit`.

Compilación de **367 fuentes sin errores**, versión 1.0.0.673 conservada, mismas 29 advertencias.
Publicado en BC252 con `Synchronize`, Package ID `F31EB089-105C-475C-8961-8C45BCC65E7D`.
Las **35/35 pruebas pasaron en 4,73 s** en `TEST_ORDEN_20261017`; paquete estable y controles
de las 65 tablas aisladas sin cambios. No se ejecutaron fixtures en ArbuTest. La primera corrida
posterior se compara en la sección siguiente; el tiempo de la suite no mide la mejora del lote.

Evidencia: `artifacts/conciliacion-testigos-utiles-20261019/`, con `scope-measurement.json`,
lecturas SQL y simulador, distribuciones por carga/tipo/base, `source-contract-check.json`,
`compile-result.json` y revisión independiente `review-final.json`. Los sentinelas no son
aislamiento transaccional ni hashes de contenido; no se modificó la configuración SQL.
Publicación y ejecución aislada: `artifacts/publicacion-testigos-utiles-20261019/`.

## Perfil posterior a precargas adaptativas (19/10/2026)

**Session24 frente a Session4(4): la conciliación baja 5,61 %, mientras el lote completo
tarda 8,27 % más.** Se verificaron en Registro Proceso las mismas 470 claves
empleado/período/tipo de marzo 202603, los mismos 348 empleados y cuatro claves con error
en ambas corridas, sin duplicados. Los documentos se recrearon. Las dos sesiones están
completas dentro de sus perfiles. Las cabeceras anteriores ya no existen y Registro Proceso
no guarda proyecto: no se acredita igualdad histórica de proyectos, configuración o importes.
Coinciden tres de los cuatro mensajes de error; el cuarto conserva la categoría de Regular
con días ya liquidados por otros recibos. No apareció una categoría nueva, pero no presentar
las claves coincidentes como igualdad de todos los mensajes ni como validación de resultados.

| Medida | Session4(4) | Session24 | Diferencia observada |
|---|---:|---:|---:|
| Rango del proceso, primer inicio a último fin | 559,406 s | 605,684 s | +46,278 s / +8,27 % |
| Suma de duraciones registradas | 533,981 s | 574,881 s | +40,900 s / +7,66 % |
| Conciliación y lectores, propios sin solapamiento | 64,011 s | 60,419 s | −3,592 s / −5,61 % |
| Conciliación, árbol inclusivo | 62,504 s | 59,313 s | −3,192 s / −5,11 % |
| Lectores de testigos, incluidas raíces separadas | 36,414 s | 23,927 s | −12,487 s / −34,29 % |
| Consulta exacta, propio | 20,449 s | 26,145 s | +5,696 s / +27,86 % |
| Cuerpo de conciliación, propio | 6,747 s | 9,743 s | +2,997 s / +44,41 % |
| Insertar líneas, propio | 88,897 s | 90,223 s | +1,326 s / +1,49 % |
| Resolver fuentes, inclusivo | 47,056 s | 49,978 s | +2,922 s |
| Cuenta corriente de francos, inclusivo | 31,159 s | 35,005 s | +3,846 s |
| Aplicación de CCT, inclusivo | 26,846 s | 33,834 s | +6,988 s |
| Detalle de variables, propio | 18,303 s | 24,377 s | +6,074 s |
| Borrado de líneas, propio | 6,733 s | 9,653 s | +2,919 s |

El ahorro del lector es real en el tiempo atribuido, pero una parte se compensa con el
mayor tiempo de las consultas exactas y del cuerpo de conciliación. La precarga propia pasa
de 0,401 a 0,603 s. El balance neto es **3,592 s**, no los 12,487 s aislados del lector.
Se compara por función cumplida: el nuevo `ConfirmarPendientesDeTestigo` reemplaza la carga
de testigos del antiguo `CargarVersionesRegistradas`; este último permanece para la precarga
propia. Comparar sólo ese nombre daría una falsa reducción del 98,91 %.

La familia completa suma tiempos propios disjuntos de conciliación, consulta exacta y ambos
lectores. Incluye 1,506 s del lector antiguo y 1,106 s del nuevo como raíces separadas,
sin inventar su padre. La suma coincide con el árbol de conciliación más esas raíces.
Los demás tiempos inclusivos de la tabla no deben sumarse entre sí ni a sus descendientes.

**La inserción de líneas sigue siendo el mayor costo propio individual: 90,223 s**, el
14,56 % del tiempo no ocioso atribuido. La conciliación completa queda en 60,419 s y las
fuentes en 49,978 s. Entre los tiempos propios ajenos a conciliación, el mayor aumento es
`WriteVariableDetail` (+6,074 s); CCT también aumenta como bloque inclusivo. Todas las clases
de liquidación aumentan su duración registrada. Esta corrida no muestra una mejora global.

El siguiente diagnóstico prioritario es separar el número y costo de las inserciones físicas
de líneas de las pasadas de grossing-up y de la pasada final, junto con las escrituras de detalle.
`InsertarLineaLiquidacion` contiene `LinLiq.Insert(true)`; el perfil no distingue CPU SQL,
esperas, transporte o mantenimiento de índices. La auditoría intermedia de grossing-up ya se
omite y el detalle de variables ya se deduplica en temporal: no proponer de nuevo esos cambios.
Las líneas intermedias aún participan en el cálculo y en sus acumulados; suprimirlas requiere
validar esa semántica y los vínculos de la traza, no sólo reducir INSERT.

Las ventanas de captura son 582,075 y 656,962 s. El tiempo Idle explícito es 6,435 y
5,772 s; el residual sin atribuir crece de 4,150 a 31,447 s. El intervalo después de la
última operación es 19,249 y 47,443 s y no equivale automáticamente a Idle. Por eso la duración
del lote procede de Registro Proceso. No se suman ni se redistribuyen esos residuos a SQL.

Son dos corridas observadas con muestreo, sin control de cachés, carga concurrente o esperas:
no permiten atribuir toda la variación al ajuste. Los porcentajes modelados de consultas y
filas de la sección anterior tampoco son contadores de esta ejecución. El perfil nuevo
contiene `ConfirmarPendientesDeTestigo`; el paquete observado sigue siendo
`F31EB089-105C-475C-8961-8C45BCC65E7D`, publicado antes de la captura. No se modificó AL,
esquema, configuración, instrumentación ni datos operativos durante este análisis.

Evidencia: `artifacts/perfil-post-testigos-utiles-20261019/`, con ambos perfiles y hashes,
`summary.json`, `analysis/`, `scope-comparison.json`, consultas agregadas de sólo lectura,
scripts reproducibles y revisión independiente `review-profile.json`.

## Relacionado

[[Ciclo de cálculo de una liquidación]] · [[Contexto de liquidación y variables]] · [[Evaluador de fórmulas - sintaxis]] · [[Procesos por lotes y progreso]]
