---
tipo: guia
tags: [pendientes, liquidación-final, enero-2026]
fecha: 2026-10-11
actualizado: 2026-10-12
fuente: [scripts/CorregirPendientesFinalOct12.sql, scripts/CorregirGananciasFinalAnual.sql, scripts/SepararSindicalRealGananciasFinal.sql, scripts/CorregirSindicalSACDevengado.sql, src/Codeunits/Cod110031.RecalculoEnCadenaLiq.al]
---

# Pendientes de la liquidación final — enero 2026

Las primeras secciones conservan el diagnóstico del 11/10/2026. El estado posterior aplicado
y verificado está en **Estado económico actualizado — 12/10/2026**, al final de esta nota.

## Lo que ya cierra

| | Estado |
|---|---|
| **Francos no gozados** (2803/2804) | **12 de 12 exactos** — ver [[devengados-no-gozados-pagaban-cero]] |
| **Vacaciones no gozadas** (3973/3974) | **13 de 14**; falta sólo 90448 |
| **Cobertura** | 0 días fuera de fase, 0 solapamientos en 570 liquidaciones |
| **Gratificación guardia puerto** (2043) | 21 de 21 |
| **SAC de egreso** (3813) | 6 de 7; queda el caso de prorrateo del punto 5 |
| **Sueldo de feriado** (1023) | Caso pendiente resuelto: feriado y SAC asociado verificados al centavo con Meta4 |
| **Novedades** | 604 aplicadas, 1 pendiente |
| **Bruto de las 8 finales** | **6 de 8 a centavos** (resto ≤ 0,86). Quedan 90448 y 04925 |
| **Descuentos de las 8 finales** | **4 de 8 exactos** sacando Ganancias; los 4 residuos van de −7.222 a +39.721 |

## El estado de las ocho, medido el 11/10/2026 después de recalcular las 570

> [!important] La brecha de bruto de 2.060.565 era la MÉTRICA, no el motor
> `TOT_REMUN_27617` **no incluye el SAC** y el bruto de BC sí (el 3813 aporta a
> `REMUNERATIVO_BRUTO`). En cinco de los ocho, la diferencia era **exactamente su SAC de egreso al
> centavo**. Sumando `SAC_ABONADO` del lado de Meta4 —ya corregido en el comparador, 1.0.0.614—:
>
> | Emp | Resto de bruto | | Emp | Resto de bruto |
> |---|---|---|---|---|
> | 03964 · 04889 | 0,00 | | 04190 | −0,86 |
> | 04807 | −0,22 | | **04925** | **−73.894,57** |
> | 04775 · 04900 | −0,30 | | **90448** | **+731.202,18** |
>
> Detalle y motivo en [[Comparador BC vs Meta4]]. En junio y diciembre esto afectaría a toda la
> nómina, no sólo a los egresados.

Y en descuentos, **Ganancias es toda la historia de los dos grandes**: Meta4 retiene 0 en los ocho, y
BC retiene 1.210.337 en 04190 y 1.360.613 en 04807. Sacando eso, cierran exacto 03964, 04889, 04900 y
04775 (a un centavo), y quedan cuatro residuos: +39.721 (04190), +16.909 (90448), −7.222 (04807) y
−5.173 (04925).

## Herramienta nueva: [[Dónde se usa un símbolo]]

Página **110062**, del 11/10/2026. Contesta *qué le afecta si toco esto* buscando el símbolo en los
ocho lugares donde puede estar nombrado —fórmula, condición, variable de cantidad, variable de base,
filtros de fuente de datos, fracciones **en las dos direcciones**, variables de sistema y los campos
de concepto que apuntan por código— con los bordes marcados, así `DIAS` no encuentra `DIAS_MAREA`.

Su columna roja marca quién **lee antes de que el símbolo esté listo**, y para un acumulador el umbral
es el orden de su **último aportante**, no el suyo. El punto 4 de esta lista se replanteó entero con la
primera corrida.

## Implementación preparada el 12/10/2026 — pendiente de publicar y recalcular

Ver [[final-vacaciones-sac-descuentos-coordinados]]. La previsualización de descuentos cierra las
8 finales con diferencias aisladas de un centavo. Se reutiliza el 3573 con orden alternativo sólo
en la final del 372/04, y el SAC incorpora su parte proporcional. Los descuentos reutilizan
6002/6012/6034/8523; los ordinarios excluyen el SAC para no cobrarlo dos veces y permiten los
reintegros de topes. El residuo principal de 04925 es el SAC no remunerativo de Meta4, no el
reparto 3554/AJ_PROM_PESQUERIA: se prepara 3814 porque ese pago no existe en el catálogo BC.
El motor lee los atributos del empleado egresado al último día de cobertura.

AL compilado; script scripts/CorregirPendientesFinalOct12.sql ejecutado sólo en previsualización.
No se aplicó todavía esta configuración. Las cifras y diagnósticos previos de abajo conservan
su fecha de medición; la corrección no se declara verificada hasta publicar y recalcular.
Ganancias sigue pendiente después de esa verificación.

## Lo que queda, en orden

### 1. Feriado — resuelto y verificado el 11/10/2026

El 1023 es un **promedio diario** y divide por los días de SU liquidación. Los 2 días previos al
zarpe (1 y 2 de enero) van a la Regular en 89 de los 90 cierres, y ahí coinciden con Meta4; 04190 es
el único que los tiene en su **final**, porque es egresado y no lleva Regular. Al caer en una
liquidación de 4 días en vez del mes entero, el promedio sale distinto.

Criterio de RRHH: *"la antigüedad al momento de la liquidación de la marea tiene que incluir esos dos
días de GP, porque más allá de que no se hayan liquidado, ya se devengaron"*.

Descartado: calcular el feriado sobre la base mensual completa (da 36.091,95 contra 46.956,80,
porque esa base mezcla la navegación del cierre).

### 2. Base de promedio — resuelta y verificada el 11/10/2026

Causa confirmada: los haberes de puerto y gratificación entraban ya reducidos por pesquería,
pero el SAC volvía a aplicar el coeficiente. El franco del ledger entraba completo.

Aplicado el 11/10/2026: `AJ_PROM_PESQUERIA`, informativo, sólo `LIQ_FINAL`, orden 469,
una fracción del 100 % únicamente a `BASE_PROMEDIO`. Incluye los aportes directos e indirectos
verificados por su fórmula y la parte proporcional reducida del `1603`.
Detalle, alcance y exclusiones: [[base-promedio-no-mezcla-porciones-y-totales]].
Después de cargar el ajuste se reinició `MicrosoftDynamicsNavServer$BC252` en mimir;
se confirmó `Running → Stopped → Running`. El recálculo posterior ejecutó el ajuste y su fracción.

La previsualización ampliada cierra el SAC del caso afectado al centavo con Meta4 y conserva
las otras siete finales. Las vacaciones de ese caso ya cierran y no toman la base del mes actual.

> [!note] Recálculo confirmado el 11/10/2026
> La línea `AJ_PROM_PESQUERIA` se calculó y aportó únicamente a `BASE_PROMEDIO` con la vigencia
> `20260101`. La nueva base y el SAC coinciden al centavo con la previsualización y Meta4;
> las vacaciones del caso y los SAC de las otras siete finales conservan sus importes anteriores.
> El evaluador actual admite `TIPO_LIQ = 'LIQ_FINAL'`: la comparación por código se confirmó
> en `Cod50015.EvaluadorFormula.al`. La advertencia anterior sobre exigir el número 40 quedó superada.
> El `3554`, sus bases contributivas y el resto de los pendientes no se dan por resueltos.
### 3. 1063 y 3554 — recalculado, y el caso quedó pasado de largo

> [!note] Recálculo hecho el 11/10/2026 a las 20:55+, y medido
> Las 570 liquidaciones se recalcularon. En el caso afectado el `3554` pasó de **4.816.041,98 a
> 886.733,82** y apareció `AJ_PROM_PESQUERIA` con esos mismos 886.733,82. Su SAC quedó en los
> **31.669,07** exactos de Meta4, o sea que **la base cerró**.
>
> Pero su **bruto quedó 73.894,57 POR DEBAJO** de Meta4, cuando antes estaba 807.000 por encima: se
> pasó de largo. Lo que sobra está en el no remunerativo, no en la base —el SAC y las vacaciones
> cierran—, así que el candidato es el reparto entre `3554` y `AJ_PROM_PESQUERIA`, no el promedio.

Ver [[coeficiente-franco-no-cambia-dias-fifo]]. Se preparó el desdoblamiento del 1063 después
del consumo FIFO, el 3554 sobre las porciones verificadas de puerto, gratificación y francos y la conservación de BASE_PROMEDIO, con las
lecturas dependientes de 1603, 2083 y 2803 preservadas. La previsualización coincide con Meta4.
Campo publicado y seis nuevas vigencias aplicadas el 11/10/2026 desde el 02/01/2026. El recálculo previo todavía usaba la fórmula antigua del 3554: publicar no carga las fórmulas de configuración. Falta recalcular después de cargar estas vigencias y verificar contra Meta4.

#### Diagnóstico previo

```
round((REMUNERATIVO_BRUTO - #4125) / #COEF_PESQUERIA * (1 - #COEF_PESQUERIA), PRECISION_REDONDEO)
```

`REMUNERATIVO_BRUTO` incluye las indemnizaciones de francos no gozados (2803/2804), y el coeficiente
debe excluirlas del término. La premisa anterior de limitarlo sólo al 1063 fue rectificada: BC reúne también los haberes de puerto de otra corrida de Meta4, cuyo complemento no remunerativo debe pagarse en esta final.

### 4. Desglosar los descuentos del SAC

> [!danger] La premisa "Meta4 sí lo descuenta" no se sostiene — medido el 12/10/2026
> `TOT_RETEN` de Meta4 **no incluye** la familia `_SAC_MES`. En 04775: su `TOT_RETEN` es 164.457,15 y
> la suma de sus columnas RT+SS da 173.261,55; **sacando las `_SAC_MES` da 164.457,15, clavado**, y
> los 8.804,40 de esa familia quedan afuera.
>
> Y columna por columna se ve por qué: **cada deducción del SAC está dos veces con el mismo valor**,
> una como retención real y otra como registro mensual.
>
> | retención real (entra en `TOT_RETEN`) | espejo mensual (no entra) |
> |---|---|
> | `JUBILACION_SAC` → 6002 · 4.611,83 | `JUB_SAC_MES` → 4751 · 4.611,83 |
> | `C_SINDICAL_SAC` → 8523 · 1.677,03 | `C_SINDICAL_SAC_MES` → 4754 · 1.677,03 |
> | `LEY_19032_SAC` → 6012 · 1.257,77 | `LEY_19032_SAC_MES` → 4752 · 1.257,77 |
> | `OBRA_SOCIAL_SAC` → 6034 · 1.257,77 | `OBRA_SOCIAL_SAC_MES` → 4753 · 1.257,77 |
>
> O sea que **los dos sistemas tratan la familia 475x como devengo** y ninguno la retiene. Antes de
> tocar el 6002 y sus hermanos hay que confirmarlo contra un recibo en papel: si es así, lo único que
> falta es la parte de las bases de Ganancias, no el descuento.



> [!note] Replanteado el 11/10/2026 con la página [[Dónde se usa un símbolo]]
> La premisa anterior —"que los conceptos del SAC lean `#3813`"— **estaba mal**. Los datos de Meta4
> dicen otra cosa, y la familia de conceptos que hace falta **ya existe entera**.

**Cómo apareció, porque el método se repite.** Primera corrida de la página nueva con el símbolo
`4751`: **ninguna fórmula lo nombra**. Llega a Ganancias por su **fracción**, que es la mitad de la
pregunta que se olvida mirando fórmulas:

| Concepto | Aporta el 100 % a |
|---|---|
| 4751 (devengo) | `GAN_NETA_MES`, `GAN_NETA_A_DEDUC`, `SS_SAC_DEV` |
| 6002 (descuento real) | `GAN_NETA_MES`, `GAN_NETA_A_DEDUC`, `SS_LIQUIDADO` |

Mirando sólo fórmulas la respuesta era "casi no se usa", que es exactamente lo contrario de la verdad.
Un concepto puede no estar nombrado en ningún lado y mover plata igual, porque entra a una base por su
fracción. Esa dirección se agregó al buscador por este caso.

**La familia completa.** Devengos, `Es Devengo = 1`, no se descuentan, aplican a
`REGULAR|VACACIONES|LIQ_FINAL|RELIQUIDACION|DEVENGADOS|CIERRE_MAREA`: **4750** SAC, **4751**
jubilación, **4752** ley 19032, **4753** obra social, **4754** cuota sindical (órdenes 924-928).
Descuentos reales, sólo `[AGUINALDO]`: **6002** (902), **6012** (908), **6034** (916), **6036** (920),
**8523** (705, fórmula vacía) y **7002** (932, patronal).

**La regla, leída de Meta4 y exacta al centavo en los 8 egresados de enero:**

| Concepto | Base | Tope |
|---|---|---|
| jubilación, ley 19032, obra social | **remuneración contributiva del período / 12** | SIPA |
| cuota sindical | **el SAC efectivamente pagado**, sin /12 | ninguno |

Meta4 publica la base ya topeada en `SAC_IMPO`, y `SAC_IMPO = REMUN_IMPO_JUB / 12` en los 8 casos.
Que para 04775 eso coincida con `SAC × 11 %` es **casualidad**: su SAC *es* la doceava parte limpia.
En 04190 se separan —SAC 554.204,51 contra base contributiva 276.132,49— porque su SAC sale de un
promedio que incluye francos no gozados, y esos no son contributivos. El sindical de 04190, en cambio,
es 4 % de los 554.204,51 completos.

El desglose de 04775 en Meta4, que es el caso limpio y sirve de patrón (SAC 41.925,69, base
contributiva idéntica porque su SAC es la doceava parte exacta):

| BC | Columna de Meta4 | Importe | % |
|---|---|---|---|
| 6002 jubilación | `JUBILACION_SAC` = `JUB_SAC_MES` = `SAC_IG_JUB` | 4.611,83 | 11 |
| 6012 ley 19032 | `LEY_19032_SAC` = `SAC_IG_LEY` | 1.257,77 | 3 |
| 6034 obra social | `OBRA_SOCIAL_SAC` = `SAC_IG_OSOC` | 1.257,77 | 3 |
| 8523 cuota sindical | `C_SINDICAL_SAC` = `SAC_IG_SIND` | 1.677,03 | 4 |

El SAC pagado también está por triplicado y coincide con el 3813 de BC al centavo: `H_SAC` =
`SAC_ABONADO` = `SAC_IMPO` = 41.925,69.

**El defecto concreto.** La fórmula del 4751 ya es la correcta, pero **tiene el SAC adentro de su
propia base**: el 3813 (orden 470) aporta el 100 % a `BASE_SS_TRAB`, y el 4751 (orden 925) lee ese
acumulador cuando el SAC ya entró. La `Fórmula Evaluada` lo muestra sin intermediarios —para 04775,
`MIN(545.034,009767 + 0 + 0 + 0, 3.823.372,95) * 11% / 100 / 12`— y la resta cierra **al centavo**:

| Empleado | base del 4751 en BC | − su SAC | `REMUN_IMPO_JUB` de M4 | resto |
|---|---|---|---|---|
| 04775 | 545.034,01 | 503.108,32 | 503.108,32 | **0,00** |
| 04889 | 518.297,00 | 478.428,00 | 478.428,00 | **0,00** |
| 04900 | 483.332,04 | 446.152,65 | 446.152,65 | **0,00** |

Hay que restarlo: `… - #3813 - #3823`.

Los otros cuatro egresados no se pueden leer así, y cada uno por un motivo que ya está en esta lista:
04190 y 04807 **topean en el SIPA** y la resta queda tapada; 04925 arrastra los ~807.000 del punto 2;
90448, el prorrateo del punto 5. Que los tres limpios den cero exacto es la prueba.

**Y falta la decisión de forma**, que es lo único abierto. El 475x es devengo y no se descuenta, pero
Meta4 **sí descuenta** en la final. `Es Devengo` es por versión de concepto, no por liquidación, así
que no se puede condicionar fila por fila. Tres caminos:

| | Qué implica |
|---|---|
| **(a) conceptos nuevos** para la final (6003/6013/6035/8524) con la fórmula de la doceava parte menos el SAC, y sacarle `LIQ_FINAL` al 475x | El más limpio: cada tipo de liquidación con su fórmula, sin tocar lo que hoy cierra en AGUINALDO |
| **(b) extender 6002/6012/6034/8523** a `AGUINALDO\|LIQ_FINAL` | Su fórmula actual es `MIN(BASE_SAC, TOPE_SIPA)/2`, que es la lógica del semestre y no sirve para la final: habría que partirla igual, con lo cual no ahorra nada |
| **(c) arreglar sólo la base del 475x** y dejar la forma del descuento para después de Ganancias | La resta está probada al centavo y es correcta en cualquier escenario; no compromete ninguna decisión |

En cualquiera de los tres hay que **apagar el 475x** cuando el descuento real corre: los dos aportan a
`GAN_NETA_MES` y `GAN_NETA_A_DEDUC`, y Ganancias contaría dos veces.

**Recomendado:** (c) ahora, (a) después. Pendiente de decisión al 11/10/2026.

Jubilación no cierra ni juntando los dos tramos (394.869,45 contra 420.571,03) porque **el tope del
SIPA se aplica por tramo** ([[tope-sac-por-liquidacion]]).

### 5bis. La deducción por ausencias — aplicada el 11/10/2026

El `4703` tenía la **fórmula vacía** desde 2023, con sus ocho fracciones ya cargadas. Ahora calcula:

```
-ROUND((#1003 + #2703) * (30 - DIAS_ALTA_30) / 30, PRECISION_REDONDEO)
```

y se movió del **orden 640 al 29**, porque en 640 llegaba tarde para seis acumuladores. Variable
nueva `DIAS_ALTA_30` (1.0.0.617), por **fase** y no por cobertura. El porqué de las dos decisiones y
los números que las respaldan: [[cobertura-parcial-no-es-ausencia]].

Previsualización sobre los 329 empleados de enero: **deducen 2, los mismos 2 que Meta4**, ninguno de
más ni de menos. **90331 cierra exacto** (−154.106,00). 90448 deduce −470.956,84, que son 141.287,05
menos que Meta4, y la diferencia es su **zona desfavorable** sin pagar: 302.757,97 × 14/30.

Falta recalcular. Y quedan afuera cinco fracciones que el `1003` tiene y el `4703` no:
`BASE_AUSENTISMO`, `BASE_SUELDO`, `BASE_ZONA`, `GAN_NETA_A_DEDUC` y `GAN_NETA_MES`. Las dos de
ganancias importan —sin ellas Ganancias ve el sueldo sin deducir— y se deciden con el punto 6.

### 5ter. La zona desfavorable de 90448 — aplicada el 11/10/2026, falta recalcular

El `2703` tiene la condición `COD_ZONA > 0` y no generaba ni la línea en cero. El valor **estaba
cargado** —atributo `ZONA_DESFAVORABLE` = 69— pero el motor lee `COD_ZONA` y el atributo se publicaba
como `ZONA_DESF`: nadie lo miraba. Detalle, números y el orden de los tres pasos en
[[atributo-cargado-que-nadie-lee]].

Hecho: se borró el atributo de los 197 de enero que no cobran zona en Meta4 (entre ellos los 7 de FA,
los únicos que habrían empezado a cobrar), se corrigieron a 69 los 32 que decían 29 —el 69 es el que
hace cerrar el bruto de los 40 del `2704`— y se renombró a `COD_ZONA`. La previsualización listó **un
solo** afectado: 90448.

**Recalculado el 12/10/2026 y cerró.** Su atributo además estaba **cerrado el 24/1**, el día de la
baja, y la liquidación se referencia al 31/1: era el único de los 90 con la vigencia cerrada. Abierta
la vigencia, el resultado es exacto:

| | BC | Meta4 |
|---|---|---|
| `2703` zona | **302.757,97** | 302.757,97 |
| `4703` deducción | **−612.243,89** | −612.243,89 |
| `3973` vac. no gozadas | **52.478,05** | 52.478,05 |
| `3974` SAC s/ vac. | **4.373,17** | 4.373,17 |
| `4683` | **106.666,67** | 106.666,67 |

Su brecha de bruto pasó de **−193.527,39 a −5.481,05**, y el control dio bien: los 40 del `2704`
conservaron su importe y el total subió exactamente los 73.671,10 del nuevo (1.009.193,22 × 7,30 %).

### 5quater. Lo último de 90448: el `3573` lee la vacación equivocada

De los −5.481,05 que quedan, **5.247,81 son el `3573`** (adicional vacaciones art. 76 CCT 372/04) y
233,24 el SAC.

El `3573` es `round(#3553 * 0.1, …)`, o sea el 10 % de las vacaciones **gozadas**. Meta4 lo paga a
cuatro y BC a tres: el que falta es 90448, y la cuenta es el 10 % de sus **no gozadas**.

| Emp | `AD_VAC_ALIM` M4 | gozadas | no gozadas | BC `3573` |
|---|---|---|---|---|
| 90440 | 74.798,36 | 747.983,63 | 0 | 74.798,36 |
| 90444 | 74.233,22 | 742.332,15 | 0 | 74.233,21 |
| 90447 | 107.537,07 | 1.075.370,69 | 0 | 107.537,07 |
| **90448** | **5.247,81** | **0** | **52.478,05** | **0** |

O sea el adicional es el 10 % de la vacación **que corresponda**, gozada o no. Y 52.478,05 × 0,10 =
5.247,805 → 5.247,81, exacto.

> [!warning] No alcanza con sumar `#3973` a la fórmula: el orden no da
> El `3573` está en el **455** y el `3973` en el **665**. Leído desde el 455, `#3973` devuelve cero.
> Y mover el `3573` después del 665 tiene un costo: aporta a `BASE_PROMEDIO` y `BASE_SAC`, que el
> `3813` lee en el **470**, así que los tres que hoy cobran el adicional perderían esa parte de su
> base de SAC. La salida es un concepto aparte para el adicional sobre no gozadas, con orden
> posterior al 665 — y asumir que, como el `3973` mismo, tampoco llega a la base del SAC.

### 5. 90448 — sin historia de remuneraciones

Ya se le cargó, pero calcula mal: **falta prorratear por los días que efectivamente trabajó en el
mes**. Es el que más lejos está de los ocho: **+731.202,18** de bruto.

Medido el 11/10/2026, y está en un solo renglón: su concepto **`1003 Sueldo` paga 1.271.184,00**,
que es **más que el bruto entero que Meta4 le liquida** (868.473,00). Paga el mes completo.

Y arrastra: su `3813` da **114.759,67** contra **58.542,18** de Meta4 —casi el doble— porque sale de
la misma base sin prorratear. Un solo arreglo cierra las dos cosas, así que no hace falta tocar el
SAC por separado. Sus vacaciones no gozadas (el caso que falta del 13 de 14) salen de la misma base.

### 6. Ganancias — el más grande

El diagnóstico inicial observaba retenciones de BC donde el total mensual de Meta4 era cero.
La revisión directa del 12/10 confirmó que Meta4 devuelve las retenciones anteriores en la final.
Se aplicó `TAB_IMP_4CAT_AN`, deducciones anuales sin prorrateo por mes y devolución permitida,
según art.21b de RG4003. Las ocho finales recalculadas dejan Ganancias total de enero en cero.
Ver [[conciliacion-enero-vigencias-francos-ganancias]].

## Sueltos

- **04382**: novedad del 8893 (17.033,40) fechada el 25/01 contra un alta del 31/01. Corregirla sería
  mover la fecha hacia adelante, que no es lo mismo que arreglar una convención de carga.
- **04706**: sin liquidación en enero pese a la regla nueva de exclusión por persona.
- **Dos bajas en el mismo mes**: `LIQ_FINAL` agrupa por empleado, así que generaría un solo documento
  para dos vínculos.
- **Francos sin lote previo**: quien devengue en su primera liquidación no tiene de dónde sacar el
  sufijo y el precio da cero.
- **El lote de francos se fecha por el documento**, no por el estado que lo devengó. Es el límite para
  que "el devengo cuenta si precede al goce" sea correcto en general.

## Diagnóstico SQL del 11/10/2026 — feriado aplicado y verificado

- **Feriado:** la traza de `1053` incluye días de francos; `BASE_FERIADO` recibe toda esa antigüedad,
  pero `1023` divide por `DIAS_MAREA + DIAS_GP_PERIODO`. La propuesta excluye del promedio sólo la
  porción de antigüedad de francos, sin alterar el haber `1053`. La previsualización de enero cambia
  una sola liquidación y coincide al centavo con el legado. El recálculo posterior ejecutó la nueva fórmula; feriado y SAC del caso afectado coinciden al centavo con Meta4.
- Scripts: `scripts/PrevisualizarFeriadoFinal.sql` (sólo lectura) y
  `scripts/CorregirFeriadoFinal.sql` (por defecto `@Aplicar = 0`; agrega una vigencia nueva del
  `1023` desde enero 2026). Aplicada con autorización del usuario el 11/10/2026; se verificó que la fórmula histórica queda intacta. `TIPO_LIQ` es el **Orden** numérico; se verificó `LIQ_FINAL = 40`.
- **3554 / base del SAC:** en el caso con coeficiente 0,30, la historia importada de Meta4 separa
  `AC_SIND_EXEN_MT` tanto en la corrida de guardia de puerto (`TP_IMPUT = 15`) como en la final
  (`TP_IMPUT = 14`). En la primera coincide con `(1083 + 2043) / 0,30 * 0,70`; en la segunda con
  `1063 / 0,30 * 0,70`, donde el `1063` del legado ya es la parte remunerativa. BC paga el valor
  completo del franco desde el ledger. No alcanza con excluir indemnizaciones del `3554`:
  queda por definir y verificar cómo representar ambas partes sin duplicar el pago ni sus bases.

> [!note] Caché y recálculo verificados
> Se reinició `MicrosoftDynamicsNavServer$BC252` en mimir y se confirmó `Running → Stopped → Running`.
> El recálculo posterior ejecutó la vigencia nueva. Los otros pendientes siguen abiertos.



> [!note] Recálculo verificado el 11/10/2026
> Las 448 líneas de `1023` de enero usan la vigencia nueva. En la final afectada, `Fórmula Aplicada`
> coincide con el texto insertado y `Fórmula Evaluada` confirma la exclusión de la antigüedad de
> francos. El feriado y el SAC coinciden al centavo con Meta4; `1053` conserva su importe.
> Los documentos se recrearon, por lo que se verificó por empleado, período y tipo de liquidación,
> no por el número antiguo. No se verificaron aún los restantes descuentos ni Ganancias.










## Orden de cálculo simplificado — 12/10/2026

El orden alternativo se configura ahora con un único campo Fórmula Orden Cálculo.
Los tres campos publicados antes quedan obsoletos y fuera de la ficha, con compatibilidad
para sus valores. Configuración y código preparados; falta publicación del campo nuevo.
Ver [[final-vacaciones-sac-descuentos-coordinados]].


## Diseño de francos y orden preparado (2026-10-12)

- Un único **Orden de cálculo** visible, constante o fórmula; actualización de datos por Upgrade.
- Cuenta corriente inmutable y matriz por lote, selección compartida entre componentes y contramovimientos al recalcular/reabrir/eliminar. También integrado con saldo inicial.
- Ver [[Cuenta corriente y matriz de francos]]. Requiere publicación completa, ejecutar pruebas y reconstruir primero un empleado de control. No se activaron cuentas ni se cambió configuración SQL de conceptos en esta intervención. La conversión de fórmulas debe hacerse en nuevas vigencias, conservando días y fracciones de SAC.

## Verificación de cuenta corriente (2026-10-12)

Versión **1.0.0.627** publicada. Tres pruebas AL ejecutadas con rollback y un empleado de control inicializado; reapertura y recálculo verificados con el mismo saldo e importes. El resto de enero no se volvió a recalcular en esta intervención. La conversión de conceptos a Fuente Matriz queda pendiente; ver [[Cuenta corriente y matriz de francos]].


## Matriz de francos aplicada (2026-10-12)

Versión **1.0.0.629** publicada. Nueva vigencia del 1063 desde 04/01/2026, selección de días preservada y fórmula de pesos por lote. Se reconstruyeron las cuentas de enero y se recalcularon 41 documentos alcanzados, incluidas las ocho finales. Huellas de cantidades, importes, bases y totales de todo enero idénticas a las anteriores; SAC y 3554 no cambiaron. 39 aplicaciones de lote revisadas, sin duplicados ni líneas sin lote. Seis tests AL pasaron con rollback, incluida eliminación de un documento. Ver [[Cuenta corriente y matriz de francos]].

Esto cierra la conversión y reversibilidad de los consumos configurados de francos. Los restantes pendientes económicos enumerados arriba no fueron modificados por este cambio.

## Estado económico actualizado — 12/10/2026

Los estados «preparado», «falta publicar» y «no aplicado» de las secciones históricas anteriores
describen esas intervenciones; este apartado registra el estado posterior.

- Aplicado `CorregirPendientesFinalOct12.sql`: 3573, SAC remunerativo/NR, descuentos reales de SAC,
  reintegros por tope y exclusión de descuentos ficticios de devengo en la final. Ocho finales
  recalculadas; las bases principales de los dos casos pendientes de SAC coinciden con Meta4.
- Publicada **1.0.0.633**, servicio reiniciado y configuración SQL releída.
- Corregidos precio de franco de Merluza y acuerdo OF02 mediante nuevas vigencias. Días y
  fracciones del 1063 conservados; precio por PESQ_FRANCO separado de otros haberes.
- Aporte solidario FTIA implementado en el 8573 existente; ambos casos de enero verificados.
- Ganancias final anual y devolución verificadas: total de enero en cero para los ocho casos.
- Antigüedad: revisión directa de la fórmula de Meta4 confirma la regla de BC; no se redujeron
  años para copiar un porcentaje discordante de la corrida histórica.
- Resuelta la diferencia principal de grossing-up: faltaban capacitación y solidaridad en
  el SAC sindical virtual para Ganancias. Rehechos los meses completos de los empleados
  alcanzados para conservar los topes; ocho pruebas con rollback pasaron.
- Persisten residuos menores de redondeo del comparativo; no se cargaron ajustes arbitrarios.
  La diferencia de antigüedad queda identificada como discordancia de la corrida del legado,
  no como una corrección pendiente de la fórmula general de BC.

Detalle, scripts, mantenimiento del nuevo atributo de buque y límites de validación:
[[conciliacion-enero-vigencias-francos-ganancias]].

## 13. Reapertura y vigencias uniformes de enero — 12/10/2026

Publicada 1.0.0.635: Revertir Calculadas resuelve los consumos del período antes de los lotes
que los originaron, y conserva el bloqueo de consumidores externos. Nueve pruebas con rollback
aprobadas. Por instrucción del usuario, las correcciones finales de conceptos y fracciones
se consolidan desde 01/01/2026, cerrando las versiones anteriores al 31/12/2025.
Ver [[reapertura-periodo-dependencias-francos]] para respaldo y procedimiento.


Aplicado: 293 conceptos y 1.276 fracciones consolidadas desde 01/01; 570 liquidaciones de enero
en Borrador, movimientos compensados y servicio reiniciado. Pendiente el recálculo de enero
por el usuario y la nueva conciliación de resultados.


## 14. Antigüedad unificada y reapertura del árbol

Publicada 1.0.0.637. Árbol/lista y Revertir Calculadas del período comparten el recorrido por
dependencias, respetando el alcance seleccionado. La corrección anterior sólo cubría el
período y por eso el árbol seguía fallando. Las diez pruebas con rollback pasaron.
El 1055 se unifica en el 1053 desde enero, conservando reglas y distribuciones por convenio.
No se cambia el porcentaje para copiar la discordancia de la corrida histórica de Meta4.
Ver [[antiguedad-unificada-1053-por-convenio]] y [[reapertura-periodo-dependencias-francos]].


Aplicado mediante AL: 1053 unificado desde 01/01/2026, 1055 histórico hasta 31/12/2025; referencias
y distribuciones actualizadas. Enero completo en Borrador para recalcular. Verificación SQL:
sin referencias al 1055 en líneas de enero ni fórmulas actuales, y sin consumos activos del período.

