**Temas a resolver y conciliación de enero de 2026 — Business Central contra Meta4**

Enero está recalculado y **no concilia**. Sobre los 307 empleados que tienen liquidación en los dos sistemas, BC paga **157.438.452,57 de bruto de más** y **112.131.284,22 de neto de más**. Sólo 31 empleados coinciden dentro de un peso.

La mayor parte de ese desvío tiene tres causas identificadas y ninguna de ellas es un error de cálculo del motor: un recibo de vacaciones que se emite cuando no corresponde, un acuerdo sindical que se aplica a más del doble de gente que en Meta4, y la producción de oficiales que no se puede calcular porque falta un parámetro. A eso se suman 22 empleados a los que Meta4 les pagó y BC no les liquidó nada.

Este informe se apoya en el trabajo previo de `../revision-enero-2026-20260927/Informe.md`, que sigue vigente en todo lo que no se contradiga acá.

---

**Advertencia de método: el comparador por concepto no es una medida de desvío**

De las 545 columnas que Meta4 usó en enero, **sólo 83 están mapeadas a un concepto de BC**. Las no mapeadas mueven 130.321.773.694 contra 2.904.512.853 de las mapeadas, aunque ese volumen incluye precios unitarios y acumuladores, no sólo importes pagados.

En particular **`PR_SUELDO`, `PR_NAVEG`, `PR_ORDENES` y `PR_PUERTO` no están mapeadas**, y son precios, no importes: mapearlas sería un error. La consecuencia práctica es que el concepto **1003 Sueldo aparece con 352.997.088,70 en BC y 0 en Meta4**, y eso **no es un desvío**: es que el sueldo de Meta4 no viaja por ninguna columna mapeada. Lo mismo pasa con las contribuciones patronales 7000, 7010, 7030, 7050, 7060 y 7070, que suman 526 millones "de más" y no tienen contraparte mapeada.

**Las cifras confiables son las del agregado** (`TOT_DEVENGO`, `TOT_RETEN`, `LIQUIDO`), y el detalle por concepto sólo sirve donde las dos puntas tienen valor. Todo lo que sigue respeta esa distinción.

---

**El agregado**

| Magnitud, sobre los 307 empleados con las dos puntas | BC | Meta4 | BC − Meta4 |
|---|---:|---:|---:|
| Bruto | 1.967.719.199,29 | 1.810.280.746,72 | +157.438.452,57 |
| Neto | 1.337.122.821,22 | 1.224.991.537,00 | +112.131.284,22 |

Cómo se reparte la diferencia de bruto:

| | empleados | diferencia |
|---|---:|---:|
| Coinciden dentro de un peso | 31 | −13,64 |
| Dentro del 1% | 3 | +109.197,49 |
| BC paga de más | 167 | +279.683.142,67 |
| BC paga de menos | 106 | −122.353.873,94 |

Los dos signos se compensan parcialmente: el desvío bruto agregado de 157 millones esconde 279 millones de sobrepago contra 122 de subpago. **No deben sumarse los importes de los hallazgos que siguen**: se superponen entre sí y con estos totales.

**Estos totales son de la corrida con 147 Vacaciones** (76 Cierre de Marea, 77 Devengados, 226 Regular). Después de corregir la regla del punto 1 la corrida quedó en **82 Vacaciones**, así que **el agregado hay que volver a medirlo**: los números de arriba describen un estado anterior y se conservan sólo como punto de partida.

---

**1. Alta: cuándo corresponde el recibo de Vacaciones — resuelto; qué paga — pendiente**

**La regla, corregida y verificada contra Meta4:** el recibo de Vacaciones va **en el mes en que las vacaciones EMPIEZAN**. En `Estado Tipo Liq.` es una sola línea: `Exige AU9`, ventana **Período**, `Empieza en la Ventana` = **Sí**.

El test que la fija, sobre enero de 2026:

| | empleados | corrida aparte en enero | corrida aparte en febrero |
|---|---:|---:|---:|
| AU9 que empieza en **febrero** | 63 | 1 | **54** |
| AU9 que empieza en **enero** | 82 | **64** | — |

Los 64 con corrida aparte más 18 dentro de la mensual dan los 82 cuyo AU9 arranca en enero, y reproducen el reparto TP_IMPUT 3 / TP_IMPUT 1 de Meta4.

**Que se pague por adelantado es cierto pero BC no lo puede leer de la fecha de liquidación**, porque estampa todos los recibos con el último día del período: "fecha de liquidación anterior al inicio de las vacaciones" da verdadero tanto para el que arranca el 5 de enero como para el que arranca el 2 de febrero. Lo que sí se puede leer es en qué mes arrancan. Un anticipo real —cobrar en enero unas vacaciones de febrero— no se infiere de las fechas: es una decisión de pago y necesitaría una marca. En enero de 2026 hubo **uno**.

**Estado medido después del cambio: 82 recibos de Vacaciones**, la población correcta. El 00492, cuyo AU9 arranca el 2 de febrero, quedó sólo con su Regular. El 90016, que arranca el 1 de enero, conserva los dos.

**Lo que NO resuelve, y es lo que queda de este punto.** Cuando los dos recibos existen, **los dos pagan el mes completo**. El 90016 sigue con Vacaciones 24.208.251,76 y Regular 26.173.261,08, con netos de 16.261.499,41 y 16.261.499,57 — prácticamente el mismo neto dos veces. Meta4 resuelve esto pagando a 64 por separado y a 18 dentro de la mensual; BC paga los dos enteros.

**Los tramos de cobertura no son el problema.** En el 00291 la de Vacaciones toma 5–15 y 30–31 y la Regular 1–4 y 16–29, sin solaparse. El reparto de días funciona; lo que falla es qué conceptos entra cada recibo.

Historial de los dos intentos fallidos, porque cada uno enseña dónde está la trampa: primero se borró la línea `Período` dejando `MesSiguiente`, y el recibo salía **un mes antes** de las vacaciones. La ventana correcta era la que se había borrado — lo que faltaba no era cambiarla sino exigir que el estado *empezara* ahí.

El mecanismo que faltaba es el campo **`Empieza en la Ventana`** de `Estado Tipo Liq.`: con Sí, la línea exige que el estado **arranque** dentro de la ventana (`SetRange("Fecha Inicio", Desde, Hasta)`) en vez de rozarla. `HayEstado` filtraba por solapamiento —`Fecha Inicio <= Hasta` y `Fecha Fin >= Desde`— y por eso un AU9 del 1 de enero al 4 de febrero entraba por cualquier ventana de las dos. Es ortogonal a la ventana, así que sirve para cualquier regla futura del mismo tipo, y por eso es un campo y no un valor nuevo del enum.

**Y el sembrador tuvo que cambiar dos veces.** Primero para **converger** en vez de sólo crear: salía si ya existía una línea con el mismo tipo, estado y ventana, con lo cual la bandera nueva nunca se habría escrito en una instalación ya corrida. Después para **retirar explícitamente la regla vieja**: `ExigirEstado` empareja por (tipo, estado, ventana), así que una línea que cambió de ventana no se pisa — queda la vieja y se agrega la nueva. Como las líneas "Exige" se combinan con **O**, una instalación actualizada seguiría admitiendo empleados por la regla anterior y se comportaría distinto de una nueva. `RetirarEstado` la da de baja por nombre, una regla por vez, para no llevarse puesta ninguna línea agregada a mano en la página.

**Lo que esto todavía no resuelve.** `DiaEnLaVentana` (Cod50016) hace:

```al
if FTramosDesde.Count() = 0 then
    exit((Dia >= FPeriodoFechaDesde) and (Dia <= FFechaRef));
```

o sea **cero tramos = el período entero**. Con la regla vieja ese camino se comía a todos los recibos generados un mes antes. Con la regla corregida los 82 recibos tienen días propios en el mes, así que el fallback deja de ser el caso mayoritario — pero sigue en pie para cualquier recibo que quede sin tramos, y no se tocó.

**Lo que sí queda abierto es qué paga cada recibo cuando hay dos.** Vacaciones tiene `Sólo Conceptos Declarados = false`, así que entran los conceptos generales y el mensual se paga entero en los dos documentos; y `ResolverNetoGarantizado` resuelve el objetivo de grossing-up completo por documento sin descontar lo que ya cubrió el otro. Acotar los conceptos declarados es la palanca natural, pero **ya se probó antes en este proyecto y, con la lista incompleta, perdió 18 conceptos** — hay que armar la lista completa primero.

Siguen abiertas las otras causas que ya señalaba el informe anterior: `1003` devuelve el básico sin proporcional por cobertura, Vacaciones tiene `Sólo Conceptos Declarados = false`, y `ResolverNetoGarantizado` resuelve el objetivo de grossing-up completo por documento sin descontar lo que ya cubrió el otro.

---

**2. Alta: 22 empleados que Meta4 pagó y BC no liquidó**

Suman **199.194.089,51** de bruto en Meta4 sin ninguna contraparte en BC. Se parten en dos grupos con causas distintas.

**Catorce eran la cohorte de cierres que terminaban con error — causa identificada y corregida.** Son 03664, 04826, 04836, 04913, 03772, 04105, 04586, 04915, 04914, 04830, 04839, 04840, 04838 y 04841, y el de mayor importe unitario de todo el informe: 03664 solo son 39.892.780,08.

La causa es `CalcDiasFeriadosGuardia` (Cod50016) recorriendo **día por día un estado abierto**. `FechaFinEfectiva()` devuelve **31/12/9999** cuando el estado no tiene fecha de fin, y el `FechaActual += 1` termina pasándose del máximo que admite un `Date`: el cálculo entero muere con **"La fecha no es válida."**. Los 14 tenían un `GP` abierto iniciado entre el 26/4 y el 2/6 de 2026 —un estado **futuro** respecto del mes que se liquidaba— con `Devenga Francos = 1` y `Transcurre en Marea = 0`, que son las dos condiciones que hacían entrar al bucle. 14 de 14, sin excepciones. Eran 183 errores en el registro de procesos.

El arreglo es **recortar contra la ventana antes de recorrer**, como ya hacía `DiasEnLaVentana`: se intersecta el estado con cada tramo y se recorre sólo la intersección (`FeriadosDelTramo`), y un `SetFilter("Fecha Inicio", '<=%1', FFechaRef)` descarta de entrada los estados futuros. Preguntar día por día si el día cae en la ventana daba el mismo resultado pero no acotaba nada.

**Y el error se borraba solo**, que es por qué los 14 pasaron desapercibidos una revisión entera. `CalcularYDescartarSiVacia` conservaba bien la liquidación fallida, pero `BarrerVacias` la borraba después: una que falló no tiene líneas, así que `EstaVacia` dice que sí. Se agregó `FFallidas`, que las deja fuera de la barrida y se limpia al empezar cada corrida. Ninguna de las dos correcciones está publicada todavía.


**Ocho no cuelgan de un proyecto** y por eso el recorrido por proyectos no los alcanza: 04775, 04900, 04925, 04889, 04888, 04360, 90448 y 03964. La corrección está escrita y compila —`CrearSinProyecto` en Cod50018 recorre estados además de proyectos para los tipos agrupados por empleado— pero **no está publicada**. Ver el punto 6.

---

**3. Alta: 3554 se aplica a más del doble de empleados que en Meta4**

| | BC | Meta4 |
|---|---:|---:|
| Importe | 401.614.424,27 | 338.003.230,16 |
| Empleados | **300** | **137** |

La diferencia de importe es +63.611.194,11, pero lo que importa es la cobertura: BC lo aplica a 300 personas y Meta4 a 137. Su condición vigente sólo pide `REMUNERATIVO_BRUTO <> 0` y permite REGULAR.

El caso demostrado es **04047**: las incidencias importadas de 4125 y 4165 suman exactamente su bruto de Meta4, y BC le agrega 3554 por **8.593.651,27**, que explica con exactitud toda su diferencia. Es una prestación ILT que ya llega separada en remunerativo y no remunerativo, y 3554 la vuelve a separar.

Afecta también aportes y Ganancias, así que corregirlo mueve el neto además del bruto.

---

**4. Alta: la producción de oficiales no se puede calcular**

| Legajo | Convenio | Bruto BC | Bruto Meta4 | Diferencia |
|---|---|---:|---:|---:|
| 04868 | 768/19 | 23.196.504,31 | 37.400.282,69 | −14.203.778,38 |
| 04837 | 175/75 | 21.905.885,97 | 34.621.798,95 | −12.715.912,98 |
| 04724 | 768/19 | 9.939.569,33 | 20.956.237,60 | −11.016.668,27 |

El concepto **2003** concentra el desvío: BC 129.197.485,52 contra 251.852.298,85, **−122.654.813,33** sobre 9 empleados en BC y 13 en Meta4.

Para 04724 está demostrada la falta de **`PCT_PROD` para 768/19 categoría OF03** vigente en enero: `PROD_EMPRESA` usa 0% y sólo computa el componente en dólares, y 2003 termina negativo. **El porcentaje correcto debe validarse contra el acuerdo, no inferirse por diferencia.** OF01 y OF02 sí tienen `PCT_PROD` = 2% y aun así no reproducen lo pagado, así que hay algo más en esa fórmula.

En la misma familia, **2498 Producción total SOMU**: BC 407.473.974,10 contra 478.030.161,96, −70.556.187,86, sobre 68 empleados en BC contra 78 en Meta4.

---

**5. Media: conceptos que Meta4 paga y BC deja en cero**

Treinta conceptos. Los de mayor importe:

| Concepto | Descripción | Meta4 | Empleados | Estado en BC |
|---|---|---:|---:|---|
| 2803 | Indemnización francos no gozados | 12.818.826,01 | 6 | sin fórmula |
| 1023 | Sueldo de feriado | 5.838.727,55 | 98 | **tiene fórmula y paga 0** |
| 3973 | Vacaciones no gozadas | 2.632.319,84 | 8 | sin fórmula |
| 8542 | Caja compensadora | 2.180.633,11 | 4 | sin fórmula |
| 2083 | A cuenta futuros aumentos francos | 1.535.412,47 | 9 | sin fórmula |
| 3813 | SAC egreso primer semestre | 1.403.259,34 | 7 | sin fórmula |
| 8563 | Contribución solidaria SOMU | 1.237.940,51 | 4 | sin fórmula |
| 8553 | Centro de capacitación | 1.122.178,88 | 9 | sin fórmula |

**1062 no entra en esta lista, y el porqué es una advertencia de método.** Figuraba con 35,7 millones en 271 empleados, y era falso: la columna de Meta4 mapeada a 1062 es `PR_FRANCO`, que es el **precio** del día de franco, no el importe pagado. Se delata sola — tiene 17 valores distintos entre 271 empleados, mientras una columna de importes como `ANTIGUEDAD` tiene 126 entre 209. Es además la única columna `PR_*` mapeada a un concepto; el resto —`PR_SUELDO`, `PR_NAVEG`, `PR_ORDENES`, `PR_PUERTO`— están sin mapear justamente por ser precios. **Ese mapeo hay que corregirlo**: mientras exista, toda comparación que toque 1062 suma precios contra importes.

**1023 y las horas extras (1803, 1813, 1893) tienen fórmula y pagan cero**, que es un síntoma distinto de "falta cargar la fórmula": ahí hay un insumo en cero, no una configuración faltante.

Los que no tienen fórmula son una decisión de carga, no un error del motor.

---

**6. La antigüedad: años y porcentaje resueltos, base resuelta para oficiales, abierta para marinería**

El concepto **1053** tiene tres piezas independientes —cuántos años, qué porcentaje les corresponde y sobre qué importe se aplica— y conviene separarlas, porque dos quedaron cerradas y una sigue abierta.

**Los años: el modelo de BC es el correcto y no hay que tocarlo.** Validado contra la columna `ANIOS_ANTIG` de Meta4 —su propia antigüedad en años, la que usa para pagar— sobre los 330 que Meta4 pagó en enero:

| Modelo | Coinciden | Se van de un año |
|---|---:|---:|
| Suma de los tramos trabajados (lo que hace BC) | **314** | **0** |
| Corrido desde la primera alta | 140 | 113 |
| Corrido desde `Employment Date` | 128 | 120 |

En los de cuatro o más fases —los relevos— la suma da 6,70 contra 6,73 de Meta4, mientras que corrido daría 10,60: **los huecos entre campañas no cuentan**. El campo `Antigüedad Reconocida` queda en cero a propósito (ver el punto 10).

**El porcentaje: resuelto con dos vigencias de fórmula.** La escala está bien —2-4-8-10-12-14-18 y 25 desde los diez años, idéntica a la de Meta4 para 729/15—, pero `PCT_ANTIG_SOMU` la evaluaba sobre la antigüedad **al 30 de junio**, que es lo que dice el Art. 32 del CCT. **Meta4 no aplica ese corte**: su `PORC_ANTIG` coincide con el tramo de la antigüedad corriente en 216 de 230 casos y con el del 30/6 en sólo 175. El corte le daba un porcentaje menor a 45 empleados, y en los 45 el bueno era el corriente. El testigo es el 00291: 2 años al 30/6 contra 3,12 corrientes, 4% contra el 8% que pagó Meta4.

Se resolvió con **dos vigencias del concepto**, no con un `IF` adentro de la fórmula:

    2023-01-12 a 2026-06-30 : escala sobre AÑOS_ANTIGUEDAD  (la corriente) → reproduce Meta4
    2026-07-01 en adelante  : escala sobre AÑOS_ANTIG_30JUN (Art. 32, como estaba)

`Concepto Liquidación` tiene clave Código + Vigencia Desde y el motor resuelve por fecha, así que la vigencia futura no contamina un recálculo de enero. Es el **primer concepto de la base con dos vigencias**; conviene mirar un recibo de enero y otro de julio antes de darlo por cerrado.

**La base: no es la misma para los dos convenios.** Así quedó la fórmula:

    Oficiales (175/75, 768/19) → PRECIO_NAV / 30 × días × porcentaje
    Marinería (729/15)         → BASE_SUELDO × porcentaje

El discriminador es **el porcentaje, no `TIPOACTIVIDAD`**: `PCT_ANTIG_OFICIALES` tiene CCT para 175/75, 768/19 y ESP, y `PCT_ANTIG_SOMU` sólo para 729/15, así que se excluyen entre sí y `#PCT_ANTIG_OFICIALES > 0` identifica al oficial sin inventar ninguna regla nueva.

**Para oficiales está verificado al peso en 16 de 17 casos.** El testigo es el 00607: Meta4 le paga 383.625,00 = 1.485.000 / 30 × 31 días × 25%. Con `BASE_SUELDO` le salían 428.289,57, porque `BASE_SUELDO` es lo que cobró de **órdenes** y las órdenes se le pagan a 55.263,17 por día, no a los 49.500 del precio base. Los casos con distinta cantidad de días lo confirman —00728: 4 días → 30.000; 01591: 4 días → 38.733,33—, que es lo que descarta que sea un 25% plano del básico mensual.

Se usa `PRECIO_NAV` y **no `BASICO`**, aunque hoy valgan lo mismo en las cuatro categorías de oficial: una sola lista por valor, decisión tomada para no depender de dos listas que pueden separarse. Por eso se borraron las cuatro vigencias de `BASICO` de 175/75 y 768/19. Antes de borrarlas se miró quién las lee: nueve conceptos leen `BASICO`, y el único que le pagaba a un oficial era 3553, que lo toca sólo dentro de `IF(BASICO_EsFCY, …)`, rama a la que los 13 oficiales con vacaciones nunca llegan porque tienen `VAC_PROMEDIO = 1`. Quedaron dos vigencias de 2023 que son **datos muertos** —`BASICO_175/75_OF01` y `BASICO_175/75_OF03`—: ese par convenio+categoría no existe y tiene 0 empleados.

**Y desde el 28/9 cuenta también los días de guardia de puerto**, que la suma de días dejaba afuera aunque 1083 los pague. Afecta a un solo oficial en enero —el 00794, que pasa de 0,00 a 232.500,00, exactamente lo de Meta4— y no mueve a ningún otro. Ver el punto 10.

**Lo que sigue abierto es la base de marinería.** `BASE_SUELDO` (vigencia 2026-01-01) junta al 100%: 1003 Sueldo, 1013 Navegación, 1033 Dique, 1043 Pilotaje, 1045 Asistencia y remolque, 1063 Franco, 1073 Órdenes, 1075 Art. 19, 1076 Art. 48 y 1083 Puerto; todos aportan con orden de cálculo ≤ 80 y 1053 corre en el 100, así que la base está completa cuando la antigüedad la necesita. El caso de referencia da bien —legajo 00191: 32.274,88 × 25% = 8.068,72, exactamente lo de Meta4— pero **en el agregado no cerraba**: 91 empleados de 729/15 tenían la base en cero porque no pagaron ninguno de los diez conceptos en ninguna liquidación, en buena medida porque su cierre de marea era uno de los 14 que morían con error.

**Ese bloqueo ya se levantó** (punto 2), pero la corrección no está publicada, así que **la composición para marinería hay que volver a medirla con los 14 recuperados**. Es lo único que falta de este punto.

**Vacaciones no puede entrar a la base todavía.** 3553 tiene orden de cálculo **450** y 1053 corre en el **100**: si las vacaciones deben integrar la base, hay que mover el productor hacia atrás, no el consumidor hacia adelante.


---

**7. Media: el recibo dice "DÍASES" — corregido**

Diez conceptos tenían `Unidad Cantidad` = `DÍAS`, que **no existe** en el catálogo de unidades: existe `DIA`, y justamente tiene `DÍAS` cargado como "Plural (recibo)". `UnidadParaMostrar` no encontraba la unidad, caía en la derivación por regla —termina en consonante, se agrega ES— y salía `DÍASES`. Eran 1.290 líneas de enero.

Los conceptos eran 1073, 1075, 1076, 4110, 4120, 4125, 4160, 4165, DIAS_ART19 y DIAS_ART48. Se corrigieron los conceptos **y las líneas ya liquidadas**, porque la línea guarda su propia unidad y los recibos de enero seguirían mostrando el error aunque se recalculara.

El campo **tiene** `TableRelation` a `Unit of Measure`, así que el valor no entró por la página: entró por una carga directa que la saltea. Queda como control: ninguna unidad usada, ni en conceptos ni en líneas, puede faltar del catálogo, o se deriva mal en silencio.

---

**8. Lo que está corregido pero todavía no surte efecto**

**La configuración de Vacaciones volvía sola.** Se eliminó la línea `Período` de `Estado Tipo Liq.`, pero reapareció con otro número de línea (la 33 en vez de la 2): la recrea `Gestión Tipo Liq.ConfigurarDisparadores()`, que corre en cada Install/Upgrade y volvía a sembrarla. **La corrección se movió al sembrador** (Cod50055) y compila; hasta publicar, el borrado en la base se deshace en el próximo upgrade.

**El recorrido por estados no está publicado.** `CrearSinProyecto` resuelve los 8 empleados sin proyecto del punto 2 y compila limpio, pero la corrida de enero se hizo con la versión anterior.

**El arreglo de `CalcDiasFeriadosGuardia` tampoco.** Es el que recupera los 14 cierres del punto 2, junto con `FFallidas`, que impide que la liquidación fallida se borre sola.

**Y los cambios por SQL necesitan reinicio.** La configuración de tipos de liquidación, las fases, los estados, las vigencias de fórmula, el concepto 2083, la lista de `PRECIO_PUERTO` y la suma de días de 1053 se modificaron por SQL directo, que no invalida la caché del service tier.

Para que la próxima corrida refleje todo: **publicar la extensión, reiniciar el servicio de BC, borrar las liquidaciones de enero y volver a crear y calcular.**


---

**9. El legajo 00291, en detalle**

Es el caso que se venía siguiendo. Hoy está así:

| | BC | Meta4 | Diferencia |
|---|---:|---:|---:|
| Bruto | 4.822.659,98 | 4.773.046,28 | +49.613,70 |
| Neto | 2.732.488,67 | 2.550.028,00 | +182.460,67 |

El bruto está dentro del 1%. **El neto se despega por una sola retención que BC no aplica**:

| Concepto | BC | Meta4 | Diferencia |
|---|---:|---:|---:|
| 5010 Impuesto a las ganancias | 0,00 | 136.915,36 | −136.915,36 |
| 4751 Jubilación sobre SAC devengado | 26.251,75 | 13.125,88 | +13.125,87 |
| 4754 Cuota sindical SAC devengado | 13.148,62 | 15.910,16 | −2.761,54 |
| 4753 Obra social SAC devengado | 11.932,61 | 9.558,43 | +2.374,18 |

La cuenta cierra: los 49.614 de bruto de más, más los 136.915 de Ganancias que no se retienen, menos unos 4.000 netos de diferencias de aportes, dan los 182.461. **No hay ningún otro concepto que explique su neto.**

**Una conclusión anterior de este informe sobre 1062 era falsa y se retiró**: los 53.158,67 que figuraban como francos no pagados son el **precio** del día de franco de Meta4 (`PR_FRANCO`), no un importe. Ver la advertencia en el punto 5.

**La antigüedad quedó bien.** Con el porcentaje corregido —8%, antes aplicaba 4%— y el recálculo, 1053 ya no aparece entre sus diferencias: coincide con Meta4 dentro de un peso. Lo que sigue abierto es el modelo general de la base (punto 6), no este caso.

---

**10. Lo que se corrigió en esta sesión, con su efecto medido**

- **38 fases abiertas en BC que Meta4 tenía cerradas**, más 36 fases que faltaban. Los estados vigentes por mes que Meta4 no pagaba pasaron de 19/20/22/23/31/37 (enero a junio) a **0 en enero, febrero, marzo y junio**, y 1 en abril y mayo. Las fases abiertas de BC quedaron en 291, las mismas que Meta4.
- **`PCT_ANTIG_SOMU` partido en dos vigencias**: hasta el 30/6/2026 usa la antigüedad corriente, desde el 1/7/2026 el corte del Art. 32. Meta4 no aplica el corte —su `PORC_ANTIG` coincide con la corriente en 216 de 230 casos y con el del 30/6 en 175—, y con esto los seis primeros meses coinciden. **Es el primer concepto de la base con dos vigencias**: conviene mirar una liquidación de enero y otra de julio.
- **La base de antigüedad de oficiales vuelve a `PRECIO_NAV`** y marinería queda con `BASE_SUELDO`, discriminadas por `#PCT_ANTIG_OFICIALES > 0`. Verificado al peso en 16 de 17 oficiales de enero. Ver el punto 6.
- **Los 14 cierres que morían con "La fecha no es válida"**: `CalcDiasFeriadosGuardia` recorría día por día un estado abierto, que termina el 31/12/9999. Ahora recorta contra la ventana antes de recorrer. Y `FFallidas` impide que `BarrerVacias` borre la liquidación fallida, que es lo que hacía desaparecer el síntoma. **Escrito y compilado, sin publicar.**
- **Concepto 2083 "A cuenta de futuros aumentos francos", implementado y verificado 9 de 9.** Es `valor de EMPRESA del franco × días − (sueldo de francos + antigüedad)`, con el valor de empresa en dólares por mes y convertido al **tipo de cambio comprador**. Se creó el parámetro `VALOR_FRANCO_ACDO` con dos vigencias desde el 1/1/2026 —`175/75_OF02` = USD 3.500 y `175/75_OF04` = USD 2.975— y la fórmula lleva guarda `IF(VALOR_FRANCO_ACDO = 0, 0, …)` porque el CCT del concepto cubre 175/75 **todas las categorías** más ESP: sin la guarda, los 18 empleados de enero con días de franco fuera de OF02/OF04 cobrarían un importe negativo. OF01 y OF03 quedan deliberadamente sin cargar hasta que un caso o el acta los confirme; un precio de acuerdo no se deduce. Los nueve casos de enero —con 1, 4, 10 y 31 días y las dos categorías— dan **diferencia 0,00** contra Meta4.
- **El precio de puerto de oficiales tenía el valor de mayo cargado desde enero.** `PRECIO_PUERTO_LAN_175/75_OF02` valía 3.600 USD con vigencia 1/1/2026, y 3.600 USD es el precio de **mayo**: el 00794 cobraba 5.263.800 de sueldo de puerto donde Meta4 le paga 1.860.000. Medido en `PR_PUERTO` × 30 sobre los seis primeros meses, hasta abril son 1.800.000 pesos (OF02) y 1.530.000 (OF04), y desde mayo pasan a dólares **partidos por pesquería**: 3.600 / 3.060 en tangoneros y 6.000 / 5.100 en poteros. En 768/19 el precio no cambia en mayo y no se parte: OF01 5.500 USD y OF03 4.304 USD todo el semestre. La lista quedó en 12 filas y se borraron 13 —tres pares que no existen (`175/75_OF01`, `768/19_OF02`, `768/19_OF04`) y las vigencias de mayo de 768/19—. **Control: 67 de 70 combinaciones en 0,00**; las 3 restantes son tres empleados sueltos de mayo a los que Meta4 todavía liquidó al precio viejo.
- **1053 no contaba los días de guardia de puerto.** Sumaba `DIAS_PROYECTO + DIAS_PUERTO + DIAS_FRANCOS_PERIODO + DIAS_ORD_PERIODO` y dejaba afuera `DIAS_GP_PERIODO`, que 1083 sí suma para pagarle el sueldo a esos mismos días. El 00794 tiene `DIAS_PUERTO = 0` y `DIAS_GP_PERIODO = 31`, así que su antigüedad salía **0,00 sin ningún error** contra los 232.500,00 de Meta4. Agregado el término, da 232.500,00 exacto. De los 20 oficiales con línea de 1083 en enero el único con días de GP es él, así que los 16 de 17 que ya coincidían no se mueven; y la rama de marinería no hizo falta tocarla porque usa `BASE_SUELDO`, que incluye 1083.
- **Queda confirmada la lista de precios de oficiales.** Las columnas `PR_*` de Meta4 son uniformes por categoría en los 40 oficiales de enero, y `PRECIO_NAV` y `VALOR_FRANCO` de BC coinciden **al peso** con `PR_SUELDO` y `PR_FRANCO` en las cuatro. Con eso se cae una duda que este informe traía abierta: `VALOR_FRANCO_175/75_OF03` = 127.350 no es un error de escala —127.350 es el precio de OF03, que vive en 768/19, y dentro de 175/75 la razón OF04/OF02 es 0,85 exacto—.

- **Diez conceptos y 1.290 líneas con la unidad inexistente `DÍAS`**, que el recibo mostraba como "DÍASES". Ver el punto 7.
- **38 motivos de baja** escritos con el valor crudo de Meta4 (`1`, `12`) traducidos a la convención de BC (`BAJ-1`, `BAJ-12`).


**Y algo que se revirtió**: se cargó `Antigüedad Reconocida` a 195 empleados suponiendo que Meta4 contaba la antigüedad corrida desde `FEC_ANTIGUEDAD`. Es falso —validado contra la columna `ANIOS_ANTIG` de Meta4, el modelo de BC, que suma sólo los tramos trabajados, acierta en 314 de 330 y ninguno se va de un año— y en los relevos daba de más. El campo volvió a cero y **debe quedar así**.

---

**Orden propuesto**

1. **Publicar y reiniciar**, borrar enero y recalcular. Es el paso que habilita casi todo lo demás: retira la regla vieja de vacaciones en las instalaciones ya corridas, recupera los 14 cierres que morían con error y alcanza a los 8 empleados sin proyecto.
2. **Volver a medir el agregado**, que hoy describe la corrida de 147 Vacaciones y ya no vale.
3. **Definir la composición de la base de antigüedad para marinería**, que con los 14 cierres recuperados ya se puede medir: era lo único que faltaba del punto 6.
4. **Corregir el mapeo de `PR_FRANCO`**, que es un precio mapeado al concepto 1062. Es una fila y contamina toda comparación que toque francos.
5. Definir qué conceptos paga cada documento cuando hay Vacaciones y Regular, que es lo que queda del punto 1 y hoy paga el mensual dos veces.
6. Acotar 3554 y completar `PCT_PROD` de oficiales.
7. Recién después, los conceptos sin fórmula, que son carga de datos y no diagnóstico.


Los importes de este informe son documentación salarial: contienen legajos y remuneraciones.
