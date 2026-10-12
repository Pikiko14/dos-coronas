-- Autotiles al estilo RPG Maker VX Ace (casillas de 32 px, cuartos de 16 px).
--
-- Suelo: bloque de 2x3 casillas (64x96 px) = 4x6 cuartos.
--   arriba izquierda  casilla "isla" (sin vecinos)
--   arriba derecha    interior con las cuatro esquinas cóncavas
--   abajo (2x2)       marco: esquinas, bordes e interior
-- Muro/tejado: bloque de 2x2 casillas (64x64 px) = 4x4 cuartos, sin esquinas cóncavas.
local Arte = require("src.presentacion.render.arte")

local A = {}

-- Bits de vecindad: true en cada lado donde hay algo del mismo tipo.
local U, D, L, R, UL, UR, DL, DR = 1, 2, 4, 8, 16, 32, 64, 128
A.U, A.D, A.L, A.R, A.UL, A.UR, A.DL, A.DR = U, D, L, R, UL, UR, DL, DR

local function tiene(m, bit)
  return math.floor(m / bit) % 2 == 1
end

-- Cuartos de suelo: esquina, borde vertical, borde horizontal, esquina cóncava, interior, isla.
local SUELO = {
  { { 0, 2 }, { 0, 4 }, { 2, 2 }, { 2, 0 }, { 2, 4 }, { 0, 0 } },
  { { 3, 2 }, { 3, 4 }, { 1, 2 }, { 3, 0 }, { 1, 4 }, { 1, 0 } },
  { { 0, 5 }, { 0, 3 }, { 2, 5 }, { 2, 1 }, { 2, 3 }, { 0, 1 } },
  { { 3, 5 }, { 3, 3 }, { 1, 5 }, { 3, 1 }, { 1, 3 }, { 1, 1 } },
}
-- Por cuarto: bit horizontal, bit vertical y bit diagonal que le tocan.
local VECINOS = {
  { L, U, UL },
  { R, U, UR },
  { L, D, DL },
  { R, D, DR },
}

local MURO = {
  { { 0, 0 }, { 0, 2 }, { 2, 0 }, { 2, 2 } },
  { { 3, 0 }, { 3, 2 }, { 1, 0 }, { 1, 2 } },
  { { 0, 3 }, { 0, 1 }, { 2, 3 }, { 2, 1 } },
  { { 3, 3 }, { 3, 1 }, { 1, 3 }, { 1, 1 } },
}

local cacheSuelo, cacheMuro = {}, {}

local function cuartosSuelo(m)
  local c = cacheSuelo[m]
  if c then return c end
  local aislada = not (tiene(m, U) or tiene(m, D) or tiene(m, L) or tiene(m, R))
  c = {}
  for i = 1, 4 do
    local t = SUELO[i]
    local v = VECINOS[i]
    local h, vv, d = tiene(m, v[1]), tiene(m, v[2]), tiene(m, v[3])
    local q
    if aislada then q = t[6]
    elseif not h and not vv then q = t[1]
    elseif not h then q = t[2]
    elseif not vv then q = t[3]
    elseif not d then q = t[4]
    else q = t[5] end
    c[i] = q
  end
  cacheSuelo[m] = c
  return c
end

local function cuartosMuro(m)
  local c = cacheMuro[m]
  if c then return c end
  c = {}
  for i = 1, 4 do
    local t = MURO[i]
    local v = VECINOS[i]
    local h, vv = tiene(m, v[1]), tiene(m, v[2])
    local q
    if not h and not vv then q = t[1]
    elseif not h then q = t[2]
    elseif not vv then q = t[3]
    else q = t[4] end
    c[i] = q
  end
  cacheMuro[m] = c
  return c
end

local DESTINO = { { 0, 0 }, { 16, 0 }, { 0, 16 }, { 16, 16 } }

local function pintar(img, ox, oy, cuartos, x, y)
  for i = 1, 4 do
    local q = cuartos[i]
    local d = DESTINO[i]
    love.graphics.draw(img, Arte.quad(img, ox + q[1] * 16, oy + q[2] * 16, 16, 16), x + d[1], y + d[2])
  end
end

-- img: lámina; (ox, oy): esquina del bloque en píxeles; m: máscara de vecinos.
function A.suelo(img, ox, oy, m, x, y)
  pintar(img, ox, oy, cuartosSuelo(m), x, y)
end

function A.muro(img, ox, oy, m, x, y)
  pintar(img, ox, oy, cuartosMuro(m), x, y)
end

-- Máscara de 8 vecinos. igual(dx, dy) responde si esa casilla es del mismo tipo.
function A.mascara(igual)
  local m = 0
  if igual(0, -1) then m = m + U end
  if igual(0, 1) then m = m + D end
  if igual(-1, 0) then m = m + L end
  if igual(1, 0) then m = m + R end
  if igual(-1, -1) then m = m + UL end
  if igual(1, -1) then m = m + UR end
  if igual(-1, 1) then m = m + DL end
  if igual(1, 1) then m = m + DR end
  return m
end

return A
