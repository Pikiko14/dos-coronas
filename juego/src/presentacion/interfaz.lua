local Datos = require("compartido.dominio.datos")
local Misiones = require("compartido.dominio.misiones")
local Atlas = require("src.presentacion.render.atlas")
local Balance = require("compartido.dominio.balance")
local Arbol = require("compartido.dominio.arbol")
local Estados = require("compartido.dominio.estados")
local Encanto = require("compartido.dominio.encanto")
local Mascotas = require("compartido.dominio.mascotas")
local Monturas = require("compartido.dominio.monturas")
local Subastas = require("compartido.dominio.subastas")
local Iso = require("src.presentacion.render.iso")
local Ajustes = require("src.presentacion.ajustes")
local Personajes = require("src.presentacion.render.personajes")
local Objetos = require("src.presentacion.render.objetos")
local Arte = require("src.presentacion.render.arte")
local Dibujo = require("src.presentacion.render.dibujo")
local Efectos = require("src.presentacion.render.efectos")
local Config = require("src.infraestructura.config")
local Util = require("compartido.dominio.util")
local Ayudas = require("src.presentacion.ayudas")

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

-- ------------------------------------------------------------------------------------ tema
-- Estilo moderno: cristal oscuro azulado con acentos dorados y cian, esquinas redondeadas,
-- degradados suaves y sombras. Todas las piezas base (caja, marco, casilla, botón, barra) salen de aquí.
local TEMA = {
  fondo = { 0.06, 0.08, 0.16 },        -- panel
  fila = { 0.10, 0.13, 0.25 },         -- filas y celdas dentro de un panel
  borde = { 0.30, 0.44, 0.82 },        -- línea de los paneles
  acento = { 0.98, 0.78, 0.36 },       -- dorado: títulos y destacados
  cian = { 0.38, 0.80, 0.96 },         -- brillo secundario
  texto = { 0.93, 0.95, 1.0 },
}
I.TEMA = TEMA

local degradado
-- Franja alfa (opaca arriba, transparente abajo) que se tiñe con setColor: sirve de brillo y de degradado.
local function brillo(x, y, w, h, r, g, b, a)
  if not degradado then
    local d = love.image.newImageData(1, 32)
    for i = 0, 31 do d:setPixel(0, i, 1, 1, 1, 1 - i / 31) end
    degradado = love.graphics.newImage(d)
    degradado:setFilter("linear", "linear")
  end
  love.graphics.setColor(r, g, b, a)
  love.graphics.draw(degradado, x, y, 0, w, h / 32)
end
I.brillo = brillo

-- Rectángulo redondeado con degradado vertical de c1 (arriba) a c2 (abajo).
local function relleno(x, y, w, h, rad, c1, c2, a)
  love.graphics.setColor(c2[1], c2[2], c2[3], a or 1)
  love.graphics.rectangle("fill", x, y, w, h, rad, rad)
  if c1 ~= c2 then
    love.graphics.stencil(function() love.graphics.rectangle("fill", x, y, w, h, rad, rad) end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    brillo(x, y, w, h, c1[1], c1[2], c1[3], a or 1)
    love.graphics.setStencilTest()
  end
end

local function caja(x, y, w, h, titulo)
  -- sombra suave
  love.graphics.setColor(0, 0, 0, 0.28)
  love.graphics.rectangle("fill", x - 2, y + 3, w + 4, h + 4, 12, 12)
  love.graphics.setColor(0, 0, 0, 0.18)
  love.graphics.rectangle("fill", x - 5, y + 6, w + 10, h + 8, 14, 14)
  -- cuerpo
  love.graphics.setColor(TEMA.fondo[1], TEMA.fondo[2], TEMA.fondo[3], 0.96)
  love.graphics.rectangle("fill", x, y, w, h, 10, 10)
  love.graphics.stencil(function() love.graphics.rectangle("fill", x, y, w, h, 10, 10) end, "replace", 1)
  love.graphics.setStencilTest("greater", 0)
  brillo(x, y, w, 70, 0.3, 0.5, 0.95, 0.16)
  love.graphics.setStencilTest()
  love.graphics.setLineWidth(1.5)
  love.graphics.setColor(TEMA.borde[1], TEMA.borde[2], TEMA.borde[3], 0.95)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 10, 10)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(1, 1, 1, 0.06)
  love.graphics.rectangle("line", x + 2.5, y + 2.5, w - 5, h - 5, 8, 8)
  if titulo then
    love.graphics.setColor(TEMA.acento[1], TEMA.acento[2], TEMA.acento[3], 1)
    love.graphics.print(titulo, x + 16, y + 9)
    local corto = math.min(120, w - 28)
    love.graphics.setColor(TEMA.acento[1], TEMA.acento[2], TEMA.acento[3], 0.55)
    love.graphics.rectangle("fill", x + 14, y + 31, corto, 2, 1, 1)
    love.graphics.setColor(TEMA.borde[1], TEMA.borde[2], TEMA.borde[3], 0.35)
    love.graphics.rectangle("fill", x + 14 + corto, y + 31, math.max(0, w - 28 - corto), 1)
  end
  I.registrar(x, y, w, h, "panel")
end

-- motivo: si el botón está desactivado, el texto que explica por qué (sale al pasar el ratón).
function I.boton(x, y, w, h, texto, id, activo, motivo)
  local s = I.escala or 1
  -- todos los "Cerrar" son una X cuadrada pegada al borde derecho del hueco original
  local equis = id == "cerrar" and texto == "Cerrar"
  if equis then
    local l = 28
    x, y, w, h = x + w - l + 4, y, l, l
  end
  local mx, my = love.mouse.getPosition()
  mx, my = mx / s, my / s
  local hover = mx >= x and mx <= x + w and my >= y and my <= y + h
  if hover and activo == false and motivo then I.pista = motivo end
  local rad = math.min(8, h / 2)
  if activo == false then
    relleno(x, y, w, h, rad, { 0.17, 0.2, 0.3 }, { 0.12, 0.14, 0.22 }, 0.95)
    love.graphics.setColor(0.28, 0.33, 0.48, 0.8)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, rad, rad)
    love.graphics.setColor(0.55, 0.6, 0.72)
  else
    if hover then
      relleno(x, y, w, h, rad, { 0.36, 0.5, 0.92 }, { 0.2, 0.3, 0.64 }, 1)
      love.graphics.setColor(TEMA.acento[1], TEMA.acento[2], TEMA.acento[3], 1)
    else
      relleno(x, y, w, h, rad, { 0.24, 0.33, 0.66 }, { 0.14, 0.2, 0.43 }, 1)
      love.graphics.setColor(0.45, 0.6, 0.95, 0.9)
    end
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, rad, rad)
    love.graphics.setColor(1, 1, 1, hover and 0.1 or 0.05)
    love.graphics.rectangle("fill", x + 2, y + 2, w - 4, h / 2 - 2, rad - 1, rad - 1)
    love.graphics.setColor(0.98, 0.98, 1)
  end
  if equis then
    local cx, cy, r = x + w / 2, y + h / 2, 5
    love.graphics.setLineWidth(2.5)
    love.graphics.line(cx - r, cy - r, cx + r, cy + r)
    love.graphics.line(cx - r, cy + r, cx + r, cy - r)
    love.graphics.setLineWidth(1)
  else
    love.graphics.printf(texto, x, y + h / 2 - 8, w, "center")
  end
  if activo ~= false then I.registrar(x, y, w, h, id) end
end

-- Retrato de un oficio: (x, y) son los pies; zoom 1 equivale a un personaje de 32 px por 2,4.
-- addon (opcional): el aspecto del addon activo del personaje en lugar del de su clase.
function I.persona(claseId, x, y, zoom, faccion, addon, genero, equipo)
  local Fao = require("src.presentacion.render.fao")
  if not addon and Fao.activo() then
    -- personaje por capas: se dibuja de frente, con su equipo (o el de escalón 1 si no hay)
    Fao.retrato(claseId or "guerrero", genero or "h", equipo, x, y, (zoom or 1) * 1.6)
    return
  end
  local c = Personajes.clases[claseId or "guerrero"] or Personajes.clases.guerrero
  local def = c[faccion or "albor"] or c.albor
  if addon then def = Personajes.de({ kind = "jugador", clase = claseId, faccion = faccion, addon = addon }) or def end
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

local function sobre(x, y, w, h)
  local s = I.escala or 1
  local mx, my = love.mouse.getPosition()
  mx, my = mx / s, my / s
  return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function fuentePortada(cual, px)
  I._fuentesPortada = I._fuentesPortada or {}
  if I._fuentesPortada[cual] then return I._fuentesPortada[cual] end
  local ruta = "arte/fuentes/SourceSans3-Regular.ttf"
  local f = love.filesystem.getInfo(ruta) and love.graphics.newFont(ruta, px) or love.graphics.newFont(px)
  I._fuentesPortada[cual] = f
  return f
end

local function iconoPortada(tipo, cx, cy)
  love.graphics.setLineWidth(1.6)
  if tipo == "casa" then
    love.graphics.polygon("line", cx, cy - 7, cx - 8, cy - 1, cx + 8, cy - 1)
    love.graphics.rectangle("line", cx - 5, cy - 1, 10, 8)
  elseif tipo == "persona" then
    love.graphics.circle("line", cx, cy - 4, 3.2)
    love.graphics.arc("line", "open", cx, cy + 8, 6, math.pi * 1.15, math.pi * 1.85)
  elseif tipo == "engranaje" then
    love.graphics.circle("line", cx, cy, 3.2)
    love.graphics.circle("line", cx, cy, 6.5)
  elseif tipo == "usuario" then
    love.graphics.circle("line", cx, cy - 5, 4)
    love.graphics.arc("line", "open", cx, cy + 10, 7, math.pi * 1.12, math.pi * 1.88)
  elseif tipo == "candado" then
    love.graphics.rectangle("line", cx - 5, cy - 1, 10, 8, 2, 2)
    love.graphics.arc("line", "open", cx, cy - 1, 3.4, math.pi, 0)
  elseif tipo == "ojo" then
    love.graphics.ellipse("line", cx, cy, 7, 4.2)
    love.graphics.circle("fill", cx, cy, 1.7)
  elseif tipo == "ojo_off" then
    love.graphics.ellipse("line", cx, cy, 7, 4.2)
    love.graphics.line(cx - 7, cy + 5, cx + 7, cy - 5)
  elseif tipo == "espada" then
    love.graphics.line(cx, cy - 10, cx, cy + 3)
    love.graphics.line(cx - 5, cy + 1, cx + 5, cy + 1)
    love.graphics.line(cx, cy + 3, cx, cy + 9)
  elseif tipo == "gente" then
    love.graphics.circle("line", cx - 3, cy - 5, 2.8)
    love.graphics.circle("line", cx + 4, cy - 4, 2.3)
    love.graphics.arc("line", "open", cx - 2, cy + 7, 6, math.pi * 1.1, math.pi * 1.95)
  elseif tipo == "estrella" then
    local pts = {}
    for i = 0, 9 do
      local ang = -math.pi / 2 + i * math.pi / 5
      local rad = (i % 2 == 0) and 8 or 3.3
      pts[#pts + 1] = cx + math.cos(ang) * rad
      pts[#pts + 1] = cy + math.sin(ang) * rad
    end
    love.graphics.polygon("line", pts)
  elseif tipo == "corona" then
    love.graphics.polygon("line", cx - 9, cy + 5, cx - 9, cy - 3, cx - 4, cy + 2, cx, cy - 7, cx + 4, cy + 2, cx + 9, cy - 3, cx + 9, cy + 5)
  elseif tipo == "mas" then
    love.graphics.circle("line", cx - 2, cy - 3, 3.2)
    love.graphics.line(cx + 5, cy + 1, cx + 5, cy + 8)
    love.graphics.line(cx + 2, cy + 4.5, cx + 8, cy + 4.5)
  end
  love.graphics.setLineWidth(1)
end

local function imgPortada(nombre)
  I._imgPortada = I._imgPortada or {}
  if I._imgPortada[nombre] ~= nil then return I._imgPortada[nombre] or nil end
  local ruta = "arte/portada/" .. nombre
  if not love.filesystem.getInfo(ruta) then I._imgPortada[nombre] = false return nil end
  local img = love.graphics.newImage(ruta)
  img:setFilter("linear", "linear")
  I._imgPortada[nombre] = img
  return img
end

local function dibujarImagen(img, x, y, w, h)
  local iw, ih = img:getDimensions()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(img, x, y, 0, w / iw, h / ih)
end

local function dibujarBotonSkin(img, x, y, w, h)
  local iw, ih = img:getDimensions()
  if not I._quadBoton then
    local cap = math.floor(iw * 0.16)
    I._quadBoton = {
      love.graphics.newQuad(0, 0, cap, ih, iw, ih),
      love.graphics.newQuad(cap, 0, iw - cap * 2, ih, iw, ih),
      love.graphics.newQuad(iw - cap, 0, cap, ih, iw, ih),
      cap, iw, ih,
    }
  end
  local q = I._quadBoton
  local cw = math.min(w * 0.18, h * (q[4] / q[6]))
  love.graphics.draw(img, q[1], x, y, 0, cw / q[4], h / q[6])
  love.graphics.draw(img, q[2], x + cw, y, 0, (w - cw * 2) / (q[5] - q[4] * 2), h / q[6])
  love.graphics.draw(img, q[3], x + w - cw, y, 0, cw / q[4], h / q[6])
end

local function botonPortada(x, y, w, h, texto, id)
  local hover = sobre(x, y, w, h)
  local piel = imgPortada("boton.png")
  if piel then
    love.graphics.setColor(hover and 1 or 0.92, hover and 1 or 0.92, hover and 1 or 0.96, 1)
    dibujarBotonSkin(piel, x, y, w, h)
  else
    relleno(x, y, w, h, 9, { 0.20, 0.48, 0.96 }, { 0.10, 0.28, 0.72 }, 1)
  end
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf(texto, x, y + h / 2 - 9, w, "center")
  I.registrar(x, y, w, h, id)
end

-- Pantalla de entrada: paisaje, marca a la izquierda y tarjeta de cuenta a la derecha.
function I.portada(form, w, h, forzar)
  I.limpiar()
  form = form or { modo = "entrar", usuario = "", clave = "", error = "" }
  local modo = forzar or form.modo or "entrar"
  local ajustes = I.portadaPanel == "ajustes"
  local crear = modo == "crear" and not ajustes
  if love.filesystem.getInfo("arte/hojas/new-sprites/Titles1/Portada.jpg") then
    I.fondo("Titles1/Portada.jpg", w, h, 0.08)
  else
    I.fondo("Titles1/Castle.png", w, h, 0.28)
  end
  love.graphics.setColor(0.02, 0.05, 0.12, 0.22)
  love.graphics.rectangle("fill", 0, 0, w, 72)

  local margen = math.max(28, math.min(64, w * 0.045))
  local barra = 58
  love.graphics.setColor(0.03, 0.05, 0.12, 0.62)
  love.graphics.rectangle("fill", 0, 0, w, barra)
  love.graphics.setColor(0.78, 0.64, 0.32, 0.45)
  love.graphics.rectangle("fill", 0, barra - 1, w, 1)
  love.graphics.setFont(fuentePortada("marca", 15))
  love.graphics.setColor(0.95, 0.82, 0.42)
  love.graphics.polygon("fill", margen, 22, margen + 6, 29, margen, 36, margen - 6, 29)
  love.graphics.print("DOS CORONAS", margen + 16, 20)

  local nav = {
    { "casa", "Inicio", "portada_inicio", not ajustes },
    { "engranaje", "Ajustes", "portada_ajustes", ajustes },
  }
  local nx = w - margen - 240
  for _, n in ipairs(nav) do
    local hover = sobre(nx, 8, 112, 42)
    love.graphics.setColor(n[4] and 0.98 or (hover and 0.95 or 0.82), n[4] and 0.86 or 0.9, n[4] and 0.45 or 0.84)
    iconoPortada(n[1], nx + 16, 29)
    love.graphics.setFont(fuentePortada("nav", 16))
    love.graphics.print(n[2], nx + 30, 20)
    if n[4] then
      local ancho = fuentePortada("nav", 16):getWidth(n[2])
      love.graphics.setColor(0.93, 0.75, 0.28)
      love.graphics.rectangle("fill", nx + 30, 44, ancho, 2)
    end
    I.registrar(nx, 8, 112, 42, n[3])
    nx = nx + 118
  end

  local panel = imgPortada("panel.png")
  local tarjetaW = math.min(400, math.max(300, w * 0.3))
  local tarjetaH = tarjetaW * (panel and (select(2, panel:getDimensions()) / panel:getWidth()) or 1.12)
  if ajustes then tarjetaH = math.max(tarjetaH, 420) end
  if tarjetaH > h - 168 then
    tarjetaH = h - 168
    if panel and not ajustes then tarjetaW = tarjetaH * (panel:getWidth() / select(2, panel:getDimensions())) end
  end
  local tx = w - margen - tarjetaW
  local ty = math.max(barra + 18, math.min(h * 0.14, (h - tarjetaH) * 0.38))
  local colW = math.max(260, tx - margen - 48)

  local logo = imgPortada("logo.png")
  local bajo = barra + 44
  local anchoFrase = math.min(440, colW)
  if logo then
    local iw, ih = logo:getDimensions()
    local lw = math.min(colW, 480)
    local lh = lw * ih / iw
    local logoX = margen + (anchoFrase + 16 - lw) / 2
    love.graphics.setColor(0.04, 0.07, 0.12, 0.55)
    love.graphics.rectangle("fill", logoX + lw * 0.08, bajo + lh * 0.9, lw * 0.84, lh * 0.2, 10, 10)
    dibujarImagen(logo, logoX, bajo, lw, lh)
    bajo = bajo + lh + 56
  end
  love.graphics.setColor(0.03, 0.05, 0.1, 0.62)
  love.graphics.rectangle("fill", margen, bajo - 6, anchoFrase + 16, 56, 10, 10)
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(0.05, 0.04, 0.02, 0.9)
  love.graphics.printf("Dos reinos, un mismo destino.\nElige tu camino, escribe tu historia.", margen + 10, bajo + 1, anchoFrase, "left")
  love.graphics.setColor(1, 0.98, 0.93)
  love.graphics.printf("Dos reinos, un mismo destino.\nElige tu camino, escribe tu historia.", margen + 8, bajo, anchoFrase, "left")
  bajo = bajo + 58
  local iconos = imgPortada("iconos.png")
  if iconos then
    local iw, ih = iconos:getDimensions()
    local dw = math.min(colW, 440)
    local dh = dw * ih / iw
    love.graphics.setColor(0.03, 0.06, 0.1, 0.5)
    love.graphics.rectangle("fill", margen - 6, bajo + dh * 0.55, dw + 12, dh * 0.48, 10, 10)
    dibujarImagen(iconos, margen, bajo, dw, dh)
  end

  if panel then
    dibujarImagen(panel, tx, ty, tarjetaW, tarjetaH)
  else
    love.graphics.setColor(0.04, 0.07, 0.15, 0.9)
    love.graphics.rectangle("fill", tx, ty, tarjetaW, tarjetaH, 18, 18)
  end
  I.registrar(tx, ty, tarjetaW, tarjetaH, "panel")

  local borde = math.floor(tarjetaW * 0.09)
  local ix = tx + borde
  local iw = tarjetaW - borde * 2
  love.graphics.setFont(fuentePortada("marca", 16))
  love.graphics.setColor(0.95, 0.84, 0.48)
  local encabezado = ajustes and "AJUSTES" or (crear and "CREAR CUENTA" or "INICIAR SESIÓN")
  love.graphics.printf(encabezado, tx, ty + math.floor(tarjetaH * 0.1), tarjetaW, "center")

  local function pies()
    local band = imgPortada("bandera.png")
    if band then
      local bw0, bh0 = band:getDimensions()
      local bh = math.min(210, h * 0.3)
      dibujarImagen(band, 6, h - bh - 4, bh * bw0 / bh0, bh)
    end
    I.persona("guerrero", 118, h - 8, 1.05, "albor")
    I.persona("mago", w - 56, h - 8, 1.05, "umbra")
    love.graphics.setFont(I.fuente)
  end

  if ajustes then
    love.graphics.setFont(I.fuente)
    love.graphics.setColor(0.86, 0.88, 0.94)
    love.graphics.printf("Tamaño de la ventana", ix, ty + 96, iw, "left")
    botonPortada(ix, ty + 124, (iw - 12) / 2, 42, "1280×720", "aj_1280")
    botonPortada(ix + (iw + 12) / 2, ty + 124, (iw - 12) / 2, 42, "1600×900", "aj_1600")
    botonPortada(ix, ty + 176, iw, 44, Ajustes.completo and "Ventana" or "Pantalla completa", "aj_completo")
    botonPortada(ix, ty + 232, iw, 44, "Volver", "portada_inicio")
    botonPortada(ix, ty + 286, iw, 44, "Salir", "menu_salir")
    pies()
    return
  end

  local altoCampo = 44
  local function campo(etiqueta, valor, y, id, secreto, icono)
    love.graphics.setColor(0.05, 0.08, 0.16, 0.94)
    love.graphics.rectangle("fill", ix, y, iw, altoCampo, 8, 8)
    local foco = I.foco == id
    love.graphics.setColor(foco and 0.95 or 0.62, foco and 0.78 or 0.58, foco and 0.38 or 0.42, foco and 1 or 0.75)
    love.graphics.setLineWidth(1.4)
    love.graphics.rectangle("line", ix + 0.5, y + 0.5, iw - 1, altoCampo - 1, 8, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.78, 0.7, 0.48)
    iconoPortada(icono, ix + 22, y + altoCampo / 2)
    local muestra = (secreto and not form.verClave) and string.rep("•", #(valor or "")) or (valor or "")
    love.graphics.setFont(I.fuente)
    if muestra == "" and not foco then
      love.graphics.setColor(0.58, 0.62, 0.7)
      love.graphics.print(etiqueta, ix + 42, y + altoCampo / 2 - 9)
    else
      love.graphics.setColor(0.97, 0.98, 1)
      love.graphics.print(muestra .. (foco and "|" or ""), ix + 42, y + altoCampo / 2 - 9)
    end
    I.registrar(ix, y, secreto and (iw - 42) or iw, altoCampo, "foco_" .. id)
    if secreto and id == "clave" then
      love.graphics.setColor(0.75, 0.78, 0.86)
      iconoPortada(form.verClave and "ojo" or "ojo_off", ix + iw - 22, y + altoCampo / 2)
      I.registrar(ix + iw - 42, y, 42, altoCampo, "cuenta_ver")
    end
  end

  local y = ty + math.floor(tarjetaH * 0.16)
  local hueco = 14
  campo("Usuario", form.usuario, y, "usuario", false, "usuario")
  y = y + altoCampo + hueco
  campo("Contraseña", form.clave, y, "clave", true, "candado")
  if crear then
    y = y + altoCampo + hueco
    campo("Repite la contraseña", form.clave2, y, "clave2", true, "candado")
  end
  y = y + altoCampo + 18
  if not crear and form.error and form.error ~= "" and I._toastClave ~= form.error then
    I._toastClave = form.error
    I._toast = { texto = form.error, hasta = love.timer.getTime() + 4.2 }
  end
  local altoBtn = 46
  botonPortada(ix, y, iw, altoBtn, crear and "Crear cuenta" or "Entrar  →", "cuenta_ok")
  y = y + altoBtn + 8
  local sep = imgPortada("separador.png")
  if sep then
    local sw, sh = sep:getDimensions()
    local dw = math.min(iw * 0.72, 220)
    dibujarImagen(sep, ix + (iw - dw) / 2, y, dw, dw * sh / sw)
    y = y + 22
  else
    y = y + 8
  end
  if crear then
    botonPortada(ix, y, iw, altoBtn, "Ya tengo cuenta", "menu_entrar")
  else
    botonPortada(ix, y, iw, altoBtn, "Crear cuenta", "menu_registro")
    y = y + altoBtn + 6
    botonPortada(ix, y, iw, altoBtn, "Salir", "menu_salir")
    y = y + altoBtn + 4
    local hover = sobre(ix, y, iw, 22)
    love.graphics.setFont(fuentePortada("mini", 13))
    love.graphics.setColor(0.55, 0.78, 1, hover and 1 or 0.85)
    love.graphics.printf("Recuperar contraseña", ix, y, iw, "center")
    I.registrar(ix, y, iw, 22, "cuenta_recuperar")
  end

  pies()
  local aviso = I._toast
  if aviso and love.timer.getTime() < aviso.hasta then
    local queda = aviso.hasta - love.timer.getTime()
    local alfa = math.min(1, queda / 0.35)
    local f = fuentePortada("mini", 15)
    love.graphics.setFont(f)
    local tw = math.min(560, f:getWidth(aviso.texto) + 56)
    local x = (w - tw) / 2
    local yy = h - 72
    love.graphics.setColor(0.07, 0.05, 0.03, 0.94 * alfa)
    love.graphics.rectangle("fill", x, yy, tw, 42, 12, 12)
    love.graphics.setColor(0.93, 0.76, 0.34, alfa)
    love.graphics.setLineWidth(1.4)
    love.graphics.rectangle("line", x + 0.5, yy + 0.5, tw - 1, 41, 12, 12)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 0.97, 0.9, alfa)
    love.graphics.printf(aviso.texto, x + 16, yy + 12, tw - 32, "center")
    love.graphics.setFont(I.fuente)
  end
end

function I.menu(_, w, h)
  I.portada({ modo = "entrar", usuario = Ajustes.ultimoUsuario or "", clave = "", error = "" }, w, h, "entrar")
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
  I.persona(claseVista, 174, 360, 2.3, estado.faccion, nil, estado.genero)
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
  -- aspecto: hombre o mujer
  I.boton(48, 480, 122, 30, (estado.genero ~= "m") and "● Hombre" or "Hombre", "genero_h")
  I.boton(178, 480, 122, 30, (estado.genero == "m") and "● Mujer" or "Mujer", "genero_m")
  if not estado.clase then
    love.graphics.setColor(0.65, 0.62, 0.55)
    love.graphics.printf("El oficio cambia este dibujo.", 40, 520, 268, "center")
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
    I.persona(claseVista, x + 76, 220, 1.25, id, nil, estado.genero)
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

  -- los oficios de la facción elegida (Alba suma al lancero y Ocaso al nigromante)
  local clases = Datos.clasesDe(estado.faccion)
  local paso = math.min(230, math.floor(920 / #clases))
  local ancho = paso - 12
  for i, id in ipairs(clases) do
    local c = Datos.clases[id]
    local cx = 348 + (i - 1) * paso
    local elegida = estado.clase == id
    love.graphics.setColor(elegida and 0.16 or 0.08, elegida and 0.12 or 0.07, 0.08, 0.96)
    love.graphics.rectangle("fill", cx, 268, ancho, 250, 6, 6)
    love.graphics.setColor(elegida and 0.95 or 0.7, elegida and 0.78 or 0.6, 0.35, 1)
    love.graphics.rectangle("line", cx, 268, ancho, 250, 6, 6)
    love.graphics.setColor(0.95, 0.9, 0.75)
    love.graphics.printf(c.nombre, cx, 278, ancho, "center")
    I.persona(id, cx + ancho / 2, 400, 1.15, estado.faccion, nil, estado.genero)
    love.graphics.setColor(0.75, 0.72, 0.64)
    love.graphics.printf(c.rol, cx + 8, 414, ancho - 16, "center")
    I.boton(cx + 12, 472, ancho - 24, 30, elegida and "Oficio elegido" or "Elegir", "clase_" .. id)
  end

  caja(348, h - 92, 620, 76, "3. Nombre")
  love.graphics.setColor(0.11, 0.15, 0.28)
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
I.LADO = 0
I.CONSOLA = 0          -- la vista del mundo ocupa toda la pantalla: el chat va encima, abajo a la izquierda
I.CHAT_ALTO = 150      -- alto del chat
I.CHAT_ANCHO = 0.30    -- ancho del chat: el 30 % de la pantalla

function I.medidas()
  return I.LADO, I.CONSOLA
end

local function marco(x, y, w, h, hundido)
  love.graphics.setColor(0, 0, 0, 0.22)
  love.graphics.rectangle("fill", x, y + 2, w, h, 8, 8)
  love.graphics.setColor(TEMA.fondo[1], TEMA.fondo[2], TEMA.fondo[3], hundido and 0.82 or 0.94)
  love.graphics.rectangle("fill", x, y, w, h, 8, 8)
  love.graphics.setColor(TEMA.borde[1], TEMA.borde[2], TEMA.borde[3], hundido and 0.7 or 0.95)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 8, 8)
  love.graphics.setColor(1, 1, 1, 0.05)
  love.graphics.rectangle("line", x + 2.5, y + 2.5, w - 5, h - 5, 6, 6)
end

local function casilla(x, y, lado)
  love.graphics.setColor(0.04, 0.06, 0.13, 0.95)
  love.graphics.rectangle("fill", x, y, lado, lado, 5, 5)
  love.graphics.setColor(0.27, 0.38, 0.68, 0.9)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, lado - 1, lado - 1, 5, 5)
  love.graphics.setColor(1, 1, 1, 0.04)
  love.graphics.rectangle("fill", x + 1, y + 1, lado - 2, (lado - 2) / 2, 4, 4)
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
  local rad = math.min(6, h / 2)
  love.graphics.setColor(0.02, 0.03, 0.08, 0.92)
  love.graphics.rectangle("fill", x, y, w, h, rad, rad)
  if frac > 0.002 then
    local ancho = math.max(rad * 2, (w - 2) * math.min(1, frac))
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", x + 1, y + 1, ancho, h - 2, rad, rad)
    love.graphics.stencil(function() love.graphics.rectangle("fill", x + 1, y + 1, ancho, h - 2, rad, rad) end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    brillo(x + 1, y + 1, ancho, (h - 2) * 0.6, 1, 1, 1, 0.32)
    love.graphics.setStencilTest()
  end
  love.graphics.setColor(0.35, 0.5, 0.9, 0.5)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, rad, rad)
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
  if it.calidad then
    -- piezas de calidad: marco y halo del color de su clase (azul = buena, dorado que pulsa = definitiva)
    local c = it.calidad == "definitiva" and { 1, 0.82, 0.3 } or { 0.45, 0.72, 1 }
    local a = it.calidad == "definitiva" and (0.55 + 0.25 * math.sin(love.timer.getTime() * 4.5)) or 0.5
    love.graphics.setBlendMode("add")
    love.graphics.setColor(c[1], c[2], c[3], a * 0.45)
    love.graphics.rectangle("fill", x + 1, y + 1, lado - 2, lado - 2, 5, 5)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(c[1], c[2], c[3], a + 0.25)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x + 1, y + 1, lado - 2, lado - 2, 5, 5)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
  end
  Atlas.dibujar(it.hoja, it.sprite, x + lado / 2, y + lado / 2 + 8 * e, e, 16, 16, it.tinte)
  enc = enc or slot.enc
  if enc and enc > 0 then texto("+" .. enc, x + 2, y + 1, { 0.6, 0.95, 1 }) end
  return it
end

-- Iconos del HUD dibujados por código (arte/hud/*.png), con filtro suave.
local ICONOS_HUD = {}
function I.iconoHud(nombre)
  local im = ICONOS_HUD[nombre]
  if im == nil then
    local ruta = "arte/hud/" .. nombre .. ".png"
    if love.filesystem.getInfo(ruta) then
      im = love.graphics.newImage(ruta, { mipmaps = true })
      im:setFilter("linear", "linear")
    else
      im = false
    end
    ICONOS_HUD[nombre] = im
  end
  return im or nil
end

function I.hud(mundo, p, w, h)
  I.limpiar()
  I.pista = nil
  if p.modo ~= "casa" then
    I.muebleSel = nil
    if I.panel == "casa" then I.panel = nil end
  end
  Dibujo.muebleElegido = p.modo == "casa" and I.muebleSel or nil
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
  local nPod = #barraP                            -- 6 poderes (10 el mago)
  local lado_c, sep = (nPod > 6 and 50 or 46), 4
  -- la barra (los poderes y las 2 pociones) va centrada en la pantalla, de 6 en 6 por fila (con 10 poderes: 6 arriba y 4 + las 2 pociones abajo);
  -- los accesos (poderes, mall, monturas, mascotas, autopoción) van abajo a la derecha
  local COLS = 6
  local nCas = nPod + 2
  local filasB = math.ceil(nCas / COLS)
  local bx0 = vw / 2 - (COLS * lado_c + (COLS - 1) * sep) / 2
  local by0 = vh - lado_c - 10                      -- fila de abajo
  local function cas(k)                              -- esquina de la casilla k (poderes y luego pociones), de arriba abajo y de izquierda a derecha
    local fila, col = math.floor((k - 1) / COLS), (k - 1) % COLS
    return bx0 + col * (lado_c + sep), by0 - (filasB - 1 - fila) * (lado_c + sep)
  end
  local ytope = by0 - (filasB - 1) * (lado_c + sep)  -- borde de arriba de la barra
  local orden = Ajustes.orden(p.clase)
  local teclas = Ajustes.teclas
  for i = 1, nPod do
    local slotReal = orden[i]
    local hid = barraP[slotReal]
    local rangoH = Arbol.rango(p, hid)
    local conocida = rangoH > 0
    local hdef = Arbol.efectiva(hid, math.max(1, rangoH))
    local x, by0 = cas(i)
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
    local tk = Ajustes.nombreTecla(teclas["poder" .. i])
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", x + 2, by0 + 2, f:getWidth(tk) + 6, 16, 3, 3)         -- (fondo oscuro tras la tecla para leerla sobre cualquier icono)
    texto(tk, x + 5, by0 + 2, { 1, 0.9, 0.5 }, f)
    if not conocida then
      if p.mobaNiveles and p.modo == "moba" then
        -- asedio: el poder se desbloquea con el nivel de la partida
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", x + 1, by0 + 1, lado_c - 2, lado_c - 2, 4, 4)
        local t = "Nv " .. (p.mobaNiveles[slotReal] or "?")
        texto(t, x + lado_c / 2 - f:getWidth(t) / 2, by0 + lado_c / 2 - 7, { 1, 0.82, 0.4 }, f)
      else
        texto("K", x + 4, by0 + lado_c - 16, { 1, 0.5, 0.4 }, f)
      end
    elseif rangoH > 1 then
      texto(tostring(rangoH), x + lado_c - f:getWidth(tostring(rangoH)) - 3, by0 + lado_c - 16, { 1, 0.85, 0.3 }, f)
    end
    I.registrar(x, by0, lado_c, lado_c, "hab_" .. slotReal)
    if sobre(x, by0, lado_c, lado_c) then
      local rango = ""
      if hdef.coef then
        local magico = hdef.dano == "magico"
        local a, b = Balance.rangoDano(magico and (p.matk or 0) or (p.atk or 0), 0, hdef.coef)
        rango = "Daño " .. (magico and "mágico " or "físico ") .. a .. "-" .. b .. ". "
      end
      I.pista = hdef.nombre .. (conocida and (" (rango " .. rangoH .. ")") or ((p.mobaNiveles and p.modo == "moba") and (" — se desbloquea en el nivel " .. (p.mobaNiveles[slotReal] or "?") .. " de la partida") or " — sin aprender (K)")) ..
        " — " .. (hdef.mana or 0) .. " de maná, " .. string.format("%.1f", hdef.cd or 0) .. " s. " .. rango .. (hdef.desc or "") .. " (Arrástralo a otra casilla para cambiarlo de sitio.)"
    end
  end
  -- arrastre de un poder: su icono sigue al ratón y la casilla de destino se resalta
  local ah = I.arrastreHab
  if ah and ah.movido >= 6 then
    local mx, my = love.mouse.getPosition()
    local esc = I.escala or 1
    mx, my = mx / esc, my / esc
    for i = 1, nPod do
      local x, by0 = cas(i)
      if sobre(x, by0, lado_c, lado_c) and orden[i] ~= ah.slot then
        love.graphics.setColor(1, 0.85, 0.3, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, by0, lado_c, lado_c, 5, 5)
        love.graphics.setLineWidth(1)
      end
    end
    love.graphics.setColor(1, 1, 1, 0.9)
    Efectos.icono(barraP[ah.slot], mx - 20, my - 20, 40)
  end
  -- estados que sufres, sobre la barra de poderes, con los segundos que quedan
  do
    local lista = {}
    for tipo, resta in pairs(p.estadosResta or {}) do lista[#lista + 1] = { tipo = tipo, resta = resta } end
    table.sort(lista, function(a, b) return a.tipo < b.tipo end)
    for i, s in ipairs(lista) do
      local def = Estados.def[s.tipo]
      local x = bx0 + (i - 1) * 36
      local y = ytope - 38
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
    -- potenciadores propios (escudo arcano, furia, grito...): a continuación, con borde verde y una barra que se vacía
    for j, b in ipairs(p.buffsResta or {}) do
      local x = bx0 + (#lista + j - 1) * 36
      local y = ytope - 38
      local hdef = b.hab and Datos.habilidades[b.hab]
      local nombre = hdef and hdef.nombre or b.id
      love.graphics.setColor(0.06, 0.1, 0.08, 0.92)
      love.graphics.rectangle("fill", x, y, 32, 32, 4, 4)
      love.graphics.setColor(0.45, 0.95, 0.55, 1)
      love.graphics.rectangle("line", x, y, 32, 32, 4, 4)
      Efectos.icono(Efectos.def[b.hab or ""] and b.hab or b.id, x + 2, y + 2, 28)
      local frac = math.max(0, math.min(1, b.resta / math.max(0.1, b.max or b.resta)))
      love.graphics.setColor(0, 0, 0, 0.7)
      love.graphics.rectangle("fill", x + 2, y + 29, 28, 3)
      love.graphics.setColor(0.45, 0.95, 0.55, 1)
      love.graphics.rectangle("fill", x + 2, y + 29, 28 * frac, 3)
      local t = string.format("%d", math.ceil(b.resta))
      texto(t, x + 32 - f:getWidth(t) - 2, y + 15, { 1, 1, 1 }, f)
      if sobre(x, y, 32, 32) then I.pista = nombre .. ": " .. t .. " s" end
    end
  end
  local function pocion(tipo, slotIdx, etiqueta, cuenta)
    local x, by0 = cas(slotIdx)
    casilla(x, by0, lado_c)
    local id = Datos.pocionAlUsar(p.bolsa, p.nivel, tipo)
    local it = Datos.item(id)
    local n = Datos.contarPociones(p.bolsa, tipo)
    love.graphics.setColor(1, 1, 1, n > 0 and 1 or 0.35)
    if it then Atlas.dibujar(it.hoja, it.sprite, x + lado_c / 2, by0 + lado_c / 2 + 8, 1.2, 16, 16) end
    -- cada poción tiene su enfriamiento (3 s)
    local queda = ((p.cdPociones or {})[id] or 0) - mundo.tiempo
    if queda > 0 then
      local frac = math.min(1, queda / 3)
      love.graphics.setColor(0, 0, 0, 0.6)
      love.graphics.rectangle("fill", x + 1, by0 + 1 + (lado_c - 2) * (1 - frac), lado_c - 2, (lado_c - 2) * frac)
      local cuenta = string.format("%.1f", queda)
      texto(cuenta, x + lado_c / 2 - f:getWidth(cuenta) / 2, by0 + lado_c / 2 - 8, { 1, 1, 1 }, f)
    end
    texto(etiqueta, x + 4, by0 + 2, { 1, 0.9, 0.5 }, f)
    texto(tostring(n), x + lado_c - f:getWidth(tostring(n)) - 4, by0 + lado_c - 16, { 1, 1, 1 }, f)
    local auto = (tipo == "vida" and p.autoPocion) or (tipo == "mana" and p.autoMana)
    if auto then
      local c = tipo == "vida" and { 0.45, 0.95, 0.55 } or { 0.45, 0.75, 1 }
      love.graphics.setColor(c[1], c[2], c[3], 0.95)
      love.graphics.rectangle("line", x + 2, by0 + 2, lado_c - 4, lado_c - 4, 3, 3)
    end
    I.registrar(x, by0, lado_c, lado_c, cuenta)
    if sobre(x, by0, lado_c, lado_c) and it then
      local umbral = tipo == "vida" and (p.autoPocionUmbral or 0.5) or (p.autoManaUmbral or 0.5)
      local pct = math.floor(umbral * 100 + 0.5)
      local estado = auto and ("activa bajo el " .. pct .. "%") or "apagada"
      I.pista = it.nombre .. " (" .. n .. " en la bolsa). Autopoción " .. estado .. ". Se configura con R."
    end
  end
  pocion("vida", nPod + 1, Ajustes.nombreTecla(teclas.pocion_vida), "poc_vida")
  pocion("mana", nPod + 2, Ajustes.nombreTecla(teclas.pocion_mana), "poc_mana")
  -- accesos abajo a la derecha: poderes (K), Item Mall (L), monturas (U), mascotas (N) y autopoción (R)
  do
    local lado, sepA = 44, 6
    local ax = vw - 5 * lado - 4 * sepA - 10
    local ay = vh - lado - 10
    local puntos = Arbol.puntos(p)
    local libre = false
    for _, id in ipairs(p.monturas or {}) do
      local dm = Monturas.especies[id]
      if dm and not dm.requiereOficio then libre = true end
    end
    local accesos = {
      { "hud_arbol", "poderes", "K", "Árbol de poderes (K): " .. puntos .. " punto(s) por gastar.", puntos > 0 },
      { "hud_mall", "mall", "L", "Item Mall (L): monedas, addons, bonos y monturas exclusivas.", false },
      { "hud_monturas", "monturas", "U", p.montado and "Colección de monturas (U). Montado: O para bajar." or "Colección de monturas (U). O monta y desmonta.", p.montado ~= nil },
      { "hud_mascotas", "mascotas", "N", (p.mascotaActiva or p.recolectoraActiva) and "Tus mascotas (N): invócalas o guárdalas desde la lista; pueden salir a la vez una de ataque y una recolectora." or "Tus mascotas (N): invócalas, guárdalas y mira cómo evolucionan.", (p.mascotaActiva or p.recolectoraActiva) ~= nil },
      { "hud_autopocion", "autopocion", "R", "Autopoción (R): bebe sola la vida o el maná al bajar de un umbral.", (p.autoPocion or p.autoMana) and true or false },
    }
    for i, a in ipairs(accesos) do
      local x = ax + (i - 1) * (lado + sepA)
      local hover = sobre(x, ay, lado, lado)
      -- fondo de cristal redondo, como el resto de botones del HUD
      love.graphics.setColor(0.07, 0.1, 0.22, 0.88)
      love.graphics.circle("fill", x + lado / 2, ay + lado / 2, lado / 2)
      local brilla = a[5]
      local pulso = (a[1] == "hud_arbol" and brilla) and (0.5 + 0.5 * math.sin(love.timer.getTime() * 4)) or 0
      if brilla then love.graphics.setColor(0.45 + 0.4 * pulso, 0.85, 0.5, 0.95); if a[1] == "hud_arbol" then love.graphics.setColor(1, 0.82 + 0.1 * pulso, 0.3, 0.95) end
      else love.graphics.setColor(hover and 0.55 or 0.3, hover and 0.7 or 0.44, hover and 1 or 0.82, 0.95) end
      love.graphics.setLineWidth(2)
      love.graphics.circle("line", x + lado / 2, ay + lado / 2, lado / 2 - 1)
      love.graphics.setLineWidth(1)
      local img = I.iconoHud(a[2])
      love.graphics.setColor(1, 1, 1, hover and 1 or 0.93)
      if img then love.graphics.draw(img, x + lado / 2, ay + lado / 2, 0, (lado - 8) / img:getWidth(), (lado - 8) / img:getHeight(), img:getWidth() / 2, img:getHeight() / 2) end
      texto(a[3], x + lado - 10, ay + lado - 14, { 1, 0.9, 0.5 }, f)
      if a[1] == "hud_arbol" and puntos > 0 then texto("+" .. puntos, x + 1, ay - 2, { 1, 0.85, 0.3 }, f) end
      if a[1] == "hud_monturas" and p.montado and p.job and p.monturaHpMax and p.monturaHpMax > 0 then
        local frac = math.max(0, math.min(1, (p.monturaHp or 0) / p.monturaHpMax))
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", x, ay - 9, lado, 6, 3, 3)
        love.graphics.setColor(0.95, 0.6, 0.2, 1)
        love.graphics.rectangle("fill", x + 1, ay - 8, math.max(0, (lado - 2) * frac), 4, 2, 2)
        if sobre(x, ay - 9, lado, 6) then I.pista = "Vida de la montura: " .. (p.monturaHp or 0) .. " / " .. p.monturaHpMax end
      end
      I.registrar(x, ay, lado, lado, a[1])
      if hover then I.pista = a[4] end
    end
  end

  -- Avisos de guerra (centro arriba)
  if p.colaGuerra and p.modo ~= "batalla" and p.modo ~= "estandarte" and p.modo ~= "moba" then I.hudCola(mundo, p, vw) end
  -- oficio, carga, montura y búsqueda
  I.estadoOficio(mundo, p, 8, 98)
  I.marquesina(mundo, p, vw, love.timer.getDelta())
  I.estadoBonos(mundo, p, 252, 8)
  if p.modo == "casa" and I.muebleSel and Datos.muebles[I.muebleSel] then
    local t = Datos.muebles[I.muebleSel].nombre .. " elegido. Clic en el suelo para moverlo. Clic derecho para rotarlo."
    love.graphics.setFont(f)
    local tw = f:getWidth(t)
    love.graphics.setColor(0.08, 0.06, 0.03, 0.82)
    love.graphics.rectangle("fill", 16, vh - 36, tw + 16, 24, 4, 4)
    love.graphics.setColor(1, 0.92, 0.55, 1)
    love.graphics.print(t, 24, vh - 32)
  end
  -- marco del grupo y su invitación
  I.estadoGrupo(mundo, p, vw - 198, 176)
  if p.modo == "batalla" or p.modo == "estandarte" or p.modo == "moba" then I.hudEvento(mundo, p, vw, vh) end

  I.consola(mundo, p, 0, vh - I.CHAT_ALTO, math.max(300, math.floor(vw * I.CHAT_ANCHO)), I.CHAT_ALTO)
  I.flotantes(mundo, p, vw, vh)

  -- el comercio se abre solo cuando empieza un trato y se cierra cuando termina
  if p.sesion then
    if I.comSesionAbierta ~= p.sesion then
      I.comSesionAbierta, I.panel, I.comScrollA, I.comScrollB = p.sesion, "comercio", 0, 0
    end
  elseif I.comSesionAbierta then
    I.comSesionAbierta = nil
    if I.panel == "comercio" then I.panel = nil end
    if I.foco == "com_oro" then I.foco = nil end
  end
  if I.panel == "bolsa" then I.panelBolsa(mundo, p, vw, h)
  elseif I.panel == "equipo" then I.panelEquipo(mundo, p, vw, h)
  elseif I.panel == "arbol" then I.panelArbol(mundo, p, vw, h)
  elseif I.panel == "encantar" then I.panelEncantar(mundo, p, vw, h)
  elseif I.panel == "mascotas" then I.panelMascotas(mundo, p, vw, h)
  elseif I.panel == "gremio" then I.panelGremio(mundo, p, vw, h)
  elseif I.panel == "oficios" then I.panelOficios(mundo, p, vw, h)
  elseif I.panel == "mercancias" then I.panelMercancias(mundo, p, vw, h)
  elseif I.panel == "establo" then I.panelEstablo(mundo, p, vw, h)
  elseif I.panel == "viaje" then I.panelViaje(mundo, p, vw, h)
  elseif I.panel == "montura" then I.panelMontura(mundo, p, vw, h)
  elseif I.panel == "mall" then I.panelMall(mundo, p, vw, h)
  elseif I.panel == "diaria" then I.panelDiaria(mundo, p, vw, h)
  elseif I.panel == "subastas" then I.panelSubastas(mundo, p, vw, h)
  elseif I.panel == "grupo" then I.panelGrupo(mundo, p, vw, h)
  elseif I.panel == "mercado" then I.panelMercado(p, vw, h)
  elseif I.panel == "comercio" then I.panelComercio(mundo, p, vw, h)
  elseif I.panel == "guerra" then I.panelGuerra(mundo, p, vw, h)
  elseif I.panel == "vivienda" then I.panelVivienda(mundo, p, vw, h)
  elseif I.panel == "misiones" then I.panelMisiones(mundo, p, vw, h)
  elseif I.panel == "diario" then I.panelDiario(mundo, p, vw, h)
  elseif I.panel == "mapa" then I.panelMapa(mundo, p, w, h)
  elseif I.panel == "ayuda" then I.panelAyuda(vw, h)
  elseif I.panel == "casa" then I.panelCasa(p, vw, h)
  elseif I.panel == "menu" then I.jugadorMenu = p I.panelPausa(vw, h)
  elseif I.panel == "ajustes" then I.panelAjustes(vw, h)
  elseif I.panel == "teclado" then I.panelTeclado(vw, h)
  elseif I.panel == "autopocion" then I.panelAutopocion(p, vw, h)
  end
  if I.menuJugador then I.dibujarMenuJugador(mundo, p, vw, h) end
  -- invitaciones (comercio, gremio, grupo): una alerta encima de todo con Aceptar y Rechazar
  if p.invComercio then
    I.alerta("Invitación de comercio", p.invComercio.de .. " quiere comerciar contigo.",
      p.invComercio.hasta - mundo.tiempo, "com_acepta", "com_rechaza", vw, h)
  elseif p.invGremio then
    I.alerta("Invitación a un gremio", p.invGremio.de .. " te invita al gremio " .. (p.invGremio.nombre or "") .. ".",
      p.invGremio.hasta and (p.invGremio.hasta - mundo.tiempo) or nil, "gr_acepta", "gr_rechaza", vw, h)
  elseif p.invGrupo then
    I.alerta("Invitación a un grupo", p.invGrupo.nombre .. " te invita a su grupo.", nil, "gp_acepta", "gp_rechaza", vw, h)
  end
  -- ayuda común: aviso de interacción ([E] ...); los mensajes del sistema van al chat
  if not I.panel and not I.foco then Ayudas.dibujarInteraccion(mundo, p, vw, vh, f) end
  if I.pista and I.pista ~= "" then
    local s = I.escala or 1
    local mx, my = love.mouse.getPosition()
    mx, my = mx / s + 14, my / s + 14
    local ancho = 260
    local _, lineas = f:getWrap(I.pista, ancho - 16)
    local alto = #lineas * f:getHeight() + 12
    if mx + ancho > w then mx = w - ancho - 4 end
    if my + alto > h then my = h - alto - 4 end
    love.graphics.setColor(0.05, 0.07, 0.15, 0.97)
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
  ["local"] = { 0.95, 0.95, 0.9 }, gremio = { 0.45, 0.95, 0.55 }, grupo = { 0.55, 0.8, 1 },
}

-- Fija el desplazamiento del chat según la altura del ratón sobre la barra (arriba = lo más antiguo).
function I.chatDesdeRaton(my)
  local b = I.chatBarra
  if not b or not I.chatMax or I.chatMax <= 0 then return end
  local esc = I.escala or 1
  local f = (my / esc - b.y - b.th / 2) / math.max(1, b.h - b.th)
  f = math.max(0, math.min(1, f))
  I.chatScroll = math.floor((1 - f) * I.chatMax + 0.5)
end

function I.consola(mundo, p, x, y, w, h)
  local f = pequena()
  love.graphics.setFont(f)
  -- El fondo se registra primero: lo que se registra después (pestañas, entrada
  -- de chat) queda por encima y recibe los clics.
  I.registrar(x, y, w, h, "panel")
  -- pestañas como iconos (el nombre sale al pasar el ratón); índices en la hoja "hud"
  local canales = { { "todo", "Todo", 4 }, { "mundo", "Mundo", 5 }, { "faccion", "Facción", 6 }, { "sistema", "Sistema", 7 },
    { "gremio", "Gremio", 8 }, { "grupo", "Grupo", 9 }, { "evento", "Eventos", 10 } }
  for i, c in ipairs(canales) do
    local bw = 44
    local bx = x + 8 + (i - 1) * (bw + 4)
    local activo = I.canal == c[1]
    local hover = sobre(bx, y + 2, bw, 22)
    if hover then I.pista = "Chat: " .. c[2] end
    love.graphics.setColor(activo and 0.27 or (hover and 0.16 or 0.09), activo and 0.4 or (hover and 0.24 or 0.13), activo and 0.8 or (hover and 0.45 or 0.27), 0.95)
    love.graphics.rectangle("fill", bx, y + 2, bw, 22, 6, 6)
    love.graphics.setColor(activo and 0.7 or 0.45, activo and 0.8 or 0.6, 0.95)
    love.graphics.rectangle("line", bx + 0.5, y + 2.5, bw - 1, 21, 6, 6)
    love.graphics.setColor(1, 1, 1, activo and 1 or 0.85)
    Atlas.dibujar("hud", c[3], bx + bw / 2, y + 13, 0.62, 16, 16)
    if c[1] == "sistema" and I.sistemaNuevo and not activo then
      love.graphics.setColor(1, 0.3, 0.25, 1)
      love.graphics.circle("fill", bx + bw - 7, y + 6, 4)
      love.graphics.setColor(1, 1, 1, 0.9)
      love.graphics.circle("line", bx + bw - 7, y + 6, 4)
    end
    I.registrar(bx, y + 2, bw, 22, "canal_" .. c[1])
  end
  local cy = y + 26
  local ch = h - 26
  love.graphics.setColor(0.04, 0.06, 0.13, 0.62)      -- el chat va sobre el mundo: se ve a través
  love.graphics.rectangle("fill", x, cy, w, ch)
  love.graphics.setColor(0.3, 0.44, 0.82)
  love.graphics.line(x, cy + 0.5, x + w, cy + 0.5)
  local lineas = {}
  local nuevoSistema = false
  for _, m in ipairs(mundo.mensajes) do
    local ver = m.canal == "sistema" or m.canal == "mundo"
    if m.canal == "faccion" and m.faccion == p.faccion then ver = true end
    if m.canal == "gremio" or m.canal == "grupo" then ver = true end -- el servidor solo manda los tuyos
    if m.canal == "local" and m.modo == p.modo then ver = true end
    if I.canal == "evento" then ver = m.evento == true
    elseif I.canal == "todo" and m.canal == "sistema" then ver = false   -- los avisos del sistema solo van en su pestaña
    elseif I.canal ~= "todo" and m.canal ~= I.canal then ver = false end
    -- punto en la pestaña del sistema cuando llega algo mientras miras otra
    if m.canal == "sistema" and m.id then
      if I.canal == "sistema" then I.sistemaVisto = math.max(I.sistemaVisto or 0, m.id)
      elseif ver or I.canal ~= "sistema" then
        if m.id > (I.sistemaVisto or 0) and (m.para == nil or m.para == p.id) then nuevoSistema = true end
      end
    end
    if ver then lineas[#lineas + 1] = m end
  end
  I.sistemaNuevo = nuevoSistema
  local entrada = 24
  local areaH = ch - entrada - 6
  local fh = f:getHeight()
  local ly = cy + areaH + 2
  -- la rueda del ratón sobre el chat recorre lo escrito desde que entraste (I.chatScroll = mensajes por encima del último)
  I.consolaRect = { x = x, y = cy, w = w, h = ch }
  I.chatScroll = math.max(0, math.min(I.chatScroll or 0, math.max(0, #lineas - 1)))
  if I.chatMax and I.chatScroll > I.chatMax and I.chatMax > 0 then I.chatScroll = I.chatMax end
  local dibujadas = 0
  for i = #lineas - I.chatScroll, 1, -1 do
    local m = lineas[i]
    local c = COLOR_CANAL[m.canal] or COLOR_CANAL["local"]
    local pref = m.canal == "sistema" and "" or (m.de .. ": ")
    local etiqueta = m.canal == "sistema" and "" or ((m.canal == "mundo" and "[Mundo] ") or (m.canal == "faccion" and "[Facción] ") or (m.canal == "gremio" and "[Gremio] ") or (m.canal == "grupo" and "[Grupo] ") or "")
    local _, partes = f:getWrap(etiqueta .. pref .. m.texto, w - 16)
    local alto = #partes * fh
    ly = ly - alto
    if ly < cy + 2 then break end
    love.graphics.setColor(c[1], c[2], c[3])
    love.graphics.printf(etiqueta .. pref .. m.texto, x + 8, ly, w - 16, "left")
    dibujadas = dibujadas + 1
  end
  -- barra de desplazamiento: aparece cuando hay más mensajes de los que caben; se arrastra o se pulsa en la pista
  I.chatMax = math.max(0, #lineas - math.max(1, dibujadas))
  local barra = nil
  if I.chatMax > 0 then
    local bx, by, bh = x + w - 10, cy + 3, areaH - 2
    local th = math.max(18, bh * math.max(1, dibujadas) / #lineas)
    local ty = by + (bh - th) * (1 - math.min(I.chatScroll, I.chatMax) / I.chatMax)
    love.graphics.setColor(1, 1, 1, 0.07)
    love.graphics.rectangle("fill", bx, by, 6, bh, 3, 3)
    local activo = I.chatArrastre or sobre(bx - 4, by, 14, bh)
    love.graphics.setColor(0.45, 0.6, 0.95, activo and 0.95 or 0.6)
    love.graphics.rectangle("fill", bx, ty, 6, th, 3, 3)
    I.chatBarra = { x = bx - 6, y = by, w = 18, h = bh, th = th }
    I.registrar(bx - 6, by, 18, bh, "chat_barra")
  else
    I.chatBarra = nil
  end
  if I.chatScroll > 0 then
    love.graphics.setColor(1, 0.85, 0.4, 0.9)
    love.graphics.printf("↓ rueda para volver a lo último (" .. I.chatScroll .. ")", x + 8, cy + 3, w - 16, "right")
  end
  local ey = cy + ch - entrada
  love.graphics.setColor(0.09, 0.12, 0.23)
  love.graphics.rectangle("fill", x + 6, ey, w - 12, entrada - 4, 2, 2)
  love.graphics.setColor(0.3, 0.44, 0.82)
  love.graphics.rectangle("line", x + 6.5, ey + 0.5, w - 13, entrada - 5, 2, 2)
  local muestra = I.foco == "chat" and I.texto or "Enter para hablar  ·  /m mundo  ·  /f facción  ·  /g gremio  ·  /p grupo"
  love.graphics.setColor(I.foco == "chat" and 1 or 0.6, I.foco == "chat" and 0.95 or 0.58, I.foco == "chat" and 0.8 or 0.5)
  love.graphics.print(muestra .. (I.foco == "chat" and "_" or ""), x + 12, ey + 2)
  I.registrar(x + 6, ey, w - 12, entrada - 4, "foco_chat")
  love.graphics.setFont(I.fuente)
end

-- Iconos de los PNJ para los mapas: forma y color según lo que hacen.
local ICONO_NPC = {
  mercado = { "circulo", { 1, 0.85, 0.2 }, "Enfermera (pociones)" },
  maestro_guerrero = { "cuadrado", { 0.75, 0.78, 0.85 }, "Maestro guerrero (equipo de guerrero)" },
  maestro_lancero = { "cuadrado", { 0.7, 0.85, 0.95 }, "Maestro lancero (equipo de lancero)" },
  maestro_cazador = { "cuadrado", { 0.55, 0.85, 0.45 }, "Maestro arquero (equipo de cazador)" },
  maestro_mago = { "cuadrado", { 0.6, 0.5, 0.95 }, "Maestro mago (equipo de mago)" },
  maestro_clerigo = { "cuadrado", { 1, 0.95, 0.6 }, "Maestro clérigo (equipo de clérigo)" },
  maestro_nigromante = { "cuadrado", { 0.65, 0.3, 0.7 }, "Maestro nigromante (equipo de nigromante)" },
  barquero = { "rombo", { 0.4, 0.8, 1 }, "Barquero (viajes entre continentes)" },
  comercio = { "cuadrado", { 0.95, 0.55, 0.2 }, "Mercader mayor (mercancías)" },
  heraldo = { "triangulo", { 0.95, 0.3, 0.3 }, "Heraldo (guerra)" },
  mayordomo = { "cuadrado", { 0.85, 0.75, 0.55 }, "Mayordomo (casas)" },
  encargos = { "rombo", { 1, 1, 0.55 }, "Encargos" },
  encantador = { "estrella", { 0.78, 0.45, 1 }, "Maestro de encantos" },
  gremio = { "cuadrado", { 0.4, 0.62, 1 }, "Escribano del gremio" },
  oficios = { "rombo", { 0.4, 0.92, 0.92 }, "Maestro de oficios" },
  establo = { "triangulo", { 0.72, 0.52, 0.3 }, "Establo (monturas)" },
  capitan = { "rombo", { 0.2, 0.85, 0.5 }, "Capitán de cazadores" },
  contacto = { "triangulo", { 0.85, 0.12, 0.2 }, "Contacto de ladrones" },
  subastas = { "estrella", { 1, 0.75, 0.15 }, "Casa de subastas" },
  misiones = { "rombo", { 1, 0.85, 0.2 }, "Misiones (cazar, recolectar y entregar)" },
}
I.ICONO_NPC = ICONO_NPC
I.ORDEN_ICONOS = { "mercado", "maestro_guerrero", "maestro_lancero", "maestro_cazador", "maestro_mago", "maestro_clerigo", "maestro_nigromante", "establo", "comercio", "heraldo", "mayordomo", "encargos", "encantador", "gremio", "oficios", "barquero", "capitan", "contacto", "subastas", "misiones" }

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

-- Icono de una puerta de mazmorra: arco de cueva violeta con el interior oscuro (r = tamaño).
function I.iconoMazmorra(x, y, r)
  local function arco(modo, k)
    local w, h = r * 1.1 * k, r * 1.3 * k
    love.graphics.rectangle(modo, x - w, y - h * 0.15, w * 2, h * 1.15)
    love.graphics.circle(modo, x, y - h * 0.15, w, 16)
  end
  love.graphics.setColor(0, 0, 0, 0.9)
  arco("fill", 1.4)
  love.graphics.setColor(0.75, 0.45, 1, 1)
  arco("fill", 1)
  love.graphics.setColor(0.12, 0.05, 0.2, 1)
  arco("fill", 0.55)
end

-- Portal a un mapa de FAO (extensión del mundo): un remolino azul.
function I.iconoPortal(x, y, r)
  love.graphics.setColor(0, 0, 0, 0.9)
  love.graphics.circle("fill", x, y, r * 1.35, 16)
  love.graphics.setColor(0.35, 0.65, 1, 1)
  love.graphics.circle("fill", x, y, r, 16)
  love.graphics.setColor(0.85, 0.95, 1, 1)
  love.graphics.setLineWidth(math.max(1, r * 0.3))
  love.graphics.arc("line", "open", x, y, r * 0.55, 0.3, 4.2)
  love.graphics.setLineWidth(1)
end

-- ¿Queda el punto dentro de lo que enseña el minimapa? (girado, la zona visible es un círculo que cubre el cuadrado)
local function dentroMini(ex, ey, x, y, lado, m)
  if Iso.activo() then
    local dx, dy = ex - (x + lado / 2), ey - (y + lado / 2)
    return dx * dx + dy * dy < (lado * 0.72) ^ 2
  end
  return ex > x + m and ex < x + lado - m and ey > y + m and ey < y + lado - m
end

-- Minimapa de un mapa aparte de FAO (.mpc): una imagen con el color medio del tileset de cada casilla del juego (más oscuro donde hay obstáculos o agua), la ventana de 96 casillas alrededor del
-- jugador, las salidas (triángulos amarillos) y los demás jugadores. Se hornea una vez por mapa.
local miniFao = {}
local function minimapaFao(mundo, p, mapa, x, y, lado)
  local m = mapa.mpc
  local img = miniFao[m.id]
  if not img then
    local datos = love.image.newImageData(mapa.w, mapa.h)
    for ty = 0, mapa.h - 1 do
      for tx = 0, mapa.w - 1 do
        local t = m.tilesets[m.ts[(ty * 2) * m.fw + tx * 2 + 1]]
        local c = t and t.color or { 40, 40, 40 }
        local k = (mapa.bloque[tx] and mapa.bloque[tx][ty]) and 0.72 or 1
        datos:setPixel(tx, ty, c[1] / 255 * k, c[2] / 255 * k, c[3] / 255 * k, 1)
      end
    end
    img = love.graphics.newImage(datos)
    img:setFilter("nearest", "nearest")
    miniFao[m.id] = img
  end
  local ventana = 96
  local px, py = p.x, p.y
  local x0 = math.max(0, math.min(math.max(0, mapa.w - ventana), px - ventana / 2))
  local y0 = math.max(0, math.min(math.max(0, mapa.h - ventana), py - ventana / 2))
  local k = lado / ventana
  local s = I.escala or 1
  love.graphics.setScissor(x * s, y * s, lado * s, lado * s)
  love.graphics.setColor(0.04, 0.05, 0.07)
  love.graphics.rectangle("fill", x, y, lado, lado)
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(img, -x0 * k + x, -y0 * k + y, 0, k, k)
  for _, sal in ipairs(p.modo == "moba" and {} or (m.salidas or {})) do         -- (en el asedio no hay salidas del mapa)
    local pt = sal.puntos
    local cx, cy = 0, 0
    for _, q in ipairs(pt) do cx, cy = cx + q.x / 64, cy + q.y / 64 end
    cx, cy = cx / #pt, cy / #pt
    local ex, ey = x + (cx - x0) * k, y + (cy - y0) * k
    if dentroMini(ex, ey, x, y, lado, 4) then
      love.graphics.setColor(0, 0, 0, 0.9)
      love.graphics.polygon("fill", ex, ey - 5, ex + 5, ey + 4, ex - 5, ey + 4)
      love.graphics.setColor(1, 0.85, 0.2)
      love.graphics.polygon("fill", ex, ey - 3.5, ex + 3.5, ey + 2.5, ex - 3.5, ey + 2.5)
    end
  end
  for _, e in pairs(mundo.entidades) do
    if e.vivo ~= false and e.id ~= p.id and e.modo == p.modo and (e.kind == "jugador" or e.kind == "bot") then
      local ex, ey = x + (e.x - x0) * k, y + (e.y - y0) * k
      if dentroMini(ex, ey, x, y, lado, 0) then
        local c = Datos.facciones[e.faccion] and Datos.facciones[e.faccion].color or { 1, 1, 1 }
        love.graphics.setColor(c[1], c[2], c[3])
        love.graphics.rectangle("fill", ex - 1.5, ey - 1.5, 3, 3)
      end
    end
  end
  -- asedio: los tres carriles (líneas tenues), nexos y torres (cuadrados grandes del color de su equipo) y esbirros (puntos)
  if p.modo == "moba" then
    for _, c in ipairs(mundo.moba and mundo.moba.carriles or {}) do
      local linea = {}
      for i = 1, #c.ruta, 4 do
        linea[#linea + 1] = x + (c.ruta[i].x - x0) * k
        linea[#linea + 1] = y + (c.ruta[i].y - y0) * k
      end
      if #linea >= 4 then
        love.graphics.setColor(1, 1, 1, 0.28)
        love.graphics.setLineWidth(2)
        love.graphics.line(linea)
        love.graphics.setLineWidth(1)
      end
    end
    for _, e in pairs(mundo.entidades) do
      if e.moba and e.vivo ~= false and e.modo == "moba" then
        local ex, ey = x + (e.x - x0) * k, y + (e.y - y0) * k
        if dentroMini(ex, ey, x, y, lado, 0) then
          local c = Datos.facciones[e.faccion] and Datos.facciones[e.faccion].color or { 1, 1, 1 }
          local r = e.kind == "altar" and 5 or (e.kind == "estatua" and 3.5 or 1.5)
          love.graphics.setColor(0, 0, 0, 0.85)
          love.graphics.rectangle("fill", ex - r - 1, ey - r - 1, r * 2 + 2, r * 2 + 2)
          love.graphics.setColor(c[1], c[2], c[3])
          love.graphics.rectangle("fill", ex - r, ey - r, r * 2, r * 2)
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

local function minimapaLocal(mundo, p, x, y, lado)
  marco(x - 3, y - 3, lado + 6, lado + 6, true)
  local fao = mundo:enMapaFao(p)
  if fao then return minimapaFao(mundo, p, fao, x, y, lado) end
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
  -- el minimapa se ve de frente (norte arriba); con DC_MINIMAPA_GIRADO=1 se gira 45º para coincidir con la pantalla isométrica
  local girado = Iso.activo() and os.getenv("DC_MINIMAPA_GIRADO") == "1"
  if girado then
    love.graphics.push()
    love.graphics.translate(x + lado / 2, y + lado / 2)
    love.graphics.rotate(math.pi / 4)
    love.graphics.scale(1, 1)
    love.graphics.translate(-(x + lado / 2), -(y + lado / 2))
    -- el centro de la vista es el jugador (salvo en los bordes del mundo): se recentra
    love.graphics.translate((x + lado / 2) - (x + (px - x0) * k), (y + lado / 2) - (y + (py - y0) * k))
    love.graphics.setColor(0.04, 0.05, 0.07)
    love.graphics.rectangle("fill", x - lado, y - lado, lado * 3, lado * 3)
  end
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
    if dentroMini(ex, ey, x, y, lado, 2) then I.iconoNpc(n.rol, ex, ey, 2.4) end
  end
  -- puertas de mazmorra
  for _, z in ipairs(mundo.mapas.mundo.mazmorras or {}) do
    local ex, ey = x + (z.x - x0) * k, y + (z.y - y0) * k
    if dentroMini(ex, ey, x, y, lado, 4) then I.iconoMazmorra(ex, ey, 3) end
  end
  -- portales a los mapas de FAO (se ven aunque estén lejos)
  for _, pt in ipairs(mundo.portalesFao or {}) do
    local ex, ey = x + (pt.x - x0) * k, y + (pt.y - y0) * k
    if (pt.faccion == nil or pt.faccion == (p.faccion or pt.faccion)) and dentroMini(ex, ey, x, y, lado, 4) then I.iconoPortal(ex, ey, 3) end
  end
  -- compañeros de grupo (se ven aunque estén lejos)
  for _, m in ipairs(p.grupo and p.grupo.miembros or {}) do
    if m.id ~= p.id then
      local ex, ey = x + (m.x - x0) * k, y + (m.y - y0) * k
      if dentroMini(ex, ey, x, y, lado, 2) then
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.circle("fill", ex, ey, 4)
        love.graphics.setColor(0.35, 0.85, 1)
        love.graphics.circle("fill", ex, ey, 2.8)
      end
    end
  end
  -- caravanas en marcha y ladrones buscados (los oficios los rastrean)
  for _, c in ipairs(p.caravanas or {}) do
    local ex, ey = x + (c.x - x0) * k, y + (c.y - y0) * k
    if dentroMini(ex, ey, x, y, lado, 2) then
      love.graphics.setColor(0, 0, 0, 0.85)
      love.graphics.rectangle("fill", ex - 3.5, ey - 2.5, 7, 5)
      love.graphics.setColor(0.95, 0.8, 0.4)
      love.graphics.rectangle("fill", ex - 2.5, ey - 1.5, 5, 3)
    end
  end
  for _, b in ipairs(p.buscados or {}) do
    local ex, ey = x + (b.x - x0) * k, y + (b.y - y0) * k
    if dentroMini(ex, ey, x, y, lado, 2) then
      love.graphics.setColor(0, 0, 0, 0.9)
      love.graphics.circle("fill", ex, ey, 4.2)
      love.graphics.setColor(1, 0.15, 0.15)
      love.graphics.circle("fill", ex, ey, 3)
    end
  end
  I.marcasMinimapa(p, x, y, lado, x0, y0, k)
  for _, e in pairs(mundo.entidades) do
    if e.vivo ~= false and e.modo == "mundo" and e.id ~= p.id and mundo:mismoLugar(p, e) then
      local ex, ey = x + (e.x - x0) * k, y + (e.y - y0) * k
      if dentroMini(ex, ey, x, y, lado, 0) then
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
  if girado then love.graphics.pop() end
  love.graphics.setScissor()
end

local AYUDA_BOTONES = {
  hud_mapa = "Mapa del mundo (M). Clic en un punto para viajar hasta allí; rueda para acercar.",
  hud_comercio = "Tratar con otro jugador (T): selecciona a un aventurero cercano y pulsa aquí.",
  hud_ayuda = "Ayuda: controles, combate, oficios, casas y mazmorras.",
  hud_diaria = "Recompensa diaria (F2): un premio por día, más grande con días seguidos.",
  hud_misiones = "Diario de misiones (Q): lo que llevas, dónde ir y qué te darán.",
  hud_menu = "Menú del juego (Esc): continuar, ajustes y salir.",
}

-- Elementos flotantes del HUD (el juego ocupa toda la pantalla): estado arriba a la izquierda,
-- minimapa y botones arriba a la derecha y el chat abajo a la izquierda. El equipo y las
-- cifras están en el panel Personaje (C) y la mochila en la bolsa (I).
function I.flotantes(mundo, p, vw, vh)
  local f = pequena()
  local fac = Datos.facciones[p.faccion].color
  love.graphics.setFont(f)

  -- estado: vida, maná, experiencia y oro
  local bx, by, bw = 8, 8, 236
  marco(bx, by, bw, 82, true)
  I.registrar(bx, by, bw, 82, "panel")
  local hp, hpMax = p.hp or 0, math.max(1, p.hpMax or 1)
  local mp, mpMax = p.mp or 0, math.max(1, p.mpMax or 1)
  local fr = hp / hpMax
  barra(bx + 6, by + 6, bw - 12, 15, fr, Dibujo.colorVida(fr))
  texto(string.format("Vida %d / %d", math.floor(hp), hpMax), bx + 10, by + 7, { 1, 1, 1 })
  barra(bx + 6, by + 24, bw - 12, 13, mp / mpMax, 0.25, 0.45, 0.92)
  texto(string.format("Maná %d / %d", math.floor(mp), mpMax), bx + 10, by + 24, { 1, 1, 1 })
  local xpN = p.xpSig or Datos.xpPara(p.nivel)
  barra(bx + 6, by + 40, bw - 12, 12, (p.xp or 0) / xpN, 0.85, 0.7, 0.2)
  texto(string.format("Nivel %d   exp %d / %d", p.nivel, math.floor(p.xp or 0), xpN), bx + 10, by + 39, { 1, 1, 1 })
  texto("Oro " .. Ayudas.num(p.oro), bx + 10, by + 60, { 1, 0.9, 0.35 })
  local clase = Datos.clases[p.clase] and Datos.clases[p.clase].nombre or ""
  texto(clase, bx + bw - 10 - f:getWidth(clase), by + 60, fac or { 0.9, 0.9, 0.9 })
  if sobre(bx, by, bw, 82) then I.pista = "Pulsa C para ver tu personaje y su equipo, e I para abrir la bolsa." end
  I.rastreoMision(mundo, p, 8, 96)

  -- minimapa y botones
  local lado = 128
  local mx0 = vw - lado - 10
  minimapaLocal(mundo, p, mx0, 10, lado)
  I.registrar(mx0, 10, lado, lado, "hud_mapa")
  -- coordenadas de tu casilla, al lado del minimapa
  do
    local cx, cy = math.floor(p.x or 0), math.floor(p.y or 0)
    local txt = { "X " .. cx, "Y " .. cy }
    local ancho = math.max(f:getWidth(txt[1]), f:getWidth(txt[2])) + 14
    marco(mx0 - ancho - 6, 10, ancho, 38, true)
    I.registrar(mx0 - ancho - 6, 10, ancho, 38, "panel")
    texto(txt[1], mx0 - ancho + 1, 13, { 0.92, 0.95, 1 })
    texto(txt[2], mx0 - ancho + 1, 28, { 0.92, 0.95, 1 })
    if sobre(mx0 - ancho - 6, 10, ancho, 38) then I.pista = "Tus coordenadas en el mapa (X hacia la derecha, Y hacia abajo)." end
    -- diario de misiones (Q): icono dorado bajo las coordenadas; late si hay una misión lista para entregar
    local lista = false
    for _, q in ipairs(Misiones.lista) do if Misiones.estado(p, q) == "lista" then lista = true break end end
    local ix, iy, il = mx0 - ancho - 6, 54, ancho
    local hover = sobre(ix, iy, il, 30)
    local pulso = lista and (0.5 + 0.5 * math.sin(love.timer.getTime() * 5)) or 0
    love.graphics.setColor(0.42 + 0.3 * pulso + (hover and 0.1 or 0), 0.3 + 0.2 * pulso, 0.05, 0.95)
    love.graphics.rectangle("fill", ix, iy, il, 30, 7, 7)
    love.graphics.setColor(1, 0.82, 0.3, 1)
    love.graphics.rectangle("line", ix + 0.5, iy + 0.5, il - 1, 29, 7, 7)
    -- pergamino dorado con una marca de admiración
    local mx, my = ix + il / 2, iy + 15
    love.graphics.setColor(0.98, 0.86, 0.45, 1)
    love.graphics.rectangle("fill", mx - 7, my - 9, 14, 18, 3, 3)
    love.graphics.setColor(0.75, 0.55, 0.15, 1)
    love.graphics.rectangle("fill", mx - 9, my - 10, 18, 3, 1.5, 1.5)
    love.graphics.rectangle("fill", mx - 9, my + 7, 18, 3, 1.5, 1.5)
    love.graphics.setColor(0.3, 0.17, 0.02, 1)
    love.graphics.rectangle("fill", mx - 1, my - 6, 2.4, 8, 1, 1)
    love.graphics.rectangle("fill", mx - 1, my + 3, 2.4, 2.4, 1, 1)
    I.registrar(ix, iy, il, 30, "hud_misiones")
    if hover then I.pista = AYUDA_BOTONES.hud_misiones end
  end
  -- botones del minimapa, como iconos del juego: mapa (pergamino), ayuda (signo de interrogación), menú (engranaje) y la
  -- recompensa diaria (regalo, que brilla mientras haya premio sin reclamar). El nombre sale al pasar el ratón.
  local botones = {
    { "hud_mapa", "hud", 0 }, { "hud_ayuda", "hud", 1 }, { "hud_menu", "hud", 2 }, { "hud_diaria", "hud", 3 },
  }
  local bww, bhh = (lado - (#botones - 1) * 4) / #botones, 30
  local cy = 10 + lado + 6
  for i, b in ipairs(botones) do
    local x = mx0 + (i - 1) * (bww + 4)
    local hover = sobre(x, cy, bww, bhh)
    if hover then I.pista = AYUDA_BOTONES[b[1]] end
    local libre = b[1] == "hud_diaria" and p.diaria and not p.diaria.reclamada
    local pulso = libre and (0.5 + 0.5 * math.sin(love.timer.getTime() * 4)) or 0
    if libre then
      love.graphics.setColor(0.45 + 0.3 * pulso, 0.34 + 0.2 * pulso, 0.06, 0.95)
    else
      love.graphics.setColor(hover and 0.3 or 0.12, hover and 0.43 or 0.18, hover and 0.85 or 0.4, 0.95)
    end
    love.graphics.rectangle("fill", x, cy, bww, bhh, 6, 6)
    if libre then love.graphics.setColor(1, 0.82, 0.3) else love.graphics.setColor(0.45, 0.6, 0.95) end
    love.graphics.rectangle("line", x + 0.5, cy + 0.5, bww - 1, bhh - 1, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    Atlas.dibujar(b[2], b[3], x + bww / 2, cy + bhh / 2, 0.85, 16, 16)
    if b[1] == "hud_diaria" and p.diaria and p.diaria.reclamada then
      love.graphics.setColor(0.4, 1, 0.5, 1)
      love.graphics.setFont(f)
      love.graphics.print("✔", x + bww - 11, cy + bhh - 16)
    end
    I.registrar(x, cy, bww, bhh, b[1])
  end

  -- medidor de daño del jefe que peleas: a la derecha, justo debajo de los botones de mapa, ayuda, menú y diaria
  if p.medidor then I.medidorDano(p, vw - 196 - 6, cy + bhh + 8, 196) end

  love.graphics.setFont(I.fuente)
end

-- Menú del clic derecho sobre otro jugador: tratar, invitar al gremio o al grupo, mirar.
function I.dibujarMenuJugador(mundo, p, w, h)
  local m = I.menuJugador
  local o = m and mundo.entidades[m.id]
  if not o or o.vivo == false or not mundo:mismoLugar(p, o) or Util.dist(p.x, p.y, o.x, o.y) > 25 then
    I.menuJugador = nil
    return
  end
  local misma = o.faccion == p.faccion
  local opciones = {
    { "Tratar (comerciar)", "ctx_trato", true },
    { "Invitar al gremio", "ctx_gremio", p.gremioNombre ~= nil and misma,
      p.gremioNombre == nil and "No tienes gremio." or "Solo puedes invitar a tu corona." },
    { "Invitar al grupo", "ctx_grupo", misma and (not p.grupo or p.grupo.lider == p.id) and not o.enGrupo,
      not misma and "Solo puedes agrupar con tu corona." or (p.grupo and p.grupo.lider ~= p.id) and "Solo el líder del grupo invita." or "Ya está en un grupo." },
    { "Mirar", "ctx_mirar", true },
  }
  local ancho, alto = 220, 46 + #opciones * 34
  local x = math.max(4, math.min(m.x + 6, w - ancho - 4))
  local y = math.max(4, math.min(m.y + 6, h - alto - 4))
  caja(x, y, ancho, alto, o.nombre or "Jugador")
  for i, op in ipairs(opciones) do
    I.boton(x + 10, y + 40 + (i - 1) * 34, ancho - 20, 28, op[1], op[2], op[3], op[4])
  end
end

-- Medidor de daño de un jefe del mundo: su vida y quién ha hecho cuánto daño (el botín es del que más hace).
function I.medidorDano(p, x, y, w)
  local m = p.medidor
  if not m or not m.f then return end
  local f = pequena()
  local fila = 17
  local h = 40 + #m.f * fila + 4
  marco(x, y, w, h, true)
  I.registrar(x, y, w, h, "panel")
  texto(m.n or "Jefe", x + 8, y + 3, { 1, 0.86, 0.5 })
  barra(x + 8, y + 21, w - 16, 9, math.max(0, math.min(1, (m.hp or 0) / math.max(1, m.hpMax or 1))), 0.85, 0.2, 0.2)
  texto("Daño hecho", x + 8, y + 31, { 0.75, 0.72, 0.62 })
  local yy = y + 46
  for i, r in ipairs(m.f) do
    local yo = r[4] == 1
    local pct = (r[3] or 0) / 100
    love.graphics.setColor(yo and 0.95 or 0.4, yo and 0.7 or 0.55, yo and 0.2 or 0.85, 0.35)
    love.graphics.rectangle("fill", x + 6, yy - 1, (w - 12) * pct, fila - 3, 3, 3)
    local puesto = r[5] or i
    local nombre = r[1] or "?"
    if f:getWidth(nombre) > 76 then nombre = nombre:sub(1, 10) .. "…" end
    local dano = r[2] or 0
    local d = dano >= 10000 and string.format("%.1fk", dano / 1000) or tostring(dano)
    texto(puesto .. ". " .. nombre, x + 9, yy, yo and { 1, 0.9, 0.5 } or { 0.9, 0.9, 0.95 })
    local t = d .. "  " .. (r[3] or 0) .. "%"
    texto(t, x + w - 9 - f:getWidth(t), yy, yo and { 1, 0.9, 0.5 } or { 0.8, 0.82, 0.9 })
    yy = yy + fila
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
    nieve = { 0.88, 0.93, 1.0 }, roca = { 0.5, 0.5, 0.55 }, pantano = { 0.17, 0.27, 0.2 }, bosque = { 0.16, 0.38, 0.18 },
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

-- ---------------------------------------------------------------------------------------------------------------------------------
-- Árbol de poderes: los poderes se reparten en columnas según su cadena de requisitos, con líneas curvas entre un poder y lo que
-- necesita; cada poder es una ficha redonda con su icono, número de casilla, rangos y estado (aprender, mejorar, máximo, bloqueado).
-- Las pasivas van en una fila aparte y abajo hay un cuadro con lo que hace el poder señalado (o el último que se señaló).
-- ---------------------------------------------------------------------------------------------------------------------------------
local COLOR_ESTADO = {
  puede = { 1.0, 0.84, 0.30 }, maximo = { 0.45, 0.86, 0.52 }, sabido = { 0.82, 0.70, 0.46 }, bloqueado = { 0.36, 0.40, 0.52 },
}

local function curvaArbol(x0, y0, x1, y1)
  local mx = (x0 + x1) / 2
  return love.math.newBezierCurve(x0, y0, mx, y0, mx, y1, x1, y1):render(4)
end

-- Columna de cada poder: 0 si no necesita nada y una más que lo que necesita.
local function profundidades(nodos)
  local por, prof = {}, {}
  for _, n in ipairs(nodos) do por[n.id] = n end
  local function d(n)
    if prof[n.id] then return prof[n.id] end
    prof[n.id] = 0
    local v = 0
    if n.requiere and por[n.requiere[1]] then v = d(por[n.requiere[1]]) + 1 end
    prof[n.id] = v
    return v
  end
  for _, n in ipairs(nodos) do d(n) end
  return prof
end

local function estadoNodo(p, n)
  local r = Arbol.rango(p, n.id)
  local motivo = Arbol.motivo(p, n.id)
  if r >= Arbol.MAX then return "maximo", r, motivo end
  if motivo == nil then return "puede", r, motivo end
  if r > 0 then return "sabido", r, motivo end
  return "bloqueado", r, motivo
end

-- Ficha de un poder o una pasiva. (cx, cy) = centro del círculo; devuelve el rectángulo que ocupa (para el ratón).
local function fichaArbol(p, n, cx, cy, R, ancho, hover, t)
  local est, r, motivo = estadoNodo(p, n)
  local c = COLOR_ESTADO[est]
  local pulso = est == "puede" and (0.5 + 0.5 * math.sin(t * 3.2)) or 0
  local x0, y0, w, h = cx - R - 4, cy - R - 4, ancho, 2 * R + 8
  -- fondo de la ficha
  love.graphics.setColor(0.08, 0.11, 0.22, hover and 1 or 0.92)
  love.graphics.rectangle("fill", x0, y0, w, h, R, R)
  love.graphics.setColor(c[1], c[2], c[3], (hover and 0.9 or 0.45) + 0.3 * pulso)
  love.graphics.setLineWidth(hover and 2 or 1.5)
  love.graphics.rectangle("line", x0 + 0.5, y0 + 0.5, w - 1, h - 1, R, R)
  love.graphics.setLineWidth(1)
  -- brillo detrás del círculo
  if est ~= "bloqueado" then
    love.graphics.setColor(c[1], c[2], c[3], 0.10 + 0.14 * pulso)
    love.graphics.circle("fill", cx, cy, R + 5)
  end
  love.graphics.setColor(0.04, 0.05, 0.12, 1)
  love.graphics.circle("fill", cx, cy, R)
  -- icono recortado al círculo
  local opaco = est == "bloqueado" and 0.38 or 1
  love.graphics.stencil(function() love.graphics.circle("fill", cx, cy, R - 2) end, "replace", 1)
  love.graphics.setStencilTest("greater", 0)
  love.graphics.setColor(1, 1, 1, opaco)
  if n.tipo == "activa" then
    Efectos.icono(n.id, cx - R + 4, cy - R + 4, 2 * R - 8)
  else
    Atlas.dibujar(n.icono.hoja, n.icono.sprite, cx, cy, R / 11, 16, 16)
  end
  love.graphics.setStencilTest()
  love.graphics.setLineWidth(2)
  love.graphics.setColor(c[1], c[2], c[3], 0.95)
  love.graphics.circle("line", cx, cy, R)
  love.graphics.setLineWidth(1)
  -- número de la casilla de la barra
  local f = I.fuente
  love.graphics.setFont(f)
  if n.tipo == "activa" then
    love.graphics.setColor(0.04, 0.05, 0.12, 0.95)
    love.graphics.circle("fill", cx - R + 3, cy - R + 3, 9)
    love.graphics.setColor(c[1], c[2], c[3], 1)
    love.graphics.circle("line", cx - R + 3, cy - R + 3, 9)
    local s = tostring(n.slot)
    love.graphics.setColor(1, 0.95, 0.8, 1)
    love.graphics.print(s, cx - R + 3 - f:getWidth(s) / 2, cy - R + 3 - f:getHeight() / 2)
  end
  -- nombre, rangos y estado
  local tx = cx + R + 9
  love.graphics.setColor(0.97, 0.94, 0.85, opaco < 1 and 0.55 or 1)
  local nombre = Arbol.nombre(n)
  local esc = math.min(1, (w - (R * 2 + 22)) / math.max(1, f:getWidth(nombre)))      -- nombres largos: más pequeños en vez de cortarlos
  love.graphics.print(nombre, tx, cy - R + 1 + (1 - esc) * 4, 0, esc, esc)
  for i = 1, Arbol.MAX do
    love.graphics.setColor(i <= r and c[1] or 0.22, i <= r and c[2] or 0.24, i <= r and c[3] or 0.32, 1)
    love.graphics.rectangle("fill", tx + (i - 1) * 13, cy + 2, 10, 6, 2, 2)
  end
  local pie, cp
  if est == "maximo" then pie, cp = "Máximo", COLOR_ESTADO.maximo
  elseif est == "puede" then pie, cp = r == 0 and "Aprender" or "Mejorar", COLOR_ESTADO.puede
  elseif r == 0 and (p.nivel or 1) < n.nivel then pie, cp = "Nivel " .. n.nivel, { 0.95, 0.5, 0.45 }
  elseif r == 0 and n.requiere and Arbol.rango(p, n.requiere[1]) < n.requiere[2] then pie, cp = "Pide otro poder", { 0.7, 0.72, 0.85 }
  else pie, cp = "Sin puntos", { 0.7, 0.72, 0.85 } end
  love.graphics.setColor(cp[1], cp[2], cp[3], 0.95)
  love.graphics.print(pie, tx, cy + R - f:getHeight() + 2)
  return x0, y0, w, h, est, r, motivo
end

function I.panelArbol(mundo, p, w, h)
  local nodos = Arbol.nodos(p.clase)
  local clase = Datos.clases[p.clase]
  local t = love.timer.getTime()
  local pw, ph = math.min(w - 40, 980), math.min(h - 24, 650)
  local px, py = (w - pw) / 2, (h - ph) / 2
  caja(px, py, pw, ph)
  love.graphics.setFont(I.grande)
  love.graphics.setColor(TEMA.acento[1], TEMA.acento[2], TEMA.acento[3], 1)
  love.graphics.print("Árbol de poderes", px + 20, py + 8, 0, 0.72, 0.72)
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(0.7, 0.78, 0.95, 1)
  love.graphics.print((clase and clase.nombre or "") .. "  ·  nivel " .. (p.nivel or 1), px + 22, py + 44)
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  -- puntos disponibles
  local puntos = Arbol.puntos(p)
  local bw = 150
  love.graphics.setColor(0.08, 0.11, 0.22, 1)
  love.graphics.rectangle("fill", px + pw - bw - 60, py + 12, bw, 36, 18, 18)
  love.graphics.setColor(puntos > 0 and 1 or 0.5, puntos > 0 and 0.84 or 0.52, puntos > 0 and 0.3 or 0.62, 0.9)
  love.graphics.rectangle("line", px + pw - bw - 60 + 0.5, py + 12.5, bw - 1, 35, 18, 18)
  love.graphics.circle("fill", px + pw - bw - 60 + 18, py + 30, 7 + 1.5 * (puntos > 0 and math.sin(t * 3) or 0))
  love.graphics.setColor(1, 0.96, 0.85, 1)
  love.graphics.print(puntos .. (puntos == 1 and " punto" or " puntos"), px + pw - bw - 60 + 34, py + 22)
  love.graphics.setColor(TEMA.borde[1], TEMA.borde[2], TEMA.borde[3], 0.4)
  love.graphics.rectangle("fill", px + 16, py + 66, pw - 32, 1)

  -- reparto de los poderes en columnas
  local activos, pasivos = {}, {}
  for _, n in ipairs(nodos) do
    if n.tipo == "activa" then activos[#activos + 1] = n else pasivos[#pasivos + 1] = n end
  end
  local prof = profundidades(activos)
  local cols, maxd, maxn = {}, 0, 1
  for _, n in ipairs(activos) do
    local d = prof[n.id]
    cols[d] = cols[d] or {}
    cols[d][#cols[d] + 1] = n
    if d > maxd then maxd = d end
  end
  local gy0, gy1 = py + 90, py + ph - 238
  local ancho = maxd >= 4 and 166 or 184
  local gx0 = px + 26
  local paso = maxd > 0 and ((pw - 52 - ancho) / maxd) or 0
  local pos = {}
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(0.85, 0.78, 0.6, 0.9)
  love.graphics.print("Poderes (casillas de la barra 1-" .. #activos .. ")", gx0, py + 72)
  for d = 0, maxd do
    local col = cols[d] or {}
    table.sort(col, function(a, b)
      local ya = a.requiere and pos[a.requiere[1]] and pos[a.requiere[1]].cy or 0
      local yb = b.requiere and pos[b.requiere[1]] and pos[b.requiere[1]].cy or 0
      if math.abs(ya - yb) > 1 then return ya < yb end
      return a.slot < b.slot
    end)
    if #col > maxn then maxn = #col end
    for i, n in ipairs(col) do
      pos[n.id] = { cx = gx0 + d * paso + 28, cy = gy0 + 8 + (gy1 - gy0 - 8) * (i - 0.5) / #col }
    end
  end
  local R = math.max(18, math.min(26, ((gy1 - gy0) / maxn - 18) / 2))
  -- líneas entre un poder y lo que necesita
  for _, n in ipairs(activos) do
    if n.requiere and pos[n.requiere[1]] then
      local a, b = pos[n.requiere[1]], pos[n.id]
      local cumple = Arbol.rango(p, n.requiere[1]) >= n.requiere[2]
      local pts = curvaArbol(a.cx - R - 4 + ancho, a.cy, b.cx - R - 4, b.cy)
      love.graphics.setLineWidth(5)
      love.graphics.setColor(cumple and 1 or 0.3, cumple and 0.8 or 0.35, cumple and 0.3 or 0.5, cumple and 0.14 or 0.08)
      love.graphics.line(pts)
      love.graphics.setLineWidth(2)
      love.graphics.setColor(cumple and 0.95 or 0.38, cumple and 0.78 or 0.42, cumple and 0.3 or 0.56, cumple and 0.95 or 0.7)
      love.graphics.line(pts)
      love.graphics.setLineWidth(1)
      -- rango que se pide, en el centro de la línea
      local k = math.floor(#pts / 4)
      local mx, my = pts[2 * k + 1], pts[2 * k + 2]
      if mx and my then
        local s = tostring(n.requiere[2])
        love.graphics.setColor(0.05, 0.06, 0.14, 1)
        love.graphics.circle("fill", mx, my, 8)
        love.graphics.setColor(cumple and 1 or 0.55, cumple and 0.84 or 0.6, cumple and 0.35 or 0.75, 1)
        love.graphics.circle("line", mx, my, 8)
        love.graphics.print(s, mx - I.fuente:getWidth(s) / 2, my - I.fuente:getHeight() / 2)
      end
    end
  end

  local function registrarNodo(n, x0, y0, fw, fh)
    I.registrar(x0, y0, fw, fh, "arb_" .. n.id)
    if sobre(x0, y0, fw, fh) then I.arbolSel = n.id end
  end
  for _, n in ipairs(activos) do
    local c = pos[n.id]
    local hover = sobre(c.cx - R - 4, c.cy - R - 4, ancho, 2 * R + 8)
    local x0, y0, fw, fh = fichaArbol(p, n, c.cx, c.cy, R, ancho, hover, t)
    registrarNodo(n, x0, y0, fw, fh)
  end

  -- pasivas
  local py2 = py + ph - 212
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(0.85, 0.78, 0.6, 0.9)
  love.graphics.print("Pasivas", gx0, py2 - 40)
  local wp = math.min(220, (pw - 52 - 12 * (math.max(1, #pasivos) - 1)) / math.max(1, #pasivos))
  for i, n in ipairs(pasivos) do
    local cx, cy = gx0 + 24 + (i - 1) * (wp + 12), py2 + 6
    local hover = sobre(cx - 24, cy - 24, wp, 48)
    local x0, y0, fw, fh = fichaArbol(p, n, cx, cy, 20, wp, hover, t)
    registrarNodo(n, x0, y0, fw, fh)
  end

  -- cuadro con lo que hace el poder señalado
  local sel = I.arbolSel and Arbol.nodo(p.clase, I.arbolSel) or nil
  if not sel then sel = activos[1] end
  local iy, ih = py + ph - 148, 96
  love.graphics.setColor(0.07, 0.10, 0.21, 1)
  love.graphics.rectangle("fill", px + 16, iy, pw - 32, ih, 8, 8)
  love.graphics.setColor(0.7, 0.62, 0.35, 0.85)
  love.graphics.rectangle("line", px + 16.5, iy + 0.5, pw - 33, ih - 1, 8, 8)
  if sel then
    local est, r, motivo = estadoNodo(p, sel)
    local c = COLOR_ESTADO[est]
    -- icono grande
    love.graphics.setColor(0.04, 0.05, 0.12, 1)
    love.graphics.circle("fill", px + 56, iy + ih / 2, 32)
    love.graphics.stencil(function() love.graphics.circle("fill", px + 56, iy + ih / 2, 30) end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    love.graphics.setColor(1, 1, 1, 1)
    if sel.tipo == "activa" then Efectos.icono(sel.id, px + 56 - 26, iy + ih / 2 - 26, 52)
    else Atlas.dibujar(sel.icono.hoja, sel.icono.sprite, px + 56, iy + ih / 2, 2, 16, 16) end
    love.graphics.setStencilTest()
    love.graphics.setLineWidth(2)
    love.graphics.setColor(c[1], c[2], c[3], 1)
    love.graphics.circle("line", px + 56, iy + ih / 2, 32)
    love.graphics.setLineWidth(1)
    local tx = px + 106
    love.graphics.setFont(I.fuente)
    love.graphics.setColor(1, 0.9, 0.55)
    love.graphics.print(Arbol.nombre(sel) .. "   rango " .. r .. "/" .. Arbol.MAX .. (sel.tipo == "activa" and ("   ·   casilla " .. sel.slot) or "   ·   pasiva"), tx, iy + 8)
    local desc = sel.tipo == "activa" and (Datos.habilidades[sel.id].desc or "") or (sel.desc or "")
    love.graphics.setColor(0.88, 0.85, 0.75)
    local ahora = r > 0 and efectoNodo(p, sel, r) or nil
    local sigue = r < Arbol.MAX and efectoNodo(p, sel, r + 1) or nil
    love.graphics.printf(desc .. (ahora and ("  Ahora: " .. ahora .. ".") or "") .. (sigue and ("  Siguiente rango: " .. sigue .. ".") or ""), tx, iy + 28, pw - 150, "left")
    love.graphics.setColor(c[1], c[2], c[3], 1)
    love.graphics.print(est == "puede" and (r == 0 and "Clic para aprender" or "Clic para mejorar") or (motivo or ""), tx, iy + ih - 20)
  end
  local coste = mundo:costeReinicio(p)
  I.boton(px + 16, py + ph - 42, 230, 28, "Reiniciar puntos (" .. coste .. " de oro)", "arbol_reset", Arbol.gastados(p) > 0)
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(0.6, 0.65, 0.8, 0.8)
  love.graphics.print("Aprender un poder pide cierto nivel y su requisito; mejorarlo solo cuesta puntos.", px + 262, py + ph - 36)
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
      love.graphics.setColor(0.09, 0.12, 0.23)
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
        love.graphics.setColor(0.10, 0.13, 0.25)
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
  hunter = "Caza a los ladrones buscados (los que roban a los comerciantes): cobras una recompensa por cada uno.",
  thief = "Roba la mercancía de los comerciantes (jugadores) fuera de las ciudades (tecla B) y véndelas a un contacto.",
}

-- Marquesina de avisos globales del sistema (por ejemplo, alguien se anota a un evento): el texto
-- cruza la parte de arriba de la pantalla de derecha a izquierda; los avisos esperan su turno.
I.MARQUESINA_VEL = 110
function I.marquesina(mundo, p, vw, dt)
  local m = I.marq
  if not m then
    m = { cola = {}, ultimo = nil }
    I.marq = m
    local alto = 0
    for _, msg in ipairs(mundo.mensajes or {}) do
      if msg.marquesina and msg.id and msg.id > alto then alto, m.epoca = msg.id, msg.epoca end
    end
    m.ultimo = alto
  end
  for _, msg in ipairs(mundo.mensajes or {}) do
    if msg.marquesina and msg.id then
      -- si el servidor se reinició, sus números de mensaje empiezan de cero: se empieza de nuevo
      if msg.epoca ~= m.epoca then m.epoca, m.ultimo = msg.epoca, 0 end
      if msg.id > m.ultimo then
        m.cola[#m.cola + 1] = msg.texto
        m.ultimo = msg.id
      end
    end
  end
  local f = pequena()
  local bx, by = 240, 6
  local bw = math.max(200, vw - 440)
  if not m.actual and #m.cola > 0 then
    local t = table.remove(m.cola, 1)
    m.actual = { texto = t, x = bx + bw, ancho = f:getWidth(t) }
  end
  local a = m.actual
  if not a then return end
  a.x = a.x - I.MARQUESINA_VEL * (dt or 0)
  if a.x + a.ancho < bx then m.actual = nil return end
  love.graphics.setFont(f)
  love.graphics.setColor(0.05, 0.07, 0.15, 0.85)
  love.graphics.rectangle("fill", bx, by, bw, 24, 4, 4)
  love.graphics.setColor(0.85, 0.72, 0.35, 0.9)
  love.graphics.rectangle("line", bx + 0.5, by + 0.5, bw - 1, 23, 4, 4)
  local esc = I.escala or 1
  love.graphics.setScissor((bx + 2) * esc, by * esc, (bw - 4) * esc, 24 * esc)
  love.graphics.setColor(1, 0.9, 0.55, 1)
  love.graphics.print(a.texto, a.x, by + 4)
  love.graphics.setScissor()
end

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
    lineas[#lineas + 1] = { "Montado: " .. (M and M.nombre or p.montado) .. "", { 0.75, 0.85, 1 } }
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
    love.graphics.setColor(0.10, 0.13, 0.25)
    love.graphics.rectangle("fill", x, y, cw, ch, 6, 6)
    love.graphics.setColor(actual and 0.95 or 0.5, actual and 0.8 or 0.42, actual and 0.3 or 0.25)
    love.graphics.rectangle("line", x, y, cw, ch, 6, 6)
    love.graphics.setColor(1, 0.9, 0.55)
    love.graphics.print(NOMBRES_OFICIO[id] .. (actual and (d.activo and "  (activo)" or "  (elegido)") or ""), x + 10, y + 8)
    local spr = Personajes.oficios[id]
    if spr then Personajes.dibujar(spr, 1, false, 0, x + cw - 28, y + 46) end
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
    I.boton(x + 10, y + ch - 32, cw - 20, 26, actual and "Elegido" or (not permitido[id] and (id == "thief" and "Solo en un refugio de ladrones" or "Solo en su campamento") or (o and "Volver a este oficio" or "Aprender")), "of_elegir_" .. id,
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
  if d.soloCiudades then
    love.graphics.setColor(1, 0.8, 0.5)
    love.graphics.printf((d.sitio or "Este puesto") .. ": aquí no se comercia. Las mercancías solo se compran y se entregan en las ciudades; cuanto más lejos esté la ciudad donde entregas, más te pagan.", px + 14, py + 50, pw - 28, "left")
    return
  end
  love.graphics.setColor(1, 0.9, 0.55)
  love.graphics.print(d.sitio .. "   —   Oro: " .. Ayudas.num(p.oro), px + 14, py + 38)
  local esComerciante = d.job == "trader"
  love.graphics.setColor(esComerciante and 0.85 or 1, esComerciante and 0.85 or 0.6, esComerciante and 0.8 or 0.4)
  love.graphics.print(esComerciante and ("Carga " .. math.floor(d.peso) .. "/" .. math.floor(d.capacidad)) or "Solo los comerciantes compran y venden mercancías.", px + 14, py + 60)
  for _, c in ipairs({ { "Mercancía", 24 }, { "Compra", 240 }, { "Venta", 320 }, { "Llevas", 400 } }) do
    love.graphics.setColor(0.7, 0.68, 0.55)
    love.graphics.print(c[1], px + c[2], py + 88)
  end
  for i, b in ipairs(d.bienes) do
    local y = py + 112 + (i - 1) * 42
    love.graphics.setColor(0.10, 0.13, 0.25)
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
    if b.bono and b.bono > 0 then
      love.graphics.setColor(0.55, 1, 0.6)
      love.graphics.print("+" .. b.bono .. "%", px + 400, y + 24)
    end
    local motComprar = "Solo los comerciantes con el oficio activo compran mercancías."
    I.boton(px + 440, y + 6, 74, 26, "Comprar 1", "mc_c1_" .. b.id, esComerciante, motComprar)
    I.boton(px + 518, y + 6, 40, 26, "x5", "mc_c5_" .. b.id, esComerciante, motComprar)
    I.boton(px + 562, y + 6, 74, 26, "Vender 1", "mc_v1_" .. b.id, esComerciante and b.tengo > 0,
      esComerciante and "No llevas esta mercancía." or motComprar)
    I.boton(px + 640, y + 6, 100, 26, "Vender todo", "mc_vt_" .. b.id, esComerciante and b.tengo > 0)
  end
  love.graphics.setColor(0.7, 0.68, 0.6)
  love.graphics.printf("Solo se comercia en ciudades. Compra donde la mercancía SOBRA y entrégala donde FALTA, cuanto más lejos mejor (el bono por distancia se ve en verde bajo lo que llevas). Los precios suben cuando compras y bajan cuando vendes, y se recuperan con el tiempo. Los ladrones acechan los caminos: viaja con escolta.",
    px + 14, py + ph - 70, pw - 28, "left")
end

-- Colección de monturas (tecla U o el botón sobre el icono de montura): todas las que tienes, siempre a mano.
-- Las normales y las del Item Mall se montan sin oficio; las de transporte piden el oficio activo. Debajo, la
-- carga de las alforjas.
local PAGINA_MONTURAS = 4

function I.panelMontura(mundo, p, w, h)
  local Oficios = require("compartido.dominio.oficios")
  local px, py, pw, ph = w / 2 - 330, 36, 660, 570
  caja(px, py, pw, ph, "Monturas")
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  local estado = p.monturasEstado or {}
  local function grupo(id)
    local d = Monturas.especies[id]
    if d.requiereOficio then return 3 end
    return d.mall and 2 or 1
  end
  local lista = {}
  for _, id in ipairs(p.monturas or {}) do if Monturas.especies[id] then lista[#lista + 1] = id end end
  table.sort(lista, function(a, b)
    if grupo(a) ~= grupo(b) then return grupo(a) < grupo(b) end
    return Monturas.especies[a].nombre < Monturas.especies[b].nombre
  end)

  -- ¿Se puede montar ahora? Devuelve el motivo si no.
  local function motivoNo(id)
    local d = Monturas.especies[id]
    local e = estado[id] or {}
    if e.caida then return "Herida: se recupera en " .. e.caida .. " s." end
    if d.requiereOficio and not p.job then return "Las monturas de transporte piden el oficio activo (Y)." end
    if p.job and not d.requiereOficio then return "Con el oficio activo solo valen las monturas de transporte." end
    if d.oficio and p.job ~= d.oficio then return "Solo para el oficio de comerciante." end
    if p.modo ~= "mundo" and not mundo:enMapaFao(p) then return "Aquí no se puede montar." end
    return nil
  end

  local function dibujarMontura(id, x, y, escala)
    local def = Personajes.monturaDe(id, p.faccion)
    if def and def.hoja then
      love.graphics.push()
      love.graphics.translate(x, y)
      love.graphics.scale(escala, escala)
      Personajes.dibujar(def, 1, false, love.timer.getTime(), 0, 0)
      love.graphics.pop()
    elseif def and def.vehiculo then
      local img = Arte.img("Characters/Vehicle.png")
      love.graphics.setColor(1, 1, 1)
      love.graphics.draw(img, Arte.quad(img, 128, 128, 32, 32), x, y, 0, 1.4 * escala, 1.4 * escala, 16, 28)
    end
  end

  -- la que llevas puesta
  love.graphics.setColor(0.10, 0.13, 0.25)
  love.graphics.rectangle("fill", px + 14, py + 42, pw - 28, 68, 6, 6)
  local actual = p.montado and Monturas.especies[p.montado]
  if actual then
    dibujarMontura(p.montado, px + 56, py + 98, 1.25)
    love.graphics.setColor(0.95, 0.9, 0.75)
    love.graphics.print(actual.nombre .. "  (montado)", px + 100, py + 50)
    love.graphics.setColor(0.6, 0.85, 1)
    love.graphics.print("Velocidad +" .. math.floor(actual.vel * 100) .. "%    Carga extra +" .. actual.carga, px + 100, py + 72)
    if p.monturaHpMax then
      love.graphics.setColor(0.95, 0.6, 0.2)
      love.graphics.print("Vida: " .. (p.monturaHp or 0) .. " / " .. p.monturaHpMax, px + 100, py + 90)
    end
    I.boton(px + pw - 28 - 130, py + 62, 130, 34, "Bajar", "mt_alt_" .. p.montado)
  else
    love.graphics.setColor(0.9, 0.86, 0.72)
    love.graphics.print(#lista > 0 and "No vas montado: elige una de tu colección." or "Aún no tienes monturas.", px + 28, py + 56)
    love.graphics.setColor(0.7, 0.75, 0.66)
    love.graphics.print(#lista > 0 and "La tecla O monta la última que usaste (o la primera que puedas)."
      or "Se compran en las cuadras de las ciudades o en el Item Mall (L).", px + 28, py + 80)
  end

  -- colección, por páginas
  local paginas = math.max(1, math.ceil(#lista / PAGINA_MONTURAS))
  I.monturaPag = math.max(1, math.min(paginas, I.monturaPag or 1))
  love.graphics.setColor(0.85, 0.82, 0.7)
  love.graphics.print("Tu colección: " .. #lista .. " / " .. Monturas.MAX, px + 14, py + 120)
  if paginas > 1 then
    I.boton(px + pw - 190, py + 116, 34, 26, "<", "mon_pag_ant", I.monturaPag > 1)
    love.graphics.setColor(0.85, 0.82, 0.7)
    love.graphics.printf(I.monturaPag .. " / " .. paginas, px + pw - 154, py + 120, 80, "center")
    I.boton(px + pw - 72, py + 116, 34, 26, ">", "mon_pag_sig", I.monturaPag < paginas)
  end
  local etiquetas = {
    { "Normal", { 0.6, 0.9, 0.6 } }, { "Item Mall", { 1, 0.78, 0.35 } }, { "Transporte (oficio)", { 0.55, 0.78, 1 } },
  }
  for i = 1, PAGINA_MONTURAS do
    local id = lista[(I.monturaPag - 1) * PAGINA_MONTURAS + i]
    if not id then break end
    local d = Monturas.especies[id]
    local y = py + 148 + (i - 1) * 78
    local puesta = p.montado == id
    love.graphics.setColor(puesta and 0.14 or 0.10, puesta and 0.22 or 0.13, puesta and 0.22 or 0.25)
    love.graphics.rectangle("fill", px + 14, y, pw - 28, 74, 6, 6)
    if puesta then
      love.graphics.setColor(0.4, 0.9, 0.5, 0.8)
      love.graphics.rectangle("line", px + 14.5, y + 0.5, pw - 29, 73, 6, 6)
    end
    dibujarMontura(id, px + 58, y + 64, 1.2)
    local et = etiquetas[grupo(id)]
    love.graphics.setColor(0.97, 0.92, 0.78)
    love.graphics.print(d.nombre, px + 110, y + 6)
    love.graphics.setColor(et[2][1], et[2][2], et[2][3])
    love.graphics.print(et[1], px + 110 + I.fuente:getWidth(d.nombre) + 12, y + 6)
    love.graphics.setColor(0.72, 0.78, 0.68)
    local fd = I.fuente
    love.graphics.setFont(pequena())
    love.graphics.printf(d.desc or "", px + 110, y + 25, 380, "left")
    love.graphics.setFont(fd)
    love.graphics.setColor(0.6, 0.85, 1)
    love.graphics.print("Vel +" .. math.floor(d.vel * 100) .. "%" .. (d.carga > 0 and ("   Carga +" .. d.carga) or ""), px + 110, y + 52)
    local e = estado[id] or {}
    if e.hp then
      love.graphics.setColor(0.95, 0.6, 0.2)
      love.graphics.print("Vida " .. e.hp .. " / " .. e.max, px + 300, y + 52)
    end
    local motivo = (not puesta) and motivoNo(id) or nil
    I.boton(px + pw - 28 - 130, y + 17, 130, 34, puesta and "Bajar" or "Montar", "mt_alt_" .. id, puesta or not motivo, motivo)
  end

  -- alforjas
  local cap, peso = math.floor(p.capacidadCarga or 0), math.floor(p.pesoCarga or 0)
  local y = py + ph - 108
  love.graphics.setColor(0.85, 0.82, 0.7)
  love.graphics.print("Carga " .. peso .. " / " .. cap .. (p.job and "" or "   (la carga es del oficio de comerciante o ladrón)"), px + 14, y)
  barra(px + 14, y + 22, pw - 28, 10, cap > 0 and math.min(1, peso / cap) or 0, 0.8, 0.65, 0.25)
  local partes = {}
  for _, bid in ipairs(Oficios.ORDEN_BIENES) do
    local n = (p.carga and p.carga[bid] or 0) + (p.cargaRobada and p.cargaRobada[bid] or 0)
    if n > 0 then partes[#partes + 1] = Oficios.BIENES[bid].nombre .. " ×" .. n end
  end
  love.graphics.setColor(0.7, 0.8, 0.6)
  love.graphics.printf(#partes > 0 and table.concat(partes, ", ") or "Las alforjas están vacías.", px + 14, y + 40, pw - 28, "left")
  love.graphics.setColor(0.7, 0.68, 0.6)
  love.graphics.printf("U abre y cierra este panel. Las monturas se bajan solas en las casas y en las guerras; las de transporte, al dejar el oficio.",
    px + 14, py + ph - 36, pw - 28, "left")
end

-- Recompensas diarias: el ciclo de siete días, con el de hoy resaltado, lo que da y cuándo vuelve a estar listo.
function I.panelDiaria(mundo, p, w, h)
  local Diaria = require("compartido.dominio.diaria")
  local px, py, pw, ph = w / 2 - 350, 70, 700, 440
  caja(px, py, pw, ph, "Recompensa diaria")
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  local d = p.diaria
  if not d then
    love.graphics.setColor(0.7, 0.68, 0.6)
    love.graphics.print("Consultando...", px + 14, py + 50)
    return
  end
  love.graphics.setColor(0.9, 0.86, 0.72)
  love.graphics.printf("Entra cada día y reclama tu premio. Con días seguidos la racha sube y el día 7 el premio es el mayor. Si faltas un día, vuelves al día 1.",
    px + 14, py + 40, pw - 28, "left")
  love.graphics.setColor(1, 0.9, 0.5)
  love.graphics.print("Racha: " .. (d.racha or 0) .. " día(s)", px + 14, py + 78)
  -- siete tarjetas
  local ancho, sep = 88, 8
  for n = 1, Diaria.CICLO do
    local x = px + 14 + (n - 1) * (ancho + sep)
    local y = py + 104
    local hecho = (n < d.dia) or (n == d.dia and d.reclamada)
    local hoy = n == d.dia and not d.reclamada
    local prem = Diaria.premio(n, p.nivel)
    love.graphics.setColor(hoy and 0.2 or 0.1, hoy and 0.17 or 0.13, hoy and 0.06 or 0.25, 0.97)
    love.graphics.rectangle("fill", x, y, ancho, 128, 6, 6)
    if hoy then
      local pulso = 0.6 + 0.4 * math.sin(love.timer.getTime() * 4)
      love.graphics.setColor(1, 0.82, 0.3, pulso)
      love.graphics.setLineWidth(2)
    else
      love.graphics.setColor(hecho and 0.4 or 0.35, hecho and 0.8 or 0.45, hecho and 0.45 or 0.75, 0.9)
    end
    love.graphics.rectangle("line", x + 0.5, y + 0.5, ancho - 1, 127, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.95, 0.9, 0.75)
    love.graphics.printf("Día " .. n, x, y + 6, ancho, "center")
    -- iconos de los dos primeros objetos
    for k, it in ipairs(prem.items) do
      if k > 2 then break end
      local def = Datos.item(it.id)
      if def then
        Atlas.dibujar(def.hoja, def.sprite, x + 24 + (k - 1) * 40, y + 44, 1, 16, 16, def.tinte)
        love.graphics.setColor(1, 1, 1)
        local c = "x" .. it.cant
        love.graphics.print(c, x + 24 + (k - 1) * 40 - pequena():getWidth(c) / 2, y + 58)
      end
    end
    love.graphics.setColor(1, 0.9, 0.4)
    love.graphics.printf(Ayudas.num(prem.oro) .. " oro", x, y + 78, ancho, "center")
    local extra = {}
    if prem.monedas > 0 then extra[#extra + 1] = prem.monedas .. " Monedas" end
    if prem.xp > 0 then extra[#extra + 1] = math.floor(prem.xp * 100) .. "% exp" end
    love.graphics.setColor(0.6, 0.9, 1)
    love.graphics.printf(table.concat(extra, "\n"), x, y + 94, ancho, "center")
    if hecho then
      love.graphics.setColor(0.4, 1, 0.5, 0.95)
      love.graphics.printf("✔", x, y + 24, ancho, "center")
    end
  end
  -- premio de hoy y botón
  local prem = d.premio
  love.graphics.setColor(0.95, 0.9, 0.75)
  local partes = { Ayudas.num(prem.oro) .. " de oro" }
  if prem.monedas > 0 then partes[#partes + 1] = prem.monedas .. " Monedas Corona" end
  if prem.xp > 0 then partes[#partes + 1] = math.floor(prem.xp * 100) .. "% de la experiencia del nivel" end
  for _, it in ipairs(prem.items) do
    local def = Datos.item(it.id)
    partes[#partes + 1] = it.cant .. " × " .. (def and def.nombre or it.id)
  end
  love.graphics.printf((d.reclamada and "Premio de hoy (ya reclamado): " or "Premio de hoy: ") .. table.concat(partes, ", ") .. ".", px + 14, py + 250, pw - 28, "left")
  local restaTxt = string.format("%02d:%02d:%02d", math.floor(d.resta / 3600), math.floor((d.resta % 3600) / 60), math.floor(d.resta % 60))
  love.graphics.setColor(0.7, 0.75, 0.66)
  love.graphics.print(d.reclamada and ("El siguiente premio estará listo en " .. restaTxt) or ("Se renueva en " .. restaTxt), px + 14, py + 300)
  I.boton(px + pw / 2 - 110, py + 340, 220, 44, d.reclamada and "Ya reclamada" or "Reclamar", "diaria_reclamar", not d.reclamada,
    "Vuelve mañana para el siguiente premio.")
  -- por qué no se pudo reclamar (bolsa llena, etc.): se ve aquí mismo, no solo en el chat
  if p.diariaError and not d.reclamada then
    love.graphics.setColor(1, 0.5, 0.42)
    love.graphics.printf(p.diariaError, px + 14, py + 392, pw - 28, "center")
  end
  love.graphics.setColor(0.7, 0.68, 0.6)
  love.graphics.printf("F2 abre y cierra este panel. La bolsa necesita espacio para los objetos del premio.", px + 14, py + ph - 28, pw - 28, "left")
end

-- Item Mall: tienda con monedas especiales (objetos de bonificación y addons).
-- ---------------------------------------------------------------- tarjetas (Item Mall y panel de mascotas)
-- Una tarjeta: vista previa a la izquierda; a la derecha el nombre, unas etiquetas, el texto y, abajo, el precio (con su moneda) y el botón.
-- t = { nombre, texto, extra (línea azul bajo el texto), etiquetas = { { texto, { r, g, b } }, ... }, previa = function(cx, pies, ancho, alto),
--       borde = { r, g, b }, cinta = "TUYA", barra = { fraccion, texto }, precio = n, boton = { texto, id, activo, motivo } }
local function moneda(x, y, r)
  love.graphics.setColor(0.5, 0.33, 0.06, 1)
  love.graphics.circle("fill", x, y, r + 1)
  love.graphics.setColor(1, 0.85, 0.3, 1)
  love.graphics.circle("fill", x, y, r)
  love.graphics.setColor(1, 0.96, 0.7, 0.9)
  love.graphics.circle("line", x, y, r - 2.5)
  love.graphics.setColor(0.65, 0.45, 0.1, 1)
  love.graphics.circle("fill", x, y, 2.2)
end
I.moneda = moneda

function I.tarjeta(x, y, w, h, t)
  local f = pequena()
  local borde = t.borde or { 0.32, 0.44, 0.8 }
  local encima = sobre(x, y, w, h)
  relleno(x, y, w, h, 9, encima and { 0.2, 0.25, 0.46 } or { 0.16, 0.2, 0.38 }, { 0.09, 0.11, 0.24 }, 1)
  love.graphics.setLineWidth(1.5)
  love.graphics.setColor(borde[1], borde[2], borde[3], encima and 1 or 0.7)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 9, 9)
  love.graphics.setLineWidth(1)
  -- vista previa
  local pv = 104
  love.graphics.setColor(0.04, 0.06, 0.14, 0.92)
  love.graphics.rectangle("fill", x + 8, y + 8, pv, h - 16, 7, 7)
  love.graphics.setColor(borde[1], borde[2], borde[3], 0.14)
  love.graphics.ellipse("fill", x + 8 + pv / 2, y + h - 26, pv * 0.42, 11)
  if t.previa then
    local s = I.escala or 1
    love.graphics.setScissor((x + 8) * s, (y + 8) * s, pv * s, (h - 16) * s)
    t.previa(x + 8 + pv / 2, y + h - 24, pv, h - 16)
    love.graphics.setScissor()
  end
  local tx = x + pv + 20
  local tw = w - pv - 30
  -- nombre y cinta
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(0.98, 0.9, 0.7)
  love.graphics.printf(t.nombre, tx, y + 8, tw - (t.cinta and 56 or 0), "left")
  if t.cinta then
    local cw = f:getWidth(t.cinta) + 12
    love.graphics.setColor(0.2, 0.55, 0.3, 0.95)
    love.graphics.rectangle("fill", x + w - cw - 8, y + 9, cw, 18, 9, 9)
    love.graphics.setFont(f)
    love.graphics.setColor(0.92, 1, 0.92)
    love.graphics.print(t.cinta, x + w - cw - 2, y + 11)
    love.graphics.setFont(I.fuente)
  end
  -- etiquetas
  love.graphics.setFont(f)
  local ex = tx
  for _, e in ipairs(t.etiquetas or {}) do
    local c = e[2] or { 0.55, 0.65, 0.95 }
    local cw = f:getWidth(e[1]) + 12
    if ex + cw <= tx + tw then
      love.graphics.setColor(c[1], c[2], c[3], 0.2)
      love.graphics.rectangle("fill", ex, y + 30, cw, 17, 8, 8)
      love.graphics.setColor(c[1], c[2], c[3], 0.85)
      love.graphics.rectangle("line", ex + 0.5, y + 30.5, cw - 1, 16, 8, 8)
      love.graphics.setColor(math.min(1, c[1] + 0.35), math.min(1, c[2] + 0.35), math.min(1, c[3] + 0.35), 1)
      love.graphics.print(e[1], ex + 6, y + 31)
      ex = ex + cw + 5
    end
  end
  -- texto y línea extra
  love.graphics.setColor(0.74, 0.8, 0.7)
  love.graphics.printf(t.texto or "", tx, y + 50, tw, "left")
  local _, lineas = f:getWrap(t.texto or "", tw)
  local yx = y + 50 + math.min(#lineas, 2) * f:getHeight() + 2
  if t.extra then
    love.graphics.setColor(0.6, 0.85, 1)
    love.graphics.printf(t.extra, tx, yx, tw, "left")
  end
  -- barra de experiencia (panel de mascotas)
  if t.barra then
    local by = y + h - 52
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", tx, by, tw, 7, 3, 3)
    love.graphics.setColor(0.88, 0.72, 0.22)
    love.graphics.rectangle("fill", tx, by, tw * math.max(0, math.min(1, t.barra[1])), 7, 3, 3)
    love.graphics.setColor(0.72, 0.76, 0.66)
    love.graphics.print(t.barra[2], tx, by + 8)
  end
  -- precio y botón
  if t.precio then
    moneda(tx + 8, y + h - 23, 8)
    love.graphics.setColor(1, 0.88, 0.35)
    love.graphics.print(Ayudas.num(t.precio), tx + 22, y + h - 31)
  end
  love.graphics.setFont(I.fuente)
  if t.boton then
    I.boton(x + w - 108, y + h - 38, 100, 30, t.boton[1], t.boton[2], t.boton[3], t.boton[4])
  end
end

-- Barra de desplazamiento fina a la derecha de una lista de tarjetas.
local function barraDesplazamiento(x, y, alto, primera, visibles, total)
  if total <= visibles then return end
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", x, y, 5, alto, 2, 2)
  local th = math.max(24, alto * visibles / total)
  local ty = y + (alto - th) * (primera / math.max(1, total - visibles))
  love.graphics.setColor(0.45, 0.6, 0.95, 0.9)
  love.graphics.rectangle("fill", x, ty, 5, th, 2, 2)
end

local function tiempoCorto(seg)
  seg = math.max(0, math.floor(seg or 0))
  if seg >= 3600 then return string.format("%d:%02d:%02d", math.floor(seg / 3600), math.floor((seg % 3600) / 60), seg % 60) end
  return string.format("%d:%02d", math.floor(seg / 60), seg % 60)
end

local COL_MALL = {
  oro = { 1, 0.82, 0.3 }, azul = { 0.5, 0.7, 1 }, verde = { 0.5, 0.9, 0.55 }, morado = { 0.78, 0.6, 1 }, rojo = { 1, 0.55, 0.5 }, gris = { 0.7, 0.74, 0.82 },
}
local TABS_MALL = {
  { "objetos", "Objetos", "mall_tab_obj", "Bonos, pociones y pergaminos para ir más rápido." },
  { "forja", "Forja", "mall_tab_forja", "Polvo arcano para encantar tu equipo." },
  { "addons", "Addons", "mall_tab_add", "Aspectos de personaje únicos." },
  { "monturas", "Monturas", "mall_tab_mont", "Monturas exclusivas: sin oficio y se pelea montado. Colección: U, montar: O." },
  { "mascotas", "Mascotas", "mall_tab_masc", "Mascotas de ataque que evolucionan solas y recolectoras de botín. Tus mascotas: N." },
}

-- Las tarjetas de cada pestaña del Item Mall.
local function tarjetasMall(p, m, Mall, pestana)
  local lista = {}
  local faltan = function(precio) return "Te faltan " .. Ayudas.num(math.max(0, precio - (m.monedas or 0))) .. " Monedas Corona." end
  if pestana == "objetos" or pestana == "forja" then
    for _, o in ipairs(Mall.OBJETOS) do
      if (o.polvo ~= nil) == (pestana == "forja") then
        local def = Datos.item(o.id)
        lista[#lista + 1] = {
          nombre = o.nombre, texto = o.texto, precio = o.precio,
          etiquetas = { { o.polvo ~= nil and "Polvo arcano" or (o.bono and "Bono temporal" or "Objeto"), o.polvo ~= nil and COL_MALL.morado or COL_MALL.azul } },
          previa = function(cx, pies)
            if def then
              local tt = def.tinte or { 1, 1, 1 }
              love.graphics.setColor(tt[1], tt[2], tt[3], 1)
              Atlas.dibujar(def.hoja, def.sprite, cx, pies - 30, 2, 16, 16, tt)
            end
          end,
          boton = { "Comprar", "mall_buy_" .. o.id, (m.monedas or 0) >= o.precio, faltan(o.precio) },
        }
      end
    end
  elseif pestana == "addons" then
    local tengo = {}
    for _, id in ipairs(m.addons or {}) do tengo[id] = true end
    for _, id in ipairs(Mall.ORDEN_ADDONS) do
      local a = Mall.ADDONS[id]
      local puesto = m.addonActivo == id
      lista[#lista + 1] = {
        nombre = a.nombre, texto = a.desc, precio = (not tengo[id]) and a.precio or nil,
        etiquetas = { { "Aspecto", COL_MALL.morado } },
        cinta = puesto and "PUESTO" or (tengo[id] and "TUYO" or nil),
        borde = tengo[id] and { 0.35, 0.75, 0.45 } or nil,
        previa = function(cx, pies)
          local skin = Personajes.skins[id]
          if skin then
            love.graphics.push()
            love.graphics.translate(cx, pies)
            love.graphics.scale(1.8, 1.8)
            Personajes.dibujar(skin, 1, false, 0, 0, 0)
            love.graphics.pop()
          end
        end,
        boton = tengo[id] and { puesto and "Quitar" or "Poner", "mall_ad_" .. id }
          or { "Comprar", "mall_ad_buy_" .. id, (m.monedas or 0) >= a.precio, faltan(a.precio) },
      }
    end
  elseif pestana == "monturas" then
    local tengo = {}
    for _, id in ipairs(p.monturas or {}) do tengo[id] = true end
    for _, id in ipairs(Mall.ORDEN_MONTURAS) do
      local d = Mall.MONTURAS[id]
      local M2 = Monturas.especies[id]
      lista[#lista + 1] = {
        nombre = d.nombre, texto = d.desc, precio = (not tengo[id]) and d.precio or nil,
        etiquetas = M2 and { { "+" .. math.floor(M2.vel * 100) .. "% velocidad", COL_MALL.verde }, { "Sin oficio", COL_MALL.gris } } or {},
        cinta = p.montado == id and "MONTADA" or (tengo[id] and "TUYA" or nil),
        borde = tengo[id] and { 0.35, 0.75, 0.45 } or nil,
        previa = function(cx, pies)
          local def = Personajes.monturaDe(id, p.faccion)
          local esc = 1.5
          if def and def.anim then
            local dm = require("src.presentacion.render.mob_anim").DEFS[def.anim]
            if dm then esc = math.min(1.5, 78 / math.max(1, dm.alto)) end
          end
          love.graphics.push()
          love.graphics.translate(cx, pies)
          love.graphics.scale(esc, esc)
          if def then Personajes.dibujar(def, 1, true, love.timer.getTime(), 0, 0) end
          love.graphics.pop()
        end,
        boton = tengo[id] and { "La tienes", "mall_mt_ya", false, "Ya es tuya: pulsa O para montar." }
          or { "Comprar", "mall_mt_buy_" .. id, (m.monedas or 0) >= d.precio, faltan(d.precio) },
      }
    end
  else
    local act1 = p.mascotaActiva and p.mascotas and p.mascotas[p.mascotaActiva]
    local act2 = p.recolectoraActiva and p.mascotas and p.mascotas[p.recolectoraActiva]
    for _, id in ipairs(Mall.ORDEN_MASCOTAS) do
      local d = Mascotas.especies[id]
      local tengo = false
      for _, mm in ipairs(p.mascotas or {}) do if Mascotas.mismaLinea(mm.especie, id) then tengo = true end end
      local n2 = d.evo and Mascotas.especies[d.evo]
      local n3 = n2 and n2.evo and Mascotas.especies[n2.evo]
      lista[#lista + 1] = {
        nombre = d.nombre, texto = d.desc, precio = (not tengo) and d.precio or nil,
        etiquetas = d.radio and { { "Recolectora", COL_MALL.oro }, { "radio " .. d.radio, COL_MALL.gris } }
          or { { "Ataque", COL_MALL.rojo }, { "3 etapas", COL_MALL.azul } },
        extra = n2 and ("Luego: " .. n2.nombre .. " (nv " .. d.evoNivel .. ")" .. (n3 and (" > " .. n3.nombre .. " (nv " .. n2.evoNivel .. ")") or "")) or nil,
        cinta = ((act1 and Mascotas.mismaLinea(act1.especie, id)) or (act2 and Mascotas.mismaLinea(act2.especie, id))) and "CONTIGO" or (tengo and "TUYA" or nil),
        borde = tengo and { 0.35, 0.75, 0.45 } or nil,
        previa = function(cx, pies)
          local def = Personajes.de({ kind = "mascota", especie = id })
          if def then
            love.graphics.push()
            love.graphics.translate(cx, pies)
            love.graphics.scale(2.2, 2.2)
            Personajes.dibujar(def, 1, true, love.timer.getTime(), 0, 0)
            love.graphics.pop()
          end
        end,
        boton = tengo and { "La tienes", "mall_ma_ya", false, "Ya es tuya: abre tus mascotas con N." }
          or { "Comprar", "mall_ma_buy_" .. id, (m.monedas or 0) >= d.precio, faltan(d.precio) },
      }
    end
  end
  return lista
end

function I.panelMall(mundo, p, w, h)
  local Mall = require("compartido.dominio.mall")
  local m = p.mall or { monedas = 0, addons = {} }
  local pw, ph = 720, 640
  local px, py = w / 2 - pw / 2, 30
  caja(px, py, pw, ph, "Item Mall")
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  -- saldo de monedas
  local saldo = Ayudas.num(m.monedas)
  love.graphics.setFont(I.fuente)
  local sw = I.fuente:getWidth(saldo)
  local bx = px + pw - 84 - sw - 62
  love.graphics.setColor(0.04, 0.06, 0.14, 0.9)
  love.graphics.rectangle("fill", bx, py + 7, sw + 62, 26, 13, 13)
  love.graphics.setColor(0.8, 0.62, 0.2, 0.85)
  love.graphics.rectangle("line", bx + 0.5, py + 7.5, sw + 61, 25, 13, 13)
  moneda(bx + 16, py + 20, 9)
  love.graphics.setColor(1, 0.88, 0.35)
  love.graphics.print(saldo, bx + 32, py + 11)
  love.graphics.setColor(0.7, 0.66, 0.5)
  love.graphics.setFont(pequena())
  love.graphics.print("Monedas", bx + sw + 36, py + 13)
  love.graphics.setFont(I.fuente)
  -- pestañas
  I.mallTab = I.mallTab or "objetos"
  local gap = 6
  local tabw = (pw - 28 - gap * (#TABS_MALL - 1)) / #TABS_MALL
  local descripcion
  for i, t in ipairs(TABS_MALL) do
    local tx, ty = px + 14 + (i - 1) * (tabw + gap), py + 42
    local activa = I.mallTab == t[1]
    local hover = sobre(tx, ty, tabw, 30)
    if activa then
      descripcion = t[4]
      relleno(tx, ty, tabw, 30, 8, { 0.45, 0.36, 0.14 }, { 0.26, 0.2, 0.08 }, 1)
      love.graphics.setColor(1, 0.82, 0.3, 1)
    else
      relleno(tx, ty, tabw, 30, 8, hover and { 0.24, 0.32, 0.6 } or { 0.15, 0.2, 0.4 }, { 0.08, 0.1, 0.22 }, 1)
      love.graphics.setColor(0.35, 0.48, 0.85, hover and 1 or 0.7)
    end
    love.graphics.rectangle("line", tx + 0.5, ty + 0.5, tabw - 1, 29, 8, 8)
    love.graphics.setColor(activa and 1 or 0.85, activa and 0.95 or 0.9, activa and 0.7 or 1)
    love.graphics.printf(t[2], tx, ty + 6, tabw, "center")
    I.registrar(tx, ty, tabw, 30, t[3])
  end
  -- tarjetas en dos columnas
  local lista = tarjetasMall(p, m, Mall, I.mallTab)
  local colW, cardH, sep = (pw - 28 - 12) / 2, 148, 10
  local filas = math.ceil(#lista / 2)
  local visibles = 3
  I.mallScrollMax = math.max(0, filas - visibles)
  I.mallScroll = math.max(0, math.min(I.mallScrollMax, I.mallScroll or 0))
  love.graphics.setFont(pequena())
  love.graphics.setColor(0.65, 0.66, 0.6)
  love.graphics.print(descripcion or "", px + 16, py + 78)
  if I.mallScrollMax > 0 then
    love.graphics.printf("Rueda del ratón: " .. (I.mallScroll * 2 + 1) .. "-" .. math.min(#lista, (I.mallScroll + visibles) * 2) .. " de " .. #lista, px + 14, py + 78, pw - 28, "right")
  end
  love.graphics.setFont(I.fuente)
  local gy = py + 96
  for i, t in ipairs(lista) do
    local fila, col = math.floor((i - 1) / 2), (i - 1) % 2
    if fila >= I.mallScroll and fila < I.mallScroll + visibles then
      I.tarjeta(px + 14 + col * (colW + 12), gy + (fila - I.mallScroll) * (cardH + sep), colW, cardH, t)
    end
  end
  barraDesplazamiento(px + pw - 12, gy, visibles * cardH + (visibles - 1) * sep, I.mallScroll, visibles, filas)
  -- bonos activos
  local yb = py + ph - 70
  love.graphics.setColor(TEMA.borde[1], TEMA.borde[2], TEMA.borde[3], 0.4)
  love.graphics.rectangle("fill", px + 14, yb - 6, pw - 28, 1)
  love.graphics.setFont(pequena())
  love.graphics.setColor(0.85, 0.82, 0.7)
  love.graphics.print("Bonos activos", px + 16, yb)
  local x = px + 110
  local hay = false
  for _, id in ipairs(Mall.ORDEN_BONOS) do
    local resta = m.bonos and m.bonos[id]
    if resta and resta > 0 then
      hay = true
      local b = Mall.BONOS[id]
      local txt = b.etiqueta .. " " .. tiempoCorto(resta)
      local cw = pequena():getWidth(txt) + 14
      love.graphics.setColor(b.color[1], b.color[2], b.color[3], 0.2)
      love.graphics.rectangle("fill", x, yb - 2, cw, 20, 9, 9)
      love.graphics.setColor(b.color[1], b.color[2], b.color[3], 1)
      love.graphics.print(txt, x + 7, yb)
      x = x + cw + 6
    end
  end
  if not hay then
    love.graphics.setColor(0.6, 0.6, 0.55)
    love.graphics.print("Ninguno. Usa una tarjeta o pergamino desde la bolsa (clic).", px + 110, yb)
  end
  love.graphics.setColor(0.6, 0.6, 0.55)
  love.graphics.printf("Las monedas las reparte un administrador por ahora. Los bonos siguen contando aunque no estés conectado.", px + 16, yb + 26, pw - 32, "left")
  love.graphics.setFont(I.fuente)
end

-- El objeto del mall que concede cada bono, para pintar su icono.
local iconoPorBono
local function idIconoBono(id)
  if not iconoPorBono then
    iconoPorBono = {}
    local Mall = require("compartido.dominio.mall")
    for _, o in ipairs(Mall.OBJETOS) do
      if o.bono and not iconoPorBono[o.bono] then iconoPorBono[o.bono] = o.id end
    end
  end
  return iconoPorBono[id]
end

-- Bonos activos junto a la vida, en fila: solo el icono. El tiempo sale al pasar el mouse.
function I.estadoBonos(mundo, p, x, y)
  local m = p.mall
  if not m or not m.bonos then return end
  local Mall = require("compartido.dominio.mall")
  local lado = 32
  local cx = x
  for _, id in ipairs(Mall.ORDEN_BONOS) do
    local resta = m.bonos[id]
    if resta and resta > 0 then
      local b = Mall.BONOS[id]
      local itemId = idIconoBono(id)
      local it = itemId and Datos.item(itemId)
      if it then Atlas.dibujar(it.hoja, it.sprite, cx + lado / 2, y + lado / 2, 1, 16, 16, it.tinte) end
      if sobre(cx, y, lado, lado) then
        I.pista = (b.nombre or b.etiqueta) .. ": " .. tiempoCorto(resta)
      end
      cx = cx + lado + 4
    end
  end
end

-- Barquero: viaje en barco entre los puertos de los continentes (al instante, por oro).
function I.panelViaje(mundo, p, w, h)
  local Viaje = require("compartido.dominio.viaje")
  local mapa = mundo.mapas.mundo
  local px, py, pw, ph = w / 2 - 300, 110, 600, 400
  caja(px, py, pw, ph, "Barquero")
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(0.85, 0.82, 0.7)
  love.graphics.print("Oro: " .. Ayudas.num(p.oro), px + 16, py + 42)
  local origen = Viaje.puertoCerca(mapa, p.x, p.y)
  if not origen then
    love.graphics.setColor(0.75, 0.7, 0.6)
    love.graphics.print("Acércate al barquero de un puerto para embarcar.", px + 16, py + 70)
    return
  end
  love.graphics.setColor(0.7, 0.75, 0.9)
  love.graphics.printf("Estás en " .. origen.nombre .. ". El barco te lleva al instante a otro continente; si llevas montura, bajas de ella.", px + 16, py + 66, pw - 32, "left")
  local y = py + 110
  for _, pu in ipairs(mapa.puertos or {}) do
    if pu.id ~= origen.id then
      local precio = Viaje.precio(origen, pu)
      local cont = mapa.continentes and mapa.continentes[pu.cont]
      love.graphics.setColor(0.10, 0.13, 0.25)
      love.graphics.rectangle("fill", px + 14, y, pw - 28, 64, 8, 8)
      love.graphics.setColor(0.98, 0.9, 0.7)
      love.graphics.print(pu.nombre, px + 28, y + 8)
      love.graphics.setColor(0.65, 0.72, 0.9)
      love.graphics.print(cont and cont.nombre or "", px + 28, y + 30)
      love.graphics.setColor(1, 0.9, 0.4)
      love.graphics.printf(Ayudas.num(precio) .. " oro", px + pw - 290, y + 20, 110, "right")
      local falta = (p.oro or 0) < precio
      I.boton(px + pw - 160, y + 16, 134, 32, "Navegar", "viaje_" .. pu.id, not falta,
        "Te faltan " .. Ayudas.num(precio - (p.oro or 0)) .. " de oro.")
      y = y + 72
    end
  end
end

function I.panelEstablo(mundo, p, w, h)
  local px, py, pw, ph = w / 2 - 340, 60, 680, 470
  caja(px, py, pw, ph, "Establo")
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  local d = I.datosPanel.establo
  if not d then
    love.graphics.setColor(0.7, 0.68, 0.6)
    love.graphics.print("Consultando...", px + 14, py + 50)
    return
  end
  love.graphics.setColor(0.85, 0.82, 0.7)
  love.graphics.print("Oro: " .. Ayudas.num(p.oro) .. (d.montado and "   (vas montado: tecla O para bajar)" or ""), px + 14, py + 38)
  -- pestanas: monturas de transporte (piden el oficio activo) y monturas normales (de viaje)
  I.establoTab = I.establoTab or "transporte"
  local pestanas = { { "transporte", "Transporte (oficio)" }, { "normales", "Monturas normales" } }
  for k, t in ipairs(pestanas) do
    local tx, ty, tw = px + 14 + (k - 1) * 214, py + 64, 208
    local activa = I.establoTab == t[1]
    local hover = sobre(tx, ty, tw, 28)
    love.graphics.setColor(activa and 0.27 or (hover and 0.16 or 0.09), activa and 0.4 or (hover and 0.24 or 0.13), activa and 0.8 or (hover and 0.5 or 0.27), 0.97)
    love.graphics.rectangle("fill", tx, ty, tw, 28, 7, 7)
    love.graphics.setColor(activa and I.TEMA.acento[1] or 0.35, activa and I.TEMA.acento[2] or 0.5, activa and I.TEMA.acento[3] or 0.9, activa and 1 or 0.7)
    love.graphics.rectangle("line", tx + 0.5, ty + 0.5, tw - 1, 27, 7, 7)
    love.graphics.setColor(activa and 1 or 0.85, activa and 0.95 or 0.88, activa and 0.8 or 0.95)
    love.graphics.printf(t[2], tx, ty + 5, tw, "center")
    I.registrar(tx, ty, tw, 28, "est_tab_" .. t[1])
  end
  local lista = {}
  for _, m in ipairs(d.catalogo) do
    if (m.requiereOficio and true or false) == (I.establoTab == "transporte") then lista[#lista + 1] = m end
  end
  -- hay muchas: se muestran de cinco en cinco
  local PAG_ESTABLO = 5
  local paginasE = math.max(1, math.ceil(#lista / PAG_ESTABLO))
  I.establoPag = math.max(1, math.min(paginasE, I.establoPag or 1))
  if paginasE > 1 then
    I.boton(px + pw - 150, py + 64, 34, 28, "<", "est_pag_ant", I.establoPag > 1)
    love.graphics.setColor(0.85, 0.82, 0.7)
    love.graphics.printf(I.establoPag .. " / " .. paginasE, px + pw - 116, py + 70, 50, "center")
    I.boton(px + pw - 62, py + 64, 34, 28, ">", "est_pag_sig", I.establoPag < paginasE)
  end
  if #lista == 0 then
    love.graphics.setColor(0.85, 0.82, 0.7)
    love.graphics.printf("No hay monturas en esta lista. Hay más en el Item Mall (tecla L, pestaña Monturas).", px + 20, py + 120, pw - 40, "left")
  end
  for k = 1, PAG_ESTABLO do
    local m = lista[(I.establoPag - 1) * PAG_ESTABLO + k]
    if not m then break end
    local y = py + 102 + (k - 1) * 62
    love.graphics.setColor(0.10, 0.13, 0.25)
    love.graphics.rectangle("fill", px + 14, y, pw - 28, 56, 6, 6)
    local def = Personajes.monturaDe(m.id, p.faccion)
    if def and def.hoja then Personajes.dibujar(def, 1, false, love.timer.getTime(), px + 54, y + 50) end
    if def and def.vehiculo then
      local img = Arte.img("Characters/Vehicle.png")
      love.graphics.setColor(1, 1, 1)
      love.graphics.draw(img, Arte.quad(img, 128, 128, 32, 32), px + 54, y + 50, 0, 1.3, 1.3, 16, 28)
    end
    local nivelOk = (p.nivel or 1) >= m.nivel
    love.graphics.setColor(nivelOk and 0.95 or 0.6, nivelOk and 0.9 or 0.58, nivelOk and 0.75 or 0.52)
    love.graphics.print(m.nombre .. "   " .. (m.precio > 0 and (Ayudas.num(m.precio) .. " oro") or "Gratis") .. "  (nv " .. m.nivel .. ")", px + 100, y + 4)
    love.graphics.setColor(0.72, 0.78, 0.68)
    love.graphics.printf(m.desc, px + 100, y + 22, 330, "left")
    love.graphics.setColor(0.6, 0.85, 1)
    love.graphics.print("Vel +" .. math.floor(m.vel * 100) .. "%" .. (m.carga > 0 and ("  Carga +" .. m.carga) or ""), px + pw - 28 - 150, y + 40)
    local montadoAqui = d.montado == m.id
    if m.tengo then
      I.boton(px + pw - 28 - 150, y + 4, 150, 32, montadoAqui and "Bajar" or "Montar", "mt_alt_" .. m.id)
    else
      local motivo
      if not d.cerca then motivo = "Acércate al mozo de cuadra para comprar."
      elseif not nivelOk then motivo = "Necesitas nivel " .. m.nivel .. " (tienes " .. (p.nivel or 1) .. ")."
      elseif (p.oro or 0) < m.precio then motivo = "Te faltan " .. Ayudas.num(m.precio - (p.oro or 0)) .. " de oro." end
      I.boton(px + pw - 28 - 150, y + 4, 150, 32, "Comprar", "mt_buy_" .. m.id, d.cerca and nivelOk and true or false, motivo)
    end
  end
  love.graphics.setColor(0.65, 0.78, 1)
  love.graphics.printf(I.establoTab == "transporte" and "Transporte: cargan mercancía y solo se usan con el oficio activo." or "Normales: sin oficio, para viajar rápido; se puede pelear montado.", px + 14, py + ph - 76, pw - 28, "left")
  love.graphics.setColor(0.7, 0.68, 0.6)
  love.graphics.printf("Se compran en las cuadras. Pulsa O para montar o bajar de la última que usaste. Las monturas se bajan solas en las casas y en las guerras. Ir cargado te frena, salvo con montura.",
    px + 14, py + ph - 50, pw - 28, "left")
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
  love.graphics.print("Oro: " .. Ayudas.num(p.oro) .. (d.cerca and "" or "     (acércate al subastador para operar)"), px + 150, py + 12)
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
    love.graphics.setColor(activa and 0.27 or 0.09, activa and 0.4 or 0.13, activa and 0.8 or 0.27, 0.95)
    love.graphics.rectangle("fill", x, py + 44, ancho, 24, 3, 3)
    love.graphics.setColor(0.45, 0.6, 0.95)
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
      love.graphics.setColor(0.09, 0.12, 0.23)
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
      love.graphics.setColor(0.10, 0.13, 0.25)
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
      love.graphics.setColor(0.10, 0.13, 0.25)
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
    love.graphics.setColor(0.09, 0.12, 0.23)
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

-- ---------------------------------------------------------------------------------------
-- Grupo (party)
-- ---------------------------------------------------------------------------------------
-- Marco con los miembros del grupo en una esquina: vida de cada uno y clic para elegirlo (curas).
function I.estadoGrupo(mundo, p, x, y)
  local g = p.grupo
  if not g then return end
  local f = pequena()
  love.graphics.setFont(f)
  local alto = #g.miembros * 30 + 22
  marco(x, y, 180, alto, true)
  texto("Grupo (" .. #g.miembros .. "/" .. g.max .. ")", x + 8, y + 3, { 0.55, 0.8, 1 }, f)
  for i, m in ipairs(g.miembros) do
    local yy = y + 20 + (i - 1) * 30
    local lider = m.id == g.lider
    local color = m.cerca and { 0.95, 0.92, 0.8 } or { 0.55, 0.55, 0.5 }
    texto((lider and "[L] " or "") .. m.nombre .. "  nv " .. m.nivel, x + 8, yy, color, f)
    local frac = math.max(0, math.min(1, m.hp / math.max(1, m.hpMax)))
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", x + 8, yy + 15, 164, 8)
    local cr, cg, cb = Dibujo.colorVida(frac)
    love.graphics.setColor(cr, cg, cb, m.cerca and 1 or 0.5)
    love.graphics.rectangle("fill", x + 8, yy + 15, 164 * frac, 8)
    if p.objetivo == m.id then
      love.graphics.setColor(1, 0.25, 0.2, 0.9)
      love.graphics.rectangle("line", x + 4, yy - 2, 172, 28, 3, 3)
    end
    I.registrar(x + 4, yy - 2, 172, 28, "gp_sel_" .. m.id)
  end
end

function I.panelGrupo(mundo, p, w, h)
  local px, py, pw, ph = w / 2 - 280, 70, 560, 440
  caja(px, py, pw, ph, "Grupo")
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  local g = p.grupo
  love.graphics.setColor(0.85, 0.82, 0.7)
  love.graphics.printf("Hasta " .. (g and g.max or 5) .. " jugadores de tu corona. Al derrotar una criatura, la experiencia (con un " ..
    math.floor(((g and g.bono) or 0.1) * 100) .. "% extra) se reparte entre los miembros que estén cerca. Cerca de un grupo salen criaturas de grupo y gigantes. Chat: /p.",
    px + 14, py + 40, pw - 28, "left")
  local objetivo = p.objetivo and mundo.entidades[p.objetivo]
  local valido = objetivo and objetivo.kind == "jugador" and not objetivo.enGrupo and objetivo.faccion == p.faccion
  local esLider = g and g.lider == p.id
  if not g or esLider then
    I.boton(px + 14, py + 112, 300, 32, valido and ("Invitar a " .. objetivo.nombre) or "Invitar (elige un jugador)", "gp_invitar", valido and true or false)
  end
  if not g then
    love.graphics.setColor(0.7, 0.68, 0.6)
    love.graphics.print("No estás en ningún grupo.", px + 14, py + 160)
    return
  end
  for i, m in ipairs(g.miembros) do
    local y = py + 156 + (i - 1) * 40
    love.graphics.setColor(0.10, 0.13, 0.25)
    love.graphics.rectangle("fill", px + 14, y, pw - 28, 34, 4, 4)
    love.graphics.setColor(m.cerca and 0.95 or 0.6, m.cerca and 0.9 or 0.6, m.cerca and 0.75 or 0.55)
    love.graphics.print((m.id == g.lider and "[L] " or "") .. m.nombre .. "   nv " .. m.nivel .. "   " .. (Datos.clases[m.clase] and Datos.clases[m.clase].nombre or ""), px + 26, y + 9)
    love.graphics.setColor(0.6, 0.85, 0.6)
    love.graphics.print(m.hp .. "/" .. m.hpMax, px + 300, y + 9)
    love.graphics.setColor(m.cerca and 0.5 or 0.9, m.cerca and 0.85 or 0.6, m.cerca and 0.5 or 0.4)
    love.graphics.print(m.cerca and "cerca" or "lejos", px + 370, y + 9)
    if esLider and m.id ~= p.id then
      I.boton(px + pw - 28 - 160, y + 4, 76, 26, "Mando", "gp_lider_" .. m.id)
      I.boton(px + pw - 28 - 80, y + 4, 80, 26, "Expulsar", "gp_exp_" .. m.id)
    end
  end
  local yb = py + ph - 52
  I.boton(px + 14, yb, 120, 34, "Salir", "gp_salir")
  if esLider then I.boton(px + 144, yb, 140, 34, I.confirmaGrupo and "¿Seguro?" or "Disolver", "gp_disolver") end
end

function I.panelMascotas(mundo, p, w, h)
  local pw, ph = 720, 600
  local px, py = w / 2 - pw / 2, 40
  caja(px, py, pw, ph, "Tus mascotas")
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  local mias = p.mascotas or {}
  -- cuántas tienes y cuál está fuera
  love.graphics.setFont(pequena())
  love.graphics.setColor(0.72, 0.74, 0.66)
  local fuera1 = p.mascotaActiva and mias[p.mascotaActiva]
  local fuera2 = p.recolectoraActiva and mias[p.recolectoraActiva]
  local function nombreDe(m) return m and Mascotas.especies[m.especie] and Mascotas.especies[m.especie].nombre or nil end
  local contigo = {}
  if nombreDe(fuera1) then contigo[#contigo + 1] = nombreDe(fuera1) end
  if nombreDe(fuera2) then contigo[#contigo + 1] = nombreDe(fuera2) end
  love.graphics.print(#mias .. " de " .. Mascotas.MAX_MASCOTAS .. " mascotas  ·  " .. (#contigo > 0 and ("contigo: " .. table.concat(contigo, " y ")) or "ninguna fuera") .. "  ·  puede salir una de ataque y una recolectora a la vez", px + 16, py + 40)
  love.graphics.setFont(I.fuente)
  if #mias == 0 then
    love.graphics.setColor(0.8, 0.78, 0.65)
    love.graphics.printf("Aún no tienes ninguna mascota.", px + 20, py + 120, pw - 40, "center")
    love.graphics.setFont(pequena())
    love.graphics.setColor(0.65, 0.68, 0.6)
    love.graphics.printf("El osito pardo se compra con oro en la tienda del mercado (la enfermera, pestaña Mascotas).\nLa cría de dragón, las pelusas y las recolectoras, con Monedas Corona en el Item Mall (L).", px + 40, py + 160, pw - 80, "center")
    love.graphics.setFont(I.fuente)
  end
  -- tarjetas en dos columnas
  local colW, cardH, sep = (pw - 28 - 12) / 2, 148, 10
  local filas = math.ceil(#mias / 2)
  local visibles = 3
  I.mascScrollMax = math.max(0, filas - visibles)
  I.mascScroll = math.max(0, math.min(I.mascScrollMax, I.mascScroll or 0))
  local gy = py + 62
  for i, m in ipairs(mias) do
    local d = Mascotas.especies[m.especie]
    local fila, col = math.floor((i - 1) / 2), (i - 1) % 2
    if d and fila >= I.mascScroll and fila < I.mascScroll + visibles then
      local fuera = p.mascotaActiva == i or p.recolectoraActiva == i
      local sig = Mascotas.xpPara(m.nivel)
      local tope = m.nivel >= math.min(Mascotas.NIVEL_MAX, p.nivel or 1)
      local n2 = d.evo and Mascotas.especies[d.evo]
      local etiquetas = { { "nv " .. m.nivel, { 0.9, 0.82, 0.4 } } }
      if d.radio then
        etiquetas[#etiquetas + 1] = { "Recolectora", { 1, 0.82, 0.3 } }
      else
        etiquetas[#etiquetas + 1] = { "Etapa " .. (d.etapa or 1) .. "/3", { 0.5, 0.7, 1 } }
      end
      I.tarjeta(px + 14 + col * (colW + 12), gy + (fila - I.mascScroll) * (cardH + sep), colW, cardH, {
        nombre = d.nombre,
        texto = d.desc,
        extra = n2 and ("Evoluciona a " .. n2.nombre .. " (nv " .. d.evoNivel .. ")") or (d.radio and ("Recoge el botín en " .. d.radio .. " casillas") or "Forma final"),
        etiquetas = etiquetas,
        cinta = fuera and "FUERA" or nil,
        borde = fuera and { 0.35, 0.8, 0.45 } or nil,
        barra = (not d.radio) and { tope and 1 or ((m.xp or 0) / sig), tope and "al nivel de su dueño" or ((m.xp or 0) .. " / " .. sig .. " xp") } or nil,
        previa = function(cx, pies)
          local def = Personajes.de({ kind = "mascota", especie = m.especie })
          if def then
            love.graphics.push()
            love.graphics.translate(cx, pies)
            love.graphics.scale(2.2, 2.2)
            Personajes.dibujar(def, 1, true, love.timer.getTime(), 0, 0)
            love.graphics.pop()
          end
        end,
        boton = { fuera and "Guardar" or "Invocar", "masc_inv_" .. i },
      })
    end
  end
  -- barra de desplazamiento
  if filas > visibles then
    love.graphics.setColor(0, 0, 0, 0.45)
    local alto = visibles * cardH + (visibles - 1) * sep
    love.graphics.rectangle("fill", px + pw - 12, gy, 5, alto, 2, 2)
    local th = math.max(24, alto * visibles / filas)
    love.graphics.setColor(0.45, 0.6, 0.95, 0.9)
    love.graphics.rectangle("fill", px + pw - 12, gy + (alto - th) * (I.mascScroll / math.max(1, filas - visibles)), 5, th, 2, 2)
  end
  love.graphics.setFont(pequena())
  love.graphics.setColor(0.65, 0.66, 0.6)
  love.graphics.printf("Te siguen, pelean a tu lado y suben de nivel contigo (sin pasar el tuyo); evolucionan solas al llegar a ciertos niveles. Puede salir una de ataque y una recolectora a la vez; descansan durante las guerras y, si una cae en combate, vuelve a los 30 s. Tecla N: abrir o cerrar esta lista.", px + 16, py + ph - 62, pw - 32, "left")
  love.graphics.setFont(I.fuente)
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
  love.graphics.print("Polvo arcano: " .. polvo .. "     Oro: " .. Ayudas.num(p.oro), px + 12, py + 34)
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
  local capacidad = Datos.capacidadBolsa(p.equipo)
  local mochila = p.equipo.mochila and Datos.item(p.equipo.mochila)
  local px, py, pw, ph = w / 2 - 280, h / 2 - 230, 560, 460
  caja(px, py, pw, ph, "Bolsa")
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  local f = pequena()
  love.graphics.setFont(f)
  love.graphics.setColor(0.78, 0.84, 0.95)
  love.graphics.print((mochila and mochila.nombre or "Bolsillos") .. "     " .. #p.bolsa .. " / " .. capacidad, px + 18, py + 40)
  for i = 1, Datos.BOLSA do
    local col = (i - 1) % 6
    local fila = math.floor((i - 1) / 6)
    local x = px + 28 + col * 64
    local y = py + 68 + fila * 64
    casilla(x, y, 56)
    if i > Datos.capacidadBolsa(p.equipo) then
      love.graphics.setColor(0, 0, 0, 0.6)
      love.graphics.rectangle("fill", x, y, 56, 56)
      goto siguiente
    end
    local slot = p.bolsa[i]
    if I.arrastre == i or (I.sel == i and slot) then
      love.graphics.setColor(0.98, 0.78, 0.36, 0.3)
      love.graphics.rectangle("fill", x, y, 56, 56, 5, 5)
      love.graphics.setColor(0.98, 0.78, 0.36, 0.9)
      love.graphics.rectangle("line", x + 0.5, y + 0.5, 55, 55, 5, 5)
    end
    if slot then
      local it = Datos.item(slot.id)
      if it then Atlas.dibujar(it.hoja, it.sprite, x + 28, y + 30, 1.2, 16, 16, it.tinte) end
      if slot.cant and slot.cant > 1 then
        local t = tostring(slot.cant)
        love.graphics.setFont(f)
        local tw = f:getWidth(t)
        love.graphics.setColor(0.04, 0.05, 0.08, 0.88)
        love.graphics.rectangle("fill", x + 52 - tw - 6, y + 38, tw + 8, 16, 3, 3)
        love.graphics.setColor(1, 0.96, 0.82)
        love.graphics.print(t, x + 52 - tw - 2, y + 39)
      end
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
  love.graphics.setFont(f)
  love.graphics.setColor(0.86, 0.82, 0.7)
  love.graphics.printf("Un clic elige. Otro clic en la misma casilla equipa.\nUn clic en otra casilla intercambia.", px + 24, py + ph - 48, pw - 48, "center")
end

-- Panel Personaje (tecla C): resumen del personaje, su equipo (con cifras de cada pieza) y estadísticas.
function I.panelEquipo(mundo, p, w, h)
  local px, py, pw, ph = w / 2 - 340, h / 2 - 260, 680, 520
  caja(px, py, pw, ph, "Personaje")
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  local f = pequena()
  local fac = Datos.facciones[p.faccion]
  local clase = Datos.clases[p.clase]
  -- retrato y datos
  love.graphics.setColor(0.10, 0.13, 0.25)
  love.graphics.rectangle("fill", px + 14, py + 44, 200, 150, 6, 6)
  local addonAct = (p.mall and p.mall.addonActivo) or p.addon
  I.persona(p.clase, px + 114, py + 160, 1.7, p.faccion, addonAct, p.genero or p.gen, p.equipo)
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(0.98, 0.93, 0.78)
  love.graphics.printf(p.nombre or "", px + 14, py + 198, 200, "center")
  texto((clase and clase.nombre or "") .. " de " .. (fac and fac.nombre or ""), px + 14, py + 218, fac and fac.color or { 1, 1, 1 })
  local xpN = p.xpSig or Datos.xpPara(p.nivel)
  barra(px + 14, py + 238, 200, 14, (p.xp or 0) / xpN, 0.85, 0.7, 0.2)
  texto("Nivel " .. p.nivel .. "   exp " .. math.floor(p.xp or 0) .. " / " .. xpN, px + 20, py + 238, { 1, 1, 1 })
  local y = py + 262
  local function dato(etiqueta, valor, color)
    texto(etiqueta, px + 16, y, { 0.75, 0.7, 0.55 })
    texto(valor, px + 120, y, color or { 1, 0.95, 0.85 })
    y = y + 18
  end
  dato("Oro", Ayudas.num(p.oro), { 1, 0.9, 0.35 })
  dato("Monedas Corona", Ayudas.num(p.mall and p.mall.monedas), { 1, 0.85, 0.3 })
  dato("Oficio", p.oficioElegido and (NOMBRES_OFICIO[p.oficioElegido] or p.oficioElegido) or "ninguno")
  local ad = addonAct and require("compartido.dominio.mall").ADDONS[addonAct]
  dato("Addon", ad and ad.nombre or "ninguno")
  dato("Gremio", p.gremioNombre or "ninguno")
  dato("Grupo", (p.grupo and p.grupo.miembros and (#p.grupo.miembros .. " miembros")) or "ninguno")
  dato("Zona", p.zona or "—")
  -- estadísticas
  y = y + 6
  love.graphics.setColor(0.3, 0.44, 0.82)
  love.graphics.line(px + 14, y, px + 214, y)
  y = y + 6
  local magico = clase and clase.danoBasico == "magico"
  local dmin, dmax = Balance.rangoDano(magico and (p.matk or 0) or (p.atk or 0), 0, 1)
  local FIS, MAG = { 1, 0.78, 0.5 }, { 0.75, 0.65, 1 }
  dato("Ataque", tostring(math.floor(p.atk or 0)), FIS)
  dato("Ataque mágico", tostring(math.floor(p.matk or 0)), MAG)
  dato("Defensa", tostring(math.floor(p.def or 0)), FIS)
  dato("Defensa mágica", tostring(math.floor(p.mdef or 0)), MAG)
  dato("Daño básico", dmin .. " - " .. dmax, magico and MAG or FIS)
  dato("Velocidad", string.format("%.1f", p.spd or 0))
  if sobre(px + 14, py + 262, 200, 200) then
    I.pista = "Los golpes físicos se reducen con Defensa y los mágicos con Defensa mágica (Res)."
  end
  -- equipo
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(0.95, 0.9, 0.75)
  love.graphics.print("Equipo (clic en una pieza para quitarla)", px + 236, py + 46)
  local huecos = { { "arma", "Arma" }, { "escudo", "Escudo" }, { "cabeza", "Cabeza" }, { "pecho", "Pecho" }, { "piernas", "Piernas" },
    { "pies", "Pies" }, { "anillo", "Anillo" }, { "amuleto", "Amuleto" }, { "mochila", "Mochila" } }
  for i, hh in ipairs(huecos) do
    local hueco = hh[1]
    local yy = py + 70 + (i - 1) * 46
    local it = p.equipo[hueco] and Datos.item(p.equipo[hueco])
    local ancho = pw - 236 - 16
    local hover = sobre(px + 236, yy, ancho, 42)
    love.graphics.setColor(hover and 0.15 or 0.1, hover and 0.2 or 0.13, hover and 0.36 or 0.25)
    love.graphics.rectangle("fill", px + 236, yy, ancho, 42, 4, 4)
    casilla(px + 240, yy + 3, 36)
    if it then
      local enc = p.encantos and p.encantos[hueco]
      iconoItem({ id = it.id }, px + 240, yy + 3, 36, enc)
      love.graphics.setFont(I.fuente)
      love.graphics.setColor(0.95, 0.9, 0.75)
      love.graphics.print(I.nombreItem(it, enc), px + 284, yy + 3)
      love.graphics.setColor(0.7, 0.75, 0.65)
      love.graphics.print(I.statsTexto(it, enc), px + 284, yy + 22)
    else
      love.graphics.setFont(I.fuente)
      love.graphics.setColor(0.55, 0.5, 0.42)
      love.graphics.print(hh[2] .. " — vacío", px + 284, yy + 12)
    end
    I.registrar(px + 236, yy, ancho, 42, "equip_" .. hueco)
  end
  love.graphics.setColor(0.7, 0.68, 0.6)
  love.graphics.setFont(f)
  love.graphics.printf("I abre la bolsa. K el árbol de poderes. Esc cierra este panel.", px + 14, py + ph - 24, pw - 28, "left")
  love.graphics.setFont(I.fuente)
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
  if it.cura then
    local hasta = it.curaMax and it.curaMax ~= it.cura and ("-" .. math.floor(it.curaMax)) or ""
    partes[#partes + 1] = "Vida +" .. math.floor(it.cura) .. hasta
  end
  if it.mana and not it.hueco then
    local hasta = it.manaMax and it.manaMax ~= it.mana and ("-" .. math.floor(it.manaMax)) or ""
    partes[#partes + 1] = "Maná +" .. math.floor(it.mana) .. hasta
  end
  local pre = ""
  if it.armadura then pre = "Armadura " .. it.armadura .. ". " end
  return pre .. table.concat(partes, "  ")
end

-- La enfermera vende solo pociones. Cada maestro, el equipo de su clase (armas, armaduras, escudos, accesorios y mochilas).
local CAT_POCIONES = { id = "pociones", nombre = "Pociones" }
local CAT_ARMAS = { id = "armas", nombre = "Armas", huecos = { arma = true } }
local CAT_ARMADURA = { id = "armadura", nombre = "Armadura", huecos = { cabeza = true, pecho = true, piernas = true, pies = true } }
local CAT_ESCUDOS = { id = "escudos", nombre = "Escudos", huecos = { escudo = true } }
local CAT_ACCESORIOS = { id = "accesorios", nombre = "Accesorios", huecos = { anillo = true, amuleto = true } }
local CAT_MOCHILAS = { id = "mochilas", nombre = "Mochilas", huecos = { mochila = true } }
local CAT_VENDER = { id = "vender", nombre = "Vender" }
local CAT_MASCOTAS = { id = "mascotas", nombre = "Mascotas" }
local TIENDAS = {
  mercado = { titulo = "Tienda del mercado", cats = { CAT_POCIONES, CAT_MASCOTAS, CAT_VENDER } },
}
for clase, nombre in pairs({ guerrero = "guerrero", lancero = "lancero", cazador = "arquero", mago = "mago", clerigo = "clérigo", nigromante = "nigromante" }) do
  TIENDAS["maestro_" .. clase] = { titulo = "Maestro " .. nombre, clase = clase, cats = { CAT_ARMAS, CAT_ARMADURA, CAT_ESCUDOS, CAT_ACCESORIOS, CAT_MOCHILAS, CAT_VENDER } }
end

-- Lo que vende el mercado en una categoría, para tu clase y tu nivel.
function I.listaItemsClase(p, cat)
  cat = cat or "pociones"
  if cat == "pociones" then
    local lista = {}
    for id, it in pairs(Datos.items) do
      if (Datos.esTipoPocion(it, "vida") or Datos.esTipoPocion(it, "mana") or it.teletransporte) and (it.nivel or 1) <= (p.nivel or 1) + 4 then
        lista[#lista + 1] = id
      end
    end
    table.sort(lista, function(a, b)
      local x, y = Datos.items[a], Datos.items[b]
      if (x.nivel or 1) ~= (y.nivel or 1) then return (x.nivel or 1) < (y.nivel or 1) end
      local vx, vy = x.teletransporte and 2 or (x.cura and 0 or 1), y.teletransporte and 2 or (y.cura and 0 or 1)
      if vx ~= vy then return vx < vy end
      return a < b
    end)
    return lista
  end
  local def
  for _, tienda in pairs(TIENDAS) do
    for _, c in ipairs(tienda.cats) do if c.id == cat then def = c end end
  end
  if not def or not def.huecos then return {} end
  local lista = {}
  for id, it in pairs(Datos.items) do
    -- solo lo que ya puedes llevar o está a pocos niveles
    local claseTienda = (TIENDAS[I.tienda] or {}).clase or p.clase
    if it.hueco and def.huecos[it.hueco] and (not it.clase or it.clase == claseTienda) and not it.quest and not it.botin and (it.nivel or 1) <= (p.nivel or 1) + 4 then
      lista[#lista + 1] = id
    end
  end
  table.sort(lista, function(a, b)
    local x, y = Datos.items[a], Datos.items[b]
    if (x.nivel or 1) ~= (y.nivel or 1) then return (x.nivel or 1) < (y.nivel or 1) end
    if x.hueco ~= y.hueco then return (ORDEN_HUECO[x.hueco] or 99) < (ORDEN_HUECO[y.hueco] or 99) end
    return a < b
  end)
  return lista
end

function I.panelMercado(p, w, h)
  local tienda = TIENDAS[I.tienda] or TIENDAS.mercado
  local cats = tienda.cats
  local px, py, pw, ph = w / 2 - 330, 60, 660, 560
  caja(px, py, pw, ph, tienda.titulo)
  I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
  local f = pequena()
  love.graphics.setFont(f)
  local tabOk = false
  for _, c in ipairs(cats) do if c.id == I.mercadoTab then tabOk = true end end
  if not tabOk then I.mercadoTab = cats[1].id end
  -- pestañas arriba
  local tw = (pw - 20 - (#cats - 1) * 4) / #cats
  for i, c in ipairs(cats) do
    local tx = px + 10 + (i - 1) * (tw + 4)
    local ty = py + 42
    local activa = I.mercadoTab == c.id
    local hover = sobre(tx, ty, tw, 28)
    love.graphics.setColor(activa and 0.27 or (hover and 0.16 or 0.09), activa and 0.4 or (hover and 0.24 or 0.13), activa and 0.8 or (hover and 0.5 or 0.27), 0.97)
    love.graphics.rectangle("fill", tx, ty, tw, 28, 7, 7)
    love.graphics.setColor(activa and I.TEMA.acento[1] or 0.35, activa and I.TEMA.acento[2] or 0.5, activa and I.TEMA.acento[3] or 0.9, activa and 1 or 0.7)
    love.graphics.rectangle("line", tx + 0.5, ty + 0.5, tw - 1, 27, 7, 7)
    love.graphics.setColor(activa and 1 or 0.85, activa and 0.95 or 0.88, activa and 0.8 or 0.95)
    love.graphics.printf(c.nombre, tx, ty + 6, tw, "center")
    I.registrar(tx, ty, tw, 28, "merc_tab_" .. c.id)
  end
  love.graphics.setFont(I.fuente)
  local x0, topeY, baseY = px + 10, py + 80, py + ph - 38
  local ancho = pw - 20
  -- lista de la pestaña
  local filas = {}
  if I.mercadoTab == "vender" then
    for i, slot in ipairs(p.bolsa) do filas[#filas + 1] = { vender = i, slot = slot } end
  elseif I.mercadoTab == "mascotas" then
    for _, id in ipairs(Mascotas.orden) do filas[#filas + 1] = { mascota = id } end
  else
    for _, id in ipairs(I.listaItemsClase(p, I.mercadoTab)) do filas[#filas + 1] = { id = id } end
  end
  local maxScroll = math.max(0, #filas - math.floor((baseY - topeY) / 44))
  I.scroll = math.max(0, math.min(maxScroll, I.scroll or 0))
  local y0 = topeY - I.scroll * 44
  if #filas == 0 then
    love.graphics.setColor(0.7, 0.72, 0.8)
    love.graphics.print(I.mercadoTab == "vender" and "Tu bolsa está vacía." or "Nada en esta categoría a tu nivel.", x0 + 12, topeY + 10)
  end
  for i, fila in ipairs(filas) do
    local y = y0 + (i - 1) * 44
    if y >= topeY - 2 and y + 40 <= baseY + 2 then
      love.graphics.setColor(0.10, 0.13, 0.25)
      love.graphics.rectangle("fill", x0, y, ancho, 40, 6, 6)
      if fila.vender then
        local it = Datos.item(fila.slot.id)
        if it then
          local cant = fila.slot.cant or 1
          Atlas.dibujar(it.hoja, it.sprite, x0 + 24, y + 20, 0.9, 16, 16, it.tinte)
          love.graphics.setColor(0.95, 0.9, 0.75)
          love.graphics.print(I.nombreItem(it, fila.slot.enc) .. (cant > 1 and ("  x" .. cant) or ""), x0 + 50, y + 3)
          love.graphics.setColor(0.7, 0.75, 0.65)
          love.graphics.print(I.statsTexto(it, fila.slot.enc), x0 + 50, y + 21)
          local vendible = not ((it.quest and not it.vendible) or it.mall)
          love.graphics.setColor(1, 0.9, 0.4)
          love.graphics.printf(vendible and (Ayudas.num(math.floor((it.precio or 1) * Datos.FACTOR_VENTA) * cant) .. " oro") or "—", x0 + ancho - 190, y + 12, 90, "right")
          I.boton(x0 + ancho - 90, y + 5, 80, 30, "Vender", "bolsa_" .. fila.vender, vendible, "Este objeto no se puede vender.")
        end
      elseif fila.mascota then
        local d = Mascotas.especies[fila.mascota]
        local def = Personajes.de({ kind = "mascota", especie = fila.mascota })
        if def then Personajes.dibujar(def, 1, false, love.timer.getTime(), x0 + 26, y + 36) end
        local tengo = false
        for _, mm in ipairs(p.mascotas or {}) do if Mascotas.mismaLinea(mm.especie, fila.mascota) then tengo = true end end
        love.graphics.setColor(0.95, 0.9, 0.75)
        love.graphics.print(d.nombre .. "  (evoluciona a " .. (d.evo and Mascotas.especies[d.evo] and (Mascotas.especies[d.evo].nombre .. " al nv " .. d.evoNivel) or "") .. ")", x0 + 56, y + 3)
        love.graphics.setColor(0.7, 0.75, 0.65)
        love.graphics.print(d.desc, x0 + 56, y + 21)
        love.graphics.setColor(1, 0.9, 0.4)
        love.graphics.printf(Ayudas.num(d.precio) .. " oro", x0 + ancho - 190, y + 12, 90, "right")
        local ok = not tengo and (p.oro or 0) >= d.precio and (p.nivel or 1) >= (d.nivel or 1)
        I.boton(x0 + ancho - 90, y + 5, 80, 30, tengo and "Tuya" or "Adoptar", "masc_adoptar_" .. fila.mascota, ok,
          tengo and "Ya la tienes." or ("Te faltan " .. Ayudas.num(math.max(0, d.precio - (p.oro or 0))) .. " de oro."))
      else
        local it = Datos.item(fila.id)
        Atlas.dibujar(it.hoja, it.sprite, x0 + 24, y + 20, 0.9, 16, 16, it.tinte)
        local nivelOk = (p.nivel or 1) >= (it.nivel or 1)
        love.graphics.setColor(nivelOk and 0.95 or 0.65, nivelOk and 0.9 or 0.6, nivelOk and 0.75 or 0.55)
        love.graphics.print(it.nombre .. (it.nivel and it.nivel > 1 and ("  (nv " .. it.nivel .. ")") or ""), x0 + 50, y + 3)
        love.graphics.setColor(0.7, 0.75, 0.65)
        love.graphics.print(I.statsTexto(it), x0 + 50, y + 21)
        love.graphics.setColor(1, 0.9, 0.4)
        love.graphics.printf(Ayudas.num(it.precio) .. " oro", x0 + ancho - 190, y + 12, 90, "right")
        local falta = (p.oro or 0) < (it.precio or 0)
        local bloqueaNivel = (it.cura or it.mana) and not nivelOk
        local motivo = bloqueaNivel and ("Necesitas nivel " .. (it.nivel or 1) .. ".")
          or ("Te faltan " .. Ayudas.num((it.precio or 0) - (p.oro or 0)) .. " de oro.")
        I.boton(x0 + ancho - 90, y + 5, 80, 30, "Comprar", "compra_" .. fila.id, not falta and not bloqueaNivel, motivo)
      end
    end
  end
  love.graphics.setColor(0.62, 0.66, 0.78)
  love.graphics.setFont(f)
  love.graphics.printf("Rueda del ratón para recorrer. Se muestran piezas hasta 4 niveles por encima del tuyo. Para vender, abre la pestaña Vender.", px + 14, py + ph - 30, pw - 28, "left")
  love.graphics.setFont(I.fuente)
end

-- Alerta con Aceptar y Rechazar sobre toda la pantalla (invitaciones de comercio, gremio y grupo).
function I.alerta(titulo, mensaje, restante, idSi, idNo, w, h)
  I.registrar(0, 0, w, h, "alerta_fondo")
  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.rectangle("fill", 0, 0, w, h)
  local bw, bh = 460, 190
  local bx, by = w / 2 - bw / 2, h / 2 - bh / 2 - 40
  love.graphics.setColor(0.08, 0.07, 0.1, 0.98)
  love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)
  love.graphics.setColor(0.95, 0.8, 0.35, 1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bx, by, bw, bh, 8, 8)
  love.graphics.setLineWidth(1)
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(1, 0.88, 0.45)
  love.graphics.printf(titulo, bx, by + 14, bw, "center")
  love.graphics.setColor(0.95, 0.92, 0.82)
  love.graphics.printf(mensaje, bx + 24, by + 52, bw - 48, "center")
  if restante then
    love.graphics.setColor(0.7, 0.68, 0.6)
    love.graphics.printf("Responde en " .. math.max(0, math.ceil(restante)) .. " s", bx, by + 104, bw, "center")
  end
  I.boton(bx + 50, by + 138, 160, 36, "Aceptar", idSi)
  I.boton(bx + bw - 210, by + 138, 160, 36, "Rechazar", idNo)
end

-- Comercio entre jugadores: dos ofertas con lista desplazable, oro con validación y tu bolsa para elegir.
I.COM_FILAS = 6
function I.panelComercio(mundo, p, w, h)
  local pw, ph = math.min(900, w - 40), 600
  local px, py = w / 2 - pw / 2, 30
  local s = p.sesion and mundo.sesiones[p.sesion]
  caja(px, py, pw, ph, "Comercio")
  if not s then
    I.boton(px + pw - 72, py + 8, 60, 28, "Cerrar", "cerrar")
    love.graphics.setColor(1, 0.9, 0.7)
    love.graphics.print("Selecciona a un jugador cercano y pulsa T para proponerle un trato.", px + 20, py + 60)
    return
  end
  I.boton(px + pw - 100, py + 8, 88, 28, "Cancelar", "comercio_no")
  local otroId = s.a == p.id and s.b or s.a
  local otro = mundo.entidades[otroId]
  local mia, suya = s.oferta[p.id], s.oferta[otroId]
  local f = pequena()
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(1, 0.92, 0.7)
  love.graphics.print("Trato con " .. (otro and otro.nombre or "?"), px + 140, py + 12)

  local colW = (pw - 60) / 2
  local filaH, filas = 30, I.COM_FILAS
  local function columna(x, titulo, of, propia)
    love.graphics.setFont(I.fuente)
    love.graphics.setColor(0.95, 0.9, 0.75)
    love.graphics.print(titulo, x, py + 50)
    love.graphics.setFont(f)
    love.graphics.setColor(of.ok and 0.5 or 0.9, of.ok and 0.95 or 0.65, of.ok and 0.5 or 0.45)
    love.graphics.printf(of.ok and "Aceptado" or "Pendiente", x, py + 52, colW, "right")
    -- oro
    love.graphics.setFont(I.fuente)
    love.graphics.setColor(1, 0.85, 0.4)
    if not propia then
      love.graphics.print("Oro: " .. (of.oro or 0), x, py + 84)
    end
    -- lista desplazable de objetos
    local ly = py + 150
    local total = #of.items
    local maxScroll = math.max(0, total - filas)
    local clave = propia and "comScrollA" or "comScrollB"
    I[clave] = math.max(0, math.min(maxScroll, I[clave] or 0))
    love.graphics.setColor(0.09, 0.12, 0.23)
    love.graphics.rectangle("fill", x, ly, colW, filaH * filas + 4, 4, 4)
    love.graphics.setColor(0.3, 0.44, 0.82)
    love.graphics.rectangle("line", x + 0.5, ly + 0.5, colW - 1, filaH * filas + 3, 4, 4)
    if propia then
      I.comListaA = { x = x, y = ly, w = colW, h = filaH * filas + 4 }
    else
      I.comListaB = { x = x, y = ly, w = colW, h = filaH * filas + 4 }
    end
    if total == 0 then
      love.graphics.setFont(f)
      love.graphics.setColor(0.6, 0.58, 0.5)
      love.graphics.print(propia and "Elige objetos de tu bolsa (abajo)." or "Aún no ofrece objetos.", x + 10, ly + 10)
    end
    for i = 1, filas do
      local idx = i + I[clave]
      local it = of.items[idx]
      if it then
        local yy = ly + 2 + (i - 1) * filaH
        local def = Datos.item(it.id)
        love.graphics.setColor(0.13, 0.17, 0.32)
        love.graphics.rectangle("fill", x + 3, yy, colW - 14, filaH - 2, 3, 3)
        if def then
          Atlas.dibujar(def.hoja, def.sprite, x + 20, yy + filaH / 2 + 3, 0.75, 16, 16, def.tinte)
          love.graphics.setFont(f)
          love.graphics.setColor(1, 0.95, 0.85)
          love.graphics.print(def.nombre .. ((it.enc or 0) > 0 and (" +" .. it.enc) or ""), x + 40, yy + 6)
        end
        love.graphics.setFont(f)
        love.graphics.setColor(0.75, 0.8, 0.7)
        love.graphics.printf("x " .. (it.cant or 1), x + colW - 130, yy + 6, 60, "right")
        if propia then
          I.boton(x + colW - 68, yy + 2, 52, filaH - 6, "Quitar", "com_quitar_" .. idx)
        end
      end
    end
    -- barra de desplazamiento
    if maxScroll > 0 then
      local bh = filaH * filas
      local th = math.max(18, bh * filas / total)
      local ty = ly + 2 + (bh - th) * (I[clave] / maxScroll)
      love.graphics.setColor(0.55, 0.45, 0.25, 0.9)
      love.graphics.rectangle("fill", x + colW - 9, ty, 6, th, 3, 3)
      love.graphics.setFont(f)
      love.graphics.setColor(0.65, 0.62, 0.55)
      love.graphics.print("Rueda del ratón para ver más (" .. total .. " objetos)", x, ly + filaH * filas + 8)
    end
  end
  columna(px + 20, "Tú ofreces", mia, true)
  columna(px + 40 + colW, (otro and otro.nombre or "Otro") .. " ofrece", suya, false)

  -- oro propio: entrada con validación (solo cifras y nunca más de lo que tienes)
  local disponible = (p.oro or 0) + (mia.oro or 0)
  local ox = px + 20
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(1, 0.85, 0.4)
  love.graphics.print("Oro", ox, py + 84)
  love.graphics.setFont(f)
  love.graphics.setColor(0.75, 0.72, 0.62)
  love.graphics.print("Tienes " .. disponible, ox + 56, py + 88)
  if I.comOroSesion ~= s.id then I.comOroSesion, I.comOro = s.id, tostring(mia.oro or 0) end
  local foco = I.foco == "com_oro"
  if not foco and tonumber(I.comOro or "0") ~= (mia.oro or 0) then I.comOro = tostring(mia.oro or 0) end
  local escrito = tonumber(I.comOro ~= "" and I.comOro or "0") or 0
  local excede = escrito > disponible
  love.graphics.setColor(0.11, 0.15, 0.28)
  love.graphics.rectangle("fill", ox, py + 108, 170, 34, 4, 4)
  love.graphics.setColor(excede and 1 or 0.4, excede and 0.35 or 0.33, excede and 0.3 or 0.2)
  love.graphics.rectangle("line", ox + 0.5, py + 108.5, 169, 33, 4, 4)
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(1, 0.95, 0.85)
  love.graphics.print((I.comOro or "") .. (foco and "_" or ""), ox + 8, py + 114)
  I.registrar(ox, py + 108, 170, 34, "foco_com_oro")
  I.boton(ox + 178, py + 108, 70, 34, "Fijar", "com_oro_fijar", not excede)
  I.boton(ox + 254, py + 108, 70, 34, "Todo", "com_oro_todo")
  if excede then
    love.graphics.setFont(f)
    love.graphics.setColor(1, 0.45, 0.4)
    love.graphics.print("No puedes ofrecer más de " .. disponible .. ".", ox + 330, py + 118)
  end

  -- tu bolsa: un clic ofrece el objeto
  local by = py + 150 + filaH * filas + 40
  love.graphics.setFont(I.fuente)
  love.graphics.setColor(0.95, 0.9, 0.75)
  love.graphics.print("Tu bolsa (clic en un objeto para ofrecerlo)", px + 20, by)
  local lado, sep = 38, 4
  local cols = math.floor((pw - 40) / (lado + sep))
  local cap = Datos.capacidadBolsa(p.equipo)
  for i = 1, cap do
    local cx = px + 20 + ((i - 1) % cols) * (lado + sep)
    local cy = by + 28 + math.floor((i - 1) / cols) * (lado + sep)
    love.graphics.setColor(0.10, 0.13, 0.25)
    love.graphics.rectangle("fill", cx, cy, lado, lado, 3, 3)
    love.graphics.setColor(0.3, 0.44, 0.82)
    love.graphics.rectangle("line", cx + 0.5, cy + 0.5, lado - 1, lado - 1, 3, 3)
    local slot = p.bolsa[i]
    local def = slot and Datos.item(slot.id)
    if def then
      Atlas.dibujar(def.hoja, def.sprite, cx + lado / 2, cy + lado / 2 + 6, 1, 16, 16, def.tinte)
      if (slot.cant or 1) > 1 then texto(tostring(slot.cant), cx + lado - f:getWidth(tostring(slot.cant)) - 3, cy + lado - 14, { 1, 1, 1 }, f) end
      I.registrar(cx, cy, lado, lado, "com_bolsa_" .. i)
      if sobre(cx, cy, lado, lado) then I.pista = def.nombre .. (def.texto and (": " .. def.texto) or "") end
    end
  end

  -- aceptar
  local yb = py + ph - 52
  I.boton(px + 20, yb, 220, 38, mia.ok and "Aceptado: esperando al otro" or "Aceptar trato", "comercio_ok", not mia.ok)
  love.graphics.setFont(f)
  love.graphics.setColor(0.7, 0.68, 0.6)
  love.graphics.printf("Si cambias la oferta, las aceptaciones se quitan. Si no os cabe todo en la bolsa, el trato se cancela y cada uno recupera lo suyo.",
    px + 256, yb - 2, pw - 276, "left")
end

-- ------------------------------------------------------------------------------------------------------------------------------ eventos de guerra (panel, cola y marcador)
local EV_UI = {
  batalla = {
    nombre = "Batalla por cristales", cuando = "Una vez al día", color = { 0.36, 0.62, 1.0 }, meta = 5,
    lema = "Derriba estatuas y puertas enemigas hasta destruir el núcleo, recoge su cristal y llévalo al altar de tu base. Gana el primer equipo con 5 cristales entregados.",
  },
  estandarte = {
    nombre = "Captura del estandarte", cuando = "Cada pocas horas", color = { 1.0, 0.76, 0.3 }, meta = 3,
    lema = "Roba la bandera enemiga y tráela a la tuya sin que te la quiten. Tres capturas ganan.",
  },
  moba = {
    nombre = "Asedio", cuando = "Sin horario: empieza con jugadores de los dos equipos", color = { 0.72, 0.5, 1.0 },
    lema = "Derriba las torres y destruye el nexo rival. Oleadas de esbirros avanzan solas, la fuente de tu base te cura y puedes reaparecer y volver.",
  },
}
local ORDEN_EV = { "moba", "batalla", "estandarte" }

local function colorEquipo(f)
  local c = Datos.facciones[f] and Datos.facciones[f].color
  return c or { 1, 1, 1 }
end

local function mmss(s)
  s = math.max(0, math.floor(s))
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

-- Barra de progreso de un equipo con su cifra dentro (frac 0..1).
local function barraEquipo(x, y, w, h, frac, f, rotulo, alinea)
  local c = colorEquipo(f)
  barra(x, y, w, h, frac, c[1] * 0.95, c[2] * 0.95, c[3] * 0.95)
  local fu = pequena()
  love.graphics.setFont(fu)
  love.graphics.setColor(0, 0, 0, 0.85)
  local tw = fu:getWidth(rotulo)
  local tx = alinea == "der" and (x + w - tw - 6) or (x + 6)
  love.graphics.print(rotulo, tx + 1, y + (h - fu:getHeight()) / 2 + 1)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(rotulo, tx, y + (h - fu:getHeight()) / 2)
end

-- Una fila de piezas (torres en pie o capturas) como puntitos del color del equipo.
local function puntos(x, y, n, total, f, alinea)
  local c = colorEquipo(f)
  local sep = 11
  for i = 1, total do
    local cx = alinea == "der" and (x - (i - 1) * sep) or (x + (i - 1) * sep)
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.circle("fill", cx, y, 6)
    if i <= n then
      love.graphics.setColor(c[1], c[2], c[3], 1)
      love.graphics.circle("fill", cx, y, 4.5)
      love.graphics.setColor(1, 1, 1, 0.45)
      love.graphics.circle("fill", cx - 1.2, y - 1.4, 1.6)
    else
      love.graphics.setColor(0.25, 0.28, 0.4, 1)
      love.graphics.circle("fill", cx, y, 3.5)
    end
  end
end

-- Aviso de quien está apuntado a un evento mientras sigue en el mundo: tarjeta con el estado de la cola de cada equipo.
function I.hudCola(mundo, p, vw)
  local modo = p.colaGuerra
  local ui = EV_UI[modo]
  if not ui then return end
  local r = mundo:resumenEvento(modo)
  local min = r.min or mundo:minimoEvento(modo)
  local w, h = 360, 52
  local x, y = vw / 2 - w / 2, 78
  marco(x, y, w, h, true)
  love.graphics.setColor(ui.color[1], ui.color[2], ui.color[3], 0.9)
  love.graphics.rectangle("fill", x + 3, y + 6, 4, h - 12, 2, 2)
  texto(ui.nombre .. " · en cola", x + 14, y + 4, TEMA.acento, pequena())
  barraEquipo(x + 14, y + 26, 160, 18, math.min(1, r.cola.albor / min), "albor", "Albor " .. r.cola.albor .. "/" .. min)
  barraEquipo(x + 184, y + 26, 160, 18, math.min(1, r.cola.umbra / min), "umbra", "Umbra " .. r.cola.umbra .. "/" .. min)
end

-- Marcador del evento en curso (arriba, en el centro), registro de lo que pasa, tus estadísticas y la pantalla de «has caído».
function I.hudEvento(mundo, p, vw, vh)
  local modo = p.modo
  local ui = EV_UI[modo]
  local inst = mundo.instancia[modo]
  if not (ui and inst) then return end
  local f = pequena()
  local gr = fuentePortada("ev_grande", 22)
  local med = fuentePortada("ev_medio", 16)
  local W, H = 620, 92
  local x, y = vw / 2 - W / 2, 74
  marco(x, y, W, H, true)
  love.graphics.setColor(ui.color[1], ui.color[2], ui.color[3], 0.9)
  love.graphics.rectangle("fill", x + 4, y + 4, W - 8, 3, 2, 2)
  local ca, cu = colorEquipo("albor"), colorEquipo("umbra")
  -- centro: nombre y tiempo restante
  local resta = inst.duracion - inst.tiempo
  love.graphics.setFont(med)
  local tn = ui.nombre
  texto(tn, vw / 2 - med:getWidth(tn) / 2, y + 8, TEMA.acento, med)
  local tt = mmss(resta)
  texto(tt, vw / 2 - gr:getWidth(tt) / 2, y + 28, resta < 60 and { 1, 0.45, 0.4 } or { 1, 1, 1 }, gr)
  -- equipos a los lados: nombre y cifra principal
  local function cifra(equipo)
    if modo == "moba" then return inst.bajas and inst.bajas[equipo] or 0 end
    if modo == "batalla" then return inst.cristales and inst.cristales[equipo] or 0 end
    return inst.puntos[equipo] or 0
  end
  texto("ALBOR", x + 16, y + 8, ca, med)
  local sa = tostring(cifra("albor"))
  texto(sa, x + 16, y + 26, { 1, 1, 1 }, gr)
  texto("UMBRA", x + W - 16 - med:getWidth("UMBRA"), y + 8, cu, med)
  local su = tostring(cifra("umbra"))
  texto(su, x + W - 16 - gr:getWidth(su), y + 26, { 1, 1, 1 }, gr)
  local unidad = modo == "moba" and "bajas" or (modo == "batalla" and "cristales" or "capturas")
  texto(unidad, x + 16 + gr:getWidth(sa) + 6, y + 36, { 0.7, 0.72, 0.82 }, f)
  local lu = unidad
  texto(lu, x + W - 16 - gr:getWidth(su) - 6 - f:getWidth(lu), y + 36, { 0.7, 0.72, 0.82 }, f)
  -- fila inferior: las barras de cada equipo
  local by = y + 66
  local bw = 218
  if modo == "moba" and inst.nexoPct and inst.torres then
    local function etiquetaNexo(eq)
      local t = "Nexo " .. (inst.nexoPct[eq] or 100) .. "%"
      if inst.nexoProt and inst.nexoProt[eq] then t = t .. " · protegido " .. (inst.carriles and inst.carriles[eq] or 0) .. "/2" end
      return t
    end
    barraEquipo(x + 12, by, bw, 18, (inst.nexoPct.albor or 100) / 100, "albor", etiquetaNexo("albor"))
    barraEquipo(x + W - 12 - bw, by, bw, 18, (inst.nexoPct.umbra or 100) / 100, "umbra", etiquetaNexo("umbra"), "der")
    puntos(x + 12 + bw + 12, by + 9, inst.torres.albor or 0, 6, "albor")
    puntos(x + W - 12 - bw - 12, by + 9, inst.torres.umbra or 0, 6, "umbra", "der")
    if inst.oleadaEn then
      local t = "Oleada " .. ((inst.oleada or 0) + 1) .. " en " .. inst.oleadaEn .. " s"
      texto(t, vw / 2 - f:getWidth(t) / 2, y + 52, { 0.85, 0.82, 0.95 }, f)
    end
  elseif modo == "estandarte" then
    barraEquipo(x + 12, by, bw, 18, (inst.puntos.albor or 0) / ui.meta, "albor", (inst.puntos.albor or 0) .. " / " .. ui.meta .. " capturas")
    barraEquipo(x + W - 12 - bw, by, bw, 18, (inst.puntos.umbra or 0) / ui.meta, "umbra", (inst.puntos.umbra or 0) .. " / " .. ui.meta .. " capturas", "der")
  else
    local ca2, cu2 = inst.cristales and inst.cristales.albor or 0, inst.cristales and inst.cristales.umbra or 0
    barraEquipo(x + 12, by, bw, 18, ca2 / ui.meta, "albor", ca2 .. " / " .. ui.meta .. " cristales")
    barraEquipo(x + W - 12 - bw, by, bw, 18, cu2 / ui.meta, "umbra", cu2 .. " / " .. ui.meta .. " cristales", "der")
  end
  -- tus estadísticas
  local st = p.eventoStats
  if st then
    local partes = { "Bajas " .. (st.bajas or 0), "Muertes " .. (st.muertes or 0) }
    if modo == "moba" then partes[#partes + 1] = "Esbirros " .. (st.esbirros or 0) partes[#partes + 1] = "Torres " .. (st.torres or 0) end
    local t = table.concat(partes, "  ·  ")
    local tw = f:getWidth(t)
    marco(vw / 2 - tw / 2 - 12, y + H + 4, tw + 24, 22, true)
    texto(t, vw / 2 - tw / 2, y + H + 7, { 0.9, 0.9, 1 }, f)
  end
  -- registro: lo último que ha pasado, con el color del equipo; se va apagando
  local reg = inst.registro or {}
  local yy = y + H + 34
  for i = math.max(1, #reg - 3), #reg do
    local e = reg[i]
    local edad = inst.tiempo - e.t
    if edad < 16 then
      local a = edad < 11 and 1 or math.max(0, 1 - (edad - 11) / 5)
      local c = e.faccion and colorEquipo(e.faccion) or { 0.85, 0.85, 0.9 }
      local tw = f:getWidth(e.texto)
      love.graphics.setColor(0.03, 0.04, 0.1, 0.62 * a)
      love.graphics.rectangle("fill", vw / 2 - tw / 2 - 12, yy - 1, tw + 24, 19, 6, 6)
      love.graphics.setColor(c[1], c[2], c[3], a)
      love.graphics.circle("fill", vw / 2 - tw / 2 - 4, yy + 8.5, 3)
      love.graphics.setFont(f)
      love.graphics.setColor(1, 1, 1, a)
      love.graphics.print(e.texto, vw / 2 - tw / 2 + 4, yy + 2)
      yy = yy + 21
    end
  end
  if modo == "batalla" and (p.llevaCristales or 0) > 0 then
    local t = "Llevas " .. p.llevaCristales .. (p.llevaCristales == 1 and " cristal" or " cristales") .. ": llévalos al altar de tu base"
    marco(vw / 2 - f:getWidth(t) / 2 - 10, yy + 4, f:getWidth(t) + 20, 24, true)
    texto(t, vw / 2 - f:getWidth(t) / 2, yy + 8, { 0.55, 0.9, 1 }, f)
  end
  -- has caído: pantalla roja suave con la cuenta atrás para reaparecer
  if p.vivo == false or (p.hp and p.hp <= 0) then
    love.graphics.setColor(0.35, 0.02, 0.04, 0.35)
    love.graphics.rectangle("fill", 0, 0, vw, vh)
    local gg = fuentePortada("ev_caido", 38)
    local t1 = "HAS CAÍDO"
    texto(t1, vw / 2 - gg:getWidth(t1) / 2, vh / 2 - 70, { 1, 0.4, 0.38 }, gg)
    local s = p.respawnResta
    local t2 = s and ("Reapareces en " .. s .. " s") or "Reapareciendo en tu base..."
    texto(t2, vw / 2 - gr:getWidth(t2) / 2, vh / 2 - 22, { 1, 1, 1 }, gr)
  end
end

local function cartaEvento(mundo, p, modo, x, y, w, h)
  local ui = EV_UI[modo]
  local r = mundo:resumenEvento(modo)
  local min = r.min or mundo:minimoEvento(modo)
  local f = pequena()
  local med = fuentePortada("ev_medio", 16)
  local gr = fuentePortada("ev_grande", 22)
  -- fondo de la tarjeta con la franja de color del evento
  love.graphics.setColor(TEMA.fila[1], TEMA.fila[2], TEMA.fila[3], 0.95)
  love.graphics.rectangle("fill", x, y, w, h, 8, 8)
  love.graphics.setColor(ui.color[1], ui.color[2], ui.color[3], 0.95)
  love.graphics.rectangle("fill", x, y, 7, h, 4, 4)
  love.graphics.setColor(ui.color[1], ui.color[2], ui.color[3], 0.35)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 8, 8)
  texto(ui.nombre, x + 20, y + 8, TEMA.acento, gr)
  -- insignia de estado
  local ins, ci
  if r.activa then ins, ci = "EN CURSO", { 0.35, 0.9, 0.5 }
  elseif r.programa then
    local m = math.ceil(r.programa.restan / 60)
    ins, ci = "A LAS " .. r.programa.hora .. (m < 600 and (" · en " .. (m >= 60 and (math.floor(m / 60) .. " h " .. string.format("%02d", m % 60)) or (m .. " min"))) or ""), { 0.5, 0.75, 1 }
  else ins, ci = "ABIERTO", { 1, 0.82, 0.4 } end
  local iw = med:getWidth(ins) + 18
  love.graphics.setColor(ci[1] * 0.25, ci[2] * 0.25, ci[3] * 0.25, 0.95)
  love.graphics.rectangle("fill", x + w - iw - 14, y + 10, iw, 24, 12, 12)
  love.graphics.setColor(ci[1], ci[2], ci[3], 0.9)
  love.graphics.rectangle("line", x + w - iw - 14 + 0.5, y + 10.5, iw - 1, 23, 12, 12)
  texto(ins, x + w - iw - 5, y + 13, ci, med)
  -- descripción
  love.graphics.setFont(f)
  love.graphics.setColor(0.86, 0.86, 0.94)
  love.graphics.printf(ui.lema, x + 20, y + 42, w - 220, "left")
  love.graphics.setColor(0.62, 0.65, 0.78)
  love.graphics.print(ui.cuando, x + 20, y + h - 22)
  -- colas: Albor y Umbra, con lo que falta para empezar
  local cx = x + w - 196
  local cola = r.activa and r.dentro or r.cola
  local rot = r.activa and "dentro" or "apuntados"
  love.graphics.setColor(0.62, 0.65, 0.78)
  love.graphics.print(rot, cx, y + 46)
  local tope = r.activa and math.max(min, cola.albor, cola.umbra, 1) or min
  barraEquipo(cx, y + 64, 182, 16, math.min(1, cola.albor / tope), "albor", "Albor " .. cola.albor .. (r.activa and "" or "/" .. min))
  barraEquipo(cx, y + 84, 182, 16, math.min(1, cola.umbra / tope), "umbra", "Umbra " .. cola.umbra .. (r.activa and "" or "/" .. min))
  -- acción
  local id, txt, activo, motivo = "guerra_" .. modo, "Apuntarse", true, nil
  if p.modo == modo then id, txt = "guerra_salir", "Abandonar el campo"
  elseif p.colaGuerra == modo then id, txt = "guerra_salir", "Salir de la cola"
  elseif r.activa then txt = "Unirse ahora"
  end
  if p.modo ~= "mundo" and p.modo ~= modo then activo, motivo = false, "Ya estás en otro evento." end
  if p.colaGuerra and p.colaGuerra ~= modo and p.modo ~= modo then activo, motivo = false, "Sal antes de la otra cola." end
  I.boton(x + w - 196, y + h - 36, 182, 28, txt, id, activo, motivo)
end

function I.panelGuerra(mundo, p, w, h)
  local pw, ph = 620, 560
  local x0, y0 = w / 2 - pw / 2, 64
  caja(x0, y0, pw, ph, "Guerra entre coronas")
  I.boton(x0 + pw - 70, y0 + 8, 60, 28, "Cerrar", "cerrar")
  local f = pequena()
  -- tu equipo y una línea de ayuda
  local c = colorEquipo(p.faccion)
  love.graphics.setColor(c[1] * 0.3, c[2] * 0.3, c[3] * 0.3, 0.95)
  love.graphics.rectangle("fill", x0 + 20, y0 + 44, 150, 24, 12, 12)
  love.graphics.setColor(c[1], c[2], c[3], 0.95)
  love.graphics.rectangle("line", x0 + 20.5, y0 + 44.5, 149, 23, 12, 12)
  texto("Luchas con " .. (p.faccion == "albor" and "Albor" or "Umbra"), x0 + 32, y0 + 48, { 1, 1, 1 }, f)
  love.graphics.setFont(f)
  love.graphics.setColor(0.78, 0.8, 0.9)
  love.graphics.printf("Apúntate con el Heraldo de una ciudad (o en el portal de la Cicatriz). Si el evento ya está en curso, te unes al momento.",
    x0 + 184, y0 + 42, pw - 204, "left")
  local ch = 148
  for k, modo in ipairs(ORDEN_EV) do
    cartaEvento(mundo, p, modo, x0 + 20, y0 + 86 + (k - 1) * (ch + 8), pw - 40, ch)
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
  local nombres = { pequena = "Pequeña", mediana = "Mediana", grande = "Grande" }
  local fila, visibles = 48, 6
  local maxScroll = math.max(0, #ciudad.parcelas - visibles)
  I.casaScrollMax = maxScroll
  I.casaScroll = math.max(0, math.min(maxScroll, I.casaScroll or 0))
  for i, par in ipairs(ciudad.parcelas) do
    if i > I.casaScroll and i <= I.casaScroll + visibles then
      local y = 176 + (i - 1 - I.casaScroll) * fila
      local precio = mundo:precioDeCasa(par)
      local estado = par.dueno and (par.dueno == p.id and "Tu casa" or "Ocupada") or ("Libre  ·  " .. Ayudas.num(precio) .. " oro")
      love.graphics.setFont(pequena())
      love.graphics.setColor(0.95, 0.9, 0.75)
      love.graphics.print("Casa " .. i .. "  ·  " .. (nombres[par.tamano] or "Mediana"), w / 2 - 250, y - 2)
      love.graphics.setColor(0.78, 0.74, 0.62)
      love.graphics.print(estado, w / 2 - 250, y + 14)
      love.graphics.setFont(I.fuente)
      if not par.dueno then I.boton(w / 2 + 40, y - 6, 140, 30, "Comprar", "casa_comprar_" .. par.id) end
      if par.dueno == p.id then I.boton(w / 2 + 190, y - 6, 100, 30, "Entrar", "casa_entrar_" .. par.id) end
    end
  end
  if maxScroll > 0 then
    love.graphics.setColor(0.65, 0.7, 0.8)
    love.graphics.print("Rueda del ratón para ver más casas", w / 2 - 250, 176 + visibles * fila)
  end
end

-- Mapa del mundo: zoom con la rueda (hacia el cursor), arrastrar para moverse, y las zonas de
-- criaturas con sus niveles (también las zonas elevadas).
local function colorNivel(n)
  local t = math.max(0, math.min(1, (n - 1) / 29))
  return 0.3 + 0.7 * t, 0.95 - 0.65 * t, 0.35
end

function I.mapaMedidas(w, h)
  local mw, mh = Datos.MAPA_W, Datos.MAPA_H
  local ax, ay = 64, 96
  local aw, ah = (w - 120) * 0.62, h - 150
  local s0 = math.min(aw / mw, ah / mh)
  return { mw = mw, mh = mh, ax = ax, ay = ay, aw = aw, ah = ah, s0 = s0 }
end

function I.mapaAjustar(g)
  I.mapaZoom = math.max(1, math.min(8, I.mapaZoom or 1))
  local s = g.s0 * I.mapaZoom
  local mitadW, mitadH = g.aw / 2 / s, g.ah / 2 / s
  local cx, cy = I.mapaCx or g.mw / 2, I.mapaCy or g.mh / 2
  if mitadW >= g.mw / 2 then cx = g.mw / 2 else cx = math.max(mitadW, math.min(g.mw - mitadW, cx)) end
  if mitadH >= g.mh / 2 then cy = g.mh / 2 else cy = math.max(mitadH, math.min(g.mh - mitadH, cy)) end
  I.mapaCx, I.mapaCy = cx, cy
  return s
end

-- Cambia el zoom manteniendo fijo el punto del mapa que hay bajo (ux, uy) (coordenadas de la interfaz).
function I.mapaZoomar(factor, ux, uy)
  local g = I.mapaGeom
  if not g then return end
  local s = I.mapaAjustar(g)
  local wx = I.mapaCx + (ux - (g.ax + g.aw / 2)) / s
  local wy = I.mapaCy + (uy - (g.ay + g.ah / 2)) / s
  I.mapaZoom = math.max(1, math.min(8, (I.mapaZoom or 1) * factor))
  local s2 = g.s0 * I.mapaZoom
  I.mapaCx = wx - (ux - (g.ax + g.aw / 2)) / s2
  I.mapaCy = wy - (uy - (g.ay + g.ah / 2)) / s2
  I.mapaAjustar(g)
end

function I.mapaCentrarEn(x, y, zoom)
  I.mapaZoom = zoom or I.mapaZoom or 1
  I.mapaCx, I.mapaCy = x, y
  if I.mapaGeom then I.mapaAjustar(I.mapaGeom) end
end

function I.panelMapa(mundo, p, w, h)
  local Mapa = require("compartido.dominio.mapa")
  caja(40, 40, w - 80, h - 80, "Mapa del mundo")
  I.boton(w - 140, 48, 70, 28, "Cerrar", "cerrar")
  local g = I.mapaMedidas(w, h)
  I.mapaGeom = g
  I.mapaZoom = I.mapaZoom or 1
  local s = I.mapaAjustar(g)
  local ax, ay, aw, ah = g.ax, g.ay, g.aw, g.ah
  local function aP(x, y) return ax + aw / 2 + (x - I.mapaCx) * s, ay + ah / 2 + (y - I.mapaCy) * s end
  local mundoMapa = mundo.mapas.mundo
  local zonas = Mapa.zonas(mundoMapa)


  -- el mapa, recortado a su marco
  local esc = I.escala or 1
  love.graphics.setScissor(ax * esc, ay * esc, aw * esc, ah * esc)
  love.graphics.setColor(0.04, 0.05, 0.07, 1)
  love.graphics.rectangle("fill", ax, ay, aw, ah)
  if I.mini then
    local x0, y0 = aP(0, 0)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(I.mini, x0, y0, 0, s, s)
  end
  for _, c in ipairs(mundoMapa.ciudades) do
    local col = Datos.facciones[c.faccion].color
    local x0, y0 = aP(c.x, c.y)
    love.graphics.setColor(col[1], col[2], col[3], 0.9)
    love.graphics.rectangle("line", x0, y0, c.w * s, c.h * s)
    if I.mapaZoom >= 1.8 then
      love.graphics.setColor(0, 0, 0, 0.6)
      love.graphics.print(c.nombre, x0 + 3, y0 + 3)
      love.graphics.setColor(col[1], col[2], col[3], 1)
      love.graphics.print(c.nombre, x0 + 2, y0 + 2)
    end
  end
  -- portales a los mapas de FAO del continente del jugador, con el nombre del mapa al que llevan
  for _, pt in ipairs(mundo.portalesFao or {}) do
    if (pt.faccion == nil or pt.faccion == (p.faccion or pt.faccion)) then
      local x0, y0 = aP(pt.x, pt.y)
      I.iconoPortal(x0, y0, math.min(7, 3 + I.mapaZoom * 0.6))
      if I.mapaZoom >= 1.2 then
        local nombreMapa = pt.nombre:gsub("^Portal: ", "")
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.print("▸ " .. nombreMapa, x0 + 9, y0 - 6)
        love.graphics.setColor(0.6, 0.85, 1, 1)
        love.graphics.print("▸ " .. nombreMapa, x0 + 8, y0 - 7)
      end
    end
  end
  for _, n in ipairs(mundoMapa.npcsMapa or {}) do
    local x0, y0 = aP(n.x, n.y)
    I.iconoNpc(n.rol, x0, y0, math.min(6, 2.2 + I.mapaZoom * 0.5))
  end
  -- zonas elevadas: contorno
  for _, ms in ipairs(mundoMapa.mesetas or {}) do
    local x0, y0 = aP(ms.x, ms.y)
    love.graphics.setColor(1, 0.85, 0.4, 0.8)
    love.graphics.rectangle("line", x0, y0, ms.w * s, ms.h * s)
  end
  -- zonas de criaturas: punto con su rango de nivel (y el nombre al acercar)
  local f = pequena()
  love.graphics.setFont(f)
  local mx, my = love.mouse.getPosition()
  mx, my = mx / esc, my / esc
  local cerca, cd
  for _, z in ipairs(zonas) do
    local x0, y0 = aP(z.x, z.y)
    local r, gg, b = colorNivel(z.nivelMax)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.circle("fill", x0, y0, 6)
    love.graphics.setColor(r, gg, b, 1)
    if z.elevada then
      love.graphics.polygon("fill", x0, y0 - 6, x0 - 6, y0 + 5, x0 + 6, y0 + 5)
    else
      love.graphics.circle("fill", x0, y0, 5)
    end
    local d = (mx - x0) ^ 2 + (my - y0) ^ 2
    -- con muchas zonas, el nivel se escribe al acercar el mapa o al pasar el raton por encima
    if I.mapaZoom >= 1.5 or d < 400 then
      local etiqueta = "nv " .. z.nivelMin .. "-" .. z.nivelMax
      if I.mapaZoom >= 2.6 then etiqueta = z.nombre .. "  " .. etiqueta end
      love.graphics.setColor(0, 0, 0, 0.75)
      love.graphics.print(etiqueta, x0 + 9, y0 - 6)
      love.graphics.setColor(1, 0.96, 0.8, 1)
      love.graphics.print(etiqueta, x0 + 8, y0 - 7)
    end
    if d < 400 and (not cd or d < cd) then cerca, cd = z, d end
  end
  -- nombres de los continentes
  do
    local Continentes = require("compartido.dominio.continentes")
    love.graphics.setFont(f)
    for id, k in pairs(mundoMapa.continentes or {}) do
      local c = k.habitado and Continentes.centro(id)
      if c then
        local x0, y0 = aP(c.x, c.y)
        local ancho = f:getWidth(k.nombre)
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.print(k.nombre, x0 - ancho / 2 + 1, y0 + 1)
        love.graphics.setColor(1, 0.97, 0.85, 0.9)
        love.graphics.print(k.nombre, x0 - ancho / 2, y0)
      end
    end
  end
  -- puertas de mazmorra: arco violeta con su nombre y nivel mínimo
  for _, z in ipairs(mundoMapa.mazmorras or {}) do
    local x0, y0 = aP(z.x, z.y)
    local def = Datos.mazmorra(z.id)
    I.iconoMazmorra(x0, y0, 5)
    local etiqueta = z.nombre .. (def and ("  nv " .. def.nivelMin .. "+") or "")
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.print(etiqueta, x0 + 11, y0 - 6)
    love.graphics.setColor(0.9, 0.75, 1, 1)
    love.graphics.print(etiqueta, x0 + 10, y0 - 7)
  end
  -- destino elegido con un clic: una cruz hasta que llegues
  local dst = I.mapaDestino
  if dst then
    if p.modo ~= "mundo" or (p.x - dst.x) ^ 2 + (p.y - dst.y) ^ 2 < 9 then
      I.mapaDestino = nil
    else
      local x0, y0 = aP(dst.x, dst.y)
      love.graphics.setColor(1, 0.35, 0.3, 1)
      love.graphics.setLineWidth(2)
      love.graphics.line(x0 - 6, y0 - 6, x0 + 6, y0 + 6)
      love.graphics.line(x0 - 6, y0 + 6, x0 + 6, y0 - 6)
      love.graphics.setLineWidth(1)
    end
  end
  if p.modo == "mundo" then I.marcasMapa(p, aP) end
  if p.modo == "mundo" then
    local x0, y0 = aP(p.x, p.y)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", x0 - 3, y0 - 3, 6, 6)
    if (p.z or 0) > 0 then
      love.graphics.setColor(1, 0.85, 0.3)
      love.graphics.print("▲", x0 + 5, y0 + 2)
    end
  end
  love.graphics.setScissor()
  love.graphics.setColor(0.85, 0.72, 0.35, 0.8)
  love.graphics.rectangle("line", ax, ay, aw, ah)
  I.registrar(ax, ay, aw, ah, "mapa_area")
  -- controles de zoom en la esquina superior derecha del mapa (se registran despues del area para
  -- que reciban los clics)
  do
    local bx = ax + aw - 8
    bx = bx - 90
    I.boton(bx, ay + 8, 90, 28, "Centrar", "mapa_centrar")
    bx = bx - 6 - 34
    I.boton(bx, ay + 8, 34, 28, "-", "mapa_menos")
    bx = bx - 6 - 34
    I.boton(bx, ay + 8, 34, 28, "+", "mapa_mas")
    love.graphics.setColor(0.04, 0.05, 0.08, 0.7)
    love.graphics.rectangle("fill", ax + 6, ay + 6, 188, 22, 5, 5)
    love.graphics.setColor(0.85, 0.82, 0.7)
    love.graphics.print("Zoom x" .. string.format("%.1f", I.mapaZoom) .. "  rueda y arrastrar", ax + 12, ay + 8)
  end

  -- columna derecha: zonas, ciudades o iconos
  local lx = ax + aw + 24
  I.mapaTab = I.mapaTab or "zonas"
  I.boton(lx, 96, 96, 26, "Zonas", "mapa_tab_zonas", I.mapaTab ~= "zonas")
  I.boton(lx + 102, 96, 96, 26, "Ciudades", "mapa_tab_ciudades", I.mapaTab ~= "ciudades")
  I.boton(lx + 204, 96, 70, 26, "PNJ", "mapa_tab_pnj", I.mapaTab ~= "pnj")
  local ly = 134
  if I.mapaTab == "zonas" then
    love.graphics.setColor(0.7, 0.68, 0.58)
    love.graphics.print("Clic en una zona para verla. ▲ = zona elevada.", lx, ly)
    ly = ly + 22
    -- la lista es larga: se recorre con la rueda del ratón
    local visibles = math.max(5, math.floor((h - 80 - ly - 30) / 19))
    I.zonasMax = math.max(0, #zonas - visibles)
    I.zonasScroll = math.max(0, math.min(I.zonasMax, I.zonasScroll or 0))
    I.zonasArea = { x = lx, y = ly, w = 320, h = visibles * 19 }
    for i = 1 + I.zonasScroll, math.min(#zonas, I.zonasScroll + visibles) do
      local z = zonas[i]
      local r, gg, b = colorNivel(z.nivelMax)
      love.graphics.setColor(r, gg, b, 1)
      love.graphics.print((z.elevada and "▲ " or "● ") .. "nv " .. z.nivelMin .. "-" .. z.nivelMax, lx, ly)
      love.graphics.setColor(0.92, 0.88, 0.78)
      love.graphics.print(z.nombre, lx + 78, ly)
      I.registrar(lx, ly - 2, 300, 18, "mapa_zona_" .. i)
      ly = ly + 19
    end
    if I.zonasMax > 0 then
      love.graphics.setColor(0.65, 0.62, 0.55)
      love.graphics.print("Rueda sobre la lista para ver más (" .. (I.zonasScroll + 1) .. "-" .. math.min(#zonas, I.zonasScroll + visibles) .. " de " .. #zonas .. ")", lx, ly + 4)
    end
  elseif I.mapaTab == "ciudades" then
    for _, c in ipairs(mundoMapa.ciudades) do
      local col = Datos.facciones[c.faccion].color
      love.graphics.setColor(col)
      love.graphics.rectangle("fill", lx, ly + 4, 10, 10)
      love.graphics.setColor(0.92, 0.88, 0.78)
      love.graphics.print(c.nombre .. (c.capital and "  ·  capital" or ""), lx + 18, ly)
      ly = ly + 26
    end
  else
    for _, rol in ipairs(I.ORDEN_ICONOS) do
      I.iconoNpc(rol, lx + 6, ly + 8, 3)
      love.graphics.setColor(0.88, 0.84, 0.72)
      love.graphics.print(ICONO_NPC[rol][3], lx + 22, ly)
      ly = ly + 22
    end
    I.iconoMazmorra(lx + 6, ly + 8, 4)
    love.graphics.setColor(0.88, 0.84, 0.72)
    love.graphics.print("Puerta de mazmorra", lx + 22, ly)
    ly = ly + 22
    I.iconoPortal(lx + 6, ly + 8, 4)
    love.graphics.setColor(0.88, 0.84, 0.72)
    love.graphics.print("Portal a un mapa de FAO (extensión del mundo)", lx + 22, ly)
    ly = ly + 20
    local nombresPortales = {}
    for _, pt in ipairs(mundo.portalesFao or {}) do
      if (pt.faccion == nil or pt.faccion == (p.faccion or pt.faccion)) then nombresPortales[#nombresPortales + 1] = (pt.nombre:gsub("^Portal: ", "")) end
    end
    love.graphics.setColor(0.6, 0.85, 1, 1)
    love.graphics.printf(table.concat(nombresPortales, "  ·  "), lx + 22, ly, 300, "left")
  end

  -- detalle de la zona bajo el ratón
  if cerca then
    local lineas = { cerca.nombre .. (cerca.elevada and "  (zona elevada)" or "") .. "  nv " .. cerca.nivelMin .. "-" .. cerca.nivelMax }
    for _, m in ipairs(cerca.monstruos) do lineas[#lineas + 1] = "  nv " .. m.nivel .. "  " .. m.nombre end
    local ancho = 0
    for _, l in ipairs(lineas) do ancho = math.max(ancho, f:getWidth(l)) end
    local bx = math.min(mx + 14, w - ancho - 30)
    local by = math.min(my + 14, h - #lineas * 16 - 20)
    love.graphics.setColor(0.05, 0.05, 0.08, 0.95)
    love.graphics.rectangle("fill", bx, by, ancho + 16, #lineas * 16 + 8, 4, 4)
    love.graphics.setColor(0.98, 0.78, 0.36, 1)
    love.graphics.rectangle("line", bx, by, ancho + 16, #lineas * 16 + 8, 4, 4)
    for i, l in ipairs(lineas) do
      love.graphics.setColor(i == 1 and 1 or 0.88, i == 1 and 0.9 or 0.86, i == 1 and 0.55 or 0.74)
      love.graphics.print(l, bx + 8, by + 4 + (i - 1) * 16)
    end
  end
end

function I.panelAyuda(w, h)
  caja(80, 60, w - 160, h - 120, "Cómo jugar")
  I.boton(w - 200, 68, 70, 28, "Cerrar", "cerrar")
  local texto = table.concat({
    "Moverte: WASD o flechas (casilla a casilla, con diagonales) o clic en el suelo. Dos criaturas no pueden ocupar la misma casilla.",
    "Combate: clic en un enemigo lo elige y lo persigue. Tab pasa al siguiente enemigo. Esc suelta el objetivo.",
    "Shift + clic sobre una criatura: la miras y la consola te cuenta qué es. Clic en un aliado: lo eliges para curarlo.",
    "Poderes 1-6 (se aprenden en el árbol, tecla K). 7 poción de vida, 8 poción de maná. R abre la autopoción: vida y maná, cada una con su porcentaje. El ladrón roba con B.",
    "Pantalla: arriba a la izquierda tu vida, maná, experiencia y oro; arriba a la derecha el minimapa; abajo a la izquierda el chat (30 % de la pantalla). C abre tu personaje (equipo y cifras), I la bolsa y K el árbol de poderes (cada nivel da un punto). En la bolsa, un clic elige, otro clic en la misma casilla equipa y otro clic en otra casilla intercambia.",
    "Clic derecho sobre otro jugador: menú para tratar con él, invitarlo a tu gremio o a tu grupo, o mirarlo. Esc abre el menú del juego (continuar, ajustes y salir); si hay un panel abierto, lo cierra.",
    "E interactúa (mercader, heraldo, mayordomo, casa, altar). M mapa, F1 ayuda, F3 medidor, F11 pantalla completa.",
    "Chat: Enter. Escribe /m para hablar al mundo y /f para hablar a tu facción. Las ciudades de tu facción son refugio.",
    "La guerra, una vez al día: batalla por cristales o captura del estandarte. Empieza con 3 jugadores por equipo.",
    "Las casas se compran al mayordomo. La tuya se ve dorada en la calle. Dentro, la puerta del sur es la salida. Clic en un mueble y luego en el suelo para moverlo; clic derecho lo rota.",
    "El mundo son tres continentes separados por mar: Alba (oeste), Umbra (este) y la Isla de la Cicatriz (centro, la zona de guerra). Entre ellos se viaja en barco: habla con el barquero de Puerto del Sol, Puerto Sombra o del Embarcadero de la Cicatriz (E) y paga el pasaje. A pie no se cruza el mar.",
    "Mazmorras: tres puertas de piedra repartidas por el mapa (violeta en el mapa). Con E junto a la puerta entras si tienes el nivel; al fondo hay un jefe y, al caer, un cofre con premio para cada jugador: objetos o addons del mall, o equipo del escalón máximo.",
  }, "\n\n")
  love.graphics.setColor(0.92, 0.88, 0.78)
  love.graphics.printf(texto, 100, 110, w - 200, "left")
end

function I.panelCasa(p, w, h)
  caja(w - 360, 80, 330, 340, "Tu casa")
  I.boton(w - 140, 88, 60, 28, "Salir", "casa_salir")
  love.graphics.setColor(0.82, 0.78, 0.68)
  love.graphics.printf("La puerta del sur es la salida. Clic en un mueble y luego en el suelo para moverlo. Clic derecho lo rota.", w - 348, 124, 306, "left")
  local casa = p.casas[p.casaId]
  local y = 176
  for _, tipo in ipairs({ "cama", "cofre", "estandarte", "mesa" }) do
    local m = Datos.muebles[tipo]
    local puesto = casa and casa.muebles[tipo]
    I.boton(w - 344, y, 298, 32, (puesto and "Usar " or "Comprar ") .. m.nombre .. (puesto and "" or (" (" .. m.precio .. ")")), "mueble_" .. tipo)
    y = y + 40
  end
  if p.modo == "casa" and I.muebleSel and Datos.muebles[I.muebleSel] then
    love.graphics.setColor(1, 0.92, 0.55)
    love.graphics.print("Elegido: " .. Datos.muebles[I.muebleSel].nombre, w - 344, y + 4)
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
    I.persona(pj.clase, w / 2 - 288, y + 84, 0.85, pj.faccion, (type(pj.addon) == "string" and Personajes.skins[pj.addon]) and pj.addon or nil, pj.genero)
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
  I.portada(form, w, h)
end

function I.panelPausa(w, h)
  caja(w / 2 - 160, h / 2 - 150, 320, 400, "Menú")
  I.boton(w / 2 - 120, h / 2 - 100, 240, 36, "Volver", "cerrar")
  I.boton(w / 2 - 120, h / 2 - 50, 240, 36, "Ajustes", "ajustes")
  local etiqueta, hay = "Oficio: aún no tienes", false
  local pj = I.jugadorMenu
  if pj and pj.oficioElegido then
    hay = true
    etiqueta = (pj.job and "Desactivar oficio" or "Activar oficio") .. " (" .. (NOMBRES_OFICIO[pj.oficioElegido] or "?") .. ")"
  end
  I.boton(w / 2 - 120, h / 2, 240, 36, etiqueta, "menu_oficio", hay)
  I.boton(w / 2 - 120, h / 2 + 50, 240, 36, "Item Mall (L)", "menu_mall")
  I.boton(w / 2 - 120, h / 2 + 100, 240, 36, "Autopoción (R)", "menu_autopocion")
  I.boton(w / 2 - 120, h / 2 + 150, 240, 36, "Salir al menú", "salir_menu")
  love.graphics.setColor(0.75, 0.72, 0.64)
  love.graphics.printf("Tu progreso se guarda solo. El oficio solo se activa dentro de una ciudad.", w / 2 - 140, h / 2 + 196, 280, "center")
end

function I.panelAutopocion(p, w, h)
  local ancho, alto = 460, 268
  local x, y = math.floor(w / 2 - ancho / 2), math.floor(h / 2 - alto / 2)
  caja(x, y, ancho, alto, "Autopoción")
  love.graphics.setFont(I.fuente)
  I.boton(x + ancho - 86, y + 8, 70, 26, "Cerrar", "cerrar")
  love.graphics.setColor(0.78, 0.76, 0.68)
  love.graphics.printf("Cada una tiene su porcentaje. Comparten 3 s de espera; si faltan las dos, primero bebe vida.", x + 16, y + 46, ancho - 32, "left")
  local nv = Datos.contarPociones(p.bolsa, "vida")
  local nm = Datos.contarPociones(p.bolsa, "mana")
  local function fila(titulo, color, cual, on, umbral, cant, y0)
    local pct = math.floor((umbral or 0.5) * 100 + 0.5)
    love.graphics.setColor(color[1], color[2], color[3])
    love.graphics.print(titulo, x + 20, y0 + 6)
    love.graphics.setColor(0.7, 0.68, 0.6)
    love.graphics.print(cant .. " en la bolsa", x + 20, y0 + 24)
    I.boton(x + 168, y0 + 8, 44, 34, "-", "auto_" .. cual .. "_menos", pct > 20, "El mínimo es 20%.")
    love.graphics.setColor(0.98, 0.86, 0.45)
    love.graphics.printf(pct .. "%", x + 216, y0 + 16, 56, "center")
    I.boton(x + 276, y0 + 8, 44, 34, "+", "auto_" .. cual .. "_mas", pct < 90, "El máximo es 90%.")
    I.boton(x + 332, y0 + 8, 108, 34, on and "Activada" or "Activar", "auto_" .. cual .. "_on")
  end
  fila("Vida", { 1, 0.55, 0.45 }, "vida", p.autoPocion, p.autoPocionUmbral, nv, y + 96)
  love.graphics.setColor(0.30, 0.42, 0.72, 0.7)
  love.graphics.rectangle("fill", x + 16, y + 156, ancho - 32, 1)
  fila("Maná", { 0.55, 0.75, 1 }, "mana", p.autoMana, p.autoManaUmbral, nm, y + 172)
end

function I.panelAjustes(w, h)
  caja(w / 2 - 220, h / 2 - 180, 440, 360, "Ajustes")
  I.boton(w / 2 + 150, h / 2 - 170, 60, 28, "Cerrar", "cerrar")
  love.graphics.setColor(0.92, 0.88, 0.78)
  love.graphics.print("Volumen del sonido: " .. math.floor((Ajustes.volumen or 0) * 100 + 0.5) .. "%", w / 2 - 180, h / 2 - 118)
  I.boton(w / 2 + 40, h / 2 - 124, 44, 30, "-", "aj_vol_menos", (Ajustes.volumen or 0) > 0.001)
  I.boton(w / 2 + 92, h / 2 - 124, 44, 30, "+", "aj_vol_mas", (Ajustes.volumen or 0) < 0.999)
  I.boton(w / 2 - 180, h / 2 - 60, 160, 32, "1280×720", "aj_1280")
  I.boton(w / 2, h / 2 - 60, 160, 32, "1600×900", "aj_1600")
  I.boton(w / 2 - 180, h / 2 - 16, 340, 32, Ajustes.completo and "Ventana" or "Pantalla completa", "aj_completo")
  I.boton(w / 2 - 180, h / 2 + 36, 340, 32, "Teclado (poderes, pociones, interactuar, bolsa)…", "aj_teclado")
  local NOMBRE_GRAFICOS = { alto = "Alto (luz, reflejos, clima)", medio = "Medio", bajo = "Bajo (solo luz)", apagado = "Apagado" }
  I.boton(w / 2 - 180, h / 2 + 78, 340, 32, "Efectos gráficos: " .. (NOMBRE_GRAFICOS[Ajustes.graficos or "alto"] or "Alto"), "aj_graficos")
  love.graphics.setColor(0.75, 0.72, 0.64)
  love.graphics.print("F11 cambia la pantalla. F3 muestra el medidor.", w / 2 - 180, h / 2 + 124)
end

-- Teclado: la tecla de cada poder (por posición en la barra, ordenada por nivel), de las pociones, de interactuar y de la bolsa. Es de cada cuenta.
function I.panelTeclado(w, h)
  local n = #Ajustes.ACCIONES
  local filas = math.ceil(n / 2)
  local bw, bh = 520, 150 + filas * 40
  local px, py = w / 2 - bw / 2, h / 2 - bh / 2
  caja(px, py, bw, bh, "Teclado")
  I.boton(px + bw - 70, py + 8, 60, 28, "Volver", "tk_volver")
  love.graphics.setFont(pequena())
  love.graphics.setColor(0.8, 0.78, 0.7)
  local usuario = Ajustes.usuarioTeclas
  love.graphics.printf("Cuenta: " .. (usuario or "(sin sesión)") .. ". Pulsa una acción y luego la tecla que quieras; si ya la usa otra acción, intercambian.",
    px + 16, py + 44, bw - 32, "left")
  local bwBtn, hBtn = (bw - 48) / 2, 32
  for i, a in ipairs(Ajustes.ACCIONES) do
    local col, fila = (i - 1) % 2, math.floor((i - 1) / 2)
    local x = px + 16 + col * (bwBtn + 16)
    local y = py + 92 + fila * 40
    local esp = Ajustes.esperando == a[1]
    I.boton(x, y, bwBtn, hBtn, esp and (a[2] .. ": pulsa una tecla…") or (a[2] .. ": " .. Ajustes.nombreTecla(Ajustes.teclas[a[1]])), "tk_" .. a[1])
  end
  local yb = py + 92 + filas * 40 + 6
  I.boton(px + 16, yb, 200, 30, "Restablecer teclas", "tk_restablecer")
  if I.avisoTeclas then
    love.graphics.setColor(1, 0.7, 0.45)
    love.graphics.printf(I.avisoTeclas, px + 224, yb + 6, bw - 240, "left")
  end
end


require("src.presentacion.misiones_ui").instalar(I, { caja = caja, texto = texto })

return I
