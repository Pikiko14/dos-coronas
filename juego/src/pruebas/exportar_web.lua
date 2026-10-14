-- Exporta los sprites del juego como PNG para la página web (web/img/sprites): las clases de cada facción, las
-- monturas y los jefes, dibujados con el mismo código que el juego. Se ejecuta con:
--     ..\love\lovec.exe juego --web
-- y deja los archivos en juego/capturas/web/ (después se copian a web/img/sprites).
local Personajes = require("src.presentacion.render.personajes")
local Datos = require("compartido.dominio.datos")
local Monturas = require("compartido.dominio.monturas")
local Log = require("compartido.infraestructura.log")

local E = {}

local ESCALA = 6

-- Dibuja una definición de personaje de frente sobre un lienzo transparente y la guarda ampliada.
local function guardar(nombre, def, lado)
  lado = lado or 40
  local pequeno = love.graphics.newCanvas(lado, lado)
  pequeno:setFilter("nearest", "nearest")
  local grande = love.graphics.newCanvas(lado * ESCALA, lado * ESCALA)
  grande:setFilter("nearest", "nearest")
  love.graphics.push("all")
  love.graphics.setCanvas({ pequeno, stencil = true })
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(1, 1, 1, 1)
  Personajes.dibujar(def, 1, false, 0, lado / 2, lado - 6)
  love.graphics.setCanvas({ grande, stencil = true })
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(pequeno, 0, 0, 0, ESCALA, ESCALA)
  love.graphics.pop()
  local datos = grande:newImageData()
  local ruta = Log.carpeta() .. "/capturas/web/" .. nombre .. ".png"
  local f = io.open(ruta, "wb")
  if f then
    f:write(datos:encode("png"):getString())
    f:close()
  end
end

function E.correr()
  Log.asegurar("capturas")
  Log.asegurar("capturas/web")
  local n = 0
  -- clases de cada facción
  for _, clase in ipairs(Datos.ORDEN_CLASES) do
    for _, fac in ipairs({ "albor", "umbra" }) do
      local def = Personajes.clases[clase] and Personajes.clases[clase][fac]
      if def then
        guardar("clase_" .. clase .. "_" .. fac, def)
        n = n + 1
      end
    end
  end
  -- monturas (las que se dibujan como criatura; las de vehículo se saltan)
  for id in pairs(Monturas.especies) do
    local def = Personajes.monturaDe(id, "albor")
    if def and (def.hoja or def.generada) and not def.vehiculo then
      guardar("montura_" .. id, def, def.escala and def.escala > 1.2 and 64 or 48)
      n = n + 1
    end
  end
  -- jefes y criaturas notables
  for _, id in ipairs({ "caballero", "titan", "behemot", "dragon_brasas", "liche", "golem", "demonio_rey", "hidra_ceniza", "rey_espectral", "ojo_abismo", "medusa_abisal" }) do
    local def = Personajes.de({ kind = "monstruo", monstruo = id })
    if def and Personajes.monstruos[id] then
      guardar("jefe_" .. id, def, (def.fila and (def.celda or 64) or 40) + 24)
      n = n + 1
    end
  end
  Log.info("exportar_web: " .. n .. " sprites en " .. Log.carpeta() .. "/capturas/web")
  print("exportar_web: " .. n .. " sprites")
  love.event.quit(0)
end

return E
