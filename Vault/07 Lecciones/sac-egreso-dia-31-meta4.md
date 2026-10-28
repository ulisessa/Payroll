---
aliases: ["El SAC de egreso de Meta4 cuenta el día 31"]
tipo: leccion
tema: vacaciones-sac-licencias
tags: [leccion, sac, liquidacion-final, meta4]
actualizado: 2026-10-16
---

# El SAC de egreso de Meta4 cuenta el día 31 de un mes de ingreso

**Caso:** 90331 (FA35, sueldo 1.155.795), alta el 5/1/2026 y baja el 6/2/2026. SAC de egreso: Meta4 `EGRESO_EXTRA_1` = **105.947,88**; BC 3813 = **102.737,33** (−3.210,55, y −353 de aporte sobre el SAC).

**Medición:**
- Meta4: 105.947,88 × 12 = 1.271.374,56 = **sueldo × DIAS_SAC / 30** = 1.155.795 × 33 / 30 (DIAS_SAC 33 = 27 días de enero + 6 de febrero, calendario).
- BC: (1.001.689 de enero + 231.159 de febrero) / 12 = 102.737,33. Esa base es lo **pagado**: en enero el recibo descuenta 4 días de ausencia (1 al 4) y paga 26 sobre el mes comercial de 30, así que el día 31 no se paga. La diferencia de numerador es **un día de sueldo** (1.155.795 / 30 = 38.526,5).
- Enero coincide (ACM_PROR_SAC 83.474,08 = 1.001.689 / 12): sólo el SAC **de egreso** se arma con los días calendario de alta del semestre y no con lo pagado.

**Alcance:** sólo cambia cuando el semestre tiene un día 31 dentro del alta y el sueldo es fijo (enero, marzo, mayo...). En las otras finales de febrero (04751, 04139, 04766...) los números cierran con la regla de BC. Un día de sueldo por egresado en esa situación; **no se cambió el cálculo** (habría que cambiar la base del 3813 en LIQ_FINAL por sueldo × DIAS_ALTA_SEMESTRE / 30 sólo para fijos, y falta evidencia de un segundo caso). Pendiente si aparece otro.

## Fórmula original leída de Oracle (16/10/2026)

`3813 EGRESO_EXTRA_1` (vigencia 2026-01-01): sale 0 si no hay alta, el mes de proceso es > 6 (el 1er semestre sólo se paga en enero-junio) o no corresponde; para **MR / OF / FE** es `3605`; para el resto es `3811 × 3605`, y en buque CG se descuenta el `4676`.
- `3811` = `diascomun(1/1, 30/6, alta, baja) / 180` acotado a 0..1: **días calendario de alta del semestre / 180** (90331: 33 / 180).
- `3605 PR_AGUINALDO` (precio de la paga SAC) depende del tipo de empleado (`@241`): **EA y FE** = `(3600 + SAC_6_MESES) / 12` (el acumulado del semestre más lo del mes, dividido 12: lo que hace BC); **AD (tierra)** = `max(mejor total mensual de 6 meses, 3601 del mes) / 2` (la mejor remuneración mensual del semestre, por mitad); **P1..P5 (jornales)** = el menor entre el acumulado de 6 meses y el total del mes, / 2.
- Entonces el SAC de egreso de un administrativo es **la mitad de la mejor remuneración mensual × días de alta / 180**: 90331 = 1.155.795 / 2 × 33 / 180 = 105.947,88. BC usa lo acumulado / 12, que coincide cuando el sueldo es parejo y se cobró entero y se separa cuando hay ausencias, aumentos o un día 31 de ingreso. `3600` / `3601` son totales de conceptos (definición en `M4SYS_HIST_NORMAS`, ID_TOTAL 11 y 60); falta leer su composición para llevar la regla a BC.

## Implementado el 16/10/2026 (convenio FA)

Variable de sistema nueva `MEJOR_MES_ACUM_SEMESTRE` (Cod50016 `CalcMejorMesAcumSemestre`, opción en Tab60018): el **mejor mes del semestre** de un acumulador (`Cód. Acumulador`) restando un concepto (`Cód. Concepto`), sin contar la liquidación en curso. Instancia de datos `MEJOR_REM_SAC_SEMESTRE` = `BASE_SAC` menos el `4703` (ausencias): la remuneración del mes **sin la ausencia**, que es el "total de precios" de Meta4. El 3813 (vigencia 2026-01-02) para `CONVENIO = 'FA'` en `LIQ_FINAL` es `ROUND(MAX(MEJOR_REM_SAC_SEMESTRE, BASE_SAC − #4703) / 2 × MIN(1, DIAS_ALTA_SEMESTRE / 180))`; para cualquier otro caso queda la fórmula de siempre (`scripts/SacEgresoAdministrativosMejorMes.sql`). Supuesto sin confirmar: que todo el convenio FA sea el tipo AD de Meta4 (hay un solo final FA para comprobarlo); jornales (P1..P5) y 372/04 conservan la regla de BC.

## La mejor remuneración del SAC de egreso no incluye vacaciones (20/10/2026)

90315 (FA31, final de marzo): Meta4 `EGRESO_EXTRA_1` 376.227,58 = `PR_AGUINALDO` 953.816,40 × `DIAS_SAC` 71 / 180; BC 446.456,73. La diferencia (−70.229) era la mejor remuneración: BC tomaba el mejor mes de `BASE_SAC` menos el 4703 (2.263.724,26 en enero, con una vacación de 2.136.548,74 menos su descuento de 1.780.457,28) y Meta4 el `3601 TOTAL_P_SAC_ADM` (1.907.632,80 todos los meses: sueldo + zona). El total 60 de `M4SYS_TOTALES` ("Total para SAC adm") lo forman 1003, 1005, 1053, 1413, 2103, 2703, 3573, 4135... y **no** la vacación (3553), su descuento (4743) ni las ausencias (4703).

Cambio de datos (`scripts/MejorRemSacSemestreSinVacaciones.sql`): `MEJOR_REM_SAC_SEMESTRE` pasa a leer el acumulador `BASE_AUSENTISMO` (1003, 1053, 2103, 2703) sin restar concepto. En 90331 y 90308, las otras finales FA, es igual a `BASE_SAC − 4703` mes por mes y no cambian. Rollback: acumulador `BASE_SAC`, concepto `4703`.

**Lo que tapaba el 3813 (20/10/2026):** al corregir la mejor remuneración, el bruto de 90315 pasó de −343.092 a −413.320: el 3813 de BC estaba +70.229 y ocultaba otra falta. Meta4 paga además SAC sobre la indemnización sustitutiva del preaviso (3904 = 3903 / 12 = 317.938,80) y sobre la integración del mes de despido (3944 = 3943 / 12 = 95.381,64): 413.320,44. En BC los dos conceptos existían sin fórmula. Se agregó la vigencia del 1/3 (`scripts/Sac3904y3944Formula.sql`), con orden 452 y 453 porque leen el 3903 y el 3943 (451). Después de recalcular, mirar también 4751 a 4753 y 5498 (que el comparador marca «sólo Meta4» en esa final): son la contribución sobre ese SAC y el redondeo.
