---
tipo: tabla
tags: [modelo-datos, extension, ganancias, familiares]
fuente: [src/TableExtensions/TabExt52002.EmpleadoRelativoLiqExt.al]
actualizado: 2026-10-04
---

# Extensión - Employee Relative (TabExt52002 "Empleado Relativo Liq. Ext.")

Extiende `Employee Relative` (familiares) con lo que Ganancias y las asignaciones necesitan. Es la fuente de las filas `Familiar` de [[Tabla - Detalle Ganancias Liq]].

| Campo | ID | Tipo / relación | Propósito |
|---|---|---|---|
| `Cód. Tipo Ded.` | 50210 | Code[20] → **[[Tabla - Parámetro]]** | Apunta a un **Parámetro** (p. ej. `DED_CONYUGE`), **no** a un concepto ni a un tipo de [[Tabla - Ded. Ganancias Vigente]]: el motor lee el Parámetro Vigente y usa su `Valor` como importe anual (`LoadDeduccionesFamiliares`, `Cod50016`). OnValidate: si hay tipo, hay fecha de alta impositiva y `% Deducción = 0`, lo pone en 100 |
| `% Deducción` | 50213 | Decimal 0–100 (InitValue 100) | Porcentaje de custodia/deducción |
| `Fecha Ingreso Impuesto` / `Fecha Egreso Impuesto` | 50211 / 50212 | Date | **Obsoletos** (Pending): unificados en "Fecha alta / baja (familiar a cargo)" |
| `Tipo Documento` / `Nro. Documento` | 50214 / 50215 | Code[10] / Code[20] | Identifican de forma estable la carga entre importaciones SIRADIG (el nombre puede variar); sirve de clave para reemplazar en lugar de duplicar |
| `Adic. Obra Social` | 50216 | Boolean | Familiar a cargo fuera del grupo habitual para el adicional de obra social (1,5% por cada uno) |

## Detalle importante: lectura por RecordRef de campos de otra extensión
`TieneFechaAltaImpositiva` mira **sólo** el campo 50008 `Fecha alta impuesto` (de la dependencia "Final Version Customization Extension"), leído con `RecordRef.FieldExist(50008)`. No mira `Fecha inicial` (50000, cargada en todo familiar) ni `Fecha alta familiar a cargo` (50010, de asignaciones familiares): cualquiera de las dos daba siempre true. Es la misma cascada que manda en `Cod50016`.

> [!danger] Tener el familiar cargado no deduce
> Hay tres pares de fechas distintos y sólo uno habilita. Ver [[familiar-alta-impuesto]]. La edad máxima (`Edad Máxima Familiar`) vive en el Parámetro del tipo, y sin fecha de nacimiento **no** se aplica.

## Dónde se lee / escribe
`Cod50016.ContextoLiquidacion` (cascada de deducciones), `Cod50048.ProcesadorImportacionSiradig` (cargas de familia, clave documento), `PagExt50354 EmpleadoRelativoLiqExt`. Ver [[Tabla - Importación SIRADIG]] y [[Tabla - Ded. Ganancias Empleado]].
