# Plan de Dos Coronas

Estado: fases 1 a 8 en el código. Los eventos de guerra arrancan con 3 jugadores por equipo, sin rellenar con bots. `love . --test` es la comprobación.

Ordenado por valor y por riesgo. Cada fase termina con `love . --test` en verde antes de abrir la siguiente. Los personajes ya guardados en PostgreSQL se leen igual: estas fases no cambian el esquema. Si una fase posterior lo cambia, lleva migración.

## Hecho en el juego hoy

Cuatro clases, diez ciudades, treinta monstruos, casas, comercio, chat, misiones y dos guerras diarias. Cuentas en Postgres (`src/pg.lua`, `src/cuentas.lua`). Servidor `--servidor` en el puerto 30555 con foto cada 0,1 s. El mundo es un continente generado (480×360) más instancias de casa, batalla y estandarte. El cliente remoto entra como Viajero, Umbra, mago, sin cuenta.

## Fase 1 — Cortar main.lua

Riesgo bajo. Valor alto: el resto de las fases tocan entrada, red y guardado, y hoy viven en el mismo archivo.

- `main.lua` solo engancha `love.load`, `love.update`, `love.draw`, ratón, teclado, rueda, texto, salida y el manejador de errores.
- `src/app.lua` guarda la sesión (estado, mundo, jugador, rol, zoom) y arranca láminas, fuente y modo.
- `src/estados/menu.lua`, `cuenta.lua`, `personajes.lua`, `crear.lua`, `juego.lua`, `servidor.lua` dibujan y, si les toca, actualizan.
- `src/entrada.lua` reparte clics, teclas y el clic en el suelo.
- `src/pruebas.lua` conserva `--test` y el modo `--foto`.
- La pantalla de unirse a una IP sigue existiendo; la dibuja el menú.

## Fase 2 — Rutas, arte, fuente y configuración

Riesgo medio. Sin esto el proyecto no arranca en otra máquina.

- Láminas usadas por `src/atlas.lua` dentro de `arte/hojas/`, con `AUTHORS.md` y la licencia CC BY 4.0 del OpenTibia Sprite Pack.
- Fuente libre en `arte/fuentes/`, cargada con `love.filesystem`. Si falta, se registra el fallo y se usa la fuente de LÖVE.
- Logs, `prueba_resultado.txt` y capturas salen de `love.filesystem.getSource()`, no de una ruta con nombre de usuario.
- `config.lua` define host, puerto, usuario y base de Postgres, y el puerto de juego. Las variables `DOSCORONAS_PG_HOST`, `DOSCORONAS_PG_PORT`, `DOSCORONAS_PG_USER`, `DOSCORONAS_PG_DB` y `DOSCORONAS_PUERTO` pisan esos valores.
- `jugar.bat` y `servidor.bat` buscan `love` en el PATH y después en `..\love\love.exe`.
- `src/log.lua` escribe `log.txt` con nivel info, warn o error.

## Fase 3 — Entrar al servidor con el personaje elegido

Riesgo alto. El mensaje `hola` deja de inventar Viajero/umbra/mago.

- Tras el login y la elección de personaje, el cliente envía el id de personaje y un token de sesión, nunca la contraseña.
- El servidor carga ese personaje desde la base y rechaza la conexión si la cuenta no coincide.

## Fase 4 — Servidor autoritativo

Riesgo alto. El cliente propone; el servidor decide.

- Tope de velocidad al mover, distancia máxima para interactuar, cooldowns, oro e inventario, y comercio.
- Mensaje inválido se ignora. Cada conexión tiene un límite de mensajes por segundo.

## Fase 5 — Cuentas

Riesgo medio. Hay que poder entrar con las claves ya guardadas o migrar el hash.

- Sustituir SHA-256 de una pasada por PBKDF2 con sal e iteraciones.
- Consultas con escape correcto (el cliente de `pg.lua` no tiene parámetros nativos: un literal único y probado).
- Tope de intentos fallidos de login.
- La contraseña no viaja en el protocolo de juego.

## Fase 6 — Guardado del servidor

Riesgo medio.

- El proceso `--servidor` guarda en periodo, al desconectar y al cerrar.
- Si Postgres no responde, reintenta, avisa y no descarta el último estado en memoria.

## Fase 7 — Juego, en este orden

1. Pisos (Z), escaleras y agujeros. Solo se dibuja el piso actual; arriba se atenúa si el personaje está debajo.
2. Profundidad al estilo Tibia: offset 3/4, orden por Y, techos que se ocultan dentro de la casa.
3. A\* del clic para mover: ya existe en `src/mapa.lua`. Falta recortar la ruta y recalcular si un obstáculo aparece.
4. Combate: cooldowns en la barra, números flotantes (ya hay un canal), barras sobre criaturas, efectos y botín en el suelo con tabla por monstruo.
5. Curva de experiencia, habilidades por nivel y `src/balance.lua` para los números.
6. Misiones encadenadas, diálogo de NPC y registro en la interfaz.
7. HUD, arrastrar en la bolsa, tooltips, minimapa, chat con pestañas, escala al redimensionar.
8. Música por zona, efectos y volumen.
9. Opciones: resolución, pantalla completa, volumen y teclas, guardadas en disco.

## Fase 8 — Calidad que aún no está en las fases de arriba

- `mundo.lua` no llama a `love.graphics` (hoy ya cumple; hay que no romperlo).
- Constantes sueltas pasan a `datos.lua` o `balance.lua`.
- Pruebas separadas por tema dentro de `src/pruebas.lua`, mismo `--test`, código de salida 1 si fallan.
- SpriteBatch para el suelo y overlay F3 (FPS, entidades, ping).
- Mapas de Tiled vía STI, además del generador actual.
- `LEEME.txt` completo: instalar, base de datos, servidor, cliente, pruebas, cómo añadir mapa, monstruo e ítem, créditos del arte.

## Fuera de esta entrega

Las fases 3 a 8 no se abren hasta que `--test` pase con las fases 1 y 2.
