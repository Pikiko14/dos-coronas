-- Arte de mapa FAO (arte/mapa/, horneado por herramientas/generar_mapa/hornear_mapa.py): árboles, rocas, plantas, props de las
-- ciudades y los muros de las ciudades. Todo viene ya a la escala de las casas (una casilla del arte original = 24 px de paso), así que
-- se dibuja 1:1. Solo se usa en vista isométrica; con DC_MAPA_FAO=0 todo vuelve al arte anterior.
-- Los objetos de pie (árboles, props) se dibujan con la base en el punto que se pide. Los de suelo que se hornean dentro de los bloques del
-- terreno (flores, setas, hojas...) se dibujan con la transformación inversa de la proyección, para que tras proyectarse el bloque se vean
-- de pie y no aplastados.
local Iso = require("src.presentacion.render.iso")
local Datos = require("src.presentacion.render.mapa_fao_datos")

local M = {}

-- Las imágenes se hornean a Datos.esc de su original, pensando en el zoom normal del juego (2); en el mundo una casilla mide 24 píxeles de
-- paso, así que al dibujarlas hay que reducirlas a la mitad de lo que miden horneadas (K). Así cada píxel de pantalla sale de un píxel real.
local K = 0.375 / (Datos.esc or 0.375)

function M.activo()
  if M._activo == nil then M._activo = os.getenv("DC_MAPA_FAO") ~= "0" and Iso.activo() end
  return M._activo
end

local imgs = {}
local function imagen(f)
  local im = imgs[f]
  if im == nil then
    local ruta = "arte/mapa/" .. f .. ".png"
    if love.filesystem.getInfo(ruta) then
      im = love.graphics.newImage(ruta, { mipmaps = true })
      im:setFilter("linear", "linear")
      im:setMipmapFilter("linear", 0)
    else
      im = false
    end
    imgs[f] = im
  end
  return im or nil
end

function M.tiene(nombre)
  local l = Datos.objetos[nombre]
  return M.activo() and l ~= nil and #l > 0
end

-- Plantas altas que se mecen con el viento: { píxeles que se mueve la copa, rapidez }
local VIVAS = {
  arbol = { 2.2, 0.9 }, arbol_pino = { 1.6, 1.0 }, arbol_pino_umbra = { 1.6, 1.0 }, palma = { 2.6, 1.1 },
  arbusto = { 1.0, 1.2 }, matorral = { 0.8, 1.2 },
}
local TIRA = 5
local tiras = {}
local function tirasDe(im, w, h)
  local l = tiras[im]
  if l then return l end
  l = {}
  local y = 0
  local iw, ih = im:getDimensions()
  while y < h do
    local alto = math.min(TIRA, h - y)
    l[#l + 1] = { quad = love.graphics.newQuad(0, y, w, alto, iw, ih), y = y, arriba = 1 - (y + alto / 2) / h }
    y = y + alto
  end
  tiras[im] = l
  return l
end

M.estatico = false      -- mientras se hornea un bloque del terreno nada se mueve

-- Dibuja el objeto `nombre` (variante cualquiera: se toma módulo) con la base en (sx, sy). `horneado`: se está dibujando dentro de un
-- bloque del terreno, en píxeles de casilla sin proyectar; (sx, sy) es entonces el centro de abajo de la casilla.
function M.dibujar(nombre, variante, sx, sy, tinte, alfa, fase, horneado)
  local lista = Datos.objetos[nombre]
  if not lista or #lista == 0 or not M.activo() then return false end
  local d = lista[((variante or 0) % #lista) + 1]
  local im = imagen(d.f)
  if not im then return false end
  if tinte then love.graphics.setColor(tinte[1], tinte[2], tinte[3], alfa or 1) else love.graphics.setColor(1, 1, 1, alfa or 1) end
  if horneado then
    local k, h = Iso.HW / 32, Iso.HH / 32
    local t = love.math.newTransform()
    -- inversa de la proyección: lo que se dibuje aquí se verá de pie cuando el bloque se proyecte
    t:setMatrix("row", 1 / (2 * k), 1 / (2 * h), 0, sx, -1 / (2 * k), 1 / (2 * h), 0, sy - 15, 0, 0, 1, 0, 0, 0, 0, 1)
    love.graphics.push()
    love.graphics.applyTransform(t)
    love.graphics.draw(im, -d.w * K / 2, -d.h * K, 0, K, K)
    love.graphics.pop()
    return true
  end
  local viva = VIVAS[nombre]
  if viva and d.h * K >= 24 and not M.estatico then
    local ahora = love.timer.getTime()
    local f = fase or 0
    local rafaga = 0.7 + 0.3 * math.sin(ahora * 0.3 + f * 0.15)
    local viento = (math.sin(ahora * viva[2] + f) + 0.25 * math.sin(ahora * viva[2] * 1.9 + f * 1.6)) * rafaga
    local amp = viva[1] * viento
    local x0, y0 = sx - d.w * K / 2, sy - d.h * K
    for _, ti in ipairs(tirasDe(im, d.w, d.h)) do
      love.graphics.draw(im, ti.quad, x0 + amp * ti.arriba * ti.arriba, y0 + ti.y * K, 0, K, K)
    end
    return true
  end
  love.graphics.draw(im, sx - d.w * K / 2, sy - d.h * K, 0, K, K)
  return true
end

-- ------------------------------------------------------------------------------------------------------------------------ muros
local SESGO = 5     -- píxeles que sube la base del muro respecto al centro de la casilla (la base real queda a medio grosor)

function M.murosActivo()
  return M.activo() and Datos.muros ~= nil and next(Datos.muros) ~= nil and os.getenv("DC_MUROS_FAO") ~= "0"
end

local function esMuro(mapa, x, y)
  local s = mapa.suelo[x] and mapa.suelo[x][y]
  return s == "muralla"
end

-- Casillas de muralla visibles de un mapa, con qué vecinos son muralla. Se calcula una vez por mapa.
--  * mundo: las murallas de las ciudades (estilo de su corona);
--  * mazmorras: solo las que tocan suelo (el resto es roca maciza, que se pinta oscura); estilo y color de cada mazmorra;
--  * campo de batalla y estandarte: todas, con el estilo del bando de cada lado.
function M.lista(mapa)
  if mapa._murosFao then return mapa._murosFao end
  local lista = {}
  local function ponerFiltrado(x, y, estilo, tinte, visible)
    if visible(x, y) then
      lista[#lista + 1] = { x = x, y = y, estilo = estilo, tinte = tinte, vx = {} }
    end
  end
  if mapa.mazmorra then
    local estilo = mapa.mazmorra == "mz1" and "albor" or "umbra"
    local t = mapa.tinte or { 1, 1, 1 }
    local tinte = { t[1] * 0.85, t[2] * 0.85, t[3] * 0.85 }
    local function visible(x, y)
      for dy = -1, 1 do
        for dx = -1, 1 do
          local n = mapa.suelo[x + dx] and mapa.suelo[x + dx][y + dy]
          if n and n ~= "muralla" then return true end
        end
      end
      return false
    end
    for x = 0, mapa.w - 1 do
      for y = 0, mapa.h - 1 do
        if esMuro(mapa, x, y) then ponerFiltrado(x, y, estilo, tinte, visible) end
      end
    end
  elseif #(mapa.ciudades or {}) > 0 then
    for _, c in ipairs(mapa.ciudades) do
      local estilo = c.faccion == "umbra" and "umbra" or "albor"
      for y = c.y, c.y + c.h - 1 do
        for x = c.x, c.x + c.w - 1 do
          if esMuro(mapa, x, y) and mapa.bioma[x] and mapa.bioma[x][y] == "ciudad" then
            lista[#lista + 1] = { x = x, y = y, estilo = estilo }
          end
        end
      end
    end
  else
    for x = 0, mapa.w - 1 do
      for y = 0, mapa.h - 1 do
        if esMuro(mapa, x, y) and mapa.bioma[x] and (mapa.bioma[x][y] == "batalla" or mapa.bioma[x][y] == "estandarte") then
          local l = mapa.lado[x] and mapa.lado[x][y]
          lista[#lista + 1] = { x = x, y = y, estilo = l == "umbra" and "umbra" or "albor" }
        end
      end
    end
  end
  -- qué vecinos son muralla visible (solo cuentan los de la lista)
  local hay = {}
  for _, m in ipairs(lista) do hay[m.x * 4096 + m.y] = true end
  for _, m in ipairs(lista) do
    m.e, m.o = hay[(m.x + 1) * 4096 + m.y] or false, hay[(m.x - 1) * 4096 + m.y] or false
    m.s, m.n = hay[m.x * 4096 + m.y + 1] or false, hay[m.x * 4096 + m.y - 1] or false
  end
  mapa._murosFao = lista
  return lista
end

-- Piedras y grietas del campo de batalla (decorado con colisión): se dibujan como rocas de pie.
function M.decorProps(mapa)
  if mapa._decorFao then return mapa._decorFao end
  local lista = {}
  if mapa.decorado then
    for x, col in pairs(mapa.decorado) do
      for y, tipo in pairs(col) do
        if tipo == "grieta" or tipo == "piedra" then lista[#lista + 1] = { x = x, y = y, tipo = "roca" } end
      end
    end
  end
  mapa._decorFao = lista
  return lista
end

local quads = {}
local function mitad(im, w, h, der)
  local clave = im
  local q = quads[clave]
  if not q then
    local iw, ih = im:getDimensions()
    q = { izq = love.graphics.newQuad(0, 0, w / 2, h, iw, ih), der = love.graphics.newQuad(w / 2, 0, w - w / 2, h, iw, ih) }
    quads[clave] = q
  end
  return der and q.der or q.izq
end

-- Dibuja una casilla de muro con la base sobre el centro de la casilla (gx, gy en pantalla).
function M.dibujarMuro(m, gx, gy, alfa)
  local rodajas = Datos.muros[m.estilo]
  if not rodajas then return end
  local t = m.tinte or { 1, 1, 1 }
  love.graphics.setColor(t[1], t[2], t[3], alfa or 1)
  local function brazo(eje, der)
    local n = #rodajas
    local d = rodajas[((eje == "x" and m.x or m.y) % n) + 1]
    local im = imagen(d.f)
    if not im then return end
    local q = mitad(im, d.w, d.h, der)
    local y0 = gy - SESGO - d.by * K
    if eje == "x" then
      love.graphics.draw(im, q, gx - d.w * K / 2 + (der and d.w * K / 2 or 0), y0, 0, K, K)
    else
      love.graphics.draw(im, q, gx + d.w * K / 2 - (der and d.w * K / 2 or 0), y0, 0, -K, K)
    end
  end
  local x_solo = (m.e or m.o) and not (m.s or m.n)
  local y_solo = (m.s or m.n) and not (m.e or m.o)
  if m.e and m.o then
    -- recto en x: las dos mitades de la misma rodaja
    brazo("x", false); brazo("x", true)
  else
    if m.o then brazo("x", false) end
    if m.e then brazo("x", true) end
  end
  if m.s and m.n then
    brazo("y", false); brazo("y", true)
  else
    if m.n then brazo("y", false) end
    if m.s then brazo("y", true) end
  end
  if not (m.e or m.o or m.s or m.n) then brazo("x", false); brazo("x", true) end
  return x_solo, y_solo
end

return M
