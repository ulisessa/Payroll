<#
.SYNOPSIS
    Compila la extensión, la publica en BC y deja el entorno listo para recalcular.

.DESCRIPTION
    Reemplaza el ciclo a mano de "compilar en VS Code, publicar con Ctrl+F5, reiniciar el servicio,
    borrar rad.json". Hace lo mismo que el Publish de VS Code —un POST al dev endpoint con
    autenticación Windows— y agrega lo que VS Code no hace.

    POR QUÉ EXISTE. Durante la conciliación de enero de 2026 hubo tres publicaciones en falso: se
    recalculó con código que no había llegado al servidor y se buscó el problema en el filtro, en la
    caché y en la publicación, cuando lo que fallaba era otra cosa. Un ciclo de un solo comando que
    AVISA si algo no se publicó evita esa clase de rato perdido.

.PARAMETER Reiniciar
    Reinicia el service tier después de publicar. Hace falta SÓLO cuando se tocaron datos por SQL
    directo: un UPDATE por fuera no invalida la caché del service tier y BC sigue devolviendo el
    valor viejo. Publicar por sí solo ya recarga la extensión, así que para un cambio de AL no se
    necesita.

.PARAMETER SoloCompilar
    Compila y no publica. Para validar que algo compila sin tocar el servidor.

.EXAMPLE
    pwsh scripts/Publicar.ps1
    pwsh scripts/Publicar.ps1 -Reiniciar      # después de correr un script SQL
#>
[CmdletBinding()]
param(
    [switch]$Reiniciar,
    [switch]$SoloCompilar
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
Push-Location $raiz
try {
    # ---------------------------------------------------------------- configuración
    # Sale de launch.json para que no haya dos lugares diciendo a qué servidor se publica.
    $launch = Get-Content (Join-Path $raiz '.vscode/launch.json') -Raw | ConvertFrom-Json
    $cfg = $launch.configurations | Where-Object { $_.request -eq 'launch' } | Select-Object -First 1
    if (-not $cfg) { throw 'launch.json no tiene ninguna configuración de tipo launch.' }
    $servidor = $cfg.server.TrimEnd('/')
    $instancia = $cfg.serverInstance
    $app = Get-Content (Join-Path $raiz 'app.json') -Raw | ConvertFrom-Json

    # EL DEV ENDPOINT NO ESTÁ DONDE ESTÁ EL CLIENTE WEB. launch.json dice
    # https://mimir.arbumasa.com/BC252, que es la URL del web client detrás de IIS; el servicio de
    # desarrollo escucha aparte, en el puerto 7049 del mismo host, y el path es sólo la instancia. Con
    # la URL del web client la publicación devuelve 404, que se lee como un problema de permisos y no
    # lo es: no hay nada escuchando ahí.
    $uriServidor = [Uri]$servidor
    $puerto = if ($cfg.port) { $cfg.port } else { 7049 }
    $devBase = "$($uriServidor.Scheme)://$($uriServidor.Host):$puerto/$instancia/dev"

    Write-Host "Extensión : $($app.name) $($app.version)" -ForegroundColor Cyan
    Write-Host "Servidor  : $servidor  (instancia $instancia)" -ForegroundColor Cyan
    Write-Host "Dev       : $devBase" -ForegroundColor Cyan

    # ---------------------------------------------------------------- 1. worktrees
    # alc compila TODO lo que haya bajo /project:, incluidos los worktrees de git, que llevan copias
    # viejas de los mismos objetos y producen una pared de errores que no están en el árbol de
    # trabajo. Avisar temprano ahorra leer cien líneas de ruido.
    $worktrees = @(git worktree list 2>$null | Select-Object -Skip 1)
    if ($worktrees.Count -gt 0) {
        Write-Warning "Hay $($worktrees.Count) worktree(s) de git. Si la compilación falla con errores en archivos que no tocaste, es por eso:"
        $worktrees | ForEach-Object { Write-Warning "  $_" }
    }

    # ---------------------------------------------------------------- 2. compilar
    $alc = Get-ChildItem "$env:USERPROFILE\.vscode\extensions\ms-dynamics-smb.al-*\bin\win32\alc.exe" -ErrorAction SilentlyContinue |
           Sort-Object FullName | Select-Object -Last 1
    if (-not $alc) { throw 'No se encontró alc.exe. ¿Está instalada la extensión AL de VS Code?' }

    $salida = Join-Path $raiz "$($app.publisher)_$($app.name)_$($app.version).app"
    if (Test-Path $salida) { Remove-Item $salida -Force }

    Write-Host "`nCompilando..." -ForegroundColor Cyan
    # Los cuatro warnings que este proyecto tiene desde siempre y no son noticia: campos marcados
    # para borrar en Fuente de Datos, idioma del xlf, archivos que no son AL, y Label sin comment.
    $ignorar = 'AL0432|AL1029|AL1025|AL0482'
    # SE COMPILA UNA COPIA, no la raíz. alc toma TODO lo que haya bajo /project:, y la raíz del repo
    # junta cosas que no son el proyecto: .snapshots (copias de src/ que dejan otras sesiones de trabajo
    # antes de tocar algo), worktrees, artifacts. Con cualquiera de ellas la compilación explota con
    # miles de errores "ambiguous reference" que no están en el árbol de trabajo. La copia lleva sólo lo
    # que es del proyecto y las carpetas de trabajo se dejan afuera.
    $stage = Join-Path ([IO.Path]::GetTempPath()) ("payroll-build-" + [Guid]::NewGuid().ToString('N'))
    $null = robocopy $raiz $stage /E /NFL /NDL /NJH /NJS /NP /XD .snapshots .git .claude .alpackages .vscode artifacts scripts Vault node_modules /XF *.app *.alcpuprofile *.tsv *.msg
    if ($LASTEXITCODE -ge 8) { throw "No se pudo armar la copia de compilación (robocopy $LASTEXITCODE)." }
    try {
        $log = & $alc.FullName "/project:$stage" "/packagecachepath:$raiz\.alpackages" "/out:$salida" 2>&1
    } finally {
        Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
    $errores = $log | Where-Object { $_ -match 'error ' -and $_ -notmatch $ignorar }
    if ($errores) {
        $errores | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        throw "La compilación falló con $($errores.Count) error(es). No se publicó nada."
    }
    if (-not (Test-Path $salida)) { throw 'La compilación no produjo el .app y no dijo por qué.' }
    $kb = [math]::Round((Get-Item $salida).Length / 1KB)
    Write-Host "  OK — $kb KB" -ForegroundColor Green

    if ($SoloCompilar) {
        Write-Host "`n-SoloCompilar: no se publicó." -ForegroundColor Yellow
        Remove-Item $salida -Force
        return
    }

    # ---------------------------------------------------------------- 3. publicar
    # El mismo dev endpoint que usa VS Code. schemaUpdateMode sale de launch.json: Synchronize
    # agrega y modifica campos sin tocar los datos; ForceSync DROPEA columnas y tablas, y por eso
    # este script nunca lo manda aunque launch.json lo diga.
    $modo = if ($cfg.schemaUpdateMode) { $cfg.schemaUpdateMode } else { 'Synchronize' }
    if ($modo -eq 'ForceSync') {
        throw 'launch.json pide ForceSync, que dropea columnas con sus datos. Publicá a mano si realmente es lo que querés.'
    }
    # Antes de mandar el .app, un GET a /dev/metadata: si el endpoint no está donde se cree, falla acá
    # con un mensaje que lo dice, en lugar de un 404 en el POST que parece falta de permiso.
    try {
        $sonda = Invoke-WebRequest -Uri "$devBase/metadata" -Method Get -UseDefaultCredentials `
            -TimeoutSec 60 -SkipHttpErrorCheck
    } catch {
        throw "No se pudo llegar al dev endpoint ($devBase): $($_.Exception.Message)"
    }
    if ($sonda.StatusCode -ne 200) {
        throw "El dev endpoint $devBase responde $($sonda.StatusCode). Revisá el puerto de desarrollo del service tier (DeveloperServicesPort, por omisión 7049) y que esté habilitado."
    }

    $uri = "$devBase/apps?SchemaUpdateMode=$modo"
    Write-Host "`nPublicando ($modo)..." -ForegroundColor Cyan
    # EL .app VA COMO multipart/form-data, no como octet-stream: con el cuerpo crudo el endpoint
    # contesta 415. -Form se lo arma solo a partir de un FileInfo.
    #
    # Y -SkipHttpErrorCheck en lugar de try/catch porque el CUERPO de la respuesta es donde BC explica
    # qué pasó. Sin leerlo, un 422 perfectamente explicado llega como "Unprocessable Entity" y se
    # confunde con un problema de permisos.
    $resp = Invoke-WebRequest -Uri $uri -Method Post -Form @{ upload = Get-Item -LiteralPath $salida } `
        -UseDefaultCredentials -TimeoutSec 900 -SkipHttpErrorCheck

    if ($resp.StatusCode -ge 400) {
        $detalle = $resp.Content
        try { $detalle = ($resp.Content | ConvertFrom-Json).Message.Trim() } catch { }

        # El caso que aparece siempre: la misma versión ya está publicada como aplicación global. El
        # dev endpoint no la reemplaza, y la versión de app.json la sube el usuario al publicar, no
        # este script.
        if ($detalle -match 'already deployed') {
            Write-Host ''
            Write-Warning "El servidor ya tiene la versión $($app.version) publicada como aplicación GLOBAL, y el dev endpoint no la reemplaza."
            Write-Warning 'Hay dos salidas, y las dos son decisión tuya:'
            Write-Warning '  1. Subir "version" en app.json y volver a correr este script.'
            Write-Warning '  2. Despublicar la global en el servidor (Unpublish-NAVApp) y publicar de nuevo.'
            Write-Host ''
            Write-Host "Respuesta del servidor: $detalle" -ForegroundColor DarkGray
            Write-Host "El .app quedó compilado en: $salida" -ForegroundColor DarkGray
            throw 'No se publicó: la versión ya está publicada.'
        }

        Write-Host "El .app quedó compilado en: $salida" -ForegroundColor DarkGray
        throw "No se pudo publicar ($($resp.StatusCode)): $detalle"
    }
    Write-Host '  Publicada.' -ForegroundColor Green
    Remove-Item $salida -Force

    # ---------------------------------------------------------------- 4. rad.json
    # VS Code lo regenera en cada publicación y su "Removed" es peligroso: si trae una TABLA, una
    # publicación posterior con RAD la dropea CON SUS DATOS. Se borra siempre, pero antes se muestra
    # para que quede registro de lo que decía.
    $rad = Join-Path $raiz '.vscode/rad.json'
    if (Test-Path $rad) {
        $contenido = Get-Content $rad -Raw | ConvertFrom-Json
        $quitados = @($contenido.Removed)
        if ($quitados.Count -gt 0) {
            $tablas = @($quitados | Where-Object { $_.Kind -eq 10 })
            if ($tablas.Count -gt 0) {
                Write-Warning "rad.json tenía TABLAS en Removed. Si alguien publica con RAD, las dropea con sus datos:"
                $tablas | ForEach-Object { Write-Warning "  Tabla $($_.Id) $($_.Name)" }
            } else {
                Write-Host "  rad.json traía en Removed: $($quitados | ForEach-Object { "$($_.Id) $($_.Name)" } | Join-String -Separator ', ')" -ForegroundColor DarkGray
            }
        }
        Remove-Item $rad -Force
        Write-Host '  rad.json borrado.' -ForegroundColor Green
    }

    # ---------------------------------------------------------------- 5. reiniciar
    if ($Reiniciar) {
        # EL NOMBRE DEL SERVIDOR DE launch.json NO SIRVE PARA WinRM. Ahí dice mimir.arbumasa.com, que
        # es un alias de DNS: resuelve a la IP correcta, pero Kerberos pide un SPN para ese nombre y
        # no existe, así que la conexión muere con "No puede encontrarse el equipo". El nombre que sí
        # funciona es el FQDN del dominio —mimir.arbumasa.net.ar—, y se saca resolviendo el nombre
        # corto por DNS en vez de escribirlo acá. Se prueban los dos: primero el del dominio, y el
        # del alias de respaldo por si algún día el alias tiene su SPN.
        $hostLaunch = ([Uri]$servidor).Host
        $corto = $hostLaunch.Split('.')[0]
        $candidatos = @()
        try { $candidatos += [System.Net.Dns]::GetHostEntry($corto).HostName } catch { }
        $candidatos += $hostLaunch
        $candidatos += $corto
        $candidatos = $candidatos | Where-Object { $_ } | Select-Object -Unique

        $servicio = "MicrosoftDynamicsNavServer`$$instancia"
        $reiniciado = $false
        foreach ($maquina in $candidatos) {
            Write-Host "`nReiniciando $servicio en $maquina..." -ForegroundColor Cyan
            try {
                Invoke-Command -ComputerName $maquina -ScriptBlock {
                    param($svc)
                    Restart-Service -Name $svc -Force
                    (Get-Service -Name $svc).Status
                } -ArgumentList $servicio -ErrorAction Stop | ForEach-Object {
                    Write-Host "  Estado: $_" -ForegroundColor Green
                }
                $reiniciado = $true
                break
            } catch {
                Write-Host "  No anduvo por $maquina ($($_.Exception.Message.Split([Environment]::NewLine)[0]))" -ForegroundColor DarkGray
            }
        }
        if (-not $reiniciado) {
            Write-Warning "No se pudo reiniciar de forma remota por ninguno de: $($candidatos -join ', ')"
            Write-Warning "Reinicialo a mano. Hace falta sólo si tocaste datos por SQL: la caché del service tier no se entera de un UPDATE por fuera."
        }
    }

    Write-Host "`nListo." -ForegroundColor Green
    if (-not $Reiniciar) {
        Write-Host 'Si antes corriste un script SQL, reiniciá con -Reiniciar o la caché va a devolver los valores viejos.' -ForegroundColor DarkGray
    }
} finally {
    Pop-Location
}
