---
tipo: tabla
tags: [modelo-datos, configuracion, formulas, variables]
fuente: [src/Tables/Tab60029.FiltroFuenteDatosLiq.al, src/Codeunits/Cod50016.ContextoLiquidacion.al]
actualizado: 2026-10-04
---

# Tabla - Filtro Fuente Datos Liq. (60029)

> [!note] Rango de IDs
> Es la **última** tabla del rango 60xxx: la licencia corta en 60029 ([[rangos-licencia-objetos]]).

## Propósito
Un filtro (campo + valor) aplicado al resolver una [[Tabla - Fuente Datos Liquidación]]. Reemplazó a los tres pares fijos `No. Filtro n`/`Filtro Valor n`: permite **filtros ilimitados**.

## PK
`Nombre Variable` + `No. Línea` (clustered). `No. Línea` es AutoIncrement.

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `Nombre Variable` (1, caption "Fuente Datos") | → `Fuente Datos Liquidación."Nombre Variable"` | |
| `No. Línea` (2) | Integer autoinc. | |
| `No. Campo` (3) | Integer | OnValidate: debe existir en la tabla (`Id. Tabla`) de la fuente |
| `Filtro Valor` (4) | Text[250] | Literal, expresión de filtro de BC, o **token** |

## Tokens soportados en `Filtro Valor` (según el comentario del objeto)
`{EMP_NO}`, `{JOB_NO}`, `{PERIODO}`, `{PERIODO_DESDE}`, `{FECHA_REF}`, `{LIQ_NO}`, `{MONEDA}`, `{SEM_DESDE}`, `{SEM_HASTA}`, `{ASIG_DESDE}`, `{ASIG_HASTA}` (alta y baja del tripulante en la marea, acotadas al período), `{MAREA_DESDE}`, `{MAREA_HASTA}` (zarpada y arribo del proyecto, sin recortar). El reemplazo se hace en `Cod50016.ContextoLiquidacion`.

> [!warning] Sin verificar
> El listado de tokens sale del comentario del archivo de la tabla; no se auditó una por una contra el reemplazo en `Cod50016`.

## Triggers
Sólo la validación de `No. Campo`. El borrado en cascada lo hace la fuente padre (`OnDelete`) y la limpieza al cambiar `Id. Tabla`.

## Quién la lee
`Cod50016.ContextoLiquidacion`; las escribe `Tab60015` (`CopiarEn`, limpieza) y `Pag50178 Filtro Fuente Datos Liq Sub`.

## Vigencias
No tiene; el filtro puede referirse a la fecha de referencia con el token.

## Trampas conocidas
- Un campo con token mal escrito no filtra como se espera y la fuente devuelve 0: ver [[fuente-datos-apunta-por-numero]].
- Cuidado con copiar filtros entre registros: `CopyFilters` copia sólo el grupo actual ([[copyfilters-solo-grupo-actual]]).
