-- Configuración del juego (cliente). Prioridad: variables de entorno, archivo
-- .env junto a main.lua y valores por defecto. Ver .env.example.
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

local function entero(nombre, defecto, minimo, maximo)
  local n = tonumber(crudo(nombre))
  if not n or (minimo and n < minimo) or (maximo and n > maximo) then return defecto end
  return math.floor(n)
end

return {
  origen = ruta,
  red = {
    -- Servidor al que se conecta el juego.
    host = texto("DOSCORONAS_SERVIDOR_HOST", "127.0.0.1"),
    puerto = entero("DOSCORONAS_PUERTO", 30555, 1, 65535),
  },
}
