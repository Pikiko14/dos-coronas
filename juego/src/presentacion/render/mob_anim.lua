-- Criaturas con animación por cuadros (arte/monstruos/<carpeta>/{wait,run,att,hurt,dead}.png): cada tira trae sus cuadros en horizontal.
-- Reparto de pasos: 3 de espera, 6 de carrera, 4 de ataque, 2 de daño y 6 de muerte. Las criaturas con dirs2 (casi todas) traen cada paso en dos
-- direcciones: cuadro = paso * 2 + hoja, con la hoja 0 espalda-izquierda y la 1 frente-izquierda (en la vista isométrica los ejes del mundo
-- son diagonales: las otras dos diagonales salen volteando). Cada cuadro lleva un margen transparente (pad) para que el filtro no mezcle
-- cuadros vecinos ni corte la silueta. Las que no (calabaza y limo) traen todos los cuadros seguidos y miran a un lado.
-- Tamaño, aura y tinte de cada criatura: render/mob_anim_datos.lua (lo genera herramientas/generar_mobs/mobs.py).
local M = {}

local CUADROS = { wait = 15, run = 30, att = 20, hurt = 10, dead = 30 }
local VELOCIDAD = { wait = 10, run = 26, att = 28, hurt = 22, dead = 18 }   -- cuadros por segundo (criaturas sin direcciones)
local PASOS = { wait = 2.6, run = 7.5, dead = 4.5 }                          -- pasos por segundo (criaturas con direcciones)

M.DEFS = require("src.presentacion.render.mob_anim_datos")
for _, d in pairs(M.DEFS) do d.mira = d.mira or "izq" end

local cache = {}

local function tira(carpeta, tipo, dirs2)
  local k = carpeta .. "/" .. tipo
  local t = cache[k]
  if t == nil then
    local ruta = "arte/monstruos/" .. carpeta .. "/" .. tipo .. ".png"
    if love.filesystem.getInfo(ruta) then
      local img = love.graphics.newImage(ruta, { mipmaps = true })
      img:setFilter("linear", "linear")
      img:setMipmapFilter("linear", 0)
      local n = dirs2 and (CUADROS[tipo] * 2 / 5) or CUADROS[tipo]
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

-- Hoja (0 espalda-izquierda, 1 frente-izquierda) y si se voltea, según la dirección del mundo de la criatura (1 y+, 2 y-, 3 x+, 4 x-): en la
-- vista isométrica y+ baja a la izquierda, y- sube a la derecha, x+ baja a la derecha y x- sube a la izquierda.
local function hojaDe(dir)
  if dir == 1 then return 1, false end        -- hacia abajo-izquierda: frente-izquierda
  if dir == 2 then return 0, true end         -- hacia arriba-derecha: espalda-izquierda volteada
  if dir == 3 then return 1, true end         -- hacia abajo-derecha: frente-izquierda volteada
  return 0, false                             -- hacia arriba-izquierda: espalda-izquierda
end

-- Aura de los jefes: un charco de luz con latido en el suelo y unas chispas que giran.
local function aura(d, sx, pies, alfa)
  if not d.aura then return end
  local t = love.timer.getTime()
  local c = d.aura
  local r = d.alto * 0.62
  local latido = 0.5 + 0.5 * math.sin(t * 2.4)
  for k = 3, 1, -1 do
    love.graphics.setColor(c[1], c[2], c[3], (0.06 + 0.04 * latido) * (4 - k) * 0.6 * (alfa or 1))
    love.graphics.ellipse("fill", sx, pies + 2, r * (0.55 + 0.22 * k), r * (0.55 + 0.22 * k) * 0.42)
  end
  love.graphics.setColor(c[1], c[2], c[3], (0.35 + 0.2 * latido) * (alfa or 1))
  love.graphics.setLineWidth(1.5)
  love.graphics.ellipse("line", sx, pies + 2, r * 0.95, r * 0.95 * 0.42)
  love.graphics.setLineWidth(1)
  for i = 1, 6 do
    local a = t * 0.9 + i * math.pi / 3
    local yy = pies + 2 - ((t * 0.5 + i * 0.17) % 1) * d.alto * 0.7
    love.graphics.setColor(c[1], c[2], c[3], (0.7 - ((t * 0.5 + i * 0.17) % 1) * 0.7) * (alfa or 1))
    love.graphics.circle("fill", sx + math.cos(a) * r * 0.7, yy, 1.6)
  end
end

-- Dibuja un cuadro de la tira. i es el cuadro (o el paso en las criaturas con direcciones); u (0..1) elige por progreso si no se da i.
local function dibujar(nombre, tipo, i, u, sx, pies, dir, alfa, tinte)
  local d = M.DEFS[nombre]
  if not d then return 32 end
  local t = tira(d.carpeta, tipo, d.dirs2)
  if not t then return d.alto end
  local voltear
  if d.dirs2 then
    local pasos = math.floor(t.n / 2)
    if not i then i = math.floor((u or 0) * pasos) end
    i = math.max(0, math.min(pasos - 1, i))
    local hoja, flip = hojaDe(dir or 1)
    voltear = flip
    i = i * 2 + hoja
  else
    if not i then i = math.floor((u or 0) * t.n) end
    i = math.max(0, math.min(t.n - 1, i))
    voltear = (d.mira == "izq") == ((dir or 1) == 3)
  end
  local e = d.escala
  local c = tinte or { 1, 1, 1 }
  local k = d.tinte
  if k then c = { c[1] * k[1], c[2] * k[2], c[3] * k[3] } end
  aura(d, sx, pies, alfa)
  love.graphics.setColor(c[1], c[2], c[3], alfa or 1)
  love.graphics.draw(t.img, cuadro(t, i), sx, pies + 2, 0, voltear and -e or e, e, t.w / 2, t.h - (d.pad or 0))
  return d.alto
end

-- Criatura viva. estado: "wait" | "run" | "att" | "hurt"; u: progreso 0..1 para ataque y daño; dir: dirección del mundo (1..4); semilla:
-- desfase para que las del mismo tipo no se muevan a la vez. Devuelve su altura para la placa.
function M.dibujar(nombre, estado, u, sx, pies, dir, tinte, semilla)
  local d = M.DEFS[nombre]
  local i
  if d and (estado == "wait" or estado == "run") then
    local t = tira(d.carpeta, estado, d.dirs2)
    local desfase = (semilla or 0) * 3.7
    if d.dirs2 then
      i = math.floor(love.timer.getTime() * PASOS[estado] + desfase) % math.max(1, math.floor((t and t.n or 2) / 2))
    else
      i = math.floor(love.timer.getTime() * VELOCIDAD[estado] + desfase) % (t and t.n or 1)
    end
  end
  return dibujar(nombre, estado, i, u, sx, pies, dir, 1, tinte)
end

-- Cadáver: la animación de muerte y, al terminar, el último cuadro que se va apagando. transcurrido: segundos desde que murió.
function M.muerto(nombre, transcurrido, sx, pies, dir, alfa)
  local d = M.DEFS[nombre]
  if not d then return end
  local t = tira(d.carpeta, "dead", d.dirs2)
  if not t then return end
  local pasos = d.dirs2 and math.floor(t.n / 2) or t.n
  local i = math.min(pasos - 1, math.floor(math.max(0, transcurrido) * (d.dirs2 and PASOS.dead or VELOCIDAD.dead)))
  dibujar(nombre, "dead", i, nil, sx, pies, dir, alfa, nil)
end

return M
