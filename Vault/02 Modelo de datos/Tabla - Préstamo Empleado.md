---
tipo: tabla
tags: [modelo-datos, prestamos, anticipos]
fuente: [src/Tables/Tab50575.PrestamoEmpleado.al, src/Codeunits/Cod50051.GestionPrestamos.al]
actualizado: 2026-10-04
---

# Tabla - Préstamo Empleado (50579)

> [!warning] Discrepancia de ID
> El archivo se llama `Tab50575.PrestamoEmpleado.al` pero el objeto declara `table 50579 "Préstamo Empleado"`. **Manda el ID declarado: 50579.** Caption real: "Préstamo / Anticipo". (La numeración 50575–50580 convive con 50578 `Tipo Liquidación`; no hay otra tabla con 50575.)

## Propósito
Cabecera de un **préstamo o anticipo** a un empleado que se descuenta en cuotas a través de una liquidación. No confundir con los anticipos de marea de Meta4 (ANP/ANL/ANH, que son novedades): ver [[anticipos-como-novedades]] y [[anticipos-cta-cte-meta4]].

## PK e índices
PK `No.` (clustered); K2 `No. Empleado`. DropDown: No., Empleado, Nombre, Tipo, Importe Total.

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `No.` (1) | Code[20] | OnInsert: si vacío toma la serie `Human Resources Setup."Cód. Serie Préstamos"` ([[Extensión - Human Resources Setup]]); error si la serie falta |
| `No. Empleado` (2) / `Nombre Empleado` (3) | → `Employee` | OnValidate copia el nombre |
| `Tipo` (4) | Enum [[Enums de liquidación#Tipo Préstamo Emp]] | Anticipo / Préstamo |
| `Fecha` (5) | Date | OnInsert: `Today()` si vacía |
| `Descripción` (6), `Observaciones` (11) | | |
| `Importe Total` (7) | Decimal ≥ 0 | |
| `Cant. Cuotas` (8) | Integer ≥ 1 (InitValue 1) | Las cuotas se generan en `GenerarCuotas` (la última absorbe el redondeo) |
| `Cód. Concepto Descuento` (9) | → `Concepto Liquidación.Código` | Concepto sobre el que se genera la incidencia de descuento. El borrado del concepto se bloquea si algún préstamo lo usa |
| `Total Aplicado` (10) | FlowField | `Sum("Cuota Préstamo".Importe)` con `Estado = Aplicada` |

## Triggers
- **OnInsert**: serie y fecha por defecto.
- **OnDelete**: error si hay cuotas `Aplicada`; si no, borra todas las cuotas.

## Ciclo de vida con la liquidación (`Cod50051.GestionPrestamos`)
`GenerarCuotas` (regenera las pendientes) → `AplicarCuotasEnLiquidacion` (el motor, sólo en Borrador: crea/actualiza [[Tabla - Incidencia Liquidación]] con `Cód. Cuota Préstamo`) → `MarcarCuotasAplicadas` (al **aprobar**) → `RevertirCuotasLiquidacion` (al reabrir o revertir la aprobación). `LimpiarParaRecalculo` corre antes de cada recálculo.

## Quién la lee
`Cod50051.GestionPrestamos`; `PagExt50350 EmployeeCardExt`, `PagExt50356 EmployeeListExt`; [[Tabla - Concepto Liquidación]] (validación de borrado). Páginas: `Pag50180 Lista Préstamos`, `Pag50181 Ficha Préstamo`, `Pag50182 Cuotas Préstamo Sub`.

## Vigencias
No tiene; las cuotas se asignan a un período o a una liquidación concreta ([[Tabla - Cuota Préstamo]]).

## Trampas conocidas
- Los anticipos no son un haber del recibo: [[anticipo-no-es-haber-del-recibo]].
- Un préstamo con cuotas aplicadas no se puede borrar; hay que revertir la liquidación primero.
- Se agrega la categoría `Préstamo` en el registro de procesos ([[Enums de liquidación#Categoría Registro Liq]]).
