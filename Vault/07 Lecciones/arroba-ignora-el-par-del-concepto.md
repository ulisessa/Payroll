---
aliases: ["@ ignora el par del concepto"]
tipo: leccion
tema: formulas-evaluador
tags: [leccion, formulas-evaluador, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-18
---

# @ ignora el par del concepto

@CÓDIGO re-evalúa con el par del concepto que llama, no con el del concepto referenciado; para respetar su Convenio/Categoría a usar hay que leerlo con #

`@CÓDIGO` re-evalúa la fórmula del otro concepto **en el contexto actual**, y el par CCT es parte
de ese contexto: su `Convenio/Categoría a usar` se ignora. `#CÓDIGO` lee el Importe ya calculado
de la línea, que sí se armó con el par propio del concepto.

**Por qué:** visto el 18/9/2026 en el legajo 04649, marea A28/59 (LIQ-00006182). PROD_EMPRESA está
declarado con "El puesto del empleado" y su línea salió con el par (ESP, FE01) — `PCT_PROD` = 4 y
`USD_MAREA` = 7000 — dando 46.571.665,92. El concepto 2003, que corre con el par de la cabecera
(768/19, OF01), lo leía con `@PROD_EMPRESA` y obtuvo 32.098.728,96: la misma fórmula recalculada
con `PCT_PROD` = 2 y `USD_MAREA` = 6900. No hay error ni aviso; el importe simplemente sale de
otro par. Para colmo el Detalle Variable de la línea registra `@PROD_EMPRESA` con el importe de la
línea (46.571.665,92), así que mirando ahí parece correcto y sólo la aritmética lo delata.

**Cómo aplicarlo:** si el concepto referenciado tiene un `Convenio/Categoría a usar` distinto del que
lo llama, la referencia va con `#` y su Orden Cálculo tiene que ser menor. `@` sirve cuando los dos
comparten el par, o cuando querés justamente que el referenciado se evalúe con el par del llamador
— que es el caso de `@ADIC_PROD_PESCA` dentro de PROD_EMPRESA, donde el arroba juega a favor.

Ver [[conceptos-tres-vigencias]], [[puesto-vs-categoria-cct]] y
[[concepto-negativo-despues-de-sus-consumidores]] para la trampa del orden con `#`.

## Relacionado

- [[conceptos-tres-vigencias]]
- [[puesto-vs-categoria-cct]]
- [[concepto-negativo-despues-de-sus-consumidores]]
- [[atributo-comparar-por-codigo]]
