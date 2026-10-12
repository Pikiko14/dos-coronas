local Mapa = require("compartido.dominio.mapa")

local T = {}

local SUELOS = {
  [1] = "hierba",
  [2] = "camino",
  [3] = "adoquin",
  [4] = "agua",
  [5] = "muro",
}

function T.desdeTabla(exportado)
  if type(exportado) ~= "table" or not exportado.width or not exportado.height then
    return nil, "El mapa no tiene ancho y alto."
  end
  local mapa = Mapa.nuevo(exportado.width, exportado.height)
  mapa.tiled = true
  local capa
  for _, layer in ipairs(exportado.layers or {}) do
    if layer.type == "tilelayer" or layer.data then
      capa = layer
      break
    end
  end
  if not capa or not capa.data then return nil, "No hay capa de tiles." end
  local w = capa.width or exportado.width
  local h = capa.height or exportado.height
  local i = 1
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local gid = capa.data[i] or 0
      i = i + 1
      local tipo = SUELOS[gid] or (gid == 0 and "hierba" or "hierba")
      mapa.suelo[x] = mapa.suelo[x] or {}
      mapa.suelo[x][y] = tipo
      if tipo == "agua" or tipo == "muro" then
        mapa.bloque[x] = mapa.bloque[x] or {}
        mapa.bloque[x][y] = true
      end
    end
  end
  return mapa
end

function T.desdeArchivo(ruta)
  if not love.filesystem.getInfo(ruta) then return nil, "No está " .. ruta end
  local chunk, err = love.filesystem.load(ruta)
  if not chunk then return nil, err end
  local ok, exportado = pcall(chunk)
  if not ok then return nil, exportado end
  return T.desdeTabla(exportado)
end

return T
