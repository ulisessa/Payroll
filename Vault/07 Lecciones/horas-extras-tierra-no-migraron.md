---
aliases: ["Horas extras de tierra no migraron"]
tipo: leccion
tema: migracion-meta4
tags: [leccion, migracion-meta4, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-30
---

# Horas extras de tierra no migraron

las novedades 1803/1813/1893 se cargaron a mano, no vinieron de Meta4; y el mapeo de conceptos

Las horas extras de tierra (1803 50%, 1813 100%, 1893 150%) **nunca entraron por ninguna
migración**: se tipearon a mano las noches del 15 y 16/9/2026, de a una, y sólo para 5 de los 9
empleados que tenían horas en enero. Se ve en los `$systemCreatedAt`, separados por minutos, contra
el alta masiva del 18/9 14:23:49 que sí trajo el resto de las novedades.

Los cuatro que faltaban —80002, 80267, 80316, 80344— se cargaron el 30/9/2026 desde Meta4.

**Mapeo de conceptos** (confirmado dos veces: contra los cinco ya cargados y contra los importes de
`M4T_ACUMULADO_RL`):

| Meta4 `M4T_VAL_INCIDENCIA` | BC |
|---|---|
| 4529 | 1803 horas extras 50% |
| 4538 **+** 4539 | 1813 horas extras 100% — BC junta las dos |
| 1891 | 1893 horas extras 150% |

Los importes de Meta4 están en `M4T_ACUMULADO_RL`: `HS_EXTRAS_50` (col 1451), `HS_EXTRAS_100`
(1454), `HS_EXTRAS_150` (1695). Las de embarcados son otras: `HORAS_100`/`HORAS_50` (61/62) → 4423 y
4433, y ésas sí vinieron en el alta masiva.

**La fórmula de BC reproduce el importe exacto**: 90414 da 200.211,48 / 139.830,24 / 238.347,00 y
Meta4 paga lo mismo al centavo. Por eso la novedad lleva sólo la CANTIDAD, con Valor Unitario e
Importe en cero: un Valor Unitario tipeado a mano pisa la fórmula (pasó con el movimiento 11 y dejó
14.191,50 donde correspondían 14.191,78).

Pendiente: **febrero a junio de 2026 no tienen ninguna de estas novedades en BC** — 75 filas de
Meta4, 1.689 horas. Ver [[migracion-novedades-meta4]] y [[anticipos-como-novedades]].

## Relacionado

- [[migracion-novedades-meta4]]
- [[anticipos-como-novedades]]
- [[anticipos-cta-cte-meta4]]
- [[equivalencia-id-puesto-meta4]]
- [[export-csv-decimal-con-coma]]
