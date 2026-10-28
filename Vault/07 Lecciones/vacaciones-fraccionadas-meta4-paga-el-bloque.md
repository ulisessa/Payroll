---
aliases: ["Vacaciones fraccionadas: Meta4 paga el bloque entero"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-15
---

# Vacaciones fraccionadas: Meta4 paga el bloque entero

**En una frase:** 04582 tomó sus vacaciones en tres tramos (7 + 6 + 1 días) y Meta4 liquidó los 14 de una vez el 27/2; BC, que sólo cuenta los AU9 que empiezan en el período, pagó 7.

`DIAS_VAC_INICIO` es una Fuente de Datos sobre `Estado Empleado` (estado `AU9`, Fecha Inicio dentro de la ventana, Fin Efectivo) y suma los días de los tramos que **empiezan** en el período. 04582 tiene tres tramos: 2 al 8/2, 6 al 11/3 y el 2/4. En Meta4 (`M4T_AUSENTISMOS`, tipo 9, "VACACIONES 2025 - EMBARCA") son los mismos tres, con `ANT_VAC_LIQ = 'N'`, y el 3553 de febrero (cont. 159, pago 27/2) es de **14 días** y no hay vacaciones en marzo ni abril. No es una novedad en Meta4 (`M4T_VAL_INCIDENCIA` no tiene 3553 ni 1054 de 04582): lo calcula Meta4.

**Es el único caso** de febrero a abril con más de un tramo AU9 (consulta sobre Estado Empleado de BC). La regla general no se pudo derivar de los datos: los tramos 2 y 3 figuran actualizados el 6/3 y el 7/4, después del pago, así que la liquidación de febrero no los veía en `M4T_AUSENTISMOS`; el 14 puede venir de un plan de vacaciones que no se migró. Mientras tanto se ajustó por novedad de importe (`scripts/Novedad3553Vacaciones04582.sql`, 6.111.053 = 65.475.571,16 / 6 / 25 × 14) y **en marzo y abril hay que cargar novedad de importe cero** para no pagar dos veces.

**Otros AU9 de febrero:** 04495 (20 días en Meta4 contra 21 de BC) y 03207 tienen el tramo cruzando el fin de mes (hasta el 1/3); Meta4 cuenta los días dentro del mes. No es lo mismo que 04582 y queda como hallazgo aparte.
