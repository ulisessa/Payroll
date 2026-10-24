---
tags: [lección, vacaciones, promedios, convenio, liquidación-final]
fecha: 2026-10-10
---

# La ventana del promedio de vacaciones corta en el alta de la fase

El art. 49 del CCT lo dice textual, y es la frase que decide todo:

> Se sumarán las remuneraciones sujetas a retenciones previsionales correspondientes a los seis meses
> anteriores a aquel en que comience a gozar sus vacaciones, **o la fracción menor de prestación de
> servicios que corresponda**.

En una dotación de **temporada** —altas y bajas varias veces al año: 04190 tiene doce fases desde
2015, 03964 tiene quince— los seis meses calendario se meten en la **fase anterior**, que es otra
relación laboral y otro sueldo. Hay que recortar la ventana al alta de la fase vigente.

## El caso que lo mostró

04807: alta el **1/1/2026**, baja el **28/1/2026**. Sin recorte, su promedio salía de agosto,
septiembre y octubre de **2025** —meses de su fase anterior— y el día de vacaciones daba 63.699,89
contra los 329.075,74 del recibo de Meta4: **cinco veces menos**.

Con el recorte, la ventana es enero de 2026, su única fracción de prestación.

## Y cuando la fracción es el mes en curso, hay que sumar la liquidación en curso

`SUMA_REM_VAC` lee **líneas ya guardadas**. En el caso normal está bien —la ventana son los seis
meses *anteriores* y el mes actual no va— pero si la fracción ES este mes, la base se queda sólo con
lo que otra liquidación del mes alcanzó a grabar.

A 04807 le tomaba los 7.332.902,72 del cierre de marea pero no los 345.531,27 de su propia final
—sueldo de franco, de puerto y de feriado—. De ahí la variable `VENT_PROM_ES_MES_ACTUAL`, que vale 1
sólo en esa rama, y la fórmula suma `#BASE_PROMEDIO` cuando corresponde. Es una bandera y no la suma
misma porque el valor en curso sólo lo tiene el evaluador.

Se verificó que no hay circularidad: los cuatro conceptos de no gozados **no** aportan a
`BASE_PROMEDIO`, y todos los que sí aportan corren antes del orden 555.

## Numerador y divisor, de una sola fuente

La ventana estaba escrita **dos veces** —en `ApplyTokens` para `{PROM_DESDE}..{PROM_HASTA}` y en
`CalcMesesPromedioVacaciones`— y el propio código ya advertía del riesgo: si se separan, se divide la
suma de un semestre por la cantidad de meses de otro. Ahora las dos salen de
`VentanaPromedioVacaciones`, y el contador recorre la ventana real en vez de seis meses fijos.

El tope de seis se cumple solo: la ventana nace de seis meses y sólo se achica.

## Dos regímenes, no uno

**El art. 49 aplica únicamente a tripulantes.** Para el personal de tierra rige la LCT. De los ocho
egresados de enero de 2026, seis son tripulantes y dos (03964 y 90448) son de tierra — se los
distingue por tener o no movimientos de franco.

La regla de los **días** también cambia: el art. 49 da 14/21/28/35 según antigüedad al 31/12, pero
**sólo con 181 días corridos de prestación**; por debajo, **un día cada veinte**. No es la fórmula de
la provisión (`días × art.150 / 360`), que es otra cosa — ver
[[devengados-no-gozados-pagaban-cero]].

## Lo que quedó abierto

Con `días de fase / 20` truncado cierran tres de los seis tripulantes (04807, 04889, 04925). De los
otros, **04775 y 04900 necesitan menos** días que los de su fase —compatible con contar días
embarcados y no días de alta— pero **04190 necesita más de los que tiene su fase vigente**, y eso
ninguna resta lo explica: su fase anterior (30/12/2024 al 13/5/2025) tiene 135 días, que darían
exactamente los 6 que pagó Meta4. Puede que le esté liquidando el año de vacaciones **2025**.

Falta definir, para un tripulante de temporada con varias fases al año, si los días corridos de
prestación se cuentan sobre la fase vigente, sobre el año calendario sumando fases, o si cada año de
vacaciones toma su propia fase.
