---
aliases: ["El feriado divide por 30 fijo"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-28
---

# El feriado divide por 30 fijo

El concepto 1023 saca el valor del día feriado dividiendo la base por 30 fijo, y Meta4 divide por los días reales del período

**El 1023 "Sueldo día feriado" no es un precio: es un promedio diario.** `PR_DIA_FERIADO` de Meta4
varía empleado por empleado dentro de la misma categoría —48.444, 48.600, 49.044, 50.314, 52.644,
54.600, 56.000, 58.200, 60.600, 64.200, 67.500 en 175/75 OF02— así que no hay lista de precios que
buscar. Es `base / días`.

La fórmula de BC divide por **30 fijo**:

    round(BASE_FERIADO / 30, PRECISION_REDONDEO) * (DIAS_FERIADOS_MAREA + DIAS_FERIADOS_GUARDIA)

y **Meta4 divide por los días reales**. El testigo es el legajo 00794 en enero de 2026, con la misma
base en los dos lados:

    base = 1.860.000 sueldo de puerto + 232.500 antigüedad = 2.092.500

    BC      2.092.500 / 30 × 1 = 69.750,00
    Meta4   2.092.500 / 31 × 1 = 67.500,00   <- lo que paga, exacto al centavo

En un mes de 31 días BC paga **3,33% de más** en cada línea de feriado. En enero de 2026 es una sola
línea y 2.250 pesos, pero la regla está mal y muerde en todos los meses con feriados.

**El divisor correcto es, conceptualmente, el mismo conjunto de días que generó la base** —no un 30
de calendario—, que en el 00794 son sus 31 días de guardia de puerto. Eso lo emparenta con
[[antiguedad-no-cuenta-dias-gp]]: los dos conceptos tienen el problema de qué días cuentan, uno en el
numerador y el otro en el divisor.

## El divisor es DIAS_MAREA, y BC ya tiene la variable

La primera medición que hice estaba mal planteada: promedié sobre **todas** las entradas, incluidas
las que no pagan feriado, donde restar `SUELDO_DIA_FDO` —nulo— no prueba nada. Acotando a las que
sí pagan feriado y **despejando los días** en vez de probar divisores uno por uno:

    dias_implicitos = (TOT_HAB_GZDO − SUELDO_DIA_FDO) / PR_DIA_FERIADO

    entero y = DIAS_MAREA   388
    entero y otro valor      10
    no entero               607

**De los 398 que dan un entero, 388 son exactamente `DIAS_MAREA`** —97,5%—, con valores de 3, 4, 11,
13, 22, 23, 31… o sea los días que cubre esa liquidación, no un 30 de calendario.

**BC ya tiene la variable**: `DIAS_MAREA`, "Días totales de la marea en la ventana de liquidación".
El arreglo es un solo término, cambiar el `30` literal por ella.

**Dos cosas a verificar antes de tocarla.** Primero, que `DIAS_MAREA` de BC valga 31 para un caso
como el 00794, que no tiene marea sino guardia de puerto —Meta4 le cuenta 31, pero si BC le da 0 la
fórmula dividiría por cero y hay que guardarla igual que en [[a-cuenta-futuros-aumentos-francos]]—.
Segundo, los **607 que no dan entero**: ahí la base no es `TOT_HAB_GZDO − SUELDO_DIA_FDO`, así que el
divisor está resuelto pero la base no del todo.

## Y `IFZERO(DIAS_MAREA, 30)` NO alcanza

La fórmula quedó así el 28/9/2026:

    round(BASE_FERIADO / IFZERO(DIAS_MAREA, 30), PRECISION_REDONDEO)
      * (DIAS_FERIADOS_MAREA + DIAS_FERIADOS_GUARDIA)

**y el 00794 sigue cobrando 69.750 en vez de 67.500.** `DIAS_MAREA` es
`CalcDiasNavegacionMarea() + CalcDiasPuertoMarea()` (Cod50016), y en él los dos dan **cero**: sus 31
días son `DIAS_GP_PERIODO`. El `IFZERO` cae al 30 y conserva el bug exactamente en el caso que se
quería arreglar — la red de seguridad tapa el síntoma.

**La causa raíz es que BC parte en dos lo que Meta4 tiene junto**: “puerto” y “guardia de puerto” son
dos contadores separados, y `CalcDiasPuertoMarea` no cuenta los GP. En Meta4 el 00794 tiene
`DIAS_PUERTO = 31` y `DIAS_MAREA = 31`; en BC tiene 0 y 0.

**El único concepto que hoy lo resuelve es el 1083**, que escribe `DIAS_PUERTO + DIAS_GP_PERIODO` a
mano. El 1053 no lo hacía —ver [[antiguedad-no-cuenta-dias-gp]]—, el 1023 tampoco, y `DIAS_MAREA`
tampoco.

**El arreglo quirúrgico es `DIAS_MAREA`**: que devuelva
`CalcDiasNavegacionMarea() + CalcDiasPuertoMarea() + los días de GP`. Sin doble conteo, porque
ninguno de los dos conceptos que la usan —1023 y `PROD_EMPRESA`— suma GP por su cuenta. Tocar
`CalcDiasPuertoMarea` en cambio arreglaría la raíz pero obligaría a sacarle el `+ DIAS_GP_PERIODO` al
1083 y al 1053, que si no contarían dos veces.

Antes de hacerlo hay que mirar **`PROD_EMPRESA`**, el otro consumidor de `DIAS_MAREA`: sumarle días de
guardia cambia cómo prorratea la producción.

Detectado el 28/9/2026 y **sin corregir**.

## Relacionado

- [[antiguedad-no-cuenta-dias-gp]]
- [[a-cuenta-futuros-aumentos-francos]]
- [[a-cuenta-futuros-aumentos-puerto]]
- [[adicional-art-23-vs-art-33]]
- [[adicional-tareas-mecanicas]]
