---
aliases: ["Antigüedad: fórmula explícita"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-04
---

# Antigüedad: fórmula explícita

La antigüedad es PRECIO_NAV/30 × pct × días × coeficiente para todos; pasaba por BASE_SUELDO en marinería y el franco, que vale 2,4 básicos, la inflaba 2,4 veces

La antigüedad se calcula igual para las dos familias:

```
PRECIO_NAV / 30 * pct/100 * (DIAS_PROYECTO + DIAS_PUERTO + DIAS_GP_PERIODO
                             + DIAS_FRANCOS_PERIODO + DIAS_ORD_PERIODO) * coeficiente
```

El coeficiente es el **30% del Dto 633/18**, no la pesquería, aunque el parámetro se llame
`COEF_TANGONERO`/`COEF_POTERO` — el nombre induce a error. El 1013 Sueldo de navegación ya lo
multiplica, así que la base remunerativa viene al 30%.

La rama de oficiales ya lo hacía así; la de marinería calculaba `BASE_SUELDO × pct`, y `BASE_SUELDO`
arrastra el **1063 Sueldo de franco**, que vale **2,4 básicos**. La antigüedad de quien cobraba
francos salía 2,4 veces de más: el 01937, 132.421,93 contra 55.175,82 de Meta4. Unificadas el
29/9/2026 con `IFZERO(#PCT_ANTIG_OFICIALES, #PCT_ANTIG_SOMU)`, que era lo único que las distinguía.
`BASE_SUELDO` quedó sin consumidores.

Los días de artículo 48 quedan cubiertos: `DIAS_ART48 = MIN(DIAS_ORD_PERIODO, DIAS_VEDA_BUQUE)`, o sea
un subconjunto de `DIAS_ORD_PERIODO`.

**Por qué:** un error en la antigüedad no se queda ahí. En el 01937 explicaba **todo** el desvío del
recibo —aportes, acuerdo 3554 y SAC devengado—, porque todos salen de una base que la incluye.

**Cómo aplicarlo:** ante varios conceptos desviados en la misma proporción, buscar el que está aguas
arriba. Y cuidado al medir: un control sobre líneas de liquidación se agrupa **por línea**, y la
categoría se toma **de la línea del concepto**, nunca con `MAX` sobre la liquidación — los francos
llevan la categoría del lote, no la del empleado, y eso me dio dos conclusiones falsas seguidas.
Quedan 43 empleados sin francos cuya antigüedad tampoco cierra: frente aparte. Relacionado:
[[valor-franco-por-terna]], [[antiguedad-suma-de-fases]].

## Relacionado

- [[valor-franco-por-terna]]
- [[antiguedad-suma-de-fases]]
- [[a-cuenta-futuros-aumentos-puerto]]
- [[adicional-art-23-vs-art-33]]
- [[adicional-tareas-mecanicas]]
