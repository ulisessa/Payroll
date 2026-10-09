---
aliases: ["Dim 2: Actividad en NAV, Marea en BC"]
tipo: leccion
tema: integracion-nav
tags: [leccion, integracion-nav, project]
origen: 9185b3df-1c53-44a4-a540-9174e99644c1
actualizado: 2026-09-11
---

# Dim 2: Actividad en NAV, Marea en BC

Las dimensiones 2 y 3 están cruzadas entre NAV y BC (actividad y marea intercambian lugar); copiar posicionalmente deja cada proyecto con marea LAN o CAL, sin error

**Las dimensiones 2 y 3 están CRUZADAS entre los dos lados.** Es un intercambio, no un corrimiento:

| | dim 1 | dim 2 | dim 3 |
|---|---|---|---|
| **NAV** | buque (`DEPARTAMENTO`) | **actividad** (`LAN`, `CAL`) | **marea** (`MAREA/CIUDAD`) |
| **BC** | buque (`DEPARTAMENTO`) | **marea** | **actividad** |

El sync copiaba la 2 tal cual (`[Global Dimension 2 Code] AS Marea`), y `Aplicar Fila Sinc NAV` hace `Job.Validate("Global Dimension 2 Code", Stg.Marea)`. El valor entra sin quejarse —el valor de dimensión existe— y cada proyecto sincronizado queda con marea `LAN` o `CAL`. No hay error: hay una marea equivocada en todos los proyectos.

**La marea sale de la dimensión 3 de NAV.** Confirmado el 11/9/2026 contra los datos: `PP-V03-260010` tiene dim1 `V03`, dim2 `LAN`, dim3 `260010`. Ojo que `Global Dimension 3 Code` en NAV es un **campo de la personalización (50000)**, no de la tabla estándar — la misma que en BC llega por el tableextension 50245.

Hubo una versión intermedia que sacaba la marea del `[No.]` con un `LIKE` de seis dígitos. Quedó como **respaldo** para el proyecto viejo con dim 3 vacía y número bien formado, porque sin él ese proyecto perdería la marea que hoy tiene, en silencio. Pero la fuente es la dimensión: el `LIKE` fallaba con `PP-TAE-2600001`, que tiene siete dígitos.

El código de marea **siempre tiene 6 caracteres** (confirmado 11/9/2026). `IncrementarMarea` en Cod50054 usa `IncStr`, que conserva el formato.

**El código de dimensión no siempre coincide con el segmento del `No.`:** `PP-HUAI-260001` tiene buque `HUA` y `PP-MAT-260001` tiene `MT1`. Otra razón para leer la dimensión y no parsear el número.

**La actividad va a la dimensión 3 de BC, por el campo, no por la Default Dimension a mano.** La personalización agrega al `Job` los campos 50000..50004 para las dimensiones 3 a 7, cada uno con su `OnValidate` que llama a `ValidateShortcutDimCode`. Ver [[job-confirm-dimension-inocuo]] — escribir sólo la Default Dimension deja el campo 50000 en blanco y los FlowFilters `Filtro actividad` no ven nada.

Relacionado: [[migracion-estados-meta4]], [[nav-odata-ntlm]], [[sincronizacion-valores-dimension]], [[job-confirm-dimension-inocuo]].

## Relacionado

- [[job-confirm-dimension-inocuo]]
- [[migracion-estados-meta4]]
- [[nav-odata-ntlm]]
- [[sincronizacion-valores-dimension]]
