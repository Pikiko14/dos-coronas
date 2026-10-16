-- Generador de los sprites de las clases nuevas (se ejecuta a mano; los PNG resultantes se guardan en el
-- repositorio y el juego los carga como cualquier otra hoja):
--     ..\love\lovec.exe herramientas\generar_clases
-- Salida:
--   juego/arte/hojas/new-sprites/Characters/Lancero.png, Nigromante.png, Esbirro_esqueleto.png,
--       Esbirro_espectro.png   hojas de 96 x 128 (3 cuadros x 4 direcciones de 32 x 32).
--   juego/arte/hojas/equipo_extra.png   iconos de armas y armaduras de las clases nuevas (ver iconos.lua).
-- Además escribe vistas previas en %TEMP% (clases_previa.png, iconos_previa.png).
local RAIZ = "C:/Users/User/juegos/dos-coronas/"
local P = require("pixel")
local Personajes = require("personajes")

local function guardar(datos, ruta)
  local f = assert(io.open(ruta, "wb"))
  f:write(datos:encode("png"):getString())
  f:close()
end

function love.load()
  local carpeta = RAIZ .. "juego/arte/hojas/new-sprites/Characters/"
  local nombres = {
    { "lancero", "Lancero.png" }, { "nigromante", "Nigromante.png" },
    { "esqueleto", "Esbirro_esqueleto.png" }, { "espectro", "Esbirro_espectro.png" },
  }
  -- vista previa: cada hoja ampliada x5 sobre fondo verde
  local esc = 5
  local pv = love.graphics.newCanvas(#nombres * 96 * esc + 20 * (#nombres + 1), 128 * esc + 40)
  love.graphics.setCanvas(pv)
  love.graphics.clear(0.33, 0.52, 0.3, 1)
  for i, n in ipairs(nombres) do
    local datos = Personajes.hoja(n[1])
    guardar(datos, carpeta .. n[2])
    local img = love.graphics.newImage(datos)
    img:setFilter("nearest", "nearest")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, 20 + (i - 1) * (96 * esc + 20), 20, 0, esc, esc)
  end
  love.graphics.setCanvas()
  local fp = io.open(os.getenv("TEMP") .. "/clases_previa.png", "wb")
  fp:write(pv:newImageData():encode("png"):getString())
  fp:close()

  local ok, Iconos = pcall(require, "iconos")
  if ok then Iconos.generar(RAIZ, guardar) end
  require("hud").generar(RAIZ, guardar)
  love.event.quit()
end
