---
aliases: ["La planilla de francos devengados no es Meta4"]
tipo: leccion
tema: francos
tags: [leccion, francos, asiento, conciliacion, meta4]
actualizado: 2026-10-28
---

# La planilla de francos devengados no es Meta4

**En una frase:** la planilla "Francos devengados 2026" de contaduría no es lo que registró Meta4. Hay tres números distintos para el mismo devengo, y BC coincide con Meta4 en los días pero no con ninguno de los dos en el valor. Antes de corregir BC contra la planilla, decidir con cuál de los tres se compara.

## Los tres números de enero de 2026

| | Días | Valor | Contribuciones − crédito IVA |
|---|---|---|---|
| Planilla de contaduría (`04-Francos devengados 2026.xlsx`, 289 filas) | 1.744,54, sin redondear | 120.967.501,80 | 36.004.559,88 |
| Meta4 (`M4T_ACUMULADO_RL3`: `DS_FRANCOS_DEV`, `FRANCOS_DEV`, 289 filas) | 1.794, redondeado por liquidación | 118.635.256 | no la asienta (`AJU_FRANCOS` = 0 en 2026) |
| BC (289 lotes de devengo de la cuenta corriente, valorizados como la provisión del asiento) | 1.795 | 110.928.087,91 | no la provisiona |

Las 289 filas de los tres cruzan 1 a 1 por **legajo + buque + marea** (NAV ↔ `PP-<buque>-<marea>`; PTO/FCO/VAC ↔ `PN-<buque>-NOMINA`). Ojo: el `PM` de Meta4 es `MAY` en BC. En RL3 hay que filtrar `DS_FRANCOS_DEV > 0`: en enero tiene 321 filas, 39 de consumo. La fila TOTAL de la planilla trae en LEGAJO la cantidad de filas, así que se excluye por el nombre, no por el legajo.

## Días: BC tiene razón y la planilla no redondea

La planilla calcula `DIAS DEV = DIAS EMB × coef + DIAS FERIADO` (0,50 marinería, 0,52 oficiales) **sin redondear**. Meta4 redondea por liquidación y BC también (`ROUND(…, 1)` en el 1062), que es el criterio confirmado hasta el 30/6/2026 ([[Cuenta corriente y matriz de francos]]). **BC = Meta4 en 286 de 289 filas.** Los +49,46 días de diferencia con la planilla son su falta de redondeo: +29,52 están en los DEVENGADOS de mareas que zarpan entre el 24 y el 30/1, con tramos de 3 a 7 días.

Las tres diferencias reales contra Meta4:

- **+1 y +1**: dos guardias parciales que incluyen el 1/1. BC suma el feriado y Meta4 no. Son los dos casos que [[feriado-de-guardia-del-1-de-enero]] deja pendientes de confirmación.
- **−1**: un cierre de marea del HF802. El 1062 de marea usa `DIAS_MAREA`, que desde el commit 850d663 (8/10/2026) descuenta el día de puerto personal anterior a la zarpada, y ese día deja de devengar franco. **Acá Meta4 tiene razón** (devenga 0,52 × 23). Ver [[Hallazgos abiertos]].

La planilla de **marzo** trae `DIAS EMB` = 0 en las 224 filas: sus días salen de otro lado o la exportación corrió una columna. En febrero y abril la fórmula se cumple.

## Valor: tres criterios distintos

| Quién | Precio por día del franco devengado |
|---|---|
| Planilla | **lo que se paga**: marinería al mayor entre el `VALOR_FRANCO` de la categoría y el del puesto embarcado, al 100 % también en tangoneros (en abril ya sólo la categoría); OF02/OF04 al acuerdo de empresa (3.500 / 2.975 USD); OF01/OF03 al convenio |
| Meta4 (RL3) | la categoría al 100 % (OF02/OF04 al convenio), más 7,47 por día fijos (224/30) en todas las filas, de origen sin identificar |
| BC (provisión) | **el 1063**: `VALOR_FRANCO_<conv>_<cat>` del par de la liquidación de origen, al TC de la fecha del lote, ÷ 30, × `COEF_PESQUERIA` de la liquidación de origen (0,3 en la marinería de tangoneros en enero) |

**Lo que se paga al consumir un franco no es el 1063 solo.** Se paga el 1063 (categoría × coeficiente de la liquidación que paga), más el 2083 (acuerdo, OF02/OF04), más la parte del 1603 sobre francos (puesto superior) y la del 3554 (el 70 % no remunerativo de tangoneros). En las 39 liquidaciones de enero con consumo, el 1063 es dos tercios de lo pagado. Ese reparto es una imputación coherente con las fórmulas, no una medición independiente: sólo cuatro liquidaciones ponen a prueba el puesto superior. La excepción es la baja: el 2803 de la final paga la categoría al 100 % y no consume lotes.

Diferencia de enero entre BC y la planilla: **−10,04 M**. Con los días al precio de la planilla y el precio a los días de BC, se reparte así:

| Causa | Enero |
|---|---|
| días (redondeo y las tres reales) | +3,07 M |
| 30 % de la marinería de tangoneros (16 filas, 195 días) | −7,69 M |
| marinería con puesto superior a la categoría (62 filas) | −2,78 M |
| OF02/OF04, acuerdo contra convenio (17 filas) | −2,64 M |
| OF01/OF03 | 0 |

Con el orden inverso (días al precio de BC) los días dan +2,66 M y el precio −12,70 M: el reparto es una convención, el total no.

## Contribuciones

La planilla suma `MONTO × (33,4 − %CF) / 100`. El 33,4 es exactamente la suma de las alícuotas marginales de BC para la tripulación (10,77 + 1,59 + 6 + 7,4 + 2 + 4,7 + 0,94), y `CNT_SAC_DEV` aplica la misma tasa neta (26,90 en zona 29 y 31,95 en zona 07). La planilla toma el `%CF` **del buque** (HF801/HF802 1,45, el resto 6,5); BC y la nómina de Meta4 lo toman **del empleado**. En enero difieren 19 filas de 7 tripulantes (−266 mil); en febrero, 12 filas; desde abril, ninguna.

BC no provisiona contribuciones sobre francos: es la mayor brecha (36,0 M en enero). Sobre la variación que asienta la provisión de enero (73,0 M), las cargas serían unos 22 M (entre 19,6 M y 23,3 M), y sobre el saldo inicial (313,3 M), entre 84 M y 100 M. Ojo: el 70 % de tangoneros que paga el 3554 es no remunerativo, así que la planilla sobreestima sus cargas.

## Febrero a abril

En BC no hay liquidaciones vivas de esos meses: se borraron al recalcular enero. Con los parámetros de BC sobre las filas de la planilla, el efecto precio estimado (el método reproduce enero al peso) es:

| Mes | Planilla | Efecto precio | OF02/OF04 | Puesto superior | 30 % tangoneros | Días Meta4 contra planilla | Contribuciones |
|---|---|---|---|---|---|---|---|
| Febrero | 136,32 M | −6,16 M | −3,31 M | −2,85 M | 0 | 1.944 / 1.942 | 40,08 M |
| Marzo | 150,13 M | −6,86 M | −4,02 M | −2,85 M | 0 | 2.159 / 2.106,88 | 43,96 M |
| Abril | 120,65 M | −3,28 M | −3,28 M | 0 | 0 | 1.768 / 1.718,56 | 35,53 M |

Desde el 1/2 no hay 30 % de tangoneros: `COEF_TANGONERO` = 1 desde el 1/2/2026 pisa al específico ([[generica-nueva-pisa-especifica-vieja]]). Coincide con la suspensión del reparto en Meta4 de febrero a abril ([[franco-porcentaje-por-pesqueria]]). Pero los lotes de enero valorizados al 0,3 se pagan después al 100 %, porque el 1063 usa el coeficiente de la liquidación que paga y la provisión, el de la de origen.

**Cómo aplicarlo:** para validar los días, comparar contra `DS_FRANCOS_DEV` de RL3, no contra la planilla. La planilla es el número que contaduría asentaba a mano en 6110001/6110002.

## Lo que se decidió (28/10/2026)

El usuario eligió **valorizar como la planilla** y provisionar las cargas **netas del crédito IVA, con la zona del empleado**. Quedó en la 1.0.0.710 como configuración de la regla del 1062 (`Fórmula Valor Franco`, `Precio por Puesto`, `Sin Coef Pesquería`) y una regla nueva de cargas (`CNT_FRANCO_DEV`, tasa `CNT_SAC_DEV` / `4750` de la liquidación del lote). Ver [[Asiento de sueldos]].

En enero, el valor por día de los 282 lotes que cruzan con la planilla da igual a su precio. La provisión queda en 72,52 M de variación y 22,39 M de cargas, más saldos iniciales de 394,7 M y 107,9 M. Todo coincidió al centavo con una predicción armada aparte desde la regla de negocio.

> [!warning] Dos trampas de la implementación
> - **La tasa de cargas de un lote se resuelve a cada cierre, con tope en el cierre.** Si la tasa de un lote del saldo inicial se busca en "la primera liquidación después", sin tope, aparece recién en un mes posterior. Ese mes revierte cargas que nunca se provisionaron.
> - **Las opciones de valuación no tienen vigencia.** Cambiarlas revalúa todo el stock abierto, y esa diferencia no entra en ninguna variación.

## Relacionado

- [[Asiento de sueldos]] · [[Cuenta corriente y matriz de francos]] · [[Hallazgos abiertos]]
- [[valor-franco-por-terna]] · [[franco-tres-niveles-de-precio]] · [[franco-porcentaje-por-pesqueria]] · [[a-cuenta-futuros-aumentos-francos]] · [[puesto-vs-categoria-cct]] · [[categoria-superior-sobre-francos-en-finales]]
- [[feriado-de-guardia-del-1-de-enero]] · [[dia-de-puerto-no-estira-la-marea]] · [[comparar-columna-contra-total]]
