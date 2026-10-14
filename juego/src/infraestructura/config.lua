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

-- Destino por defecto: el paquete del juego lo lleva dentro (src/infraestructura/destino.lua, lo escribe construir.ps1),
-- así los jugadores no necesitan ningún archivo .env. Un .env o una variable de entorno siguen mandando (desarrollo).
local okDestino, destino = pcall(require, "src.infraestructura.destino")
if not okDestino or type(destino) ~= "table" then destino = {} end

return {
  origen = ruta,
  -- Dirección de los parches de actualización (http://servidor/actualizacion/); sin ella el juego no busca actualizaciones.
  actualizaciones = texto("DOSCORONAS_ACTUALIZACIONES", destino.actualizaciones),
  red = {
    -- Servidor al que se conecta el juego.
    host = texto("DOSCORONAS_SERVIDOR_HOST", destino.host or "127.0.0.1"),
    puerto = entero("DOSCORONAS_PUERTO", destino.puerto or 30555, 1, 65535),
  },
}
