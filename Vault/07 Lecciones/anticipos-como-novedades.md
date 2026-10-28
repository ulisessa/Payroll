---
aliases: ["Anticipos como novedades"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-16
---

# Anticipos como novedades

> [!warning] Criterio histórico superado para nuevas cargas
> Para preparar otro mes, usar [[Préstamos y cuotas]], [[anticipos-cta-cte-meta4]]
> y [[anticipo-no-es-haber-del-recibo]]. Los pagos de anticipo tipo 4 no se agregan
> como haberes del recibo mensual. El proyecto se determina por el movimiento y
> el destino acreditado; no se deja vacío por regla general. Un patrón de importes
> no acredita por sí solo una entrada manual. El texto siguiente conserva el
> diagnóstico de una migración anterior; no es la receta para repetirla.

4803, 4813, 4823 y 4115 se cargan como Novedades y no tienen fórmula a propósito; 902 migradas de ene-jun 2026

Los anticipos **no se calculan**: alguien decide el importe y la fecha. Por eso los conceptos
**4803** (anticipo de poder), **4813** (de llegada), **4823** (de haberes) y **4115** (descuento
de días de enfermedad) están en BC **sin fórmula a propósito**, y se alimentan por `Novedad
Liquidación`.

Migradas 902 novedades de enero a junio de 2026, con los importes clavados contra Meta4:

```
4803  ANTICIPO_PODER    190.000.000     (149 de los 160 empleados caen en mayo)
4813  ANTICIPO_LLEGAD   123.500.000     (~80 por mes, 178 en junio)
4823  ANTICIPO_HABERE    70.916.087
4115  DED_ENFERMEDAD     -7.163.113     (3 empleados, meses sueltos)
```

**El proyecto, el convenio y la categoría van en blanco**: el motor los resuelve contra el
historial del empleado a la fecha, que es más confiable que deducirlos — ver
[[novedad-proyecto-sale-del-estado]].

**`2103 Presentismo Comercio` NO se migró**, aunque aparecía en la misma lista de "sin fórmula ni
novedades". En Meta4 crece suave mes a mes para el mismo empleado —113.497,96 · 113.497,96 ·
114.377,79 · 116.882,03 · 118.760,20 · 120.638,38—, y eso es un **porcentaje sobre el sueldo**,
no un importe que alguien decide. Importarlo como novedad congelaría el valor y taparía la falta
de la fórmula.

**Cómo distinguirlos en general:** un importe que sigue al sueldo mes a mes es un cálculo; uno que
salta sin patrón, o que aparece en meses sueltos, es una novedad.

## Relacionado

- [[novedad-proyecto-sale-del-estado]]
- [[a-cuenta-futuros-aumentos-puerto]]
- [[adicional-art-23-vs-art-33]]
- [[adicional-tareas-mecanicas]]
