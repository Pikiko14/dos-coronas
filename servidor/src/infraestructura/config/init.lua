-- Configuración del servidor. Orden de prioridad:
--   1. variables de entorno del sistema
--   2. archivo .env junto al juego
--   3. valores por defecto de este archivo
-- Los nombres y su significado están en .env.example.
local Env = require("compartido.infraestructura.env")

local archivo, ruta = Env.cargar(".env")

local function crudo(nombre)
  local v = os.getenv and os.getenv(nombre)
  if v and v ~= "" then return v end
  v = archivo[nombre]
  if v and v ~= "" then return v end
  return nil
end

local function texto(nombre, defecto)
  return crudo(nombre) or defecto
end

local function numero(nombre, defecto, minimo, maximo)
  local n = tonumber(crudo(nombre))
  if not n then return defecto end
  if minimo and n < minimo then return defecto end
  if maximo and n > maximo then return defecto end
  return n
end

local function entero(nombre, defecto, minimo, maximo)
  local n = numero(nombre, defecto, minimo, maximo)
  return math.floor(n)
end

local ALMACENES = { auto = true, postgres = true, archivo = true }

local almacen = (texto("DOSCORONAS_ALMACEN", "auto")):lower()
if not ALMACENES[almacen] then almacen = "auto" end

return {
  origen = ruta,
  -- Dónde se guardan cuentas y personajes: "auto", "postgres" o "archivo".
  almacen = almacen,
  postgres = {
    host = texto("DOSCORONAS_PG_HOST", "127.0.0.1"),
    puerto = entero("DOSCORONAS_PG_PORT", 5433, 1, 65535),
    usuario = texto("DOSCORONAS_PG_USER", "doscoronas"),
    base = texto("DOSCORONAS_PG_DB", "doscoronas"),
    -- Solo vale para autenticación con clave en texto (password); md5 y scram no.
    clave = texto("DOSCORONAS_PG_PASSWORD", ""),
  },
  red = {
    -- Puerto donde escucha el servidor.
    puerto = entero("DOSCORONAS_PUERTO", 30555, 1, 65535),
  },
  servidor = {
    guardado_segundos = numero("DOSCORONAS_GUARDADO_SEGUNDOS", 600, 5, 86400),
    reintento_segundos = numero("DOSCORONAS_REINTENTO_SEGUNDOS", 5, 1, 600),
    tasa_mensajes = entero("DOSCORONAS_TASA_MENSAJES", 40, 5, 1000),
    fotos_por_segundo = numero("DOSCORONAS_FOTOS_POR_SEGUNDO", 15, 2, 60),
  },
  -- Eventos de guerra que lanza el servidor (ver programacion.lua).
  eventos = {
    activos = texto("DOSCORONAS_EVENTOS", "si"):lower() ~= "no",
    estandarteCadaHoras = entero("DOSCORONAS_ESTANDARTE_CADA_HORAS", 4, 1, 24),
    batallaHora = entero("DOSCORONAS_BATALLA_HORA", 21, 0, 23),
    batallaMinuto = entero("DOSCORONAS_BATALLA_MINUTO", 0, 0, 59),
    avisoMinutos = entero("DOSCORONAS_EVENTOS_AVISO_MINUTOS", 5, 0, 60),
    -- jugadores por corona que hacen falta para que un evento empiece
    minJugadores = entero("DOSCORONAS_EVENTO_MIN_JUGADORES", 1, 1, 50),
    duracionBatalla = entero("DOSCORONAS_BATALLA_DURACION_SEG", 300, 30, 7200),
    duracionEstandarte = entero("DOSCORONAS_ESTANDARTE_DURACION_SEG", 300, 30, 7200),
  },
  -- Reglas del juego que el servidor puede ajustar (ver servidor/src/aplicacion/ajustes.lua).
  juego = {
    -- progresión y combate
    xpDificultad = numero("DOSCORONAS_XP_DIFICULTAD", 1.8, 0.1, 20),
    -- multiplicador de la experiencia que se gana (2 = experiencia doble)
    xpMultiplicador = numero("DOSCORONAS_XP_MULTIPLICADOR", 1, 0, 100),
    monstruoVida = numero("DOSCORONAS_MONSTRUO_VIDA", 3.0, 0.1, 50),
    monstruoAtaque = numero("DOSCORONAS_MONSTRUO_ATAQUE", 1.05, 0.1, 20),
    nivelPaso = numero("DOSCORONAS_DIFERENCIA_NIVEL", 0.04, 0, 0.2),
    respawnMonstruo = numero("DOSCORONAS_RESPAWN_MONSTRUO_SEG", 22, 1, 3600),
    respawnElite = numero("DOSCORONAS_RESPAWN_ELITE_SEG", 90, 1, 86400),
    -- subastas
    subastaComision = numero("DOSCORONAS_SUBASTA_COMISION", 0.05, 0, 0.5),
    subastaImpuesto = numero("DOSCORONAS_SUBASTA_IMPUESTO", 0.08, 0, 0.5),
    subastaMaxPorJugador = entero("DOSCORONAS_SUBASTA_MAX_POR_JUGADOR", 8, 1, 100),
    subastaDuraciones = texto("DOSCORONAS_SUBASTA_DURACIONES_HORAS", "1,6,12,24"),
    subastaSubidaMinima = numero("DOSCORONAS_SUBASTA_SUBIDA_MINIMA", 0.05, 0, 1),
    subastaTiempoExtra = entero("DOSCORONAS_SUBASTA_TIEMPO_EXTRA_SEG", 120, 0, 3600),
    -- gremios
    gremioNivelMinimo = entero("DOSCORONAS_GREMIO_NIVEL_MINIMO", 8, 1, 30),
    gremioCoste = entero("DOSCORONAS_GREMIO_COSTE", 1500, 0, 10000000),
    gremioMaxMiembros = entero("DOSCORONAS_GREMIO_MAX_MIEMBROS", 25, 2, 200),
    gremioBonoXp = numero("DOSCORONAS_GREMIO_BONO_XP", 0.05, 0, 1),
    gremioTopeCompaneros = entero("DOSCORONAS_GREMIO_TOPE_COMPANEROS", 3, 0, 20),
    -- oficios y caravanas
    caravanaIntervalo = numero("DOSCORONAS_CARAVANA_INTERVALO_SEG", 70, 5, 86400),
    caravanaMax = entero("DOSCORONAS_CARAVANA_MAX", 8, 0, 100),
    caravanaVelocidad = numero("DOSCORONAS_CARAVANA_VELOCIDAD", 2.4, 0.5, 10),
    oficioCosteCambio = entero("DOSCORONAS_OFICIO_COSTE_CAMBIO", 300, 0, 10000000),
    buscadoSeg = numero("DOSCORONAS_LADRON_BUSCADO_SEG", 240, 10, 86400),
    buscadoFalloSeg = numero("DOSCORONAS_LADRON_BUSCADO_FALLO_SEG", 120, 10, 86400),
    -- mascotas
    mascotaDescanso = numero("DOSCORONAS_MASCOTA_DESCANSO_SEG", 30, 0, 3600),
  },
}
