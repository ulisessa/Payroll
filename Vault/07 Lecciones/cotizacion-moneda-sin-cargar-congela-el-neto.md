---
aliases: ["Cotización de la moneda sin cargar congela el neto en la última fila"]
tipo: leccion
tema: grossing-up-tipo-cambio
tags: [leccion, tipo-cambio, grossing-up, project]
actualizado: 2026-10-16
---

# Cotización de la moneda sin cargar: el neto queda en la última fila

**Síntoma:** 90212 (neto objetivo 6.000 EUR) salía en febrero con el neto de enero: +390.000 de neto y +628.184 de bruto contra Meta4; 90302 (2.000 EUR) igual, 3.539.998 en vez de 3.410.000.

**Causa:** `TC_VENDEDOR` toma la última fila de `Currency Exchange Rate` con `Starting Date <= fecha`. Para el EUR no había filas entre el 14/1/2026 (1.770) y el 17/9/2026, así que febrero usaba 1.770. Meta4 liquidó febrero con **1.705** (`LIQUIDO` / EUR = 10.230.000 / 6.000 y 3.410.000 / 2.000). No da error: el grossing-up converge al neto objetivo con la cotización vieja y "sale bien".

**Cómo se ve:** el neto de BC es exactamente `EUR × última cotización` (10.620.000 = 6.000 × 1.770) y el de Meta4 también, con otra cotización. Dividir `LIQUIDO` de Meta4 por los EUR da la cotización que usó.

**Arreglo:** fila del EUR desde el 1/2/2026 con 1.705 (comprador y vendedor en la misma fila), `scripts/CotizacionEURFebrero2026.sql`. Marzo en adelante no se cargó (Meta4: 1.640 en marzo, 1.685 en mayo; abril y junio mezclan otros conceptos). **Las cotizaciones las publica quien liquida**: sin fila nueva, cada mes repite la anterior.

## La fecha de la cotización también es un dato mensual: FECHA_TC (16/10/2026)

90016 (9.000 USD netos) y 90251 (5.750 USD de básico) quedaban 83.642 y 28.750 abajo en febrero: Meta4 liquidó a **1.425** (USD vendedor del 26/2) y BC a **1.420** (la del 27/2, último día del período). El tipo de cambio de los sueldos en divisa es el del día en que Meta4 **cortó el proceso** (27/1, 26/2, 27/3), que no se deduce de ninguna regla (Meta4: enero 1.465, febrero 1.425, marzo 1.405, abril 1.430, mayo 1.430). La infraestructura ya existía (concepto `FECHA_TC`, fuentes `TC_COMPRADOR` / `TC_VENDEDOR` con `<={FECHA_TC}`), pero **no había ninguna novedad cargada**. Se cargaron las de enero (27/1) y febrero (26/2) de 90016, 90251, 90361, 90212 y 90302 (`scripts/NovedadesFechaTCEnero_Febrero.sql`). Marzo en adelante: cargar la novedad cada mes con la fecha de corte de Meta4, o el sueldo queda cotizado al último día del período.

**Marzo (20/10/2026):** volvió a pasar con 90212 y 90302 (EUR, 1.640 en Meta4 contra 1.705 de la última fila): neto +389.996 y +129.993. Se cargó la fila del 1/3 (`scripts/CotizacionEURMarzo2026.sql`). Abril y mayo siguen sin fila (Meta4: 1.690 / 1.764,01 en abril y 1.685 en mayo).
