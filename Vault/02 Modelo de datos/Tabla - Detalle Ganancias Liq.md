---
tipo: tabla
tags: [modelo-datos, transaccional, ganancias, recibo]
fuente: [src/Tables/Tab60025.DetalleGananciasLiq.al]
actualizado: 2026-10-04
---

# Tabla - Detalle Ganancias Liq. (60025)

## Propósito
Una fila por **deducción activa** al calcular, más los **pasos de cálculo** que se quieran mostrar en la sección de Ganancias del recibo. Caption: "Detalle Deducciones Ganancias".

## PK y SIFT
PK `No. Liquidación`, `No. Línea` (clustered, `No. Línea` autoincremental). **Sin SumIndexFields a propósito** (igual que [[Tabla - Línea Liquidación]]): 0 lecturas contra 12.208 mantenimientos en 90 h. Si hiciera falta totalizar, la SIFT debe ser por `No. Liquidación` más el campo de corte, no por la PK completa.

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `Tipo` (3) | **Option** `Familiar, Gasto, Paso` | Único campo Option del grupo (no enum) |
| `Código` (4), `Descripción` (5) | | Tipo de deducción / código de concepto |
| `Cantidad` (6) | Decimal (0:4) | Familiar: coeficiente prorrateado `(meses activos/12) × (% custodia/100)` (año completo al 100% = 1,0; alta en junio con 50% = 0,2917). Gasto: 0 |
| `Importe Unit. Anual` (7) | Decimal | Familiar: importe AFIP por familiar ([[Tabla - Ded. Ganancias Vigente]]). Gasto: 0 |
| `Importe Total` (8) | Decimal | Familiar: `Cantidad × Importe Unit.`; Gasto: `Importe Fijo` declarado; Paso: importe del concepto |
| `Orden` (9) | Integer | Orden en el recibo: Familiar/Gasto = 500; Paso = `Orden Cálculo` del concepto |

## Origen de las filas
- **Familiar**: se cuenta desde `Employee Relative` (con `Cód. Tipo Ded.` y fechas activas; ver [[Extensión - Employee Relative]]).
- **Gasto**: [[Tabla - Ded. Ganancias Empleado]] con `Importe Fijo > 0`.
- **Paso**: conceptos con `Etiqueta Det. Ganancias` ([[Tabla - Concepto Liquidación]]) y variables de sistema con `Etiqueta Det. Ganancias` ([[Tabla - Variable Sistema Liq]]).

## Triggers
Ninguno. `CalcDeduccionesGanancias` (`Cod50016`) la escribe durante el cálculo; `DeleteLineas` (`Cod50014`) la borra al recalcular (`BorrarDetalleGanancias`).

## Quién la lee
`Cod110055.PresentacionCalculoLiq` (sección del recibo), `Cod50014`, `Cod50016`.

## Vigencias
No tiene.

> [!warning] Posibles huérfanas al borrar la liquidación
> `Cod50014.DeleteLineas` (recálculo) borra esta tabla y [[Tabla - Resumen Variable Liq]]; en las iteraciones del grossing-up usa `ConservarDeducciones = true` y deja las filas `Familiar`/`Gasto`, borrando sólo los `Paso`. En cambio `Liquidación.OnDelete` (borrar un Borrador) **no** las limpia explícitamente. Sin verificar si otro camino las limpia.

## Trampas conocidas
- [[familiar-alta-impuesto]] (tres pares de fechas), [[grossing-up-tapa-errores]].
