---
aliases: ["La asignación no pisa el historial de estados"]
tipo: leccion
tema: estados-fases
tags: [leccion, estados-fases, project]
actualizado: 2026-10-08
---

# La asignación no pisa el historial de estados

Una marea tiene varios estados y la sincronización asumía uno: pisaba el primero y descolgaba al resto, en silencio

> [!warning] `FindFirst()` sobre (empleado, proyecto) **no** devuelve el estado más temprano: la PK de `Estado Empleado` es `No. Mov.`, no la fecha. Un cascade que asume un registro por relación corrompe los demás sin avisar.

`Personal Proyecto.OnModify` llamaba a `SincronizarEstadoDesdeProyecto`, que hacía `FindFirst` sobre (empleado, proyecto) y le escribía encima **el tramo completo de la asignación**. Pero una marea tiene **varios** estados —`PS` de salida, `NV` de navegación, `PL` de llegada—, así que agarraba uno y dejaba al resto descolgado.

**Qué pasó.** Cambiarle la fecha de embarque a un tripulante del 2/1 al 3/1 dejó su historial así:

| Antes | Después |
|---|---|
| `PS` 2/1 → PP-802-00000**6** | sin proyecto, y en una fila **nueva** |
| `NV` 3/1–24/1 → PP-802-00000**6** | **PP-802-000007** — la navegación de una marea colgada de la siguiente |
| `PS` 25/1 → PP-802-000007 | convertida en `NV` 25/1–11/2 |
| `NV` 26/1–11/2 → PP-802-000007 | desaparecida, absorbida por la anterior |

Nada de eso avisó. Con el `NV` de la marea 6 apuntando a la 7, el cierre de la 6 se queda sin estados y la 7 hereda 22 días que no son suyos.

**El tell que lo delató:** los `No. Mov.`. El `PS` del 2/1 tenía el número **máximo de la tabla** — era una fila nueva, no la original. Un número de movimiento fuera de orden en un tramo viejo es la firma de que algo reescribió el historial.

## La dirección correcta

**El historial es la fuente de verdad** —es lo que firma el capitán— y la asignación es un resumen suyo. Que el resumen reescriba la fuente es al revés. Desde el 8/10/2026:

- **Crear sigue automatizado**: si no hay ningún estado para ese proyecto no hay nada que romper, y es lo que hace cómoda el alta.
- **Modificar avisa y no toca**: `AvisarDesajusteConHistorial` compara el tramo que cubre el historial contra el de la asignación y saca un `Message` si difieren, nombrando los dos. Sólo cuando hay algo que mirar: editar el Rol no tiene por qué sacar un cuadro de diálogo, y el trigger corre en cada `Modify`.
- **Borrar la asignación** borra su estado sólo si es **uno**; con varios avisa y no borra ninguno. Tenía el mismo defecto.

El tramo del historial se calcula **recorriendo**, no con `FindFirst`/`FindLast`: ese supuesto es el que rompió los datos. Un estado abierto (`Fecha Fin` en blanco) no tiene fin con qué comparar, así que ahí alcanza con que arranquen juntos.

> [!note] La ventana de la marea sale de la asignación, no del historial
> `VentanaEmpleadoEnMarea` lee `Personal Proyecto."Fecha Alta Asignación"` / `"Fecha Baja"`. Cambiar el **tipo** de un estado —de `PS` a `NV`— no mueve ningún día: el reparto navegación/puerto lo decide el zarpe del proyecto, no el estado. Ver [[Estados y transiciones de una liquidación]].

## Relacionado

- [[tres-capas-fase-estado-asignacion]]
- [[algo-parte-estados-en-dos]]
- [[get-con-menos-argumentos]]
- [[join-por-menos-campos-que-la-pk]]
- [[previsualizar-antes-de-migrar]]
