-- Sonido del juego. No hay archivos de audio: los efectos los genera presentacion/sintesis.lua al arrancar (poderes, voces de las
-- criaturas por familia y la muerte del personaje). Cada sonido tiene unas cuantas copias para que puedan solaparse.
local Sintesis = require("src.presentacion.sintesis")
local Log = require("compartido.infraestructura.log")

local S = { fuentes = {}, volumen = 0.8, fondos = {}, ALCANCE = 26 }
local COPIAS = 4

-- silencio = true: no se crea nada (pruebas y modos sin audio).
function S.iniciar(silencio)
  if S.ok ~= nil then return end
  S.ok = false
  if silencio or not love.audio or not love.sound then return end
  local t0 = love.timer.getTime()
  local ok, err = pcall(function()
    for nombre, f in pairs(Sintesis.catalogo()) do
      S.fuentes[nombre] = { base = love.audio.newSource(f(), "static"), copias = {}, n = 0, ultimo = 0 }
    end
  end)
  if not ok then Log.error("sonido: " .. tostring(err)) return end
  S.ok = true
  Log.info(string.format("sonido: efectos sintetizados en %.2f s", love.timer.getTime() - t0))
end

-- Toca un sonido por su nombre; rel = volumen relativo (0..1).
function S.tocar(nombre, rel)
  if not S.ok or (S.volumen or 0) <= 0 then return false end
  local e = S.fuentes[nombre]
  if not e then return false end
  local ahora = love.timer.getTime()
  if ahora - e.ultimo < 0.05 then return false end      -- el mismo sonido pegado a sí mismo no se repite
  e.ultimo = ahora
  e.n = e.n % COPIAS + 1
  local f = e.copias[e.n]
  if not f then f = e.base:clone() e.copias[e.n] = f end
  f:stop()
  f:setVolume(math.max(0, math.min(1, (S.volumen or 1) * (rel or 1))))
  f:setPitch(0.94 + math.random() * 0.12)
  f:play()
  return true
end

-- Un evento del mundo ({ n = nombre, x, y }): se oye más bajo cuanto más lejos ocurre de quien escucha.
function S.evento(ev, oyente)
  if type(ev) == "string" then return S.tocar(ev) end
  if type(ev) ~= "table" or not ev.n then return false end
  local rel = 1
  if ev.x and oyente and oyente.x then
    local d = math.sqrt((ev.x - oyente.x) ^ 2 + (ev.y - oyente.y) ^ 2)
    if d >= S.ALCANCE then return false end
    rel = math.max(0.12, (1 - d / S.ALCANCE) ^ 1.3)
  end
  return S.tocar(ev.n, rel)
end

function S.claveZona(nombre)
  nombre = (nombre or ""):lower()
  if nombre:find("puerto") or nombre:find("costa") then return "mar" end
  if nombre:find("cicatriz") then return "cicatriz" end
  if nombre:find("bosque") then return "bosque" end
  return "ciudad"
end

-- (sin música de ambiente por ahora)
function S.ambiente() end

function S.cerrar()
  for _, e in pairs(S.fuentes) do
    pcall(function()
      e.base:stop()
      for _, c in pairs(e.copias) do c:stop() end
    end)
  end
end

return S
