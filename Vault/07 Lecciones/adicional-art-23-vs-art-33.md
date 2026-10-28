---
aliases: ["Adicional art. 23 vs art. 33"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-04
---

# Adicional art. 23 vs art. 33

1533 y 1543 son el mismo 60% del sueldo de navegación; el artículo lo decide el convenio, oficiales art. 23 y marinería art. 33

El adicional por artículo es **60% del sueldo de navegación para todos**; lo único que cambia
es el artículo, y lo decide el convenio:

- **Oficiales (175/75 y 768/19)** → **1533 `ADIC_ART_23`**
- **Marinería (729/15)** → **1543 `ADIC_ART_33`**

Sin excepciones en enero 2026: 13 oficiales con art. 23 y 83 marineros con art. 33, y el
porcentaje implícito sobre `SUELDO_NAVEG` da 0,6000 en los diez pares convenio+categoría.

BC les pagaba a los seis oficiales de 175/75 (4 OF02 + 2 OF04, 2.803.500 en enero) por 1543
en vez de 1533, por dos errores que se tapaban entre sí: 1543 tenía el 175/75 en su lista de
CCT, y `PCT_ADIC_ART23` sólo tenía vigencias para 768/19, así que 1533 resolvía a cero en
silencio (ver [[get-con-menos-argumentos]] sobre parámetros que faltan y no avisan). Los de
768/19 ya estaban bien, y el importe total no cambiaba: cambiaba de concepto.

**Por qué:** el síntoma no era una diferencia de plata sino una fila "Sólo Meta4 / 1533" y otra
"Sólo BC / 1543" por el mismo importe en el comparador. Dos conceptos que se tapan uno al
otro no mueven ningún total, así que el control de importes no los ve.

**Cómo aplicarlo:** ojo con las unidades, que conviven las dos — 1533 hace
`PCT_ADIC_ART23 / 100` y 1543 multiplica `PCT_33` directo, así que las vigencias del primero
van en 60 y las del segundo en 0,60. `PCT_33` además es el Nombre Variable del parámetro
`PCT_ADIC_ART_33`, que es global y no lleva sufijos. Mismo patrón de reparto por convenio que
[[sueldo-ordenes-por-convenio]].

## Relacionado

- [[get-con-menos-argumentos]]
- [[sueldo-ordenes-por-convenio]]
- [[a-cuenta-futuros-aumentos-puerto]]
- [[adicional-tareas-mecanicas]]
- [[anticipo-no-es-haber-del-recibo]]
