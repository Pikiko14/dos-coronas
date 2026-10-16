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
  if def.anim then
    require("src.presentacion.render.mob_anim").dibujar(def.anim, "wait", 0, lado / 2, lado - 6, 1, nil, 0)
  else
    Personajes.dibujar(def, 1, false, 0, lado / 2, lado - 6)
  end
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
  for _, id in ipairs({ "jefe_gorila_bosque", "jefe_orco_glacial", "jefe_basilisco_dorado", "jefe_wyvern_carmesi", "jefe_dragon_sombra", "reina_espejos", "elemental_brasas", "golem_cristal", "troll_escarcha", "bestia_espectral", "medusa_guerrera" }) do
    local def = Personajes.de({ kind = "monstruo", monstruo = id })
    if def and Personajes.monstruos[id] then
      guardar("jefe_" .. id, def, (def.anim and (require("src.presentacion.render.mob_anim").DEFS[id].alto + 40)) or ((def.fila and (def.celda or 64) or 40) + 24))
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
      lista[#lista + 1] = def
      n = n + 1
    end
  end
  do
    local E = 3
    local ancho, alto = 4 * 52 * E + 10, #lista * 52 * E + 10
    local cv = love.graphics.newCanvas(ancho, alto)
    love.graphics.push("all")
    love.graphics.setCanvas({ cv, stencil = true })
    love.graphics.clear(0.3, 0.42, 0.55, 1)
    for k, def in ipairs(lista) do
      for dir = 1, 4 do
        love.graphics.push()
        love.graphics.translate(5 + (dir - 1) * 52 * E + 26 * E, (k - 1) * 52 * E + 47 * E)
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
      { kind = "monstruo", monstruo = "seta_azul", dir = 3 },
      { kind = "monstruo", monstruo = "pinguino_aprendiz", dir = 1 },
      { kind = "monstruo", monstruo = "girasol_lancero", dir = 4 },
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
  -- hoja de revisión del vaivén de los árboles: 10 instantes (cada 0,45 s) de un árbol, un pino, una palma y un arbusto
  do
    local Objetos = require("src.presentacion.render.objetos")
    local nombres = { "arbol", "arbol_pino", "palma", "arbusto", "arbol_seco" }
    local E2 = 3
    local cv = love.graphics.newCanvas(10 * 40 * E2, #nombres * 70 * E2)
    local reloj = love.timer.getTime
    love.graphics.push("all")
    love.graphics.setCanvas({ cv, stencil = true })
    love.graphics.clear(0.35, 0.55, 0.3, 1)
    for r, nombre in ipairs(nombres) do
      for c = 1, 10 do
        love.timer.getTime = function() return 10 + (c - 1) * 0.45 end
        love.graphics.push()
        love.graphics.translate((c - 1) * 40 * E2, (r - 1) * 70 * E2)
        love.graphics.scale(E2, E2)
        Objetos.dibujar(nombre, 0, 20, 64, nil, nil, 0)
        love.graphics.pop()
      end
    end
    love.timer.getTime = reloj
    love.graphics.pop()
    local datos = cv:newImageData()
    local f = io.open(Log.carpeta() .. "/capturas/web/arboles_vista.png", "wb")
    if f then f:write(datos:encode("png"):getString()) f:close() end
  end
  -- hoja de revisión del fénix: 4 direcciones (filas) x 3 cuadros de aleteo, de Albor y de Umbra
  do
    local E2, C = 6, 36
    local cv = love.graphics.newCanvas(6 * C * E2, 4 * C * E2)
    love.graphics.push("all")
    love.graphics.setCanvas({ cv, stencil = true })
    love.graphics.clear(0.3, 0.42, 0.55, 1)
    for lado, fac in ipairs({ "albor", "umbra" }) do
      local def = Personajes.monturaDe("fenix", fac)
      for dir = 1, 4 do
        for k, t in ipairs({ 0.0, 0.0, 0.25 }) do
          love.graphics.push()
          love.graphics.translate(((lado - 1) * 3 + (k - 1)) * C * E2 + 18 * E2, (dir - 1) * C * E2 + 33 * E2)
          love.graphics.scale(E2, E2)
          love.graphics.setColor(1, 1, 1, 1)
          Personajes.dibujar(def, dir, k ~= 2, t + (k == 1 and 0 or 0), 0, 0)
          love.graphics.pop()
        end
      end
    end
    love.graphics.pop()
    local fh = io.open(Log.carpeta() .. "/capturas/web/fenix_vista.png", "wb")
    if fh then fh:write(cv:newImageData():encode("png"):getString()) fh:close() end
  end
  -- el fénix con jinete, en las 4 direcciones
  do
    local Dibujo = require("src.presentacion.render.dibujo")
    local E2, C = 5, 60
    local cv = love.graphics.newCanvas(4 * C * E2, 2 * C * E2)
    love.graphics.push("all")
    love.graphics.setCanvas({ cv, stencil = true })
    love.graphics.clear(0.3, 0.42, 0.55, 1)
    for k, par in ipairs({ { "guerrero", "albor" }, { "mago", "umbra" } }) do
      for dir = 1, 4 do
        local e = { id = "fj" .. k .. dir, kind = "jugador", clase = par[1], faccion = par[2], montado = "fenix", dir = dir, vivo = true, hp = 10, hpMax = 10, nivel = 5 }
        love.graphics.push()
        love.graphics.translate((dir - 1) * C * E2 + 30 * E2, (k - 1) * C * E2 + 42 * E2)
        love.graphics.scale(E2, E2)
        Dibujo.entidad(e, 0, 0, { tiempo = 0, entidades = {} }, nil)
        love.graphics.pop()
      end
    end
    love.graphics.pop()
    local fh = io.open(Log.carpeta() .. "/capturas/web/fenix_jinete.png", "wb")
    if fh then fh:write(cv:newImageData():encode("png"):getString()) fh:close() end
  end
  -- revisión de los efectos con dirección del lancero: estocada y embestida hacia derecha, abajo, izquierda y arriba
  do
    local Efectos = require("src.presentacion.render.efectos")
    local C, E2 = 150, 1
    local TIPOS = { "estocada", "embestida", "tajo", "barrido", "corte", "desgarro", "carga" }
    local cv = love.graphics.newCanvas(8 * C, #TIPOS * C)
    love.graphics.push("all")
    love.graphics.setCanvas({ cv, stencil = true })
    love.graphics.clear(0.3, 0.42, 0.55, 1)
    for fila, tipo in ipairs(TIPOS) do
      for k, rot in ipairs({ 0, math.pi / 2, math.pi, -math.pi / 2 }) do
        for j, t in ipairs({ 0.18, 0.28 }) do
          local cx, cy = ((k - 1) * 2 + (j - 1)) * C + C / 2, (fila - 1) * C + C / 2
          love.graphics.setColor(1, 1, 1, 0.25)
          love.graphics.circle("fill", cx, cy, 5)
          Efectos.cuadro(tipo, t, 0.4, cx, cy + 14, 1, 1, rot)
        end
      end
    end
    love.graphics.pop()
    local fh = io.open(Log.carpeta() .. "/capturas/web/efectos_lancero.png", "wb")
    if fh then fh:write(cv:newImageData():encode("png"):getString()) fh:close() end
  end
  -- contacto de TODOS los efectos de poderes (tres instantes de cada uno) para revisar hacia dónde apunta cada dibujo
  do
    local Efectos = require("src.presentacion.render.efectos")
    local nombres = {}
    for k in pairs(Efectos.def) do nombres[#nombres + 1] = k end
    table.sort(nombres)
    local C, COL = 128, 6
    local filas = math.ceil(#nombres / COL)
    local cv = love.graphics.newCanvas(COL * C * 3, filas * C)
    love.graphics.push("all")
    love.graphics.setCanvas({ cv, stencil = true })
    love.graphics.clear(0.2, 0.28, 0.38, 1)
    for i, tipo in ipairs(nombres) do
      local cx0, cy0 = ((i - 1) % COL) * C * 3, math.floor((i - 1) / COL) * C
      for j, t in ipairs({ 0.2, 0.45, 0.7 }) do
        love.graphics.push()
        love.graphics.translate(cx0 + (j - 1) * C + C / 2, cy0 + C / 2 + 10)
        love.graphics.scale(0.62, 0.62)
        Efectos.cuadro(tipo, t, 1, 0, 0, 1, 1)
        love.graphics.pop()
      end
      love.graphics.setColor(1, 1, 0.5, 1)
      love.graphics.print(tipo, cx0 + 4, cy0 + 2)
    end
    love.graphics.pop()
    local fh = io.open(Log.carpeta() .. "/capturas/web/efectos_todos.png", "wb")
    if fh then fh:write(cv:newImageData():encode("png"):getString()) fh:close() end
    print("efectos: " .. table.concat(nombres, " "))
  end
  Log.info("exportar_web: " .. n .. " sprites en " .. Log.carpeta() .. "/capturas/web")
  print("exportar_web: " .. n .. " sprites")
  love.event.quit(0)
end

return E
