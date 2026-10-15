-- Animaciones de poderes. Cada hoja de "Animations" es una rejilla de 5 columnas
-- con celdas de 192x192; los cuadros se reproducen en orden de lectura.
local Arte = require("src.presentacion.render.arte")

local E = {}

local CELDA = 192
local COLUMNAS = 5

-- tipo de efecto -> hoja, escala, desplazamiento vertical (px sobre el suelo) y mezcla.
-- Los poderes de las cuatro clases usan las hojas "Hechizo_<poder>" (generadas con
-- herramientas/generar_hechizos, 15 cuadros de 192x192 como las del pack).
E.def = {
  -- guerrero
  golpe = { "Hechizo_golpe", 0.55, 20, "add" },
  tajo = { "Hechizo_tajo", 0.95, 14, "add", base = math.pi / 6 },
  grito = { "Hechizo_grito", 0.9, 10, "add" },
  desgarro = { "Hechizo_desgarro", 0.7, 18, base = -math.pi / 4 },
  furia = { "Hechizo_furia", 0.62, 8, "add" },
  carga = { "Hechizo_carga", 0.7, 20, "add", base = 0 },
  -- mago
  misil = { "Hechizo_misil", 0.55, 20, "add" },
  fuego = { "Hechizo_fuego", 0.8, 14, "add" },
  escudo = { "Hechizo_escudo", 0.7, 20, "add" },
  nova = { "Hechizo_nova", 1.25, 6, "add" },
  sombra = { "Hechizo_sombra", 0.8, 14 },
  meteoro = { "Hechizo_meteoro", 0.95, 8 },
  -- cazador
  disparo = { "Hechizo_disparo", 0.5, 20, "add" },
  lluvia = { "Hechizo_lluvia", 1.05, 6 },
  trampa = { "Hechizo_trampa", 0.62, 4 },
  preciso = { "Hechizo_preciso", 0.62, 20, "add" },
  flecha_veneno = { "Hechizo_flecha_veneno", 0.62, 14, "add" },
  paso_agil = { "Hechizo_paso_agil", 0.65, 10, "add" },
  -- clerigo
  curar = { "Hechizo_curar", 0.72, 10, "add" },
  bendicion = { "Hechizo_bendicion", 0.72, 12, "add" },
  castigo = { "Hechizo_castigo", 0.72, 14, "add" },
  consagrar = { "Hechizo_consagrar", 1.15, 6, "add" },
  sanacion = { "Hechizo_sanacion", 1.15, 8, "add" },
  juicio = { "Hechizo_juicio", 0.8, 12, "add" },
  -- lancero
  estocada = { "Hechizo_estocada", 0.7, 20, "add", base = math.pi / 4 },
  barrido = { "Hechizo_barrido", 0.95, 14, "add", base = 0 },
  muro_lanzas = { "Hechizo_muro_lanzas", 0.95, 8 },
  embestida = { "Hechizo_embestida", 0.8, 20, "add", base = 0 },
  jabalina = { "Hechizo_jabalina", 0.7, 16, "add" },
  tormenta_lanzas = { "Hechizo_tormenta_lanzas", 1.1, 6 },
  -- nigromante (las hojas Necro_* son las del pack de efectos; el toque necrótico es propio)
  toque_necro = { "Hechizo_toque_necro", 0.6, 20, "add" },
  espinas = { "Necro_huesos", 0.95, 12 },
  maldecir = { "Necro_maldicion", 0.7, 12 },
  alzar_esqueletos = { "Necro_invocar", 0.85, 6 },
  drenar = { "Necro_drenar", 0.8, 18, "add" },
  espectro = { "Necro_alma", 0.7, 20, "add" },
  -- impactos de proyectiles y varios
  lanza = { "Hechizo_golpe", 0.5, 20, "add" },          -- impacto de la jabalina
  necro = { "Necro_alma", 0.5, 20, "add" },            -- impacto del proyectil necrótico
  sagrado = { "Hechizo_castigo", 0.5, 20, "add" },
  flecha = { "Hechizo_disparo", 0.45, 20, "add" },
  impacto = { "Hechizo_golpe", 0.42, 20, "add" },
  corte = { "Attack7", 0.5, 22, base = math.pi / 4 },
  hielo = { "Ice2", 0.65, 20 },
  nivel = { "Light2", 0.8, 4 },
  -- estados alterados (también se dibujan en bucle sobre quien los sufre)
  quemar = { "Fire2", 0.4, 14 },
  sangrar = { "Attack12", 0.45, 18, base = math.pi / 4 },
  veneno = { "State1", 0.45, 10 },
  drenar_vida = { "Darkness1", 0.38, 14 },
  drenar_mana = { "State2", 0.38, 14 },
  lentitud = { "State5", 0.4, 8 },
  aturdir = { "State4", 0.45, 36 },
  -- poderes de criaturas
  maldicion = { "Ice4", 0.35, 4 },
  aliento = { "Fire3", 0.6, 10, "add" },
  pisoton = { "Earth3", 0.35, 4 },
  -- poderes nuevos de cada oficio
  -- nigromante: hojas de 5x3 cuadros de 192, igual que los hechizos
  necro_huesos = { "Necro_huesos", 0.72, 16 },
  necro_alma = { "Necro_alma", 0.62, 20, "add" },
  necro_drenar = { "Necro_drenar", 0.7, 18, "add" },
  necro_maldicion = { "Necro_maldicion", 0.7, 12 },
  necro_invocar = { "Necro_invocar", 0.85, 6 },
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
-- rot: ángulo hacia donde debe apuntar (si el efecto tiene dirección: d.base es hacia dónde apunta el dibujo original).
function E.cuadro(tipo, t, dur, sx, sy, escalaExtra, alfa, rot)
  local d = E.def[tipo] or E.def.misil
  local h = hoja(d[1])
  local n = #h.cuadros
  if n == 0 then return end
  local k = math.min(n, math.floor(math.max(0, math.min(0.9999, t / math.max(0.01, dur))) * n) + 1)
  local esc = d[2] * (escalaExtra or 1)
  if d[4] == "add" then love.graphics.setBlendMode("add") end
  love.graphics.setColor(1, 1, 1, alfa or 1)
  local giro = (rot and d.base) and (rot - d.base) or 0
  love.graphics.draw(h.img, h.cuadros[k], sx, sy - d[3] * (escalaExtra or 1), giro, esc, esc, CELDA / 2, CELDA / 2)
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
