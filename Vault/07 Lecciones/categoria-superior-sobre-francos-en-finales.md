---
tags: [leccion, liquidacion-final, categoria-superior]
---
# Categoría Superior (1603) también sobre los francos de la final

**Síntoma:** en las liquidaciones finales de febrero 2026, 04751 (−300.559 en el 1603) y 04139 (−128.811) quedaban bajos contra Meta4; el 3813 (SAC de egreso), 3973 y 3974 arrastraban la diferencia.

**Causa:** Meta4 aplica la diferencia de escala (PCT_PUESTO / PCT_ESCALA_CONV − 1) a `1083 + 1053 + 1063 + 2803`; la fórmula de BC no incluía el 2803 (indemnización de francos no gozados), que además corre en el orden 400 y el 1603 en el 170.

**Arreglo (datos):** vigencia 2026-02-02 del 1603 con `+ IF(TIPO_LIQ = 'LIQ_FINAL', #2803, 0)` en la base y Fórmula Orden Cálculo `IF(TIPO_LIQ = 'LIQ_FINAL', 401, 170)`. Script: `scripts/Categoria1603SobreFrancos.sql`.

**Trampa:** mover el productor de un acumulador hacia atrás obliga a revisar a los lectores intermedios (171–400): PROM_ENF_MES, 4110, 4120, 4125 — en una final no leen aportes del 1603.

**Pendiente:** diferencia de retención de SS sobre el SAC de egreso (Meta4 17% sobre todo el SAC; BC con tope).

## Retención sobre el SAC de egreso (6002/6012/6034), 15/10/2026

El 1603 y el 3813 quedaron iguales a Meta4, pero el aporte sobre el SAC no: Meta4 aporta el SAC **entero** (04751: JUBILACION_SAC 36.213 = 11% × 329.209; 04139: 32.054) y BC lo topaba siempre a (base sin SAC)/12 (11.891 y 7.732). Los aportes mensuales (6000/6010/6030) ya daban al peso.

**Regla que cierra los 8 finales de enero y los 2 de febrero:** el tope/12 sólo corre si la base del mes sin SAC llega al tope prorrateado (en enero, 04190 y 04807); si no llega, el SAC aporta entero. Se verificó con `scripts/PrevisualizarDescuentosFinal.sql` (enero queda igual, salvo el 90448 de siempre).

Aplicado con `scripts/TopeSacEgresoSoloSiSeAlcanza.sql`: vigencia 2026-02-01 de 6002, 6012 y 6034, con `IF(MAX(0, X) < TOPE, #3813 + #3823, TOPE / 12)` en lugar de `MIN(MAX(0, X), TOPE) / 12`.

## 3973/3974 de 04751: la fase anterior se colaba en el promedio, 15/10/2026

El 3973 salía 11.215 abajo y el 3974 934. Meta4: PROM_6_ULT_MES 2.732.877,21 = (279.292,29 + 11.654.269) / **131** días × 30, o sea sólo la fase vigente (alta 23/9/2025). BC: 12.177.198 / **136** × 30 = 2.686.147.

Dos causas, las dos por una baja (5/9/2025) y un alta (23/9/2025) **en el mismo mes**:
- **Divisor:** `CalcDiasPrestacionPromedioVac` sumaba también los 5 días de la fase vieja. Ahora salta las fases que terminan antes del alta de la vigente (Cod50016).
- **Numerador:** la historia de septiembre 2025 sumó 279.292,29 (TOT_REM_IMP de la fase nueva) + 243.637,67 (TOT_PROMEDIOS de la final de la fase vieja) = 522.929,96. Corregido a 279.292,29 con `scripts/BasePromedioSep2025_04751.sql`.

**Alcance:** hay 8 empleados con baja y alta en el mismo mes desde 8/2025 (04751, 04894, 04826, 04833, 04921, 04785, 04586, 03714); ninguno tiene 3553/3973 en 2026, así que el cambio de código sólo afecta a 04751 hoy. Los demás de 2025 tienen la historia del mes mezclada igual que 04751 y **no se corrigieron** (no se puede separar por fase con fechas de imputación): si alguno toma vacaciones con ventana sobre ese mes, revisar su numerador.

**Cierre de 04751 (16/10/2026):** tras recalcular la final, 1603 = 356.584, 3813 = 329.210, 3973 = 655.890 (divisor 131 y base 11.933.563), 3974 = 54.657 y los aportes sobre el SAC (6002/6012/6034) coinciden con Meta4 en todas las columnas. Total haberes 6.895.449,75 contra `TOT_HAB_S_ASIG` 6.895.450 y neto 6.503.900,97 contra `LIQUIDO` 6.503.902: **diferencia de 1 peso** (de −337.755 al comienzo). 04139 quedó cerrado antes.
