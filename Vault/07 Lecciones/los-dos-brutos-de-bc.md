---
aliases: ["Los dos brutos de BC"]
tipo: leccion
tema: controles-auditoria
tags: [leccion, controles-auditoria, project]
actualizado: 2026-10-09
---

# Los dos brutos de BC

`Total Haberes` y `REMUNERATIVO_BRUTO` no son lo mismo, y el comparador mira el segundo

> [!warning] Una liquidación tiene **dos** cifras que se llaman "bruto". El recibo y la cabecera muestran `Total Haberes`, que suma las líneas de tipo haber. El [[Comparador BC vs Meta4]] lee el **acumulador** `REMUNERATIVO_BRUTO` (+ `NO_REMUNERATIVO`). Cuando un concepto entra en una y no en el otro, **el comparador da verde sobre un recibo que está mal**.

El caso: un tripulante con 27 días de enfermedad.

| | |
|---|---|
| `Total Haberes` (cabecera y recibo impreso) | **335.405,60** |
| `REMUNERATIVO_BRUTO` (lo que compara el comparador) | **4.751.877,14** |
| Meta4 | 4.751.877,85 |

El comparador lo daba por bueno —a 71 centavos, que es el *Redondeo* del propio recibo de Meta4— mientras su recibo salía **4,4 millones corto**. La diferencia es un concepto que suma a `Total Haberes` y no aporta al acumulador.

**El control que lo encuentra** es comparar las dos cifras entre sí, sin salir de BC:

```sql
ABS([Total Haberes] - (REMUNERATIVO_BRUTO + NO_REMUNERATIVO)) >= 1
```

En enero de 2026 daba **28 liquidaciones y 27,4 M**. No hace falta Meta4 para correrlo.

## Lo que lo causó: el 4115

`4110 Enfermedad inculpable` y `4115 Descuento días de enfermedad` son **la misma fórmula con el signo cambiado** y la misma condición (`DIAS_ENFERMEDAD > 0`): siempre que dispara uno dispara el otro y se anulan.

En tierra eso es correcto —el recibo de Meta4 muestra las dos líneas por el mismo importe—. En los embarcados **no**: Meta4 les paga la enfermedad y no la descuenta. Se verificó sobre el recibo y sobre las columnas: `ENFERMEDAD` 4.416.471,54, `SUELDO_FRANCO`, antigüedad y categoría superior, y **ninguna columna que descuente**. `AUX_REMUN_27617` da exactamente esa suma.

El reparto no deja lugar a dudas: de los 28 con 4115 en enero, los **27 de 729/15 no lo tienen en Meta4** y el único de 372/04 sí, con sus 27 conceptos 4110 coincidiendo al centavo.

### El arreglo ya estaba al lado

`4743 Descuento días de vacaciones` —el análogo exacto— está restringido por CCT a **130/75, 372/04 y FA**: los tres convenios de tierra. Al 4115 le faltaban esas tres filas. No se tocó ni la fórmula, ni la condición, ni el 4110.

> [!note] Fechar la restricción en 2026 no toca el pasado
> `ResolverCCTAplicaAConcepto` filtra las inclusiones por `Vigencia Desde <= FechaRef` y **si no queda ninguna activa devuelve true** —aplica a todos—. Con las filas desde el 1/1/2026, las liquidaciones de 2024 y 2025 no ven ninguna activa y se comportan igual que antes. El versionado por CCT es independiente del de la fórmula ([[conceptos-tres-vigencias]]).

Medido antes de aplicarlo: de los 27, **26 quedan exactos** contra Meta4 y uno a 1,04.

## Por qué el embarcado tampoco muestra sueldo

En la comparación de un embarcado no aparece el sueldo del lado de Meta4, y no es un error: **Meta4 no usa la columna `SUELDO` para ellos**. Su remuneración sale de `SUELDO_FRANCO`, `ENFERMEDAD`, antigüedad y categoría superior. La columna `SUELDO` es de mensualizados.

## Relacionado

- [[Comparador BC vs Meta4]]
- [[conceptos-tres-vigencias]]
- [[dias-sumados-donde-van-pesos]]
- [[acumuladores-orden-calculo]]
- [[ratio-uniforme-delata-un-parametro]]
