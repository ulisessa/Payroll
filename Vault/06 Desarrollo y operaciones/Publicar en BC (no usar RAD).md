---
tipo: proceso
tags: [desarrollo, publicacion, rad, bc]
fuente: [.vscode/launch.json, REAPLICAR_TRAS_RESTORE.md, src/Codeunits/Cod110049.VariablesSistemaInstall.al, src/Codeunits/Cod110050.VariablesSistemaUpgrade.al]
actualizado: 2026-10-04
---

# Publicar en BC (no usar RAD)

La extensión se despliega **a mano** en el servidor de desarrollo `mimir` (instancia `BC252`, base `Migr2013R2`, empresa `ArbuTest`). No hay pipeline.

> [!danger] Publicar siempre completo
> Publicar con `Ctrl+F5` / *AL: Publish* completo, **nunca en modo RAD** (Rapid Application Development). RAD usa `.vscode/rad.json`, cuya lista `Removed` puede dropear tablas **con sus datos**. Ver [[rad.json - peligro]].

## Pasos

1. [[Compilar con alc.exe]] — cero errores.
2. Confirmar que `.vscode/rad.json` **no existe** (y si existe, mirar su `Removed` y borrarlo): [[borrar-rad-json-tras-cada-cambio]].
3. El usuario sube `version` en `app.json` ([[Versionado de app.json]]). Si el cambio toca el control add-in (`src/ControlAddIns/EditorFormula/`) hay que republicar con versión nueva: el navegador cachea el JS/CSS.
4. En VS Code, configuración **Publish & debug (mimir)** (`launch.json`): `schemaUpdateMode: Synchronize`, abre la página 50149 (Role Center de Payroll).
5. Si el esquema cambió de forma que la sincronización normal rechaza (p. ej. renombrar un campo se ve como eliminación), el `Sync-NAVApp` se corta. Se completa desde el Administration Shell del servidor:

```powershell
Sync-NAVApp -ServerInstance $ServerInstance -Tenant default -Name $AppName -Version $Version -Mode ForceSync
Start-NAVAppDataUpgrade -ServerInstance $ServerInstance -Tenant default -Name $AppName -Version $Version
```

   (Origen: `REAPLICAR_TRAS_RESTORE.md`, caso 1.0.0.412 publicada pero no sincronizada.)
6. `Start-NAVAppDataUpgrade` es lo que **dispara los codeunits Upgrade** ([[Install y Upgrade - qué siembra cada uno]]).
7. Reiniciar el service tier (o `Sync-NAVTenant`) si hubo `UPDATE` directos por SQL: [[sql-directo-deja-cache-rancia]].

## Qué corre y qué no al publicar

| Acción | ¿Corre Install/Upgrade? |
|---|---|
| Publish completo + `Start-NAVAppDataUpgrade` | Sí |
| **RAD** | **No.** Hay que usar a mano la acción *Sembrar* de la página Variables de Sistema (misma llamada) — [[variable-sistema-hay-que-sembrarla]] |
| Publish con versión idéntica a la instalada | Sin verificar si dispara Upgrade; lo comprobado es que repetir número deja de saber qué build corre (ver [[Versionado de app.json]]) |

> [!warning] Un publish refresca la caché del service tier
> Esto explica casos en que un cambio por SQL "tomó" y otro no: sólo los hechos antes del último publish quedaron visibles. Ver [[sql-directo-deja-cache-rancia]].

## Verificar qué quedó instalado

Si el comportamiento no coincide con el código, **verificar la premisa**: que lo que corre es lo que se compiló.

- `scripts/EstaPublicadoElBuildNuevo.sql`: busca en SQL una columna que sólo existe en el código nuevo (los dos campos de `TabExt52001`, Config. RRHH). Veredicto en una línea.
- `scripts/QueObjetosEstanPublicados.sql`: pregunta a la metadata del servidor (`NAV App Installed App`, `NAV App Object Metadata`); arma las consultas desde `sys.columns` porque los nombres de columna cambian entre versiones.
- `scripts/DiagnosticoTablasExtension.sql`: tablas vacías o **recreadas** (`create_date` reciente = DROP + CREATE por una publicación, no un vaciado).
- `scripts/BuscarTablasDuplicadas.sql`: dos tablas para el mismo objeto lógico (huérfanas de una renumeración).

Detalle de todos en [[Scripts SQL y PowerShell del repo]].

## Antes de renumerar o borrar un objeto con datos

Renumerar una tabla la dropea con sus datos y la nueva nace vacía, sin diff en el código que lo delate. **Exportar antes, reimportar después.** Ver [[Rangos de IDs y licencia]] y [[rad.json - peligro]].

## Otro servidor

`launch.json` incluye una configuración contra `mimir2.arbumasa.com` para la página de OCR (otra extensión). No usarla para Payroll.
