---
aliases: ["Medir el bruto de un mes contra Meta4 por SQL"]
tipo: leccion
tema: comparacion-meta4
tags: [leccion, comparacion-meta4, project]
actualizado: 2026-10-14
---

# Medir el bruto de un mes contra Meta4 por SQL

Equivalente a la página "Comparar BC vs Meta4", útil para agrupar por causa.

- **Meta4:** el bruto es la suma del último valor acumulado del mes de `TOT_REMUN_27617` (columna 484) y de `SAC_ABONADO` (334) por empleado, ordenando las corridas por `Contador Liq.`. La suma de las diferencias entre corridas telescopa al último acumulado.
- **BC:** suma de las líneas `REMUNERATIVO_BRUTO` y `NO_REMUNERATIVO` del período, sin `HIST_REMUN`.
- **Por concepto:** BC con tipo de concepto 0 y 1 y `Es Devengo` = no; Meta4 con las columnas de clasificación `DV` (más las verificadas y las sin clasificar con concepto), sumando las corridas salvo el tipo de imputación 4.

**Resultado de febrero 2026** (líneas calculadas el 14/10): 339 empleados en BC y 338 en Meta4, 117 con diferencia mayor a 5 pesos; BC 1.919,6 M contra Meta4 1.958,3 M (neto de diferencias –38,7 M, absoluto 58,8 M). Enero con el mismo método: 329 empleados, 11 con diferencia, 0,35 M absolutos: sirve de línea base antes de tocar fórmulas.

Las diferencias se concentran en cinco causas (feriado con producción, acuerdo de oficiales, no gozadas por recálculo pendiente, vacaciones normales y trabajo especial). Los empleados 8xxxx/9xxxx de tierra (FA) tienen diferencia de conceptos pero no de bruto.

## Relacionado

- [[feriado-en-cierre-con-produccion]]
- [[promedio-vacaciones-topa-en-180-dias]]

**Aviso (15/10/2026): el bruto de Meta4 incluye `SAC_ABONADO` también en el script SQL.** Una comparación que sólo tomaba `TOT_REMUN_27617` (col. 484) mostró +1,95 M "de más" en la liquidación final de 04766 y errores parecidos en otros cinco finales: eran el 3813 (SAC de egreso), que Meta4 guarda en `SAC_ABONADO` (col. 334). Con la columna 334 sumada, febrero queda en 316 empleados exactos y 14 con diferencia de más de $10.000.
