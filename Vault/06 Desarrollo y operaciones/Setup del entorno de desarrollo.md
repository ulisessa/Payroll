---
tipo: guia
tags: [desarrollo, entorno, vscode]
fuente: [app.json, .vscode/launch.json, .vscode/settings.json, .gitignore, .claude/settings.json, .altestrunner/config.json]
actualizado: 2026-10-04
---

# Setup del entorno de desarrollo

Qué hace falta para abrir, compilar y publicar la extensión *Liquidación Sueldos Pesca* en una máquina nueva. Complementa a [[Compilar con alc.exe]] y [[Publicar en BC (no usar RAD)]].

## Identidad de la app (`app.json`)

| Campo | Valor |
|---|---|
| `id` | `d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890` (es el sufijo de todas las tablas SQL de la extensión, ver [[campos-extension-tabla-ext]]) |
| `name` / `publisher` | `Liquidación Sueldos Pesca` / `Grupo Arbumasa` |
| `platform` / `application` / `runtime` | `25.2.0.0` / `25.2.0.0` / `14.0` |
| `target` | **OnPrem** (no hay SaaS, no hay AppSource) |
| `idRanges` | **50000–149999** — pero la licencia habilita sólo parte, ver [[Rangos de IDs y licencia]] |
| `features` | `TranslationFile` (ver [[Convenciones de código AL del proyecto]], sección traducciones) |
| `resourceExposurePolicy` | `allowDebugging: true`, `allowDownloadingSource: false` |
| `version` | la sube el usuario a mano, ver [[Versionado de app.json]] |

## Dependencias declaradas

| Dependencia | Publisher | Versión pedida | Para qué |
|---|---|---|---|
| Final Version Customization Extension - Tables Only | Grupo Arbumasa | 2.0.0.0 | Personalización convertida de NAV: Job, Employee, Cab./Lín. descarga. Sus símbolos traen el AL completo, ver [[symbolos-final-version-tienen-fuente]] |
| System Application / Business Foundation / Base Application | Microsoft | 25.2.0.0 | Base de BC |
| Impuestos.Retenciones | Grupo Arbumasa | 25.2.31024.61 | Retenciones (extensión hermana del grupo) |
| Generalistas.Escaneado | Grupo Arbumasa | 25.2.31024.0 | Escaneado/OCR (hermana) |
| WebServicesAFIP | Grupo Arbumasa | 25.2.31024.0 | Servicios AFIP (lo consume la auditoría AFIP, ver `Cod50059.AuditoriaAfipInterface.al`) |

Los `.app` de símbolos viven en `.alpackages/` (no versionada). Al 2026-10-04 contiene varias versiones de cada dependencia propia (Final Version 2.0.0.0/.2/.3, Generalistas.Escaneado .0/.5, WebServicesAFIP .14/.100) y los símbolos de Microsoft son **25.5.30849** aunque `app.json` pide 25.2.0.0. Compila igual (ver [[Compilar con alc.exe]]).

> [!note] Cómo conseguir los símbolos
> Se descargan desde el servidor (`AL: Download Symbols`, con `launch.json`) o se copian de la máquina de otro desarrollador. Las tres extensiones Grupo Arbumasa no son públicas: hay que sacarlas del servidor `mimir` o de quien las compile.

## Herramientas

- **VS Code + extensión AL** (`ms-dynamics-smb.al`). Al 2026-10-04: `17.0.2273547`. El compilador `alc.exe` viene adentro, ver [[Compilar con alc.exe]].
- **Git Bash** y **PowerShell 7** (los scripts de `scripts/*.ps1` usan `System.Data.SqlClient` y COM de Excel).
- **sqlcmd** (go-sqlcmd) en `C:\Program Files\SqlCmd\sqlcmd.exe`, fuera del PATH; hace falta `-C`. Detalle en [[conexion-sql-bc]].
- **Node.js** sólo para el test del editor de fórmulas, ver [[Tests automatizados]].
- Opcional: DBeaver para Oracle/Meta4 ([[meta4-es-oracle]], [[meta4-conectar-desde-powershell]]).
- **Windows PowerShell Admin Shell** de BC (Publish-/Sync-/Start-NAVAppDataUpgrade) en el servidor, ver [[Publicar en BC (no usar RAD)]].

## `.vscode/`

- `launch.json` — cinco configuraciones, todas contra `https://mimir.arbumasa.com/BC252`, instancia `BC252`, autenticación Windows, tenant `default`:
  - **Publish & debug (mimir)**: `launch`, `schemaUpdateMode: Synchronize`, arranca en la página 50149 (`Payroll Role Center`), `breakOnError: All`.
  - **Attach to my next web-client action** y **Attach (record writes too)**: tienen `sessionId` **fijo** (53 y 38); hay que editarlo cada vez con el id real de la sesión del cliente web.
  - **Lanzar página de OCR (mimir2)**: apunta a otro servidor (`mimir2`) y a la página 50199, que **no es de este proyecto** (es de la extensión de escaneado).
  - **AL: Attach session**: `snapshotInitialize` contra `localhost:7049` (profiling).
- `settings.json` — sólo `git.openRepositoryInParentFolders: never` y `git.ignoreLimitWarning`.
- `rad.json` — **no debe existir**, ver [[rad.json - peligro]].
- `.alcache/` — caché del compilador (ignorada).

## `.claude/`

- `settings.json` y `settings.local.json`: listas de permisos (`allow`) de Claude Code. Varias entradas apuntan a la ruta vieja `d:\Users\...\OneDrive\Personal\...` (el proyecto se movió a `C:\Users\ulises.sasovsky\OneDrive\Documentos\...`), así que esas reglas ya no matchean.
- `worktrees/` está vacía; `git worktree list` sólo muestra el árbol principal. Si reaparece un worktree, ver el gotcha de [[Compilar con alc.exe]].

## `.altestrunner/config.json`

Plantilla de AL Test Runner con todo vacío (`launchConfigName`, `userName`, etc.). Nunca se completó; los tests se corren desde la UI de BC, ver [[Tests automatizados]].

## Carpetas ignoradas por git

`.gitignore` excluye `.alpackages/`, `.altestrunner/`, `.alcache/`, `.snapshots/`, `.netpackages/`, `*.app`, `*.xlsx|xls|csv|docx|pdf`, `.vscode/rad.json`. Cuidado: varios archivos de esos tipos **ya estaban versionados** antes de ignorarse; ver [[Mapa de la raíz del repo]].

## `.netpackages/`

Contiene 4 DLL (`System.IO.Compression.ZipFile`, `System.IO.FileSystem`, `System.Runtime`, `System.Windows.Forms`). Hoy **nada en `src/` usa `DotNet`** (el único hit es un comentario en `Cod110028.ControlMareaExcelLiq.al`), así que esa carpeta es un resto de cuando SIRADIG descomprimía con .NET; ahora se usa el codeunit `Data Compression` de la System Application (`Cod50047.GestorArchivosSiradig.al`). `NOTA_DESCOMPRESION_ZIP.md` está desactualizada en eso.

## Primer arranque, en orden

1. Clonar el repo, abrir la carpeta en VS Code.
2. Copiar/bajar los símbolos a `.alpackages/`.
3. Compilar con `Ctrl+Shift+B` o por CLI ([[Compilar con alc.exe]]).
4. Confirmar que **no** existe `.vscode/rad.json`.
5. Leer [[Runbook - tareas frecuentes]] antes del primer cambio.
