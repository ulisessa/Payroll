---
aliases: ["Control de precedencia de fórmulas"]
tipo: leccion
tema: controles-auditoria
tags: [leccion, controles-auditoria, project]
actualizado: 2026-10-04
---

# Control de precedencia de fórmulas

Control estático de dependencias de conceptos y acumuladores.

> [!important] Aclaración del 14/10/2026
> `#` lee un resultado ya calculado y depende del orden. `@` reevalúa la fórmula: no necesita que
> el concepto referenciado haya corrido, aunque hereda las dependencias de sus acumuladores y
> referencias `#`. El diagnóstico histórico siguiente no debe interpretarse como una regla de
> precedencia de `@`. La acción actual se documenta en [[Orden de cálculo y precedencia]].

Una fórmula que lee `#XXXX` o `@XXXX` de un concepto que se calcula **después** obtiene **cero**, sin
error y sin rastro — el patrón de [[concepto-negativo-despues-de-sus-consumidores]] y de
[[acumuladores-orden-calculo]]. Es barato detectarlo de forma estática: extraer las referencias de
todas las fórmulas y comparar `Orden Cálculo`. El script es `precedencia.sql`.

Corrido el 28/9/2026: **90 referencias en total, 4 mal ordenadas.**

    1534 Premio adicional especial (orden 159)  ->  #1023 Sueldo de feriado (450)
    2103 Presentismo Comercio      (orden  45)  ->  #1053 Antigüedad Tripulación (100)
    2103 Presentismo Comercio      (orden  45)  ->  #1054 Antigüedad mensuales (50)
    PROD_EMPRESA                   (orden   0)  ->  @ADIC_PROD_PESCA (0)   mismo orden, ambiguo

Las tres primeras leen cero hoy. La cuarta depende del desempate dentro del mismo orden.

Aparte, dos fórmulas —3553 y 4743— referencian `#4573`, que **no es un concepto con fórmula**: se
alimenta por novedad. Ahí el orden también importa, pero el control no puede decidirlo solo.

## Al mover un concepto de orden, mirar a los dos lados

Mover un concepto para que pueda leer a otro lo acerca a sus propios consumidores. Antes de mover
hay que ver quién lo lee: por ejemplo 2073 corre en 195 y podría moverse para leer al 2013 (551),
pero **2003 lee `#2073` y corre en 650**, así que la ventana es 552–649.

**Y leer un concepto calculado no siempre devuelve lo que la fórmula calculó**: si ese concepto vino
de una **novedad**, `#` devuelve el importe de la novedad, porque el motor da precedencia a la
incidencia y saltea la fórmula — ver [[novedad-con-proyecto-queda-huerfana]]. Reconstruir una base a
partir de `#2013 + #1083 + #1023 + #1053` funciona sólo si 2013 se calculó; con novedad da otra cosa.
Por eso a veces conviene repetir la expresión en vez de leer el resultado, o sacarla a un concepto
intermedio que los dos lean.

## Relacionado

- [[concepto-negativo-despues-de-sus-consumidores]]
- [[acumuladores-orden-calculo]]
- [[novedad-con-proyecto-queda-huerfana]]
- [[comparar-columna-contra-total]]
- [[grossing-up-tapa-errores]]

## El 1534 seguía leyendo #1023 antes de que se calculara (16/10/2026)

El control del 28/9 había listado `1534 (159) -> #1023 (450)` y quedó. El 1023 después pasó de 450 a **470** y la rama del 1534 que restaba el feriado quedó en el **451**: siempre leyó cero. En el devengado del 13 al 28/2 de 04724 el premio absorbía el feriado (1534 +142.318, 2003 −140.320 contra Meta4, bruto +1.997). El orden del 1534 pasó a `IF(APLICA_PROD_FIJO > 0 AND TIPOACTIVIDAD = 1 AND PCT_PROD_CAPECA > 0, 471, 159)` (`scripts/Orden1534DespuesDel1023.sql`, vigencia 2026-02-04): 471 es justo después del 1023, y sin la guarda del grossing-up porque la rama con `#1023` también les aplica. **Pendiente:** la rama tangonero (`TIPOACTIVIDAD <> 1`) también lee `#1023` y sigue en 159; sin verificar contra Meta4. Las fracciones del 1534 no necesitaron copia: el motor toma la vigencia de fracciones más reciente a la fecha (01/01, 01/02 y 02/02 existen; no hay de 03/02).
