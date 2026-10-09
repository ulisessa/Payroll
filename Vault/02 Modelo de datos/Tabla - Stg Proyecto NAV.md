---
tipo: tabla
tags: [modelo-de-datos, integracion-nav, staging, proyectos]
fuente: [src/Tables/Tab110042.StgProyectoNAV.al, src/Codeunits/Cod110037.AplicarFilaSincNAV.al, src/Codeunits/Cod110041.TraerNAVWS.al]
actualizado: 2026-10-04
---

# Tabla - Stg Proyecto NAV

**Tabla 110042 `Stg Proyecto NAV`** (*Staging Proyecto NAV*). **Datos persistentes** (staging). Patrón común: [[Patrón de las tablas de staging NAV]].

**Propósito.** Espejo de la fila de `Job` que vino de NAV, **antes** de aplicarse: la marea. Sólo están los campos que la liquidación usa o que identifican la marea. Agregar uno exige tocarlo en tres lugares: esta tabla, el `MERGE` del script y `Aplicar Fila Sinc NAV`. Los FlowFields de `Job` (kilos descargados, totales DCL) no se traen.

## Clave primaria
`"No Proyecto"` (Code[20]). Secundaria `("Estado Sinc","No Proyecto")`.

## Campos relevantes
| Campo | Tipo | Propósito |
|---|---|---|
| `Descripcion`, `Descripcion 2` | Text | |
| `Fecha Inicio`, `Fecha Fin` (arribo) | Date | **Cargar `Fecha Fin` es cerrar la marea**: al validarse sobre un Job que la tenía vacía, el `OnModify` de `Proyecto Pesca Ext.` cierra las asignaciones de personal abiertas. |
| `Buque` | Code[20] | → `Global Dimension 1 Code`. |
| `Marea` | Code[20] | NAV `Global_Dimension_3_Code` → BC `Global Dimension 2`. |
| `Actividad` | Code[20] | LAN/CAL. NAV `Global_Dimension_2_Code` → BC `Global Dimension 3` (campo 50000 de `Job` de la personalización). |
| `Estado` | Integer | Ordinal de `Job.Status` de NAV, **sólo referencia**: no se aplica (en BC gobierna WIP y registración). |
| `Tipo Proyecto` | Integer | `Job Ext.` campo 50806; el que el motor filtra para productivo/improductivo (`AplicarFiltroJobs` de `Proceso Liq. por Lotes`). |
| `Patron`, `Hora Zarpada`, `Hora Ingreso Puerto`, `Fecha Llegada Prevista`, `Puerto Zarpada`, `Puerto Descarga`, `Anio Marea` | varios | Datos del viaje, asignación directa a campos de `Job`. |
| 90–95 | | Estado, observación, intentos, marca, traído/procesado. |

## Se aplica sobre
`Job` (+ Default Dimensions de Buque, Marea y Actividad vía `Validate`). Se crea con `Insert(true)` y luego `Validate` de descripción, `Starting Date`, tres dimensiones, `Tipo`, y **al final** `Ending Date`.

## Quién la lee y la escribe
- **Escribe (traída):** `Cod110041.VolcarProyectos` (WS) o el job SQL. `Status` y `Tipo` llegan por OData como **caption localizada** (por SQL llegaban como número); un valor desconocido **falla la fila** en lugar de asumir 0.
- **Aplica:** `Cod110037.AplicarProyecto` (orquestado por `Cod110036.ProcesarProyectos`).
- **Lee:** páginas `Sinc. Proyectos NAV` (110033) y `Control Sinc. NAV`.

## Trampas
> [!warning] Dimensiones 2 y 3 cruzadas
> En NAV la 2 es actividad y la 3 marea; en BC es al revés. El cruce es explícito; copiar posicionalmente dejaba todos los proyectos con marea LAN o CAL sin error. Ver [[dim2-nav-actividad-bc-marea]].

> [!warning] La fecha de arribo se limpia antes de tocar la de zarpada
> `Job."Ending Date" := 0D` antes de `Validate("Starting Date")` evita el error "Fecha inicial debe ser igual o anterior a Fecha final" con un par perfectamente coherente; la definitiva se escribe al final con `Validate`, que dispara el cierre de marea. Si esa cadena falla, falla la fila y la marea no queda cerrada a medias.

- El valor de dimensión de una marea nueva tiene que existir antes: por eso [[Tabla - Stg Valor Dim NAV]] se procesa primero ([[sincronizacion-valores-dimension]]).
- Un proyecto que cambia en NAV vuelve a Pendiente en la siguiente traída (y pierde el Procesado anterior).

## Relacionado
[[Tabla - Stg Valor Dim NAV]] · [[Tabla - Stg Descarga Cab NAV]] · [[Tabla - Config Sinc NAV]] · [[job-confirm-dimension-inocuo]] · [[proyecto-nomina-dos-fuentes]]
