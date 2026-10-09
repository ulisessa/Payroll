---
tipo: tabla
tags: [modelo-datos, configuracion, formulas]
fuente: [src/Tables/Tab60014.TablaEscalonadaDet.al]
actualizado: 2026-10-04
---

# Tabla - Tabla Escalonada Det. (60014)

> [!note] Nombre de archivo
> El objeto se llama `Tabla Escalonada Det.` (con punto final). La nota se nombra "Tabla Escalonada Detalle" para evitar el punto antes de la extensión.

## Propósito
Tramos de una versión de [[Tabla - Tabla Escalonada]]: cada fila define un rango y cómo se calcula el importe dentro de él.

## PK e índices
PK `Código`, `Vigencia Desde`, `No. Tramo` (clustered). K2 `Código`, `Vigencia Desde`, `Límite Inferior` (la usa `EvalTramo` para elegir el tramo).

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `Código` (1) | → `Tabla Escalonada.Código` | |
| `Vigencia Desde` (2), `No. Tramo` (3, ≥1) | | Identifican la versión y el tramo |
| `Límite Inferior` (4) | Decimal ≥ 0 | Piso del tramo |
| `Límite Superior` (5) | Decimal ≥ 0 | **0 = sin tope** (último tramo) |
| `Monto Fijo` (6) | Decimal | Acumulado hasta el piso |
| `Porcentaje` (7, "% Sobre Excedente") | Decimal (0:6) | Se aplica a `valor − Límite Inferior` |
| `Descripción` (8) | Text[100] | |

## Triggers
OnInsert/OnModify → `ValidarLimites`: error si `Límite Superior <> 0` y `< Límite Inferior`. **No valida** solapamiento ni huecos entre tramos: eso queda a cargo de quien carga la escala.

## Quién la lee
`Cod50015.EvaluadorFormula` (`EvalTramo`, `DescribirTramo`). Página `Pag50133 Tabla Escalonada Det Sub`.

## Vigencias
Hereda la de la cabecera (la columna `Vigencia Desde` es parte de la PK, sin TableRelation compuesta).

## Trampas conocidas
> [!warning] Sin control de solapamiento
> Dos tramos que cubran el mismo valor: `FindLast` por `Límite Inferior` toma el de piso más alto. Un hueco entre `Límite Superior` de un tramo y `Límite Inferior` del siguiente hace que `TRAMO` falle ("tramo no encontrado") en tiempo de cálculo.
