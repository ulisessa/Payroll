---
aliases: ["Lote con tipo de liq. en blanco"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, feedback]
actualizado: 2026-10-04
---

# Lote con tipo de liq. en blanco

**En una frase:** crear o calcular sin elegir tipo corre los tipos marcados "Entra en Corrida Completa"; que fueran todos los activos duplicó 2.748 liquidaciones con importe

En `Proceso Liq. por Lotes`, dejar el **tipo de liquidación en blanco** significa "todos los
tipos que tengan marcado **`Entra en Corrida Completa`**, en su `Orden`" — al crear y al
calcular. **No alcanza con `Activo`**: activo dice que el tipo existe y se puede usar a mano;
el campo nuevo dice que corresponde dispararlo solo todos los meses.

**Por qué:** cuando el blanco pasó a significar "todos los activos", los ocho tipos lo estaban, y
enero de 2026 terminó con **3.604 liquidaciones donde iban ~520**: 687 de AGUINALDO, 687 de
LIQ_FINAL, 687 de RELIQUIDACION y 687 de SALDO_INICIAL. Y **no salieron vacías** — que era lo
que yo esperaba —, salieron con importes, porque **185 conceptos activos no declaran
`Tipos Liq. Aplicables` y por lo tanto aplican a todos**.

El síntoma apareció lejos de la causa: el comparador suma todas las líneas del empleado-mes,
así que el bruto de BC dio **29% arriba** del de Meta4 y el adicional art. 33 salió **×5
exacto**. Parecía una fórmula rota. El 04918 tenía 15 liquidaciones en enero y sólo una era la
buena — su `CIERRE_MAREA` daba 7.303.318,63, clavado contra Meta4.

**Cómo aplicarlo:** un importe que sale multiplicado por un entero chico y exacto (×5, ×3) casi
nunca es la fórmula: es la misma cosa contada varias veces. Antes de mirar la fórmula, contar
cuántas liquidaciones tiene el empleado en el período.

**Y para limpiar no sirve el SQL directo:** el `OnDelete` de Liquidación devuelve las novedades
materializadas con `GestNov.RevertirLiquidacion`. Borrando por fuera, esas novedades quedan
Aplicada contra una liquidación que no existe y **no entran nunca más en ninguna**. Hay que
reabrir y borrar desde la UI. Ver [[novedades-pre-liquidacion]].

## Relacionado

- [[novedad-con-proyecto-queda-huerfana]]
- [[novedad-en-cero-no-apagaba-el-concepto]]
- [[novedad-estado-apunta-a-proyecto-sin-liquidar]]
- [[novedad-tipo-liq-y-fecha-se-pelean]]
- [[novedades-pre-liquidacion]]
- [[orden-calculo-del-lote]]
- Tema: `motor-calculo` (ver [[_Convenciones del vault]])
