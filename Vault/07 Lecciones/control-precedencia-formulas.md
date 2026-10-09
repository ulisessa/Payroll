---
aliases: ["Control de precedencia de fórmulas"]
tipo: leccion
tema: controles-auditoria
tags: [leccion, controles-auditoria, project]
actualizado: 2026-10-04
---

# Control de precedencia de fórmulas

Control estático que detecta fórmulas que referencian con # o @ un concepto de orden de cálculo mayor, que leen cero sin dar error

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
