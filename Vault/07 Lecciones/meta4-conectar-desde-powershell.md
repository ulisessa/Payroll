---
aliases: ["Conectar a Meta4 desde PowerShell"]
tipo: leccion
tema: migracion-meta4
tags: [leccion, migracion-meta4, reference]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-27
---

# Conectar a Meta4 desde PowerShell

**En una frase:** Cómo consultar Meta4 (Oracle): usar el puente de node-oracledb, no el de ODP.NET, que dejó de completar el handshake

## Usar el puente de node-oracledb: `scratchpad/ora/m4.js`

Desde el 27/9/2026 **el camino de ODP.NET dejó de funcionar** y el que anda es
`node-oracledb` en modo Thin —JavaScript puro, sin cliente Oracle— que es el mismo transporte
que usa DBeaver:

```powershell
$env:M4PWD = '...'; Get-Content consulta.sql | node m4.js     # salida delimitada por |
```

La contraseña va por `M4PWD`, nunca como argumento: un argumento se ve en la lista de procesos.
`M4RETRIES` y `M4RETRYMS` controlan los reintentos.

**Por qué reintenta.** La instancia va y viene. Contesta `ORA-12528` —"todas las instancias
bloquean conexiones nuevas"— y a los segundos `NJS-519`/`ORA-12505` —"la SID no está
registrada", o sea caída—. No significa que la cadena esté mal: hay que esperar la ventana. El
27/9/2026 entró en el intento 5 de 60.

**Y por qué el diagnóstico costó.** ODP.NET reporta ese mismo bloqueo como `ORA-50000:
Connection request timed out`, un timeout genérico sin código, así que parece un problema de red
y no lo es. Lo que confunde más: DBeaver seguía "funcionando" porque tenía conexiones **ya
establecidas**; `Get-NetTCPConnection -RemotePort 1521` muestra si hay alguna viva. Y el TCP a
la 1521 abre siempre en 10 ms porque el listener está arriba: es la instancia la que no acepta.
Si hace falta descartar la credencial, probar con contraseña vacía: si da el mismo timeout en
vez de `ORA-01017`, no es la contraseña.

En la máquina **no hay ningún JDK** —el JRE de DBeaver no trae `javac` ni `jshell`—, así que un
puente JDBC no es opción aunque el `ojdbc11` esté en
`AppData\Roaming\DBeaverData\drivers\maven\...`.

## Lo que sigue valiendo del camino viejo (ODP.NET, `ora\Meta4.ps1`)

Funcionó desde el 18/9/2026, sin instalar cliente Oracle ni driver ODBC. Reemplaza lo que
decía [[meta4-es-oracle]] sobre que no había vía: la había, faltaba el ensamblado. Se deja
documentado porque de ahí sale la contraseña y la cadena de conexión.

`Oracle.ManagedDataAccess.dll` (build de **.NET Framework / net462**, dentro del `.nupkg` de
NuGet en `lib\net462\`) quedó en la raíz del proyecto. La `.Core` NO sirve: esta máquina tiene
runtime de .NET 9/10 pero **no tiene SDK**, así que el único compilador es el del Framework
vía `Add-Type` de PowerShell 5.1.

Tres cosas que hay que saber o no arranca:

- **`Add-Type -Path` revienta** con `ReflectionTypeLoadException`: enumera todos los tipos del
  ensamblado. Usar `[Reflection.Assembly]::LoadFrom()`.
- **Faltan dependencias** que no vienen en el paquete: `System.Threading.Tasks.Extensions`,
  `System.Buffers`, `System.Runtime.CompilerServices.Unsafe`, `System.Memory` (están en
  `~\.vscode\extensions\ms-dotnettools.csharp-*\.roslyn\BuildHost-net472\`) y
  `System.Diagnostics.DiagnosticSource` (en `C:\Program Files\Git\mingw64\bin\`, build netfx).
- **Las versiones no coinciden** con las que pide el driver, y .NET Framework exige exactitud.
  En PowerShell no hay `app.config` para una redirección de enlace, así que hay que enganchar
  `AppDomain.CurrentDomain.add_AssemblyResolve` y resolver por nombre simple ignorando la
  versión. Eso ES la redirección.

El helper quedó en el scratchpad (`ora\Meta4.ps1`) y **tiene la contraseña adentro**: si alguna
vez se mueve al repo, sacarla primero. Conexión por **SID** (`CONNECT_DATA=(SID=Meta4)`), no
por service name.

Tablas útiles del esquema `ARBPRO`: `M4T_HIST_PUESTOS` (historial), `M4T_PUESTOS_TRABAJO` (el
catálogo; la descripción es `N_PUESTO`, no `DESCRIPCION`), `M4T_VAL_COEF_CAPECA_PUESTO` (los
índices) y `M4T_VAL_CONVENIO_CATEG_PUESTO`.

## El handler de AssemblyResolve no puede usar cmdlets

La primera versión usaba `Test-Path` y `Join-Path` adentro del handler. Son **cmdlets**, y si
PowerShell necesita cargar un ensamblado para ejecutarlos vuelve a disparar `AssemblyResolve`,
que vuelve a llamar al cmdlet: **recursión infinita y `StackOverflowException` que mata el
proceso entero**, sin excepción capturable.

Sólo se manifiesta cuando alguien pide un ensamblado que **no** está en la carpeta, así que
parece estable durante meses. Apareció al formatear un mensaje de error, que internamente pidió
`System.Text.Json`. En una corrida de minutos se pierde el trabajo; en una de horas, mucho más.

Tres correcciones, todas en `ora\Meta4.ps1`:

- Sólo llamadas a .NET adentro del handler: `[System.IO.Path]::Combine` y `[System.IO.File]::Exists`.
- Un guard de reentrada (`$script:M4Resolviendo`), porque `LoadFrom` puede disparar el evento
  para una dependencia del ensamblado que se está cargando.
- Registrar el handler **una sola vez**: cada dot-source agregaba otro, y todos corren en cada
  fallo de resolución.

Relacionado: leer valores con `$rd[$i]` en vez de getters tipados también dispara la carga de
`System.Text.Json` — ver [[meta4-number-castea-a-cero]] para ésa y las otras trampas de forma.

## Relacionado

- [[meta4-es-oracle]]
- [[meta4-number-castea-a-cero]]
- [[migracion-atributos-cct-meta4]]
- [[migracion-estados-meta4]]
- [[migracion-novedades-meta4]]
- [[migracion-tipo-liq-incompleta]]
- Tema: `migracion-meta4` (ver [[_Convenciones del vault]])
