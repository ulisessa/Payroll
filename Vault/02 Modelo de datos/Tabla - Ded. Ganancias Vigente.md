---
tipo: tabla
tags: [modelo-datos, ganancias, effective-dating]
fuente: [src/Tables/Tab60021.DedGananciasVigente.al]
actualizado: 2026-10-04
---

# Tabla - Ded. Ganancias Vigente (60021)

## Propósito
Importes de deducción anual publicados por AFIP, por **tipo** y con vigencia. Cada resolución nueva inserta filas nuevas; las viejas se conservan para reliquidar y auditar. Caption: "Tabla Deducciones Ganancias".

## PK
`Código` + `Vigencia Desde` (clustered). FieldGroup DropDown (Código, Descripción, Importe Anual) para que el lookup de `Cód. Tipo` de [[Tabla - Ded. Ganancias Empleado]] muestre de qué deducción se trata.

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `Código` (1) | Code[20] | Tipos estándar: `CONYUGE`, `HIJO_MENOR`, `HIJO_INCAP`, `ASCENDIENTE`, `HERMANO`, `OTROS`; por importe: `PREPAGA`, `HIPOTECA`, `SERV_DOM` |
| `Importe Anual` (4, caption "Importe Acumulado") | Decimal ≥ 0 | Importe **acumulado al período** de vigencia: enero = 1/12 del anual, febrero = 2/12… (mismo criterio que `MNI_ANUAL` y `DESP_4CAT_ANUAL`) |
| `Aplica Cantidad` (5) | Boolean | true = se multiplica por la `Cantidad` declarada (familiares); false = importe fijo cargado en el registro del empleado |

> [!note] Nombres de tipo: documentación vs. enum SIRADIG
> Los códigos de acá (`HIJO_MENOR`, `HIJO_INCAP`) son los del comentario del objeto; la `Edad Máxima Familiar` de [[Tabla - Parámetro]] habla de `HIJO`/`HIJO_INC`. Los enums SIRADIG ([[Enums de liquidación#SIRADIG Parentesco]]) son otra codificación (AFIP). Verificar los códigos reales en datos antes de asumir.

## Triggers
Ninguno.

## Quién la lee
`Cod50016.ContextoLiquidacion` (`CalcDeduccionesGanancias`, vía las relaciones de familiares y [[Tabla - Ded. Ganancias Empleado]]); la referencia [[Extensión - Employee Relative]] (`Cód. Tipo Ded.`). Páginas: `Pag50150 Ded. Ganancias Vigente List`, `Pag50151` card, `PagExt50352 ITManagerRCPayrollExt`.

## Vigencias
Por `Vigencia Desde`; el motor usa la última `<=` fecha de referencia.

## Trampas conocidas
> [!warning] Tener el familiar cargado no deduce Ganancias
> Son tres pares de fechas distintos y sólo uno habilita. Ver [[familiar-alta-impuesto]].

- Detalle por liquidación en [[Tabla - Detalle Ganancias Liq]].
- El grossing-up tapa los errores de Ganancias en el neto: [[grossing-up-tapa-errores]].
