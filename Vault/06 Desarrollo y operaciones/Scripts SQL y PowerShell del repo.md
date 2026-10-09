---
tipo: referencia
tags: [desarrollo, sql, scripts, powershell, diagnostico, migracion]
fuente: [scripts/, scripts/DiagnosticoLiquidacion.sql, scripts/EstadoConfiguracion.sql, scripts/Indices_Linea_Liquidacion.sql, scripts/QueObjetosEstanPublicados.sql, scripts/EstaPublicadoElBuildNuevo.sql, scripts/BuscarTablasDuplicadas.sql, scripts/VerChangeLog4743.sql, scripts/VerHistorialFormula.sql, scripts/DiagnosticoTablasExtension.sql]
actualizado: 2026-10-04
---

# Scripts SQL y PowerShell del repo

`scripts/` tiene ~60 archivos. Se agrupan por **riesgo**: los de diagnóstico **sólo leen**; los de corrección/migración **escriben** y siguen la regla de [[previsualizar-antes-de-migrar]] (mostrar antes de correr). Conexión y cómo ejecutarlos: [[conexion-sql-bc]] (BC: `Migr2013R2` en `mimir`; `sqlcmd -C`; .NET necesita el FQDN `mimir.arbumasa.com`).

> [!warning] Dos cosas comunes a todos los scripts
> 1. **Los nombres de tabla se descubren** en `sys.tables` con `LIKE` (`<Empresa>$Línea Liquidación$<GUID>`): dependen del id de la extensión y BC convierte el `.` final en `_`. Empezar siempre por las variables `@Empresa = 'ArbuTest'` y la base `Migr2013R2`; cambiarlas si el entorno es otro. Ver [[campos-extension-tabla-ext]].
> 2. Un `UPDATE` directo **deja la caché del service tier rancia**: reiniciar tras escribir ([[sql-directo-deja-cache-rancia]]). Un `INSERT` en una columna `DateFormula` con `0` envenena la fila (mismo documento).

## A. Diagnóstico (sólo leen)

| Script | Para qué | Cuándo |
|---|---|---|
| `DiagnosticoLiquidacion.sql` | De dónde sale cada peso de **una** liquidación: cabecera vs suma de líneas, líneas, detalle de variables; parámetros `@Nombre`, `@Periodo`, `@NoEmpleado` (grillas 5 y 6 = grossing-up). Los de grossing-up: 90016, 90212, 90302, 90361 | Cuando el total no cierra contra el recibo |
| `EstadoConfiguracion.sql` | «¿Dónde estoy parado?» tras restaurar: conceptos, fracciones, filtros, parámetros `NETO_GU_*`, Config. RRHH. Imprime esperado al lado de real | Tras restore o apply de paquete ([[Backup y restauración - cómo reaplicar]]) |
| `DiagnosticoTablasExtension.sql` | Todas las tablas `%$<AppId>` con filas, creada/modificada; las **recreadas** en 24 h; Estado Empleado y fases | Tras una publicación que se llevó datos ([[rad.json - peligro]]) |
| `BuscarTablasDuplicadas.sql` | Dos tablas para el mismo nombre lógico (huérfanas por renumeración) | Sospecha de leer la tabla equivocada con `LIKE` |
| `EstaPublicadoElBuildNuevo.sql` | Busca una **columna** que sólo existe en el código nuevo (Config. RRHH) → veredicto «build publicado / NO publicado» | Cuando el comportamiento no coincide con el código |
| `QueObjetosEstanPublicados.sql` | Pregunta a la metadata del servidor qué extensiones y objetos hay (arma las consultas desde `sys.columns`) | ídem |
| `VerChangeLog4743.sql` | Las dos modificaciones de Fórmula del 4743 que el **Change Log** de BC sí registró y el historial propio no (valor viejo/nuevo completos) | Caso `xRec` ([[xrec-no-confiable-con-addin]]) |
| `VerHistorialFormula.sql` | Separa las 3 causas de «el cambio no se guardó» en `Historial Fórmula Concepto`: (a) se agrupó (ventana de **15 min**, mismo usuario y fórmula), (b) quedó como **Alta** con otra vigencia, (c) no se registró. `@Concepto` = 4743 | ídem |
| `Indices_Linea_Liquidacion.sql` | Índices de las tablas del cálculo: tamaño, uso, candidatos a baja, **reversa** | Rendimiento ([[Diagnóstico de rendimiento]]) |
| `Auditar*.sql` (`AuditarAsignacionesSinFase`, `AuditarBuqueMareaAsignaciones`, `AuditarFechasAsignaciones`) | Calidad de datos de asignaciones (`Personal Proyecto`): quién entra al lote sin estar en la empresa; buque/marea mal; fechas contra Meta4 (3.039 líneas) | Antes de liquidar un período |
| `Explorar*` (`ExplorarPuestosMeta4`, `ExplorarValSindicato_Meta4_Oracle`) | Exploración en **Oracle/Meta4** por DBeaver | Antes de una migración ([[meta4-es-oracle]]) |

## B. Rendimiento / captura (PowerShell, conectan a `mimir`)

| Script | Qué hace |
|---|---|
| `CapturarSQLMotor.ps1` | Sesión de Extended Events temporal; vuelca eventos y esperas a `captura-motor-<fecha>/` |
| `DepurarIndicesLiq20260921.ps1` | Prepara (`restore.sql`/`drops.sql`) o aplica (`-Apply`) la baja de 6 índices cubiertos |
| `CompararEneroMotor.ps1 -Phase Before|After` | Hash por fila de 5 tablas para las 519 liquidaciones de enero → prueba de equivalencia |
| `GenerarIndiceVault.ps1` | Regenera los índices del vault (`08 Referencia`) y reporta enlaces rotos |

Detalle en [[Diagnóstico de rendimiento]].

## C. Migración desde Meta4 (en pares: Oracle → BC)

Meta4 es Oracle y BC es SQL Server: no hay linked server ni provider. Cada migración va **en tiempos**: (1) consulta en Oracle por DBeaver → (2) los resultados se cargan a una tabla de paso `dbo.MIG_*` en BC → (3) un script BC la convierte. Conexión Oracle: [[meta4-conectar-desde-powershell]] (ODP.NET administrado; `Oracle.ManagedDataAccess.dll` está en la raíz).

| Migración | Scripts | Notas |
|---|---|---|
| Estados de empleado | `MigrarEstados_1_Meta4_Oracle.sql`, `MigrarEstados_2_BC_SqlServer.sql` | Buque `HF`+n→n, `A`+n→`1`+n, `PM`→`PPM`; el proyecto sale de «Devenga Francos» ([[migracion-estados-meta4]], [[gp-devenga-francos-pero-es-improductivo]]) |
| Fases de alta/baja | `MigrarFasesAlta_1_…`, `…_1b_GenerarInserts_Oracle`, `…_2_BC_SqlServer`, `…_3_AEntidadPropia` | Mueve altas/bajas a su propia tabla `Fase Alta Empleado` ([[tres-capas-fase-estado-asignacion]]) |
| Ausentismos | `MigrarAusentismos_1_…`, `…_2_BC_SqlServer` | Administrativos sin estados |
| Atributos CCT | `MigrarAtributosCCT_1_…`, `…_2_BC_SqlServer` | Convenio/categoría como atributos con vigencia ([[migracion-atributos-cct-meta4]]) |
| Personal Proyecto | `MigrarPersonalProyecto_4.sql` (850 líneas) | **Paso 4**, después de `MigrarEstados_2` |
| Puestos | `puestos/1_NormalizarHistorialPuestos.pl`, `2_GenerarStaging.pl`, `3_ValidarContraMarea59.pl`, `4_MigrarPuestos.sql`; `ExplorarPuestosMeta4.sql`, `MapearPuestosMeta4ACategorias.sql` | Los `.pl` son Perl sobre `M4T_HIST_PUESTOS_*.csv` ([[puesto-vs-categoria-cct]]). Ojo con decimales: [[export-csv-decimal-con-coma]] |
| Fracciones | `CargarFraccionesMeta4.sql` | Reemplaza **toda** la tabla (1.208 filas); por SQL porque el ConfigPackage no la aplicó |
| Francos | `ImportarSaldoInicialFrancos.sql` + `_Datos.sql` | Carga la hoja `Saldo Inicial Francos Liq.` al 31/12/2025; **no aplica**: se aplica desde la página |
| NAV | `SincronizarNAV_2013R2.sql` | Sólo transporta filas a staging; AL (`Sinc NAV Liq.`) las aplica ([[transporte-ws-sincronizacion]]) |

Cada script de migración tiene un encabezado con **lo que traduce y lo que excluye a propósito**; leerlo antes de correrlo.

## D. Correcciones puntuales de datos o configuración (escriben)

`CerrarEstadosPorBaja`, `RecortarAsignacionesAlProyecto`, `MoverEstadosDeTierraANomina`, `RellenarEstadoActivoTierra`, `CorregirEstadosNavegacionA28M59`, `CorregirCategoriaPersonalProyectoA28M59` (datos de asignaciones/estados); `CorregirBaseIG4Duplicada`, `CompletarFraccionesFaltantes`, `LimpiarFraccionesHuerfanas`, `CrearCuotaSindicalSACDevengado` (4754), `CorregirOrdenAbsorcionArt36` (4415 480→412), `CorregirOrdenSACDevengado` (460-463→924-928), `CorregirPorcentajesSACDevengado`, `CorregirEscalaPrecioPuertoLAN`, `CorregirValoresCalamar2026`, `CargarValoresOficiales768`; y `RestaurarFiltrosFuenteDatos` (repone los 76 filtros de la tabla 60029 desde un export). Casi todos son **de una sola vez y ya corrieron**; sirven de historia y de plantilla. Conceptos relacionados: [[acumuladores-orden-calculo]], [[concepto-negativo-despues-de-sus-consumidores]], [[escala-somu-indice-70]].

> [!danger] No reejecutar a ciegas
> Varios borran y reinsertan (`CargarFraccionesMeta4`) o asumen un estado previo. Releer el encabezado y correr primero el bloque de diagnóstico que traen.

## E. Carpetas de salida dentro de `scripts/`

| Carpeta | Contenido |
|---|---|
| `captura-motor-20260921-085924`, `…090219`, `…091620` | Salida de `CapturarSQLMotor.ps1`: `events-*.xml`, `waits-*.json` (≈10 KB c/u) |
| `diagnostico-sql-20260921/` | Salida de `DepurarIndicesLiq20260921.ps1`: `indexes-before.json`, `restore.sql`, `drops.sql`, `selection.csv`, `result.json` (6 bajas, 44→38) y cuatro `build-*.log` |
| `comparacion-enero-2026/` | `Before.json` / `After.json` (≈16,8 MB c/u) y `corrida-anterior-20260921-091548/`; contienen **hashes**, no importes en claro |
| `puestos/` | Cadena Perl+SQL de puestos |

Los contenedores de salida pueden borrarse sin romper nada, pero `comparacion-enero-2026/Before.json` es la **referencia** para la próxima optimización: conservarla.

## Convenciones al escribir un script nuevo

- Cabecera `/* … */` con: qué hace, **si sólo lee**, de dónde salen los datos, por qué por SQL y no por AL.
- `USE [Migr2013R2]; SET NOCOUNT ON;` y `DECLARE @Empresa sysname = N'ArbuTest'`.
- Descubrir tablas y columnas en `sys.tables`/`sys.columns` (joins por `object_id` de la propia `sys.tables`, **no** reconstruyendo el nombre con `REPLACE`/`PARSENAME`: devuelve `NULL` sin error y se lee como «no existe»).
- SQL dinámico: castear a `nvarchar(max)` ([[sql-dinamico-truncado-4000]]). Subconsultas correlacionadas: calificar cada columna ([[subconsulta-correlacionada-silenciosa]]). Leer escalares remotos con `sp_executesql` a cuatro partes ([[linked-server-leer-escalar-remoto]]).
- Para escribir: bloque de **previsualización** primero, `BEGIN TRAN` con control de filas afectadas, reversa guardada.
