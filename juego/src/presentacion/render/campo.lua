-- Sprites propios del campo de batalla, dibujados por código (no hay hojas de arte para esto):
-- peñascos, riscos (crestas de montaña), huecos con borde y marcas en el suelo (manchas de quemado,
-- brasas, guijarros, grietas finas). Se generan una vez en lienzos y se reutilizan.
local Objetos = require("src.presentacion.render.objetos")
local MapaFao = require("src.presentacion.render.mapa_fao")

local C = {}

local TILE = 32
local cache = {}

-- Pinta con una función en un lienzo transparente de w x h y devuelve la imagen.
local function lienzo(w, h, pintar)
  local cv = love.graphics.newCanvas(w, h)
  local anterior = love.graphics.getCanvas()
  love.graphics.push("all")
  love.graphics.setCanvas(cv)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.origin()
  love.graphics.setBlendMode("alpha")
  pintar()
  love.graphics.pop()
  love.graphics.setCanvas(anterior)
  cv:setFilter("nearest", "nearest")
  return cv
end

local function poligono(modo, pts, r, g, b, a)
  love.graphics.setColor(r, g, b, a or 1)
  love.graphics.polygon(modo, pts)
end

-- Polígono irregular alrededor de (cx, cy) con radios (rx, ry) y n puntos, con ruido repetible.
local function irregular(rng, cx, cy, rx, ry, n, ruido)
  local pts = {}
  for i = 0, n - 1 do
    local a = (i / n) * math.pi * 2
    local k = 1 - (ruido or 0.25) * rng:random()
    pts[#pts + 1] = cx + math.cos(a) * rx * k
    pts[#pts + 1] = cy + math.sin(a) * ry * k
  end
  return pts
end

-- ---------------------------------------------------------------- peñasco (cabe en una casilla)
local function penasco(variante)
  local clave = "pen" .. variante
  if cache[clave] then return cache[clave] end
  local rng = love.math.newRandomGenerator(100 + variante * 17)
  local img = lienzo(40, 40, function()
    -- sombra en el suelo
    love.graphics.setColor(0, 0, 0, 0.32)
    love.graphics.ellipse("fill", 21, 33, 15, 5)
    -- masa de roca: base oscura, luego caras iluminadas
    local sx = 1 + 0.12 * (variante % 3)
    local pts = irregular(rng, 20, 22, 14 * sx, 11, 9, 0.28)
    poligono("fill", pts, 0.30, 0.22, 0.21)
    local claro = irregular(rng, 18, 19, 10 * sx, 7.5, 8, 0.3)
    poligono("fill", claro, 0.50, 0.40, 0.36)
    local brillo = irregular(rng, 15, 16, 5.5, 3.5, 7, 0.3)
    poligono("fill", brillo, 0.68, 0.57, 0.50, 0.9)
    -- grietas y borde oscuro
    love.graphics.setColor(0.14, 0.1, 0.1, 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.line(22, 14, 25, 21, 23, 27)
    love.graphics.line(13, 25, 17, 28)
    poligono("line", pts, 0.12, 0.08, 0.08, 0.9)
  end)
  cache[clave] = img
  return img
end

-- ---------------------------------------------------------------- risco: cresta de montaña (2x2 casillas)
local function risco(variante, lado)
  local clave = "risco" .. variante .. lado
  if cache[clave] then return cache[clave] end
  local rng = love.math.newRandomGenerator(900 + variante * 31)
  local tinte = lado == "umbra" and { 0.86, 0.80, 0.98 } or { 1, 0.95, 0.88 }
  local w, h = 80, 96
  local img = lienzo(w, h, function()
    -- sombra larga hacia la derecha
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.polygon("fill", 6, 86, 70, 86, 78, 92, 14, 94)
    -- cuerpo: picos escalonados
    local picos = {
      { 8, 84 }, { 6, 62 }, { 16, 52 }, { 22, 30 }, { 32, 44 }, { 40, 14 + 6 * (variante % 2) }, { 50, 40 },
      { 58, 26 }, { 66, 50 }, { 74, 60 }, { 72, 84 },
    }
    local flat = {}
    for _, p in ipairs(picos) do
      flat[#flat + 1] = p[1]
      flat[#flat + 1] = p[2]
    end
    poligono("fill", flat, 0.27 * tinte[1], 0.20 * tinte[2], 0.20 * tinte[3])
    -- cara iluminada (izquierda de cada pico)
    local luz = { 8, 84, 6, 62, 16, 52, 22, 30, 32, 44, 40, 20, 40, 60, 30, 84 }
    poligono("fill", luz, 0.46 * tinte[1], 0.36 * tinte[2], 0.33 * tinte[3])
    local luz2 = { 40, 20, 50, 40, 58, 26, 56, 62, 44, 84, 40, 60 }
    poligono("fill", luz2, 0.40 * tinte[1], 0.31 * tinte[2], 0.29 * tinte[3])
    -- zona de sombra a la derecha
    local sombra = { 50, 40, 58, 26, 66, 50, 74, 60, 72, 84, 56, 84, 56, 62 }
    poligono("fill", sombra, 0.18 * tinte[1], 0.13 * tinte[2], 0.14 * tinte[3])
    -- nieve de ceniza en los picos
    poligono("fill", { 22, 30, 27, 38, 22, 40, 18, 44 }, 0.8, 0.76, 0.72, 0.85)
    poligono("fill", { 40, 20, 45, 30, 40, 31, 36, 28 }, 0.85, 0.8, 0.76, 0.9)
    -- estratos y grietas
    love.graphics.setColor(0.1, 0.07, 0.08, 0.7)
    love.graphics.setLineWidth(1)
    for _ = 1, 7 do
      local x = 10 + rng:random() * 58
      local y = 40 + rng:random() * 40
      love.graphics.line(x, y, x + 5 + rng:random() * 8, y + 3 + rng:random() * 4)
    end
    -- base con piedras sueltas
    love.graphics.setColor(0.2, 0.15, 0.15, 1)
    for i = 0, 5 do love.graphics.ellipse("fill", 10 + i * 12, 86, 6, 3) end
    love.graphics.setColor(0.08, 0.06, 0.07, 0.9)
    love.graphics.polygon("line", flat)
  end)
  cache[clave] = img
  return img
end

-- ---------------------------------------------------------------- hueco (cráter) por casillas con borde
-- Cada casilla se pinta según sus vecinas: donde no hay hueco al lado se dibuja el borde del cráter.
function C.hueco(mapa, x, y, px, py)
  local d = mapa.decorado
  local function es(dx, dy) return d[x + dx] and d[x + dx][y + dy] == "grieta" end
  local n, s, o, e = es(0, -1), es(0, 1), es(-1, 0), es(1, 0)
  -- pared interior sombreada y fondo del pozo (marrón rojizo muy oscuro, no negro plano)
  love.graphics.setColor(0.17, 0.09, 0.08, 1)
  love.graphics.rectangle("fill", px, py, TILE, TILE)
  love.graphics.setColor(0.07, 0.035, 0.04, 1)
  love.graphics.rectangle("fill", px + (o and 0 or 4), py + (n and 0 or 6), TILE - (o and 0 or 4) - (e and 0 or 4), TILE - (n and 0 or 6) - (s and 0 or 3))
  -- brillo tenue de magma en un punto distinto por casilla (para que no parezca una cuadrícula)
  local gx, gy = 8 + ((x * 7 + y * 3) % 5) * 4, 14 + ((x * 5 + y * 11) % 3) * 4
  love.graphics.setColor(0.8, 0.28, 0.1, 0.16)
  love.graphics.ellipse("fill", px + gx, py + gy, 9, 5)
  love.graphics.setColor(1, 0.5, 0.15, 0.2)
  love.graphics.ellipse("fill", px + gx, py + gy, 4, 2.2)
  -- sombra que cae de la pared norte dentro del hueco
  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.rectangle("fill", px, py, TILE, n and 0 or 10)
  -- labio de tierra en los lados abiertos: tierra clara arriba (le da la luz) y oscura abajo
  local claro, medio, oscuro = { 0.68, 0.46, 0.33 }, { 0.5, 0.33, 0.25 }, { 0.3, 0.19, 0.15 }
  if not n then
    love.graphics.setColor(claro[1], claro[2], claro[3], 1); love.graphics.rectangle("fill", px, py, TILE, 4)
    love.graphics.setColor(medio[1], medio[2], medio[3], 1); love.graphics.rectangle("fill", px, py + 4, TILE, 2)
  end
  if not o then love.graphics.setColor(medio[1], medio[2], medio[3], 1) love.graphics.rectangle("fill", px, py, 4, TILE) end
  if not e then love.graphics.setColor(oscuro[1], oscuro[2], oscuro[3], 1) love.graphics.rectangle("fill", px + TILE - 4, py, 4, TILE) end
  if not s then
    love.graphics.setColor(oscuro[1], oscuro[2], oscuro[3], 1); love.graphics.rectangle("fill", px, py + TILE - 5, TILE, 5)
    love.graphics.setColor(0, 0, 0, 0.35); love.graphics.rectangle("fill", px, py + TILE - 1, TILE, 1)
  end
  -- esquinas: la tierra redondea el pozo
  love.graphics.setColor(medio[1], medio[2], medio[3], 1)
  if not n and not o then love.graphics.polygon("fill", px, py, px + 10, py, px, py + 10) end
  if not n and not e then love.graphics.polygon("fill", px + TILE, py, px + TILE - 10, py, px + TILE, py + 10) end
  love.graphics.setColor(oscuro[1], oscuro[2], oscuro[3], 1)
  if not s and not o then love.graphics.polygon("fill", px, py + TILE, px + 10, py + TILE, px, py + TILE - 10) end
  if not s and not e then love.graphics.polygon("fill", px + TILE, py + TILE, px + TILE - 10, py + TILE, px + TILE, py + TILE - 10) end
end

-- ---------------------------------------------------------------- marcas del suelo (sin colisión)
local function marca(clave, semilla, pintar)
  if cache[clave] then return cache[clave] end
  local rng = love.math.newRandomGenerator(semilla)
  cache[clave] = lienzo(40, 28, function() pintar(rng) end)
  return cache[clave]
end

local function mancha(variante)
  return marca("mancha" .. variante, 400 + variante, function(rng)
    for i = 1, 3 do
      local pts = irregular(rng, 14 + rng:random() * 14, 12 + rng:random() * 6, 7 + rng:random() * 7, 4 + rng:random() * 4, 8, 0.35)
      poligono("fill", pts, 0.10, 0.05, 0.05, 0.28)
    end
    love.graphics.setColor(0.2, 0.1, 0.08, 0.22)
    love.graphics.ellipse("fill", 20, 14, 12, 6)
  end)
end

local function brasas(variante)
  return marca("brasas" .. variante, 500 + variante, function(rng)
    for _ = 1, 6 do
      local x, y = 6 + rng:random() * 28, 6 + rng:random() * 16
      love.graphics.setColor(1, 0.5, 0.15, 0.25)
      love.graphics.circle("fill", x, y, 3)
      love.graphics.setColor(1, 0.8, 0.3, 0.95)
      love.graphics.circle("fill", x, y, 1.1)
    end
  end)
end

local function guijarros(variante)
  return marca("guij" .. variante, 600 + variante, function(rng)
    for _ = 1, 5 do
      local x, y = 6 + rng:random() * 26, 8 + rng:random() * 14
      love.graphics.setColor(0, 0, 0, 0.3)
      love.graphics.ellipse("fill", x + 1, y + 2, 3.5, 1.6)
      love.graphics.setColor(0.4 + rng:random() * 0.15, 0.32, 0.28)
      love.graphics.ellipse("fill", x, y, 3, 2.2)
      love.graphics.setColor(0.62, 0.52, 0.46, 0.9)
      love.graphics.ellipse("fill", x - 0.8, y - 0.8, 1.2, 0.8)
    end
  end)
end

local function grietita(variante)
  return marca("griet" .. variante, 700 + variante, function(rng)
    love.graphics.setColor(0.12, 0.06, 0.06, 0.85)
    love.graphics.setLineWidth(1.4)
    local x, y = 6 + rng:random() * 8, 8 + rng:random() * 10
    local pts = { x, y }
    for _ = 1, 5 do
      x = x + 4 + rng:random() * 4
      y = y + (rng:random() - 0.5) * 7
      pts[#pts + 1] = x
      pts[#pts + 1] = y
    end
    love.graphics.line(pts)
    love.graphics.setColor(0.9, 0.35, 0.12, 0.3)
    love.graphics.setLineWidth(0.8)
    love.graphics.line(pts)
  end)
end

local function huesos(variante)
  return marca("huesos" .. variante, 800 + variante, function(rng)
    love.graphics.setColor(0.86, 0.82, 0.72, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(8, 16, 24, 12)
    love.graphics.line(10, 10, 26, 18)
    love.graphics.circle("fill", 8, 16, 2); love.graphics.circle("fill", 24, 12, 2)
    love.graphics.circle("fill", 10, 10, 2); love.graphics.circle("fill", 26, 18, 2)
    love.graphics.setColor(0.9, 0.86, 0.78, 1)
    love.graphics.ellipse("fill", 30, 14, 5, 4)
    love.graphics.setColor(0.2, 0.15, 0.12, 1)
    love.graphics.circle("fill", 28.5, 13.5, 1.1); love.graphics.circle("fill", 31.5, 13.5, 1.1)
  end)
end

-- Dibuja una decoración del campo de batalla en la casilla (x, y) cuya esquina está en (px, py).
function C.decoracion(mapa, tipo, x, y, px, py)
  local v = (x * 7 + y * 13) % 4
  -- arte de mapa FAO: las piedras y grietas (con colisión) se dibujan como rocas de pie (props, ver MapaFao.decorProps); el resto son
  -- marcas del suelo que se hornean en el bloque
  if MapaFao.activo() then
    if tipo == "grieta" or tipo == "piedra" then return end
    if MapaFao.tiene(tipo) and MapaFao.dibujar(tipo, x * 7 + y * 13, px + 16, py + 31, nil, nil, nil, true) then return end
  end
  if tipo == "grieta" then return C.hueco(mapa, x, y, px, py) end
  local img
  local ox, oy
  if tipo == "piedra" then
    img, ox, oy = penasco(v), 20, 36
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, px + 16, py + 32, 0, 1, 1, ox, oy)
    return
  elseif tipo == "mancha" then img = mancha(v)
  elseif tipo == "brasas" then img = brasas(v)
  elseif tipo == "guijarros" then img = guijarros(v)
  elseif tipo == "grietita" then img = grietita(v)
  elseif tipo == "restos" then img = huesos(v)
  else return end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(img, px + 16, py + 16, 0, 1, 1, 20, 14)
end

-- Cresta de montaña del campo de batalla (prop de 2x2 casillas); (sx, sy) es el centro inferior.
function C.risco(p, sx, sy)
  local v = (p.x * 5 + p.y * 11) % 3
  local img = risco(v, p.tipo == "risco_umbra" and "umbra" or "albor")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(img, sx, sy + 6, 0, 1, 1, 40, 90)
end

-- Se registran como objetos personalizados para que Dibujo los pinte como cualquier prop.
Objetos.personalizados = Objetos.personalizados or {}
Objetos.personalizados.risco_albor = function(p, sx, sy) C.risco(p, sx, sy) end
Objetos.personalizados.risco_umbra = function(p, sx, sy) C.risco(p, sx, sy) end

function C.olvidar() cache = {} end

return C
