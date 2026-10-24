local Atlas = {}

local HOJAS = {
  "otsp_tiles_01.png",
  "otsp_walls_01.png",
  "otsp_walls_02.png",
  "otsp_nature_01.png",
  "otsp_town_01.png",
  "otsp_doors_01.png",
  "otsp_equipment_01.png",
  "pociones.png",
  "bonos.png",
  "pergaminos.png",
  "otsp_misc_01.png",
  "equipo_extra.png",
  "iconos_hud.png",
  "armas.png",
  "equipo_altos.png",
  "equipo_fao.png",
  "apariencias_iconos.png",
}

local alias = {
  tiles = "otsp_tiles_01.png",
  walls = "otsp_walls_01.png",
  walls2 = "otsp_walls_02.png",
  nature = "otsp_nature_01.png",
  town = "otsp_town_01.png",
  doors = "otsp_doors_01.png",
  equipment = "otsp_equipment_01.png",
  pociones = "pociones.png",
  bonos = "bonos.png",
  pergaminos = "pergaminos.png",
  misc = "otsp_misc_01.png",
  extra = "equipo_extra.png",
  hud = "iconos_hud.png",
  armas = "armas.png",
  altos = "equipo_altos.png",
  fao = "equipo_fao.png",
  apar = "apariencias_iconos.png",
}

local CARPETA = "arte/hojas"

local function claveMagenta(datos)
  datos:mapPixel(function(_, _, r, g, b, a)
    if r > 0.97 and g < 0.05 and b > 0.97 then
      return 0, 0, 0, 0
    end
    return r, g, b, a
  end)
end

local function claveGris(datos)
  datos:mapPixel(function(_, _, r, g, b, a)
    local R, G, B = r * 255, g * 255, b * 255
    if math.abs(R - 110) < 4 and math.abs(G - 110) < 4 and math.abs(B - 110) < 4 then
      return 0, 0, 0, 0
    end
    if r > 0.97 and g < 0.05 and b > 0.97 then
      return 0, 0, 0, 0
    end
    return r, g, b, a
  end)
end

local function imagenDesde(ruta, clave)
  if not love.filesystem.getInfo(ruta) then
    error("No encuentro " .. ruta .. ". Las láminas van en arte/hojas.")
  end
  local fd = love.filesystem.newFileData(ruta)
  local datos = love.image.newImageData(fd)
  clave(datos)
  local img = love.graphics.newImage(datos)
  img:setFilter("nearest", "nearest")
  return img
end

function Atlas.cargar()
  Atlas.carpeta = CARPETA
  Atlas.imgs = {}
  Atlas.quads = {}
  Atlas.cols = {}
  for _, nombre in ipairs(HOJAS) do
    local img = imagenDesde(CARPETA .. "/" .. nombre, claveMagenta)
    Atlas.imgs[nombre] = img
    Atlas.quads[nombre] = {}
    Atlas.cols[nombre] = math.floor(img:getWidth() / 32)
  end
  Atlas.imgs.humanos = imagenDesde(CARPETA .. "/humanos.png", claveGris)
  Atlas.quads.humanos = {}
  Atlas.cols.humanos = 1
  Atlas.recortes = {}
  for k, v in pairs(alias) do
    Atlas.imgs[k] = Atlas.imgs[v]
    Atlas.quads[k] = Atlas.quads[v]
    Atlas.cols[k] = Atlas.cols[v]
  end
end

function Atlas.quad(hoja, indice)
  indice = math.max(0, math.floor(indice or 0))
  local cache = Atlas.quads[hoja]
  local img = Atlas.imgs[hoja]
  if not img then return nil, nil end
  local q = cache[indice]
  if not q then
    local cols = Atlas.cols[hoja]
    local maxIdx = cols * math.floor(img:getHeight() / 32) - 1
    if indice > maxIdx then indice = maxIdx end
    local col = indice % cols
    local row = math.floor(indice / cols)
    q = love.graphics.newQuad(col * 32, row * 32, 32, 32, img:getDimensions())
    cache[indice] = q
  end
  return img, q
end

function Atlas.recorte(hoja, x, y, w, h, dx, dy, zoom, ox, oy, espejo)
  local img = Atlas.imgs[hoja]
  if not img then return end
  Atlas.recortes = Atlas.recortes or {}
  Atlas.recortes[hoja] = Atlas.recortes[hoja] or {}
  local clave = x .. "_" .. y .. "_" .. w .. "_" .. h
  local q = Atlas.recortes[hoja][clave]
  if not q then
    q = love.graphics.newQuad(x, y, w, h, img:getDimensions())
    Atlas.recortes[hoja][clave] = q
  end
  love.graphics.setColor(1, 1, 1, 1)
  local esc = zoom or 1
  love.graphics.draw(img, q, dx, dy, 0, espejo and -esc or esc, esc, ox or 0, oy or 0)
end

function Atlas.armaEnMano(item, clase, rec, x, y, zoom, espejo)
  if not item or not rec or not rec.mano then return end
  local z = zoom or 0.5
  local sign = espejo and -1 or 1
  local hx = x + (rec.mano.x - rec.w / 2) * z * sign
  local hy = y + (rec.mano.y - (rec.h - 6)) * z
  local tipo = clase and clase.arma or "espada"
  local ox, oy, rot, wz = 16, 26, 0, z * 0.85
  if tipo == "espada" then
    ox, oy, rot, wz = 23, 25, -0.45, z * 0.8
  elseif tipo == "arco" then
    ox, oy, rot, wz = 18, 20, 0.3, z * 0.75
  else
    ox, oy, rot, wz = 16, 28, 0, z * 0.8
  end
  if espejo then rot = -rot end
  local img, q = Atlas.quad(item.hoja, item.sprite)
  if not img then return end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(img, q, hx, hy, rot, sign * wz, wz, ox, oy)
end

-- El x2 del atlas es de 32 px y con el filtro del juego se lee como un bloque. Esta lámina es suave.
local imgX2
local function dibujarX2(x, y, zoom)
  if imgX2 == nil then
    local ok, img = pcall(love.graphics.newImage, "arte/hojas/x2.png")
    if ok and img then
      img:setFilter("linear", "linear")
      imgX2 = img
    else
      imgX2 = false
    end
  end
  if not imgX2 then return false end
  local w, h = imgX2:getWidth(), imgX2:getHeight()
  local e = (20 * (zoom or 1)) / w
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(imgX2, x, y, 0, e, e, w / 2, h / 2)
  return true
end

function Atlas.dibujar(hoja, indice, x, y, zoom, ox, oy, tinte)
  if hoja == "bonos" and dibujarX2(x, y, zoom) then return end
  local img, q = Atlas.quad(hoja, indice)
  if not img then return end
  if tinte then love.graphics.setColor(tinte[1], tinte[2], tinte[3], 1) else love.graphics.setColor(1, 1, 1, 1) end
  love.graphics.draw(img, q, x, y, 0, zoom or 1, zoom or 1, ox or 0, oy or 0)
end

-- Bloque ancho x alto en celdas, anclado al centro inferior.
function Atlas.bloque(hoja, indice, celdasX, celdasY, x, y, zoom)
  zoom = zoom or 1
  celdasX = celdasX or 1
  celdasY = celdasY or 1
  local cols = Atlas.cols[hoja] or 16
  local col0 = indice % cols
  local row0 = math.floor(indice / cols)
  local ancho = celdasX * 32
  local alto = celdasY * 32
  for cy = 0, celdasY - 1 do
    for cx = 0, celdasX - 1 do
      local id = (row0 + cy) * cols + (col0 + cx)
      local px = x + (cx * 32 - ancho / 2) * zoom
      local py = y + (cy * 32 - alto) * zoom
      Atlas.dibujar(hoja, id, px, py, zoom, 0, 0)
    end
  end
end

return Atlas
