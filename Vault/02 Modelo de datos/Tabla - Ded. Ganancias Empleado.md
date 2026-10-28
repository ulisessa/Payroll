---
tipo: tabla
tags: [modelo-datos, ganancias, effective-dating]
fuente: [src/Tables/Tab60022.DedGananciasEmpleado.al]
actualizado: 2026-10-04
---

# Tabla - Ded. Ganancias Empleado (60022)

## Propósito
Declaraciones de deducción de Ganancias 4ª categoría **por empleado**, versionadas por fecha. Caption: "Deducciones Ganancias del Empleado". Una **versión** es el conjunto de filas con el mismo (`No. Empleado`, `Vigencia Desde`); el motor toma la última versión con `Vigencia Desde <= fecha de referencia`.

## PK e índices
PK `No. Empleado`, `Vigencia Desde`, `Cód. Tipo` (clustered); K2 `No. Empleado`, `Vigencia Desde`.

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `No. Empleado` (1) | → `Employee."No."` | |
| `Vigencia Desde` (2) | Date | |
| `Cód. Tipo` (3) | → [[Tabla - Ded. Ganancias Vigente]]`.Código` | OnValidate: si `Descripción` está vacía la toma de la tabla vigente |
| `Cantidad` (5) | Decimal (InitValue 1) | Cabezas de familia; 1 para tipos de importe fijo |
| `Importe Fijo` (6, "Importe Fijo Anual") | Decimal ≥ 0 | Si **> 0**, pisa el importe de la tabla AFIP (obligatorio para gastos: prepaga, hipoteca, servicio doméstico) |
| `Descripción` (4), `Observaciones` (7) | | |

## Resolución por línea
`Importe Fijo > 0` → se usa; `Importe Fijo = 0` → `Ded. Ganancias Vigente."Importe Anual" × Cantidad`.

## Triggers
Sólo el autocompletado de `Descripción`.

## Quién la lee / escribe
Lee: `Cod50016.ContextoLiquidacion` (`DEDUC_GANANCIAS`, `CalcDeduccionesGanancias`; escribe filas "Gasto" en [[Tabla - Detalle Ganancias Liq]]). Escribe: `Cod50048.ProcesadorImportacionSiradig` (importación SIRADIG, ver [[Tabla - Importación SIRADIG]]) y la página `Pag50152 Ded. Ganancias Empleado Sub`.

## Vigencias
Versiones por `Vigencia Desde` (conjunto completo por fecha, no fila a fila).

## Trampas conocidas
- Los **familiares** no están acá: se cuentan desde `Employee Relative` ([[Extensión - Employee Relative]]) con sus propias fechas; ver [[familiar-alta-impuesto]].
- La base de Ganancias de Meta4 debe reconstruirse con cuidado: [[cuota-sindical-deducida-dos-veces]].
