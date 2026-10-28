---
aliases: ["El tope del SAC se aplica por liquidación"]
tipo: leccion
tema: descuentos-ganancias-sipa
tags: [leccion, descuentos-ganancias-sipa, project]
actualizado: 2026-10-12
---

# El tope del SAC se aplica por liquidación

> [!warning] Falla en silencio
> 4751/4752/4753 topean por liquidación y el tope de SIPA es mensual: la segunda liquidación del mes vuelve a cobrar

Los aportes sobre SAC devengado 4751 (jubilación), 4752 (ley 19032) y 4753 (obra social) topean con
`MIN(base, TOPE_SIPA)` **dentro de cada liquidación**. El tope de SIPA es **mensual y se agota**: si
la liquidación de vacaciones ya aportó sobre los 3.823.372,95 completos, la regular del mismo mes no
debe aportar nada más. BC le vuelve a cobrar sobre su propia base.

**Un solo defecto explica el residuo de los tres casos que miramos en enero de 2026**, y en todos lo
que sobra es exactamente el aporte de la liquidación que corrió segunda:

| | conceptos que sobran | base de más | impuesto |
|---|---|---|---|
| 00406 | 4751 + 4752 + 4753 de la REGULAR | 9.354,72 | **3.274,15** (al 35%) |
| 00291 | 4753 de la REGULAR | 2.374,18 | 451,09 (al 19%) |
| 00191 | 4753 de la REGULAR | 336,18 | 104,22 (al 31%) |

Sólo el 4753 aparece en los tres porque es el único cuyo tope se agotaba con bases chicas; en el
00406, que es grande, los tres llegan al tope. **El 4754 ya no entra en esta lista**: no tiene tope y
con la fórmula nueva da exacto en las dos liquidaciones (ver [[sindical-sac-base-equivocada]]).

**Cómo se verifica que Meta4 agota el tope**: en la corrida de vacaciones su `JUB_SAC_MES` da
35.047,59, que es `3.823.372,95 × 11% / 12` — el tope entero, no su base real — y en la mensual
`JUB_SAC_MES`, `LEY_19032_SAC_MES` y `OBRA_SOCIAL_SAC_MES` **no existen como columnas**, porque valen
cero. BC coincide al centavo en la primera liquidación y difiere sólo en la segunda.

**Arreglado el 2/10/2026** (criterio confirmado por el usuario: el tope se agota en el mes). Las tres
fórmulas pasaron a tomar la base acumulada del mes y restar lo ya aportado:

```
round(MAX(0, MIN(BASE_SS_TRAB + BASE_SS_VAC + PERIODO_BASE_SS_TRAB + PERIODO_BASE_SS_VAC, TOPE_SIPA)
             * PCT_JUB / 100 / 12
         - PERIODO_APORTE_JUB_SAC), PRECISION_REDONDEO)
```

con **siete variables de sistema nuevas**: `PERIODO_BASE_SS_TRAB`, `PERIODO_BASE_SS_VAC`,
`PERIODO_BASE_OS_TRAB`, `PERIODO_BASE_OS_VAC` (todas `PERIODO_ACUM` sobre su acumulador) y
`PERIODO_APORTE_JUB_SAC`, `PERIODO_APORTE_19032_SAC`, `PERIODO_APORTE_OS_SAC` (`PERIODO_CONCEPTO`
sobre 4751/4752/4753). `CalcImportePeriodoPorConcepto` ya hacía justo lo que hacía falta: suma **por
mes** —no por código de período, así una segunda liquidación ve a la primera— y excluye la
liquidación en curso filtrando `No. Liquidación <> FLiqNo`.

Verificado a mano antes de aplicarlo: en el 00291 el 4753 de la REGULAR pasa a
`MIN(4.773.045,87, 3.823.372,95) × 3% / 12 − 6.903,83 = 2.654,60`, **el valor exacto de Meta4**; y en
el 00406 los tres dan cero, que es lo que Meta4 hace al no emitir la columna.

**El reparto entre liquidaciones depende del orden de cálculo** y el total del mes no: quien corre
primero consume el tope. Meta4 corrió vacaciones antes que la mensual, y el Orden del Tipo Liq. de BC
se ha invertido entre recálculos, así que para comparar liquidación por liquidación hay que mirar qué
corrió primero — para Ganancias no importa, porque acumula.

## El 8593 repitió el mismo error el 3/10/2026

Al escribirle la fórmula le puse `MAX(0, BASE_SINDICAL - TOPE_SIPA)` sobre la base de **cada
liquidación**. En 04924, que tiene tres, sólo el cierre de marea supera el tope por sí solo
(12.324.052 − 3.823.372 = 8.500.679 → 255.020,38) y el devengado y la regular quedan debajo y pagan
cero. Meta4 cobra 296.213,86, que es el 3% del excedente del **mes entero**.

Quedó con el patrón de los vecinos, que ya lo hacían bien:

```
IF(PCT_SINDICATO = 'CAP',
   round(MAX(0, BASE_SINDICAL + MES_BASE_SINDICAL - TOPE_SIPA) * PCT_CUOTA_EXT_CAP / 100, PRECISION_REDONDEO)
   - MES_CUOTA_EXT_CAP, 0)
```

con dos variables de sistema nuevas: `MES_BASE_SINDICAL` (`PERIODO_ACUM` sobre `BASE_SINDICAL`) y
`MES_CUOTA_EXT_CAP` (`PERIODO_CONCEPTO` sobre 8593). Da 255.020,38 + 22.923,00 + 18.270,48 =
296.213,86, igual a Meta4.

**Control para la próxima**: de los trece conceptos que usan `TOPE_SIPA`, los doce viejos ya suman
`MES_BASE_SS_TRAB` / `MES_BASE_OS_TRAB`. Cualquier fórmula nueva con `TOPE_SIPA` que **no** sume un
`MES_*` está mal, y se ve con un `LIKE '%TOPE_SIPA%'` sobre las fórmulas.

En estos dos códigos el motor **ignora `Tipo Concepto`**: `PERIODO_ACUM` lee sólo `Cód. Acumulador`
y `PERIODO_CONCEPTO` sólo `Cód. Concepto` (Cod50016:811-814).

## Adicional de obra social del SAC devengado: corregido

Revisión en lectura del 12/10/2026: el 4753 de BC contempla solamente el aporte común
de obra social. Falta el devengo adicional que Meta4 registra como `OB_SOC_ADIC_SAC_MES`.
La fórmula original de Oracle, concepto **5397**, vigente desde 01/12/2023, calcula en
la rama mensual normal `(@6032 + @6037) / 12`, siempre que exista base de SAC mensual.
Lee descuentos reales que ya aplicaron sus topes; no vuelve a consumir un tope virtual.

**Aplicado en ArbuTest el 12/10/2026**, con vigencia única desde 01/01/2026: se configuró
el concepto existente en el catálogo de Meta4 **5397** como devengo en BC, en orden 934,
después de 6032/6037 y antes de 5010,
con fórmula `ROUND((#6032 + #6037) / 12, 0.0001)`, condicionado a base de SAC devengado
distinta de cero y excluyendo LIQ_FINAL y jubilados. Aporta 100 % a SS_SAC_DEV,
GAN_NETA_MES y GAN_NETA_A_DEDUC, como 4753, sin imprimir ni descontar del neto.
Así se conserva el 4753 común y su variable PERIODO_APORTE_OS_SAC: sumar el adicional
dentro del mismo 4753 sin separar su acumulado mensual haría que la segunda corrida
restase también el adicional anterior de la provisión común.

El archivo de enero registra el adicional virtual para tres empleados. La suma de
6032/6037 de BC dividida doce coincide con ese archivo al centavo en los tres.
Uno no presenta diferencia de Ganancias porque no tiene impuesto a retener; los otros
dos sí. El caso investigado queda explicado al aplicar la alícuota marginal a la
deducción omitida. Tras recalcular, ambos casos con impuesto tienen residuos inferiores
a un centavo contra Meta4; el tercero conserva impuesto cero.

`scripts/CrearObraSocialAdicionalSAC.sql` queda en preview por defecto, valida la plantilla,
las fracciones y la precedencia, y crea el concepto, tres fracciones y su alta en el
historial en una transacción. `scripts/AplicarObraSocialAdicionalSAC.ps1 -Aplicar` guarda
respaldo privado en `.snapshots`, aplica la configuración, reinicia BC252 para invalidar
la caché de SQL directo y recalcula el mes completo de cada afectado mediante AL.
No incorpora objetos AL ni cambia la versión de la aplicación. Rechaza configuración
5397 preexistente, liquidaciones aprobadas/contabilizadas y meses posteriores calculados
de los afectados; no sobrescribe ni reabre esos casos.

Se recalcularon cuatro documentos de tres empleados. La comparación del respaldo verificó
que los otros conceptos conservan importes, cantidades, bases y encuadres; sólo cambian
5397, Ganancias y sus acumuladores fiscales. Haberes brutos y estados quedaron iguales;
el ledger de francos quedó idéntico. La condición conserva la exclusión de finales.

La fórmula original también tiene ramas de ajuste, reliquidación y egreso; la configuración
anterior cubre la rama mensual normal. No extrapolar esa rama al cierre anual ni al pago
del SAC real. Para nuevos recálculos, rehacer todo el mes del empleado, no una corrida
aislada. Ver [[conciliacion-enero-vigencias-francos-ganancias]].

## Relacionado

- [[retenido-true-importe-cero]]
- [[sindical-sac-base-equivocada]]
- [[tot-remun-27617-es-acumulador]]
- Tema: `descuentos-ganancias-sipa` (ver [[_Convenciones del vault]])
