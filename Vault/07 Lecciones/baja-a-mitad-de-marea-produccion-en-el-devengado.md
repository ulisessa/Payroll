---
aliases: ["Baja a mitad de marea: la producción sale en el devengado"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-15
---

# Baja a mitad de marea: la producción sale en el devengado

**En una frase:** un tripulante que se baja antes del arribo cobra la producción hasta su día de desembarque en el devengado de la baja (Meta4 lo cierra al bajarse); el cierre de la marea descuenta lo ya pagado.

**Caso 04850** (HF801, marea 8): asignación del 17 al 27/2 y enfermedad desde el 28/2. Meta4 (cont. 5, imputación 10) pagó 2498 = 634.800 y feriado = 96.658; BC lo habría pagado en el cierre del 27/3. El diario de a bordo del tramo (63.480 kg × 10.000 por tonelada, MR08 entero) da 634.800 exacto, así que la rama no completa del 2498 (`DIARIO_KN_*` + `{ASIG_DESDE}..{ASIG_HASTA}`) ya calculaba bien; faltaba el momento.

**Datos (`scripts/Baja2498MitadMarea.sql`):** fuente `BAJA_EN_COBERTURA` (Personal Proyecto con Fecha Baja dentro de la cobertura), fuente `PROD_DEV_PREV` (2498 ya liquidado en devengados de ese proyecto) y el 2498 desde el 1/2: `CIERRE_MAREA|DEVENGADOS`, condición `TIPO_LIQ = 'CIERRE_MAREA' OR (BAJA_EN_COBERTURA > 0 AND TIPOACTIVIDAD = 1)` y `− IF(TIPO_LIQ = 'CIERRE_MAREA', PROD_DEV_PREV, 0)`. El feriado 1023 sale solo: ya suma `#2498 / DIAS_ENROLAMIENTO` (634.800 / 11). **Límite:** sólo poteros (`TIPOACTIVIDAD = 1`); los tangoneros no tienen producción diaria por especie.

**Pendiente de verificar en marzo:** que el cierre de la marea 8 le dé cero a 04850 (PROD_DEV_PREV = 634.800 contra una producción del mismo tramo).
