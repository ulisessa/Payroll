---
tipo: referencia
tags: [desarrollo, repo, estructura, limpieza]
fuente: [.gitignore, .gitattributes, app.json, README.md]
actualizado: 2026-10-04
---

# Mapa de la raíz del repo

La raíz mezcla **código**, **generadores**, **documentación vieja**, **builds** y **datos de trabajo** (planillas y recibos). Pesa ~890 MB sin `.git` (94 MB), de los cuales el código es una fracción mínima. Esta nota dice qué es cada cosa y qué es descartable. Las recomendaciones de `.gitignore` son **sólo propuestas**: no se modificó nada.

> [!danger] Datos personales y salariales en la raíz
> Las carpetas `2026-01`…`2026-08` y los PDF/XLSX de mareas contienen **recibos de sueldo reales** (CUIL, legajo, importes) y planillas de liquidación. `recibos_2026-01_extraidos.tsv` es la extracción de esos recibos. No deben publicarse ni subirse a un remoto compartido.

## 1. Código y proyecto AL (versionado)

| Ruta | Qué es |
|---|---|
| `app.json` | Manifiesto ([[Setup del entorno de desarrollo]]) |
| `src/` | 347 archivos: `Codeunits` (60), `Pages` (129), `Tables` (72), `Enums` (32), `Reports` (11 archivos, 7 informes + `.rdl`/`.rdlc`), `TableExtensions` (7), `PageExtensions` (10), `PermissionSets` (3), `Profiles` (2), `ControlAddIns/EditorFormula` (JS/CSS) |
| `test/` | 7 codeunits de test + 1 test JS ([[Tests automatizados]]) |
| `Translations/` | `.g.xlf` generado + `.g.es-ES.xlf` ([[Convenciones de código AL del proyecto]]) |
| `.vscode/` | `launch.json`, `settings.json` (y `rad.json`: **debe borrarse**, [[rad.json - peligro]]) |
| `.claude/` | permisos de Claude Code (`settings.json`, `settings.local.json`) y `worktrees/` (vacía) |
| `.gitignore`, `.gitattributes` | Reglas de git (`*.al`, `*.json`, `*.md`, `*.xml`, `*.xlf` con LF) |
| `README.md` | Hoy sólo documenta *Comparar atributos por código* (no es un README del proyecto) |
| `Vault/` | Este vault de Obsidian |

## 2. Carpetas de herramientas (ignoradas)

`.alpackages/` (58 MB, símbolos), `.netpackages/` (14 MB, resto de .NET sin uso, ver [[Setup del entorno de desarrollo]]), `.altestrunner/`, `.snapshots/` (vacía), `.vscode/.alcache/`.

## 3. Generadores de configuración

| Archivo | Qué es | Estado |
|---|---|---|
| `gen_config.ps1` | Genera `ConfigPackage_Payroll.xlsx` (Excel COM) | Vigente |
| `gen_rapidstart.ps1` | Genera `.xml` + `.rapidstart` | Atrasado (campo 14 obsoleto) |
| `gen_config.py` | Versión Python | **Obsoleta** |
| `ConfigPackage_Payroll.xlsx/.xml/.rapidstart` | Salida de lo anterior (22/5/2026) | Desactualizados; versionados |
| `ConfigPaq-FueraConvenio.xlsx` | Paquete de valores fuera de convenio (17/5/2026) | Versionado |
| `PackageLIQUIDACION.rapidstart` | **Export completo de BC** del 14/8/2026, 10 MB gzip / 177 MB XML | **No versionar** (en el índice como `A`) |

Ver [[ConfigPackage y RapidStart - qué lleva y qué no]].

## 4. Documentación `.md`/`.txt` de la raíz

| Archivo | Fecha | Estado / destino |
|---|---|---|
| `REAPLICAR_TRAS_RESTORE.md` | 8/9/2026 | Vigente como procedimiento; foto de estado vieja → [[Backup y restauración - cómo reaplicar]] |
| `REVISION_RENDIMIENTO_2026-09-18.md` | 18/9/2026 | Revisión estática → [[Diagnóstico de rendimiento]] |
| `ADR_001_FIRMA_DIGITAL_RECIBOS.md` | 26/8/2026 | Estado «Propuesto». Sólo referencia; ver [[firma-recibos-digitales]] |
| `GROSSING_UP_Y_TC_CONFIGURABLES.md` | 4/10/2026 | Diseño a revisar **antes de tocar código** (no versionado aún) |
| `METODO_COMPARACION_META4_BC.md` | 27/9/2026 | Método de comparación de liquidaciones Meta4 vs BC (no versionado aún) |
| `PROPUESTA_TOPE_SIPA_PERIODO.md` | 7/9/2026 | Propuesta **no implementada** |
| `FRACCIONES_RETIRADAS_VS_META4.md` | 7/9/2026 | Foto del paquete antes de reconstruir Fracción Acumulador |
| `CARGA_VALORES_TANGONEROS_2026.md` | 17/9/2026 | Carga de valores SOMU/oficiales/fuera de convenio; preguntas abiertas contestadas |
| `GUIA-LIQUIDACION.md` | 22/5/2026 | Guía de uso (1.106 líneas), **anterior** a muchas funciones; verificar contra el código |
| `CAMBIOS_SESION_ACTUAL.md` | 11/6/2026 | Registro de una sesión de junio (SIRADIG); **histórico** |
| `NOTA_DESCOMPRESION_ZIP.md` | 11/6/2026 | **Desactualizada**: habla de `DotNet` + `src/DotNet/Assemblies.al` + `assemblyProbingPaths`; nada de eso existe hoy (se usa el codeunit `Data Compression`) |
| `COMIENZA_AQUI.md`, `README_SIRADIG.md`, `GUIA_PRUEBAS_SIRADIG.md`, `IMPLEMENTACION_SIRADIG_RESUMEN.md`, `IMPORTACION_SIRADIG_GUIA.md`, `INDICE_IMPORTACION_SIRADIG.md`, `SIRADIG_EJEMPLOS_Y_EXTENSIONES.md`, `RESUMEN_IMPLEMENTACION.txt`, `EJEMPLO_SIRADIG.xml` | 11/6/2026 | Paquete de documentación de la **importación SIRADIG** de la sesión 2; redundante entre sí. Candidatos a consolidar en el vault |

## 5. Builds `.app` (ignorados por `*.app`; ~92 MB, 68 archivos)

- `Grupo Arbumasa_Liquidación Sueldos Pesca_1.0.0.506.app` … `…565.app` (falta el 525): historial local de builds, uno por versión ([[Versionado de app.json]]).
- `_codex_correcciones_474.app`, `_codex_mejoras_calculo.app`, `_codex_perfil_borrados.app`, `_codex_progreso_474.app`, `_codex_review_474|477|522|agrupacion.app`: builds experimentales de septiembre 2026 (prefijo `_codex`; los scripts de rendimiento de esas fechas identifican su conexión como «Codex Payroll…», o sea que salen de una revisión asistida por otra herramienta). `out.app`: salida suelta de compilación (2/10/2026).
- `artifacts/atributos-por-codigo.app`, `artifacts/detalle-calculo.app` (+ `-build.log`, 140 KB c/u): builds de funcionalidades del 2/10/2026.

**Todos descartables** salvo el último publicado (1.0.0.565) por si hay que hacer rollback.

## 6. Datos de trabajo (no código)

| Qué | Dónde | Observación |
|---|---|---|
| Recibos de sueldo Meta4 en PDF, por mes | `2026-01` … `2026-08` (16–47 archivos c/u; `2026-07` y `2026-08` ≈105 MB c/u) | Nombres `AAAA-MM-DD <TIPO>.pdf` (`FRA`, `BAJ`, `PUE`, `MAR`, `ADM`, `EMB`, `ORD`, `VAC`, `LIQFIN-…`). En `2026-07/08` también `A14M311.PDF`, `A14O1022.PDF`… (buque + tipo + marea). Referencia para comparar BC vs Meta4. **Datos personales** |
| Planillas/PDF por marea | raíz: `A14…`, `A19…`, `A28 59…62`, `HF801 6…9`, `HF802 6…9` (`CLC producción.xlsx`, `Descarga.pdf`, `Detalle.pdf`, `Incidencias.pdf`, `Movimientos.pdf`, `Rol Entrada/Salida.pdf`) | Documentos operativos de cada marea para cerrar liquidaciones |
| Planillas de configuración / análisis | `Book1*.xlsx` (6), `Genérico06/07_09_2026_*.xlsx` (exports de configuración; **el `…07_09_2026_23_24_04` era la única copia de los 76 filtros**, ver [[Backup y restauración - cómo reaplicar]]), `Ganancias 2026 - 90016|90046|90251|90259|90261|90414.xlsx`, `Liquidaciones*.xlsx`, `Recibos*.xlsx`, `SI.COSS 01…08-2026.xlsx`, `Estados enero.xlsx`, `Conceptos Liquidación.xlsx`, `Avance implementación conceptos.xlsx`, `Saldo francos 31-12-25.xlsx`, `valores SOMU 1er sem 2026.xlsx`, `Valores … TANGONEROS …xlsx`, `Valores producción calamar campaña 2026.xlsx`, `CONDICIONES OFICIALES POTEROS CAMPAÑA 26.xlsx`, `prov vac 06-2026.xlsx` | 57 `.xlsx` en total; fuentes de cargas y controles |
| Convenios y normativa | `CCT 768-2019 AACPyPP 2016.pdf`, `Marítimos. Armadores pesqueros congeladores, CCT 729_2015. Homologación.pdf`, `Escala salarial CAPA/CAPECA - SOMU 07-26.pdf`, `TABLAS PRODUCCION SOMU 05-05-26.pdf`, `Deducciones-personales-art-30-*.pdf`, `Tabla-Art-94-LIG-*.pdf` | **Referencia legal**: conviene conservarlas (están versionadas) |
| Propuestas comerciales | `Propuesta - Modulo Liquidacion de Haberes para BC*.docx` (4, con backups), `10 -8 Grupo Arbumasa Propuesta Solución MANDÜ - People&Payroll.pptx.pdf` | Documentación de proyecto, no del código |
| Extractos | `recibos_2026-01_extraidos.tsv` (574 líneas: archivo, tipo, legajo, nombre, CUIL, buque, categoría…), `M4T_HIST_PUESTOS_202609180955.csv` (entrada de `scripts/puestos/`), `GU_formula_updates.csv`, `HF801 8 info desembarco GRANCE HECTOR DANIEL.msg` | **Datos personales**; el `.tsv` y el `.msg` están en el índice de git como `A` |

## 7. Binarios y trazas sueltos

- `Oracle.ManagedDataAccess.dll` (5,6 MB): cliente Oracle administrado para consultar Meta4 desde PowerShell ([[meta4-conectar-desde-powershell]]). En el índice como `A`.
- `PerformanceProfile_Session9.alcpuprofile` (8,8 KB, 8/9/2026): perfil que mostró `ResolveFuente`/`CalcFinEfectivo` ([[Diagnóstico de rendimiento]]). En el índice como `A`.
- `perf_hits.txt` (42 KB, 3/8/2026, **versionado**): parece la salida de un `grep` de `.Get(`/`FindSet` sobre `src` (líneas con rutas `src\Reports\Rep50043…`); origen sin verificar, descartable.

## 8. `scripts/` y `artifacts/`

- `scripts/`: ver [[Scripts SQL y PowerShell del repo]]. Incluye salidas con timestamp (`captura-motor-*`, `diagnostico-sql-*`, `comparacion-enero-2026`, **65 MB**).
- `artifacts/revision-enero-2026-20260927/` (20 archivos, 1,3 MB): evidencia de la **revisión de enero 2026** contra Meta4: `Informe.md`, `LEEME.txt`, JSON de comparación (`comparacion-1|2|3.json`, `comparacion-mareas.json`, `comparacion-mensual-final.json`, `bc-verificacion-final.json`…), `ConsultaComparacion.sql` y `ConsultaOracle.sql` para repetir las extracciones. **Datos salariales**, sin contraseñas (lo dice el LEEME).
- `artifacts/temas-a-resolver-20260927/Informe.md` (36 KB): informe de «temas a resolver» del 27/9/2026 (no leído en esta revisión).
- `.snapshots/`: vacía.

## 9. Recomendación de `.gitignore` (no aplicada)

Hoy `.gitignore` excluye `*.app`, `*.xlsx|xls|csv|docx|pdf`, `.alpackages` etc. **Pero** hay archivos ya versionados de esos tipos (24) y otros en el índice sin commit. Propuesta:

```gitignore
# Datos personales / salariales y artefactos de trabajo
/20[0-9][0-9]-[0-9][0-9]/
*.msg
*.tsv
*.rapidstart          # excepto el paquete generado, si se decide versionarlo
*.alcpuprofile
*.dll                 # Oracle.ManagedDataAccess.dll: bajar de NuGet, no versionar
/artifacts/
/scripts/captura-motor-*/
/scripts/diagnostico-sql-*/
/scripts/comparacion-enero-2026/
/perf_hits.txt
/out.app
_compile_test.app
```

Y, para lo ya versionado: `git rm --cached` de lo que no debe estar (decisión del usuario; `PackageLIQUIDACION.rapidstart` antes del primer commit con `git restore --staged`). Mover los `.docx`/`.pdf`/planillas a una carpeta fuera del repo (`Documentacion/` en el OneDrive) liberaría ~880 MB.

> [!warning] OneDrive
> El repo vive en OneDrive (`C:\Users\ulises.sasovsky\OneDrive\Documentos\...`): `.alpackages` y las carpetas de PDF se sincronizan sin necesidad. Considerar excluirlas de la sincronización.
