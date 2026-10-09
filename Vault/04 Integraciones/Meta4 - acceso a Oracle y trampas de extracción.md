---
tipo: guia
tags: [migracion-meta4, oracle, powershell, dbeaver, extraccion]
fuente: [scripts/MigrarEstados_1_Meta4_Oracle.sql, scripts/ExplorarPuestosMeta4.sql, scripts/ExplorarValSindicato_Meta4_Oracle.sql, scripts/puestos/1_NormalizarHistorialPuestos.pl, Oracle.ManagedDataAccess.dll]
actualizado: 2026-10-04
---

# Meta4 - acceso a Oracle y trampas de extracción

Cómo se llega a los datos de Meta4 y qué se rompe en silencio al extraerlos. Mapa de migraciones: [[Migración desde Meta4 - mapa y orden de ejecución]].

## Dónde está Meta4

- **Oracle**, `m4-vm.arbumasa.net.ar:1521`, conexión por **SID `Meta4`** (no service name), esquema **`ARBPRO`** (`ARBPRO.M4T_*`, catálogo `M4SYS_CONCEPTOS`). Una sola sociedad: `ID_SOCIEDAD = '01'`.
- **No hay linked server ni provider de Oracle** desde BC (mimir ni BRAGI), ni cliente Oracle en la estación. Por eso las migraciones son de **tres tiempos** (Oracle -> puente -> SQL Server). La nota de memoria [[meta4-es-oracle]] dice que "no hay vía automatizable"; está **desactualizada** (la hubo: ODP.NET desde el 18/9/2026 y luego node-oracledb).

## Tres formas de consultarlo

| Vía | Cuándo | Notas |
|---|---|---|
| **DBeaver** (conexión "Meta4") | scripts `*_1_*_Oracle.sql`, exploraciones; exportar resultado -> BD / CSV | La instancia va y viene (`ORA-12528`/`ORA-12505`); DBeaver puede seguir "funcionando" con conexiones ya abiertas. |
| **`node-oracledb` Thin** (`scratchpad/ora/m4.js`) | automatizar (el camino vigente desde 27/9/2026) | `$env:M4PWD` (nunca como argumento), reintentos `M4RETRIES`/`M4RETRYMS`. ODP.NET reportaba el bloqueo como `ORA-50000` (timeout genérico) y despistaba. |
| **ODP.NET administrado** (`Oracle.ManagedDataAccess.dll`, net462, en la raíz del repo; helper `ora\Meta4.ps1`) | funcionó desde el 18/9/2026, dejó de completar el handshake | Cinco dependencias sueltas + `AssemblyResolve` que hace de redirección; **el handler no puede usar cmdlets** (recursión -> `StackOverflowException`). El helper contiene la contraseña: no subirlo al repo. |

Detalle y credenciales de contexto: [[meta4-conectar-desde-powershell]]. El `Oracle.ManagedDataAccess.dll` está en el repo (agregado al índice de git en el estado actual); no es un artefacto de la extensión.

## Trampas de extracción (todas silenciosas)

1. **`ID_SOCIEDAD = '1'` vs `'01'`**: con el valor equivocado la consulta devuelve **cero filas sin error**; idéntico a un rango de fechas mal puesto o falta de permisos. En `MigrarFasesAlta_1` el filtro está como `'COMPLETAR'`.
2. **Un `DATE` de Oracle lleva hora** y un campo `Date` de BC no la admite: la inserción no falla, falla la **página al abrir** ("La fecha no es válida"). Truncar **del lado de Oracle** (`TRUNC(col)` / `TO_CHAR`). La carga del archivo metió 2.200.914 filas así (todas `FEC_ULT_ACTUALIZACION`); la hora **no se tira**, queda como texto ISO en `Valor Texto`. Control: `WHERE [Campo] <> CONVERT(datetime, CONVERT(date, [Campo]))` ([[oracle-date-lleva-hora]]).
3. **`Export-Csv` escribe decimales con la coma regional**; Perl los trunca a entero con un warning por fila ([[export-csv-decimal-con-coma]]): migrando `M4T_VAL_INCIDENCIA` 4.747 novedades habrían entrado sin decimales.
4. **`M4-Query` devuelve un `DataRow` con una sola fila** y `$r[0]` indexa la primera **columna**: da 0 o vacío. Siempre `@($r)[0]`. **`return $rd` enumera el DataReader**: usar `return ,$rd` ([[meta4-number-castea-a-cero]]).
5. **`COMENT` trae saltos de línea y comillas**: cortar a 250 en Oracle (`SUBSTR(TRIM(...),1,250)`), quitar `CHR(10)`/`CHR(13)`, duplicar `'`. Un registro puede ocupar dos líneas físicas en el CSV (Perl: el registro empieza con `"NNNNN"|`).
6. **Fechas como ISO `YYYY-MM-DD`** al generar `INSERT`: `DD/MM/YYYY` se interpreta distinto según el idioma del servidor y no da error.
7. **Legajos sin ceros a la izquierda** (`191` vs `00191`).
8. **`NUMBER` contra texto** da `ORA-01722` sin decir qué columna.
9. **`BULK INSERT` no sirve** (corre en el servidor y no ve el disco local) y no hay `bcp`: se generan `INSERT` por lotes de 1000 ([[fases-bc-contra-meta4]]).
10. **El `NOMBRE_CORTO` de `M4SYS_CONCEPTOS` no siempre es el nombre de la columna física** (1003 Sueldo = `SAL_BASE`, columna `SUELDO`): cruzar por `N_ACUMULADO`.
11. **Doble carga de una puente**: no falla, deja conteos raros tres pasos después. `TRUNCATE` antes de recargar.

## Tablas de Meta4 que aparecen en los scripts

`M4T_FASES_ALTA`, `M4T_HIST_ESTADOS_EMPL`, `M4T_AUSENTISMOS` / `M4T_TIPOS_AUSENTISMO`, `M4T_HIST_CONVENIOS`, `M4T_HIST_CATEGORIAS`, `M4T_HIST_PUESTOS`, `M4T_PUESTOS` / `M4T_PUESTOS_TRABAJO`, `M4T_VAL_COEF_CAPECA_PUESTO`, `M4T_VAL_CONVENIO_CATEG_PUESTO`, `M4T_HIST_SINDICATOS`, `M4T_VAL_INCIDENCIA`, `M4T_CTA_CTE_ANTICIPOS`, `M4T_FAMILIARES`, `M4T_ACUMULADO_RL`..`RL5` (la forma ancha partida en 5 por el límite de 1.000 columnas de Oracle), `M4SYS_CONCEPTOS`.

> [!warning] Sin verificar
> El nombre del catálogo de puestos aparece como `M4T_PUESTOS` en `ExplorarPuestosMeta4.sql` y como `M4T_PUESTOS_TRABAJO` en la memoria (con la advertencia de que la descripción es `N_PUESTO`). El script trae una consulta 1.b para descubrirlo.

## Ver también

[[Archivo literal de Meta4 en BC]], [[Tabla - Valor Hist. Meta4]], [[Migración desde Meta4 - mapa y orden de ejecución]].
