---
aliases: ["La cobertura parcial no es una ausencia"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, cobertura, prorrateo]
actualizado: 2026-10-11
---

# La cobertura parcial no es una ausencia

**En una frase:** para prorratear un sueldo mensual por los días que no se devengaron hay que mirar la **fase**, no la cobertura de la liquidación: una cobertura parcial casi siempre significa que otra liquidación cubre el resto.

## El caso

El `4703 Deducción por ausencias` tenía la **fórmula vacía** desde 2023 —el concepto estaba, con sus ocho fracciones cargadas, y simplemente no calculaba nada—. Meta4 sí deduce, y la regla salió exacta de sus datos:

```
deducción = (sueldo mensual + zona desfavorable) × (30 − días de alta) / 30
```

Las dos coberturas parciales de enero de 2026 daban el número correcto, y es ahí donde está la trampa: **medir con esa muestra no distingue las dos definiciones.**

| | cobertura | días de fase |
|---|---|---|
| de alta desde el 5 | 26 | 26 |
| de alta del 9 al 24 | 16 | 16 |

## Por qué la cobertura está mal de todos modos

Porque en esta nómina la cobertura es parcial **por diseño**. De las 570 liquidaciones de enero, **397 tienen cobertura menor al mes**: los 90 cierres de marea, los 90 devengados, las 64 de vacaciones y 145 de las 318 regulares. La regular de un tripulante cubre sólo los días que no cubre el cierre de su marea ([[cobertura-en-tramos]]).

Prorratear por la cobertura les habría descontado esa proporción del sueldo a casi toda la nómina. Por la fase, en cambio, sólo **15 empleados** tienen el mes incompleto, y de ésos **2** tienen sueldo mensual — exactamente los 2 que Meta4 deduce, sin uno de más ni uno de menos.

> [!tip] La fase contesta la pregunta correcta
> "¿La liquidación paga estos días?" no es lo mismo que "¿existía la relación laboral?". El sueldo
> mensual se devenga por lo segundo. Es la misma distinción de [[nomina-no-es-intervalo-presencia]].

## La otra mitad: el orden

La deducción estaba declarada en el **orden 640**, y ahí llega tarde. De los acumuladores que el sueldo alimenta, **seis tienen lectores antes de 640**: `BASE_ZONA` (1823, orden 30), `BASE_IG4` (2703, 28), `BASE_AUSENTISMO` (4125, 370), `REMUNERATIVO_BRUTO` (3554, 452), `BASE_PROMEDIO` y `BASE_SAC` (3813, 470). Todos habrían trabajado sobre el sueldo **sin deducir**, y el síntoma sería un SAC y un promedio de más, sin un solo error ([[acumuladores-orden-calculo]]).

Se movió al **orden 29**: después del `1003` (10) y del `2703` (28), que son lo que lee, y antes de todo lo demás. Que el `2703` corra antes es deliberado — Meta4 calcula la zona sobre el básico **completo** y recién después deduce las ausencias de los dos juntos.

## El cerrojo que la hace segura

La base es `(#1003 + #2703)`, y para un tripulante eso **ya da cero**: su sueldo son el 1053, 1063, 1073 o 1083, no el 1003. Así que la fórmula se autolimita aunque los tipos de liquidación la dejaran pasar. El `Tipos Liq. Aplicables = REGULAR|LIQ_FINAL|RELIQUIDACION` es un segundo cerrojo, no el único.

## Cómo aplicarlo

- Para prorratear cualquier cosa mensual, `DIAS_ALTA_30` ([[Variables de sistema]]); nunca `DIAS_MES`, que da 31 en enero.
- Antes de darle fórmula a un concepto que reduce bases, mirar **quién lee esas bases y en qué orden** con [[Dónde se usa un símbolo]]. Fue lo que destapó el problema del 640.
- Un concepto con la fórmula vacía no está apagado: está **mudo**. Es la misma familia que [[devengados-no-gozados-pagaban-cero]].

## Relacionado

- [[cobertura-en-tramos]] · [[nomina-no-es-intervalo-presencia]] · [[acumuladores-orden-calculo]]
- [[concepto-negativo-despues-de-sus-consumidores]] — mover el productor hacia atrás, no al consumidor
- [[feriado-divide-por-30-fijo]] — el otro lugar donde el divisor es 30 y no el calendario
