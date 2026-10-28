---
tipo: tabla
tags: [modelo-datos, estados, catalogo]
fuente: [src/Tables/Tab60003.CodEstadoEmpleado.al]
actualizado: 2026-10-04
---

# Tabla - Cód. Estado Empleado (60003)

## Propósito
Catálogo de **códigos de estado** (NV, PS, PL, GP, FR, AU1, ACC, ALT, BAJ…). Cada código lleva banderas que el motor lee en lugar de tener listas de códigos escritas en AL: el motor se configura, no se programa (ver [[avoid-tables-principle]]). Lo usan [[Tabla - Estado Empleado]] (el historial) y `Fase Alta Empleado` (los motivos de alta/baja).

## PK
`Código` (Code[20]), clustered. FieldGroup DropDown: Código, Descripción, Tipo Empleado.

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `Código` (1) / `Descripción` (2) / `Descripción Ampliada` (9) | Code[20] / Text[100] / Text[250] | La ampliada guarda el detalle que no entra en la descripción (artículo, indemnización…); nació de los comentarios de los motivos de baja de Meta4 |
| `Tipo Empleado` (3) | Enum [[Enums de liquidación#Aplica A Liq]] | Población a la que aplica |
| `Activo` (4) | Boolean | InitValue true |
| `Tipo Estado` (5) | Enum [[Enums de liquidación#Tipo Estado Empleado]] | Normal / Alta / Baja / Vacaciones / Francos. Alta y Baja **no se admiten** en el historial de estados |
| `Ámbito` (6) | Enum [[Enums de liquidación#Ámbito Estado]] | Empleado / Buque / Ambos |
| `Estado Siguiente` (7) | Code[20] → misma tabla | Auto-transición: cuando el estado termina, la entidad pasa a éste. En blanco = terminal |
| `Devenga Francos` (8) | Boolean | Estado productivo/embarcado: sus días cuentan para `DIAS_ENROLAMIENTO`, base del devengo de francos |
| `Transcurre en Marea` (10) | Boolean | Los días transcurren **a bordo, dentro de una marea** (NV, PS, PL: sí; GP, DQ, PI: no). Lo lee `ResolverProyectoInactividad` (Cod50017) para mandar al proyecto de nómina el estado que deja la marea, y `Estado Empleado.ValidarDentroDelProyecto` |
| `Promedia Ausencia` (11) | Boolean | El inicio de este estado **ancla la ventana del promedio** (enfermedad, accidente: AU1, ACC). Lo lee `FechaInicioAusencia` (Cod50016) para `{AUS_PROM_HASTA}`, `{AUS_PROM6_DESDE}`, `{AUS_PROM12_DESDE}` |

## TableRelations
`Estado Siguiente` → `Cód. Estado Empleado.Código` (auto-referencia).

## Triggers / validaciones
Ninguno propio. La lógica vive en el consumidor (`Cod50017.GestionEstadoEmpleado`: `AplicarAutoTransicion`, `ResolverProyectoInactividad`, `CalcDiasVacaciones`).

## Quién la usa
`Cod50017`, `Cod50016.ContextoLiquidacion`, `Cod50018`, `Cod50072.AltaEstadosBuque`, `Cod50077.GestionVariablesSistema`, `Cod110036.SincNAVLiq`; la referencian `Tab110048 Fase Alta Empleado`, `Tab110059 Estado Tipo Liq.`, `Tab60018 Variable Sistema Liq.` y las extensiones [[Extensión - Human Resources Setup]] y [[Extensión - Job]]. Página: `Pag50104 Cód. Estados Empleado`.

## Vigencias
Sin vigencia propia: un cambio de bandera afecta retroactivamente al cálculo de cualquier período que se recalcule.

## Trampas conocidas
> [!warning] Banderas parecidas, preguntas distintas
> `Devenga Francos` contesta "¿está trabajando?" y `Transcurre en Marea` contesta "¿está a bordo en una marea?". GP/DQ/PI devengan francos **sin** estar en ninguna marea. Confundirlas dejó 12.324 guardias en puerto colgadas del proyecto de la marea anterior. Ver [[gp-devenga-francos-pero-es-improductivo]].

> [!warning] `Tipo Estado` no distingue enfermedad de navegación
> Enfermedad y accidente caen en `Normal`; por eso existe `Promedia Ausencia`. Ver [[ventana-promedio-ausentismo]] y [[enfermedad-sin-convenio-paga-cero]].

Ver [[Mapa del modelo de datos - configuración y empleado]].
