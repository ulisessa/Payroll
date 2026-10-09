---
aliases: ["Tres capas: fase, estado, asignación"]
tipo: leccion
tema: estados-fases
tags: [leccion, estados-fases, project]
origen: 9185b3df-1c53-44a4-a540-9174e99644c1
actualizado: 2026-09-17
---

# Tres capas: fase, estado, asignación

**En una frase:** Fase Alta → Estado Empleado → Personal Proyecto; el síntoma aparece una capa abajo del problema

El personal se modela en tres capas derivadas una de otra:
`Fase Alta Empleado` (pertenencia a la empresa) → `Estado Empleado` (qué hacía
cada día) → `Personal Proyecto` (asignación, derivada de los estados) →
liquidación. Cada capa se calcula de la anterior.

**Por qué:** el 17/9/2026, "el legajo 00794 tiene mal la fecha de baja" resultó ser
una cadena de cuatro escalones, con un problema propio en cada uno: fases de
eventuales sin el alta del reingreso → estados futuros cargados con el WorkDate
adelantado → una derivación que trataba la nómina como intervalo de presencia →
fechas raras en la asignación. Mirar más abajo nunca resolvió nada; el avance
siempre vino de subir una capa.

**Cómo aplicarlo:** ante una fecha rara en `Personal Proyecto`, no corregirla ahí:
preguntar de qué estado sale. Ante un estado raro, preguntar si cae dentro de una
fase. Corregir la capa de abajo deja el arreglo en pie hasta la próxima corrida de
la migración, que lo vuelve a pisar. Y el orden de la limpieza es siempre
fases → estados → asignaciones, nunca al revés: borrar una asignación antes de
limpiar su estado la hace volver. Ver [[nomina-no-es-intervalo-presencia]],
[[estado-empleado-effective-dated]] y [[previsualizar-antes-de-migrar]].

## Relacionado

- [[job-tipo-cero-no-bloquea]]
- [[nomina-no-es-intervalo-presencia]]
- [[novedad-proyecto-sale-del-estado]]
- [[proyecto-nomina-dos-fuentes]]
- [[puente-mayor-no-es-la-planta]]
- [[recorrer-estado-abierto-dia-por-dia]]
- Tema: `estados-fases` (ver [[_Convenciones del vault]])
