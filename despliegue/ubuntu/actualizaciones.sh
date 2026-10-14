#!/usr/bin/env bash
# Prepara en el VPS el servidor HTTP de las actualizaciones del juego (nginx, puerto 80, solo /actualizacion/).
# Idempotente: se puede repetir. No toca el servidor del juego ni la base de datos.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Ejecuta como root."; exit 1; }

DIR=/var/www/doscoronas/actualizacion
mkdir -p "$DIR"
chmod 755 /var/www /var/www/doscoronas "$DIR"

if ! command -v nginx >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y nginx
fi

cat > /etc/nginx/sites-available/doscoronas-actualizaciones <<'CONF'
# Parches de actualización del cliente de Dos Coronas: archivos estáticos, nada más.
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    server_tokens off;

    location = /actualizacion/version.txt {
        root /var/www/doscoronas;
        default_type text/plain;
        add_header Cache-Control "no-cache";
    }
    location ~ ^/actualizacion/actualizacion_[0-9]+\.zip$ {
        root /var/www/doscoronas;
        default_type application/zip;
    }
    location / { return 404; }
}
CONF
ln -sf /etc/nginx/sites-available/doscoronas-actualizaciones /etc/nginx/sites-enabled/doscoronas-actualizaciones
rm -f /etc/nginx/sites-enabled/default

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow 80/tcp >/dev/null
  echo "ufw: puerto 80/tcp permitido"
fi

nginx -t
systemctl enable nginx >/dev/null 2>&1 || true
systemctl reload nginx 2>/dev/null || systemctl restart nginx
echo "Listo: http://<IP>/actualizacion/version.txt (carpeta $DIR)."
