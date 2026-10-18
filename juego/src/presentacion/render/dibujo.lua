local Datos = require("compartido.dominio.datos")
local Atlas = require("src.presentacion.render.atlas")
local Campo = require("src.presentacion.render.campo")

local Terreno = require("src.presentacion.render.terreno")
local Casas = require("src.presentacion.render.casas")
local Ambiente = require("src.presentacion.render.ambiente")
local MobAnim = require("src.presentacion.render.mob_anim")
local CasasIso = require("src.presentacion.render.casas_iso")
local Iso = require("src.presentacion.render.iso")
local PropsIso = require("src.presentacion.render.props_iso")
local MapaFao = require("src.presentacion.render.mapa_fao")
local InteriorCasa = require("src.presentacion.render.interior_casa")
local Personajes = require("src.presentacion.render.personajes")
local Objetos = require("src.presentacion.render.objetos")
local Trampas = require("src.presentacion.render.trampas")
local Efectos = require("src.presentacion.render.efectos")
local MapaMpc = require("src.presentacion.render.mapa_mpc")
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
  -- los mapas de FAO (.mpc) se ven en vista cenital, como en FAO (su minimapa lo demuestra: en isométrica los puentes y los muros de piedra se desarman)
  if mapa and mapa.mpc then Iso.forzar(false) else Iso.forzar(nil) end
  local vx, vy, vw, vh = vista()
  zoom = zoom or Datos.ZOOM
  local gx, gy = Iso.suelo(jugador.x, jugador.y)
  local x = gx - (vw / zoom) / 2
  local y = gy - (vh / zoom) / 2
  if mapa and mapa.w and mapa.h and not Iso.activo() then
    local ancho, alto = vw / zoom, vh / zoom
    local maxX = mapa.w * TILE - ancho
    local maxY = mapa.h * TILE - alto
    if maxX > 0 then x = math.max(0, math.min(maxX, x)) else x = maxX / 2 end
    if maxY > 0 then y = math.max(0, math.min(maxY, y)) else y = maxY / 2 end
  end
  return { x = x, y = y, zoom = zoom, vx = vx, vy = vy, vw = vw, vh = vh }
end

function D.mundoAPantalla(cam, x, y)
  local gx, gy = Iso.suelo(x, y)
  return (cam.vx or 0) + (gx - cam.x) * cam.zoom, (cam.vy or 0) + (gy - cam.y) * cam.zoom
end

function D.pantallaAMundo(cam, mx, my)
  local gx = (mx - (cam.vx or 0)) / cam.zoom + cam.x
  local gy = (my - (cam.vy or 0)) / cam.zoom + cam.y
  return Iso.inversa(gx, gy)
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
  -- personal del servidor: etiqueta [GM] (dorada) o [CM] (celeste) delante del nombre
  if e.staff and (e.kind == "jugador" or e.kind == "bot") then
    nombre = "[" .. e.staff:upper() .. "] " .. nombre
    color = e.staff == "gm" and { 1, 0.82, 0.3 } or { 0.45, 0.85, 1 }
  end
  if e.llevaBandera then nombre = nombre .. " [estandarte]" end
  if (e.llevaCristales or 0) > 0 then nombre = nombre .. " [" .. e.llevaCristales .. (e.llevaCristales == 1 and " cristal]" or " cristales]") end
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
    local radio = Iso.radio(w, h) - 1
    love.graphics.setColor(1, 1, 1, 1)
    Iso.empujar(cam)
    for x = px - radio, px + radio do
      local col = mapa.alto[x]
      if col then
        for y = py - radio, py + radio do
          if col[y] then
            love.graphics.draw(im, Arte.quad(im, 32 * (x % 2), 32 * (y % 2), 32, 32), x * TILE, y * TILE)
          end
        end
      end
    end
    Iso.sacar()
  end
end

local marcarCasaPropia
local marcarTiendas

function D.escena(mundo, jugador, cam, mx, my)
  local mapa = mundo:mapaDe(jugador)
  local z = cam.zoom
  local vx, vy, vw, vh = cam.vx, cam.vy, cam.vw, cam.vh
  local ambiente = Ambiente.empezar(vx, vy, vw, vh)
  love.graphics.setScissor(vx, vy, vw, vh)
  love.graphics.setColor(0.04, 0.05, 0.07, 1)
  love.graphics.rectangle("fill", vx, vy, vw, vh)
  love.graphics.push()
  love.graphics.translate(vx, vy)
  love.graphics.scale(z, z)
  local pz = jugador.z or 0
  local ancho, alto = vw / z, vh / z
  local radio = Iso.radio(ancho, alto)
  if pz > 0 then
    dibujarPiso(mapa, jugador, cam, ancho, alto)
  else
    love.graphics.setColor(1, 1, 1, 1)
    Terreno.dibujar(mapa, cam.x, cam.y, ancho, alto, mundo.tiempo)
    Terreno.precargar(mapa, cam.x, cam.y, ancho, alto)
    if mapa.trampas then Trampas.dibujar(mapa, mundo.tiempo, cam.x, cam.y, ancho, alto) end
  end
  -- zonas elevadas: desde el suelo se marca su contorno y su nombre con el nivel de sus criaturas
  if pz == 0 and jugador.modo == "mundo" then
    for _, ms in ipairs(mapa.mesetas or {}) do
      if math.abs(ms.x + ms.w / 2 - jugador.x) < radio + 8 and math.abs(ms.y + ms.h / 2 - jugador.y) < radio + 8 then
        local gx, gy = Iso.suelo(ms.x, ms.y)
        local rx, ry = gx - cam.x, gy - cam.y
        love.graphics.setColor(1, 0.85, 0.4, 0.35)
        Iso.empujar(cam)
        love.graphics.setLineWidth(2 * (Iso.activo() and 1.4 or 1))
        love.graphics.rectangle("line", ms.x * TILE, ms.y * TILE, ms.w * TILE, ms.h * TILE, 6, 6)
        love.graphics.setLineWidth(1)
        Iso.sacar()
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
      local gx, gy = Iso.suelo(s.x + 0.5, s.y + 0.5)
      local sx, sy = gx - cam.x, gy - cam.y
      Iso.empujar(cam)
      love.graphics.setColor(0.35, 0.22, 0.12, 1)
      love.graphics.rectangle("fill", s.x * TILE, s.y * TILE, TILE, TILE)
      love.graphics.setColor(0.8, 0.62, 0.34, 1)
      for i = 0, 3 do love.graphics.rectangle("fill", s.x * TILE + 2, s.y * TILE + 3 + i * 8, TILE - 4, 5) end
      Iso.sacar()
      love.graphics.setColor(1, 0.9, 0.45, 0.9)
      love.graphics.print(s.a > s.de and "▲" or "▼", sx - 5, sy - 10)
    end
  end
  if mx and my and jugador.modo ~= "casa" and love.window.hasMouseFocus() and D.dentroVista(mx, my) then
    local wx, wy = D.pantallaAMundo(cam, mx, my)
    local tx, ty = math.floor(wx), math.floor(wy)
    love.graphics.setColor(1, 1, 1, 0.18)
    Iso.empujar(cam)
    love.graphics.rectangle("fill", tx * TILE, ty * TILE, TILE, TILE)
    Iso.sacar()
  end
  if pz == 0 and jugador.modo == "mundo" then
    marcarCasaPropia(mapa, jugador, cam, radio)
  end
  if mx and my and jugador.modo == "casa" and D.muebleElegido and love.window.hasMouseFocus() and D.dentroVista(mx, my) then
    local wx, wy = D.pantallaAMundo(cam, mx, my)
    local tx, ty = math.floor(wx), math.floor(wy)
    love.graphics.setColor(1, 0.86, 0.28, 0.35)
    Iso.empujar(cam)
    love.graphics.rectangle("fill", tx * TILE, ty * TILE, TILE, TILE)
    Iso.sacar()
  end

  -- cadáveres y puertas caídas: debajo de todo lo que se mueve
  for _, e in pairs(mundo.entidades) do
    if e.vivo == false and mundo:mismoLugar(jugador, e)
      and math.abs(e.x - jugador.x) < radio and math.abs(e.y - jugador.y) < radio then
      local px, py = Iso.pos(e.x, e.y)
      local sx, sy = px - cam.x, py - cam.y
      local defMuerto = e.kind == "monstruo" and Personajes.de(e) or nil
      if e.kind == "monstruo" and defMuerto and defMuerto.anim then
        -- la animación de muerte y, al acabar, el último cuadro que se va apagando antes de reaparecer
        local resta = (e.respawn or 0) - (mundo.tiempo or 0)
        local total = e.elite and Datos.RESPAWN_ELITE or Datos.RESPAWN_MONSTRUO
        MobAnim.muerto(defMuerto.anim, total - resta, sx, sy + 12, e.dir or 1, math.max(0, math.min(1, resta / 6)))
      elseif e.kind == "monstruo" then
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

  if jugador.modo == "casa" then InteriorCasa.paredesIso(mapa, cam) end
  if ambiente and pz == 0 then
    Ambiente.sombrasSuelo(mundo, mapa, jugador, radio, cam)
    Ambiente.dibujarAntorchas(mapa, cam, z, vw, vh)
  end
  local cola = {}
  -- casas isométricas: se ordenan con todo lo demás por el borde de abajo de su huella
  if pz == 0 and jugador.modo == "mundo" and CasasIso.activo() then
    for _, e in ipairs(mapa.edificios or {}) do
      if math.abs(e.x + e.w / 2 - jugador.x) < radio + 5 and math.abs(e.y + e.h / 2 - jugador.y) < radio + 5 then
        cola[#cola + 1] = { tipo = "casa", x = e.x + e.w / 2, y = e.y + e.h, e = e, prof = e.x + e.w + e.y + e.h - 1.5 }
      end
    end
  end
  if pz == 0 then
    for _, prop in ipairs(mapa.props or {}) do
      if math.abs(prop.x - jugador.x) < radio and math.abs(prop.y - jugador.y) < radio then
        cola[#cola + 1] = {
          tipo = "prop", x = prop.x + (prop.ancho or 1) / 2,
          y = prop.y + (prop.alto or 1) - 0.1, prop = prop,
          prof = prop.x + (prop.ancho or 1) / 2 + prop.y + (prop.alto or 1) / 2 + 0.2,
        }
      end
    end
  end
  if pz == 0 and MapaFao.activo() and mapa.decorado then
    for _, prop in ipairs(MapaFao.decorProps(mapa)) do
      if math.abs(prop.x - jugador.x) < radio and math.abs(prop.y - jugador.y) < radio then
        prop.fao = prop.fao or { 0.74, 0.68, 0.66 }      -- piedras del campo quemado: algo más oscuras
        cola[#cola + 1] = { tipo = "prop", x = prop.x + 0.5, y = prop.y + 0.9, prop = prop, prof = prop.x + prop.y + 1.2 }
      end
    end
  end
  local objetosMpc
  if mapa.mpc then
    -- mapa de FAO (.mpc): sus árboles, rocas y plantas se ordenan con los personajes por su punto de apoyo (y sus sombras van antes, en el suelo)
    objetosMpc = MapaMpc.visibles(mapa, jugador.x, jugador.y, radio + 4)
    for _, o in ipairs(objetosMpc) do
      local d = mapa.mpc.defs[o.id]
      if not (d and d.p) then cola[#cola + 1] = { tipo = "objfao", x = o.x / 64, y = o.y / 64, o = o } end
    end
  end
  if pz == 0 and MapaFao.murosActivo() then
    for _, m in ipairs(MapaFao.lista(mapa)) do
      if math.abs(m.x - jugador.x) < radio and math.abs(m.y - jugador.y) < radio then
        cola[#cola + 1] = { tipo = "muro", x = m.x + 0.5, y = m.y + 0.5, m = m, prof = m.x + m.y + 1.2 }
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
  -- de atrás hacia delante: por la fila en la pantalla (y en vista cenital; x + y en isométrica)
  local iso = Iso.activo()
  for _, item in ipairs(cola) do
    item.p = item.prof or (iso and (item.x + item.y) or item.y)
  end
  if iso then
    -- quien está delante de una casa (al sur o al este de su huella) se dibuja después de ella: el dibujo de la casa es más grande que su
    -- huella y, ordenado solo por su esquina de abajo, taparía a los PNJ que esperan junto a la puerta
    for _, c in ipairs(cola) do
      if c.tipo == "casa" then
        local e = c.e
        for _, it in ipairs(cola) do
          if it.tipo == "ent" and it.p < c.p then
            local sur = it.y >= e.y + e.h and it.y <= e.y + e.h + 3 and it.x >= e.x - 1.5 and it.x <= e.x + e.w + 1.5
            local este = it.x >= e.x + e.w and it.x <= e.x + e.w + 3 and it.y >= e.y - 1.5 and it.y <= e.y + e.h + 1.5
            if sur or este then it.p = c.p + 0.001 end
          end
        end
      end
    end
  end
  table.sort(cola, function(a, b) return a.p < b.p end)
  if objetosMpc then
    -- piezas planas (tableros de puentes, bordes, césped): en el suelo, bajo los personajes, de atrás hacia delante
    local planos = {}
    for _, o in ipairs(objetosMpc) do
      local d = mapa.mpc.defs[o.id]
      if d and d.p then planos[#planos + 1] = o end
    end
    table.sort(planos, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
    for _, o in ipairs(planos) do
      local gx, gy = Iso.suelo(o.x / 64, o.y / 64)
      MapaMpc.dibujarObjeto(mapa, o, gx - cam.x, gy - cam.y + (Iso.activo() and Iso.PIES or 0), mundo.tiempo)
    end
    for _, o in ipairs(objetosMpc) do
      local gx, gy = Iso.suelo(o.x / 64, o.y / 64)
      MapaMpc.dibujarSombra(mapa, o, gx - cam.x, gy - cam.y)
    end
  end
  -- capa de suelo de los efectos de FAO compuestos (el anillo del tajo): bajo los personajes
  for _, fx in ipairs(mundo.efectos or {}) do
    local d = Efectos.def[fx.tipo]
    if d and d.suelo and math.abs(fx.x - jugador.x) < radio and math.abs(fx.y - jugador.y) < radio then
      local epx, epy = Iso.pos(fx.x, fx.y)
      Efectos.suelo(fx.tipo, fx, epx - cam.x, epy - cam.y + 14)
    end
  end
  local placas = {}
  for _, item in ipairs(cola) do
    local px, py = Iso.pos(item.x, item.y)
    local sx, sy = px - cam.x, py - cam.y
    if item.tipo == "prop" then
      local p = item.prop
      local variante = math.floor(hash(p.x, p.y) * 997)
      local tint = p.fao
      local nombreFao = p.tipo
      local umbra = mapa.lado and mapa.lado[p.x] and mapa.lado[p.x][p.y] == "umbra"
      if MapaFao.activo() then
        -- arte de mapa FAO: en las ciudades los árboles son de hoja ancha; en tierras de Umbra los abetos son de otro color
        if nombreFao == "arbol_pino" and mapa.bioma and mapa.bioma[p.x] and mapa.bioma[p.x][p.y] == "ciudad" then nombreFao = "arbol"
        elseif nombreFao == "arbol_pino" and umbra then nombreFao = "arbol_pino_umbra" end
      end
      if p.tipo:find("arbol") and umbra and nombreFao ~= "arbol_pino_umbra" then
        tint = { 0.72, 0.64, 0.95 }
      end
      local ancho, alto = p.ancho or 1, p.alto or 1
      local alfa
      if p.ancho and jugador.x > p.x - 1 and jugador.x < p.x + ancho + 1
        and jugador.y > p.y - 2.5 and jugador.y < p.y + alto - 0.1 then
        alfa = 0.45 -- el jugador queda detrás: se ve a través de la montaña
      end
      local px0, py0
      if iso then
        -- vista isométrica: el objeto se apoya en el centro de su huella
        local gx, gy = Iso.suelo(p.x + ancho / 2, p.y + alto / 2)
        px0, py0 = gx - cam.x, gy - cam.y + 4
      else
        px0, py0 = (p.x + ancho / 2) * TILE - cam.x, (p.y + alto) * TILE - cam.y
      end
      if iso and MapaFao.tiene(nombreFao) and MapaFao.dibujar(nombreFao, variante, px0, py0, tint, alfa, p.x * 0.35 + p.y * 0.2 + hash(p.x, p.y) * 0.9) then
        -- arte de mapa FAO
      elseif PropsIso.dibujar(p, mapa, px0, py0, alfa, tint) then
        -- arte nuevo de las ciudades
      elseif Objetos.personalizados and Objetos.personalizados[p.tipo] then Objetos.personalizados[p.tipo](p, px0, py0)
      else Objetos.dibujar(p.tipo, variante, px0, py0, tint, alfa, p.x * 0.35 + p.y * 0.2 + hash(p.x, p.y) * 0.9) end
    elseif item.tipo == "objfao" then
      local sy0 = sy + (Iso.activo() and Iso.PIES or 0)
      -- objeto alto delante del personaje que lo tapa: se atenúa (como los árboles); las piezas de suelo ya van debajo de todo
      local jx, jy = Iso.pos(jugador.x, jugador.y)
      local alfaO = (item.y > jugador.y and MapaMpc.tapa(mapa, item.o, sx, sy0, jx - cam.x, jy - cam.y - 20)) and 0.45 or 1
      MapaMpc.dibujarObjeto(mapa, item.o, sx, sy0, mundo.tiempo, alfaO)
    elseif item.tipo == "muro" then
      local m = item.m
      local gx, gy = Iso.suelo(m.x + 0.5, m.y + 0.5)
      -- el jugador queda tapado por el muro (delante de él): se ve a través
      local alfa = (jugador.x + jugador.y < m.x + m.y + 1 and math.abs(jugador.x - m.x) < 2.6 and math.abs(jugador.y - m.y) < 2.6) and 0.5 or 1
      MapaFao.dibujarMuro(m, gx - cam.x, gy - cam.y, alfa)
    elseif item.tipo == "casa" then
      CasasIso.dibujar(item.e, cam.x, cam.y, CasasIso.tapa(item.e, jugador.x, jugador.y) and 0.5 or 1)
    elseif item.tipo == "mueble" then
      D.mueble(item.nombre, sx, sy, item.rot, item.elegido)
    else
      local e = item.e
      local alto = D.entidad(e, sx, sy, mundo, jugador)
      placas[#placas + 1] = { e = e, x = sx, y = sy, alto = alto }
    end
  end
  for _, e in pairs(mundo.entidades) do
    if e.kind == "proyectil" and not e.oculto and mundo:mismoLugar(jugador, e) then
      local ppx, ppy = Iso.pos(e.x, e.y)
      D.proyectil(e, ppx - cam.x, ppy - cam.y)
    end
  end
  -- quien va montado: los hechizos salen y caen sobre el jinete (centrados en él), no a los pies de la montura
  local montados
  for _, e in pairs(mundo.entidades) do
    if e.montado and e.vivo ~= false and (e.kind == "jugador" or e.kind == "bot") then
      local m = Personajes.monturaDe(e.montado, e.faccion)
      if m and (m.altura or m.vehiculo) then
        montados = montados or {}
        montados[#montados + 1] = { e = e, lift = m.altura or 14 }
      end
    end
  end
  for _, fx in ipairs(mundo.efectos or {}) do
    if math.abs(fx.x - jugador.x) < radio and math.abs(fx.y - jugador.y) < radio then
      local epx, epy = Iso.pos(fx.x, fx.y)
      local rotE = fx.rot
      if rotE and Iso.activo() then rotE = Iso.angulo(math.cos(rotE), math.sin(rotE)) end
      local lift = 0
      for _, mo in ipairs(montados or {}) do
        if math.abs(mo.e.x - fx.x) < 0.7 and math.abs(mo.e.y - fx.y) < 0.7 then lift = mo.lift break end
      end
      Efectos.cuadro(fx.tipo, fx.t, fx.dur, epx - cam.x, epy - cam.y + 14 - lift, nil, nil, rotE, fx)
    end
  end
  -- apuntando un poder de area: la zona habilitada (alcance) y el area de impacto bajo el cursor
  if D.apuntando and mx and my and D.dentroVista(mx, my) then
    D.zonaApuntada(D.apuntando, jugador, cam, mx, my, mundo.tiempo or 0)
  end
  if pz == 0 and jugador.modo == "mundo" then
    marcarTiendas(mapa, jugador, cam, radio)
    if not CasasIso.activo() then Casas.humo(mapa, cam, mundo.tiempo or 0, jugador.x, jugador.y, radio) end
    -- flecha dorada hacia el destino de la misión que sigues
    if D.flechaMision then
      local fpx, fpy = Iso.pos(jugador.x, jugador.y)
      D.flechaMision(jugador, fpx - cam.x, fpy - cam.y)
    end
  end
  love.graphics.pop()
  love.graphics.setScissor()
  if ambiente then Ambiente.terminar(mundo, jugador, mapa, cam) end

  -- nombres, barras y números de daño: en pantalla, con letra pequeña y nítida
  love.graphics.setScissor(vx, vy, vw, vh)
  for _, p in ipairs(placas) do
    placa(p.e, vx + p.x * z, vy + (p.y + 12) * z, p.alto * z, jugador, mundo.tiempo)
  end
  local f = fuente()
  love.graphics.setFont(f)
  for _, n in ipairs(mundo.numeros) do
    if math.abs(n.x - jugador.x) < radio then
      local npx, npy = Iso.pos(n.x, n.y - 0.2)
      local sx = vx + (npx - cam.x) * z
      local sy = vy + (npy - cam.y) * z - 24 * z
      textoSombra(n.texto, sx - f:getWidth(n.texto) / 2, sy, n.color, math.min(1, n.vida / 0.5))
    end
  end
  love.graphics.setScissor()
end

-- tipo de proyectil -> mezcla con que se dibuja
local PROYECTILES = { misil = "add", fuego = "add", sagrado = "add", flecha = "alpha", sombra = "alpha", lanza = "alpha", necro = "alpha" }

function D.proyectil(e, sx, sy)
  sy = sy - 17      -- sale del pecho de quien lo lanza
  local ang = Iso.angulo((e.tx or e.x) - e.x, (e.ty or e.y) - e.y)
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
      love.graphics.setColor(1, 0.78, 0.22, 0.38)
      Iso.empujar(cam)
      for fy = 0, e.h - 1 do
        for fx = 0, e.w - 1 do
          if not (e.vacio and e.vacio[fx .. "," .. fy]) then
            love.graphics.rectangle("fill", (e.x + fx) * TILE, (e.y + fy) * TILE, TILE, TILE)
          end
        end
      end
      Iso.sacar()
      local gx, gy = Iso.suelo(e.x + e.w / 2, e.y + e.h / 2)
      local rx, ry = gx - cam.x - 22, gy - cam.y - (Iso.activo() and 70 or 0) - (e.h * TILE) / 2
      love.graphics.setColor(0.12, 0.07, 0.02, 0.9)
      love.graphics.print("Tu casa", rx + 1, ry + 1)
      love.graphics.setColor(1, 0.95, 0.55, 1)
      love.graphics.print("Tu casa", rx, ry)
    end
  end
end

-- El arma más básica de cada clase de un reino, en el orden de sus maestros.
local armasCache = {}
local function armasPorClase(faccion)
  local f = faccion == "umbra" and "umbra" or "albor"
  if armasCache[f] then return armasCache[f] end
  local lista = {}
  for _, c in ipairs(f == "umbra" and { "guerrero", "nigromante", "cazador", "mago", "clerigo" } or { "guerrero", "lancero", "cazador", "mago", "clerigo" }) do
    local mejor
    for id, it in pairs(Datos.items) do
      if it.hueco == "arma" and it.clase == c and not it.quest and not it.mall then
        local m = Datos.items[mejor]
        if not mejor or (it.nivel or 1) < (m.nivel or 1) or ((it.nivel or 1) == (m.nivel or 1) and id < mejor) then mejor = id end
      end
    end
    if mejor then lista[#lista + 1] = mejor end
  end
  armasCache[f] = lista
  return lista
end

function marcarTiendas(mapa, jugador, cam, radio)
  -- Lo que se ve en el letrero: la enfermera, una poción; el gremio de maestros, un arma; el establo, una montura.
  local iconos = {
    mercado = { "pocion_vida" },
    maestros = { "guerrero_arma_1" },
    establo = { "montura" },
  }
  local function dibujarIcono(id, x, y, faccion)
    if id == "montura" then
      local def = Personajes.monturaDe("caballo", faccion)
      if not def then return end
      love.graphics.push()
      love.graphics.translate(x, y + 8)
      love.graphics.scale(0.45, 0.45)
      Personajes.dibujar(def, 1, false, 0, 0, 0)
      love.graphics.pop()
      return
    end
    local it = Datos.item(id)
    if it then Atlas.dibujar(it.hoja, it.sprite, x, y, 0.55, 16, 16) end
  end
  -- Letrero pequeño sobre la puerta de cada tienda, con un solo icono que dice qué vende.
  for _, e in ipairs(mapa.edificios or {}) do
    local lista = e.rotulo and iconos[e.tienda]
    if lista
      and math.abs(e.puertaX + 0.5 - jugador.x) < radio
      and math.abs(e.puertaY + 0.5 - jugador.y) < radio then
      local fila = e.techoSur and (e.puertaY + 1) or (e.puertaY - 1)
      if e.estilo == "establo" then fila = e.techoSur and (e.puertaY + 2) or (e.puertaY - 2) end  -- la puerta grande ocupa dos filas: el letrero va en el tejado
      local gx, gy = Iso.suelo(e.puertaX + 0.5, fila + 0.5)
      local cx, cy = gx - cam.x, gy - cam.y
      if Iso.activo() then
        -- el letrero cuelga sobre la puerta del dibujo de la casa
        local dx, dy = Iso.suelo(e.puertaX + 0.5, e.puertaY + 1)
        cx, cy = dx - cam.x, dy - cam.y - 66
      end
      -- el gremio de maestros muestra el arma de cada clase de su reino; el resto, un solo icono
      local iconosLetrero = lista
      if e.tienda == "maestros" then iconosLetrero = armasPorClase(e.faccion) end
      local n = #iconosLetrero
      local ancho = 24 * n
      love.graphics.setColor(0, 0, 0, 0.35)
      love.graphics.rectangle("fill", cx - ancho / 2 + 1, cy - 9, ancho, 24, 4, 4)
      love.graphics.setColor(0.36, 0.24, 0.1, 1)
      love.graphics.rectangle("fill", cx - ancho / 2, cy - 11, ancho, 22, 4, 4)
      love.graphics.setColor(0.85, 0.66, 0.3, 1)
      love.graphics.rectangle("line", cx - ancho / 2 + 0.5, cy - 10.5, ancho - 1, 21, 4, 4)
      for i, id in ipairs(iconosLetrero) do dibujarIcono(id, cx - ancho / 2 + 12 + (i - 1) * 24, cy, e.faccion) end
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
  local px, py = jugador.x * TILE, jugador.y * TILE
  local pulso = 0.5 + 0.5 * math.sin(t * 6)
  -- todo va pegado al suelo: en isométrico los círculos salen como elipses
  Iso.empujar(cam)
  -- zona habilitada: todo lo que alcanza el poder
  love.graphics.setColor(0.4, 0.75, 1, 0.07)
  love.graphics.circle("fill", px, py, (ap.rango or 6) * TILE)
  love.graphics.setColor(0.55, 0.85, 1, 0.55)
  love.graphics.setLineWidth(1.5)
  love.graphics.circle("line", px, py, (ap.rango or 6) * TILE)
  -- area de impacto
  local sx, sy = ix * TILE, iy * TILE
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
  Iso.sacar()
end

-- ---------------------------------------------------------------------------------------------------------------------------
-- Animación de ataque. Los sprites solo traen cuadros de caminar, así que el ataque se anima por código y vale para toda
-- criatura y todo addon: anticipación (se encoge y echa atrás), embestida (se estira y se lanza hacia el objetivo), tajo
-- y recuperación con un pequeño rebote. Los que atacan de lejos (disparos y conjuros) cargan con un pulso de luz y sueltan.
-- El servidor solo dice "atacó" (atqN sube con cada ataque, atqX/atqY = hacia dónde, atqL = de lejos): el movimiento lo
-- calcula cada cliente con su reloj, a toda velocidad de cuadros, así que no depende de cuántas fotos lleguen.
-- ---------------------------------------------------------------------------------------------------------------------------
local ATQ = {}
local atqLimpieza = 0
local DUR_CERCA, DUR_LEJOS = 0.46, 0.52

local function suave(t) return t * t * (3 - 2 * t) end
local function salida(t) return 1 - (1 - t) * (1 - t) end
local function rebote(t)   -- sale y se pasa un poco antes de asentarse
  local c1, c3 = 1.2, 2.2
  return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

-- Dirección del ataque en pantalla: hacia el objetivo si el servidor la dio; si no, hacia donde mira.
local DIR_PANTALLA = { [1] = { 0, 1 }, [2] = { 0, -1 }, [3] = { 1, 0 }, [4] = { -1, 0 } }

local function estadoAtaque(e)
  local ahora = (D.relojAtaque or love.timer.getTime)()
  if ahora - atqLimpieza > 10 then
    atqLimpieza = ahora
    for id, st in pairs(ATQ) do if ahora - st.visto > 10 then ATQ[id] = nil end end
  end
  local st = ATQ[e.id]
  if e.atqN and (not st or st.n ~= e.atqN) then
    st = { n = e.atqN, t0 = ahora, ax = e.atqX, ay = e.atqY, lejos = e.atqL and true or false }
    if st.ax then st.ax, st.ay = Iso.vector(st.ax, st.ay) end
    if not st.ax then
      local d = DIR_PANTALLA[e.dir or 1] or DIR_PANTALLA[1]
      st.ax, st.ay = d[1], d[2]
    end
    ATQ[e.id] = st
  end
  if not st then return nil end
  st.visto = ahora
  local u = (ahora - st.t0) / (st.lejos and DUR_LEJOS or DUR_CERCA)
  if u >= 1 then return nil end
  return st, u
end

D.estadoAtaque = estadoAtaque   -- (las pruebas lo usan con D.relojAtaque para congelar el tiempo)

-- Calcula la pose de este cuadro: desplazamiento, giro, escala y cuánto "golpe" hay (s) para los efectos.
local function poseAtaque(st, u, k)
  local ax, ay = st.ax, st.ay
  local pos, s, esx, esy, alz = 0, 0, 1, 1, 0
  if st.lejos then
    -- conjuro / disparo: carga (se estira hacia arriba) y suelta con un retroceso corto
    if u < 0.38 then
      local c = suave(u / 0.38)
      esy, esx, alz = 1 + 0.06 * c, 1 - 0.03 * c, 2.2 * c
      pos = -1.2 * c
      s = c
    else
      local r = (u - 0.38) / 0.62
      local b = rebote(r)
      esy, esx = 1 + 0.06 * (1 - b), 1 - 0.03 * (1 - b)
      alz = 2.2 * (1 - b)
      pos = -1.2 + 1.2 * b - 2.4 * math.sin(math.pi * math.min(1, r * 1.6)) * (1 - r)
      s = math.max(0, 1 - r * 2.2)
    end
  else
    local ATRAS, ADELANTE = 3.5 * k, 9 * k
    if u < 0.28 then
      local c = salida(u / 0.28)
      pos = -ATRAS * c
      esy, esx = 1 - 0.05 * c, 1 + 0.04 * c
    elseif u < 0.46 then
      local g = suave((u - 0.28) / 0.18)
      pos = -ATRAS + (ATRAS + ADELANTE) * g
      s = math.sin(math.pi * (u - 0.28) / 0.18)
      esy, esx = 0.95 + 0.10 * g, 1.04 - 0.07 * g
      alz = 1.5 * s
    else
      local r = (u - 0.46) / 0.54
      pos = ADELANTE * (1 - rebote(r))
      esy, esx = 1.05 - 0.05 * rebote(r), 0.97 + 0.03 * rebote(r)
    end
  end
  return {
    dx = ax * pos, dy = ay * pos * 0.6 - alz,
    rot = st.lejos and 0 or ax * 0.11 * (pos / (9 * k)),
    esx = esx, esy = esy, s = s,
  }
end

-- Efectos que acompañan al ataque (tajo, pulso de luz): se dibujan sin la deformación de la criatura.
local function efectoAtaque(e, st, u, sx, pies, k, def)
  local monstruo = e.kind == "monstruo"
  local c = monstruo and { 1, 0.42, 0.32 } or { 1, 0.95, 0.72 }
  local alto = (def and def.fila and 14 or 21) * k      -- (altura del pecho: los personajes de FAO son más altos que los antiguos)
  if st.lejos then
    local cm = monstruo and { 0.85, 0.4, 1 } or { 0.62, 0.86, 1 }
    -- anillo que se abre en el suelo mientras carga y destello en el pecho al soltar
    local a = math.sin(math.pi * math.min(1, u / 0.8)) * 0.8
    if a > 0 then
      love.graphics.setColor(cm[1], cm[2], cm[3], a * 0.55)
      love.graphics.ellipse("line", sx, pies - 1, (9 + 15 * u) * k, (4 + 6 * u) * k)
      love.graphics.setColor(cm[1], cm[2], cm[3], a * 0.22)
      love.graphics.ellipse("fill", sx, pies - 1, (8 + 12 * u) * k, (3 + 5 * u) * k)
    end
    local f = 1 - math.abs(u - 0.38) / 0.22
    if f > 0 then
      love.graphics.setColor(cm[1], cm[2], cm[3], 0.55 * f)
      love.graphics.circle("fill", sx + st.ax * 6 * k, pies - alto - st.ay * 2, (5 + 6 * f) * k)
      love.graphics.setColor(1, 1, 1, 0.7 * f)
      love.graphics.circle("fill", sx + st.ax * 6 * k, pies - alto - st.ay * 2, (2 + 3 * f) * k)
    end
    return
  end
  -- tajo: un arco que barre de un lado al otro delante de quien ataca, con estela que se apaga
  local u0, u1 = 0.26, 0.54
  if u < u0 or u > u1 + 0.18 then return end
  local prog = math.min(1, (u - u0) / (u1 - u0))
  local a0 = math.atan2(st.ay * 0.7, st.ax)
  local cx, cy = sx + st.ax * 8 * k, pies - alto + st.ay * 5 * k
  local R = 19 * k
  local cabeza = a0 - 1.15 + 2.3 * prog
  local desv = u > u1 and (1 - (u - u1) / 0.18) or 1
  local n = 10
  local px, py
  for i = 0, n do
    local ang = cabeza - i * 0.11
    local fx = (1 - i / n) * desv
    local x, y = cx + math.cos(ang) * R, cy + math.sin(ang) * R * 0.75
    if px then
      love.graphics.setColor(c[1], c[2], c[3], 0.95 * fx)
      love.graphics.setLineWidth(1 + 5 * fx)
      love.graphics.line(px, py, x, y)
    end
    px, py = x, y
  end
  love.graphics.setLineWidth(1)
end

-- Marca de un PNJ de misiones para este jugador ("!" nuevo, "?" para entregar); se calcula dos veces por segundo.
local marcasNpc = {}
function D.marcaNpc(jugador, qid)
  local ahora = love.timer.getTime()
  local c = marcasNpc[qid]
  if not c or ahora - c.t > 0.5 or c.jugador ~= jugador.id then
    c = { t = ahora, jugador = jugador.id, marca = require("compartido.dominio.misiones").marcaNpc(jugador, qid) or false }
    marcasNpc[qid] = c
  end
  return c.marca or nil
end

-- Hacia dónde se ve que mira alguien en la pantalla (1 abajo, 2 arriba, 3 derecha, 4 izquierda). En vista isométrica los ejes del
-- mundo van en diagonal: se mira hacia donde se mueve en la pantalla y, parado, hacia donde miraba.
local DIR_MUNDO = { [1] = { 0, 1 }, [2] = { 0, -1 }, [3] = { 1, 0 }, [4] = { -1, 0 } }
function D.dirVisible(e)
  if not Iso.activo() then return e.dir end
  local d = Iso.dirPantalla(e.velx or 0, e.vely or 0)
  if d then
    e._dirIso = d
    return d
  end
  if e._dirIso and e._dirMundo == e.dir then return e._dirIso end
  e._dirMundo = e.dir
  local v = DIR_MUNDO[e.dir or 1] or DIR_MUNDO[1]
  e._dirIso = Iso.dirPantalla(v[1], v[2]) or e.dir
  return e._dirIso
end

local entidadBase

-- Dibuja una criatura u objeto vivo. Devuelve su altura en píxeles (para la placa).
function D.entidad(e, sx, sy, mundo, jugador)
  local dir0 = e.dir
  e.dir = D.dirVisible(e)
  local alto = entidadBase(e, sx, sy, mundo, jugador)
  e.dir = dir0
  return alto
end

function entidadBase(e, sx, sy, mundo, jugador)
  local pies = sy + 12
  local elevJinete = pies      -- desde dónde salen los efectos de ataque: los pies, o el asiento si va montado
  local alto = 32
  local def = Personajes.de(e)
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.ellipse("fill", sx, pies - 1, def and def.fila and ((def.celda or 64) > 64 and 26 or 20) or (e.montado and 17 or 11), def and def.fila and 7 or (e.montado and 6 or 4))
  -- animación de ataque: la criatura (y su montura) se deforma y se mueve; la sombra se queda en el suelo
  local atq, atqU, atqPose, atqK
  if def and e.kind ~= "caravana" and e.kind ~= "cuerpo" and e.vivo ~= false then
    atq, atqU = estadoAtaque(e)
    if atq and not def.anim and not def.fao then
      atqK = math.max(1, math.min(2.4, def.fila and ((def.celda or 64) / 40) or (def.escala or 1)))
      atqPose = poseAtaque(atq, atqU, atqK)
      love.graphics.push()
      love.graphics.translate(sx + atqPose.dx, pies + atqPose.dy)
      love.graphics.rotate(atqPose.rot)
      love.graphics.scale(atqPose.esx, atqPose.esy)
      love.graphics.translate(-sx, -pies)
    end
  end
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
  elseif def and def.anim and (e.kind == "monstruo" or e.kind == "npc" or e.kind == "guardia") then
    -- criatura con animación por cuadros: ataque, daño, carrera o espera
    local ahora = (mundo and mundo.tiempo) or 0
    local tinte = nil
    local estado, u = "wait", 0
    local restante = (e.flashHasta or 0) - ahora
    if atq then
      estado, u = "att", atqU
    elseif (e.flash or 0) > 0 or restante > 0 then
      estado, u = "hurt", math.max(0, math.min(0.99, 1 - (restante > 0 and restante or 0.1) / 0.35))
      tinte = { 1, 0.78, 0.78 }
    elseif e.mov or (math.abs(e.velx or 0) + math.abs(e.vely or 0) > 0.08) then
      estado = "run"
    end
    alto = MobAnim.dibujar(def.anim, estado, u, sx, pies, e.dir or 1, tinte, (tonumber(e.id and tostring(e.id):match("%d+")) or 0) % 7 * 0.13, e)
  elseif def then
    def = Personajes.jineteDe(e, def)
    local reloj = (e.anim or 0) / 8
    local rojo = (e.flash or 0) > 0 or (e.flashHasta or 0) > ((mundo and mundo.tiempo) or 0)
    local anda = e.mov or (math.abs(e.velx or 0) + math.abs(e.vely or 0) > 0.08)
    local piesJinete = pies
    local montaFrente
    local jineteSentado      -- montura de FAO bajo un personaje por capas: se dibuja al jinete sentado en su asiento
    if def.fao then def.fao._faoAtq = atq and { st = atq, u = atqU } or nil end   -- (antes de la montura: ella también se gira hacia el objetivo)

    if e.montado then
      -- la montura va debajo y el jinete algo más arriba
      local m = Personajes.monturaDe(e.montado, e.faccion)
      if m and m.vehiculo then
        local img = Arte.img("Characters/Vehicle.png")
        local fila = ({ [1] = 0, [4] = 1, [3] = 2, [2] = 3 })[e.dir or 1] or 0
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, Arte.quad(img, 128, 128 + fila * 32, 32, 32), sx, pies, 0, 1.25, 1.25, 16, 28)
        piesJinete = pies - 14
      elseif m and def.fao and m.anim and require("src.presentacion.render.fao").tieneMontado() then
        -- personaje por capas sobre una montura de FAO: la montura va debajo y el jinete sentado encima, en el asiento de ese cuadro
        -- (si la montura no tuviera datos de asiento, más abajo se dibuja el jinete de pie, a la altura de siempre)
        Personajes.dibujar(m, e.dir or 1, anda, reloj, sx, pies, nil, nil, e)
        piesJinete = pies - (m.altura or 10)
        jineteSentado = m
      elseif m then
        if (e.dir or 1) == 1 then
          -- de frente la cabeza de la montura queda delante del jinete: se pinta el jinete antes
          -- (algo mas alto) y la montura encima, asi no le tapa la cara
          montaFrente = m
          piesJinete = pies - (m.altura or 10) - (m.extraFrente or 8)
        else
          Personajes.dibujar(m, e.dir or 1, anda, reloj, sx, pies, nil, nil, e)
          piesJinete = pies - (m.altura or 10)
        end
      end
    end
    elevJinete = piesJinete
    -- quien lleva cristales enemigos: halo del color del cristal y los cristales flotando sobre su cabeza
    if (e.llevaCristales or 0) > 0 and (e.kind == "jugador" or e.kind == "bot") then
      local fac = e.faccion == "albor" and "umbra" or "albor"
      local col = fac == "umbra" and { 0.7, 0.4, 1 } or { 1, 0.85, 0.3 }
      local reloj = love.timer.getTime()
      local pulso = 0.5 + 0.5 * math.sin(reloj * 5)
      love.graphics.setColor(col[1], col[2], col[3], 0.22 + 0.2 * pulso)
      love.graphics.ellipse("fill", sx, pies - 1, 22, 9)
      love.graphics.setColor(col[1], col[2], col[3], 0.9)
      love.graphics.ellipse("line", sx, pies - 1, 22 + 2 * pulso, 9 + pulso)
      local n = math.min(e.llevaCristales, 5)
      for i = 1, n do
        local ang = reloj * 2 + (i - 1) * (math.pi * 2 / n)
        love.graphics.push()
        love.graphics.translate(sx + math.cos(ang) * 13, piesJinete - 30 + math.sin(ang) * 4)
        love.graphics.scale(0.42, 0.42)
        Objetos.cristal(fac, math.sin(reloj * 4 + i) > 0, 0, 0)
        love.graphics.pop()
      end
    end
    -- quien lleva el estandarte enemigo: halo del color de esa bandera en el suelo y la bandera a la espalda
    local llevaEst = e.llevaBandera and (e.kind == "jugador" or e.kind == "bot") and e.llevaBandera or nil
    if llevaEst then
      local col = llevaEst == "umbra" and { 0.7, 0.4, 1 } or { 1, 0.85, 0.3 }
      local pulso = 0.5 + 0.5 * math.sin(love.timer.getTime() * 5)
      love.graphics.setColor(col[1], col[2], col[3], 0.22 + 0.2 * pulso)
      love.graphics.ellipse("fill", sx, pies - 1, 22, 9)
      love.graphics.setColor(col[1], col[2], col[3], 0.9)
      love.graphics.ellipse("line", sx, pies - 1, 22 + 2 * pulso, 9 + pulso)
      if (e.dir or 1) ~= 1 then Objetos.dibujar(llevaEst == "umbra" and "bandera_umbra" or "bandera_albor", 0, sx + 10, piesJinete + 4) end
    end
    -- montado, la que camina es la montura: el jinete va quieto (sin mover los pies)
    if jineteSentado then
      -- El jinete va sobre su montura, en el asiento original de FAO (origen común con la altura de setting/chardef.xml, ver herramientas/generar_mobs/monturas.py)
      local tint = rojo and { 1, 0.6, 0.6 } or nil
      if require("src.presentacion.render.fao").dibujarMontado(def.fao, jineteSentado.anim, sx, pies, tint) then
        alto = 36
        -- Montura de frente (solo de cara; de tres cuartos el jinete va sobre el lomo y no hay que taparle nada): su cabeza y su pecho quedan DELANTE del jinete. Se repinta la montura (el mismo
        -- cuadro) solo por debajo del pecho del jinete: la cabeza y el pecho de la montura tapan su cintura y sus piernas, y el torso, la
        -- cara y el arma siguen viéndose por encima.
        local _, sdy, _, _, hojaM = require("src.presentacion.render.mob_anim").asiento(jineteSentado.anim, e.dir)
        if sdy and hojaM == 0 then
          Personajes.dibujar(jineteSentado, e.dir or 1, anda, reloj, sx, pies, nil, nil, e, true, pies + sdy - 30)
        end
      else
        alto = Personajes.dibujar(def, e.dir or 1, anda and not e.montado, reloj, sx, piesJinete, tint)
      end
    else
      alto = Personajes.dibujar(def, e.dir or 1, anda and not e.montado, reloj, sx, piesJinete, rojo and { 1, 0.6, 0.6 } or nil)
    end
    if montaFrente then Personajes.dibujar(montaFrente, 1, anda, reloj, sx, pies) end
    if llevaEst and (e.dir or 1) == 1 then Objetos.dibujar(llevaEst == "umbra" and "bandera_umbra" or "bandera_albor", 0, sx + 12, piesJinete + 4) end
    if e.montado then
      alto = alto + math.max(10, pies - piesJinete)
    end
  elseif e.kind == "portal" then
    -- portal a un mapa de FAO: dos anillos de luz que giran sobre el suelo y un haz que sube
    local t = (mundo.tiempo or 0)
    local aplastado = Iso.activo() and 0.5 or 1
    love.graphics.setBlendMode("add")
    for k = 0, 2 do
      local u = (t * 0.6 + k / 3) % 1
      love.graphics.setColor(0.4, 0.7, 1, (1 - u) * 0.9)
      love.graphics.setLineWidth(3)
      love.graphics.ellipse("line", sx, pies - 2, (10 + 26 * u) , (10 + 26 * u) * aplastado)
    end
    love.graphics.setColor(0.35, 0.6, 1, 0.35 + 0.15 * math.sin(t * 3))
    love.graphics.ellipse("fill", sx, pies - 2, 16, 16 * aplastado)
    for k = 1, 8 do
      local ph = (t * 0.9 + k * 0.125) % 1
      local a = k * 0.785 + t * 1.5
      love.graphics.setColor(0.7, 0.9, 1, (1 - ph) * 0.9)
      love.graphics.circle("fill", sx + math.cos(a) * 14 * (1 - ph * 0.5), pies - 2 - ph * 46, 2.2)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setBlendMode("alpha")
    alto = 54
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
  if atq and atqPose then
    love.graphics.pop()
    efectoAtaque(e, atq, atqU, sx + atqPose.dx * 0.6, elevJinete, atqK, def)
  elseif atq then
    -- criaturas con animación por cuadros: sin deformación, solo el efecto del golpe
    efectoAtaque(e, atq, atqU, sx, elevJinete, 1, def)
  end
  -- PNJ de misiones: "!" si tiene algo nuevo para ti y "?" si puedes entregarle algo
  if e.kind == "npc" and e.qid and jugador then
    local m = D.marcaNpc(jugador, e.qid)
    if m then
      local t = love.timer.getTime()
      local ym = pies - alto - 16 - 2 * math.abs(math.sin(t * 4))
      love.graphics.setColor(0, 0, 0, 0.55)
      love.graphics.circle("fill", sx, ym + 5, 9)
      love.graphics.setColor(m == "?" and 0.55 or 1, m == "?" and 0.95 or 0.85, m == "?" and 0.55 or 0.2, 1)
      local f = love.graphics.getFont()
      love.graphics.print(m, sx - f:getWidth(m) / 2, ym - f:getHeight() / 2 + 5)
    end
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
