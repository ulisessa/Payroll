---
aliases: ["Proyecto de nómina: dos fuentes"]
tipo: leccion
tema: estados-fases
tags: [leccion, estados-fases, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-10-01
---

# Proyecto de nómina: dos fuentes

**En una frase:** la liquidación mensual deducía el proyecto del último embarque en vez de leerlo del estado; 64 quedaban en el buque equivocado

`ProyectoNominaDe` (Cod50018) elegía el proyecto de la liquidación REGULAR **recorriendo hacia atrás
hasta el último estado que "Transcurre en Marea"**, sacando el buque de su dimensión 1 y de ahí el
atributo `PROY_NOMINA`. Pero el proyecto **ya estaba escrito en el estado**: lo puso
`ResolverProyectoInactividad` (Cod50017) al crearlo, con el `Proyecto Inactividad Nómina` de la marea
de la que el tripulante venía bajando.

**Dos fuentes para el mismo dato, por caminos distintos.** Mientras el empleado pasó por un solo
buque coinciden; cuando cambió, no. Corregido el 1/10/2026: si el estado vigente a la fecha no
transcurre en marea y tiene proyecto, **ése es**, sin deducir nada.

Fallaba **sólo con los estados que no transcurren en marea** —FR, GP, AU9, OR—, porque son los únicos
que el recorrido salteaba buscando un embarque. Los NV ya salían bien.

**Medido sobre enero de 2026**: de 323 liquidaciones REGULAR, **65 cambian de proyecto** y **64 de
esas 65 estaban sobre un proyecto donde el empleado no tuvo ningún estado en el mes**. (Un conteo
anterior mío dio 14; era una medición distinta y más laxa — el número bueno es 64.) 156 quedan igual,
85 tienen estado de marea al cierre y siguen por el camino viejo, y **ninguna queda sobre un proyecto
de marea**, que era el riesgo: hay 687 estados de no-marea que arrastran un `PP-`, pero ninguno
vigente en enero.

**No es sólo un proyecto mal puesto: del proyecto sale el buque, y del buque TODOS sus atributos.**
04360 estaba en francos sobre PN-117-NOMINA (buque **tangonero**) y su liquidación salió en
PN-128-NOMINA (**potero**), así que la fórmula del 1053 tomó la rama potero y el coeficiente le dio 1
en vez de 0,3: 68.663 contra los 20.599 de Meta4. Lo mismo 04495 (planta, sin coeficiente, liquidado
en el 110) y 02748 (potero liquidado en el 117, al revés). **Los tres se arreglan con el proyecto, sin
tocar el motor** — el diagnóstico previo de "llevar el coeficiente al lote" era equivocado.

Afecta también la veda, los precios por pesquería y cualquier cosa que cuelgue del buque.

`PROY_NOMINA` está cargado sólo sobre los **12 buques**; no hay filas sobre empleado, así que
PN-PPM-NOMINA y los PN-ADM-* **no** son valores de ese atributo y no sirven para validar si un
proyecto es "de nómina". Tampoco sirve la dimensión 2: 503 proyectos `PN-` la tienen cargada. Ver
[[tres-capas-fase-estado-asignacion]], [[veda-como-atributo-del-buque]] y
[[novedad-proyecto-sale-del-estado]].

## Relacionado

- [[job-tipo-cero-no-bloquea]]
- [[nomina-no-es-intervalo-presencia]]
- [[novedad-proyecto-sale-del-estado]]
- [[puente-mayor-no-es-la-planta]]
- [[recorrer-estado-abierto-dia-por-dia]]
- [[tres-capas-fase-estado-asignacion]]
- Tema: `estados-fases` (ver [[_Convenciones del vault]])
