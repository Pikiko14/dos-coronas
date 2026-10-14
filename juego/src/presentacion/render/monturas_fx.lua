-- Efectos de las monturas vistosas (las nuevas de la cuadra y del Item Mall): un aura en el suelo, alas animadas
-- y partículas (estrellas, llamas, copos, rayos, humo, destellos) que giran y suben alrededor de la montura.
-- Se dibujan en el mundo, junto al jinete: "detras" antes de la montura y "delante" después. Las alas son hojas
-- generadas con herramientas/generar_clases (Characters/Alas_<tipo>.png, 3 cuadros de 64 x 64 de un ala izquierda).
local Arte = require("src.presentacion.render.arte")

local F = {}

local pi, sin, cos, floor = math.pi, math.sin, math.cos, math.floor

-- aura: color del resplandor del suelo; alas: tipo de alas; halo: aro de luz sobre el jinete; capa de cada
-- partícula: "detras" (humo y nubes, que no tapan) o "delante" (brillos).
F.def = {
  unicornio = {
    aura = { 1, 0.95, 0.7 },
    part = { tipo = "estrella", n = 9, c = { { 1, 0.95, 0.55 }, { 0.75, 0.9, 1 } }, radio = 19, alto = 36, vel = 0.45, tam = 3.4 },
  },
  lobo_ascua = {
    aura = { 1, 0.45, 0.12 },
    part = { tipo = "llama", n = 11, c = { { 1, 0.85, 0.3 }, { 1, 0.4, 0.08 } }, radio = 13, alto = 24, vel = 0.85, tam = 4.2 },
  },
  lobo_escarcha = {
    aura = { 0.5, 0.85, 1 },
    part = { tipo = "copo", n = 12, c = { { 0.9, 0.97, 1 }, { 0.55, 0.8, 1 } }, radio = 20, alto = 34, vel = 0.4, tam = 3.2, cae = true },
  },
  toro_trueno = {
    aura = { 0.45, 0.55, 1 },
    part = { tipo = "rayo", n = 5, c = { { 0.92, 0.96, 1 }, { 0.5, 0.62, 1 } }, radio = 20, alto = 26, vel = 1.5, tam = 11 },
  },
  pegaso = {
    aura = { 0.75, 0.86, 1 }, alas = "pegaso",
    part = { tipo = "nube", n = 6, c = { { 1, 1, 1 } }, radio = 16, alto = 18, vel = 0.35, tam = 5, capa = "detras" },
  },
  fenix = {
    aura = { 1, 0.5, 0.1 }, alas = "fenix",
    part = { tipo = "llama", n = 14, c = { { 1, 0.9, 0.35 }, { 1, 0.35, 0.05 } }, radio = 20, alto = 34, vel = 0.9, tam = 4.5 },
  },
  corcel_astral = {
    aura = { 0.55, 0.4, 1 }, halo = { 0.7, 0.6, 1 },
    part = { tipo = "estrella", n = 15, c = { { 0.85, 0.75, 1 }, { 0.5, 0.9, 1 }, { 1, 1, 1 } }, radio = 21, alto = 40, vel = 0.4, tam = 3.4 },
  },
  dragon_hielo = {
    aura = { 0.5, 0.9, 1 },
    part = { tipo = "copo", n = 14, c = { { 0.9, 0.97, 1 }, { 0.5, 0.85, 1 } }, radio = 26, alto = 46, vel = 0.4, tam = 3.6, cae = true },
  },
  dragon_sombra = {
    aura = { 0.5, 0.2, 0.8 },
    part = { tipo = "humo", n = 9, c = { { 0.18, 0.08, 0.28 }, { 0.38, 0.12, 0.55 } }, radio = 22, alto = 40, vel = 0.5, tam = 8, capa = "detras" },
  },
  gargola_oro = {
    aura = { 1, 0.85, 0.3 },
    part = { tipo = "estrella", n = 12, c = { { 1, 0.9, 0.35 }, { 1, 0.97, 0.7 } }, radio = 20, alto = 34, vel = 0.55, tam = 3 },
  },
}

local function azar(i, sal)
  local n = (i * 73856093 + (sal or 0) * 19349663) % 2147483647
  n = (n * 1103515245 + 12345) % 2147483647
  return (n % 10007) / 10007
end

local function mezcla(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end

-- Resplandor suave: varios círculos concéntricos con mezcla aditiva.
local function brillo(x, y, r, c, a)
  for k = 1, 4 do
    love.graphics.setColor(c[1], c[2], c[3], a * 0.2 * (5 - k) / 4)
    love.graphics.circle("fill", x, y, r * k / 4)
  end
end

local function estrella(x, y, r, c, a, rot)
  brillo(x, y, r * 1.6, c, a * 0.55)
  love.graphics.setColor(1, 1, 1, a)
  for k = 0, 1 do
    local ang = rot + k * pi / 2
    local ca, sa = cos(ang), sin(ang)
    local px, py = -sa, ca
    love.graphics.polygon("fill", x + ca * r, y + sa * r, x + px * r * 0.2, y + py * r * 0.2, x - ca * r, y - sa * r, x - px * r * 0.2, y - py * r * 0.2)
  end
  love.graphics.setColor(c[1], c[2], c[3], a * 0.9)
  love.graphics.circle("fill", x, y, r * 0.32)
end

local function llama(x, y, r, c, a, vida)
  -- gota de fuego: más roja y pequeña a medida que sube
  local col = mezcla(c[1], c[2], vida)
  brillo(x, y, r * 1.5, col, a * 0.6)
  love.graphics.setColor(col[1], col[2], col[3], a)
  love.graphics.polygon("fill", x - r * 0.6, y, x, y - r * 1.9, x + r * 0.6, y, x, y + r * 0.5)
  love.graphics.setColor(1, 0.95, 0.7, a * 0.8)
  love.graphics.polygon("fill", x - r * 0.25, y, x, y - r * 0.9, x + r * 0.25, y)
end

local function copo(x, y, r, c, a, rot)
  love.graphics.setColor(c[1], c[2], c[3], a)
  love.graphics.setLineWidth(1)
  for k = 0, 2 do
    local ang = rot + k * pi / 3
    love.graphics.line(x + cos(ang) * r, y + sin(ang) * r, x - cos(ang) * r, y - sin(ang) * r)
  end
  love.graphics.setColor(1, 1, 1, a)
  love.graphics.circle("fill", x, y, r * 0.3)
end

local function rayo(x, y, largo, c, a, semilla)
  -- zigzag de arriba hacia abajo desde (x, y)
  local px, py = x, y
  love.graphics.setLineWidth(2)
  love.graphics.setColor(c[1], c[2], c[3], a * 0.8)
  local pts = { x, y }
  for k = 1, 5 do
    px = px + (azar(semilla, k) - 0.5) * 10
    py = py + largo / 5
    pts[#pts + 1] = px
    pts[#pts + 1] = py
  end
  love.graphics.line(pts)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(1, 1, 1, a)
  love.graphics.line(pts)
end

local function humo(x, y, r, c, a)
  love.graphics.setColor(c[1], c[2], c[3], a)
  love.graphics.circle("fill", x, y, r)
  love.graphics.setColor(c[1] * 0.6, c[2] * 0.6, c[3] * 0.6, a * 0.7)
  love.graphics.circle("fill", x + r * 0.3, y + r * 0.2, r * 0.7)
end

local function nube(x, y, r, c, a)
  love.graphics.setColor(c[1], c[2], c[3], a)
  love.graphics.circle("fill", x, y, r)
  love.graphics.circle("fill", x - r * 0.8, y + r * 0.25, r * 0.7)
  love.graphics.circle("fill", x + r * 0.8, y + r * 0.2, r * 0.75)
end

-- Una capa de partículas de la montura. sx, pies = pies de la montura; esc = escala de la montura.
local function particulas(d, sx, pies, t, esc, capa)
  local p = d.part
  if not p or (p.capa or "delante") ~= capa then return end
  for i = 0, p.n - 1 do
    local fase = (t * p.vel + i / p.n + azar(i, 3) * 0.2) % 1
    local ang = (i / p.n) * 2 * pi + t * 0.35 + azar(i, 5) * 2
    local r = p.radio * esc * (0.55 + 0.45 * azar(i, 7))
    local x = sx + cos(ang) * r
    local alto = p.alto * esc
    local y
    if p.cae then
      y = pies - alto + fase * alto * 0.95 + sin(ang) * r * 0.25
      x = x + sin(t * 2 + i) * 3
    else
      y = pies - 4 - fase * alto + sin(ang) * r * 0.3
    end
    local a = math.sin(fase * pi) ^ 0.7
    local c = p.c[(i % #p.c) + 1]
    local tam = p.tam * esc * (p.tipo == "llama" and (1 - fase * 0.5) or 1)
    if p.tipo == "estrella" then estrella(x, y, tam, c, a, t * 1.5 + i)
    elseif p.tipo == "llama" then llama(x, y, tam, p.c, a, fase)
    elseif p.tipo == "copo" then copo(x, y, tam, c, a * 0.95, t + i)
    elseif p.tipo == "humo" then humo(x, y, tam * (0.6 + fase), c, a * 0.45)
    elseif p.tipo == "nube" then nube(x, y + 4, tam * (0.7 + fase * 0.5), c, a * 0.55)
    elseif p.tipo == "rayo" then
      -- cada rayo destella un instante de su ciclo
      local u = (t * p.vel + i * 0.37) % 1
      if u < 0.22 then rayo(x, pies - alto, p.tam * esc, c, 1 - u / 0.22, floor(t * 6) + i) end
    end
  end
end

local sombras = {}
local function hojaAlas(tipo)
  local h = sombras[tipo]
  if not h then
    local img = Arte.img("Characters/Alas_" .. tipo .. ".png")
    h = { img = img, cuadros = {} }
    for k = 0, 2 do h.cuadros[k + 1] = Arte.quad(img, k * 64, 0, 64, 64) end
    sombras[tipo] = h
  end
  return h
end

local function alas(d, sx, pies, dir, t, esc)
  local h = hojaAlas(d.alas)
  local k = ({ 1, 2, 3, 2 })[floor(t * 5) % 4 + 1]
  local hombro = pies - 17 * esc
  love.graphics.setColor(1, 1, 1, 1)
  if dir == 1 or dir == 2 then
    -- de frente o de espaldas: una a cada lado
    love.graphics.draw(h.img, h.cuadros[k], sx - 3, hombro, 0, 1, 1, 50, 46)
    love.graphics.draw(h.img, h.cuadros[k], sx + 3, hombro, 0, -1, 1, 50, 46)
  elseif dir == 3 then
    love.graphics.draw(h.img, h.cuadros[k], sx - 1, hombro, 0, 1, 1, 50, 46)
  else
    love.graphics.draw(h.img, h.cuadros[k], sx + 1, hombro, 0, -1, 1, 50, 46)
  end
end

function F.tiene(id) return F.def[id] ~= nil end

-- Antes de la montura: aura, alas y las partículas "detrás".
function F.detras(id, sx, pies, dir, t, esc)
  local d = F.def[id]
  if not d then return end
  esc = esc or 1
  if d.aura then
    love.graphics.setBlendMode("add")
    local pulso = 0.8 + 0.2 * sin(t * 3)
    for k = 1, 4 do
      love.graphics.setColor(d.aura[1], d.aura[2], d.aura[3], 0.08 * pulso * (5 - k))
      love.graphics.ellipse("fill", sx, pies - 1, (14 + k * 4) * esc, (6 + k * 1.6) * esc)
    end
    love.graphics.setBlendMode("alpha")
  end
  if d.alas then alas(d, sx, pies, dir, t, esc) end
  particulas(d, sx, pies, t, esc, "detras")
end

-- Después del jinete: halo y partículas que brillan por delante.
function F.delante(id, sx, pies, dir, t, esc, altoJinete)
  local d = F.def[id]
  if not d then return end
  esc = esc or 1
  love.graphics.setBlendMode("add")
  if d.halo then
    local y = pies - (altoJinete or 44) - 4
    local pulso = 0.7 + 0.3 * sin(t * 4)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(d.halo[1], d.halo[2], d.halo[3], 0.75 * pulso)
    love.graphics.ellipse("line", sx, y, 11, 4)
    love.graphics.setColor(1, 1, 1, 0.5 * pulso)
    love.graphics.ellipse("line", sx, y, 9, 3)
    love.graphics.setLineWidth(1)
  end
  particulas(d, sx, pies, t, esc, "delante")
  love.graphics.setBlendMode("alpha")
end

-- Vista previa para los paneles (cuadra y mall): el mismo efecto alrededor de un punto.
function F.vista(id, x, y, t, esc)
  F.detras(id, x, y, 1, t, esc)
  F.delante(id, x, y, 1, t, esc, 0)
end

return F
