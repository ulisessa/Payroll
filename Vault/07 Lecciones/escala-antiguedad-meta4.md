---
aliases: ["Escala de antigüedad de Meta4"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, reference]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-10-02
---

# Escala de antigüedad de Meta4

la escala de Meta4 son TECHOS sin truncar y la de BC PISOS truncando; equivalentes salvo en el aniversario exacto, y la regla cambia por convenio

El script de Meta4 (`PORC_ANTIGUEDAD`) recorre `M4T_PORC_ANTIGUEDAD` y se queda con **el primer
umbral >= los años**, sin truncar — `si (an_ant <= an_ant_ti)` y después `ult = i`, que corta el
bucle. Los umbrales son **techos**, no pisos:

| ANIOS_ANTIGUEDAD | PORC |
|---|---|
| 2 | 2 |
| 3 | 4 |
| 4 | 8 |
| 5 | 10 |
| 6 | 12 |
| 7 | 14 |
| 10 | 18 |
| 99 | 25 |

Menos de 1 año → 0.

**Es la misma escala que BC, escrita al revés.** BC hace `CASE(AÑOS >= 10, 25, … AÑOS >= 1, 2)` con
`PISO(años)`. Para 4,9945: BC trunca a 4 → tramo ">= 4" → 10%; Meta4 toma el primer techo >= 4,9945,
que es 5 → 10%. **Dan lo mismo.** Sólo difieren en el **aniversario exacto**: con 5,0000 BC ya paga
12% y Meta4 todavía 10%. Meta4 cambia de tramo al día siguiente del aniversario.

(Mi conclusión anterior de "Meta4 trunca igual que BC" venía de ajustar PISO contra los datos: 436 de
451. La regla real es ésta y explica lo mismo sin forzar nada.)

**La regla cambia según el `ID_CONVENIO` de Meta4** (`M4T_CONVENIOS`):

| Meta4 | descripción | regla | BC |
|---|---|---|---|
| **OF** | Oficiales Embarcados | la tabla de arriba | **1053**, convenios 175/75, 768/19 |
| **MR** | Marinería Embarcados | la tabla de arriba | **1053**, convenio 729/15 |
| **CA** | Mensualizados Alimentación | `entero(años)`, ×1,5 de 10 a 19, ×2 desde 20 | **1055**, convenio 372/04 |
| **JO** | Personal Jornalizado | idem CA | **1055** |
| **EC** | Empleados de Comercio | `entero(años)` | — |
| FA, MA, CE, FE, DE | fuera de convenio, maestranza… | **0%** | BC tampoco les paga ✓ |

**El modelo de BC ya es el correcto.** El 1055 hace `AÑOS × TRAMO('ANTIGÜEDAD_MENS', AÑOS) × BASICO /
100`, y esa tabla escalonada tiene exactamente 1 / 1,5 / 2 en los cortes 0-9, 10-19 y 20+. Y FA no
cobra antigüedad de ningún lado.

Medido en enero de 2026: 04190 (12% los dos, 58.474,50 los dos) y 90419 (3%, 38.135,52) **coinciden**;
04495 coincide en el % y difiere sólo por [[proyecto-nomina-dos-fuentes]]; 80344 es un arrastre de
Meta4 (reporta 5,8356 años y aplica 4% donde `entero` da 5). Ver [[antiguedad-dia-por-fase]] y
[[antiguedad-suma-de-fases]].

## Relacionado

- [[proyecto-nomina-dos-fuentes]]
- [[antiguedad-dia-por-fase]]
- [[antiguedad-suma-de-fases]]
- [[a-cuenta-futuros-aumentos-puerto]]
- [[adicional-art-23-vs-art-33]]
- [[adicional-tareas-mecanicas]]

## Código unificado desde enero de 2026

Por instrucción del usuario, la regla salarial de Alimentación pasa del 1055 al 1053 desde
01/01/2026, como rama por convenio 372/04. El historial anterior del 1055 se conserva.
No cambia la escala ni el porcentaje. Ver [[antiguedad-unificada-1053-por-convenio]].

