---
tipo: proceso
tags: [integracion-nav, sql, linked-server, rowversion, collation]
fuente: [scripts/SincronizarNAV_2013R2.sql, src/Tables/Tab110046.ConfigSincNAV.al, src/Tables/Tab110041.CtrlSincNAV.al, src/Enums/Enum50330.TransporteSincNAV.al]
actualizado: 2026-10-04
---

# Sincronización NAV - transporte SQL

Transporte `SQL (linked server)` (ordinal 0 de `Transporte Sinc NAV`). Un job de SQL Agent **en el servidor de BC** lee de NAV por **linked server** lo que cambió por **rowversion** y lo deja en el staging. Visión de conjunto: [[Sincronización NAV - visión general]].

> [!warning] Cubre sólo 5 de las 9 entidades
> El script trae las entidades 0-4: Empleado, Proyecto, Descarga Cabecera, Descarga Línea y Valor Dimensión. **Informe del Capitán y Diario de Abordo (5-8) sólo existen por el transporte WS** ([[Sincronización NAV - transporte WS]]). `Ctrl Sinc NAV.Entidad` y el `WHERE [Entidad] = 0..4` del script usan el ordinal del enum, por eso el enum no se puede renumerar.

## Cómo detecta cambios

Cada tabla de NAV tiene `[timestamp]` (rowversion), que sube en cada INSERT/UPDATE. La **marca de agua** (`Ctrl Sinc NAV."Marca Agua"`, decimal como texto) guarda hasta dónde se leyó. Cada corrida pide `rowversion > marca AND rowversion <= techo`.

- **Techo = `min_active_rowversion() - 1`** del origen. Sin él, una fila de una transacción aún abierta recibe un rowversion bajo al confirmarse, la marca ya pasó y esa fila **no llega nunca** (sin error).
- Se lee llamando al `sp_executesql` **del origen con nombre de cuatro partes** (`[srv].[base].sys.sp_executesql`) y devolviendo por `OUTPUT`: sin MSDTC y sin depender del catálogo por defecto del linked server. Ver [[linked-server-leer-escalar-remoto]].
- **No detecta bajas**: un DELETE no deja rastro en ningún rowversion. Si hicieran falta, el camino es Change Tracking en NAV.
- Vaciar la `Marca Agua` fuerza una traída completa (palanca de resincronización; botón "Volver a traer todo"). No borra nada en BC.

## Estructura del script `scripts/SincronizarNAV_2013R2.sql`

Se ejecuta **un bloque por vez, completo** (no el archivo entero: `CREATE OR ALTER PROCEDURE` tiene que ser la primera sentencia del lote; sin `GO` para que corra en DBeaver).

| Bloque | Qué hace | Escribe |
|---|---|---|
| 0 | Guardián: ¿es la base de BC? (busca la tabla `Ctrl Sinc NAV`) | no |
| 1 | Crea el linked server (`MSOLEDBSQL`, `rpc out = true`, `collation compatible = false`); credenciales a mano, **comentado** | sí, una vez, con el DBA |
| 2 | Muestra la configuración cargada en BC | no |
| 3 | **Verificación de nombres de columna del origen** (no saltear) | no |
| 4 | `dbo.SincNAV_ActualizarControl` (mueve marca/filas en `Ctrl Sinc NAV`) | crea proc |
| 5 | `dbo.SincNAV_Traer @EmpresaBC` (5.1 tablas, 5.2 techo, 5.3 Empleados, 5.4 Proyectos, 5.5 Cab. descarga, 5.6 Lín. descarga, 5.7 Valores dim.) | crea proc |
| 6 | `dbo.SincNAV_TraerTodo`: recorre las empresas activas | crea proc |
| 7 | Primera corrida a mano con `@Debug = 1` (imprime los MERGE) | comentado |
| 8 | Job de Agent `BC - Sincronizar NAV 2013R2`, cada 15 min desde 00:02 | comentado |
| 9 | Diagnóstico | no |

Los **tres procedimientos (4, 5, 6) hay que crearlos los tres**.

## Reglas que el script ya resuelve (no romperlas)

- **Todo configurable desde BC** (`Config Sinc NAV`): linked server, base, prefijo de empresa NAV, nombres de tabla. El script **no se edita** salvo las credenciales del paso 1. La tabla es `DataPerCompany = false` para que SQL la encuentre con `LIKE 'Config Sinc NAV$%'`.
- **Prefijo de empresa NAV** = nombre SQL, no el lindo: `Arbumasa S.A.` es `Arbumasa S_A_`. Equivocarlo da "Invalid object name", idéntico al error de permisos.
- **`COLLATE DATABASE_DEFAULT`** en las dos puntas de cada `ON` de los MERGE: la base de BC es `Modern_Spanish_CI_AS` y la de Navision `Modern_Spanish_100_CI_AS` ([[sql-ares-dos-collations]]).
- **`CAST(N'' AS nvarchar(max)) +`** al armar SQL dinámico; sin eso el MERGE de empleados (~4.300 caracteres) se guarda cortado a 4000 sin error ([[sql-dinamico-truncado-4000]]). Los comentarios largos van **fuera** del literal.
- Dentro de un `OPENQUERY` una comilla literal lleva cuatro `'` en el archivo; la lista de dimensiones se arma con `NCHAR(39)`.
- Las tablas de BC no admiten NULL y llevan columnas de sistema (`$systemId`, `$systemCreatedAt`...) que el MERGE completa a mano.
- Proyectos: las dimensiones 2 y 3 están cruzadas entre NAV y BC ([[dim2-nav-actividad-bc-marea]]).

## Infraestructura implicada

El linked server apunta a `navdb.arbumasa.com` (alias DNS de ARES, ver [[ares-topologia-bc]]), base `Navision`. `@datasrc` es el **servidor SQL** (`host\instancia` o `host,1433`), nunca el endpoint del NST (`:7046/Instancia`). El login remoto necesita `db_datareader` + `VIEW DATABASE STATE`. Conexión a BC: [[conexion-sql-bc]].

## Cambiar de transporte

Los dos llenan las mismas tablas. Al cambiar hay que **vaciar la `Marca Agua`**: un rowversion (~17.500 millones) leído como `Entry_No` del Change Log (~14,5 millones) deja todo afuera, para siempre y sin error ([[transporte-ws-sincronizacion]]).

## Ver también

[[Tabla - Config Sinc NAV]], [[Tabla - Ctrl Sinc NAV]], [[Patrón de las tablas de staging NAV]], [[Catálogo de scripts SQL y PowerShell]], [[Sincronización NAV - operación y errores]].
