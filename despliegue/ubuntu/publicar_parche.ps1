# Genera un parche de actualización del juego y lo sube al VPS; los jugadores lo reciben solos al abrir el juego
# (no tienen que volver a descargarlo). Se ejecuta en tu PC con Windows.
#   .\despliegue\ubuntu\publicar_parche.ps1 -Servidor 203.0.113.10 -Version "beta 0.9.9"
#   .\despliegue\ubuntu\publicar_parche.ps1 -SinSubir            (solo genera dist\parche\, para probarlo en local)
# El parche lleva TODO el código del juego (juego\src, compartido\, version.lua) y no el arte (juego\arte, 80 MB):
# si cambias imágenes o sonidos hay que usar -ConArte (parche grande) o publicar un paquete nuevo en la web.
# Sube el número "build" de juego\version.lua en 1 (un parche solo se aplica si su build supera al del juego instalado).
# Una vez lo has probado, haz commit de juego\version.lua para que los paquetes nuevos nazcan con ese build.
param(
  [string]$Servidor = "",
  [string]$Version = "",
  [string]$Usuario = "root",
  [int]$Puerto = 22,
  [switch]$ConArte,
  [switch]$SinSubir
)
$ErrorActionPreference = "Stop"
$raiz = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if (-not $SinSubir -and -not $Servidor) { throw "Indica -Servidor (IP o dominio del VPS), o usa -SinSubir." }

# --- build nuevo ---
$archivoVersion = Join-Path $raiz "juego\version.lua"
$actual = Get-Content $archivoVersion -Raw
if ($actual -notmatch "build\s*=\s*(\d+)") { throw "No encuentro el build en juego\version.lua" }
$build = [int]$Matches[1] + 1
$nombre = $Version
if (-not $nombre) { if ($actual -match 'nombre\s*=\s*"([^"]*)"') { $nombre = $Matches[1] } }
$lua = "-- Versión del juego. build sube con cada parche de actualización (despliegue/ubuntu/publicar_parche.ps1); un parche solo se`n-- aplica si su build es mayor que el del paquete instalado.`nreturn { build = $build, nombre = `"$nombre`" }`n"
[System.IO.File]::WriteAllText($archivoVersion, $lua, (New-Object System.Text.UTF8Encoding $false))

# --- zip con rutas de barra normal (Compress-Archive de PowerShell 5 pone contrabarras y LÖVE no las toma por carpetas) ---
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$salida = Join-Path $raiz "dist\parche"
New-Item -ItemType Directory -Force $salida | Out-Null
$nombreZip = "actualizacion_$build.zip"
$rutaZip = Join-Path $salida $nombreZip
Get-ChildItem $salida -Filter "actualizacion_*.zip" | Remove-Item -Force
if (Test-Path $rutaZip) { Remove-Item $rutaZip -Force }

function Incluir($rel) {
  $r = $rel.Replace("\", "/")
  if ($r -match "^(capturas|preview)/") { return $false }
  if (-not $ConArte -and $r -match "^arte/") { return $false }
  if ($r -in @("main.lua", "conf.lua", "src/infraestructura/destino.lua", ".env", "log.txt", "error_log.txt")) { return $false }
  if ($r -match "(^|/)prueba_[^/]*\.txt$" -or $r -match "(^|/)cuentas\.json$") { return $false }
  return $true
}

$zip = [System.IO.Compression.ZipFile]::Open($rutaZip, "Create")
try {
  $n = 0
  foreach ($par in @(@{ dir = (Join-Path $raiz "juego"); pre = "" }, @{ dir = (Join-Path $raiz "compartido"); pre = "compartido/" })) {
    $base = $par.dir.TrimEnd("\") + "\"
    foreach ($f in Get-ChildItem $par.dir -Recurse -File) {
      $rel = $f.FullName.Substring($base.Length).Replace("\", "/")
      if ($par.pre -eq "" -and -not (Incluir $rel)) { continue }
      [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, ($par.pre + $rel), [System.IO.Compression.CompressionLevel]::Optimal)
      $n++
    }
  }
} finally { $zip.Dispose() }

$sha = (Get-FileHash $rutaZip -Algorithm SHA256).Hash.ToLower()
$manifiesto = "build=$build`nnombre=$nombre`narchivo=$nombreZip`nsha256=$sha`n"
$rutaManifiesto = Join-Path $salida "version.txt"
[System.IO.File]::WriteAllText($rutaManifiesto, $manifiesto, (New-Object System.Text.UTF8Encoding $false))
"Parche build {0} ({1}): {2} archivos, {3:N1} MB, sha256 {4}" -f $build, $nombre, $n, ((Get-Item $rutaZip).Length / 1MB), $sha

if ($SinSubir) { "Generado en $salida (no se subió)."; return }

# --- subida: primero el zip, al final el manifiesto (así nadie ve un manifiesto sin su archivo) ---
$destino = "$Usuario@$Servidor"
$dir = "/var/www/doscoronas/actualizacion"
scp -P $Puerto $rutaZip "${destino}:$dir/$nombreZip.tmp"
scp -P $Puerto $rutaManifiesto "${destino}:$dir/version.txt.tmp"
ssh -p $Puerto $destino "set -e; cd $dir; chmod 644 *.tmp; mv $nombreZip.tmp $nombreZip; mv version.txt.tmp version.txt; ls -1t actualizacion_*.zip | tail -n +4 | xargs -r rm -f; ls -la"
"Listo: los jugadores recibirán el build $build al abrir el juego."
