---
aliases: ["Diferencias de descuentos de enero"]
tipo: leccion
tema: descuentos-ganancias-sipa
tags: [leccion, descuentos-ganancias-sipa, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-10-02
---

# Diferencias de descuentos de enero

de 260 con bruto coincidente, 120 difieren en descuentos; el mapa de causas y cuál es ruido del comparador

Enero de 2026: de 330 empleados, **260 tienen el bruto coincidente** y de ésos **120 difieren en
descuentos**, por 5.055.817 (BC retiene de más). Desglosado por concepto, las causas son cuatro
familias y **una de ellas no es una diferencia real**.

**1. Los anticipos, −10,25 M: el mapeo está BIEN y la clasificación mal.** `ANTICIPO_LLEGAD`→4813 (el
pago, que vive sólo en el `ti=4`) y `DESC_ANT_LLEGAD`→8840 (el descuento del mes) son dos conceptos
distintos de Meta4, cada uno apuntando al suyo. Lo que está mal es que en BC **el 4813 tiene Tipo
Concepto 2 (Descuento) mientras sus hermanos 4803 y 4823 son 0 (Haber)**: por eso se cuela en
cualquier análisis de descuentos y aparece como 10,25 M que BC no retiene. No lo retiene porque no
liquida el 4813, a propósito. Ver [[anticipo-no-es-haber-del-recibo]].

**2. Ganancias (5010) — 108 empleados, +3.858.444.** Es la diferencia real más grande.

**3. El SAC Devengado (4750) está BIEN; lo que falla son sus descuentos.** Entre los 120 de bruto
coincidente el 4750 coincide en **119** y difiere en uno por 16.667. La diferencia de +1.384.866 que
medí al principio era sobre toda la población, donde están los del grossing-up al 70% y los del
Puente Mayor: ahí el 4750 ARRASTRA un bruto que ya difiere, no lo causa.

Los que sí fallan son 4751, 4752 y 4753, y la fórmula del 4751 lo muestra:
`MIN(BASE_SS_TRAB + BASE_SS_VAC + BASE_SAC, TOPE_SIPA) * PCT_JUB / 100 / 12`, que en 03196 evalúa
`561.283,33 + 0 + 561.283,33` — **la base va duplicada**, porque `BASE_SS_TRAB` y `BASE_SAC` valen lo
mismo y se suman. Como después hay un tope, a unos los corta y a otros no, y por eso el desvío varía
por empleado (129%, 114%…) en vez de ser un factor fijo. El **4754** es otra causa: da el 2,95% de lo
que paga Meta4 y su fórmula usa `PCT_SINDICATO`, que convive en dos unidades.

**4. Conceptos que BC no liquida — −2,2 M.** Dos subgrupos distintos:
  - **6032 y 6037** (Adicional obra social y su variante de vacaciones) están **inactivos** en BC.
  - **8542 Caja compensadora, 8543 Fondo de desempleo, 8553 Centro de capacitación, 8593 Cuota
    extraordinaria acción social CAP** están **activos y con cero líneas en enero**: configurados
    pero algo no los dispara (CCT, parámetro o condición).

Más dos chicos de pocos casos: **8830** descuento anticipo poder (2 empleados, +1.969.414) y **8893**
cuota alimentaria (4 empleados, +1.505.040).

**Cómo se mide**: el bruto de Meta4 es `TOT_REMUN_27617` y se toma el **MAX** del mes, no la suma
(ver [[tot-remun-27617-es-acumulador]]); los descuentos son `TOT_RETEN` (col 169) y el neto `LIQUIDO`
(col 90). Del lado de BC, los descuentos son los `Tipo Concepto` **2 (Descuento Empleado), 4
(Retención) y 5 (Seguridad Social)** — el 0 y el 1 son haberes y el 3 son contribuciones patronales,
que no entran en el recibo de Meta4.

## Relacionado

- [[anticipo-no-es-haber-del-recibo]]
- [[tot-remun-27617-es-acumulador]]
- [[cuatro-conceptos-sin-disparar]]
- [[cuota-sindical-deducida-dos-veces]]
- [[embargo-cuota-alimentaria-como-retencion]]
