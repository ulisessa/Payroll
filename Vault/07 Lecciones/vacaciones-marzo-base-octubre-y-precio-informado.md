---
aliases: ["Vacaciones de marzo: base de octubre y precio informado"]
tipo: leccion
tema: vacaciones-sac-licencias
tags: [leccion, vacaciones, migracion-meta4, promedios]
actualizado: 2026-10-20
---

# Vacaciones de marzo: base de octubre y precio informado

nueve vacaciones de marzo no coincidían con Meta4: cinco por una base histórica de octubre, dos por un precio cargado a mano, una por un día de más y una (04706) por las dos primeras

El promedio de vacaciones de BC (`SUMA_REM_VAC / 6 / 25 × días`) suma seis meses de `BASE_PROMEDIO` (septiembre a febrero para una vacación de marzo); Meta4 suma `TOT_PROMEDIOS` de los mismos meses por fecha de imputación. Comparando mes a mes, el único mes que difería era octubre de 2025.

## Qué se hizo (20/10/2026)

1. **`BASE_PROMEDIO` de octubre de 2025 de 01937, 02737, 02854, 03660 y 04207** puesto en el `TOT_PROMEDIOS` de Meta4 (el `HIST_REMUN_BRUTO` de esos meses ya coincidía al centavo).
2. **Precio de vacaciones informado a mano** (03073 y 04706): Meta4 tiene una incidencia `4056 PRE_VACACIONES` del 27/3 (234.681,04 y 77.285,50 por día) que pisa el promedio. Dos novedades de importe sobre el 3553 (8.213.836,40 y 1.081.997,00).
3. **04495**: la novedad pagaba 22 días ("1 residual + 21") y Meta4 pagó 21.

## Por qué NO se extendió a otros empleados

Se comparó, para todos los empleados y de 1/2024 a 6/2026, la suma mensual de `BASE_PROMEDIO` de BC contra el `TOT_PROMEDIOS` de Meta4. De 2025-01 a 2025-07 coincide siempre; en 2025-08 a 2025-12 BC queda por debajo en 19 empleado-mes. Se corrigieron esos meses al valor literal de Meta4 y **se revirtió el mismo día**, porque rompía lo que ya coincidía:

- **Meta4 no es consistente en el tiempo.** La historia original de BC coincide con la suma de `TOT_PROMEDIOS` de las corridas con `TOT_REM_IMP` distinto de cero (las de tipo de imputación 14 —liquidaciones finales de una fase anterior— tienen cero y quedan afuera). Con esa historia coinciden las vacaciones de enero y febrero de 00191, 00965, 02745, 03090 y 03207 y las finales de 04047 y 04573. En cambio las vacaciones de marzo de 02737 incluyen una de esas corridas.
- Para vacaciones procesadas **hasta el 30/6** la historia anterior a octubre no entra en ninguna ventana (abril = octubre a marzo, mayo = noviembre a abril, junio = diciembre a mayo), y las cinco vacaciones de abril que hay en Meta4 ya coinciden con BC.

Regla práctica: **una vacación que no coincide se resuelve caso por caso** (comparar la suma de `TOT_PROMEDIOS` de Meta4 contra `SUMA_REM_VAC` mes por mes, con y sin las corridas de `TOT_REM_IMP` cero, y mirar si hay una incidencia 4056), no tocando la historia en bloque. Ver [[promedio-vacaciones-regla-original-meta4]] y [[historia-remuneraciones-migrada]].

Scripts: `VacacionesMarzoComoMeta4.sql` (el punto A sólo vale para los cinco de arriba: la corrección de 04706 se revirtió), `BasePromedioHistoricaComoMeta4.sql` (anulado) y `BasePromedioHistoricaRevertir.sql`.

## Cierre (20/10/2026)

Con las novedades, las 33 vacaciones de marzo coinciden con Meta4 salvo una, 04495 (+1.884, 0,1 %), que queda **a propósito**:

- Sus vacaciones corren del 9/2 al 22/3 y Meta4 las paga en dos tramos de 21 días. BC calcula el tramo de marzo con el promedio de **agosto a enero**, la ventana anclada en el *inicio de la licencia* (Art. 34 del CCT: "los seis meses anteriores a aquel en que comience a gozar sus vacaciones"), y por eso el precio del tramo de marzo es el mismo que el de febrero (87.049,92). Meta4 recalcula el precio en marzo con septiembre a febrero (86.960,20). Es una diferencia de criterio de Meta4 en una vacación partida entre dos meses; no es un error de base.
- 02937: Meta4 paga los 35 días al arrancar aunque una licencia por enfermedad parta las vacaciones (30 días en marzo, 5 a fines de mayo). Novedad de 35 días; la fórmula valoriza.

## Estados de 04495 (20/10/2026)

Los estados de 04495 no eran los de Meta4: una sesión anterior (16/10) había agregado un AU9 del 2/3 al 22/3 —leído de `M4T_AUSENTISMOS`, "vacaciones 02–22/03"— y movido el franco al 23/3 para reproducir el pago de 22 días. El historial de estados de Meta4 (`M4T_HIST_ESTADOS_EMPL`) dice AU9 del 9/2 al 1/3 y **franco desde el 2/3**, y de ahí salen los 30 días de franco y de antigüedad que Meta4 pagó en marzo. Se devolvieron los estados a los del historial (`scripts/Estados04495ComoMeta4.sql`). La vacación de marzo (21 días, 1.826.164,11) queda por la novedad 11603 sobre la liquidación VACACIONES de marzo, que cubre el 1/3 (el día del AU9 que cae en marzo).

Aprendizaje: **cuando una tabla de ausentismos y el historial de estados de Meta4 discrepan, el pago manda sobre cuál es el estado**. Antes de armar un estado a partir de otra tabla, comparar los días pagados (`DIAS_FRANCO`, `DIAS_VACACION`) con el historial.

## Actualización (20/10/2026, tarde): la historia se reconstruyó con la regla de la fase vigente

La sección "Por qué NO se extendió" quedó superada. El usuario fijó la regla —**los promedios son SIEMPRE de la fase de alta vigente, con todas las remuneraciones devengadas desde la última fecha de ingreso**— y la auditoría mostró que la historia migrada era inconsistente: de 124 empleado-mes con corridas de remuneración cero (`TOT_REM_IMP` = 0, promedio > 0) BC dejó afuera 72 (172,6 M) y las incluyó en 50 (2024 todas afuera, enero–julio de 2025 todas incluidas, agosto–diciembre de 2025 mezcladas); además hay corridas parciales (promedio mayor que remuneración) y diez meses de alta con dos fases en la misma línea.

Se reconstruyó `BASE_PROMEDIO` de la historia de **julio a diciembre de 2025** desde Meta4 (27 líneas; `scripts/BasePromedioHistoricaReconstruccion.sql`). No se tocaron los meses enteros anteriores al alta, 2024, ni las 13 líneas donde BC es mayor que Meta4 (90xxx de noviembre y 90455/90456 de diciembre: pendiente de revisar).

**Consecuencia:** Meta4 liquidó enero y febrero con la historia sin esas corridas (vacaciones de 00191, 00965, 02745, 03090 y 03207, la final de 04047 y la enfermedad de 02670, 04216 y 00191). Para que esas liquidaciones sigan coincidiendo con lo que Meta4 pagó se fijaron con novedades de importe (`NovedadesEneroFebreroPromedioHistoria.sql`, `EnfermedadHistoriaNuevaComoMeta4.sql`). Cualquier recálculo de la historia debe repasar el 4110 y el 3553 de los empleados que cambian de base.

**Descuentos de la VACACIONES de 04495 (20/10/2026):** al pagarse por novedad y sin días de vacaciones en los estados, `DIAS_VAC_INICIO` es 0 y los conceptos cuya condición dependía de ese valor no corrían: Ley 19032 vacaciones (6013) y cuota sindical vacaciones (8525), que Meta4 sí descuenta (54.785 y 73.047). Pasaron a la condición por la base (`BASE_SS_VAC > 0`, `BASE_SINDICAL_VAC > 0`) desde el 1/3 (`scripts/Condicion6013y8525PorBase.sql`), como ya hacía el 6003. Quedan con la condición por días el 6037 (adicional obra social vacaciones) y el 8810 (descuento de anticipo de vacaciones).
