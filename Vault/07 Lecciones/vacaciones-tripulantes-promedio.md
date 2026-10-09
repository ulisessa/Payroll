---
aliases: ["Vacaciones de tripulantes: promedio de 6 meses"]
tipo: leccion
tema: vacaciones-sac-licencias
tags: [leccion, vacaciones-sac-licencias, project]
actualizado: 2026-10-04
---

# Vacaciones de tripulantes: promedio de 6 meses

**En una frase:** Vacaciones de embarcados = promedio de 6 meses / 25 * días; qué quedó configurado el 21/9/2026 y qué falta

**La regla** (Art. 34 CCT, confirmada por el asesor el 21/9/2026): promedio de los **seis
meses completos anteriores al mes de liquidación** / 25 * días de vacaciones, "o fracción en
casos de ingresos producidos en el semestre". Ejemplos dados: vacaciones en enero → promedio
julio a diciembre; febrero → agosto a enero.

**Lo que quedó configurado en ArbuTest:** variable de sistema `MESES_PROM_VAC` dada de alta,
parámetro `VAC_PROMEDIO` (1 en 729/15, 768/19 y 175/75; 0 de base, o sea tierra sigue con la
remuneración del mes; ESP quedó afuera a propósito), y la fórmula del concepto **3553**
ramificando por ese parámetro. La cadena `BASE_PROMEDIO` (acumulador, 126 conceptos) →
`SUMA_REM_VAC` (fuente de datos con la ventana `{PROM_DESDE}..{PROM_HASTA}`) ya existía y
estaba bien: sólo faltaba el divisor y enchufarla.

**Validado contra recibos reales de Meta4 de enero 2026: 49 de 52 al centavo.** Los tres que no
cierran dan DE MÁS en BC —03090 ×1,1428, 00191 ×1,0822, 02745 ×1,0706— y comparten haber tenido
TP 14 en agosto y una corrida **TP 99** en diciembre con un `PRE_VACACIONES` distinto al de las
otras corridas del mes. No es la liquidación final por sí sola: 40 de los 49 exactos también
tuvieron TP 14 en la ventana.

**Para revalidar sin pedir recibos:** Meta4 guarda su propio valor del día en la columna
`PRE_VACACIONES` (No. 127 de Columna Hist. Meta4), mes a mes y para todos — 416.053 filas.

**El divisor cero es una trampa:** hay 52 empleados con remuneración en la ventana y NINGÚN mes
de fase que la solape. Con `MAX(MESES_PROM_VAC,1)` la vacación se multiplicaba por seis en
silencio. Quedó `IF(MESES_PROM_VAC > 0, MESES_PROM_VAC, 6)`.

**Lo que todavía falta:**
- El **corte 30/70**: marinería cobra 30% como "Vacaciones" remunerativo y 70% como "Acuerdo
  sindical no remun Dto 633/18" (39 de 52 recibos); los oficiales cobran 100% remunerativo (13
  de 52). El concepto no remunerativo no existe en BC.
- Los **181 días** del CCT deciden los DÍAS, no el importe: 181 días corridos de prestación en
  el año → período completo; si no, 1 día cada 20 corridos. Prestación incluye enfermedad,
  accidente, francos, vacaciones y órdenes; lo único que resta es la licencia sin goce. Hoy
  `VACACIONES_ANUALES` aplica la escala por antigüedad del Art. 150 LCT.
- El **ancla** de la ventana: el motor la fija en el inicio de la licencia, la regla dice mes de
  liquidación. Sólo se separan en el pago anticipado.

Los devengados **no** se revierten: aunque se llamen así, esas liquidaciones se cobran. Los
anticipos vuelven como descuento (8830/8840/8850) y ésos no alimentan `BASE_PROMEDIO`, así que
la remuneración entra a la base una sola vez. Ver [[novedad-proyecto-sale-del-estado]] y
[[acumuladores-orden-calculo]].

## Relacionado

- [[recaida-accidente-mismo-valor]]
- [[recibo-vacaciones-paga-solo-vacaciones]]
- [[vacaciones-tierra-duplica-el-mes]]
- [[ventana-promedio-ausentismo]]
- Tema: `vacaciones-sac-licencias` (ver [[_Convenciones del vault]])
