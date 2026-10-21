-- Eco instantáneo de los poderes propios. Con la red de por medio, el efecto de un poder tardaba la ida y la vuelta (unos 170 ms contra el
-- VPS) en aparecer: lo crea el servidor y llega en la foto siguiente. Aquí, al pulsar el poder, el cliente comprueba lo mismo que el
-- servidor (conoces el poder, no está en enfriamiento, hay maná, objetivo en alcance y a la vista) y dibuja ya el efecto o el proyectil.
-- El servidor sigue mandando: cuando llega su efecto equivalente se descarta (para no verlo doble) y cuenta como confirmación; si no llega
-- en un tiempo razonable (el servidor rechazó el poder), el eco se corta. Daño, maná y enfriamientos reales los decide el servidor: aquí
-- solo se adelantan en el HUD hasta que llega la siguiente foto.
local Datos = require("compartido.dominio.datos")
local Arbol = require("compartido.dominio.arbol")
local Mundo = require("compartido.dominio.mundo")
local Sonido = require("src.presentacion.sonido")
local Log = require("compartido.infraestructura.log")

local Eco = {}

local VEL_PROYECTIL = 11        -- casillas por segundo: la misma del servidor

local function estado(app)
  local e = app._eco
  if not e then
    e = { fx = {}, proy = {}, sup = {}, psup = {}, n = 0 }
    app._eco = e
  end
  return e
end

local function ahora() return love.timer.getTime() end

-- cuánto se espera la confirmación del servidor antes de cortar el eco
local function limite(app)
  return math.max(0.6, (app.ping or 0.15) * 1.2 + 0.35)
end

local function dist(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end

local function distSegmento(px, py, ax, ay, bx, by)
  local dx, dy = bx - ax, by - ay
  local l2 = dx * dx + dy * dy
  if l2 < 1e-6 then return dist(px, py, ax, ay) end
  local t = math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / l2))
  return dist(px, py, ax + dx * t, ay + dy * t)
end

local function nuevoEfecto(app, tipo, x, y, dur, rot, tol, x0, y0)
  local e, t0 = estado(app), ahora()
  local fx = { tipo = tipo, x = x, y = y, t = 0, dur = dur, rot = rot, x0 = x0, y0 = y0, _eco = true, nace = t0 }
  e.fx[#e.fx + 1] = fx
  e.sup[#e.sup + 1] = { tipo = tipo, x = x, y = y, tol = tol or 1.5, hasta = t0 + dur + limite(app) + 0.3, limite = t0 + limite(app), fx = fx }
  return fx
end

-- Lo que el servidor haría con este poder y puede verse de inmediato. Devuelve true si dibujó algo.
function Eco.lanzar(app, datos)
  if app.rol ~= "cliente" or app._ecoOff then return false end
  local p, mundo = app.jugador, app.mundo
  if not p or not mundo or p.vivo == false or not datos or not datos.slot then return false end
  local ok, res = pcall(function()
    local t0 = ahora()
    if (app._ecoGcd or 0) > t0 then return false end
    local idh = Datos.barra[p.clase] and Datos.barra[p.clase][datos.slot]
    local rango = idh and Arbol.rango(p, idh) or 0
    if rango < 1 then return false end
    local h = Arbol.efectiva(idh, rango)
    if not h then return false end
    if (p.cds[idh] or 0) > mundo.tiempo or (p.mp or 0) < (h.mana or 0) then return false end
    local objetivo = p.objetivo and mundo.entidades[p.objetivo]
    local function enRango(obj, r)
      return obj and mundo:mismoLugar(p, obj) and dist(p.x, p.y, obj.x, obj.y) <= r + 0.3
    end
    if h.tipo == "enemigo" then
      if not objetivo or not mundo:puedeDanar(p, objetivo) or not enRango(objetivo, h.rango) or not mundo:lineaLibre(p, objetivo) then return false end
    elseif h.tipo == "aliado" then
      if not objetivo or not mundo:aliado(p, objetivo) then objetivo = p end
      if not enRango(objetivo, h.rango) then return false end
    elseif h.dash or h.blink or h.salto or h.tipo == "resucitar" then
      return false      -- los saltos mueven al personaje: lo decide el servidor
    end
    -- adelanta el gasto en el HUD (la foto siguiente trae las cifras reales)
    p.mp = p.mp - (h.mana or 0)
    p.cds[idh] = mundo.tiempo + (h.cd or 0)
    app._ecoGcd = t0 + 0.35
    local ex = objetivo and objetivo.x or p.x
    local ey = objetivo and objetivo.y or p.y
    if Mundo.PODERES_FAO[idh] then
      -- poder con efecto de capas de FAO: un solo efecto (el vuelo del proyectil va dentro de él); mismas posiciones que pone el servidor
      local X, Y, rot = ex, ey, (objetivo and objetivo ~= p) and math.atan2(ey - p.y, ex - p.x) or nil
      if h.tipo == "alrededor" or h.tipo == "buff_alrededor" or h.tipo == "mixto" or h.tipo == "propio" or h.tipo == "suelo" or h.tipo == "aliados" or h.tipo == "invocar" then
        X, Y, rot = p.x, p.y, Mundo.ANGULO_DIR[p.dir or 1]
      elseif h.tipo == "punto" then
        rot = nil
        local px, py = datos.x or (objetivo and objetivo.x), datos.y or (objetivo and objetivo.y)
        if not px then
          local d = math.min(h.rango or 5, 4)
          local mx = ({ [1] = 0, [2] = 0, [3] = 1, [4] = -1 })[p.dir or 1] or 0
          local my = ({ [1] = 1, [2] = -1, [3] = 0, [4] = 0 })[p.dir or 1] or 0
          px, py = p.x + mx * d, p.y + my * d
        end
        local d = dist(p.x, p.y, px, py)
        local alcance = (h.rango or 6) + 0.3
        if d > alcance then px, py = p.x + (px - p.x) * alcance / d, p.y + (py - p.y) * alcance / d end
        X, Y = px, py
      end
      nuevoEfecto(app, idh, X, Y, Mundo.DURACION_EFECTO[idh], rot, 2.5, p.x, p.y)
    elseif h.proyectil and objetivo then
      local e = estado(app)
      e.n = e.n + 1
      local pr = {
        id = "eco" .. e.n, kind = "proyectil", tipo = h.proyectil, x = p.x, y = p.y, tx = objetivo.x, ty = objetivo.y,
        objetivo = objetivo.id, vivo = true, modo = p.modo, z = p.z or 0, casaId = p.casaId, _eco = true, nace = t0, ox = p.x, oy = p.y,
      }
      e.proy[#e.proy + 1] = pr
      e.psup[#e.psup + 1] = {
        tipo = h.proyectil, ox = p.x, oy = p.y, tx = objetivo.x, ty = objetivo.y, hasta = t0 + dist(p.x, p.y, objetivo.x, objetivo.y) / VEL_PROYECTIL + limite(app) + 0.3,
        limite = t0 + limite(app), pr = pr,
      }
    elseif h.tipo == "alrededor" or h.tipo == "buff_alrededor" or h.tipo == "mixto" or h.tipo == "propio" or h.tipo == "suelo" or h.tipo == "aliados" or h.tipo == "invocar" then
      nuevoEfecto(app, idh, p.x, p.y, Mundo.DURACION_EFECTO[idh] or 0.5, Mundo.ANGULO_DIR[p.dir or 1])
    elseif h.tipo == "punto" then
      local px, py = datos.x or (objetivo and objetivo.x), datos.y or (objetivo and objetivo.y)
      if not px then
        local d = math.min(h.rango or 5, 4)
        local mx = ({ [1] = 0, [2] = 0, [3] = 1, [4] = -1 })[p.dir or 1] or 0
        local my = ({ [1] = 1, [2] = -1, [3] = 0, [4] = 0 })[p.dir or 1] or 0
        px, py = p.x + mx * d, p.y + my * d
      end
      -- el servidor limita el alcance: aquí también, para no adelantar un punto que no aceptaría
      local d = dist(p.x, p.y, px, py)
      local alcance = (h.rango or 6) + 0.3
      if d > alcance then px, py = p.x + (px - p.x) * alcance / d, p.y + (py - p.y) * alcance / d end
      nuevoEfecto(app, idh, px, py, Mundo.DURACION_EFECTO[idh] or 0.55, nil, 2.5)
    else
      local rot = (objetivo and objetivo ~= p) and math.atan2(ey - p.y, ex - p.x) or nil
      nuevoEfecto(app, idh, ex, ey, Mundo.DURACION_EFECTO[idh] or 0.4, rot, nil, p.x, p.y)
    end
    -- el sonido también se adelanta; el del servidor se descarta al llegar
    local nombre = Mundo.SONIDO_PODER[idh] or "magia"
    Sonido.evento({ n = nombre, x = p.x, y = p.y, e = p }, p)
    app._ecoSon = { n = nombre, hasta = t0 + 1.2 }
    return true
  end)
  if not ok then
    Log.warn("eco de poderes desactivado: " .. tostring(res))
    app._ecoOff = true
    return false
  end
  return res
end

-- ¿Este sonido que manda el servidor ya se oyó como eco? (se gasta una vez)
function Eco.sonidoRepetido(app, ev)
  local s = app._ecoSon
  if s and ev and ev.n == s.n and ahora() < s.hasta and app.jugador and ev.x and dist(ev.x, ev.y, app.jugador.x, app.jugador.y) < 1.5 then
    app._ecoSon = nil
    return true
  end
  return false
end

-- Cada cuadro, después de que llegue una foto o no: avanza los ecos, los vuelve a poner en el mundo (cada foto lo reemplaza), quita
-- los efectos y proyectiles del servidor que ya se están viendo como eco y corta los que el servidor no confirmó.
function Eco.actualizar(app, dt)
  local e, mundo = app._eco, app.mundo
  if not e or not mundo then return end
  local t0 = ahora()
  -- proyectiles propios en vuelo
  for i = #e.proy, 1, -1 do
    local pr = e.proy[i]
    local obj = mundo.entidades[pr.objetivo]
    if obj and obj.x and obj.vivo ~= false then pr.tx, pr.ty = obj.x, obj.y end
    local dx, dy = pr.tx - pr.x, pr.ty - pr.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 0.3 or t0 - pr.nace > 1.4 then
      nuevoEfecto(app, pr.tipo, pr.x, pr.y, 0.32)
      mundo.entidades[pr.id] = nil
      table.remove(e.proy, i)
    else
      pr.x, pr.y = pr.x + dx / d * VEL_PROYECTIL * dt, pr.y + dy / d * VEL_PROYECTIL * dt
      mundo.entidades[pr.id] = pr
    end
  end
  -- los proyectiles del servidor que son los mismos
  if #e.psup > 0 then
    for id, en in pairs(mundo.entidades) do
      if en.kind == "proyectil" and not en._eco then
        for _, s in ipairs(e.psup) do
          if t0 < s.hasta and en.tipo == s.tipo and en.tx and dist(en.tx, en.ty, s.tx, s.ty) < 0.8
            and distSegmento(en.x, en.y, s.ox, s.oy, s.tx, s.ty) < 0.8 then
            mundo.entidades[id] = nil
            s.conf = true
            break
          end
        end
      end
    end
    for i = #e.psup, 1, -1 do
      local s = e.psup[i]
      if t0 > s.hasta then
        table.remove(e.psup, i)
      elseif not s.conf and t0 > s.limite then
        -- el servidor no lanzó nada: se corta el proyectil
        for j = #e.proy, 1, -1 do
          if e.proy[j] == s.pr then mundo.entidades[s.pr.id] = nil table.remove(e.proy, j) end
        end
        table.remove(e.psup, i)
      end
    end
  end
  -- efectos: edad real, reinserción y descarte de los equivalentes del servidor
  local presentes = {}
  for _, fx in ipairs(mundo.efectos) do presentes[fx] = true end
  for i = #e.sup, 1, -1 do
    local s = e.sup[i]
    if t0 > s.hasta then
      table.remove(e.sup, i)
    elseif not s.conf and t0 > s.limite then
      s.fx.cortado = true
      table.remove(e.sup, i)
    end
  end
  for i = #e.fx, 1, -1 do
    local fx = e.fx[i]
    fx.t = t0 - fx.nace
    if fx.cortado or fx.t >= fx.dur then
      table.remove(e.fx, i)
    elseif not presentes[fx] then
      mundo.efectos[#mundo.efectos + 1] = fx
    end
  end
  if #e.sup > 0 then
    for i = #mundo.efectos, 1, -1 do
      local fx = mundo.efectos[i]
      if not fx._eco then
        for _, s in ipairs(e.sup) do
          if fx.tipo == s.tipo and dist(fx.x, fx.y, s.x, s.y) < s.tol then
            table.remove(mundo.efectos, i)
            s.conf = true
            break
          end
        end
      end
    end
  end
  -- los efectos cortados que ya estaban en el mundo salen también
  for i = #mundo.efectos, 1, -1 do
    if mundo.efectos[i].cortado then table.remove(mundo.efectos, i) end
  end
end

return Eco
