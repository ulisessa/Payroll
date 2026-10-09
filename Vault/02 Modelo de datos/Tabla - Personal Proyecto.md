---
tipo: tabla
tags: [modelo-datos, estados-fases, mareas]
fuente: [src/Tables/Tab60009.PersonalProyecto.al]
actualizado: 2026-10-04
---

# Tabla - Personal Proyecto (60009)

## Propósito
**Asignación** de un empleado a un proyecto (`Job`): mareas, nómina administrativa y planta. Es la tercera capa junto a la fase de alta y el estado ([[tres-capas-fase-estado-asignacion]]). Una asignación **genera y mantiene** un estado en [[Tabla - Estado Empleado]].

## PK e índices
PK (clustered): `No. Empleado`, `No. Proyecto`. K2 `No. Proyecto`; K3 `Buque`, `Marea`; K4 `No. Empleado`, `Fecha Alta Asignación` ("la última asignación antes de tal fecha").

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `No. Empleado` (1) | Code[20] → `Employee` | |
| `No. Proyecto` (2) | Code[20] → `Job` | OnValidate copia `Buque` (←Dim global 1) y `Marea` (←Dim global 2) y hereda `Starting/Ending Date` del Job **sólo si la asignación los tiene en blanco** |
| `Fecha Alta Asignación` (5) | Date | Maneja el `Fecha Inicio` del estado vinculado |
| `Fecha Baja` (6) | Date | Fin informativo de la asignación |
| `Buque` (8) | Code[20] | No editable. Es Code[20] (antes [10] truncaba en silencio) |
| `Marea` (9) | Code[10] | No editable |
| `Observaciones` (10), `Nombre Empleado` (11, FlowField) | | |

Los campos `Cód. Convenio`/`Cód. Categoría` de la asignación **se eliminaron el 18/9/2026**; el par por puesto sale ahora de atributos (ver [[Enums de liquidación#Par CCT Liq]]).

## Triggers
- **OnInsert / OnModify** → `Gestión Estado Empleado`.`SincronizarEstadoDesdeProyecto(Rec)` (`Cod50017`).
- **OnModify**: sólo al *completar* `Fecha Baja` (de vacío a cargado) → `EncadenarSiguienteAsignacion` (estado siguiente al día posterior y alta en el proyecto predeterminado). Si la cadena falla, el error revierte también el cierre de la asignación.
- **OnDelete** → `EliminarEstadoDeProyecto`.

> [!note] Sin validación de la baja contra el arribo (a propósito)
> Se probó "Error si `Fecha Baja` > `Job."Ending Date"`" y los datos la desmintieron: PL cae 1–3 días después del arribo (1.587 casos) y PS hasta 3 días antes de la zarpada (9.221 de 10.004). El límite real sería la próxima zarpada del buque, dato que la tabla no tiene. Detalle en el comentario del archivo.

## Quién la lee / escribe
`Cod50017.GestionEstadoEmpleado`, `Cod50054.GestionMarea` (asignar tripulación), `Cod50075.GestionEntidadesLiq`, `Cod50014.MotorLiquidacion`, `Cod50016.ContextoLiquidacion`, `Cod50018.ProcesoLiqPorLotes`. Páginas: `Pag50109 Personal Proyecto`, `PagExt50350 EmployeeCardExt`, `PagExt50351 JobCardExt`, `PagExt50356 EmployeeListExt`.

## Vigencias
Intervalo `[Fecha Alta Asignación, Fecha Baja]` informativo; la vigencia operativa real es la del estado.

## Trampas conocidas
- Derivar la asignación del MIN/MAX de los estados la deja mal si los estados están mal ([[nomina-no-es-intervalo-presencia]]).
- El proyecto de la novedad sale del estado, no de la asignación: [[novedad-proyecto-sale-del-estado]], [[proyecto-nomina-dos-fuentes]].
- Migración desde Meta4: [[migracion-estados-meta4]].
