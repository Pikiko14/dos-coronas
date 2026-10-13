local Datos = require("compartido.dominio.datos")
local Atlas = require("src.presentacion.render.atlas")
local Campo = require("src.presentacion.render.campo")

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
  if e.kind == "proyectil" or e.kind == "trampa" or e.kind == "loot" or e.kind == "bandera" or e.kind == "cuerpo" or e.kind == "cristal" then return end
  local f = fuente()
  love.graphics.setFont(f)
  local color = { 0.92, 0.9, 0.84 }
  if TINTES_FACCION[e.faccion] and e.kind ~= "monstruo" then color = TINTES_FACCION[e.faccion]
  elseif e.kind == "monstruo" then color = e.elite and { 1, 0.8, 0.2 } or { 1, 0.62, 0.45 } end
  if e.kind == "caravana" then color = { 0.95, 0.8, 0.45 } end
  local nombre = e.nombre or ""
  if e.categoria == "party" then color, nombre = { 0.8, 0.55, 1 }, nombre .. " (Grupo)"
  elseif e.categoria == "gigante" then color, nombre = { 1, 0.35, 0.3 }, nombre .. " (Gigante)" end
  if e.buscado then
    -- los ladrones buscados se ven de rojo y marcados
    color = { 1, 0.3, 0.25 }
    nombre = "☠ " .. nombre
  end
  if e.llevaBandera then nombre = nombre .. " [estandarte]" end
  if e.gremio and (e.kind == "jugador" or e.kind == "bot") then nombre = nombre .. " <" .. e.gremio .. ">" end
  local ancho = f:getWidth(nombre)
  local y = py - alto - 15
  local barra = e.hp and e.hpMax
    and (e.kind == "monstruo" or e.kind == "estatua" or e.kind == "puerta" or e.kind == "altar" or e.hp < e.hpMax
      or (jugador and jugador.objetivo == e.id))
  if barra then
    local w = 34
    local frac = math.max(0, math.min(1, e.hp / math.max(1, e.hpMax)))
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", px - w / 2 - 1, y + 14, w + 2, 6)
    love.graphics.setColor(D.colorVida(frac))
    love.graphics.rectangle("fill", px - w / 2, y + 15, w * frac, 4)
  end
  if e.monturaFrac then
    -- vida de la montura: barra naranja sobre la del jinete
    local w = 34
    local frac = math.max(0, math.min(1, e.monturaFrac))
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", px - w / 2 - 1, y + 7, w + 2, 6)
    love.graphics.setColor(0.95, 0.6, 0.2, 1)
    love.graphics.rectangle("fill", px - w / 2, y + 8, w * frac, 4)
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

local marcarCasaPropia

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
  -- zonas elevadas: desde el suelo se marca su contorno y su nombre con el nivel de sus criaturas
  if pz == 0 and jugador.modo == "mundo" then
    for _, ms in ipairs(mapa.mesetas or {}) do
      if math.abs(ms.x + ms.w / 2 - jugador.x) < radio + 8 and math.abs(ms.y + ms.h / 2 - jugador.y) < radio + 8 then
        local rx, ry = ms.x * TILE - cam.x, ms.y * TILE - cam.y
        love.graphics.setColor(1, 0.85, 0.4, 0.35)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", rx, ry, ms.w * TILE, ms.h * TILE, 6, 6)
        love.graphics.setLineWidth(1)
        local texto = ms.nombre .. "  (nv " .. ms.nivelMin .. "-" .. ms.nivelMax .. ")  ▲"
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.print(texto, rx + 9, ry + 5)
        love.graphics.setColor(1, 0.9, 0.55, 0.9)
        love.graphics.print(texto, rx + 8, ry + 4)
      end
    end
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
  if pz == 0 and jugador.modo == "mundo" then
    marcarCasaPropia(mapa, jugador, cam, radio)
  end
  if mx and my and jugador.modo == "casa" and D.muebleElegido and love.window.hasMouseFocus() and D.dentroVista(mx, my) then
    local wx, wy = D.pantallaAMundo(cam, mx, my)
    local tx, ty = math.floor(wx), math.floor(wy)
    love.graphics.setColor(1, 0.86, 0.28, 0.35)
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
      elseif e.kind == "altar" then
        -- núcleo destruido: ruinas apagadas hasta que se regenere
        Objetos.dibujar("altar_cristal", 0, sx, sy + 14, { 0.3, 0.3, 0.32 }, 0.7)
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
    for nombre in pairs(casa and casa.muebles or {}) do
      local x, y, rot = mundo:posMueble(casa, nombre)
      if x then
        cola[#cola + 1] = {
          tipo = "mueble", x = x, y = y, nombre = nombre, rot = rot,
          elegido = nombre == D.muebleElegido,
        }
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
      local px0, py0 = (p.x + ancho / 2) * TILE - cam.x, (p.y + alto) * TILE - cam.y
      if Objetos.personalizados and Objetos.personalizados[p.tipo] then Objetos.personalizados[p.tipo](p, px0, py0)
      else Objetos.dibujar(p.tipo, variante, px0, py0, tint, alfa) end
    elseif item.tipo == "mueble" then
      D.mueble(item.nombre, sx, sy, item.rot, item.elegido)
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
  -- apuntando un poder de area: la zona habilitada (alcance) y el area de impacto bajo el cursor
  if D.apuntando and mx and my and D.dentroVista(mx, my) then
    D.zonaApuntada(D.apuntando, jugador, cam, mx, my, mundo.tiempo or 0)
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

-- tipo de proyectil -> mezcla con que se dibuja
local PROYECTILES = { misil = "add", fuego = "add", sagrado = "add", flecha = "alpha", sombra = "alpha" }

function D.proyectil(e, sx, sy)
  sy = sy - 8
  local ang = math.atan2((e.ty or e.y) - e.y, (e.tx or e.x) - e.x)
  -- sprites generados (Animations/Proyectil_<tipo>.png: 4 cuadros de 64x64, miran a la derecha)
  if PROYECTILES[e.tipo] then
    local img = Arte.img("Animations/Proyectil_" .. e.tipo .. ".png", true)
    local cuadro = math.floor(love.timer.getTime() * 12) % 4
    love.graphics.setColor(1, 1, 1, 1)
    if PROYECTILES[e.tipo] == "add" then love.graphics.setBlendMode("add") end
    love.graphics.draw(img, Arte.quad(img, cuadro * 64, 0, 64, 64), sx, sy, ang, 0.9, 0.9, 40, 32)
    love.graphics.setBlendMode("alpha")
    return
  end
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

-- La casa del jugador se tiñe de oro encima del terreno, sin hornear el color en la caché.
function marcarCasaPropia(mapa, jugador, cam, radio)
  local mias = nil
  for _, c in ipairs(mapa.ciudades or {}) do
    for _, par in ipairs(c.parcelas or {}) do
      if par.dueno == jugador.id then
        mias = mias or {}
        mias[par.x .. "," .. par.y] = true
      end
    end
  end
  if not mias then return end
  for _, e in ipairs(mapa.edificios or {}) do
    if mias[e.puertaX .. "," .. e.puertaY]
      and math.abs(e.x + e.w / 2 - jugador.x) < radio + 4
      and math.abs(e.y + e.h / 2 - jugador.y) < radio + 4 then
      local rx, ry = e.x * TILE - cam.x, e.y * TILE - cam.y
      local rw, rh = e.w * TILE, e.h * TILE
      love.graphics.setColor(1, 0.78, 0.22, 0.38)
      love.graphics.rectangle("fill", rx, ry, rw, rh)
      love.graphics.setColor(1, 0.92, 0.38, 1)
      love.graphics.setLineWidth(3)
      love.graphics.rectangle("line", rx + 1.5, ry + 1.5, rw - 3, rh - 3)
      love.graphics.setLineWidth(1)
      love.graphics.setColor(0.12, 0.07, 0.02, 0.9)
      love.graphics.print("Tu casa", rx + 8, ry - 16)
      love.graphics.setColor(1, 0.95, 0.55, 1)
      love.graphics.print("Tu casa", rx + 7, ry - 17)
    end
  end
end

function D.mueble(nombre, sx, sy, rot, elegido)
  rot = ((rot or 0) % 4) * (math.pi / 2)
  if nombre == "cofre" then
    local img = Arte.img("Characters/!Chest.png")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, Arte.quad(img, 0, 128, 32, 32), sx, sy + 14, rot, 1, 1, 16, 30)
  else
    local img = Arte.img("Tilesets/Inside_B.png")
    local pos = { cama = { 1, 10, 2, 2 }, mesa = { 0, 12, 1, 1 }, estandarte = { 14, 0, 1, 2 } }
    local p = pos[nombre] or pos.mesa
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, Arte.quad(img, p[1] * 32, p[2] * 32, p[3] * 32, p[4] * 32), sx, sy + 14, rot, 1, 1, p[3] * 16, p[4] * 32)
  end
  if elegido then
    love.graphics.setColor(1, 0.9, 0.35, 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", sx, sy - 8, 20)
    love.graphics.setLineWidth(1)
  end
end

-- Punto de impacto de un poder de area: el del cursor, dentro del alcance. Devuelve x, y y si el
-- cursor estaba fuera de la zona habilitada (en ese caso se acerca al borde).
function D.puntoApuntado(ap, jugador, cam, mx, my)
  local wx, wy = D.pantallaAMundo(cam, mx, my)
  local dx, dy = wx - jugador.x, wy - jugador.y
  local d = math.sqrt(dx * dx + dy * dy)
  local max = ap.rango or 6
  if d > max then return jugador.x + dx / d * max, jugador.y + dy / d * max, true end
  return wx, wy, false
end

function D.zonaApuntada(ap, jugador, cam, mx, my, t)
  local ix, iy, fuera = D.puntoApuntado(ap, jugador, cam, mx, my)
  local px, py = jugador.x * TILE - cam.x, jugador.y * TILE - cam.y
  local pulso = 0.5 + 0.5 * math.sin(t * 6)
  -- zona habilitada: todo lo que alcanza el poder
  love.graphics.setColor(0.4, 0.75, 1, 0.07)
  love.graphics.circle("fill", px, py, (ap.rango or 6) * TILE)
  love.graphics.setColor(0.55, 0.85, 1, 0.55)
  love.graphics.setLineWidth(1.5)
  love.graphics.circle("line", px, py, (ap.rango or 6) * TILE)
  -- area de impacto
  local sx, sy = ix * TILE - cam.x, iy * TILE - cam.y
  local r = (ap.aoe or 2) * TILE
  local c = fuera and { 1, 0.65, 0.3 } or { 1, 0.45, 0.25 }
  love.graphics.setColor(c[1], c[2], c[3], 0.18 + 0.1 * pulso)
  love.graphics.circle("fill", sx, sy, r)
  love.graphics.setColor(c[1], c[2], c[3], 0.9)
  love.graphics.setLineWidth(2)
  love.graphics.circle("line", sx, sy, r)
  love.graphics.setLineWidth(1)
  love.graphics.line(sx - 7, sy, sx + 7, sy)
  love.graphics.line(sx, sy - 7, sx, sy + 7)
  -- el trazo del personaje al punto
  love.graphics.setColor(c[1], c[2], c[3], 0.35)
  love.graphics.line(px, py, sx, sy)
end

-- Dibuja una criatura u objeto vivo. Devuelve su altura en píxeles (para la placa).
function D.entidad(e, sx, sy, mundo, jugador)
  local pies = sy + 12
  local alto = 32
  local def = Personajes.de(e)
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.ellipse("fill", sx, pies - 1, def and def.fila and ((def.celda or 64) > 64 and 26 or 20) or 11, def and def.fila and 7 or 4)
  if e.kind == "caravana" then
    -- carreta cubierta de las hojas de vehículos
    local img = Arte.img("Characters/Vehicle.png")
    local fila = ({ [1] = 0, [4] = 1, [3] = 2, [2] = 3 })[e.dir or 1] or 0
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, Arte.quad(img, 128, 128 + fila * 32, 32, 32), sx, pies, 0, 1.5, 1.5, 16, 28)
    alto = 52
  elseif e.kind == "cuerpo" and def then
    -- el cuerpo del caído: misma imagen en gris
    alto = Personajes.dibujarGris(def, e.dir or 1, sx, pies, 0.9)
  elseif def then
    def = Personajes.jineteDe(e, def)
    local reloj = (e.anim or 0) / 8
    local rojo = (e.flash or 0) > 0
    local anda = e.mov or (math.abs(e.velx or 0) + math.abs(e.vely or 0) > 0.08)
    local piesJinete = pies
    local montaFrente

    if e.montado then
      -- la montura va debajo y el jinete algo más arriba
      local m = Personajes.monturaDe(e.montado, e.faccion)
      if m and m.vehiculo then
        local img = Arte.img("Characters/Vehicle.png")
        local fila = ({ [1] = 0, [4] = 1, [3] = 2, [2] = 3 })[e.dir or 1] or 0
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, Arte.quad(img, 128, 128 + fila * 32, 32, 32), sx, pies, 0, 1.25, 1.25, 16, 28)
        piesJinete = pies - 14
      elseif m then
        if (e.dir or 1) == 1 then
          -- de frente la cabeza de la montura queda delante del jinete: se pinta el jinete antes
          -- (algo mas alto) y la montura encima, asi no le tapa la cara
          montaFrente = m
          piesJinete = pies - (m.altura or 10) - (m.extraFrente or 8)
        else
          Personajes.dibujar(m, e.dir or 1, anda, reloj, sx, pies)
          piesJinete = pies - (m.altura or 10)
        end
      end
    end
    -- montado, la que camina es la montura: el jinete va quieto (sin mover los pies)
    alto = Personajes.dibujar(def, e.dir or 1, anda and not e.montado, reloj, sx, piesJinete, rojo and { 1, 0.6, 0.6 } or nil)
    if montaFrente then Personajes.dibujar(montaFrente, 1, anda, reloj, sx, pies) end
    if e.montado then alto = alto + math.max(10, pies - piesJinete) end
  elseif e.kind == "estatua" then
    Objetos.dibujar(e.faccion == "umbra" and "estatua_umbra" or "estatua_albor", 0, sx, pies)
    alto = 64
  elseif e.kind == "puerta" then
    Objetos.puerta(e.faccion, false, sx, pies, 0.8)
    alto = 50
  elseif e.kind == "altar" then
    Objetos.dibujar("altar_cristal", 0, sx, pies)
    alto = 64
  elseif e.kind == "cofre_mz" then
    -- cofre de premio de la mazmorra: late con un brillo dorado
    local br = 0.3 + 0.15 * math.sin((mundo.tiempo or 0) * 4)
    love.graphics.setColor(1, 0.82, 0.3, br)
    love.graphics.ellipse("fill", sx, pies - 8, 26, 16, 20)
    Objetos.cofre(sx, pies)
    alto = 40
  elseif e.kind == "bandera" then
    if not e.portador then Objetos.dibujar(e.faccion == "umbra" and "bandera_umbra" or "bandera_albor", 0, sx, pies) end
    alto = 64
  elseif e.kind == "loot" then
    -- cada objeto, montón de oro o fardo de mercancía cae al suelo por separado
    local def = e.item and Datos.item(e.item)
    local brillo = 0.5 + math.sin((mundo.tiempo or 0) * 5 + (e.x or 0) * 3) * 0.25
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", sx, pies - 2, 9, 4)
    if def then
      Atlas.dibujar(def.hoja, def.sprite, sx, pies - 9, 0.75, 16, 16)
    elseif e.bien then
      Atlas.dibujar("equipment", 699, sx, pies - 9, 0.75, 16, 16)
    elseif e.oroSuelo then
      love.graphics.setColor(1, 0.82, 0.2, 1)
      love.graphics.circle("fill", sx, pies - 6, 5)
      love.graphics.setColor(0.7, 0.5, 0.1, 1)
      love.graphics.circle("line", sx, pies - 6, 5)
    else
      Objetos.cofre(sx, pies)
    end
    love.graphics.setColor(1, 0.9, 0.4, brillo)
    love.graphics.circle("line", sx, pies - 8, 10)
  elseif e.kind == "cristal" then
    -- cristal enemigo en el suelo: brilla y late para verse de lejos
    local pulso = 0.5 + 0.5 * math.sin((mundo.tiempo or 0) * 4 + (e.x or 0))
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", sx, pies - 1, 9, 4)
    Objetos.cristal(e.faccion, pulso, sx, pies - 2)
    love.graphics.setColor(0.5, 0.9, 1, 0.35 + 0.35 * pulso)
    love.graphics.circle("line", sx, pies - 10, 12 + 2 * pulso)
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
    local celda = def and def.fila and (def.celda or 64)
    local lado = celda and math.floor(celda * 0.85) or 30
    local arriba = celda and (celda - 6) or 28
    love.graphics.setColor(1, 0.25, 0.2, 0.9)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", sx - lado / 2, pies - arriba, lado, lado, 3, 3)
    love.graphics.setLineWidth(1)
  end
  return alto
end

return D
