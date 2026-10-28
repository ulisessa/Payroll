---
tipo: tabla
tags: [migracion-meta4, historia, archivo, tablas]
fuente: [src/Tables/Tab110054.HistLiqMeta4.al, src/Tables/Tab110055.ColumnaHistMeta4.al, src/Tables/Tab110056.ValorHistMeta4.al, src/Pages/Pag110047.HistoriaLiqMeta4.al, src/Pages/Pag110048.FichaHistLiqMeta4.al, src/Pages/Pag110049.ValoresHistMeta4.al, src/Pages/Pag110050.ColumnasHistMeta4.al]
actualizado: 2026-10-04
---

# Archivo literal de Meta4 en BC

Tres tablas guardan **la historia de liquidaciones de Meta4 tal como quedó**, para poder abrir un recibo de 2003 cuando ANSES pide una certificación de servicios, cuando llega una demanda, y para que **Meta4 se pueda apagar**. Es un **archivo literal**: no se interpreta, no se traduce a conceptos de BC y **no lo lee el motor de cálculo**.

> [!danger] Nada de acá alimenta el cálculo
> La historia que BC *sí* usa (promedios de vacaciones, ausentismo, base de Ganancias) vive en `Liquidación` + `Línea Liquidación`, como liquidaciones de tipo `HIST_REMUN` ([[historia-remuneraciones-migrada]]). Mezclar las dos estructuras fue la primera idea y es la que hay que evitar: una necesita los bytes originales, la otra códigos de concepto de BC. Si algún dato del archivo debiera alimentar un cálculo, el camino es cargarlo como línea con su concepto, no enseñarle al motor a leer este archivo.

## Las tres tablas

| Tabla | Rol | Volumen | Clave |
|---|---|---|---|
| **110054 `Hist. Liq. Meta4`** | Cabecera: una corrida de liquidación | ~485.000 | `No. Entrada` (sustituto entero; la natural de Meta4 son 5 campos) |
| **110055 `Columna Hist. Meta4`** | Catálogo de las ~1.818 columnas de `M4T_ACUMULADO_RL`..`RL5` | ~1.818 | `No.`; único `(Tabla Origen, Nombre Columna)` |
| **110056 `Valor Hist. Meta4`** | Detalle **angosto**: una fila por columna *con dato* | ~117 M (97,6 M numéricos + 19,1 M texto/fecha) | `(No. Entrada, No. Columna)` agrupada |

Por qué no se replicaron las cinco tablas anchas: `M4T_ACUMULADO_RL` a `RL5` comparten PK; son **una fila partida en cinco** porque Oracle no admite más de 1.000 columnas. Sumadas dan 1.818 y en SQL Server no entran (límite 1.024 columnas; ~31 KB por fila contra 8.060 bytes). Y el 86% de la forma ancha son ceros: una fila tiene ~250 valores no nulos de 1.759 numéricas. **Un cero ausente = cero**, no "se desconoce".

### 110054 `Hist. Liq. Meta4` - campos clave
`No. Empleado` (no se valida contra `Employee`: hay 31 años y gente que ya no está), `Fecha Alta Empleado` (parte de la clave en Meta4: un reingreso es otra serie), `Fecha Imputación` (mes), `Fecha Pago`, **`Tipo Imputación`** (`TP_IMPUT` crudo: 1 = la mensual, 3 = vacaciones, 4 = anticipos, 14 = liquidación final, 99 = indemnizaciones puras; **el significado se dedujo perfilando qué columnas vienen en no-cero**, Meta4 no expone dominio), **`Contador Liq.`** (`CONTADOR_LIQ`, **el orden real de las corridas**, que no coincide con la fecha), `Cód. Convenio Meta4` (códigos de Meta4 `MR, OF, FA, CA, FE, EC`, sin traducir), `Cód. Empresa Meta4`, `Año`/`Mes` (derivados y guardados para el índice), `Cód. Buque Meta4` (`A28`, `HF801`), `No. Marea Meta4`. Claves: `PorEmpleado`, `PorFecha`, `PorAnio (Año, Mes)`, `PorMarea`, `PorEmpMes (Empleado, Año, Mes, Contador)`. Apellido y nombre son FlowFields contra `Employee`.

### 110055 `Columna Hist. Meta4` - el catálogo
Existe para que el detalle guarde un entero en lugar de `'TOT_REMUN_27617'` (ahorra ~2 GB sobre 117 M de filas). Campos: `Tipo Dato` (Decimal/Texto/Fecha: lo declara el catálogo, no cada fila), `Descripción` (a mano), `Filas con Valor` (cuáles de las 1.818 se usaron de verdad), y los campos que usa el [[Comparador BC vs Meta4]]:

| Campo | Qué es |
|---|---|
| `Cód. Concepto BC` | Equivalencia **decidida por nosotros**, "una ayuda para comparar, no una autoridad" (reconstruir importes desde ella dio 25% bajo). |
| `Cód. Concepto Meta4` | El `ID_CONCEPTO` de `M4SYS_CONCEPTOS` cruzado por `N_ACUMULADO` (dato de Meta4 tal cual; encontró 12 columnas que el mapeo por nombre no tenía, entre ellas `SUELDO` -> 1003 y `PR_FRANCO` -> 1062). Van separados para ver dónde la equivalencia se aparta del dato. |
| `Clasificación Meta4` | `DV` devengos, `RT` retenciones al empleado, `SS` seguridad social (**los importes**); `CT` contribuciones patronales; `D`/`P`/`U` días, precios, unidades; `AX` auxiliares; `O`/`RS` procesos internos. De 1.646 columnas con datos, **420** son importes. |
| `Mapeo Verificado` | La equivalencia se **comprobó aritméticamente** (p. ej. `BSAC_MES_RG3976` -> 4750: el incremento mensual de `IG_TOT_C_IM_ST` es `TOT_REMUN_27617 + BSAC_MES_RG3976` al centavo). |

### 110056 `Valor Hist. Meta4` - la tabla más grande del sistema
Tres campos de valor (`Valor` decimal, `Valor Texto`, `Valor Fecha`); `Nombre Columna` y `Descripción Columna` son FlowFields. **Cualquier campo que se agregue se multiplica por 117 millones** (un Decimal son ~2 GB): calcular el costo antes de tocarla. El 70% de cada fila son columnas de sistema de BC (72 bytes contra ~33 útiles; ~7 GB). **No hay índice por columna** a propósito (~3 GB; sirve para análisis, no para archivo): si aparece la necesidad, que sea decisión con el número a la vista.

> [!warning] Un `DATE` de Oracle lleva hora
> `Valor Fecha` no la admite: la inserción no falla, falla la **página al abrir** ("La fecha no es válida"). La carga inicial metió 2.200.914 filas así (`FEC_ULT_ACTUALIZACION`), truncadas a medianoche con la hora conservada como texto ISO en `Valor Texto` (52.000 horas distintas). Cualquier carga nueva trunca del lado de Oracle ([[oracle-date-lleva-hora]]).

## Páginas

| Pág. | Nombre | Uso |
|---|---|---|
| 110047 | `Historia Liq. Meta4` (lista, `UsageCategory = History`) | Navegar el archivo; acciones *Valores* y *Catálogo de columnas*. |
| 110048 | `Ficha Hist. Liq. Meta4` | Una corrida, con su subpágina de valores. |
| 110049 | `Valores Hist. Meta4` (ListPart) | Los valores de la corrida. |
| 110050 | `Columnas Hist. Meta4` | Catálogo, ordenado por `Filas con Valor` desc. |

## Cómo se cargó
**No hay script de carga en el repositorio.** Se cargó desde Meta4 por fuera del repositorio (con el puente de [[meta4-conectar-desde-powershell]], según la memoria del proyecto; el mecanismo exacto no está versionado) y los datos de 2026 **no se cargaron como historia** a propósito: duplicarían el mes en los acumuladores en cuanto se aprueben las liquidaciones de BC ([[Comparador BC vs Meta4]]). Si se corrigen filas por SQL directo hay que reiniciar el service tier ([[sql-directo-deja-cache-rancia]]: un `UPDATE` de `Cód. Concepto BC` en el catálogo dejó el drilldown comparando contra el concepto viejo).

Las tres tablas **no declaran `DataPerCompany = false`**, o sea que son **por empresa** (verificado leyendo los `.al`): con 117 M de filas, una segunda empresa duplicaría el archivo.

## Ver también

Una nota por tabla: [[Tabla - Hist. Liq. Meta4]], [[Tabla - Columna Hist. Meta4]], [[Tabla - Valor Hist. Meta4]]. Buffers del comparador: [[Buffers temporales - comparador Meta4 y auxiliares]]. Uso: [[Comparador BC vs Meta4]].
