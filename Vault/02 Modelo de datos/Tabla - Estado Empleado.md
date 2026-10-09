---
tipo: tabla
tags: [modelo-datos, estados, effective-dating]
fuente: [src/Tables/Tab60000.EstadoEmpleado.al]
actualizado: 2026-10-04
---

# Tabla - Estado Empleado (60000)

## Propósito
Historial **contiguo y con vigencia** de lo que hacía cada entidad cada día: un empleado (navegando, de vacaciones, enfermo, de franco, en puerto…) o un buque. Una sola tabla sirve a las dos entidades, discriminada por `Tipo Entidad`. Es el eje de la liquidación: de acá salen el tipo de población, el proyecto de nómina, los días de cada estado (`DIAS_*`), la cobertura y el devengo de francos.

Las **altas y bajas ya NO viven acá**: están en `Fase Alta Empleado` (ver [[Tabla - Fase Alta Empleado]]). Ver [[tres-capas-fase-estado-asignacion]] y [[estado-empleado-effective-dated]].

## Clave primaria e índices
| Clave | Campos | Notas |
|---|---|---|
| PK (clustered) | `No. Mov.` | AutoIncrement |
| K1 (**Unique**) | `Tipo Entidad`, `No. Empleado`, `No. Proyecto`, `Fecha Inicio` | Incluye el proyecto: dos estados del mismo día de distinto proyecto *no chocan* acá; los frena `ValidarUnEstadoPorFecha` |
| K2 | `Tipo Entidad`, `No. Empleado`, `Fecha Inicio` | La que usa todo recorrido de historial (`GetEstado` = FindLast) |

Sin SumIndexFields.

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `No. Mov.` (7) | Integer | PK autoincremental |
| `No. Empleado` (1) — caption **Cód. Entidad** | Code[20] | Nº de empleado o código de buque según `Tipo Entidad`. Sin TableRelation (apunta a dos tablas) |
| `Tipo Entidad` (9) | Enum [[Enums de liquidación#Tipo Entidad Estado]] | Empleado / Buque (el valor Proyecto no se usa acá) |
| `Fecha Inicio` (2) | Date | Inicio del estado. Su OnValidate autocalcula el fin en Vacaciones |
| `Cód. Estado` (3) | Code[20] | TableRelation → [[Tabla - Cód. Estado Empleado]] |
| `Fecha Fin` (4) | Date | Fin **inclusive**; en blanco = abierto. Se mantiene sola (ver contigüidad) |
| `No. Proyecto` (8) | Code[20] | TableRelation → `Job`. No editable. Lleno si el estado salió de una asignación ([[Tabla - Personal Proyecto]]) o del proyecto de inactividad/nómina; vacío si se cargó a mano |
| `Descripción Estado` (5) | FlowField | Lookup a la descripción del código |
| `Observaciones` (6) | Text[250] | Libre |

## Lógica de triggers (lo que importa)
**OnInsert**: `TestField` de entidad/fecha/estado → `ValidarNoEsAltaNiBaja` → `ValidarDentroDeFaseDeAlta` → `ValidarDentroDelProyecto` → `ValidarOrdenFechas` → `ValidarUnEstadoPorFecha` → `ValidarNoHayLiquidacionesBloqueantes` → `AplicarAutoTransicion` y `ResolverProyectoInactividad` (codeunit `Gestión Estado Empleado`, `Cod50017`) → `SincronizarContiguidad` **último a propósito** (la auto-transición inserta el estado de retorno antes de que éste esté escrito).

**OnModify**: mismas validaciones; el rango bloqueado abarca fin viejo **y** nuevo (acortar le pasa días al siguiente). Si cambia `Fecha Fin` a un valor no vacío → `EmpujarSiguienteEstado` (corre el inicio del siguiente a `Fecha Fin + 1`; error si lo dejaría sin días o pasaría al sub-siguiente).

**OnDelete**: valida liquidaciones bloqueantes y `ReabrirAnteriorAlBorrar` (el anterior absorbe el tramo; si era el último queda abierto).

Reglas:
- **Contigüidad**: al insertar/modificar, el estado anterior se cierra en `Fecha Inicio − 1` y éste toma el fin del siguiente. El historial nunca tiene huecos.
- **Un estado por fecha** por entidad (`ValidarUnEstadoPorFecha`), independientemente del proyecto.
- **No altas ni bajas** en este historial (códigos con `Tipo Estado` Alta/Baja → error).
- **Dentro de una fase de alta** (sólo empleados): sin fase → error; fuera de fase → error. No crea la fase sola (la fecha de ingreso es dato contractual).
- **Dentro del proyecto**: un estado con `Transcurre en Marea` no puede empezar después de `Job."Ending Date"` (sin tolerancia; origen: 29 estados NV fechados 13/10/2026 en PP-119-000308).
- **Liquidaciones bloqueantes**: sólo empleados; si hay una `Liquidación` no Borrador cuya cobertura se cruce con el tramo afectado → error "Revertí la liquidación". Para Cierre de Marea (`EsArribo`) la cobertura llega hasta `Fecha Liquidación`, no hasta el fin del período.
- **Vacaciones**: elegir un código de Tipo Estado Vacaciones propone `Fecha Fin = Fecha Inicio + días LCT − 1` (`CalcDiasVacaciones`); queda editable.

## Procedimiento público
- `FechaFinEfectiva()`: `Fecha Fin` si está cargada; si no, `Fecha Inicio` del siguiente − 1; si es el último, **31/12/9999**. Todo el motor lee el fin por acá.

> [!warning] 31/12/9999 desborda
> Recorrer un estado abierto día por día con `FechaFinEfectiva` revienta con "La fecha no es válida". Ver [[recorrer-estado-abierto-dia-por-dia]].

> [!warning] Dos generadores, una sola fecha
> La sincronización desde la asignación (`SincronizarEstadoDesdeProyecto`) y `SetEstadoEntidad` crean estados por caminos distintos; antes se pisaban y el `GetEstado` elegía uno al azar. Hoy `ValidarUnEstadoPorFecha` lo corta. Hay estados partidos en dos por una cuenta de sistema sin causa identificada: [[algo-parte-estados-en-dos]].

## Quién la lee / escribe
- Escribe: `Cod50017.GestionEstadoEmpleado` (altas, transiciones, cascada de buque), `Cod50072.AltaEstadosBuque`, `Cod50075.GestionEntidadesLiq`, `Cod50062.EstadoFechaFinUpgrade` (backfill de `Fecha Fin`), migración Meta4, `Tab60009` Personal Proyecto (vía sincronización).
- Lee: `Cod50016.ContextoLiquidacion` (`DIAS_*`, población), `Cod50053.GestionFrancos`, `Cod50018.ProcesoLiqPorLotes`, `Cod50061.GestionNovedadesLiq`, `Cod110030.ControlCoberturaLiq`, `Cod110054.CoberturaTramosLiq`, `Tab60011` (`RecortarAlTramoDelEmpleado`).
- Páginas: `Pag50103 Estados Empleado`, `Pag50135 Nuevo Estado Empleado`, `Pag50136` FactBox, `Pag50192 Estados de Buque`.

## Vigencias
Es la tabla de effective-dating por excelencia: intervalo `[Fecha Inicio, FechaFinEfectiva]` contiguo. Ver [[estado-empleado-effective-dated]] y [[nomina-no-es-intervalo-presencia]].

## Trampas conocidas
- [[tres-capas-fase-estado-asignacion]]: el síntoma aparece una capa más abajo del problema; limpiar de arriba hacia abajo.
- [[gp-devenga-francos-pero-es-improductivo]] y `Transcurre en Marea` ≠ `Devenga Francos` (ver [[Tabla - Cód. Estado Empleado]]).
- [[xrec-no-confiable-con-addin]] si se modifica desde un control add-in.
- Modificaciones por SQL directo dejan la caché rancia: [[sql-directo-deja-cache-rancia]].

Ver también [[Mapa del modelo de datos - configuración y empleado]].
