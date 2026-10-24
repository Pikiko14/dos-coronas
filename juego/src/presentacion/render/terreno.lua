-- Dibuja el suelo con las láminas nuevas. El mapa se pinta en bloques de
-- 16x16 casillas dentro de canvas que se guardan, así cada fotograma solo
-- coloca unos pocos bloques en pantalla.
local Arte = require("src.presentacion.render.arte")
local Auto = require("src.presentacion.render.autotile")
local Objetos = require("src.presentacion.render.objetos")
local MapaFao = require("src.presentacion.render.mapa_fao")
local Detalle = require("src.presentacion.render.casas")
local CasasIso = require("src.presentacion.render.casas_iso")
local Iso = require("src.presentacion.render.iso")
local InteriorCasa = require("src.presentacion.render.interior_casa")
local MapaMpc = require("src.presentacion.render.mapa_mpc")

local T = {}

local TILE = 32
local BLOQUE = 16
-- En isométrico los bloques se hornean al doble de resolución (así el suelo proyectado no sale borroso) y pesan 4 veces más.
local ESC_BLOQUE = Iso.activo() and 2 or 1
local LIMITE_BLOQUES = Iso.activo() and 45 or 120   -- (cada bloque son 1 MB de memoria de vídeo, 5 MB al doble de resolución)
local TINTE_UMBRA = { 0.66, 0.58, 0.92 }
local TINTE_CICATRIZ = { 0.62, 0.42, 0.40 }

-- Familias de suelo: lo que cuenta como "lo mismo" para unir bordes.
local FAMILIA = {
  hierba = "hierba", hierba_osc = "hierba", bosque = "hierba", adoquin = "hierba",
  arena = "arena", tierra = "tierra", cicatriz = "tierra", montana = "tierra",
  camino = "pavimento", calle = "pavimento", plaza = "pavimento",
  agua = "agua", muralla = "muralla", teja = "edificio", teja_umbra = "edificio",
  fachada = "edificio", empedrado = "empedrado", madera = "madera", tejado = "edificio", mazmorra = "mazmorra",
  nieve = "nieve", roca = "roca", pantano = "pantano",
}

local img

local function imagenes()
  if img then return img end
  img = {
    a1 = Arte.img("Tilesets/Outside_A1.png"),
    a2 = Arte.img("Tilesets/Outside_A2.png"),
    a3 = Arte.img("Tilesets/Outside_A3.png"),
    a5 = Arte.img("Tilesets/Outside_A5.png"),
    b = Arte.img("Tilesets/Outside_B.png"),
    ia5 = Arte.img("Tilesets/Inside_A5.png"),
    ib = Arte.img("Tilesets/Inside_B.png"),
  }
  return img
end

local function hash(x, y, sal)
  local n = (x * 73856093 + y * 19349663 + (sal or 0) * 83492791) % 2147483647
  n = (n * 1103515245 + 12345) % 2147483647
  return (n % 10007) / 10007
end

local function suelo(mapa, x, y)
  return mapa.suelo[x] and mapa.suelo[x][y]
end

local function familia(mapa, x, y)
  if x < 0 or y < 0 or x >= mapa.w or y >= mapa.h then return nil end
  local f = FAMILIA[suelo(mapa, x, y) or ""]
  -- con las casas isométricas, bajo la huella del edificio hay hierba normal (la casa se dibuja encima)
  if f == "edificio" and CasasIso.activo() then return "hierba" end
  return f
end

local function lado(mapa, x, y)
  return mapa.lado[x] and mapa.lado[x][y]
end

-- Base de suelo (fila del bloque A2) a la que pertenece una casilla.
local function baseDe(mapa, x, y)
  local f = familia(mapa, x, y)
  if f == "arena" then return 2 end
  if f == "tierra" then return 1 end
  if f == "hierba" then return 0 end
  -- pavimento y demás: vota la base de los vecinos
  local votos = { [0] = 0, 0, 0 }
  for dy = -1, 1 do
    for dx = -1, 1 do
      local g = familia(mapa, x + dx, y + dy)
      if g == "arena" then votos[2] = votos[2] + 1
      elseif g == "tierra" then votos[1] = votos[1] + 1
      elseif g == "hierba" then votos[0] = votos[0] + 1 end
    end
  end
  local mejor, mv = 0, votos[0]
  if votos[1] > mv then mejor, mv = 1, votos[1] end
  if votos[2] > mv then mejor, mv = 2, votos[2] end
  return mejor
end

-- Color de una casilla: la hierba y la tierra del lado de Umbra se oscurecen y la
-- cicatriz se tiñe de rojizo. fam es la familia de suelo a la que se pinta.
local function tinte(mapa, x, y, fam)
  local tipo = suelo(mapa, x, y)
  if tipo == "cicatriz" then return TINTE_CICATRIZ end
  if (fam == "hierba" or fam == "tierra") and (tipo == "hierba_osc" or lado(mapa, x, y) == "umbra") then
    return TINTE_UMBRA
  end
  return nil
end

local function color(c)
  if c then love.graphics.setColor(c[1], c[2], c[3], 1) else love.graphics.setColor(1, 1, 1, 1) end
end

local NOMBRE_FAMILIA_BASE = { [0] = "hierba", [1] = "tierra", [2] = "arena" }

local function hayVecino(mapa, x, y, fam)
  for dy = -1, 1 do
    for dx = -1, 1 do
      if (dx ~= 0 or dy ~= 0) and familia(mapa, x + dx, y + dy) == fam then return true end
    end
  end
  return false
end

-- Suelo base de una casilla. Los cambios de terreno no se hacen cortando de golpe
-- de un tile a otro: la hierba junto a la arena y la tierra sobre la hierba se
-- pintan como parches con bordes redondeados (autotiles A2) sobre el suelo de abajo.
-- Devuelve la fila de base (0 hierba, 1 tierra, 2 arena) para los caminos.
local function dibujarBase(mapa, x, y, px, py)
  local im = imagenes()
  local f = familia(mapa, x, y)
  local v = math.floor(hash(x, y, 1) * 4)
  local function plano(fila)
    love.graphics.draw(im.a2, Arte.quad(im.a2, (v % 2) * 32, fila * 96 + math.floor(v / 2) * 32, 32, 32), px, py)
  end
  if f == "hierba" then
    color(tinte(mapa, x, y, "hierba"))
    if hayVecino(mapa, x, y, "arena") then
      plano(2)
      local m = Auto.mascara(function(dx, dy)
        local g = familia(mapa, x + dx, y + dy)
        return g ~= "arena" and g ~= "agua"
      end)
      Auto.suelo(im.a2, 64, 2 * 96, m, px, py) -- "Grass (Sand)"
    else
      plano(0)
    end
    return 0
  elseif f == "tierra" then
    color(tinte(mapa, x, y, "tierra"))
    plano(0)
    local m = Auto.mascara(function(dx, dy)
      local g = familia(mapa, x + dx, y + dy)
      return g ~= "hierba"
    end)
    Auto.suelo(im.a2, 64, 0, m, px, py) -- "Dirt (Meadow)"
    return 1
  elseif f == "arena" then
    color(nil)
    plano(2)
    return 2
  end
  local base = baseDe(mapa, x, y)
  color(tinte(mapa, x, y, NOMBRE_FAMILIA_BASE[base]))
  plano(base)
  return base
end

local function dibujarPavimento(mapa, x, y, px, py, base)
  local im = imagenes()
  local m = Auto.mascara(function(dx, dy)
    local g = familia(mapa, x + dx, y + dy)
    return g == "pavimento" or g == nil
  end)
  color(tinte(mapa, x, y, NOMBRE_FAMILIA_BASE[base]))
  Auto.suelo(im.a2, 128, base * 96, m, px, py)
end

-- Decoración repartida por biomas: cada bioma tiene su lista de objetos y la
-- probabilidad de cada uno por casilla. Así ningún sitio queda pelado.
local DECORADO = {
  trigal = { { "flor_amarilla", 0.03 }, { "flor_blanca", 0.015 }, { "matas", 0.03 }, { "heno", 0.004 }, { "flores_mixtas", 0.01 } },
  campos = { { "flor_roja", 0.012 }, { "matas", 0.025 }, { "heno", 0.01 }, { "piedra", 0.008 }, { "hierba_alta", 0.02 } },
  muelle = { { "hierba_seca", 0.035 }, { "piedra", 0.012 }, { "tronco", 0.008 }, { "cubo", 0.004 }, { "madera_apilada", 0.003 } },
  marea = { { "hierba_seca", 0.035 }, { "piedra", 0.014 }, { "tronco", 0.007 }, { "seta_roja", 0.004 } },
  senda = { { "seta_marron", 0.02 }, { "seta_roja", 0.012 }, { "tocon", 0.014 }, { "tronco", 0.01 }, { "helecho", 0.05 }, { "matas", 0.035 }, { "hojas", 0.015 } },
  pinar = { { "seta_marron", 0.012 }, { "seta_roja", 0.012 }, { "tocon", 0.012 }, { "tronco", 0.012 }, { "helecho", 0.05 }, { "hojas", 0.025 }, { "piedra", 0.008 } },
  colina = { { "piedra", 0.025 }, { "flor_amarilla", 0.03 }, { "hierba_alta", 0.03 }, { "matas", 0.025 }, { "arbusto", 0.01 } },
  velo = { { "seta_roja", 0.022 }, { "hierba_seca", 0.04 }, { "hojas", 0.025 }, { "rafflesia", 0.004 }, { "piedra", 0.008 } },
  cienaga = { { "seta_roja", 0.028 }, { "rafflesia", 0.009 }, { "hierba_alta", 0.045 }, { "hojas", 0.03 }, { "helecho", 0.035 } },
  eclipse = { { "grieta", 0.04 }, { "piedra", 0.025 }, { "hierba_seca", 0.025 } },
  cicatriz = { { "grieta", 0.045 }, { "piedra", 0.025 } },
  costa = { { "hierba_seca", 0.03 }, { "piedra", 0.014 }, { "tronco", 0.006 } },
  bosque = { { "seta_marron", 0.014 }, { "seta_roja", 0.008 }, { "tocon", 0.012 }, { "tronco", 0.008 }, { "helecho", 0.045 }, { "hojas", 0.02 } },
  altiplano = { { "piedra", 0.035 }, { "grieta", 0.02 }, { "hierba_seca", 0.012 } },
  ventisca = { { "piedra", 0.022 }, { "grieta", 0.01 }, { "tronco", 0.004 } },
  islote = { { "flor_blanca", 0.02 }, { "matas", 0.03 }, { "piedra", 0.01 } },
  albor = { { "flor_amarilla", 0.022 }, { "flor_blanca", 0.018 }, { "flor_roja", 0.008 }, { "matas", 0.035 }, { "hierba_alta", 0.02 }, { "piedra", 0.005 } },
  umbra = { { "seta_roja", 0.012 }, { "hierba_seca", 0.03 }, { "matas", 0.025 }, { "piedra", 0.007 }, { "flor_blanca", 0.012 }, { "hojas", 0.012 } },
  ciudad = { { "flor_amarilla", 0.03 }, { "flor_roja", 0.02 }, { "flores_mixtas", 0.025 }, { "matas", 0.025 }, { "jarron", 0.004 }, { "cubo", 0.004 } },
}
-- Lo que se queda tal cual, sin teñir con el color de la zona.
local SIN_TINTE = { piedra = true, grieta = true, restos = true, fogata = true, cubo = true, jarron = true, madera_apilada = true, tronco = true, tocon = true }

-- Campos de cultivo: parches de 8x6 casillas con hortalizas.
local function cultivo(mapa, x, y, bioma)
  if bioma ~= "campos" and bioma ~= "trigal" then return nil end
  local bx, by = math.floor(x / 8), math.floor(y / 6)
  if hash(bx, by, 9) > 0.3 then return nil end
  local lx, ly = x - bx * 8, y - by * 6
  if lx < 1 or lx > 6 or ly < 1 or ly > 4 then return nil end
  return "cultivo", math.floor(hash(bx, by, 10) * 4)
end

local function decorar(mapa, x, y, px, py, tipo, fam)
  if fam ~= "hierba" and fam ~= "tierra" and fam ~= "arena" then return end
  if mapa.decorado then
    -- mapas con la decoración colocada a mano (campo de batalla): rocas, huecos y restos con colisión
    -- relieve suave del suelo: lomas claras y hondonadas oscuras (ruido de baja frecuencia)
    local n = math.sin(x * 0.19 + y * 0.07) + math.sin(y * 0.23 - x * 0.05) + math.sin((x + y) * 0.09) * 0.8
    if n < -0.3 then
      love.graphics.setColor(0, 0, 0, math.min(0.2, (-n - 0.3) * 0.1))
      love.graphics.rectangle("fill", px, py, TILE, TILE)
    elseif n > 0.9 then
      love.graphics.setColor(1, 0.78, 0.55, math.min(0.1, (n - 0.9) * 0.08))
      love.graphics.rectangle("fill", px, py, TILE, TILE)
    end
    local d = mapa.decorado[x] and mapa.decorado[x][y]
    if d then require("src.presentacion.render.campo").decoracion(mapa, d, x, y, px, py) end
    return
  end
  -- relieve suave del terreno abierto: lomas claras y hondonadas oscuras (ruido de baja frecuencia)
  if not mapa.decorado and mapa.w > 300 then
    local n = math.sin(x * 0.045 + y * 0.02) + math.sin(y * 0.06 - x * 0.03) + 0.8 * math.sin((x + y) * 0.021) + 0.6 * math.sin(x * 0.11 - y * 0.09)
    if n < -0.5 then
      love.graphics.setColor(0, 0, 0.05, math.min(0.16, (-n - 0.5) * 0.09))
      love.graphics.rectangle("fill", px, py, TILE, TILE)
    elseif n > 1.1 then
      love.graphics.setColor(1, 0.95, 0.7, math.min(0.1, (n - 1.1) * 0.07))
      love.graphics.rectangle("fill", px, py, TILE, TILE)
    end
  end
  local adorno = mapa.adorno and mapa.adorno[x] and mapa.adorno[x][y]
  if adorno then
    Objetos.dibujar(adorno, 0, px + 16, py + 31, nil, nil, x * 0.35 + y * 0.2)
    return
  end
  if mapa.bloque[x] and mapa.bloque[x][y] then return end
  if tipo == "montana" or tipo == "adoquin" then return end
  local bioma = mapa.bioma[x] and mapa.bioma[x][y]
  local nombre, variante = cultivo(mapa, x, y, bioma)
  if not nombre then
    local lista = DECORADO[bioma or ""]
    if not lista then return end
    local r = hash(x, y, 7)
    local acum = 0
    for _, d in ipairs(lista) do
      acum = acum + d[2]
      if r < acum then nombre = d[1] break end
    end
    if not nombre then return end
    variante = math.floor(hash(x, y, 8) * 997)
  end
  Objetos.dibujar(nombre, variante, px + 16, py + 31, (not SIN_TINTE[nombre]) and tinte(mapa, x, y, fam) or nil, nil, x * 0.35 + y * 0.2)
end

-- Mar: autotile A1 tipo 10 (agua con su orilla de arena), tres cuadros de oleaje.
local function dibujarAgua(mapa, x, y, px, py, cuadro)
  local im = imagenes()
  local m = Auto.mascara(function(dx, dy)
    local g = familia(mapa, x + dx, y + dy)
    return g == "agua" or g == nil
  end)
  love.graphics.setColor(1, 1, 1, 1)
  Auto.suelo(im.a1, cuadro * 64, 288, m, px, py)
end

local function dibujarMuralla(mapa, x, y, px, py)
  local im = imagenes()
  local v = math.floor(hash(x, y, 2) * 3)
  if mapa.mazmorra then love.graphics.setColor(0.5, 0.5, 0.58, 1) else love.graphics.setColor(1, 1, 1, 1) end
  love.graphics.draw(im.a5, Arte.quad(im.a5, v * 32, 8 * 32, 32, 32), px, py)
  if familia(mapa, x, y - 1) ~= "muralla" then
    -- remate más claro en el borde superior
    love.graphics.setColor(1, 1, 1, 0.22)
    love.graphics.rectangle("fill", px, py, 32, 3)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", px, py + 3, 32, 2)
  end
  if familia(mapa, x, y + 1) ~= "muralla" then
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", px, py + 28, 32, 4)
  end
end

local function dibujarInterior(mapa, x, y, px, py)
  local im = imagenes()
  local tipo = suelo(mapa, x, y)
  love.graphics.setColor(1, 1, 1, 1)
  if tipo == "madera" then
    -- parquet de la lámina interior (A5, fila 2)
    love.graphics.draw(im.ia5, Arte.quad(im.ia5, 0, 2 * 32, 32, 32), px, py)
    InteriorCasa.interior(mapa, x, y, px, py, tipo)
  elseif InteriorCasa.interior(mapa, x, y, px, py, tipo) then
    -- pared de la casa pintada por código
  else
    -- muro de piedra
    love.graphics.draw(im.ia5, Arte.quad(im.ia5, (2 + (x + y) % 2) * 32, 0, 32, 32), px, py)
    love.graphics.setColor(0, 0, 0, 0.18)
    love.graphics.rectangle("fill", px, py + 28, 32, 4)
  end
end

-- Suelos propios (nieve, roca, pantano): se dibujan por código, con 4 variantes cada uno, y se funden con
-- los suelos vecinos mediante franjas suaves en vez de cortar de golpe de un tile a otro.
local PROC = { nieve = true, roca = true, pantano = true }
local COLOR_SUELO = {
  nieve = { 0.88, 0.93, 1.0 }, roca = { 0.50, 0.50, 0.55 }, pantano = { 0.17, 0.27, 0.20 },
  hierba = { 0.38, 0.62, 0.28 }, tierra = { 0.55, 0.40, 0.24 }, arena = { 0.85, 0.78, 0.52 },
}
local variantesProc = {}
local franjaV, franjaH

local function ruidoTile(i, j, sal)
  local n = (i * 374761393 + j * 668265263 + sal * 1274126177) % 2147483647
  n = (n * 1103515245 + 12345) % 2147483647
  return (n % 10007) / 10007
end

local function crearVariantes(tipo)
  local lista = {}
  for v = 1, 4 do
    local d = love.image.newImageData(32, 32)
    local base = COLOR_SUELO[tipo]
    -- manchas suaves dentro del tile (nunca tocan el borde, así los tiles encajan sin costuras)
    local function mancha(cx, cy, rx, ry, color, fuerza)
      for py = math.max(1, math.floor(cy - ry)), math.min(30, math.ceil(cy + ry)) do
        for px = math.max(1, math.floor(cx - rx)), math.min(30, math.ceil(cx + rx)) do
          local dx, dy = (px - cx) / rx, (py - cy) / ry
          local k = 1 - (dx * dx + dy * dy)
          if k > 0 then
            local a = math.min(1, k * 2.2) * fuerza
            local r, g, b = d:getPixel(px, py)
            d:setPixel(px, py, r + (color[1] - r) * a, g + (color[2] - g) * a, b + (color[3] - b) * a, 1)
          end
        end
      end
    end
    for py = 0, 31 do
      for px = 0, 31 do
        local g2 = ruidoTile(px, py, v * 13 + 2) - 0.5
        local r, gg, b = base[1], base[2], base[3]
        if tipo == "nieve" then
          local k = 1 + g2 * 0.035
          r, gg, b = r * k, gg * k, b * (k + 0.005)
          if ruidoTile(px, py, v * 17 + 3) > 0.988 then r, gg, b = 1, 1, 1 end
        elseif tipo == "roca" then
          local k = 1 + g2 * 0.14
          r, gg, b = r * k, gg * k, b * k
          if ruidoTile(px, py, v * 17 + 3) > 0.975 then r, gg, b = r * 1.18, gg * 1.18, b * 1.18 end
        else
          local k = 1 + g2 * 0.16
          r, gg, b = r * k, gg * k, b * k
        end
        d:setPixel(px, py, math.min(1, r), math.min(1, gg), math.min(1, b), 1)
      end
    end
    if tipo == "nieve" then
      mancha(8 + ruidoTile(v, 1, 5) * 16, 8 + ruidoTile(v, 2, 5) * 16, 9, 6, { 0.78, 0.87, 0.97 }, 0.35)
    elseif tipo == "roca" then
      mancha(8 + ruidoTile(v, 1, 6) * 16, 8 + ruidoTile(v, 2, 6) * 16, 8, 6, { 0.38, 0.38, 0.43 }, 0.3)
      for c = 1, 2 do
        local x, y = math.floor(ruidoTile(v, c, 5) * 22) + 5, math.floor(ruidoTile(c, v, 6) * 22) + 5
        for _ = 1, 8 do
          if x >= 2 and x <= 29 and y >= 2 and y <= 29 then
            d:setPixel(x, y, 0.22, 0.22, 0.26, 1)
            if ruidoTile(x, y, v + 30) > 0.5 then d:setPixel(x + 1, y, 0.3, 0.3, 0.34, 1) end
          end
          x = x + (ruidoTile(x, y, v + 40) > 0.5 and 1 or -1)
          y = y + (ruidoTile(x, y, v + 50) > 0.35 and 1 or 0)
        end
      end
    else
      -- pantano: charcos de agua oscura, manchas de barro y cañas
      if ruidoTile(v, 3, 9) < 0.7 then
        mancha(9 + ruidoTile(v, 1, 7) * 14, 9 + ruidoTile(v, 2, 7) * 14, 4 + ruidoTile(v, 4, 7) * 4, 3 + ruidoTile(v, 5, 7) * 3, { 0.09, 0.19, 0.21 }, 0.85)
      end
      if ruidoTile(v, 6, 9) < 0.5 then
        mancha(8 + ruidoTile(v, 7, 7) * 16, 8 + ruidoTile(v, 8, 7) * 16, 5, 4, { 0.27, 0.23, 0.15 }, 0.5)
      end
      for c = 1, 2 do
        local x, y = math.floor(ruidoTile(v, c, 7) * 24) + 4, math.floor(ruidoTile(c, v, 8) * 20) + 9
        for k = 0, 4 do d:setPixel(x, y - k, 0.34, 0.5, 0.28, 1) end
        d:setPixel(x + 1, y - 3, 0.42, 0.58, 0.32, 1)
      end
    end
    local img = love.graphics.newImage(d)
    img:setFilter("nearest", "nearest")
    lista[v] = img
  end
  return lista
end

local function franjas()
  if franjaV then return end
  local dv = love.image.newImageData(1, 16)
  for i = 0, 15 do dv:setPixel(0, i, 1, 1, 1, 1 - i / 15) end
  franjaV = love.graphics.newImage(dv)
  franjaV:setFilter("linear", "linear")
  local dh = love.image.newImageData(16, 1)
  for i = 0, 15 do dh:setPixel(i, 0, 1, 1, 1, 1 - i / 15) end
  franjaH = love.graphics.newImage(dh)
  franjaH:setFilter("linear", "linear")
end

local function colorVecino(mapa, x, y)
  local g = familia(mapa, x, y)
  if g == "hierba" and suelo(mapa, x, y) == "hierba_osc" then return { 0.28, 0.40, 0.34 } end
  return COLOR_SUELO[g]
end

-- Franjas de color del vecino sobre los cuatro bordes del tile cuando el suelo vecino es distinto y
-- alguno de los dos es un suelo propio: la frontera se ve difuminada.
local function fundirBordes(mapa, x, y, px, py, fam)
  franjas()
  local ANCHO = 11
  local lados = { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }
  for _, l in ipairs(lados) do
    local g = familia(mapa, x + l[1], y + l[2])
    if g and g ~= fam and (PROC[g] or PROC[fam]) and COLOR_SUELO[g] then
      local c = colorVecino(mapa, x + l[1], y + l[2])
      if c then
        love.graphics.setColor(c[1], c[2], c[3], 0.62)
        if l[2] == -1 then love.graphics.draw(franjaV, px, py, 0, TILE, ANCHO / 16)
        elseif l[2] == 1 then love.graphics.draw(franjaV, px, py + TILE, 0, TILE, -ANCHO / 16)
        elseif l[1] == -1 then love.graphics.draw(franjaH, px, py, 0, ANCHO / 16, TILE)
        else love.graphics.draw(franjaH, px + TILE, py, 0, -ANCHO / 16, TILE) end
      end
    end
  end
end

local function dibujarProcedural(mapa, x, y, px, py, fam, tipo)
  if not variantesProc[fam] then variantesProc[fam] = crearVariantes(fam) end
  local v = 1 + math.floor(hash(x, y, 3) * 4)
  local k = 0.985 + hash(x, y, 9) * 0.03
  love.graphics.setColor(k, k, k, 1)
  love.graphics.draw(variantesProc[fam][v], px, py)
  fundirBordes(mapa, x, y, px, py, fam)
  if not (mapa.bloque[x] and mapa.bloque[x][y]) then
    decorar(mapa, x, y, px, py, tipo, "tierra")
  end
end

-- Suelo de las ciudades con las texturas nuevas (arte/ciudad/terreno/): cada textura cubre 8x8 casillas. Devuelve true si dibujó la casilla.
local TEX_CIUDAD = {}
local function texturaCiudad(nombre)
  local t = TEX_CIUDAD[nombre]
  if t == nil then
    local ruta = "arte/ciudad/terreno/" .. nombre .. ".png"
    if love.filesystem.getInfo(ruta) then
      local img = love.graphics.newImage(ruta, { mipmaps = true })
      img:setFilter("linear", "linear")
      img:setWrap("repeat", "repeat")
      t = { img = img, w = img:getWidth(), h = img:getHeight(), quads = {} }
    else
      t = false
    end
    TEX_CIUDAD[nombre] = t
  end
  return t or nil
end

local SUELO_CIUDAD = {
  calle = "calle", plaza = "plaza", adoquin = "hierba", agua = "agua", arena = "arena",
  teja = "hierba", teja_umbra = "hierba", fachada = "hierba", tejado = "hierba",
}

local TONO_CIUDAD = { calle = { 1.35, 1.28, 1.15 }, plaza = { 1.0, 0.95, 0.84 }, hierba = { 1.0, 1.03, 0.95 } }

local function sueloCiudad(mapa, x, y, px, py, tipo)
  if not Iso.activo() then return false end
  local nombre = SUELO_CIUDAD[tipo]
  if not nombre and tipo == "muralla" and MapaFao.murosActivo() then nombre = "hierba" end    -- bajo los muros nuevos, hierba normal
  if not nombre then return false end
  if not (mapa.bioma[x] and mapa.bioma[x][y] == "ciudad") then return false end
  local t = texturaCiudad(nombre)
  if not t then return false end
  local cel = t.w / 8
  local q = t.quads[(x % 8) .. "," .. (y % 8)]
  if not q then
    q = love.graphics.newQuad((x % 8) * cel, (y % 8) * (t.h / 8), cel, t.h / 8, t.w, t.h)
    t.quads[(x % 8) .. "," .. (y % 8)] = q
  end
  local c = (lado(mapa, x, y) == "umbra" and nombre ~= "agua") and TINTE_UMBRA or { 1, 1, 1 }
  -- tonos unificados: calles de piedra cálida y clara, plaza algo más dorada, hierba sin manchas
  if (nombre == "calle" or nombre == "plaza") and lado(mapa, x, y) == "umbra" then c = { 0.92, 0.88, 1.0 } end   -- piedra fría, no violeta
  local k = TONO_CIUDAD[nombre]
  if k then c = { math.min(1.3, c[1] * k[1]), math.min(1.3, c[2] * k[2]), math.min(1.3, c[3] * k[3]) } end
  love.graphics.setColor(math.min(1, c[1]), math.min(1, c[2]), math.min(1, c[3]), 1)
  love.graphics.draw(t.img, q, px, py, 0, TILE / cel, TILE / (t.h / 8))
  if nombre == "calle" or nombre == "plaza" then
    -- bordillo: una franja oscura donde la piedra toca la hierba
    local function vecino(dx, dy)
      local n = SUELO_CIUDAD[suelo(mapa, x + dx, y + dy) or ""]
      return n ~= nil and n ~= "calle" and n ~= "plaza"
    end
    love.graphics.setColor(0.18, 0.14, 0.1, 0.55)
    if vecino(0, -1) then love.graphics.rectangle("fill", px, py, TILE, 2) end
    if vecino(0, 1) then love.graphics.rectangle("fill", px, py + TILE - 2, TILE, 2) end
    if vecino(-1, 0) then love.graphics.rectangle("fill", px, py, 2, TILE) end
    if vecino(1, 0) then love.graphics.rectangle("fill", px + TILE - 2, py, 2, TILE) end
  end
  return true
end

-- Suelo del mundo abierto con las texturas FAO (arte/ciudad/terreno/): hierba, arena, tierra, nieve, roca, pantano, camino, cicatriz y mar.
-- Cada textura cubre 8x8 casillas. Entre dos suelos distintos no hay corte seco: cada casilla funde en sus bordes la textura del vecino
-- (una franja que va de medio opaca en el borde a transparente hacia dentro; los dos lados lo hacen, así empalman sin salto).
local TEX_MUNDO = {
  hierba = "hierba", hierba_osc = "hierba", bosque = "hierba", adoquin = "hierba", arena = "arena", tierra = "tierra", cicatriz = "cicatriz",
  montana = "roca", camino = "camino", agua = "agua", nieve = "nieve", roca = "roca", pantano = "pantano", plaza = "plaza",
}
local DECORA_MUNDO = { hierba = "hierba", arena = "arena", tierra = "tierra", cicatriz = "tierra", montana = "tierra", nieve = "tierra", roca = "tierra", pantano = "tierra" }
local FUNDIDO, MALLA = 10, nil

local function colorMundo(mapa, x, y)
  local tipo = suelo(mapa, x, y)
  if tipo == "cicatriz" then return 1, 1, 1 end
  if tipo == "plaza" then
    -- las bases del campo de batalla: piedra clara para Alba y fría para Umbra
    if lado(mapa, x, y) == "umbra" then return 0.78, 0.72, 1.0 end
    return 1, 1, 1
  end
  local c = tinte(mapa, x, y, FAMILIA[tipo or ""])
  if c then return c[1], c[2], c[3] end
  return 1, 1, 1
end

local function celda(t, x, y) return (x % 8) / 8, (y % 8) / 8 end

local function fundirFao(mapa, x, y, px, py, nombre)
  for _, d in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
    local nx, ny = x + d[1], y + d[2]
    local tn = suelo(mapa, nx, ny)
    local nombreN = tn and TEX_MUNDO[tn]
    if nombreN and nombreN ~= nombre then
      local t = texturaCiudad(nombreN)
      if t then
        local r, g, b = colorMundo(mapa, nx, ny)
        local u0, v0 = celda(t, x, y)
        local function vert(vx, vy, a)
          return { px + vx, py + vy, u0 + vx / TILE / 8, v0 + vy / TILE / 8, r, g, b, a }
        end
        local e, i = 0.55, 0
        local v
        if d[2] == -1 then v = { vert(0, 0, e), vert(TILE, 0, e), vert(TILE, FUNDIDO, i), vert(0, FUNDIDO, i) }
        elseif d[2] == 1 then v = { vert(0, TILE, e), vert(TILE, TILE, e), vert(TILE, TILE - FUNDIDO, i), vert(0, TILE - FUNDIDO, i) }
        elseif d[1] == -1 then v = { vert(0, 0, e), vert(0, TILE, e), vert(FUNDIDO, TILE, i), vert(FUNDIDO, 0, i) }
        else v = { vert(TILE, 0, e), vert(TILE, TILE, e), vert(TILE - FUNDIDO, TILE, i), vert(TILE - FUNDIDO, 0, i) } end
        if not MALLA then MALLA = love.graphics.newMesh(4, "fan", "stream") end
        MALLA:setTexture(t.img)
        MALLA:setVertices(v)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(MALLA)
      end
    end
  end
end

local function sueloMundo(mapa, x, y, px, py, tipo)
  if not Iso.activo() or not MapaFao.activo() or not mapa.ciudades then return false end
  local nombre = TEX_MUNDO[tipo]
  if not nombre then return false end
  local t = texturaCiudad(nombre)
  if not t then return false end
  local cel = t.w / 8
  local clave = (x % 8) .. "," .. (y % 8)
  local q = t.quads[clave]
  if not q then
    q = love.graphics.newQuad((x % 8) * cel, (y % 8) * (t.h / 8), cel, t.h / 8, t.w, t.h)
    t.quads[clave] = q
  end
  local r, g, b = colorMundo(mapa, x, y)
  love.graphics.setColor(r, g, b, 1)
  love.graphics.draw(t.img, q, px, py, 0, TILE / cel, TILE / (t.h / 8))
  fundirFao(mapa, x, y, px, py, nombre)
  local fam = DECORA_MUNDO[tipo]
  if fam and not (mapa.bloque[x] and mapa.bloque[x][y] and tipo == "montana") then decorar(mapa, x, y, px, py, tipo, fam) end
  return true
end

-- Suelo de las mazmorras con texturas FAO: cada mazmorra tiene la suya (arte/ciudad/terreno/mz1..mz3.png); la roca maciza se pinta oscura
-- y sus bordes los dibujan los muros de render/mapa_fao.lua. Sobre el suelo se reparten restos (huesos, brasas, grietas) de cada una.
local DECOR_MZ = { mz1 = { "guijarros" }, mz2 = { "brasas", "mancha" }, mz3 = { "grietita", "guijarros" }, mz4 = { "brasas", "mancha" }, mz5 = { "grietita", "guijarros" } }
local function sueloMazmorra(mapa, x, y, px, py, tipo)
  if not mapa.mazmorra or not Iso.activo() or not MapaFao.activo() then return false end
  local nombre = (tipo == "muralla" and "vacio") or (tipo == "mazmorra" and mapa.mazmorra) or nil
  if not nombre then return false end
  local t = texturaCiudad(nombre)
  if not t then return false end
  local cel = t.w / 8
  local clave = (x % 8) .. "," .. (y % 8)
  local q = t.quads[clave]
  if not q then
    q = love.graphics.newQuad((x % 8) * cel, (y % 8) * (t.h / 8), cel, t.h / 8, t.w, t.h)
    t.quads[clave] = q
  end
  if tipo == "muralla" then love.graphics.setColor(0.35, 0.35, 0.4, 1) else love.graphics.setColor(1, 1, 1, 1) end
  love.graphics.draw(t.img, q, px, py, 0, TILE / cel, TILE / (t.h / 8))
  if tipo == "mazmorra" then
    local lista = DECOR_MZ[mapa.mazmorra]
    if lista and hash(x, y, 31) < 0.04 then
      MapaFao.dibujar(lista[1 + math.floor(hash(x, y, 32) * #lista)], math.floor(hash(x, y, 33) * 997), px + 16, py + 31, nil, nil, nil, true)
    end
  end
  return true
end

function T.dibujarSuelo(mapa, x, y, px, py, cuadroAgua)
  if mapa.mpc and MapaMpc.suelo(mapa, x, y, px, py) then return end
  local tipo = suelo(mapa, x, y)
  if not tipo then
    love.graphics.setColor(0.04, 0.05, 0.07, 1)
    love.graphics.rectangle("fill", px, py, TILE, TILE)
    return
  end
  if sueloCiudad(mapa, x, y, px, py, tipo) then return end
  if sueloMundo(mapa, x, y, px, py, tipo) then return end
  if sueloMazmorra(mapa, x, y, px, py, tipo) then return end
  local f = FAMILIA[tipo]
  if f == "edificio" and CasasIso.activo() then f = "hierba" end   -- casas isométricas: bajo la huella, hierba normal
  if f == "agua" then
    dibujarAgua(mapa, x, y, px, py, cuadroAgua)
  elseif f == "muralla" then
    dibujarMuralla(mapa, x, y, px, py)
  elseif f == "empedrado" or f == "madera" then
    dibujarInterior(mapa, x, y, px, py)
  elseif f == "mazmorra" then
    -- losas de piedra de la lámina interior, con el tinte de cada mazmorra y un veteado sutil
    local im = imagenes()
    local t = mapa.tinte or { 1, 1, 1 }
    love.graphics.setColor(t[1], t[2], t[3], 1)
    love.graphics.draw(im.ia5, Arte.quad(im.ia5, 5 * 32, 2 * 32, 32, 32), px, py)
    local r = hash(x, y, 5)
    if r < 0.30 then
      love.graphics.setColor(0, 0, 0.05, 0.10 + r * 0.35)
      love.graphics.rectangle("fill", px, py, TILE, TILE)
    elseif r > 0.93 then
      love.graphics.setColor(1, 1, 1, 0.07)
      love.graphics.rectangle("fill", px, py, TILE, TILE)
    end
    if hash(x, y, 6) < 0.04 then
      love.graphics.setColor(0, 0, 0, 0.25)
      love.graphics.rectangle("fill", px + 5, py + 9, 20, 1)
      love.graphics.rectangle("fill", px + 12, py + 10, 8, 1)
    end
  elseif PROC[f] then
    dibujarProcedural(mapa, x, y, px, py, f, tipo)
  elseif f == "edificio" then
    -- el edificio se pinta aparte; debajo va el patio
    dibujarBase(mapa, x, y, px, py)
    -- con las casas isométricas el suelo bajo la huella es hierba normal, para que se funda con el resto
    if CasasIso.activo() then fundirBordes(mapa, x, y, px, py, "hierba") end
  else
    local base = dibujarBase(mapa, x, y, px, py)
    if f == "hierba" or f == "tierra" or f == "arena" then fundirBordes(mapa, x, y, px, py, f) end
    if f == "pavimento" then dibujarPavimento(mapa, x, y, px, py, base) end
    if f ~= "pavimento" then
      decorar(mapa, x, y, px, py, tipo, NOMBRE_FAMILIA_BASE[base])
    end
  end
end

-- Edificios: tejado (autotile A3 por filas) y fachada con puerta y ventanas.
local TEJADO = { albor = { 0, 0 }, umbra = { 3, 0 } }
local PARED = { albor = { 4, 1 }, umbra = { 3, 1 } }

local function dibujarEdificio(e, ox, oy)
  local im = imagenes()
  local roja = TEJADO[e.faccion] or TEJADO.albor
  local pared = PARED[e.faccion] or PARED.albor
  if e.estilo == "establo" then roja, pared = { 3, 2 }, { 1, 3 } end  -- tejado de paja y tablones oscuros
  local filasTecho = e.techo or 2
  local puertaX, puertaY = e.puertaX - e.x, e.puertaY - e.y
  -- cada columna puede empezar más abajo (alas bajas de las casas en L y en T): su tejado va sobre su fachada
  local function cima(fx) return e.cima and e.cima[fx + 1] or 0 end
  local function solido(fx, fy)
    if fx < 0 or fy < 0 or fx >= e.w or fy >= e.h then return false end
    if e.vacio and e.vacio[fx .. "," .. fy] then return false end
    return true
  end
  local function esTecho(fx, fy)
    if e.techoSur then return (e.h - 1 - fy) < filasTecho end
    return fy - cima(fx) < filasTecho
  end
  for fy = 0, e.h - 1 do
    for fx = 0, e.w - 1 do
      if solido(fx, fy) then
        local px = (e.x + fx) * TILE - ox
        local py = (e.y + fy) * TILE - oy
        local techo = esTecho(fx, fy)
        local m = Auto.mascara(function(dx, dy)
          if dx ~= 0 and dy ~= 0 then return false end
          local nx, ny = fx + dx, fy + dy
          return solido(nx, ny) and esTecho(nx, ny) == techo
        end)
        love.graphics.setColor(1, 1, 1, 1)
        local k = techo and roja or pared
        Auto.muro(im.a3, k[1] * 64, k[2] * 64, m, px, py)
        if fy == e.h - 1 then
          love.graphics.setColor(0, 0, 0, 0.18)
          love.graphics.rectangle("fill", px, py + TILE, TILE, 4)
        end
      end
    end
  end
  Detalle.fachada(e, ox, oy, solido, esTecho, cima, filasTecho, puertaX, puertaY)
  -- ventanas en la primera fila de fachada de las columnas 1 y w-2 (si no son la puerta)
  love.graphics.setColor(1, 1, 1, 1)
  for _, fx in ipairs({ 1, e.w - 2 }) do
    local fy = cima(fx) + filasTecho
    if fx ~= puertaX and solido(fx, fy) and fy < e.h and not (fx == puertaX and fy == puertaY) then
      love.graphics.draw(im.b, Arte.quad(im.b, 32, 4 * 32, 32, 32), (e.x + fx) * TILE - ox, (e.y + fy) * TILE - oy)
    end
  end
  Detalle.ventanas(e, ox, oy, solido, cima, filasTecho, puertaX)
  Detalle.dibujarChimenea(e, ox, oy)
  if e.estilo == "establo" then
    -- puerta doble de granero (tres casillas de ancho y dos de alto) con aspas y un hueco oscuro entre las hojas
    local px, py = (e.x + puertaX) * TILE - ox, (e.y + puertaY) * TILE - oy
    local y0 = e.techoSur and py or (py - TILE)
    local x0, ancho, alto = px - TILE + 2, TILE * 3 - 4, TILE * 2 - 2
    love.graphics.setColor(0.13, 0.08, 0.04, 1)
    love.graphics.rectangle("fill", x0 - 2, y0 + 1, ancho + 4, alto + 1, 3, 3)
    for lado = 0, 1 do
      local hx = x0 + lado * (ancho / 2 + 1)
      local hw = ancho / 2 - 1
      love.graphics.setColor(0.56, 0.37, 0.19, 1)
      love.graphics.rectangle("fill", hx, y0 + 4, hw, alto - 4)
      love.graphics.setColor(0.4, 0.25, 0.12, 1)
      for k = 1, 3 do love.graphics.rectangle("fill", hx + k * hw / 4, y0 + 4, 1, alto - 4) end
      love.graphics.setLineWidth(3)
      love.graphics.setColor(0.27, 0.16, 0.08, 1)
      love.graphics.line(hx + 2, y0 + 6, hx + hw - 2, y0 + alto - 3)
      love.graphics.line(hx + hw - 2, y0 + 6, hx + 2, y0 + alto - 3)
      love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", hx + 0.5, y0 + 4.5, hw - 1, alto - 5)
    end
    love.graphics.setColor(0.3, 0.19, 0.09, 1)
    love.graphics.rectangle("fill", x0 - 3, y0, ancho + 6, 5, 2, 2)
    love.graphics.setColor(0.95, 0.8, 0.3, 1)
    love.graphics.circle("fill", x0 + ancho / 2 - 4, y0 + alto / 2 + 4, 1.8)
    love.graphics.circle("fill", x0 + ancho / 2 + 4, y0 + alto / 2 + 4, 1.8)
    return
  end
  -- la puerta: marco de piedra y hoja de madera sobre la pared de la fila de abajo
  local dx, dy = (e.x + puertaX) * TILE - ox, (e.y + puertaY) * TILE - oy
  local hierro = e.faccion == "umbra"
  love.graphics.setColor(0.2, 0.17, 0.15, 1)
  love.graphics.rectangle("fill", dx + 5, dy + 5, 22, TILE - 5, 8, 8)
  if hierro then love.graphics.setColor(0.3, 0.3, 0.36, 1) else love.graphics.setColor(0.5, 0.31, 0.15, 1) end
  love.graphics.rectangle("fill", dx + 7, dy + 8, 18, TILE - 8, 7, 7)
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.rectangle("fill", dx + 15, dy + 8, 2, TILE - 8)
  love.graphics.setColor(0.95, 0.8, 0.3, 1)
  love.graphics.circle("fill", dx + 21, dy + 21, 1.6)
  Detalle.puerta(e, dx, dy)
end

-- Bloques cacheados ----------------------------------------------------
local function clave(cx, cy, cuadro) return cx .. "," .. cy .. "," .. cuadro end

local function tieneAgua(mapa, cx, cy)
  if mapa.mpc then return false end      -- (el agua de los mapas de FAO es un tile más: sin variantes animadas)
  local clavec = cx .. "," .. cy
  mapa._aguaBloque = mapa._aguaBloque or {}
  local v = mapa._aguaBloque[clavec]
  if v ~= nil then return v end
  v = false
  for y = cy * BLOQUE, cy * BLOQUE + BLOQUE - 1 do
    for x = cx * BLOQUE, cx * BLOQUE + BLOQUE - 1 do
      if FAMILIA[suelo(mapa, x, y) or ""] == "agua" then v = true break end
    end
    if v then break end
  end
  mapa._aguaBloque[clavec] = v
  return v
end

local function construir(mapa, cx, cy, cuadro)
  -- una casilla de margen por cada lado: al proyectar en isométrico (filtro lineal) no quedan costuras entre bloques
  local canvas = love.graphics.newCanvas((BLOQUE + 2) * TILE * ESC_BLOQUE, (BLOQUE + 2) * TILE * ESC_BLOQUE)
  if Iso.activo() or mapa.mpc then canvas:setFilter("linear", "linear") else canvas:setFilter("nearest", "nearest") end
  local previo = { love.graphics.getCanvas() }
  love.graphics.push("all")
  -- sin el recorte de la vista del juego: si no, el bloque nuevo se hornea recortado y deja huecos negros en pantalla
  love.graphics.setScissor()
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.origin()
  love.graphics.scale(ESC_BLOQUE, ESC_BLOQUE)
  love.graphics.translate(TILE, TILE)
  Objetos.estatico = true       -- lo que se hornea en el lienzo no se mueve: dibujos normales (y más baratos)
  for ty = -1, BLOQUE do
    for tx = -1, BLOQUE do
      local x, y = cx * BLOQUE + tx, cy * BLOQUE + ty
      T.dibujarSuelo(mapa, x, y, tx * TILE, ty * TILE, cuadro)
    end
  end
  -- Casas antiguas (dibujadas por código): desactivadas mientras haya casas isométricas (render/casas_iso.lua).
  -- Para volver a verlas: DC_CASAS_ISO=0 o Ajustes.casasIso = false.
  if not CasasIso.activo() then
    for _, e in ipairs(mapa.edificios or {}) do
      if e.x + e.w > cx * BLOQUE - 1 and e.x < (cx + 1) * BLOQUE + 1 and e.y + e.h > cy * BLOQUE - 1 and e.y < (cy + 1) * BLOQUE + 1 then
        dibujarEdificio(e, cx * BLOQUE * TILE, cy * BLOQUE * TILE)
      end
    end
  end
  Objetos.estatico = false
  love.graphics.pop()
  love.graphics.setCanvas(previo[1])
  return canvas
end

local function bloque(mapa, cx, cy, cuadro)
  mapa._bloques = mapa._bloques or { mapa = {}, n = 0, orden = 0 }
  local c = mapa._bloques
  local k = clave(cx, cy, cuadro)
  local b = c.mapa[k]
  c.orden = c.orden + 1
  if not b then
    if c.n >= LIMITE_BLOQUES then
      local viejo, vk
      for kk, bb in pairs(c.mapa) do
        if not vk or bb.uso < viejo.uso then viejo, vk = bb, kk end
      end
      if vk then
        viejo.canvas:release()
        c.mapa[vk] = nil
        c.n = c.n - 1
      end
    end
    b = { canvas = construir(mapa, cx, cy, cuadro), uso = c.orden }
    c.mapa[k] = b
    c.n = c.n + 1
  end
  b.uso = c.orden
  return b.canvas
end

-- Bloques (índices de bloque: x0, y0, x1, y1) que cubren el encuadre; margen en bloques.
local function bloquesVisibles(mapa, camX, camY, vw, vh, margen)
  local x0, y0, x1, y1
  if Iso.activo() then
    x0, y0, x1, y1 = Iso.rango(camX, camY, vw, vh, 2)
  else
    x0, y0, x1, y1 = camX / TILE, camY / TILE, (camX + vw) / TILE, (camY + vh) / TILE
  end
  local maxX, maxY = math.floor((mapa.w - 1) / BLOQUE), math.floor((mapa.h - 1) / BLOQUE)
  -- los mapas de FAO (.mpc) siguen unos bloques más allá del borde (repiten la casilla del borde): así la vista no acaba en negro
  local fuera = mapa.mpc and 2 or 0
  return math.max(-fuera, math.floor(x0 / BLOQUE) - margen), math.max(-fuera, math.floor(y0 / BLOQUE) - margen),
    math.min(maxX + fuera, math.floor(x1 / BLOQUE) + margen), math.min(maxY + fuera, math.floor(y1 / BLOQUE) + margen)
end

-- Dibuja el suelo visible. (camX, camY) en píxeles de mundo (o de pantalla isométrica); la escala la
-- pone quien llama con love.graphics.scale.
function T.dibujar(mapa, camX, camY, vw, vh, tiempo, alfa)
  local cuadro = ({ 0, 1, 2, 1 })[(math.floor((tiempo or 0) * 3) % 4) + 1]
  local x0, y0, x1, y1 = bloquesVisibles(mapa, camX, camY, vw, vh, 0)
  love.graphics.setColor(1, 1, 1, alfa or 1)
  local iso = Iso.activo()
  local k, h = Iso.HW / TILE / ESC_BLOQUE, Iso.HH / TILE / ESC_BLOQUE
  for cy = y0, y1 do
    for cx = x0, x1 do
      local f = tieneAgua(mapa, cx, cy) and cuadro or 0
      local canvas = bloque(mapa, cx, cy, f)
      if iso then
        -- el bloque (una cuadrícula de casillas) se proyecta entero con una transformación afín: rombos en vez de cuadrados
        local bx, by = cx * BLOQUE, cy * BLOQUE
        local t = love.math.newTransform()
        t:setMatrix("row", k, -k, 0, (bx - by) * Iso.HW - camX, h, h, 0, (bx + by) * Iso.HH - 2 * Iso.HH - camY, 0, 0, 1, 0, 0, 0, 0, 1)
        love.graphics.push()
        love.graphics.applyTransform(t)
        love.graphics.draw(canvas, 0, 0)
        love.graphics.pop()
      else
        love.graphics.draw(canvas, cx * BLOQUE * TILE - camX - TILE, cy * BLOQUE * TILE - camY - TILE, 0, 1 / ESC_BLOQUE, 1 / ESC_BLOQUE)
      end
    end
  end
end

-- Hornea de antemano (como mucho UN bloque por cuadro) los bloques que van a hacer falta: el anillo de bloques alrededor de lo
-- visible y las otras variantes de la animación del agua. Así el tirón de construir un bloque no cae en mitad de un paso.
function T.precargar(mapa, camX, camY, vw, vh)
  local x0, y0, x1, y1 = bloquesVisibles(mapa, camX, camY, vw, vh, 1)
  mapa._bloques = mapa._bloques or { mapa = {}, n = 0, orden = 0 }
  local c = mapa._bloques
  if c.n >= LIMITE_BLOQUES - 12 then return end
  for cy = y0, y1 do
    for cx = x0, x1 do
      for _, f in ipairs(tieneAgua(mapa, cx, cy) and { 0, 1, 2 } or { 0 }) do
        if not c.mapa[clave(cx, cy, f)] then
          bloque(mapa, cx, cy, f)
          return
        end
      end
    end
  end
end

-- Bloques que faltan por construir alrededor del bloque (bx, by) en un radio dado, con sus variantes de agua. soloBase: solo la
-- variante 0 (lo imprescindible para ver el suelo).
function T.faltantes(mapa, bx, by, radio, soloBase)
  mapa._bloques = mapa._bloques or { mapa = {}, n = 0, orden = 0 }
  local c = mapa._bloques
  local maxX, maxY = math.floor((mapa.w - 1) / BLOQUE), math.floor((mapa.h - 1) / BLOQUE)
  local lista = {}
  for cy = math.max(0, by - radio), math.min(maxY, by + radio) do
    for cx = math.max(0, bx - radio), math.min(maxX, bx + radio) do
      for _, f in ipairs((not soloBase and tieneAgua(mapa, cx, cy)) and { 0, 1, 2 } or { 0 }) do
        if not c.mapa[clave(cx, cy, f)] then lista[#lista + 1] = { cx, cy, f } end
      end
    end
  end
  return lista
end

function T.construirYa(mapa, cx, cy, f) bloque(mapa, cx, cy, f) end
T.BLOQUE_PX = BLOQUE * TILE

function T.olvidar(mapa)
  if mapa._bloques then
    for _, b in pairs(mapa._bloques.mapa) do b.canvas:release() end
  end
  mapa._bloques = nil
  mapa._aguaBloque = nil
end

return T
