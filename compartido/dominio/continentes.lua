-- Generador de continentes del mundo: varias masas de tierra separadas por mar, con costas
-- orgánicas (ruido fractal), playas, zonas altas, bosques y manchas de terreno que rompen la
-- llanura. No depende de la semilla del juego: el mapa es siempre el mismo y se calcula una vez por
-- proceso (ver Mapa.mundo).
--   Continente 1 (Alba, oeste) y 2 (Umbra, este): las diez ciudades.
--   Continente 3 (Isla de la Cicatriz, centro): la zona de guerra, sin ciudades, la más peligrosa.
--   Islotes (4 en adelante): solo decoración, sin criaturas ni nada que hacer.
-- Entre continentes se viaja en barco (Barquero de los puertos).
local Datos = require("compartido.dominio.datos")

local C = {}

-- Masas de tierra, en fracciones del mapa. Un continente puede tener varios lóbulos (mismo id): así
-- sus costas no son una elipse sino penínsulas, golfos y bultos.
C.NOMBRES = {
  [1] = { nombre = "Continente del Alba", habitado = true },
  [2] = { nombre = "Continente de Umbra", habitado = true },
  [3] = { nombre = "Isla de la Cicatriz", habitado = true },
  [4] = { nombre = "Islote del norte" }, [5] = { nombre = "Islote del sur" },
  [6] = { nombre = "Islote del este" }, [7] = { nombre = "Islote del oeste" },
}
C.DEF = {
  -- Alba (oeste)
  { id = 1, cx = 0.180, cy = 0.50, rx = 0.120, ry = 0.330 },
  { id = 1, cx = 0.205, cy = 0.20, rx = 0.095, ry = 0.150 },
  { id = 1, cx = 0.150, cy = 0.80, rx = 0.100, ry = 0.130 },
  { id = 1, cx = 0.265, cy = 0.40, rx = 0.060, ry = 0.130 },
  { id = 1, cx = 0.255, cy = 0.74, rx = 0.070, ry = 0.100 },
  -- Umbra (este)
  { id = 2, cx = 0.820, cy = 0.50, rx = 0.120, ry = 0.330 },
  { id = 2, cx = 0.800, cy = 0.19, rx = 0.100, ry = 0.140 },
  { id = 2, cx = 0.860, cy = 0.80, rx = 0.095, ry = 0.130 },
  { id = 2, cx = 0.735, cy = 0.36, rx = 0.060, ry = 0.130 },
  { id = 2, cx = 0.745, cy = 0.72, rx = 0.070, ry = 0.100 },
  -- Isla de la Cicatriz (centro)
  { id = 3, cx = 0.50, cy = 0.50, rx = 0.060, ry = 0.220 },
  { id = 3, cx = 0.50, cy = 0.33, rx = 0.075, ry = 0.100 },
  { id = 3, cx = 0.50, cy = 0.68, rx = 0.070, ry = 0.090 },
  -- islotes
  { id = 4, cx = 0.42, cy = 0.075, rx = 0.02, ry = 0.035 },
  { id = 5, cx = 0.58, cy = 0.925, rx = 0.02, ry = 0.035 },
  { id = 6, cx = 0.585, cy = 0.13, rx = 0.016, ry = 0.03 },
  { id = 7, cx = 0.415, cy = 0.87, rx = 0.016, ry = 0.03 },
}
C.AMPLITUD = 1.0     -- cuánto deforma el ruido la costa

-- ----------------------------------------------------------------------------------------- ruido
local function azar(x, y, sal)
  local n = (x * 73856093 + y * 19349663 + (sal or 0) * 83492791) % 2147483647
  n = (n * 1103515245 + 12345) % 2147483647
  return (n % 10007) / 10007
end

local function suave(t) return t * t * (3 - 2 * t) end

local function ruidoV(x, y, sal)
  local ix, iy = math.floor(x), math.floor(y)
  local fx, fy = suave(x - ix), suave(y - iy)
  local a, b = azar(ix, iy, sal), azar(ix + 1, iy, sal)
  local c, d = azar(ix, iy + 1, sal), azar(ix + 1, iy + 1, sal)
  local top = a + (b - a) * fx
  return top + ((c + (d - c) * fx) - top) * fy
end

-- Ruido fractal 0..1: varias capas de ruido a distinta escala.
local function fbm(x, y, sal, octavas)
  local v, amp, f, total = 0, 1, 1, 0
  for o = 1, octavas do
    v = v + amp * ruidoV(x * f, y * f, sal + o * 7)
    total = total + amp
    amp = amp * 0.5
    f = f * 2
  end
  return v / total
end
C.fbm = fbm

-- Los campos de ruido se calculan en una malla de PASO casillas y se interpolan: son suaves.
local PASO = 4
local campos = {}
local function malla(nombre, f)
  local g = campos[nombre]
  if g then return g end
  local gw, gh = math.ceil(Datos.MAPA_W / PASO) + 2, math.ceil(Datos.MAPA_H / PASO) + 2
  g = {}
  for i = 0, gw - 1 do
    local col = {}
    for j = 0, gh - 1 do col[j] = f(i * PASO, j * PASO) end
    g[i] = col
  end
  campos[nombre] = g
  return g
end

local function leer(g, x, y)
  local fx, fy = x / PASO, y / PASO
  local i, j = math.floor(fx), math.floor(fy)
  local tx, ty = fx - i, fy - j
  local a, b = g[i][j], g[i + 1][j]
  local c, d = g[i][j + 1], g[i + 1][j + 1]
  local top = a + (b - a) * tx
  return top + ((c + (d - c) * tx) - top) * ty
end

-- Altura base de la tierra: 1 en el centro de un continente y 0 en su orilla (sin ruido).
local function baseTierra(x, y)
  local W, H = Datos.MAPA_W, Datos.MAPA_H
  local u, v = x / W, y / H
  local mejor, id = -9, 0
  for _, c in ipairs(C.DEF) do
    local dx, dy = (u - c.cx) / c.rx, (v - c.cy) / c.ry
    local b = 1 - math.sqrt(dx * dx + dy * dy)
    if b > mejor then mejor, id = b, c.id end
  end
  return mejor, id
end

local function campoTierra()
  return malla("tierra", function(x, y)
    -- la base se mide sobre coordenadas deformadas (golfos y penínsulas) y se suma ruido fractal
    local wx = x + 95 * (fbm(x / 150, y / 150, 71, 3) - 0.5)
    local wy = y + 95 * (fbm(x / 150, y / 150, 72, 3) - 0.5)
    local b = baseTierra(wx, wy)
    return b + C.AMPLITUD * (fbm(x / 70, y / 70, 11, 5) - 0.5) + 0.35 * (fbm(x / 260, y / 260, 12, 2) - 0.5)
  end)
end

local function campoCont()
  return malla("cont", function(x, y)
    local _, id = baseTierra(x, y)
    return id
  end)
end

-- Altura de tierra en una casilla (>0 es tierra). Sirve para colocar las ciudades.
function C.altura(x, y)
  return leer(campoTierra(), x, y)
end

-- Punto central de un continente (para poner su nombre en el mapa).
function C.centro(id)
  for _, c in ipairs(C.DEF) do
    if c.id == id then return { x = c.cx * Datos.MAPA_W, y = c.cy * Datos.MAPA_H } end
  end
end

-- Continente al que pertenece una casilla (el de la masa más cercana).
function C.continenteDe(x, y)
  local g = campoCont()
  return g[math.floor(x / PASO + 0.5)][math.floor(y / PASO + 0.5)]
end

local function campo(nombre, escala, sal, octavas)
  return malla(nombre, function(x, y) return fbm(x / escala, y / escala, sal, octavas) end)
end

-- ------------------------------------------------------------------------------ generación
-- Rellena suelo, bioma, lado, continente y bloqueo de todas las casillas. ciudades: lista con
-- (x, y, w, h, faccion, bioma) para repartir los biomas por cercanía.
function C.generar(mapa, ciudades, setSuelo, setBloque)
  local W, H = mapa.w, mapa.h
  local E = Datos.ESCALA
  local gT = campoTierra()
  local gWX, gWY = campo("wx", 120, 21, 3), campo("wy", 120, 22, 3)
  local gBosque = campo("bosque", 48, 31, 3)
  local gTierra = campo("tierra2", 40, 41, 3)
  local gAlto = campo("alto", 150, 51, 4)
  local gPlaya = campo("playa", 30, 61, 2)

  -- 1) máscara de tierra y continente de cada casilla
  local MARGEN = 9
  local tierra, cont = {}, {}
  mapa.cont = {}
  for x = 0, W - 1 do
    local col, cc = {}, {}
    for y = 0, H - 1 do
      local t = x >= MARGEN and y >= MARGEN and x < W - MARGEN and y < H - MARGEN and leer(gT, x, y) > 0
      col[y] = t
      cc[y] = t and C.continenteDe(x, y) or 0
    end
    tierra[x], cont[x] = col, cc
    mapa.cont[x] = cc
  end

  -- 2) distancia al agua (para las playas y para que los lagos no toquen la costa)
  local dist = {}
  local INF = 9999
  for x = 0, W - 1 do
    local col = {}
    for y = 0, H - 1 do col[y] = tierra[x][y] and INF or 0 end
    dist[x] = col
  end
  for x = 1, W - 2 do
    for y = 1, H - 2 do
      local d = dist[x][y]
      if d > 0 then
        local m = math.min(dist[x - 1][y] + 1, dist[x][y - 1] + 1, dist[x - 1][y - 1] + 1.4, dist[x + 1][y - 1] + 1.4)
        if m < d then dist[x][y] = m end
      end
    end
  end
  for x = W - 2, 1, -1 do
    for y = H - 2, 1, -1 do
      local d = dist[x][y]
      if d > 0 then
        local m = math.min(dist[x + 1][y] + 1, dist[x][y + 1] + 1, dist[x + 1][y + 1] + 1.4, dist[x - 1][y + 1] + 1.4)
        if m < d then dist[x][y] = m end
      end
    end
  end
  mapa.distAgua = dist

  -- ciudades por continente
  local porCont = {}
  for _, c in ipairs(ciudades) do
    local ancho, alto = c.capital and 72 or 48, c.capital and 56 or 36
    c.cx, c.cy = c.x + ancho / 2, c.y + alto / 2
    c.cont = C.continenteDe(c.cx, c.cy)
    porCont[c.cont] = porCont[c.cont] or {}
    table.insert(porCont[c.cont], c)
  end
  mapa.continentes = {}
  for id, d in pairs(C.NOMBRES) do
    mapa.continentes[id] = { id = id, nombre = d.nombre, habitado = d.habitado, ciudades = {} }
  end
  for _, c in ipairs(ciudades) do
    local k = mapa.continentes[c.cont]
    if k then k.ciudades[#k.ciudades + 1] = c.id end
  end

  -- 3) suelo y bioma de cada casilla
  local RADIO2 = (110 * E) ^ 2
  for x = 0, W - 1 do
    local dcol = dist[x]
    for y = 0, H - 1 do
      if not tierra[x][y] then
        setSuelo(mapa, x, y, "agua", "agua", nil)
        setBloque(mapa, x, y, true)
      else
        local id = cont[x][y]
        local d = dcol[y]
        local lado = id == 1 and "albor" or (id == 2 and "umbra" or nil)
        local playa = 1.5 + 3.5 * leer(gPlaya, x, y)
        if d <= playa then
          setSuelo(mapa, x, y, "arena", "costa", lado)
        elseif id == 3 then
          -- isla de la Cicatriz: tierra quemada con zonas de roca
          if leer(gAlto, x, y) > 0.60 then setSuelo(mapa, x, y, "roca", "cicatriz", nil)
          else setSuelo(mapa, x, y, "cicatriz", "cicatriz", nil) end
        elseif id >= 4 then
          setSuelo(mapa, x, y, "hierba", "islote", nil)
        else
          -- ciudad más cercana del mismo continente (con la distancia deformada: fronteras irregulares)
          local wx = x + (leer(gWX, x, y) - 0.5) * 150
          local wy = y + (leer(gWY, x, y) - 0.5) * 150
          local mejor, md
          for _, c in ipairs(porCont[id] or {}) do
            local dx, dy = wx - c.cx, wy - c.cy
            local d2 = dx * dx + dy * dy
            if not md or d2 < md then mejor, md = c, d2 end
          end
          local suelo, bioma = id == 1 and "hierba" or "hierba_osc", lado
          if mejor and Datos.biomas[mejor.bioma] then
            suelo, bioma = Datos.biomas[mejor.bioma].suelo, mejor.bioma
            if suelo == "arena" and md > 70 * 70 then suelo, bioma = id == 1 and "hierba" or "hierba_osc", lado end
          end
          -- distancia real a la ciudad más cercana: cerca de una ciudad las zonas altas y los
          -- bosques se desvanecen poco a poco (umbral que sube), sin dejar claros redondos
          local dc = 9999
          for _, c in ipairs(porCont[id] or {}) do
            local dx, dy = x - c.cx, y - c.cy
            local d2 = dx * dx + dy * dy
            if d2 < dc then dc = d2 end
          end
          dc = math.sqrt(dc)
          local cerca = math.max(0, 1 - dc / 95)
          local alto = leer(gAlto, x, y) - cerca * 0.5
          if alto > 0.62 then
            if y / H < 0.33 or alto > 0.76 then suelo, bioma = "nieve", "ventisca"
            else suelo, bioma = "roca", "altiplano" end
          elseif leer(gBosque, x, y) - cerca * 0.35 > 0.58 and (suelo == "hierba" or suelo == "hierba_osc" or suelo == "tierra") then
            suelo, bioma = "bosque", "bosque"
          elseif leer(gTierra, x, y) > 0.66 and (suelo == "hierba" or suelo == "hierba_osc") then
            suelo = "tierra"
          end
          setSuelo(mapa, x, y, suelo, bioma, lado)
        end
      end
    end
  end
end

return C
