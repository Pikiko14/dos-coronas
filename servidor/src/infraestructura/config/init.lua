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
  },
}
