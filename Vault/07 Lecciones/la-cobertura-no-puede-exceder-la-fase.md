---
tags: [lección, cobertura, liquidación-final, francos]
fecha: 2026-10-10
---

# El "resto del período" no es el resto del mes

Quien se da de baja el 16 **no genera cobertura del 17 al 31**. En esos días no hay vínculo, y
cubrirlos no sólo le hace pagar días que nadie trabajó: le hace **devengar** por ellos.

El reparto de [[cobertura-en-tramos]] ya repartía bien entre liquidaciones —un día se liquida una
vez— pero el tipo que se queda con "lo que sobra" reclamaba hasta fin de mes sin mirar la fase.

**Medido en enero de 2026**: 136 días de cobertura indebida en las 8 liquidaciones finales y 48 más
en 4 regulares. El recibo de Meta4 lo dice en la cara: *"Período Pagado: 25/01/2026 al 28/01/2026"*
para un tripulante dado de baja el 28, donde BC daba 25 al 31.

## Por qué se recorre día por día y no se recorta el rango

Un **reingreso parte el mes en dos**: entre la baja y el alta nueva hay días sin vínculo *en el
medio* del período, y un recorte por los extremos los dejaría adentro. En una dotación de temporada
no es un caso raro — hay empleados con doce fases ([[antiguedad-suma-de-fases]]).

## El envolvente no es la cobertura

`Cobertura Desde/Hasta` de la cabecera es el **envolvente** de los tramos, y una liquidación final
suele tener dos —los días antes de la marea y los de después— con el cierre en el medio. En enero,
la final de 04807 tiene los tramos `[1-2]` y `[25-31]` y un envolvente de `[1-31]`.

**Cualquier cálculo que cuente días tiene que recorrer los TRAMOS**, no el envolvente: contarlo por el
envolvente le sumaría los 22 días que el cierre ya pagó. El contexto los tiene cargados en
`FTramosDesde`/`FTramosHasta` y ya hay tres lugares que los intersecan; el cuarto es
`DIAS_DEVENGA_FRANCOS_COBERTURA`, que nació usando el envolvente y se corrigió antes de que llegara
a pagar nada.

## Dos cosas que parecían obstáculos y no lo eran

- **El motor escribe las líneas mientras calcula** (`Insert(true)`, no un Record temporary), así que
  un concepto de orden 400 SÍ ve el lote que generó otro de orden 55 en la misma liquidación.
- **El cálculo borra las líneas previas** antes de recalcular (`BorrarLineasLiquidacion`), así que no
  hace falta que "Reabrir" las borre — Reabrir sólo cambia el estado a Borrador.

Lo que queda como límite real para el devengo de francos en la final es que **el lote se fecha por el
documento y no por el estado que lo devengó**, y la regla correcta es que el devengo cuente si es
anterior al goce. Eso es un campo que hoy no existe y entra en [[pendiente-rediseno-francos]].
