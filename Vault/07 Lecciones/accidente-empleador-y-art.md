---
aliases: ["Accidente: empleador y ART"]
tipo: leccion
tema: vacaciones-sac-licencias
tags: [leccion, vacaciones-sac-licencias, project]
actualizado: 2026-10-04
---

# Accidente: empleador y ART

El accidente se reparte entre el empleador (4120, primeros 10 días) y la ART (4125 + 4165); que el 4120 pague cero es correcto cuando hay días previos, no un defecto

Un accidente se paga con **cuatro** conceptos, no uno:

| concepto | quién paga | fórmula |
|---|---|---|
| **4120** Accidente | el empleador | `… / 30 × MIN(DIAS_ACCIDENTE, MAX(0, DIAS_ACC_EMPLEADOR − DIAS_ACC_PREVIOS)) × 13/12` |
| **4125** Prestación ILT | la ART, remunerativo | igual, pero `MAX(0, DIAS_ACCIDENTE − MAX(0, DIAS_ACC_EMPLEADOR − DIAS_ACC_PREVIOS))` |
| **4165** Prestación ILT no remunerativa | la ART | igual al 4125 pero sobre `#PROM_AUS_MES_NR` |
| 4124 Ajuste prestación ILT | — | inactivo |

Los dos topes son **complementarios**: el empleador cubre los primeros `DIAS_ACC_EMPLEADOR` (10) días
y la ART el resto. `DIAS_ACC_PREVIOS` (`DIAS_ESTADO_PREVIOS` sobre ACC) descuenta los días de
accidente ya consumidos, así que con 80 días previos el 4120 da **cero por diseño** y todo va por ILT.

Validado en enero de 2026 contra los recibos de Meta4, al centavo: el 04047 cobra
`4125 = 3.682.993,50` y `4165 = 8.269.220,10` —que es la "Prestación ART" y "Prestación ART no rem."
de su recibo— y el 4120 cero. El 02854 cobra `4125 + 4165 = 591.851,55`.

**Por qué:** en Meta4 la columna `H_ACCIDENTES` trae el **total** de la prestación, así que leerla y
compararla contra el concepto del empleador hace parecer que BC no paga nada cuando en realidad paga
por otros dos conceptos. Yo saqué el tope del 4120 creyendo que era un bug y le agregué 2.267.932,57
de más al 04047; hubo que revertirlo.

**Cómo aplicarlo:** ante un concepto que paga cero, buscar primero si otro concepto lo cubre, antes de
concluir que falta. Comparar `H_ACCIDENTES` contra `4120 + 4125 + 4165`, nunca contra el 4120 solo.
Relacionado: [[ventana-promedio-ausentismo]], [[enfermedad-sin-convenio-paga-cero]].

## Relacionado

- [[ventana-promedio-ausentismo]]
- [[enfermedad-sin-convenio-paga-cero]]
- [[exclusividad-vacaciones]]
