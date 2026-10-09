---
aliases: ["Historia de remuneraciones migrada"]
tipo: leccion
tema: migracion-meta4
tags: [leccion, migracion-meta4, project]
actualizado: 2026-10-04
---

# Historia de remuneraciones migrada

La historia de Meta4 en BC son liquidaciones HIST_REMUN; desde el 23/9/2026 cubre 2024 y 2025

La historia de remuneraciones vive en BC como **liquidaciones de tipo `HIST_REMUN`**, una por empleado y mes, con líneas de tipo acumulador (Tipo Concepto 6, orden 0). Hoy cubre **enero 2024 a diciembre 2025** (10.032 liquidaciones). El archivo crudo de Meta4 —`Hist. Liq. Meta4` + `Valor Hist. Meta4` + `Columna Hist. Meta4`— tiene más años que eso; las liquidaciones se generan a mano por SQL.

| línea | fuente Meta4 | para qué |
|---|---|---|
| `BASE_PROMEDIO` | `TOT_REM_IMP` sumado por empleado y mes | promedios de vacaciones y de ausentismo |
| `HIST_REMUN_BRUTO`, `HIST_BASE_IG4`, `HIST_BASE_EXT_IG4`, `HIST_BASE_SAC_DEV`, `HIST_SS_LIQUIDADO`, `HIST_SS_SAC_DEV` | acumuladores YTD de Ganancias diferenciados | base del impuesto — **sólo 2025** |

**Por qué:** los conceptos `HIST_*` tienen `Vigencia Hasta` en 2025-12-31 a propósito, porque son del ejercicio fiscal 2025 y en 2026 conviven con los conceptos reales; meterles líneas de otro año los saca de vigencia y hace contar doble. `BASE_PROMEDIO` no tiene ese problema: es un acumulador común, y las fuentes que lo leen filtran por código de concepto directamente.

**Cómo se nota que falta un tramo:** el promedio sale diluido, no vacío. El divisor cuenta **meses de alta** (que es lo correcto), así que una ventana con nueve meses de datos y doce de alta divide por doce. El 00949 pagaba 1.002.502 de enfermedad contra 1.094.676 de Meta4 — 8,4% bajo — sólo por los tres meses de 2024 que faltaban. Nunca hay que "arreglarlo" dividiendo por los meses con datos: eso se pasa por arriba tanto como el otro se queda corto.

**Cómo aplicarlo:** el script está en el scratchpad como `hist2024.sql`, con `$(Commit)` para ensayo y tres invariantes (suma BC = suma Meta4, sin duplicados empleado/período, sin líneas huérfanas). Para extender a otro año alcanza con cambiar el año; crea también los `Período Liquidación` que falten.



**`TOT_REM_IMP` NO es "el total remunerativo".** Hay liquidaciones sueltas cuyo único concepto es no remunerativo y que igual llenan esa columna: el 00949 tiene una de 200.000 el 1/10/2024, `TP_IMPUT` 10, sin buque ni marea. Meta4 no las promedia.

Se reconocen por **`TOT_HAB_CON_AP` (haberes CON aportes) en cero**: si nada del importe soporta aportes, no hay remuneración que promediar. La ausencia de fila en `Valor Hist. Meta4` es lo mismo que cero, así que el control va por `NOT EXISTS`, no por `= 0`.

Dos caminos que parecen buenos y no lo son:
- **Usar `TOT_HAB_CON_AP` como importe**: está topeado por el límite de aportes. Para el 00949 da 25.250.443 contra los 42.374.558 que Meta4 promedia. Sirve para decidir si la entrada entra, no para decir cuánto.
- **Restar `TOT_OTR_NO_REMUN_ST`**: también recoge el redondeo de las liquidaciones normales (0,76), que Meta4 sí promedia. Deja el promedio en 1.568.456.

Corregido en 2024 el 23/9/2026 (616 líneas, 348 empleados, −327 M) con `fix_base_promedio_nr.sql`. **2025 quedó sin tocar**: aplicar ahí la misma regla movía el total +1.513 M, señal de que esas líneas se cargaron con otro criterio, y el control del 00949 ya da exacto sin tocarlas. Antes de tocar 2025 hay que entender cómo se cargó, porque las vacaciones están validadas 52/52 contra esos datos.

Ojo también con los `BASE_PROMEDIO` negativos: hay dos en enero 2024 (02937 y 04194) y vienen así de Meta4, que tiene `TOT_REM_IMP` negativo por un ajuste. No son un defecto de la carga.

## Relacionado

- [[anticipos-cta-cte-meta4]]
- [[equivalencia-id-puesto-meta4]]
- [[export-csv-decimal-con-coma]]
