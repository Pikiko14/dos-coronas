-- Animaciones de poderes. Cada hoja de "Animations" es una rejilla de 5 columnas
-- con celdas de 192x192; los cuadros se reproducen en orden de lectura.
local Arte = require("src.presentacion.render.arte")

local E = {}

local CELDA = 192
local COLUMNAS = 5

-- tipo de efecto -> hoja, escala, desplazamiento vertical (px sobre el suelo) y mezcla.
E.def = {
  golpe = { "Attack10", 0.5, 22 },
  corte = { "Attack7", 0.5, 22 },
  carga = { "Attack8", 0.6, 22 },
  tajo = { "Attack11", 0.8, 18 },
  grito = { "Special6", 0.8, 12, "add" },
  escudo = { "Special11", 0.6, 22 },
  curar = { "Heal1", 0.65, 12 },
  bendicion = { "Heal3", 0.65, 12 },
  consagrar = { "Light3", 0.8, 16, "add" },
  castigo = { "Light4", 0.7, 4 },
  sagrado = { "Attack1", 0.55, 20 },
  misil = { "Attack3", 0.5, 20 },
  fuego = { "Fire1", 0.7, 20 },
  nova = { "Ice5", 0.85, 6 },
  hielo = { "Ice2", 0.65, 20 },
  disparo = { "Sword1", 0.45, 20 },
  preciso = { "Spear2", 0.6, 20 },
  flecha = { "Spear1", 0.45, 20 },
  lluvia = { "Light5", 0.75, 4 },
  trampa = { "Earth2", 0.6, 4 },
  impacto = { "Attack1", 0.4, 20 },
  nivel = { "Light2", 0.8, 4 },
  -- estados alterados (tambiÃ©n se dibujan en bucle sobre quien los sufre)
  quemar = { "Fire2", 0.4, 14 },
  sangrar = { "Attack12", 0.45, 18 },
  veneno = { "State1", 0.45, 10 },
  drenar_vida = { "Darkness1", 0.38, 14 },
  drenar_mana = { "State2", 0.38, 14 },
  lentitud = { "State5", 0.4, 8 },
  aturdir = { "State4", 0.45, 36 },
  -- poderes de criaturas
  maldicion = { "Ice4", 0.35, 4 },
  aliento = { "Fire3", 0.6, 10, "add" },
  pisoton = { "Earth3", 0.35, 4 },
}

local hojas = {}

local function celdaVacia(datos, cx, cy)
  local x0, y0 = cx * CELDA, cy * CELDA
  local ancho, alto = datos:getDimensions()
  for y = y0, math.min(alto - 1, y0 + CELDA - 1), 4 do
    for x = x0, math.min(ancho - 1, x0 + CELDA - 1), 4 do
      local _, _, _, a = datos:getPixel(x, y)
      if a > 0.12 then return false end
    end
  end
  return true
end

local function hoja(nombre)
  local h = hojas[nombre]
  if h then return h end
  local ruta = "Animations/" .. nombre .. ".png"
  local img = Arte.img(ruta, true)
  local datos = Arte.datos(ruta)
  local filas = math.floor(img:getHeight() / CELDA)
  local cuadros = {}
  for fy = 0, filas - 1 do
    for fx = 0, COLUMNAS - 1 do
      if not celdaVacia(datos, fx, fy) then
        cuadros[#cuadros + 1] = Arte.quad(img, fx * CELDA, fy * CELDA, CELDA, CELDA)
      end
    end
  end
  h = { img = img, cuadros = cuadros }
  hojas[nombre] = h
  return h
end

-- Dibuja el cuadro que toca a los 't' segundos de una animación de 'dur'.
function E.cuadro(tipo, t, dur, sx, sy, escalaExtra, alfa)
  local d = E.def[tipo] or E.def.misil
  local h = hoja(d[1])
  local n = #h.cuadros
  if n == 0 then return end
  local k = math.min(n, math.floor(math.max(0, math.min(0.9999, t / math.max(0.01, dur))) * n) + 1)
  local esc = d[2] * (escalaExtra or 1)
  if d[4] == "add" then love.graphics.setBlendMode("add") end
  love.graphics.setColor(1, 1, 1, alfa or 1)
  love.graphics.draw(h.img, h.cuadros[k], sx, sy - d[3] * (escalaExtra or 1), 0, esc, esc, CELDA / 2, CELDA / 2)
  if d[4] == "add" then love.graphics.setBlendMode("alpha") end
end

-- Miniatura del primer cuadro bonito de una animación (para la barra de poderes).
function E.icono(tipo, x, y, lado)
  local d = E.def[tipo]
  if not d then return end
  local h = hoja(d[1])
  local n = #h.cuadros
  if n == 0 then return end
  local k = math.max(1, math.min(n, math.floor(n * 0.45) + 1))
  local esc = lado / CELDA
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(h.img, h.cuadros[k], x, y, 0, esc, esc)
end

return E
