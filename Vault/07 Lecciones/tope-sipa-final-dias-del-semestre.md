---
aliases: ["El tope de SIPA de una final se prorratea por los días del semestre"]
tipo: leccion
tema: descuentos-ganancias-sipa
tags: [leccion, descuentos-ganancias-sipa, liquidacion-final, project]
actualizado: 2026-10-16
---

# El tope de SIPA de una final se prorratea por los días de alta del semestre

**Síntoma:** en las finales de febrero 04766, 04351, 04726, 04750, 04907 y 04918 el aporte sobre el SAC (6002/6012/6034) salía muy por debajo de Meta4 (04766: 7.209 contra 44.457) y, en 04766, también el aporte mensual (86.511 contra 106.260).

**Causa:** BC prorrateaba el tope con `DIAS_ALTA_30` (los días del **mes**: 6 en una baja del 6/2). Meta4 usa `DIAS_SAC`: los **días calendario de alta desde el 1/1 (o 1/7)** hasta la baja (04766: 37; 04751: 43; 04139: 40; en enero 04190: 26 y 04807: 28, que coinciden con los del mes, por eso las finales de enero cerraban).

**Regla (cierra enero y febrero):**
- Mensual (6000/6010/6030, rama final): `MIN(base, TOPE × DIAS_SAC / 30)`.
- SAC (6002/6012/6034): base = `MIN(SAC, TOPE × DIAS_SAC / 360)`. Con esto sobra la condición "el tope se alcanza" de la regla anterior (`tope-sac-egreso...` en [[categoria-superior-sobre-francos-en-finales]]): 04190 = 3.823.372,95 × 26/360 = 276.133; 04766 = 3.932.339,08 × 37/360 = 404.155.

**Cambio:** variable de sistema nueva `DIAS_ALTA_SEMESTRE` (Cod50016, sembrada en Cod50077, opción en Tab60018) y vigencia 2026-02-02 de los seis conceptos (`scripts/TopeSipaFinalPorDiasDelSemestre.sql`). Enero no se tocó. El 8542/8543/8593 también se corrigieron el mismo día para vacaciones (`scripts/CajaCompFdoDesempAcSocEnVacaciones.sql`: la base de vacaciones es `BASE_SINDICAL_VAC`, no `BASE_SINDICAL`).

## Corrección el mismo día: el aporte MENSUAL no se topa por semestre

Al recalcular, 04047 (baja el 11/2) quedó con la obra social mensual 29.404 arriba: Meta4 usó `REMU_IMPO_OS_ST` = 1.704.013 = `TOPE × 13 / 30`, con **13** días y no 11 ni 42. Meta4 cuenta `DIAS_ALTA = 30 − DIAS_POST_BAJA`, con post-baja = último día calendario del mes − día de baja (28 − 11 = 17): en febrero suma los 2 días que faltan para 30 (04751, baja el 12/2: DIAS_ALTA 14, post-baja 16). En enero no cambia.

Quedó así: **el SAC** se topa por semestre (`TOPE × DIAS_SAC / 360`) y **el aporte mensual** (6000/6010/6030, rama final) por `TOPE × MIN(30, DIAS_ALTA_30 + MAX(0, 30 − DIAS_MES)) / 30` (`scripts/TopeMensualFinalDiasMeta4.sql`, vigencia 2026-02-03). Es una vigencia aparte de la 2026-02-02 porque esa ya había liquidado.

Pendiente que quedó resuelto el mismo día (ver abajo): el impuesto de 01541 quedaba 29.797 arriba de Meta4.

## 4754/4755/4756/4757: el hueco era el 4757 (16/10/2026)

Meta4 junta en `C_SINDICAL_SAC_MES` la cuota, la caja compensadora, el fondo de desempleo y la acción social CAP sobre el SAC devengado; **BC ya los reparte en cuatro conceptos informativos** (4754 cuota, 4755 caja, 4756 fondo, 4757 acción social) que suman a `CUOTA_SINDICAL_RET`. Mi primer arreglo (meter caja y fondo en el 4754) los contaba dos veces y bajaba el impuesto 91.405 de más; se revirtió. El hueco real era el **4757**, que usaba `BASE_SINDICAL` y en las vacaciones de 01541 daba 0 (debía dar 84.967 = 3.159.882 × 2,689 %). Quedó como el SAC devengado por la tasa efectiva del 8593 del mes (`scripts/Acsoc4757EnVacaciones.sql`). **Regla general:** antes de tocar un concepto informativo de Ganancias, listar con `Fracción Acumulador` qué conceptos suman al acumulador, para no duplicar.
