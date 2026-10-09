---
aliases: ["Adicional de tareas mecánicas (2073)"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-28
---

# Adicional de tareas mecánicas (2073)

El concepto 2073 es el 15% del monto garantizado prorrateado, no de la producción; la fórmula de BC toma la base equivocada y por eso paga cero

Concepto **2073** (`ADIC_MECANICA` en Meta4). **No es una novedad**: tiene fórmula en BC desde
siempre. Lo que está mal es la **base**.

    BC      round(#2499 * COEF_TANGONERO * PCT_TAR_MEC, PRECISION_REDONDEO)
            #2499 = "Producción total langostino FC"

    Meta4   ADIC_MECANICA = 15% × BRUTO_PRORRAT

**El porcentaje es correcto** —`PCT_TAR_MEC` = 0,15— y **la base no**. `BRUTO_PRORRAT` es el monto
garantizado prorrateado, el mismo primer término del 2013: ver
[[a-cuenta-futuros-aumentos-puerto]].

**Verificado en 11 de 11 entradas de enero a abril de 2026**, con razón exactamente `0,150000` y
diferencias de 0,00 a 0,01 por redondeo al centavo:

    00794 ene   1.468.644,07  de  9.790.960,43
    04582 abr      45.701,57  de    304.677,10
    03196 feb     779.667,00  de  5.197.780,00   … y ocho más

**Por eso BC paga cero.** Las 11 entradas que cobran el adicional son exactamente las 11 de guardia
de puerto que cobran el 2013, y **ninguna tiene producción**, así que `#2499` vale 0 y el concepto se
apaga sin dar error — el patrón de [[acumuladores-orden-calculo]].

**Lo que no está resuelto** es qué pasa cuando **sí** hay producción: en enero-abril no hay un solo
caso de `ADIC_MECANICA` con producción, así que no se puede saber si la base es siempre el prorrateo
o si con producción pasa a ser la producción. La cláusula tercera del acuerdo 175/75 —el garantizado
"absorbe y comprende todos los conceptos devengados durante la marea hasta su concurrencia", ver
[[cct-175-75-remuneracion-navegacion]]— sugiere que la base es **el paquete**, sea cual sea su
origen, pero es una lectura, no una medición.

**Corregido el 28/9/2026** (`f2073_base.sql`): se agregó la rama del prorrateo para los días de
guardia y se dejó intacta la de producción, porque no hay ningún caso medido de adicional CON
producción. Control: 11 de 11 al centavo, y 0 líneas con importe hoy, así que sólo puede sumar.

**La expresión del prorrateo quedó repetida** en 2013 y 2073: el 2073 corre en el orden 195 y el
2013 en el 551, así que no puede leerlo con `#` — leería cero. Lo limpio sería un concepto
intermedio con el prorrateo en un orden menor que 195 que los dos lean; queda como deuda.

## Relacionado

- [[a-cuenta-futuros-aumentos-puerto]]
- [[acumuladores-orden-calculo]]
- [[cct-175-75-remuneracion-navegacion]]
- [[adicional-art-23-vs-art-33]]
- [[anticipo-no-es-haber-del-recibo]]
- [[anticipos-como-novedades]]
