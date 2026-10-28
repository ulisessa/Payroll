---
tipo: proceso
tags: [desarrollo, publicacion, rad, bc]
fuente: [scripts/Publicar.ps1, .vscode/launch.json, REAPLICAR_TRAS_RESTORE.md, src/Codeunits/Cod110049.VariablesSistemaInstall.al, src/Codeunits/Cod110050.VariablesSistemaUpgrade.al]
actualizado: 2026-10-11
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

## `scripts/Publicar.ps1` — el ciclo en un comando

```powershell
pwsh scripts/Publicar.ps1                 # compilar + publicar + borrar rad.json
pwsh scripts/Publicar.ps1 -SoloCompilar   # validar sin tocar el servidor
pwsh scripts/Publicar.ps1 -Reiniciar      # y reiniciar el service tier (sólo si hubo UPDATE por SQL)
```

Hace lo mismo que el *Publish* de VS Code —un POST al dev endpoint con autenticación Windows— y agrega lo que VS Code no hace: avisa si hay worktrees de git (compilarían copias viejas), filtra los cuatro warnings de siempre, rechaza `ForceSync` aunque `launch.json` lo pida, y mira el `Removed` de `rad.json` antes de borrarlo.

> [!warning] Para reiniciar, el nombre del servidor tampoco es el de `launch.json`
> `mimir.arbumasa.com` es un **alias de DNS**: resuelve a la IP correcta, pero Kerberos pide un SPN para ese nombre y no existe, así que WinRM muere con «No puede encontrarse el equipo». El que funciona es el FQDN del dominio, **`mimir.arbumasa.net.ar`**, y sale de resolver el nombre corto por DNS (`[System.Net.Dns]::GetHostEntry('mimir').HostName`). Desde el 13/10/2026 `-Reiniciar` lo deriva solo y prueba los dos nombres antes de rendirse. Ver [[ares-topologia-bc]].

> [!warning] El dev endpoint NO está donde está el cliente web
> `launch.json` dice `https://mimir.arbumasa.com/BC252`, que es la URL del **cliente web detrás de IIS**. El servicio de desarrollo escucha **aparte, en el puerto 7049** del mismo host, y el path es sólo la instancia:
>
> ```
> https://mimir.arbumasa.com:7049/BC252/dev/apps?SchemaUpdateMode=Synchronize
> ```
>
> Contra la URL del cliente web la publicación devuelve **404**, que se lee como un problema de permisos y no lo es: no hay nada escuchando ahí. Por eso el script sondea primero `…/dev/metadata` con un GET: si el endpoint no está donde se cree, falla ahí y lo dice.

Dos detalles más del protocolo, cada uno con su código de error propio:

| Síntoma | Causa |
|---|---|
| **415** Unsupported Media Type | El `.app` va como `multipart/form-data`, no como `application/octet-stream`. En PowerShell, `-Form @{ upload = Get-Item $app }` |
| **422** Unprocessable Entity | El **cuerpo** de la respuesta lo explica; hay que leerlo. El caso habitual: *"already deployed as a global application"* |

> [!important] El dev endpoint no reemplaza una versión ya publicada como global
> Si la versión de `app.json` ya está instalada como aplicación **global** —que es cómo está hoy la de `mimir`—, el POST devuelve 422 y no publica nada. Las dos salidas son decisión del usuario: subir `version` en `app.json` ([[Versionado de app.json]]), o despublicar la global con `Unpublish-NAVApp` en el servidor. El script no toca la versión: la sube el usuario al publicar ([[version-app-json-manual]]).

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
