---
tipo: proceso
tags: [motor, orden-calculo, controles, auditoria]
fuente: [src/Codeunits/Cod50014.MotorLiquidacion.al, src/Codeunits/Cod50067.ControlOrdenAcumuladores.al, src/Codeunits/Cod110074.CorreccionOrdenAcum.al, src/Tables/Tab60007.ConceptoLiquidacion.al, src/Codeunits/Cod50070.HistorialFormulasLiq.al]
actualizado: 2026-10-20
---

# Revisión de conflictos de orden octubre 2026

## Validador de órdenes corregido, probado y publicado (20/10/2026)

La corrección posterior, autorizada por el usuario, reconoce exactamente `AND`, `OR` y
`NOT` como operadores aunque el operando empiece por paréntesis. Se corrigieron **tres
recorridos en dos codeunits**: `Motor Liquidación.ValidarDependenciasOrden`, y
`Control Orden Acumuladores.ComprobarFormulaOrdenAdmisible` / `EvaluarExpresionPura`.
La evaluación pura era un tercer rechazo que también impedía resolver un orden positivo
en el control. Las listas de funciones permitidas y las restricciones de contexto
estable se conservan: no se habilitan conceptos, acumuladores ni consultas dinámicas.

Compilación sin errores y publicación completa con `Synchronize`, versión conservada
**1.0.0.673**, paquete `cab92589-991d-47b9-94da-07964ae93a01`. Pasaron **18/18 pruebas AL**
en la empresa aislada `TEST_ORDEN_20261017`, incluidas las once expresiones exactas del
plan, el orden efectivo del motor y resultados positivos exactos del control; los casos
de falta de contexto y las referencias prohibidas siguen rechazándose. No se ejecutó
el cálculo de nómina ni se modificaron fórmulas de importe, órdenes configurados o recibos.
El error de Regular sin días es independiente y no se corrige mediante este cambio.

El control posterior confirma 59/59 tablas operativas con igual conteo y máximo rowversion,
11.635 cabeceras completas y cuatro configuraciones idénticas. Las 62 tablas controladas
de la empresa de prueba conservan sus conteos/revisiones y no tienen recibos. Coinciden
los 84 esquemas de tablas/extensiones y las 364 fuentes instaladas con la compilación;
sólo cambiaron los cuatro codeunits autorizados respecto al paquete anterior.

Evidencia privada: `.snapshots/validador-orden-20261020/`. La revisión siguiente describe
el estado anterior a esta publicación; sus límites sobre resultados económicos siguen vigentes.

## Revisión concreta de febrero/marzo y bloqueo del validador (20/10/2026)

Revisión solicitada expresamente **sin modificar fórmulas ni recalcular recibos**.
Se leyó el informe local `document-19.pdf`, se reconstruyeron lecturas desde líneas y
distribuciones selladas y se compararon los 59 controles de tablas antes/después:
**sin cambios**, mismo paquete instalado y cuatro tablas de configuración completas
idénticas. No se ejecutaron el motor, pruebas AL, publicaciones, eliminaciones ni
reaperturas. Sólo se agregan esta documentación y evidencia privada.

### Bloqueo real de ejecución, no un conflicto monetario de precedencia

El informe tiene **470 errores**, sin avisos de bases/orden de esa corrida: 469 rechazos
del orden de 1534 por consultar la supuesta función AND y un error de cobertura sin días.
El cambio de orden aplicado en la sección siguiente disparó un defecto del validador que
la validación local anterior no cotejó. **No se acreditó su ejecución correcta en BC.**

`Motor Liquidación.ValidarDependenciasOrden` trata cualquier identificador seguido de
paréntesis como función. Así rechaza el operador de `A AND (B OR C)`; ocurre también
con OR/NOT parentizados. El evaluador sí admite esos operadores. El mismo defecto está
duplicado en `Control Orden Acumuladores.ComprobarFormulaOrdenAdmisible` y explica que
el análisis global se propague como Requiere Contexto: no atribuir todos esos avisos
solamente a la falta de incidencias o atributos de una liquidación.

La reproducción local del escáner rechaza **las once versiones** del plan: tres de 1023,
cinco de 1534, dos de 3813 y una de 3814. PrepararConceptosParaCalculo verifica órdenes
antes de filtrar la aplicabilidad por tipo/convenio; el primer rechazo visible es 1534,
incluso para liquidaciones donde no corresponde pagarlo. No son 469 diferencias de haber.

Corrección candidata, **no aplicada en esta revisión**: distinguir exactamente los
operadores AND/OR/NOT en ambos validadores antes de clasificar llamadas a funciones,
manteniendo las listas permitidas y los rechazos de #/@, conceptos/acumuladores y
consultas dinámicas. No ampliar indiscriminadamente a todos los keywords del evaluador,
porque esa lista incluye funciones que no son estables. Antes de publicar se necesitan
regresiones AL del validador real y del control con los once textos; la reproducción
offline de 29 controles léxicos no equivale a una prueba operativa del motor.

### Evidencia económica guardada

Febrero tiene **483 Calculadas y tres Borrador**; marzo tiene **470 Borrador**, con las
líneas y auditorías de su cálculo anterior. La revisión de marzo describe esa historia,
no una liquidación vigente ni el resultado de las órdenes recién configuradas.

| Familia | Resultado observado y clasificación |
|---|---|
| 1023 y BASE_FERIADO | 647 lecturas reconstruidas coinciden con la base completa; no hay aporte posterior efectivo. |
| 1534 potero | Las 24 líneas guardadas leen exactamente el feriado previo: 470 → 471. No hay muestra ejecutada que valide la nueva rama tangonero. |
| 3554 no final / REMUNERATIVO_BRUTO | Etapa sensible: 924 lecturas coinciden con el subtotal en 452. En una Regular de cada mes ese subtotal es distinto de cero y el total posterior queda en cero por 4135 en 620. No atrasar el lector ni su condición hasta la base final. |
| 2703 / BASE_IG4 | 80 lecturas del subtotal previo en 28, reconstruidas sin diferencias. Antigüedad y otros haberes posteriores no convierten por sí mismos esta etapa en un error. |
| 2003, 2013 y 2073 | En los casos concretos se usan componentes explícitos o el complemento de grossing-up; ninguna línea auditada de 2003 lee BASE_IG4 y ninguna de 2013 lee el bruto. La rama teórica no se considera ejecutada. |
| 4905 | Sus 162 lecturas en 681 coinciden con la base completa de la corrida, sin aporte tardío efectivo. |
| 3573 | Las dos líneas son REGULAR y usan 3553; el nombre 3973 corresponde a la condición de otra rama, LIQ_FINAL. No hay precedencia monetaria demostrada. |
| 3813, BASE_PROMEDIO y BASE_SAC | Los 26 SAC conservan orden 470, con ajustes posteriores en cero. No hubo ejecución de 686/687. La ausencia de aporte efectivo no elimina el riesgo estructural ante futuras novedades. |
| 3973 | 23 promedios históricos sin mes actual y tres ramas de componentes. Ninguna muestra usa la lectura del BASE_PROMEDIO corriente que podría cerrar el ciclo con 3573. |
| 3814 | Sin líneas ni auditoría operativa en ambos meses; sin validación de 687. |
| 3610 y descuentos 6000/6002/6010/6012/6030/6034/8522/8523 | Sus entradas están disponibles antes de la lectura. En los ocho descuentos, 6.054 lecturas de bases coinciden con subtotal y total completo, sin aporte posterior no nulo. No extender esta afirmación a conceptos patronales no incluidos. |

Además se cotejaron 8.263 referencias calculadas de 1023/1534/2003/2013/2073/3554/3610
con los resultados previos guardados: sin discrepancias ni productor posterior efectivo.
Estas comprobaciones no certifican composición contra Meta4 ni importes futuros después
de corregir el validador. Los identificadores de casos y valores auditados permanecen
en la evidencia privada, no en el vault.

### Cobertura: cuatro REGULAR vacías

El censo de 956 cabeceras identifica cuatro Regular sin días propios: tres de febrero
y una de marzo, todas Borrador, sin líneas, incidencias, novedades vinculadas ni
referencias como origen. Sus días activos corresponden a proyectos productivos y a
Devengados. En marzo la fase activa sólo abarca el 22–31/3 (PS y NV); no hay días elegibles
para Regular, incluso antes de restar cobertura ajena. El Devengado también está Borrador
tras su reapertura: el texto del error «ya pagó» no describe su estado actual.

Son candidatas a omitirse o retirarse por la acción normal de BC en un paso posterior,
revalidando su vacío y dependencias. No se eliminó ninguna ni se deben alterar estados,
proyectos o exclusiones BAJ para forzar días. El código local de creación ya incluye
la guarda de estado justificante dentro de fase activa; no se comprobó aquí su publicación.

Evidencia privada: `.snapshots/avisos-contexto-febmar-20261020/`, incluyendo
`integridad-lectura.json`, `etapas-reconstruidas.json`, `referencias-reconstruidas.json`,
`analisis-sac-descuentos.json`, `agente-tierra/` y `caso-sin-dias-59432/`.

## Corrección coordinada de tangonero y SAC (20/10/2026)

Aplicada en ArbuTest a pedido del usuario, conservando fórmulas de importe, condiciones,
fechas, fracciones y restricciones por convenio. No se agregaron campos ni tablas, no se
publicó otra extensión y este proceso no ejecutó cálculos ni reaperturas. Se editaron
**11 fórmulas de orden** y se agregaron once entradas de historial de tipo **Orden**.
El orden numérico base de cada versión se conserva; la expresión decide la excepción.

**Tangonero:** en CIERRE_MAREA/DEVENGADOS, con actividad distinta de potero y convenio
768/19 o ESP categorías FE01/FE03, se recupera la secuencia
`1023(450) → 1534(451) → 3554(452)`. Se envolvieron las cinco versiones de 1534 desde
el 1/2, y las tres de 1023 desde el 2/2. Enero ya tenía 450/451 y no se editó. Las ramas
potero y los ámbitos ajenos conservan literalmente su expresión anterior.

No basta con atrasar 1534 a 471: cruza el subtotal sindical. Desde el 2/2 el traslado
coordinado conserva ese subtotal porque el feriado y el premio aportan con el mismo
porcentaje/signo, y el premio resta el feriado: `F + (B − F) = B`. El 1/2 el feriado ya
estaba en 450; corregir el premio evita leerlo antes de que se calcule, pero no se debe
afirmar que conserva el subtotal defectuoso anterior de ese día.

La identidad exige que se ejecute la fórmula del premio. Para un importe informado o
un cero explícito se conserva el orden previo de **ambos** conceptos. Dos fuentes COUNT
decimales activas sobre Incidencia Liquidación reproducen exactamente la regla del motor:

- `INC_1534_CANT_CERO`: `{LIQ_NO}`, concepto 1534 y Cantidad = 0.
- `INC_1534_IMP_NO_CERO`: `{LIQ_NO}`, concepto 1534 e Importe <> 0.

Ambos conteos deben ser cero para aplicar 450/451. Una incidencia con sólo cantidad y
sin importe sigue valorizándose por fórmula. Son seis filtros de la tabla auxiliar;
COUNT no requiere campo de valor. El token de liquidación vacío devuelve cero sin
consultar otras liquidaciones. La categoría es el atributo existente `CATEGORIA`,
con sus códigos originales FE01/FE03, no su proyección numérica.

**SAC:** 3813 queda en **686** para LIQ_FINAL/RELIQUIDACION y 3814 en **687** para
LIQ_FINAL. Ambos quedan después del último ajuste de orden 685 y antes del siguiente
consumidor compatible, 8522 en 700. Se conservan 3973/3573 y el corte de vacaciones;
3813/3814 no aportan a BASE_PROMEDIO ni BASE_SAC. SALDO_INICIAL mantiene 3813 en 470.
El cambio incorpora cualquier aporte tardío compatible ya distribuido a esas bases,
incluidos descuentos de enfermedad/maternidad, no solamente los ajustes manuales.

Se conserva una excepción hasta el **01/02/2026 inclusive** en 175/75, 768/19 y ESP:
3813 sigue en 470 y 3814 final en 669. Allí 2013 aún lee el bruto en 551 y SAC aporta a
ese bruto. Completar la base del SAC y conservar simultáneamente esa etapa produce una
dependencia circular; no se disimula moviendo un ajuste. Desde el 2/2, 2013 usa componentes
explícitos y permite 686/687. Las restricciones históricas genéricas de 2013 siguen siendo
alcanzables por el retroceso del motor por convenio/categoría: no limitar la excepción a
OF01/OF02 sólo por ver las filas más nuevas de 175/75.

El parámetro global **ORDEN_SAC_TARDIO**, sin moneda ni sufijos, vale 0 desde el 1/1 y
1 desde el 2/2. Sólo decide esa excepción de orden; 0 no desactiva el orden tardío en
los demás convenios. Evita cambiar las fechas de versiones usadas por recibos existentes.

Se validaron localmente todas las expresiones y fronteras, más de un millón de
combinaciones de ramas y las identidades decimales/overrides. No se ejecutó un runner
ni el motor contra datos operativos. La escritura fue atómica, con control de revisión
y guardas previas sobre 59 tablas. Hubo un intento previo cancelado sin escrituras por
una edición concurrente de novedades. Tras renovar el respaldo se aplicó el plan a las
13:21:29 UTC y se reinició BC252; quedó Running a las 13:22:04 UTC para renovar la caché.

La comparación posterior confirma exactamente los once cambios de orden, las dos fuentes,
seis filtros, un parámetro y dos valores de vigencia previstos. Las fórmulas de importe,
condiciones, fechas, fracciones y restricciones permanecen idénticas. **No certifica que
todos los recibos se conservaron:** durante el control, 468 cabeceras de marzo pasaron de
Calculada a Borrador entre 13:22:18 y 13:22:47 UTC, con cambios concomitantes en líneas,
incidencias, movimientos y usos. El aplicador de esta tarea no llama ninguna reapertura.
El usuario confirmó que esa reapertura era intencional; no se revierte. Las demás
cabeceras se conservaron. Los 91 cambios adicionales de Parámetro Vigente se limitan al
indicador derivado En Uso y sus metadatos; sus importes y alcances permanecen iguales.
La nueva coincidencia de importes con Meta4 requiere el recálculo posterior del usuario.
Evidencia privada: `.snapshots/corregir-riesgos-orden-20261020/`.

El diagnóstico global posterior devuelve 28 filas pendientes al 28/2 y 21 al 31/1,
marcadas Requiere Contexto. La revisión operativa posterior encontró además el rechazo
incorrecto de AND/OR/NOT en el validador: ver la sección superior. Por ello aquella
clasificación inicial no acredita que sólo faltaran atributos/incidencias. No convertir
esos avisos en cambios automáticos de orden ni afirmar que el plan quedó validado en BC.

## Clasificación actual, sólo lectura (20/10/2026)

La solicitud de esta revisión autoriza diagnosticar, sin aplicar cambios de orden ni condición,
modificar fórmulas o recalcular recibos. El diagnóstico instalado devuelve **7 pendientes** a
28/02 y 20/10/2026; al 31/01 devuelve seis, sin la fila 1534. No son siete errores de importe.
Se contrastaron configuración vigente, 483 liquidaciones Calculadas de febrero y 468 de marzo.
Los tres Borrador de febrero y dos de marzo se excluyeron de las conclusiones económicas.

| Pendiente | Clasificación | Evidencia y criterio |
|---|---|---|
| 1534 | Riesgo real de precedencia, condicionado a la rama | Tangonero conserva 159 y puede leer `#1023` en 470. En las 24 líneas Calculadas de febrero/marzo se ejecuta potero fijo en 471 y el feriado auditado coincide con la línea 470. No hay error observado en esas líneas. Enero usa 451 después de 450. Las versiones del 1–3/2 requieren su propio contexto. |
| 3573 | Aviso conservador de una condición en otra rama | Fuera de LIQ_FINAL, el término de condición que nombra `#3973` está bajo la conjunción de LIQ_FINAL y su fórmula de importe usa `#3553`. En final de Alimentación ya corre en 667, después de 3973 en 665. No atrasarlo globalmente. |
| 3813, referencias directas | Aviso conservador de convenio/rama | En final de Alimentación la cadena es `3973(665) → 3573(667) → 3813(668) → 3814(669)`; FA usa la rama BASE_SAC. El contexto residual con convenio vacío no demuestra una precedencia monetaria en la selección normal. Las bases se revisan por separado y una incidencia fuera de alcance requiere su caso concreto. |
| BASE_IG4 | Mezcla de etapas deliberadas y riesgo condicionado | Zona 2703 lee el subtotal original de Meta4 y 2003 necesita la base previa a su propio aporte. Eso no demuestra que cualquier ajuste posterior sea ajeno: 4111/4833 siguen siendo entradas posibles posteriores a 2003. Ninguna de las 24 líneas de 2003 de cada mes ejecutó la rama tangonero que lee BASE_IG4; los dos ajustes están en cero. No hay defecto económico probado ni justificación para completar globalmente la base. |
| BASE_PROMEDIO | Riesgo estructural ante aportes tardíos | El diagnóstico conserva 4111, 4124, 4243, 4140 y 4723 en ámbitos potenciales; enero añade 4135. En los SAC revisados no hubo aporte posterior no nulo. No declarar la base una etapa correcta por defecto ni adelantar todos sus aportes. |
| BASE_SAC | Riesgo estructural ante aportes tardíos | Conserva el riesgo de 4111, 4140, 4243 y 4723, y de 4135 en enero. La rama final FA requiere revisar esos aportes concretos; los otros lectores posteriores no justifican retrasar todo el SAC. No hubo aporte posterior efectivo en la muestra. |
| REMUNERATIVO_BRUTO | Etapa con condición sensible | El 3554 no final usa el subtotal y su condición en 452. Se comprobó en una corrida de cada mes que ese subtotal era distinto de cero y el total posterior quedó en cero por 4135. Por tanto, mover el lector puede cambiar su activación aunque hoy su importe sea cero. No moverlo detrás de todos los aportes ni adelantar redondeo para quitar el aviso. El 3554 final ya está corregido en 470 y no usa esa condición del bruto. |

Las **26 líneas de SAC** revisadas (10 de febrero y 16 de marzo) tienen auditoría de su base
y ninguna recibe después un aporte no nulo. Los cinco ajustes del diagnóstico valen cero en
esas corridas. En vacaciones no se activó la lectura del mes actual: 23 casos tienen
`VAC_PROMEDIO = 1` y `VENT_PROM_ES_MES_ACTUAL = 0`; tres tienen `VAC_PROMEDIO = 0`.
Esto no valida qué ocurriría con futuras novedades ni sustituye una conciliación con Meta4.

Completar indiscriminadamente BASE_PROMEDIO antes de vacaciones puede crear el ciclo
`3973 → 3573 → BASE_PROMEDIO → 3973` cuando se activa esa rama. Atrasar el SAC después de
todos los ajustes también puede dejarlo detrás de 3814, que depende de él. Las cadenas se
deben tratar conjuntamente y por ámbito, no moviendo cada fila hasta que desaparezca el aviso.

**Ya resueltos por orden:** 3554 final, 4905, 1603, 2103, BASE_FERIADO, BASE_ZONA y
CURR_DED_ESP_SAC. Las 162 lecturas guardadas del 4905 de febrero/marzo usan 681 y coinciden
con la base final de su corrida. Desde febrero 2013 usa componentes explícitos, no el bruto.
Que feriado/zona ya estén ordenados no certifica su composición: permanecen fracciones
cuestionadas por el contraste anterior con Meta4, sin aportes efectivos observados en estos
casos; ese asunto es distinto de los pendientes de orden.

La captura anterior/posterior confirmó **59 tablas sin cambios**, configuración completa y
las 11.635 cabeceras idénticas. No hubo publicación, modificación de órdenes/fórmulas,
pruebas ni recálculos. Evidencia privada: `.snapshots/revision-orden-20261020/`.

## Alcance autorizado

Revisar los pendientes y aplicar sólo órdenes seguros, conservando fórmulas de importe y
recibos guardados. No ejecutar recálculos ni runners de pruebas. Ver
[[Orden de cálculo y precedencia]] y [[Tests automatizados]].

El diagnóstico operativo se contrastó al 01/01, 31/01, 28/02, 31/03 y 16/10/2026.
Antes de aplicar había respectivamente 8, 9, 11, 11 y 11 filas globales pendientes.
Una fila global compara extremos de ramas posibles: no demuestra por sí sola una
diferencia de importe en un recibo. Se pidieron también propuestas por tipo y convenio.

## Corrección aplicada

Se actualizó exclusivamente el orden del **4124 — Ajuste prestación ILT**, PK iniciada
el **01/01/2026**, cuyo fin existente es **15/10/2026**. El orden anterior era 685.
Su fórmula de importe está vacía: recibe importes informados. Aporta a `BASE_PROMEDIO`,
pero no a `BASE_SAC` ni a `BASE_IG4` en la distribución leída.

| Tipo | Convenio | Orden nuevo |
|---|---|---:|
| LIQ_FINAL | 130/75 | 469 |
| LIQ_FINAL | 372/04 | 664 |
| LIQ_FINAL | 729/15 | 469 |
| LIQ_FINAL | FA | 469 |
| LIQ_FINAL | JO | 469 |
| Otros ámbitos | Todos | 685, conservado |

Son cinco reglas de una misma vigencia, no cinco conceptos nuevos. Los órdenes quedan
después del subtotal de `3554` y antes de las lecturas pertinentes de `BASE_PROMEDIO`:
470 en el caso general, y vacaciones 665/SAC 668 en final de Alimentación. El corrector
comprobó las doce fronteras de configuración del intervalo, las otras entradas,
consumidores y etapas. La propuesta general estaba bloqueada por el complemento de
puerto; por eso no se adelantó el concepto en todos los ámbitos.

La aplicación se hizo con `AplicarOrdenSeguroJson`, renovando la propuesta y su
`rowversion` después de cada escritura. Cada cambio conserva las reglas previas.
La vigencia del 16/10/2026, que ya tenía orden 469, no se modificó. No se cambiaron
fechas, fracciones, restricciones ni fórmulas de importe.

## Pendientes que no se deben resolver con un movimiento global

| Fila | Evaluación |
|---|---|
| 1603 | `#2803` sólo se usa en final; en esa rama 401 sigue a 400. El extremo 170 corresponde a otra rama. |
| 2103 | Presentismo sólo aplica a Comercio; allí 1053 corre en 50 y el lector en 55. No corresponde llevarlo a 101 por el orden de antigüedad de otro convenio. |
| 3573 | Sólo Alimentación; en final usa 667 después de 3973 en 665. El orden 455 corresponde al resto de tipos. |
| 3813 / 3814 | Las referencias a vacaciones y sus complementos requieren interpretar las ramas. En final de Alimentación la secuencia es 665, 667, 668, 669. Esto no valida los demás aportes tardíos a las bases. |
| 1534 | La rama tangonero conserva una referencia potencialmente tardía a 1023. La rama potero fijo actual ya va en 471. No se generalizó un cambio de enero: el contraste agregado con Meta4 no confirmó una corrección uniforme por el feriado. |
| 3554 | La referencia explícita a 1023 puede llegar tarde. Adelantar el feriado o atrasar el complemento cruza otras lecturas/subtotales; no hay un movimiento individual general aprobado. |
| BASE_IG4 | Zona y complementos leen subtotales y vuelven a aportar. No equivale a pedir la base completa antes de la primera lectura. |
| REMUNERATIVO_BRUTO | El 3554 toma un tramo previo; SAC y redondeo se incorporan después. No adelantar redondeo para que desaparezca el aviso. |
| BASE_PROMEDIO / BASE_SAC | Persisten aportes tardíos potenciales para SAC y vacaciones. Las incompatibilidades de tipos descartan parte del cruce global; otros descuentos y ajustes necesitan revisión conjunta. La corrección de 4124 no resuelve toda la fila. |

No se aplicaron propuestas sólo para reducir el contador: por ejemplo, adelantar producción
calamar a la zona de un convenio incompatible o mover redondeo a una etapa anterior.

## Operación y evidencia

La versión **1.0.0.670** agrega el puente administrativo en la codeunit existente, sin
objetos, campos ni tablas nuevos, y sin agregar `Commit`. Publicación `Synchronize`,
HTTP 200, con las ocho tablas de control intactas antes de aplicar los órdenes.
Compilación completa sin errores; las 92 pruebas del corrector no se ejecutaron en
la empresa operativa. Evidencia privada: `.snapshots/corregir-ordenes-seguros-20261016/`.

> [!tip] Invocación administrativa desde PowerShell
> Cargar el módulo de BC nativamente dentro de PowerShell 7. El proxy de compatibilidad
> de Windows PowerShell 5 quedó esperando al transmitir errores extensos, aunque BC ya
> había terminado el diagnóstico. La salida identificada se pudo recuperar del registro
> de aplicación; no fue necesario reiniciar BC ni modificar la lógica del control.

La verificación final de datos y el diagnóstico posterior se conservan junto a las
peticiones originales y sus cinco entradas de auditoría. Los próximos recálculos de
los ámbitos indicados usarán el orden corregido; esta operación no los ejecuta.

**Verificación final confirmada:** 61 tablas controladas; 59 sin cambios de cantidad ni
revisión máxima. Sólo cambiaron la PK indicada de `Concepto Liquidación` y cinco nuevas
entradas de historial de tipo Orden. Las 700 vigencias conservaron sus claves y todos
sus demás campos; las historias anteriores quedaron idénticas. Fórmulas de importe,
condiciones, fracciones, restricciones y recibos intactos. El diagnóstico individual
confirmó el orden correcto del 4124 en los cinco ámbitos. No aparecieron conflictos
globales nuevos: el contador sigue en 11 a febrero, marzo y octubre porque conserva
las otras lecturas, etapas y comparaciones entre ramas pendientes de interpretar.

## Lote ejecutado después por el usuario

El usuario ejecutó **Recalcular órdenes** al 01/01/2026 y comunicó dos actualizaciones
y seis pendientes. La captura posterior confirmó exclusivamente estos cambios:

| Concepto y vigencia | Orden anterior | Orden nuevo | Evaluación |
|---|---:|---:|---|
| 1534, 01/01–31/01/2026 | 159 | 451 | Queda después del feriado de enero en 450. La corrección de orden estructural no demuestra por sí sola coincidencia del importe con Meta4 en la rama tangonero. |
| 2103, sólo 01/01/2026 | 55 | 101 | Movimiento innecesario por combinar convenios en el diagnóstico general. Desde el 02/01 conserva 55. |

En Comercio, el 01/01 el 1053 todavía no está incluido; el 1054 ya corre en 27. Desde
el 02/01 la antigüedad unificada usa orden 50 en ese convenio. El control general tomó
el extremo 100 de otros convenios y lo comparó con Presentismo en 55. No se encontraron
lectores compatibles atravesados entre 55 y 101, ni recibos de Comercio con fecha de
liquidación 01/01/2026. No se revirtió la decisión del usuario ni se ejecutaron cálculos.

La comparación con la captura final anterior confirmó cabeceras, líneas, fracciones,
restricciones, tipos y variables sin cambios. Las fórmulas de importe y condiciones
también siguieron idénticas; sólo cambiaron los dos órdenes y sus dos auditorías.
Evidencia privada adicional: `.snapshots/revision-lote-enero-20261016/`.

> [!warning] Límite observado antes de 1.0.0.673
> Una ventana estructural segura no prueba que el conflicto corresponda a un ámbito
> ejecutable. El lote podía proponer movimientos innecesarios al combinar la
> aplicabilidad por convenio con extremos de ramas de otro contexto. No interpretar
> el contador de órdenes actualizadas como cantidad de errores de importe resueltos.
> Los seis pendientes del resumen tampoco autorizan a completar todos los subtotales:
> las referencias de vacaciones/SAC necesitan su rama, y las bases de Ganancias y bruto
> tienen etapas deliberadas. `BASE_PROMEDIO` conserva revisiones específicas pendientes.

## Control compatible publicado en 1.0.0.673

Se corrigieron el diagnóstico y el corrector: orden, dependencias y aplicabilidad se
comparan dentro del mismo tipo, convenio, categoría y rama. La observación identifica
el ámbito testigo de ambos órdenes. El cambio debe ser necesario en un ámbito demostrado
y seguro en todos los ámbitos y fechas que afecta. Los datos desconocidos del empleado
y pares alternativos conservan relaciones potenciales como guardas; no justifican solos
una escritura. Tampoco un lector con condición falsa u opaca demuestra necesidad.
Las lecturas por etapas y las variables sembradas conservan sus restricciones.

Al 28/02/2026, los avisos falsos de **1603, 2103 y 3814** desaparecen. Quedan ocho filas:
1534, 3554, 3573, 3813, BASE_IG4, BASE_PROMEDIO, BASE_SAC y REMUNERATIVO_BRUTO. La presencia
en esa lista no demuestra un error de importe: incluye condiciones pendientes y subtotales
por etapas. No se deshizo el 2103 de enero cambiado por el usuario ni se aplicó otro orden.

Validación: 117/117 pruebas en empresa aislada, compilación sin errores, publicación
HTTP 200 e instalación confirmada. Las 59 tablas controladas de la empresa operativa
conservaron cantidades y revisiones; conceptos, historial, fracciones y restricciones
también conservaron idénticos sus volcados completos. Fórmulas de importe y recibos
intactos, sin recálculos. Se agruparon categorías equivalentes e indexaron fracciones y
extracciones durante la operación; el diagnóstico global completo de febrero mide unos
20 segundos. Evidencia privada: `.snapshots/orden-contextos-compatibles-20261017/`.

## Revisión de los ocho pendientes con recibos guardados (17/10/2026)

Revisión exclusivamente en lectura, con configuración vigente 1.0.0.673, 486 cabeceras
calculadas de febrero, 82.515 líneas y 6.017 variables auditadas de los lectores relevantes.
No es una conciliación nueva de todos los importes contra Meta4 ni un recálculo del motor.
No se encontró impacto económico demostrado de estos ocho avisos en esos recibos.

| Pendiente | Clasificación y evidencia de febrero | Criterio de resolución |
|---|---|---|
| 1534 | Riesgo estructural en las versiones del 1–3/2 y la rama tangonero en 159. Las 12 líneas existentes usan la versión 4/2, orden 471, y leen el feriado correcto. | Conservar febrero. La rama tangonero exige revisar conjuntamente feriado, premio y reparto 3554; adelantar o atrasar sólo un concepto cruza subtotales. |
| 3554 | Dependencia temprana real en LIQ_FINAL: 452 antes de 1023 en 470. Las 483 líneas de febrero tienen coeficiente 1 y resultado cero; no causa diferencia monetaria actual. | Candidato preventivo: 470 sólo en final, por desempate 1023 < 3554 < 3813. Conservar 452 en otros tipos y revisar la activación por REMUNERATIVO_BRUTO. No se considera aplicado ni validado en todo el intervalo. |
| 3573 | La final de Alimentación ya está en 667, después de vacaciones 665. El aviso restante conserva #3973 dentro de la condición de otra rama sin efecto en su resultado. | Conservar los órdenes; no usar ese aviso para mover vacaciones o el adicional. |
| 3813 | Final de Alimentación usa 668; FA usa su rama BASE_SAC; otros convenios no generan 3573 en selección normal. Sus referencias potenciales a #3973 no demuestran una precedencia económica incorrecta en febrero. | Conservar 470/668. Las bases tardías se revisan por separado. |
| BASE_IG4 | Zona y complemento leen subtotales deliberados. Las 40 bases actuales de zona reproducen la composición original del total09 de Meta4; las 82 lecturas del 4905 coinciden con el total final de su corrida. 4111 y 4833 no tienen importes no nulos. | No completar la base antes de zona/complemento. Si futuras novedades afectaran al 4905, estudiar atrasar sólo ese lector después de 680, sin alterar las etapas anteriores. |
| BASE_PROMEDIO | Nueve SAC finales la leen sin aportes posteriores no nulos; las vacaciones no activan la rama que incorpora el mes actual. Persisten riesgos potenciales de ajustes y otros haberes posteriores a 470. | Corregir aportantes concretos sólo si existe la necesidad y el alcance es seguro. Conservar la cadena 3973 → 3573 → 3813 de Alimentación: completar el promedio antes de vacaciones generaría una dependencia circular. |
| BASE_SAC | La única final FA que usa esta base no tiene aportes posteriores no nulos; sus otros lectores son posteriores a los ajustes. | Misma revisión contextual de aportantes; no atrasar todo el SAC ni adelantar ajustes a todos los convenios. |
| REMUNERATIVO_BRUTO | La lectura del 3554 es por etapas; otros usos son condiciones o una base de presentación. Las 486 líneas de redondeo 5498 tienen importe cero. | Conservar las etapas y el redondeo final; no adelantarlo para eliminar el aviso. |

La composición original del total09 usada para comprobar zona proviene de las consultas
Oracle ya archivadas el 15/10: excluye antigüedad, frío, asistencia, incremento no remunerativo,
SAC y descuentos de enfermedad. La reconstrucción usa valores BC guardados; no afirma
una nueva comparación individual con recibos Meta4. Tampoco se supuso que 2013 siga
leyendo el bruto: actualmente usa componentes explícitos.

Recomendación: conservar las liquidaciones y los órdenes actuales de febrero. Las mejoras
preventivas de orden se deben validar y fechar por separado, con fórmulas de importe
intactas; ninguna se aplicó en esta revisión. Evidencia privada, trazas y scripts de lectura:
`.snapshots/revision-ocho-febrero-20261017/`.

**Control final completado el 18/10/2026:** volvió la conexión y se comparó la captura
del 17/10 con la base actual. Los volcados completos de conceptos, historial de fórmulas,
fracciones y restricciones son idénticos; continúa instalada la versión 1.0.0.673.
Hubo actividad posterior en nueve tablas operativas/de registros, correspondiente a una
liquidación del período 202603. Febrero conserva 486 cabeceras, 82.515 líneas y las
6.017 variables auditadas revisadas, sin líneas ni detalles con revisión posterior a
la captura. Las conclusiones sobre los ocho pendientes siguen vigentes. El reintento
fue sólo de lectura, sin aplicar órdenes, fórmulas ni recálculos.

## Aplicación individual autorizada (18/10/2026)

El usuario autorizó validar y aplicar únicamente dos candidatos seguros: `3554` en
470 sólo para `LIQ_FINAL`, y `4905` después de 680. Se aplicó únicamente **4905**,
mediante el corrector instalado, con revalidación bajo sus bloqueos y control de
revisión de origen. Su versión abierta desde el 01/01/2026 conserva fechas y usa
`IF(TIPO_LIQ = 'CIERRE_MAREA', 681, 670)` como fórmula de orden. Sólo está habilitado
para `CIERRE_MAREA`; sus próximos recálculos, incluidos los de enero, usarán 681.

La ventana comprobada fue 680–938, con propuesta 681, para los ámbitos compatibles
y las once fechas de configuración programadas del intervalo. Así incluye los
aportes a `BASE_IG4` de 4833 (675) y 4111 (680), y permanece antes de sus consumidores
de `NO_REMUNERATIVO`. No se cambiaron las etapas de zona y producción. Es una
corrección preventiva; no se atribuye a ella una diferencia monetaria ya probada
en febrero.

**3554 no se aplicó.** El empate `1023 < 3554 < 3813` permite la posición 470 por
dependencias, pero no demuestra seguridad de su condición `REMUNERATIVO_BRUTO <> 0`.
El movimiento cruza, según convenio, el descuento firmado 4743 (458), la novedad
4873 (460) y el ajuste 4124 (469). Pueden cambiar la verdad de la condición y, por
lo tanto, la activación del concepto. La vigencia abierta desde enero ampliaría
ese alcance. El servicio no produjo una propuesta validada; se conservó 452.
Que las líneas auditadas de febrero tengan coeficiente 1 y resultado cero no
demuestra invariancia de esa condición ni autoriza omitir la guarda.

La comparación inmediata anterior/posterior confirmó un único concepto modificado
y una única auditoría de orden agregada; las otras 57 tablas controladas conservaron
cantidades y revisiones. Fórmulas de importe, condiciones, fechas, fracciones,
restricciones y recibos guardados permanecieron idénticos. No hubo recálculos,
publicación ni reinicio del servicio. Evidencia privada:
`.snapshots/aplicar-3554-4905-20261018/`.

## 3554 final: condición y orden autorizados (18/10/2026)

Después del rechazo anterior, el usuario aprobó expresamente ajustar también la
condición de habilitación de `3554` para `LIQ_FINAL`, conservando su fórmula de
importe. Se actualizaron únicamente estos dos textos de su vigencia abierta desde
el 01/01/2026:

```text
Fórmula Orden Cálculo: IF(TIPO_LIQ = 'LIQ_FINAL', 470, 452)
Condición: IF(TIPO_LIQ = 'LIQ_FINAL', 1, REMUNERATIVO_BRUTO <> 0)
```

La final calcula con sus componentes explícitos después del feriado y antes del
SAC: `1023 → 3554 → 3813`, con empate 470 resuelto por código. La rama final ya no
depende del subtotal del bruto para habilitarse. Los otros tipos conservan 452 y
su condición anterior. Este ajuste de habilitación es intencional: una cancelación
del bruto por otros descuentos no impide calcular el complemento de los componentes
incluidos en la fórmula final. No se duplicó esa fórmula dentro de la condición.

El navegador volvió a rechazar la autenticación. Se aplicaron ambos textos en una
única transacción SQL con guarda de revisión y comparación completa de la fila,
conservando exactamente fórmula de importe, fechas y demás configuración. Se
agregaron dos auditorías diferenciadas: modificación de condición y cambio de orden.
Se reinició `MicrosoftDynamicsNavServer$BC252` y se confirmó su regreso a Running
para descartar la caché anterior. No hubo cambios de código ni publicación.

La comparación previa/posterior confirmó sólo esa vigencia modificada y dos
entradas de historial nuevas; las otras 57 tablas controladas conservaron cantidades
y revisiones. Fórmulas de importe, fracciones, restricciones, otros conceptos
(incluido el 4905 recién corregido) y todos los recibos guardados permanecieron
idénticos. El control instalado de `3554`, a referencia 28/02/2026 y tipo `LIQ_FINAL`,
quedó sin conflictos ni contexto pendiente en los ámbitos comprobados.

El usuario recalculará los recibos. La comparación posterior con Meta4 de 3554,
promedio y SAC sigue pendiente; la ausencia de conflictos de orden no certifica
esa igualdad monetaria. Evidencia privada:
`.snapshots/3554-final-condicion-orden-20261018/`.
