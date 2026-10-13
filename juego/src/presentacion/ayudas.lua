-- Ayudas de interfaz comunes a todos los sistemas:
--   * num: números con separador de miles (12.500) para oro, monedas y precios.
--   * aviso de interacción: "[E] Hablar con ..." cuando hay algo con lo que interactuar a mano
--     (PNJ, puertas de mazmorra, cofres, casas, portal de guerra...).
--   (los mensajes de sistema van solo al chat, pestaña Sistema: no hay avisos emergentes)
--   * cursor de mano sobre lo que se puede pulsar.
local Datos = require("compartido.dominio.datos")
local Ajustes = require("src.presentacion.ajustes")

local A = {}

-- 12500 -> "12.500"
function A.num(n)
  n = math.floor(tonumber(n) or 0)
  local neg = n < 0
  local s = tostring(math.abs(n))
  local r = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
  if r:sub(1, 1) == "." then r = r:sub(2) end
  return (neg and "-" or "") .. r
end

local function tecla()
  return ((Ajustes.teclas and Ajustes.teclas.interactuar) or "e"):upper()
end

local function dist(ax, ay, bx, by)
  local dx, dy = ax - bx, ay - by
  return math.sqrt(dx * dx + dy * dy)
end

-- Qué hay a mano con lo que interactuar (el mismo alcance que usa el servidor). Devuelve el texto.
function A.interaccion(mundo, p)
  if p.vivo == false then return nil end
  local k = tecla()
  local mz = mundo.enMazmorra and mundo:enMazmorra(p)
  if mz then
    for _, e in pairs(mundo.entidades) do
      if e.kind == "cofre_mz" and e.modo == p.modo and dist(p.x, p.y, e.x, e.y) < 2.6 then
        return "[" .. k .. "] Abrir el cofre de premio"
      end
    end
    local mapa = mundo.mapas[p.modo]
    if mapa and mapa.salida and dist(p.x, p.y, mapa.salida.x, mapa.salida.y) < 3.2 then
      return "[" .. k .. "] Salir de " .. mz.nombre
    end
    return nil
  end
  if p.modo == "casa" then
    local s = mundo.mapas.casa.salida
    if dist(p.x, p.y, s.x, s.y) < 1.3 then return "[" .. k .. "] Salir de la casa" end
    return nil
  end
  if p.modo == "batalla" then
    for _, e in pairs(mundo.entidades) do
      if e.kind == "altar" and e.faccion == p.faccion and e.vivo ~= false and dist(p.x, p.y, e.x, e.y) < 1.8 then
        return (p.llevaCristales or 0) > 0 and ("[" .. k .. "] Entregar los cristales en el altar") or "Altar de tu base (trae cristales)"
      end
    end
    return nil
  end
  if p.modo ~= "mundo" then return nil end
  -- PNJ y guardias
  local mejor, md = nil, 1.8
  for _, e in pairs(mundo.entidades) do
    if (e.kind == "npc" or e.kind == "guardia") and e.vivo ~= false and (e.z or 0) == (p.z or 0) then
      local d = dist(p.x, p.y, e.x, e.y)
      if d < md then mejor, md = e, d end
    end
  end
  if mejor then
    return "[" .. k .. "] Hablar con " .. (mejor.nombre or "el PNJ")
  end
  -- puerta de mazmorra
  for _, z in ipairs(mundo.mapas.mundo.mazmorras or {}) do
    if dist(p.x, p.y, z.x + 0.5, z.y + 0.5) < 2.6 then
      local def = Datos.mazmorra(z.id)
      local ok = def and (p.nivel or 1) >= def.nivelMin
      return "[" .. k .. "] Entrar en " .. z.nombre .. (def and ("  (nivel " .. def.nivelMin .. "+)") or "") .. (ok and "" or "  — nivel insuficiente")
    end
  end
  -- casas
  for _, c in ipairs(mundo.mapas.mundo.ciudades) do
    for _, par in ipairs(c.parcelas or {}) do
      if dist(p.x, p.y, par.x + 0.5, par.y + 0.5) < 1.6 then
        if par.dueno == p.id then return "[" .. k .. "] Entrar en tu casa" end
        return par.dueno and "Casa de otro jugador" or ("[" .. k .. "] Ver la parcela en venta")
      end
    end
  end
  local portal = mundo.mapas.mundo.portal
  if portal and dist(p.x, p.y, portal.x, portal.y) < 2.2 then return "[" .. k .. "] Portal de guerra" end
  return nil
end

function A.dibujarInteraccion(mundo, p, vw, vh, fuente)
  local t = A.interaccion(mundo, p)
  if not t then return end
  love.graphics.setFont(fuente)
  local w = fuente:getWidth(t) + 24
  local x, y = vw / 2 - w / 2, vh - 92
  local pulso = 0.85 + 0.15 * math.sin(love.timer.getTime() * 4)
  love.graphics.setColor(0.07, 0.06, 0.05, 0.92)
  love.graphics.rectangle("fill", x, y, w, 26, 6, 6)
  love.graphics.setColor(0.95 * pulso, 0.8 * pulso, 0.4 * pulso, 1)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, 25, 6, 6)
  love.graphics.setColor(1, 0.95, 0.8, 1)
  love.graphics.printf(t, x, y + 5, w, "center")
end

-- ------------------------------------------------------------------------------------- cursor
local mano, puesto
function A.cursor(Interfaz)
  if not love.mouse.isCursorSupported() then return end
  if mano == nil then
    local ok, c = pcall(love.mouse.getSystemCursor, "hand")
    mano = ok and c or false
  end
  if not mano then return end
  local mx, my = love.mouse.getPosition()
  local id = Interfaz.consumir and Interfaz.consumir(mx, my)
  local quiere = (id ~= nil and id ~= "panel") and mano or nil
  if quiere ~= puesto then
    love.mouse.setCursor(quiere)
    puesto = quiere
  end
end

return A
