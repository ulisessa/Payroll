---
tipo: tabla
tags: [modelo-de-datos, integracion-nav, staging, dimensiones]
fuente: [src/Tables/Tab110047.StgValorDimNAV.al, src/Codeunits/Cod110037.AplicarFilaSincNAV.al, src/Codeunits/Cod110036.SincNAVLiq.al]
actualizado: 2026-10-04
---

# Tabla - Stg Valor Dim NAV

**Tabla 110047 `Stg Valor Dim NAV`** (*Staging Valor de Dimensión NAV*). **Datos persistentes** (staging). Patrón común: [[Patrón de las tablas de staging NAV]].

**Propósito.** Los valores de dimensión que usan los proyectos de NAV. Es la **primera entidad que se procesa**: una marea nueva es, por definición, un valor de dimensión que BC todavía no tiene; sin esto cada marea nueva hace fallar el `Job.Validate` de su proyecto y queda en Error todos los meses. El nombre se trae de NAV (allá `V03` es *Villarino III*) en vez de inventarse con el código.

## Clave primaria
`("Cod Dimension","Codigo")`. Secundaria `("Estado Sinc","Cod Dimension","Codigo")`.

## Campos relevantes
| Campo | Propósito |
|---|---|
| `Cod Dimension`, `Codigo` | Dimensión y valor. |
| `Nombre` | Descripción del valor. |
| `Bloqueado` | Se trae para no dar de alta en BC un código ya fuera de uso en NAV; un valor bloqueado en origen se crea **bloqueado** (existe para que los movimientos históricos lo encuentren). |
| 90–95 | Estado de sincronización común. |

## Se aplica sobre
`Dimension Value`. Sólo se trae lo que usan las tres dimensiones que se aplican sobre el proyecto (buque, marea, actividad); el resto del catálogo de NAV no cruza.

## Quién la lee y la escribe
- **Escribe:** `Cod110041.VolcarValoresDim` (si `Entidad Valores Dim` está configurado) o el job SQL.
- **Aplica:** `Cod110037.AplicarValorDimension`.
- **Lee:** página `Sinc. Valores Dim. NAV` (110038).

> [!warning] Sin permisos en los PermissionSets
> A diferencia de las otras ocho tablas de staging, `Stg Valor Dim NAV` **no figura** en `LiqPescaAdmin`, `LiqPescaLiquidador` ni `LiqPescaLectura` (verificado en `src/PermissionSets/`). Un usuario que no sea SUPER y corra la sincronización fallaría con error de permisos sobre esta tabla.

## Trampas
> [!warning] La dimensión tiene que existir
> Si la `Dimension` no existe en BC la fila da Error: crearla toca la configuración contable, no el catálogo de una marea.

- Si el valor ya existe y el nombre difiere, **no se modifica**: la fila queda Procesada con un aviso en `Observacion` (`TxtNombreDistinto`).
- Ver también [[sincronizacion-valores-dimension]] (la "basura" que trae NAV, p. ej. CARPETA IMPORTACION).

## Relacionado
[[Tabla - Stg Proyecto NAV]] · [[Tabla - Entidad Liq]] · [[dim2-nav-actividad-bc-marea]]
