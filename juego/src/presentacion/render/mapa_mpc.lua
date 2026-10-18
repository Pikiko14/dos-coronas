-- Dibujo de los mapas de Free Angels Online (.mpc, compartido/dominio/mapa_mpc.lua): el suelo con las texturas reales de FAO y los objetos (árboles, rocas, plantas...) con sus sprites.
-- Arte de un juego ajeno (FAO): prototipo. Lo que hornea herramientas/generar_mapa/hornear_mpc.py está en arte/mapas_fao/ (atlas del suelo y de los objetos).
--
-- FAO dibuja sus mapas en VISTA CENITAL (su minimapa lo muestra: el puente llega a la isla, las rocas y los muros siguen la costa); girarlos a isométrica desarma los objetos que están
-- colocados en la pantalla. Por eso los mapas de FAO se ven en cenital (Iso.forzar(false) en D.camara) y a su escala nativa: Dos Coronas dibuja a la mitad (zoom 2: un píxel de FAO = un píxel
-- de pantalla) y su casilla (32 px de mundo) son 64 px de FAO = 2 x 2 celdas del .mpc.
-- Suelo: texturas continuas muestreadas por posición y fundidas donde cambia el tileset. Objetos: sprites a tamaño nativo (atlas a escala 1, se dibujan a 0,5), anclados en su punto de apoyo
-- y ordenados con los personajes por su y.
local Iso = require("src.presentacion.render.iso")

local M = {}

local K = 0.5                 -- atlas de objetos (escala 1 de FAO) -> mundo (zoom 2: un píxel de FAO = un píxel de pantalla)
local TROZO = 16              -- casillas del juego por lado de cada trozo del índice espacial de objetos

local atlas = {}              -- por mapa (id): { suelo = { img, quads }, objetos = { img, quads } } (false = no se pudo cargar)

local function cargarImagen(ruta, suave)
  if not love.filesystem.getInfo(ruta) then return nil end
  local img = love.graphics.newImage(ruta)
  img:setFilter(suave and "linear" or "nearest", suave and "linear" or "nearest")
  return img
end

local function datosDe(mapa)
  local m = mapa.mpc
  local a = atlas[m.id]
  if a ~= nil then return a end
  a = { suelo = { quads = {} }, objetos = { quads = {} } }
  a.suelo.img = cargarImagen("arte/mapas_fao/" .. m.atlasSuelo.archivo, true)
  a.objetos.img = cargarImagen("arte/mapas_fao/" .. m.atlasObjetos.archivo, true)
  if not a.suelo.img then a = false end
  atlas[m.id] = a
  return a
end

-- Suelo de la casilla del juego (x, y) en (px, py) (esquina, en píxeles de mundo cenitales; 32 px por casilla = 64 px de FAO). Cada tileset de FAO es una textura continua de 512x512: la casilla
-- toma el trozo de 64x64 que le toca por su posición ((x mod 8, y mod 8) * 64), así el suelo no repite un tile ni deja costuras. Donde cambia el tileset se funde con el vecino (una franja de
-- FUNDIDO px con la textura del vecino que se va apagando hacia dentro). Fuera del mapa se repite la casilla más cercana (así la vista no acaba en negro).
local FUNDIDO = 12
local MALLA

local function tilesetDe(m, mapa, gx, gy)
  local fx, fy = math.min(m.fw - 1, gx * 2), math.min(m.fh - 1, gy * 2)
  local ts = m.ts[fy * m.fw + fx + 1]
  local t = m.tilesets[ts]
  return ts, t and t.x, t and t.y
end

function M.suelo(mapa, x, y, px, py)
  local m = mapa.mpc
  if not m then return false end
  local a = datosDe(mapa)
  if not a then return false end
  local cx, cy = math.max(0, math.min(mapa.w - 1, x)), math.max(0, math.min(mapa.h - 1, y))
  local ts, ox, oy = tilesetDe(m, mapa, cx, cy)
  if not ox then return true end
  local ancho, alto = m.atlasSuelo.ancho, m.atlasSuelo.alto
  local u, v = (x % 8) * 64, (y % 8) * 64
  local clave = ts * 64 + (x % 8) * 8 + (y % 8)
  local q = a.suelo.quads[clave]
  if not q then
    q = love.graphics.newQuad(ox + u, oy + v, 64, 64, ancho, alto)
    a.suelo.quads[clave] = q
  end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(a.suelo.img, q, px, py, 0, 0.5, 0.5)
  if x < 0 or y < 0 or x >= mapa.w or y >= mapa.h then return true end
  -- fundido con los vecinos de otro tileset (la textura del vecino a esta altura, de más a menos opaca hacia dentro de la casilla)
  for _, d in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
    local nx, ny = x + d[1], y + d[2]
    if nx >= 0 and ny >= 0 and nx < mapa.w and ny < mapa.h then
      local ts2, ox2, oy2 = tilesetDe(m, mapa, nx, ny)
      if ts2 ~= ts and ox2 then
        local function vert(vx, vy, alfa)
          return { px + vx, py + vy, (ox2 + u + vx * 2) / ancho, (oy2 + v + vy * 2) / alto, 1, 1, 1, alfa }
        end
        local e, i0 = 0.55, 0
        local vs
        if d[2] == -1 then vs = { vert(0, 0, e), vert(32, 0, e), vert(32, FUNDIDO, i0), vert(0, FUNDIDO, i0) }
        elseif d[2] == 1 then vs = { vert(0, 32, e), vert(32, 32, e), vert(32, 32 - FUNDIDO, i0), vert(0, 32 - FUNDIDO, i0) }
        elseif d[1] == -1 then vs = { vert(0, 0, e), vert(0, 32, e), vert(FUNDIDO, 32, i0), vert(FUNDIDO, 0, i0) }
        else vs = { vert(32, 0, e), vert(32, 32, e), vert(32 - FUNDIDO, 32, i0), vert(32 - FUNDIDO, 0, i0) } end
        if not MALLA then MALLA = love.graphics.newMesh(4, "fan", "stream") end
        MALLA:setTexture(a.suelo.img)
        MALLA:setVertices(vs)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(MALLA)
      end
    end
  end
  return true
end

-- Índice espacial de los objetos dibujables, por trozos de 16x16 casillas.
local function indice(mapa)
  local m = mapa.mpc
  if m._trozos then return m._trozos end
  local t = {}
  for _, o in ipairs(m.objetos) do
    local cx, cy = math.floor(o.x / 64 / TROZO), math.floor(o.y / 64 / TROZO)
    local k = cx * 1000 + cy
    t[k] = t[k] or {}
    t[k][#t[k] + 1] = o
  end
  m._trozos = t
  return t
end

-- Objetos a menos de `radio` casillas de (x, y).
function M.visibles(mapa, x, y, radio)
  local m = mapa.mpc
  if not m then return {} end
  local t = indice(mapa)
  local out = {}
  local c0x, c1x = math.floor((x - radio) / TROZO), math.floor((x + radio) / TROZO)
  local c0y, c1y = math.floor((y - radio) / TROZO), math.floor((y + radio) / TROZO)
  for cx = c0x, c1x do
    for cy = c0y, c1y do
      local l = t[cx * 1000 + cy]
      if l then
        for _, o in ipairs(l) do
          local dx, dy = o.x / 64 - x, o.y / 64 - y
          if dx > -radio and dx < radio and dy > -radio and dy < radio then out[#out + 1] = o end
        end
      end
    end
  end
  return out
end

-- Sombra de un objeto (FAO guarda cada una en otro sprite: una silueta negra con la misma ancla): se dibuja antes que los personajes y los objetos, con un 40 % de opacidad.
function M.dibujarSombra(mapa, o, sx, sy)
  local m = mapa.mpc
  local d = m.defs[o.id]
  local s = d and d.s
  local a = s and datosDe(mapa)
  if not a or not a.objetos.img then return end
  local clave = -o.id
  local q = a.objetos.quads[clave]
  if not q then
    q = love.graphics.newQuad(s[1], s[2], s[3], s[4], m.atlasObjetos.ancho, m.atlasObjetos.alto)
    a.objetos.quads[clave] = q
  end
  love.graphics.setColor(0, 0, 0, 0.4)
  love.graphics.draw(a.objetos.img, q, sx, sy, 0, K, K, s[5], s[6])
end

-- Dibuja el objeto con su punto de apoyo en (sx, sy) (pantalla). tiempo: segundos (para los animados).
-- ¿Este objeto alto (con profundidad, sprite de 80 px de FAO o más) se dibuja delante del personaje y le tapa el torso? (px, py) = el torso del personaje en pantalla; (sx, sy) = el punto de
-- apoyo del objeto. Las piezas de suelo (sin z) no tapan nunca. Es el atenuado de los árboles: el objeto se dibuja al 45 % mientras tapa.
function M.tapa(mapa, o, sx, sy, px, py)
  local d = mapa.mpc.defs[o.id]
  if not (d and d.z and not d.p) then return false end
  local c = d.f[1]
  if c[4] < 80 then return false end
  return px > sx - c[5] * K and px < sx + (c[3] - c[5]) * K and py > sy - c[6] * K and py < sy + (c[4] - c[6]) * K
end

function M.dibujarObjeto(mapa, o, sx, sy, tiempo, alfa)
  local m = mapa.mpc
  local d = m.defs[o.id]
  local a = datosDe(mapa)
  if not d or not a or not a.objetos.img then return end
  local f = d.f
  local n = #f
  local k = 1
  if n > 1 then
    -- animación: cada cuadro dura su retardo (unidades de 60 ms) y cada objeto va desfasado según dónde está
    local total = 0
    for i = 1, n do total = total + math.max(1, f[i][7]) end
    local fase = ((tiempo or 0) * 1000 / 60 + (o.x * 7 + o.y * 13) % total) % total
    for i = 1, n do
      fase = fase - math.max(1, f[i][7])
      if fase < 0 then k = i break end
    end
  end
  local cuadro = f[k]
  local clave = o.id * 64 + k
  local q = a.objetos.quads[clave]
  if not q then
    q = love.graphics.newQuad(cuadro[1], cuadro[2], cuadro[3], cuadro[4], m.atlasObjetos.ancho, m.atlasObjetos.alto)
    a.objetos.quads[clave] = q
  end
  if d.mezcla == "add" then love.graphics.setBlendMode("add") end
  love.graphics.setColor(1, 1, 1, alfa or 1)
  love.graphics.draw(a.objetos.img, q, sx, sy, 0, K, K, cuadro[5], cuadro[6])
  if d.mezcla == "add" then love.graphics.setBlendMode("alpha") end
end

-- Carga las imágenes del mapa (para el arranque o al entrar, así el primer fotograma no se queda esperando).
function M.precargar(mapa)
  if mapa.mpc then datosDe(mapa) end
end

function M.olvidar()
  for _, a in pairs(atlas) do
    if a then
      if a.suelo.img then a.suelo.img:release() end
      if a.objetos.img then a.objetos.img:release() end
    end
  end
  atlas = {}
end

return M
