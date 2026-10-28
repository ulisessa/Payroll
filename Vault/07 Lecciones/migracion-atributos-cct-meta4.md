---
aliases: ["Migración atributos CCT desde Meta4"]
tipo: leccion
tema: migracion-meta4
tags: [leccion, migracion-meta4, project]
origen: 9185b3df-1c53-44a4-a540-9174e99644c1
actualizado: 2026-09-14
---

# Migración atributos CCT desde Meta4

**En una frase:** El par convenio/categoría sale de los ATRIBUTOS, no de la ficha; migrado desde Meta4 el 13/9/2026 y 285 de 330 activos resuelven

El motor no lee `Employee."Cód. Convenio"`: ése es el respaldo. El par canónico sale de
`Atributo Entidad Liq.` (Tab110005) vía `ParDeEntidad` (Cod50080), y `ResolverParDeAtributos`
(Tab60011) lo pisa sobre lo que hayan puesto la asignación y la ficha. Por eso la ficha estaba
vacía para todos y no era un error: **no es donde va el dato**.

Migrado el 13/9/2026 con `MigrarAtributosCCT_1/2`. Pasó de 103 convenios y 95 categorías cargados
a mano, a **285 de 330 activos resolviendo el par completo**.

Tres cosas que condicionaron el diseño y que valen para cualquier migración parecida:

- **La categoría cuelga del convenio.** La clave de `Categoría CCT` es (convenio, código) — `OF01`
  es Capitán en `175/75` y también en `768/19` — así que el atributo de categoría guarda el
  convenio en `Cód. Valor Padre`, y tiene que ser el vigente A ESA FECHA. Hay que intersecar las
  vigencias y partir la categoría donde cambia el convenio.
- **El convenio de los OFICIALES sale del BUQUE, no de Meta4.** Meta4 tiene un solo `OF`; BC tiene
  `175/75` (CAPECA, tangoneros = buques 101-119) y `768/19` (AACPyPP, poteros = el resto). La línea
  de tiempo de flota se deriva de los estados. La tripulación rota mucho, así que un oficial cambia
  de convenio al cambiar de flota. El rango 101-119 quedó como número mágico en el script: debería
  ser un atributo `TIPO_BUQUE` sobre la entidad buque.
- **Normalizar ANTES de filtrar.** El `LEAD` que cierra cada vigencia tiene que ver el historial
  completo. Filtrando primero por los convenios mapeados, salta por encima de los descartados y
  cierra la vigencia anterior cuatro años tarde. Costó una corrida entera descubrirlo.

Equivalencia final: `MR`→729/15 · `FE`→ESP · `EC`→130/75 · `OF`→según flota · `JO`→JO y `FA`→FA
(creados con el mismo código: ninguno tiene CCT vigente al que llevarlo, y `ADM` tenía CERO
conceptos así que no se perdió nada al mover los administrativos a `FA`).

QUEDA ABIERTO: los 11 activos de `CA` (faltan CA11/13/14/15 en 372/04), 5 empleados con el par
inconsistente en Meta4, y **37 activos cuya vigencia de convenio está cerrada en Meta4 aunque su
fase de alta en BC siga abierta** — o se fueron y la baja no llegó, o el convenio quedó viejo.
Sin migrar todavía: `M4T_HIST_PUESTOS` (el cargo) y `M4T_HIST_SINDICATOS` (la retención sindical,
con `NRO_AFILIADO_SIND`). Ver [[campos-extension-tabla-ext]] y [[atributos-tipados]].

## Relacionado

- [[meta4-conectar-desde-powershell]]
- [[meta4-es-oracle]]
- [[meta4-number-castea-a-cero]]
- [[migracion-estados-meta4]]
- [[migracion-novedades-meta4]]
- [[migracion-tipo-liq-incompleta]]
- Tema: `migracion-meta4` (ver [[_Convenciones del vault]])
