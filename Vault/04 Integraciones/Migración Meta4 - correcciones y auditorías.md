---
tipo: guia
tags: [migracion-meta4, auditoria, correcciones, estados-fases, scripts]
fuente: [scripts/AuditarAsignacionesSinFase.sql, scripts/AuditarBuqueMareaAsignaciones.sql, scripts/AuditarFechasAsignaciones.sql, scripts/CerrarEstadosPorBaja.sql, scripts/MoverEstadosDeTierraANomina.sql, scripts/RecortarAsignacionesAlProyecto.sql, scripts/CorregirEstadosNavegacionA28M59.sql, scripts/CorregirCategoriaPersonalProyectoA28M59.sql, scripts/LimpiarFraccionesHuerfanas.sql]
actualizado: 2026-10-04
---

# Migración Meta4 - correcciones y auditorías

Después de migrar, apareció una familia de scripts que **auditan** (sólo leen) y **corrigen** (`UPDATE`/`DELETE` comentados dentro de una transacción) lo que la migración dejó mal. Todos corren contra `Migr2013R2`, empresa `ArbuTest`. Orden y contexto: [[Migración desde Meta4 - mapa y orden de ejecución]]; lista completa: [[Catálogo de scripts SQL y PowerShell]].

La regla de oro: **las tres capas se limpian de arriba hacia abajo** (fase -> estado -> asignación) porque el síntoma aparece una capa más abajo que el problema ([[tres-capas-fase-estado-asignacion]]). Y toda corrección masiva va con previsualización y controles de **invariante y dirección** ([[previsualizar-antes-de-migrar]]).

## Auditorías (sólo leen)

| Script | Pregunta que contesta |
|---|---|
| `AuditarAsignacionesSinFase.sql` | ¿Quién entra al lote sin estar en la empresa? El lote (`AplicarFiltroPersonal`, Cod50018) elige por la **asignación**, nunca por la fase; una asignación abierta cuando la persona se fue genera una liquidación **vacía en borrador** (caso 02678: fase cerrada 23/2/2001, asignación sin baja desde 2000). Parámetros `@Desde/@Hasta` = período. Bloque 5 trae el UPDATE comentado (cerrar la asignación el día de la baja). El 4 es "el espejo": fases abiertas de gente que ya no está y estados abiertos fuera de fase. |
| `AuditarBuqueMareaAsignaciones.sql` | ¿Hay asignaciones con buque/marea mal? Son **copias** (se llenan al elegir el proyecto): o el proyecto tiene mal su dimensión (arreglar en el proyecto y rehacer copias) o la asignación quedó vieja (arreglar sólo la asignación). Disparado por PP-119-000308 del legajo 00794. Ningún bloque escribe. |
| `AuditarFechasAsignaciones.sql` (3.039 líneas, bloques 0-14) | ¿Las fechas de `Personal Proyecto` coinciden con Meta4? El span de un tripulante sale de los estados que **transcurren a bordo** (campo `Transcurre en Marea`), no de todos los que llevan ese `ID_MAREA` (queda puesto tras el arribo: 8 meses de más en el 307). Criterio de alta decidido: las altas viejas (2002-2021) estaban un día después que Meta4 (se salteó el día de puerto de salida); la buena es la de Meta4. 4.a/4.b corrigen altas/bajas; 4.c son 25 casos a decidir a mano; 5-13 reconstruyen un episodio de estados futuros (ver abajo); **21.d** detecta estados partidos en dos ([[algo-parte-estados-en-dos]]). |
| `DiagnosticoLiquidacion.sql`, etc. | Ver el catálogo (son diagnósticos de motor, no de Meta4). |

### El episodio de los estados futuros (bloques 5-14 de `AuditarFechasAsignaciones`)
29 estados `NV` fechados 13/10/2026 en `PP-119-000308` (más uno el 23/9) se escribieron el 17/7/2026 con el **`WorkDate` adelantado**, desde un entorno de prueba, por el flujo de asignar tripulación. Como `Estado Empleado` mantiene la contigüidad, esa inserción **cerró el 12/10** el estado anterior de cada uno; el 14/9 la migración derivó `Personal Proyecto` del `MIN/MAX` de esos estados y dejó 12/10 y 13/10 en las asignaciones (23 cerradas, 6 altas "fantasma", nómina cerrada de 02804). Conclusión del bloque 11: **no se limpia por SQL**: `EstadoEmpleado.ReabrirAnteriorAlBorrar()` (Tab60000, `OnDelete`) reabre el anterior y un `DELETE` directo no lo ejecuta. Se borran los 30 estados **desde BC** (página de Estados de Empleado); 04220 tiene dos encadenados. Después se regenera `Personal Proyecto` con la derivación corregida de las `PN-`. Los bloques 12-13 reconstruyen contra Meta4 lo que el borrado se llevó (inserción comentada, sin auditoría de borrados: se detecta el hueco). El bloque 11.c señala "el control que falta en el motor": evitar estados futuros.

## Correcciones de estados y asignaciones

| Script | Qué corrige | Notas |
|---|---|---|
| `CerrarEstadosPorBaja.sql` | Estados que quedaron **pasados de la baja** de su fase (un estado sin fecha fin vale hasta 31/12/9999 -> Francos abiertos desde 2001 solapados con 2026). Sólo los que **empiezan dentro de la fase**; el que arranca después es otro error (4.b-4.c los lista). 4.d borra rellenos `OR` que cruzaron una baja. | De ahí en adelante lo sostiene `Fase Alta Empleado.CerrarEstadosPorBaja` (OnInsert/OnModify). UPDATE del bloque 5 comentado. |
| `MoverEstadosDeTierraANomina.sql` | GP/DQ/PI **no son marea**: 12.324 guardias + 2.120 pilotajes + 1.038 diques colgados del proyecto equivocado. Bloque 1 marca `Transcurre en Marea` (sólo NV/PS/PL); 4 mueve los estados a `PN-<buque>-NOMINA`; 5 rehace asignaciones. | Requiere el build con el campo nuevo (Tab60003). Evidencia: `PL` después del arribo nunca a más de 3 días (evento de borde, es marea); `GP` hasta 3.904 días (no es borde, es tierra). [[gp-devenga-francos-pero-es-improductivo]]. |
| `RecortarAsignacionesAlProyecto.sql` | "La asignación no puede durar más que el proyecto": 7.457 pasadas del fin, 3.360 entre 1 y 12 meses. Causa: una sola asignación por par empleado+proyecto, así que quien repite barco quedó del primer embarque al último desembarque. | **Correr el bloque 0 primero** (tres consultas que miden qué pasos de la limpieza se corrieron; tienen que dar cero). Excepción conocida desde 15/9/2026: no "arreglar" las `PN-ADM-*` creadas desde 1/1/2026. 3.b: antes de recortar, ¿es la marea correcta? (marea 1 de 2007 y marea 2 de 2010 caen en el mismo proyecto de BC). Lo sostiene `ValidarBajaDentroDelProyecto`. |
| `CorregirEstadosNavegacionA28M59.sql` | A28/59: a cinco tripulantes les faltaba el estado `NV` (el `GP` previo nunca se cerró y cubría 26 días de navegación). Cobraron sueldo de puerto por 27 días en vez de 1. | Puntual; `SincronizarEstadoDesdeProyecto` no alcanza (cierra con `Fecha Baja` y no cierra el GP). Los días de navegación se cuentan del rango de la **asignación**, no de los estados: por eso sólo aparece en el puerto. |
| `CorregirCategoriaPersonalProyectoA28M59.sql` | A28/59: `Personal Proyecto` se cargó copiando la categoría de la ficha y en el barco se navega en el puesto del rol. | Fuentes: `A28 59 Movimientos.pdf` extraído con `pdftotext -table` (con `-layout` ESCALANTE salía como BODEGUERO) y recibos Meta4 ($/ton identifica el escalón). Coinciden en 29 de 30 filas. Probablemente superado por la migración de puestos (sin verificar). |

## Otras limpiezas ligadas a la migración

- `LimpiarFraccionesHuerfanas.sql`: filas de `Fracción Acumulador` que apuntan a conceptos inexistentes (el `OnDelete` de `Concepto Liquidación` no las limpiaba hasta la 1.0.0.374). **No alcanza**: una fórmula que nombra un acumulador borrado resuelve la variable como CERO sin error (4751-4753, `IMPO_CNT_SS`).
- `BuscarTablasDuplicadas.sql`, `DiagnosticoTablasExtension.sql`: ver [[rad-json-removed-peligroso]] (renumerar IDs dropea la tabla con sus datos).

## Cómo trabajar con estas correcciones

1. Correr los bloques de lectura y **mirar** cada número antes de descomentar nada.
2. Anotar las claves afectadas en una `#temp` **antes** del `UPDATE` y verificar contra ella (un verificador que acota de menos da 0/0 con una fila mal; de más, falsas diferencias).
3. Un control de invariante sobre un estado preexistente mide la **diferencia** contra un conteo previo, no el absoluto (44 huecos históricos hicieron un `ROLLBACK` de una corrección buena).
4. `COMMIT`/`ROLLBACK` a mano; reiniciar el service tier después ([[sql-directo-deja-cache-rancia]]).

## Ver también

[[Tabla - Estado Empleado]], [[Tabla - Personal Proyecto]], [[Tabla - Fase Alta Empleado]], [[Migración desde Meta4 - mapa y orden de ejecución]].
