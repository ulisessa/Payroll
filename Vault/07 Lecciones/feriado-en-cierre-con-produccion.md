---
aliases: ["El feriado del cierre con producción"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-14
---

# El feriado del cierre con producción

> [!note] Resuelto por parametrización el 14/10/2026. La producción va aparte en el 1023, dividida por los días de la marea entera.

En enero Meta4 no pagó `SUELDO_DIA_FDO` en los cierres de marea. En febrero sí (carnaval, dos días) y pagó entre 4 y 9 veces lo que daba BC (24 M de diferencia en 50 tripulantes de 729/15).

**Definición de Meta4** (dada por el usuario): `PR_DIA_FERIADO` = (sueldo de navegación, puerto, dique y pilotaje + categoría superior + adicionales de los artículos 23 y 33 + antigüedad + bodega + **producción SOMU** + absorción) / días; `SUELDO_DIA_FDO` = `PR_DIA_FERIADO` × `DIAS_FERIADO`.

**Lo que se midió en los 60 cierres de febrero que pagan feriado:**

- Los oficiales y ESP ya cerraban exactos: `BASE_FERIADO / DIAS_MAREA`, sin producción.
- En los marineros **el sueldo se divide por los días liquidados y la producción por los días de la marea entera** (`DIAS_NAV_MAREA` + `DIAS_PTO_MAREA` de Meta4, que es `DIAS_ENROLAMIENTO` en BC: 19, 20 o 21 según el buque). La producción es de toda la marea aunque el cierre sólo liquide el tramo de febrero. Por eso sumar `2498` al acumulador y dividir todo por `DIAS_MAREA` sobraba 7% en promedio y 15% en los cierres de 16 días.
- `HORAS_50/100` (4423, 4433) y la absorción 4415 ya están los tres en `BASE_FERIADO` y se anulan entre sí (la absorción es igual y de signo contrario a las horas). La composición del acumulador no necesitaba cambios.
- El residuo que queda (–0,24% típico, máximo –0,53%) es que Meta4 pesa el día de puerto en la producción a unos 0,973 del de navegación. No hay variable en BC para eso.

**Cómo quedó:** el 1023 tiene una vigencia nueva desde 2026-02-03 (la 2026-02-02 se cerró ese mismo día) con el término `+ IF(DIAS_ENROLAMIENTO > 0, #2498 / DIAS_ENROLAMIENTO, 0)` dentro del redondeo de la rama general. Script: `scripts/FeriadoCierreConProduccion.sql`. Resultado medido a mano: BC 3,94 M → 27,81 M contra Meta4 27,85 M; los 60 dentro del 1%.

Enero no cambia (la vigencia nueva no alcanza ninguna fecha de enero) y el 1023 de DEVENGADOS, REGULAR y LIQ_FINAL tampoco: `2498` sólo existe en las liquidaciones de cierre.

**Trampa evitada:** el valor de `BASE_FERIADO` de la línea incluye al propio 1023 (está en el acumulador al 100%). Para comparar contra Meta4 hay que leer la base *evaluada* de la fórmula, no la línea.

## Relacionado

- [[feriado-divide-por-30-fijo]]
- [[produccion-no-se-prorratea]]
- [[medir-el-bruto-de-un-mes-por-sql]]
