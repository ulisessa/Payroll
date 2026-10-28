---
tags: [lección, sac, liquidación-final, convenio]
fecha: 2026-10-11
---

# El SAC de egreso es la doceava parte, no la mejor remuneración sobre dos

```
SAC egreso = remuneraciones del semestre en curso / 12 * coeficiente de pesquería
```

Art. 121 LCT literal. **No** es "la mitad de la mayor remuneración mensual por una proporción de
días", que es lo que uno espera del art. 122 y es lo que yo asumí primero: con esa hipótesis hacía
falta una remuneración de ~7,68 M para 04190 y ninguna columna se le acercaba.

La cuenta sale de `TOT_PROMEDIOS` de Meta4 y cierra al centavo en seis de siete egresados de enero
de 2026:

```
(111.633,19 + 6.299.341,22 + 239.479,66) / 12 = 554.204,51
7.678.433,99 / 12 = 639.869,50
```

## La base es la misma que la de vacaciones, con otra ventana

`BASE_PROMEDIO`. Lo que cambia es qué se mira:

| | Ventana |
|---|---|
| **SAC** | el **semestre en curso** (desde el 1/1 o el 1/7) |
| **Vacaciones** | los **seis meses anteriores** |

En un egresado de enero cuya fase también arranca en enero, las dos coinciden —04807 da 7.678.433,99
en ambas— y eso confunde: parecen la misma cuenta y son dos ventanas distintas.

Las dos se recortan al alta de la fase vigente, por lo mismo que
[[ventana-promedio-vacaciones-corta-en-la-fase]].

## El coeficiente de pesquería SÍ va acá y NO en vacaciones no gozadas

Dos decisiones opuestas sobre el mismo factor, las dos verificadas contra **04925**, el único de los
ocho con coeficiente distinto de 1:

- SAC: `105.563,55 * 0,3 = 31.669,07`, su importe exacto en Meta4.
- Vacaciones no gozadas: sin el coeficiente. Con él pagaba `59.534,84` en lugar de `198.449,46`.

Un solo caso con el coeficiente distinto alcanzó para delatar las dos. Sin él, los otros siete dan
igual con el factor o sin él, y el error habría viajado invisible: en una flota de tangoneros habría
recortado el 70% de cada indemnización de vacaciones.

## Por qué la fórmula suma #BASE_PROMEDIO

La variable `BASE_SAC_SEMESTRE` no puede ver la liquidación en curso
([[variables-sistema-se-precalculan]]), así que la fórmula le suma el acumulador:

```
ROUND((BASE_SAC_SEMESTRE + #BASE_PROMEDIO) / 12 * #COEF_PESQUERIA, PRECISION_REDONDEO)
```

## El concepto NO se mueve de orden

A diferencia del 3973 —que hubo que correr al 665 para que `#BASE_PROMEDIO` estuviera completo— el
3813 se queda en 470: moverlo lo sacaría de la base de 2013 (551), 2003 (650) y 4905 (670), que hoy
lo leen. Se verificó que en el orden 470 el acumulador **ya está completo** para las ocho finales, y
eso quedó como guarda del script.

## Los descuentos sobre el SAC

Meta4 los desglosa (4751, 6002, 6012, 6034, 8523) y BC los cobra dentro de los conceptos
principales, porque el 3813 aporta a `BASE_SS_TRAB`, `BASE_OS_TRAB` y `BASE_SINDICAL`. Sumando los
dos de Meta4 da casi lo mismo que BC junto —el sindical difiere en 115,17— pero **jubilación no
cierra** (394.869,45 contra 420.571,03): el tope del SIPA se aplica por tramo y juntarlos lo
distorsiona.

Para desglosar alcanza con quitar esas tres fracciones del 3813 y que los conceptos del SAC lean
`#3813`. **No hace falta un acumulador nuevo**: fue mi primera propuesta y era innecesaria.
