---
tipo: guia
tags: [indice, desarrollo, operaciones]
fuente: [app.json, .gitignore, scripts/]
actualizado: 2026-10-04
---

# Índice Desarrollo y operaciones

Todo lo que necesita quien **modifica, compila, publica y opera** la extensión *Liquidación Sueldos Pesca* (AL, BC 25.2, OnPrem, servidor `mimir`, base `Migr2013R2`, empresa `ArbuTest`).

## Reglas que no se discuten

1. Compilar con `alc.exe` antes de dar algo por cerrado → [[Compilar con alc.exe]].
2. **Borrar `.vscode/rad.json`** tras cada cambio y **nunca publicar en RAD** → [[rad.json - peligro]], [[Publicar en BC (no usar RAD)]].
3. **No tocar `version` en `app.json`** → [[Versionado de app.json]].
4. Objetos nuevos en **110000–149999**; Table corta en 60029 fuera de ese rango → [[Rangos de IDs y licencia]].
5. El ConfigPackage **no es un backup** → [[ConfigPackage y RapidStart - qué lleva y qué no]].
6. Un `UPDATE` por SQL deja la caché rancia: reiniciar el service tier → [[sql-directo-deja-cache-rancia]].

## Empezar

| Nota | Para qué |
|---|---|
| [[Setup del entorno de desarrollo]] | Herramientas, `app.json`, dependencias, `.vscode`, `.claude` |
| [[Runbook - tareas frecuentes]] | Checklists: cerrar un cambio, publicar, diagnosticar |
| [[Convenciones de código AL del proyecto]] | Nombres, namespace, captions, `Error`/`Message`, `Commit`, temporales |

## Construir y publicar

| Nota | Para qué |
|---|---|
| [[Compilar con alc.exe]] | Comando exacto, filtros, gotcha de worktrees |
| [[Publicar en BC (no usar RAD)]] | Publish completo, Sync/Upgrade, verificar qué corre |
| [[Versionado de app.json]] | Quién sube la versión y cuándo |
| [[rad.json - peligro]] | El archivo que dropea tablas |
| [[Rangos de IDs y licencia]] | Qué IDs habilita la licencia, desfasajes archivo/ID |
| [[Permission sets de la extensión]] | Tres sets, perfiles, tablas que faltan |

## Datos de instalación y restauración

| Nota | Para qué |
|---|---|
| [[Install y Upgrade - qué siembra cada uno]] | Los 8 codeunits Install/Upgrade |
| [[ConfigPackage y RapidStart - qué lleva y qué no]] | Generadores, campos que no viajan, flag que borra |
| [[Backup y restauración - cómo reaplicar]] | Fases A–G tras restaurar, medir antes de tocar |

## Calidad y rendimiento

| Nota | Para qué |
|---|---|
| [[Tests automatizados]] | 70 pruebas AL + 14 comprobaciones JS, cómo correrlas, qué falta |
| [[Diagnóstico de rendimiento]] | 123 s → filtros; índices `missing_index_*`; SIFT; prioridades |

## Repositorio y scripts

| Nota | Para qué |
|---|---|
| [[Mapa de la raíz del repo]] | Qué es cada archivo/carpeta, qué es basura, propuesta de `.gitignore` |
| [[Scripts SQL y PowerShell del repo]] | Diagnóstico, migración Meta4, correcciones, captura |

## Lecciones más usadas por quien desarrolla

[[al-compile-command]] · [[rad-json-removed-peligroso]] · [[borrar-rad-json-tras-cada-cambio]] · [[version-app-json-manual]] · [[rangos-licencia-objetos]] · [[configpackage-campos-faltantes]] · [[conexion-sql-bc]] · [[sql-directo-deja-cache-rancia]] · [[indices-missing-index-nocturnos]] · [[sift-sobre-clave-unica]] · [[variable-sistema-hay-que-sembrarla]] · [[codeunit-run-necesita-commit]] · [[al-sin-cortocircuito]] · [[get-con-menos-argumentos]] · [[xrec-no-confiable-con-addin]] · [[bucle-modifica-campo-filtrado]] · [[format-no-se-valida-al-compilar]] · [[report-sin-layout-compila]] · [[clear-no-vacia-temporary]] · [[campos-extension-tabla-ext]] · [[symbolos-final-version-tienen-fuente]]

## Documentos de la raíz que se referencian, no se copian

`REAPLICAR_TRAS_RESTORE.md`, `REVISION_RENDIMIENTO_2026-09-18.md`, `ADR_001_FIRMA_DIGITAL_RECIBOS.md` ([[firma-recibos-digitales]]), `GROSSING_UP_Y_TC_CONFIGURABLES.md`, `METODO_COMPARACION_META4_BC.md`, `PROPUESTA_TOPE_SIPA_PERIODO.md`. Estado de cada uno en [[Mapa de la raíz del repo]].

## Discrepancias abiertas detectadas al escribir esta carpeta

1. `NOTA_DESCOMPRESION_ZIP.md` describe `src/DotNet/Assemblies.al` y `assemblyProbingPaths` que no existen; SIRADIG descomprime con `Data Compression` (`Cod50047`). `.netpackages/` quedó sin uso.
2. Los permission sets no incluyen 13 tablas con datos (Filtro Fuente Datos, Estado Tipo Liq., préstamos, SIRADIG, comparador Meta4…) → [[Permission sets de la extensión]].
3. `ConfigPackage_Payroll.xml/.rapidstart/.xlsx` (22/5) y `gen_rapidstart.ps1` están atrasados respecto de `gen_config.ps1` (7/9); Concepto Liquidación tiene hoy 28 campos y el generador lleva 13.
4. `.vscode/rad.json` existe en disco (3/10/2026, 2 entradas en `Removed`, sin tablas): falta borrarlo.
5. Siete archivos AL con ID de nombre distinto del declarado y una page extension con otro namespace → [[Rangos de IDs y licencia]], [[Convenciones de código AL del proyecto]].
6. `.claude/settings*.json` apuntan a la ruta vieja `d:\…\OneDrive\Personal\…`.
7. Mucho trabajo sin commit (último commit 20/9/2026) y archivos sensibles/pesados agregados al índice → [[Mapa de la raíz del repo]].
