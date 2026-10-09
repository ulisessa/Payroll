---
aliases: ["Un proceso desconocido parte estados en dos"]
tipo: leccion
tema: estados-fases
tags: [leccion, estados-fases, project]
actualizado: 2026-10-04
---

# Un proceso desconocido parte estados en dos

Un proceso desconocido parte estados en dos filas; corrió al menos dos veces en 2025 y la causa sigue abierta

Hay un proceso que **parte un estado en dos filas contiguas**, y a veces le borra
el proyecto a la segunda. Descubierto el 17/9/2026. Corrió por lo menos dos veces:

- **18/3/2025** · 33 filas · `OR`, `AU9` y `GP` sobre proyectos `PN-`.
- **6/10/2025** · 28 filas · `NV` de toda la tripulación del A19, marea 000307.
  Acá además la cola quedó sin proyecto.

En Meta4 cada caso es UNA sola fila. Las escribió la cuenta de sistema
(`00000000-…-0001`), no un usuario, y **no fue la cascada del buque**: no hay ni un
`Estado Empleado` con `Tipo Entidad = 1` en esas fechas. **La causa sigue sin
identificarse.** Si aparece un tercer corte, la fecha del corte es la pista: las
dos veces fue el mismo día para todo un grupo.

**Por qué:** el síntoma no es un error, es una ficha que se ve rara —dos renglones de
navegación seguidos con el mismo proyecto— y ningún control de la auditoría lo
miraba, porque los bloques 1 a 5 comparan contra Meta4 filtrando `'PP-%'` y una
fila sin proyecto se les escapa.

**Cómo aplicarlo:** el control está en el bloque 21.d de
`scripts/AuditarFechasAsignaciones.sql` y no necesita a Meta4: dos filas contiguas
con el mismo empleado, código, proyecto y observaciones no se distinguen en nada.
La unión va por **islas**, no de a pares (hubo una cadena de tres), y el fin de la
isla sale de la fila que empieza última, nunca de `MAX(Fecha Fin)`: un estado
abierto tiene `'1753-01-01'`, que es el mínimo de la columna. Ver
[[estado-empleado-effective-dated]] y [[tres-capas-fase-estado-asignacion]].

## Relacionado

- [[estado-empleado-effective-dated]]
- [[tres-capas-fase-estado-asignacion]]
- [[fases-bc-contra-meta4]]
- [[gp-devenga-francos-pero-es-improductivo]]
