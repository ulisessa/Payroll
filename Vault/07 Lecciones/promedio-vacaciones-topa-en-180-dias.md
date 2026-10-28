---
aliases: ["El divisor del promedio de vacaciones topa en 180 días"]
tipo: leccion
tema: vacaciones-sac-licencias
tags: [leccion, vacaciones-sac-licencias, project]
actualizado: 2026-10-14
---

# El divisor del promedio de vacaciones topa en 180 días

> [!warning] Con la ventana completa de seis meses Meta4 divide por 6 períodos de 30 días, no por los 184 días reales.

**Regla de Meta4** (decisión del usuario del 14/10/2026: reflejar a Meta4): `PROM_6_ULT_MES = base / min(días de prestación, 180) * 30`.

- Ventana **parcial** (alta reciente, fase corta): divide por los días reales. Cierra al centavo en las once finales medidas (de 37 a 170 días), seis de enero y cinco de febrero.
- Ventana **completa** de seis meses (agosto a enero suma 184 días): Meta4 divide por 180, o sea por 6 períodos. BC dividía por 184 y pagaba 2,2% menos.

Ninguna ventana de seis meses tiene menos de 181 días, así que el tope sólo actúa cuando la ventana está completa y enero no cambia.

**Cómo quedó:** el 3973 tiene una vigencia nueva desde 2026-02-01 con `MIN(DIAS_PREST_PROM_VAC, 180)`; la anterior (2026-01-02) se cerró el 31/1. No hace falta código AL. Script: `scripts/VacNoGozadasDivisorTope180.sql`. El 3553 (vacaciones normales) usa `MESES_PROM_VAC` y ya divide por seis meses completos: no se tocó.

**Alcance medido en febrero:** una sola final con ventana completa, que mueve unos 118 mil pesos en el 3973 y unos 10 mil en el 3974.

## Lo que sí era falso positivo: novedades cargadas después del cálculo

Ocho de las nueve finales con días de vacaciones no gozadas figuraban con 3973 en cero. No era el divisor: las novedades `CargarVacNoGozadasMeta4.sql` se insertaron a las 19:45 y las liquidaciones se habían calculado a las 17:46. Con recalcular alcanza, y la base y el divisor de esas ocho ya coincidían con `PROM_6_ULT_MES`.

El script de carga leía sólo las corridas TP 14. El personal de tierra (90xxx) cobra sus no gozadas en la corrida mensual (TP 1): se completó con `CargarVacNoGozadasTierraMeta4.sql` (cinco novedades, febrero a mayo).

## Relacionado

- [[el-promedio-de-vacaciones-divide-por-dias]]
- [[ventana-promedio-vacaciones-corta-en-la-fase]]
- [[vacaciones-tripulantes-promedio]]
