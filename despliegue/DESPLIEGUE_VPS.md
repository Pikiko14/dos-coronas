# Despliegue del servidor en el VPS (beta)

Registro de cómo se montó y cómo se opera el servidor de **Dos Coronas** en el VPS Linux de la beta. Fecha del primer
despliegue: **14-oct-2026**. El desarrollo sigue siendo en Windows; el VPS solo aloja el servidor y su base de datos.

> **Secretos:** este documento NO lleva contraseñas ni la IP del servidor (el repositorio puede ser visible). Donde
> aparece `IP_DEL_VPS` pon la IP real. La clave de PostgreSQL vive solo en `/opt/doscoronas/.env` del VPS.

## 1. Arquitectura

```
 Jugadores (cliente de Windows, DosCoronas.exe)
        │  TCP 30555 (sin cifrar)
        ▼
 VPS Ubuntu 22.04 ── systemd: doscoronas.service ── love servidor.love ──► PostgreSQL (solo 127.0.0.1)
        │                                                   │
        └─ ufw: solo SSH y 30555/tcp                        └─ copias diarias: /var/backups/doscoronas
```

- El servidor es el mismo código que en desarrollo, empaquetado en `servidor.love` (lleva `compartido/` dentro) y
  ejecutado con **LÖVE 11.5 sin ventana** (`servidor/conf.lua` desactiva ventana, gráficos y sonido).
- Guarda cuentas y personajes en **PostgreSQL** (`DOSCORONAS_ALMACEN=postgres`: si la base no responde, avisa en lugar de
  caer al archivo local). El servidor crea las tablas solo la primera vez.
- Un único puerto de juego: **30555/tcp**.

## 2. Qué se cambió en el código para Linux

Antes la red y el cliente de PostgreSQL abrían sockets con Winsock (`ws2_32`), solo Windows. Ahora:

| Archivo | Cambio |
| --- | --- |
| `compartido/infraestructura/sockets.lua` (nuevo) | Capa de sockets no bloqueantes con dos implementaciones por FFI: Winsock en Windows y la libc en Linux (`poll`, `MSG_NOSIGNAL`, `SO_REUSEADDR`). Elige según `ffi.os`. |
| `compartido/infraestructura/red.lua` | Usa la capa anterior (servidor y cliente del juego). |
| `servidor/src/infraestructura/persistencia/pg.lua` | El cliente de PostgreSQL usa la misma capa. |
| `compartido/infraestructura/log.lua` | Los registros van junto a `servidor.love` (no dentro del archivo) y el `mkdir` solo se usa en Windows. |
| `servidor/src/consola.lua` | Avisa si la clave de PostgreSQL es corta o está vacía. |

El desarrollo en Windows no cambia. La prueba `despliegue/ubuntu/prueba_red` (`love despliegue/ubuntu/prueba_red`) valida la
red en el sistema donde se ejecute: servidor y cliente, un mensaje de 200 KB, detección del cierre y puerto ocupado.

## 3. Requisitos del VPS

- Ubuntu 22.04 o 24.04 de 64 bits, root por SSH, IPv4 pública.
- Mínimo razonable: 2 vCPU, 2 GB de RAM y 20 GB de disco (el servidor simula el mundo en un solo hilo: pesa más la
  velocidad del núcleo que cuántos haya). La beta actual usa 2 vCPU, 3,8 GB y 39 GB.
- Entrada TCP **30555** abierta también en el firewall/panel del proveedor (aparte de `ufw`).

## 4. Montaje paso a paso

### 4.1 Acceso por clave SSH (una vez, desde tu PC con Windows, en PowerShell)

```powershell
if (!(Test-Path $env:USERPROFILE\.ssh\id_ed25519)) { ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\id_ed25519 -N '""' }
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh root@IP_DEL_VPS "umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys; echo clave_guardada"
ssh root@IP_DEL_VPS "echo funciona"      # debe responder sin pedir contraseña
```

Comprueba la huella del servidor la primera vez (`yes` solo si coincide con la que muestra la consola del proveedor:
`ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`). Si SSH avisa de que la huella cambió para una IP que ya conocías,
no desactives la comprobación: borra solo esa entrada con `ssh-keygen -R IP_DEL_VPS` cuando sepas que el servidor se reinstaló.

### 4.2 Instalación (una vez)

```powershell
tar -czf - -C despliegue/ubuntu . | ssh root@IP_DEL_VPS "mkdir -p /root/despliegue && tar -xzf - -C /root/despliegue && sed -i 's/\r$//' /root/despliegue/*.sh /root/despliegue/*.service && chmod +x /root/despliegue/*.sh"
ssh root@IP_DEL_VPS "cd /root/despliegue && bash instalar.sh"
```

`instalar.sh` es idempotente (se puede repetir) y hace:

1. Instala LÖVE 11.5 (PPA `bartbes/love-stable`), PostgreSQL, `ufw`, `chrony`, `openssl`, `rsync`, `unzip`.
2. Crea el usuario de sistema `doscoronas` y las carpetas (`/opt/doscoronas`, `/var/lib/doscoronas`, `/var/backups/doscoronas`).
3. PostgreSQL: rol y base `doscoronas` con una **clave aleatoria de 48 caracteres**; claves guardadas con SCRAM-SHA-256;
   escucha solo en `127.0.0.1`; regla `pg_hba` con autenticación `password` solo desde `127.0.0.1` y solo para esa base
   (el cliente del juego no soporta md5/scram). Si ya hay `.env`, reutiliza su clave para no desincronizarse.
4. Crea `/opt/doscoronas/.env` (permisos 600) desde `env.beta.example` con el puerto y la clave.
5. Instala el servicio `doscoronas.service` y la copia diaria (cron 03:30).
6. Firewall `ufw`: solo el puerto SSH real y 30555/tcp. Si detecta cPanel/WHM o CSF **no toca el firewall** y avisa.
7. Activa `chrony` (reloj sincronizado).

### 4.3 Subir el servidor y arrancar

Desde tu PC (construye `dist\servidor.love`, lo sube, reinicia el servicio):

```powershell
.\despliegue\ubuntu\desplegar.ps1 -Servidor IP_DEL_VPS
```

Si solo quieres empaquetar sin el cliente de Windows (lo que se hizo en el primer despliegue), `servidor.love` es un zip
de `servidor/` + `compartido/` (sin `.env`, logs, capturas ni `cuentas.json`), instalado en `/opt/doscoronas/servidor.love`
con propietario `doscoronas`. Luego:

```bash
systemctl start doscoronas
```

### 4.4 Cliente para los jugadores

```powershell
.\construir.ps1 -Servidor "IP_O_DOMINIO" -Puerto 30555
```

Genera `dist\DosCoronas-Windows` apuntando a ese servidor. La dirección va **dentro del paquete** (`src/infraestructura/destino.lua`,
que escribe `construir.ps1`): los jugadores no reciben ningún `.env` suelto. No es un secreto (cualquier cliente puede verla en
la red), así que la protección real es el firewall y los límites del servidor; con un dominio podrás cambiar de IP sin
repartir otro cliente. Si el juego de `dist\` está abierto, `construir.ps1` avisa antes de borrar nada.

## 5. Cómo comprobar que está encendido

```powershell
Test-NetConnection IP_DEL_VPS -Port 30555                     # TcpTestSucceeded : True = responde desde fuera
ssh root@IP_DEL_VPS "systemctl status doscoronas --no-pager"   # active (running)
ssh root@IP_DEL_VPS "journalctl -u doscoronas -f"              # registros en vivo
```

Los registros del juego están en `/opt/doscoronas/log.txt` (y `error_log.txt` si hay un fallo). La prueba definitiva es
entrar con el cliente. Si el proceso cae, systemd lo relanza a los 5 s y también arranca con el VPS.

## 6. Operación diaria

| Tarea | Cómo |
| --- | --- |
| Actualizar el servidor | `.\despliegue\ubuntu\desplegar.ps1 -Servidor IP_DEL_VPS` (no toca el `.env` ni la base). |
| Actualizar a los jugadores | `.\despliegue\ubuntu\publicar_parche.ps1 -Servidor IP_DEL_VPS -Version "beta 0.9.9"` (ver sección 7). |
| Reiniciar / parar | `systemctl restart doscoronas` / `systemctl stop doscoronas` (al parar guarda a todos los jugadores). |
| Cambiar ajustes del juego | Editar `/opt/doscoronas/.env` y reiniciar. Hay plantilla comentada en `despliegue/ubuntu/env.beta.example`. |
| Zona horaria de los eventos | `timedatectl set-timezone America/Bogota` (los eventos usan la hora del servidor; ahora UTC). |
| Entrar a la base | `ssh root@IP_DEL_VPS`, luego `cd /tmp; sudo -u postgres psql doscoronas` (sin clave, como administrador). |
| Dar rol GM / CM | `UPDATE cuentas SET rol='gm' WHERE usuario='...';` (o `cm`; `NULL` lo quita). Surte efecto al volver a entrar. |
| Copia de seguridad a mano | `sudo doscoronas-respaldo` → `/var/backups/doscoronas/doscoronas-FECHA.dump` |
| Restaurar una copia | Parar el servicio, `sudo -u postgres dropdb doscoronas && sudo -u postgres createdb -O doscoronas doscoronas`, `sudo -u postgres pg_restore -d doscoronas ARCHIVO.dump`, arrancar. |
| Ver la clave de PostgreSQL | `ssh root@IP_DEL_VPS "grep DOSCORONAS_PG_PASSWORD /opt/doscoronas/.env"` (no la pegues en chats ni tickets). |

Cambiar la clave de PostgreSQL (siempre las dos cosas a la vez, o el servidor no podrá entrar):

```bash
NUEVA=$(openssl rand -hex 24)
sudo -u postgres psql -c "ALTER ROLE doscoronas PASSWORD '$NUEVA'"
sed -i "s|^DOSCORONAS_PG_PASSWORD=.*|DOSCORONAS_PG_PASSWORD=$NUEVA|" /opt/doscoronas/.env
systemctl restart doscoronas
```

Las copias diarias (03:30, 14 días) están **en el mismo VPS**: copia `/var/backups/doscoronas` fuera de vez en cuando
(`scp`/`rsync` a otro sitio) para sobrevivir a la pérdida del servidor.

## 7. Estado de la beta (14-oct-2026)

- VPS `4VJRnGMv`: Ubuntu 22.04.5, **2 vCPU, 3,8 GB de RAM, 39 GB de disco**, sin otros servicios.
- Servicio `doscoronas` activo y habilitado al arranque; escucha en `0.0.0.0:30555`.
- Firewall `ufw` activo: 22/tcp y 30555/tcp.
- PostgreSQL local, esquema creado por el servidor; copia diaria probada.
- Pruebas hechas: red en Linux (`prueba_red`, 3/3), bot del juego desde Windows contra el VPS (registro, movimiento,
  habilidad, guardado y reconexión: OK). La cuenta de prueba se borró; la base quedó vacía.

### Hallazgos del proveedor

- El correo de alta trae dos IP: la del **VPS** y la del **servidor anfitrión (Proxmox)**. Solo se usa la del VPS (la que
  responde con el nombre `4VJRnGMv`). La del anfitrión no se toca.
- El plan que se vio en la tienda (4 vCPU / 8 GB / 2×200 GB) no coincide con la máquina entregada (2 vCPU / 3,8 GB / 39 GB).
  Conviene reclamarlo al proveedor.

## 8. Seguridad

- El tráfico del juego va por **TCP sin cifrar** (incluidas las claves al entrar). Aceptable para una beta cerrada; antes de
  abrirlo al público hay que envolverlo en TLS o un túnel.
- PostgreSQL solo escucha en `127.0.0.1`; la autenticación `password` viaja por el bucle local, que no sale del VPS.
- Acceso al VPS **solo por clave SSH**. Cambiar la contraseña de root dada por el proveedor y, cuando todo funcione,
  desactivar el acceso por contraseña (`PasswordAuthentication no` en `/etc/ssh/sshd_config`, luego `systemctl reload ssh`).
- Pendiente recomendable: `fail2ban`, límite de conexiones por IP, y protección anti-DDoS del proveedor.
- Los volcados de copia llevan hashes de claves de jugadores: solo root los lee (`chmod 700`).

## 9. Problemas encontrados y cómo se resolvieron

| Problema | Causa | Solución |
| --- | --- | --- |
| `Host key verification failed` | Se usó una IP que antes era de otra máquina (huella distinta en `known_hosts`). | Confirmar a qué servidor pertenece cada IP; `ssh-keygen -R` solo de la entrada afectada. |
| Comandos de PowerShell pegados dentro del VPS | Se ejecutaron en la ventana equivocada. | Ejecutarlos en PowerShell de Windows (prompt `PS C:\...`). |
| La clave SSH no se autorizaba | El primer envío de la clave no llegó a `authorized_keys`. | Reenviarla con `umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys`. |
| `instalar.sh` terminaba con código 141 | `awk '... exit'` cortaba la tubería de `sshd -T` y `pipefail` lo trataba como error (SIGPIPE). | `awk` ahora lee todo y el script es idempotente. |
| `could not change directory to "/root"` | `sudo -u postgres` hereda el directorio actual. | Los scripts hacen `cd /tmp`. |
| El registro del servidor no se podía escribir | `Log.carpeta()` devolvía `servidor.love` (un archivo). | Ahora usa la carpeta que lo contiene. |

## 10. Archivos

`despliegue/ubuntu/`: `instalar.sh`, `doscoronas.service`, `respaldo.sh`, `desplegar.ps1`, `env.beta.example`,
`prueba_red/`, `LEEME.md` (resumen corto).

## 7. Actualizaciones del cliente (sin volver a descargar el juego)

El juego lleva dentro la dirección `http://IP/actualizacion/`. Al abrirlo pregunta por `version.txt` (build, nombre, archivo, sha256);
si hay un build más nuevo baja `actualizacion_<build>.zip` (solo código: `juego/src`, `compartido/`, `version.lua`; ~0,3 MB), comprueba el sha256,
lo guarda en su carpeta de datos (`%APPDATA%\doscoronas`) y se reinicia. `main.lua` monta ese zip encima del paquete instalado antes de cargar nada.
Si un parche hace que el juego no llegue a dibujar la primera pantalla, el siguiente arranque lo descarta y vuelve al código instalado.

- **Una sola vez en el VPS:** `cat despliegue/ubuntu/actualizaciones.sh | ssh root@IP "bash -s"` (instala nginx, sirve solo `/actualizacion/` y abre el 80/tcp).
- **Cada vez que cambies código:** `publicar_parche.ps1` sube en 1 el build de `juego/version.lua`, genera el zip y lo sube (primero el zip, al final `version.txt`).
  Conserva los 3 últimos parches. Haz commit de `juego/version.lua` para que los paquetes nuevos nazcan con ese build.
- **No viajan en el parche:** `juego/arte` (imágenes y sonidos, ~80 MB), `main.lua`, `conf.lua` y el destino del servidor. Si cambias arte usa `-ConArte`
  (parche de ~80 MB) o publica un paquete nuevo en la web. Un cambio en `main.lua` o `conf.lua` también exige paquete nuevo (por eso `main.lua` es mínimo).
- **Probar en local:** `publicar_parche.ps1 -SinSubir` deja el parche en `dist/parche/`; sírvelo con `python -m http.server 8099` y abre el juego con
  `DOSCORONAS_ACTUALIZACIONES=http://127.0.0.1:8099/`. En desarrollo (`love juego`) el parche no se monta salvo con `DOSCORONAS_PARCHE=1`.
- **Limitación:** va por HTTP sin cifrar (LÖVE no trae HTTPS). El sha256 protege de descargas corruptas, no de alguien que intercepte la conexión y
  cambie a la vez el manifiesto y el zip.
