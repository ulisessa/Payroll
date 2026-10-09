---
tipo: proceso
tags: [migracion-meta4, estados-fases, oracle, sql-server]
fuente: [scripts/MigrarFasesAlta_1_Meta4_Oracle.sql, scripts/MigrarFasesAlta_1b_GenerarInserts_Oracle.sql, scripts/MigrarFasesAlta_2_BC_SqlServer.sql, scripts/MigrarFasesAlta_3_AEntidadPropia.sql, scripts/MigrarEstados_1_Meta4_Oracle.sql, scripts/MigrarEstados_2_BC_SqlServer.sql, scripts/MoverEstadosDeTierraANomina.sql]
actualizado: 2026-10-04
---

# Migración Meta4 - estados y fases

Cómo el historial de personas de Meta4 (altas/bajas y estados diarios) llegó a `Fase Alta Empleado` y `Estado Empleado`. Mapa general: [[Migración desde Meta4 - mapa y orden de ejecución]]. Modelo: [[estado-empleado-effective-dated]], [[tres-capas-fase-estado-asignacion]].

## Dos tablas de Meta4, dos caminos que no se pisan

| Meta4 | Contiene | Script | Destino |
|---|---|---|---|
| `ARBPRO.M4T_FASES_ALTA` | alta (`FEC_ALTA_EMPLEADO`), baja (`FEC_BAJA`), `ID_MOTIVO_BAJA`, comentarios | `MigrarFasesAlta_*` | `Fase Alta Empleado` |
| `ARBPRO.M4T_HIST_ESTADOS_EMPL` | estados operativos `NV PS GP PL PI DQ`, tierra `FR OR OI`, ausencias `AU*`, `ACC`, `LE` | `MigrarEstados_*` | `Estado Empleado` |

`M4T_HIST_ESTADOS_EMPL` **no trae ni una fila `BAJ-*`**; las bajas viven en las fases ([[migracion-estados-meta4]]).

## Fases de alta

1. **`MigrarFasesAlta_1_Meta4_Oracle.sql`** - SELECT de `M4T_FASES_ALTA`. En el archivo el filtro es `ID_SOCIEDAD = 'COMPLETAR'`: **hay que reemplazarlo por `'01'`** antes de correr (con otro valor devuelve cero filas sin error).
   `MigrarFasesAlta_1b_GenerarInserts_Oracle.sql` es la alternativa "sin asistente": devuelve una columna de texto con los `INSERT INTO dbo.MIG_FasesM4` ya escritos (fechas ISO, comillas duplicadas, saltos de línea quitados). Se pega en una pestaña conectada a la base de BC. Crear funciones en Meta4 exige escritura sobre un sistema ajeno, por eso va todo en línea.
2. **Puente `dbo.MIG_FasesM4`** (la crea el bloque -1 del paso 2): `LEGAJO, FEC_ALTA, FEC_BAJA, MOTIVO_BAJA, COMENT, COMENT_BAJA`.
3. **`MigrarFasesAlta_2_BC_SqlServer.sql`** (pasos 0-7): traduce cada fase a **una o dos filas** de `Estado Empleado` (`ALT`, Tipo Estado = Alta; y el código de baja, `BAJ-<n>`, `BAJ-1`...`BAJ-50`, uno por motivo de Meta4). El paso 2 verifica que los códigos existan y el 2.b genera el `INSERT` de los que falten; el 3 lista legajos inexistentes en BC (**no se migran**); el 4 detecta choques; el **5 (inserción) está comentado**; el 7 es el "deshacer" por ventana.
4. **`MigrarFasesAlta_3_AEntidadPropia.sql`** - mueve altas y bajas del historial a su tabla propia. Razón: el alta/baja y el estado operativo competían por el mismo día (en enero de 2026 fueron **153 choques**, no por datos sucios sino por el modelo). Desde ese cambio `Estado Empleado` **rechaza activamente** códigos de tipo Alta y Baja. Pasos: 1-3 leen, **4 inserta fases** (aparea cada Alta con la primera Baja posterior; lo del medio no interrumpe), **5 borra** del historial las filas Alta/Baja, **6 recalcula contigüidad** de lo que queda.

> [!warning] Hallazgo: `MigrarFasesAlta_2` describe el modelo viejo
> El paso 2 inserta altas/bajas **como estados**; el modelo vigente los rechaza. En un entorno nuevo el camino hoy es adaptar `_2` para insertar directo en `Fase Alta Empleado` o correr `_2` + `_3` como se hizo históricamente. Sin verificar si `_2` sigue ejecutable contra el esquema actual.

### Comparación posterior (27/9/2026)
Las fases se emparejan por **empleado + fecha de alta**, nunca sólo por empleado. Se exportaron las 11.740 fases con el puente de [[meta4-conectar-desde-powershell]] a `dbo.StgFaseM4` (sin `BULK INSERT` ni `bcp`: `INSERT`s por lotes de 1000). **38 fases abiertas en BC estaban cerradas en Meta4** (BC les creaba liquidación todos los meses): se cerraron y se recortaron 37 estados con la regla de `CerrarEstadosBaja` replicada en SQL ([[fases-bc-contra-meta4]]).

## Estados operativos

1. **`MigrarEstados_1_Meta4_Oracle.sql`**: `LEGAJO, FEC_ALTA, FEC_INICIO, FEC_FIN, COD_ESTADO, BUQUE_M4, MAREA, COMENT` (recortado a 250). Desde el 13/9/2026 trae **el histórico completo**: 244.010 filas desde 1999-08-28 (las líneas del rango enero-junio 2026 quedan comentadas; con rango daba 2.910). Veinte códigos: `NV 68305, PS 56661, PL 41923, FR 28062, GP 14241, OR 13517, AU9 7819, OI 5982, AU1 2353, PI 2296, ACC 1412, DQ 1154, AU5 234, AU10 22...`. Los `AU*` son ausentismos: el código es `'AU' + ID_TIPO_AUSENTISMO` (`M4T_TIPOS_AUSENTISMO`); `AU1` = enfermedad, `AU9` = **vacaciones** (tiene que estar marcado como tal en el catálogo).
2. **Puente `dbo.MIG_EstadosM4`** (DDL en el bloque 1 del paso 2). **Guarda 1.b** contra doble carga.
3. **`MigrarEstados_2_BC_SqlServer.sql`** (bloques 1-7):
   - **2 Traducción** en `#Estados`: buque (`HF`/`A`/`PM`), proyecto, `LEAD` para la contigüidad.
   - **2.b Depuración contra las fases**: 3.982 estados caían fuera de toda fase y 3.900 a **un día exacto del borde** -> son dos desfasajes opuestos: (i) el `OR` del día siguiente a la baja **no es un estado, es el fin de la relación** (3.835 filas, 1.071 legajos): se **descarta** (extender la fase un día inventaría un día de antigüedad); (ii) el embarque del día anterior al alta **sí es un estado** (65 filas): llegó tarde el alta.
   - **Cierre**: se **respeta el `FEC_FIN` de Meta4** cuando es anterior al inicio del siguiente. Estirar el estado miente en los consumibles (`FR` es franco gozado: estirar 2 semanas consume francos no tomados; 28 casos de 2-22 días).
   - **Huecos** se tapan con una fila propia `OR` (observación identificable), nunca estirando la anterior; **y el relleno no cruza una baja** (dejó 28 estados de hasta 54 días sobre períodos fuera de la empresa).
   - **3 Pre-vuelo** (todo debe dar CERO): 3.a códigos inexistentes, 3.b buques sin mapear, 3.c proyectos inexistentes (ya **no bloquea**: desde el 13/9/2026 esas filas entran con `No. Proyecto` en blanco), 3.d legajos inexistentes, 3.e choques con lo ya cargado, 3.h estados sin fase que los cubra, 3.f autopsia fila a fila, 3.g ceros a la izquierda.
   - **5 Inserción** (comentada, con `BEGIN TRANSACTION`), 5.b conciliación post-COMMIT, **6 recalcular contigüidad de todo el historial (no opcional: las `Fecha Fin` calculadas por la migración de fases quedan viejas al intercalar estados)**, 6.b-6.d (abiertos, estados pasados de la baja, activos sin estado vigente), 7 verificación.
   - Proyecto: **por la bandera `Devenga Francos`** del código de estado (Sí -> `PP-<buque>-<marea>`; No -> `PN-<buque>-NOMINA`; `PM` -> `PN-PPM-NOMINA`).

> [!danger] Esa regla de proyecto ya se sabe errónea
> `Devenga Francos` contesta "¿se trabaja?", no "¿está en una marea?". `GP` (guardia en puerto), `DQ` (dique) y `PI` (pilotaje) devengan francos pero transcurren en tierra: debían ir a `PN-`. Dejó **12.324 guardias, 2.120 pilotajes y 1.038 diques** colgadas de la marea anterior (una a 3.904 días del arribo, porque el `ID_MAREA` de Meta4 se congela al arribar). Lo corrige `MoverEstadosDeTierraANomina.sql` con el campo **`Transcurre en Marea`** de `Cód. Estado Empleado` (sólo `NV`, `PS`, `PL` en Sí) y de ahí lo lee `ResolverProyectoInactividad` (Cod50017). **`MigrarEstados_2` no menciona ese campo**: recorrerlo de nuevo reproduce el error. Ver [[gp-devenga-francos-pero-es-improductivo]] y [[Migración Meta4 - correcciones y auditorías]].

## Después de los estados

- Ausentismos de tierra, `ACT` y asignaciones: [[Migración Meta4 - atributos CCT, puestos y ausentismos]].
- La nómina no es un intervalo de presencia: derivar `PN-` del `MIN/MAX` de los estados la cierra el día antes de embarcar ([[nomina-no-es-intervalo-presencia]]).
- Hay un proceso desconocido que **parte estados en dos** (18/3/2025 y 6/10/2025, cuenta de sistema, causa sin identificar): control en el bloque 21.d de `AuditarFechasAsignaciones.sql` ([[algo-parte-estados-en-dos]]).

## Ver también

[[Tabla - Fase Alta Empleado]], [[Tabla - Estado Empleado]], [[Tabla - Cód. Estado Empleado]], [[Fases de alta]], [[Migración desde Meta4 - mapa y orden de ejecución]].
