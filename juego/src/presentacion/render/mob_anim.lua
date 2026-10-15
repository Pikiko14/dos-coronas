-- Criaturas con animación por cuadros (arte/monstruos/<nombre>/{wait,run,att,hurt,dead}.png): cada tira trae sus cuadros en horizontal.
-- Todas las criaturas de este tipo comparten el reparto: 15 cuadros de espera, 30 de carrera, 20 de ataque, 10 de daño y 30 de muerte.
-- El arte mira a un lado: se voltea según hacia dónde va la criatura.
local M = {}

local CUADROS = { wait = 15, run = 30, att = 20, hurt = 10, dead = 30 }
local VELOCIDAD = { wait = 10, run = 26, att = 28, hurt = 22, dead = 18 }   -- cuadros por segundo

-- escala: tamaño en el mundo; pies: píxeles del cuadro (sin escalar) que quedan bajo el suelo; mira: lado al que mira el arte.
M.DEFS = {
  calabaza = { escala = 0.62, mira = "izq", alto = 40 },
  limo = { escala = 0.50, mira = "izq", alto = 42 },
}

local cache = {}

local function tira(nombre, tipo)
  local k = nombre .. "/" .. tipo
  local t = cache[k]
  if t == nil then
    local ruta = "arte/monstruos/" .. nombre .. "/" .. tipo .. ".png"
    if love.filesystem.getInfo(ruta) then
      local img = love.graphics.newImage(ruta)
      img:setFilter("linear", "linear")
      local n = CUADROS[tipo]
      t = { img = img, n = n, w = img:getWidth() / n, h = img:getHeight(), quads = {} }
    else
      t = false
    end
    cache[k] = t
  end
  return t or nil
end

local function cuadro(t, i)
  local q = t.quads[i]
  if not q then
    q = love.graphics.newQuad(i * t.w, 0, t.w, t.h, t.img:getDimensions())
    t.quads[i] = q
  end
  return q
end

function M.existe(nombre) return M.DEFS[nombre] ~= nil end

-- Dibuja un cuadro de la tira. i va de 0 a n-1; u (0..1) elige el cuadro por progreso si no se da i.
local function dibujar(nombre, tipo, i, u, sx, pies, derecha, alfa, tinte)
  local d = M.DEFS[nombre]
  local t = tira(nombre, tipo)
  if not d or not t then return d and d.alto or 32 end
  if not i then i = math.min(t.n - 1, math.floor((u or 0) * t.n)) end
  i = math.max(0, math.min(t.n - 1, i))
  local voltear = (d.mira == "izq") == (derecha and true or false)
  local e = d.escala
  tinte = tinte or { 1, 1, 1 }
  love.graphics.setColor(tinte[1], tinte[2], tinte[3], alfa or 1)
  love.graphics.draw(t.img, cuadro(t, i), sx, pies + 2, 0, voltear and -e or e, e, t.w / 2, t.h)
  return d.alto
end

-- Criatura viva. estado: "wait" | "run" | "att" | "hurt"; u: progreso 0..1 para ataque y daño. Devuelve su altura para la placa.
function M.dibujar(nombre, estado, u, sx, pies, derecha, tinte)
  local t = tira(nombre, estado)
  local i
  if estado == "wait" or estado == "run" then
    i = math.floor(love.timer.getTime() * VELOCIDAD[estado]) % (t and t.n or 1)
  end
  return dibujar(nombre, estado, i, u, sx, pies, derecha, 1, tinte)
end

-- Cadáver: la animación de muerte y, al terminar, el último cuadro que se va apagando. transcurrido: segundos desde que murió.
function M.muerto(nombre, transcurrido, sx, pies, derecha, alfa)
  local t = tira(nombre, "dead")
  if not t then return end
  local i = math.min(t.n - 1, math.floor(math.max(0, transcurrido) * VELOCIDAD.dead))
  dibujar(nombre, "dead", i, nil, sx, pies, derecha, alfa)
end

return M
