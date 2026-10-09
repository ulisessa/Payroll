---
aliases: ["Concepto que corre después de sus consumidores"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-04
---

# Concepto que corre después de sus consumidores

Un concepto que alimenta acumuladores debe correr antes que todo lo que los lee; se mueve el productor, no el consumidor

Si un concepto **alimenta** acumuladores y corre DESPUÉS de los conceptos que los
**leen**, esos leen una base incompleta y nadie avisa. El 17/9/2026: la Absorción
art. 36 (4415, negativa, −724.890) corría en el orden 480, veinte lugares después
de los cuatro de SAC devengado (4750-4753, órdenes 460-462), que leen los mismos
`BASE_IG4`, `BASE_SS_TRAB`, `BASE_OS_TRAB` y `BASE_SAC`. Corregido moviendo 4415
al **412**.

**Por qué:** tres cosas que no eran obvias y valen para la próxima.

1. **Se mueve el productor hacia atrás, no el consumidor hacia adelante.** Entre
   460 y 480 están los conceptos de aguinaldo (3613 en 459, 3623 en 465) que
   alimentan los mismos acumuladores: correr el devengado hacia adelante lo haría
   provisionar aguinaldo sobre aguinaldo. No había ningún hueco que evitara las
   dos cosas.
2. **El destino lo fija la fórmula del concepto movido.** 4415 es
   `IF(TIPOACTIVIDAD = 1, -(#4423 + #4433), -BASE_ABS_SOMU)`, y sus entradas están
   en los órdenes 405, 410, 15 y 154 — así que el primer orden válido era el 411.
3. **Un `MIN(base, TOPE)` puede tapar el error.** De los cuatro consumidores sólo
   4750 cambió de resultado: los otros tres topean contra `TOPE_SIPA` y la base
   estaba muy por encima, así que restarle 724.890 no movió el `MIN`. Con un sueldo
   más bajo los tres habrían estado mal también.

**Cómo aplicarlo:** antes de mover un orden, listar (a) qué acumuladores alimenta el
concepto, (b) qué conceptos leen esos acumuladores y en qué orden, y (c) qué lee el
concepto que se mueve, para saber cuál es el primer orden válido. Las tres salen de
`Fracción Acumulador` cruzada con `Concepto Liquidación`. Ver
[[acumuladores-orden-calculo]] y [[ventana-liquidacion-es-cobertura]].

## Relacionado

- [[acumuladores-orden-calculo]]
- [[ventana-liquidacion-es-cobertura]]
- [[cobertura-devengado-tapa-dias]]
- [[cobertura-en-tramos]]
- [[conceptos-tres-vigencias]]
