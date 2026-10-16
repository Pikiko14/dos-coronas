-- Trampas del suelo de las mazmorras (pinchos, fuego y gas), dibujadas por código sobre el terreno. Su ciclo
-- (reposo, aviso y activa) depende solo del reloj del mundo, igual que en el servidor (Mazmorras.faseTrampa).
local Mazmorras = require("compartido.dominio.mazmorras")

local T = {}

local TILE = 32
local Iso = require("src.presentacion.render.iso")

-- La placa de la trampa es un rombo apoyado en el suelo (como las casillas isométricas), con su dibujo propio.
local function rombo(modo, cx, cy, rx, ry)
  love.graphics.polygon(modo, cx, cy - ry, cx + rx, cy, cx, cy + ry, cx - rx, cy)
end

local function placa(tipo, px, py)
  local cx, cy = px + TILE / 2, py + TILE / 2
  love.graphics.setColor(0.05, 0.045, 0.06, 0.9)
  rombo("fill", cx, cy, 21, 10.5)
  local c = tipo == "pinchos" and { 0.36, 0.37, 0.43 } or (tipo == "fuego" and { 0.45, 0.16, 0.08 } or { 0.2, 0.36, 0.2 })
  love.graphics.setColor(c[1], c[2], c[3], 1)
  rombo("line", cx, cy, 21, 10.5)
  love.graphics.setColor(c[1] * 0.55, c[2] * 0.55, c[3] * 0.55, 1)
  rombo("fill", cx, cy, 14, 7)
  if tipo == "pinchos" then
    love.graphics.setColor(c[1], c[2], c[3], 1)
    for i = -1, 1, 2 do
      for j = -1, 1, 2 do love.graphics.circle("fill", cx + i * 7, cy + j * 3.5, 1.6) end
    end
  end
end

local function pinchos(px, py, alto, brillo)
  for i = 0, 1 do
    for j = 0, 1 do
      local bx, by = px + 10 + i * 12, py + 14 + j * 12
      love.graphics.setColor(0.55 * brillo, 0.57 * brillo, 0.62 * brillo, 1)
      love.graphics.polygon("fill", bx - 3, by, bx + 3, by, bx, by - alto)
      love.graphics.setColor(0.9, 0.92, 1, 1)
      love.graphics.line(bx, by - alto, bx, by - alto * 0.4)
    end
  end
end

local function llamas(px, py, intensidad, t)
  love.graphics.setColor(1, 0.45, 0.1, 0.28 * intensidad)
  love.graphics.circle("fill", px + 16, py + 18, 20 * intensidad)
  for i = -1, 1 do
    local alto = (12 + 8 * math.sin(t * 9 + i * 2)) * intensidad
    local bx = px + 16 + i * 7
    love.graphics.setColor(1, 0.35, 0.08, 0.9)
    love.graphics.polygon("fill", bx - 5, py + 22, bx + 5, py + 22, bx + math.sin(t * 7 + i) * 2, py + 22 - alto - 8 * intensidad)
    love.graphics.setColor(1, 0.85, 0.3, 0.95)
    love.graphics.polygon("fill", bx - 3, py + 22, bx + 3, py + 22, bx, py + 22 - alto)
  end
end

local function gas(px, py, intensidad, t)
  for i = 1, 4 do
    local a = t * 1.5 + i * 1.7
    love.graphics.setColor(0.4, 0.85, 0.35, 0.28 * intensidad)
    love.graphics.circle("fill", px + 16 + math.cos(a) * 7, py + 16 + math.sin(a * 1.3) * 7 - 4 * intensidad, 8 + 4 * intensidad)
  end
end

-- Dibuja las trampas visibles. (camx, camy) es la esquina del encuadre en píxeles y (ancho, alto) su tamaño.
function T.dibujar(mapa, tiempo, camx, camy, ancho, alto)
  local lista = mapa.trampas
  if not lista then return end
  local x0, y0, x1, y1 = Iso.rango(camx, camy, ancho, alto, 1)
  for _, tr in ipairs(lista) do
    if tr.x >= x0 and tr.x <= x1 and tr.y >= y0 and tr.y <= y1 then
      local gx, gy = Iso.suelo(tr.x + 0.5, tr.y + 0.5)
      local px, py = gx - camx - TILE / 2, gy - camy - TILE / 2
      local fase = Mazmorras.faseTrampa(tr, tiempo)
      placa(tr.tipo, px, py)
      if fase == "aviso" then
        -- parpadea para avisar
        local parpadeo = 0.5 + 0.5 * math.sin(tiempo * 14)
        if tr.tipo == "pinchos" then pinchos(px, py, 4 + 3 * parpadeo, 0.8)
        elseif tr.tipo == "fuego" then llamas(px, py, 0.25 + 0.25 * parpadeo, tiempo)
        else gas(px, py, 0.4 + 0.3 * parpadeo, tiempo) end
      elseif fase == "activa" then
        if tr.tipo == "pinchos" then pinchos(px, py, 13, 1)
        elseif tr.tipo == "fuego" then llamas(px, py, 1, tiempo)
        else gas(px, py, 1, tiempo) end
      end
    end
  end
end

return T
