-- Efectos de poder compuestos con los sprites originales de FAO (arte/fao_efectos, ver efectos_fao_datos.lua): "pantera" (Panther Killing: una pantera de fuego corre
-- del guerrero al enemigo y estalla) y "nova" (Blizzard Burst: cristales de hielo caen sobre el área y un cristal grande se rompe en el centro). Arte de un juego ajeno: prototipo.
-- Reconstrucción a partir de efecto.json: la elección de cuadro por dirección es de los propios sprites; tiempos y trayectorias están inferidos.
-- Escala: los personajes de FAO se dibujan a 0,5 (render/fao.lua), así que estos sprites también (K).
local Iso = require("src.presentacion.render.iso")
local Datos = require("src.presentacion.render.efectos_fao_datos")
local DatosJuego = require("compartido.dominio.datos")

local M = {}

local K = 0.5
local PANTERA = 0.65      -- tamaño de la pantera respecto al original de FAO
local imagenes, quads, cajas = {}, {}, {}

local function imagen(sec)
  local i = imagenes[sec]
  if i == nil then
    local ruta = "arte/fao_efectos/" .. sec .. ".png"
    if love.filesystem.getInfo(ruta) then
      i = love.graphics.newImage(ruta)
      i:setFilter("linear", "linear")
    else
      i = false
    end
    imagenes[sec] = i
  end
  return i
end

local function quad(sec, k)
  local d = Datos[sec]
  local clave = sec .. k
  local q = quads[clave]
  if not q then
    local img = imagen(sec)
    q = love.graphics.newQuad(k * d.w, 0, d.w, d.h, img:getWidth(), img:getHeight())
    quads[clave] = q
  end
  return q
end

-- Centro de la caja de píxeles visibles del cuadro (el abanico de fuego y la pantera se centran juntos aunque sus anclas difieran).
local function centro(sec, k)
  local clave = sec .. k
  local c = cajas[clave]
  if c then return c[1], c[2] end
  local d = Datos[sec]
  local datos = love.image.newImageData("arte/fao_efectos/" .. sec .. ".png")
  local x0, y0, x1, y1 = d.w, d.h, -1, -1
  for y = 0, d.h - 1, 2 do
    for x = 0, d.w - 1, 2 do
      local _, _, _, a = datos:getPixel(k * d.w + x, y)
      if a > 0.1 then
        if x < x0 then x0 = x end
        if x > x1 then x1 = x end
        if y < y0 then y0 = y end
        if y > y1 then y1 = y end
      end
    end
  end
  datos:release()
  c = x1 >= 0 and { (x0 + x1) / 2, (y0 + y1) / 2 } or { d.w / 2, d.h / 2 }
  cajas[clave] = c
  return c[1], c[2]
end

local function limitar(v, a, b) return math.max(a, math.min(b, v)) end
local function seg(t, a, b) return limitar((t - a) / (b - a), 0, 1) end

-- Cuadro de dirección (0 arriba, n/2 lateral izquierdo, n-1 abajo) y espejo, según el ángulo de avance en pantalla (grados, 0 = derecha, y hacia abajo).
local function cuadroDir(th, n)
  local espejo = math.cos(math.rad(th)) >= 0
  local ang = espejo and (180 - th) or th
  while ang > -90 do ang = ang - 360 end
  while ang < -270 do ang = ang + 360 end
  return math.floor(limitar((-90 - ang) / 180 * (n - 1), 0, n - 1) + 0.5), espejo
end

-- Dibuja el cuadro k (0..n-1) de la secuencia con su ancla en (x, y); centrado = el centro visible va en (x, y).
local function poner(sec, k, x, y, alfa, escala, espejo, centrado)
  local img = imagen(sec)
  if not img then return end
  local d = Datos[sec]
  local ox, oy = d.ox, d.oy
  if centrado then ox, oy = centro(sec, k) end
  local sx = escala
  if espejo then ox = d.w - ox sx = -escala end
  love.graphics.setColor(1, 1, 1, alfa)
  love.graphics.draw(img, quad(sec, k), x, y, 0, sx, escala, ox, oy)
end

-- Posición en pantalla de (x, y) del mundo relativa a (x0, y0).
local function delta(x, y, x0, y0)
  local ax, ay = Iso.pos(x, y)
  local bx, by = Iso.pos(x0, y0)
  return ax - bx, ay - by
end

local PECHO = 20          -- px de pantalla sobre los pies (la altura del pecho de un personaje de FAO a 0,5)

-- Pantera: fx.x, fx.y = el enemigo; fx.x0, fx.y0 = quien la lanza. (sx, sy) = dónde cae el enemigo en pantalla.
local CORRE_DE, CORRE_A, IMPACTO = 0.05, 0.50, 0.50
local function pantera(fx, t, sx, sy)
  local x0 = fx.x0 or fx.x - 1
  local y0 = fx.y0 or fx.y
  local dx, dy = delta(x0, y0, fx.x, fx.y)             -- del enemigo al lanzador, en pantalla
  local largo = math.sqrt(dx * dx + dy * dy)
  if largo < 1 then dx, dy, largo = -1, 0, 1 end
  local ux, uy = -dx / largo, -dy / largo               -- sentido de la carrera
  local th = math.deg(math.atan2(uy, ux))
  local di, espejo = cuadroDir(th, 5)
  love.graphics.setBlendMode("add")
  if t >= CORRE_DE and t <= CORRE_A then
    local u = (t - CORRE_DE) / (CORRE_A - CORRE_DE)
    local ini = math.min(largo, 14)                       -- sale un poco delante del guerrero y se detiene antes de pisar al enemigo
    local fin = largo - 10
    local rec = ini + (math.max(ini, fin) - ini) * u
    local x, y = sx + dx + ux * rec, sy + dy + uy * rec - PECHO
    local abanico = math.floor((t - CORRE_DE) / 0.07) % 3 + 1
    local ciclo = math.floor((t - CORRE_DE) / 0.07) % 6 + 1
    poner(("S3910%d03"):format(abanico), di, x, y, 0.85, K * PANTERA, espejo, true)
    poner(("S3920%d03"):format(ciclo), di, x, y, 1, K * 1.35 * PANTERA, espejo, true)
  end
  if t >= IMPACTO and t <= IMPACTO + 0.42 then
    local k = math.min(2, math.floor((t - IMPACTO) / 0.14))
    local a = 1 - seg(t, IMPACTO + 0.2, IMPACTO + 0.42)
    poner(("S3910%d03"):format(k + 1), 4, sx, sy - PECHO, a, K * PANTERA, false, false)
  end
  love.graphics.setBlendMode("alpha")
end

-- Ventisca: fx.x, fx.y = el centro; cristales repartidos por el área (en casillas del mundo, así se aplasta solo en isométrica).
local RADIO = 2.8          -- casillas (algo menos que el área de daño de la nova, 3)
local CAIDOS = 12
local function azar(i, k)
  local n = math.sin(i * 12.9898 + k * 78.233) * 43758.5453
  return n - math.floor(n)
end

local function ventisca(fx, t, sx, sy)
  love.graphics.setBlendMode("add")
  for i = 0, CAIDOS - 1 do
    local ang = azar(i, 1) * math.pi * 2
    local r = RADIO * math.sqrt(azar(i, 2))
    local dx, dy = delta(fx.x + math.cos(ang) * r, fx.y + math.sin(ang) * r, fx.x, fx.y)
    local nace, cae = 0.12 + i * 0.05, 0.35
    if t >= nace and t <= nace + cae + 0.5 then
      local u = (t - nace) / cae
      local alto = 55
      local y = u < 1 and (-alto * (1 - u * u)) or 0                 -- cae acelerando
      local vida = 1 - seg(t, nace + cae + 0.2, nace + cae + 0.5)
      local sec = (i % 2 == 0) and "ice030001" or "ice020001"
      local k = math.floor((t - nace) / 0.06) % 6
      poner(sec, k, sx + dx, sy + dy + y - 6, vida, K * 0.95, false, false)
    end
  end
  local tb = 0.45
  if t >= tb and t <= tb + 0.55 then
    local k = math.min(2, math.floor((t - tb) / 0.15))
    poner("ice0101", k, sx, sy - 12, 0.75 * (1 - seg(t, tb + 0.35, tb + 0.55)), K * 0.8, false, false)
  end
  love.graphics.setBlendMode("alpha")
end

-- Tajo (Revolving Swords): un AoE circular centrado en el guerrero. Dos capas con la misma escala, ajustada al radio REAL del poder (rango en habilidades.xml):
-- el anillo de aire (AIR, bajo los personajes) y las espadas girando (SWORD, sobre el guerrero). Dura lo que AIR: 12 cuadros de 80 ms.
local TAJO_MS = 0.08
local ANILLO_MEDIO_ANCHO, ANILLO_MEDIO_ALTO = 245, 107       -- mitad de la caja visible del anillo AIR (px nativos)
local TORSO = 28                                            -- px de pantalla sobre los pies (≈ 0,45 del personaje de FAO a 0,5)

-- Escala (x, y) del anillo para que su elipse sea el círculo de radio `rango` casillas del mundo: se aplasta sola en isométrica y es redonda en cenital.
local function escalaRadio(x, y, rango)
  local ex, ey = delta(x + rango, y, x, y)
  local sx, sy = delta(x, y + rango, x, y)
  return math.sqrt(ex * ex + sx * sx) / ANILLO_MEDIO_ANCHO, math.sqrt(ey * ey + sy * sy) / ANILLO_MEDIO_ALTO
end

local function alfaTajo(t, dur)
  local total = 12 * TAJO_MS
  local a = math.min(1, t / (2 * TAJO_MS))
  return a * (1 - seg(t, total - 3 * TAJO_MS, total))
end

local function tajoSuelo(fx, t, sx, sy)
  local def = DatosJuego.habilidades.tajo
  local kx, ky = escalaRadio(fx.x, fx.y, def and def.rango or 2.5)
  local k = math.min(11, math.floor(t / TAJO_MS))
  if t > 12 * TAJO_MS then return end
  local crece = 0.6 + 0.4 * limitar(t / (6 * TAJO_MS), 0, 1)
  local img = imagen("tajo_AIR")
  if not img then return end
  local d = Datos.tajo_AIR
  love.graphics.setBlendMode("add")
  love.graphics.setColor(1, 1, 1, alfaTajo(t))
  love.graphics.draw(img, quad("tajo_AIR", k), sx, sy, 0, kx * crece, ky * crece, d.ox, d.oy)
  love.graphics.setBlendMode("alpha")
end

local function tajoEspadas(fx, t, sx, sy)
  local def = DatosJuego.habilidades.tajo
  local kx = escalaRadio(fx.x, fx.y, def and def.rango or 2.5)
  local t2 = t - TAJO_MS
  if t2 < 0 or t > 12 * TAJO_MS then return end
  local crece = 0.6 + 0.4 * limitar(t / (6 * TAJO_MS), 0, 1)
  love.graphics.setBlendMode("add")
  poner("tajo_SWORD", math.floor(t2 / TAJO_MS) % 6, sx, sy - TORSO, alfaTajo(t), kx * crece, false, false)
  love.graphics.setBlendMode("alpha")
end

-- Golpe (Slicing Chop): tres medias lunas de espada que cruzan al enemigo a la altura del torso, escalonadas. Cada secuencia son 11 cuadros: 0-4 el cuerpo oscuro del tajo al formarse
-- y 5-10 la estela fina; se reproducen enteros (80 ms/cuadro en FAO, aquí 60 para caber holgadamente en los 1,5 s de enfriamiento). La media luna abre hacia arriba a la derecha
-- en la hoja (-45°): se gira para que abra hacia quien golpea. fx.x, fx.y = el enemigo; fx.x0, fx.y0 = el atacante.
local GOLPES = { { "golpe_s3820303", 0, 0 }, { "golpe_s3820503", 0.07, 0.55 }, { "golpe_s3820203", 0.14, -0.55 } }
local GOLPE_MS = 0.06
local function golpe(fx, t, sx, sy)
  local x0, y0 = fx.x0 or fx.x - 1, fx.y0 or fx.y
  local dx, dy = delta(x0, y0, fx.x, fx.y)
  if dx * dx + dy * dy < 1 then dx, dy = -1, -1 end
  local giro = math.atan2(dy, dx) + math.pi / 4
  love.graphics.setBlendMode("add")
  for _, g in ipairs(GOLPES) do
    local sec, ini, extra = g[1], g[2], g[3]
    local u = t - ini
    local d = Datos[sec]
    if u >= 0 and u < d.n * GOLPE_MS then
      local k = math.floor(u / GOLPE_MS)
      local a = 1 - seg(u, (d.n - 2) * GOLPE_MS, d.n * GOLPE_MS)
      love.graphics.setColor(1, 1, 1, a)
      local cx, cy = centro(sec, k)          -- gira sobre el centro de lo visible del cuadro (el tajo no está centrado en la celda)
      love.graphics.draw(imagen(sec), quad(sec, k), sx, sy - PECHO, giro + extra, K * 1.1, K * 1.1, cx, cy)
    end
  end
  love.graphics.setBlendMode("alpha")
end

M.dibujar = { pantera = pantera, nova = ventisca, tajo = tajoEspadas, golpe = golpe }
M.suelo = { tajo = tajoSuelo }

-- Miniatura para la barra de poderes (cuadrado de `lado` px en (x, y)).
function M.icono(tipo, x, y, lado)
  if tipo == "golpe" then
    love.graphics.setBlendMode("add")
    poner("golpe_s3820303", 8, x + lado / 2, y + lado / 2, 1, lado / Datos.golpe_s3820303.w * 0.95, false, true)
    love.graphics.setBlendMode("alpha")
  elseif tipo == "tajo" then
    love.graphics.setBlendMode("add")
    poner("tajo_SWORD", 2, x + lado / 2, y + lado / 2, 1, lado / Datos.tajo_SWORD.w * 0.95, false, true)
    love.graphics.setBlendMode("alpha")
  elseif tipo == "pantera" then
    local sec, k = "S3920203", 2
    local d = Datos[sec]
    local esc = lado / d.w * 0.95
    local cx, cy = centro(sec, k)
    love.graphics.setBlendMode("add")
    poner("S3910203", 2, x + lado / 2, y + lado / 2, 0.8, esc * 0.55, false, true)
    poner(sec, k, x + lado / 2, y + lado / 2, 1, esc, false, true)
    love.graphics.setBlendMode("alpha")
  else
    local d = Datos.ice0101
    love.graphics.setBlendMode("add")
    poner("ice0101", 0, x + lado / 2, y + lado * 0.95, 1, lado / d.h * 1.0, false, false)
    love.graphics.setBlendMode("alpha")
  end
end

function M.existe(sec) return Datos[sec] ~= nil end

return M
