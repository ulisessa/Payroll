---
tags: [lección, vacaciones, promedios, convenio, meta4]
fecha: 2026-10-10
---

# El promedio de vacaciones divide por días, no por meses

```
promedio   = suma de remuneraciones de la ventana ÷ DÍAS de prestación × 30
valor día  = promedio ÷ 25
importe    = valor día × días no gozados
```

Un **"período mensual" son treinta días**, no un mes del calendario. El art. 49 del CCT dice "el total
así obtenido, se dividirá por la cantidad de períodos mensuales considerados", y así es como hay que
leerlo.

## Cómo se confirmó, que es la parte que importa

No se infirió de los importes: **Meta4 guarda el promedio que usa**, en la columna `PROM_6_ULT_MES`, y
de ahí sale todo lo demás. Dos identidades que se cumplen exactas:

```
PROM_6_ULT_MES / 25            = PRE_VACACIONES      (el valor del día)
PRE_VACACIONES * DIAS_VAC_NO_GOZ = VAC_NO_GOZADAS
```

Y `PROM_6_ULT_MES` = base ÷ días × 30, **al centavo en los seis** tripulantes dados de baja en enero
de 2026, con 94, 80, 121, 64, 107 y 37 días de prestación.

La lección de método: antes de deducir la regla de un sistema legado a partir de sus importes,
**buscar si el legado guarda el intermedio**. Los acumuladores de Meta4 —clase `AX`, `O`, `BL`— tienen
las bases, los promedios y los precios unitarios; `PRE_*` es el valor unitario y `PROM_*` el promedio.
Tres hipótesis sobre la misma gente fallaron antes de mirar ahí.

## Por qué contar meses estaba mal

Un mes trabajado a medias **aporta su fracción al numerador pero pesa un mes entero en el divisor**. A
un tripulante que entró el 25 de noviembre, ese mes le aportaba seis días de sueldo y le sumaba
treinta al divisor: su promedio salía **38% corto**.

Medido contra Meta4 antes del cambio: 0,62 · 0,71 · 0,78 · 0,89 · 0,89 · 1,01. **Lo desparejo era la
pista** —cada uno entró un día distinto del mes—, y el único que casi cerraba (1,008) había entrado un
día 2.

Con días: exacto en los seis.

## El síntoma uniforme que vino después

Una corrección anterior —excluir el mes de ingreso del divisor— dejaba los seis en 1,020-1,047: un
sesgo **parejo** de +2 a +4%. Eso era [[ratio-uniforme-delata-un-parametro]] en acción: un ratio
uniforme no son seis errores, es un parámetro. Era el divisor, y la aproximación "excluir el mes
parcial" se descartó por la regla real.

## Lo que esto deja de necesitar

- El debate sobre si el mes de ingreso cuenta: cuenta **por los días que cuenta**.
- `CalcMesesPromedioVacaciones`, con su bucle mes a mes y su tope de seis, para este cálculo. Se
  reemplaza por `CalcDiasPrestacionPromedioVac`, que recorre las FASES —un temporario puede tener
  varias en la ventana— y acota por los dos extremos. El de arriba importa: la ventana de una
  fracción llega a fin de mes, pero el que se da de baja el 28 prestó 28 días.

Sigue haciendo falta la ventana recortada a la fase
([[ventana-promedio-vacaciones-corta-en-la-fase]]) y la bandera `VENT_PROM_ES_MES_ACTUAL`: los
7.678.433,99 de 04807 incluyen su propia liquidación final, sin la cual no cierra.

`MESES_PROM_VAC` queda sembrada y la sigue usando el 3553 —las vacaciones normales—, que es otra
discusión y no se tocó.
