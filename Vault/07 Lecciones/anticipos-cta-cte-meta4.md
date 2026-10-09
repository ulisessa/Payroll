---
aliases: ["Anticipos: cuenta corriente de Meta4"]
tipo: leccion
tema: migracion-meta4
tags: [leccion, migracion-meta4, project]
actualizado: 2026-10-04
---

# Anticipos: cuenta corriente de Meta4

Los anticipos no están en VAL_INCIDENCIA sino en M4T_CTA_CTE_ANTICIPOS, y se parten en dos modelos distintos

Los "Descuento Anticipo Poder / Llegada / Haberes" del recibo **no salen de
`M4T_VAL_INCIDENCIA`** (ahí hay 193 filas en 25 años, la excepción cargada a mano). Salen de
**`M4T_CTA_CTE_ANTICIPOS`**, una cuenta corriente por empleado:

- `CONC_DESC`: `C` concesión (positivo) · `D` descuento (negativo)
- `TIPO_ANT`: `ANP` poder · `ANL` llegada · `ANH` haberes · `AHA`
- `ID_BUQUE` + `ID_MAREA` **en la fila D**: a qué marea se imputa. Es autoritativo y NO se
  puede deducir de la fecha — en 03774 la concesión es de la marea 58 y el descuento de la 59.

**El dato se parte solo en dos modelos:**

- **ANP/ANL/ANH** son pares C/D del mismo día y el mismo importe, una sola cuota, contra una
  marea. ANL y ANP cierran en cero al peso sobre todo 2026. Van como **novedad** con el
  proyecto LLENO (excepción a [[novedad-proyecto-sale-del-estado]]: acá la fuente lo trae).
  Migradas 2.028 de 2026 el 18/9/2026 → conceptos 8830/8840/8850, 619.220.000 pesos.
- **AHA** amortiza: legajos de tierra (`8xxxx`/`9xxxx`), sin buque ni marea, cuotas mensuales
  el día 25. Ej.: 90361 recibe 14.000.000 y devuelve 4 cuotas de 2.000.000. Va a
  **`Préstamo Empleado`** + `Cuota Préstamo`. **PENDIENTE**, y BC no tiene concepto de
  descuento de préstamo (habría que usar 8850 o crear uno).

**Dos trampas de fecha:**

- El **período** de la novedad tiene que ser el de la liquidación, que el cierre de marea toma
  del ARRIBO. Si Meta4 imputa días después, caen en meses distintos y la novedad no se
  encuentra nunca. Se corrige leyendo el período de la liquidación real cuando existe.
- **No derivar el período del arribo del Job**: seis proyectos con mareas vivas en 2026 tienen
  inicio 23/09/2025 y arribo 12/10/2025 idénticos y cero liquidaciones — son fechas por
  defecto. Eso tiraba 590 filas.

Las filas con `ID_BUQUE = 'PM'` (Puerto Madryn) son anticipos de haberes imputados el 25
contra la nómina mensual, no de una marea: van sin proyecto.

## Relacionado

- [[novedad-proyecto-sale-del-estado]]
- [[equivalencia-id-puesto-meta4]]
- [[export-csv-decimal-con-coma]]
- [[historia-remuneraciones-migrada]]
