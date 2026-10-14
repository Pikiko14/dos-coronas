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
  -- addons del Item Mall: uno de frente cada uno, y una hoja con las cuatro direcciones para revisarlos
  local Mall = require("compartido.dominio.mall")
  local lista = {}
  for _, id in ipairs(Mall.ORDEN_ADDONS) do
    local def = Personajes.skins[id]
    if def then
      guardar("addon_" .. id, def)
      if id == "skin_gladiador" or id == "skin_barbaro" or id == "skin_archimago" or id == "skin_hechicero_fuego" or id == "skin_montaraz"
        or id == "skin_arquero_elfico" or id == "skin_sacerdotisa_alba" or id == "skin_hoplita" or id == "skin_senor_huesos" or id == "skin_dama_lich" then
        lista[#lista + 1] = def
      end
      n = n + 1
    end
  end
  do
    local E = 3
    local ancho, alto = 4 * 36 * E + 10, #lista * 36 * E + 10
    local cv = love.graphics.newCanvas(ancho, alto)
    love.graphics.push("all")
    love.graphics.setCanvas({ cv, stencil = true })
    love.graphics.clear(0.3, 0.42, 0.55, 1)
    for k, def in ipairs(lista) do
      for dir = 1, 4 do
        love.graphics.push()
        love.graphics.translate(5 + (dir - 1) * 36 * E + 18 * E, (k - 1) * 36 * E + 33 * E)
        love.graphics.scale(E, E)
        love.graphics.setColor(1, 1, 1, 1)
        Personajes.dibujar(def, dir, false, 0, 0, 0)
        love.graphics.pop()
      end
    end
    love.graphics.pop()
    local datos = cv:newImageData()
    local f = io.open(Log.carpeta() .. "/capturas/web/addons_vista.png", "wb")
    if f then f:write(datos:encode("png"):getString()) f:close() end
  end
  -- hoja de revisión de las animaciones de ataque: una fila por criatura, 8 instantes del ataque (cerca y de lejos)
  do
    local Dibujo = require("src.presentacion.render.dibujo")
    local filas = {
      { kind = "monstruo", monstruo = "gato", dir = 3 },
      { kind = "monstruo", monstruo = "jabali", dir = 1 },
      { kind = "monstruo", monstruo = "gargola", dir = 4 },
      { kind = "jugador", clase = "guerrero", faccion = "albor", dir = 3 },
      { kind = "jugador", clase = "guerrero", faccion = "albor", addon = "skin_hoplita", dir = 1 },
      { kind = "jugador", clase = "mago", faccion = "umbra", addon = "skin_archimago", dir = 3, lejos = true },
      { kind = "jugador", clase = "cazador", faccion = "albor", dir = 4, lejos = true },
    }
    local E2, W, H = 3, 8, #filas
    local cv = love.graphics.newCanvas(W * 40 * E2, H * 44 * E2)
    love.graphics.push("all")
    love.graphics.setCanvas({ cv, stencil = true })
    love.graphics.clear(0.3, 0.42, 0.55, 1)
    for r, base in ipairs(filas) do
      for c = 1, W do
        local u = (c - 1) / (W - 1) * 0.92
        local e = {}
        for k, v in pairs(base) do e[k] = v end
        e.id = "atq" .. r .. "_" .. c
        e.vivo = true
        e.hp, e.hpMax = 10, 10
        e.nivel = 5
        e.atqN, e.atqX, e.atqY, e.atqL = 1, (base.dir == 3 and 1) or (base.dir == 4 and -1) or 0, (base.dir == 1 and 1) or 0, base.lejos
        local t0 = 100
        Dibujo.relojAtaque = function() return t0 end
        Dibujo.estadoAtaque(e)
        t0 = 100 + u * (base.lejos and 0.52 or 0.46)
        love.graphics.push()
        love.graphics.translate((c - 1) * 40 * E2, (r - 1) * 44 * E2)
        love.graphics.scale(E2, E2)
        love.graphics.setColor(1, 1, 1, 1)
        Dibujo.entidad(e, 20, 20, { tiempo = 0, entidades = {} }, nil)
        love.graphics.pop()
      end
    end
    Dibujo.relojAtaque = nil
    love.graphics.pop()
    local datos = cv:newImageData()
    local f = io.open(Log.carpeta() .. "/capturas/web/ataques_vista.png", "wb")
    if f then f:write(datos:encode("png"):getString()) f:close() end
  end
  Log.info("exportar_web: " .. n .. " sprites en " .. Log.carpeta() .. "/capturas/web")
  print("exportar_web: " .. n .. " sprites")
  love.event.quit(0)
end

return E
