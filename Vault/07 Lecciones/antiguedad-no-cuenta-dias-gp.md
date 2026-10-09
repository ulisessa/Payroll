---
aliases: ["La antigüedad no cuenta los días de GP"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-04
---

# La antigüedad no cuenta los días de GP

La fórmula de 1053 no suma DIAS_GP_PERIODO, así que un oficial de guardia de puerto cobra antigüedad cero

**1053 suma `DIAS_PROYECTO + DIAS_PUERTO + DIAS_FRANCOS_PERIODO + DIAS_ORD_PERIODO` y deja afuera
`DIAS_GP_PERIODO`.** El 1083, que paga el sueldo de esos mismos días, sí lo suma:
`(DIAS_PUERTO + DIAS_GP_PERIODO) × precio / 30`.

El testigo es el **legajo 00794** en enero de 2026: 31 días de guardia de puerto, `DIAS_PUERTO = 0` y
`DIAS_GP_PERIODO = 31`. La fórmula evaluada que quedó en la línea lo muestra crudo:

    900000 / 30 * 25 / 100 * ( 0 + 0 + 0 + 0 )   ->  0,00

Meta4 le paga **232.500,00** = 900.000 / 30 × 31 × 25%, contando esos 31 días como puerto
(`DIAS_PUERTO = 31`, `SUELDO_PUERTO = 1.860.000` a 60.000 el día).

**El importe sale en cero sin ningún error**, que es el patrón de
[[acumuladores-orden-calculo]]: el concepto corre, la fórmula es válida, y lo que falta es un
término. Los precios y el porcentaje están bien —`PRECIO_NAV` 900.000 y
`#PCT_ANTIG_OFICIALES` 25 son los de Meta4, ver [[lista-precios-oficiales]]—; lo único que falla es
el conjunto de días.

**Corregido el 28/9/2026** (`f1053_dias_gp.sql`): el término se agregó a las dos ramas de oficiales.
No puede romper lo que ya cuadraba porque de los 20 oficiales con línea de 1083 en enero **el único
con días de GP es el 00794**, y los 16 de 17 que ya coincidían no se mueven.

**La rama de marinería no hizo falta tocarla**: usa `BASE_SUELDO`, que incluye 1083, y 1083 ya cuenta
los días de GP, así que ahí el término llega solo.

## Relacionado

- [[acumuladores-orden-calculo]]
- [[lista-precios-oficiales]]
- [[a-cuenta-futuros-aumentos-puerto]]
- [[adicional-art-23-vs-art-33]]
- [[adicional-tareas-mecanicas]]
