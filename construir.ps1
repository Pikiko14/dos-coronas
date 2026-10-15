# Empaqueta el proyecto para distribuirlo.
#   dist\servidor.love  y  dist\juego.love        (con compartido\ dentro)
#   dist\DosCoronas-Windows\                       el juego listo para entregar a los jugadores:
#                                                  DosCoronas.exe + DLL de LÖVE (el servidor va dentro del paquete, sin .env)
# Uso:  construir.bat              (o)  construir.ps1 -Servidor "mi.dominio.com" -Puerto 30555
param(
  [string]$Servidor = "",
  [int]$Puerto = 0,
  [string]$Actualizaciones = "",      # dirección de los parches (por defecto http://<Servidor>/actualizacion/)
  [string]$Love = ""
)
$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$dist = Join-Path $raiz "dist"
New-Item -ItemType Directory -Force $dist | Out-Null

function Vaciar($ruta) {
  if (Test-Path $ruta) { Get-ChildItem $ruta -Recurse -Force | Remove-Item -Recurse -Force; Remove-Item $ruta -Force }
}

function Empaquetar($nombre) {
  $origen = Join-Path $raiz $nombre
  $stage = Join-Path $dist ($nombre + "-stage")
  Vaciar $stage
  New-Item -ItemType Directory -Force $stage | Out-Null
  robocopy $origen $stage /E /XD capturas preview mon house npc /XF .env log.txt error_log.txt "prueba_*.txt" cuentas.json /NFL /NDL /NJH /NJS /NP | Out-Null
  robocopy (Join-Path $raiz "compartido") (Join-Path $stage "compartido") /E /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($nombre -eq "juego" -and ($Servidor -or $Puerto -gt 0)) {
    # el servidor de destino va DENTRO del paquete (no en un .env suelto junto al .exe)
    $urlAct = $Actualizaciones
    if (-not $urlAct -and $Servidor -and $Servidor -ne "127.0.0.1") { $urlAct = "http://$Servidor/actualizacion/" }
    $lua = "-- Generado por construir.ps1: servidor al que se conecta este juego y de dónde baja las actualizaciones.`r`nreturn { host = `"$Servidor`", puerto = $Puerto, actualizaciones = `"$urlAct`" }`r`n"
    [System.IO.File]::WriteAllText((Join-Path $stage "src\infraestructura\destino.lua"), $lua, (New-Object System.Text.UTF8Encoding $false))
  }
  $zip = Join-Path $dist ($nombre + ".zip")
  $love = Join-Path $dist ($nombre + ".love")
  if (Test-Path $zip) { Remove-Item $zip -Force }
  if (Test-Path $love) { Remove-Item $love -Force }
  Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip -Force
  Move-Item $zip $love -Force
  Vaciar $stage
  "{0}: {1:N1} MB" -f $love, ((Get-Item $love).Length / 1MB)
}

Empaquetar "servidor"
Empaquetar "juego"

# --- Juego para Windows: love.exe + juego.love fusionados en un solo .exe ---
if (-not $Love) {
  foreach ($c in @((Join-Path $raiz "..\love"), "C:\Program Files\LOVE")) {
    if (Test-Path (Join-Path $c "love.exe")) { $Love = (Resolve-Path $c).Path; break }
  }
}
if (-not $Love) {
  "No encontré la carpeta de LÖVE: no se genera el .exe. Usa -Love 'C:\ruta\a\love'."
} else {
  $salida = Join-Path $dist "DosCoronas-Windows"
  # si el juego está abierto, el .exe no se puede reemplazar: se avisa ANTES de borrar nada
  $exeViejo = Join-Path $salida "DosCoronas.exe"
  if (Test-Path $exeViejo) {
    try { $f = [System.IO.File]::Open($exeViejo, "Open", "ReadWrite", "None"); $f.Close() }
    catch { throw "DosCoronas.exe de dist\DosCoronas-Windows está en uso: cierra el juego y vuelve a ejecutar construir (no se ha borrado nada)." }
  }
  Vaciar $salida
  New-Item -ItemType Directory -Force $salida | Out-Null
  $exe = Join-Path $salida "DosCoronas.exe"
  # love.exe con el icono del juego (la corona): se cambia en una copia ANTES de pegarle el juego
  $base = Join-Path $Love "love.exe"
  $copiaIcono = Join-Path $dist "love-icono.exe"
  try {
    . (Join-Path $raiz "recursos\PonerIcono.ps1")
    Copy-Item (Join-Path $Love "love.exe") $copiaIcono -Force
    Poner-Icono $copiaIcono (Join-Path $raiz "recursos\DosCoronas.ico")
    $base = $copiaIcono
  } catch {
    "AVISO: no se pudo poner el icono del juego en el .exe ($($_.Exception.Message)); se usa el de LÖVE."
  }
  $out = [System.IO.File]::Create($exe)
  foreach ($parte in @($base, (Join-Path $dist "juego.love"))) {
    $bytes = [System.IO.File]::ReadAllBytes($parte)
    $out.Write($bytes, 0, $bytes.Length)
  }
  $out.Close()
  if (Test-Path $copiaIcono) { Remove-Item $copiaIcono -Force }
  Get-ChildItem $Love -Filter *.dll | Copy-Item -Destination $salida
  Copy-Item (Join-Path $Love "license.txt") (Join-Path $salida "LICENCIA-LOVE.txt") -ErrorAction SilentlyContinue
  $leeme = "Dos Coronas`r`n`r`nAbre DosCoronas.exe. Crea una cuenta y juega.`r`n"
  [System.IO.File]::WriteAllText((Join-Path $salida "LEEME.txt"), $leeme, (New-Object System.Text.UTF8Encoding $false))
  "{0}: {1:N1} MB (servidor: {2})" -f $salida, ((Get-ChildItem $salida -Recurse | Measure-Object Length -Sum).Sum / 1MB), $(if ($Servidor) { $Servidor } else { "127.0.0.1" })
}
Copy-Item (Join-Path $raiz "servidor\.env.example") (Join-Path $dist "servidor.env.example") -Force
