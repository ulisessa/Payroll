---
tipo: tabla
tags: [modelo-datos, extension, recibo]
fuente: [src/TableExtensions/TabExt110033.UnidadPluralExt.al]
actualizado: 2026-10-04
---

# Extensión - Unit of Measure (TabExt110033 "Unidad Plural Liq.")

Extiende `Unit of Measure` con el **plural para el recibo**.

| Campo | ID | Tipo | Propósito |
|---|---|---|---|
| `Plural Liq.` (caption "Plural (recibo)") | 52020 | Code[20] | Cómo se escribe la unidad cuando la cantidad no es 1. En blanco se deriva solo |

## Por qué en la unidad y no en el concepto
Es propiedad de la unidad, no de para qué se la usa; los conceptos, las [[Tabla - Incidencia Liquidación]] y las novedades apuntan a la misma tabla. Se carga una vez y lo heredan todos.

## Regla de derivación
La implementa `Línea Liquidación.UnidadParaMostrar()` ([[Tabla - Línea Liquidación]]): |cantidad| = 1 → singular; si `Plural Liq.` está cargado → ese; si la unidad no tiene vocales (KN, KG, TN) → invariable; termina en vocal → +S; en consonante → +ES (DIA→DIAS, MES→MESES). El campo es la **excepción** (irregulares, abreviaturas con punto), no el mecanismo: si fuera obligatorio, cada unidad nueva saldría vacía en el recibo.

## Dónde se edita
`PagExt110032 UnidadesMedidaExt` (página de unidades de medida).

> [!note] Numeración
> El archivo/objeto es 110033 (rango 110xxx) pero el campo usa 52020. Es el único tableextension del rango 110xxx de este grupo.
