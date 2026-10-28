---
aliases: ["Días sumados donde van pesos"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-04
---

# Días sumados donde van pesos

El 1603 sumaba #DIAS_ART48 —cuatro días— dentro de una base en pesos; y por qué un control por empleado miente cuando hay más de una liquidación en el mes

La base del **1603 Categoría superior** era
`#1013 + #1083 + #1543 + #1053 + #1547 + #DIAS_ART48`. Los cinco primeros son importes; el último es
un concepto que devuelve **días**. Para el legajo 01642 la base quedaba en `7.119,46 + 4` en vez de
`7.119,46 + 28.477,84`, y el concepto pagaba **474,90** contra **2.373,15** de Meta4.

El importe del artículo 48 lo paga el **1076**; `DIAS_ART48` (orden 62) sólo cuenta los días de
órdenes en veda. Corregido el 29/9/2026 reemplazando `#DIAS_ART48` por `#1076`. `DIAS_ART48` sigue
existiendo y lo usan otras dos fórmulas.

**Por qué:** sumar 4 a una cifra en pesos no rompe nada, no avisa y deja un número más chico y creíble.
Sólo se ve cuando el resto de la base da casi cero —acá el empleado cobró **sólo** artículo 48, sin
sueldo de navegación—, así que aparece en un puñado de casos y parece puntual.

**Cómo aplicarlo:** ante una fórmula que mezcla conceptos, mirar si alguno devuelve días en vez de
pesos; el nombre lo delata cuando empieza con DIAS_. El detalle de variables de la línea
(`Detalle Variable Línea Liq.`) muestra el valor con que entró cada término y lo hace obvio.

**Y una trampa de medición que me hizo descartar el arreglo:** el primer control agrupaba las
variables **por empleado** y el importe con `MAX`. Los empleados con dos liquidaciones en el mes —muy
común acá— quedaban con las variables de una línea y el importe de otra, y el control informó que el
cambio rompía 6 casos que en realidad no tocaba. Un control sobre líneas de liquidación se agrupa
**por línea**, nunca por empleado. Relacionado: [[previsualizar-antes-de-migrar]],
[[control-precedencia-formulas]].

## Relacionado

- [[previsualizar-antes-de-migrar]]
- [[control-precedencia-formulas]]
- [[a-cuenta-futuros-aumentos-puerto]]
- [[adicional-art-23-vs-art-33]]
- [[adicional-tareas-mecanicas]]
