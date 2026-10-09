---
tipo: tabla
tags: [modelo-de-datos, atributos, entidades]
fuente: [src/Tables/Tab110006.ClaseEntidadLiq.al, src/TableExtensions/TabExt52005.ClaseEnDimensionValue.al, src/Codeunits/Cod50075.GestionEntidadesLiq.al]
actualizado: 2026-10-04
---

# Tabla - Clase Entidad Liq

**Tabla 110006 `Clase Entidad Liq.`** (caption *Clase de Entidad*). **Datos persistentes** (catálogo chico).

**Propósito.** Qué *clase de cosa* es un valor de la dimensión global 1: buque, planta de proceso, administración. La dimensión mezcla las tres sin distinción, y esta clase permite que un atributo sepa a qué entidades corresponde (los datos de un barco no son los de una planta).

## Clave primaria
`Código` (Code[20]).

## Campos relevantes
| Campo | Tipo | Propósito |
|---|---|---|
| `Descripción` | Text[100] | |
| `Cant. Atributos` | FlowField Count | Cantidad de [[Tabla - Tipo Atributo Liq]] con `Cód. Clase` = este código. |

## Relaciones
- `Tipo Atributo Liq."Cód. Clase"` → esta tabla.
- `Entidad Liq."Cód. Clase"` → esta tabla (obligatoria).
- La clase de un valor de dimensión se guarda en la extensión `Clase en Dimension Value` (tableextension 52005, campo `Cód. Clase Entidad`).

## Lógica en triggers
`OnDelete`: error si algún tipo de atributo la usa.

## Quién la lee y la escribe
- **Lee:** `Cod50075 Gestión Entidades Liq.`, [[Tabla - Entidad Liq]], [[Tabla - Tipo Atributo Liq]], página `Clases de Entidad` (110015).
- **Escribe:** esa página.

## Trampas
> [!note] Por qué no guarda datos de la entidad
> Pensada para la migración a BC 28.0, donde `Vessels` pasa al contenedor compartido y se vuelve un maestro de Entidad: la tabla sólo es el catálogo de clases y la asignación se referencia siempre **por código** (el mismo string hoy como valor de dimensión y mañana como `Entidad.Código`). Ninguna fila tendría que migrarse.

- La plantilla de atributos (`Cod50073`) usa la clase para saber qué obligatorios materializar; una entidad sin clase no recibe plantilla.

## Relacionado
[[Tabla - Entidad Liq]] · [[Tabla - Tipo Atributo Liq]] · [[atributos-tipados]]
