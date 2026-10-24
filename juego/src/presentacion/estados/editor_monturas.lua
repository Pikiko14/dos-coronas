-- Editor visual del asiento del jinete: arrastra al personaje sobre cada montura, en cada una de las ocho direcciones, y guarda el resultado.
-- Se abre con `love juego --monturas` (editor_monturas.bat) o `DosCoronas.exe --monturas`; no necesita servidor ni cuenta.
--   Lista de la izquierda: todas las monturas del juego (✓ = ya tiene ajustes). Clic o flechas arriba/abajo para elegir.
--   Centro: la montura con el jinete a gran tamaño; arrastra al jinete con el ratón (flechas izquierda/derecha cambian de dirección).
--   Botones: clase y género del jinete, las ocho direcciones, quieto/corriendo, reiniciar, copiar a las otras direcciones y guardar (F9).
-- Los ajustes (px de pantalla respecto al asiento calculado) van a render/montura_ajustes.lua (o a la carpeta de datos si el juego está empaquetado).
local MobAnim = require("src.presentacion.render.mob_anim")
local Personajes = require("src.presentacion.render.personajes")
local Dibujo = require("src.presentacion.render.dibujo")
local Fao = require("src.presentacion.render.fao")
local Items = require("compartido.dominio.items")
local Ajuste = require("src.presentacion.ajuste_montura")

local M = {}

local CLASES = { "guerrero", "mago", "cazador", "clerigo", "lancero", "nigromante" }
-- octante (0 derecha y en el sentido de las agujas del reloj) -> hoja y si va volteada (como fao.lua)
local OCTANTE = { [0] = { 3, true }, [1] = { 4, true }, [2] = { 0, false }, [3] = { 4, false }, [4] = { 3, false }, [5] = { 2, false }, [6] = { 1, false }, [7] = { 2, true } }
local FLECHAS = { [0] = "→", "↘", "↓", "↙", "←", "↖", "↑", "↗" }
local ZOOM = 4
local ANCHO_LISTA = 280

local E = { lista = {}, sel = 1, scroll = 0, clase = "guerrero", gen = "h", oct = 4, corre = false, botones = {}, arrastre = nil, aviso = nil, avisoHasta = 0 }

local function construirLista()
  local especies, orden = require("compartido.dominio.configuracion").mapaOrden("monturas", "montura", false)
  E.lista = {}
  for _, id in ipairs(orden) do
    local m = Personajes.monturaDe(id, "albor")
    local d = m and m.anim and MobAnim.DEFS[m.anim]
    if d and d.dirs5 then E.lista[#E.lista + 1] = { id = id, anim = m.anim, nombre = especies[id].nombre or id } end
  end
  table.sort(E.lista, function(a, b) return a.id < b.id end)
end

local function actual() return E.lista[E.sel] end

local function hojaActual()
  local o = OCTANTE[E.oct]
  return o[1], o[2]
end

local function ajusteDe(anim, hoja)
  local a = MobAnim.AJUSTES[anim]
  return a and a[hoja] or { 0, 0 }
end

local function tieneAjustes(anim)
  local a = MobAnim.AJUSTES[anim]
  if not a then return false end
  for h = 0, 4 do if a[h] and (a[h][1] ~= 0 or a[h][2] ~= 0 or a[h][3]) then return true end end
  return (a.escala ~= nil and math.abs(a.escala - 1) > 1e-6) or (a.jinete ~= nil and math.abs(a.jinete - 1) > 1e-6)
end

local function avisar(t) E.aviso, E.avisoHasta = t, love.timer.getTime() + 4 end

-- ---------------------------------------------------------------- interfaz
local function boton(x, y, w, h, texto, fn, activo)
  E.botones[#E.botones + 1] = { x = x, y = y, w = w, h = h, fn = fn }
  local mx, my = love.mouse.getPosition()
  local sobre = mx >= x and mx <= x + w and my >= y and my <= y + h
  love.graphics.setColor(activo and 0.45 or (sobre and 0.3 or 0.2), activo and 0.36 or (sobre and 0.38 or 0.26), activo and 0.12 or (sobre and 0.6 or 0.42), 1)
  love.graphics.rectangle("fill", x, y, w, h, 5, 5)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.printf(texto, x, y + h / 2 - 8, w, "center")
end

function M.iniciar(app)
  construirLista()
  Fao.forzar(nil)
  app.estado = "editor_monturas"
  if app.fuente then love.graphics.setFont(app.fuente) end
end

local function entidad(oct)
  local a = actual()
  return { kind = "jugador", id = 9000 + oct + (E.corre and 100 or 0), nombre = "", clase = E.clase, gen = E.gen, equipo = Items.equipoDe(E.clase, 8), x = 10, y = 10, dir = 1, _f8 = oct,
    montado = a.id, mov = E.corre, vivo = true, faccion = "albor", velx = 0, vely = 0 }
end

function M.dibujar(app, w, h)
  E.botones = {}
  love.graphics.clear(0.13, 0.15, 0.2, 1)
  love.graphics.setFont(app.fuente)
  -- lista de monturas
  love.graphics.setColor(0.08, 0.1, 0.15, 1)
  love.graphics.rectangle("fill", 0, 0, ANCHO_LISTA, h)
  local filaH = 24
  local visibles = math.floor((h - 40) / filaH)
  if E.sel - 1 < E.scroll then E.scroll = E.sel - 1 end
  if E.sel > E.scroll + visibles then E.scroll = E.sel - visibles end
  love.graphics.setColor(1, 0.85, 0.4, 1)
  love.graphics.print(string.format("Monturas (%d)", #E.lista), 10, 8)
  for i = 1, visibles do
    local it = E.lista[E.scroll + i]
    if not it then break end
    local y = 32 + (i - 1) * filaH
    E.botones[#E.botones + 1] = { x = 0, y = y, w = ANCHO_LISTA, h = filaH, fn = function() E.sel = E.scroll + i end }
    if E.scroll + i == E.sel then
      love.graphics.setColor(0.35, 0.3, 0.12, 1)
      love.graphics.rectangle("fill", 4, y, ANCHO_LISTA - 8, filaH - 2, 4, 4)
    end
    love.graphics.setColor(tieneAjustes(it.anim) and 0.6 or 0.85, tieneAjustes(it.anim) and 1 or 0.88, tieneAjustes(it.anim) and 0.6 or 0.95, 1)
    love.graphics.print((tieneAjustes(it.anim) and "✓ " or "  ") .. it.id:gsub("mnt_", "") .. "  " .. it.nombre, 10, y + 3)
  end
  -- barra superior: clase, género, quieto/corre
  local x0 = ANCHO_LISTA + 14
  love.graphics.setColor(0.8, 0.85, 1, 1)
  love.graphics.print("Jinete:", x0, 12)
  local x = x0 + 60
  for _, c in ipairs(CLASES) do
    boton(x, 8, 86, 26, c, function() E.clase = c end, E.clase == c)
    x = x + 90
  end
  boton(x + 10, 8, 40, 26, E.gen == "h" and "♂" or "♀", function() E.gen = E.gen == "h" and "m" or "h" end)
  boton(x + 56, 8, 90, 26, E.corre and "Corriendo" or "Quieto", function() E.corre = not E.corre end)
  -- las ocho direcciones
  love.graphics.setColor(0.8, 0.85, 1, 1)
  love.graphics.print("Dirección:", x0, 48)
  for oct = 0, 7 do
    boton(x0 + 90 + oct * 44, 44, 40, 26, FLECHAS[oct], function() E.oct = oct end, E.oct == oct)
  end
  -- escenario
  local a = actual()
  if a then
    local cx, cy = ANCHO_LISTA + (w - ANCHO_LISTA) / 2, h * 0.72
    love.graphics.setColor(0.2, 0.26, 0.2, 1)
    love.graphics.rectangle("fill", ANCHO_LISTA + 10, 84, w - ANCHO_LISTA - 20, h - 190, 8, 8)
    love.graphics.setColor(1, 1, 1, 0.12)
    love.graphics.line(ANCHO_LISTA + 10, cy, w - 10, cy)
    love.graphics.line(cx, 84, cx, h - 106)
    E.centro = { cx, cy }
    love.graphics.push("all")
    love.graphics.setScissor(ANCHO_LISTA + 10, 84, w - ANCHO_LISTA - 20, h - 190)
    love.graphics.translate(cx, cy)
    love.graphics.scale(ZOOM, ZOOM)
    local ok, err = pcall(Dibujo.entidad, entidad(E.oct), 0, 0, nil, nil)
    love.graphics.pop()
    if not ok then
      love.graphics.setColor(1, 0.4, 0.4, 1)
      love.graphics.print("Error al dibujar: " .. tostring(err), x0, 100)
    end
    -- datos y ayuda
    local hoja, flip = hojaActual()
    local aj = ajusteDe(a.anim, hoja)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(string.format("%s  %s   hoja %d%s   ajuste dx %g  dy %g   tamaño x%g  jinete x%g", a.id, a.nombre, hoja, flip and " (volteada)" or "", aj[1], aj[2],
      (MobAnim.AJUSTES[a.anim] and MobAnim.AJUSTES[a.anim].escala) or 1, (MobAnim.AJUSTES[a.anim] and MobAnim.AJUSTES[a.anim].jinete) or 1), x0, h - 96)
    love.graphics.setColor(0.7, 0.75, 0.9, 1)
    love.graphics.printf("Arrastra al jinete con el ratón. ←/→ cambian de dirección y ↑/↓ de montura. Cada dirección base se ajusta por separado (las volteadas comparten con su simétrica).",
      x0, h - 74, w - x0 - 10, "left")
    local y = h - 36
    boton(x0, y, 130, 28, "Guardar (F9)", function() avisar(Ajuste.guardar()) end)
    boton(x0 + 140, y, 150, 28, "Reiniciar dirección", function() if MobAnim.AJUSTES[a.anim] then MobAnim.AJUSTES[a.anim][hoja] = nil end end)
    boton(x0 + 300, y, 150, 28, "Reiniciar montura", function() MobAnim.AJUSTES[a.anim] = nil end)
    boton(x0 + 460, y, 190, 28, "Copiar a las 5 direcciones", function()
      local t = MobAnim.AJUSTES[a.anim] or {}
      MobAnim.AJUSTES[a.anim] = t
      for hh = 0, 4 do t[hh] = { aj[1], aj[2], aj[3] } end
    end)
    local TEXTOS = { [0] = "montura detrás del jinete", [1] = "montura delante (entera)", [2] = "montura delante (de la cintura abajo)" }
    boton(x0 + 460, y - 34, 330, 28, "Capa: " .. (TEXTOS[aj[3]] or "automática"), function()
      local t = MobAnim.AJUSTES[a.anim] or {}
      MobAnim.AJUSTES[a.anim] = t
      local v = t[hoja] or { 0, 0 }
      local sig = ({ [0] = 1, [1] = 2 })[v[3] or -1]            -- automática -> detrás -> delante entera -> delante de la cintura abajo -> automática
      if v[3] == nil then sig = 0 elseif v[3] == 2 then sig = nil end
      t[hoja] = { v[1], v[2], sig }
    end)
    boton(x0 + 920, y - 34, 90, 28, "Tamaño -", function()
      local t = MobAnim.AJUSTES[a.anim] or {}
      MobAnim.AJUSTES[a.anim] = t
      t.escala = math.max(0.3, math.floor(((t.escala or 1) - 0.05) * 100 + 0.5) / 100)
    end)
    boton(x0 + 1016, y - 34, 90, 28, "Tamaño +", function()
      local t = MobAnim.AJUSTES[a.anim] or {}
      MobAnim.AJUSTES[a.anim] = t
      t.escala = math.min(3, math.floor(((t.escala or 1) + 0.05) * 100 + 0.5) / 100)
    end)
    boton(x0 + 920, y, 90, 28, "Jinete -", function()
      local t = MobAnim.AJUSTES[a.anim] or {}
      MobAnim.AJUSTES[a.anim] = t
      t.jinete = math.max(0.4, math.floor(((t.jinete or 1) - 0.05) * 100 + 0.5) / 100)
    end)
    boton(x0 + 1016, y, 90, 28, "Jinete +", function()
      local t = MobAnim.AJUSTES[a.anim] or {}
      MobAnim.AJUSTES[a.anim] = t
      t.jinete = math.min(1.5, math.floor(((t.jinete or 1) + 0.05) * 100 + 0.5) / 100)
    end)
    boton(x0 + 660, y, 120, 28, "Anterior", function() E.sel = math.max(1, E.sel - 1) end)
    boton(x0 + 790, y, 120, 28, "Siguiente", function() E.sel = math.min(#E.lista, E.sel + 1) end)
  end
  if E.aviso and love.timer.getTime() < E.avisoHasta then
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", ANCHO_LISTA + 14, 78, w - ANCHO_LISTA - 28, 24, 4, 4)
    love.graphics.setColor(0.6, 1, 0.6, 1)
    love.graphics.print(E.aviso, ANCHO_LISTA + 20, 82)
  end
end

function M.actualizar() end

-- ---------------------------------------------------------------- entrada
function M.raton(x, y, boton)
  if boton ~= 1 then return end
  for i = #E.botones, 1, -1 do
    local b = E.botones[i]
    if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then b.fn() return end
  end
  local a = actual()
  if a and E.centro and x > ANCHO_LISTA then E.arrastre = { x = x, y = y } end
end

function M.mover(x, y, dx, dy)
  local a = actual()
  if not (E.arrastre and a) then return end
  local hoja, flip = hojaActual()
  local t = MobAnim.AJUSTES[a.anim] or {}
  MobAnim.AJUSTES[a.anim] = t
  local v = t[hoja] or { 0, 0 }
  local ddx, ddy = dx / ZOOM, dy / ZOOM
  t[hoja] = { v[1] + (flip and -ddx or ddx), v[2] + ddy, v[3] }
end

function M.soltar()
  local a = actual()
  if E.arrastre and a then
    local hoja = hojaActual()
    local v = MobAnim.AJUSTES[a.anim] and MobAnim.AJUSTES[a.anim][hoja]
    if v then v[1], v[2] = math.floor(v[1] * 2 + 0.5) / 2, math.floor(v[2] * 2 + 0.5) / 2 end     -- (al soltar, a medios píxeles)
  end
  E.arrastre = nil
end

function M.rueda(dy)
  local mx = love.mouse.getPosition()
  if mx < ANCHO_LISTA then E.scroll = math.max(0, E.scroll - dy * 3) else E.sel = math.max(1, math.min(#E.lista, E.sel - dy)) end
end

function M.tecla(tecla)
  if tecla == "up" then E.sel = math.max(1, E.sel - 1)
  elseif tecla == "down" then E.sel = math.min(#E.lista, E.sel + 1)
  elseif tecla == "left" then E.oct = (E.oct - 1) % 8
  elseif tecla == "right" then E.oct = (E.oct + 1) % 8
  elseif tecla == "f9" then avisar(Ajuste.guardar())
  elseif tecla == "escape" then love.event.quit() end
end

-- para las pruebas
M.estado = E
return M
