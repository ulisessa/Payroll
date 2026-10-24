---
aliases: ["Dos liquidaciones del mes con el tope SIPA se anulan"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-15
---

# Dos liquidaciones del mes pueden dejar la seguridad social en cero

**En una frase:** el tope SIPA descuenta lo "ya liquidado en el mes" por las OTRAS liquidaciones calculadas, sin orden entre ellas; si se recalcula una sola con la otra ya calculada, las dos se ven como previas y ninguna retiene.

`6000`, `6010` y `6030` restan del tope `MES_BASE_SS_TRAB + MES_BASE_SS_VAC` (todas las demás liquidaciones del período que no están en Borrador). Dentro del período Regular, Devengados y Cierre de Marea no tienen un orden establecido (ver [[Recálculo en cadena]]).

**Caso 04826, febrero de 2026:** cierre (LIQ-00053136, 1 al 12/2) y devengado (LIQ-00053289, 13 al 28/2), las dos Calculadas. El cierre quedó con `MES_BASE_SS_TRAB` = 12,94 M (el valor viejo del devengado) y retuvo 0; al recalcular el devengado, éste vio el cierre (6,86 M) contra un tope de 3,93 M y también retuvo 0. Meta4 retiene 668.497 en el cierre (= 3.932.339 × (11% + 3% + 3%)) y 0 en el devengado. Con el neto pactado por grossing-up, 668 k de retención menos son 733 k de bruto menos: justo la diferencia (−732.902) del recibo. El resto del recibo cerraba al centavo.

**Cómo se sale:** reabrir las dos liquidaciones (Borrador) y calcular primero la que Meta4 calcula primero (el cierre) y después la otra. Sirve para cualquier empleado con dos o más liquidaciones en el mes que se recalcularon de a una; una pista es una retención de seguridad social en cero en alguna de ellas.

**Resuelto en el motor (15/10/2026):** `PERIODO_ACUM` y `PERIODO_CONCEPTO` (`MES_BASE_SS_*`, `MES_CONTRIB_SIND`, `MES_VALOR_ART_FIJO`, los `SAC_*_PAGADO_MES`…) sólo cuentan las liquidaciones **anteriores en el orden de cálculo**: primero el Orden del Tipo de Liquidación (CIERRE_MAREA 1, ANTICIPO 10, VACACIONES 30, LIQ_FINAL 40, RELIQUIDACION 50, DEVENGADOS 60, REGULAR 100, AGUINALDO 110) y a igual Orden el No. Es el mismo orden con que el lote calcula (Cod50076). `EsAnteriorEnElMes` en Cod50016. Una liquidación sin Tipo conserva el criterio viejo (ve todas). Ya no importa en qué orden se calculen: la primera toma el tope y la segunda el resto.

**Contrapartida:** recalcular una liquidación no corrige a las que la siguen en el orden (si se rehace el cierre hay que rehacer el devengado y la regular del mes), igual que el [[Recálculo en cadena]] entre períodos. El YTD anual de Ganancias no se tocó: ya filtra por fecha.

Ver [[orden-calculo-del-lote]] y [[detraccion-por-liquidacion]].
