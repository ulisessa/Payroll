---
aliases: ["La producción no se prorratea"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-04
---

# La producción no se prorratea

**En una frase:** PROD_KN_MAREA es de la marea entera aunque la marea no haya cerrado; el garantizado sí se prorratea por DIAS_MAREA, y mezclarlos con MAX() paga de más

En una fórmula de producción conviven dos magnitudes con escalas distintas:

- `PROD_KN_MAREA` son los kilos de **toda la marea**, estén o no cerrados. Para la marea 60, en
  enero de 2026 y con el buque todavía navegando, BC ya devolvía 574.563.
- El garantizado (`USD_MAREA * TC_COMPRADOR / 30 * DIAS_MAREA`) sí está **prorrateado** por los
  días que el empleado hizo en el período.

En un `CIERRE_MAREA` las dos coinciden en alcance y se pueden comparar. En un `DEVENGADOS` a mitad
de marea no: el 01477 embarcó el 29/1 y con 3 días le tocaba un garantizado de 976.350, pero la
producción de la marea entera daba 12.878.025 y un `MAX()` entre ambas le pagó 12.242.866,92 de
premio.

**Por qué:** el síntoma no es un error sino un importe enorme y plausible, y el concepto que lo produce
no avisa nada. Sólo se ve comparando contra el garantizado del mismo empleado.

**Cómo aplicarlo:** antes de poner producción y garantizado en un mismo `MAX()` o `MIN()`, verificar
que las dos estén prorrateadas por el mismo denominador. Si la liquidación no es un cierre, la
producción no es comparable y hay que ir sólo por el garantizado — ver
[[tipo-liq-no-implementada]] para el discriminador que hace falta. El detalle por línea
(`Detalle Variable Línea Liq.`) muestra el valor exacto que tomó cada variable y es la forma más
rápida de confirmarlo. Relacionado: [[produccion-oficiales-poteros]],
[[a-cuenta-futuros-aumentos-puerto]].

## Relacionado

- [[oficiales-netos-al-70]]
- [[precio-puerto-lista-inconsistente]]
- [[produccion-oficiales-poteros]]
- [[que-tc-usa-cada-concepto]]
- [[tc-de-marea-no-es-cotizacion]]
- Tema: `conceptos-haberes` (ver [[_Convenciones del vault]])
