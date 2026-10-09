---
tipo: proceso
tags: [migracion-meta4, comparador, controles-auditoria, conciliacion]
fuente: [METODO_COMPARACION_META4_BC.md, src/Pages/Pag110051.CompararBCMeta4.al, src/Pages/Pag110052.DetalleCompMeta4.al, src/Tables/Tab110057.CompMeta4Buffer.al, src/Tables/Tab110058.CompDetMeta4Buffer.al, src/Tables/Tab110055.ColumnaHistMeta4.al, scripts/CompararEneroMotor.ps1]
actualizado: 2026-10-08
---

# Comparador BC vs Meta4

Método y pantallas para decidir si el motor de BC liquida bien contra lo que pagó Meta4 (producción de enero a julio de 2026; BC corrió en paralelo). Documento fuente del método: `METODO_COMPARACION_META4_BC.md` (raíz del repo). Datos de partida: [[Archivo literal de Meta4 en BC]].

> [!note] Regla que ordena todo
> **Una diferencia no es un hallazgo hasta que se sabe de qué capa viene.** Cuatro capas, y sólo la última es "el motor está mal": **asimetría** (de un lado entra algo que del otro no -> el filtro), **mapeo** (no se sabe contra qué concepto comparar -> el catálogo de columnas), **dato** (falta un parámetro, novedad o estado -> la configuración), **motor** (la fórmula da otro número).

## Los cuatro niveles

```mermaid
flowchart LR
  N0[0 Archivo literal<br/>Hist. Liq. / Valor Hist. Meta4] --> N1[1 Pantalla 110051<br/>por empleado-mes o marea<br/>bruto / descuentos / neto]
  N1 -->|clic en la diferencia| N2[2 Drilldown 110052<br/>concepto por concepto]
  N2 --> N3[3 Recibo PDF de Meta4<br/>pdftotext -table]
```

1. **Pantalla `Comparar BC contra Meta4` (Pag110051)**, tabla temporal `Comp. Meta4 Buffer` (110057, se arma en memoria al abrir; nada se guarda). Filtros: año, mes desde/hasta, marea, *Sólo diferencias*, *Sólo meses que BC calculó*. **Tres pares de importes** (porque un bruto que cierra no garantiza un neto que cierre, y el grossing-up tapa los errores al revés: ver [[grossing-up-tapa-errores]]):

| | Meta4 | BC |
|---|---|---|
| Bruto | `TOT_REMUN_27617` | `REMUNERATIVO_BRUTO` **+** `NO_REMUNERATIVO` (el bruto de Meta4 incluye el acuerdo sindical del Dto 633/18, no remunerativo) |
| Descuentos | `TOT_RETEN` | `Total Descuentos` de la **cabecera** |
| Neto | `LIQUIDO` | `Neto a Pagar` de la cabecera |

2. **Drilldown `Qué explica la diferencia` (Pag110052)**, buffer `Comp. Det. Meta4 Buffer` (110058). `Origen`: **Ambos**, **Sólo Meta4** (el motor no lo liquidó), **Sólo BC** (liquidó de más), **Sin equivalencia** (hay valor en Meta4 y no se sabe qué concepto de BC le corresponde: es un hueco del mapeo, nunca se mezcla con "Sólo Meta4"). Sólo compara columnas `DV`/`RT`/`SS`, salvo las de `Mapeo Verificado`. Si el catálogo (`Clasificación Meta4`, `Cód. Concepto BC`) está vacío **da error** en vez de mostrar "todo Sólo BC" (que se leería como "Meta4 no liquidó nada", lo contrario de la verdad; ya pasó).
3. **Recibo en PDF** (`2026-01/` ... `2026-08/`, nombrados por fecha y tipo: `FRA` francos, `PUE` puerto, `MAR` marea, `EMB` embarcados, `VAC`, `ADM`, `BAJ`). Extraer con `pdftotext -table` (con `-layout` una celda vacía corre las columnas). Índice de enero: `recibos_2026-01_extraidos.tsv`.

## Qué hace que la comparación no mienta

**Simetría** (lo que se excluye de un lado se excluye del otro): fuera de Meta4 la corrida mensual (`TP_IMPUT` 1), la final (14), contribuciones patronales (`CT`), días/cantidades/precios (`D`,`P`,`U`); fuera de BC la liquidación sin proyecto, `Tipo Concepto` = Contribución Patronal / Informativo, `Es Devengo` = sí (SAC 4750-4754 y francos 1062 se provisionan y no están en el recibo) y `Cód. Tipo Liq.` = `HIST_REMUN` (**es** Meta4 importado: compararlo da cero siempre).

**Semántica temporal por columna** (viven en la misma tabla y no se comportan igual):

| Columna | Qué guarda cada corrida | Cómo se agrega |
|---|---|---|
| `TOT_REMUN_27617` | acumulado del mes **hasta ella** | diferencia contra la corrida anterior, en orden de `CONTADOR_LIQ` |
| `TOT_RETEN`, `LIQUIDO` | lo suyo | suma |
| `IG_*` | acumulado del año | máximo |
| `DV`/`RT`/`SS` | lo suyo | suma |

- **No se puede filtrar la marea en la consulta del bruto** (la corrida de la 58 devuelve 58 + 59): se recorren todas las corridas del empleado-mes, se resta contra la anterior y se suman sólo las diferencias de la marea pedida. **No se saltea ninguna corrida** (filtrar anticipos no los saca: los esconde en la siguiente). El corte es por mes entero.
- **La marea sólo existe fila por fila** (`ID_MAREA` agregado da la de la última corrida). El filtro acota **los dos lados a la vez** (BC por proyecto, Meta4 por `No. Marea Meta4`); con marea elegida se excluyen las corridas `TP_IMPUT` 1 y 14 (`EsDeLaMarea`). Acotar uno solo inventa todas las diferencias.
- **La unidad manda sobre el mapeo**: `D` es DÍAS, no descuentos. Un mapeo por nombre dice contra qué comparar; la clasificación dice **si** se puede comparar. De 205 mapeos por nombre, al menos cinco son colisiones (1054 es "Ds vacac deveng mes act" en Meta4 y "Antigüedad mensuales" en BC).
- **El neto de Meta4 excluye la corrida de anticipo** (`TP_IMPUT` 4, 250.000 en 107 empleados en enero): es plata a cuenta que el recibo de BC no paga. El bruto **sí** la conserva (está dentro del acumulado y del bruto de BC). Esto está en el código (Pag110051) y no en el `.md`.
- `Con borrador`: un borrador cuenta acá pero **no** en los acumuladores del motor (`Estado <> Borrador`).

> [!warning] Refrescar borraba los filtros del usuario
> `Cargar()` empieza con un `Reset()` —hace falta, porque un `DeleteAll` con filtros vaciaría sólo
> una parte del buffer— y eso se lleva **todos** los filtros, incluidos los que puso el usuario.
> Refrescar devolvía la lista entera: con dos mil empleados-mes, filtrar un legajo, corregir un
> parámetro y refrescar obligaba a filtrar de nuevo cada vez. Arreglado el 8/10/2026.
>
> La vista se guarda con `GetView()` antes del `Reset()` y se repone con `SetView()` al final —lleva
> también la **ordenación**—. Pero reponerla a secas no alcanza: trae los filtros de las tres
> casillas tal como estaban, así que destildar una no la soltaría. Por eso los **tres campos que
> maneja la página** (`Presencia`, `Liq. en BC`, `Hay Dif. Recibo`) se limpian uno por uno con
> `SetRange` sin valor y recién después se aplica el estado actual de las casillas. Quien agregue
> una casilla nueva tiene que sumar su campo a esa limpieza, o quedará pegada.

## Procedimiento

1. Catálogo poblado. 2. Abrir con año 2026, *Sólo meses que BC calculó* y *Sólo diferencias*. 3. Mirar las **tres** columnas de `% Dif.` (coloreadas por separado). 4. Drilldown y clasificar en una de las cuatro capas. 5. Si es del motor, contra el PDF. 6. Limpiar de arriba hacia abajo (fase -> estado -> asignación).

**Signos** (siempre BC - Meta4): bruto positivo = BC de más (sube el neto); **descuentos positivo = BC retuvo de más = BAJA el neto**; neto positivo = la persona cobraría más con BC.

## Lo que NO es esto
`scripts/CompararEneroMotor.ps1` compara **BC contra BC** (antes/después de un cambio en el motor): hashea fila por fila las 5 tablas de resultado de las 519 liquidaciones de enero 2026 (`Liquidación`, `Línea Liquidación`, `Detalle Variable Línea Liq.`, `Resumen Variable Liq.`, `Detalle Ganancias Liq.`) y guarda `scripts/comparacion-enero-2026/Before.json`/`After.json`. `-Phase Before|After`; **se niega a sobrescribir** una referencia existente y aborta si no encuentra exactamente 519 liquidaciones. Se complementan: la comparación contra Meta4 encuentra el error; el snapshot demuestra que arreglarlo no rompió lo que ya cerraba.

## Límites
Unidad mínima = empleado-mes o empleado-marea (no recibo por recibo). El mapeo por `NOMBRE_CORTO` es parcial (1003 Sueldo = `SAL_BASE`, columna `SUELDO`; por eso las bases de Ganancias salieron de diferenciar acumuladores, no de acá). 2026 es **referencia, no insumo**: nada de esto se escribe en ninguna tabla.

## Casos resueltos con este método (para no re-investigar)
[[diferencias-descuentos-enero]], [[cuota-sindical-deducida-dos-veces]], [[comparar-columna-contra-total]], [[ventana-promedio-ausentismo]], [[antiguedad-no-cuenta-dias-gp]], [[feriado-divide-por-30-fijo]].

> [!warning] Discrepancia código/documentación
> El comentario de `Cargar()` en Pag110051 todavía dice "se toma el MÁXIMO por empleado-mes, no la suma", pero el código resta cada corrida contra la anterior (diferencias). Manda el código. Además el tooltip del bruto de BC sólo menciona `REMUNERATIVO_BRUTO` aunque se suma `NO_REMUNERATIVO`.

## Ver también

[[Buffers temporales - comparador Meta4 y auxiliares]], [[Tabla - Hist. Liq. Meta4]], [[Tabla - Columna Hist. Meta4]], [[Tabla - Valor Hist. Meta4]], [[Archivo literal de Meta4 en BC]].
