#!/usr/bin/env bash
# Instalación del servidor de Dos Coronas en un VPS Ubuntu 22.04 / 24.04 (beta).
# Ejecutar UNA vez como root en el VPS recién creado:
#     sudo bash instalar.sh
# Deja instalados LÖVE 11.5, PostgreSQL (solo en 127.0.0.1), el firewall (solo SSH y el puerto del juego; si el VPS
# trae cPanel/WHM o CSF no lo toca y te dice qué puerto abrir), el
# servicio systemd "doscoronas" y la copia de seguridad diaria. Después se sube el juego con desplegar.ps1
# (o copiando dist/servidor.love a /opt/doscoronas/) y se arranca con:  systemctl start doscoronas
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then echo "Ejecuta este script como root (sudo bash instalar.sh)."; exit 1; fi

PUERTO="${DOSCORONAS_PUERTO:-30555}"
RAIZ=/opt/doscoronas
USUARIO=doscoronas
DB=doscoronas
AQUI="$(cd "$(dirname "$0")" && pwd)"
cd /tmp   # sudo -u postgres no puede entrar en /root

echo "==> Paquetes"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y software-properties-common ca-certificates curl ufw chrony postgresql postgresql-contrib openssl rsync unzip
# LÖVE 11.5 (el servidor corre sin ventana: no hace falta pantalla)
add-apt-repository -y ppa:bartbes/love-stable
apt-get update -y
apt-get install -y love
love --version || true

echo "==> Usuario y carpetas"
id "$USUARIO" >/dev/null 2>&1 || useradd --system --create-home --home-dir /var/lib/doscoronas --shell /usr/sbin/nologin "$USUARIO"
mkdir -p "$RAIZ" /var/backups/doscoronas
chown -R "$USUARIO":"$USUARIO" "$RAIZ" /var/lib/doscoronas
chmod 700 /var/backups/doscoronas   # solo root (los volcados llevan las claves con hash de los jugadores)

echo "==> PostgreSQL (solo local; el cliente del servidor usa autenticación 'password')"
# Clave fuerte: 24 bytes aleatorios del sistema (48 caracteres hexadecimales, 192 bits). Solo letras y números, para
# que no dé problemas en el .env ni en el SQL. Se puede fijar otra con DOSCORONAS_PG_CLAVE=... (mínimo 24 caracteres).
# Si ya hay un .env con clave (reinstalación), se reutiliza para no desincronizarlo de la base de datos.
PGPASS="${DOSCORONAS_PG_CLAVE:-}"
if [ -z "$PGPASS" ] && [ -f "$RAIZ/.env" ]; then
  PGPASS="$(sed -n 's/^DOSCORONAS_PG_PASSWORD=//p' "$RAIZ/.env" | head -n1 || true)"
fi
PGPASS="${PGPASS:-$(openssl rand -hex 24)}"
if [ "${#PGPASS}" -lt 24 ]; then echo "La clave de PostgreSQL debe tener al menos 24 caracteres."; exit 1; fi
case "$PGPASS" in *[!A-Za-z0-9._-]*) echo "La clave solo puede llevar letras, números, punto, guion y guion bajo."; exit 1;; esac
# guardar las claves con SCRAM-SHA-256 y escuchar solo en el propio servidor
sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER SYSTEM SET password_encryption = 'scram-sha-256'" -c "ALTER SYSTEM SET listen_addresses = '127.0.0.1'"
systemctl restart postgresql
sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$USUARIO') THEN
    CREATE ROLE $USUARIO LOGIN PASSWORD '$PGPASS';
  ELSE
    ALTER ROLE $USUARIO PASSWORD '$PGPASS';
  END IF;
END \$\$;
SQL
sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB'" | grep -q 1 || sudo -u postgres createdb -O "$USUARIO" "$DB"
HBA="$(sudo -u postgres psql -tAc 'SHOW hba_file')"
if ! grep -q "doscoronas-servidor" "$HBA"; then
  # el cliente del juego no soporta scram/md5: se acepta 'password' solo desde 127.0.0.1 y solo para esta base
  sed -i "0,/^host/s//# doscoronas-servidor\nhost    $DB    $USUARIO    127.0.0.1\/32    password\nhost/" "$HBA"
fi
PGPUERTO="$(sudo -u postgres psql -tAc 'SHOW port')"
systemctl reload postgresql

echo "==> Configuración del servidor ($RAIZ/.env)"
if [ ! -f "$RAIZ/.env" ]; then
  cp "$AQUI/env.beta.example" "$RAIZ/.env"
  sed -i "s|^DOSCORONAS_PUERTO=.*|DOSCORONAS_PUERTO=$PUERTO|" "$RAIZ/.env"
  sed -i "s|^DOSCORONAS_PG_PORT=.*|DOSCORONAS_PG_PORT=$PGPUERTO|" "$RAIZ/.env"
  sed -i "s|^DOSCORONAS_PG_PASSWORD=.*|DOSCORONAS_PG_PASSWORD=$PGPASS|" "$RAIZ/.env"
  chown "$USUARIO":"$USUARIO" "$RAIZ/.env"
  chmod 600 "$RAIZ/.env"
else
  echo "   ya existe $RAIZ/.env: no se toca. La clave nueva de PostgreSQL está en $RAIZ/.pg_clave_nueva (ponla en DOSCORONAS_PG_PASSWORD y borra ese archivo)"
  umask 077; echo "$PGPASS" > "$RAIZ/.pg_clave_nueva"; chown "$USUARIO":"$USUARIO" "$RAIZ/.pg_clave_nueva"
fi

echo "==> Servicio systemd y copias de seguridad"
install -m 644 "$AQUI/doscoronas.service" /etc/systemd/system/doscoronas.service
install -m 755 "$AQUI/respaldo.sh" /usr/local/bin/doscoronas-respaldo
cat > /etc/cron.d/doscoronas-respaldo <<CRON
# copia de seguridad diaria de la base de datos del juego (03:30), se conservan 14 días
30 3 * * * root /usr/local/bin/doscoronas-respaldo
CRON
systemctl daemon-reload
systemctl enable doscoronas

echo "==> Firewall"
# Puerto real de SSH (por si no es el 22) para no dejarte fuera al activar el firewall
# (sin "exit" en awk: con pipefail, cortar la tubería haría fallar el script con SIGPIPE)
SSHPUERTO="$(sshd -T 2>/dev/null | awk '/^port /{p=$2} END{print p}')"
SSHPUERTO="${SSHPUERTO:-22}"
if [ -d /usr/local/cpanel ] || command -v csf >/dev/null 2>&1; then
  # cPanel/WHM gestiona su propio firewall (CSF u otro): no se mezcla con ufw
  echo "   Se detectó cPanel/WHM o CSF: NO se toca el firewall. Abre tú el puerto $PUERTO/tcp (entrada):"
  echo "   - en WHM > ConfigServer Security & Firewall (o en el firewall del panel de tu proveedor), y"
  echo "   - añade $PUERTO a TCP_IN en /etc/csf/csf.conf si usas CSF, y reinicia con: csf -r"
else
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow "$SSHPUERTO"/tcp
  ufw allow "$PUERTO"/tcp
  ufw --force enable
fi

systemctl enable --now chrony

echo
echo "Listo. Pasos que quedan:"
echo "  1) Sube el servidor:  desde tu PC, despliegue\\ubuntu\\desplegar.ps1 -Servidor IP_DEL_VPS   (o copia dist/servidor.love a $RAIZ/)"
echo "  2) Revisa $RAIZ/.env (zona horaria, administradores, eventos)."
echo "  3) Arranca:           systemctl start doscoronas   y mira   journalctl -u doscoronas -f"
echo "  Zona horaria actual: $(timedatectl show -p Timezone --value)  (cámbiala con: timedatectl set-timezone America/Bogota)"
