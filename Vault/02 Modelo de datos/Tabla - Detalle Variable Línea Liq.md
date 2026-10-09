---
tipo: tabla
tags: [modelo-datos, transaccional, auditoria, motor]
fuente: [src/Tables/Tab60023.DetalleVariableLineaLiq.al]
actualizado: 2026-10-04
---

# Tabla - Detalle Variable Línea Liq. (60023)

> [!note] Nombre de archivo
> El objeto termina en punto (`Detalle Variable Línea Liq.`). La nota omite el punto final.

## Propósito
**Qué variables (y con qué valor) intervinieron en cada línea** de [[Tabla - Línea Liquidación]], más el *snapshot de la escala* cuando se usó `TRAMO`. Es la base de la pantalla "Variables del cálculo" y del detalle de cálculo.

## PK
`No. Liquidación`, `No. Línea`, `Nombre Variable` (clustered). Sin otros índices ni SumIndexFields.

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `No. Liquidación` (1) | → `Liquidación."No."` | |
| `No. Línea` (2) | Integer | Línea de la liquidación |
| `Nombre Variable` (3) | Text[50] | Variable usada |
| `Valor` (4) | Decimal (0:6) | Valor que vio la fórmula |
| `Detalle` (5) | Text[250] | Sólo para filas que no son variable de configuración (hoy, consultas `TRAMO`): en qué tramo cayó la base y con qué fijo/porcentaje |
| `Tabla Tramo` (6), `Base Tramo` (7), `Límite Tramo` (8), `Fijo Tramo` (9), `Porcentaje Tramo` (10), `Vigencia Tramo` (11), `Snapshot Tramo` (12) | | Snapshot de la escala aplicada ([[Tabla - Tabla Escalonada]]); `Snapshot Tramo` = escala conservada |
| `Código Atributo` (13) | Text[100] | Código del atributo usado (para explicar variables derivadas de atributos) |

## Triggers
Ninguno propio. Las **borra** `Línea Liquidación.OnDelete` (las de esa línea) y `Liquidación.OnDelete` (todas con `DeleteAll` directo, sin trigger por línea).

## Quién la lee / escribe
Escribe: `Cod50014.MotorLiquidacion` (variables de la línea, `WriteTramoDetail`). Lee: `Cod110044.DetalleCalculoLinea`, `Cod110055.PresentacionCalculoLiq`. Páginas: `Pag50156 Detalle Variable Línea Sub`, `Pag50159 Variables Cálculo Línea`.

## Vigencias
No tiene; es evidencia del cálculo.

## Trampas conocidas
- Si una liquidación vieja se recalcula con una escala distinta, esto es lo que muestra "lo que se aplicó" ([[Tabla - Tabla Escalonada]]).
- El detalle de la fórmula con valores vive aparte, en `Fórmula Evaluada` de la línea.
