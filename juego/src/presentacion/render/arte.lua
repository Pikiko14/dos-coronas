-- Carga de láminas del pack nuevo (arte/hojas/new-sprites), con caché.
local Arte = {}

local RAIZ = "arte/hojas/new-sprites/"
local imagenes = {}
local datos = {}
local recortes = {}

local function existe(ruta)
  return love.filesystem.getInfo(ruta) ~= nil
end

-- Imagen con filtro "nearest" para que los píxeles queden nítidos.
function Arte.img(ruta, suave)
  local clave = ruta .. (suave and "#s" or "")
  if imagenes[clave] then return imagenes[clave] end
  local completa = RAIZ .. ruta
  if not existe(completa) then error("No encuentro " .. completa) end
  local img = love.graphics.newImage(completa)
  img:setFilter(suave and "linear" or "nearest", suave and "linear" or "nearest")
  imagenes[clave] = img
  return img
end

function Arte.datos(ruta)
  if datos[ruta] then return datos[ruta] end
  local d = love.image.newImageData(RAIZ .. ruta)
  datos[ruta] = d
  return d
end

local quads = setmetatable({}, { __mode = "k" })

-- Quad (x, y, w, h) de una imagen, reutilizado.
function Arte.quad(img, x, y, w, h)
  local porImg = quads[img]
  if not porImg then
    porImg = {}
    quads[img] = porImg
  end
  local clave = x .. "," .. y .. "," .. w .. "," .. h
  local q = porImg[clave]
  if not q then
    q = love.graphics.newQuad(x, y, w, h, img:getDimensions())
    porImg[clave] = q
  end
  return q
end

-- Caja mínima con píxeles visibles dentro de un rectángulo de la lámina.
-- Sirve para ajustar un objeto por casillas aunque tenga margen transparente.
function Arte.recorte(ruta, x, y, w, h)
  local clave = ruta .. "|" .. x .. "," .. y .. "," .. w .. "," .. h
  if recortes[clave] then return recortes[clave] end
  local d = Arte.datos(ruta)
  local minx, miny, maxx, maxy = math.huge, math.huge, -1, -1
  local ancho, alto = d:getDimensions()
  for py = y, math.min(alto - 1, y + h - 1) do
    for px = x, math.min(ancho - 1, x + w - 1) do
      local _, _, _, a = d:getPixel(px, py)
      if a > 0.12 then
        if px < minx then minx = px end
        if px > maxx then maxx = px end
        if py < miny then miny = py end
        if py > maxy then maxy = py end
      end
    end
  end
  local r
  if maxx < 0 then
    r = { x = x, y = y, w = w, h = h }
  else
    r = { x = minx, y = miny, w = maxx - minx + 1, h = maxy - miny + 1 }
  end
  recortes[clave] = r
  return r
end

return Arte
