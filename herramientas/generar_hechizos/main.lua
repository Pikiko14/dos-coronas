-- Generador de los sprites de hechizos (se ejecuta una vez a mano; los PNG resultantes se guardan en
-- el repositorio y el juego los carga como cualquier otra hoja de animación):
--     ..\love\lovec.exe herramientas\generar_hechizos
-- Salida:
--   juego/arte/hojas/new-sprites/Animations/Hechizo_<poder>.png   hojas de 5 columnas x 3 filas de
--       192x192 (15 cuadros, igual que las del pack), una por poder de cada clase.
--   juego/arte/hojas/new-sprites/Animations/Proyectil_<tipo>.png  4 cuadros de 64x64 en fila, mirando a
--       la derecha, para los proyectiles en vuelo.
-- Además escribe una vista previa en %TEMP%/hechizos_previa.png.
local RAIZ = "C:/Users/User/juegos/dos-coronas/"
local SALIDA = RAIZ .. "juego/arte/hojas/new-sprites/Animations/"

local CELDA, COL, FILAS, N = 192, 5, 3, 15
local pi, sin, cos, sqrt, floor, max, min = math.pi, math.sin, math.cos, math.sqrt, math.floor, math.max, math.min

local gl
local function glowImg()
  if gl then return gl end
  local d = love.image.newImageData(64, 64)
  for y = 0, 63 do
    for x = 0, 63 do
      local dx, dy = (x - 31.5) / 32, (y - 31.5) / 32
      local r = sqrt(dx * dx + dy * dy)
      local a = max(0, 1 - r)
      a = a * a * (3 - 2 * a)
      d:setPixel(x, y, 1, 1, 1, a)
    end
  end
  gl = love.graphics.newImage(d)
  gl:setFilter("linear", "linear")
  return gl
end

local function azar(i, sal)
  local n = (i * 73856093 + (sal or 0) * 19349663) % 2147483647
  n = (n * 1103515245 + 12345) % 2147483647
  return (n % 10007) / 10007
end

local function ease(t) return 1 - (1 - t) ^ 3 end
local function suave(t) return t * t * (3 - 2 * t) end
local function clamp(v, a, b) return max(a, min(b, v)) end

-- ------------------------------------------------------------------------------ primitivas
local function color(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

local function glow(x, y, r, c, a)
  if r <= 0 or a <= 0 then return end
  color(c, a)
  love.graphics.draw(glowImg(), x, y, 0, r * 2 / 64, r * 2 / 64, 32, 32)
end

local function anillo(x, y, r, w, c, a)
  if r <= 0 or a <= 0 then return end
  love.graphics.setLineWidth(max(0.5, w))
  color(c, a)
  love.graphics.circle("line", x, y, r, 48)
end

local function elipseAnillo(x, y, rx, ry, w, c, a)
  love.graphics.setLineWidth(max(0.5, w))
  color(c, a)
  love.graphics.ellipse("line", x, y, rx, ry, 48)
end

local function linea(x0, y0, x1, y1, w, c, a)
  love.graphics.setLineWidth(max(0.5, w))
  color(c, a)
  love.graphics.line(x0, y0, x1, y1)
end

-- Destello de cuatro puntas con halo.
local function destello(x, y, r, rot, c, a, fino)
  if r <= 0 or a <= 0 then return end
  glow(x, y, r * 0.9, c, a * 0.55)
  local f = fino or 0.14
  for k = 0, 1 do
    local ang = rot + k * pi / 2
    local ca, sa = cos(ang), sin(ang)
    local px, py = -sa, ca
    color({ 1, 1, 1 }, a)
    love.graphics.polygon("fill",
      x + ca * r, y + sa * r, x + px * r * f, y + py * r * f,
      x - ca * r, y - sa * r, x - px * r * f, y - py * r * f)
    color(c, a * 0.8)
    love.graphics.polygon("fill",
      x + ca * r * 1.1, y + sa * r * 1.1, x + px * r * f * 1.7, y + py * r * f * 1.7,
      x - ca * r * 1.1, y - sa * r * 1.1, x - px * r * f * 1.7, y - py * r * f * 1.7)
  end
  glow(x, y, r * 0.28, { 1, 1, 1 }, a)
end

-- Gota/llama: lágrima que apunta hacia arriba (ang = -pi/2).
local function lengua(x, y, largo, ancho, ang, c, a)
  if largo <= 0 or a <= 0 then return end
  local ca, sa = cos(ang), sin(ang)
  local px, py = -sa, ca
  local tip = { x + ca * largo, y + sa * largo }
  color(c, a)
  love.graphics.polygon("fill",
    x + px * ancho, y + py * ancho,
    x + ca * largo * 0.45 + px * ancho * 0.85, y + sa * largo * 0.45 + py * ancho * 0.85,
    tip[1], tip[2],
    x + ca * largo * 0.45 - px * ancho * 0.85, y + sa * largo * 0.45 - py * ancho * 0.85,
    x - px * ancho, y - py * ancho)
end

local function chispas(n, cx, cy, r0, r1, t, c, sal, tam, a)
  for i = 1, n do
    local ang = azar(i, sal) * pi * 2
    local v = 0.55 + azar(i, sal + 5) * 0.45
    local r = r0 + (r1 - r0) * ease(t) * v
    local x, y = cx + cos(ang) * r, cy + sin(ang) * r
    local al = (a or 1) * (1 - t) * (0.6 + azar(i, sal + 9) * 0.4)
    glow(x, y, tam * (1 - t * 0.5) * (0.6 + azar(i, sal + 3)), c, al)
    color({ 1, 1, 1 }, al)
    love.graphics.circle("fill", x, y, max(0.6, tam * 0.18 * (1 - t)))
  end
end

local function cruz(x, y, r, w, c, a)
  color(c, a)
  love.graphics.rectangle("fill", x - r, y - w / 2, r * 2, w, w / 2, w / 2)
  love.graphics.rectangle("fill", x - w / 2, y - r, w, r * 2, w / 2, w / 2)
end

-- ------------------------------------------------------------------------------- paletas
local FUEGO1, FUEGO2, FUEGO3 = { 1, 0.28, 0.08 }, { 1, 0.62, 0.15 }, { 1, 0.92, 0.45 }
local HIELO1, HIELO2 = { 0.4, 0.75, 1 }, { 0.88, 0.97, 1 }
local ARCANO1, ARCANO2 = { 0.62, 0.38, 1 }, { 0.45, 0.85, 1 }
local SOMBRA1, SOMBRA2 = { 0.32, 0.08, 0.5 }, { 0.78, 0.38, 1 }
local SAGRADO1, SAGRADO2 = { 1, 0.85, 0.35 }, { 1, 0.98, 0.8 }
local CURA1, CURA2 = { 0.35, 0.95, 0.5 }, { 0.85, 1, 0.65 }
local ACERO = { 0.88, 0.94, 1 }
local SANGRE = { 1, 0.15, 0.2 }
local VENENO1, VENENO2 = { 0.4, 0.9, 0.25 }, { 0.8, 1, 0.45 }
local VIENTO = { 0.7, 1, 0.88 }
local ORO = { 1, 0.8, 0.3 }

-- ------------------------------------------------------------------------------- efectos
local EF = {}

-- Guerrero ------------------------------------------------------------------------------------
EF.golpe = function(t)
  local e, a = ease(t), 1 - t
  glow(96, 96, 22 + 62 * e, FUEGO2, 0.75 * a)
  glow(96, 96, 10 + 24 * (1 - t), { 1, 1, 0.9 }, a)
  anillo(96, 96, 10 + 60 * e, 5 * (1 - t) + 1, FUEGO3, a)
  anillo(96, 96, 6 + 40 * e, 3 * (1 - t) + 0.5, { 1, 1, 1 }, a * 0.8)
  for i = 0, 9 do
    local ang = i * pi / 5 + 0.2 + azar(i, 3) * 0.2
    local r0 = 12 + 34 * e
    local r1 = r0 + 14 + 26 * (1 - t) * (0.6 + azar(i, 4) * 0.6)
    linea(96 + cos(ang) * r0, 96 + sin(ang) * r0, 96 + cos(ang) * r1, 96 + sin(ang) * r1, 4 * (1 - t) + 1, i % 2 == 0 and { 1, 1, 0.85 } or FUEGO2, a)
  end
  destello(96, 96, 14 + 46 * (1 - t), 0.6, FUEGO3, a)
  chispas(8, 96, 96, 20, 70, t, FUEGO3, 11, 7, 1)
end

EF.desgarro = function(t)
  local a = t < 0.6 and 1 or (1 - t) / 0.4
  local prog = ease(min(1, t / 0.45))
  for k = 0, 2 do
    local off = (k - 1) * 22
    local x0, y0 = 44 + off, 40 + off * 0.2
    local x1, y1 = 148 + off, 152 + off * 0.2
    local px, py = x0 + (x1 - x0) * prog, y0 + (y1 - y0) * prog
    -- tajo cónico: se ensancha hasta el centro y se estrecha
    local ang = atan2 and atan2(y1 - y0, x1 - x0) or math.atan2(y1 - y0, x1 - x0)
    local nx, ny = -sin(ang), cos(ang)
    local pts = {}
    local mid = 0.5
    local function pt(f, w) return x0 + (px - x0) * f + nx * w, y0 + (py - y0) * f + ny * w end
    local a1x, a1y = pt(0, 0)
    local b1x, b1y = pt(mid, 7)
    local c1x, c1y = pt(1, 0)
    local b2x, b2y = pt(mid, -7)
    color(SANGRE, 0.85 * a)
    love.graphics.polygon("fill", a1x, a1y, b1x, b1y, c1x, c1y, b2x, b2y)
    local b3x, b3y = pt(mid, 2.5)
    local b4x, b4y = pt(mid, -2.5)
    color({ 1, 0.85, 0.85 }, a)
    love.graphics.polygon("fill", a1x, a1y, b3x, b3y, c1x, c1y, b4x, b4y)
    glow(c1x, c1y, 16, SANGRE, 0.6 * a)
  end
  -- gotas
  for i = 1, 8 do
    local x = 96 + (azar(i, 41) - 0.5) * 100
    local y = 96 + (azar(i, 42) - 0.5) * 100 + t * 40 * azar(i, 43)
    color(SANGRE, a * 0.9 * (t > 0.3 and 1 or t / 0.3))
    love.graphics.circle("fill", x, y, 2 + azar(i, 44) * 3)
  end
end

EF.furia = function(t)
  local a = t < 0.8 and 1 or (1 - t) / 0.2
  glow(96, 150, 62, FUEGO1, 0.5 * a)
  elipseAnillo(96, 150, 42 + 6 * sin(t * 12), 12, 4, FUEGO2, 0.8 * a)
  for i = 0, 8 do
    local fase = (t * 1.4 + i * 0.37) % 1
    local x = 96 + (i - 4) * 10 + sin(fase * 7 + i) * 6
    local alto = 90 * (1 - fase * 0.55)
    local ancho = 14 * (1 - fase * 0.7)
    lengua(x, 152 - fase * 24, alto, ancho, -pi / 2 + sin(fase * 6 + i) * 0.18, FUEGO1, 0.75 * a * (1 - fase * 0.6))
    lengua(x, 152 - fase * 24, alto * 0.68, ancho * 0.7, -pi / 2 + sin(fase * 6 + i) * 0.18, FUEGO2, 0.85 * a * (1 - fase * 0.6))
    lengua(x, 152 - fase * 24, alto * 0.38, ancho * 0.4, -pi / 2 + sin(fase * 6 + i) * 0.18, FUEGO3, a * (1 - fase * 0.6))
  end
  for i = 1, 14 do
    local fase = (t * 1.8 + azar(i, 51)) % 1
    glow(96 + (azar(i, 52) - 0.5) * 80, 150 - fase * 130, 4, FUEGO3, a * (1 - fase))
  end
end

EF.carga = function(t)
  local a = 1 - t * 0.7
  local e = ease(min(1, t / 0.6))
  -- estela horizontal que llega al centro y onda de choque
  local x1 = 20 + 76 * e
  color({ 0.55, 0.8, 1 }, 0.55 * a)
  love.graphics.polygon("fill", 8, 96, x1, 84, x1 + 6, 96, x1, 108)
  color({ 1, 1, 1 }, 0.9 * a)
  love.graphics.polygon("fill", 30, 96, x1, 90, x1 + 6, 96, x1, 102)
  for i = 0, 4 do
    local y = 66 + i * 15
    linea(10 + 20 * e, y, 60 + 60 * e, y, 2, { 0.8, 0.92, 1 }, 0.5 * a)
  end
  local tt = clamp((t - 0.4) / 0.6, 0, 1)
  if tt > 0 then
    local ee = ease(tt)
    anillo(96, 96, 8 + 62 * ee, 7 * (1 - tt) + 1, { 0.75, 0.9, 1 }, (1 - tt))
    glow(96, 96, 18 + 48 * ee, { 0.6, 0.85, 1 }, 0.6 * (1 - tt))
    destello(96, 96, 30 * (1 - tt) + 10, 0.8, { 0.8, 0.95, 1 }, 1 - tt)
    chispas(10, 96, 96, 14, 66, tt, { 0.8, 0.95, 1 }, 61, 5, 1)
  end
end

EF.tajo = function(t)
  local a = t < 0.75 and 1 or (1 - t) / 0.25
  local giro = ease(min(1, t / 0.75)) * pi * 2.3 - 0.8
  local seg, largo = 40, 2.3
  -- media luna con estela: ancha y brillante en la cabeza, fina y azulada en la cola
  for s = 0, seg - 1 do
    local f0, f1 = s / seg, (s + 1) / seg
    local a0, a1 = giro - largo * (1 - f0), giro - largo * (1 - f1)
    local w0, w1 = 3 + 26 * f0 ^ 1.4, 3 + 26 * f1 ^ 1.4
    local R = 66
    local al = (f1 ^ 1.3) * a
    color({ 0.45 + 0.55 * f1, 0.7 + 0.3 * f1, 1 }, al * 0.95)
    love.graphics.polygon("fill",
      96 + cos(a0) * R, 96 + sin(a0) * R, 96 + cos(a1) * R, 96 + sin(a1) * R,
      96 + cos(a1) * (R - w1), 96 + sin(a1) * (R - w1), 96 + cos(a0) * (R - w0), 96 + sin(a0) * (R - w0))
    color({ 0.5, 0.75, 1 }, al * 0.35)
    love.graphics.polygon("fill",
      96 + cos(a0) * (R + 7), 96 + sin(a0) * (R + 7), 96 + cos(a1) * (R + 7), 96 + sin(a1) * (R + 7),
      96 + cos(a1) * R, 96 + sin(a1) * R, 96 + cos(a0) * R, 96 + sin(a0) * R)
  end
  -- filo blanco y destello en la punta
  love.graphics.setLineWidth(4)
  color({ 1, 1, 1 }, a)
  love.graphics.arc("line", "open", 96, 96, 66, giro - largo * 0.5, giro, 20)
  local px, py = 96 + cos(giro) * 64, 96 + sin(giro) * 64
  destello(px, py, 28, giro + 0.4, ACERO, a, 0.12)
  glow(px, py, 26, { 0.6, 0.85, 1 }, 0.5 * a)
  chispas(12, 96, 96, 44, 84, t, ACERO, 21, 5, 0.9)
  anillo(96, 96, 72, 1.5, { 0.7, 0.9, 1 }, 0.3 * a)
end

EF.grito = function(t)
  glow(96, 96, 44 + 20 * sin(t * 14), ORO, 0.45 * (1 - t * 0.5))
  for k = 0, 2 do
    local tt = clamp((t - k * 0.16) / 0.68, 0, 1)
    if tt > 0 and tt < 1 then
      local e = ease(tt)
      anillo(96, 96, 14 + 72 * e, 10 * (1 - tt) + 2, k % 2 == 0 and ORO or FUEGO2, 0.95 * (1 - tt))
      anillo(96, 96, 14 + 72 * e, 3, { 1, 1, 0.9 }, 0.9 * (1 - tt))
      glow(96, 96, 20 + 70 * e, FUEGO2, 0.3 * (1 - tt))
    end
  end
  -- rayos de furia hacia fuera
  for i = 0, 11 do
    local ang = i * pi / 6 + t * 0.4
    local r0 = 22 + 20 * ease(t)
    local r1 = r0 + (i % 2 == 0 and 40 or 24) * (1 - t * 0.6)
    local px, py = -sin(ang), cos(ang)
    color(i % 2 == 0 and ORO or FUEGO2, 0.9 * (1 - t))
    love.graphics.polygon("fill", 96 + cos(ang) * r0 + px * 4, 96 + sin(ang) * r0 + py * 4,
      96 + cos(ang) * r1, 96 + sin(ang) * r1, 96 + cos(ang) * r0 - px * 4, 96 + sin(ang) * r0 - py * 4)
  end
  for i = 0, 7 do
    local ang = i * pi / 4 + 0.2
    local r = 30 + 44 * ease(t)
    local x, y = 96 + cos(ang) * r, 96 + sin(ang) * r * 0.8 - 26 * t
    color(i % 2 == 0 and ORO or FUEGO3, (1 - t))
    love.graphics.polygon("fill", x, y - 14, x + 10, y + 5, x, y, x - 10, y + 5)
  end
  destello(96, 96, 30 * (1 - t) + 10, t * 2, { 1, 0.9, 0.5 }, 1 - t, 0.12)
  chispas(14, 96, 96, 20, 82, t, ORO, 31, 6, 1)
end

EF.trampa = function(t)
  local ent = ease(min(1, t / 0.3))
  local a = t < 0.8 and 1 or (1 - t) / 0.2
  glow(96, 112, 70, ORO, 0.25 * a)
  glow(96, 112, 40, { 1, 0.85, 0.4 }, 0.2 * a)
  elipseAnillo(96, 112, 60, 24, 4, ORO, a)
  elipseAnillo(96, 112, 46, 18, 2, { 1, 0.95, 0.7 }, 0.8 * a)
  -- mandibulas de la trampa: dientes grandes que se cierran sobre el centro
  for i = 0, 13 do
    local ang = i * pi / 7
    local bx, by = 96 + cos(ang) * 54, 112 + sin(ang) * 21
    local cierre = 1 - 0.7 * ent
    local tx, ty = 96 + cos(ang) * 54 * cierre, 112 + sin(ang) * 21 * cierre - 34 * ent
    local px, py = -sin(ang) * 8, cos(ang) * 3.2
    color({ 0.38, 0.4, 0.46 }, a)
    love.graphics.polygon("fill", bx + px, by + py, tx, ty, bx - px, by - py)
    color({ 0.82, 0.86, 0.95 }, a)
    love.graphics.polygon("fill", bx + px * 0.5, by + py * 0.5, tx, ty, bx - px * 0.1, by - py * 0.1)
    color({ 1, 1, 1 }, 0.9 * a)
    love.graphics.polygon("fill", bx + px * 0.2, by + py * 0.2, tx, ty - 1, bx - px * 0.05, by - py * 0.05)
  end
  if t > 0.25 then
    local f = clamp((t - 0.25) / 0.3, 0, 1)
    destello(96, 96, 30 * (1 - f * 0.5) + 6, 0, { 1, 0.9, 0.5 }, a * (1 - f * 0.6), 0.12)
    anillo(96, 112, 10 + 52 * ease(f), 3 * (1 - f) + 1, { 1, 1, 0.8 }, 0.8 * (1 - f))
  end
  chispas(10, 96, 108, 14, 60, t, ORO, 141, 5, 0.9)
end

-- Mago ----------------------------------------------------------------------------------------
EF.misil = function(t)
  local e, a = ease(t), 1 - t
  glow(96, 96, 16 + 52 * e, ARCANO1, 0.7 * a)
  glow(96, 96, 8 + 20 * (1 - t), ARCANO2, a)
  anillo(96, 96, 8 + 46 * e, 3 * a + 1, ARCANO2, a)
  anillo(96, 96, 4 + 28 * e, 2 * a + 0.5, { 1, 1, 1 }, a * 0.8)
  destello(96, 96, 14 + 44 * (1 - t), t * 3, { 0.75, 0.6, 1 }, a)
  for i = 0, 5 do
    local ang = i * pi / 3 + t * 4
    local r = 18 + 38 * e
    glow(96 + cos(ang) * r, 96 + sin(ang) * r, 8 * a + 2, i % 2 == 0 and ARCANO2 or ARCANO1, a)
  end
  chispas(10, 96, 96, 16, 66, t, ARCANO2, 71, 6, 1)
end

EF.fuego = function(t)
  local e = ease(t)
  local a = t < 0.65 and 1 or (1 - t) / 0.35
  glow(96, 100, 30 + 66 * e, FUEGO1, 0.55 * a)
  for i = 0, 9 do
    local ang = i * pi / 5 + azar(i, 81)
    local r = 8 + 46 * e * (0.5 + azar(i, 82) * 0.6)
    local x, y = 96 + cos(ang) * r, 100 + sin(ang) * r * 0.8
    glow(x, y, 20 + 20 * (1 - t), FUEGO1, 0.7 * a)
    glow(x, y, 12 + 12 * (1 - t), FUEGO2, 0.8 * a)
  end
  glow(96, 100, 22 + 22 * (1 - t), FUEGO3, a)
  glow(96, 100, 10 + 10 * (1 - t), { 1, 1, 0.9 }, a)
  for i = 0, 7 do
    local ang = -pi / 2 + (i - 3.5) * 0.28
    local largo = (40 + 40 * azar(i, 83)) * e * (1 - t * 0.4)
    lengua(96 + (i - 3.5) * 6, 110, largo, 10 * (1 - t * 0.5), ang, i % 2 == 0 and FUEGO1 or FUEGO2, 0.85 * a)
  end
  anillo(96, 100, 12 + 70 * e, 5 * (1 - t) + 1, FUEGO3, 0.8 * a)
  anillo(96, 108, 18 + 84 * e, 2, { 0.35, 0.3, 0.3 }, 0.5 * a * (t > 0.3 and 1 or 0))
  chispas(14, 96, 100, 20, 84, t, FUEGO3, 85, 6, 1)
end

EF.escudo = function(t)
  local a = t < 0.7 and 1 or (1 - t) / 0.3
  local pul = 0.85 + 0.15 * sin(t * 18)
  local ent = ease(min(1, t / 0.25))
  local R = 62 * ent
  glow(96, 96, R * 1.15, ARCANO2, 0.35 * a)
  -- esfera translúcida con degradado
  for k = 5, 1, -1 do
    color({ 0.4, 0.65, 1 }, 0.07 * a)
    love.graphics.circle("fill", 96, 96, R * (k / 5))
  end
  anillo(96, 96, R, 4, ARCANO2, 0.95 * a * pul)
  anillo(96, 96, R - 6, 1.5, { 1, 1, 1 }, 0.7 * a)
  -- celdas hexagonales
  love.graphics.setLineWidth(1.5)
  for i = -3, 3 do
    for j = -3, 3 do
      local hx = 96 + (i + (j % 2) * 0.5) * 24
      local hy = 96 + j * 20.8
      local d = sqrt((hx - 96) ^ 2 + (hy - 96) ^ 2)
      if d < R - 10 then
        local br = 0.25 + 0.55 * max(0, sin(t * 10 - d * 0.09))
        color({ 0.7, 0.9, 1 }, br * a)
        local pts = {}
        for k = 0, 5 do pts[#pts + 1] = hx + cos(k * pi / 3 + pi / 6) * 11; pts[#pts + 1] = hy + sin(k * pi / 3 + pi / 6) * 11 end
        love.graphics.polygon("line", pts)
      end
    end
  end
  -- anillo de runas que gira
  for k = 0, 11 do
    local ang = k * pi / 6 + t * 3
    local x, y = 96 + cos(ang) * (R + 8), 96 + sin(ang) * (R + 8)
    color(ARCANO1, 0.9 * a * ent)
    love.graphics.rectangle("fill", x - 2, y - 2, 4, 4)
    glow(x, y, 7, ARCANO2, 0.6 * a * ent)
  end
  destello(96 + R * 0.55, 96 - R * 0.55, 14, t * 2, { 1, 1, 1 }, a * (0.5 + 0.5 * sin(t * 14)))
end

EF.nova = function(t)
  local e = ease(t)
  local a = t < 0.7 and 1 or (1 - t) / 0.3
  local R = 18 + 70 * e
  glow(96, 96, R * 1.1, HIELO1, 0.3 * a)
  for k = 4, 1, -1 do
    color(HIELO2, 0.07 * a)
    love.graphics.circle("fill", 96, 96, R * k / 4)
  end
  anillo(96, 96, R, 7 * (1 - t) + 2, HIELO1, 0.9 * a)
  anillo(96, 96, R, 3, { 1, 1, 1 }, a)
  -- cristales de hielo en el anillo
  for i = 0, 15 do
    local ang = i * pi / 8 + 0.1
    local largo = (14 + 16 * azar(i, 91)) * suave(min(1, t * 2.2))
    local x, y = 96 + cos(ang) * R, 96 + sin(ang) * R
    local px, py = -sin(ang), cos(ang)
    color(i % 2 == 0 and HIELO2 or HIELO1, 0.95 * a)
    love.graphics.polygon("fill", x + px * 5, y + py * 5, x + cos(ang) * largo, y + sin(ang) * largo, x - px * 5, y - py * 5)
    color({ 1, 1, 1 }, 0.8 * a)
    love.graphics.polygon("fill", x + px * 1.8, y + py * 1.8, x + cos(ang) * largo * 0.9, y + sin(ang) * largo * 0.9, x - px * 1.8, y - py * 1.8)
  end
  -- copo de nieve central
  for k = 0, 5 do
    local ang = k * pi / 3 + t * 0.6
    linea(96, 96, 96 + cos(ang) * 30 * (1 - t * 0.4), 96 + sin(ang) * 30 * (1 - t * 0.4), 3, HIELO2, a)
    local bx, by = 96 + cos(ang) * 18, 96 + sin(ang) * 18
    linea(bx, by, bx + cos(ang + 0.9) * 8, by + sin(ang + 0.9) * 8, 2, { 1, 1, 1 }, a)
    linea(bx, by, bx + cos(ang - 0.9) * 8, by + sin(ang - 0.9) * 8, 2, { 1, 1, 1 }, a)
  end
  glow(96, 96, 14, { 1, 1, 1 }, a)
  chispas(16, 96, 96, 20, 82, t, HIELO2, 95, 5, 1)
end

EF.sombra = function(t)
  local a = t < 0.7 and 1 or (1 - t) / 0.3
  local ent = ease(min(1, t / 0.3))
  glow(96, 96, 66 * ent, SOMBRA1, 0.6 * a)
  -- brazos de espiral que giran hacia el centro
  for brazo = 0, 3 do
    local pts = {}
    for k = 0, 24 do
      local f = k / 24
      local r = (66 - 58 * f) * ent
      local ang = brazo * pi / 2 + f * 4.2 + t * 7
      pts[#pts + 1] = 96 + cos(ang) * r
      pts[#pts + 1] = 96 + sin(ang) * r
    end
    love.graphics.setLineWidth(7)
    color(SOMBRA2, 0.35 * a)
    love.graphics.line(pts)
    love.graphics.setLineWidth(3)
    color({ 0.95, 0.75, 1 }, 0.8 * a)
    love.graphics.line(pts)
  end
  -- núcleo oscuro con borde violeta
  glow(96, 96, 30 * ent, SOMBRA2, a)
  color({ 0.04, 0, 0.08 }, a)
  love.graphics.circle("fill", 96, 96, 17 * ent)
  anillo(96, 96, 17 * ent, 2.5, { 0.85, 0.55, 1 }, a)
  for i = 1, 10 do
    local fase = (t * 1.6 + azar(i, 101)) % 1
    local ang = azar(i, 102) * pi * 2 + t * 4
    local r = 70 * (1 - fase)
    glow(96 + cos(ang) * r, 96 + sin(ang) * r, 5, SOMBRA2, a * fase)
  end
end

EF.meteoro = function(t)
  local caida = 0.38
  if t < caida then
    local f = t / caida
    local x, y = 168 - 72 * f, -10 + 106 * f
    -- cola de fuego
    for k = 1, 16 do
      local g = k / 16
      local tx, ty = x + 30 * g * 1.0, y - 40 * g
      glow(tx, ty, 18 * (1 - g) + 3, g < 0.5 and FUEGO2 or FUEGO1, 0.75 * (1 - g))
    end
    glow(x, y, 30, FUEGO1, 0.7)
    color({ 0.35, 0.24, 0.2 }, 1)
    love.graphics.circle("fill", x, y, 15)
    color({ 0.55, 0.38, 0.28 }, 1)
    love.graphics.circle("fill", x - 4, y - 4, 8)
    glow(x, y, 20, FUEGO3, 0.5)
    -- sombra de impacto en el suelo
    color({ 0, 0, 0 }, 0.25 * f)
    love.graphics.ellipse("fill", 96, 106, 30 * f, 10 * f)
    return
  end
  local tt = (t - caida) / (1 - caida)
  local e = ease(tt)
  local a = tt < 0.6 and 1 or (1 - tt) / 0.4
  glow(96, 100, 36 + 62 * e, FUEGO1, 0.6 * a)
  glow(96, 100, 20 + 40 * (1 - tt), FUEGO3, a)
  glow(96, 100, 10 + 14 * (1 - tt), { 1, 1, 0.95 }, a)
  anillo(96, 104, 14 + 80 * e, 7 * (1 - tt) + 1, FUEGO3, a)
  elipseAnillo(96, 108, 20 + 76 * e, 8 + 28 * e, 3, { 0.3, 0.25, 0.25 }, 0.55 * a)
  for i = 0, 11 do
    local ang = -pi / 2 + (i - 5.5) * 0.24
    local largo = (36 + 48 * azar(i, 111)) * e * (1 - tt * 0.5)
    lengua(96 + (i - 5.5) * 5, 110, largo, 9, ang, i % 2 == 0 and FUEGO1 or FUEGO2, 0.85 * a)
  end
  for i = 1, 12 do
    local ang = -pi / 2 + (azar(i, 112) - 0.5) * 2.4
    local r = 20 + 80 * e * azar(i, 113)
    local x, y = 96 + cos(ang) * r, 100 + sin(ang) * r + 40 * tt * tt
    color({ 0.3, 0.2, 0.15 }, a)
    love.graphics.circle("fill", x, y, 3 + azar(i, 114) * 3)
    glow(x, y, 8, FUEGO2, 0.6 * a)
  end
end

-- Cazador -------------------------------------------------------------------------------------
EF.disparo = function(t)
  local e, a = ease(t), 1 - t
  glow(96, 96, 14 + 36 * e, VENENO2, 0.55 * a)
  glow(96, 96, 8 + 14 * (1 - t), { 1, 1, 0.9 }, a)
  anillo(96, 96, 6 + 32 * e, 3 * a + 1, { 0.85, 1, 0.7 }, a)
  for i = 0, 5 do
    local ang = i * pi / 3 + 0.3
    local r0, r1 = 10 + 14 * e, 22 + 34 * e
    linea(96 + cos(ang) * r0, 96 + sin(ang) * r0, 96 + cos(ang) * r1, 96 + sin(ang) * r1, 3 * a + 1, { 1, 1, 0.8 }, a)
  end
  destello(96, 96, 10 + 30 * (1 - t), 0.4, { 0.9, 1, 0.6 }, a, 0.12)
  chispas(8, 96, 96, 14, 54, t, { 1, 1, 0.7 }, 121, 5, 1)
end

local function flecha(x, y, ang, largo, a, c)
  local ca, sa = cos(ang), sin(ang)
  local px, py = -sa, ca
  -- astil
  linea(x - ca * largo, y - sa * largo, x + ca * largo * 0.55, y + sa * largo * 0.55, 3, { 0.55, 0.36, 0.18 }, a)
  -- punta
  color(c or { 0.95, 0.97, 1 }, a)
  love.graphics.polygon("fill", x + ca * largo, y + sa * largo,
    x + ca * largo * 0.5 + px * 5, y + sa * largo * 0.5 + py * 5,
    x + ca * largo * 0.5 - px * 5, y + sa * largo * 0.5 - py * 5)
  -- plumas
  color({ 0.95, 0.35, 0.3 }, a)
  love.graphics.polygon("fill", x - ca * largo, y - sa * largo,
    x - ca * largo * 0.6 + px * 5, y - sa * largo * 0.6 + py * 5, x - ca * largo * 0.55, y - sa * largo * 0.55)
  love.graphics.polygon("fill", x - ca * largo, y - sa * largo,
    x - ca * largo * 0.6 - px * 5, y - sa * largo * 0.6 - py * 5, x - ca * largo * 0.55, y - sa * largo * 0.55)
end

EF.lluvia = function(t)
  glow(96, 120, 70, { 0.5, 0.9, 0.4 }, 0.12 * (1 - t))
  elipseAnillo(96, 120, 72 * ease(min(1, t * 3)), 28 * ease(min(1, t * 3)), 2, { 0.7, 1, 0.5 }, 0.45 * (1 - t))
  for i = 0, 11 do
    local x = 96 + (azar(i, 131) - 0.5) * 120
    local suelo = 120 + (azar(i, 132) - 0.5) * 36
    local retraso = azar(i, 133) * 0.45
    local f = (t - retraso) / 0.4
    if f > 0 and f < 1 then
      local y = -20 + (suelo + 20) * f
      flecha(x + (1 - f) * 22, y, pi / 2 + 0.28, 20, 1, { 0.95, 1, 0.9 })
      glow(x + (1 - f) * 22, y, 8, { 0.8, 1, 0.5 }, 0.5)
    elseif f >= 1 then
      local g = clamp((t - retraso - 0.4) / 0.35, 0, 1)
      -- clavada y onda
      flecha(x, suelo, pi / 2 + 0.28, 16, (1 - g) * 0.9 + 0.1, { 0.95, 1, 0.9 })
      elipseAnillo(x, suelo + 8, 4 + 22 * ease(g), 2 + 8 * ease(g), 2, { 0.85, 1, 0.55 }, 0.8 * (1 - g))
      glow(x, suelo + 6, 12 * (1 - g) + 4, { 1, 1, 0.7 }, 0.6 * (1 - g))
    end
  end
end

EF.preciso = function(t)
  local a = t < 0.75 and 1 or (1 - t) / 0.25
  local cierre = ease(min(1, t / 0.5))
  local R = 74 - 46 * cierre
  glow(96, 96, R + 14, ORO, 0.2 * a)
  anillo(96, 96, R, 3, ORO, a)
  anillo(96, 96, R * 0.55, 1.5, { 1, 1, 1 }, 0.8 * a)
  for k = 0, 3 do
    local ang = k * pi / 2
    linea(96 + cos(ang) * (R + 12), 96 + sin(ang) * (R + 12), 96 + cos(ang) * (R * 0.3), 96 + sin(ang) * (R * 0.3), 2.5, { 1, 0.95, 0.7 }, a)
  end
  if t > 0.45 then
    local f = (t - 0.45) / 0.55
    -- línea de disparo que atraviesa
    local l = 190 * ease(min(1, f * 2.2))
    color({ 1, 0.95, 0.7 }, (1 - f) * 0.7)
    love.graphics.polygon("fill", 96 - l * 0.7, 96 + l * 0.34, 96 + l * 0.7, 96 - l * 0.34, 96 + l * 0.7, 96 - l * 0.34 + 3, 96 - l * 0.7, 96 + l * 0.34 + 6)
    color({ 1, 1, 1 }, 1 - f)
    love.graphics.polygon("fill", 96 - l * 0.7, 96 + l * 0.34 + 2, 96 + l * 0.7, 96 - l * 0.34 + 1, 96 + l * 0.7, 96 - l * 0.34 + 2.5, 96 - l * 0.7, 96 + l * 0.34 + 4)
    destello(96, 96, 36 * (1 - f) + 12, 0.7, ORO, 1 - f)
    anillo(96, 96, 8 + 50 * ease(f), 4 * (1 - f) + 1, ORO, 1 - f)
  end
end

EF.flecha_veneno = function(t)
  local e = ease(t)
  local a = t < 0.7 and 1 or (1 - t) / 0.3
  glow(96, 100, 20 + 52 * e, VENENO1, 0.5 * a)
  for i = 0, 8 do
    local ang = i * pi / 4.5 + azar(i, 151)
    local r = 6 + 40 * e * (0.5 + azar(i, 152) * 0.6)
    local x, y = 96 + cos(ang) * r, 100 + sin(ang) * r * 0.8
    glow(x, y, 16 + 8 * (1 - t), VENENO1, 0.65 * a)
    glow(x, y, 8, VENENO2, 0.8 * a)
  end
  glow(96, 100, 12 + 12 * (1 - t), { 0.95, 1, 0.7 }, a)
  -- burbujas que suben y gotas
  for i = 1, 12 do
    local fase = (t * 1.2 + azar(i, 153)) % 1
    local x = 96 + (azar(i, 154) - 0.5) * 80
    local y = 120 - fase * 90
    color({ 0.75, 1, 0.5 }, a * (1 - fase) * 0.9)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", x, y, 3 + azar(i, 155) * 4)
    glow(x - 1, y - 1, 3, { 1, 1, 1 }, a * (1 - fase) * 0.6)
  end
  anillo(96, 100, 10 + 60 * e, 4 * (1 - t) + 1, VENENO2, 0.8 * a)
end

EF.paso_agil = function(t)
  local a = t < 0.7 and 1 or (1 - t) / 0.3
  glow(96, 120, 54, VIENTO, 0.25 * a)
  elipseAnillo(96, 124, 44, 14, 3, VIENTO, 0.8 * a)
  -- ráfagas en espiral que suben
  for k = 0, 4 do
    local pts = {}
    for j = 0, 18 do
      local f = j / 18
      local ang = k * 1.26 + f * 5 + t * 9
      local r = 12 + 34 * f
      pts[#pts + 1] = 96 + cos(ang) * r
      pts[#pts + 1] = 128 - f * 100 + sin(ang) * r * 0.32
    end
    love.graphics.setLineWidth(5)
    color(VIENTO, 0.35 * a)
    love.graphics.line(pts)
    love.graphics.setLineWidth(2)
    color({ 1, 1, 1 }, 0.9 * a)
    love.graphics.line(pts)
  end
  -- hojas y motas
  for i = 1, 10 do
    local fase = (t * 1.5 + azar(i, 161)) % 1
    local ang = azar(i, 162) * pi * 2 + fase * 6
    local r = 10 + fase * 44
    local x, y = 96 + cos(ang) * r, 126 - fase * 96 + sin(ang) * r * 0.3
    color(i % 2 == 0 and { 0.55, 0.95, 0.5 } or { 1, 1, 0.8 }, a * (1 - fase))
    love.graphics.ellipse("fill", x, y, 5, 2.4, 12)
  end
end

-- Clérigo -------------------------------------------------------------------------------------
EF.curar = function(t)
  local a = t < 0.75 and 1 or (1 - t) / 0.25
  glow(96, 128, 64, CURA1, 0.35 * a)
  elipseAnillo(96, 130, 40 + 10 * sin(t * 10), 13, 4, CURA2, 0.9 * a)
  elipseAnillo(96, 130, 26, 8, 2, { 1, 1, 1 }, 0.8 * a)
  glow(96, 100, 30, CURA2, 0.25 * a)
  for i = 0, 9 do
    local fase = (t * 1.3 + azar(i, 171)) % 1
    local x = 96 + (azar(i, 172) - 0.5) * 90
    local y = 138 - fase * 112
    local r = 5 + azar(i, 173) * 5
    local al = a * sin(fase * pi)
    if i % 2 == 0 then cruz(x, y, r, 3, CURA1, al); cruz(x, y, r * 0.55, 1.5, { 1, 1, 1 }, al)
    else glow(x, y, r * 1.6, CURA2, al); destello(x, y, r * 1.6, 0.6, { 1, 1, 0.8 }, al * 0.8, 0.2) end
  end
  glow(96, 96, 18 * (1 - t) + 6, { 1, 1, 0.9 }, 0.8 * (1 - t))
end

EF.bendicion = function(t)
  local a = t < 0.7 and 1 or (1 - t) / 0.3
  local baja = ease(min(1, t / 0.28))
  -- rayo que cae desde arriba
  local yTope = -10 + 106 * baja
  glow(96, 50, 44, SAGRADO1, 0.25 * a)
  color(SAGRADO1, 0.55 * a)
  love.graphics.polygon("fill", 96 - 14, -10, 96 + 14, -10, 96 + 5, yTope, 96 - 5, yTope)
  color({ 1, 1, 0.92 }, a)
  love.graphics.polygon("fill", 96 - 6, -10, 96 + 6, -10, 96 + 2, yTope, 96 - 2, yTope)
  -- impacto con cruz de luz
  local f = clamp((t - 0.22) / 0.78, 0, 1)
  if f > 0 then
    local e = ease(f)
    glow(96, 98, 14 + 52 * e, SAGRADO1, 0.7 * (1 - f))
    anillo(96, 98, 8 + 54 * e, 4 * (1 - f) + 1, SAGRADO2, 1 - f)
    destello(96, 98, 20 + 50 * (1 - f), 0, { 1, 0.95, 0.6 }, 1 - f, 0.1)
    destello(96, 98, 12 + 30 * (1 - f), pi / 4, { 1, 0.95, 0.7 }, (1 - f) * 0.8, 0.1)
    chispas(12, 96, 98, 12, 62, f, SAGRADO2, 181, 6, 1)
  end
end

EF.castigo = function(t)
  local e, a = ease(t), 1 - t
  glow(96, 96, 22 + 56 * e, SAGRADO1, 0.65 * a)
  glow(96, 96, 10 + 22 * (1 - t), SAGRADO2, a)
  anillo(96, 96, 8 + 52 * e, 4 * a + 1, SAGRADO2, a)
  for i = 0, 7 do
    local ang = i * pi / 4 + 0.2
    local r0 = 10 + 20 * e
    local r1 = r0 + (i % 2 == 0 and 50 or 28) * (1 - t * 0.5)
    local px, py = -sin(ang), cos(ang)
    color(i % 2 == 0 and { 1, 1, 0.9 } or SAGRADO1, a)
    love.graphics.polygon("fill", 96 + cos(ang) * r0 + px * 4, 96 + sin(ang) * r0 + py * 4,
      96 + cos(ang) * r1, 96 + sin(ang) * r1, 96 + cos(ang) * r0 - px * 4, 96 + sin(ang) * r0 - py * 4)
  end
  destello(96, 96, 20 + 44 * (1 - t), t * 1.5, SAGRADO1, a, 0.1)
  -- plumas que caen
  for i = 1, 6 do
    local x = 96 + (azar(i, 191) - 0.5) * 90
    local y = 50 + t * 70 + azar(i, 192) * 20
    color({ 1, 1, 0.95 }, a * 0.9)
    love.graphics.ellipse("fill", x, y, 7, 2.2, 14)
  end
end

EF.consagrar = function(t)
  local a = t < 0.75 and 1 or (1 - t) / 0.25
  local ent = ease(min(1, t / 0.3))
  local rx, ry = 66 * ent, 25 * ent
  glow(96, 118, 74 * ent, SAGRADO1, 0.3 * a)
  elipseAnillo(96, 118, rx, ry, 4, ORO, a)
  elipseAnillo(96, 118, rx * 0.82, ry * 0.82, 1.5, { 1, 1, 0.9 }, 0.8 * a)
  -- estrella de cinco puntas y cruz giratorias (en perspectiva)
  local pts = {}
  for k = 0, 4 do
    local ang = k * 4 * pi / 5 - pi / 2 + t * 1.2
    pts[#pts + 1] = 96 + cos(ang) * rx * 0.72
    pts[#pts + 1] = 118 + sin(ang) * ry * 0.72
  end
  love.graphics.setLineWidth(2.5)
  color(SAGRADO2, 0.95 * a)
  love.graphics.polygon("line", pts)
  -- rayos de luz que suben
  for i = 0, 8 do
    local ang = i * pi / 4.5 + t
    local x, y = 96 + cos(ang) * rx * 0.8, 118 + sin(ang) * ry * 0.8
    local alto = (36 + 28 * azar(i, 201)) * ent * (0.7 + 0.3 * sin(t * 12 + i))
    color(SAGRADO1, 0.35 * a)
    love.graphics.polygon("fill", x - 5, y, x + 5, y, x + 2, y - alto, x - 2, y - alto)
    color({ 1, 1, 0.9 }, 0.8 * a)
    love.graphics.polygon("fill", x - 1.6, y, x + 1.6, y, x + 0.8, y - alto, x - 0.8, y - alto)
  end
  chispas(12, 96, 112, 10, 60, (t * 1.6) % 1, SAGRADO2, 202, 5, a)
end

EF.sanacion = function(t)
  local e = ease(t)
  local a = t < 0.7 and 1 or (1 - t) / 0.3
  glow(96, 100, 20 + 70 * e, CURA1, 0.45 * a)
  anillo(96, 108, 10 + 70 * e, 7 * (1 - t) + 1, CURA2, a)
  anillo(96, 108, 6 + 50 * e, 3, { 1, 1, 1 }, 0.9 * a)
  elipseAnillo(96, 124, 20 + 70 * e, 8 + 24 * e, 3, CURA1, 0.7 * a)
  -- columna de luz central suave
  color(CURA2, 0.2 * a)
  love.graphics.polygon("fill", 80, 130, 112, 130, 104, 4, 88, 4)
  color({ 1, 1, 1 }, 0.35 * a)
  love.graphics.polygon("fill", 90, 130, 102, 130, 99, 4, 93, 4)
  for i = 0, 11 do
    local fase = (t * 1.2 + azar(i, 211)) % 1
    local ang = azar(i, 212) * pi * 2
    local r = 12 + 66 * azar(i, 213) * ease(t)
    local x, y = 96 + cos(ang) * r, 112 + sin(ang) * r * 0.45 - fase * 60
    local al = a * sin(fase * pi)
    if i % 3 == 0 then cruz(x, y, 6, 3, CURA1, al); cruz(x, y, 3.5, 1.5, { 1, 1, 1 }, al)
    else destello(x, y, 7, 0.4, CURA2, al, 0.2) end
  end
end

EF.juicio = function(t)
  local a = t < 0.7 and 1 or (1 - t) / 0.3
  local baja = ease(min(1, t / 0.2))
  local ancho = 22 * (t < 0.2 and 0.5 or (0.8 + 0.2 * sin(t * 20)))
  glow(96, 70, 60, SAGRADO1, 0.3 * a)
  color(SAGRADO1, 0.42 * a)
  love.graphics.polygon("fill", 96 - ancho * 1.5, -10, 96 + ancho * 1.5, -10, 96 + ancho, 118 * baja, 96 - ancho, 118 * baja)
  color({ 1, 1, 0.85 }, 0.8 * a)
  love.graphics.polygon("fill", 96 - ancho * 0.7, -10, 96 + ancho * 0.7, -10, 96 + ancho * 0.45, 118 * baja, 96 - ancho * 0.45, 118 * baja)
  color({ 1, 1, 1 }, a)
  love.graphics.polygon("fill", 96 - ancho * 0.25, -10, 96 + ancho * 0.25, -10, 96 + ancho * 0.15, 118 * baja, 96 - ancho * 0.15, 118 * baja)
  local f = clamp((t - 0.15) / 0.85, 0, 1)
  if f > 0 then
    local e = ease(f)
    elipseAnillo(96, 120, 12 + 70 * e, 5 + 26 * e, 5 * (1 - f) + 1, SAGRADO2, 1 - f)
    elipseAnillo(96, 120, 8 + 44 * e, 3 + 16 * e, 2, ORO, 0.9 * (1 - f))
    glow(96, 118, 22 + 56 * e, SAGRADO1, 0.65 * (1 - f))
    destello(96, 114, 26 + 40 * (1 - f), 0, { 1, 0.95, 0.6 }, 1 - f, 0.1)
    for i = 0, 8 do
      local x = 96 + (azar(i, 221) - 0.5) * 110 * e
      local y = 112 - 60 * e * azar(i, 222) + 30 * f * f
      color({ 1, 1, 0.95 }, (1 - f) * 0.9)
      love.graphics.ellipse("fill", x, y, 7, 2.2, 14)
    end
  end
end

local abs = math.abs
-- Lancero (Alba) y Nigromante (Ocaso) ---------------------------------------------------------
local NECRO1, NECRO2 = { 0.15, 0.85, 0.4 }, { 0.8, 1, 0.75 }
local HUESO = { 0.95, 0.93, 0.8 }
local AZUL1, AZUL2 = { 0.35, 0.6, 1 }, { 0.85, 0.95, 1 }
local MADERA = { 0.72, 0.5, 0.26 }

-- Lanza dibujada con la punta en (x, y) y el asta hacia atrás (ang = hacia donde apunta).
local function lanzaDib(x, y, ang, largo, a, c2)
  if a <= 0 then return end
  local ca, sa = cos(ang), sin(ang)
  local px, py = -sa, ca
  linea(x - ca * largo, y - sa * largo, x - ca * 8, y - sa * 8, 3.2, MADERA, a)
  linea(x - ca * largo, y - sa * largo, x - ca * (largo - 7), y - sa * (largo - 7), 3.6, { 0.55, 0.6, 0.7 }, a)
  color(ACERO, a)
  love.graphics.polygon("fill", x, y, x - ca * 9 + px * 4.5, y - sa * 9 + py * 4.5, x - ca * 7, y - sa * 7, x - ca * 9 - px * 4.5, y - sa * 9 - py * 4.5)
  color({ 1, 1, 1 }, a * 0.95)
  love.graphics.polygon("fill", x, y, x - ca * 6 + px * 1.6, y - sa * 6 + py * 1.6, x - ca * 6 - px * 1.6, y - sa * 6 - py * 1.6)
  linea(x - ca * 8, y - sa * 8, x - ca * 11 + px * 5, y - sa * 11 + py * 5, 2, ORO, a)
  linea(x - ca * 8, y - sa * 8, x - ca * 11 - px * 5, y - sa * 11 - py * 5, 2, ORO, a)
  glow(x, y, 11, c2 or AZUL1, a * 0.5)
end

EF.estocada = function(t)
  local a = t < 0.65 and 1 or (1 - t) / 0.35
  local prog = ease(min(1, t / 0.32))
  local x, y = 24 + 72 * prog, 24 + 72 * prog
  for k = 1, 7 do
    local g = k / 7
    glow(x - 18 * g * 3.2, y - 18 * g * 3.2, 14 * (1 - g * 0.6), AZUL1, 0.5 * (1 - g) * (t < 0.5 and 1 or (1 - t) * 2))
  end
  lanzaDib(x, y, pi / 4, 70, a * (t < 0.5 and 1 or 1 - (t - 0.5) / 0.5 * 0.6))
  if t > 0.28 then
    local u = (t - 0.28) / 0.72
    local e = ease(u)
    glow(96, 96, 16 + 40 * e, AZUL2, 0.7 * (1 - u))
    anillo(96, 96, 8 + 44 * e, 4 * (1 - u) + 0.8, AZUL2, 1 - u)
    for i = 0, 7 do
      local ang = i * pi / 4 + 0.3
      linea(96 + cos(ang) * (10 + 26 * e), 96 + sin(ang) * (10 + 26 * e), 96 + cos(ang) * (18 + 46 * e), 96 + sin(ang) * (18 + 46 * e), 3 * (1 - u) + 0.6, { 1, 1, 1 }, 1 - u)
    end
    destello(96, 96, 14 + 30 * (1 - u), 0.5, AZUL1, 1 - u)
  end
end

EF.barrido = function(t)
  local a = t < 0.6 and 1 or (1 - t) / 0.4
  local prog = ease(min(1, t / 0.5))
  local a0, a1 = -2.3, -2.3 + 4.6 * prog
  glow(96, 96, 70, AZUL1, 0.18 * a)
  for capa = 0, 3 do
    local r = 58 + capa * 6
    local n = 36
    for i = 0, n - 1 do
      local g0, g1 = i / n, (i + 1) / n
      local an0, an1 = a0 + (a1 - a0) * g0, a0 + (a1 - a0) * g1
      local w = (4 + 12 * sin(pi * g0) ^ 0.8) * (1 - capa * 0.22) * (0.25 + 0.75 * g0)
      linea(96 + cos(an0) * r, 96 + sin(an0) * r * 0.7, 96 + cos(an1) * r, 96 + sin(an1) * r * 0.7, w,
        capa == 0 and { 1, 1, 1 } or (capa == 1 and AZUL2 or AZUL1), a * (0.35 + 0.65 * g0) * (1 - capa * 0.2))
    end
  end
  local tx, ty = 96 + cos(a1) * 58, 96 + sin(a1) * 58 * 0.7
  lanzaDib(tx, ty, a1 + pi / 2, 54, a)
  chispas(8, 96, 96, 20, 80, t, AZUL2, 21, 6, 1)
end

EF.muro_lanzas = function(t)
  local a = t < 0.75 and 1 or (1 - t) / 0.25
  local h = 52 * ease(min(1, t / 0.35))
  glow(96, 134, 76, AZUL1, 0.35 * a)
  elipseAnillo(96, 134, 66, 24, 3, AZUL2, 0.7 * a)
  local n = 12
  for pasada = 0, 1 do
    for i = 0, n - 1 do
      local ang = i * 2 * pi / n
      local atras = sin(ang) < 0
      if (pasada == 0) == atras then
        local x, y = 96 + cos(ang) * 64, 134 + sin(ang) * 22
        lanzaDib(x, y - h, -pi / 2, 40 + h * 0.5, a)
      end
    end
  end
  if t > 0.3 then
    local u = (t - 0.3) / 0.7
    elipseAnillo(96, 96, 62, 70, 2, AZUL2, 0.3 * (1 - u) * a)
    destello(96, 60, 12 + 6 * sin(t * 18), t * 3, AZUL2, a * 0.8)
  end
end

EF.embestida = function(t)
  local a = t < 0.7 and 1 or (1 - t) / 0.3
  local prog = ease(min(1, t / 0.4))
  local x = 20 + 120 * prog
  -- estelas de velocidad
  for i = 0, 8 do
    local y = 96 + (i - 4) * 9
    local l = 40 + azar(i, 61) * 60
    linea(x - l - 20, y, x - 12 - azar(i, 62) * 12, y, 2.5 * (1 - abs(i - 4) / 6), i % 2 == 0 and { 1, 1, 1 } or AZUL2, a * (0.4 + 0.5 * (1 - abs(i - 4) / 5)))
  end
  glow(x, 96, 30, AZUL1, 0.5 * a)
  lanzaDib(x + 16, 96, 0, 64, a)
  -- onda de choque cónica
  for k = 0, 2 do
    local u = clamp((t - 0.25 - k * 0.07) / 0.5, 0, 1)
    if u > 0 then
      local px = 20 + 120 * ease(min(1, 0.25 / 0.4)) + 20
      anillo(px + 22 * u, 96, 8 + 40 * ease(u), 4 * (1 - u) + 0.8, AZUL2, (1 - u) * a)
    end
  end
  chispas(7, x + 14, 96, 6, 44, clamp((t - 0.2) / 0.8, 0, 1), AZUL2, 77, 6, 1)
end

EF.jabalina = function(t)
  local a = t < 0.7 and 1 or (1 - t) / 0.3
  local prog = ease(min(1, t / 0.3))
  local x, y = 40 + 56 * prog, 56 + 40 * prog
  if t < 0.45 then lanzaDib(x, y, 0.65, 60, 1) end
  if t >= 0.25 then
    local u = (t - 0.25) / 0.75
    local e = ease(u)
    lanzaDib(96, 98, 0.65, 54, a)
    glow(96, 98, 14 + 44 * e, ORO, 0.7 * (1 - u))
    anillo(96, 100, 6 + 52 * e, 4 * (1 - u) + 0.8, { 1, 0.95, 0.6 }, 1 - u)
    elipseAnillo(96, 104, 10 + 60 * e, 4 + 20 * e, 2, AZUL2, (1 - u) * 0.8)
    destello(96, 98, 12 + 30 * (1 - u), 0.5, ORO, 1 - u)
    chispas(8, 96, 98, 8, 62, u, ORO, 83, 5, 1)
  end
end

EF.tormenta_lanzas = function(t)
  local n = 14
  glow(96, 120, 78, AZUL1, 0.22 * (t < 0.8 and 1 or (1 - t) / 0.2))
  elipseAnillo(96, 120, 70, 34, 2, AZUL2, 0.5 * (t < 0.8 and 1 or (1 - t) / 0.2))
  for i = 1, n do
    local ang = azar(i, 91) * pi * 2
    local r = sqrt(azar(i, 92)) * 68
    local tx, ty = 96 + cos(ang) * r, 122 + sin(ang) * r * 0.45
    local salida = 0.04 + azar(i, 93) * 0.5
    local u = (t - salida) / 0.22
    if u > 0 then
      local caida = ease(min(1, u))
      local y = ty - 130 * (1 - caida)
      local a = t < 0.78 and 1 or (1 - t) / 0.22
      if u < 1 then
        linea(tx - 1, y - 60, tx - 1, y - 20, 2, AZUL2, 0.35 * a)
      else
        local w = clamp((u - 1) / 0.6, 0, 1)
        anillo(tx, ty, 3 + 16 * w, 2.4 * (1 - w) + 0.5, AZUL2, (1 - w) * a)
        glow(tx, ty, 6 + 12 * w, AZUL1, 0.6 * (1 - w) * a)
      end
      lanzaDib(tx, y, pi / 2 + 0.05, 46, a)
    end
  end
end

-- Nigromante ----------------------------------------------------------------------------------
local function calavera(x, y, r, a, c)
  if a <= 0 then return end
  color(c or HUESO, a)
  love.graphics.circle("fill", x, y, r)
  love.graphics.rectangle("fill", x - r * 0.55, y + r * 0.4, r * 1.1, r * 0.9, 2, 2)
  color({ 0.04, 0.02, 0.06 }, a)
  love.graphics.circle("fill", x - r * 0.38, y - r * 0.05, r * 0.28)
  love.graphics.circle("fill", x + r * 0.38, y - r * 0.05, r * 0.28)
  love.graphics.polygon("fill", x, y + r * 0.2, x - r * 0.12, y + r * 0.5, x + r * 0.12, y + r * 0.5)
  color(NECRO2, a)
  love.graphics.circle("fill", x - r * 0.38, y - r * 0.05, r * 0.11)
  love.graphics.circle("fill", x + r * 0.38, y - r * 0.05, r * 0.11)
end

EF.toque_necro = function(t)
  local a = 1 - t
  local e = ease(t)
  glow(96, 100, 20 + 60 * e, NECRO1, 0.7 * a)
  glow(96, 100, 10 + 24 * (1 - t), NECRO2, a)
  anillo(96, 100, 8 + 52 * e, 4 * (1 - t) + 1, NECRO2, a)
  calavera(96, 96 - 26 * e, 10 + 14 * sin(pi * t), sin(pi * min(1, t * 1.2)) * 0.95)
  for i = 0, 6 do
    local ang = i * pi * 2 / 7 + t * 4
    local r = 14 + 46 * e
    glow(96 + cos(ang) * r, 100 + sin(ang) * r * 0.7 - 20 * e, 7 * (1 - t * 0.5), NECRO1, 0.8 * a)
  end
  chispas(8, 96, 100, 16, 70, t, NECRO2, 101, 5, 1)
end

-- ----------------------------------------------------------------------------- proyectiles
-- Cuadros de 64x64, el proyectil mira a la derecha y su centro es (40, 32).
local PR = {}
local function cola(n, largo, c, r0, a)
  for k = 1, n do
    local g = k / n
    glow(40 - largo * g, 32 + sin(g * 6) * 0.6, r0 * (1 - g * 0.7), c, a * (1 - g))
  end
end

PR.misil = function(f)
  local t = f / 4
  cola(8, 30, ARCANO1, 9, 0.8)
  glow(40, 32, 15, ARCANO1, 0.7)
  glow(40, 32, 9, ARCANO2, 1)
  glow(40, 32, 4.5, { 1, 1, 1 }, 1)
  for k = 0, 2 do
    local ang = t * pi * 2 + k * 2.1
    glow(40 + cos(ang) * 9, 32 + sin(ang) * 9, 3.2, ARCANO2, 0.95)
  end
end

PR.fuego = function(f)
  local t = f / 4
  for k = 1, 9 do
    local g = k / 9
    local jit = sin(t * 12.56 + k * 1.7) * 3 * g
    glow(38 - 28 * g, 32 + jit, 12 * (1 - g * 0.6), g < 0.5 and FUEGO2 or FUEGO1, 0.85 * (1 - g))
  end
  lengua(36, 32, 22, 7, pi + sin(t * 12.56) * 0.3, FUEGO1, 0.8)
  lengua(36, 28, 18, 5, pi - 0.5 + cos(t * 12.56) * 0.3, FUEGO2, 0.8)
  lengua(36, 36, 18, 5, pi + 0.5 - cos(t * 12.56) * 0.3, FUEGO2, 0.8)
  glow(42, 32, 16, FUEGO1, 0.8)
  glow(42, 32, 11, FUEGO2, 1)
  glow(43, 32, 6.5, FUEGO3, 1)
  glow(43, 32, 3, { 1, 1, 1 }, 1)
end

PR.flecha = function(f)
  local t = f / 4
  glow(20, 32, 16, { 0.8, 1, 0.8 }, 0.18)
  for k = 1, 3 do linea(28 - k * 6, 32 + (k - 2) * 2, 12 - k * 4, 32 + (k - 2) * 2, 1.4, { 1, 1, 1 }, 0.35 / k) end
  flecha(30, 32, 0, 24, 1, { 0.95, 0.97, 1 })
  glow(54, 32, 6, { 1, 1, 0.9 }, 0.5 + 0.2 * sin(t * 6.28))
end

PR.sagrado = function(f)
  local t = f / 4
  for k = 1, 8 do
    local g = k / 8
    glow(40 - 28 * g, 32 + sin(g * 9 + t * 6.28) * 3, 8 * (1 - g * 0.6), SAGRADO1, 0.75 * (1 - g))
  end
  glow(42, 32, 17, SAGRADO1, 0.6)
  destello(42, 32, 17, t * pi / 2, { 1, 0.95, 0.6 }, 1, 0.14)
  glow(42, 32, 7, { 1, 1, 1 }, 1)
end

PR.sombra = function(f)
  local t = f / 4
  for k = 1, 9 do
    local g = k / 9
    glow(40 - 30 * g, 32 + sin(g * 8 + t * 6.28) * 4, 8 * (1 - g * 0.5), SOMBRA2, 0.55 * (1 - g))
  end
  glow(42, 32, 15, SOMBRA1, 0.85)
  color({ 0.05, 0, 0.1 }, 1)
  love.graphics.circle("fill", 42, 32, 8)
  anillo(42, 32, 8, 2, SOMBRA2, 1)
  for k = 0, 2 do
    local ang = -t * pi * 2 + k * 2.1
    glow(42 + cos(ang) * 11, 32 + sin(ang) * 11, 3, { 0.9, 0.6, 1 }, 0.9)
  end
end


PR.lanza = function(f)
  local t = f / 4
  for k = 1, 6 do
    local g = k / 6
    glow(34 - 24 * g, 32, 9 * (1 - g * 0.6), AZUL1, 0.55 * (1 - g))
  end
  for k = 1, 3 do linea(30 - k * 6, 32 + (k - 2) * 3, 12 - k * 3, 32 + (k - 2) * 3, 1.4, { 1, 1, 1 }, 0.35 / k) end
  lanzaDib(56, 32, 0, 46, 1)
  glow(56, 32, 8, AZUL2, 0.5 + 0.2 * sin(t * 6.28))
end

PR.necro = function(f)
  local t = f / 4
  for k = 1, 9 do
    local g = k / 9
    glow(40 - 30 * g, 32 + sin(g * 8 + t * 6.28) * 4, 8 * (1 - g * 0.5), NECRO1, 0.6 * (1 - g))
  end
  glow(42, 32, 16, NECRO1, 0.8)
  calavera(43, 32, 7.5, 1)
  for k = 0, 2 do
    local ang = -t * pi * 2 + k * 2.1
    glow(43 + cos(ang) * 11, 32 + sin(ang) * 11, 3, NECRO2, 0.9)
  end
end

-- ------------------------------------------------------------------------------- exportación
local function guardar(datos, nombre)
  local f = assert(io.open(SALIDA .. nombre, "wb"))
  f:write(datos:encode("png"):getString())
  f:close()
end

function love.load()
  love.graphics.setLineStyle("smooth")
  local orden = {}
  for id in pairs(EF) do orden[#orden + 1] = id end
  table.sort(orden)
  local previa = {}
  for _, id in ipairs(orden) do
    local cv = love.graphics.newCanvas(CELDA * COL, CELDA * FILAS, { msaa = 4 })
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 0)
    for f = 0, N - 1 do
      local cx, cy = f % COL, floor(f / COL)
      love.graphics.push()
      love.graphics.setScissor(cx * CELDA, cy * CELDA, CELDA, CELDA)
      love.graphics.translate(cx * CELDA, cy * CELDA)
      love.graphics.setBlendMode("alpha")
      EF[id](f / (N - 1))
      love.graphics.setScissor()
      love.graphics.pop()
    end
    love.graphics.setCanvas()
    local datos = cv:newImageData()
    guardar(datos, "Hechizo_" .. id .. ".png")
    previa[#previa + 1] = { id = id, datos = datos }
  end
  -- proyectiles: 4 cuadros de 64x64 en fila
  local pro = {}
  for id in pairs(PR) do pro[#pro + 1] = id end
  table.sort(pro)
  for _, id in ipairs(pro) do
    local cv = love.graphics.newCanvas(256, 64, { msaa = 4 })
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 0)
    for f = 0, 3 do
      love.graphics.push()
      love.graphics.setScissor(f * 64, 0, 64, 64)
      love.graphics.translate(f * 64, 0)
      PR[id](f)
      love.graphics.setScissor()
      love.graphics.pop()
    end
    love.graphics.setCanvas()
    local datos = cv:newImageData()
    guardar(datos, "Proyectil_" .. id .. ".png")
    previa[#previa + 1] = { id = "proy_" .. id, datos = datos, proyectil = true }
  end
  -- vista previa: sobre fondo verde, cuadros 3, 6, 9 y 12 de cada efecto (y los proyectiles)
  local cols = 8
  local filas = math.ceil(#previa / 2)
  local pv = love.graphics.newCanvas(cols * 130, filas * 135)
  love.graphics.setCanvas(pv)
  love.graphics.clear(0.33, 0.52, 0.3, 1)
  local k = 0
  for _, p in ipairs(previa) do
    local img = love.graphics.newImage(p.datos)
    img:setFilter("linear", "linear")
    local fila, col0 = floor(k / 2), (k % 2) * 4
    if p.proyectil then
      for f = 0, 3 do
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, love.graphics.newQuad(f * 64, 0, 64, 64, 256, 64), (col0 + f) * 130 + 20, fila * 135 + 20, 0, 1.5, 1.5)
      end
    else
      for q, f in ipairs({ 3, 6, 9, 12 }) do
        local cx, cy = f % COL, floor(f / COL)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, love.graphics.newQuad(cx * CELDA, cy * CELDA, CELDA, CELDA, CELDA * COL, CELDA * FILAS), (col0 + q - 1) * 130, fila * 135, 0, 0.67, 0.67)
      end
    end
    love.graphics.setColor(1, 1, 0.6)
    love.graphics.print(p.id, col0 * 130 + 4, fila * 135 + 118)
    k = k + 1
  end
  love.graphics.setCanvas()
  local fp = io.open(os.getenv("TEMP") .. "/hechizos_previa.png", "wb")
  fp:write(pv:newImageData():encode("png"):getString())
  fp:close()
  love.event.quit()
end
