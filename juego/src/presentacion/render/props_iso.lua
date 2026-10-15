-- Objetos de las ciudades con el arte nuevo (arte/ciudad/props/): árboles, farolas, pozos, estatuas, flores... Solo se usan dentro de
-- las ciudades y en vista isométrica; fuera de ellas (y para lo que no está aquí) se sigue dibujando el arte anterior.
local Iso = require("src.presentacion.render.iso")

local M = {}

local MAPA = {
  arbol_pino = { "arbol1", "arbol2", "arbol3", "arbol4" },
  arbusto = { "arbusto1", "arbusto2" },
  farol = { "farol" }, pozo = { "pozo" }, barril = { "barril" }, maceta = { "maceta" }, caja = { "caja" }, banco = { "banco" },
  estatua_albor = { "estatua_albor" }, estatua_umbra = { "estatua_umbra" },
  flores_mixtas = { "flor1", "flor2", "flor3", "flor4", "flor5", "flor6" }, flor_roja = { "flor5" }, flor_blanca = { "flor1" },
  flor_amarilla = { "flor6" }, matas = { "junco" }, hierba_alta = { "junco" },
}

local imgs = {}
local function imagen(nombre)
  local im = imgs[nombre]
  if im == nil then
    local ruta = "arte/ciudad/props/" .. nombre .. ".png"
    if love.filesystem.getInfo(ruta) then
      im = love.graphics.newImage(ruta, { mipmaps = true })
      im:setFilter("linear", "linear")
    else
      im = false
    end
    imgs[nombre] = im
  end
  return im or nil
end

local function hash(x, y)
  local n = (x * 73856093 + y * 19349663) % 2147483647
  n = (n * 1103515245 + 12345) % 2147483647
  return (n % 10007) / 10007
end

-- Dibuja el prop con el arte nuevo si corresponde. (sx, sy): su pie en pantalla. Devuelve true si lo dibujó.
function M.dibujar(p, mapa, sx, sy, alfa, tinte)
  if not Iso.activo() then return false end
  local lista = MAPA[p.tipo]
  if not lista then return false end
  local bio = mapa.bioma and mapa.bioma[p.x] and mapa.bioma[p.x][p.y]
  if bio ~= "ciudad" then return false end
  local im = imagen(lista[math.floor(hash(p.x, p.y) * #lista) % #lista + 1])
  if not im then return false end
  local c = tinte or { 1, 1, 1 }
  love.graphics.setColor(c[1], c[2], c[3], alfa or 1)
  love.graphics.draw(im, sx, sy, 0, 0.34, 0.34, im:getWidth() / 2, im:getHeight() - 6)
  return true
end

return M
