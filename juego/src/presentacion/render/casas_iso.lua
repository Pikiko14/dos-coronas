-- Casas isométricas (arte/casas/<código>.png, pre-renderizadas) para los edificios de las ciudades. Se dibujan encima de la huella
-- del edificio en el mapa y se ordenan con los personajes, así se puede pasar por detrás de ellas.
-- El dibujo procedural anterior (render/terreno.lua dibujarEdificio y render/casas.lua) sigue ahí, desactivado mientras esto esté activo:
-- DC_CASAS_ISO=0 en el entorno (o Ajustes.casasIso = false) vuelve a las casas antiguas.
local Ajustes = require("src.presentacion.ajustes")
local Iso = require("src.presentacion.render.iso")

local M = {}
local TILE = 32

-- Tres tipos de casa por corona, uno por tamaño de parcela, con la misma gama de color para que cada ciudad se vea armoniosa:
-- Albor, tejados azules y paredes claras; Umbra, tejados fríos y piedra oscura. Las tiendas usan la casa de su tamaño.
local POZOS = {
  albor = { pequena = { "01-005" }, mediana = { "01-010" }, grande = { "01-002" } },
  umbra = { pequena = { "02-006" }, mediana = { "02-005" }, grande = { "01-003" } },
}
-- (Lote anterior, con 5 a 6 casas por corona: albor pequena 01-007/01-008/01-009/00-006, mediana 01-010/01-005/02-005/02-002/00-005,
--  grande 01-006/01-002/01-001/02-001, tiendas mercado 01-005, armero 01-007, establo 00-010; umbra pequena 02-006/02-004/00-003/01-008,
--  mediana 00-004/02-007/00-005/01-004/02-005, grande 01-003/00-007/00-008/01-001.)

function M.activo()
  if M._activo == nil then
    local env = os.getenv("DC_CASAS_ISO")
    if env == "0" then
      M._activo = false
    elseif Ajustes.casasIso == false then
      M._activo = false
    else
      M._activo = love.filesystem.getInfo("arte/casas/01-005.png") ~= nil
    end
  end
  return M._activo
end

local function hash(x, y, sal)
  local n = (x * 73856093 + y * 19349663 + (sal or 0) * 83492791) % 2147483647
  n = (n * 1103515245 + 12345) % 2147483647
  return (n % 10007) / 10007
end

local imagenes = {}

local function imagen(codigo)
  local im = imagenes[codigo]
  if im == nil then
    local ruta = "arte/casas/" .. codigo .. ".png"
    if love.filesystem.getInfo(ruta) then
      im = love.graphics.newImage(ruta, { mipmaps = true })
      im:setFilter("linear", "linear")
      im:setMipmapFilter("linear", 0.2)
    else
      im = false
    end
    imagenes[codigo] = im
  end
  return im or nil
end

-- Casa de un edificio: siempre la misma para el mismo sitio del mapa.
function M.codigoDe(e)
  if e._casaIso then return e._casaIso end
  local pozo = POZOS[e.faccion == "umbra" and "umbra" or "albor"]
  local lista = pozo[e.tamano or "mediana"] or pozo.mediana
  local c = lista[math.floor(hash(e.x, e.y, 3) * #lista) % #lista + 1]
  e._casaIso = c
  return c
end

-- Rectángulo (en píxeles de pantalla del mundo) que ocupa el dibujo de la casa: x0, y0, ancho, alto y escala.
-- En vista isométrica la casa se apoya en el rombo de su huella; en cenital, en el borde de abajo.
local function caja(e, img)
  if Iso.activo() then
    local ancho = (e.w + e.h) * Iso.HW * 1.04
    local esc = ancho / img:getWidth()
    local alto = img:getHeight() * esc
    local gx, gy = Iso.suelo(e.x + e.w, e.y + e.h)     -- la esquina de delante del rombo
    return gx - ancho / 2, gy + 2 - alto, ancho, alto, esc
  end
  local ancho = e.w * TILE * 1.12
  local esc = ancho / img:getWidth()
  local alto = img:getHeight() * esc
  local cx = (e.x + e.w / 2) * TILE
  local base = (e.y + e.h) * TILE + 6
  return cx - ancho / 2, base - alto, ancho, alto, esc
end

-- Dibuja la casa con su base apoyada en su huella. (camX, camY) es la cámara.
function M.dibujar(e, camX, camY, alfa)
  local img = imagen(M.codigoDe(e))
  if not img then return end
  local x0, y0, _, _, esc = caja(e, img)
  love.graphics.setColor(1, 1, 1, alfa or 1)
  love.graphics.draw(img, x0 - camX, y0 - camY, 0, esc, esc)
end

-- ¿Queda el punto (px, py) (casillas) detrás de la casa, tapado por su dibujo?
function M.tapa(e, px, py)
  local img = imagen(M.codigoDe(e))
  if not img then return false end
  local x0, y0, ancho, alto = caja(e, img)
  if px >= e.x + e.w or py >= e.y + e.h then return false end     -- está delante o a un lado (no queda tapado)
  local gx, gy = Iso.suelo(px, py)
  return gx > x0 and gx < x0 + ancho and gy - 20 > y0 and gy < y0 + alto
end

return M
