local Log = require("compartido.infraestructura.log")

local S = { fuentes = {}, volumen = 0.8, fondos = {} }

local function tono(frecuencia, duracion, forma)
  local tasa = 22050
  local n = math.floor(tasa * duracion)
  local datos = love.sound.newSoundData(n, tasa, 16, 1)
  for i = 0, n - 1 do
    local t = i / tasa
    local env = math.min(1, t * 40) * math.max(0, 1 - t / duracion)
    local s
    local fase = t * frecuencia
    if forma == "ruido" then
      s = math.random() * 2 - 1
    elseif forma == "cuadrada" then
      s = (fase % 1 < 0.5) and 0.25 or -0.25
    else
      s = math.sin(fase * math.pi * 2) * 0.35
    end
    datos:setSample(i, s * env * 0.4)
  end
  return love.audio.newSource(datos, "static")
end

-- El juego va sin sonido: no se crea ninguna fuente de audio y tocar/ambiente no hacen nada.
function S.iniciar()
  S.ok = false
end

function S.tocar(nombre)
  if not S.ok then return end
  local f = S.fuentes[nombre]
  if not f then return end
  f:setVolume(S.volumen or 1)
  f:stop()
  f:play()
end

function S.claveZona(nombre)
  nombre = (nombre or ""):lower()
  if nombre:find("puerto") or nombre:find("costa") then return "mar" end
  if nombre:find("cicatriz") then return "cicatriz" end
  if nombre:find("bosque") then return "bosque" end
  return "ciudad"
end

function S.ambiente(zona)
  if not S.ok then return end
  local clave = S.claveZona(zona)
  if S.zona == clave and S.musica then
    S.musica:setVolume((S.volumen or 1) * 0.22)
    return
  end
  if S.musica then S.musica:stop() end
  S.zona = clave
  local f = S.fondos[clave]
  if not f then return end
  f:setLooping(true)
  f:setVolume((S.volumen or 1) * 0.22)
  f:play()
  S.musica = f
end

function S.cerrar()
  for _, f in pairs(S.fuentes) do
    pcall(function() f:stop() end)
  end
end

return S
