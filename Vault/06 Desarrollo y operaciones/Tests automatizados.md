---
tipo: guia
tags: [desarrollo, tests, calidad]
fuente: [test/Codeunits/Cod50021.TestEvaluadorFormula.al, test/Codeunits/Cod110034.TestFormateadorFormula.al, test/Codeunits/Cod110045.TestFinEfectivoLiq.al, test/Codeunits/Cod110046.TestCorreccionesRendLiq.al, test/Codeunits/Cod110047.TestCacheLiquidacion.al, test/Codeunits/Cod110048.TestEscrituraAuditoria.al, test/Codeunits/Cod110056.TestDetalleCalculo.al, test/Codeunits/Cod110070.RunnerTestsLiq.al, test/Codeunits/Cod110073.TestUsoParametros.al, test/Codeunits/Cod110081.TestControlPrevioLiq.al, test/editorFormula.atributos.test.cjs, .altestrunner/config.json]
actualizado: 2026-10-21
---

# Tests automatizados

## Preparación: destino de nómina sin duplicar atributos (21/10/2026)

La suite de control previo contiene ahora **60 pruebas**; el runner aislado exige
esa cantidad. Las siete regresiones de proyectos cubren atributo `PROY_NOMINA`
válido sin copia en Job, campo específico y respaldo general válidos, destinos
inexistentes/productivos/autorreferentes, vigencia exacta al arribo, filtros,
deduplicación y ausencia de escrituras. Una falta de destino de una eventual
transición se comprueba como revisión opcional, fuera de **Errores comprobados**.

Compilación integrada sin errores, versión y `app.json` conservados en
**1.0.0.678**. Estos cambios todavía **no se publicaron ni ejecutaron** en BC;
el resultado anterior de 53 pruebas corresponde al código instalado de aquella
validación y no acredita estas siete regresiones nuevas.

## Puerto personal posterior al arribo (21/10/2026)

`Runner Tests Liq.EjecPuertoCobertura` pasó **10/10 pruebas** en **1,26 segundos**,
exclusivamente en `TEST_ORDEN_20261017`, todas con `AutoRollback`. El runner exige
exactamente diez casos y sólo selecciona el prefijo `PuertoCobertura` de la CU110046.
Los fixtures verifican la empresa antes de escribir; no llaman al cálculo normal
ni crean recibos. Compilación sin errores y publicación `Synchronize`, sin RAD,
con versión **1.0.0.678** y `app.json` conservados. Paquete
`47deec09-b51e-478c-89ae-c48f55b46275`.

Cubren puerto posterior dentro de cobertura, empleado que termina en el arribo,
límite de fin de mes, guarda por tipo y período, reinicio mediante `Init` anterior,
puerto previo, estado/proyecto ajeno, coberturas sin extensión, fuente que sigue
leyendo `FECHA_REF`, cobertura de sólo puerto posterior y un hueco entre tramos.
Comprueban navegación, puerto y viaje por separado, sin modificar fechas fuente
ni marcas de uso. Ver [[dia-de-puerto-no-estira-la-marea]].

Las 370 fuentes instaladas coinciden con el compilado: sólo cambiaron motor,
contexto, pruebas y runner; ningún esquema de tabla. Las 59 tablas operativas,
las 11.633 cabeceras completas y las cuatro capturas completas de conceptos,
fórmulas, fracciones y restricciones quedaron idénticas. Las 62 tablas controladas
de la empresa aislada también quedaron iguales, sin recibos ni fixtures. No se
recalcularon liquidaciones. Evidencia privada:
`.snapshots/correccion-puerto-vacaciones-estados-puestos-20261021/`.

## Preparación: reglas explícitas de fecha (21/10/2026)

`Runner Tests Liq.EjecControlPrevio` pasó **53/53 pruebas** en **5,49 segundos**,
exclusivamente en `TEST_ORDEN_20261017`: 51 con `AutoRollback` y dos lectores sin
escrituras. El runner exige exactamente 53. Compilación sin errores; versión y
`app.json` conservados en **1.0.0.678**. Publicado con `Synchronize`, sin RAD,
paquete `0372d719-c417-4986-b4bf-f3bac1951108`.

Las trece regresiones nuevas comprueban reglas temporales sin lector textual,
enero dentro del límite frente a marzo/abril vencidos, límite inclusivo, cero cargado,
filas sólo futuras, base sin filas, empleado ajeno al alcance, genérica más reciente,
regla imposible con límite futuro y ancla `<-CM>` igual a la referencia. Conservan las
ausencias sin regla como revisiones opcionales, agrupan por clave física y comprueban
reinicio entre períodos sin marcas `En Uso` ni escrituras operativas. Incluyen claves
históricas sin base y ejes distintos al fin del mes y a la baja, recorriendo mensual
y final en ambos órdenes.

Las 370 fuentes instaladas coinciden con el compilado: sólo cambiaron tres codeunits
(control, pruebas y runner); no hay cambios de esquema ni de fórmulas, fracciones o
restricciones de conceptos. Las 62 tablas de la empresa de pruebas conservaron conteo
y revisión, sin recibos ni fixtures. Durante la revisión hubo cálculos simultáneos de
marzo en la empresa operativa: cambiaron 54 cabeceras entre la captura inicial y la
final. Por eso no se afirma igualdad de todos los recibos desde el inicio. Esa
actividad terminó antes de la publicación final; las dos capturas posteriores son
estables. Esta tarea no ejecutó cálculos operativos ni restauró el trabajo simultáneo.

Evidencia privada: `.snapshots/preparacion-fechas-20261021/`. Ver
[[Flujo operativo mensual de liquidación]] y [[Parámetros y vigencias]].

## Preparación: errores comprobados y contexto opcional (20/10/2026)

`Runner Tests Liq.EjecControlPrevio` pasó **40/40 pruebas** en
`TEST_ORDEN_20261017`, en 7,53 segundos. Son 38 pruebas con `AutoRollback` y dos
lectores léxicos sin escrituras. El runner exige exactamente 40 casos. La versión
**1.0.0.678** y `app.json` se conservaron; paquete publicado
`09bec76e-b089-4a38-af5a-65043f6006c8`.

Las regresiones prueban perfiles 0/1/2, filtro de severidad en grupo 2 con
intersección de filtros del usuario y grupo 4, y conservación de las filas al
alternar vista. Verifican la obligatoriedad global como advertencia, la omisión de
selectores/fallback acreditados, la conservación de auxiliares leídos y la fuente
Code/Text a Decimal sin lectores frente a una fuente referida. Un filtro estructural
inválido de una fuente activa sigue siendo error aunque nadie lea su resultado.
Las tasas ausentes/no positivas se distinguen del contexto no resoluble, sin
arrastrar el indicador de la consulta anterior.

Dos pruebas ejecutan el informe real a XML en memoria mediante `TempBlob`: una
excluye filas ocultas por área y severidad; la otra comprueba el resumen vacío sin
revelar ni borrar las revisiones del origen. El período sintético no existe, por lo
que la prueba también acredita que `SetBuffer` no reanaliza la nómina. No se crean
archivos ni documentos de liquidación.

Se cotejaron las 370 fuentes instaladas con el compilado: sólo cambiaron seis
objetos del control, presentación y pruebas; ningún esquema de tabla. Los diseños
RDLC mantienen campos y expresiones; la diferencia de orden de una definición
nombrada del dataset no altera la impresión. Las 59 tablas operativas, las 11.633
cabeceras completas y las cuatro capturas completas de configuración quedaron
idénticas desde el corte previo a publicar. Las 62 tablas controladas de la empresa
aislada también quedaron iguales, sin recibos ni fixtures persistentes.

Antes de ese corte hubo cambios de fórmulas/parametrización y recálculos ajenos;
se conservaron y documentaron sin restaurarlos. Esta tarea no ejecutó cálculos
operativos ni cambió fórmulas de importe. Evidencia privada:
`.snapshots/preparacion-solo-errores-20261020/`.

## Preparación: aceptación de la segunda exportación (20/10/2026)

`Runner Tests Liq.EjecControlPrevio` pasó **35/35 pruebas** en
`TEST_ORDEN_20261017`, en 5,71 segundos. Las tres regresiones nuevas cubren
código y proyección numérica de atributos de lista; selectores compuestos sin
ocultar lecturas directas ni fuentes inactivas; y agrupación de una misma ausencia
de atributo con severidad máxima, lectores y repeticiones conservados. Los dos
casos léxicos son sólo lectura y los otros 33 usan `AutoRollback`.

El inspector usa el código cuando el comparando derecho es un literal de texto
válido y, en otro caso, el valor numérico congelado en el atributo seleccionado,
siguiendo el motor. No deriva el número del catálogo actual ni interpreta el código
como número. Las colisiones y conversiones pendientes conservan contexto sin resolver.

Sólo se modificaron el control previo, su codeunit de pruebas y el runner. No hubo
cambios de esquema ni RDLC. La instalación concurrente ya contenía exactamente las
370 fuentes compiladas; se verificó antes y después de probar y no se repitió la
publicación. Paquete `076b4bcb-bbb9-409e-8333-820b554b4aa1`, versión **1.0.0.674**,
sin modificar `app.json` en esta intervención.

Las 59 tablas operativas controladas, las 11.635 cabeceras completas y las cuatro
capturas completas de conceptos, fórmulas, fracciones y restricciones conservaron
sus valores. También quedaron iguales las 62 tablas de la empresa aislada, sin
recibos ni fixtures persistentes. No se ejecutaron recálculos. El nuevo análisis de
marzo debe obtenerse con **Verificar**; las pruebas no constituyen una nueva captura
del informe de marzo. Evidencia privada: `.snapshots/preparacion-aceptacion-20261020/`.

## Preparación: clasificación, omisiones y agrupación (20/10/2026)

`Runner Tests Liq.EjecControlPrevio` pasó **32/32 pruebas** en
`TEST_ORDEN_20261017`, en 4,85 segundos, sobre el paquete
`5d273804-6377-4dc7-88ca-c000ea1d0998`. Se conservó la versión **1.0.0.673**.
Las once regresiones adicionales cubren condiciones positivas con parámetro ausente,
cero y positivo; alternativas explícitas y usos adicionales; auxiliares informativos;
colisiones con productores; agrupación idempotente con suma de repeticiones y alcance
exacto; atributos obligatorios de empleado con clase y atributos opcionales; y
conversión incompatible con un error estructural posterior que debe prevalecer.
Los dos casos léxicos son sólo lectura; las otras treinta pruebas usan `AutoRollback`.

Sólo cambiaron siete objetos AL del informe/control y sus pruebas, más el RDLC.
Los dos campos nuevos pertenecen al buffer `TableType = Temporary`; no agregan
almacenamiento de nómina. Las 370 fuentes instaladas coinciden con el stage probado.
La prueba visual offline usó 24 grupos, 84 ocurrencias y una lista de 150 conceptos,
completa y legible en cinco páginas. Las 62 tablas controladas de la empresa aislada
conservaron conteo y revisión; no quedaron recibos ni fixtures persistentes.

Conceptos, historial de fórmulas, fracciones y restricciones de convenio conservaron
íntegras sus cuatro capturas completas. El control operativo detectó una reapertura
y un recálculo concurrentes de marzo posteriores a la finalización de las pruebas:
11.634 cabeceras quedaron idénticas y una cambió. Por eso no se afirma igualdad global
de recibos. Esta tarea no ejecutó `Liquidar`, `BuildContext`, `Commit` ni una suite en
la empresa operativa; tampoco restauró ni alteró el trabajo concurrente.

Una guarda detuvo la primera publicación al cambiar el paquete instalado. Se capturó
la nueva base y se comparó completa antes de publicar con `Synchronize`, preservándola.
Evidencia privada: `.snapshots/preparacion-clasificacion-20261020/` y
`.snapshots/control-previo-agrupado-20261020/` para la presentación.

## Preparación de liquidaciones: control previo (20/10/2026)

`Runner Tests Liq.EjecControlPrevio` pasó **21/21 pruebas AL** en
`TEST_ORDEN_20261017`, sobre el paquete publicado
`476b8d7f-f8cc-4e84-bccd-885628cf082e` (versión conservada **1.0.0.673**).
El selector exige empresa `TEST_` y exactamente 21 casos de `Test Control Previo Liq.`;
los demás selectores limpian su bandera. Las fixtures persistentes tienen `AutoRollback`.
No se ejecutó `Liquidar`, `BuildContext` ni ninguna suite en la empresa operativa.

Cobertura: cero válido frente a ausencia; fechas explícitas y versiones futuras;
cascada por fecha/especificidad y ejes; vigencia y entidad de atributos; lexer y
clasificación directa/condicional/fallback; IF con TAB/CR/LF; metadatos de fuentes,
filtros legacy ignorados, DateTime y campo de valor no numérico; cotización por fecha
y moneda, fuente sin filtros y tokens todavía indisponibles; selección por fase/tipo/
filtro, alternativa sin fases modeladas, repetición y ausencia de escrituras del control.
Incluye conversión automática de un parámetro FCY aunque ninguna fórmula lo lea y dos
atributos obligatorios administrativos sin nombre de variable, que deben conservar
filas independientes. Los asserts de integridad comparan documentos, usos y configuración.

Compilación completa sin errores. El nuevo resultado usa un buffer `TableType = Temporary`;
no agrega almacenamiento de nómina ni modifica las fórmulas. El RDLC del paquete compilado
se renderizó offline con ReportViewer 15: 24 filas sintéticas en cinco páginas A4
horizontales, encabezados repetidos y textos largos verificados visualmente, sin datos
de empleados. Esta comprobación del diseño no sustituye las pruebas AL del análisis.

Tras publicar y probar se conservaron las 11.635 cabeceras completas y cuatro capturas
completas de configuración. Los conteos y máximos rowversion de las 59 tablas operativas
y las 62 controladas de la empresa aislada quedaron idénticos; no quedaron recibos de
prueba. Las 370 fuentes instaladas coinciden con el stage compilado.

Evidencia privada: `.snapshots/control-previo-20261020/`. Operación y límites:
[[Flujo operativo mensual de liquidación]].

## Validador de órdenes: operadores parentizados (20/10/2026)

`Runner Tests Liq.EjecutarValidadorOrden` ejecutó **18/18 pruebas aprobadas** en
`TEST_ORDEN_20261017`: diez regresiones nuevas de `Test Detalle Calculo` y ocho controles
anteriores de orden puro. El selector exige empresa `TEST_` y un mínimo de 18 casos;
las fixtures persistentes usan `AutoRollback`. No invoca `Liquidar` ni recalcula recibos.
Los demás selectores reinician explícitamente esta selección para evitar arrastrarla.

Los casos verifican `Motor.OrdenEfectivo`, `Control.ResolverOrden` con resultado exacto
y `Control.ObtenerOrdenesPosibles`, incluyendo las **once expresiones de orden exactas**
del plan tangonero/SAC. Cubren `AND`/`OR`/`NOT` ante paréntesis, espacios y saltos de línea,
literales y apóstrofes escapados, contexto por tipo/convenio/categoría/actividad,
prioridad de importes informados y parámetro SAC cero/uno. La falta de contexto conserva
el resultado no resuelto; no cuenta como éxito positivo. `#`/`@`, conceptos,
acumuladores, `FILA_`, cantidades y consultas dinámicas siguen rechazándose, incluso
en ramas no elegidas.

Se corrigieron tres procedimientos de validación en dos codeunits de producción y se
actualizaron dos codeunits de pruebas, sin nuevos objetos, campos, tablas ni cambios a
`Commit`. Compilación sin errores y publicación completa con `Synchronize`, manteniendo
la versión **1.0.0.673**. Las pruebas se ejecutaron sobre el paquete publicado; no son
una reconstrucción offline ni una suite completa. Evidencia privada:
`.snapshots/validador-orden-20261020/`.

`integridad-final.json` acredita igualdad completa de las 11.635 cabeceras y cuatro
configuraciones; conteos y máximo rowversion iguales en las 59 tablas operativas y
las 62 controladas de la empresa aislada. Los 84 esquemas de tablas/extensiones se
conservan y las 364 fuentes instaladas coinciden con el stage probado. No quedaron
fixtures persistentes ni cambios de configuración de esta suite.

## Filtro literal de códigos: resuelto (20/10/2026)

La corrección de `Gestión Francos.FiltrarCodigos` pasó **56/56 pruebas** de
`EjecutarLecturasParciales` en `TEST_ORDEN_20261017`: 21 de correcciones de rendimiento,
25 de caché y 10 autocontenidas de francos. El runner exige esos mínimos por codeunit.
El test `FiltroConApostrofesYOperadores` conserva sus asserts de conjunto exacto y se amplió
con `?`, `@`, comparadores, paréntesis, igual y `%1`, junto con códigos ajenos que no deben entrar.

Tres regresiones nuevas verifican lista vacía incluso con códigos blancos o marcas anteriores;
reutilización entre selección marcada y numérica; duplicados y listas mixtas; y, con filas
persistentes bajo `AutoRollback`, filtros de empleado/fecha/documento/estado en grupos distintos,
lectura parcial de campos, clave, recorrido y suma. Las fixtures persistentes exigen empresa `TEST_`.

No se recalcularon recibos ni se ejecutaron pruebas en la empresa operativa. Se publicó sin
cambiar `app.json`, versión **1.0.0.673**. Las 11.635 cabeceras completas y las cuatro capturas
de configuración permanecieron idénticas; ninguna de las 59 tablas operativas cambió su conteo
o máximo rowversion. Evidencia privada: `.snapshots/filtro-codigos-20261020/`.
Esto cierra el fallo de filtro de las capturas anteriores; no equivale a ejecutar la suite completa.

## Avisos de cálculo y selección por fase (20/10/2026)

La revisión del informe de enero añadió **18 regresiones**, todas aprobadas en
`TEST_ORDEN_20261017`, sin ejecutar pruebas ni recálculos en la empresa operativa:

- Ocho de selección: estado exigido, ventana configurada y fase de alta deben coincidir;
  incluyen reingreso, huecos, límites de día, mes siguiente, exclusiones y alternativa sin fases.
- Cuatro de retiro seguro: PK y revisión explícitas, estado Borrador, ausencia de contenido y
  dependencias, prevalidación de todos los objetivos y limpieza/reversión mediante `Delete(true)`.
  Una fila de novedad totalmente vacía no bloquea; sí bloquean un concepto informado aunque valga
  cero o un valor informado sin concepto. Las novedades vinculadas siempre bloquean.
- Tres de indicadores informativos: sólo se omite el falso aviso de cantidad cuando el catálogo,
  la fuente activa, su lectura real y los tres filtros exactos acreditan ese uso; se conservan
  los avisos de casos pagables, manuales, históricos monetarios o ambiguos.
- Tres de informe: las observaciones de orden continúan visibles, se cuentan aparte y los
  registros históricos se presentan sin cambiar sus datos o severidades guardadas.

En esa revisión, `EjecutarLecturasParciales` seleccionó **53 pruebas**: 18 de correcciones de rendimiento,
25 de caché y 10 autocontenidas de francos. Resultado de esa captura: **52/53 aprobadas**; la única falla
era `FiltroConApostrofesYOperadores`, corregida después según la sección anterior. Su criterio no se relajó.
`EjecutarAvisosYOrden` ejecutó **152/152 aprobadas**: 10 de auditoría, 25 de caché, 12 de control
y 105 de corrección. La comprobación de etapa conserva los asserts de importe y acumulador;
sólo adapta el texto esperado al mensaje que no da por intencional un subtotal.

La auditoría de selección, sólo en lectura sobre la captura de enero, mantuvo elegibles las
316 regulares calculadas y descartó dos borradores vacíos redundantes. Su retiro operativo
se efectuó separadamente mediante AL normal, nunca dentro de una suite. La comparación de
las 11.635 cabeceras restantes confirmó igualdad completa; de las 59 tablas controladas,
sólo cambió el conteo de cabeceras por esos dos retiros. Conceptos, historial de fórmulas,
fracciones y convenios conservaron íntegros sus datos. No se recalcularon recibos.

El RDLC se renderizó además **offline con ReportViewer 15** y las capturas históricas, sin
ejecutar el motor. La revisión de las dos páginas confirmó ambas secciones, encabezados repetidos
y ausencia de superposiciones o recortes. Esa comprobación detectó y corrigió seis celdas físicas
faltantes en la fila combinada de sección, un defecto que la compilación AL no detectaba.
El PDF de comprobación conserva los mensajes históricos; no representa una corrida nueva de nómina.

Evidencia privada: `.snapshots/documento-18-20261020/`. La aprobación de esas 18 regresiones no
cubría el defecto de filtro; su corrección y validación posteriores se documentan arriba.

> [!danger] Ejecutar las pruebas que escriben configuración sólo en una empresa o BD de prueba aislada
> Incidente confirmado el 15/10/2026: una corrida con `AutoRollback` coincidió con recálculos operativos.
> Esos recálculos alcanzaron a leer conceptos sintéticos aún no confirmados y los guardaron en recibos
> reales. Revertir la transacción de la prueba no revierte las escrituras de otra sesión que leyó esos
> datos. Las comprobaciones finales de 661/662 sin concurrencia no cubren ese efecto anterior.
> No usar ArbuTest para estas suites mientras sea la empresa de nómina operativa. Una pausa momentánea
> o una guarda de inactividad previa no reemplaza la empresa/BD de prueba aislada. Revisar configuración,
> cabeceras, líneas, auditoría y consumidores de resultados antes de decidir la reparación de los recibos.

El usuario completó el recálculo de enero el 15/10/2026. La verificación posterior, sólo en lectura
y con captura estable de enero, confirmó los 41 recibos previstos Calculados y los siete afectados
con haberes y netos exactamente iguales a lo esperado al retirar los importes sintéticos; se
conservaron descuentos, contribuciones, Ganancias y bases. Los censos globales inicial y final
no encontraron líneas de prueba ni huérfanas. Enero tiene 570 de 570 cabeceras Calculadas.
Durante esa verificación febrero quedó fuera de la certificación de inalterado: el usuario confirmó
otro trabajo concurrente sobre ese mes. Tras informar que terminó su cálculo, una nueva captura
estable confirmó ausencia global de residuos y conservación de las cabeceras y marcas de enero;
febrero presenta cambios del recálculo y un cierre todavía en Borrador. Ver
[[Control de haberes brutos de febrero 2026]]. No se ejecutaron cálculos, pruebas ni escrituras
en la BD durante estas verificaciones.

## K4/K5 sin mantenimiento SIFT: comprobación previa (19/10/2026)

El cambio de esquema de `Línea Liquidación` compiló con los 364 archivos AL actuales, sin
errores. Se verificó que las únicas diferencias ejecutables son `MaintainSIFTIndex = false`
en K4/K5 y que K2, claves, identidad, campos y triggers se conservan.

La comprobación SQL independiente sobre 293.460 líneas comparó todos los grupos: 19.092 K4,
17.209 K5 y 25.297 K2, sin diferencias exactas de suma/conteo ni grupos faltantes. Planes reales
confirman acceso separado a las vistas y la tabla base; conteo/rowversion estables antes/después.
Evidencia en `artifacts/k4-k5-sift-20261019/` y [[Rendimiento y caché del cálculo]].

**No se ejecutaron suites AL ni recálculos con el esquema nuevo.** BC252 no tiene una instancia
Payroll separada y TEST_ORDEN comparte la aplicación y el esquema con ArbuTest. El resultado
SQL no equivale a validar CalcSums AL, grossing-up o regeneración de trazas después de publicar.
La optimización se publicó con Synchronize el 19/10, Package ID
`4BA4BB2F-883A-4B62-8C02-B9DEE6C09E21`. Se confirmó el retiro de las dos vistas, conservación de
K2/índices ordinarios/campos y conteos/máximos rowversion estables en 22 tablas. No se ejecutaron
tests ni recálculos durante la publicación. No reutilizar aprobaciones históricas de las suites
como si se hubieran ejecutado sobre esta modificación.

## Acumulados históricos y lectura de fracciones (18/10/2026)

`Test Cache Liquidacion` agrega dos pruebas con `AutoRollback`:
`AcumuladosConservanPrimeraFraccionYFiltros` y
`AcumuladosRenovadosIncluyenPropiaSoloEnAnual`. Cubren conceptos repetidos en distintas vigencias
con signos opuestos, conservación de la primera fila por K2, filtros de fecha/período/empleado/estado,
fracciones futuras y conservación de las líneas e importes. También comprueban la instantánea hasta
`InvalidarAcumulados` y que, al renovarla, crezca el anual con las líneas propias mientras el acumulado
del período sigue excluyéndolas.

Se revisaron y **compilaron sin errores con el proyecto 1.0.0.673** tras agregar `SetLoadFields`
de concepto y signo a las dos lecturas de `Fracción Acumulador`. El 19/10 ambas **pasaron en
`TEST_ORDEN_20261017`**, dentro de la selección aislada de 38 pruebas. `AutoRollback` no habilita
su ejecución en ArbuTest operativa. La ejecución valida esos escenarios, no mide el cálculo completo.
Registro: `artifacts/indices-20261018/compile-fraccion.json` y `compile-fraccion.log` de esa carpeta.
Ver [[Rendimiento y caché del cálculo]].

## Lecturas parciales de SUM y francos (19/10/2026)

**Publicadas en 1.0.0.673; resultado aislado: 37 de 38 aprobadas.**
`Runner Tests Liq.EjecutarLecturasParciales` ejecuta una selección de **38 pruebas**:

| Codeunit | Pruebas seleccionadas | Alcance |
|---|---:|---|
| `Test Correcciones Rend. Liq.` (110046) | 6 | Tres anteriores y tres nuevas de SUM: importes, filtros, traza, campos heredados, fechas, FlowField, valor no configurado y conjunto vacío |
| `Test Cache Liquidacion` (110047) | 22 | Las veinte anteriores y dos regresiones de fracciones y renovación de acumulados |
| `Test Cuenta Francos` (110061) | 10 | Siete fixtures autocontenidos, dos pruebas nuevas de `Total` y una de `Matriz`: rol, vigencia, cortes, exclusión, líneas asentadas, reversión, origen y trazabilidad |

El método exige una empresa cuyo nombre empiece por `TEST_`; la empresa aislada conservada para
esta validación es `TEST_ORDEN_20261017`. Antes de reutilizarla se debe comprobar que sigue sin
datos operativos. El prefijo es una guarda de invocación, no prueba por sí solo ese aislamiento.
El runner ejecuta por `OnRun` con `TestIsolation = Function`, aplica la selección también al
contar resultados y exige mínimos de 6, 22 y 10 por codeunit. Los otros selectores restablecen
`SoloLecturasParciales` para evitar arrastrar esta selección si se reutiliza una instancia.

La selección de francos usa una lista explícita y deja fuera cinco pruebas históricas que exigen
ArbuTest y operan sobre su configuración o recibos existentes: `HistoriaEneroRespaldaSusConsumos`,
`Matriz1063ConservaRecibosEnero`, `PrecioRespetaVigenciaSinCambiarDias`,
`RecalculoMensualConservaTopeYTotales` y `AntiguedadUnificadaConservaTotalesYBases`.
No se cambian esas guardas ni se ejecutan esas pruebas en la empresa operativa para esta revisión.

La revisión de las rutas seleccionadas no encontró cambios de empresa, commits ni escrituras
en la tabla global `Config Sinc NAV`. La reapertura sí escribe bitácora y datos por empresa,
dentro de la transacción de la prueba. Después de la ejecución, **69 de 69 tablas** conservaron
sus conteos exactos y máximos rowversion frente al preflight; no se observaron fixtures persistentes.

La compilación completa terminó con código 0 y la publicación con HTTP 200. PackageId:
`98A651B5-9DCE-4D10-868F-05F01C772B9D`; **361/361 fuentes AL desplegadas** coinciden con el stage
final. SHA256 del paquete: `8E0F1B1B73C90C9A3361DAC61D411A844FBCD98A8D52155FD4FB0C9F2F63D8E1`.
Para la ejecución administrativa corresponde codeunit 110070, método `EjecutarLecturasParciales`,
empresa aislada, `MaxRetries=0` y un tiempo máximo acotado. El runner 110062 exige todavía diez
pruebas y no sirve para esta selección.

**Las ocho regresiones nuevas pasan.** La única falla es `FiltroConApostrofesYOperadores`:
el constructor preexistente conserva `*` y `@` como operadores; esperaba seis códigos literales
y seleccionó siete. La función coincide con HEAD y con el paquete instalado antes de estos cambios.
La prueba sigue seleccionada y su criterio no se relajó; la suite completa permanece fallida.
No se identificaron esos disparadores en los 334 códigos actuales de concepto de ArbuTest
(`*`, `?` y `@`: cero), lo que no elimina el defecto ni garantiza futuras altas.

La sonda pública `Test Correcciones Rend. Liq.ValidarLectoresPublicados` **no es un `[Test]`**
y se invoca por ese método, nunca por el runner, en ArbuTest. Valida previamente las tres fuentes
ENF y sólo lee datos persistentes. Terminó sobre seis documentos: 18 pares SUM, 24 pares Total,
36 trazas y doce lecturas de Matriz; ésta sólo materializa un buffer temporal y exige su error
final de saldo insuficiente. Cualquier otro error aborta. La repetición comprueba estabilidad
y trazas añadidas, no equivalencia independiente ni recibos completos.

Evidencia en `artifacts/indices-20261018/lectores/continuacion-20261019/`: `compile-result.json`,
`publication-result.json`, `suite-38-revision2.json`, `fallo-preexistente-filtro-codigos.json`,
`empresa-aislada-preflight.json`, `empresa-aislada-post-tests.json`, `sonda-indice-ampliado.json`
y `metadata-publicada-98a651b5-9dce-4d10-868f-05f01c772b9d/metadata-comparacion.json`.

El **benchmark SQL sí se ejecutó**: 96 consultas con hashes de claves y campos usados idénticos;
lecturas lógicas de 6.144 a 276 en francos y de 9.704 a 388 en el patrón de enfermedad, sumando
doce ejecuciones por variante y familia. Los planes automáticos usan el compacto sin `Key Lookup`.
Este benchmark es independiente de las 38 pruebas AL; no certifica recibos/trazas completos ni
mide la duración del motor. El compacto ampliado para Matriz ocupa 74,60 MiB. El índice ancho
se retiró el 19/10 a las 08:33:41 UTC: las 293.993 filas y el máximo rowversion 17.053.973.210
permanecieron iguales. La sonda AL posterior volvió a pasar en 0,879 s, con los mismos seis
documentos, 18 pares SUM (18 no cero), 24 pares Total, 36 trazas y doce lecturas de Matriz.
Esto no cambia el resultado **37/38** de la suite ni sustituye un recálculo completo de nómina.
Evidencia: `wide-index-removal-result.json` y `sonda-post-retiro.json` dentro de
`artifacts/indices-20261018/lectores/continuacion-20261019/`. Ver [[Rendimiento y caché del cálculo]].

El control SQL posterior al retiro añadió 27 consultas y nueve planes reales: seis comparaciones
con campos, orden y rowversions estables. La paginación parcial usa el compacto sin lookup;
`Inicializar` conserva su lectura completa por K4 y PK con lookup. Sólo se reprodujo su SQL,
sin ejecutar el método AL ni reconstruir movimientos. Siete planes compilados asociados a la sonda
AL posterior también usan exclusivamente el compacto, sin lookup, para SUM, Total y Matriz.
El estado final confirma el ancho ausente, el compacto activo y filas/rowversion sin cambios.
Evidencia: `artifacts/indices-20261018/lectores/post-retirement-reader-summary.json`.

## Avisos, informe y propuestas de orden (1.0.0.660–662)

`Runner Tests Liq.EjecutarAvisosYOrden` selecciona 63 pruebas: 7 de escritura e informe,
20 de caché y recorrido del motor, 12 del diagnóstico estático y 24 de propuestas de orden.
Exige esos mínimos por codeunit y falla si falta una suite. `TestIsolation = Function`
revierte los datos sintéticos de la transacción de cada prueba; no protege de lectores concurrentes
ajenos a esa transacción. Usar exclusivamente una empresa/BD de prueba aislada.

Las pruebas nuevas cubren el resumen completo de una corrida, filtros y documentos distintos,
mensajes extensos, aislamiento de trazas, aportes efectivos, consumidores y lecturas por etapas.
Las propuestas prueban ventanas de dependencias, empates por código, vigencias futuras,
alternativas y ausencia de solución segura. La última regresión comprueba también la asignación
booleana y su envoltura `TryFunction`, como usa la página. Ver [[Avisos y advertencias del cálculo]] y
[[Orden de cálculo y precedencia]]. **63 de 63 aprobadas en BC252/ArbuTest con 1.0.0.662,
el 15/10/2026**. Las diez tablas operativas/financieras controladas y las ocho tablas de
configuración permanecieron iguales entre la referencia previa a esa publicación y el fin
de las pruebas. Esta selección no reemplaza la suite completa de 203 pruebas.

El RDL del informe se renderizó por separado con 570 procesos sintéticos, agrupados en
500/69/1 casos. Se verificaron encabezado global, totales y texto largo completo, sin recortes
ni advertencias del renderizador. No se generaron liquidaciones para esa revisión visual.

### Rendimiento del diagnóstico y del corrector (2026-10-16)

Se agregaron nueve regresiones a `Test Corrección Orden Acum.` (33 en total): equivalencia
entre diagnóstico global y por fila, lectores compartidos, cambio de contexto y descarte
de configuración obsoleta entre operaciones. Compilaron con el proyecto completo, sin
errores. Su ejecución AL queda pendiente en una empresa/BD aislada; no se publicaron
ni se ejecutaron pruebas o cálculos en la empresa operativa durante esta revisión.
La aprobación histórica de 63 pruebas indicada arriba no incluye estas nueve.

La acción **Recalcular órdenes** agrega otras once regresiones (44 pruebas del corrector
en total): varias bases y aportes, repetición sin duplicar vigencias, fecha exacta ocupada,
casos bloqueados junto a corregibles, etapas, contexto insuficiente, conservación de
fórmulas/recibos/fracciones, uso calculado posterior, dependencias liberadas por otro cambio
y varios lectores cuyo primer movimiento no reduce el conteo de aportantes tardíos.
Compilaron con el proyecto completo sin errores; ejecución AL pendiente en empresa/BD
aislada. No se ejecutaron en la empresa operativa ni se publicó esta revisión.

El modo concepto desde la ficha agrega diez regresiones más (54 pruebas del corrector):
alcance de bases relacionadas, lecturas sin fracciones, llamadas indirectas, versiones
históricas, rechazo de rowversion obsoleta en ambas APIs, propuesta fija del lector,
rechazo de base ajena, acumulador sin orden propio, referencias `#` sin bases y fracciones
con vigencias distintas. Compilaron con todo el proyecto sin errores; ejecución AL y
validación de interfaz pendientes en un entorno aislado. No se publicaron ni se
ejecutaron en la empresa operativa.

La versión **1.0.0.663** se publicó el 16/10/2026 y su instalación se confirmó por metadata
del servidor. Las 54 pruebas del corrector compilaron, pero no se ejecutaron durante la
publicación. Ocho tablas operativas y de configuración conservaron cantidades y revisiones
máximas antes/después. Esto verifica la conservación de la publicación, no la aprobación
de las pruebas pendientes.

El modo **Actualizar esta vigencia** agrega diez regresiones (64 pruebas del corrector):
misma PK e intervalo, auditoría, conservación de fórmulas/recibos/fracciones/vigencias
futuras, permiso de corregir una versión usada sin relajar las guardas del modo anterior,
fecha inicial exacta, fronteras anteriores a la referencia y posteriores, ausencia de
cambio global, lote sin duplicados y repetición idempotente, concurrencia, etapas/ciclos
y alcance fijo desde ficha. Compilaron sin errores con el proyecto completo. No se
ejecutaron en BC: sólo existe la empresa operativa ArbuTest, que no se usa para estas suites.

La actualización se publicó como **1.0.0.664** el 16/10/2026. La metadata confirmó su
instalación y las ocho tablas controladas conservaron cantidades y revisiones máximas.
No se ejecutaron correcciones de orden, recálculos ni pruebas AL en la empresa operativa;
la compilación de las 64 pruebas no equivale a una corrida aprobada.

El control de órdenes condicionales agrega diez regresiones (74 pruebas del corrector):
resolución exacta antes de acotar ramas, árboles IF anidados y cadenas escapadas, rechazo de
aritmética en hojas, órdenes inválidos y consultas desde condiciones, conservación de la fórmula
de la referencia, cruce peligroso en una sola rama, fuente condicional sin contexto y fuente
de puesto bloqueadas, desconocidos ajenos, par alternativo sin suponer el convenio y fronteras
futuras. Se ajustó un caso anterior: un aportante de puesto queda intacto mientras su lector
de entidad puede atrasarse si todas las posibilidades lo permiten.

Las 74 pruebas compilaron con el proyecto completo sin errores; permanecen pendientes de
ejecución en empresa/BD aislada. No se usa ArbuTest operativa para ejecutarlas.
La versión **1.0.0.665** quedó instalada el 16/10/2026, con HTTP 200 y las ocho tablas
controladas sin cambios de cantidades ni revisiones máximas. No se ejecutaron correcciones
ni recálculos durante la publicación; esta verificación no sustituye la ejecución de las pruebas.

La ampliación a dependencias entre fórmulas agrega doce grupos de regresiones (86 pruebas
del corrector): referencias `#` sin acumuladores, entradas múltiples y campos auxiliares,
cadenas e idempotencia del lote, expansión anidada de `@`, autorreferencias y ciclos,
referencias inexistentes, órdenes condicionales, fronteras futuras, conservación de etapas
de otros acumuladores, vigencias nuevas con recibos guardados, concurrencia y nombres sin
prefijo. Se actualizó la expectativa anterior de una ficha que sólo lee `#Entrada`: ahora
debe mostrar esa dependencia, además de las filas donde el concepto actúa como productor.
Estas regresiones no se ejecutan en la empresa operativa; requieren un entorno aislado.
Compilación completa de las 86 pruebas sin errores. Publicada e instalada **1.0.0.668**
el 16/10/2026, con HTTP 200 y ocho tablas controladas sin cambios de cantidades ni revisiones
máximas. No se ejecutaron pruebas AL, correcciones ni recálculos operativos; la compilación
y la conservación de la publicación no equivalen a una corrida aprobada de estas regresiones.

La clasificación de valores precargados agrega seis grupos (92 pruebas del corrector):
autorreferencia inicializada y expansión `@`, conservación de fase al mover lector o escritor,
combinación de `#A` y `A`, acumuladores con nombre también inicializado, todas las ramas de
orden y caché, y captura fiscal antes de la transformación del concepto homónimo. Se ajustó
la expectativa del nombre sin prefijo: una lectura inicializada no es una ambigüedad ni un
ciclo calculado; una referencia `#` conserva su dependencia explícita.
Compilación completa sin errores. Publicada e instalada **1.0.0.669** el 16/10/2026, con
HTTP 200 y ocho tablas controladas sin cambios de cantidades ni revisiones máximas.
No se ejecutaron estas pruebas AL ni correcciones o recálculos operativos. La ejecución
de las 92 regresiones sigue pendiente en empresa/BD aislada. Ver [[Orden de cálculo y precedencia]].

La versión **1.0.0.670** agrega únicamente el puente administrativo del corrector, con
compilación completa sin errores y sin ampliar la suite AL. Se comprobó el rechazo de
una petición incompleta, los diagnósticos de lectura y la aplicación normal de cinco
reglas revisadas sobre el orden histórico de un concepto. Estas operaciones autorizadas
no son una ejecución de pruebas sintéticas. Ver [[Revisión de conflictos de orden octubre 2026]].

## Oficiales poteros: orden e historia (2026-10-13)

La versión 1.0.0.654 agrega quince pruebas del orden con contexto estable, restricciones
de dependencias, persistencia del resultado de `ACUM_PARAM_CCT`, tarifas y tipos de
cambio históricos, rechazo de datos faltantes y registro de las vigencias utilizadas.
Las quince finalizaron correctamente con rollback en BC252/ArbuTest.

`Runner Tests Liq.EjecutarOficialesParametricos` ejecuta Detalle, Uso de parámetros,
Evaluador y Formateador; exige que cada codeunit haya ejecutado pruebas. En la corrida
ampliada pasaron 73 de 77: quedaron cuatro fallos en pruebas anteriores (compatibilidad
de trazas sin registro, comparación de atributo, coma decimal y corte del formateador).
No presentar esa corrida como una suite completa aprobada. La instrumentación del primer
fallo quedó en el respaldo privado para su investigación; no se cambió su lógica productiva.

Al invocar por administración, usar `-MaxRetries 0` para pruebas y diagnósticos que deben
devolver el error de AL. Los reintentos automáticos del cliente pueden aparentar una
ejecución larga aunque BC ya haya registrado el fallo. Acotar también `NetworkTimeout`.

Hay suites AL de lógica y de integración con datos sintéticos, además de las pruebas del editor de fórmulas en el navegador. El motor comparte su recorrido de conceptos con las pruebas del diagnóstico de orden.

## 1. Tests AL (`test/Codeunits/`, 205 `[Test]` al 15/10/2026)

Dos regresiones nuevas de saldo de francos a fecha cubren créditos y consumos futuros, exclusión
del documento y contramovimientos, tanto con cuenta activa como en el camino de líneas. Están
compiladas, pendientes de ejecución en un entorno aislado. La comprobación del incidente se hizo
sólo con la captura local; no se ejecutaron estas suites en la empresa operativa. Ver
[[Cuenta corriente y matriz de francos]].

| Codeunit (archivo) | Pruebas | Qué cubre |
|---|---|---|
| `Test Evaluador Fórmula` (`Cod50021`) | 35 | Aritmética, precedencia, `IF`/`CASE` perezosos (evitan división por cero), comparadores, `AND/OR/NOT`, variables, decimal con coma/punto, atributos comparados por código (`AtributoComparaCodigoAunqueNumeroSeRepita`, `AtributoValidaCodigosSinEmpleado`) |
| `Test Formateador Fórmula` (`Cod110034`) | 11 | Normalización de espacios, menos unario, literales de texto, corte de líneas largas |
| `Test Fin Efectivo Liq.` (`Cod110045`) | 10 | Equivalencia entre resolver el fin efectivo recorriendo la lista (definición) y con mapa (rápido): desordenadas, repetidas, historial largo |
| `Test Claves Parámetro Liq.` (`Cod110069`) | 7 | Qué clave de parámetro gana: genérica posterior contra específica anterior, el empate que protege a la específica, empleado, y el caso sin ninguna cargada. Ver [[Parámetros y vigencias]] |
| `Test Detalle Calculo` (`Cod110056`) | 30 | Reconstrucción del detalle, oficiales paramétricos y diagnóstico estático de orden |
| `Test Correcciones Rend. Liq.` (`Cod110046`) | 3 | Tolerancia de un peso y 20 iteraciones del grossing-up, filtro con apóstrofes |
| `Test Cache Liquidacion` (`Cod110047`) | 20 | Incidencias, CCT y avisos dinámicos en el recorrido real de conceptos |
| `Test Escritura Auditoria` (`Cod110048`) | 7 | Truncamiento, texto completo y resumen del informe por selección |
| `Test Cuenta Francos` (`Cod110061`) | 12 | Cuenta corriente, reversión, dependencias y saldo a fecha sin lotes futuros |
| `Test Promedio Enfermedad` (`Cod110072`) | 24 | Historia del vínculo, promedios y fechas de enfermedad |
| `Test Uso Parametros` (`Cod110073`) | 22 | Vigencias, tarifas, trazabilidad y parámetros históricos |
| `Test Corrección Orden Acum.` (`Cod110075`) | 92 | Propuestas seguras, vigencias, bloqueos, cachés, lote, misma vigencia, órdenes condicionales, dependencias y fases de valores precargados |

Características comunes:
- `Subtype = Test; TestPermissions = Disabled;`
- **Sin librerías de test**: cada codeunit define su propio `Assert`/`AssertEq`/`AssertFecha` local. `app.json` **no** declara dependencia con *Test Runner* ni *Library Assert*.
- Los tests usan **tablas temporales** o datos sintéticos revertidos por el aislamiento del runner. Cada uno instancia su propio `Contexto Liquidación` (la caché es por nombre de variable y compartir la instancia contaminaría).
- **Viajan dentro de la misma app**: `alc` compila `test/` junto con `src/` (≈1,4 MB). IDs: `50021` y `110034`–`110056` ([[Rangos de IDs y licencia]]).

### Cómo correrlos — sin cliente, desde el servidor

`Runner Tests Liq.` (`Cod110070`) es un `Subtype = TestRunner` que corre los doce codeunits de test o sus selecciones específicas, así que se puede invocar con `Invoke-NAVCodeunit` y **no hace falta abrir el cliente ni el AL Test Tool**. Publicar la app ([[Publicar en BC (no usar RAD)]]) y después:

```powershell
# El módulo de administración de BC 25.2 es .NET 8: NO carga en Windows PowerShell 5.1, que es lo
# que da una sesión remota por defecto. Hay que pasar por pwsh 7 en el servidor.
$inner = @'
Import-Module "C:\Program Files\Microsoft Dynamics 365 Business Central\252\Service\Admin\Microsoft.Dynamics.Nav.Management.psm1" -DisableNameChecking
try { Invoke-NAVCodeunit -ServerInstance "BC252" -CompanyName "EMPRESA_PRUEBAS_AISLADA" -CodeunitId 110070 -MaxRetries 0 -NetworkTimeout ([timespan]::FromSeconds(180)); "OK: pasaron todas" }
catch { "RESULTADO: " + $_.Exception.Message }
'@
$enc = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($inner))
Invoke-Command -ComputerName 'mimir.arbumasa.net.ar' -ArgumentList $enc -ScriptBlock {
  param($e) & 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -EncodedCommand $e 2>&1 }
```

**Terminar en silencio significa que pasó todo dentro de la suite.** No prueba por sí solo ausencia de efectos en otras sesiones. Un codeunit invocado así no tiene dónde escribir: lo único que vuelve es el error, así que el runner informa el resultado *fallando* con el detalle de qué prueba se rompió y por qué. También falla si no se ejecutó ninguna prueba — sin ese control, un runner que no encuentra nada que correr se ve igual que uno que corrió y pasó.

> [!note] El nombre del servidor para WinRM no es el de `launch.json`
> Ahí dice `mimir.arbumasa.com`, que es un **alias de DNS**: resuelve a la IP correcta pero no tiene SPN, así que Kerberos rechaza la conexión con «No puede encontrarse el equipo». El que funciona es el FQDN del dominio, `mimir.arbumasa.net.ar`. `Publicar.ps1 -Reiniciar` ahora lo deriva solo —resuelve el nombre corto por DNS— y prueba los dos. Ver [[ares-topologia-bc]].

Alternativas manuales: el *AL Test Tool* de BC (agregar los codeunits por ID y ejecutar), o la extensión *AL Test Runner*, cuyo `.altestrunner/config.json` existe pero está **vacío** ([[Setup del entorno de desarrollo]]).

### Primera corrida completa (13/10/2026)

**90 pruebas, 5 fallos.** Es la primera vez que la suite se corre entera; antes sólo la validaba el compilador. Los cinco fallos están en `Test Evaluador Fórmula` (2), `Test Formateador Fórmula`, `Test Correcciones Rend. Liq.` y `Test Cuenta Francos`. Ver [[Hallazgos abiertos]].

Un sexto fallo era de una prueba recién escrita que cargaba una clave de un convenio y resolvía con otro: afirmaba que ganaba una clave que ni siquiera competía. Corregido. **Es el argumento a favor de correrlas**: el compilador la daba por buena.

## 2. Test JS del editor (`test/editorFormula.atributos.test.cjs`)

Prueba las sugerencias de valores de atributo del control add-in `EditorFormula` (`src/ControlAddIns/EditorFormula/editorFormula.js`). No usa framework: `node:assert`, `node:vm`. Carga el JS en un sandbox y le inyecta un detector expuesto sólo para el test (`_valores`), sin alterar la API del add-in.

```bash
node test/editorFormula.atributos.test.cjs
# 14 comprobaciones de sugerencias de atributos correctas.
```

Corrido el 2026-10-04 con Node v24.19.0: pasa. No hay `package.json` ni dependencias.

Verifica: `CONVENIO = ` y `<>` proponen los 3 valores, filtro por código/descripción, inserción con comillas, comillas duplicadas (`D''ANGELO`), ausencia de sugerencia con `>`/`TRAMO('`/otra variable, y que el rango reemplazado reconstruye la fórmula idéntica. Contexto funcional: [[atributo-comparar-por-codigo]].

## Reconciliación de parámetros (13/10/2026)

`Test Uso Parametros` (110073) agrega seis regresiones con datos sintéticos y
`TransactionModel::AutoRollback`: marca huérfana, uso compartido por una liquidación
activa, registro de Borrador, traza histórica sin registro, coincidencia exacta de tokens,
y versión anterior sin uso frente a una nueva consumida, conservando el empleado ajeno.
`Runner Tests Liq.EjecutarUsoParametros` ejecuta solamente esta suite; también está
incluida en la corrida completa. Compilación validada. Su ejecución requiere publicar
la corrección y los tests en BC252; no se ejecutaron contra la app anterior.

### Equivalencia de la reconciliación optimizada (13/10/2026)

Se agregan nueve pruebas a `Test Uso Parametros`, todas con `AutoRollback`; la suite queda
en 22 pruebas. Capturan la respuesta de `TieneUsoActivo` antes de reconciliar y comparan
las marcas resultantes; el oráculo conserva la estructura previa, con la misma corrección
del filtro histórico que el camino optimizado. Cubren:

- Versiones generales, del empleado y ajenas, con consumidores en Calculada, Aprobada,
  Contabilizada, Borrador o sin cabecera.
- Coincidencia exacta de base, clave y vigencia, incluidas claves compartidas entre bases.
- Trazas históricas por nombre actual, código base y `_ESFCY`, sin confundir prefijos.
- Una liquidación con cualquier registro de uso no habilita el respaldo por trazas;
  se conservan tanto la traza como el registro existente.
- La cabecera determina el estado activo del histórico; las líneas huérfanas no bloquean.
- Llamadas sucesivas sobre la misma instancia, pasando de Borrador a Calculada y otra vez
  a Borrador, tanto por registro como por traza histórica, para detectar respuestas
  reutilizadas después de cambiar el estado.
- Varios registros de uso de la misma versión.
- Alias históricos compartidos entre bases y vigencias, conservando la distinción entre
  el alcance general y el del empleado.

Validan la consulta `110000 "Versiones Parámetro En Uso"` y las cachés locales del
respaldo histórico descritas en [[Parámetros y vigencias]]. La consulta une usos y cabecera
activa, filtra por base, clave y vigencia de cada candidata, y usa `TopNumberOfRows = 1`.
Conserva una consulta por versión y evita obtener una cabecera por cada registro de uso;
no agrupa todos los consumidores. Las candidatas siguen siendo las generales y las del
empleado. Las respuestas por alias/empleado y por aptitud de cabecera sólo viven durante
una reconciliación; no se cambia el punto de llamada, las trazas ni los registros, y no
se agrega `Commit`.

**Primera ejecución en BC:** después de compilar y publicar la optimización en BC252,
la suite terminó con 17 de 22 pruebas aprobadas. Los cinco fallos correspondían al
respaldo histórico; uno ya estaba documentado en el oráculo antes de esta optimización.
La investigación encontró que `SetFilter('*%1*', Nombre)` conservaba `%1` literal en el
patrón. Se corrigieron los dos caminos históricos para construirlo primero con
`StrSubstNo`, manteniendo la comparación posterior de tokens exactos.

La corrección protege las marcas `En Uso` sostenidas por trazas antiguas sin registro;
no modifica importes ni reescribe trazas. El oráculo ya no es una copia intacta del código
anterior: conserva su estructura y comparte esa corrección funcional del filtro.

**Validación final:** versión `1.0.0.655` publicada nuevamente en BC252, con respuesta
HTTP 200. `Runner Tests Liq.EjecutarUsoParametros` terminó con **22 de 22 pruebas aprobadas
y rollback** en ArbuTest. La corrección del filtro resolvió los cinco fallos históricos de
la primera corrida. La ejecución fue del 14/10/2026 02:58:43 al 02:58:59 UTC (13/10 por la
noche en Argentina), en 16,30 segundos. Ese tiempo corresponde a las pruebas; sigue
pendiente medir el rendimiento de un cálculo real comparable.

Evidencia: [publicación final](../../artifacts/publicacion-conciliacion-20261013/publicacion-final.json)
y [pruebas de parámetros](../../artifacts/publicacion-conciliacion-20261013/pruebas-parametros-final.json).
Para repetir por administración, mantener `-MaxRetries 0` y un `NetworkTimeout` acotado.

### Precarga positiva por documento (19/10/2026)

`Test Uso Parametros` incorpora cuatro regresiones para el overload
`ReconciliarEnUso(NoEmpleado, NoLiquidacionActual)`: 26 pruebas en total. Comparan las marcas
con el oráculo previo para los tres estados activos, identidad exacta de base/clave/vigencia,
usos repetidos, documentos inválidos o ajenos, cambios de estado y usos entre invocaciones,
respaldo histórico y conservación de trazas/registros de uso. Las pruebas anteriores siguen
ejercitando el overload de un argumento.

`Runner Tests Liq.EjecutarUsoParametros` exige ahora una empresa `TEST_` y un mínimo de 26
pruebas, manteniendo `TestIsolation = Function`. No se debe ejecutar en ArbuTest operativa.
El prefijo no sustituye el control de que la empresa aislada carezca de datos operativos.

El 19/10 se publicó la versión 1.0.0.673 sin modificar `app.json`, con sincronización normal
y HTTP 200. El paquete instalado coincide con la cabecera NAVX del compilado:
`39854D29-6104-444D-9F98-E22790CA039A`, SHA256 de la app
`C8D22643AE4D7957D6010459F2C4F9CE9328ACEE329616E9DE646E8829125979`.
La comparación previa de las 361 fuentes instaladas confirmó que las únicas diferencias
contra el proyecto correspondían a los cuatro objetos de esta entrega; los demás cambios
desplegados desde la publicación anterior estaban preservados.

**26/26 pruebas aprobadas** mediante `EjecutarUsoParametros` en `TEST_ORDEN_20261017`:
la llamada terminó sin error en 3,73 s, el runner exige un mínimo de 26 y la fuente compilada
contiene exactamente esas 26 pruebas. Incluye las cuatro regresiones nuevas. La empresa
aislada mantuvo vacías las tablas de empleados, cabeceras, líneas, usos y parámetros antes
y después. Los nueve controles de cantidad y revisión máxima de ArbuTest no cambiaron;
son controles de conservación, no hashes completos ni una corrida de nómina.

`TEST_ORDEN_20261017` comparte tenant y aplicación con ArbuTest; sólo los datos de prueba
están aislados. No se recalcularon recibos operativos. La compilación completa de `src` y
`test` terminó sin errores. Evidencia de implementación en
`artifacts/conciliacion-positivos-20261019/`; publicación, preflight, suite y postflight en
`artifacts/publicacion-conciliacion-20261019/`.

### Precarga por recibos testigo (19/10/2026, 30/30 aprobadas)

`Test Uso Parametros` suma cuatro regresiones; el runner exige ahora **30 pruebas**, manteniendo
la guarda de empresa `TEST_` y el aislamiento por función. La implementación reutiliza los
usos de cada recibo activo hallado por el TOP1 exacto, en un temporal local de positivos.
Se conservan el TOP1 para ausentes, la precarga propia y el respaldo histórico.

| Prueba nueva | Contrato comprobado por la prueba |
|---|---|
| `TestigosNoMezclanComponentesDeVersiones` | Dos bases comparten un testigo y otra tiene uno distinto; no se mezclan base/clave/fecha ni se aceptan usos de Borrador |
| `TestigosConservanUsoDeOtroEmpleado` | El consumidor exacto puede pertenecer a otro empleado; las candidatas ajenas no se modifican |
| `TestigosSinEmpleadoSoloGenerales` | Empleado vacío, respaldo histórico, marca ya desactivada y conservación de personales |
| `TestigosRenuevanEntreEmpleadosYLlamadas` | Misma instancia con distintos empleados, cambios de estado, usos eliminados/agregados y transición al respaldo histórico |

Las cuatro contrastan contra `TieneUsoActivo` antes de reconciliar y comprueban conservación
de registros y trazas. El oráculo y las 26 pruebas anteriores permanecen sin modificaciones.
La compilación completa terminó con **cero errores**, 27 advertencias AL0432, una AL1029 y
una AL0482 preexistentes. La metadata del paquete instalado
`B3169B4B-9C28-4C44-824B-B3DE5292B4ED` confirmó que ya incluía esta optimización y las 30
pruebas; no fue necesario otro POST. Se ejecutó únicamente `110070.EjecutarUsoParametros` en
`TEST_ORDEN_20261017`: **30/30 aprobadas, 4,08 s**, sin reintentos. Las 65 tablas controladas
conservaron conteos y máximos rowversion (62 vacías y tres configuraciones iniciales).
El Package ID no cambió durante la prueba. No se ejecutaron cálculos operativos en ArbuTest.
Los tests funcionales no certifican concurrencia ni ausencia de interbloqueos.

Evidencia: `artifacts/conciliacion-usos-conjunto-20261019/compile-result.json`, manifiesto de
fuentes, `source-contract-check.json`, copias previas y revisión independiente. Ver
[[Parámetros y vigencias]] para el contrato de bloqueo y [[Rendimiento y caché del cálculo]]
para el contraste SQL de sólo lectura y sus límites. La ejecución y sus controles están en
`artifacts/publicacion-testigos-conciliacion-20261019/test-validation-result.json`, con los
preflight/postflight de aislamiento y la respuesta del runner. Estos controles son indicadores
de conservación, no hashes completos ni una instantánea transaccional.

### Precargas de testigos según pendientes (19/10/2026, 35/35 en empresa aislada)

Se conservan las 30 pruebas anteriores y se agregan cinco regresiones con AutoRollback:

| Prueba nueva | Contrato |
|---|---|
| `PendientesConservanVigenciasYAliasDeMismaBase` | Claves y vigencias distintas dentro de una base; alias duplicados no resuelven versiones ausentes |
| `UltimaPendienteConservaConsumoExacto` | La última candidata conserva TOP1 aunque ya no haya motivo para una precarga adicional |
| `UltimaPendienteConservaAusenciaYHistorico` | Última candidata con Borrador o sólo respaldo histórico; no confundir ausencia de pendientes con existencia |
| `BaseSinAporteSigueConsultandoCadaVersion` | Un testigo sin aporte adicional no suprime las consultas exactas de las versiones posteriores de su base |
| `OtraBaseConservaPendientesDeOtroEmpleado` | Cambio de base, otras vigencias, consumidor de otro empleado y versión fuera del alcance |

Comparan las marcas contra `TieneUsoActivo` antes de reconciliar y verifican registros de uso,
alias, triples y trazas sin cambios. Las transiciones de estado y llamadas sucesivas permanecen
cubiertas por las pruebas anteriores. El runner conserva su guarda `TEST_` y exige mínimo 35.

Compilación completa de **367 fuentes, cero errores**, con las mismas 29 advertencias
preexistentes. Publicado con `Synchronize`, versión **1.0.0.673**, Package ID
`F31EB089-105C-475C-8961-8C45BCC65E7D`. La comparación previa de 364 objetos instalados
encontró sólo los tres cambios esperados: 50019, 110070 y 110073; 361 objetos idénticos.

Se ejecutó una vez `110070.EjecutarUsoParametros` en **TEST_ORDEN_20261017**:
**35/35 pasaron en 4,73 s**. El runner exige mínimo 35, falla ante cualquier error y la
fuente instalada contiene exactamente 35 tests. El paquete coincidió antes y después.
Las **65 tablas** de la empresa aislada conservaron sus controles: 62 vacías y tres
configuraciones semilla sin cambios. No se ejecutaron fixtures en ArbuTest.
Los controles de **22 tablas operativas de ArbuTest** también conservaron conteos y máximo
rowversion. Las columnas e índices de líneas, incluido K2, permanecieron iguales; las vistas
SIFT K4/K5 siguieron ausentes. Estos controles no equivalen a hashes completos de contenido.

La simulación SQL validó la equivalencia del conjunto de positivos exactos sobre datos actuales;
no ejecuta AL ni el respaldo histórico y no prueba que un test funcional haya omitido una
consulta. El ahorro de lecturas se evalúa separadamente. La comparación posterior Session24
frente a Session4(4) y sus límites figuran en [[Rendimiento y caché del cálculo]]; no reemplaza
la validación funcional de resultados. Evidencia de implementación:
`artifacts/conciliacion-testigos-utiles-20261019/`; publicación y ejecución:
`artifacts/publicacion-testigos-utiles-20261019/`, con `publication-result.json`,
`suite-parametros-35.json` y controles de aislamiento previos/posteriores.

## Lo que no está cubierto

- La suite de francos compara recibos completos de enero mediante Motor Liquidación, con rollback.
  Esa cobertura de integración no sustituye la del resto del motor ni otros períodos.
- Sincronización NAV, SIRADIG, informes y otros escenarios de estados.
- La comparación real es **contra Meta4** con consultas y scripts (`scripts/CompararEneroMotor.ps1`, `artifacts/revision-enero-2026-*`), no automatizada.

## Cómo agregar un test

1. Un codeunit `Subtype = Test` en `test/Codeunits/` con ID en 110000+ y nombre `Test <Tema>`.
2. `[Test] procedure` por caso, con `Assert` local; evitar tocar tablas reales (usar `temporary`).
3. Para lógica pura de un codeunit sin estado, hacerla `Access = Public` o exponer un procedimiento `…DeLista` como `FinEfectivoDeLista` ([[Convenciones de código AL del proyecto]]).
4. Compilar ([[Compilar con alc.exe]]) y sumar la fila en esta tabla.
5. Si se agrega JS al add-in, un `.test.cjs` análogo; recordar que publicar cambios del add-in exige subir versión ([[Versionado de app.json]]).

## Cuenta corriente de francos (2026-10-12)

`Test Cuenta Francos` (110061): tres tests con tablas reales y `TransactionModel::AutoRollback`. `Runner Cuenta Francos` (110062) usa `TestIsolation = Function`; ejecutado correctamente en BC252 / ArbuTest con versión 1.0.0.627 mediante herramientas de administración. La descripción anterior de que todos los tests trabajan exclusivamente con temporales ya no aplica a esta suite.

El caso de error esperado usa `asserterror` al final de su prueba aislada: no encerrar un procedimiento que necesita LockTable en TryFunction, ni continuar verificando saldos del mismo ámbito después del rollback provocado por un error intencional.

Además se verificó un recibo real tras inicializar su cuenta, reabrir y recalcular. Se compararon huellas de cantidades, importes, bases y totales: sin cambios. Ver [[Cuenta corriente y matriz de francos]].


## Matriz aplicada (2026-10-12)

La suite `Test Cuenta Francos` ahora tiene seis pruebas, ejecutadas correctamente en 1.0.0.629: consumo compartido/reversión/recálculo, selección parcial, bloqueo de devengo utilizado, eliminación con conservación de movimientos, reconstrucción de cuentas de enero y comparación de recibos de enero (incluidas finales) usando el motor y una nueva vigencia de fórmula por fila. Las pruebas de integración se restringen a ArbuTest y todas usan rollback.

Ejecutor repetible: `scripts/ProbarCuentaFrancos.ps1`. Usa WinRM a `mimir` (nombre corto) y `Invoke-NAVCodeunit` de la instalación 252; no publica servicios web ni necesita el navegador. La prueba de error esperado está separada de los casos que verifican saldos después de escribir.

## Vigencias y recálculo mensual (2026-10-12)

Versión **1.0.0.633**, ocho pruebas ejecutadas y aprobadas en BC252/ArbuTest con rollback.
Se agregaron a las seis anteriores: alternar fechas de configuración del precio en la misma
instancia sin modificar días, y rehacer dos veces un mes con cierre/devengados/regular conservando
el aporte mensual completo hasta el tope y los mismos totales. La comparación de recibos usa
la vigencia efectiva del 1063 a su fecha, sin fijar una versión histórica en el test.

Ver [[conciliacion-enero-vigencias-francos-ganancias]] y [[Recálculo en cadena]].

## Reapertura por dependencias (2026-10-12)

La suite incorpora un noveno caso: origen y consumo del mismo período y fecha, consumidor
externo bloqueado y reapertura repetida sin duplicar contramovimientos. Los fixtures de precio
crean sus propias vigencias con rollback; las fechas productivas de enero pueden consolidarse.
La comparación de recibos se realiza después de rehacer el mes íntegro y se repite por empleado,
para no comparar topes mensuales completos con un recálculo aislado.
Ver [[reapertura-periodo-dependencias-francos]].


Verificación en BC252/ArbuTest: las nueve pruebas pasaron con rollback en la versión 1.0.0.635,
antes de reabrir enero para consolidar la configuración. Para repetir los casos que comparan
recibos calculados, primero debe estar calculado el mes de integración.


## Antigüedad unificada y reapertura desde el árbol

La suite incorpora un décimo caso: conserva los totales mensuales de Alimentación y tripulación
al convertir el 1055 en el 1053, y verifica la distribución por convenio. El noveno caso ahora
llama a Lotes.Reabrir, que es el camino usado por árbol/lista. La suite se ejecuta mediante el OnRun del TestRunner.
El fixture de precio cierra su versión original antes de insertar las versiones de prueba;
así no se superponen con la configuración consolidada del primer día de enero.


Verificación en versión 1.0.0.637: las diez pruebas finalizaron correctamente en BC252/ArbuTest
con rollback. Incluye conservación de bruto, descuentos y neto después de la unificación y
presentación del porcentaje efectivamente aplicado a Alimentación.

## Control de orden por contextos compatibles (16/10/2026)

**1.0.0.673: 117 pruebas aprobadas en 11,15 segundos**, ejecutadas mediante
`Runner Tests Liq.` / `EjecutarCorreccionOrden`: 105 de `Test Corrección Orden Acum.` y
12 `ControlOrden*` de `Test Detalle Calculo`. El runner exige esos mínimos para evitar
un éxito aparente por omisión de pruebas. Incluyen tipos/convenios excluyentes, ramas
IF/CASE/@, categorías y blanco, pares alternativos, condiciones falsas/desconocidas,
necesidad y seguridad, fronteras futuras, repetición, concurrencia, etapas y conservación
de recibos y fórmulas. Son pruebas del control y corrector; no sustituyen el paralelo Meta4.

Se creó para esta revisión la empresa **TEST_ORDEN_20261017**, separada de ArbuTest.
Los fixtures son autocontenidos y usan rollback. Al terminar, 58 tablas de Payroll están
vacías, incluidos conceptos, historial, recibos, empleados, fracciones y restricciones.
Sólo hay 7 tipos, 40 variables de sistema y 2 asociaciones de estados sembrados por los
upgrades existentes, con fecha de alta 17/10/2026 02:23:35 UTC; no son residuos sintéticos.
La empresa se conserva para próximas validaciones aisladas. Antes de reutilizarla,
comprobar que continúa sin datos operativos. Nunca ejecutar esta suite sobre ArbuTest.

Lecciones corregidas en los fixtures: `AssertError` revierte también las altas sintéticas
anteriores; comprobar el error y la atomicidad al final. Usar `TryFunction` sólo para
validaciones sin escrituras ni `LockTable`. Un historial inicial puede existir por
`Insert(true)`: comparar cantidad y PK/rowversion antes/después, y exigir cero auditorías
de orden nuevas. `Activo=false` no retira un concepto: para una frontera futura crear
la fila con su inicio real. La PK de Valor Atributo incluye el Valor Padre vacío.

Ejecutar las invocaciones administrativas de codeunits en secuencia y con PowerShell 7
nativo; el proxy de compatibilidad puede bloquear errores extensos. Un error 500 de esta
validación se localizó en el validador de licencia al abrir empresa, antes de AL; el
reintento secuencial funcionó. Evidencia, paquetes, hashes y registro de integridad en
`.snapshots/orden-contextos-compatibles-20261017/`; las 59 tablas operativas controladas
permanecieron intactas durante la revisión.
