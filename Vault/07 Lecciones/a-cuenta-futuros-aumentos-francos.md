---
aliases: ["A cuenta de futuros aumentos: francos (2083)"]
tipo: leccion
tema: francos
tags: [leccion, francos, project]
actualizado: 2026-10-28
---

# A cuenta de futuros aumentos: francos (2083)

Franco empresa menos TODO lo pagado por convenio; implementado con VALOR_FRANCO_ACDO y guarda por categoría, 9/9 al peso

> [!warning] La guarda debe ir sobre el producto precio x días, no sobre el precio solo: con precio cargado y cero días la fórmula paga un importe negativo.

> [!note] Actualización 28/10/2026: `VALOR_FRANCO_ACDO` ya no existe
> El parámetro de empresa hoy es `VALOR_FRANCO_EMP` (`EMP_LAN_175/75_OF02` 3.500, `EMP_CAL_175/75_OF02` 3.500 desde el 5/1, `EMP_175/75_OF04` 2.975). El 2083 ramifica por `TIPOACTIVIDAD` (`'TA'` / `'PO'`). Desde el 1/3/2026 resta sólo la parte del 1053 que corresponde a los días de franco, y desde el 1/4/2026 lleva `MAX(0, …)`. Las fórmulas de abajo son las del 28/9.

Concepto **2083** (`A_CT_FUT_AUM_FR` en Meta4). Aplica sólo a **jefe de máquinas y primer oficial de máquinas de tangoneros**, que tienen un valor de francos de empresa superior al de convenio.

```
a cuenta = (valor EMPRESA del franco × días) − (sueldo de francos + antigüedad)
```

Los valores están **en dólares por mes** (Adriana Sienes, 23/9/2026):

| | empresa | convenio |
|---|---|---|
| Jefe de Máquinas | USD 3.500 | USD 3.000 |
| Primer Oficial de Máquinas | USD 2.975 | USD 2.550 |

Verificado al centavo en el 00406, enero 2026, 4 días de franco y TC 1.415:

```
empresa   3.500 / 30 × 4 × 1.415 = 660.333,33   (= PR_AP_SOL_FTIA de Meta4)
convenio  3.000 / 30 × 1.415     = 141.500/día  (= PR_FRANCO)  × 4 = 566.000
antigüedad                        =  30.000
a cuenta  660.333,33 − 566.000 − 30.000 = 64.333,33  ✓
```

**Por qué:** con un solo recibo parece un importe fijo mensual prorrateado —482.500/30×4 da el mismo número— y esa lectura no sobrevive al segundo caso. **Tampoco es (empresa − convenio) prorrateado**: eso da 94.333 porque ignora que la antigüedad también se descuenta. Lo que se resta es TODO lo pagado por convenio.

Ojo con el tipo de cambio: acá Meta4 usó **1.415**, el comprador, no el vendedor con el que se liquida el resto — ver [[tc-de-marea-no-es-cotizacion]].

Aparte, los que tienen **sindicato centro de patrones** pagan un aporte sindical del **1%**, con la misma base que la cuota sindical.

## Cómo quedó implementado (28/9/2026, commiteado)

Parámetro nuevo **`VALOR_FRANCO_ACDO`** (el valor de EMPRESA, mensual, en **USD**), con dos vigencias
desde el 1/1/2026 y ninguna más:

    VALOR_FRANCO_ACDO_175/75_OF02 = 3500
    VALOR_FRANCO_ACDO_175/75_OF04 = 2975

**OF01 y OF03 quedan sin cargar a propósito.** El CCT de 2083 cubre `175/75` *todas las categorías*
más `ESP`, y un precio de acuerdo no se deduce: se lee del acta. Por eso la fórmula lleva guarda —
sin ella, los 18 empleados de enero con días de franco fuera de OF02/OF04 cobrarían
`0 − franco − antigüedad`, un importe **negativo**:

```
IF(
    VALOR_FRANCO_ACDO * DIAS_FRANCOS_PERIODO = 0,
    0,
    round(
        VALOR_FRANCO_ACDO / 30 * DIAS_FRANCOS_PERIODO * TC_COMPRADOR - (#1063 + #1053),
        PRECISION_REDONDEO
    )
)
```

**La guarda va sobre el producto, y eso no es cosmético.** El 28/9/2026 la escribí sólo como
`VALOR_FRANCO_ACDO = 0` —pensando en los pares sin precio— y **se rompió apenas el precio existió**.
Un concepto que resta lo ya pagado necesita guarda sobre **el driver**, no sobre el precio: con
precio cargado y cero días de franco la fórmula queda en `0 − (franco + antigüedad)` y paga un
importe **negativo**. El testigo es el 00794: 175/75 OF02, precio 3.500 USD, cero días de franco y
232.500 de antigüedad, cobrando **−232.500,00**. Eran 12 líneas por −611.100,00 sólo en enero, todas
de OF02 con antigüedad y sin francos. Un solo producto cubre los dos casos: si falta el precio **o**
faltan los días, paga 0. Ver [[retenido-true-importe-cero]] para el otro concepto que miente con
importe cero, y tenerlo presente al escribir 2013, que tiene la misma forma y todavía no tiene fórmula.

**Se resta `#1063 + #1053` —sueldo de francos más antigüedad— y NO `TOT_HAB_GZDO`.** Es la misma
trampa de [[tot-remun-27617-es-acumulador]] con otra cara: en un recibo que paga sólo el cierre de
francos las dos cosas coinciden, pero si el recibo paga algo más, `TOT_HAB_GZDO` lo arrastra todo.
Mi primer control de dirección usó `TOT_HAB_GZDO` y dio 7 de 9; los 2 que "fallaban" eran los de
**1 día** (04826 y 04921), donde el total traía mucho más que el franco. Con `#1063 + #1053` dan
**9 de 9 al peso**, enero 2026, con 1, 4, 10 y 31 días y las dos categorías.

El TC es `TC_COMPRADOR`, el del comprador — ver [[que-tc-usa-cada-concepto]].

## Relacionado

- [[tc-de-marea-no-es-cotizacion]]
- [[retenido-true-importe-cero]]
- [[tot-remun-27617-es-acumulador]]
- [[que-tc-usa-cada-concepto]]
- [[franco-porcentaje-por-pesqueria]]
- [[francos-fifo-ledger]]
