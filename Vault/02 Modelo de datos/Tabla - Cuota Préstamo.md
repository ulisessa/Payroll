---
tipo: tabla
tags: [modelo-datos, prestamos]
fuente: [src/Tables/Tab50576.CuotaPrestamo.al, src/Codeunits/Cod50051.GestionPrestamos.al]
actualizado: 2026-10-04
---

# Tabla - Cuota Préstamo (50580)

> [!warning] Discrepancia de ID
> El archivo se llama `Tab50576.CuotaPrestamo.al` pero el objeto declara `table 50580 "Cuota Préstamo"`. **Manda el ID declarado: 50580.**

## Propósito
Cada cuota de un [[Tabla - Préstamo Empleado]]: importe, destino (período o liquidación) y estado.

## PK e índices
PK `No. Préstamo`, `No. Cuota` (clustered; `No. Cuota` es AutoIncrement). K2 `No. Liquidación Aplicada`; K3 `Cód. Período`, `Estado`.

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `No. Préstamo` (1) | → `Préstamo Empleado."No."` | |
| `No. Cuota` (2) | Integer autoinc. | |
| `Importe` (3) | Decimal ≥ 0 | |
| `Cód. Período` (4, "Período Destino") | → [[Tabla - Período Liquidación]] | Opcional: se aplica sola cuando se calcula una liquidación de ese período del empleado |
| `No. Liquidación` (5, "Liquidación Destino") | → [[Tabla - Liquidación]] | Opcional: **pisa al período**; la cuota sólo se aplica a esa liquidación. Sin ninguno de los dos, la cuota **no se auto-aplica** |
| `Estado` (6) | Enum [[Enums de liquidación#Estado Cuota Préstamo]] | Pendiente / Aplicada / Anulada |
| `No. Liquidación Aplicada` (7), `Fecha Aplicada` (8) | | No editables; los fija `MarcarCuotasAplicadas` al aprobar |
| `No. Empleado` (9) | FlowField | Lookup al préstamo |

## Triggers
**OnModify**: error si el `Estado` **resultante** es `Aplicada` ("Revertí la liquidación correspondiente primero"). Sólo protege la **edición manual** (páginas, `Modify(true)`): el módulo de préstamos usa `Modify()` sin parámetro, que en AL **no ejecuta triggers**, y por eso `MarcarCuotasAplicadas` (Pendiente → Aplicada) y `RevertirCuotasLiquidacion` (Aplicada → Pendiente) no chocan con él.

> [!note] Guarda frágil
> Quien llame `Modify(true)` sobre una cuota ya Aplicada (o que se vuelve Aplicada) recibirá el error. Es la intención, pero depende de que el módulo de préstamos siga escribiendo sin triggers.

## Quién la lee / escribe
`Cod50051.GestionPrestamos` (`GenerarCuotas`, `AplicarCuotasEnLiquidacion`, `MarcarCuotasAplicadas`, `LimpiarParaRecalculo`, `RevertirCuotasLiquidacion`, `CuotaAplicaALiquidacion`). Página `Pag50182 Cuotas Préstamo Sub`.

## Vigencias
Por período destino, no por vigencia.

## Trampas conocidas
- La incidencia generada lleva `Cód. Cuota Préstamo = "No.Prestamo|NoCuota"` en [[Tabla - Incidencia Liquidación]]; sobre eso se limpia al revertir o recalcular.
- `Anulada` excluye la cuota para siempre.
