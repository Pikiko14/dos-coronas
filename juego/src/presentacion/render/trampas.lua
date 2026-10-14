-- Trampas del suelo de las mazmorras (pinchos, fuego y gas), dibujadas por código sobre el terreno. Su ciclo
-- (reposo, aviso y activa) depende solo del reloj del mundo, igual que en el servidor (Mazmorras.faseTrampa).
local Mazmorras = require("compartido.dominio.mazmorras")

local T = {}

local TILE = 32

local function placa(tipo, px, py)
  love.graphics.setColor(0.07, 0.06, 0.08, 0.85)
  love.graphics.rectangle("fill", px + 2, py + 2, TILE - 4, TILE - 4, 3, 3)
  if tipo == "pinchos" then
    love.graphics.setColor(0.32, 0.32, 0.38, 1)
    for i = 0, 1 do
      for j = 0, 1 do love.graphics.circle("fill", px + 10 + i * 12, py + 10 + j * 12, 2) end
    end
  elseif tipo == "fuego" then
    love.graphics.setColor(0.32, 0.12, 0.08, 1)
    love.graphics.circle("fill", px + 16, py + 16, 8)
    love.graphics.setColor(0.12, 0.06, 0.05, 1)
    love.graphics.circle("fill", px + 16, py + 16, 5)
  else
    love.graphics.setColor(0.14, 0.26, 0.15, 1)
    love.graphics.circle("fill", px + 16, py + 16, 8)
    love.graphics.setColor(0.07, 0.12, 0.08, 1)
    love.graphics.circle("fill", px + 16, py + 16, 4)
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
  local x0, x1 = camx / TILE - 1, (camx + ancho) / TILE + 1
  local y0, y1 = camy / TILE - 1, (camy + alto) / TILE + 1
  for _, tr in ipairs(lista) do
    if tr.x >= x0 and tr.x <= x1 and tr.y >= y0 and tr.y <= y1 then
      local px, py = tr.x * TILE - camx, tr.y * TILE - camy
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
