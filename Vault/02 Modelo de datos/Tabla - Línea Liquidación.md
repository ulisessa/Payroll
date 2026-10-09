---
tipo: tabla
tags: [modelo-datos, transaccional, motor, rendimiento]
fuente: [src/Tables/Tab60012.LineaLiquidacion.al]
actualizado: 2026-10-04
---

# Tabla - Línea Liquidación (60012)

## Propósito
Una fila por **concepto calculado** en una [[Tabla - Liquidación]]: lo que se imprime en el recibo y la materia prima de acumulados, francos y controles. Es la tabla más grande y más escrita del cálculo (~45% del tiempo ocupado), por eso su diseño de claves es deliberado.

## El importe lleva su propio signo
`Tipo Concepto` dice **qué es** la línea; el signo dice **para qué lado va**. Haber → suma al neto; Descuento/Retención → resta; Contribución Patronal → lado patronal, fuera del neto; y un importe negativo invierte esa dirección. Antes se guardaba todo positivo (Abs) y existía el tipo "Deducción Remunerativa" (ordinal 7, ya **quemado**, ver [[Enums de liquidación#Tipo Concepto Liq]]).

## PK e índices
| Clave | Campos | Notas |
|---|---|---|
| PK (clustered) | `No. Liquidación`, `No. Línea` | **Sin SumIndexFields a propósito**: una SIFT sobre una clave única crea una fila de vista indexada por línea (104.588) — medido 0 lecturas vs 1.020.888 mantenimientos |
| K2 | `No. Liquidación`, `Es Devengo`, `Tipo Concepto` | **SumIndexFields = Importe**. `Es Devengo` va en el medio porque `UpdateTotals` y `CalcNetoDesdeBD` (Cod50014) filtran siempre por los tres; un `CalcSums` que filtre sin `Es Devengo` no puede usar esta SIFT |
| K3 | `No. Liquidación`, `Orden Cálculo`, `No. Línea` | |
| K4 | `No. Empleado`, `Fecha Liquidación`, `Tipo Concepto` | SumIndexFields = Importe (acumulados) |
| K5 | `No. Empleado`, `Cód. Período`, `Tipo Concepto` | SumIndexFields = Importe |
| K6 | `Cód. Concepto`, `Vigencia Concepto`, `Fecha Liquidación` | "¿esta versión ya se usó, y después de qué fecha?" (`Concepto Liquidación.BuscarUso`). `Estado` queda fuera: se filtra con `<>` y cortaría el rango |
| K7 | `Cód. Concepto`, `No. Empleado`, `Fecha Liquidación` + IncludedFields `Cantidad`, `Importe` | Ledger de francos y acumulados por concepto; reemplazó a un `missing_index` de 357 MB |

> [!danger] No agregar SumIndexFields "por las dudas"
> Cada SIFT es una vista indexada que se mantiene en cada insert/delete del cálculo. Ver [[sift-sobre-clave-unica]] e [[indices-missing-index-nocturnos]] (los `missing_index_*` son nocturnos y a mano).

## Campos (agrupados)
| Grupo | Campos | Propósito |
|---|---|---|
| Identidad | `No. Liquidación` (1), `No. Línea` (2, autoinc.), `Cód. Concepto` (3, **sin TableRelation**), `Descripción Concepto`, `Nombre Impresión` | El código no tiene relación porque el concepto es versionado y se conserva aunque se dé de baja |
| Resultado | `Importe` (7, 2:2), `Cantidad` (13, 0:4), `Unidad Cantidad` (14), `Base Cálculo` (27), `Orden Cálculo` (8), `Tipo Concepto` (6) | `Tipo Concepto` está **desnormalizado**: no reutilizar ordinales quemados |
| Auditoría | `Fórmula Aplicada` (9), `Fórmula Evaluada` (15 "Fórmula con Valores"), `Fuente Parámetros` (11, lista `PARAM|FECHA` separada por `|`), `Vigencia Concepto` (12), `Vigencias Distribución` (31, `ACUMULADOR:AAAAMMDD`) | Permiten reproducir el cálculo. `Vigencias Distribución` cierra el agujero de una fracción cargada con vigencia retroactiva |
| Desnormalizados de cabecera | `No. Empleado` (16), `Cód. Período` (17), `No. Proyecto` (18), `Cód. Tipo Liq.` (30), `Cód. Convenio` (20), `Cód. Categoría` (21), `Estado` (22), `Fecha Liquidación` (23) | Evitan el join con la cabecera. El motor los escribe al crear la línea; `Estado` se sincroniza en aprobar/reabrir (Cod50019) |
| Banderas | `Imprime en Recibo` (24), `Grupo Costo Laboral` (25), `Es Devengo` (26) | Copiadas del concepto |

## Procedimientos
`UnidadParaMostrar()`: unidad concordada con la cantidad ("1 DIA", "9 DIAS", "35.676 KN"). Orden: |cantidad| = 1 no pluraliza; `Unit of Measure."Plural Liq."` si está cargado ([[Extensión - Unit of Measure]]); unidad **sin vocales** (KN, KG, TN) es invariable; termina en vocal → +S, consonante → +ES.

## Triggers
Sólo `OnDelete`: borra los [[Tabla - Detalle Variable Línea Liq]] de esa línea. (La cabecera borra los de todas las líneas de una vez y llama `DeleteAll(false)` — si este trigger hiciera algo más, hay que volver a `DeleteAll(true)`.)

## Quién la lee / escribe
Escribe: `Cod50014.MotorLiquidacion`, `Cod50019.GestionLiquidacion`, `Cod50053.GestionFrancos` (ledger), migración Meta4. Lee: `Cod50016.ContextoLiquidacion` (acumulados mensuales, YTD), `Cod50018`, `Cod50081.ControlMareaLiq`, `Cod110028/29/31/44/55`, `Tab110054 HistLiqMeta4`. Páginas: `Pag50118 Líneas Liquidación`, `Pag50170 Líneas Liq con Variables`, `Pag50175 Acumuladores Liq Sub`.

## Vigencias
Cada línea guarda `Vigencia Concepto`: qué versión de [[Tabla - Concepto Liquidación]] la generó. Impide cerrar esa versión por delante de la línea.

## Trampas conocidas
- Francos como lotes no fungibles sobre estas líneas: [[francos-fifo-ledger]].
- Días sumados donde van pesos (el 1603): [[dias-sumados-donde-van-pesos]].
- Importe bajo sin error = un aporte quedó después de la lectura: [[acumuladores-orden-calculo]].
- SQL directo sobre la tabla: [[sql-directo-deja-cache-rancia]]; rendimiento: [[sift-sobre-clave-unica]].
