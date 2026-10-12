local Datos = require("compartido.dominio.datos")
local Atlas = require("src.presentacion.render.atlas")
local Balance = require("compartido.dominio.balance")
local Arbol = require("compartido.dominio.arbol")
local Estados = require("compartido.dominio.estados")
local Encanto = require("compartido.dominio.encanto")
local Mascotas = require("compartido.dominio.mascotas")
local Monturas = require("compartido.dominio.monturas")
local Subastas = require("compartido.dominio.subastas")
local Ajustes = require("src.presentacion.ajustes")
local Personajes = require("src.presentacion.render.personajes")
local Objetos = require("src.presentacion.render.objetos")
local Arte = require("src.presentacion.render.arte")
local Dibujo = require("src.presentacion.render.dibujo")
local Efectos = require("src.presentacion.render.efectos")
local Config = require("src.infraestructura.config")

local I = { datosPanel = {}, rects = {}, foco = nil, texto = "", panel = nil, sel = 1, scroll = 0, aviso = "", canal = "todo", escala = 1 }

function I.iniciar(fuente, fuenteG)
  I.fuente = fuente
  I.grande = fuenteG
end

function I.limpiar()
  I.rects = {}
end

function I.registrar(x, y, w, h, id)
  I.rects[#I.rects + 1] = { x = x, y = y, w = w, h = h, id = id }
end

function I.consumir(mx, my)
  local s = I.escala or 1
  mx, my = mx / s, my / s
  for i = #I.rects, 1, -1 do
    local r = I.rects[i]
    if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
      return r.id or "panel"
    end
  end
end

local function caja(x, y, w, h, titulo)
  love.graphics.setColor(0.08, 0.07, 0.1, 0.94)
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)
  love.graphics.setColor(0.85, 0.72, 0.35, 1)
  love.graphics.rectangle("line", x, y, w, h, 6, 6)
  if titulo then
    love.graphics.setColor(0.95, 0.9, 0.75)
    love.graphics.print(titulo, x + 12, y + 8)
  end
  I.registrar(x, y, w, h, "panel")
end

function I.boton(x, y, w, h, texto, id, activo)
  local s = I.escala or 1
  local mx, my = love.mouse.getPosition()
  mx, my = mx / s, my / s
  local hover = mx >= x and mx <= x + w and my >= y and my <= y + h
  if activo == false then
    love.graphics.setColor(0.2, 0.2, 0.22, 0.9)
  elseif hover then
    love.graphics.setColor(0.45, 0.32, 0.12, 1)
  else
    love.graphics.setColor(0.22, 0.16, 0.1, 1)
  end
  love.graphics.rectangle("fill", x, y, w, h, 4, 4)
  love.graphics.setColor(0.9, 0.78, 0.4)
  love.graphics.rectangle("line", x, y, w, h, 4, 4)
  love.graphics.setColor(0.95, 0.92, 0.84)
  love.graphics.printf(texto, x, y + h / 2 - 8, w, "center")
  if activo ~= false then I.registrar(x, y, w, h, id) end
end

-- Retrato de un oficio: (x, y) son los pies; zoom 1 equivale a un personaje de 32 px por 2,4.
function I.persona(claseId, x, y, zoom, faccion)
  local c = Personajes.clases[claseId or "guerrero"] or Personajes.clases.guerrero
  local def = c[faccion or "albor"] or c.albor
  local s = (zoom or 1) * 2.4
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(s, s)
  Personajes.dibujar(def, 1, false, 0, 0, 0)
  love.graphics.pop()
end

-- Ilustración de fondo (Titles1/Titles2) ajustada a la ventana, con velo oscuro.
function I.fondo(ruta, w, h, velo)
  local img = Arte.img(ruta, true)
  local iw, ih = img:getDimensions()
  local k = math.max(w / iw, h / ih)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(img, (w - iw * k) / 2, (h - ih * k) / 2, 0, k, k)
  love.graphics.setColor(0.02, 0.02, 0.05, velo or 0.3)
  love.graphics.rectangle("fill", 0, 0, w, h)
end

function I.menu(hayPartida, w, h)
  I.limpiar()
  I.fondo("Titles1/Castle.png", w, h, 0.3)
  love.graphics.setColor(0, 0, 0, 0.42)
  love.graphics.rectangle("fill", w / 2 - 270, 36, 540, 352, 14, 14)
  I.persona("guerrero", w / 2 - 330, h - 60, 1.7, "albor")
  I.persona("mago", w / 2 + 330, h - 60, 1.7, "umbra")
  love.graphics.setFont(I.grande)
  love.graphics.setColor(0.95, 0.82, 0.35)
  love.graphics.printf("DOS CORONAS", 0, 64, w, "center")
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(0.8, 0.78, 0.7)
  love.graphics.printf("Albor contra Umbra", 0, 118, w, "center")
  love.graphics.setColor(0.9, 0.86, 0.72)
  love.graphics.printf("Para jugar, inicia sesión o crea una cuenta.", 0, 156, w, "center")
  local y = 210
  I.boton(w / 2 - 170, y, 340, 48, "Iniciar sesión", "menu_entrar")
  I.boton(w / 2 - 170, y + 60, 340, 48, "Crear cuenta", "menu_registro")
  I.boton(w / 2 - 170, y + 120, 340, 42, "Salir", "menu_salir")
  love.graphics.setColor(0.7, 0.68, 0.6)
  love.graphics.printf("Los eventos empiezan con 3 jugadores por equipo, una vez al día.", 0, h - 48, w, "center")
  love.graphics.printf("Arte: pack de gráficos new-sprites", 0, h - 28, w, "center")
end

function I.crear(estado, w, h)
  I.limpiar()
  I.fondo("Titles2/Forest.png", w, h, 0.62)
  love.graphics.setFont(I.grande)
  love.graphics.setColor(0.95, 0.86, 0.55)
  love.graphics.printf("Crea tu personaje", 0, 16, w, "center")
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(0.75, 0.72, 0.64)
  love.graphics.printf("1. Facción    2. Oficio    3. Nombre", 0, 52, w, "center")

  local claseVista = estado.clase or "guerrero"
  local facVista = estado.faccion and Datos.facciones[estado.faccion]
  caja(24, 84, 300, 520, "Así se verá")
  if facVista then
    love.graphics.setColor(facVista.color[1], facVista.color[2], facVista.color[3], 0.25)
    love.graphics.rectangle("fill", 48, 160, 252, 220, 8, 8)
  end
  I.persona(claseVista, 174, 360, 2.3, estado.faccion)
  love.graphics.setColor(0.95, 0.9, 0.75)
  local nombreVista = (estado.nombre ~= "" and estado.nombre) or "Sin nombre"
  love.graphics.printf(nombreVista, 40, 400, 268, "center")
  if facVista then
    love.graphics.setColor(facVista.color)
    love.graphics.printf(facVista.nombre, 40, 428, 268, "center")
  else
    love.graphics.setColor(0.7, 0.66, 0.58)
    love.graphics.printf("Elige una facción", 40, 428, 268, "center")
  end
  love.graphics.setColor(0.9, 0.84, 0.7)
  love.graphics.printf(Datos.clases[claseVista].nombre, 40, 452, 268, "center")
  if not estado.clase then
    love.graphics.setColor(0.65, 0.62, 0.55)
    love.graphics.printf("El oficio cambia este dibujo.", 40, 490, 268, "center")
  end

  local function tarjetaFaccion(id, x)
    local f = Datos.facciones[id]
    local elegida = estado.faccion == id
    love.graphics.setColor(elegida and 0.16 or 0.08, elegida and 0.13 or 0.07, elegida and 0.08 or 0.1, 0.96)
    love.graphics.rectangle("fill", x, 84, 450, 168, 6, 6)
    love.graphics.setColor(elegida and f.color[1] or 0.7, elegida and f.color[2] or 0.6, elegida and f.color[3] or 0.35, 1)
    love.graphics.rectangle("line", x, 84, 450, 168, 6, 6)
    love.graphics.setColor(f.color[1], f.color[2], f.color[3], 0.2)
    love.graphics.rectangle("fill", x + 16, 118, 120, 110, 6, 6)
    I.persona(claseVista, x + 76, 220, 1.25, id)
    love.graphics.setColor(f.color)
    love.graphics.print(f.nombre, x + 150, 108)
    love.graphics.setColor(0.9, 0.86, 0.75)
    love.graphics.print(f.titulo, x + 150, 130)
    love.graphics.setColor(0.8, 0.78, 0.7)
    love.graphics.printf(f.texto, x + 150, 154, 280, "left")
    I.boton(x + 150, 210, 180, 30, elegida and "Facción elegida" or "Elegir facción", "faccion_" .. id)
  end
  tarjetaFaccion("albor", 348)
  tarjetaFaccion("umbra", 812)

  local clases = { "guerrero", "mago", "cazador", "clerigo" }
  for i, id in ipairs(clases) do
    local c = Datos.clases[id]
    local cx = 348 + (i - 1) * 230
    local elegida = estado.clase == id
    love.graphics.setColor(elegida and 0.16 or 0.08, elegida and 0.12 or 0.07, 0.08, 0.96)
    love.graphics.rectangle("fill", cx, 268, 218, 250, 6, 6)
    love.graphics.setColor(elegida and 0.95 or 0.7, elegida and 0.78 or 0.6, 0.35, 1)
    love.graphics.rectangle("line", cx, 268, 218, 250, 6, 6)
    love.graphics.setColor(0.95, 0.9, 0.75)
    love.graphics.printf(c.nombre, cx, 278, 218, "center")
    I.persona(id, cx + 109, 400, 1.15, estado.faccion)
    love.graphics.setColor(0.75, 0.72, 0.64)
    love.graphics.printf(c.rol, cx + 10, 414, 198, "center")
    I.boton(cx + 16, 472, 186, 30, elegida and "Oficio elegido" or "Elegir", "clase_" .. id)
  end

  caja(348, h - 92, 620, 76, "3. Nombre")
  love.graphics.setColor(0.15, 0.13, 0.1)
  love.graphics.rectangle("fill", 368, h - 58, 280, 32, 4, 4)
  love.graphics.setColor(1, 0.95, 0.8)
  love.graphics.print((estado.nombre or "") .. (I.foco == "nombre" and "_" or ""), 378, h - 52)
  I.registrar(368, h - 58, 280, 32, "foco_nombre")
  if estado.error and estado.error ~= "" then
    love.graphics.setColor(1, 0.45, 0.4)
    love.graphics.print(estado.error, 368, h - 108)
  end
  I.boton(980, h - 70, 200, 40, "Entrar al mundo", "crear_entrar", estado.faccion and estado.clase and estado.nombre ~= "")
  I.boton(24, h - 70, 140, 36, "Volver", "crear_volver")
end

-- Medidas del marco de juego (en píxeles lógicos de la interfaz).
I.LADO = 236
I.CONSOLA = 150

function I.medidas()
  return I.LADO, I.CONSOLA
end

local PANEL_FONDO = { 0.16, 0.14, 0.12 }
local PANEL_BORDE = { 0.42, 0.35, 0.22 }

local function marco(x, y, w, h, hundido)
  love.graphics.setColor(PANEL_FONDO[1], PANEL_FONDO[2], PANEL_FONDO[3], 0.97)
  love.graphics.rectangle("fill", x, y, w, h, 3, 3)
  love.graphics.setColor(hundido and 0.05 or 0.55, hundido and 0.045 or 0.46, hundido and 0.04 or 0.3, 1)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 3, 3)
  love.graphics.setColor(PANEL_BORDE[1], PANEL_BORDE[2], PANEL_BORDE[3], 0.5)
  love.graphics.rectangle("line", x + 2.5, y + 2.5, w - 5, h - 5, 2, 2)
end

local function casilla(x, y, lado)
  love.graphics.setColor(0.07, 0.065, 0.06, 1)
  love.graphics.rectangle("fill", x, y, lado, lado, 2, 2)
  love.graphics.setColor(0.3, 0.26, 0.2, 1)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, lado - 1, lado - 1, 2, 2)
end

local function pequena()
  if not I.chica then
    local ruta = "arte/fuentes/SourceSans3-Regular.ttf"
    if love.filesystem.getInfo(ruta) then I.chica = love.graphics.newFont(ruta, 13)
    else I.chica = love.graphics.newFont(12) end
  end
  return I.chica
end

local function texto(t, x, y, c, fuente)
  love.graphics.setFont(fuente or pequena())
  love.graphics.setColor(0, 0, 0, 0.8)
  love.graphics.print(t, x + 1, y + 1)
  love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)
  love.graphics.print(t, x, y)
end

local function barra(x, y, w, h, frac, r, g, b, etiqueta)
  love.graphics.setColor(0, 0, 0, 0.9)
  love.graphics.rectangle("fill", x, y, w, h, 2, 2)
  love.graphics.setColor(r, g, b, 1)
  if frac > 0.002 then
    love.graphics.rectangle("fill", x + 1, y + 1, math.max(2, (w - 2) * math.min(1, frac)), h - 2, 2, 2)
  end
  love.graphics.setColor(1, 1, 1, 0.12)
  love.graphics.rectangle("fill", x + 1, y + 1, w - 2, (h - 2) / 2)
  if etiqueta then
    local f = pequena()
    love.graphics.setFont(f)
    local tw = f:getWidth(etiqueta)
    texto(etiqueta, x + (w - tw) / 2, y + (h - f:getHeight()) / 2 - 1, { 1, 1, 1 })
  end
end

local function sobre(x, y, w, h)
  local s = I.escala or 1
  local mx, my = love.mouse.getPosition()
  mx, my = mx / s, my / s
  return mx >= x and mx <= x + w and my >= y and my <= y + h
end

-- Nombre de una pieza con su encantamiento: "+3 Espada tosca".
function I.nombreItem(it, enc)
  return ((enc or 0) > 0 and ("+" .. enc .. " ") or "") .. it.nombre
end

local function iconoItem(slot, x, y, lado, enc)
  local it = slot and Datos.item(slot.id)
  if not it then return nil end
  local e = (lado - 4) / 32
  Atlas.dibujar(it.hoja, it.sprite, x + lado / 2, y + lado / 2 + 8 * e, e, 16, 16)
  enc = enc or slot.enc
  if enc and enc > 0 then texto("+" .. enc, x + 2, y + 1, { 0.6, 0.95, 1 }) end
  return it
end

function I.hud(mundo, p, w, h)
  I.limpiar()
  I.pista = nil
  local lado, consola = I.medidas()
  local vw, vh = w - lado, h - consola
  local fac = Datos.facciones[p.faccion]
  local f = pequena()

  -- Marco superior del mundo: zona y gloria
  love.graphics.setFont(I.fuente)
  texto(p.zona or "", vw / 2 - I.fuente:getWidth(p.zona or "") / 2, 10, { 1, 0.95, 0.75 }, I.fuente)
  local gl = "Gloria  Albor " .. (mundo.gloria.albor or 0) .. "   Umbra " .. (mundo.gloria.umbra or 0)
  texto(gl, vw - f:getWidth(gl) - 12, 10, fac.color, f)

  -- Objetivo
  local obj = p.objetivo and mundo.entidades[p.objetivo]
  if obj and obj.vivo and obj.hpMax then
    local bx = vw / 2 - 110
    marco(bx, 34, 220, 38, true)
    texto(obj.nombre .. (obj.nivel and ("  nv " .. obj.nivel) or ""), bx + 10, 38, { 1, 0.9, 0.7 }, f)
    barra(bx + 10, 55, 200, 11, obj.hp / obj.hpMax, Dibujo.colorVida(obj.hp / obj.hpMax))
  end

  -- Barra de poderes (sobre el mundo, abajo en el centro)
  local barraP = Datos.barra[p.clase]
  local lado_c, sep = 46, 4
  local total = 8 * lado_c + 7 * sep
  local bx0 = vw / 2 - total / 2
  local by0 = vh - lado_c - 10
  for i = 1, 6 do
    local hid = barraP[i]
    local rangoH = Arbol.rango(p, hid)
    local conocida = rangoH > 0
    local hdef = Arbol.efectiva(hid, math.max(1, rangoH))
    local x = bx0 + (i - 1) * (lado_c + sep)
    local queda = (p.cds[hid] or 0) - mundo.tiempo
    local nivelOk = conocida
    local manaOk = (p.mp or 0) >= (hdef.mana or 0)
    casilla(x, by0, lado_c)
    love.graphics.setColor(1, 1, 1, (nivelOk and manaOk) and 1 or 0.35)
    Efectos.icono(hid, x + 3, by0 + 3, lado_c - 6)
    if queda > 0 and hdef.cd and hdef.cd > 0 then
      local frac = math.min(1, queda / hdef.cd)
      love.graphics.setColor(0, 0, 0, 0.6)
      love.graphics.rectangle("fill", x + 1, by0 + 1 + (lado_c - 2) * (1 - frac), lado_c - 2, (lado_c - 2) * frac)
      local cuenta = queda < 10 and string.format("%.1f", queda) or tostring(math.ceil(queda))
      texto(cuenta, x + lado_c / 2 - f:getWidth(cuenta) / 2, by0 + lado_c / 2 - 8, { 1, 1, 1 }, f)
    end
    texto(tostring(i), x + 4, by0 + 2, { 1, 0.9, 0.5 }, f)
    if not conocida then
      texto("K", x + 4, by0 + lado_c - 16, { 1, 0.5, 0.4 }, f)
    elseif rangoH > 1 then
      texto(tostring(rangoH), x + lado_c - f:getWidth(tostring(rangoH)) - 3, by0 + lado_c - 16, { 1, 0.85, 0.3 }, f)
    end
    I.registrar(x, by0, lado_c, lado_c, "hab_" .. i)
    if sobre(x, by0, lado_c, lado_c) then
      local rango = ""
      if hdef.coef then
        local magico = hdef.dano == "magico"
        local a, b = Balance.rangoDano(magico and (p.matk or 0) or (p.atk or 0), 0, hdef.coef)
        rango = "Daño " .. (magico and "mágico " or "físico ") .. a .. "-" .. b .. ". "
      end
      I.pista = hdef.nombre .. (conocida and (" (rango " .. rangoH .. ")") or " — sin aprender (K)") ..
        " — " .. (hdef.mana or 0) .. " de maná, " .. string.format("%.1f", hdef.cd or 0) .. " s. " .. rango .. (hdef.desc or "")
    end
  end
  -- botón del árbol de poderes, a la izquierda de la barra; brilla si hay puntos por gastar
  do
    local x = bx0 - lado_c - sep - 6
    local puntos = Arbol.puntos(p)
    casilla(x, by0, lado_c)
    if puntos > 0 and math.floor(love.timer.getTime() * 2) % 2 == 0 then
      love.graphics.setColor(1, 0.85, 0.3, 0.35)
      love.graphics.rectangle("fill", x, by0, lado_c, lado_c, 3, 3)
    end
    love.graphics.setColor(1, 0.9, 0.55, 1)
    love.graphics.printf("K", x, by0 + 4, lado_c, "center")
    love.graphics.setColor(0.85, 0.8, 0.65, 1)
    love.graphics.printf("poderes", x, by0 + 24, lado_c, "center")
    if puntos > 0 then texto("+" .. puntos, x + lado_c - f:getWidth("+" .. puntos) - 3, by0 + 2, { 1, 0.85, 0.3 }, f) end
    I.registrar(x, by0, lado_c, lado_c, "hud_arbol")
    if sobre(x, by0, lado_c, lado_c) then I.pista = "Árbol de poderes (K): " .. puntos .. " punto(s) por gastar." end
  end
  -- estados que sufres, sobre la barra de poderes, con los segundos que quedan
  do
    local lista = {}
    for tipo, resta in pairs(p.estadosResta or {}) do lista[#lista + 1] = { tipo = tipo, resta = resta } end
    table.sort(lista, function(a, b) return a.tipo < b.tipo end)
    for i, s in ipairs(lista) do
      local def = Estados.def[s.tipo]
      local x = bx0 + (i - 1) * 36
      local y = by0 - 38
      love.graphics.setColor(0.08, 0.07, 0.1, 0.9)
      love.graphics.rectangle("fill", x, y, 32, 32, 4, 4)
      local c = def and def.color or { 1, 1, 1 }
      love.graphics.setColor(c[1], c[2], c[3], 1)
      love.graphics.rectangle("line", x, y, 32, 32, 4, 4)
      Efectos.icono(s.tipo, x + 2, y + 2, 28)
      local t = string.format("%d", math.ceil(s.resta))
      texto(t, x + 32 - f:getWidth(t) - 2, y + 17, { 1, 1, 1 }, f)
      if sobre(x, y, 32, 32) then I.pista = (def and def.nombre or s.tipo) .. ": " .. t .. " s" end
    end
  end
  local function pocion(id, slotIdx, etiqueta, cuenta)
    local x = bx0 + (slotIdx - 1) * (lado_c + sep)
    casilla(x, by0, lado_c)
    local it = Datos.item(id)
    local n = 0
    for _, s in ipairs(p.bolsa or {}) do if s.id == id then n = n + (s.cant or 1) end end
    love.graphics.setColor(1, 1, 1, n > 0 and 1 or 0.35)
    if it then Atlas.dibujar(it.hoja, it.sprite, x + lado_c / 2, by0 + lado_c / 2 + 8, 1.2, 16, 16) end
    texto(etiqueta, x + 4, by0 + 2, { 1, 0.9, 0.5 }, f)
    texto(tostring(n), x + lado_c - f:getWidth(tostring(n)) - 4, by0 + lado_c - 16, { 1, 1, 1 }, f)
    I.registrar(x, by0, lado_c, lado_c, cuenta)
    if sobre(x, by0, lado_c, lado_c) and it then I.pista = it.nombre end
  end
  pocion("pocion_vida", 7, "7", "poc_vida")
  pocion("pocion_mana", 8, "8", "poc_mana")

  -- Avisos de guerra (centro arriba)
  if p.colaGuerra and p.modo ~= "batalla" and p.modo ~= "estandarte" then
    local r = mundo:resumenEvento(p.colaGuerra)
    local min = Datos.JUGADORES_EVENTO
    local titulo = mundo:nombreEvento(p.colaGuerra)
    marco(vw / 2 - 230, 78, 460, 28, true)
    love.graphics.setFont(f)
    love.graphics.setColor(0.95, 0.9, 0.7)
    love.graphics.printf(string.format("%s en cola   Albor %d/%d   Umbra %d/%d", titulo, r.cola.albor, min, r.cola.umbra, min), vw / 2 - 224, 84, 448, "center")
  end
  -- oficio, carga, montura y búsqueda
  I.estadoOficio(mundo, p, 8, 8)
  -- invitación a un gremio
  if p.invGremio then
    local bx, by = vw / 2 - 210, 112
    marco(bx, by, 420, 46, true)
    love.graphics.setFont(f)
    love.graphics.setColor(0.95, 0.9, 0.7)
    love.graphics.printf(p.invGremio.de .. " te invita al gremio " .. (p.invGremio.nombre or "") .. ".", bx + 8, by + 4, 404, "center")
    I.boton(bx + 100, by + 22, 90, 22, "Aceptar", "gr_acepta")
    I.boton(bx + 230, by + 22, 90, 22, "Rechazar", "gr_rechaza")
  end
  if p.modo == "batalla" or p.modo == "estandarte" then
    local inst = mundo.instancia[p.modo]
    local titulo = p.modo == "batalla" and "Batalla por cristales" or "Captura el estandarte"
    marco(vw / 2 - 160, 78, 320, 44, true)
    texto(titulo, vw / 2 - f:getWidth(titulo) / 2, 82, { 0.95, 0.9, 0.7 }, f)
    texto("Albor " .. inst.puntos.albor, vw / 2 - 140, 100, Datos.facciones.albor.color, f)
    texto("Umbra " .. inst.puntos.umbra, vw / 2 - 30, 100, Datos.facciones.umbra.color, f)
    texto(math.ceil(inst.duracion - inst.tiempo) .. " s", vw / 2 + 90, 100, { 1, 1, 1 }, f)
  end

  I.consola(mundo, p, 0, vh, vw, consola)
  I.lateral(mundo, p, vw, 0, lado, h)

  if I.panel == "bolsa" then I.panelBolsa(mundo, p, vw, h)
  elseif I.panel == "equipo" then I.panelEquipo(mundo, p, vw, h)
  elseif I.panel == "arbol" then I.panelArbol(mundo, p, vw, h)
  elseif I.panel == "encantar" then I.panelEncantar(mundo, p, vw, h)
  elseif I.panel == "mascotas" then I.panelMascotas(mundo, p, vw, h)
  elseif I.panel == "gremio" then I.panelGremio(mundo, p, vw, h)
  elseif I.panel == "oficios" then I.panelOficios(mundo, p, vw, h)
  elseif I.panel == "mercancias" then I.panelMercancias(mundo, p, vw, h)
  elseif I.panel == "establo" then I.panelEstablo(mundo, p, vw, h)
  elseif I.panel == "subastas" then I.panelSubastas(mundo, p, vw, h)
  elseif I.panel == "mercado" then I.panelMercado(p, vw, h)
  elseif I.panel == "comercio" then I.panelComercio(mundo, p, vw, h)
  elseif I.panel == "guerra" then I.panelGuerra(mundo, p, vw, h)
  elseif I.panel == "vivienda" then I.panelVivienda(mundo, p, vw, h)
  elseif I.panel == "misiones" then I.panelMisiones(mundo, p, vw, h)
  elseif I.panel == "mapa" then I.panelMapa(mundo, p, w, h)
  elseif I.panel == "ayuda" then I.panelAyuda(vw, h)
  elseif I.panel == "casa" then I.panelCasa(p, vw, h)
  elseif I.panel == "menu" then I.panelPausa(vw, h)
  elseif I.panel == "ajustes" then I.panelAjustes(vw, h)
  end
  if I.pista and I.pista ~= "" then
    local s = I.escala or 1
    local mx, my = love.mouse.getPosition()
    mx, my = mx / s + 14, my / s + 14
    local ancho = 260
    local _, lineas = f:getWrap(I.pista, ancho - 16)
    local alto = #lineas * f:getHeight() + 12
    if mx + ancho > w then mx = w - ancho - 4 end
    if my + alto > h then my = h - alto - 4 end
    love.graphics.setColor(0.07, 0.06, 0.05, 0.96)
    love.graphics.rectangle("fill", mx, my, ancho, alto, 4, 4)
    love.graphics.setColor(0.7, 0.58, 0.3)
    love.graphics.rectangle("line", mx + 0.5, my + 0.5, ancho - 1, alto - 1, 4, 4)
    love.graphics.setFont(f)
    love.graphics.setColor(1, 0.95, 0.85)
    love.graphics.printf(I.pista, mx + 8, my + 6, ancho - 16, "left")
  end
  love.graphics.setFont(I.fuente)
end

local COLOR_CANAL = {
  sistema = { 1, 0.85, 0.4 }, mundo = { 1, 0.62, 0.3 }, faccion = { 0.75, 0.6, 1 },
  ["local"] = { 0.95, 0.95, 0.9 }, gremio = { 0.45, 0.95, 0.55 },
}

function I.consola(mundo, p, x, y, w, h)
  local f = pequena()
  love.graphics.setFont(f)
  -- El fondo se registra primero: lo que se registra después (pestañas, entrada
  -- de chat) queda por encima y recibe los clics.
  I.registrar(x, y, w, h, "panel")
  local canales = { { "todo", "Todo" }, { "mundo", "Mundo" }, { "faccion", "Facción" }, { "sistema", "Sistema" }, { "gremio", "Gremio" } }
  for i, c in ipairs(canales) do
    local bx = x + 8 + (i - 1) * 76
    local activo = I.canal == c[1]
    love.graphics.setColor(activo and 0.42 or 0.2, activo and 0.32 or 0.16, activo and 0.14 or 0.1, 0.95)
    love.graphics.rectangle("fill", bx, y + 2, 72, 20, 3, 3)
    love.graphics.setColor(0.8, 0.68, 0.38)
    love.graphics.rectangle("line", bx + 0.5, y + 2.5, 71, 19, 3, 3)
    love.graphics.setColor(1, 0.95, 0.85)
    love.graphics.printf(c[2], bx, y + 4, 72, "center")
    I.registrar(bx, y + 2, 72, 20, "canal_" .. c[1])
  end
  local cy = y + 26
  local ch = h - 26
  love.graphics.setColor(0.06, 0.055, 0.05, 0.9)
  love.graphics.rectangle("fill", x, cy, w, ch)
  love.graphics.setColor(0.4, 0.33, 0.2)
  love.graphics.line(x, cy + 0.5, x + w, cy + 0.5)
  local lineas = {}
  for _, m in ipairs(mundo.mensajes) do
    local ver = m.canal == "sistema" or m.canal == "mundo"
    if m.canal == "faccion" and m.faccion == p.faccion then ver = true end
    if m.canal == "gremio" then ver = true end -- el servidor solo manda los de tu gremio
    if m.canal == "local" and m.modo == p.modo then ver = true end
    if I.canal ~= "todo" and m.canal ~= I.canal then ver = false end
    if ver then lineas[#lineas + 1] = m end
  end
  local entrada = 24
  local areaH = ch - entrada - 6
  local fh = f:getHeight()
  local ly = cy + areaH + 2
  for i = #lineas, 1, -1 do
    local m = lineas[i]
    local c = COLOR_CANAL[m.canal] or COLOR_CANAL["local"]
    local pref = m.canal == "sistema" and "" or (m.de .. ": ")
    local etiqueta = m.canal == "sistema" and "" or ((m.canal == "mundo" and "[Mundo] ") or (m.canal == "faccion" and "[Facción] ") or (m.canal == "gremio" and "[Gremio] ") or "")
    local _, partes = f:getWrap(etiqueta .. pref .. m.texto, w - 16)
    local alto = #partes * fh
    ly = ly - alto
    if ly < cy + 2 then break end
    love.graphics.setColor(c[1], c[2], c[3])
    love.graphics.printf(etiqueta .. pref .. m.texto, x + 8, ly, w - 16, "left")
  end
  local ey = cy + ch - entrada
  love.graphics.setColor(0.12, 0.1, 0.08)
  love.graphics.rectangle("fill", x + 6, ey, w - 12, entrada - 4, 2, 2)
  love.graphics.setColor(0.4, 0.33, 0.2)
  love.graphics.rectangle("line", x + 6.5, ey + 0.5, w - 13, entrada - 5, 2, 2)
  local muestra = I.foco == "chat" and I.texto or "Enter para hablar  ·  /m mundo  ·  /f facción  ·  /g gremio"
  love.graphics.setColor(I.foco == "chat" and 1 or 0.6, I.foco == "chat" and 0.95 or 0.58, I.foco == "chat" and 0.8 or 0.5)
  love.graphics.print(muestra .. (I.foco == "chat" and "_" or ""), x + 12, ey + 2)
  I.registrar(x + 6, ey, w - 12, entrada - 4, "foco_chat")
  love.graphics.setFont(I.fuente)
end

-- Iconos de los PNJ para los mapas: forma y color según lo que hacen.
local ICONO_NPC = {
  mercado = { "circulo", { 1, 0.85, 0.2 }, "Mercader de equipo" },
  comercio = { "cuadrado", { 0.95, 0.55, 0.2 }, "Mercader mayor (mercancías)" },
  heraldo = { "triangulo", { 0.95, 0.3, 0.3 }, "Heraldo (guerra)" },
  mayordomo = { "cuadrado", { 0.85, 0.75, 0.55 }, "Mayordomo (casas)" },
  encargos = { "rombo", { 1, 1, 0.55 }, "Encargos" },
  encantador = { "estrella", { 0.78, 0.45, 1 }, "Maestro de encantos" },
  criador = { "circulo", { 0.4, 0.92, 0.4 }, "Criador de mascotas" },
  gremio = { "cuadrado", { 0.4, 0.62, 1 }, "Escribano del gremio" },
  oficios = { "rombo", { 0.4, 0.92, 0.92 }, "Maestro de oficios" },
  establo = { "triangulo", { 0.72, 0.52, 0.3 }, "Cuadra (monturas)" },
  capitan = { "rombo", { 0.2, 0.85, 0.5 }, "Capitán de cazadores" },
  contacto = { "triangulo", { 0.85, 0.12, 0.2 }, "Contacto de ladrones" },
  subastas = { "estrella", { 1, 0.75, 0.15 }, "Casa de subastas" },
}
I.ICONO_NPC = ICONO_NPC
I.ORDEN_ICONOS = { "mercado", "comercio", "heraldo", "mayordomo", "encargos", "encantador", "criador", "gremio", "oficios", "establo", "capitan", "contacto", "subastas" }

function I.iconoNpc(rol, x, y, r)
  local d = ICONO_NPC[rol]
  if not d then return end
  local forma, c = d[1], d[2]
  love.graphics.setColor(0, 0, 0, 0.85)
  local function figura(modo, k)
    if forma == "circulo" then love.graphics.circle(modo, x, y, r * k)
    elseif forma == "cuadrado" then love.graphics.rectangle(modo, x - r * k, y - r * k, 2 * r * k, 2 * r * k)
    elseif forma == "rombo" then love.graphics.polygon(modo, x, y - r * 1.25 * k, x + r * 1.25 * k, y, x, y + r * 1.25 * k, x - r * 1.25 * k, y)
    elseif forma == "triangulo" then love.graphics.polygon(modo, x, y - r * 1.2 * k, x + r * 1.15 * k, y + r * k, x - r * 1.15 * k, y + r * k)
    else
      local pts = {}
      for i = 0, 9 do
        local ang = -math.pi / 2 + i * math.pi / 5
        local rr = (i % 2 == 0 and 1.35 or 0.6) * r * k
        pts[#pts + 1] = x + math.cos(ang) * rr
        pts[#pts + 1] = y + math.sin(ang) * rr
      end
      love.graphics.polygon(modo, pts)
    end
  end
  figura("fill", 1.35)
  love.graphics.setColor(c[1], c[2], c[3], 1)
  figura("fill", 1)
end

local function minimapaLocal(mundo, p, x, y, lado)
  marco(x - 3, y - 3, lado + 6, lado + 6, true)
  if p.modo ~= "mundo" then
    love.graphics.setColor(0.05, 0.05, 0.06)
    love.graphics.rectangle("fill", x, y, lado, lado)
    texto("sin mapa", x + lado / 2 - 26, y + lado / 2 - 7, { 0.7, 0.68, 0.6 })
    return
  end
  I.cargarMini(mundo)
  local ventana = 96
  local px, py = p.x, p.y
  local x0 = math.max(0, math.min(Datos.MAPA_W - ventana, px - ventana / 2))
  local y0 = math.max(0, math.min(Datos.MAPA_H - ventana, py - ventana / 2))
  local k = lado / ventana
  local s = I.escala or 1
  love.graphics.setScissor(x * s, y * s, lado * s, lado * s)
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(I.mini, -x0 * k + x, -y0 * k + y, 0, k, k)
  for _, c in ipairs(mundo.mapas.mundo.ciudades) do
    local col = Datos.facciones[c.faccion].color
    love.graphics.setColor(col[1], col[2], col[3], 0.35)
    love.graphics.rectangle("line", x + (c.x - x0) * k, y + (c.y - y0) * k, c.w * k, c.h * k)
  end
  -- un icono por cada PNJ (la lista sale del mapa, así se ven aunque estén lejos)
  for _, n in ipairs(mundo.mapas.mundo.npcsMapa or {}) do
    local ex, ey = x + (n.x - x0) * k, y + (n.y - y0) * k
    if ex > x + 2 and ex < x + lado - 2 and ey > y + 2 and ey < y + lado - 2 then I.iconoNpc(n.rol, ex, ey, 2.4) end
  end
  -- caravanas en marcha y ladrones buscados (los oficios los rastrean)
  for _, c in ipairs(p.caravanas or {}) do
    local ex, ey = x + (c.x - x0) * k, y + (c.y - y0) * k
    if ex > x + 2 and ex < x + lado - 2 and ey > y + 2 and ey < y + lado - 2 then
      love.graphics.setColor(0, 0, 0, 0.85)
      love.graphics.rectangle("fill", ex - 3.5, ey - 2.5, 7, 5)
      love.graphics.setColor(0.95, 0.8, 0.4)
      love.graphics.rectangle("fill", ex - 2.5, ey - 1.5, 5, 3)
    end
  end
  for _, b in ipairs(p.buscados or {}) do
    local ex, ey = x + (b.x - x0) * k, y + (b.y - y0) * k
    if ex > x + 2 and ex < x + lado - 2 and ey > y + 2 and ey < y + lado - 2 then
      love.graphics.setColor(0, 0, 0, 0.9)
      love.graphics.circle("fill", ex, ey, 4.2)
      love.graphics.setColor(1, 0.15, 0.15)
      love.graphics.circle("fill", ex, ey, 3)
    end
  end
  for _, e in pairs(mundo.entidades) do
    if e.vivo ~= false and e.modo == "mundo" and e.id ~= p.id and mundo:mismoLugar(p, e) then
      local ex, ey = x + (e.x - x0) * k, y + (e.y - y0) * k
      if ex > x and ex < x + lado and ey > y and ey < y + lado then
        if e.kind == "jugador" or e.kind == "bot" then
          local c = Datos.facciones[e.faccion] and Datos.facciones[e.faccion].color or { 1, 1, 1 }
          love.graphics.setColor(c[1], c[2], c[3])
          love.graphics.rectangle("fill", ex - 1.5, ey - 1.5, 3, 3)
        elseif e.kind == "monstruo" then
          love.graphics.setColor(0.9, 0.25, 0.2)
          love.graphics.rectangle("fill", ex - 1, ey - 1, 2, 2)
        end
      end
    end
  end
  local ex, ey = x + (px - x0) * k, y + (py - y0) * k
  love.graphics.setColor(0, 0, 0)
  love.graphics.rectangle("fill", ex - 3, ey - 3, 6, 6)
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("fill", ex - 2, ey - 2, 4, 4)
  love.graphics.setScissor()
end

function I.lateral(mundo, p, x, y, w, h)
  local f = pequena()
  local fac = Datos.facciones[p.faccion].color
  love.graphics.setColor(0.1, 0.09, 0.08, 1)
  love.graphics.rectangle("fill", x, y, w, h)
  love.graphics.setColor(0.45, 0.37, 0.22)
  love.graphics.rectangle("fill", x, y, 2, h)
  I.registrar(x, y, w, h, "panel")
  local ix = x + 10
  local iw = w - 20
  local cy = 10

  -- Minimapa local
  local lado = 128
  minimapaLocal(mundo, p, ix + (iw - lado) / 2, cy + 3, lado)
  I.registrar(ix + (iw - lado) / 2, cy + 3, lado, lado, "hud_mapa")
  cy = cy + lado + 12

  -- Botones
  local botones = { { "Mapa", "hud_mapa" }, { "Guerra", "hud_guerra" }, { "Trato", "hud_comercio" }, { "Ayuda", "hud_ayuda" }, { "Menú", "hud_menu" } }
  local bw = (iw - 4 * 3) / 5
  for i, b in ipairs(botones) do
    local bx = ix + (i - 1) * (bw + 3)
    local hover = sobre(bx, cy, bw, 22)
    love.graphics.setColor(hover and 0.45 or 0.26, hover and 0.33 or 0.19, hover and 0.14 or 0.11)
    love.graphics.rectangle("fill", bx, cy, bw, 22, 3, 3)
    love.graphics.setColor(0.8, 0.68, 0.38)
    love.graphics.rectangle("line", bx + 0.5, cy + 0.5, bw - 1, 21, 3, 3)
    love.graphics.setFont(f)
    love.graphics.setColor(1, 0.95, 0.85)
    love.graphics.printf(b[1], bx, cy + 3, bw, "center")
    I.registrar(bx, cy, bw, 22, b[2])
  end
  cy = cy + 28

  -- Estado
  marco(ix - 4, cy, iw + 8, 64, true)
  local hp, hpMax = p.hp or 0, math.max(1, p.hpMax or 1)
  local mp, mpMax = p.mp or 0, math.max(1, p.mpMax or 1)
  local fr = hp / hpMax
  barra(ix + 4, cy + 6, iw - 8, 15, fr, Dibujo.colorVida(fr))
  love.graphics.setFont(f)
  texto(string.format("Vida %d / %d", math.floor(hp), hpMax), ix + 8, cy + 7, { 1, 1, 1 })
  barra(ix + 4, cy + 24, iw - 8, 13, mp / mpMax, 0.25, 0.45, 0.92)
  texto(string.format("Maná %d / %d", math.floor(mp), mpMax), ix + 8, cy + 24, { 1, 1, 1 })
  local xpN = p.xpSig or Datos.xpPara(p.nivel)
  barra(ix + 4, cy + 40, iw - 8, 12, (p.xp or 0) / xpN, 0.85, 0.7, 0.2)
  texto(string.format("Nivel %d   exp %d / %d", p.nivel, math.floor(p.xp or 0), xpN), ix + 8, cy + 39, { 1, 1, 1 })
  cy = cy + 70

  -- Equipo (cuadrícula de 3x3) y cifras
  local ec = 40
  local huecos = {
    { "amuleto", 0, 0 }, { "cabeza", 1, 0 }, { "mochila", 2, 0 }, { "arma", 0, 1 }, { "pecho", 1, 1 }, { "escudo", 2, 1 }, { "anillo", 0, 2 }, { "piernas", 1, 2 }, { "pies", 1, 3 },
  }
  marco(ix - 4, cy, iw + 8, ec * 4 + 14, true)
  local gx, gy = ix + 2, cy + 7
  for _, hh in ipairs(huecos) do
    local sx, sy = gx + hh[2] * (ec + 2), gy + hh[3] * (ec + 2)
    casilla(sx, sy, ec)
    local itemId = p.equipo[hh[1]]
    local it = itemId and Datos.item(itemId)
    if it then
      iconoItem({ id = itemId }, sx, sy, ec, p.encantos and p.encantos[hh[1]])
      if sobre(sx, sy, ec, ec) then
        local enc = p.encantos and p.encantos[hh[1]]
        I.pista = I.nombreItem(it, enc) .. " — " .. I.statsTexto(it, enc)
      end
    else
      love.graphics.setColor(0.35, 0.3, 0.24, 0.8)
      love.graphics.setFont(f)
      love.graphics.printf(hh[1] == "mochila" and "bolsa" or hh[1] == "amuleto" and "amul." or hh[1], sx, sy + ec / 2 - 7, ec, "center")
    end
    I.registrar(sx, sy, ec, ec, "equip_" .. hh[1])
  end
  local tx = gx + 3 * (ec + 2) + 4
  love.graphics.setFont(f)
  texto("Oro", tx, gy + 2, { 0.8, 0.75, 0.55 })
  texto(tostring(math.floor(p.oro or 0)), tx, gy + 16, { 1, 0.9, 0.35 })
  -- Ataque y defensa físicos y mágicos. El rango de daño es el del ataque básico del oficio.
  local magico = Datos.clases[p.clase].danoBasico == "magico"
  local dmin, dmax = Balance.rangoDano(magico and (p.matk or 0) or (p.atk or 0), 0, 1)
  local MAG, FIS = { 0.75, 0.65, 1 }, { 1, 0.78, 0.5 }
  texto("Atq " .. math.floor(p.atk or 0), tx, gy + 32, FIS)
  texto("Mág " .. math.floor(p.matk or 0), tx + 44, gy + 32, MAG)
  texto("Def " .. math.floor(p.def or 0), tx, gy + 47, FIS)
  texto("Res " .. math.floor(p.mdef or 0), tx + 44, gy + 47, MAG)
  texto("Daño " .. dmin .. "-" .. dmax, tx, gy + 63, magico and MAG or FIS)
  texto(Datos.clases[p.clase].nombre, tx, gy + 90, fac or { 0.9, 0.9, 0.9 })
  if sobre(tx, gy + 30, 90, 50) then
    I.pista = "Atq: ataque físico. Mág: ataque mágico. Def: defensa física. Res: defensa mágica (resistencia). "
      .. "Los golpes físicos se reducen con Def y los mágicos con Res."
  end
  cy = cy + ec * 4 + 20

  -- Mochila: la guardamos para calcular lo que cabe
  local cols, filas = 6, math.ceil(Datos.BOLSA / 6)
  local bc = 34
  local altoMochila = filas * (bc + 2) + 24
  -- Lista de batalla: ocupa lo que sobra entre el equipo y la mochila
  local altoLista = math.max(70, (love.graphics.getHeight() / (I.escala or 1)) - cy - altoMochila - 14)
  I.listaBatalla(mundo, p, ix - 4, cy, iw + 8, altoLista)
  cy = cy + altoLista + 6

  marco(ix - 4, cy, iw + 8, altoMochila, true)
  local capacidad = Datos.capacidadBolsa(p.equipo)
  local mochila = p.equipo.mochila and Datos.item(p.equipo.mochila)
  texto((mochila and mochila.nombre or "Bolsillos") .. "  " .. #p.bolsa .. "/" .. capacidad, ix + 2, cy + 3, { 0.85, 0.78, 0.6 })
  local bx0 = ix + (iw - (cols * (bc + 2) - 2)) / 2
  local by0 = cy + 20
  for i = 1, Datos.BOLSA do
    local col = (i - 1) % cols
    local fila = math.floor((i - 1) / cols)
    local sx = bx0 + col * (bc + 2)
    local sy = by0 + fila * (bc + 2)
    casilla(sx, sy, bc)
    if i > capacidad then
      -- espacio que aún no da la mochila
      love.graphics.setColor(0, 0, 0, 0.62)
      love.graphics.rectangle("fill", sx, sy, bc, bc)
      if sobre(sx, sy, bc, bc) then I.pista = "Bloqueado: una mochila mayor da más espacios." end
      goto siguiente
    end
    local slot = p.bolsa[i]
    if I.arrastre == i or (I.sel == i and slot) then
      love.graphics.setColor(0.9, 0.75, 0.3, 0.35)
      love.graphics.rectangle("fill", sx, sy, bc, bc)
    end
    if slot then
      local it = iconoItem(slot, sx, sy, bc)
      if slot.cant and slot.cant > 1 then
        texto(tostring(slot.cant), sx + bc - f:getWidth(tostring(slot.cant)) - 2, sy + bc - 15, { 1, 1, 1 })
      end
      if it and sobre(sx, sy, bc, bc) then
        I.pista = I.nombreItem(it, slot.enc) .. (it.nivel and it.nivel > 1 and (" (nv " .. it.nivel .. ")") or "") .. " — " ..
          I.statsTexto(it, slot.enc) .. (it.texto and ("  " .. it.texto) or "")
      end
    end
    I.registrar(sx, sy, bc, bc, "bolsa_" .. i)
    ::siguiente::
  end
  love.graphics.setFont(I.fuente)
end

-- Criaturas cercanas, ordenadas por distancia. Un clic las elige y las ataca.
function I.listaBatalla(mundo, p, x, y, w, h)
  local f = pequena()
  marco(x, y, w, h, true)
  texto("Lista de batalla", x + 8, y + 3, { 0.85, 0.78, 0.6 })
  local lista = {}
  for _, e in pairs(mundo.entidades) do
    if e.vivo ~= false and e.id ~= p.id and mundo:mismoLugar(p, e)
      and (e.kind == "monstruo" or e.kind == "jugador" or e.kind == "bot" or e.kind == "guardia") then
      local d = math.sqrt((e.x - p.x) ^ 2 + (e.y - p.y) ^ 2)
      if d < 11 then lista[#lista + 1] = { e = e, d = d } end
    end
  end
  table.sort(lista, function(a, b) return a.d < b.d end)
  local fila = 26
  local maxFilas = math.floor((h - 24) / fila)
  if #lista == 0 then
    texto("Nadie a la vista", x + 10, y + 26, { 0.55, 0.52, 0.45 })
  end
  for i = 1, math.min(#lista, maxFilas) do
    local e = lista[i].e
    local ry = y + 22 + (i - 1) * fila
    local elegido = p.objetivo == e.id
    love.graphics.setColor(elegido and 0.4 or 0.12, elegido and 0.12 or 0.11, elegido and 0.1 or 0.1, 1)
    love.graphics.rectangle("fill", x + 4, ry, w - 8, fila - 2, 2, 2)
    if elegido then
      love.graphics.setColor(1, 0.3, 0.25)
      love.graphics.rectangle("line", x + 4.5, ry + 0.5, w - 9, fila - 3, 2, 2)
    end
    local def = Personajes.de(e)
    if def then
      love.graphics.push()
      love.graphics.translate(x + 20, ry + fila - 2)
      local esc = def.fila and 0.4 or 0.78
      love.graphics.scale(esc, esc)
      Personajes.dibujar(def, 1, false, 0, 0, 0)
      love.graphics.pop()
    end
    local c = { 1, 0.62, 0.45 }
    if e.kind ~= "monstruo" then c = Datos.facciones[e.faccion] and Datos.facciones[e.faccion].color or { 1, 1, 1 } end
    texto(e.nombre or "", x + 38, ry - 1, c)
    local fr = (e.hp or 1) / math.max(1, e.hpMax or 1)
    local r, g, b = Dibujo.colorVida(fr)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", x + 38, ry + 14, w - 52, 6)
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", x + 39, ry + 15, (w - 54) * math.max(0, math.min(1, fr)), 4)
    I.registrar(x + 4, ry, w - 8, fila - 2, "bl_" .. e.id)
  end
  if #lista > maxFilas then
    texto("+" .. (#lista - maxFilas) .. " más", x + w - 52, y + 3, { 0.7, 0.65, 0.5 })
  end
end

function I.cargarMini(mundo)
  if I.mini then return end
  local mw, mh = Datos.MAPA_W, Datos.MAPA_H
  local datos = love.image.newImageData(mw, mh)
  local mapa = mundo.mapas.mundo
  local colores = {
    hierba = { 0.38, 0.62, 0.28 }, hierba_osc = { 0.26, 0.34, 0.3 },
    bosque = { 0.16, 0.38, 0.18 }, arena = { 0.82, 0.72, 0.46 },
    tierra = { 0.55, 0.4, 0.24 }, camino = { 0.62, 0.55, 0.4 },
    agua = { 0.15, 0.36, 0.7 }, empedrado = { 0.5, 0.5, 0.52 },
    madera = { 0.42, 0.28, 0.14 }, tejado = { 0.7, 0.28, 0.2 },
    adoquin = { 0.4, 0.62, 0.3 }, muralla = { 0.4, 0.4, 0.44 },
    calle = { 0.62, 0.58, 0.46 }, teja = { 0.8, 0.34, 0.2 },
    teja_umbra = { 0.28, 0.36, 0.6 }, fachada = { 0.72, 0.58, 0.5 },
    cicatriz = { 0.38, 0.24, 0.22 }, montana = { 0.45, 0.43, 0.42 }, plaza = { 0.62, 0.62, 0.64 },
  }
  for ty = 0, mh - 1 do
    for tx = 0, mw - 1 do
      local tipo = mapa.suelo[tx] and mapa.suelo[tx][ty] or "agua"
      local c = colores[tipo] or { 0.2, 0.2, 0.2 }
      datos:setPixel(tx, ty, c[1], c[2], c[3], 1)
    end
  end
  I.mini = love.graphics.newImage(datos)
  I.mini:setFilter("nearest", "nearest")
end

function I.minimap() end

local ETIQUETA_PASIVA = {
  hp = "vida", mp = "maná", atk = "ataque", matk = "ataque mágico", def = "defensa", mdef = "resistencia", spd = "velocidad",
}

-- Texto de lo que hace un poder o una pasiva en su rango actual y en el siguiente.
local function efectoNodo(p, n, rango)
  if n.tipo == "pasiva" then
    local partes = {}
    for k, v in pairs(n.por) do
      local cifra = k == "spd" and string.format("+%.2f", v * rango) or string.format("+%d%%", math.floor(v * rango * 100 + 0.5))
      partes[#partes + 1] = cifra .. " " .. ETIQUETA_PASIVA[k]
    end
    table.sort(partes)
    return table.concat(partes, ", ")
  end
  local h = Arbol.efectiva(n.id, math.max(1, rango))
  local partes = {}
  if h.coef then
    local magico = h.dano == "magico"
    local a, b = Balance.rangoDano(magico and (p.matk or 0) or (p.atk or 0), 0, h.coef)
    partes[#partes + 1] = "daño " .. (magico and "mágico " or "") .. a .. "-" .. b
  end
  if h.estado then
    local d = Estados.def[h.estado.tipo]
    partes[#partes + 1] = math.floor(h.estado.prob * 100 + 0.5) .. "% de " .. (d and d.nombre:lower() or h.estado.tipo)
  end
  if h.cura then partes[#partes + 1] = "cura " .. math.floor((h.cura or 0) + (p.nivel or 1) * (h.curaN or 0) + (p.matk or 0) * 0.4) end
  if h.buff then partes[#partes + 1] = "potencia x" .. string.format("%.2f", h.pot) .. ", " .. string.format("%g", h.dur or 0) .. " s" end
  partes[#partes + 1] = string.format("%.1f s de enfriamiento", h.cd)
  partes[#partes + 1] = h.mana .. " de maná"
  return table.concat(partes, ", ")
end

function I.panelArbol(mundo, p, w, h)
  local nodos = Arbol.nodos(p.clase)
  local clase = Datos.clases[p.clase]
  local px, py, pw, ph = w / 2 - 380, h / 2 - 250, 760, 500
  caja(px, py, pw, ph, "Árbol de poderes — " .. (clase and clase.nombre or ""))
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  local puntos = Arbol.puntos(p)
  love.graphics.setColor(puntos > 0 and 1 or 0.7, puntos > 0 and 0.88 or 0.68, puntos > 0 and 0.35 or 0.6)
  love.graphics.print("Puntos disponibles: " .. puntos .. "   (1 por nivel)", px + 12, py + 34)

  local cw, ch, sep = 116, 134, 8
  local x0 = px + (pw - (6 * cw + 5 * sep)) / 2
  local filas = { activa = py + 78, pasiva = py + 78 + ch + 34 }
  love.graphics.setColor(0.85, 0.78, 0.6)
  love.graphics.print("Poderes (barra 1-6)", x0, filas.activa - 20)
  love.graphics.print("Pasivas", x0, filas.pasiva - 20)

  local pos, contadores = {}, { activa = 0, pasiva = 0 }
  for _, n in ipairs(nodos) do
    contadores[n.tipo] = contadores[n.tipo] + 1
    pos[n.id] = { x = x0 + (contadores[n.tipo] - 1) * (cw + sep), y = filas[n.tipo] }
  end
  -- líneas entre un nodo y lo que necesita
  for _, n in ipairs(nodos) do
    if n.requiere then
      local a, b = pos[n.requiere[1]], pos[n.id]
      if a and b then
        local cumple = Arbol.rango(p, n.requiere[1]) >= n.requiere[2]
        love.graphics.setColor(cumple and 0.9 or 0.4, cumple and 0.75 or 0.38, cumple and 0.3 or 0.35, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.line(a.x + cw / 2, a.y + ch / 2, b.x + cw / 2, b.y + ch / 2)
        love.graphics.setLineWidth(1)
      end
    end
  end

  local info
  for _, n in ipairs(nodos) do
    local c = pos[n.id]
    local r = Arbol.rango(p, n.id)
    local motivo = Arbol.motivo(p, n.id)
    local puede = motivo == nil
    local maximo = r >= Arbol.MAX
    love.graphics.setColor(0.13, 0.11, 0.14, 1)
    love.graphics.rectangle("fill", c.x, c.y, cw, ch, 6, 6)
    if puede then love.graphics.setColor(1, 0.85, 0.3, 1)
    elseif maximo then love.graphics.setColor(0.45, 0.8, 0.45, 1)
    elseif r > 0 then love.graphics.setColor(0.75, 0.68, 0.5, 1)
    else love.graphics.setColor(0.35, 0.33, 0.36, 1) end
    love.graphics.rectangle("line", c.x, c.y, cw, ch, 6, 6)
    local opaco = (r > 0 or puede) and 1 or 0.4
    love.graphics.setColor(1, 1, 1, opaco)
    if n.tipo == "activa" then
      Efectos.icono(n.id, c.x + cw / 2 - 24, c.y + 8, 48)
    else
      Atlas.dibujar(n.icono.hoja, n.icono.sprite, c.x + cw / 2, c.y + 32, 1.4, 16, 16)
    end
    love.graphics.setColor(0.95, 0.9, 0.78, opaco)
    love.graphics.printf(Arbol.nombre(n), c.x + 4, c.y + 56, cw - 8, "center")
    -- rangos
    for i = 1, Arbol.MAX do
      love.graphics.setColor(i <= r and 1 or 0.25, i <= r and 0.8 or 0.24, i <= r and 0.25 or 0.22, 1)
      love.graphics.rectangle("fill", c.x + cw / 2 - 45 + (i - 1) * 19, c.y + 98, 16, 8, 2, 2)
    end
    love.graphics.setColor(0.75, 0.72, 0.6, opaco)
    local pie
    if maximo then pie = "Máximo"
    elseif r == 0 and n.requiere and Arbol.rango(p, n.requiere[1]) < n.requiere[2] then
      local previo = Arbol.nodo(p.clase, n.requiere[1])
      pie = "Pide " .. Arbol.nombre(previo) .. " " .. n.requiere[2]
    elseif r == 0 and (p.nivel or 1) < n.nivel then pie = "Nivel " .. n.nivel
    elseif puede then pie = r == 0 and "Clic: aprender" or "Clic: mejorar"
    else pie = "Sin puntos" end
    love.graphics.printf(pie, c.x + 4, c.y + 110, cw - 8, "center")
    if n.tipo == "activa" then
      love.graphics.setColor(1, 0.9, 0.5, opaco)
      love.graphics.print(tostring(n.slot), c.x + 8, c.y + 6)
    end
    I.registrar(c.x, c.y, cw, ch, "arb_" .. n.id)
    if sobre(c.x, c.y, cw, ch) then
      local desc = n.tipo == "activa" and (Datos.habilidades[n.id].desc or "") or (n.desc or "")
      info = { nombre = Arbol.nombre(n), desc = desc, ahora = r > 0 and efectoNodo(p, n, r) or nil,
        sigue = r < Arbol.MAX and efectoNodo(p, n, r + 1) or nil, motivo = motivo, rango = r }
    end
  end

  -- cuadro de información del nodo bajo el ratón
  local iy = py + ph - 108
  love.graphics.setColor(0.1, 0.09, 0.12, 1)
  love.graphics.rectangle("fill", px + 12, iy, pw - 24, 64, 4, 4)
  love.graphics.setColor(0.7, 0.62, 0.35, 1)
  love.graphics.rectangle("line", px + 12, iy, pw - 24, 64, 4, 4)
  if info then
    love.graphics.setColor(1, 0.9, 0.55)
    love.graphics.print(info.nombre .. "  — rango " .. info.rango .. "/" .. Arbol.MAX, px + 20, iy + 4)
    love.graphics.setColor(0.88, 0.85, 0.75)
    love.graphics.printf(info.desc .. (info.ahora and ("  Ahora: " .. info.ahora .. ".") or "") ..
      (info.sigue and ("  Siguiente rango: " .. info.sigue .. ".") or ""), px + 20, iy + 22, pw - 40, "left")
  else
    love.graphics.setColor(0.7, 0.68, 0.6)
    love.graphics.printf("Pasa el ratón por un poder para ver lo que hace. Clic para aprenderlo o subirlo de rango; aprender un poder pide cierto nivel; mejorarlo solo cuesta puntos.", px + 20, iy + 8, pw - 40, "left")
  end
  local coste = mundo:costeReinicio(p)
  I.boton(px + 12, py + ph - 36, 230, 28, "Reiniciar puntos (" .. coste .. " de oro)", "arbol_reset", Arbol.gastados(p) > 0)
end

local NOMBRE_RANGO = { lider = "Líder", oficial = "Oficial", miembro = "Miembro" }
local COLOR_RANGO = { lider = { 1, 0.85, 0.35 }, oficial = { 0.6, 0.85, 1 }, miembro = { 0.85, 0.85, 0.8 } }

function I.panelGremio(mundo, p, w, h)
  local px, py, pw, ph = w / 2 - 340, 60, 680, 520
  caja(px, py, pw, ph, "Gremio")
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  local d = I.datosGremio
  if not d then
    love.graphics.setColor(0.7, 0.68, 0.6)
    love.graphics.print("Consultando...", px + 14, py + 50)
    return
  end
  if d.sin then
    -- sin gremio: formulario para fundar uno
    love.graphics.setColor(0.9, 0.86, 0.72)
    love.graphics.printf("Un gremio reúne a jugadores de tu corona: chat propio (/g), rangos y un 5% más de experiencia por cada compañero cerca (hasta 15%).",
      px + 14, py + 44, pw - 28, "left")
    love.graphics.setColor(0.85, 0.78, 0.6)
    love.graphics.print("Fundar un gremio  (nivel " .. (d.nivel or 8) .. ", " .. (d.coste or 1500) .. " de oro; habla con el escribano de la ciudad)", px + 14, py + 110)
    local function campo(etiqueta, valor, foco, y, ancho)
      love.graphics.setColor(0.8, 0.78, 0.65)
      love.graphics.print(etiqueta, px + 14, y + 6)
      love.graphics.setColor(0.12, 0.1, 0.08)
      love.graphics.rectangle("fill", px + 120, y, ancho, 28, 3, 3)
      love.graphics.setColor(I.foco == foco and 0.95 or 0.5, I.foco == foco and 0.8 or 0.42, I.foco == foco and 0.35 or 0.25)
      love.graphics.rectangle("line", px + 120.5, y + 0.5, ancho - 1, 27, 3, 3)
      love.graphics.setColor(1, 0.95, 0.85)
      love.graphics.print((valor or "") .. (I.foco == foco and "_" or ""), px + 128, y + 6)
      I.registrar(px + 120, y, ancho, 28, "foco_" .. foco)
    end
    campo("Nombre", I.gremioNombre, "gremio_nombre", py + 140, 300)
    campo("Etiqueta", I.gremioTag, "gremio_tag", py + 178, 100)
    I.boton(px + 120, py + 222, 220, 34, "Fundar gremio", "gr_crear")
  else
    love.graphics.setColor(1, 0.9, 0.55)
    love.graphics.print(d.nombre .. "  [" .. d.etiqueta .. "]   " .. #d.miembros .. "/" .. d.max .. " miembros", px + 14, py + 40)
    local yo = p.gremioRango
    local y0 = py + 74
    for i, m in ipairs(d.miembros) do
      local y = y0 + (i - 1) * 30
      if y < py + ph - 100 then
        love.graphics.setColor(0.13, 0.11, 0.14)
        love.graphics.rectangle("fill", px + 14, y, pw - 28, 26, 3, 3)
        love.graphics.setColor(m.conectado and 0.4 or 0.3, m.conectado and 0.9 or 0.3, m.conectado and 0.4 or 0.3)
        love.graphics.circle("fill", px + 28, y + 13, 5)
        love.graphics.setColor(0.95, 0.9, 0.78)
        love.graphics.print(m.nombre .. (m.nivel and ("  nv " .. m.nivel) or ""), px + 42, y + 5)
        local c = COLOR_RANGO[m.rango]
        love.graphics.setColor(c[1], c[2], c[3])
        love.graphics.print(NOMBRE_RANGO[m.rango], px + 260, y + 5)
        local bx = px + pw - 28 - 150
        if yo == "lider" and m.rango ~= "lider" then
          if m.rango == "miembro" then I.boton(bx, y + 1, 70, 24, "Ascender", "gr_sube_" .. m.id)
          else I.boton(bx, y + 1, 70, 24, "Bajar", "gr_baja_" .. m.id) end
        end
        local puedeEchar = (yo == "lider" and m.rango ~= "lider") or (yo == "oficial" and m.rango == "miembro")
        if puedeEchar then I.boton(bx + 76, y + 1, 74, 24, "Expulsar", "gr_exp_" .. m.id) end
      end
    end
    local yb = py + ph - 92
    if yo == "lider" or yo == "oficial" then
      local objetivo = p.objetivo and mundo.entidades[p.objetivo]
      local valido = objetivo and objetivo.kind == "jugador" and not objetivo.gremio
      I.boton(px + 14, yb, 230, 32, valido and ("Invitar a " .. objetivo.nombre) or "Invitar (elige un jugador)", "gr_invitar", valido and true or false)
    end
    I.boton(px + pw - 14 - 120 - 130, yb, 120, 32, "Salir", "gr_salir")
    if yo == "lider" then
      I.boton(px + pw - 14 - 120, yb, 120, 32, I.confirmaDisolver and "¿Seguro?" or "Disolver", "gr_disolver")
    end
    love.graphics.setColor(0.7, 0.68, 0.6)
    love.graphics.printf("Chat del gremio: escribe /g y tu mensaje. Para invitar, elige a un jugador de tu corona (clic) y pulsa Invitar.", px + 14, py + ph - 50, pw - 28, "left")
  end
end

-- ---------------------------------------------------------------------------------------
-- Oficios: comerciante, cazarrecompensas y ladrón
-- ---------------------------------------------------------------------------------------
local NOMBRES_OFICIO = { trader = "Comerciante", hunter = "Cazarrecompensas", thief = "Ladrón" }
local DESC_OFICIO = {
  trader = "Compra mercancías donde sobran y véndelas donde faltan. Cuanto más lejos, más ganas. Con una montura llevas más y vas más rápido.",
  hunter = "Escolta caravanas y caza a los ladrones buscados: cobras una recompensa por cada uno.",
  thief = "Roba mercancías de comerciantes y caravanas fuera de las ciudades (tecla R) y véndelas a un contacto.",
}

-- Franja de estado del oficio en la esquina del mundo.
function I.estadoOficio(mundo, p, x, y)
  if not p.job and not p.buscadoResta and not p.montado then return end
  local f = pequena()
  love.graphics.setFont(f)
  local lineas = {}
  if p.job then
    local o = p.oficios and p.oficios[p.job]
    lineas[#lineas + 1] = { NOMBRES_OFICIO[p.job] .. (o and (" nv " .. o.nivel) or ""), { 0.95, 0.9, 0.7 } }
    if (p.capacidadCarga or 0) > 0 then
      lineas[#lineas + 1] = { "Carga " .. math.floor(p.pesoCarga or 0) .. "/" .. math.floor(p.capacidadCarga or 0), { 0.8, 0.85, 0.7 } }
    end
  end
  if p.montado then
    local M = Monturas.especies[p.montado]
    lineas[#lineas + 1] = { "Montado: " .. (M and M.nombre or p.montado) .. "  (O: bajar)", { 0.75, 0.85, 1 } }
  end
  if p.buscadoResta then
    lineas[#lineas + 1] = { "BUSCADO " .. math.ceil(p.buscadoResta) .. " s — recompensa " .. (p.recompensa or 0), { 1, 0.35, 0.3 } }
  end
  if p.escolta then lineas[#lineas + 1] = { "Escoltando una caravana", { 0.5, 0.95, 0.6 } } end
  local ancho = 0
  for _, l in ipairs(lineas) do ancho = math.max(ancho, f:getWidth(l[1])) end
  marco(x, y, ancho + 16, #lineas * 16 + 8, true)
  for i, l in ipairs(lineas) do texto(l[1], x + 8, y + 4 + (i - 1) * 16, l[2], f) end
  -- barra del robo en curso
  if p.robo then
    local frac = math.max(0, math.min(1, (mundo.tiempo - p.robo.desde) / math.max(0.1, p.robo.hasta - p.robo.desde)))
    barra(x, y + #lineas * 16 + 14, 150, 12, frac, 0.9, 0.7, 0.2)
    texto("Robando...", x + 6, y + #lineas * 16 + 13, { 1, 1, 1 }, f)
  end
end

function I.panelOficios(mundo, p, w, h)
  local px, py, pw, ph = w / 2 - 380, 60, 760, 520
  caja(px, py, pw, ph, "Oficios")
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  local d = I.datosPanel.oficios
  if not d then
    love.graphics.setColor(0.7, 0.68, 0.6)
    love.graphics.print("Consultando...", px + 14, py + 50)
    return
  end
  local permitido = {}
  if d.lugar == "ciudad" then permitido = { trader = true, hunter = true }
  elseif d.lugar == "capitan" then permitido = { hunter = true }
  elseif d.lugar == "ladron" then permitido = { thief = true } end
  love.graphics.setColor(0.8, 0.78, 0.65)
  local aviso = d.lugar == "ciudad" and "Maestro de oficios: aquí se aprende el de comerciante y el de cazarrecompensas."
    or d.lugar == "capitan" and "Capitán de cazadores: aquí se aprende el de cazarrecompensas y se mira el cartel de buscados."
    or d.lugar == "ladron" and "Contacto de ladrones: aquí se aprende el oficio de ladrón y se vende lo robado."
    or "Acércate a un maestro de oficios para cambiar de oficio."
  love.graphics.printf(aviso, px + 14, py + 38, pw - 28, "left")
  local cw, ch = 236, 190
  for i, id in ipairs({ "trader", "hunter", "thief" }) do
    local x = px + 14 + (i - 1) * (cw + 12)
    local y = py + 78
    local actual = d.job == id
    love.graphics.setColor(0.13, 0.11, 0.14)
    love.graphics.rectangle("fill", x, y, cw, ch, 6, 6)
    love.graphics.setColor(actual and 0.95 or 0.5, actual and 0.8 or 0.42, actual and 0.3 or 0.25)
    love.graphics.rectangle("line", x, y, cw, ch, 6, 6)
    love.graphics.setColor(1, 0.9, 0.55)
    love.graphics.print(NOMBRES_OFICIO[id] .. (actual and "  (actual)" or ""), x + 10, y + 8)
    love.graphics.setColor(0.82, 0.8, 0.7)
    love.graphics.printf(DESC_OFICIO[id], x + 10, y + 32, cw - 20, "left")
    local o = d.oficios[id]
    if o then
      love.graphics.setColor(0.7, 0.9, 0.9)
      love.graphics.print("Nivel " .. o.nivel .. "   " .. o.xp .. "/" .. o.sig .. " xp", x + 10, y + 128)
      love.graphics.setColor(0, 0, 0, 0.7)
      love.graphics.rectangle("fill", x + 10, y + 148, cw - 20, 8)
      love.graphics.setColor(0.35, 0.8, 0.85)
      love.graphics.rectangle("fill", x + 10, y + 148, (cw - 20) * math.min(1, o.xp / math.max(1, o.sig)), 8)
    end
    I.boton(x + 10, y + ch - 32, cw - 20, 26, actual and "En ejercicio" or (o and "Volver a este oficio" or "Aprender"), "of_elegir_" .. id,
      (not actual) and permitido[id] and true or false)
  end
  love.graphics.setColor(0.7, 0.68, 0.6)
  love.graphics.printf("Cambiar de oficio cuesta " .. (d.coste or 300) .. " de oro (el primero es gratis). Debes dejar tu carga y no estar buscado. Cada oficio conserva su nivel.",
    px + 14, py + 280, pw - 28, "left")
  local y2 = py + 322
  if d.buscado then
    love.graphics.setColor(1, 0.4, 0.35)
    love.graphics.print("Te buscan durante " .. math.ceil(d.buscado.resta) .. " s. Recompensa por tu cabeza: " .. d.buscado.recompensa .. ".", px + 14, y2)
    y2 = y2 + 22
  end
  if d.lugar == "ladron" then
    love.graphics.setColor(0.9, 0.85, 0.7)
    local total = 0
    for _, c in pairs(d.robado or {}) do total = total + c end
    love.graphics.print("Mercancía robada: " .. total .. " unidades (" .. (d.valorRobado or 0) .. " de oro).", px + 14, y2)
    I.boton(px + 14, y2 + 24, 240, 30, "Vender lo robado", "perista_vender", total > 0)
  elseif d.lugar == "capitan" then
    love.graphics.setColor(0.85, 0.78, 0.6)
    love.graphics.print("Cartel de buscados", px + 14, y2)
    local lista = d.buscados or {}
    if #lista == 0 then
      love.graphics.setColor(0.7, 0.68, 0.6)
      love.graphics.print("Nadie por ahora.", px + 14, y2 + 20)
    end
    for i, b in ipairs(lista) do
      if i > 4 then break end
      love.graphics.setColor(1, 0.55, 0.5)
      love.graphics.print(b.nombre .. "  — recompensa " .. b.recompensa .. "  (cerca de " .. b.x .. ", " .. b.y .. ")", px + 14, y2 + 20 + (i - 1) * 18)
    end
    love.graphics.setColor(0.7, 0.68, 0.6)
    love.graphics.printf("Para escoltar una caravana, acércate a ella y pulsa E. Mantente cerca hasta que llegue.", px + 14, y2 + 100, pw - 28, "left")
  end
end

local ETIQUETA_BIEN = { sobra = { "sobra", { 0.45, 0.9, 0.5 } }, falta = { "falta", { 1, 0.7, 0.35 } } }

function I.panelMercancias(mundo, p, w, h)
  local px, py, pw, ph = w / 2 - 380, 60, 760, 520
  caja(px, py, pw, ph, "Mercader mayor")
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  local d = I.datosPanel.mercancias
  if not d then
    love.graphics.setColor(0.7, 0.68, 0.6)
    love.graphics.print("Consultando...", px + 14, py + 50)
    return
  end
  if d.lejos then
    love.graphics.setColor(0.8, 0.78, 0.65)
    love.graphics.print("Acércate a un mercader mayor.", px + 14, py + 50)
    return
  end
  love.graphics.setColor(1, 0.9, 0.55)
  love.graphics.print(d.sitio .. "   —   Oro: " .. math.floor(p.oro or 0), px + 14, py + 38)
  local esComerciante = d.job == "trader"
  love.graphics.setColor(esComerciante and 0.85 or 1, esComerciante and 0.85 or 0.6, esComerciante and 0.8 or 0.4)
  love.graphics.print(esComerciante and ("Carga " .. math.floor(d.peso) .. "/" .. math.floor(d.capacidad)) or "Solo los comerciantes compran y venden mercancías.", px + 14, py + 60)
  for _, c in ipairs({ { "Mercancía", 24 }, { "Compra", 240 }, { "Venta", 320 }, { "Llevas", 400 } }) do
    love.graphics.setColor(0.7, 0.68, 0.55)
    love.graphics.print(c[1], px + c[2], py + 88)
  end
  for i, b in ipairs(d.bienes) do
    local y = py + 112 + (i - 1) * 42
    love.graphics.setColor(0.13, 0.11, 0.14)
    love.graphics.rectangle("fill", px + 14, y, pw - 28, 38, 4, 4)
    love.graphics.setColor(0.95, 0.9, 0.75)
    love.graphics.print(b.nombre, px + 24, y + 10)
    local et = b.etiqueta and ETIQUETA_BIEN[b.etiqueta]
    if et then
      love.graphics.setColor(et[2][1], et[2][2], et[2][3])
      love.graphics.print(et[1], px + 150, y + 10)
    end
    love.graphics.setColor(1, 0.9, 0.45)
    love.graphics.print(tostring(b.compra), px + 240, y + 10)
    love.graphics.setColor(0.6, 0.9, 1)
    love.graphics.print(tostring(b.venta), px + 320, y + 10)
    love.graphics.setColor(0.9, 0.9, 0.85)
    love.graphics.print(tostring(b.tengo), px + 400, y + 10)
    I.boton(px + 440, y + 6, 74, 26, "Comprar 1", "mc_c1_" .. b.id, esComerciante)
    I.boton(px + 518, y + 6, 40, 26, "x5", "mc_c5_" .. b.id, esComerciante)
    I.boton(px + 562, y + 6, 74, 26, "Vender 1", "mc_v1_" .. b.id, esComerciante and b.tengo > 0)
    I.boton(px + 640, y + 6, 100, 26, "Vender todo", "mc_vt_" .. b.id, esComerciante and b.tengo > 0)
  end
  love.graphics.setColor(0.7, 0.68, 0.6)
  love.graphics.printf("Compra donde la mercancía SOBRA y vende donde FALTA, cuanto más lejos mejor. Los precios suben cuando compras y bajan cuando vendes, y se recuperan con el tiempo. Los ladrones acechan los caminos: viaja con escolta.",
    px + 14, py + ph - 70, pw - 28, "left")
end

function I.panelEstablo(mundo, p, w, h)
  local px, py, pw, ph = w / 2 - 340, 70, 680, 480
  caja(px, py, pw, ph, "Cuadra")
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  local d = I.datosPanel.establo
  if not d then
    love.graphics.setColor(0.7, 0.68, 0.6)
    love.graphics.print("Consultando...", px + 14, py + 50)
    return
  end
  love.graphics.setColor(0.85, 0.82, 0.7)
  love.graphics.print("Oro: " .. math.floor(p.oro or 0) .. (d.montado and "   (vas montado: tecla O para bajar)" or ""), px + 14, py + 38)
  for i, m in ipairs(d.catalogo) do
    local y = py + 70 + (i - 1) * 100
    love.graphics.setColor(0.13, 0.11, 0.14)
    love.graphics.rectangle("fill", px + 14, y, pw - 28, 90, 6, 6)
    local def = Personajes.monturas[m.id]
    if def and def.hoja then Personajes.dibujar(def, 1, false, love.timer.getTime(), px + 54, y + 70) end
    if def and def.vehiculo then
      local img = Arte.img("Characters/Vehicle.png")
      love.graphics.setColor(1, 1, 1)
      love.graphics.draw(img, Arte.quad(img, 128, 128, 32, 32), px + 54, y + 70, 0, 1.6, 1.6, 16, 28)
    end
    local nivelOk = (p.nivel or 1) >= m.nivel
    love.graphics.setColor(nivelOk and 0.95 or 0.6, nivelOk and 0.9 or 0.58, nivelOk and 0.75 or 0.52)
    love.graphics.print(m.nombre .. "   " .. m.precio .. " oro  (nv " .. m.nivel .. ")", px + 100, y + 8)
    love.graphics.setColor(0.72, 0.78, 0.68)
    love.graphics.printf(m.desc, px + 100, y + 30, 340, "left")
    love.graphics.setColor(0.6, 0.85, 1)
    love.graphics.print("Velocidad +" .. math.floor(m.vel * 100) .. "%    Carga +" .. m.carga, px + 100, y + 70)
    local montadoAqui = d.montado == m.id
    if m.tengo then
      I.boton(px + pw - 28 - 150, y + 28, 150, 32, montadoAqui and "Bajar" or "Montar", "mt_alt_" .. m.id)
    else
      I.boton(px + pw - 28 - 150, y + 28, 150, 32, "Comprar", "mt_buy_" .. m.id, d.cerca and nivelOk and true or false)
    end
  end
  love.graphics.setColor(0.7, 0.68, 0.6)
  love.graphics.printf("Se compran en las cuadras. Pulsa O para montar o bajar de la última que usaste. Las monturas se bajan solas en las casas y en las guerras. Ir cargado te frena, salvo con montura.",
    px + 14, py + ph - 58, pw - 28, "left")
end

-- ---------------------------------------------------------------------------------------
-- Casa de subastas
-- ---------------------------------------------------------------------------------------
local function tiempoRestante(s)
  s = math.floor(s)
  if s >= 3600 then return string.format("%d h %02d m", math.floor(s / 3600), math.floor((s % 3600) / 60)) end
  if s >= 60 then return string.format("%d min", math.floor(s / 60)) end
  return s .. " s"
end

local function numero(c)
  return tonumber(c) and math.floor(tonumber(c)) or nil
end

function I.panelSubastas(mundo, p, w, h)
  local px, py, pw, ph = w / 2 - 390, 50, 780, 540
  caja(px, py, pw, ph, "Casa de subastas")
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  local d = I.datosPanel.subastas
  I.subCat = I.subCat or "todo"
  I.subCampos = I.subCampos or { oferta = "", cant = "1", salida = "", compra = "" }
  I.subHoras = I.subHoras or 12
  if not d then
    love.graphics.setColor(0.7, 0.68, 0.6)
    love.graphics.print("Consultando...", px + 14, py + 50)
    return
  end
  love.graphics.setColor(0.9, 0.82, 0.5)
  love.graphics.print("Oro: " .. math.floor(p.oro or 0) .. (d.cerca and "" or "     (acércate al subastador para operar)"), px + 150, py + 12)
  -- pestañas
  local pestanas = {}
  for _, c in ipairs(Subastas.ORDEN_CATEGORIAS) do pestanas[#pestanas + 1] = { c, Subastas.CATEGORIAS[c].nombre } end
  pestanas[#pestanas + 1] = { "vender", "Vender" }
  pestanas[#pestanas + 1] = { "mias", "Mis subastas (" .. #d.mias .. ")" }
  pestanas[#pestanas + 1] = { "buzon", "Buzón (" .. #d.buzon .. ")" }
  local x = px + 12
  for _, t in ipairs(pestanas) do
    local ancho = love.graphics.getFont():getWidth(t[2]) + 20
    local activa = I.subCat == t[1]
    love.graphics.setColor(activa and 0.42 or 0.2, activa and 0.32 or 0.16, activa and 0.14 or 0.1, 0.95)
    love.graphics.rectangle("fill", x, py + 44, ancho, 24, 3, 3)
    love.graphics.setColor(0.8, 0.68, 0.38)
    love.graphics.rectangle("line", x + 0.5, py + 44.5, ancho - 1, 23, 3, 3)
    love.graphics.setColor(1, 0.95, 0.85)
    love.graphics.print(t[2], x + 10, py + 48)
    I.registrar(x, py + 44, ancho, 24, "sb_tab_" .. t[1])
    x = x + ancho + 4
  end
  local y0 = py + 80

  -- una fila de objeto con su icono y nombre
  local function filaObjeto(item, cant, enc, x1, y1)
    local it = Datos.item(item)
    if it then Atlas.dibujar(it.hoja, it.sprite, x1 + 18, y1 + 20, 1, 16, 16) end
    if enc and enc > 0 then texto("+" .. enc, x1 + 2, y1 + 2, { 0.6, 0.95, 1 }) end
    love.graphics.setColor(0.95, 0.9, 0.75)
    love.graphics.print((it and it.nombre or item) .. (cant > 1 and ("  x" .. cant) or ""), x1 + 42, y1 + 4)
    if it and sobre(x1, y1, 40, 40) then I.pista = I.nombreItem(it, enc) .. " — " .. I.statsTexto(it, enc) end
    return it
  end

  if I.subCat == "vender" then
    love.graphics.setColor(0.85, 0.8, 0.65)
    love.graphics.print("1. Elige el objeto de tu bolsa", px + 14, y0)
    local cols, lado = 8, 40
    for i = 1, Datos.capacidadBolsa(p.equipo) do
      local col, fila = (i - 1) % cols, math.floor((i - 1) / cols)
      local sx, sy = px + 14 + col * (lado + 4), y0 + 24 + fila * (lado + 4)
      casilla(sx, sy, lado)
      local slot = p.bolsa[i]
      if I.subIdx == i then
        love.graphics.setColor(0.9, 0.75, 0.3, 0.4)
        love.graphics.rectangle("fill", sx, sy, lado, lado)
      end
      if slot then
        iconoItem(slot, sx, sy, lado)
        if slot.cant and slot.cant > 1 then texto(tostring(slot.cant), sx + lado - 14, sy + lado - 14, { 1, 1, 1 }) end
        local it = Datos.item(slot.id)
        if it and sobre(sx, sy, lado, lado) then I.pista = I.nombreItem(it, slot.enc) .. " — " .. I.statsTexto(it, slot.enc) end
        I.registrar(sx, sy, lado, lado, "sb_item_" .. i)
      end
    end
    local fx = px + 14 + 8 * 44 + 20
    local function campo(etiqueta, clave, y1, ancho)
      love.graphics.setColor(0.8, 0.78, 0.65)
      love.graphics.print(etiqueta, fx, y1 + 6)
      love.graphics.setColor(0.12, 0.1, 0.08)
      love.graphics.rectangle("fill", fx + 130, y1, ancho, 28, 3, 3)
      local foco = "sub_" .. clave
      love.graphics.setColor(I.foco == foco and 0.95 or 0.5, I.foco == foco and 0.8 or 0.42, I.foco == foco and 0.35 or 0.25)
      love.graphics.rectangle("line", fx + 130.5, y1 + 0.5, ancho - 1, 27, 3, 3)
      love.graphics.setColor(1, 0.95, 0.85)
      love.graphics.print(I.subCampos[clave] .. (I.foco == foco and "_" or ""), fx + 138, y1 + 6)
      I.registrar(fx + 130, y1, ancho, 28, "foco_" .. foco)
    end
    love.graphics.setColor(0.85, 0.8, 0.65)
    love.graphics.print("2. Precios y duración", fx, y0)
    campo("Cantidad", "cant", y0 + 24, 90)
    campo("Precio de salida", "salida", y0 + 60, 130)
    campo("Compra ya (opcional)", "compra", y0 + 96, 130)
    love.graphics.setColor(0.8, 0.78, 0.65)
    love.graphics.print("Duración", fx, y0 + 138)
    for i, hh in ipairs(d.duraciones) do
      local activo = I.subHoras == hh
      I.boton(fx + 130 + (i - 1) * 56, y0 + 132, 52, 26, hh .. " h", "sb_dur_" .. hh, true)
      if activo then
        love.graphics.setColor(1, 0.85, 0.3, 0.9)
        love.graphics.rectangle("line", fx + 130 + (i - 1) * 56, y0 + 132, 52, 26, 4, 4)
      end
    end
    local salida = numero(I.subCampos.salida) or 0
    love.graphics.setColor(0.7, 0.68, 0.6)
    love.graphics.printf("Publicar cuesta una comisión del " .. math.floor(d.comision * 100) .. "% del precio de salida (mínimo 5), que no se devuelve. Al vender, el impuesto es del " ..
      math.floor(d.impuesto * 100) .. "%.", fx, y0 + 170, 290, "left")
    local valido = d.cerca and p.bolsa[I.subIdx or 0] and salida > 0
    I.boton(fx, y0 + 232, 220, 32, "Publicar (comisión " .. math.max(5, math.floor(salida * d.comision)) .. ")", "sb_pub", valido and true or false)
  elseif I.subCat == "mias" then
    if #d.mias == 0 then
      love.graphics.setColor(0.7, 0.68, 0.6)
      love.graphics.print("No tienes subastas activas.", px + 14, y0)
    end
    for i, s in ipairs(d.mias) do
      local y = y0 + (i - 1) * 46
      love.graphics.setColor(0.13, 0.11, 0.14)
      love.graphics.rectangle("fill", px + 12, y, pw - 24, 42, 4, 4)
      filaObjeto(s.item, s.cant, s.enc, px + 16, y + 1)
      love.graphics.setColor(0.7, 0.9, 1)
      love.graphics.print(s.oferta > 0 and ("Puja: " .. s.oferta .. " (" .. (s.postor or "") .. ")") or ("Salida: " .. s.salida .. " (sin pujas)"), px + 330, y + 4)
      love.graphics.setColor(0.8, 0.8, 0.7)
      love.graphics.print("Termina en " .. tiempoRestante(s.resta), px + 330, y + 22)
      I.boton(px + pw - 24 - 110, y + 7, 110, 28, "Cancelar", "sb_cancel_" .. s.id, d.cerca and s.oferta == 0)
    end
  elseif I.subCat == "buzon" then
    if #d.buzon == 0 then
      love.graphics.setColor(0.7, 0.68, 0.6)
      love.graphics.print("Tu buzón está vacío.", px + 14, y0)
    end
    for i, e in ipairs(d.buzon) do
      if i > 9 then break end
      local y = y0 + (i - 1) * 40
      love.graphics.setColor(0.13, 0.11, 0.14)
      love.graphics.rectangle("fill", px + 12, y, pw - 24, 36, 4, 4)
      if e.item then filaObjeto(e.item, e.cant or 1, e.enc, px + 16, y - 2) end
      love.graphics.setColor(1, 0.9, 0.4)
      if (e.oro or 0) > 0 then love.graphics.print(e.oro .. " de oro", px + 300, y + 9) end
      love.graphics.setColor(0.75, 0.75, 0.68)
      love.graphics.print(e.nota or "", px + 400, y + 9)
    end
    I.boton(px + 14, py + ph - 52, 220, 34, "Recoger todo", "sb_cobrar", d.cerca and (#d.buzon > 0))
  else
    -- listado de subastas de la categoría
    if #d.lista == 0 then
      love.graphics.setColor(0.7, 0.68, 0.6)
      love.graphics.print("No hay subastas en esta categoría.", px + 14, y0)
    end
    for i, s in ipairs(d.lista) do
      local y = y0 + (i - 1) * 46
      local elegida = I.subSel == s.id
      love.graphics.setColor(elegida and 0.2 or 0.13, elegida and 0.17 or 0.11, elegida and 0.12 or 0.14)
      love.graphics.rectangle("fill", px + 12, y, pw - 24, 42, 4, 4)
      if elegida then
        love.graphics.setColor(0.9, 0.75, 0.3)
        love.graphics.rectangle("line", px + 12.5, y + 0.5, pw - 25, 41, 4, 4)
      end
      filaObjeto(s.item, s.cant, s.enc, px + 16, y + 1)
      love.graphics.setColor(0.7, 0.75, 0.65)
      love.graphics.print("de " .. s.vendedor, px + 58, y + 22)
      love.graphics.setColor(s.lider and 0.5 or 0.9, s.lider and 1 or 0.85, s.lider and 0.5 or 0.45)
      love.graphics.print(s.oferta > 0 and ("Puja: " .. s.oferta .. (s.lider and "  (tuya)" or "")) or ("Salida: " .. s.salida), px + 330, y + 4)
      love.graphics.setColor(0.8, 0.8, 0.7)
      love.graphics.print((s.compra and ("Compra: " .. s.compra .. "   ") or "") .. tiempoRestante(s.resta), px + 330, y + 22)
      I.registrar(px + 12, y, pw - 24, 42, "sb_fila_" .. s.id)
    end
    -- paginación y acciones
    local yb = py + ph - 52
    I.boton(px + 14, yb, 36, 32, "<", "sb_prev", d.pagina > 1)
    love.graphics.setColor(0.85, 0.82, 0.7)
    love.graphics.print(d.pagina .. "/" .. d.paginas, px + 58, yb + 8)
    I.boton(px + 100, yb, 36, 32, ">", "sb_next", d.pagina < d.paginas)
    local sel
    for _, s in ipairs(d.lista) do if s.id == I.subSel then sel = s end end
    love.graphics.setColor(0.8, 0.78, 0.65)
    love.graphics.print("Tu puja:", px + 170, yb + 8)
    love.graphics.setColor(0.12, 0.1, 0.08)
    love.graphics.rectangle("fill", px + 236, yb + 2, 110, 28, 3, 3)
    love.graphics.setColor(I.foco == "sub_oferta" and 0.95 or 0.5, I.foco == "sub_oferta" and 0.8 or 0.42, I.foco == "sub_oferta" and 0.35 or 0.25)
    love.graphics.rectangle("line", px + 236.5, yb + 2.5, 109, 27, 3, 3)
    love.graphics.setColor(1, 0.95, 0.85)
    love.graphics.print((I.subCampos.oferta or "") .. (I.foco == "sub_oferta" and "_" or ""), px + 244, yb + 8)
    I.registrar(px + 236, yb + 2, 110, 28, "foco_sub_oferta")
    local puja = numero(I.subCampos.oferta) or (sel and sel.minima) or 0
    I.boton(px + 356, yb, 150, 32, "Pujar" .. (sel and (" " .. puja) or ""), "sb_pujar", d.cerca and sel and not sel.mia and not sel.lider and true or false)
    I.boton(px + 514, yb, 170, 32, "Comprar ya" .. ((sel and sel.compra) and (" " .. sel.compra) or ""), "sb_comprar",
      d.cerca and sel and sel.compra and not sel.mia and true or false)
    if sel then
      love.graphics.setColor(0.65, 0.65, 0.58)
      love.graphics.print("Mínimo: " .. sel.minima, px + 236, yb - 18)
    end
  end
end

function I.panelMascotas(mundo, p, w, h)
  local px, py, pw, ph = w / 2 - 400, 60, 800, 520
  caja(px, py, pw, ph, "Criador de mascotas")
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  local reloj = love.timer.getTime()
  -- tus mascotas
  love.graphics.setColor(0.85, 0.78, 0.6)
  love.graphics.print("Tus mascotas", px + 14, py + 40)
  local mias = p.mascotas or {}
  if #mias == 0 then
    love.graphics.setColor(0.7, 0.68, 0.6)
    love.graphics.printf("Aun no tienes ninguna. Adopta una a la derecha.", px + 14, py + 70, 330, "left")
  end
  for i, m in ipairs(mias) do
    local d = Mascotas.especies[m.especie]
    local y = py + 68 + (i - 1) * 62
    love.graphics.setColor(0.13, 0.11, 0.14)
    love.graphics.rectangle("fill", px + 14, y, 340, 56, 4, 4)
    local def = Personajes.de({ kind = "mascota", especie = m.especie })
    if def then Personajes.dibujar(def, 1, true, reloj, px + 44, y + 48) end
    love.graphics.setColor(0.95, 0.9, 0.75)
    love.graphics.print((d and d.nombre or m.especie) .. "  nv " .. m.nivel, px + 74, y + 4)
    local sig = Mascotas.xpPara(m.nivel)
    local tope = m.nivel >= math.min(Mascotas.NIVEL_MAX, p.nivel or 1)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", px + 74, y + 26, 150, 8)
    love.graphics.setColor(0.85, 0.7, 0.2)
    love.graphics.rectangle("fill", px + 74, y + 26, 150 * (tope and 1 or math.min(1, (m.xp or 0) / sig)), 8)
    love.graphics.setColor(0.7, 0.75, 0.65)
    love.graphics.print(tope and "al nivel de su dueño" or ((m.xp or 0) .. "/" .. sig .. " xp"), px + 74, y + 38)
    local fuera = p.mascotaActiva == i
    I.boton(px + 252, y + 12, 94, 32, fuera and "Guardar" or "Invocar", "masc_inv_" .. i)
  end
  -- especies disponibles
  local x2 = px + 390
  love.graphics.setColor(0.85, 0.78, 0.6)
  love.graphics.print("Adoptar", x2, py + 40)
  for i, id in ipairs(Mascotas.orden) do
    local d = Mascotas.especies[id]
    local y = py + 68 + (i - 1) * 62
    local tengo = false
    for _, m in ipairs(mias) do if m.especie == id then tengo = true end end
    local nivelOk = (p.nivel or 1) >= d.nivel
    local oroOk = (p.oro or 0) >= d.precio
    love.graphics.setColor(0.13, 0.11, 0.14)
    love.graphics.rectangle("fill", x2, y, 396, 56, 4, 4)
    local def = Personajes.de({ kind = "mascota", especie = id })
    love.graphics.setColor(1, 1, 1, (nivelOk and 1 or 0.4))
    if def then Personajes.dibujar(def, 1, false, reloj, x2 + 30, y + 48, nil, nivelOk and 1 or 0.4) end
    love.graphics.setColor(nivelOk and 0.95 or 0.6, nivelOk and 0.9 or 0.58, nivelOk and 0.75 or 0.52)
    love.graphics.print(d.nombre, x2 + 60, y + 2)
    love.graphics.setColor(oroOk and 1 or 1, oroOk and 0.9 or 0.45, oroOk and 0.4 or 0.4)
    love.graphics.print(d.precio .. " oro, nv " .. d.nivel, x2 + 60 + love.graphics.getFont():getWidth(d.nombre) + 10, y + 2)
    love.graphics.setColor(0.7, 0.75, 0.65)
    love.graphics.printf(d.desc, x2 + 60, y + 21, 230, "left")
    I.boton(x2 + 296, y + 12, 94, 32, tengo and "Tuya" or "Adoptar", "masc_adoptar_" .. id, (not tengo) and nivelOk and oroOk)
  end
  love.graphics.setColor(0.7, 0.68, 0.6)
  love.graphics.printf("La mascota te sigue, pelea a tu lado y sube de nivel contigo (sin pasar del tuyo). Puede caer en combate y vuelve a los 30 s. Solo sale una a la vez y descansa durante las guerras. Tecla N: llamar o guardar la última.",
    px + 14, py + ph - 70, pw - 28, "left")
end
-- Piezas que se pueden encantar: lo que llevas puesto y lo que hay en la bolsa.
local HUECOS_ENCANTO = { "arma", "escudo", "cabeza", "pecho", "piernas", "pies", "anillo", "amuleto" }

local function piezasEncantables(p)
  local lista = {}
  for _, hueco in ipairs(HUECOS_ENCANTO) do
    local it = p.equipo[hueco] and Datos.item(p.equipo[hueco])
    if Encanto.encantable(it) then
      lista[#lista + 1] = { donde = "equipo", ref = hueco, it = it, enc = p.encantos and p.encantos[hueco] or 0 }
    end
  end
  for i, s in ipairs(p.bolsa) do
    local it = Datos.item(s.id)
    if Encanto.encantable(it) then lista[#lista + 1] = { donde = "bolsa", ref = i, it = it, enc = s.enc or 0 } end
  end
  return lista
end

function I.panelEncantar(mundo, p, w, h)
  local px, py, pw, ph = w / 2 - 350, 60, 700, 520
  caja(px, py, pw, ph, "Maestro de encantos")
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  local polvo = mundo:contarItem(p, Encanto.MATERIAL)
  love.graphics.setColor(0.85, 0.8, 0.6)
  love.graphics.print("Polvo arcano: " .. polvo .. "     Oro: " .. math.floor(p.oro or 0), px + 12, py + 34)
  local lista = piezasEncantables(p)
  local cols, lado = 6, 48
  local gx, gy = px + 14, py + 84
  love.graphics.setColor(0.85, 0.78, 0.6)
  love.graphics.print("Elige una pieza (puesta o en la bolsa)", gx, gy - 22)
  local elegida
  for i, e in ipairs(lista) do
    local col, fila = (i - 1) % cols, math.floor((i - 1) / cols)
    local x, y = gx + col * (lado + 6), gy + fila * (lado + 6)
    casilla(x, y, lado)
    local clave = e.donde .. "_" .. e.ref
    if I.encSel == clave then
      elegida = e
      love.graphics.setColor(0.9, 0.75, 0.3, 0.35)
      love.graphics.rectangle("fill", x, y, lado, lado)
    end
    iconoItem({ id = e.it.id }, x, y, lado, e.enc)
    if e.donde == "equipo" then texto("E", x + lado - 12, y + lado - 15, { 0.6, 0.9, 0.6 }) end
    I.registrar(x, y, lado, lado, "enc_" .. clave)
    if sobre(x, y, lado, lado) then I.pista = I.nombreItem(e.it, e.enc) .. " — " .. I.statsTexto(e.it, e.enc) end
  end
  if not elegida and lista[1] then
    -- sin elección todavía: la primera de la lista
    elegida = lista[1]
    I.encSel = elegida.donde .. "_" .. elegida.ref
  end
  -- detalle de la pieza elegida
  local dx = px + 360
  if elegida then
    local it, enc = elegida.it, elegida.enc
    love.graphics.setColor(1, 0.92, 0.6)
    love.graphics.print(I.nombreItem(it, enc), dx, py + 70)
    love.graphics.setColor(0.8, 0.85, 0.75)
    love.graphics.printf("Ahora: " .. I.statsTexto(it, enc), dx, py + 94, pw - 380, "left")
    if enc >= Encanto.MAX then
      love.graphics.setColor(0.55, 0.9, 0.55)
      love.graphics.print("Está al máximo (+" .. Encanto.MAX .. ").", dx, py + 150)
    else
      love.graphics.setColor(0.55, 0.9, 1)
      love.graphics.printf("Con +" .. (enc + 1) .. ": " .. I.statsTexto(it, enc + 1), dx, py + 140, pw - 380, "left")
      local c = Encanto.coste(it, enc)
      local ok = (p.oro or 0) >= c.oro and polvo >= c.polvo
      love.graphics.setColor((p.oro or 0) >= c.oro and 0.9 or 1, (p.oro or 0) >= c.oro and 0.85 or 0.4, (p.oro or 0) >= c.oro and 0.5 or 0.35)
      love.graphics.print("Oro: " .. c.oro, dx, py + 200)
      love.graphics.setColor(polvo >= c.polvo and 0.9 or 1, polvo >= c.polvo and 0.85 or 0.4, polvo >= c.polvo and 0.5 or 0.35)
      love.graphics.print("Polvo arcano: " .. c.polvo, dx, py + 222)
      love.graphics.setColor(0.85, 0.85, 0.85)
      love.graphics.print("Probabilidad de éxito: " .. math.floor(Encanto.prob(enc) * 100 + 0.5) .. "%", dx, py + 250)
      if Encanto.prob(enc) < 1 then
        love.graphics.setColor(1, 0.7, 0.4)
        love.graphics.printf(Encanto.bajaAlFallar(enc) and "Si falla, la pieza baja un nivel." or "Si falla, no pierdes el nivel (sí los materiales).", dx, py + 272, pw - 380, "left")
      end
      I.boton(dx, py + 320, 200, 36, "Encantar", "enc_go", ok)
    end
  else
    love.graphics.setColor(0.7, 0.68, 0.6)
    love.graphics.printf("No tienes equipo que encantar.", dx, py + 90, pw - 380, "left")
  end
  love.graphics.setColor(0.7, 0.68, 0.6)
  love.graphics.printf("El polvo arcano lo sueltan las criaturas. Cada nivel suma un " .. math.floor(Encanto.PCT * 100) .. "% a las cifras de la pieza; los primeros son seguros, después se puede fallar.",
    px + 14, py + ph - 70, pw - 28, "left")
end
function I.panelBolsa(mundo, p, w, h)
  caja(w / 2 - 280, h / 2 - 220, 560, 420, "Bolsa")
  I.boton(w / 2 + 200, h / 2 - 210, 60, 28, "Cerrar", "cerrar")
  for i = 1, Datos.BOLSA do
    local col = (i - 1) % 6
    local fila = math.floor((i - 1) / 6)
    local x = w / 2 - 250 + col * 64
    local y = h / 2 - 160 + fila * 64
    love.graphics.setColor(0.15, 0.13, 0.12)
    love.graphics.rectangle("fill", x, y, 56, 56)
    if i > Datos.capacidadBolsa(p.equipo) then
      love.graphics.setColor(0, 0, 0, 0.6)
      love.graphics.rectangle("fill", x, y, 56, 56)
      goto siguiente
    end
    local slot = p.bolsa[i]
    if I.arrastre == i then
      love.graphics.setColor(0.9, 0.75, 0.3, 0.35)
      love.graphics.rectangle("fill", x, y, 56, 56)
    end
    if slot then
      local it = Datos.item(slot.id)
      if it then Atlas.dibujar(it.hoja, it.sprite, x + 28, y + 30, 1.2, 16, 16) end
      love.graphics.setColor(1, 1, 1)
      if slot.cant and slot.cant > 1 then love.graphics.print(slot.cant, x + 4, y + 36) end
      local s = I.escala or 1
      local mx, my = love.mouse.getPosition()
      mx, my = mx / s, my / s
      if it and mx >= x and mx <= x + 56 and my >= y and my <= y + 56 then
        I.pista = it.nombre .. " — " .. I.statsTexto(it) .. (it.texto and ("  " .. it.texto) or "")
      end
    end
    I.registrar(x, y, 56, 56, "bolsa_" .. i)
    ::siguiente::
  end
  love.graphics.setColor(0.9, 0.85, 0.7)
  love.graphics.print("Un clic elige. Otro clic en la misma casilla equipa. Clic en otra casilla intercambia.", w / 2 - 250, h / 2 + 170)
end

function I.panelEquipo(mundo, p, w, h)
  caja(w / 2 - 330, h / 2 - 240, 660, 480, "Equipo")
  I.boton(w / 2 + 260, h / 2 - 232, 60, 28, "Cerrar", "cerrar")
  I.persona(p.clase, w / 2 - 190, h / 2 + 60, 2, p.faccion)
  local huecos = { "cabeza", "pecho", "piernas", "pies", "arma", "escudo", "anillo", "amuleto", "mochila" }
  for i, hueco in ipairs(huecos) do
    local y = h / 2 - 200 + (i - 1) * 42
    local it = p.equipo[hueco] and Datos.item(p.equipo[hueco])
    love.graphics.setColor(0.14, 0.12, 0.1)
    love.graphics.rectangle("fill", w / 2 - 80, y, 400, 38)
    if it then
      Atlas.dibujar(it.hoja, it.sprite, w / 2 - 56, y + 20, 0.9, 16, 16)
      love.graphics.setColor(0.95, 0.9, 0.75)
      local enc = p.encantos and p.encantos[hueco]
      love.graphics.print(I.nombreItem(it, enc), w / 2 - 34, y + 2)
      love.graphics.setColor(0.7, 0.75, 0.65)
      love.graphics.print(I.statsTexto(it, enc), w / 2 - 34, y + 20)
    else
      love.graphics.setColor(0.6, 0.55, 0.45)
      love.graphics.print(hueco .. " vacío", w / 2 - 34, y + 10)
    end
    I.registrar(w / 2 - 80, y, 400, 38, "equip_" .. hueco)
  end
  love.graphics.setColor(0.9, 0.88, 0.75)
  love.graphics.print(string.format("Ataque %d   Ataque mágico %d   Defensa %d   Defensa mágica %d",
    math.floor(p.atk), math.floor(p.matk or 0), math.floor(p.def), math.floor(p.mdef or 0)), w / 2 - 300, h / 2 + 190)
  love.graphics.print(string.format("Vida %d   Maná %d   Velocidad %.2f", math.floor(p.hpMax), math.floor(p.mpMax), p.spd or 0), w / 2 - 300, h / 2 + 212)
end
local ORDEN_HUECO = { arma = 1, escudo = 2, cabeza = 3, pecho = 4, piernas = 5, pies = 6, anillo = 7, amuleto = 8, mochila = 9 }

-- Lo que da una pieza, en una línea corta ("Atq +12  Def +8 ...").
function I.statsTexto(it, enc)
  local partes = {}
  for _, k in ipairs({ { "atk", "Atq" }, { "matk", "Mág" }, { "def", "Def" }, { "mdef", "Res" }, { "hp", "Vida" }, { "mp", "Maná" } }) do
    if it[k[1]] then
      local v = math.floor(Encanto.valor(it, k[1], enc) + 0.5)
      partes[#partes + 1] = k[2] .. " " .. (v > 0 and "+" or "") .. v
    end
  end
  if it.spd and it.spd ~= 0 then partes[#partes + 1] = "Vel " .. (it.spd > 0 and "+" or "") .. string.format("%.2f", it.spd) end
  if it.slots then partes[#partes + 1] = it.slots .. " espacios" end
  local pre = ""
  if it.armadura then pre = "Armadura " .. it.armadura .. ". " end
  return pre .. table.concat(partes, "  ")
end

function I.listaItemsClase(p)
  local lista = { "pocion_vida", "pocion_mana" }
  local detras = {}
  for id, it in pairs(Datos.items) do
    -- solo lo que ya puedes llevar o está a pocos niveles
    if it.hueco and (not it.clase or it.clase == p.clase) and not it.quest and (it.nivel or 1) <= (p.nivel or 1) + 4 then
      detras[#detras + 1] = id
    end
  end
  table.sort(detras, function(a, b)
    local x, y = Datos.items[a], Datos.items[b]
    if x.hueco ~= y.hueco then return (ORDEN_HUECO[x.hueco] or 99) < (ORDEN_HUECO[y.hueco] or 99) end
    if (x.nivel or 1) ~= (y.nivel or 1) then return (x.nivel or 1) < (y.nivel or 1) end
    return a < b
  end)
  for _, id in ipairs(detras) do lista[#lista + 1] = id end
  return lista
end

function I.panelMercado(p, w, h)
  caja(w / 2 - 330, 60, 660, 560, "Mercado")
  love.graphics.setColor(0.65, 0.62, 0.52)
  love.graphics.print("Rueda del ratón para recorrer. Se muestran piezas hasta 4 niveles por encima del tuyo.", w / 2 - 240, 69)
  I.boton(w / 2 + 260, 68, 60, 28, "Cerrar", "cerrar")
  local lista = I.listaItemsClase(p)
  local y0 = 104 - I.scroll * 44
  for i, id in ipairs(lista) do
    local y = y0 + (i - 1) * 44
    if y > 96 and y < 520 then
      local it = Datos.item(id)
      love.graphics.setColor(0.12, 0.1, 0.09)
      love.graphics.rectangle("fill", w / 2 - 320, y, 640, 40)
      Atlas.dibujar(it.hoja, it.sprite, w / 2 - 296, y + 20, 0.9, 16, 16)
      local nivelOk = (p.nivel or 1) >= (it.nivel or 1)
      love.graphics.setColor(nivelOk and 0.95 or 0.65, nivelOk and 0.9 or 0.6, nivelOk and 0.75 or 0.55)
      love.graphics.print(it.nombre .. (it.nivel and it.nivel > 1 and ("  (nv " .. it.nivel .. ")") or ""), w / 2 - 270, y + 3)
      love.graphics.setColor(0.7, 0.75, 0.65)
      love.graphics.print(I.statsTexto(it), w / 2 - 270, y + 21)
      love.graphics.setColor(1, 0.9, 0.4)
      love.graphics.printf(it.precio .. " oro", w / 2 + 70, y + 12, 90, "right")
      I.boton(w / 2 + 170, y + 5, 90, 30, "Comprar", "compra_" .. id)
    end
  end
  if I.sel and p.bolsa[I.sel] then
    I.boton(w / 2 - 320, 562, 160, 28, "Vender selección", "vender_sel")
  end
end
function I.panelComercio(mundo, p, w, h)
  local s = p.sesion and mundo.sesiones[p.sesion]
  caja(80, 80, w - 160, h - 200, "Comercio")
  I.boton(w - 180, 90, 70, 28, "Cerrar", "comercio_no")
  if not s then
    love.graphics.setColor(1, 0.9, 0.7)
    love.graphics.print("Selecciona a un jugador o aventurero cercano y pulsa T.", 110, 140)
    return
  end
  local otroId = s.a == p.id and s.b or s.a
  local otro = mundo.entidades[otroId]
  love.graphics.setColor(0.95, 0.9, 0.75)
  love.graphics.print("Tú ofreces", 110, 130)
  love.graphics.print(otro and otro.nombre or "?", w / 2 + 20, 130)
  local function pintar(of, x)
    love.graphics.print("Oro: " .. (of.oro or 0), x, 160)
    for i, it in ipairs(of.items or {}) do
      local d = Datos.item(it.id)
      if d then
        Atlas.dibujar(d.hoja, d.sprite, x + 20, 200 + i * 28, 0.8, 16, 16)
        love.graphics.setColor(1, 0.95, 0.85)
        love.graphics.print(d.nombre, x + 40, 190 + i * 28)
      end
    end
    love.graphics.print(of.ok and "Aceptado" or "Pendiente", x, 420)
  end
  pintar(s.oferta[p.id], 110)
  if otro then pintar(s.oferta[otro.id], w / 2 + 20) end
  I.boton(110, 460, 80, 30, "+10 oro", "oro_10")
  I.boton(200, 460, 80, 30, "+50 oro", "oro_50")
  I.boton(110, 500, 160, 32, "Aceptar", "comercio_ok")
  love.graphics.setColor(0.8, 0.78, 0.7)
  love.graphics.print("Clic en la bolsa (ábrela con I) para poner un objeto en la oferta.", 110, 548)
end

function I.panelGuerra(mundo, p, w, h)
  caja(w / 2 - 280, 70, 560, 500, "Guerra entre coronas")
  I.boton(w / 2 + 210, 78, 60, 28, "Cerrar", "cerrar")
  local min = Datos.JUGADORES_EVENTO
  love.graphics.setColor(0.9, 0.86, 0.75)
  love.graphics.printf("Los eventos los lanza el servidor a sus horas. Apúntate antes y empiezan si hay al menos " .. min .. " jugadores de Albor y " .. min .. " de Umbra. Puedes participar una vez por edición.", w / 2 - 250, 120, 500, "left")
  local function estado(modo)
    local r = mundo:resumenEvento(modo)
    if r.activa then
      return "En curso. Dentro: Albor " .. r.dentro.albor .. " · Umbra " .. r.dentro.umbra
    end
    local rm = r.min or min
    local base = string.format("Apuntados: Albor %d/%d · Umbra %d/%d", r.cola.albor, rm, r.cola.umbra, rm)
    if r.programa then
      local m = math.ceil(r.programa.restan / 60)
      local falta = m >= 60 and string.format("%d h %02d min", math.floor(m / 60), m % 60) or (m .. " min")
      return "Próxima: " .. r.programa.hora .. " (en " .. falta .. ")   " .. base
    end
    return base
  end
  love.graphics.setColor(0.95, 0.9, 0.75)
  love.graphics.printf("Batalla por cristales (una vez al día). Derribad estatuas y puertas enemigas, recoged el cristal y llevadlo a vuestro altar.", w / 2 - 250, 180, 500, "left")
  love.graphics.setColor(0.8, 0.78, 0.65)
  love.graphics.print(estado("batalla"), w / 2 - 250, 248)
  if p.modo == "batalla" then
    I.boton(w / 2 - 240, 274, 220, 36, "Abandonar el campo", "guerra_salir")
  elseif p.colaGuerra == "batalla" then
    I.boton(w / 2 - 240, 274, 220, 36, "Salir de la cola", "guerra_salir")
  else
    I.boton(w / 2 - 240, 274, 240, 36, "Apuntarse a la batalla", "guerra_batalla")
  end
  love.graphics.setColor(0.95, 0.9, 0.75)
  love.graphics.printf("Captura del estandarte (cada pocas horas). Roba la bandera enemiga y tráela a la tuya. Tres capturas ganan.", w / 2 - 250, 330, 500, "left")
  love.graphics.setColor(0.8, 0.78, 0.65)
  love.graphics.print(estado("estandarte"), w / 2 - 250, 390)
  if p.modo == "estandarte" then
    I.boton(w / 2 - 240, 416, 220, 36, "Abandonar el campo", "guerra_salir")
  elseif p.colaGuerra == "estandarte" then
    I.boton(w / 2 - 240, 416, 220, 36, "Salir de la cola", "guerra_salir")
  else
    I.boton(w / 2 - 240, 416, 260, 36, "Apuntarse al estandarte", "guerra_estandarte")
  end
end

function I.panelVivienda(mundo, p, w, h)
  caja(w / 2 - 280, 90, 560, 460, "Casas")
  I.boton(w / 2 + 210, 98, 60, 28, "Cerrar", "cerrar")
  local ciudad = nil
  local cid = I.ciudad
  for _, c in ipairs(mundo.mapas.mundo.ciudades) do
    if c.id == cid or (not cid and c.faccion == p.faccion and mundo:ciudadEn(p.x, p.y) == c) then ciudad = c end
  end
  if not ciudad then
    for _, c in ipairs(mundo.mapas.mundo.ciudades) do
      if mundo:ciudadEn(p.x, p.y) == c then ciudad = c end
    end
  end
  if not ciudad then
    love.graphics.setColor(1, 0.9, 0.75)
    love.graphics.print("Habla con el mayordomo dentro de una ciudad de tu facción.", w / 2 - 240, 160)
    return
  end
  love.graphics.setColor(0.95, 0.9, 0.75)
  love.graphics.print(ciudad.nombre, w / 2 - 250, 140)
  for i, par in ipairs(ciudad.parcelas) do
    local y = 180 + (i - 1) * 80
    local precio = ciudad.capital and Datos.precioCasa.capital or Datos.precioCasa.normal
    local txt = par.dueno and (par.dueno == p.id and "Tu casa" or "Ocupada") or ("Libre  ·  " .. precio .. " oro")
    love.graphics.print("Parcela " .. i .. "  " .. txt, w / 2 - 240, y)
    if not par.dueno then I.boton(w / 2 + 40, y - 6, 140, 30, "Comprar", "casa_comprar_" .. par.id) end
    if par.dueno == p.id then I.boton(w / 2 + 190, y - 6, 100, 30, "Entrar", "casa_entrar_" .. par.id) end
  end
end

function I.panelMisiones(mundo, p, w, h)
  caja(w / 2 - 300, 80, 600, 500, "Encargos")
  I.boton(w / 2 + 230, 88, 60, 28, "Cerrar", "cerrar")
  local y = 130
  for _, q in ipairs(Datos.misiones) do
    local st = p.misiones[q.id]
    local ciudadOk = (not I.ciudad) or q.ciudad == I.ciudad or (st and st.aceptada)
    if q.requiere then
      local prev = p.misiones[q.requiere]
      if not (prev and prev.entregada) then ciudadOk = false end
    end
    if ciudadOk and y < 540 then
      love.graphics.setColor(0.95, 0.9, 0.75)
      local prog = st and (st.progreso or 0) or 0
      love.graphics.print(q.titulo .. "  (" .. prog .. "/" .. q.cantidad .. ")", w / 2 - 270, y)
      if not st then I.boton(w / 2 + 120, y - 4, 100, 26, "Aceptar", "mision_ok_" .. q.id)
      elseif st.aceptada and not st.entregada and prog >= q.cantidad then
        I.boton(w / 2 + 120, y - 4, 100, 26, "Entregar", "mision_fin_" .. q.id)
      end
      y = y + 36
    end
  end
end

function I.panelMapa(mundo, p, w, h)
  caja(40, 40, w - 80, h - 80, "Las diez ciudades")
  I.boton(w - 140, 48, 70, 28, "Cerrar", "cerrar")
  local mw, mh = Datos.MAPA_W, Datos.MAPA_H
  local areaW, areaH = (w - 120) * 0.62, h - 150
  local s = math.min(areaW / mw, areaH / mh)
  local ox, oy = 64, 96
  if I.mini then
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(I.mini, ox, oy, 0, s, s)
  end
  if p.modo == "mundo" then
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", ox + p.x * s - 3, oy + p.y * s - 3, 6, 6)
  end
  -- los PNJ: un icono por cada uno
  for _, n in ipairs(mundo.mapas.mundo.npcsMapa or {}) do I.iconoNpc(n.rol, ox + n.x * s, oy + n.y * s, 2.6) end
  for _, c in ipairs(mundo.mapas.mundo.ciudades) do
    local col = Datos.facciones[c.faccion].color
    love.graphics.setColor(col[1], col[2], col[3], 0.9)
    love.graphics.rectangle("line", ox + c.x * s, oy + c.y * s, c.w * s, c.h * s)
  end
  local ly = 100
  for _, c in ipairs(mundo.mapas.mundo.ciudades) do
    local col = Datos.facciones[c.faccion].color
    love.graphics.setColor(col)
    love.graphics.rectangle("fill", ox + mw * s + 28, ly + 4, 10, 10)
    love.graphics.setColor(0.92, 0.88, 0.78)
    love.graphics.print(c.nombre .. (c.capital and "  ·  capital" or ""), ox + mw * s + 46, ly)
    ly = ly + 26
  end
  -- leyenda de iconos
  ly = ly + 10
  love.graphics.setColor(0.85, 0.78, 0.6)
  love.graphics.print("PNJ", ox + mw * s + 28, ly)
  ly = ly + 22
  for _, rol in ipairs(I.ORDEN_ICONOS) do
    I.iconoNpc(rol, ox + mw * s + 34, ly + 8, 3)
    love.graphics.setColor(0.88, 0.84, 0.72)
    love.graphics.print(ICONO_NPC[rol][3], ox + mw * s + 50, ly)
    ly = ly + 20
  end
end

function I.panelAyuda(w, h)
  caja(80, 60, w - 160, h - 120, "Cómo jugar")
  I.boton(w - 200, 68, 70, 28, "Cerrar", "cerrar")
  local texto = table.concat({
    "Moverte: WASD o flechas (casilla a casilla, con diagonales) o clic en el suelo. Dos criaturas no pueden ocupar la misma casilla.",
    "Combate: clic en un enemigo (o en la Lista de batalla) lo elige y lo persigue. Tab pasa al siguiente enemigo. Esc suelta el objetivo.",
    "Shift + clic sobre una criatura: la miras y la consola te cuenta qué es. Clic en un aliado: lo eliges para curarlo.",
    "Poderes 1-6 (se aprenden en el árbol, tecla K). 7 poción de vida, 8 poción de maná. La barra de abajo muestra el enfriamiento.",
    "Panel derecho: minimapa, vida, maná y experiencia, equipo, lista de batalla y mochila. K abre el árbol de poderes: cada nivel da un punto para aprender o mejorar un poder. En la mochila, un clic elige, otro clic en la misma casilla equipa y otro clic en otra casilla intercambia.",
    "E interactúa (mercader, heraldo, mayordomo, casa, altar). T comercio, B guerra, M mapa, F1 ayuda, F3 medidor, F11 pantalla completa.",
    "Chat: Enter. Escribe /m para hablar al mundo y /f para hablar a tu facción. Las ciudades de tu facción son refugio.",
    "La guerra, una vez al día: batalla por cristales o captura del estandarte. Empieza con 3 jugadores por equipo.",
    "Las casas se compran al mayordomo. Dentro puedes poner cama, cofre, mesa y estandarte.",
  }, "\n\n")
  love.graphics.setColor(0.92, 0.88, 0.78)
  love.graphics.printf(texto, 100, 110, w - 200, "left")
end

function I.panelCasa(p, w, h)
  caja(w - 340, 80, 300, 280, "Tu casa")
  I.boton(w - 120, 88, 60, 28, "Salir", "casa_salir")
  local casa = p.casas[p.casaId]
  local y = 130
  for _, tipo in ipairs({ "cama", "cofre", "estandarte", "mesa" }) do
    local m = Datos.muebles[tipo]
    local puesto = casa and casa.muebles[tipo]
    I.boton(w - 320, y, 260, 32, (puesto and "Usar " or "Comprar ") .. m.nombre .. (puesto and "" or (" (" .. m.precio .. ")")), "mueble_" .. tipo)
    y = y + 40
  end
end

function I.personajes(lista, usuario, w, h, errorTxt)
  I.limpiar()
  I.fondo("Titles2/Forest.png", w, h, 0.62)
  love.graphics.setFont(I.grande)
  love.graphics.setColor(0.95, 0.86, 0.55)
  love.graphics.printf("Elige personaje", 0, 28, w, "center")
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(0.8, 0.78, 0.7)
  love.graphics.printf("Cuenta: " .. (usuario or ""), 0, 68, w, "center")
  if errorTxt and errorTxt ~= "" then
    love.graphics.setColor(1, 0.45, 0.4)
    love.graphics.printf(errorTxt, 80, 96, w - 160, "center")
  end
  local y = 130
  if not lista or #lista == 0 then
    love.graphics.setColor(0.85, 0.82, 0.75)
    love.graphics.printf("Esta cuenta aún no tiene personajes.\nPulsa Crear personaje, elige facción y oficio, y ponle un nombre.", 0, 220, w, "center")
  end
  for _, pj in ipairs(lista or {}) do
    local fac = Datos.facciones[pj.faccion]
    local clase = Datos.clases[pj.clase]
    caja(w / 2 - 340, y, 680, 96, nil)
    if fac then
      love.graphics.setColor(fac.color[1], fac.color[2], fac.color[3], 0.2)
      love.graphics.rectangle("fill", w / 2 - 324, y + 12, 72, 72, 4, 4)
    end
    I.persona(pj.clase, w / 2 - 288, y + 84, 0.85, pj.faccion)
    love.graphics.setColor(fac and fac.color or { 1, 1, 1 })
    love.graphics.print(pj.nombre .. "   nivel " .. pj.nivel, w / 2 - 220, y + 28)
    love.graphics.setColor(0.85, 0.82, 0.75)
    love.graphics.print((fac and fac.nombre or "") .. "  ·  " .. (clase and clase.nombre or ""), w / 2 - 220, y + 52)
    I.boton(w / 2 + 80, y + 30, 160, 36, "Jugar", "pj_" .. pj.id)
    y = y + 108
  end
  love.graphics.setColor(0.7, 0.68, 0.6)
  love.graphics.printf("El servidor ya validó la cuenta. Jugar entra con ese personaje.", 40, h - 118, w - 80, "center")
  I.boton(w / 2 - 220, h - 72, 240, 44, "Crear personaje", "pj_nuevo", not lista or #lista < 4)
  I.boton(w / 2 + 40, h - 72, 180, 44, "Cerrar sesión", "cuenta_salir")
end

function I.cuenta(form, w, h)
  I.limpiar()
  I.fondo("Titles2/Forest.png", w, h, 0.62)
  love.graphics.setFont(I.grande)
  love.graphics.setColor(0.95, 0.86, 0.55)
  love.graphics.printf(form.modo == "crear" and "Crear cuenta" or "Iniciar sesión", 0, 48, w, "center")
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(0.8, 0.78, 0.7)
  local ayuda = form.modo == "crear"
    and "El servidor crea la cuenta. Después podrás tener hasta 4 personajes."
    or "El servidor comprueba el usuario y la clave. jugar.bat lo abre por ti."
  love.graphics.printf(ayuda, w / 2 - 280, 100, 560, "center")
  I.boton(w / 2 - 220, 150, 210, 36, "Iniciar sesión", "menu_entrar", form.modo ~= "entrar")
  I.boton(w / 2 + 10, 150, 210, 36, "Crear cuenta", "menu_registro", form.modo ~= "crear")
  local function campo(etiqueta, valor, y, id, secreto, pista)
    love.graphics.setColor(0.9, 0.86, 0.75)
    love.graphics.print(etiqueta, w / 2 - 180, y)
    love.graphics.setColor(0.15, 0.13, 0.1)
    love.graphics.rectangle("fill", w / 2 - 180, y + 22, 360, 36, 4, 4)
    love.graphics.setColor(1, 0.95, 0.85)
    local muestra = secreto and string.rep("•", #(valor or "")) or (valor or "")
    if muestra == "" and I.foco ~= id then
      love.graphics.setColor(0.55, 0.5, 0.42)
      muestra = pista
    end
    love.graphics.print(muestra .. (I.foco == id and "_" or ""), w / 2 - 168, y + 30)
    I.registrar(w / 2 - 180, y + 22, 360, 36, "foco_" .. id)
  end
  campo("Usuario", form.usuario, 210, "usuario", false, "3 a 16 letras o números")
  campo("Clave", form.clave, 290, "clave", true, "mínimo 4 caracteres")
  if form.error and form.error ~= "" then
    love.graphics.setColor(1, 0.45, 0.4)
    love.graphics.printf(form.error, w / 2 - 240, 360, 480, "center")
  end
  I.boton(w / 2 - 180, 410, 360, 46, form.modo == "crear" and "Registrarme" or "Entrar", "cuenta_ok")
  I.boton(w / 2 - 180, 468, 360, 36, "Volver al menú", "cuenta_volver")
end

function I.panelPausa(w, h)
  caja(w / 2 - 160, h / 2 - 125, 320, 250, "Menú")
  I.boton(w / 2 - 120, h / 2 - 75, 240, 36, "Volver", "cerrar")
  I.boton(w / 2 - 120, h / 2 - 25, 240, 36, "Ajustes", "ajustes")
  I.boton(w / 2 - 120, h / 2 + 25, 240, 36, "Salir al menú", "salir_menu")
  love.graphics.setColor(0.75, 0.72, 0.64)
  love.graphics.printf("Tu progreso se guarda solo.", w / 2 - 140, h / 2 + 76, 280, "center")
end

function I.panelAjustes(w, h)
  caja(w / 2 - 220, h / 2 - 180, 440, 360, "Ajustes")
  I.boton(w / 2 + 150, h / 2 - 170, 60, 28, "Cerrar", "cerrar")
  love.graphics.setColor(0.92, 0.88, 0.78)
  love.graphics.print(string.format("Volumen %d%%", math.floor((Ajustes.volumen or 0) * 100)), w / 2 - 180, h / 2 - 110)
  I.boton(w / 2 + 20, h / 2 - 118, 70, 28, "−", "aj_vol_menos")
  I.boton(w / 2 + 100, h / 2 - 118, 70, 28, "+", "aj_vol_mas")
  I.boton(w / 2 - 180, h / 2 - 60, 160, 32, "1280×720", "aj_1280")
  I.boton(w / 2, h / 2 - 60, 160, 32, "1600×900", "aj_1600")
  I.boton(w / 2 - 180, h / 2 - 16, 340, 32, Ajustes.completo and "Ventana" or "Pantalla completa", "aj_completo")
  local inter = Ajustes.teclas and Ajustes.teclas.interactuar or "e"
  local bolsa = Ajustes.teclas and Ajustes.teclas.bolsa or "i"
  local espera = Ajustes.esperando
  I.boton(w / 2 - 180, h / 2 + 36, 340, 32, espera == "interactuar" and "Pulsa una tecla…" or ("Interactuar: " .. inter), "aj_tecla_interactuar")
  I.boton(w / 2 - 180, h / 2 + 78, 340, 32, espera == "bolsa" and "Pulsa una tecla…" or ("Bolsa: " .. bolsa), "aj_tecla_bolsa")
  love.graphics.setColor(0.75, 0.72, 0.64)
  love.graphics.print("F11 cambia la pantalla. F3 muestra el medidor.", w / 2 - 180, h / 2 + 124)
end


return I
