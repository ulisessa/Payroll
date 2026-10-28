---
aliases: ["El feriado de guardia del 1/1 en el devengo de francos"]
tipo: leccion
tema: francos
tags: [leccion, francos, project]
actualizado: 2026-10-15
---

# El feriado de guardia del 1/1 en el devengo de francos

> [!note] Enero a junio debe reproducir Meta4 al recalcular.
> El usuario confirmó el 15/10/2026 que, aun tratándose de un error conocido del calendario de Meta4, los tres finales señalados deben conservar sus resultados originales mediante novedades. Esta instrucción reemplaza el criterio anterior de aceptar la diferencia en BC. La regla general de feriados se conserva; la excepción queda identificada en la novedad individual.

En el devengo del 1062 la rama de tierra suma `DIAS_FERIADOS_GUARDIA`. En enero hay 16 empleados con guardia de puerto y feriado del 1/1:

- **11 con guardia todo el mes (31 días)**: Meta4 suma el feriado y BC también. Cierran.
- **5 con guardia parcial que contiene el 1/1** y después francos, ausencia o baja (tramos de 2, 2, 3, 14 y 28 días): Meta4 **no** suma el feriado (no aparece `DIAS_FERIADO` en su corrida) y BC sí. La diferencia de tres finales fue reconocida como error de calendario en Meta4; los otros dos casos siguen pendientes de confirmación funcional.

**No es una regla general por tramo parcial:** en febrero más de treinta empleados de guardia con tramo parcial (17 a 28 días) *sí* cuentan sus dos feriados de carnaval y cierran con Meta4. La omisión observada en enero no debe convertirse en una condición de cálculo por duración del tramo o por liquidación final. Los 83 finales con marea cuentan el 1/1 por `DIAS_FERIADOS_MAREA`, otra rama.

**Criterio vigente:** cargar únicamente las tres novedades autorizadas del 1062 con los días originales de `DS_FRANCOS_DEV` de Meta4. El motor recibe esos días en **Importe**, sustituye la fórmula y los guarda como **Cantidad** del devengo, con importe monetario cero. Una novedad con sólo Cantidad no sustituye la fórmula del 1062. La carga no debe modificar directamente recibos ni movimientos de la cuenta corriente; el recálculo posterior usa la reversión normal de BC.

**Verificación previa del 15/10/2026:** las tres finales están calculadas en BC y el 1062 incluye el día adicional del feriado. Ya existen novedades originales del 2803 aplicadas y coincidentes con `FCOS_NO_GOZADOS` de Meta4; no deben duplicarse. También se conserva el cero explícito original del 1023. Los consumos del 1063 proceden de lotes anteriores, sin depender de los tres lotes de devengo final que se corregirán.

La confirmación del error de Meta4 cubre sólo esas tres finales. Los otros dos tramos parciales de enero siguen pendientes de confirmación; no extenderles el ajuste automáticamente.

**Aplicado el 15/10/2026:** cargadas las tres novedades individuales del 1062, pendientes, con tipo `LIQ_FINAL` y proyecto explícito para que sólo entren en sus finales de enero. El ensayo con rollback y la revisión independiente pasaron. Se reinició BC252 y se verificó la conservación de los recibos, fórmulas, novedades anteriores y movimientos. No se reabrió ni recalculó ninguna liquidación; ese paso queda pendiente para que el devengo y su lote reflejen los días originales. Respaldo operativo privado: `.snapshots/novedades-francos-enero-20261015/`.

El punto se refiere al **devengamiento de días de francos**. No modifica por sí mismo el precio del feriado ni la parametrización de los conceptos 1022/1023.

## Relacionado

- [[feriado-divide-por-30-fijo]]
- [[franco-porcentaje-por-pesqueria]]
