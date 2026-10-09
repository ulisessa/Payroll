---
aliases: ["Fases de BC contra Meta4"]
tipo: leccion
tema: estados-fases
tags: [leccion, estados-fases, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-27
---

# Fases de BC contra Meta4

La comparación de Fase Alta Empleado contra M4T_FASES_ALTA: qué se corrigió el 27/9/2026 y las tres categorías que quedaron abiertas

Las fases se comparan emparejando por **empleado + fecha de alta**, nunca sólo por empleado:
varios tienen más de una fase y ponerle la baja a la equivocada mueve la antigüedad sin que nada
falle. Los nombres reales en Oracle son `FEC_ALTA_EMPLEADO` y `FEC_BAJA` (no `FEC_DESDE`/
`FEC_HASTA`), con `ID_MOTIVO_BAJA` y `COMENT_BAJA`, y hay una sola `ID_SOCIEDAD` ('01').

Método: exportar las 11.740 fases con el puente de [[meta4-conectar-desde-powershell]] y cargarlas
en `dbo.StgFaseM4` en mimir. **`BULK INSERT` no sirve** —corre en el servidor, que no ve el disco
local— y no hay `bcp`: hay que generar `INSERT` por lotes de 1000.

## Corregido el 27/9/2026

**38 fases estaban abiertas en BC y cerradas en Meta4.** BC creía que esas personas seguían
empleadas y les creaba liquidación todos los meses. Se cerraron las fases con la baja de Meta4 y
se recortaron 37 estados, con la regla de `Tab110048."Fase Alta Empleado".CerrarEstadosBaja`
replicada en SQL porque por SQL no corre el trigger. Efecto medido, empleados con estado vigente
en un mes que Meta4 no pagó:

    enero 19 → 2 · febrero 20 → 1 · marzo 22 → 2 · abril 23 → 3 · mayo 31 → 6 · junio 37 → 8

En la dirección inversa no faltaba nada: BC tiene estados para todos los que Meta4 pagó (0 en
enero). Toda la diferencia era ésta. Quedaron 23 liquidaciones de 202601 (16 empleados) sin estado
que las sostenga, para barrer.

**Y se crearon 36 de las 102 fases que faltaban** (mismo día), con `Cód. Motivo Alta` = `ALT` y
`No. Fase` = máximo por empleado + 1. Se recortaron 11 estados. Con eso **enero, febrero, marzo y
junio cuadran exacto en las dos direcciones** (330/330, 340/340, 349/349, 298/298) y las fases
abiertas de BC quedaron en 291, las mismas que Meta4.

Las 10 que importaban eran 04889 ×2, 04894, 04901, 04906, 04907, 04919, 04921, 04923 y 04932: las
segundas fases cuya ausencia dejaba un estado abierto o estirado. Las otras 26 son de **un solo
día** (alta = baja, `Días` = 0).

**El motivo de baja se traduce.** Meta4 guarda el número suelto (`1`, `12`) y BC usa `BAJ-1`,
`BAJ-12`; el campo tiene `TableRelation` a `Cód. Estado Empleado` filtrado por `Tipo Estado = Baja`,
y de ahí salen los atributos indemnizatorios. Escribir el número crudo deja el lookup roto sin que
nada falle — pasó y hubo que corregir 38 filas.

## Lo que quedó abierto

- **66 fases de Meta4 que BC no puede recibir**: se solapan con una que BC ya tiene y la tabla lo
  prohíbe. **39 son el mismo evento**: Meta4 corta la fase larga el 17/3/2025 y abre otra *ese
  mismo día* que cierra el 30/6/2025, mientras BC tiene la versión sin partir con la misma alta y
  la misma baja final. La unión de las dos es la fase de BC, así que la antigüedad da igual y no
  cambia nada en la liquidación; replicarlo obligaría a **inventar un día de frontera**, porque
  Meta4 admite baja y alta el mismo día y BC no. Es el mismo fenómeno de
  [[algo-parte-estados-en-dos]]. Las otras 27: 22 chocan con una fase que BC tiene y Meta4 no, 2
  tienen la baja de BC anterior, y 3 son desfasajes de 235, 702 y 878 días.
- **48 fases cerradas en las dos con fecha distinta**, 39 separadas por 105 días — la misma partición
  del 17/3/2025 vista del otro lado. Mueven antigüedad, no crean liquidaciones.
- **33 fases que BC tiene y Meta4 no.** Ocho son altas y reingresos de julio/agosto de 2026
  (04937, 04938, 04939, 90457, 90458, 01339, 04318, 04551) que Meta4 todavía no tiene.
- **22 fases viejas (2002-2017) con `Días` menor que la resta de fechas**, entre 2 y 62 días.
  Parecen traer un "días trabajados" de Meta4 en vez de la resta que hace la tabla. Corregirlo mueve
  antigüedad.
- **Dos huecos sueltos**: 04325 en mayo y 90308 en abril, pagados por Meta4 sin estado en BC.

## Lo que NO es una discrepancia

`M4T_HIST_ESTADOS_EMPL` es la tabla de estados **operativos de tripulación**: cubre 2.974 de los
6.679 empleados. El código `ACT` **no existe en Meta4** — cero filas. Los administrativos (80xxx,
90xxx, proyectos `PN-ADM-*`) cobran en Meta4 y **no tienen historial de estados ahí**, porque no
embarcan. En enero eran 58 empleados y 76 estados: borrarlos "por estar de más" dejaba a BC sin
constancia de que gente que Meta4 paga estaba trabajando.

Y **`Fecha Fin` en BC se deriva por contigüidad** —día anterior al inicio del siguiente—, así que
comparar por solapamiento de intervalos da falsos positivos: BC estira el último estado hasta donde
Meta4 tiene un hueco.

**No usar "el último mes que Meta4 pagó" como criterio de baja.** Falla con los reingresos, y el
historial de Meta4 importado en BC termina en julio de 2026 con ese mes incompleto (37 empleados
contra 298 en junio), así que marca como bajas a los que acaban de entrar.

Ver [[tres-capas-fase-estado-asignacion]] para el orden de la limpieza y
[[previsualizar-antes-de-migrar]] para los controles.

## Relacionado

- [[meta4-conectar-desde-powershell]]
- [[algo-parte-estados-en-dos]]
- [[tres-capas-fase-estado-asignacion]]
- [[previsualizar-antes-de-migrar]]
- [[estado-empleado-effective-dated]]
- [[gp-devenga-francos-pero-es-improductivo]]
