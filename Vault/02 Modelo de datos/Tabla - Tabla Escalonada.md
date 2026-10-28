---
tipo: tabla
tags: [modelo-datos, configuracion, effective-dating, formulas]
fuente: [src/Tables/Tab60013.TablaEscalonada.al, src/Codeunits/Cod50015.EvaluadorFormula.al]
actualizado: 2026-10-04
---

# Tabla - Tabla Escalonada (60013)

## Propósito
Cabecera de una **tabla de tramos** (escala de retención de 4ª categoría, topes de seguridad social, etc.). Cada par (`Código`, `Vigencia Desde`) es una **versión completa e inmutable**: para actualizarla se inserta una cabecera nueva y sus tramos con una `Vigencia Desde` posterior. El detalle está en [[Tabla - Tabla Escalonada Detalle]].

## PK
`Código` + `Vigencia Desde` (clustered).

## Campos
`Código` (Code[20]), `Vigencia Desde`, `Descripción` (los tres NotBlank), `Cant. Tramos` (FlowField: `Count("Tabla Escalonada Det.")` de esa versión).

## Triggers
`OnDelete`: `DeleteAll(true)` de los tramos de esa versión.

## Quién la lee
Sólo el evaluador de fórmulas: función **`TRAMO(código, valor)`** en `Cod50015.EvaluadorFormula` (`EvalTramo`):
1. Busca la cabecera con `Vigencia Desde <= fecha de referencia` (`FindLast`) y la cachea por código.
2. En el detalle toma el tramo con `Límite Inferior <= valor` y (`Límite Superior = 0` o `>= valor`).
3. Resultado = `Monto Fijo + (Porcentaje/100) × (valor − Límite Inferior)`.
4. Valor ≤ 0 devuelve 0 (y lo registra en el log de la línea).
Sin tabla vigente: error (en modo tolerante devuelve 0); sin tramo para el valor: error (tolerante o modo validación: 0). El detalle de qué tramo cayó se guarda en [[Tabla - Detalle Variable Línea Liq]] (campos `*Tramo`).

Páginas: `Pag50131 Tabla Escalonada List`, `Pag50132` card, `Pag50133` subpágina de detalle.

## Vigencias
Versión completa por fecha; el motor usa la última `<=` fecha de referencia (la de la liquidación, no `Today`).

## Trampas conocidas
- Una fórmula con `TRAMO` que devuelve cero es justamente el caso que se mira en el detalle; por eso se loguea incluso con base cero.
- Al recalcular una liquidación vieja con una escala posterior retroactiva, el snapshot de la línea (campo `Snapshot Tramo`) es lo que permite mostrar lo que se aplicó; en modo "histórico" el evaluador no recalcula la escala ("No se conservó la escala aplicada a esta base").
- Ver [[tope-sac-por-liquidacion]] para topes por liquidación y [[acumuladores-orden-calculo]].
