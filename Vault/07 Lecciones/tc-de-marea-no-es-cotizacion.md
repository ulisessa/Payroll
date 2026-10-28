---
aliases: ["El TC de la marea no es una cotización"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-04
---

# El TC de la marea no es una cotización

**En una frase:** El tipo de cambio con que se valoriza la producción es un valor acordado por marea, y TC_CERCANO devuelve otra cosa

La producción en dólares se pesifica con un **tipo de cambio acordado para esa marea**, no con
la cotización del día. Leído de la celda C7 de cada `CLC producción.xlsx`:

    A28/59  llegada 29/01/2026  ->  1.415
    A28/60  llegada 18/02/2026  ->  1.370
    A28/61  llegada 30/03/2026  ->  1.370
    A28/62  llegada 23/04/2026  ->  1.365

En ese período el mercado **subía** (1.465 el 14/01, 1.425 el 01/02) y el de la planilla
**baja**. No hay forma de derivarlo de la tabla de cotizaciones.

**`TC_CERCANO` no sirve para esto y además no hace lo que su nombre dice.** Es una Fuente de
Datos con `Función Agregado = LOOKUP` sobre la tabla 330 filtrando sólo por `{MONEDA}`, **sin
campos de fecha**, y `LOOKUP` no agrega vigencia por su cuenta (ver [[atributos-tipados]]). En
LIQ-00006169 devolvió 1.465, que es la última cotización cargada antes del arribo — no la más
cercana, y en enero de 2026 no hay cotizaciones entre el 15/01 y el 01/02.

**Alcance**: hoy `TC_CERCANO` ya se usa en la rama de LANGOSTINO del concepto 2498, así que la
producción de tangoneros puede estar valorizada con un TC equivocado. La rama de CALAMAR no lo
usa —`VALOR_CAL_*` está en pesos— y por eso la validación 26/26 de A28/59 pasó igual.

**Antes de escribir las fórmulas de producción de oficiales** (ver
[[produccion-oficiales-poteros]]) el TC tiene que entrar como dato por marea. El mecanismo
natural es un atributo sobre la entidad **Proyecto**, que ya existe y es efectivo-fechado;
`TIPOACTIVIDAD` sobre la entidad Buque es el precedente.

## Relacionado

- [[oficiales-netos-al-70]]
- [[precio-puerto-lista-inconsistente]]
- [[produccion-no-se-prorratea]]
- [[produccion-oficiales-poteros]]
- [[que-tc-usa-cada-concepto]]
- Tema: `conceptos-haberes` (ver [[_Convenciones del vault]])
