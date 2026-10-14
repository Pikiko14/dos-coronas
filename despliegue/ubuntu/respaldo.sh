#!/usr/bin/env bash
# Copia de seguridad de la base de datos del juego. La lanza cron cada día (ver instalar.sh); también se puede
# ejecutar a mano:  sudo doscoronas-respaldo
# Deja los volcados en /var/backups/doscoronas y borra los de más de 14 días. IMPORTANTE: están en el mismo VPS;
# copia esa carpeta fuera de vez en cuando (scp/rsync a otro sitio) para sobrevivir a la pérdida del servidor.
set -euo pipefail
umask 077          # los volcados llevan las claves (con hash) de los jugadores: solo root los lee
cd /tmp           # sudo -u postgres no puede entrar en /root
DESTINO=/var/backups/doscoronas
mkdir -p "$DESTINO"
FECHA="$(date +%Y%m%d-%H%M%S)"
sudo -u postgres pg_dump --format=custom doscoronas > "$DESTINO/doscoronas-$FECHA.dump"
# la carpeta de guardado del servidor (por si se usó el almacén de archivo)
if [ -d /var/lib/doscoronas/.local/share/love/doscoronas ]; then
  tar -czf "$DESTINO/archivos-$FECHA.tar.gz" -C /var/lib/doscoronas/.local/share/love doscoronas
fi
find "$DESTINO" -type f -mtime +14 -delete
echo "Copia hecha: $DESTINO/doscoronas-$FECHA.dump"
