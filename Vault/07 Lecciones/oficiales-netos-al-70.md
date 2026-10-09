---
aliases: ["Oficiales netos al 70%"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-04
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
