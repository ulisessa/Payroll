---
aliases: ["CopyFilters copia sólo el grupo actual"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-18
---

# CopyFilters copia sólo el grupo actual

CopyFilters copia sólo el grupo de filtro actual, así que no arrastra los del SubPageLink (grupo 4) y el recorrido sale sin acotar

`CopyFilters` copia los filtros del **grupo actual** nada más. Los que pone un `SubPageLink` viven en
el **grupo 4**, así que copiar desde el `Rec` de una subpágina estando en el grupo 0 no trae el
alcance a la entidad de la ficha: el recorrido sale sobre la tabla entera.

**Por qué:** visto el 18/9/2026 en `FiltrarUltimaPorTipo` (Cod110035). La parte de Atributos de la ficha
de empleado está vinculada con `SubPageLink = "Tipo Entidad" = CONST(Empleado), "Cód. Entidad" =
FIELD("No.")`. El `CopyFilters` no copió nada, el bucle recorrió las 19.573 vigencias de toda la
nómina y armó un id por cada par empleado-atributo. El síntoma no fue lentitud sino *"The incoming
request has too many parameters. The server supports a maximum of 2100"* y la ficha cerrándose sola:
cada literal de un filtro `a|b|c` es un parámetro de SQL.

**Cómo aplicarlo:** para arrastrar el alcance completo hay que copiar grupo por grupo — `CopyFilters`
en el 0, después `FilterGroup(4)` en origen y destino, `CopyFilters` de nuevo, y restaurar. Y cuando
un filtro se arma con una lista de literales, poner dos guardas: exigir que el filtro que acota
exista (`GetFilter("Cód. Entidad") <> ''`) y topear la cantidad de literales. Si alguna falla, **no
filtrar** — mostrar de más es recuperable, una consulta que el server rechaza cierra la página.

Ver [[setselectionfilter-tabla-temporal]], que es la misma clase de trampa: una API de filtros que
parece hacer lo obvio y hace algo más angosto, sin avisar.

## Relacionado

- [[setselectionfilter-tabla-temporal]]
- [[al-compile-command]]
- [[al-sin-cortocircuito]]
- [[avoid-tables-principle]]
