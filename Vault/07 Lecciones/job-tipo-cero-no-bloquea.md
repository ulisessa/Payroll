---
aliases: ["Job.Tipo en cero no bloquea"]
tipo: leccion
tema: estados-fases
tags: [leccion, estados-fases, feedback]
actualizado: 2026-10-04
---

# Job.Tipo en cero no bloquea

> [!warning] Falla en silencio
> el Tipo del proyecto en cero significa "sin clasificar", no "ninguno"; compararlo estricto deja empleados sin liquidación

El campo `Tipo` del Job (Todos / Productivo / Improductivo) lo define la extensión Producción, y
**el cero significa "sin clasificar", no "ninguno"**. El resto del motor lo entiende así —
`AplicarFiltroJobs` filtra sólo `if TipoProyecto > 0` — pero una comparación estricta
`Job.Tipo = <calificador>` lo trata como un valor más y descarta.

Mordió con el 04901: sus dos proyectos de nómina **no tienen fila en la tabla `$ext`**, así que
su `Tipo` se lee cero. Con la línea de la Regular pidiendo estados de proyecto Improductivo, no
matcheaba ninguno y el empleado se quedaba sin liquidación de enero, que Meta4 sí le había pagado.

**Se compara por el ordinal**, no por el miembro: la opción cero no tiene nombre en el enum, así
que `Job.Tipo::Todos` no compila. Hay que asignarlo a un Integer.

**Los datos además están sucios:** de los 509 proyectos de nómina, 14 figuran como Productivo y 4
como Todos; y de los 3.975 de marea, 12 como Improductivo y 2 como Todos. Un `PN-` productivo o un
`PP-` improductivo dan resultados raros por caminos que no parecen tener que ver.

Ver [[campos-extension-tabla-ext]] y [[cuando-corresponde-una-liquidacion]].

## Relacionado

- [[nomina-no-es-intervalo-presencia]]
- [[novedad-proyecto-sale-del-estado]]
- [[proyecto-nomina-dos-fuentes]]
- [[puente-mayor-no-es-la-planta]]
- [[recorrer-estado-abierto-dia-por-dia]]
- [[tres-capas-fase-estado-asignacion]]
- Tema: `estados-fases` (ver [[_Convenciones del vault]])
