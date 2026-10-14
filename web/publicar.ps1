# Prepara la descarga de la web: comprime dist\DosCoronas-Windows en web\descargas\DosCoronas-Windows.zip y escribe
# web\descargas\version.json (versión, fecha, tamaño y huella SHA-256) que la página lee para mostrar los datos.
#   .\web\publicar.ps1                          solo prepara los archivos de web\descargas
#   .\web\publicar.ps1 -Construir -Servidor "IP_O_DOMINIO"   antes ejecuta construir.ps1 para regenerar dist\
#   .\web\publicar.ps1 -Version "0.9.1 beta"    cambia el texto de la versión (por defecto, fecha de hoy)
#   .\web\publicar.ps1 -Origen dist\_web\DosCoronas-Windows   comprime otra carpeta (p. ej. si el juego de dist está abierto)
#   .\web\publicar.ps1 -Subir root@IP_DEL_VPS   además sube toda la carpeta web\ al VPS (/var/www/doscoronas)
param(
  [switch]$Construir,
  [string]$Servidor = "",
  [int]$Puerto = 30555,
  [string]$Version = "",
  [string]$Subir = "",
  [string]$Origen = ""      # carpeta del juego a comprimir (por defecto dist\DosCoronas-Windows)
)
$ErrorActionPreference = "Stop"
$raiz = Resolve-Path (Join-Path $PSScriptRoot "..")
$dist = if ($Origen) { (Resolve-Path $Origen).Path } else { Join-Path $raiz "dist\DosCoronas-Windows" }
$salida = Join-Path $PSScriptRoot "descargas"
New-Item -ItemType Directory -Force $salida | Out-Null

if ($Construir) {
  if (-not $Servidor) { throw "Con -Construir indica -Servidor (la IP o el dominio al que se conectará el juego)." }
  & (Join-Path $raiz "construir.ps1") -Servidor $Servidor -Puerto $Puerto
}
if (-not (Test-Path (Join-Path $dist "DosCoronas.exe"))) { throw "No existe $dist\DosCoronas.exe: ejecuta construir.ps1 primero (o usa -Construir)." }

$zip = Join-Path $salida "DosCoronas-Windows.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
"Comprimiendo $dist ..."
Compress-Archive -Path (Join-Path $dist "*") -DestinationPath $zip -CompressionLevel Optimal
$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
$mb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
$ahora = Get-Date
$meses = @("enero","febrero","marzo","abril","mayo","junio","julio","agosto","septiembre","octubre","noviembre","diciembre")
if (-not $Version) { $Version = "beta " + $ahora.ToString("yyyy.MM.dd") }
$info = [ordered]@{
  version = $Version
  fecha = "{0} de {1} de {2}" -f $ahora.Day, $meses[$ahora.Month - 1], $ahora.Year
  tamano = "$mb MB".Replace(",", ".")
  sha256 = $hash
  archivo = "DosCoronas-Windows.zip"
}
[System.IO.File]::WriteAllText((Join-Path $salida "version.json"), ($info | ConvertTo-Json), (New-Object System.Text.UTF8Encoding $false))
"Listo: $zip ($mb MB)`nSHA-256: $hash"

if ($Subir) {
  "Subiendo la web a $Subir ..."
  ssh $Subir "mkdir -p /var/www/doscoronas"
  scp -r (Join-Path $PSScriptRoot "index.html") (Join-Path $PSScriptRoot "guia.html") (Join-Path $PSScriptRoot "css") (Join-Path $PSScriptRoot "js") (Join-Path $PSScriptRoot "img") (Join-Path $PSScriptRoot "descargas") "${Subir}:/var/www/doscoronas/"
  "Subida. Revisa que nginx sirva /var/www/doscoronas (ver web\LEEME.md)."
}
