# Empaqueta el proyecto para distribuirlo.
#   dist\servidor.love  y  dist\juego.love        (con compartido\ dentro)
#   dist\DosCoronas-Windows\                       el juego listo para entregar a los jugadores:
#                                                  DosCoronas.exe + DLL de LÖVE + .env con la dirección del servidor
# Uso:  construir.bat              (o)  construir.ps1 -Servidor "mi.dominio.com" -Puerto 30555
param(
  [string]$Servidor = "",
  [int]$Puerto = 0,
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
  robocopy $origen $stage /E /XD capturas preview /XF .env log.txt error_log.txt "prueba_*.txt" cuentas.json /NFL /NDL /NJH /NJS /NP | Out-Null
  robocopy (Join-Path $raiz "compartido") (Join-Path $stage "compartido") /E /NFL /NDL /NJH /NJS /NP | Out-Null
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
  Vaciar $salida
  New-Item -ItemType Directory -Force $salida | Out-Null
  $exe = Join-Path $salida "DosCoronas.exe"
  $out = [System.IO.File]::Create($exe)
  foreach ($parte in @((Join-Path $Love "love.exe"), (Join-Path $dist "juego.love"))) {
    $bytes = [System.IO.File]::ReadAllBytes($parte)
    $out.Write($bytes, 0, $bytes.Length)
  }
  $out.Close()
  Get-ChildItem $Love -Filter *.dll | Copy-Item -Destination $salida
  Copy-Item (Join-Path $Love "license.txt") (Join-Path $salida "LICENCIA-LOVE.txt") -ErrorAction SilentlyContinue
  $envTexto = Get-Content (Join-Path $raiz "juego\.env.example") -Raw
  if ($Servidor) { $envTexto = $envTexto -replace "DOSCORONAS_SERVIDOR_HOST=.*", "DOSCORONAS_SERVIDOR_HOST=$Servidor" }
  if ($Puerto -gt 0) { $envTexto = $envTexto -replace "DOSCORONAS_PUERTO=.*", "DOSCORONAS_PUERTO=$Puerto" }
  [System.IO.File]::WriteAllText((Join-Path $salida ".env"), $envTexto, (New-Object System.Text.UTF8Encoding $false))
  $leeme = "Dos Coronas`r`n`r`nAbre DosCoronas.exe. Crea una cuenta y juega.`r`nSi no conecta, revisa la direccion del servidor en el archivo .env (junto al .exe).`r`n"
  [System.IO.File]::WriteAllText((Join-Path $salida "LEEME.txt"), $leeme, (New-Object System.Text.UTF8Encoding $false))
  "{0}: {1:N1} MB (servidor: {2})" -f $salida, ((Get-ChildItem $salida -Recurse | Measure-Object Length -Sum).Sum / 1MB), $(if ($Servidor) { $Servidor } else { "127.0.0.1" })
}
Copy-Item (Join-Path $raiz "servidor\.env.example") (Join-Path $dist "servidor.env.example") -Force
