---
tipo: tabla
tags: [modelo-datos, extension, obsoleto]
fuente: [src/TableExtensions/TabExt52005.ClaseEnDimensionValue.al]
actualizado: 2026-10-04
---

# Extensión - Dimension Value (TabExt52005 "Clase en Dimension Value")

> [!warning] Extensión sin uso
> Está **obsoleta (Pending)** y ningún objeto referencia su único campo. Se conserva porque sacar un campo de una extensión publicada exige pasar antes por `ObsoleteState`.

| Campo | ID | Tipo | Estado |
|---|---|---|---|
| `Cód. Clase Entidad` (caption "Clase de Entidad (obsoleto)") | 52010 | Code[20] | `ObsoleteState = Pending` |

## Por qué existió y por qué murió
Colgaba la **clase de la entidad** del valor de dimensión para no inventar un maestro paralelo. La entidad terminó necesitando un registro propio: una ficha, un lugar donde crecer sin extender una tabla de sistema, un alta controlada que garantice que toda entidad tiene clase, y una relación de tabla real para `Cód. Entidad` en los atributos (apuntaba a tres cosas distintas, por eso no podía tener ninguna). Hoy la clase vive en **`Entidad Liq.`** (maestro operativo; ver `Gestión Entidades Liq.`, `Cod50075`).

No hay migración de datos: la clase nunca llegó a cargarse acá. Ver [[atributos-tipados]].
