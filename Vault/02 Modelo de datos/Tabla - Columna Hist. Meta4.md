---
tipo: tabla
tags: [modelo-de-datos, meta4, historia, catalogo]
fuente: [src/Tables/Tab110055.ColumnaHistMeta4.al, src/Pages/Pag110050.ColumnasHistMeta4.al, src/Pages/Pag110051.CompararBCMeta4.al]
actualizado: 2026-10-04
---

# Tabla - Columna Hist. Meta4

**Tabla 110055 `Columna Hist. Meta4`** (*Columnas de la Historia Meta4*). **Datos persistentes** (catálogo, ~1.818 filas).

**Propósito.** Una fila por cada columna de `M4T_ACUMULADO_RL` a `RL5`. Existe para que el detalle ([[Tabla - Valor Hist. Meta4]]) guarde un entero en vez del nombre de la columna: sobre ~117 millones de filas, `'TOT_REMUN_27617'` en texto en lugar de un Integer cuesta ~2 GB. Además es la **pieza clave del comparador** BC–Meta4: acá vive la equivalencia (verificada o no) con los conceptos de BC.

## Clave primaria
`"No."` (Integer). Secundarias: `PorNombre ("Tabla Origen","Nombre Columna")` **Unique**, `PorUso ("Filas con Valor")`.

## Campos relevantes
| Campo | Tipo | Propósito |
|---|---|---|
| `Tabla Origen` | Code[30] | M4T_ACUMULADO_RL, RL2…RL5. El nombre de columna **no es único** entre las cinco. |
| `Nombre Columna` | Code[50] | |
| `Tipo Dato` | Option Decimal/Texto/Fecha | Dice cuál de los tres campos de valor del detalle está cargado; lo declara el catálogo, no cada fila. |
| `Descripción` | Text[100] | Se llena a mano sólo para las columnas que importan. |
| `Filas con Valor` | Integer | Cuántas filas del detalle usan la columna (se calcula una vez al migrar): de las 1.818, cuáles se usaron de verdad. |
| `Cód. Concepto BC` | Code[20] → `Concepto Liquidación` (`ValidateTableRelation = false`) | **Equivalencia decidida por nosotros**: ayuda para comparar, no autoridad. Sale de `M4SYS_CONCEPTOS` (ID_CONCEPTO ↔ NOMBRE_CORTO). |
| `Cód. Concepto Meta4` | Code[20] (no editable) | El `ID_CONCEPTO` de Meta4 para la columna, cruzado por `N_ACUMULADO`; es el dato de Meta4 tal cual. Normalmente coincide con el de BC; **si difieren es una decisión** y conviene que esté a la vista. |
| `Mapeo Verificado` | Boolean | Equivalencia **comprobada**, no deducida del nombre. Marcada, la columna entra en la comparación aunque su clasificación no sea de importe. |
| `Clasificación Meta4` | Code[10] | `ID_CLASIFICACION`: DV devengos, RT retenciones, SS seguridad social (los tres = **importes**); D = **días y unidades**; P precios unitarios; U horas/cantidades; CT contribuciones patronales; C créditos/anticipos; AX auxiliares; O, RS procesos internos. |

## Lógica en triggers
Ninguna.

## Quién la lee y la escribe
- **Escribe:** carga masiva (migración) y la edición a mano de `Descripción`, `Cód. Concepto BC`, `Mapeo Verificado` en la página `Columnas Hist. Meta4` (110050).
- **Lee:** `Valor Hist. Meta4` (FlowFields), páginas `Comparar BC contra Meta4` (110051) y `Detalle Comp. Meta4` (110052).
- **Permisos:** no figura en los PermissionSets (verificado).

## Trampas
> [!danger] La "D" son DÍAS, no descuentos
> Incluir las D en una comparación de importes pone `27` al lado de `2.493.907,25`. `DIAS_ALTA` suma 9.958 para 330 empleados (30 días cada uno). Los descuentos al empleado son **RT**. De las 1.646 columnas con datos sólo 420 son DV/RT/SS; sin este filtro el drilldown mostraba 1.199 filas de ruido.

> [!warning] No marcar un mapeo automático sin comprobarlo
> De los 205 que salieron por nombre, al menos cinco son colisiones reales: 1054 es "Ds vacac deveng mes act" en Meta4 y "Antigüedad mensuales" en BC. `NOMBRE_CORTO` no siempre coincide con la columna física (1003 Sueldo tiene `SAL_BASE` y la columna se llama `SUELDO`); cruzando por `N_ACUMULADO` se resolvieron doce (entre ellas SUELDO→1003 y PR_FRANCO→1062).

> [!warning] Mapear no es migrar
> Reconstruir importes desde este mapeo dio 25% bajo; por eso las bases de Ganancias salieron de **diferenciar los acumuladores propios de Meta4**, no de acá. Si BC necesita calcular con un dato de esta tabla, el camino es cargarlo como línea en `Línea Liquidación` con su concepto, no enseñarle al motor a leer el archivo.

- Equivalencias verificadas aritméticamente en AX/vacío: SAC devengado `BSAC_MES_RG3976 → 4750` (el incremento mensual de `IG_TOT_C_IM_ST` es exactamente `TOT_REMUN_27617 + BSAC_MES_RG3976`).

## Relacionado
[[Tabla - Hist. Liq. Meta4]] · [[Tabla - Valor Hist. Meta4]] · [[Tabla - Concepto Liquidación]] · [[comparar-columna-contra-total]] · [[tot-remun-27617-es-acumulador]] · [[historia-remuneraciones-migrada]]
