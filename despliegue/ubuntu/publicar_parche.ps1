# Publica una actualización del juego en el VPS; los jugadores la reciben solos al abrir el juego. Se ejecuta en tu PC con Windows.
#
#   .\despliegue\ubuntu\publicar_parche.ps1 -Servidor 203.0.113.10 -Version "beta 0.9.9"
#        PARCHE (lo normal, ~0,3 MB): todo el código (juego\src, compartido\, version.lua) + los archivos de juego\arte que sean
#        NUEVOS o hayan CAMBIADO desde el último paquete completo (sprites, sonidos...). El cliente lo aplica y se reinicia.
#   .\despliegue\ubuntu\publicar_parche.ps1 -Servidor 203.0.113.10 -Version "beta 1.0.0" -Completo
#        PAQUETE COMPLETO (~85 MB): reconstruye el juego entero (exe, DLL, main.lua, conf.lua, todo el arte), lo sube y obliga a los
#        clientes anteriores a bajarlo; el juego lo descarga, se cierra, lo instala encima y se vuelve a abrir. Úsalo cuando cambie
#        algo que un parche no puede cambiar (main.lua, conf.lua, el .exe/DLL, archivos que haya que borrar) o para "reiniciar" la
#        base de los parches (después de un completo los parches vuelven a ser mínimos).
#   .\despliegue\ubuntu\publicar_parche.ps1 -SinSubir            solo genera dist\parche\ (para probarlo en local)
#
# Cada ejecución sube en 1 el "build" de juego\version.lua (un parche solo se aplica si su build supera al del juego instalado).
# Después de publicar, haz commit de juego\version.lua (y de despliegue\arte_base.txt si publicaste un completo).
param(
  [string]$Servidor = "",
  [string]$Version = "",
  [string]$Usuario = "root",
  [int]$Puerto = 22,
  [int]$PuertoJuego = 30555,
  [switch]$Completo,
  [switch]$ConArte,       # el parche lleva TODA la carpeta arte (80 MB) en vez de solo lo que cambió
  [switch]$SinSubir
)
$ErrorActionPreference = "Stop"
$raiz = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if (-not $SinSubir -and -not $Servidor) { throw "Indica -Servidor (IP o dominio del VPS), o usa -SinSubir." }
if ($Completo -and -not $Servidor) { throw "Con -Completo indica -Servidor: el paquete nuevo lleva dentro la dirección del servidor." }

$destino = "$Usuario@$Servidor"
$dirRemoto = "/var/www/doscoronas/actualizacion"

# --- build nuevo ---
$archivoVersion = Join-Path $raiz "juego\version.lua"
$actual = Get-Content $archivoVersion -Raw
if ($actual -notmatch "build\s*=\s*(\d+)") { throw "No encuentro el build en juego\version.lua" }
$build = [int]$Matches[1] + 1
$nombre = $Version
if (-not $nombre) { if ($actual -match 'nombre\s*=\s*"([^"]*)"') { $nombre = $Matches[1] } }
$lua = "-- Versión del juego. build sube con cada parche de actualización (despliegue/ubuntu/publicar_parche.ps1); un parche solo se`n-- aplica si su build es mayor que el del paquete instalado.`nreturn { build = $build, nombre = `"$nombre`" }`n"
[System.IO.File]::WriteAllText($archivoVersion, $lua, (New-Object System.Text.UTF8Encoding $false))

# --- manifiesto anterior: de ahí salen los datos del último paquete completo (minimo, completo, shacompleto...) ---
function Leer-Manifiesto($texto) {
  $d = @{}
  foreach ($l in ($texto -split "`r?`n")) { if ($l -match "^(\w+)=(.*)$") { $d[$Matches[1]] = $Matches[2] } }
  return $d
}
$salida = Join-Path $raiz "dist\parche"
New-Item -ItemType Directory -Force $salida | Out-Null
$previo = @{}
if (-not $SinSubir) {
  $t = ssh -p $Puerto $destino "cat $dirRemoto/version.txt 2>/dev/null"
  if ($t) { $previo = Leer-Manifiesto ($t -join "`n") }
} elseif (Test-Path (Join-Path $salida "version.txt")) {
  $previo = Leer-Manifiesto (Get-Content (Join-Path $salida "version.txt") -Raw)
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ===================== PAQUETE COMPLETO =====================
if ($Completo) {
  & (Join-Path $raiz "web\publicar.ps1") -Construir -Servidor $Servidor -Puerto $PuertoJuego -Version $nombre
  $zipCompleto = Join-Path $raiz "web\descargas\DosCoronas-Windows.zip"
  $nombreCompleto = "completo_$build.zip"
  $sha = (Get-FileHash $zipCompleto -Algorithm SHA256).Hash.ToLower()
  $tam = (Get-Item $zipCompleto).Length
  $manifiesto = "build=$build`nnombre=$nombre`nminimo=$build`ncompleto=$nombreCompleto`nshacompleto=$sha`ntamanocompleto=$tam`n"
  $rutaManifiesto = Join-Path $salida "version.txt"
  [System.IO.File]::WriteAllText($rutaManifiesto, $manifiesto, (New-Object System.Text.UTF8Encoding $false))
  "Paquete completo build {0} ({1}): {2:N1} MB, sha256 {3}" -f $build, $nombre, ($tam / 1MB), $sha
  if ($SinSubir) { "Generado (no se subió)."; return }
  scp -P $Puerto $zipCompleto "${destino}:$dirRemoto/$nombreCompleto.tmp"
  scp -P $Puerto $rutaManifiesto "${destino}:$dirRemoto/version.txt.tmp"
  ssh -p $Puerto $destino "set -e; cd $dirRemoto; chmod 644 *.tmp; mv $nombreCompleto.tmp $nombreCompleto; mv version.txt.tmp version.txt; ls -1t completo_*.zip | tail -n +3 | xargs -r rm -f; ls -la"
  "Listo: los clientes anteriores bajarán el paquete completo (build $build) al abrir el juego."
  "Recuerda: sube también web\descargas\ al repo dos-coronas-web (descarga nueva) y haz commit de juego\version.lua y despliegue\arte_base.txt."
  return
}

# ===================== PARCHE =====================
$nombreZip = "actualizacion_$build.zip"
$rutaZip = Join-Path $salida $nombreZip
Get-ChildItem $salida -Filter "actualizacion_*.zip" | Remove-Item -Force
if (Test-Path $rutaZip) { Remove-Item $rutaZip -Force }

# arte de la última base: despliegue\arte_base.txt (ruta<TAB>sha256) lo escribe web\publicar.ps1 con cada paquete completo
$arteBase = @{}
$archivoBase = Join-Path $raiz "despliegue\arte_base.txt"
if (Test-Path $archivoBase) {
  foreach ($l in Get-Content $archivoBase) { $p = $l -split "`t"; if ($p.Count -eq 2) { $arteBase[$p[0]] = $p[1] } }
} elseif (-not $ConArte) {
  "AVISO: no existe despliegue\arte_base.txt: el parche no lleva arte. Publica un paquete completo (-Completo) para crearlo, o usa -ConArte."
}

function Incluir($rel, $ruta) {
  $r = $rel.Replace("\", "/")
  if ($r -match "^(capturas|preview|arte/hojas/(mon|house|npc)|arte/fao-equipos|arte/fao-personajes)/") { return $false }
  if ($r -in @("main.lua", "conf.lua", "src/infraestructura/destino.lua", ".env", "log.txt", "error_log.txt")) { return $false }
  if ($r -match "(^|/)prueba_[^/]*\.txt$" -or $r -match "(^|/)cuentas\.json$") { return $false }
  if ($r -match "^arte/") {
    if ($ConArte) { return $true }
    if ($arteBase.Count -eq 0) { return $false }
    $h = (Get-FileHash $ruta -Algorithm SHA256).Hash.ToLower()
    return (-not $arteBase.ContainsKey($r)) -or ($arteBase[$r] -ne $h)    # nuevo o cambiado
  }
  return $true
}

$zip = [System.IO.Compression.ZipFile]::Open($rutaZip, "Create")
$n = 0; $nArte = 0
try {
  foreach ($par in @(@{ dir = (Join-Path $raiz "juego"); pre = "" }, @{ dir = (Join-Path $raiz "compartido"); pre = "compartido/" })) {
    $base = $par.dir.TrimEnd("\") + "\"
    foreach ($f in Get-ChildItem $par.dir -Recurse -File) {
      $rel = $f.FullName.Substring($base.Length).Replace("\", "/")
      if ($par.pre -eq "" -and -not (Incluir $rel $f.FullName)) { continue }
      [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, ($par.pre + $rel), [System.IO.Compression.CompressionLevel]::Optimal)
      $n++
      if ($rel -match "^arte/") { $nArte++ }
    }
  }
} finally { $zip.Dispose() }

$sha = (Get-FileHash $rutaZip -Algorithm SHA256).Hash.ToLower()
$minimo = if ($previo.ContainsKey("minimo")) { $previo["minimo"] } else { "0" }
$manifiesto = "build=$build`nnombre=$nombre`narchivo=$nombreZip`nsha256=$sha`nminimo=$minimo`n"
foreach ($k in @("completo", "shacompleto", "tamanocompleto")) { if ($previo.ContainsKey($k)) { $manifiesto += "$k=$($previo[$k])`n" } }
$rutaManifiesto = Join-Path $salida "version.txt"
[System.IO.File]::WriteAllText($rutaManifiesto, $manifiesto, (New-Object System.Text.UTF8Encoding $false))
"Parche build {0} ({1}): {2} archivos ({3} de arte), {4:N1} MB, sha256 {5}" -f $build, $nombre, $n, $nArte, ((Get-Item $rutaZip).Length / 1MB), $sha

if ($SinSubir) { "Generado en $salida (no se subió)."; return }

# primero el zip, al final el manifiesto (así nadie ve un manifiesto sin su archivo)
scp -P $Puerto $rutaZip "${destino}:$dirRemoto/$nombreZip.tmp"
scp -P $Puerto $rutaManifiesto "${destino}:$dirRemoto/version.txt.tmp"
ssh -p $Puerto $destino "set -e; cd $dirRemoto; chmod 644 *.tmp; mv $nombreZip.tmp $nombreZip; mv version.txt.tmp version.txt; ls -1t actualizacion_*.zip | tail -n +4 | xargs -r rm -f; ls -la"
"Listo: los jugadores recibirán el build $build al abrir el juego."
