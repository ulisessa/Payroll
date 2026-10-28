---
aliases: ["Nómina no es intervalo de presencia"]
tipo: leccion
tema: estados-fases
tags: [leccion, estados-fases, project]
origen: 9185b3df-1c53-44a4-a540-9174e99644c1
actualizado: 2026-09-17
---

# Nómina no es intervalo de presencia

**En una frase:** Las asignaciones PN- no se derivan de MIN/MAX de estados; la nómina es pertenencia, no presencia

`MigrarPersonalProyecto_4` deriva `Fecha Alta Asignación` / `Fecha Baja` del
`MIN(Fecha Inicio)` / `MAX(Fecha Fin)` de los estados del empleado en ese
proyecto. Para una marea (`PP-`) está bien. Para una nómina (`PN-`) está mal, y
cerró 170 asignaciones el 14/9/2026.

**Por qué:** un tripulante sigue perteneciendo a la nómina del buque mientras
navega, pero sus estados se mudan al proyecto de la marea. `MAX(Fecha Fin)` lee
esa mudanza como que se fue de la nómina, y la cierra el día antes de embarcar
—de ahí la firma `baja = alta − 1`, que parece una cascada de contigüidad y no
lo es. El personal de tierra (`PN-ADM-*`) no tiene ninguna cerrada justamente
porque nunca embarca.

**Cómo aplicarlo:** al derivar una asignación `PN-`, no cerrarla con el `MAX`:
queda abierta, o se cierra sólo por baja del empleado. Y antes de culpar a un
proceso de BC por una fecha rara, mirar `$systemModifiedAt` / `$systemModifiedBy`
de las filas: acá el GUID nulo y el timestamp del 14/9 mostraron que era una
escritura por SQL y no el motor. Ver [[migracion-estados-meta4]] y
[[estado-empleado-effective-dated]].

## Relacionado

- [[job-tipo-cero-no-bloquea]]
- [[novedad-proyecto-sale-del-estado]]
- [[proyecto-nomina-dos-fuentes]]
- [[puente-mayor-no-es-la-planta]]
- [[recorrer-estado-abierto-dia-por-dia]]
- [[tres-capas-fase-estado-asignacion]]
- Tema: `estados-fases` (ver [[_Convenciones del vault]])
