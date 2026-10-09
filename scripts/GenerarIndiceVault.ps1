<#
.SYNOPSIS
  Regenera los índices automáticos del vault de Obsidian (Vault/).
.DESCRIPTION
  - 08 Referencia/Objetos AL.md       : inventario de objetos de src/ y test/ (tipo, ID declarado, nombre, archivo)
  - 07 Lecciones/Índice de lecciones.md : lecciones agrupadas por el campo `tema` del frontmatter
  - Informe de enlaces [[...]] rotos y de notas huérfanas (por consola)
  Uso:  pwsh scripts/GenerarIndiceVault.ps1
#>
param([string]$Raiz = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$vault = Join-Path $Raiz 'Vault'
$hoy = Get-Date -Format 'yyyy-MM-dd'
$utf8 = New-Object System.Text.UTF8Encoding($false)

# ---------- 1. Objetos AL ----------
$tipos = [ordered]@{
  'table' = 'Tablas'; 'tableextension' = 'Extensiones de tabla'; 'codeunit' = 'Codeunits'; 'page' = 'Páginas';
  'pageextension' = 'Extensiones de página'; 'report' = 'Reportes'; 'enum' = 'Enums'; 'controladdin' = 'Control add-ins';
  'permissionset' = 'Permission sets'; 'profile' = 'Perfiles'; 'query' = 'Queries'; 'xmlport' = 'XMLports'
}
$objs = @()
foreach ($carpeta in 'src', 'test') {
  $ruta = Join-Path $Raiz $carpeta
  if (-not (Test-Path $ruta)) { continue }
  Get-ChildItem $ruta -Recurse -Filter *.al | ForEach-Object {
    $rel = $_.FullName.Substring($Raiz.Length + 1).Replace('\', '/')
    $linea = Get-Content $_.FullName -Encoding UTF8 | Where-Object { $_ -match '^\s*(table|tableextension|codeunit|page|pageextension|report|enum|controladdin|permissionset|profile|query|xmlport)\s+' } | Select-Object -First 1
    if ($linea -match '^\s*(?<t>\w+)\s+(?<id>\d+)?\s*"?(?<n>[^"\r\n]*?)"?(\s+extends\s+"?(?<b>[^"\r\n]*?)"?)?\s*(\{)?\s*$') {
      $objs += [pscustomobject]@{ Tipo = $Matches.t.ToLower(); Id = $Matches.id; Nombre = $Matches.n; Base = $Matches.b; Archivo = $rel }
    }
  }
}
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("---`ntipo: referencia`ntags: [referencia, generado]`nactualizado: $hoy`n---")
[void]$sb.AppendLine("`n# Objetos AL`n`n> [!note] Generado por ``scripts/GenerarIndiceVault.ps1`` — no editar a mano. El **ID declarado** dentro del archivo manda sobre el número del nombre de archivo (hay tablas renumeradas, ver [[rangos-licencia-objetos]]).`n")
[void]$sb.AppendLine("Total: **$($objs.Count)** objetos.`n")
foreach ($t in $tipos.Keys) {
  $g = $objs | Where-Object Tipo -eq $t | Sort-Object { if ($_.Id) { [int]$_.Id } else { 0 } }, Nombre
  if (-not $g) { continue }
  [void]$sb.AppendLine("## $($tipos[$t]) ($($g.Count))`n")
  [void]$sb.AppendLine("| ID | Nombre | Base | Archivo |`n|---|---|---|---|")
  foreach ($o in $g) { [void]$sb.AppendLine("| $($o.Id) | $($o.Nombre) | $($o.Base) | ``$($o.Archivo)`` |") }
  [void]$sb.AppendLine('')
}
[System.IO.File]::WriteAllText((Join-Path $vault '08 Referencia\Objetos AL.md'), $sb.ToString(), $utf8)
Write-Host "Objetos AL: $($objs.Count)"

# ---------- 2. Índice de lecciones ----------
$dirL = Join-Path $vault '07 Lecciones'
$lecc = Get-ChildItem $dirL -Filter *.md | Where-Object { $_.Name -notlike '_*' -and $_.Name -notlike 'Índice*' } | ForEach-Object {
  $txt = Get-Content $_.FullName -Raw -Encoding UTF8
  $tema = if ($txt -match '(?m)^tema:\s*(.+?)\s*$') { $Matches[1] } else { 'sin-tema' }
  $alias = if ($txt -match '(?m)^aliases:\s*\[(.+?)\]\s*$') { $Matches[1].Trim('"', ' ') } else { $_.BaseName }
  $h1 = if ($txt -match '(?m)^[^\r\n]*?\r?\n#\s+(.+)$') { $null } else { $null }
  [pscustomobject]@{ Slug = $_.BaseName; Tema = $tema; Titulo = $alias }
}
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("---`ntipo: referencia`ntags: [referencia, generado, leccion]`nactualizado: $hoy`n---")
[void]$sb.AppendLine("`n# Índice de lecciones`n`n> [!note] Generado por ``scripts/GenerarIndiceVault.ps1``. $($lecc.Count) lecciones agrupadas por tema. Cada una es una trampa o decisión que ya costó tiempo: **leer las del tema antes de tocar esa zona**.`n")
foreach ($g in ($lecc | Group-Object Tema | Sort-Object Name)) {
  [void]$sb.AppendLine("## $($g.Name) ($($g.Count))`n")
  foreach ($l in ($g.Group | Sort-Object Slug)) { [void]$sb.AppendLine("- [[$($l.Slug)]] — $($l.Titulo)") }
  [void]$sb.AppendLine('')
}
[System.IO.File]::WriteAllText((Join-Path $dirL 'Índice de lecciones.md'), $sb.ToString(), $utf8)
Write-Host "Lecciones: $($lecc.Count)"

# ---------- 3. Enlaces rotos y huérfanas ----------
$notas = Get-ChildItem $vault -Recurse -Filter *.md | Where-Object { $_.FullName -notmatch '\\\.obsidian\\' }
$nombres = @{}; foreach ($n in $notas) { $nombres[$n.BaseName.ToLower()] = $true }
$rotos = @(); $entrantes = @{}
foreach ($n in $notas) {
  $txt = Get-Content $n.FullName -Raw -Encoding UTF8
  $txt = [regex]::Replace($txt, '(?s)```.*?```', '')
  foreach ($m in [regex]::Matches($txt, '\[\[([^\]\|#]+)(#[^\]\|]*)?(\|[^\]]*)?\]\]')) {
    $dest = $m.Groups[1].Value.Trim()
    if ($nombres.ContainsKey($dest.ToLower())) { $entrantes[$dest.ToLower()] = 1 + [int]$entrantes[$dest.ToLower()] }
    else { $rotos += [pscustomobject]@{ Desde = $n.BaseName; Destino = $dest } }
  }
}
Write-Host "`nEnlaces rotos: $($rotos.Count)"
$rotos | Group-Object Destino | Sort-Object Count -Descending | Select-Object -First 40 | ForEach-Object { "{0,3}  {1}   <- {2}" -f $_.Count, $_.Name, (($_.Group.Desde | Select-Object -Unique -First 3) -join ', ') }
$huerf = $notas | Where-Object { -not $entrantes.ContainsKey($_.BaseName.ToLower()) } | Select-Object -ExpandProperty BaseName
Write-Host "`nNotas sin enlaces entrantes: $($huerf.Count)"
$huerf | Select-Object -First 40
