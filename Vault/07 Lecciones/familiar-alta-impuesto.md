---
aliases: ["Alta de impuesto del familiar"]
tipo: leccion
tema: descuentos-ganancias-sipa
tags: [leccion, descuentos-ganancias-sipa, project]
actualizado: 2026-10-04
---

# Alta de impuesto del familiar

Un familiar en la ficha no deduce Ganancias; lo habilita FEC_ALTA_IMP, que es un dato aparte de la vigencia de la fila

En `M4T_FAMILIARES` conviven **tres pares de fechas que no significan lo mismo**, y confundirlas cambia la retención:

| par | qué es |
|---|---|
| `FEC_INICIO` / `FEC_FIN` | vigencia de la fila del familiar; está cargada para todos |
| `FEC_ALTA_FAM_CARGO` / `FEC_BAJA_FAM_CARGO` | asignaciones familiares |
| **`FEC_ALTA_IMP` / `FEC_BAJA_IMP`** | **alta/baja como carga a efectos de Ganancias — el F.572** |

**Sólo el tercer par habilita la deducción.** Tener el familiar cargado no alcanza: la ficha sirve también para asignaciones, obra social y adherentes. Un `FEC_ALTA_IMP` vacío significa *nunca se declaró*, no *vigente desde siempre*.

**Por qué:** la migración original trajo sólo `FEC_INICIO`/`FEC_FIN`, y `CalcDeduccionesGanancias` leía "Fecha inicial" primero con la regla permisiva `(Fecha = 0D) or (Fecha <= FechaRef)`. Resultado: **todo** familiar en la ficha deducía. En enero 2026 BC deducía cónyuge a 186 empleados y Meta4 a 135 — 54 de más, ~8,3 M de retención. No se ve en un legajo suelto porque el importe es plausible; se ve en el total. Y en empleados con neto garantizado no se ve para nada: el grossing-up sube el bruto hasta compensar y el neto sale bien igual (ver [[grossing-up-tapa-errores]]).

**Cómo aplicarlo:** las fechas se migraron el 22/9/2026 a `Fecha alta impuesto` (50008) y `Fecha baja impuesto` (50009) de la $ext de Employee Relative, cruzando por empleado + parentesco + fecha de nacimiento (8.307 de 8.315 filas; las 8 restantes son familiares idénticos con fechas distintas). `FechaIngresoImpuesto` lee ahora 50008 y como respaldo 50211, y **nunca** 50000 ni 50010.

Regla verificada contra los 323 recibos de enero: acierta 315. Las 8 excepciones son 5 empleados a los que Meta4 les deduce sin cónyuge en la ficha, 2 a los que no les deduce teniéndolo vigente, y el 90251, donde Meta4 sigue deduciendo un cónyuge con baja al 31/12/2024 — ése parece un error de Meta4.

**En BC el par está duplicado, y una de las dos copias es nuestra y está muerta.** Meta4 tiene UN solo par de fechas de impuesto; BC tiene dos porque dos extensiones agregaron el mismo concepto a `Employee Relative`:

| campos | extensión | estado |
|---|---|---|
| "Fecha alta/baja impuesto" (50008/50009) | `a423950b` (Final Version) | **la buena**: espeja Meta4, 7.346 altas y 293 bajas cargadas |
| "Fecha Ingreso/Egreso Impuesto" (50211/50212) | `d4f5a6b7` (nuestra) | `ObsoleteState = Pending`, vacía en las 8.315 filas, en ninguna página |

También está vacío el par de asignaciones familiares (50010/50011), así que la cascada vieja caía siempre en "Fecha inicial".

Se quitó de `Cod50016` el respaldo que leía 50211/50212 —no podía aportar nada— y se expusieron 50008/50009 en la página de familiares, que antes no mostraba ninguna de las dos: el dato no era mantenible desde la interfaz. Y se vació `Cod50082 "Migracion Fechas ImpFam"` con su acción de página, que hacía lo contrario: aplanaba los tres pares en "Fecha inicial"/"Fecha final".

## Relacionado

- [[grossing-up-tapa-errores]]
- [[cuatro-conceptos-sin-disparar]]
- [[cuota-sindical-deducida-dos-veces]]
- [[diferencias-descuentos-enero]]
