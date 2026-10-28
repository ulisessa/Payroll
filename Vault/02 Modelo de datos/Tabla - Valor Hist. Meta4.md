---
tipo: tabla
tags: [modelo-de-datos, meta4, historia, rendimiento]
fuente: [src/Tables/Tab110056.ValorHistMeta4.al, src/Pages/Pag110049.ValoresHistMeta4.al, src/Pages/Pag110051.CompararBCMeta4.al]
actualizado: 2026-10-04
---

# Tabla - Valor Hist. Meta4

**Tabla 110056 `Valor Hist. Meta4`** (*Valores de la Historia Meta4*). **Datos persistentes** — **la tabla más grande del sistema por varios órdenes de magnitud**: ~117 millones de filas (97,6 M valores numéricos y 19,1 M de texto y fecha) contra 485.000 cabeceras.

**Propósito.** Un valor de una liquidación de Meta4 en **forma angosta**: una fila por cada columna que tenía dato (cabecera en [[Tabla - Hist. Liq. Meta4]], definición de la columna en [[Tabla - Columna Hist. Meta4]]). Sólo se guardan los no nulos: una fila de Meta4 tiene ~250 valores de 1.818 columnas, y **un cero ausente significa cero**, no "se desconoce" (misma semántica que la columna ancha de Oracle).

## Clave primaria
`("No. Entrada","No. Columna")` — clustered. Es exactamente el acceso previsto: abrir una liquidación y ver todos sus valores juntos (contiguo en disco: un segundo contra un minuto). **No hay índice por columna a propósito** (costaría ~3 GB y sirve para análisis, no para archivo).

## Campos relevantes
| Campo | Tipo | Propósito |
|---|---|---|
| `No. Entrada` | Integer → `Hist. Liq. Meta4` (`ValidateTableRelation = false`) | |
| `No. Columna` | Integer → `Columna Hist. Meta4` (`ValidateTableRelation = false`) | |
| `Valor` | Decimal (0:5) | Si la columna es Decimal. |
| `Valor Texto` | Text[100] | Si es Texto; también la **hora** de las fechas truncadas (texto ISO). |
| `Valor Fecha` | Date | Campo propio (8 bytes × 117 M ≈ 940 MB) para que una fecha se vea como fecha dentro de diez años. |
| `Nombre Columna`, `Descripción Columna` | FlowFields | Lookups al catálogo. |

## Lógica en triggers
Ninguna.

## Quién la lee y la escribe
- **Escribe:** carga masiva por fuera de AL. *Sin verificar:* el script de carga no está en `scripts/`.
- **Lee:** páginas `Valores Hist. Meta4` (110049), `Comparar BC contra Meta4` (110051), `Detalle Comp. Meta4` (110052).
- **Permisos:** no figura en los PermissionSets (verificado).

## Trampas
> [!danger] Cada campo que se agregue se multiplica por 117 millones
> Un Decimal de más son ~2 GB. Antes de tocar esta tabla, calcular cuánto cuesta el campo. El 70% de cada fila son columnas de sistema de BC (`$systemId`, `$systemCreatedAt`, CreatedBy, ModifiedAt, ModifiedBy y el timestamp: 72 bytes contra ~33 de datos útiles) — ~7 GB de control de cambios que no se pueden desactivar.

> [!danger] Un DATE de Oracle lleva hora y este campo no la admite
> Escribir una fecha con hora **no falla al insertar**: falla la página al renderizarla ("La fecha no es válida") y se cierra entera; una carga puede parecer perfecta (controles de importe en cero) y estar rota. La carga inicial metió 2.200.914 filas así, todas de `FEC_ULT_ACTUALIZACION`; se truncaron a medianoche y la hora quedó como texto ISO en `Valor Texto` (52.000 horas distintas; es un archivo literal). **Toda carga nueva debe truncar del lado de Oracle** (`TRUNC(col)` o `TO_CHAR`). Ver [[oracle-date-lleva-hora]].

- Ver [[sift-sobre-clave-unica]] y [[indices-missing-index-nocturnos]] antes de proponer índices o SumIndexFields sobre esta tabla.
- La clave agrupada sólo sirve para "todos los valores de *una* corrida": para llegar desde empleado/mes hay que pasar por `Hist. Liq. Meta4` (clave `PorEmpMes`) y luego leer por `No. Entrada`.

## Relacionado
[[Tabla - Hist. Liq. Meta4]] · [[Tabla - Columna Hist. Meta4]] · [[oracle-date-lleva-hora]] · [[meta4-number-castea-a-cero]] · [[export-csv-decimal-con-coma]]
