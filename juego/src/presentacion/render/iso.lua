-- Proyección isométrica del mapa. El mundo sigue siendo una cuadrícula (x, y en casillas, como en el servidor); solo cambia cómo se
-- dibuja: cada casilla es un rombo de 2*HW x 2*HH píxeles, x crece hacia abajo a la derecha e y hacia abajo a la izquierda.
-- Con DC_ISO=0 (o Ajustes.mapaIso = false) todo vuelve a la vista cenital de antes.
local Ajustes = require("src.presentacion.ajustes")

local I = {}
local TILE = 32
I.HW, I.HH = 24, 12          -- medio rombo: 48 x 24 píxeles por casilla
I.PIES = 12                  -- los personajes se dibujan con los pies 12 px por debajo de la posición que devuelve I.pos

local activo
local forzado        -- nil: lo que diga la configuración; false: vista cenital (los mapas de FAO, que ya vienen en vista cenital)
function I.forzar(v) forzado = v end
function I.activo()
  if forzado ~= nil then return forzado end
  if activo == nil then
    local env = os.getenv("DC_ISO")
    if env == "0" then activo = false
    elseif Ajustes.mapaIso == false then activo = false
    else activo = true end
  end
  return activo
end

-- Punto del suelo (en píxeles de mundo, sin restar la cámara) bajo el centro de la casilla (x, y).
function I.suelo(x, y)
  if I.activo() then return (x - y) * I.HW, (x + y) * I.HH end
  return x * TILE, y * TILE
end

-- Dónde se dibuja un personaje o criatura: sus pies quedan en I.suelo (vista isométrica) o 12 px bajo el centro (vista cenital).
function I.pos(x, y)
  if I.activo() then return (x - y) * I.HW, (x + y) * I.HH - I.PIES end
  return x * TILE, y * TILE
end

-- Del suelo en píxeles a casillas (inversa de I.suelo).
function I.inversa(gx, gy)
  if I.activo() then
    local a, b = gx / I.HW, gy / I.HH      -- a = x - y, b = x + y
    return (a + b) / 2, (b - a) / 2
  end
  return gx / TILE, gy / TILE
end

-- Casillas (mínimo y máximo de x e y) que cubre un encuadre de (ancho x alto) píxeles con la esquina en (camX, camY).
function I.rango(camX, camY, ancho, alto, margen)
  margen = margen or 1
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, c in ipairs({ { camX, camY }, { camX + ancho, camY }, { camX, camY + alto }, { camX + ancho, camY + alto } }) do
    local x, y = I.inversa(c[1], c[2])
    x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
  end
  return math.floor(x0) - margen, math.floor(y0) - margen, math.ceil(x1) + margen, math.ceil(y1) + margen
end

-- Radio (en casillas, alrededor del jugador) que hay que mirar para cubrir el encuadre.
function I.radio(ancho, alto)
  if I.activo() then return math.ceil((ancho / I.HW + alto / I.HH) / 2) + 3 end
  return math.ceil(math.max(ancho, alto) / TILE) + 3
end

-- Empuja una transformación tal que lo que se dibuja en píxeles de mundo CENITALES (x * 32, y * 32, valores absolutos) queda
-- proyectado y con la cámara restada: sirve para todo lo que va pegado al suelo (marcas, zonas, sombras, rombos).
function I.empujar(cam)
  love.graphics.push()
  if I.activo() then
    local k, h = I.HW / TILE, I.HH / TILE
    local t = love.math.newTransform()
    t:setMatrix("row", k, -k, 0, -cam.x, h, h, 0, -cam.y, 0, 0, 1, 0, 0, 0, 0, 1)
    love.graphics.applyTransform(t)
  else
    love.graphics.translate(-cam.x, -cam.y)
  end
end

function I.sacar() love.graphics.pop() end

-- Ángulo en la pantalla de una dirección del mundo (dx, dy); en vista cenital es el mismo.
function I.angulo(dx, dy)
  if not I.activo() then return math.atan2(dy, dx) end
  return math.atan2((dx + dy) * I.HH, (dx - dy) * I.HW)
end

-- Vector unitario en la pantalla de una dirección del mundo.
function I.vector(dx, dy)
  if not I.activo() then return dx, dy end
  local sx, sy = (dx - dy) * I.HW, (dx + dy) * I.HH
  local n = math.sqrt(sx * sx + sy * sy)
  if n < 1e-6 then return 0, 0 end
  return sx / n, sy / n
end

-- Dirección en que se ve a alguien que se mueve con velocidad (vx, vy) del mundo: 1 abajo, 2 arriba, 3 derecha, 4 izquierda, según
-- hacia dónde va en la pantalla. Devuelve nil si apenas se mueve.
function I.dirPantalla(vx, vy)
  if not I.activo() then return nil end
  local sx, sy = (vx - vy) * I.HW, (vx + vy) * I.HH
  if math.abs(sx) + math.abs(sy) < 0.5 then return nil end
  if math.abs(sx) >= math.abs(sy) * 1.6 then return sx > 0 and 3 or 4 end
  return sy > 0 and 1 or 2
end

return I
