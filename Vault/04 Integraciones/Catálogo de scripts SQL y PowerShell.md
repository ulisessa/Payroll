---
tipo: referencia
tags: [scripts, sql, powershell, oracle, migracion-meta4, integracion-nav, sql-bc-infra]
fuente: [scripts/]
actualizado: 2026-10-04
---

# Catálogo de scripts SQL y PowerShell

Los 51 archivos `.sql`/`.ps1` de `scripts/` (48 SQL + 3 PowerShell), más `scripts/puestos/` (3 Perl + 1 SQL) y carpetas de salida. **Ninguno se ejecuta desde AL ni desde CI**: se corren a mano (DBeaver, SSMS o `sqlcmd`, ver [[conexion-sql-bc]]).

## Cómo leer la columna "Destructivo"

| Valor | Significado |
|---|---|
| **No** | Sólo `SELECT`/diagnóstico. Se puede correr sin preguntar. |
| **Sí, comentado** | La sección de escritura (`INSERT`/`UPDATE`/`DELETE`) está **dentro de un bloque comentado**, o su `COMMIT` está comentado (`-- COMMIT;   -- o ROLLBACK;`): se corre lo de lectura, se mira, se descomenta y se confirma a mano. Si se descomenta `BEGIN TRAN` y se ejecuta sin el `COMMIT`/`ROLLBACK`, la transacción queda abierta y **bloquea a BC** (ver `MigrarAtributosCCT_2`). |
| **SÍ (vivo)** | Escribe o borra **al ejecutarlo tal cual**, con `COMMIT` automático. Backup antes. |
| **Crea** | Crea objetos (procedimientos, job, puentes) sin tocar datos de negocio. |

> [!danger] Convenciones comunes de casi todos los scripts de BC
> - **Hardcodean** `USE [Migr2013R2]`, empresa `ArbuTest` y el AppId `d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890` (de `app.json`) en los nombres de tabla (`ArbuTest$Estado Empleado$d4f5a6b7-...`). Contra otra empresa/base hay que editarlos. Tablas de la app `Job` usan el AppId del base app (`437dbf0e-84ff-417a-965d-ed2bb9650972`).
> - **Backup y nadie liquidando** antes de escribir. **Reiniciar el service tier** después de `UPDATE`s directos ([[sql-directo-deja-cache-rancia]]).
> - **Sin `GO`** o con `GO` según el script; los de DBeaver se ejecutan **bloque por bloque**.
> - Un `INSERT` por SQL **saltea** la lógica de AL (contigüidad, validaciones, change log): cada script recalcula lo que el trigger haría.
> - `rad.json`: ver [[rad-json-removed-peligroso]].

Contexto de las migraciones: [[Migración desde Meta4 - mapa y orden de ejecución]]. Contexto NAV: [[Sincronización NAV - transporte SQL]].

## 1. Sincronización NAV

| Script | Propósito | Motor | Cuándo | Destructivo |
|---|---|---|---|---|
| `SincronizarNAV_2013R2.sql` | Mitad SQL de la sincronización: linked server, verificación de columnas, procs `SincNAV_ActualizarControl`/`_Traer`/`_TraerTodo`, job de Agent cada 15 min | SQL Server (BC) -> lee NAV por linked server | Puesta en marcha del transporte SQL; bloque por bloque | **Crea** (procs, job, linked server comentados) |

## 2. Migración de Meta4 - fases, estados, ausencias, asignaciones

Se ejecutan en el **orden** del mapa. `_1` = Oracle, `_2` = SQL Server.

| Script | Propósito | Motor | Cuándo | Destructivo |
|---|---|---|---|---|
| `MigrarFasesAlta_1_Meta4_Oracle.sql` | SELECT de `M4T_FASES_ALTA` (completar `ID_SOCIEDAD`, hoy `'COMPLETAR'`) | **Oracle** | Primer paso de fases | No |
| `MigrarFasesAlta_1b_GenerarInserts_Oracle.sql` | Igual, pero devuelve los `INSERT` como texto (sin asistente de DBeaver) | **Oracle** | Si falla la transferencia automática | No |
| `MigrarFasesAlta_2_BC_SqlServer.sql` | Puente `MIG_FasesM4` -> altas/bajas como estados `ALT`/`BAJ-n` (modelo viejo) | SQL Server | Después de `_1`; revisar pasos 1-4 antes del 5 | Sí, comentado (paso 5; paso 7 deshace) |
| `MigrarFasesAlta_3_AEntidadPropia.sql` | Mueve altas/bajas de `Estado Empleado` a `Fase Alta Empleado` y recalcula contigüidad | SQL Server | Una sola vez, tras publicar la tabla `Fase Alta Empleado` | Sí, comentado (4 inserta, 5 borra, 6 recalcula) |
| `MigrarEstados_1_Meta4_Oracle.sql` | SELECT de `M4T_HIST_ESTADOS_EMPL` (244.010 filas, `ID_SOCIEDAD='01'`) | **Oracle** | Después de fases | No |
| `MigrarEstados_2_BC_SqlServer.sql` | Puente `MIG_EstadosM4` -> `Estado Empleado` con traducción de buque/proyecto, depuración contra fases, rellenos, contigüidad | SQL Server | Después de `_1`; **recalcular (bloque 6) es obligatorio** | Sí, comentado (bloque 5) |
| `MigrarAusentismos_1_Meta4_Oracle.sql` | Mide y exporta `M4T_AUSENTISMOS` (bloques 1-4 miden; el 5 exporta) | **Oracle** | Para estados de tierra | No |
| `MigrarAusentismos_2_BC_SqlServer.sql` | Puente `MIG_AusentismosM4` -> estados `AU*` de tierra | SQL Server | Tras estados y fases | Sí, comentado (bloques 3 y 3.b) |
| `RellenarEstadoActivoTierra.sql` | Rellena con `ACT` los huecos de tierra dentro de cada fase | SQL Server | Después de ausentismos | Sí, comentado |
| `MigrarPersonalProyecto_4.sql` | Deriva `Personal Proyecto` de los estados (no lee Meta4) | SQL Server | Después de `MigrarEstados_2` | Sí, comentado (3, 3.b, 3.c, 5.c) |
| `MigrarAtributosCCT_1_Meta4_Oracle.sql` | `M4T_HIST_CONVENIOS` + `M4T_HIST_CATEGORIAS` (~21.000 filas) | **Oracle** | Para convenio/categoría con vigencia | No |
| `MigrarAtributosCCT_2_BC_SqlServer.sql` | Puente `MIG_AtributosM4` -> `Atributo Entidad Liq.` (traduce convenio, parte categoría, normaliza vigencias) | SQL Server | Tras `_1`; bloque 3.g primero (carga de arranque) | Sí, comentado (bloque 4) |

## 3. Puestos (eje de la producción)

| Script | Propósito | Motor | Cuándo | Destructivo |
|---|---|---|---|---|
| `ExplorarPuestosMeta4.sql` | Catálogo `M4T_PUESTOS` e historial `M4T_HIST_PUESTOS` completos | **Oracle** (DBeaver) | Exploración / re-extracción | No |
| `MapearPuestosMeta4ACategorias.sql` | `#MapaPuesto` puesto Meta4 -> categoría BC (exacta/decidida/sin mapeo) | SQL Server | Antes de migrar puestos | No (temporal) |
| `puestos/1_NormalizarHistorialPuestos.pl` | Cierra cada vigencia el día anterior a la siguiente (Perl, archivo CSV) | local (Perl) | Paso 1 | No |
| `puestos/2_GenerarStaging.pl` | Traduce `ID_PUESTO`->categoría y genera `cargaPuestos.sql` (llena `#Puesto`, 10.107 filas) | local (Perl) | Paso 2 | No |
| `puestos/3_ValidarContraMarea59.pl` | Simula puesto -> categoría -> producción y compara con el recibo de A28/59 | local (Perl) | Validación sin tocar la base | No |
| `puestos/4_MigrarPuestos.sql` | Crea el atributo `PUESTO` y carga las vigencias | SQL Server (`sqlcmd`, misma sesión que `#Puesto`) | Tras publicar la extensión | Sí, comentado (`COMMIT` a mano) |
| `ExplorarValSindicato_Meta4_Oracle.sql` | Busca el % de caja compensadora (8542) y fondo de desempleo (8543) en tablas de sindicato de Meta4 | **Oracle** | Antes de decidir si el % es por empleado | No |

## 4. Correcciones y auditorías de estados/asignaciones

| Script | Propósito | Motor | Cuándo | Destructivo |
|---|---|---|---|---|
| `AuditarAsignacionesSinFase.sql` | Quién entra al lote sin fase que cubra el período | SQL Server | Antes de calcular un lote (`@Desde/@Hasta`) | No (bloque 5 comentado) |
| `AuditarBuqueMareaAsignaciones.sql` | Asignaciones con buque/marea distinto del proyecto | SQL Server | Tras cambiar dimensiones de proyectos | No |
| `AuditarFechasAsignaciones.sql` | Fechas de `Personal Proyecto` vs Meta4 (bloques 0-14: span, evento de estados futuros, reposición) | SQL Server (+ `MIG_EstadosM4`) | Tras migrar o ante fechas raras | Sí, comentado (4.a, 4.b, 13.a, 13.b) |
| `CerrarEstadosPorBaja.sql` | Recorta estados pasados de la baja de su fase; lista huérfanos y rellenos que cruzaron una baja | SQL Server | Tras migrar fases/estados | Sí, comentado (4.d.2, 5) |
| `MoverEstadosDeTierraANomina.sql` | Mueve GP/DQ/PI de `PP-` a `PN-NOMINA` (campo `Transcurre en Marea`) y rehace asignaciones | SQL Server | Tras publicar el campo nuevo | Sí, comentado (4, 5) |
| `RecortarAsignacionesAlProyecto.sql` | La asignación no puede durar más que el proyecto | SQL Server | Correr el bloque 0 primero | Sí, comentado (bloque 4) |
| `CorregirEstadosNavegacionA28M59.sql` | Estado `NV` faltante de cinco tripulantes en A28/59 | SQL Server | Puntual (hecho) | Sí, comentado |
| `CorregirCategoriaPersonalProyectoA28M59.sql` | Categoría de asignación en A28/59 | SQL Server | Puntual (hecho) | Sí, comentado |

Detalle: [[Migración Meta4 - correcciones y auditorías]].

## 5. Cargas y correcciones de configuración del motor

| Script | Propósito | Motor | Cuándo | Destructivo |
|---|---|---|---|---|
| `CargarFraccionesMeta4.sql` | **Reemplaza toda** `Fracción Acumulador` por 1.208 filas de la especificación de Meta4 (el ConfigPackage no puede vaciar) | SQL Server | Tras restore / recarga de configuración | **SÍ (vivo)**: `BEGIN TRAN ... COMMIT`; **pierde `Invertir Signo`** (queda en 0) |
| `CompletarFraccionesFaltantes.sql` | Agrega bases de aportes de 1054, 1055 y 2493 | SQL Server | Puntual | **SÍ (vivo)** (inserta) |
| `CorregirBaseIG4Duplicada.sql` | Quita 3553/3573/4243/4743 de `BASE_IG4` (doble contabilización con `BASE_EXT_IG4`) | SQL Server | Tras `CargarFraccionesMeta4` | **SÍ (vivo)** |
| `RestaurarFiltrosFuenteDatos.sql` | Restaura los 76 filtros de `Filtro Fuente Datos Liq.` (sin ellos, 75% del tiempo de cálculo) | SQL Server | Tras perderlos | **SÍ (vivo)**; usa `IDENTITY_INSERT` |
| `LimpiarFraccionesHuerfanas.sql` | Borra fracciones que apuntan a conceptos inexistentes | SQL Server | Pasos 1-2 miran; el 3 borra | Sí, comentado |
| `CorregirOrdenAbsorcionArt36.sql` | Concepto 4415: orden 480 -> 412 | SQL Server | Puntual (hecho) | Sí, comentado |
| `CorregirOrdenSACDevengado.sql` | SAC devengado 460-463 -> 924-928 | SQL Server | Puntual (hecho) | Sí, comentado |
| `CorregirPorcentajesSACDevengado.sql` | 4751-4753: les faltaba `/100` | SQL Server | Puntual (hecho) | Sí, comentado |
| `CrearCuotaSindicalSACDevengado.sql` | Alta del concepto 4754 copiando 4752 | SQL Server | Puntual (hecho) | Sí, comentado |
| `CorregirEscalaPrecioPuertoLAN.sql` | `PRECIO_PUERTO_LAN` SOMU: 5 categorías fuera de la escala 100/85/80/75/70 | SQL Server | Puntual (hecho) | Sí, comentado |
| `CorregirValoresCalamar2026.sql` | 18 `VALOR_CAL_*` con cociente redondeado | SQL Server | Puntual (hecho) | Sí, comentado |
| `CargarValoresOficiales768.sql` | Básicos de oficiales 768/19 extraídos de los recibos PDF de Meta4 | SQL Server | Puntual | Sí, comentado |
| `ImportarSaldoInicialFrancos.sql` | `Saldo francos 31-12-25.xlsx` -> hoja de carga `Saldo Inicial Francos Liq.` (no aplica el ledger) | SQL Server | Una vez; luego "Aplicar" desde la página | Sí (inserta en la hoja; reversible) |
| `ImportarSaldoInicialFrancos_Datos.sql` | Los 214 registros del Excel como `INSERT` a `dbo.MIG_SaldoFrancos` | SQL Server | Antes del script principal | **SÍ (vivo)**: `DELETE FROM dbo.MIG_SaldoFrancos` + inserta |

## 6. Diagnóstico (sólo lectura)

| Script | Propósito | Motor | Cuándo | Destructivo |
|---|---|---|---|---|
| `DiagnosticoLiquidacion.sql` | De dónde sale cada peso de una liquidación (`@Nombre/@Periodo/@NoEmpleado`) | SQL Server | Cuando un total no cierra contra el recibo | No |
| `EstadoConfiguracion.sql` | ¿Dónde estoy parado? valores esperados vs reales de la configuración | SQL Server | Después de restaurar un backup | No |
| `EstaPublicadoElBuildNuevo.sql` | ¿Está el build nuevo? busca columnas que sólo existen en el código nuevo | SQL Server | Tras publicar | No |
| `QueObjetosEstanPublicados.sql` | Metadata del servidor: qué objetos están instalados | SQL Server | Si el comportamiento no coincide con el código | No |
| `DiagnosticoTablasExtension.sql` | Tablas de la extensión vacías / recreadas (`create_date`) | SQL Server | Tras una publicación que se llevó datos | No |
| `BuscarTablasDuplicadas.sql` | Dos tablas para el mismo objeto lógico (renumeración de IDs) | SQL Server | Si el historial de fórmulas "no guarda" | No |
| `VerHistorialFormula.sql` | Qué hay en el historial de fórmulas (agrupado / alta / no registrado) | SQL Server | `@Concepto` | No |
| `VerChangeLog4743.sql` | Las dos modificaciones que el Change Log sí registró | SQL Server | Diagnóstico puntual del 4743 | No |
| `Indices_Linea_Liquidacion.sql` | Índices no usados en las tablas del cálculo | SQL Server | Revisión de rendimiento ([[indices-missing-index-nocturnos]]) | No (DROP en el paso 4, comentado) |

## 7. PowerShell

| Script | Propósito | Motor | Cuándo | Destructivo |
|---|---|---|---|---|
| `CompararEneroMotor.ps1 -Phase Before\|After` | Snapshot (hash fila por fila) de 5 tablas de resultado de las 519 liquidaciones de enero 2026 -> `comparacion-enero-2026/{Before,After}.json` | SQL Server (`mimir.arbumasa.com`, Windows auth) | Antes y después de un cambio en el motor; se niega a sobrescribir; falla si no hay exactamente 519 liquidaciones | No (sólo lee; escribe JSON) |
| `CapturarSQLMotor.ps1 -Seconds N` | Sesión de Extended Events (10-900 s) sobre sentencias >=10 ms de las tablas de liquidación -> `captura-motor-<fecha>/events-*.xml`, `waits-*.json` | SQL Server | Perfilar un cálculo | Crea y **elimina** su sesión XE; no toca datos |
| `DepurarIndicesLiq20260921.ps1 [-Apply]` | Prepara (`restore.sql`, `drops.sql`, `selection.csv`, `indexes-before.json`) y con `-Apply` **elimina 6 índices `missing_index_*` de `Línea Liquidación`** cubiertos por otros, en una transacción, verificando antes/después | SQL Server | Depuración de índices del 21/9/2026 | Sin `-Apply`: No. **Con `-Apply`: SÍ** (`DROP INDEX`; rollback con `restore.sql`) |

Los tres scripts PowerShell usan `Application Name=Codex Payroll ...` y autenticación integrada contra `tcp:mimir.arbumasa.com,1433` (se necesita el FQDN con `SqlClient`, ver [[conexion-sql-bc]]). Están pensados para `PowerShell 5.1`.

## 8. Carpetas de salida (no son scripts)

| Carpeta | Contenido |
|---|---|
| `scripts/comparacion-enero-2026/` | `Before.json`, `After.json` y `corrida-anterior-20260921-091548/` (snapshot de referencia del motor). |
| `scripts/captura-motor-20260921-*` (3 carpetas) | Salida de `CapturarSQLMotor.ps1`: `events-*.xml`, `waits-*.json`. |
| `scripts/diagnostico-sql-20260921/` | Salida de `DepurarIndicesLiq20260921.ps1`: `restore.sql`, `drops.sql`, `indexes-before.json`, `selection.csv`, `result.json`, `build-*.log`. |

## Qué no está en `scripts/`
`scripts/GenerarIndiceVault.ps1` (agregado después de este catálogo, mientras se armaba el vault; genera los índices de `08 Referencia`) no está catalogado arriba: ver las notas de `06 Desarrollo y operaciones`. Los scripts de las cargas hechas desde scratchpad (archivo literal, `HIST_REMUN`, novedades, anticipos, fases comparadas) **no están versionados** ([[Migración desde Meta4 - mapa y orden de ejecución]]). En la raíz hay además `gen_config.ps1`, `gen_config.py` y `gen_rapidstart.ps1` (ConfigPackage, ver [[configpackage-campos-faltantes]]).

## Ver también

[[ConfigPackage y RapidStart - qué lleva y qué no]], [[Diagnóstico de rendimiento]], [[Índice Integraciones]].
