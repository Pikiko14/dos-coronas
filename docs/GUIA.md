# Dos Coronas — guía de cómo funciona todo

MMORPG 2.5D en Lua para LÖVE 11.5: dos facciones (**Albor** y **Umbra**), seis oficios de combate, ciudades, mazmorras, eventos de guerra,
oficios de trabajo (jobs), monturas, Item Mall con addons, comercio entre jugadores y un servidor propio en un VPS Ubuntu.
Esta guía junta lo que está repartido por el repositorio. Para detalles finos de un tema hay documentos específicos:

| Tema | Documento |
| --- | --- |
| Primeros pasos y variables `.env` | `LEEME.txt` |
| Instalar y operar el servidor en el VPS (incluye actualizaciones del cliente) | `despliegue/DESPLIEGUE_VPS.md`, `despliegue/ubuntu/LEEME.md` |
| Web de presentación, guía de juego y descarga | `web/LEEME.md` |
| Historial de decisiones y fases | `PLAN.md` |

---

## 1. Mapa del repositorio

```
compartido/     Código que usan el servidor Y el cliente (reglas del mundo, datos XML, protocolo, sockets)
  dominio/      mundo.lua (el motor: combate, movimiento, eventos...), mapa.lua (generación), mazmorras.lua, mall.lua, ...
  datos/        Configuración en XML: clases, habilidades, monstruos, items, ciudades, mall, mazmorras, misiones...
  infraestructura/  sockets.lua (FFI Windows/Linux), red.lua, log.lua, env.lua
  protocolo.lua Contrato de mensajes cliente <-> servidor
servidor/       Servidor sin ventana (consola): cuentas, mundo, guardado
  src/aplicacion/servicio_servidor.lua   Bucle de red, sesiones, inactividad, guardado
  src/dominio/autoridad.lua              Valida cada acción que pide un cliente
  src/infraestructura/persistencia/      PostgreSQL (postgres.lua/pg.lua) o archivo (archivo.lua)
juego/          Cliente: ventana, arte, sonido, interfaz
  main.lua      Mínimo: monta el parche de actualización y carga src/principal.lua
  src/principal.lua       Callbacks de LÖVE (love.load/draw/mousepressed...)
  src/presentacion/       app.lua (estados), interfaz.lua (HUD y paneles), entrada.lua (ratón/teclado), estados/, render/
  src/infraestructura/    config.lua (destino), actualizacion.lua (parches)
  src/pruebas/            Pruebas del cliente, modos --foto/--bot/--web
  version.lua   Build y nombre de la versión instalada
  arte/         Imágenes y sonidos (80 MB, no viajan en los parches)
herramientas/   generar_clases (pixel art), generar_hechizos, volcar_configuracion
despliegue/     Scripts del VPS Ubuntu (instalar, desplegar, parches, nginx, respaldos)
web/            Página web (HTML/CSS/JS) y publicar.ps1; se publica en el repo dos-coronas-web (GitHub Pages)
recursos/       Icono del juego (corona) y PonerIcono.ps1
construir.ps1   Empaqueta dist/servidor.love, dist/juego.love y dist/DosCoronas-Windows
```

Regla de oro: **las reglas viven en `compartido/` y el servidor es la autoridad.** El cliente dibuja y pide acciones; el servidor decide.

---

## 2. Ejecutar en desarrollo (Windows)

Hace falta LÖVE 11.5 (los `.bat` lo buscan en el PATH o en `..\love\love.exe`).

| Qué | Comando |
| --- | --- |
| Servidor | `servidor.bat` (o `love servidor`) |
| Cliente | `juego.bat` (o `love juego`) — se conecta al servidor de `juego\.env` o al local |
| Parar el servidor | `detener.bat` |
| Pruebas del servidor | `lovec servidor --test` (esperado: sin fallos; hoy 2 de balance dependen de los valores de `habilidades.xml`/`clases.xml`) |
| Pruebas del cliente | `lovec juego --test` (termina en `OK`) |
| Capturas de pantalla de los menús y la ciudad | `lovec juego --foto` → `juego/capturas/` |
| Exportar sprites para la web y la hoja de addons | `lovec juego --web` → `juego/capturas/web/` (`addons_vista.png`) |

`lovec.exe` es la versión con consola. Antes de lanzar pruebas cierra los `lovec.exe` abiertos (`taskkill /F /IM lovec.exe`).
El servidor en desarrollo usa archivo (`cuentas.json`) si no hay PostgreSQL; en el VPS usa PostgreSQL.

---

## 3. Arquitectura cliente / servidor

### 3.1 Red
- TCP propio, un mensaje JSON por línea (`compartido/protocolo.lua`). Los sockets van por FFI (`sockets.lua`): Windows (ws2_32) y Linux (libc).
- **Cliente → servidor:** `cuenta` (registrar / entrar / crear personaje), `hola` (entrar al mundo con un personaje), `act` (una acción de juego).
- **Servidor → cliente:** `sesion`, `ok`, `snap` (foto del mundo, ~15 por segundo), `panel`, `no`.
- El servidor manda a cada cliente solo lo cercano y lo que le toca: entidades próximas, su propio estado (`tu`), mensajes de chat desde que entró.
- Sin cifrar (TCP plano). Las contraseñas de las cuentas se guardan con hash en la base.

### 3.2 Autoridad
`servidor/src/dominio/autoridad.lua` valida y limpia cada acción (rangos, tipos, límites) antes de que `Mundo:accion` la ejecute.
El cliente nunca decide daño, loot ni posiciones. Hay límite de mensajes por segundo por conexión y **desconexión por inactividad a los 60 s**
(`DOSCORONAS_INACTIVIDAD_SEG`, 0 = nunca; avisa 10 s antes).

### 3.3 Mundo
`compartido/dominio/mundo.lua` es el motor: entidades (jugadores, monstruos, NPC, proyectiles), combate, estados, loot, misiones, grupos, gremios,
comercio, subastas, eventos programados, mazmorras, monturas, mascotas, esbirros, barcos... `Mundo:foto(id)` arma la foto que se envía.
El mapa del mundo (`mapa.lua`, `continentes.lua`) se **genera con semilla fija** al arrancar; cliente y servidor generan lo mismo, por eso no se envía el terreno.

### 3.4 Persistencia
`persistencia/postgres.lua` guarda cuentas y personajes (el servidor se guarda: periódicamente, al salir cada jugador y al apagar).
La clave de PostgreSQL es fuerte y vive solo en `/opt/doscoronas/.env` del VPS.

---

## 4. Datos y balance (XML)

Casi todo se cambia **sin tocar código**, en `compartido/datos/*.xml`:

| Archivo | Contenido |
| --- | --- |
| `clases.xml`, `habilidades.xml`, `arbol.xml` | Oficios de combate, poderes (coste, enfriamiento, rango, daño) y árbol de talentos |
| `monstruos.xml`, `biomas.xml`, `esbirros.xml`, `mascotas.xml` | Criaturas, zonas y compañeros |
| `items.xml`, `equipo.xml` | Objetos, pociones, armas y armaduras por escalón |
| `ciudades.xml`, `facciones.xml`, `muebles.xml` | Ciudades, facciones y muebles de casas |
| `mazmorras.xml` | Planes de mazmorras (salas, trampas, jefes) — se generan proceduralmente con semilla |
| `mall.xml` | Item Mall: bonos, objetos (pergaminos, paquetes de polvo), addons y monturas |
| `constantes.xml` | Balance global (XP, daño, crítico, bolsa, respawn, caravanas, gremios, grupos, comercio...) |
| `oficios.xml`, `misiones.xml`, `diaria.xml` | Jobs, encargos y recompensas diarias |

Tras editar un XML basta reiniciar. **Ojo:** las pruebas de balance del servidor comparan resultados concretos (p. ej. DPS del mago vs clérigo); si
cambias números a propósito, actualiza esas pruebas.

---

## 5. Sistemas de juego (cómo se comportan)

- **Combate:** poderes por tecla (1–6), pociones 7 (vida) y 8 (maná) con **enfriamiento individual por poción**, autopoción configurable (R) con umbral.
- **Facciones y PvP:** Albor vs Umbra. Con un oficio (job) activo se ignora la facción; en modo job solo se montan monturas de transporte.
- **Ciudades:** muralla, avenidas, plaza central con estatua, farolas, pozos, **bancos, macetas, setos y flores**, casas, tiendas (clériga = pociones, armero, establo),
  rincones temáticos por ciudad. NPC solo dentro de ciudades.
- **Mazmorras:** generadas por semilla, no lineales, con **trampas**; los monstruos **no reaparecen**; el cofre suelta su botín al suelo y desaparece;
  el loot puede ser de cualquier clase.
- **Eventos:** *Captura del estandarte* y *Batalla de cristales* (mapas temáticos por facción, no lineales; el portador del cristal se ve; aviso en marquesina).
  Premios: 1000 de oro al equipo ganador del estandarte, monedas del mall (5 ganar / 2 perder), polvo arcano, pergaminos.
- **Viajes:** muelles con barqueros y barcos entre continentes; monturas (también de vehículo).
- **Grupos:** invita solo el líder; cualquiera puede salir; se puede cambiar de líder.
- **Chat:** pestañas con iconos; solo ves mensajes desde que te conectas; scroll con rueda/AvPág/RePág.
- **Item Mall** (se paga con Monedas Corona, repartidas con `/admin monedas`):
  - *Objetos:* tarjeta de experiencia, pergaminos de atributos y de forja (+6, +10 seguro).
  - *Forja:* paquetes de **polvo de encantamiento** (x10, x50, x150) que van directo a la bolsa.
  - *Addons:* skins de personaje; se ven en el panel del personaje. 12 en total (2 exclusivos + 10 de clase).
  - *Monturas.*
- **Encantamiento:** en el Maestro de encantos; cuesta oro y polvo arcano (lo sueltan criaturas altas y los eventos).

### Administración dentro del juego
Las cuentas con rol `gm` o `cm` usan `/admin ayuda`. Comandos principales: `mob`, `item`, `oro|xp|nivel|monedas`, `tp`, `traer`, `evento`, `anuncio`,
`kick`, `silenciar`, `ban`/`desban`, `rol`. El CM solo modera (sus baneos duran 72 h como máximo). Dar rol GM a una cuenta en PostgreSQL:

```sql
UPDATE cuentas SET rol='gm' WHERE usuario='nombre';   -- 'cm' o NULL para quitar; surte efecto al volver a entrar
```

---

## 6. Render y arte

- Terreno por casillas (`render/terreno.lua`), objetos del mapa recortados de las láminas del pack (`render/objetos.lua`); el **mobiliario de la plaza**
  (banco, maceta) y los barcos/puertas de mazmorra se dibujan por código (`Objetos.personalizados`).
- Personajes: hojas de 3×4 cuadros de 32×32 (fila 0 frente, 1 izquierda, 2 derecha, 3 espalda). `render/personajes.lua` define skins y clases;
  `render/propias.lua` genera **variantes recoloreadas con shader** (`DISENOS`) y superpone accesorios en capas (`detras`/`delante` por fila y columna).
- **Addons con arma** (hoplita, señor de los huesos): de frente y de lado el arma va en la mano y sobre el cuerpo; **de espaldas va detrás del cuerpo**
  (el personaje la lleva delante) y solo asoma la punta y un trozo del asta; la mano no se ve.
- Herramienta de pixel art: `herramientas/generar_clases` (`lovec herramientas\generar_clases`) crea íconos, personajes y HUD.

---

## 7. Construir, probar y publicar

### 7.1 Empaquetar
`construir.ps1 -Servidor IP -Puerto 30555` genera:
- `dist/servidor.love` — el servidor (con `compartido/`).
- `dist/juego.love` — el cliente (con `compartido/`, 80 MB por el arte).
- `dist/DosCoronas-Windows/` — `DosCoronas.exe` (love.exe con el icono de la corona + `juego.love`) y las DLL de LÖVE.
  La dirección del servidor y de las actualizaciones va **dentro** del paquete (`src/infraestructura/destino.lua`), sin `.env` visible.

### 7.2 Web de descarga
`web/publicar.ps1 -Construir -Servidor IP -Version "beta X.Y.Z"` reconstruye, comprime `DosCoronas-Windows.zip` en `web/descargas/` y escribe `version.json`
(versión, tamaño, sha256). Se publica copiando `web/` al repo **dos-coronas-web** (GitHub Pages) y haciendo push; el zip va en `descargas/`.
Cada zip nuevo pesa ~84 MB en el historial de git; si crece demasiado conviene pasarlos a GitHub Releases.

### 7.3 Actualizar el servidor
`despliegue\ubuntu\desplegar.ps1 -Servidor IP -SinConstruir` sube `dist/servidor.love`, lo instala en `/opt/doscoronas` y reinicia el servicio.
Reiniciar guarda a los jugadores conectados, pero los desconecta unos segundos: hazlo cuando haya pocos.

### 7.4 Actualizar a los jugadores (sin descargar de nuevo)
Ver `despliegue/DESPLIEGUE_VPS.md`, sección 7. **Todo se puede actualizar**; cambia cuánto baja el jugador:

- `publicar_parche.ps1 -Servidor IP -Version "beta X.Y.Z"` → **parche** de ~0,3 MB: todo el código y los datos XML, más los sprites/sonidos nuevos o cambiados de `juego/arte`.
- `publicar_parche.ps1 -Servidor IP -Version "beta X.Y.Z" -Completo` → **paquete completo** (~85 MB): para `main.lua`, `conf.lua`, el `.exe`/DLL o archivos que haya que borrar.
  El juego lo baja con barra de progreso, se cierra, se instala encima y se vuelve a abrir solo. Luego sube `web/descargas/` al repo de la web.

**Receta típica de un cambio de código:**
1. Editar, `lovec servidor --test` y `lovec juego --test`.
2. `desplegar.ps1` (si cambió el servidor o `compartido/`).
3. `publicar_parche.ps1` (si cambió el cliente, el arte o `compartido/`; con `-Completo` si cambió algo que un parche no puede) y commit de `juego/version.lua`.
4. Commit y push. El paquete de la web solo se rehace cuando hace falta un cliente completo.

---

## 8. El VPS (Ubuntu)

- Servicio systemd `doscoronas` (`love /opt/doscoronas/servidor.love`, `.env` en `/opt/doscoronas`), PostgreSQL local, firewall `ufw` con **22 (SSH), 30555 (juego) y 80 (parches)**.
- Acceso **solo por clave SSH** (nada de contraseñas en el repositorio ni en chats; rota la de root si alguna vez se compartió).
- Copias diarias de la base con `doscoronas-respaldo` (cron) en `/var/backups/doscoronas` (solo root). Conviene copiarlas también fuera del VPS.
- Comandos útiles (desde tu PC):

| Tarea | Comando |
| --- | --- |
| Estado | `ssh root@IP "systemctl status doscoronas --no-pager"` |
| Logs en vivo | `ssh root@IP "journalctl -u doscoronas -f"` |
| Reiniciar | `ssh root@IP "systemctl restart doscoronas"` |
| Ver la clave de PostgreSQL | `ssh root@IP "grep DOSCORONAS_PG_PASSWORD /opt/doscoronas/.env"` (no la pegues en chats) |
| Entrar a la base | `ssh root@IP`, luego `cd /tmp; sudo -u postgres psql doscoronas` |
| Ver parches publicados | `ssh root@IP "ls -la /var/www/doscoronas/actualizacion; cat /var/www/doscoronas/actualizacion/version.txt"` |

La IP del VPS no está en el repositorio: se pasa por parámetro (`-Servidor`) a los scripts.

---

## 9. Trampas conocidas (para no tropezar dos veces)

- **LuaJIT no tiene `//`**: usa `math.floor(a / b)`.
- Editar archivos con CRLF desde scripts: respeta los saltos de línea del archivo (o los `.sh`/`.service` se rompen en Linux; `.gitattributes` fuerza LF en ellos).
- Cierra `lovec.exe` y `DosCoronas.exe` antes de `construir.ps1`/pruebas; si el `.exe` está en uso el empaquetado se detiene sin borrar nada.
- El juego instalado guarda sus datos en `%APPDATA%\doscoronas` (el de desarrollo, en `%APPDATA%\LOVE\doscoronas`).
- Las contraseñas y claves **nunca** al repo ni al chat. `.env` está en `.gitignore`.
- Un parche solo se aplica si su `build` es mayor que el del paquete instalado; el `build` sube solo con `publicar_parche.ps1`. Haz commit de `despliegue/arte_base.txt` tras cada paquete completo.
- `compartido/` es de los dos proyectos: un cambio ahí exige desplegar servidor **y** publicar parche, o clientes y servidor discrepan (p. ej. en el mapa generado).
