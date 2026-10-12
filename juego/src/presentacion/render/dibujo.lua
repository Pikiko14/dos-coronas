local Datos = require("compartido.dominio.datos")
local Terreno = require("src.presentacion.render.terreno")
local Personajes = require("src.presentacion.render.personajes")
local Objetos = require("src.presentacion.render.objetos")
local Efectos = require("src.presentacion.render.efectos")
local Arte = require("src.presentacion.render.arte")

local D = {}
local TILE = 32

-- Zona de la pantalla donde se ve el mundo (el resto es interfaz).
D.vista = nil

local function vista()
  local v = D.vista
  if v then return v.x, v.y, v.w, v.h end
  local w, h = love.graphics.getDimensions()
  return 0, 0, w, h
end

function D.fijarVista(x, y, w, h)
  if x then D.vista = { x = x, y = y, w = w, h = h } else D.vista = nil end
end

function D.dentroVista(mx, my)
  local vx, vy, vw, vh = vista()
  return mx >= vx and mx < vx + vw and my >= vy and my < vy + vh
end

function D.camara(jugador, zoom, mapa)
  local vx, vy, vw, vh = vista()
  zoom = zoom or Datos.ZOOM
  local x = jugador.x * TILE - (vw / zoom) / 2
  local y = jugador.y * TILE - (vh / zoom) / 2
  if mapa and mapa.w and mapa.h then
    local ancho, alto = vw / zoom, vh / zoom
    local maxX = mapa.w * TILE - ancho
    local maxY = mapa.h * TILE - alto
    if maxX > 0 then x = math.max(0, math.min(maxX, x)) else x = maxX / 2 end
    if maxY > 0 then y = math.max(0, math.min(maxY, y)) else y = maxY / 2 end
  end
  return { x = x, y = y, zoom = zoom, vx = vx, vy = vy, vw = vw, vh = vh }
end

function D.mundoAPantalla(cam, x, y)
  return (cam.vx or 0) + (x * TILE - cam.x) * cam.zoom, (cam.vy or 0) + (y * TILE - cam.y) * cam.zoom
end

function D.pantallaAMundo(cam, mx, my)
  local wx = (mx - (cam.vx or 0)) / cam.zoom + cam.x
  local wy = (my - (cam.vy or 0)) / cam.zoom + cam.y
  return wx / TILE, wy / TILE
end

local function hash(x, y)
  local n = (x * 73856093 + y * 19349663) % 2147483647
  return (n % 997) / 997
end

local fuentePlaca
local function fuente()
  if fuentePlaca then return fuentePlaca end
  local ruta = "arte/fuentes/SourceSans3-Regular.ttf"
  if love.filesystem.getInfo(ruta) then fuentePlaca = love.graphics.newFont(ruta, 13)
  else fuentePlaca = love.graphics.newFont(12) end
  return fuentePlaca
end

-- Color de la barra de vida según lo que queda, como en Tibia.
function D.colorVida(frac)
  if frac > 0.6 then return 0.22, 0.78, 0.25 end
  if frac > 0.3 then return 0.85, 0.8, 0.2 end
  if frac > 0.1 then return 0.85, 0.45, 0.15 end
  return 0.8, 0.15, 0.15
end

local TINTES_FACCION = {
  albor = Datos.facciones.albor.color,
  umbra = Datos.facciones.umbra.color,
}

local function textoSombra(texto, x, y, c, alfa)
  love.graphics.setColor(0, 0, 0, (alfa or 1) * 0.85)
  love.graphics.print(texto, x + 1, y + 1)
  love.graphics.print(texto, x - 1, y + 1)
  love.graphics.setColor(c[1], c[2], c[3], alfa or 1)
  love.graphics.print(texto, x, y)
end

-- Nombre y barra de vida de una criatura, en pantalla (fuera de la escala del mundo).
local function placa(e, px, py, alto, jugador, tiempo)
  if e.kind == "proyectil" or e.kind == "trampa" or e.kind == "loot" or e.kind == "bandera" then return end
  local f = fuente()
  love.graphics.setFont(f)
  local color = { 0.92, 0.9, 0.84 }
  if TINTES_FACCION[e.faccion] and e.kind ~= "monstruo" then color = TINTES_FACCION[e.faccion]
  elseif e.kind == "monstruo" then color = e.elite and { 1, 0.8, 0.2 } or { 1, 0.62, 0.45 } end
  local nombre = e.nombre or ""
  if e.llevaBandera then nombre = nombre .. " [estandarte]" end
  if e.gremio and (e.kind == "jugador" or e.kind == "bot") then nombre = nombre .. " <" .. e.gremio .. ">" end
  local ancho = f:getWidth(nombre)
  local y = py - alto - 15
  local barra = e.hp and e.hpMax and e.kind ~= "altar"
    and (e.kind == "monstruo" or e.kind == "estatua" or e.kind == "puerta" or e.hp < e.hpMax
      or (jugador and jugador.objetivo == e.id))
  if barra then
    local w = 34
    local frac = math.max(0, math.min(1, e.hp / math.max(1, e.hpMax)))
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", px - w / 2 - 1, y + 14, w + 2, 6)
    love.graphics.setColor(D.colorVida(frac))
    love.graphics.rectangle("fill", px - w / 2, y + 15, w * frac, 4)
  end
  textoSombra(nombre, px - ancho / 2, y - 2, color)
  if e.burbuja and e.burbuja.hasta and e.burbuja.texto and e.burbuja.hasta > (tiempo or 0) then
    local t = e.burbuja.texto
    local tw = math.min(220, f:getWidth(t) + 12)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", px - tw / 2, y - 24, tw, 18, 4, 4)
    love.graphics.setColor(1, 1, 0.8)
    love.graphics.printf(t, px - tw / 2 + 4, y - 22, tw - 8, "center")
  end
end

local function dibujarPiso(mapa, jugador, cam, w, h)
  Terreno.dibujar(mapa, cam.x, cam.y, w, h, 0, 0.35)
  if mapa.alto then
    local im = Arte.img("Tilesets/Inside_A5.png")
    local px, py = math.floor(jugador.x), math.floor(jugador.y)
    local radio = math.ceil(math.max(w, h) / TILE) + 2
    love.graphics.setColor(1, 1, 1, 1)
    for x = px - radio, px + radio do
      local col = mapa.alto[x]
      if col then
        for y = py - radio, py + radio do
          if col[y] then
            love.graphics.draw(im, Arte.quad(im, 32 * (x % 2), 32 * (y % 2), 32, 32), x * TILE - cam.x, y * TILE - cam.y)
          end
        end
      end
    end
  end
end

function D.escena(mundo, jugador, cam, mx, my)
  local mapa = mundo:mapaDe(jugador)
  local z = cam.zoom
  local vx, vy, vw, vh = cam.vx, cam.vy, cam.vw, cam.vh
  love.graphics.setScissor(vx, vy, vw, vh)
  love.graphics.setColor(0.04, 0.05, 0.07, 1)
  love.graphics.rectangle("fill", vx, vy, vw, vh)
  love.graphics.push()
  love.graphics.translate(vx, vy)
  love.graphics.scale(z, z)
  local pz = jugador.z or 0
  local ancho, alto = vw / z, vh / z
  local radio = math.ceil(math.max(ancho, alto) / TILE) + 3
  if pz > 0 then
    dibujarPiso(mapa, jugador, cam, ancho, alto)
  else
    love.graphics.setColor(1, 1, 1, 1)
    Terreno.dibujar(mapa, cam.x, cam.y, ancho, alto, mundo.tiempo)
  end
  for _, s in ipairs(mapa.escaleras or {}) do
    if s.de == pz then
      local sx, sy = s.x * TILE - cam.x, s.y * TILE - cam.y
      love.graphics.setColor(0.35, 0.22, 0.12, 1)
      love.graphics.rectangle("fill", sx, sy, TILE, TILE)
      love.graphics.setColor(0.8, 0.62, 0.34, 1)
      for i = 0, 3 do love.graphics.rectangle("fill", sx + 2, sy + 3 + i * 8, TILE - 4, 5) end
      love.graphics.setColor(1, 0.9, 0.45, 0.9)
      love.graphics.print(s.a > s.de and "▲" or "▼", sx + 10, sy + 6)
    end
  end
  if mx and my and jugador.modo ~= "casa" and love.window.hasMouseFocus() and D.dentroVista(mx, my) then
    local wx, wy = D.pantallaAMundo(cam, mx, my)
    local tx, ty = math.floor(wx), math.floor(wy)
    love.graphics.setColor(1, 1, 1, 0.18)
    love.graphics.rectangle("fill", tx * TILE - cam.x, ty * TILE - cam.y, TILE, TILE)
  end

  -- cadáveres y puertas caídas: debajo de todo lo que se mueve
  for _, e in pairs(mundo.entidades) do
    if e.vivo == false and mundo:mismoLugar(jugador, e)
      and math.abs(e.x - jugador.x) < radio and math.abs(e.y - jugador.y) < radio then
      local sx, sy = e.x * TILE - cam.x, e.y * TILE - cam.y
      if e.kind == "monstruo" then
        local resta = (e.respawn or 0) - (mundo.tiempo or 0)
        Objetos.dibujar("restos", 0, sx, sy + 14, nil, math.max(0, math.min(1, resta / 6)))
      elseif e.kind == "puerta" then
        Objetos.puerta(e.faccion, true, sx, sy + 14, 0.8)
      end
    end
  end

  local cola = {}
  if pz == 0 then
    for _, prop in ipairs(mapa.props or {}) do
      if math.abs(prop.x - jugador.x) < radio and math.abs(prop.y - jugador.y) < radio then
        cola[#cola + 1] = {
          tipo = "prop", x = prop.x + (prop.ancho or 1) / 2,
          y = prop.y + (prop.alto or 1) - 0.1, prop = prop,
        }
      end
    end
  end
  if jugador.modo == "casa" then
    local casa = jugador.casas and jugador.casas[jugador.casaId]
    for nombre, pos in pairs(mapa.muebles or {}) do
      if casa and casa.muebles and casa.muebles[nombre] then
        cola[#cola + 1] = { tipo = "mueble", x = pos.x, y = pos.y, nombre = nombre }
      end
    end
  end
  for _, e in pairs(mundo.entidades) do
    if e.vivo ~= false and mundo:mismoLugar(jugador, e) and e.kind ~= "proyectil" then
      if math.abs(e.x - jugador.x) < radio + 2 and math.abs(e.y - jugador.y) < radio + 2 then
        cola[#cola + 1] = { tipo = "ent", x = e.x, y = e.y, e = e }
      end
    end
  end
  table.sort(cola, function(a, b) return a.y < b.y end)
  local placas = {}
  for _, item in ipairs(cola) do
    local sx, sy = item.x * TILE - cam.x, item.y * TILE - cam.y
    if item.tipo == "prop" then
      local p = item.prop
      local variante = math.floor(hash(p.x, p.y) * 2)
      local tint
      if p.tipo:find("arbol") and mapa.lado and mapa.lado[p.x] and mapa.lado[p.x][p.y] == "umbra" then
        tint = { 0.72, 0.64, 0.95 }
      end
      local ancho, alto = p.ancho or 1, p.alto or 1
      local alfa
      if p.ancho and jugador.x > p.x - 1 and jugador.x < p.x + ancho + 1
        and jugador.y > p.y - 2.5 and jugador.y < p.y + alto - 0.1 then
        alfa = 0.45 -- el jugador queda detrás: se ve a través de la montaña
      end
      Objetos.dibujar(p.tipo, variante, (p.x + ancho / 2) * TILE - cam.x, (p.y + alto) * TILE - cam.y, tint, alfa)
    elseif item.tipo == "mueble" then
      D.mueble(item.nombre, sx, sy)
    else
      local e = item.e
      local alto = D.entidad(e, sx, sy, mundo, jugador)
      placas[#placas + 1] = { e = e, x = sx, y = sy, alto = alto }
    end
  end
  for _, e in pairs(mundo.entidades) do
    if e.kind == "proyectil" and mundo:mismoLugar(jugador, e) then
      D.proyectil(e, e.x * TILE - cam.x, e.y * TILE - cam.y)
    end
  end
  for _, fx in ipairs(mundo.efectos or {}) do
    if math.abs(fx.x - jugador.x) < radio and math.abs(fx.y - jugador.y) < radio then
      Efectos.cuadro(fx.tipo, fx.t, fx.dur, fx.x * TILE - cam.x, fx.y * TILE - cam.y + 14)
    end
  end
  love.graphics.pop()
  love.graphics.setScissor()

  -- nombres, barras y números de daño: en pantalla, con letra pequeña y nítida
  love.graphics.setScissor(vx, vy, vw, vh)
  for _, p in ipairs(placas) do
    placa(p.e, vx + p.x * z, vy + (p.y + 12) * z, p.alto * z, jugador, mundo.tiempo)
  end
  local f = fuente()
  love.graphics.setFont(f)
  for _, n in ipairs(mundo.numeros) do
    if math.abs(n.x - jugador.x) < radio then
      local sx = vx + (n.x * TILE - cam.x) * z
      local sy = vy + ((n.y - 0.2) * TILE - cam.y) * z - 24 * z
      textoSombra(n.texto, sx - f:getWidth(n.texto) / 2, sy, n.color, math.min(1, n.vida / 0.5))
    end
  end
  love.graphics.setScissor()
end

function D.proyectil(e, sx, sy)
  sy = sy - 8
  local ang = math.atan2((e.ty or e.y) - e.y, (e.tx or e.x) - e.x)
  local col = { 1, 0.9, 0.45 }
  if e.tipo == "sagrado" then col = { 1, 0.95, 0.55 }
  elseif e.tipo == "misil" then col = { 0.55, 0.8, 1 } end
  if e.tipo == "fuego" then
    Efectos.cuadro("fuego", 0, 1, sx, sy + 14, 0.5)
  elseif e.tipo == "flecha" then
    love.graphics.setColor(0.35, 0.22, 0.1)
    love.graphics.setLineWidth(2)
    love.graphics.line(sx - math.cos(ang) * 9, sy - math.sin(ang) * 9, sx + math.cos(ang) * 7, sy + math.sin(ang) * 7)
    love.graphics.setColor(0.9, 0.9, 0.95)
    love.graphics.polygon("fill",
      sx + math.cos(ang) * 11, sy + math.sin(ang) * 11,
      sx + math.cos(ang + 2.5) * 4 + math.cos(ang) * 5, sy + math.sin(ang + 2.5) * 4 + math.sin(ang) * 5,
      sx + math.cos(ang - 2.5) * 4 + math.cos(ang) * 5, sy + math.sin(ang - 2.5) * 4 + math.sin(ang) * 5)
    love.graphics.setLineWidth(1)
  else
    love.graphics.setBlendMode("add")
    for i = 1, 5 do
      love.graphics.setColor(col[1], col[2], col[3], 0.5 - i * 0.08)
      love.graphics.circle("fill", sx - math.cos(ang) * i * 4, sy - math.sin(ang) * i * 4, 7 - i)
    end
    love.graphics.setColor(1, 1, 0.95, 0.95)
    love.graphics.circle("fill", sx, sy, 4)
    love.graphics.setBlendMode("alpha")
  end
end

function D.mueble(nombre, sx, sy)
  if nombre == "cofre" then
    Objetos.cofre(sx, sy + 14)
    return
  end
  local img = Arte.img("Tilesets/Inside_B.png")
  local pos = { cama = { 1, 10, 2, 2 }, mesa = { 0, 12, 1, 1 }, estandarte = { 14, 0, 1, 2 } }
  local p = pos[nombre] or pos.mesa
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(img, Arte.quad(img, p[1] * 32, p[2] * 32, p[3] * 32, p[4] * 32), sx, sy + 14, 0, 1, 1, p[3] * 16, p[4] * 32)
end

-- Dibuja una criatura u objeto vivo. Devuelve su altura en píxeles (para la placa).
function D.entidad(e, sx, sy, mundo, jugador)
  local pies = sy + 12
  local alto = 32
  local def = Personajes.de(e)
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.ellipse("fill", sx, pies - 1, def and def.fila and 20 or 11, def and def.fila and 7 or 4)
  if def then
    local reloj = (e.anim or 0) / 8
    local rojo = (e.flash or 0) > 0
    alto = Personajes.dibujar(def, e.dir or 1, e.mov or (math.abs(e.velx or 0) + math.abs(e.vely or 0) > 0.08), reloj,
      sx, pies, rojo and { 1, 0.6, 0.6 } or nil)
  elseif e.kind == "estatua" then
    Objetos.dibujar(e.faccion == "umbra" and "estatua_umbra" or "estatua_albor", 0, sx, pies)
    alto = 64
  elseif e.kind == "puerta" then
    Objetos.puerta(e.faccion, false, sx, pies, 0.8)
    alto = 50
  elseif e.kind == "altar" then
    Objetos.dibujar("altar_cristal", 0, sx, pies)
    alto = 64
  elseif e.kind == "bandera" then
    if not e.portador then Objetos.dibujar(e.faccion == "umbra" and "bandera_umbra" or "bandera_albor", 0, sx, pies) end
    alto = 64
  elseif e.kind == "loot" then
    Objetos.cofre(sx, pies)
    love.graphics.setColor(1, 0.9, 0.4, 0.6 + math.sin((mundo.tiempo or 0) * 5) * 0.3)
    love.graphics.circle("line", sx, pies - 6, 11)
  elseif e.kind == "trampa" then
    local img = Arte.img("Characters/!Hexagram.png")
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.draw(img, Arte.quad(img, 0, 0, 32, 32), sx, pies, 0, 1, 1, 16, 20)
  end
  if e.est then
    -- estados alterados: su animación se repite sobre la criatura
    local esc = (e.tam or 1) > 1 and 1.5 or 1
    local reloj = love.timer.getTime()
    for i, tipo in ipairs(e.est) do
      Efectos.cuadro(tipo, (reloj + i * 0.23) % 1, 1, sx, pies - (tipo == "aturdir" and 12 * esc or 0), esc, 0.9)
    end
  end
  if jugador and jugador.objetivo == e.id then
    love.graphics.setColor(1, 0.25, 0.2, 0.9)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", sx - 15, pies - 28, 30, 30, 3, 3)
    love.graphics.setLineWidth(1)
  end
  return alto
end

return D
