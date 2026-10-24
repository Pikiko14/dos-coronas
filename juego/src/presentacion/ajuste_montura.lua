-- Ajuste del asiento del jinete montado, desde el juego. Solo para personal (staff "gm") o con DC_AJUSTE_MONTURAS=1.
-- Montado en una montura de FAO: teclado numérico 4 / 6 / 8 / 2 (y 9 / 7: adelante / atrás) mueven al jinete 1 px (Mayús: 5 px) a izquierda / derecha / arriba / abajo en la
-- dirección que está mirando la montura (cada una de las cinco hojas se ajusta por separado; las volteadas comparten), 0 reinicia esa dirección y
-- F9 guarda: en desarrollo escribe src/presentacion/render/montura_ajustes.lua y en un paquete montura_ajustes.lua en la carpeta de datos.
local MobAnim = require("src.presentacion.render.mob_anim")
local Personajes = require("src.presentacion.render.personajes")
local Interfaz = require("src.presentacion.interfaz")

local M = {}
local aviso, avisoHasta = nil, 0
M.modo = false          -- F8: las flechas y RePág / AvPág ajustan al jinete en vez de mover al personaje (para teclados sin teclado numérico)

local function activo(app)
  local p = app.jugador
  return app.estado == "juego" and p and p.montado and (p.staff == "gm" or os.getenv("DC_AJUSTE_MONTURAS") == "1") and true or false
end

local function actual(app)
  local m = Personajes.monturaDe(app.jugador.montado, app.jugador.faccion)
  if not (m and m.anim and MobAnim.DEFS[m.anim] and MobAnim.DEFS[m.anim].dirs5) then return nil end
  local u = MobAnim.ultimo(m.anim)
  return m.anim, u and u.hoja
end

local function guardar()
  local ids = {}
  for id in pairs(MobAnim.AJUSTES) do ids[#ids + 1] = id end
  table.sort(ids)
  local t = { "-- Ajustes a mano del asiento del jinete (px de pantalla), por montura y hoja de dirección (0 frente, 1 espalda, 2 espalda-izquierda, 3 izquierda,\n",
    "-- 4 frente-izquierda). Lo escribe src/presentacion/ajuste_montura.lua (F9 en el juego).\nreturn {\n" }
  for _, id in ipairs(ids) do
    local filas = {}
    for h = 0, 4 do
      local a = MobAnim.AJUSTES[id][h]
      if a and (a[1] ~= 0 or a[2] ~= 0) then filas[#filas + 1] = string.format("[%d] = { %g, %g }", h, a[1], a[2]) end
    end
    if #filas > 0 then t[#t + 1] = string.format("  %s = { %s },\n", id, table.concat(filas, ", ")) end
  end
  t[#t + 1] = "}\n"
  local texto = table.concat(t)
  if love.filesystem.isFused() then
    love.filesystem.write("montura_ajustes.lua", texto)
    return "guardado en la carpeta de datos (montura_ajustes.lua)"
  end
  local ruta = love.filesystem.getSource():gsub("\\", "/") .. "/src/presentacion/render/montura_ajustes.lua"
  local f = io.open(ruta, "wb")
  if not f then return "no pude escribir " .. ruta end
  f:write(texto)
  f:close()
  return "guardado en " .. ruta
end

-- true si la tecla era de este ajuste
function M.tecla(app, tecla)
  if not activo(app) then M.modo = false end
  if Interfaz.foco or not activo(app) then return false end
  local id, hoja = actual(app)
  if not id or not hoja then return false end
  if tecla == "f8" then
    M.modo = not M.modo
    return true
  end
  if M.modo then
    tecla = ({ left = "kp4", right = "kp6", up = "kp8", down = "kp2", pageup = "kp9", pagedown = "kp7", ["0"] = "kp0", delete = "kp0" })[tecla] or tecla
  end
  local paso = (love.keyboard.isDown("lshift", "rshift") and 5 or 1)
  local dx, dy = 0, 0
  local u0 = MobAnim.ultimo(id)
  local volteada = u0 and u0.flip
  if tecla == "kp4" then dx = -paso elseif tecla == "kp6" then dx = paso elseif tecla == "kp8" then dy = -paso elseif tecla == "kp2" then dy = paso
  elseif tecla == "kp9" or tecla == "kp7" then
    -- adelante / atrás: hacia donde mira la montura. Las hojas de lado miran a la izquierda (volteadas, a la derecha); de frente es hacia abajo en pantalla y
    -- de espalda hacia arriba; las diagonales mezclan las dos cosas.
    local m = tecla == "kp9" and 1 or -1
    local ADELANTE = { [0] = { 0, 1 }, [1] = { 0, -1 }, [2] = { -1, -0.5 }, [3] = { -1, 0 }, [4] = { -1, 0.5 } }
    local v = ADELANTE[hoja]
    dx, dy = v[1] * paso * m, v[2] * paso * m
    if volteada then dx = -dx end         -- (abajo se vuelve a invertir al guardar: se pide en pantalla)
  end
  if dx ~= 0 or dy ~= 0 then
    local a = MobAnim.AJUSTES[id] or {}
    MobAnim.AJUSTES[id] = a
    local v = a[hoja] or { 0, 0 }
    -- el desplazamiento se da como se ve en pantalla: en las hojas volteadas el dx se invierte al guardarse
    local u = MobAnim.ultimo(id)
    if u and u.flip then dx = -dx end
    a[hoja] = { v[1] + dx, v[2] + dy }
    return true
  end
  if tecla == "kp0" then
    if MobAnim.AJUSTES[id] then MobAnim.AJUSTES[id][hoja] = nil end
    return true
  end
  if tecla == "f9" then
    aviso, avisoHasta = guardar(), love.timer.getTime() + 5
    return true
  end
  return false
end

function M.dibujar(app, w, h)
  if not activo(app) then return end
  local id, hoja = actual(app)
  if not id then return end
  local a = MobAnim.AJUSTES[id] and hoja and MobAnim.AJUSTES[id][hoja]
  local texto = string.format("Ajuste de montura %s  hoja %s  dx %g  dy %g   [F8 %s: flechas = izquierda/derecha/arriba/abajo, RePág/AvPág = adelante/atrás (o numérico 4/6/8/2 y 9/7), Mayús x5, 0 reinicia, F9 guarda]",
    id, tostring(hoja), a and a[1] or 0, a and a[2] or 0, M.modo and "ACTIVO" or "apagado")
  if aviso and love.timer.getTime() < avisoHasta then texto = texto .. "\n" .. aviso end
  love.graphics.push("all")
  love.graphics.origin()
  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.rectangle("fill", 6, h - 52, w - 12, aviso and love.timer.getTime() < avisoHasta and 44 or 26)
  love.graphics.setColor(1, 0.9, 0.5, 1)
  love.graphics.print(texto, 12, h - 48)
  love.graphics.pop()
end

return M
