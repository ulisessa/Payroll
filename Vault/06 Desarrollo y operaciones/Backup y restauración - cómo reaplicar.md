---
tipo: proceso
tags: [desarrollo, backup, restauracion, configuracion, runbook]
fuente: [REAPLICAR_TRAS_RESTORE.md, scripts/EstadoConfiguracion.sql, scripts/CargarFraccionesMeta4.sql, scripts/RestaurarFiltrosFuenteDatos.sql, scripts/CorregirBaseIG4Duplicada.sql, scripts/DiagnosticoTablasExtension.sql]
actualizado: 2026-10-04
---

# Backup y restauración - cómo reaplicar

Qué hacer cuando se restaura la base de BC (`Migr2013R2`, empresa `ArbuTest`) desde un backup anterior a trabajo de configuración, o cuando una publicación se llevó datos. La fuente es `REAPLICAR_TRAS_RESTORE.md` (escrito el 8/9/2026 sobre el backup del 7/9 14:31). Esa nota es una **foto de ese día**: su «Dónde estamos» (versión 1.0.0.412, sync pendiente) ya no describe el estado actual (`app.json` está en 1.0.0.565); lo que sigue es el procedimiento generalizado y la cronología del incidente.

> [!danger] Principio
> No suponer el estado de los DATOS. **Medir primero** (Fase C) y reaplicar sólo lo que el script marque como faltante. Una restauración mezcla datos viejos con configuración nueva: lo que se creó *después* del backup no está, y lo que se recargó a mano puede estar a medias.

## Cronología del incidente de septiembre 2026 (para entender qué se pierde)

| Cuándo (07–08/09) | Qué pasó |
|---|---|
| 14:31 | Hora del backup restaurado |
| 14:52 | `PROPUESTA_TOPE_SIPA_PERIODO.md` (sólo propuesta) |
| ~22:00 | Recarga de Fracción Acumulador desde la especificación de Meta4 |
| 23:05 / 23:24 | Exports de la configuración sin / con el concepto `NETO_GARANT` (se creó entre ambos) |
| 00:40+ | Se detecta que los **76 filtros** de Fuente Datos desaparecieron |

La causa de fondo y las lecciones: [[rad.json - peligro]], [[ConfigPackage y RapidStart - qué lleva y qué no]].

## Fases

### A. Antes de restaurar
1. **Resguardar fuera del proyecto el último export de configuración** (en el incidente fue `Genérico07_09_2026_23_24_04.xlsx`, ignorado por git): era la **única** copia de los 76 filtros, `NETO_GARANT` y las escalas.
2. Anotar contra qué se trabaja: base `Migr2013R2`, empresa `ArbuTest`. Los scripts empiezan con esas dos variables; si la empresa es otra, cambiar la primera línea.

### B. Código (puede hacerse mientras se restaura)
Dos bloqueadores de publicación que ya ocurrieron:
- **Carpetas duplicadas** (`src/Tables copy/`, 57 archivos idénticos a `src/Tables/`): `AL0275` y no compila. No estaban en git; borrarlas no pierde nada (ya no existe).
- **`.vscode/rad.json`** con `Removed` poblado: borrarlo ([[rad.json - peligro]]).
- Compilar y publicar; **no subir la versión** ([[Versionado de app.json]]). Al publicar corre `Cod110038` y completa Config. RRHH **sólo si está en blanco** ([[Install y Upgrade - qué siembra cada uno]]).

### C. Medir
Correr `scripts/EstadoConfiguracion.sql` (sólo lee; imprime el valor esperado al lado del real):

| Bloque | Pregunta | Esperado (el 8/9) |
|---|---|---|
| 1 | ¿Publicada la versión con los campos nuevos? | `publicada`, `NETO_GARANT` / `BASE_IG4` |
| 2 | ¿Existe el concepto `NETO_GARANT`? | Informativo, orden 5, con fórmula |
| 3 | Filtros de Fuente Datos | **76**, ninguna fuente activa sin filtros |
| 4 | Fracción Acumulador | **1208**, `BASE_IG4` **123**, sin solapamiento ni huérfanos |
| 5 | Parámetros `NETO_GU_*` | 90016, 90212, 90302, 90361 |
| 6 | Conceptos activos sin fórmula | cuantos menos mejor |

Los valores esperados son del 8/9/2026: **recalcularlos** si la configuración cambió desde entonces. Las fases D–F son **condicionales**: sólo lo que el script marque como faltante.

### D. Datos, en este orden
1. **Fracciones** — si no da 1208: `scripts/CargarFraccionesMeta4.sql` (borra la tabla entera y reinserta; ya excluye 4 fracciones duplicadas de Meta4). Se hizo **por SQL y no por ConfigPackage** porque el import por Excel «aplicó 1212 registros informando cero errores y dejó la tabla igual».
2. **Filtros de Fuente Datos** — si no da 76: `scripts/RestaurarFiltrosFuenteDatos.sql`. Sin filtros cada fuente lee su tabla entera: una liquidación pasó de segundos a **123 s** (65,5 s en `ResolveFuente`, 26,6 s en `CalcFinEfectivo`, 0,22 s de cálculo real).
3. **Concepto `NETO_GARANT`** — si falta, crearlo a mano: código `NETO_GARANT`, vigencia desde `12/01/2023`, tipo **Informativo** (no Haber: `CalcNetoDesdeBD` suma haberes y el grossing-up no convergería), orden de cálculo 5, fórmula `NETO_GU * (1 + DIAS_VAC_INICIO / 150)`, aplica a Todos. **La fórmula no puede referenciar `COMPLEMENTO_GU`** (el objetivo se movería en cada iteración; el motor corta con error).
4. **Config. RRHH** — si los dos punteros están vacíos: `Concepto Neto Garantizado (Grossing-up)` = `NETO_GARANT`, `Acumulador Haberes Gravados` = `BASE_IG4`.
5. **Parámetros y escalas** — si faltan los `NETO_GU_*`, reimportar sólo esa tabla (leer E antes).

### E. Que no se vuelva a romper
- Revisar el flag **«Eliminar los registros de tablas antes del procesamiento»** en el paquete para la tabla **60029** y el resto.
- **No reimportar el ConfigPackage completo** sobre tablas que ya están bien.

### F. Revisar a mano (ningún script lo resuelve)
- **Invertir Signo** de las fracciones (no viaja en el paquete, queda en 0).
- Concepto **1223**: su fórmula `MAX(GARANTIA_MAREA, PROD_MAREA)` referencia dos variables inexistentes: cerrar la vigencia o crear las Fuentes de Datos.
- Concepto **4743**: el prorrateo `/30 * MIN(DIAS_VAC_PERIODO, 30)` estaba dentro de la rama equivocada del `IF`; la corrección va con **vigencia nueva**, no editando la del 12/01/2023 (las liquidaciones ya calculadas deben seguir reproduciéndose igual). Ver [[conceptos-tres-vigencias]].
- Redondeos que no cancelan entre 1003 (`0,0001`) y 4743 (`PRECISION_REDONDEO`=1): dejan `0,489` en `BASE_SS_TRAB`.

### G. Validar
1. Reiniciar el service tier (o `Sync-NAVTenant`) para vaciar la caché ([[sql-directo-deja-cache-rancia]]).
2. Re-correr `EstadoConfiguracion.sql`: todo en verde antes de liquidar.
3. Liquidar enero 2026 y comparar **Guillermo Re** contra el recibo: es el caso difícil (vacaciones **y** grossing-up; la única combinación que expuso la doble contabilización). Desglose: `scripts/DiagnosticoLiquidacion.sql` (las grillas 5 y 6 son las de grossing-up). Ver [[grossing-up-tapa-errores]].
4. Si vuelve a tardar, perfilar: `ResolveFuente` alto = faltan filtros.

## La decisión que quedó abierta: BASE_IG4 vs BASE_EXT_IG4

La corrección de las fracciones asume que `BASE_IG4` son los haberes **habituales** y `BASE_EXT_IG4` los **extraordinarios**, y que las fórmulas 4750, 7000 y 5010 los suman porque son disjuntos (9 de 13 conceptos de `BASE_EXT_IG4` ya lo eran; el campo de cabecera se llama «Haberes Ordinarios Gravados»; la 5010 lleva `YTD_HAB_GRAV_ANUAL` en paralelo a `YTD_HAB_EXTORD_ANUAL`). Si resultara al revés, el arreglo es sacar el `+ BASE_EXT_IG4` de esas tres fórmulas y **no** tocar las fracciones. **No hacer las dos cosas.** Si las fracciones se cargaron con los 4 duplicados, `scripts/CorregirBaseIG4Duplicada.sql` los quita sin recargar todo.

> [!warning] Sin verificar
> No se confirmó en esta revisión si esa decisión se cerró después del 8/9.

## Qué NO se puede reaplicar desde ningún paquete

Ver la lista de tablas fuera del ConfigPackage en [[ConfigPackage y RapidStart - qué lleva y qué no]]: Estado Empleado, Cód. Estado Empleado, Filtro/Fuente Datos, Tipo Liquidación, Novedades, Préstamos. Para esas, la única fuente es el backup, un export (`Genérico*.xlsx`) o los scripts de migración desde Meta4 ([[Scripts SQL y PowerShell del repo]], [[previsualizar-antes-de-migrar]]).
