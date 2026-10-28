---
tipo: referencia
tags: [modelo-de-datos, buffers, temporales, meta4, comparador]
fuente: [src/Tables/Tab110057.CompMeta4Buffer.al, src/Tables/Tab110058.CompDetMeta4Buffer.al, src/Tables/Tab110060.MesFiltroLiq.al, src/Tables/Tab50578.TipoLiquidacion.al]
actualizado: 2026-10-04
---

# Buffers temporales - comparador Meta4 y auxiliares

Tablas `TableType = Temporary`. Otros grupos: [[Buffers temporales - control y consulta de liquidaciones]], [[Buffers temporales - francos y antigüedad]].

## Comp. Meta4 Buffer (110057)
- **Para qué:** página `Comparar BC contra Meta4` (110051): contraste por empleado y mes entre lo que liquidó Meta4 y lo que calcula BC. Se arma en memoria **cada vez que se abre**; guardarlo sería guardar una foto que envejece apenas alguien recalcula.
- **PK:** `("No. Empleado", Año, Mes)`; clave `PorDiferencia`.
- **Campos:** tres comparaciones —bruto, descuentos, neto— porque un bruto que coincide no garantiza un neto que coincida:
  - `Importe Meta4` = `TOT_REMUN_27617`, un **acumulador corrido dentro del mes** (el aporte de cada corrida es su valor menos el de la anterior); `Importe BC` = acumulador `REMUNERATIVO_BRUTO` sumado de las liquidaciones del mes; `Diferencia`, `% Diferencia`.
  - `Descuentos Meta4` = `TOT_RETEN` (por corrida, sin patronales), `Descuentos BC` = `Total Descuentos` de la cabecera, `Dif. Descuentos` (**BC − Meta4: un positivo es BC reteniendo de más**, al revés que el bruto).
  - `Neto Meta4` = `LIQUIDO` (por corrida), `Neto BC` = `Neto a Pagar`, `Dif. Neto`.
  - `Liq. en BC` (cuántas liquidaciones entraron; 0 con Meta4 ≠ 0 = mes sin calcular) y `Hay Borrador` (un borrador entra acá pero **no** en los acumuladores del motor, que filtran `Estado <> Borrador`).
- **Por qué no es una migración:** 2026 se conserva como **referencia**, no como insumo (Meta4 siguió siendo producción de enero a julio y BC corrió en paralelo). Cargarlo como historia haría que alimente acumuladores y el mes contaría dos veces al aprobar; por eso los conceptos `HIST_*` vencen el 31/12/2025.
- **Trampas:** sumar `TOT_REMUN_27617` en crudo triplica un mes de tres corridas ([[tot-remun-27617-es-acumulador]]); comparar columna contra total rompe el sindical ([[comparar-columna-contra-total]]). Método: `METODO_COMPARACION_META4_BC.md`.

## Comp. Det. Meta4 Buffer (110058)
- **Para qué:** `Detalle Comp. Meta4` (110052): qué concepto explica una diferencia, al hacer drilldown sobre un mes.
- **PK:** `"No. Línea"`; claves `PorDif` y `PorConcepto` (orden del recibo; la PK deja el mismo concepto en dos lugares: primero todo Meta4 y después todo BC).
- **Campos:** `Cód. Concepto`, `Descripción`, `Columna Meta4`, `Importe Meta4`, `Importe BC`, `Diferencia`, `Origen` (Option: Ambos, Sólo Meta4, Sólo BC, Sin equivalencia).
- **Trampa:** las filas que importan son las de **un solo lado**. `Sin equivalencia` (columna Meta4 con valor cuyo concepto de BC se desconoce) no es lo mismo que `Sólo Meta4` (se sabe el concepto y BC no lo liquidó): mezclarlos hace parecer un defecto del motor lo que es un hueco del mapeo ([[Tabla - Columna Hist. Meta4]]). Las que coinciden se esconden por defecto.

## Mes Filtro Liq. (110060)
- **Para qué:** una fila con un número de mes, **sólo para usarse `TEMPORARY`**, para evaluar el campo `Meses` de [[Tabla - Tipo Liquidación]] (un filtro de BC como `6|12` o `1..6`) dejando que la plataforma aplique el filtro en vez de escribir un parser a mano (que diferiría del de BC justo en los bordes).
- **PK:** `Numero` (Integer). `DataClassification = SystemMetadata`.
- **Quién la usa:** `Tab50578 Tipo Liquidación` (única referencia en el código).

## Relacionado
[[Tabla - Hist. Liq. Meta4]] · [[Tabla - Valor Hist. Meta4]] · [[historia-remuneraciones-migrada]] · [[Índice Modelo de datos (110xxx)]]
