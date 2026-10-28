---
tipo: guia
tags: [desarrollo, version, app-json]
fuente: [app.json]
actualizado: 2026-10-04
---

# Versionado de app.json

> [!danger] Regla
> **No incrementar `version` en `app.json`.** Lo hace el usuario, a mano, cuando decide publicar. Ni al compilar, ni al cerrar un cambio, ni "por prolijidad".

Origen: lección [[version-app-json-manual]].

## Por qué

Compilar con `alc.exe` no cambia la versión. Si nadie la toca, varios builds distintos terminan compartiendo número, y eso ya causó confusión real: `1.0.0.383` se recompiló cuatro veces con código distinto y no había forma de saber qué estaba instalado en BC. El usuario prefiere controlar ese momento.

## Estado actual

- `app.json`: `"version": "1.0.0.565"` (al 2026-10-04).
- Los `.app` de la raíz con nombre `Grupo Arbumasa_Liquidación Sueldos Pesca_1.0.0.NNN.app` van de **506 a 565** (68 archivos `.app` en total en la raíz, contando los experimentales); sirven de historial local de builds pero **no se versionan** (`*.app` en `.gitignore`). Ver [[Mapa de la raíz del repo]].
- Hay un hueco en 525 (no existe ese `.app`).

## Cómo aplicarlo

- Compilar todas las veces que haga falta sin tocar `app.json` ([[Compilar con alc.exe]]).
- Si un cambio necesita **republicarse para verse** —sobre todo los del control add-in (`src/ControlAddIns/EditorFormula/editorFormula.js|css`), que además el navegador cachea— **decirlo en la respuesta** y dejar que el usuario suba la versión.
- La versión de las **dependencias** (`dependencies[].version`) tampoco se toca sin motivo: es la mínima que se exige, no la última instalada. Ver [[Setup del entorno de desarrollo]].

## Relación con Install/Upgrade

Los codeunits de Upgrade corren al pasar de una versión a otra publicada ([[Install y Upgrade - qué siembra cada uno]]). Por eso un número repetido no sólo confunde: puede que una versión nueva no dispare la siembra que se espera.

## Qué hacer al cerrar un cambio

Anotar en la respuesta: "requiere subir versión para verse" cuando corresponda; el checklist está en [[Runbook - tareas frecuentes]].
