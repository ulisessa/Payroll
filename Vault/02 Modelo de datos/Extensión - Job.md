---
tipo: tabla
tags: [modelo-datos, extension, mareas, estados-fases]
fuente: [src/TableExtensions/TabExt52003.ProyectoPescaExt.al]
actualizado: 2026-10-04
---

# Extensión - Job (TabExt52003 "Proyecto Pesca Ext.")

Extiende `Job` (Proyecto), que en este sistema es la **marea** (o el proyecto de nómina `PN-`). Dimensión global 1 = Buque, dimensión global 2 = Marea ([[dim2-nav-actividad-bc-marea]]).

| Campo | ID | Tipo / relación | Propósito |
|---|---|---|---|
| `Estado Liq. Personal Predet.` | 52020 | → [[Tabla - Cód. Estado Empleado]] | Estado que se asigna automáticamente al empleado al asignarlo al proyecto ([[Tabla - Personal Proyecto]]), vía `SetEstado` |
| `Zona Desfavorable` | 52021 | Integer ≥ 0 | Zona del viaje compartida por toda la dotación. El motor la inyecta como `COD_ZONA`; si es 0 cae a la de la ficha ([[Extensión - Employee]]). **Es la red**: si existe una Fuente de Datos `COD_ZONA` (atributo con historial) manda ésa y estos dos campos no se leen |
| `Proyecto Inactividad Nómina` | 52022 | Code[20] → `Job."No."` | Al pasar un empleado de un estado activo a uno inactivo se lo asigna a este proyecto. En blanco → `Proyecto Nómina` de [[Extensión - Human Resources Setup]]. OnValidate: no puede ser el mismo proyecto |

## Trigger: cargar el arribo cierra la marea
**OnModify**: cuando `Ending Date` pasa de **vacío a cargado** (no al corregirlo) llama a `Gestión Estado Empleado`.`CerrarAsignacionesDeProyecto(No., Ending Date)`. Antes las asignaciones quedaban abiertas y el tripulante seguía "navegando" en un buque ya amarrado. Corregir la fecha después **no** reabre nada.

> [!warning] El arribo manda sobre los estados
> `Ending Date` vacío = marea en curso (o proyecto de nómina que no termina). Ver [[Tabla - Estado Empleado]] (`ValidarDentroDelProyecto`) y [[Tabla - Tipo Liquidación]] (el *Marea en curso* mira la fecha de arribo, no el `Status` del Job, que está mal mantenido).

## Dónde se lee
`Cod50017.GestionEstadoEmpleado`, `Cod50018.ProcesoLiqPorLotes`, `Cod50014.MotorLiquidacion`, `Pag110022 Control Liquidación Marea`, `PagExt50351 JobCardExt`.

## Trampas
- Estados de marea dentro del proyecto: [[tres-capas-fase-estado-asignacion]], [[nomina-no-es-intervalo-presencia]].
- Veda como atributo del buque (no del Job): [[veda-como-atributo-del-buque]].
