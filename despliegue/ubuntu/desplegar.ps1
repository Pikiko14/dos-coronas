# Sube el servidor al VPS Ubuntu y lo reinicia. Se ejecuta en tu PC con Windows (usa el OpenSSH de Windows).
#   .\despliegue\ubuntu\desplegar.ps1 -Servidor 203.0.113.10 [-Usuario root] [-Puerto 22] [-SinConstruir]
# Antes (la primera vez) hay que haber ejecutado instalar.sh en el VPS. Hace: construir.ps1 (dist\servidor.love),
# copia el .love a /opt/doscoronas y reinicia el servicio. NO toca el .env ni la base de datos del VPS.
param(
  [Parameter(Mandatory = $true)][string]$Servidor,
  [string]$Usuario = "root",
  [int]$Puerto = 22,
  [switch]$SinConstruir
)
$ErrorActionPreference = "Stop"
$raiz = Resolve-Path (Join-Path $PSScriptRoot "..\..")

if (-not $SinConstruir) {
  & (Join-Path $raiz "construir.ps1")
}
$love = Join-Path $raiz "dist\servidor.love"
if (-not (Test-Path $love)) { throw "No existe $love: ejecuta construir.ps1 primero." }

$destino = "$Usuario@$Servidor"
"Subiendo servidor.love a $destino ..."
scp -P $Puerto $love "${destino}:/tmp/servidor.love"
ssh -p $Puerto $destino "set -e; install -o doscoronas -g doscoronas -m 644 /tmp/servidor.love /opt/doscoronas/servidor.love; rm -f /tmp/servidor.love; systemctl restart doscoronas; sleep 3; systemctl --no-pager --lines=15 status doscoronas"
"Listo. Logs en vivo:  ssh $destino journalctl -u doscoronas -f"
