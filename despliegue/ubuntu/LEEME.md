# Servidor de Dos Coronas en Ubuntu (beta)

Documentación completa del despliegue: [`../DESPLIEGUE_VPS.md`](../DESPLIEGUE_VPS.md).

Esta carpeta es lo que se usa **en el VPS**. El desarrollo sigue siendo en Windows como siempre: la misma base de
código elige sola Winsock (Windows) o la libc (Linux) en `compartido/infraestructura/sockets.lua`.

## Qué hay

| Archivo | Para qué |
| --- | --- |
| `instalar.sh` | Se ejecuta **una vez** como root en el VPS: instala LÖVE 11.5, PostgreSQL (solo local), firewall, `chrony`, el servicio y las copias. |
| `env.beta.example` | Plantilla de `/opt/doscoronas/.env` (la copia el instalador con el puerto y la clave de PostgreSQL). |
| `doscoronas.service` | Servicio systemd (`doscoronas`): arranca solo, se reinicia si cae, usuario sin privilegios. |
| `desplegar.ps1` | En tu PC: construye `dist\servidor.love`, lo sube al VPS y reinicia el servicio. |
| `respaldo.sh` | Copia diaria de la base de datos (`/var/backups/doscoronas`, 14 días). |
| `prueba_red/` | Prueba de la red en el sistema donde se ejecute (`love despliegue/ubuntu/prueba_red`). |

## Primera vez

1. En el VPS (Ubuntu 22.04/24.04), como root: copia esta carpeta y ejecuta `bash instalar.sh`.
2. En tu PC: `.\despliegue\ubuntu\desplegar.ps1 -Servidor IP_DEL_VPS`.
3. En el VPS: `systemctl start doscoronas` y `journalctl -u doscoronas -f`.
4. Para los jugadores: `.\construir.ps1 -Servidor "IP_O_DOMINIO" -Puerto 30555` genera el cliente de Windows apuntando
   a ese servidor.

## Día a día

- Actualizar el servidor: `.\despliegue\ubuntu\desplegar.ps1 -Servidor IP_DEL_VPS` (no toca el `.env` ni la base).
- Logs: `journalctl -u doscoronas -f`. Estado: `systemctl status doscoronas`.
- Ajustes del juego: editar `/opt/doscoronas/.env` y `systemctl restart doscoronas`.
- Roles de GM/CM: `UPDATE cuentas SET rol='gm' WHERE usuario='...';` (con `sudo -u postgres psql doscoronas`).
- Copia a mano: `sudo doscoronas-respaldo`. **Copia también `/var/backups/doscoronas` fuera del VPS.**

## Seguridad (beta)

- El tráfico del juego va por TCP **sin cifrar** (incluidas las claves al entrar). Vale para una beta cerrada; antes de
  abrirlo al público hay que envolverlo en TLS o un túnel.
- PostgreSQL solo escucha en `127.0.0.1`. El firewall deja entrar únicamente SSH y el puerto del juego (30555/tcp).
- Usa acceso SSH por clave y desactiva la contraseña de root (`PasswordAuthentication no`).
