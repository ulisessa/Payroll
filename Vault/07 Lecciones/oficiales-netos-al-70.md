---
aliases: ["Oficiales netos al 70%"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-16
---

# Oficiales netos al 70%

**En una frase:** siete oficiales poteros cobran un neto pactado; el 1534 paga el CCT, el 2003 es el tapón del grossing-up y los 12.750 no son del 1534

Siete oficiales de poteros —**4724, 4868, 4837, 4826, 4921, 4836, 4163**— tienen en
`CONDICIONES OFICIALES POTEROS CAMPAÑA 26.xlsx` un **fijo mensual en USD** con la leyenda *"valores
netos por todo concepto, pago al 70% para prever SAC, vacaciones y francos - a revisar"*. Los otros
—1477, 4649/4766, 2452, 4924, 4455— tienen línea de `TON ENTERO` y *"compara con CCT, paga el
mayor"*, que es otra modalidad. **BC hoy no distingue los dos grupos.**

El 70% **no es un reparto: es un grossing-up hecho a mano**, porque en Meta4 no se podía calcular de
otra forma. En BC la maquinaria ya existe: `ConvergerGrossingUp` ajusta `COMPLEMENTO_GU` hasta que
el neto iguala a `NETO_GARANTIZADO`, y `NETO_GU` es el neto mensual en divisa por empleado (hoy
cargado para cuatro de tierra: 90016, 90212, 90302, 90361).

## Las tres piezas, verificadas contra los recibos de Meta4 de 04724

```
1534 marea 6:  MAX(producción 9.942.332,56 ; CCT 5.400 ×1405/30×22 = 5.563.800) − básicos = 8.561.876,56
1534 marea 7:  CCT 5.400 ×1415/30×7 = 1.782.900 − básicos                                 = 1.202.632,00
```

**El 1534 lee el valor del CCT (`SALARIO_ASEG_CAL`), no el acordado (`USD_MAREA`)**, y hoy BC usa
el acordado: por eso su garantizado sale inflado, le gana a la producción y el premio queda 5,62 M
de más. Los dos recibos dan exacto con el CCT.

**Los 12.750 de `USD_MAREA_04724` son el paquete acordado**, no un insumo del 1534. Al 70% dan
8.925, que es el objetivo del grossing-up.

**El 2003 (A Cta Futuros Aumentos) es el tapón**, no una fórmula. En la exportación de Meta4 el
`A_CTA_MAREA` es idéntico al `TOTAL_VAL_NTO`. Por eso nunca se pudo derivar de una tarifa por días.

El neto cierra solo: `NETO PRORR 9.195.725 − anticipo de llegada 250.000 = 8.945.725`, que es el
importe neto a percibir del recibo.

## El /30 de la planilla es una simplificación

`HF802 6 CLC producción.xlsx`, celda I13: `+H13/30*F13*$C$7`, o sea **USD × 0,7 / 30 × días × TC**
con el 30 **fijo**. Está así para que no haya que tocar la planilla mes a mes. Lo correcto es
dividir por los días reales del mes, y **BC no tiene variable para eso**: hay `DIAS_HAB`,
`DIAS_MAREA`, `DIAS_PUERTO`, pero ninguna de días calendario del mes. Haría falta un `Cód. Cálculo`
nuevo en Cod50016 más su fila sembrada (ver [[variable-sistema-hay-que-sembrarla]]).

## Cuidado al tocarlo

**Arreglar el 1534 solo empeora mucho.** Con el CCT, el 1534 baja a 9.764.508 —exacto— pero el bruto
de 04724 cae de 18.776.947 a 13.155.805 contra un objetivo de 20.706.237. El 1534 y el tapón tienen
que moverse **en el mismo cambio**. Ver [[cuatro-conceptos-sin-disparar]], que es la misma lección
por tercera vez.

Los conceptos mensuales 8542/8543/8593 sí quedaron verificados contra el recibo: caja 879.898,35
(6%), fondo 36.662,43 (0,25%) y extraordinaria 325.247,99 (3% del excedente sobre el TOPE_SIPA).

## Relacionado

- [[precio-puerto-lista-inconsistente]]
- [[produccion-no-se-prorratea]]
- [[produccion-oficiales-poteros]]
- [[que-tc-usa-cada-concepto]]
- [[tc-de-marea-no-es-cotizacion]]
- Tema: `conceptos-haberes` (ver [[_Convenciones del vault]])

## 04724 y 04921 en febrero (15/10/2026)

- **04724 (Primer Oficial de Cubierta, HF802):** el cierre de la marea 7 (1 al 12/2) pagaba 1.782.900 de más: la garantía CCT de los 7 días de enero (5.400 USD × 1.415 / 30 × 7) que el devengado de enero ya había pagado. Meta4 resta ese devengado anterior (`ACUM_PARAM_CCT('DEV_PREV_MAREA', ...)`) y BC no, porque la rama del 1534 que lo hace estaba reservada a quien no tiene neto pactado. En el devengado del 13 al 28/2 faltaba además restar el feriado 1023. Nueva vigencia 2026-02-03 del 1534 sin `NETO_GU_MAREA = 0 AND ES_GROSSING_UP = 0` en la condición. Para quien tiene grossing-up el total lo fija el 2003, así que 04868 sólo cambia el reparto 1534/2003.
- **04921 (Jefe de Máquinas, HF801):** el escalón de febrero (20.000 USD) arranca con la marea 8 (17/2) y no el 1/2: el cierre del 1 al 16/2 de la marea 7 se paga a 17.000 (verificado con el neto de Meta4 + el anticipo). 04836, con el mismo tipo de escalón mensual, cierra con el valor de febrero desde el 1/2, así que no hay una regla general: cada uno se mide contra su cierre. Script: `scripts/Premio1534OficialesNeto.sql`.

## El neto acordado es del mes (04724, 15/10/2026)

Meta4 trata el neto pactado como un objetivo **del mes**: si el cierre ya pagó de más (el premio 1534 supera el objetivo prorrateado y el tapón 2003 queda en cero), el exceso se descuenta del objetivo de la liquidación siguiente. 04724 en febrero: objetivo del mes 12.750 × 1.370 × 0,70 / 30 × 28 = 11.412.100; el cierre pagó 5.388.440 contra 4.873.050 de objetivo (+515.390) y el devengado pagó 6.004.710 en vez de 6.521.200. **Medido en las 33 liquidaciones con `NETO_GARANT` de enero y febrero de los siete oficiales: neto + exclusión − objetivo da cero (±10 pesos) en todas menos en ese cierre**, así que la regla sólo mueve a 04724. Implementado con la variable `EXCESO_NETO_GU_MES` (Cod50016, sembrada en Cod50077) y una vigencia nueva de `NETO_GARANT` desde el 1/2: `… − IF(NETO_GU_MAREA > 0, MAX(0, EXCESO_NETO_GU_MES), 0)`. Sólo se descuenta el exceso, no se reparte un faltante. Script: `scripts/NetoGarantMesAcumulado.sql`. Para que el devengado lea al cierre, éste tiene que estar calculado antes (ver [[tope-sipa-dos-liquidaciones-se-anulan]]).

## Comprobación posterior del complemento (16/10/2026)

La revisión actual de febrero confirma que el cierre y los demás haberes del
devengado del caso con exceso mensual ya coinciden con Meta4. El residuo está
en `2003`: Oracle conserva una entrada original en `M4T_VAL_INCIDENCIA`, mientras
BC obtiene el complemento por grossing-up. Los descuentos derivan de ese cambio
de bruto y BC converge dentro de su tolerancia.

Se conserva la fórmula conforme al criterio del usuario de mantener resultados
razonablemente equivalentes. No ajustar otra vez `1534` ni copiar el `2003` original
sólo para eliminar ese residuo. La planilla expresa el neto final USD como dato;
la diferencia de tratamiento ARS/USD del exceso no explica por sí sola ese dato.
Evidencia y estabilidad en `.snapshots/revision-febrero-03207-04724-20261016/`.

## El 2013 en guardia de puerto: indicador 2041 y subtotal 1990 (15/10/2026)

La fórmula de Meta4 (confirmada por el usuario): `G = asegurado de puerto × TC × días / 30 × (1,4 si el indicador 2041 = 1)`, `H = TOT_HAB_GZDO` (1990 = 1083 + 1023 + 1053, sin el sueldo a órdenes 1073) y `2013 = MAX(0, G − H)` en poteros. Quedó en datos: `2013` resta `(#1083 + #1023 + #1053)` (`scripts/Concepto2013Subtotal1990.sql`) y el factor sale del indicador, migrado como 188 novedades de febrero a junio (`scripts/Indicador2041.sql`: concepto informativo 2041, fuente `IND_GUARDIA_2041` sobre la tabla de novedades, Cantidad 1 por empleado y mes) con `COEF_GUARDIA_PUERTO_175/75` = 1,4 desde el 1/2 (`scripts/Concepto2013Indicador2041.sql`). El formato para cargarlo: período del mes, tipo REGULAR, concepto 2041, Cantidad 1, importe 0, fecha de la incidencia, observación "Meta4 2041".
