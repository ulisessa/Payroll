---
tipo: tabla
tags: [modelo-de-datos, auditoria, formulas, conceptos]
fuente: [src/Tables/Tab110002.HistorialFormulaConcepto.al, src/Codeunits/Cod50070.HistorialFormulasLiq.al, src/Pages/Pag110004.HistorialFormulasConcepto.al]
actualizado: 2026-10-14
---

# Tabla - Historial Fórmula Concepto

**Tabla 110002 `Historial Fórmula Concepto`** (caption *Historial de Cambios de Fórmula*). **Datos persistentes.**

**Propósito.** Quién cambió la fórmula o la condición de un concepto, cuándo, y de qué texto a qué texto. No lo cubría nada: el "Historial de Fórmulas" de la ficha lista las **vigencias** del concepto (versionado por fecha), pero editar la fórmula de una vigencia existente sobrescribía el texto sin rastro. El *Change Log* de BC no sirve porque guarda `Text[250]` y una fórmula llega a 2048 caracteres.

## Clave primaria
`"No. Entrada"` (Integer, `AutoIncrement`). Secundarias: `("Cód. Concepto","Vigencia Desde","Fecha Hora")` (la que usa la agrupación), `("Fecha Hora")`, `(Usuario,"Fecha Hora")`.

## Campos relevantes
| Campo | Tipo | Propósito |
|---|---|---|
| `Cód. Concepto`, `Vigencia Desde` | Code/Date | Qué versión se tocó: la clave de [[Tabla - Concepto Liquidación]] es *(Código, Vigencia Desde)*; el historial es por vigencia, no por código. |
| `Fecha Hora` | DateTime | Cuándo **empezó** la sesión de edición. No se toca después: ancla la ventana de agrupación y el orden de la lista. |
| `Última Edición` | DateTime | Último guardado dentro de la misma sesión. |
| `Usuario` | Code[50] | Quién editó. |
| `Tipo Cambio` | Enum `Tipo Cambio Fórmula` | Alta, Modificación, Eliminación, Formato, Orden. |
| `Fórmula Anterior/Nueva`, `Condición Anterior/Nueva` | Text[2048] | Textos completos. |
| `Cambió Fórmula`, `Cambió Condición` | Boolean | Qué parte cambió. |

`ResumenCambio()` devuelve `Fórmula Anterior` si es Eliminación, si no `Fórmula Nueva` (texto corto para la grilla).

Para tipo **Orden**, `Fórmula Anterior/Nueva` contienen las expresiones completas del **orden de
cálculo**. `ResumenCambio()` lo rotula explícitamente y la ficha muestra una sección de orden.
`RegistrarCambioOrden` crea una entrada independiente, sin campos nuevos ni agrupación con ediciones
de importe. El método de restauración rechaza ese tipo; revertirlo requiere una nueva vigencia.

## Lógica en triggers
Ninguna en la tabla. La lógica vive en `Cod50070 Historial Fórmulas Liq.`, llamado desde los triggers de `Concepto Liquidación`: `RegistrarAlta`, `RegistrarModificacion`, `RegistrarFormato`, `RegistrarBaja`, `Restaurar`.

## Quién la lee y la escribe
- **Escribe:** `Cod50070` solamente.
- **Lee:** páginas `Historial Fórmulas Concepto` (110004), `Ficha Cambio Fórmula` (110005) y la ficha `Concepto Liq. Card` (50145).

## Vigencias
No es effective-dated; *registra* sobre qué vigencia del concepto se editó.

## Trampas
> [!warning] Agrupación en ventana de 15 minutos
> Las ediciones sucesivas del mismo usuario, sobre la misma vigencia, tipo Modificación, dentro de 15 minutos del `Fecha Hora` de inicio (`VentanaAgrupacion`) se funden en una sola entrada. Si la edición vuelve al texto original, la entrada **se borra** (ya no documenta ningún cambio). Es deliberado: el editor con IntelliSense guarda mientras se escribe.

> [!warning] xRec no sirve como "texto anterior"
> Desde el editor add-in el `Modify` llega con `xRec.Fórmula = Rec.Fórmula`; por eso `RegistrarModificacion` lee el texto anterior de la base. Ver [[xrec-no-confiable-con-addin]].

- `Restaurar` no funciona sobre entradas de tipo Alta (no hay texto previo) y su propio efecto queda registrado como otro cambio.
- Si la vigencia ya no existe, `Restaurar` corta con error.

## Relacionado
[[Tabla - Concepto Liquidación]] · [[conceptos-tres-vigencias]] · [[xrec-no-confiable-con-addin]] · [[Índice Modelo de datos (110xxx)]]
