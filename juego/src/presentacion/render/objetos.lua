-- Objetos del mapa: árboles, faroles, estatuas, banderas, puertas, cristales...
-- Cada uno es un trozo de una lámina del pack nuevo (en casillas) que se recorta
-- a sus píxeles visibles y se ancla por el centro de abajo.
local Arte = require("src.presentacion.render.arte")

local O = {}

local B = "Tilesets/Outside_B.png"
local C = "Tilesets/Outside_C.png"
local W = "Tilesets/World_B.png"

-- area = { casillaX, casillaY, ancho, alto } en casillas de la lámina.
local DEF = {
  arbol = { { B, 0, 14, 2, 2 } },
  arbol_pino = { { B, 5, 11, 1, 2 } },
  arbol_seco = { { B, 8, 5, 1, 2 } },
  huevo = { { C, 4, 3, 1, 1 } },
  palma = { { B, 12, 5, 1, 2 }, { B, 13, 5, 1, 1 } },
  barril = { { B, 5, 9, 1, 1 } },
  caja = { { B, 4, 14, 1, 2 } },
  pozo = { { B, 3, 9, 1, 1 } },
  farol = { { B, 11, 10, 1, 3 } },
  tumba = { { B, 7, 9, 1, 1 } },
  roca = { { B, 7, 11, 1, 1 }, { B, 7, 12, 1, 1 } },
  matorral = { { B, 6, 12, 1, 1 } },
  estatua_albor = { { C, 1, 10, 1, 2 } },
  estatua_umbra = { { C, 3, 10, 1, 2 } },
  estatua = { { C, 7, 10, 1, 2 } },
  columna_albor = { { C, 6, 0, 1, 2 } },
  columna_umbra = { { C, 7, 0, 1, 2 } },
  bandera_albor = { { C, 0, 4, 1, 2 } },
  bandera_umbra = { { C, 2, 4, 1, 2 } },
  altar = { { C, 2, 6, 3, 2 } },
  altar_cristal = { { C, 5, 6, 3, 2 } },
  restos = { { C, 0, 3, 1, 1 } },
  -- Montañas del mapa del mundo (2 casillas de ancho, 4 de alto).
  montana_albor = { { W, 4, 3, 2, 2 } },
  montana_umbra = { { W, 2, 3, 2, 2 } },
  -- Decoración pequeña: se reparte por los biomas para que el suelo no quede vacío.
  seta_marron = { { B, 10, 5, 1, 1 } },
  seta_roja = { { B, 11, 5, 1, 1 } },
  tocon = { { B, 4, 11, 1, 1 } },
  tronco = { { B, 4, 12, 1, 1 } },
  piedra = { { B, 7, 11, 1, 1 }, { B, 7, 12, 1, 1 } },
  heno = { { B, 8, 7, 1, 1 } },
  helecho = { { B, 14, 6, 1, 1 } },
  hierba_seca = { { B, 15, 5, 1, 1 }, { B, 15, 6, 1, 1 } },
  hierba_alta = { { B, 11, 7, 1, 1 } },
  hojas = { { B, 12, 7, 1, 1 } },
  rafflesia = { { B, 10, 6, 1, 1 } },
  grieta = { { B, 12, 8, 1, 2 }, { B, 13, 8, 1, 2 }, { B, 14, 8, 1, 2 } },
  cultivo = { { B, 4, 13, 1, 1 }, { B, 5, 13, 1, 1 }, { B, 6, 13, 1, 1 }, { B, 7, 13, 1, 1 } },
  espantapajaros = { { B, 0, 13, 1, 1 } },
  fogata = { { B, 4, 10, 1, 1 } },
  circulo_piedras = { { B, 3, 10, 1, 1 } },
  cartel = { { B, 1, 9, 1, 1 }, { B, 6, 9, 1, 1 } },
  jarron = { { B, 0, 10, 1, 1 } },
  cubo = { { B, 1, 10, 1, 1 }, { B, 2, 10, 1, 1 } },
  flor_amarilla = { { B, 0, 12, 1, 1 } },
  flor_blanca = { { B, 1, 12, 1, 1 } },
  flor_roja = { { B, 2, 12, 1, 1 } },
  flores_mixtas = { { B, 3, 12, 1, 1 } },
  matas = { { B, 1, 11, 1, 1 }, { B, 3, 11, 1, 1 } },
  arbusto = { { B, 2, 11, 1, 1 } },
  madera_apilada = { { B, 2, 13, 1, 1 } },
  flores_naranja = { { B, 10, 7, 1, 1 } },
  arbusto_rosa = { { B, 13, 6, 1, 1 } },
}

local cache = {}

local function trozo(nombre, variante)
  local lista = DEF[nombre]
  if not lista then return nil end
  local d = lista[((variante or 0) % #lista) + 1]
  local clave = nombre .. "#" .. ((variante or 0) % #lista)
  local t = cache[clave]
  if t then return t end
  local img = Arte.img(d[1])
  local r = Arte.recorte(d[1], d[2] * 32, d[3] * 32, d[4] * 32, d[5] * 32)
  t = { img = img, quad = Arte.quad(img, r.x, r.y, r.w, r.h), w = r.w, h = r.h, rx = r.x, ry = r.y }
  cache[clave] = t
  return t
end

function O.existe(nombre)
  return DEF[nombre] ~= nil
end

-- Nombres y número de variantes de cada objeto (para revisarlos en pantalla).
function O.catalogo()
  local lista = {}
  for nombre, variantes in pairs(DEF) do lista[#lista + 1] = { nombre = nombre, n = #variantes } end
  table.sort(lista, function(a, b) return a.nombre < b.nombre end)
  return lista
end

-- Plantas vivas: se mecen con el viento (los árboles secos, las rocas y lo demás no). El sprite va sobre una malla de tiras
-- finas y cada fila se desplaza una fracción de píxel distinta: la base queda quieta y la copa se dobla en una curva suave,
-- sin saltos. amp = píxeles que se mueve la copa al máximo, vel = rapidez del vaivén. El viento avanza como una ola por el mapa
-- (la fase sale de la posición) y sube y baja con ráfagas lentas.
-- Solo se mecen las plantas altas, que es donde se nota (árboles, palmeras y arbustos grandes): la hierba y las flores bajas
-- son cientos por pantalla y un movimiento de un píxel no se ve, así que se dibujan normales (y mucho más baratas).
local VIVAS = {
  arbol = { 2.4, 0.9 }, arbol_pino = { 2.0, 1.0 }, palma = { 3.0, 1.1 },
  arbusto = { 1.2, 1.2 }, arbusto_rosa = { 1.1, 1.2 },
}
local MALLAS_POR_SPRITE = 12   -- se turnan: actualizar una y otra vez el mismo búfer en un cuadro hace esperar a la GPU
local TIRA = 4   -- alto de cada fila de la malla, en píxeles

-- La malla de un sprite (una sola vez): su propia copia con filtro suave, para que los desplazamientos de fracción de píxel no
-- parpadeen, y los vértices preparados. En reposo se ve idéntico al original.
local function malla(t)
  if t.malla ~= nil then return t.malla end
  t.malla = false
  local ok = pcall(function()
    local cv = love.graphics.newCanvas(t.w, t.h)
    love.graphics.push("all")
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.origin()
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(t.img, t.quad, 0, 0)
    love.graphics.pop()
    -- (el lienzo queda con el color ya multiplicado por la transparencia: se dibuja en modo "premultiplied", si no los
    -- bordes salen con un halo oscuro que parpadea al moverse)
    cv:setFilter("nearest", "nearest")
    local filas = math.max(2, math.ceil(t.h / TIRA))
    local verts = {}
    for k = 0, filas do
      local v = k / filas
      verts[#verts + 1] = { 0, v * t.h, 0, v, 1, 1, 1, 1 }
      verts[#verts + 1] = { t.w, v * t.h, 1, v, 1, 1, 1, 1 }
    end
    local lista = {}
    for i = 1, MALLAS_POR_SPRITE do
      local m = love.graphics.newMesh(verts, "strip", "stream")
      m:setTexture(cv)
      lista[i] = m
    end
    t.malla, t.mallas, t.turno, t.filas, t.verts = lista[1], lista, 1, filas, verts
  end)
  if not ok then t.malla = false end
  return t.malla
end

-- Prepara de antemano las mallas de las plantas que se mecen (si no, la primera vez que aparece cada una en pantalla hay un tirón).
function O.precalentar()
  for nombre in pairs(VIVAS) do
    local lista = DEF[nombre]
    for v = 0, (lista and #lista or 0) - 1 do
      local t = trozo(nombre, v)
      if t and t.h >= 8 then malla(t) end
    end
  end
end

-- Dibuja con la base en (sx, sy) (centro de abajo de la casilla). fase: desfase del vaivén de las plantas vivas.
function O.dibujar(nombre, variante, sx, sy, tinte, alfa, fase)
  local t = trozo(nombre, variante)
  if not t then return false end
  if tinte then love.graphics.setColor(tinte[1], tinte[2], tinte[3], alfa or 1)
  else love.graphics.setColor(1, 1, 1, alfa or 1) end
  local viva = VIVAS[nombre]
  if viva and t.h >= 8 then
    local m0 = malla(t)
    if m0 then
      t.turno = t.turno % MALLAS_POR_SPRITE + 1
      local m = t.mallas[t.turno]
      local ahora = love.timer.getTime()
      local f = fase or 0
      -- ráfagas lentas y un vaivén propio con un segundo armónico suave, para que no sea un péndulo perfecto
      local rafaga = 0.7 + 0.3 * math.sin(ahora * 0.3 + f * 0.15)
      local viento = (math.sin(ahora * viva[2] + f) + 0.25 * math.sin(ahora * viva[2] * 1.9 + f * 1.6)) * rafaga
      local verts, filas = t.verts, t.filas
      local x0, y0 = sx - t.w / 2, sy - t.h
      for k = 0, filas do
        local arriba = 1 - k / filas                      -- 0 en la base, 1 en la copa
        local d = viva[1] * viento * arriba * arriba       -- curva: casi nada abajo, mucho arriba
        local a, b = verts[k * 2 + 1], verts[k * 2 + 2]
        a[1], a[2] = x0 + d, y0 + (k / filas) * t.h
        b[1], b[2] = x0 + t.w + d, y0 + (k / filas) * t.h
      end
      m:setVertices(verts)
      local r, g, b, a = love.graphics.getColor()
      love.graphics.setBlendMode("alpha", "premultiplied")
      love.graphics.setColor(r * a, g * a, b * a, a)
      love.graphics.draw(m)
      love.graphics.setBlendMode("alpha")
      return true
    end
  end
  love.graphics.draw(t.img, t.quad, sx, sy, 0, 1, 1, t.w / 2, t.h)
  return true
end

-- Puerta de ciudad o de batalla (hoja "$Gate": 3 columnas x 4 filas de 96x64).
-- estado: 0 cerrada, 2 abierta.
local PUERTAS = { albor = "Characters/!$Gate1.png", umbra = "Characters/!$Gate2.png" }
function O.puerta(faccion, abierta, sx, sy, escala)
  local ruta = PUERTAS[faccion] or PUERTAS.albor
  local img = Arte.img(ruta)
  local q = Arte.quad(img, 0, abierta and 128 or 0, 96, 64)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(img, q, sx, sy, 0, escala or 1, escala or 1, 48, 62)
end

-- Cristal (hoja "!Crystal": 12 columnas x 8 filas de 32x64). Albor azul, Umbra violeta.
function O.cristal(faccion, brillo, sx, sy)
  local img = Arte.img("Characters/!Crystal.png")
  local col = faccion == "umbra" and 9 or 0
  local fila = brillo and 1 or 0
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(img, Arte.quad(img, col * 32, fila * 64, 32, 64), sx, sy, 0, 1, 1, 16, 58)
end

-- Cofre (hoja "!Chest": cuadros de 32x32). Cerrado.
function O.cofre(sx, sy)
  local img = Arte.img("Characters/!Chest.png")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(img, Arte.quad(img, 0, 128, 32, 32), sx, sy, 0, 1, 1, 16, 30)
end

O.personalizados = O.personalizados or {}

-- Mobiliario de la plaza, dibujado con rectángulos (no hay láminas de bancos ni macetas en el pack).
-- La madera es oscura en las ciudades de Umbra y clara en las de Albor (p.fac).
O.personalizados.banco = function(p, sx, sy)
  local umbra = p.fac == "umbra"
  local madera = umbra and { 0.3, 0.22, 0.34 } or { 0.62, 0.42, 0.22 }
  local claro = umbra and { 0.42, 0.32, 0.46 } or { 0.78, 0.55, 0.3 }
  local hierro = umbra and { 0.16, 0.14, 0.2 } or { 0.25, 0.22, 0.2 }
  love.graphics.setColor(0, 0, 0, 0.22)
  love.graphics.ellipse("fill", sx, sy - 3, 15, 4, 16)
  -- patas y respaldo
  love.graphics.setColor(hierro[1], hierro[2], hierro[3], 1)
  love.graphics.rectangle("fill", sx - 13, sy - 9, 2, 8)
  love.graphics.rectangle("fill", sx + 11, sy - 9, 2, 8)
  love.graphics.rectangle("fill", sx - 13, sy - 19, 2, 11)
  love.graphics.rectangle("fill", sx + 11, sy - 19, 2, 11)
  love.graphics.setColor(madera[1], madera[2], madera[3], 1)
  love.graphics.rectangle("fill", sx - 14, sy - 19, 28, 3)
  love.graphics.rectangle("fill", sx - 14, sy - 14, 28, 3)
  love.graphics.setColor(claro[1], claro[2], claro[3], 1)
  love.graphics.rectangle("fill", sx - 15, sy - 9, 30, 4)
  love.graphics.setColor(madera[1] * 0.7, madera[2] * 0.7, madera[3] * 0.7, 1)
  love.graphics.rectangle("fill", sx - 15, sy - 5, 30, 1)
  love.graphics.setColor(1, 1, 1, 0.18)
  love.graphics.rectangle("fill", sx - 14, sy - 19, 28, 1)
end

-- Maceta de la plaza: un cubo de madera del pack con una mata florida encima (naranja o rosa según la casilla).
O.personalizados.maceta = function(p, sx, sy)
  local v = (p.x * 7 + p.y * 13) % 2
  love.graphics.setColor(0, 0, 0, 0.2)
  love.graphics.ellipse("fill", sx, sy - 2, 11, 4, 14)
  O.dibujar("cubo", v, sx, sy)
  O.dibujar(v == 0 and "flores_naranja" or "arbusto_rosa", 0, sx, sy - 9)
end

-- Puerta de mazmorra: un portón de piedra con un resplandor y el nombre encima. Es un prop del mapa
-- (tipo "puerta_mazmorra"; salida = true la pinta como la puerta de salida de dentro).
O.personalizados = O.personalizados or {}

-- Barcos de los muelles (hoja Vehicle: columnas 0-2 el bote, 3-5 el navío; filas abajo, izquierda, derecha, arriba).
-- Van amarrados mirando a lo largo del muelle y se mecen suavemente con las olas.
local FILA_RUMBO = function(rx, ry)
  if rx > 0 then return 2 elseif rx < 0 then return 1 elseif ry > 0 then return 0 end
  return 3
end
local function embarcacion(p, sx, sy, col0, escala, ancla)
  local img = Arte.img("Characters/Vehicle.png")
  local t = love.timer.getTime()
  local mece = math.sin(t * 1.4 + (p.x * 3 + p.y) * 0.7)
  love.graphics.setColor(0, 0, 0, 0.18)
  love.graphics.ellipse("fill", sx, sy - 2, 18 * escala, 6 * escala)
  love.graphics.setColor(1, 1, 1, 1)
  local fila = FILA_RUMBO(p.rx or 0, p.ry or 1)
  love.graphics.draw(img, Arte.quad(img, (col0 + 1) * 32, fila * 32, 32, 32), sx, sy + mece * 1.6, mece * 0.012, escala, escala, 16, ancla)
end
O.personalizados.barco = function(p, sx, sy) embarcacion(p, sx, sy, 3, 2.4, 28) end
O.personalizados.bote = function(p, sx, sy) embarcacion(p, sx, sy, 0, 1.4, 28) end

O.personalizados.puerta_mazmorra = function(p, sx, sy)
  local def = require("compartido.dominio.datos").mazmorra(p.mz)
  local t = love.timer.getTime()
  local c = def and def.tinte or { 1, 1, 1 }
  love.graphics.setColor(c[1] * 0.5, c[2] * 0.5, c[3] * 0.9, 0.22 + 0.08 * math.sin(t * 2.4))
  love.graphics.ellipse("fill", sx, sy - 24, 54, 38, 24)
  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.ellipse("fill", sx, sy - 1, 40, 9, 20)
  O.puerta("umbra", p.salida and true or false, sx, sy, 0.8)
  if def then
    local f = love.graphics.getFont()
    local texto = p.salida and "Salida" or (def.nombre .. "  (nivel " .. def.nivelMin .. "+)")
    local w = f:getWidth(texto)
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.print(texto, sx - w / 2 + 1, sy - 82 + 1)
    love.graphics.setColor(1, 0.9, 0.55, 1)
    love.graphics.print(texto, sx - w / 2, sy - 82)
  end
end

return O
