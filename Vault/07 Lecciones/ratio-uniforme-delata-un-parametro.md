---
aliases: ["Un ratio uniforme delata un parámetro"]
tipo: leccion
tema: parametros-atributos
tags: [leccion, parametros-atributos, project]
actualizado: 2026-10-16
---

# Un ratio uniforme delata un parámetro

Si todos los conceptos de alguien salen al mismo porcentaje, el error está arriba de todos ellos

> [!tip] Cuando una liquidación difiere **concepto por concepto en la misma proporción**, no hay que buscar en los conceptos: hay un solo valor mal, y está en la raíz de la que todos cuelgan.

Un empleado de tierra daba 1,27 M abajo de Meta4. El detalle:

| | BC | Meta4 | ratio |
|---|---|---|---|
| Asig. zona desfavorable | 107.397,80 | 400.899,65 | 0,26789 |
| Horas extras 50% | 14.047,28 | 52.436,34 | 0,26789 |
| Horas extras 100% | 3.405,40 | 12.711,84 | 0,26789 |

Tres conceptos sin relación entre sí, el mismo ratio a cinco decimales. Lo único que comparten es que todos derivan del básico. Y el básico era:

```
BASICO_372/04_CA10   2023-01-12   340.540,00   "STIA Of.Especializado Dic 2023"
BASICO_372/04_CA09   2026-01-01 1.271.184,00
```

`340.540 / 1.271.184 = 0,26789`. **La categoría nunca recibió la vigencia 2026** y liquidaba con el valor de hacía tres años. En el mismo convenio había **cuatro** así —CA05, CA07, CA08 y CA10— contra cuatro que sí tenían 2026.

El síntoma no aparece en los importes grandes sino en el **patrón**: ordenar los conceptos por ratio en vez de por diferencia pone el problema a la vista en una pantalla.

## Tres maneras de que un parámetro valga cero, y las tres se parecen

El mismo día, otro concepto —`1823 = round(BASE_ZONA * PCT_FRIO_PTA, ...)`— pagaba **cero** a dos empleados. El parámetro existía:

```
PCT_FRIO_PTA_372/04_CA10   0,333   En Uso = 0
PCT_FRIO_PTA_FA_FA39       0,333   En Uso = 0
```

1. **Sin fila para el alcance que hace falta.** Los dos que lo cobran son **CA09**, y no había fila de CA09.
2. **`En Uso` = 0.** Aunque hubiera existido la fila correcta, apagada resuelve a cero igual que ausente.
3. **El valor truncado.** `0,333` no es un tercio: con él a uno le faltaban 602,75. El implícito era **1/3 exacto** —`1.808.259,24/3 = 602.753,08` y `1.849.572,72/3 = 616.524,24`, clavados contra Meta4—. La columna `Valor` es `decimal(38,20)`: no hay motivo para redondear un tercio a tres decimales.

Las tres fallan **sin error**, y las tres dan el mismo síntoma que [[variables-rotas-valen-cero]] y [[un-valor-una-fuente]].

> [!warning] El alcance se mide, no se supone
> La tentación era cargar `PCT_FRIO_PTA` por categoría CA09. Pero de los doce del convenio sólo **dos** lo cobran, y uno de los que **no** lo cobra también es CA09. Es por empleado. El control que lo mostró: el porcentaje implícito (`1823 de Meta4 / BASE_ZONA de BC`) da **0,33333** en los dos y **0,00000** en los otros diez.

## Y dos trampas de forma que aparecieron en el mismo lote

**El mismo descuento, tipificado de dos maneras.** `4115 Descuento días de enfermedad` era `Descuento Empleado` y `4743 Descuento días de vacaciones` —el mismo constructo— es `Haber Remunerativo`. BC deja el primero fuera de `Total Haberes` y Meta4 lo netea en su `TOT_DEVENGO`, así que todo enfermo mostraba una brecha de bruto **falsa**: uno aparecía 1,36 M arriba y su diferencia real eran 172.920.

**Una novedad duplicada paga el doble.** Un concepto sin fórmula cobra lo que diga la novedad, y el motor **suma los importes** de las que materializa en la misma incidencia. Dos filas de 1.281.441,39 —una de un usuario y otra de la migración— pagaron 2.562.882,78. Ver [[adicional-frio-por-tramo-del-diario]], donde el mismo duplicado sumaba las *cantidades* y falseaba los días del recibo.

## Una coincidencia algebraica no identifica la causa

Al reconstruir Ganancias de febrero, un residuo coincidía exactamente con
`IG_DED_ESP / 12`. También era `40 % × MNI`, porque la deducción especial original
equivale a `4,8 × MNI`. No demuestra una doceava de SAC faltante.

La regla original `5599` de gastos educativos usa ese tope del 40 % y participa en
`5002`. Una fuente personal retroactiva por encima del límite y el residuo original
son consistentes con esa deducción. Deben distinguirse el gasto médico acreditado
en columnas históricas y el educativo inferido por regla y saldo; no alterar `5010`
por la primera equivalencia numérica encontrada. Un dato modificado después del
recibo no certifica su entrada original ni autoriza trasladarlo a enero.

Evidencia de fórmulas y reconstrucción en
`.snapshots/revision-netos-contribuciones-febrero-20261016/`.
Ver [[ganancias-devolucion-mensual-y-unidades]].

## Relacionado

- [[variables-rotas-valen-cero]]
- [[un-valor-una-fuente]]
- [[basico-de-tierra-por-empleado]]
- [[dos-parametros-mismo-nombre]]
- [[antiguedad-maxima-vigencia-avisa-de-mas]]
- [[adicional-frio-por-tramo-del-diario]]
