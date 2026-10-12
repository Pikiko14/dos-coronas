local Datos = require("compartido.dominio.datos")
local Atlas = require("src.presentacion.render.atlas")
local Balance = require("compartido.dominio.balance")
local Arbol = require("compartido.dominio.arbol")
local Estados = require("compartido.dominio.estados")
local Ajustes = require("src.presentacion.ajustes")
local Personajes = require("src.presentacion.render.personajes")
local Objetos = require("src.presentacion.render.objetos")
local Arte = require("src.presentacion.render.arte")
local Dibujo = require("src.presentacion.render.dibujo")
local Efectos = require("src.presentacion.render.efectos")
local Config = require("src.infraestructura.config")

local I = { rects = {}, foco = nil, texto = "", panel = nil, sel = 1, scroll = 0, aviso = "", canal = "todo", escala = 1 }

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

local function iconoItem(slot, x, y, lado)
  local it = slot and Datos.item(slot.id)
  if not it then return nil end
  local e = (lado - 4) / 32
  Atlas.dibujar(it.hoja, it.sprite, x + lado / 2, y + lado / 2 + 8 * e, e, 16, 16)
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
  local total = 6 * lado_c + 5 * sep
  local bx0 = vw / 2 - total / 2
  local by0 = vh - lado_c - 10
  for i = 1, 4 do
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
  pocion("pocion_vida", 5, "5", "poc_vida")
  pocion("pocion_mana", 6, "6", "poc_mana")

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
  ["local"] = { 0.95, 0.95, 0.9 },
}

function I.consola(mundo, p, x, y, w, h)
  local f = pequena()
  love.graphics.setFont(f)
  -- El fondo se registra primero: lo que se registra después (pestañas, entrada
  -- de chat) queda por encima y recibe los clics.
  I.registrar(x, y, w, h, "panel")
  local canales = { { "todo", "Todo" }, { "mundo", "Mundo" }, { "faccion", "Facción" }, { "sistema", "Sistema" } }
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
    local etiqueta = m.canal == "sistema" and "" or ((m.canal == "mundo" and "[Mundo] ") or (m.canal == "faccion" and "[Facción] ") or "")
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
  local muestra = I.foco == "chat" and I.texto or "Enter para hablar  ·  /m mundo  ·  /f facción"
  love.graphics.setColor(I.foco == "chat" and 1 or 0.6, I.foco == "chat" and 0.95 or 0.58, I.foco == "chat" and 0.8 or 0.5)
  love.graphics.print(muestra .. (I.foco == "chat" and "_" or ""), x + 12, ey + 2)
  I.registrar(x + 6, ey, w - 12, entrada - 4, "foco_chat")
  love.graphics.setFont(I.fuente)
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
  local ventana = 72
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
  local xpN = Datos.xpPara(p.nivel)
  barra(ix + 4, cy + 40, iw - 8, 12, (p.xp or 0) / xpN, 0.85, 0.7, 0.2)
  texto(string.format("Nivel %d   exp %d / %d", p.nivel, math.floor(p.xp or 0), xpN), ix + 8, cy + 39, { 1, 1, 1 })
  cy = cy + 70

  -- Equipo (cuadrícula de 3x3) y cifras
  local ec = 40
  local huecos = {
    { "anillo", 0, 0 }, { "cabeza", 1, 0 }, { "mochila", 2, 0 }, { "arma", 0, 1 }, { "pecho", 1, 1 }, { "escudo", 2, 1 }, { "pies", 1, 2 },
  }
  marco(ix - 4, cy, iw + 8, ec * 3 + 14, true)
  local gx, gy = ix + 2, cy + 7
  for _, hh in ipairs(huecos) do
    local sx, sy = gx + hh[2] * (ec + 2), gy + hh[3] * (ec + 2)
    casilla(sx, sy, ec)
    local itemId = p.equipo[hh[1]]
    local it = itemId and Datos.item(itemId)
    if it then
      iconoItem({ id = itemId }, sx, sy, ec)
      if sobre(sx, sy, ec, ec) then
        I.pista = it.nombre .. (it.atk and ("  ataque +" .. it.atk) or "") .. (it.def and ("  defensa +" .. it.def) or "")
      end
    else
      love.graphics.setColor(0.35, 0.3, 0.24, 0.8)
      love.graphics.setFont(f)
      love.graphics.printf(hh[1] == "mochila" and "bolsa" or hh[1], sx, sy + ec / 2 - 7, ec, "center")
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
  cy = cy + ec * 3 + 20

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
        I.pista = it.nombre .. (it.texto and (" — " .. it.texto) or "") ..
          (it.atk and ("  ataque +" .. it.atk) or "") .. (it.def and ("  defensa +" .. it.def) or "")
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
  local px, py, pw, ph = w / 2 - 340, h / 2 - 250, 680, 500
  caja(px, py, pw, ph, "Árbol de poderes — " .. (clase and clase.nombre or ""))
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  local puntos = Arbol.puntos(p)
  love.graphics.setColor(puntos > 0 and 1 or 0.7, puntos > 0 and 0.88 or 0.68, puntos > 0 and 0.35 or 0.6)
  love.graphics.print("Puntos disponibles: " .. puntos .. "   (1 por nivel)", px + 12, py + 34)

  local cw, ch, sep = 150, 130, 14
  local x0 = px + (pw - (4 * cw + 3 * sep)) / 2
  local filas = { activa = py + 78, pasiva = py + 78 + ch + 34 }
  love.graphics.setColor(0.85, 0.78, 0.6)
  love.graphics.print("Poderes (barra 1-4)", x0, filas.activa - 20)
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
    love.graphics.printf(Arbol.nombre(n), c.x + 4, c.y + 62, cw - 8, "center")
    -- rangos
    for i = 1, Arbol.MAX do
      love.graphics.setColor(i <= r and 1 or 0.25, i <= r and 0.8 or 0.24, i <= r and 0.25 or 0.22, 1)
      love.graphics.rectangle("fill", c.x + cw / 2 - 45 + (i - 1) * 19, c.y + 88, 15, 8, 2, 2)
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
    love.graphics.printf(pie, c.x + 4, c.y + 104, cw - 8, "center")
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
        I.pista = it.nombre .. (it.texto and (" — " .. it.texto) or "")
      end
    end
    I.registrar(x, y, 56, 56, "bolsa_" .. i)
    ::siguiente::
  end
  love.graphics.setColor(0.9, 0.85, 0.7)
  love.graphics.print("Un clic elige. Otro clic en la misma casilla equipa. Clic en otra casilla intercambia.", w / 2 - 250, h / 2 + 170)
end

function I.panelEquipo(mundo, p, w, h)
  caja(w / 2 - 300, h / 2 - 230, 600, 460, "Equipo visible")
  I.boton(w / 2 + 230, h / 2 - 220, 60, 28, "Cerrar", "cerrar")
  I.persona(p.clase, w / 2 - 140, h / 2 + 60, 2, p.faccion)
  local huecos = { "cabeza", "pecho", "arma", "escudo", "pies", "anillo", "mochila" }
  for i, hueco in ipairs(huecos) do
    local y = h / 2 - 170 + (i - 1) * 48
    local it = p.equipo[hueco] and Datos.item(p.equipo[hueco])
    love.graphics.setColor(0.14, 0.12, 0.1)
    love.graphics.rectangle("fill", w / 2 + 20, y, 250, 46)
    if it then
      Atlas.dibujar(it.hoja, it.sprite, w / 2 + 44, y + 24, 1, 16, 16)
      love.graphics.setColor(0.95, 0.9, 0.75)
      love.graphics.print(it.nombre, w / 2 + 70, y + 14)
    else
      love.graphics.setColor(0.6, 0.55, 0.45)
      love.graphics.print(hueco .. " vacío", w / 2 + 70, y + 14)
    end
    I.registrar(w / 2 + 20, y, 250, 46, "equip_" .. hueco)
  end
  love.graphics.setColor(0.9, 0.88, 0.75)
  love.graphics.print(string.format("Ataque %d   Ataque mágico %d   Defensa %d   Defensa mágica %d",
    math.floor(p.atk), math.floor(p.matk or 0), math.floor(p.def), math.floor(p.mdef or 0)), w / 2 - 260, h / 2 + 170)
  love.graphics.print(string.format("Vida %d   Maná %d", math.floor(p.hpMax), math.floor(p.mpMax)), w / 2 - 260, h / 2 + 192)
end

function I.listaItemsClase(p)
  local lista = { "pocion_vida", "pocion_mana" }
  for id, it in pairs(Datos.items) do
    if it.hueco and (not it.clase or it.clase == p.clase) and not it.quest then
      lista[#lista + 1] = id
    end
  end
  table.sort(lista)
  return lista
end

function I.panelMercado(p, w, h)
  caja(w / 2 - 260, 80, 520, 520, "Mercado")
  I.boton(w / 2 + 190, 88, 60, 28, "Cerrar", "cerrar")
  local lista = I.listaItemsClase(p)
  local y0 = 130 - I.scroll * 28
  for i, id in ipairs(lista) do
    local y = y0 + (i - 1) * 36
    if y > 110 and y < 520 then
      local it = Datos.item(id)
      love.graphics.setColor(0.12, 0.1, 0.09)
      love.graphics.rectangle("fill", w / 2 - 240, y, 480, 32)
      Atlas.dibujar(it.hoja, it.sprite, w / 2 - 210, y + 16, 0.9, 16, 16)
      love.graphics.setColor(0.95, 0.9, 0.75)
      love.graphics.print(it.nombre .. "   " .. it.precio .. " oro", w / 2 - 180, y + 8)
      I.boton(w / 2 + 120, y + 2, 90, 28, "Comprar", "compra_" .. id)
    end
  end
  if I.sel and p.bolsa[I.sel] then
    I.boton(w / 2 - 240, 560, 160, 28, "Vender selección", "vender_sel")
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
  love.graphics.printf("Los eventos se juegan entre jugadores. Empiezan con al menos " .. min .. " de Albor y " .. min .. " de Umbra. El día se gasta al empezar, no al apuntarte.", w / 2 - 250, 120, 500, "left")
  local function estado(modo)
    local r = mundo:resumenEvento(modo)
    if r.activa then
      return "En curso. Dentro: Albor " .. r.dentro.albor .. " · Umbra " .. r.dentro.umbra
    end
    return string.format("En cola: Albor %d/%d · Umbra %d/%d", r.cola.albor, min, r.cola.umbra, min)
  end
  love.graphics.setColor(0.95, 0.9, 0.75)
  love.graphics.printf("Batalla por cristales. Derribad estatuas y puertas enemigas, recoged el cristal y llevadlo a vuestro altar.", w / 2 - 250, 180, 500, "left")
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
  love.graphics.printf("Captura el estandarte. Roba la bandera enemiga y tráela a la tuya. Tres capturas ganan.", w / 2 - 250, 330, 500, "left")
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
  local ly = 100
  for _, c in ipairs(mundo.mapas.mundo.ciudades) do
    local col = Datos.facciones[c.faccion].color
    love.graphics.setColor(col)
    love.graphics.rectangle("fill", ox + mw * s + 28, ly + 4, 10, 10)
    love.graphics.setColor(0.92, 0.88, 0.78)
    love.graphics.print(c.nombre .. (c.capital and "  ·  capital" or ""), ox + mw * s + 46, ly)
    ly = ly + 26
  end
end

function I.panelAyuda(w, h)
  caja(80, 60, w - 160, h - 120, "Cómo jugar")
  I.boton(w - 200, 68, 70, 28, "Cerrar", "cerrar")
  local texto = table.concat({
    "Moverte: WASD o flechas (casilla a casilla, con diagonales) o clic en el suelo. Dos criaturas no pueden ocupar la misma casilla.",
    "Combate: clic en un enemigo (o en la Lista de batalla) lo elige y lo persigue. Tab pasa al siguiente enemigo. Esc suelta el objetivo.",
    "Shift + clic sobre una criatura: la miras y la consola te cuenta qué es. Clic en un aliado: lo eliges para curarlo.",
    "Poderes 1-4 (el 3 desde el nivel 4, el 4 desde el 8). 5 poción de vida, 6 poción de maná. La barra de abajo muestra el enfriamiento.",
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
