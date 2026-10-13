local Datos = require("compartido.dominio.datos")
local Util = require("compartido.dominio.util")
local Continentes = require("compartido.dominio.continentes")

local M = {}

-- Número repetible en [0, 1) para una casilla: reparte árboles sin cuadrícula.
local function azar(x, y, sal)
  local n = (x * 73856093 + y * 19349663 + (sal or 0) * 83492791) % 2147483647
  n = (n * 1103515245 + 12345) % 2147483647
  return (n % 10007) / 10007
end

local function ruido(x, y)
  local n = math.sin(x * 0.17 + y * 0.13) * 0.5 + math.sin(x * 0.05 - y * 0.08) * 0.5
  return n * 0.07
end

function M.nuevo(w, h)
  return {
    w = w, h = h,
    suelo = {}, bloque = {}, bioma = {}, lado = {},
    props = {}, ciudades = {}, campamentos = {}, edificios = {},
    portal = { x = 68.5, y = 46.5 },
  }
end

function M.get(mapa, x, y)
  if x < 0 or y < 0 or x >= mapa.w or y >= mapa.h then return nil end
  return mapa.suelo[x] and mapa.suelo[x][y]
end

function M.bloqueado(mapa, x, y, faccion)
  local tx, ty = math.floor(x), math.floor(y)
  if tx < 0 or ty < 0 or tx >= mapa.w or ty >= mapa.h then return true end
  if not (mapa.bloque[tx] and mapa.bloque[tx][ty]) then return false end
  local p = mapa.puerta and mapa.puerta[tx .. "_" .. ty]
  if p and p.viva and p.faccion == faccion then return false end
  return true
end

local function setSuelo(mapa, x, y, tipo, bioma, lado)
  mapa.suelo[x] = mapa.suelo[x] or {}
  mapa.bioma[x] = mapa.bioma[x] or {}
  mapa.lado[x] = mapa.lado[x] or {}
  mapa.suelo[x][y] = tipo
  if bioma then mapa.bioma[x][y] = bioma end
  if lado then mapa.lado[x][y] = lado end
end

local function setBloque(mapa, x, y, v)
  mapa.bloque[x] = mapa.bloque[x] or {}
  mapa.bloque[x][y] = v and true or nil
end

function M.transitable(mapa, x, y)
  if x < 1 or y < 1 or x >= mapa.w - 1 or y >= mapa.h - 1 then return false end
  if mapa.bloque[x] and mapa.bloque[x][y] then return false end
  local s = mapa.suelo[x] and mapa.suelo[x][y]
  if s == "agua" then return false end
  return s ~= nil
end

function M.buscar(mapa, x0, y0, x1, y1)
  x0, y0 = math.floor(x0), math.floor(y0)
  x1, y1 = math.floor(x1), math.floor(y1)
  if not M.transitable(mapa, x1, y1) then
    local hallado = false
    for r = 1, 4 do
      for dy = -r, r do
        for dx = -r, r do
          if M.transitable(mapa, x1 + dx, y1 + dy) then
            x1, y1 = x1 + dx, y1 + dy
            hallado = true
            break
          end
        end
        if hallado then break end
      end
      if hallado then break end
    end
  end
  local function clave(x, y) return x .. "_" .. y end
  local heap, abierto, cerrado, desde, gscore = {}, {}, {}, {}, {}
  local function push(n)
    heap[#heap + 1] = n
    local i = #heap
    while i > 1 do
      local p = math.floor(i / 2)
      if heap[p].f <= heap[i].f then break end
      heap[p], heap[i] = heap[i], heap[p]
      i = p
    end
  end
  local function pop()
    local top = heap[1]
    local last = heap[#heap]
    heap[#heap] = nil
    if not last or not top then return top end
    if #heap == 0 then return top end
    heap[1] = last
    local i = 1
    while true do
      local l, r = i * 2, i * 2 + 1
      local s = i
      if l <= #heap and heap[l].f < heap[s].f then s = l end
      if r <= #heap and heap[r].f < heap[s].f then s = r end
      if s == i then break end
      heap[s], heap[i] = heap[i], heap[s]
      i = s
    end
    return top
  end
  local inicio = clave(x0, y0)
  gscore[inicio] = 0
  push({ x = x0, y = y0, f = math.abs(x1 - x0) + math.abs(y1 - y0) })
  abierto[inicio] = true
  local dirs = {
    { 1, 0, 1 }, { -1, 0, 1 }, { 0, 1, 1 }, { 0, -1, 1 },
    { 1, 1, 1.4 }, { 1, -1, 1.4 }, { -1, 1, 1.4 }, { -1, -1, 1.4 },
  }
  local pasos = 0
  local meta = nil
  while #heap > 0 and pasos < 80000 do
    pasos = pasos + 1
    local n = pop()
    local ck = clave(n.x, n.y)
    if not cerrado[ck] then
      cerrado[ck] = true
      if n.x == x1 and n.y == y1 then meta = n break end
      for _, d in ipairs(dirs) do
        local nx, ny = n.x + d[1], n.y + d[2]
        if M.transitable(mapa, nx, ny) then
          if d[3] > 1 then
            if not M.transitable(mapa, n.x + d[1], n.y) or not M.transitable(mapa, n.x, n.y + d[2]) then
              goto seguir
            end
          end
          local nk = clave(nx, ny)
          local g = (gscore[ck] or 0) + d[3]
          if not gscore[nk] or g < gscore[nk] then
            gscore[nk] = g
            desde[nk] = { x = n.x, y = n.y }
            push({ x = nx, y = ny, f = g + math.abs(x1 - nx) + math.abs(y1 - ny) })
          end
          ::seguir::
        end
      end
    end
  end
  if not meta then return nil end
  local camino = {}
  local cx, cy = x1, y1
  local guard = 0
  while (cx ~= x0 or cy ~= y0) and guard < 16000 do
    guard = guard + 1
    table.insert(camino, 1, { x = cx + 0.5, y = cy + 0.5 })
    local p = desde[clave(cx, cy)]
    if not p then break end
    if p.x == cx and p.y == cy then break end
    cx, cy = p.x, p.y
  end
  if cx ~= x0 or cy ~= y0 then return nil end
  return camino
end

local function dentroCiudad(ciudades, x, y)
  for _, c in ipairs(ciudades) do
    if x >= c.x and x < c.x + c.w and y >= c.y and y < c.y + c.h then return c end
  end
end

local function estamparCiudad(mapa, ciudad)
  local grande = ciudad.capital and true or false
  local w = grande and 72 or 48
  local h = grande and 56 or 36
  local x0, y0 = ciudad.x, ciudad.y
  ciudad.w, ciudad.h = w, h
  ciudad.npcs = {}
  ciudad.parcelas = {}
  local techo = ciudad.faccion == "umbra" and "teja_umbra" or "teja"
  local puertaTipo = ciudad.faccion == "umbra" and "puerta_hierro" or "puerta"
  local medio = math.floor(w / 2)
  local medioY = math.floor(h / 2)
  local prx = grande and 8 or 5
  local pry = grande and 6 or 4
  local function avenida(x, y)
    return math.abs(x - medio) <= 2 or math.abs(y - medioY) <= 2
  end
  local function enPlaza(x, y)
    return math.abs(x - medio) <= prx and math.abs(y - medioY) <= pry
  end
  local function esAcceso(x, y)
    if math.abs(x - medio) > 1 then return false end
    if grande then return y == 0 or y == h - 1 end
    if ciudad.acceso == "norte" then return y == 0 end
    return y == h - 1
  end
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local tx, ty = x0 + x, y0 + y
      local borde = x == 0 or y == 0 or x == w - 1 or y == h - 1
      if borde and not esAcceso(x, y) then
        setSuelo(mapa, tx, ty, "muralla", "ciudad", ciudad.faccion)
        setBloque(mapa, tx, ty, true)
      elseif enPlaza(x, y) then
        setSuelo(mapa, tx, ty, "plaza", "ciudad", ciudad.faccion)
        setBloque(mapa, tx, ty, false)
      elseif avenida(x, y) then
        setSuelo(mapa, tx, ty, "calle", "ciudad", ciudad.faccion)
        setBloque(mapa, tx, ty, false)
      else
        setSuelo(mapa, tx, ty, "adoquin", "ciudad", ciudad.faccion)
        setBloque(mapa, tx, ty, false)
      end
    end
  end
  setBloque(mapa, x0 + medio, y0 + medioY, true)
  mapa.props[#mapa.props + 1] = {
    x = x0 + medio, y = y0 + medioY,
    tipo = ciudad.faccion == "umbra" and "estatua_umbra" or "estatua_albor",
  }
  -- farolas en las cuatro esquinas de la plaza y pozos a los lados
  for _, sx in ipairs({ -1, 1 }) do
    for _, sy in ipairs({ -1, 1 }) do
      local fx, fy = x0 + medio + sx * prx, y0 + medioY + sy * pry
      setBloque(mapa, fx, fy, true)
      mapa.props[#mapa.props + 1] = { x = fx, y = fy, tipo = "farol" }
    end
    local px = x0 + medio + sx * (prx - 2)
    setBloque(mapa, px, y0 + medioY - pry + 1, true)
    mapa.props[#mapa.props + 1] = { x = px, y = y0 + medioY - pry + 1, tipo = (sx < 0) and "pozo" or "barril" }
  end
  -- banderas colgadas del muro norte
  for bx = 6, w - 7, 7 do
    if math.abs(bx - medio) > 3 then
      mapa.props[#mapa.props + 1] = {
        x = x0 + bx, y = y0 + 1,
        tipo = ciudad.faccion == "umbra" and "bandera_umbra" or "bandera_albor", cuelga = true,
      }
    end
  end
  ciudad.accesos = {}
  local function abrir(y)
    ciudad.accesos[#ciudad.accesos + 1] = { x = x0 + medio, y = y0 + y }
    for _, sx in ipairs({ -2, 2 }) do
      mapa.props[#mapa.props + 1] = { x = x0 + medio + sx, y = y0 + y, tipo = ciudad.faccion == "umbra" and "columna_umbra" or "columna_albor" }
    end
  end
  if grande or ciudad.acceso ~= "norte" then abrir(h - 1) end
  if grande or ciudad.acceso == "norte" then abrir(0) end
  ciudad.puerta = ciudad.accesos[1]
  if ciudad.acceso == "norte" and not grande then
    ciudad.spawn = { x = x0 + medio + 0.5, y = y0 + 1.5 }
  else
    ciudad.spawn = { x = x0 + medio + 0.5, y = y0 + h - 2.5 }
  end
  local bw, bh = 6, 4
  local puertas = {}
  local function cabe(ex, ey)
    for yy = 0, bh - 1 do
      for xx = 0, bw - 1 do
        local lx, ly = ex + xx, ey + yy
        if lx <= 0 or ly <= 0 or lx >= w - 1 or ly >= h - 1 then return false end
        if avenida(lx, ly) or enPlaza(lx, ly) then return false end
      end
    end
    return true
  end
  for ey = 2, h - 2 - bh, 6 do
    for ex = 2, w - 2 - bw, 8 do
      if cabe(ex, ey) then
        local dx = ex + math.floor((bw - 1) / 2)
        local dy = ey + bh - 1
        for yy = 0, bh - 1 do
          for xx = 0, bw - 1 do
            local lx, ly = ex + xx, ey + yy
            local tx, ty = x0 + lx, y0 + ly
            if lx == dx and ly == dy then
              setBloque(mapa, tx, ty, false)
              setSuelo(mapa, tx, ty, "adoquin", "ciudad", ciudad.faccion)
            else
              setBloque(mapa, tx, ty, true)
              setSuelo(mapa, tx, ty, yy < 2 and techo or "fachada", "ciudad", ciudad.faccion)
            end
          end
        end
        mapa.edificios[#mapa.edificios + 1] = {
          x = x0 + ex, y = y0 + ey, w = bw, h = bh,
          faccion = ciudad.faccion, puertaX = x0 + dx, puertaY = y0 + dy,
        }
        puertas[#puertas + 1] = { x = x0 + dx, y = y0 + dy }
      end
    end
  end
  table.sort(puertas, function(a, b)
    if a.x == b.x then return a.y < b.y end
    return a.x < b.x
  end)
  local usada = {}
  local function tomar(idx)
    if not puertas[idx] or usada[idx] then return end
    usada[idx] = true
    local n = #ciudad.parcelas + 1
    local p = puertas[idx]
    ciudad.parcelas[n] = { id = ciudad.id .. "_" .. n, x = p.x, y = p.y, dueno = nil }
  end
  if #puertas > 0 then
    tomar(1)
    tomar(math.ceil(#puertas / 2))
    tomar(#puertas)
    for i = 1, #puertas do
      if #ciudad.parcelas >= 3 then break end
      tomar(i)
    end
  end
  local function npc(nx, ny, rol, nombre)
    ciudad.npcs[#ciudad.npcs + 1] = {
      x = x0 + nx + 0.5, y = y0 + ny + 0.5,
      rol = rol, nombre = nombre, faccion = ciudad.faccion,
    }
  end
  -- Los PNJ se reparten por las avenidas de la ciudad, no en el centro de la plaza.
  local k = grande and 1.5 or 1
  local function en(dx, dy) return medio + math.floor(dx * k), medioY + math.floor(dy * k) end
  local function npcEn(dx, dy, rol, nombre)
    local nx, ny = en(dx, dy)
    npc(nx, ny, rol, nombre)
  end
  npcEn(-11, 0, "mercado", "Mercader de " .. ciudad.nombre)
  npcEn(11, 0, "heraldo", "Heraldo")
  npcEn(-7, 0, "comercio", "Mercader mayor")
  npcEn(7, 0, "establo", "Mozo de cuadra")
  npcEn(-2, -9, "mayordomo", "Mayordomo")
  npcEn(2, -9, "encargos", "Tablón de encargos")
  npcEn(-2, 9, "encantador", "Maestro de encantos")
  npcEn(2, 9, "criador", "Criador de mascotas")
  npcEn(-17, 0, "gremio", "Escribano del gremio")
  npcEn(17, 0, "oficios", "Maestro de oficios")
  npcEn(-14, 2, "subastas", "Subastador")
  if ciudad.puerto then npcEn(0, -6, "barquero", "Barquero de " .. ciudad.nombre) end
  local gy = (ciudad.acceso == "norte" and not grande) and 2 or (h - 3)
  npc(medio - 2, gy, "guardia", "Guardia de " .. ciudad.nombre)
  npc(medio + 2, gy, "guardia", "Guardia de " .. ciudad.nombre)
end

-- Copia profunda de una estructura con referencias compartidas.
local function copiaProfunda(v, vistos)
  if type(v) ~= "table" then return v end
  vistos = vistos or {}
  if vistos[v] then return vistos[v] end
  local n = {}
  vistos[v] = n
  for k, x in pairs(v) do
    if type(x) == "table" then n[k] = copiaProfunda(x, vistos) else n[k] = x end
  end
  return n
end

-- Mundo abierto: varios continentes separados por mar (ver continentes.lua), con costas orgánicas,
-- biomas irregulares, caminos curvos entre las ciudades de cada continente, lagos y cordilleras.
local function generarMundo(rng)
  local mapa = M.nuevo(Datos.MAPA_W, Datos.MAPA_H)
  local cx, cy = mapa.w / 2, mapa.h / 2
  local E = Datos.ESCALA
  -- 1) terreno: continentes, playas, biomas, zonas altas, bosques y manchas de tierra
  local ciudadesBase = {}
  for _, c in ipairs(Datos.ciudades) do
    local copia = {}
    for k, v in pairs(c) do copia[k] = v end
    ciudadesBase[#ciudadesBase + 1] = copia
  end
  Continentes.generar(mapa, ciudadesBase, setSuelo, setBloque)
  -- 2) las ciudades se estampan sobre el terreno
  for _, c in ipairs(ciudadesBase) do
    estamparCiudad(mapa, c)
    mapa.ciudades[#mapa.ciudades + 1] = c
  end
  local function despejar(c, radio)
    local def = Datos.biomas[c.bioma]
    local suelo = def and def.suelo or (c.faccion == "umbra" and "hierba_osc" or "hierba")
    local bio = c.bioma or c.faccion
    for y = c.y - radio, c.y + c.h - 1 + radio do
      for x = c.x - radio, c.x + c.w - 1 + radio do
        local dentro = x >= c.x and x < c.x + c.w and y >= c.y and y < c.y + c.h
        if not dentro and x > 0 and y > 0 and x < mapa.w - 1 and y < mapa.h - 1 then
          local actual = mapa.bioma[x] and mapa.bioma[x][y]
          local s = mapa.suelo[x] and mapa.suelo[x][y]
          if s and actual ~= "agua" and actual ~= "cicatriz" and actual ~= "ciudad" and actual ~= "costa" then
            setSuelo(mapa, x, y, suelo, bio, c.faccion)
            setBloque(mapa, x, y, false)
          end
        end
      end
    end
  end
  for _, c in ipairs(mapa.ciudades) do despejar(c, 5) end
  -- 3) caminos
  local function pintar(x, y)
    for dy = -1, 1 do
      for dx = -1, 1 do
        local tx, ty = x + dx, y + dy
        if tx > 0 and ty > 0 and tx < mapa.w - 1 and ty < mapa.h - 1 then
          local bio = mapa.bioma[tx] and mapa.bioma[tx][ty]
          local s = mapa.suelo[tx] and mapa.suelo[tx][ty]
          local lado = mapa.lado[tx] and mapa.lado[tx][ty]
          if s and bio ~= "ciudad" and s ~= "agua" then
            setSuelo(mapa, tx, ty, "camino", bio, lado)
            setBloque(mapa, tx, ty, false)
          end
        end
      end
    end
  end
  local function linea(x0, y0, x1, y1)
    local dx, dy = x1 - x0, y1 - y0
    local pasos = math.max(math.abs(dx), math.abs(dy))
    if pasos < 1 then pintar(x0, y0) return end
    for i = 0, pasos do
      local t = i / pasos
      pintar(math.floor(x0 + dx * t + 0.5), math.floor(y0 + dy * t + 0.5))
    end
  end
  -- Curva de Catmull-Rom por los puntos de control: devuelve casillas separadas ~1.
  local function curva(pts)
    local salida = {}
    local n = #pts
    for i = 1, n - 1 do
      local p0, p1, p2, p3 = pts[math.max(1, i - 1)], pts[i], pts[i + 1], pts[math.min(n, i + 2)]
      local largo = math.max(1, math.sqrt((p2.x - p1.x) ^ 2 + (p2.y - p1.y) ^ 2))
      local pasos = math.ceil(largo)
      for k = 0, pasos - 1 do
        local t = k / pasos
        local t2, t3 = t * t, t * t * t
        local function c(a, b, cc, d)
          return 0.5 * ((2 * b) + (-a + cc) * t + (2 * a - 5 * b + 4 * cc - d) * t2 + (-a + 3 * b - 3 * cc + d) * t3)
        end
        salida[#salida + 1] = { x = c(p0.x, p1.x, p2.x, p3.x), y = c(p0.y, p1.y, p2.y, p3.y) }
      end
    end
    salida[#salida + 1] = { x = pts[n].x, y = pts[n].y }
    return salida
  end
  local function puertaHacia(c, otra)
    local mejor, md
    for _, a in ipairs(c.accesos) do
      local d = (a.x - otra.cx) ^ 2 + (a.y - otra.cy) ^ 2
      if not md or d < md then mejor, md = a, d end
    end
    return mejor
  end
  mapa.caminos = {}
  local function trazarCamino(a, b)
    local ga, gb = puertaHacia(a, b), puertaHacia(b, a)
    local sa = ga.y <= a.y + 1 and -1 or 1
    local sb = gb.y <= b.y + 1 and -1 or 1
    local p0 = { x = ga.x, y = ga.y + sa * 6 }
    local p1 = { x = gb.x, y = gb.y + sb * 6 }
    local largo = math.max(1, math.sqrt((p1.x - p0.x) ^ 2 + (p1.y - p0.y) ^ 2))
    local nx, ny = -(p1.y - p0.y) / largo, (p1.x - p0.x) / largo
    local mejor
    for intento = 1, 8 do
      local amp = math.min(44, largo * 0.24) * (intento <= 6 and 1 or 0.3)
      local pts = { { x = ga.x + 0.5, y = ga.y + 0.5 }, { x = p0.x + 0.5, y = p0.y + 0.5 } }
      local n = math.max(1, math.floor(largo / 38))
      for i = 1, n do
        local t = i / (n + 1)
        local off = (rng:int(-100, 100) / 100) * amp * math.sqrt(math.sin(math.pi * t))
        pts[#pts + 1] = { x = p0.x + (p1.x - p0.x) * t + nx * off + 0.5, y = p0.y + (p1.y - p0.y) * t + ny * off + 0.5 }
      end
      pts[#pts + 1] = { x = p1.x + 0.5, y = p1.y + 0.5 }
      pts[#pts + 1] = { x = gb.x + 0.5, y = gb.y + 0.5 }
      local ruta = curva(pts)
      local agua = 0
      for _, p in ipairs(ruta) do
        local s = mapa.suelo[math.floor(p.x)] and mapa.suelo[math.floor(p.x)][math.floor(p.y)]
        if s == "agua" or s == nil then agua = agua + 1 end
      end
      if agua == 0 or intento == 8 then mejor = ruta break end
    end
    for _, p in ipairs(mejor) do pintar(math.floor(p.x), math.floor(p.y)) end
    -- puntos de la ruta (para las caravanas): empiezan y acaban fuera de las murallas, donde ya se puede herir
    local puntos = {}
    local ini, fin = math.min(7, math.floor(#mejor / 3)), math.max(#mejor - 7, math.ceil(#mejor * 2 / 3))
    for i = ini, fin, 4 do puntos[#puntos + 1] = { x = mejor[i].x, y = mejor[i].y } end
    puntos[#puntos + 1] = { x = mejor[fin].x, y = mejor[fin].y }
    mapa.caminos[#mapa.caminos + 1] = { a = a.id, b = b.id, puntos = puntos }
  end
  -- árbol de expansión mínima de las ciudades de cada continente y, además, cada ciudad con su vecina
  -- más cercana (así hay algún circuito y no solo un árbol)
  for _, k in pairs(mapa.continentes) do
    local lista = {}
    for _, cid in ipairs(k.ciudades) do
      for _, c in ipairs(mapa.ciudades) do if c.id == cid then lista[#lista + 1] = c end end
    end
    if #lista >= 2 then
      local dentro, hecho = { [lista[1].id] = true }, {}
      local function dist(a, b) return math.sqrt((a.cx - b.cx) ^ 2 + (a.cy - b.cy) ^ 2) end
      local function unir(a, b)
        local clave = a.id < b.id and (a.id .. "|" .. b.id) or (b.id .. "|" .. a.id)
        if not hecho[clave] then hecho[clave] = true trazarCamino(a, b) end
      end
      for _ = 1, #lista - 1 do
        local mejor, ma, mb
        for _, a in ipairs(lista) do
          if dentro[a.id] then
            for _, b in ipairs(lista) do
              if not dentro[b.id] and (not mejor or dist(a, b) < mejor) then mejor, ma, mb = dist(a, b), a, b end
            end
          end
        end
        if mb then dentro[mb.id] = true unir(ma, mb) end
      end
      for _, a in ipairs(lista) do
        local mejor, vecina
        for _, b in ipairs(lista) do
          if b ~= a and (not mejor or dist(a, b) < mejor) then mejor, vecina = dist(a, b), b end
        end
        if vecina then unir(a, vecina) end
      end
    end
  end
  -- 4) Isla de la Cicatriz: plaza de guerra en el centro con sus cruces de camino
  local isla = mapa.cont[math.floor(cx)][math.floor(cy)] == 3
  local px0, px1 = math.floor(cx) - 14, math.floor(cx) + 14
  local py0, py1 = math.floor(cy) - 10, math.floor(cy) + 10
  if isla then
    linea(math.floor(cx), math.floor(cy) - 60, math.floor(cx), math.floor(cy) + 60)
    linea(math.floor(cx) - 45, math.floor(cy), math.floor(cx) + 45, math.floor(cy))
  end
  for y = py0, py1 do
    for x = px0, px1 do
      local cruz = math.abs(x - cx) <= 1 or math.abs(y - cy) <= 1
      if M.get(mapa, x, y) and not cruz and mapa.suelo[x][y] ~= "agua" then
        local lado = mapa.lado[x] and mapa.lado[x][y]
        setSuelo(mapa, x, y, "plaza", "cicatriz", lado)
        setBloque(mapa, x, y, false)
      end
    end
  end
  mapa.portal = { x = cx + 0.5, y = cy + 0.5 }
  -- 5) puertos: ciudades con barquero (el embarcadero de la isla se añade con los puestos)
  mapa.puertos = {}
  for _, c in ipairs(mapa.ciudades) do
    for _, n in ipairs(c.npcs) do
      if n.rol == "barquero" then
        mapa.puertos[#mapa.puertos + 1] = {
          id = c.id, nombre = c.nombre, x = n.x, y = n.y + 1.6, cont = c.cont, faccion = c.faccion,
        }
      end
    end
  end
  -- 6) escala de niveles: la distancia a la ciudad más cercana fija el nivel de cada zona. Se ajusta
  -- para que el nivel máximo se alcance en el interior de los continentes (nivel 30 hacia el 93% de
  -- la distancia máxima), así hay zonas de todos los niveles aunque cada continente sea pequeño.
  M.DIST_BASE = 40
  do
    local distancias = {}
    for y = 6, mapa.h - 6, 7 do
      for x = 6, mapa.w - 6, 7 do
        local k = mapa.cont[x][y]
        if (k == 1 or k == 2) and mapa.suelo[x][y] ~= "agua" then
          local md
          for _, c in ipairs(mapa.ciudades) do
            local d2 = (c.cx - x) ^ 2 + (c.cy - y) ^ 2
            if not md or d2 < md then md = d2 end
          end
          distancias[#distancias + 1] = math.sqrt(md)
        end
      end
    end
    table.sort(distancias)
    local q = distancias[math.max(1, math.floor(#distancias * 0.93))] or 200
    M.DIST_POR_NIVEL = math.max(3.0, math.min(6.5, (q - M.DIST_BASE) / 28))
  end
  local function cercaCiudad(x, y, margen)
    for _, c in ipairs(mapa.ciudades) do
      if x >= c.x - margen and x < c.x + c.w + margen and y >= c.y - margen and y < c.y + c.h + margen then
        return true
      end
    end
  end
  -- Lagos: masas de agua (con orilla de arena) repartidas por el territorio, lejos de las ciudades y sin
  -- cortar caminos ni la plaza central. Rompen la llanura y obligan a rodear.
  mapa.lagos = {}
  do
    local function hayCamino(x0, y0, r)
      for y = y0 - r, y0 + r do
        for x = x0 - r, x0 + r do
          local s = M.get(mapa, x, y)
          if s == "camino" or s == "plaza" or s == "montana" then return true end
          if cercaCiudad(x, y, 16) then return true end
        end
      end
      return false
    end
    local intentos = 0
    while #mapa.lagos < 30 and intentos < 900 do
      intentos = intentos + 1
      local x = rng:int(50, mapa.w - 50)
      local y = rng:int(50, mapa.h - 50)
      local k = mapa.cont[x][y]
      local b = mapa.bioma[x] and mapa.bioma[x][y]
      local r = rng:int(5, 13)
      if (k == 1 or k == 2) and mapa.distAgua[x][y] > r + 16 and b ~= "agua" and b ~= "cicatriz" and b ~= "costa" and not hayCamino(x, y, r + 4) then
        local ya = false
        for _, l in ipairs(mapa.lagos) do
          if (l.x - x) ^ 2 + (l.y - y) ^ 2 < (l.r + r + 14) ^ 2 then ya = true end
        end
        if not ya then
          local ang0 = rng:int(0, 359)
          for ty = y - r - 3, y + r + 3 do
            for tx = x - r - 3, x + r + 3 do
              local dx, dy = (tx - x) / (r * 1.25), (ty - y) / (r * 0.8)
              local ruido2 = 0.22 * math.sin(math.atan2(ty - y, tx - x) * 3 + ang0) + 0.1 * math.sin((tx + ty) * 0.7)
              local dd = math.sqrt(dx * dx + dy * dy) + ruido2
              local s = M.get(mapa, tx, ty)
              if s and s ~= "camino" and s ~= "plaza" and s ~= "montana" and (mapa.bioma[tx][ty] ~= "agua") then
                if dd < 0.85 then
                  setSuelo(mapa, tx, ty, "agua", mapa.bioma[tx][ty], nil)
                  setBloque(mapa, tx, ty, true)
                elseif dd < 1.1 and s ~= "agua" and s ~= "arena" then
                  setSuelo(mapa, tx, ty, "arena", mapa.bioma[tx][ty], nil)
                end
              end
            end
          end
          mapa.lagos[#mapa.lagos + 1] = { x = x, y = y, r = r }
        end
      end
    end
  end
  -- Cordilleras: cadenas de picos de 2x2 casillas que siguen crestas del ruido fractal (curvas, no
  -- rectas), con huecos para pasar. Nunca pisan caminos, plazas, ciudades ni la costa, así que las
  -- ciudades siguen conectadas por los caminos.
  local function libre(x, y)
    local s = M.get(mapa, x, y)
    local b = mapa.bioma[x] and mapa.bioma[x][y]
    if not s or s == "camino" or s == "plaza" or s == "agua" or s == "arena" or s == "cicatriz" or s == "montana" then return false end
    if b == "ciudad" or b == "costa" or b == "cicatriz" then return false end
    if mapa.bloque[x] and mapa.bloque[x][y] then return false end
    return true
  end
  for y = 6, mapa.h - 8, 2 do
    for x = 6, mapa.w - 8, 2 do
      local k = mapa.cont[x][y]
      if (k == 1 or k == 2) and mapa.distAgua[x][y] > 9 then
        local r = Continentes.fbm(x / 90, y / 90, 91, 3)
        local cresta = 1 - math.abs(r * 2 - 1)
        local grosor = 0.952 - 0.025 * azar(math.floor(x / 18), math.floor(y / 18), 24)
        if cresta > grosor and azar(math.floor(x / 14), math.floor(y / 14), 22) >= 0.15 and azar(x, y, 23) < 0.85
          and not cercaCiudad(x, y, 12)
          and libre(x, y) and libre(x + 1, y) and libre(x, y + 1) and libre(x + 1, y + 1) then
          for dy = 0, 1 do
            for dx = 0, 1 do
              setSuelo(mapa, x + dx, y + dy, "montana", nil, nil)
              setBloque(mapa, x + dx, y + dy, true)
            end
          end
          mapa.props[#mapa.props + 1] = {
            x = x, y = y, ancho = 2, alto = 2,
            tipo = k == 1 and "montana_albor" or "montana_umbra",
          }
        end
      end
    end
  end
  for y = 2, mapa.h - 3 do
    for x = 2, mapa.w - 3 do
      local b = mapa.bioma[x] and mapa.bioma[x][y]
      local s = M.get(mapa, x, y)
      if s and s ~= "camino" and s ~= "plaza" and s ~= "agua" and s ~= "montana" and b ~= "ciudad" and b ~= "costa" and b ~= "islote" and not cercaCiudad(x, y, 6) then
        local bosque = b == "senda" or b == "pinar" or b == "bosque" or b == "ventisca"
        local seco = b == "cienaga" or b == "velo" or b == "eclipse" or b == "cicatriz" or b == "altiplano"
        local mata = (b == "trigal" or b == "campos" or b == "colina") and azar(x, y, 7) < 0.012 and math.sin(x * 0.05) * math.sin(y * 0.05) > 0.3
        local pb = b == "ventisca" and 0.03 or 0.085
        local ps = b == "altiplano" and 0.012 or 0.045
        if (bosque and azar(x, y, 1) < pb) or (seco and azar(x, y, 2) < ps) or mata then
          local tipo = "arbol"
          if seco then tipo = "arbol_seco"
          elseif bosque then tipo = "arbol_pino" end
          setBloque(mapa, x, y, true)
          mapa.props[#mapa.props + 1] = { x = x, y = y, tipo = tipo }
        end
      end
    end
  end
  -- Puestos y refugios repartidos por el mapa, cada uno con sus PNJ y lejos del centro de las
  -- ciudades: puestos de comercio junto a los caminos, campamentos de cazadores, refugios de
  -- ladrones, torres de magos y ermitas de criadores.
  mapa.puestos = {}
  local BUENO = { hierba = true, hierba_osc = true, bosque = true, arena = true, tierra = true, camino = true }
  local function areaBuena(px, py, r)
    for y = py - r, py + r do
      for x = px - r, px + r do
        local s = M.get(mapa, x, y)
        if not s or not BUENO[s] then return false end
        local b = mapa.bioma[x] and mapa.bioma[x][y]
        if b == "ciudad" then return false end
      end
    end
    return true
  end
  local function cercaDePuesto(x, y, d)
    for _, pu in ipairs(mapa.puestos) do
      if math.abs(pu.x - x) < d and math.abs(pu.y - y) < d then return true end
    end
    return false
  end
  local function limpiar(px, py, r)
    for y = py - r, py + r do
      for x = px - r, px + r do
        if mapa.bloque[x] and mapa.bloque[x][y] then setBloque(mapa, x, y, false) end
      end
    end
    for i = #mapa.props, 1, -1 do
      local p = mapa.props[i]
      if p.x >= px - r and p.x <= px + r and p.y >= py - r and p.y <= py + r then table.remove(mapa.props, i) end
    end
  end
  local function nuevoPuesto(tipo, nombre, px, py, roles)
    limpiar(px, py, 4)
    local lado = px < cx and "albor" or "umbra"
    local pu = { id = #mapa.puestos + 1, tipo = tipo, nombre = nombre, x = px, y = py, npcs = {} }
    local sitios = { { -2, -1 }, { 2, -1 }, { -2, 2 }, { 2, 2 } }
    for i, r in ipairs(roles) do
      local o = sitios[i] or { 0, 3 }
      pu.npcs[#pu.npcs + 1] = { x = px + o[1] + 0.5, y = py + o[2] + 0.5, rol = r[1], nombre = r[2], faccion = lado }
    end
    mapa.props[#mapa.props + 1] = { x = px, y = py, tipo = "fogata" }
    mapa.props[#mapa.props + 1] = { x = px - 3, y = py - 2, tipo = "cartel" }
    mapa.props[#mapa.props + 1] = { x = px + 3, y = py + 1, tipo = "barril" }
    mapa.props[#mapa.props + 1] = { x = px - 3, y = py + 2, tipo = "caja" }
    mapa.puestos[#mapa.puestos + 1] = pu
    return pu
  end
  local function buscarSitio(biomas, minCiudad, minPuesto)
    for _ = 1, 800 do
      local x = rng:int(12, mapa.w - 13)
      local y = rng:int(12, mapa.h - 13)
      local b = mapa.bioma[x] and mapa.bioma[x][y]
      local ok = false
      for _, bb in ipairs(biomas) do if b == bb then ok = true end end
      if ok and mapa.cont[x][y] <= 2 and areaBuena(x, y, 4) and not cercaCiudad(x, y, minCiudad) and not cercaDePuesto(x, y, minPuesto) then
        return x, y
      end
    end
  end
  -- 1) puestos de comercio junto a los caminos entre ciudades
  for _, cam in ipairs(mapa.caminos) do
    local pts = cam.puntos
    for _, f in ipairs({ 0.25, 0.5, 0.75 }) do
      local p = pts[math.max(1, math.min(#pts, math.floor(#pts * f)))]
      local q = pts[math.max(1, math.min(#pts, math.floor(#pts * f) + 1))]
      local dx, dy = q.x - p.x, q.y - p.y
      local l = math.max(0.01, math.sqrt(dx * dx + dy * dy))
      for _, lado in ipairs({ 1, -1 }) do
        local x = math.floor(p.x + (-dy / l) * 8 * lado)
        local y = math.floor(p.y + (dx / l) * 8 * lado)
        if areaBuena(x, y, 4) and not cercaCiudad(x, y, 16) and not cercaDePuesto(x, y, 40) then
          nuevoPuesto("comercio", "Puesto del camino", x, y, { { "comercio", "Mercader del camino" }, { "establo", "Mozo de posta" } })
          break
        end
      end
    end
  end
  -- 2) los demás, escondidos por el territorio
  local function repartir(cant, biomas, tipo, nombre, roles, minCiudad)
    for _ = 1, cant do
      local x, y = buscarSitio(biomas, minCiudad, 60)
      if x then nuevoPuesto(tipo, nombre, x, y, roles) end
    end
  end
  repartir(4, { "senda", "pinar", "colina", "campos", "bosque" }, "cazadores", "Campamento de cazadores",
    { { "capitan", "Capitán de cazadores" }, { "comercio", "Proveedor del campamento" } }, 30)
  repartir(4, { "marea", "cienaga", "eclipse", "muelle", "velo" }, "ladrones", "Refugio de ladrones",
    { { "contacto", "Contacto en las sombras" } }, 40)
  repartir(2, { "velo", "campos", "colina" }, "torre", "Torre de encantos",
    { { "encantador", "Maestro de encantos" } }, 40)
  repartir(2, { "trigal", "senda", "cienaga" }, "ermita", "Ermita del criador",
    { { "criador", "Criador de mascotas" }, { "establo", "Mozo de cuadra" } }, 40)
  -- Embarcadero de la isla de la Cicatriz: el barquero que la une con los puertos de los continentes.
  if mapa.cont[math.floor(cx)][math.floor(cy)] == 3 then
    local pu = nuevoPuesto("embarcadero", "Embarcadero de la Cicatriz", math.floor(cx), math.floor(cy) + 26,
      { { "barquero", "Barquero de la Cicatriz" } })
    pu.npcs[1].faccion = nil
    mapa.puertos[#mapa.puertos + 1] = { id = "cicatriz", nombre = "Embarcadero de la Cicatriz", x = pu.npcs[1].x, y = pu.npcs[1].y + 1.6, cont = 3 }
    linea(math.floor(cx), math.floor(cy) + 10, math.floor(cx), math.floor(cy) + 25)
  end
  -- 3) lista de todos los PNJ para los iconos del mapa
  mapa.npcsMapa = {}
  for _, c in ipairs(mapa.ciudades) do
    for _, n in ipairs(c.npcs) do
      if n.rol ~= "guardia" then mapa.npcsMapa[#mapa.npcsMapa + 1] = { x = n.x, y = n.y, rol = n.rol, nombre = n.nombre } end
    end
  end
  for _, pu in ipairs(mapa.puestos) do
    for _, n in ipairs(pu.npcs) do mapa.npcsMapa[#mapa.npcsMapa + 1] = { x = n.x, y = n.y, rol = n.rol, nombre = n.nombre } end
  end
  local function punto(bioma)
    for _ = 1, 400 do
      local x = rng:int(2, mapa.w - 3)
      local y = rng:int(2, mapa.h - 3)
      local b = mapa.bioma[x] and mapa.bioma[x][y]
      local s = M.get(mapa, x, y)
      local ok = M.transitable(mapa, x, y) and mapa.cont[x][y] <= 3 and b == bioma and b ~= "ciudad" and s ~= "camino" and s ~= "plaza"
      if ok and cercaCiudad(x, y, 8) then ok = false end
      if ok and cercaDePuesto(x, y, 14) then ok = false end
      if ok and not dentroCiudad(mapa.ciudades, x, y) then return x + 0.5, y + 0.5 end
    end
  end
  -- Campamentos de criaturas: alrededor de CADA ciudad hay zonas para todos los niveles. Las criaturas
  -- de nivel bajo salen cerca de la ciudad y las de nivel alto cada vez mas lejos (anillos). En la
  -- ciudad de su bioma cada criatura tiene el doble de campamentos.
  local function puntoAnillo(c, dist)
    local ccx, ccy = c.x + c.w / 2, c.y + c.h / 2
    for _ = 1, 80 do
      local ang = rng:int(0, 359) * math.pi / 180
      local d = dist + rng:int(-9, 9)
      local x, y = math.floor(ccx + math.cos(ang) * d), math.floor(ccy + math.sin(ang) * d)
      if x > 2 and y > 2 and x < mapa.w - 3 and y < mapa.h - 3 then
        local s = M.get(mapa, x, y)
        local b = mapa.bioma[x] and mapa.bioma[x][y]
        local ok = M.transitable(mapa, x, y) and mapa.cont[x][y] == c.cont and b ~= "ciudad" and b ~= "cicatriz" and s ~= "camino" and s ~= "plaza"
        if ok and cercaCiudad(x, y, 10) then ok = false end
        if ok and cercaDePuesto(x, y, 12) then ok = false end
        if ok then return x + 0.5, y + 0.5 end
      end
    end
  end
  -- Nivel de la zona en un punto: depende de lo lejos que está de la ciudad MÁS CERCANA, así una
  -- criatura nunca sale en una zona de otro nivel aunque el anillo de otra ciudad pase por ahí.
  local function nivelZona(x, y)
    local md
    for _, c in ipairs(mapa.ciudades) do
      local d2 = (c.x + c.w / 2 - x) ^ 2 + (c.y + c.h / 2 - y) ^ 2
      if not md or d2 < md then md = d2 end
    end
    return math.max(1, math.min(Datos.NIVEL_MAX, math.floor((math.sqrt(md) - M.DIST_BASE) / M.DIST_POR_NIVEL + 0.5)))
  end
  M.nivelZona = nivelZona
  M.TOLERANCIA_NIVEL = 2
  for _, mon in ipairs(Datos.monstruos) do
    if not mon.noCampamento then
      local cant = mon.elite and 2 or (mon.nivel <= 8 and 4 or 3)
      for _, c in ipairs(mapa.ciudades) do
        local propia = mon.bioma == c.bioma
        -- menos campamentos: dos en la ciudad de su bioma y uno en la mitad de las demás
        local camps = mon.elite and (propia and 1 or 0) or (propia and 2 or rng:int(0, 1))
        for _ = 1, camps do
          local x, y
          for _ = 1, 8 do
            x, y = puntoAnillo(c, M.DIST_BASE + mon.nivel * M.DIST_POR_NIVEL)
            if x and math.abs(nivelZona(x, y) - mon.nivel) <= M.TOLERANCIA_NIVEL then break end
            x = nil
          end
          if x then
            mapa.campamentos[#mapa.campamentos + 1] = {
              x = x, y = y, monstruo = mon.id, cantidad = cant, radio = 4, ciudad = c.id,
            }
          end
        end
      end
    end
  end
  -- Relleno: las zonas entre ciudades y la Cicatriz tambien tienen criaturas. Sobre una rejilla se
  -- anaden campamentos donde no hay ninguno cerca; su nivel depende de lo lejos que estan de la ciudad
  -- mas proxima (mismo reparto por anillos), asi el centro del mapa es la zona mas peligrosa.
  do
    local CELDA, HUECO = 46, 36
    local function campamentoCerca(x, y, r)
      for _, k in ipairs(mapa.campamentos) do
        if not k.z and (k.x - x) ^ 2 + (k.y - y) ^ 2 < r * r then return true end
      end
      return false
    end
    for gy = 12, mapa.h - 12, CELDA do
      for gx = 12, mapa.w - 12, CELDA do
        local x, y = gx + rng:int(-12, 12), gy + rng:int(-12, 12)
        if x > 2 and y > 2 and x < mapa.w - 3 and y < mapa.h - 3 then
          local s = M.get(mapa, x, y)
          local b = mapa.bioma[x] and mapa.bioma[x][y]
          local ok = M.transitable(mapa, x, y) and mapa.cont[x][y] <= 3 and b ~= "ciudad" and s ~= "camino" and s ~= "plaza"
          if ok and (cercaCiudad(x, y, 10) or cercaDePuesto(x, y, 12) or campamentoCerca(x, y, HUECO)) then ok = false end
          if ok then
            local cerca, md
            for _, c in ipairs(mapa.ciudades) do
              local d2 = (c.x + c.w / 2 - x) ^ 2 + (c.y + c.h / 2 - y) ^ 2
              if not md or d2 < md then cerca, md = c, d2 end
            end
            local nivel = math.max(1, math.min(Datos.NIVEL_MAX, math.floor((math.sqrt(md) - M.DIST_BASE) / M.DIST_POR_NIVEL + 0.5)))
            local posibles = {}
            for _, mon in ipairs(Datos.monstruos) do
              if not mon.noCampamento and not mon.elite and math.abs(mon.nivel - nivel) <= 2 then posibles[#posibles + 1] = mon end
            end
            if #posibles > 0 then
              local mon = posibles[rng:int(1, #posibles)]
              mapa.campamentos[#mapa.campamentos + 1] = {
                x = x + 0.5, y = y + 0.5, monstruo = mon.id, radio = 4, ciudad = cerca.id,
                cantidad = mon.nivel <= 8 and 4 or 3,
              }
            end
          end
        end
      end
    end
  end
  -- Isla de la Cicatriz: la zona de guerra, con criaturas del nivel máximo repartidas por toda la isla
  do
    local altas = {}
    for _, mon in ipairs(Datos.monstruos) do
      if not mon.noCampamento and not mon.elite and mon.nivel >= 26 then altas[#altas + 1] = mon end
    end
    local isla = {}
    for gy = 24, mapa.h - 24, 30 do
      for gx = 24, mapa.w - 24, 30 do
        local x, y = gx + rng:int(-9, 9), gy + rng:int(-9, 9)
        if mapa.cont[x][y] == 3 and M.transitable(mapa, x, y) then
          local s = M.get(mapa, x, y)
          local ok = s ~= "camino" and s ~= "plaza" and Util.dist(x, y, cx, cy) > 26 and not cercaDePuesto(x, y, 14)
          for _, k in ipairs(isla) do
            if (k.x - x) ^ 2 + (k.y - y) ^ 2 < 22 * 22 then ok = false end
          end
          if ok and #altas > 0 then
            local mon = altas[rng:int(1, #altas)]
            local camp = { x = x + 0.5, y = y + 0.5, monstruo = mon.id, radio = 4, ciudad = "cicatriz", isla = true, cantidad = 3 }
            isla[#isla + 1] = camp
            mapa.campamentos[#mapa.campamentos + 1] = camp
          end
        end
      end
    end
  end
  mapa.escaleras = {}
  mapa.alto = {}
  for _, c in ipairs(mapa.ciudades) do
    if c.capital then
      local sx, sy = c.x + 8, c.y + 6
      mapa.escaleras[#mapa.escaleras + 1] = { x = sx, y = sy, de = 0, a = 1 }
      mapa.escaleras[#mapa.escaleras + 1] = { x = sx, y = sy + 3, de = 1, a = 0 }
      for y = c.y + 4, c.y + 12 do
        for x = c.x + 4, c.x + 14 do
          mapa.alto[x] = mapa.alto[x] or {}
          mapa.alto[x][y] = true
        end
      end
    end
  end
  -- Zonas elevadas (mesetas y cumbres): una plataforma a la que se sube por una escalera y donde
  -- salen criaturas más fuertes que las de su zona. Solo se ve y se pisa estando arriba (z = 1).
  mapa.mesetas = {}
  local ELEVADAS = {
    { bioma = "colina", nombre = "Meseta del Alba" },
    { bioma = "senda", nombre = "Terraza de Liria" },
    { bioma = "velo", nombre = "Terraza del Velo" },
    { bioma = "cienaga", nombre = "Meseta de la Ciénaga" },
    { bioma = "pinar", nombre = "Cumbre de Nox" },
    { bioma = "eclipse", nombre = "Cumbre del Eclipse" },
  }
  M.NIVEL_EXTRA_ELEVADA = 3
  for _, z in ipairs(ELEVADAS) do
    local x, y
    for _ = 1, 6 do
      x, y = buscarSitio({ z.bioma }, 22, 30)
      if x and areaBuena(x, y, 8) then break end
      x = nil
    end
    if x then
      -- criaturas de la zona: las más fuertes, con el nivel subido
      local lista = {}
      for _, mon in ipairs(Datos.monstruos) do
        if mon.bioma == z.bioma and not mon.noCampamento then lista[#lista + 1] = mon end
      end
      table.sort(lista, function(a, b) return a.nivel > b.nivel end)
      if #lista > 0 then
        local x0, y0, w, h = x - 7, y - 6, 14, 12
        for tx = x0, x0 + w - 1 do
          mapa.alto[tx] = mapa.alto[tx] or {}
          for ty = y0, y0 + h - 1 do mapa.alto[tx][ty] = true end
        end
        mapa.escaleras[#mapa.escaleras + 1] = { x = x, y = y + 3, de = 0, a = 1 }
        mapa.escaleras[#mapa.escaleras + 1] = { x = x, y = y, de = 1, a = 0 }
        local nmin, nmax = 99, 0
        local sitios = { { x - 4, y - 3 }, { x + 4, y - 3 }, { x - 4, y + 4 } }
        for i, s in ipairs(sitios) do
          local mon = lista[math.min(#lista, (i == 3) and 1 or ((i % #lista) + 1))]
          local nivel = math.min(Datos.NIVEL_MAX, mon.nivel + M.NIVEL_EXTRA_ELEVADA)
          mapa.campamentos[#mapa.campamentos + 1] = {
            x = s[1] + 0.5, y = s[2] + 0.5, monstruo = mon.id, cantidad = 2, radio = 3, z = 1, nivel = nivel,
          }
          nmin, nmax = math.min(nmin, nivel), math.max(nmax, nivel)
        end
        mapa.mesetas[#mapa.mesetas + 1] = {
          nombre = z.nombre, bioma = z.bioma, x = x0, y = y0, w = w, h = h,
          entrada = { x = x, y = y + 3 }, nivelMin = nmin, nivelMax = nmax,
        }
      end
    end
  end
  -- Puertas de las tres mazmorras, en sitios despejados y bien separados entre sí (Datos.mazmorras).
  mapa.mazmorras = {}
  local TODOS = { "senda", "pinar", "colina", "campos", "bosque", "marea", "cienaga", "eclipse", "muelle", "velo" }
  local function lejosDeOtras(x, y, d)
    for _, z in ipairs(mapa.mazmorras) do
      if math.abs(z.x - x) < d and math.abs(z.y - y) < d then return false end
    end
    return true
  end
  for _, def in ipairs(Datos.mazmorras) do
    local x, y
    for _, d in ipairs({ 260, 160, 80, 0 }) do
      for _, biomas in ipairs({ def.biomas, TODOS }) do
        for _ = 1, 25 do
          x, y = buscarSitio(biomas, 26, 20)
          if x and lejosDeOtras(x, y, d) then break end
          x = nil
        end
        if x then break end
      end
      if x then break end
    end
    if x then
      limpiar(x, y, 3)
      mapa.mazmorras[#mapa.mazmorras + 1] = { id = def.id, x = x, y = y, nombre = def.nombre }
      mapa.props[#mapa.props + 1] = { x = x, y = y, tipo = "puerta_mazmorra", mz = def.id }
      mapa.props[#mapa.props + 1] = { x = x - 3, y = y + 1, tipo = "farol" }
      mapa.props[#mapa.props + 1] = { x = x + 3, y = y + 1, tipo = "farol" }
    end
  end
  return mapa
end

-- El mapa del mundo es siempre el mismo: se genera una vez por proceso y cada mundo recibe una copia
-- con sus propias ciudades (las parcelas cambian de dueño); el terreno se comparte porque no cambia.
local cacheMundo
function M.mundo()
  if not cacheMundo then
    cacheMundo = generarMundo(Util.rng(Datos.SEMILLA + 17))
    cacheMundo.distAgua = nil
  end
  local m = {}
  for k, v in pairs(cacheMundo) do m[k] = v end
  m.ciudades = copiaProfunda(cacheMundo.ciudades)
  return m
end

function M.batalla()
  local w, h = 96, 64
  local mapa = M.nuevo(w, h)
  local medio = math.floor(h / 2)
  mapa.decorado = {}
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local enCalle = math.abs(y - medio) <= 1 or math.abs(x - w / 2) <= 1
      -- bioma "batalla": sin la decoración al azar del resto del mundo (todo se coloca a mano)
      setSuelo(mapa, x, y, enCalle and "camino" or "cicatriz", "batalla", nil)
      if x == 0 or y == 0 or x == w - 1 or y == h - 1 then setBloque(mapa, x, y, true) end
    end
  end
  local function base(x0, y0, bw, bh)
    for y = 0, bh - 1 do
      for x = 0, bw - 1 do
        setSuelo(mapa, x0 + x, y0 + y, "plaza", "batalla", nil)
        setBloque(mapa, x0 + x, y0 + y, false)
      end
    end
  end
  base(4, medio - 8, 16, 16)
  base(w - 20, medio - 8, 16, 16)
  -- Cada muro tiene varias entradas: la puerta principal en el centro y dos laterales.
  local ENTRADAS = { medio, medio - 14, medio + 14 }
  local function muro(x, faccion)
    local esPuerta = {}
    for _, py in ipairs(ENTRADAS) do esPuerta[py] = true end
    for y = 1, h - 2 do
      if not esPuerta[y] then
        setBloque(mapa, x, y, true)
        setSuelo(mapa, x, y, "muralla", "batalla", nil)
      end
    end
    mapa.puerta = mapa.puerta or {}
    for _, py in ipairs(ENTRADAS) do
      mapa.puerta[x .. "_" .. py] = { faccion = faccion, viva = true, x = x, y = py }
      setBloque(mapa, x, py, true)
      setSuelo(mapa, x, py, "camino", "batalla", nil)
    end
  end
  muro(22, "albor")
  muro(w - 23, "umbra")  mapa.spawns = { albor = { x = 8.5, y = medio + 0.5 }, umbra = { x = w - 8.5, y = medio + 0.5 } }
  mapa.objetivos = {
    { tipo = "altar", faccion = "albor", x = 12.5, y = medio + 0.5 },
    { tipo = "altar", faccion = "umbra", x = w - 12.5, y = medio + 0.5 },
    { tipo = "estatua", faccion = "albor", x = 30.5, y = medio - 14.5 },
    { tipo = "estatua", faccion = "albor", x = 30.5, y = medio + 14.5 },
    { tipo = "estatua", faccion = "umbra", x = w - 30.5, y = medio - 14.5 },
    { tipo = "estatua", faccion = "umbra", x = w - 30.5, y = medio + 14.5 },
    { tipo = "puerta", faccion = "albor", x = 22.5, y = medio + 0.5, principal = true },
    { tipo = "puerta", faccion = "albor", x = 22.5, y = medio - 14 + 0.5 },
    { tipo = "puerta", faccion = "albor", x = 22.5, y = medio + 14 + 0.5 },
    { tipo = "puerta", faccion = "umbra", x = (w - 23) + 0.5, y = medio + 0.5, principal = true },
    { tipo = "puerta", faccion = "umbra", x = (w - 23) + 0.5, y = medio - 14 + 0.5 },
    { tipo = "puerta", faccion = "umbra", x = (w - 23) + 0.5, y = medio + 14 + 0.5 },
  }

  -- Relieve y obstáculos. Todo es determinista (mismo mapa en servidor y cliente) y con colisiones.
  local cx = w / 2
  local function libreDeRuta(x, y)
    -- fuera de las calles, las bases, los muros y los objetivos
    if math.abs(y - medio) <= 2 or math.abs(x - cx) <= 2 then return false end
    if x < 24 or x > w - 25 then return false end
    for _, o in ipairs(mapa.objetivos) do
      if math.abs(o.x - x) < 5 and math.abs(o.y - y) < 5 then return false end
    end
    return true
  end
  local function decor(x, y, tipo)
    mapa.decorado[x] = mapa.decorado[x] or {}
    mapa.decorado[x][y] = tipo
    setBloque(mapa, x, y, tipo ~= "restos")
  end
  -- 1) piedras al borde de los caminos (a ambos lados, con huecos para cruzar)
  for x = 24, w - 25 do
    if math.abs(x - cx) > 5 and azar(x, 3, 91) < 0.62 then
      decor(x, medio - 3, "piedra")
      if azar(x, 4, 92) < 0.3 then decor(x, medio - 4, "piedra") end
    end
    if math.abs(x - cx) > 5 and azar(x, 5, 93) < 0.62 then
      decor(x, medio + 3, "piedra")
      if azar(x, 6, 94) < 0.3 then decor(x, medio + 4, "piedra") end
    end
  end
  for y = 3, h - 4 do
    if math.abs(y - medio) > 5 and azar(y, 7, 95) < 0.62 then
      decor(math.floor(cx) - 3, y, "piedra")
      if azar(y, 8, 96) < 0.3 then decor(math.floor(cx) - 4, y, "piedra") end
    end
    if math.abs(y - medio) > 5 and azar(y, 9, 97) < 0.62 then
      decor(math.floor(cx) + 3, y, "piedra")
      if azar(y, 10, 98) < 0.3 then decor(math.floor(cx) + 4, y, "piedra") end
    end
  end
  -- 2) crestas de montaña (relieve): bloques de 2x2 en el campo abierto, agrupados por ruido
  local function libre2(x, y)
    for dy = 0, 1 do
      for dx = 0, 1 do
        local tx, ty = x + dx, y + dy
        if not libreDeRuta(tx, ty) or (mapa.bloque[tx] and mapa.bloque[tx][ty]) then return false end
      end
    end
    return true
  end
  for y = 4, h - 6, 2 do
    for x = 26, w - 28, 2 do
      local n = math.sin(x * 0.21 + y * 0.09) + math.sin(x * 0.07 - y * 0.23) + azar(x, y, 99) * 0.9
      if n > 1.2 and libre2(x, y) then
        for dy = 0, 1 do
          for dx = 0, 1 do
            setBloque(mapa, x + dx, y + dy, true)
          end
        end
        -- risco dibujado por el cliente (render/campo.lua)
        mapa.props[#mapa.props + 1] = { x = x, y = y, ancho = 2, alto = 2, tipo = x < cx and "risco_albor" or "risco_umbra" }
      end
    end
  end
  -- 3) huecos (grietas) en parches de 2x2 o 3x2: no se pueden pisar
  for y = 5, h - 7, 4 do
    for x = 27, w - 30, 5 do
      local px, py = x + math.floor(azar(x, y, 101) * 3), y + math.floor(azar(x, y, 102) * 2)
      if azar(x, y, 103) < 0.38 then
        local ancho = 2 + math.floor(azar(x, y, 104) * 2)
        local ok = true
        for dy = 0, 1 do
          for dx = 0, ancho - 1 do
            local tx, ty = px + dx, py + dy
            if not libreDeRuta(tx, ty) or (mapa.bloque[tx] and mapa.bloque[tx][ty]) or M.get(mapa, tx, ty) ~= "cicatriz" then ok = false end
          end
        end
        if ok then
          for dy = 0, 1 do
            for dx = 0, ancho - 1 do decor(px + dx, py + dy, "grieta") end
          end
        end
      end
    end
  end
  -- 4) restos en el suelo, sin colisión
  -- (manchas de quemado, brasas, guijarros, grietas finas y restos: no bloquean el paso)
  for y = 3, h - 4 do
    for x = 24, w - 25 do
      if not (mapa.bloque[x] and mapa.bloque[x][y]) and not (mapa.decorado[x] and mapa.decorado[x][y]) then
        local suelo = M.get(mapa, x, y)
        if suelo == "cicatriz" then
          local r = azar(x, y, 105)
          local tipo
          if r < 0.006 then tipo = "restos"
          elseif r < 0.07 then tipo = "mancha"
          elseif r < 0.10 then tipo = "guijarros"
          elseif r < 0.125 then tipo = "grietita"
          elseif r < 0.14 then tipo = "brasas" end
          if tipo then decor(x, y, tipo) end
        end
      end
    end
  end
  -- 5) nunca se debe cerrar el paso: de la base de Albor se llega a todos los objetivos y a la base rival
  local function alcanzable(desdeX, desdeY, destinos)
    local visto, cola, i = {}, { { desdeX, desdeY } }, 1
    visto[desdeX .. "_" .. desdeY] = true
    local function pasa(tx, ty)
      return M.transitable(mapa, tx, ty) or (mapa.puerta and mapa.puerta[tx .. "_" .. ty] ~= nil)
    end
    while cola[i] do
      local c = cola[i]
      i = i + 1
      for dy = -1, 1 do
        for dx = -1, 1 do
          if dx ~= 0 or dy ~= 0 then
            local nx, ny = c[1] + dx, c[2] + dy
            local k = nx .. "_" .. ny
            if pasa(nx, ny) and not visto[k] and (dx == 0 or dy == 0 or (pasa(c[1] + dx, c[2]) and pasa(c[1], c[2] + dy))) then
              visto[k] = true
              cola[#cola + 1] = { nx, ny }
            end
          end
        end
      end
    end
    for _, d in ipairs(destinos) do
      if not visto[math.floor(d[1]) .. "_" .. math.floor(d[2])] then return false end
    end
    return true
  end
  local destinos = {}
  for _, o in ipairs(mapa.objetivos) do destinos[#destinos + 1] = { o.x, o.y } end
  destinos[#destinos + 1] = { mapa.spawns.umbra.x, mapa.spawns.umbra.y }
  mapa.conexo = alcanzable(math.floor(mapa.spawns.albor.x), math.floor(mapa.spawns.albor.y), destinos)
  return mapa
end

function M.estandarte()
  local w, h = 96, 64
  local mapa = M.nuevo(w, h)
  local medio = math.floor(h / 2)
  local centro = math.floor(w / 2)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local calle = math.abs(y - medio) <= 1
      local lado = x < centro and "hierba" or "hierba_osc"
      setSuelo(mapa, x, y, calle and "camino" or lado, "campo", nil)
      if x == 0 or y == 0 or x == w - 1 or y == h - 1 then setBloque(mapa, x, y, true) end
    end
  end
  local function fuerte(x0)
    for y = medio - 6, medio + 6 do
      for x = x0, x0 + 10 do
        setSuelo(mapa, x, y, "plaza", "campo", nil)
      end
    end
  end
  fuerte(6)
  fuerte(w - 17)
  for y = 8, h - 9 do
    local paso = math.abs(y - medio) <= 1 or math.abs(y - (medio - 12)) <= 1 or math.abs(y - (medio + 12)) <= 1
    if not paso then
      setBloque(mapa, centro, y, true)
      setSuelo(mapa, centro, y, "muralla", "campo", nil)
    else
      setSuelo(mapa, centro, y, "camino", "campo", nil)
    end
  end
  mapa.spawns = { albor = { x = 18.5, y = medio + 0.5 }, umbra = { x = w - 18.5, y = medio + 0.5 } }
  mapa.banderas = { albor = { x = 11.5, y = medio + 0.5 }, umbra = { x = w - 11.5, y = medio + 0.5 } }
  return mapa
end

function M.casa()
  local w, h = 22, 16
  local mapa = M.nuevo(w, h)
  local puerta = math.floor(w / 2)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local borde = x == 0 or y == 0 or x == w - 1 or y == h - 1
      setSuelo(mapa, x, y, borde and "empedrado" or "madera", "casa", nil)
      if borde and not (y == h - 1 and x == puerta) then setBloque(mapa, x, y, true) end
    end
  end
  mapa.salida = { x = puerta + 0.5, y = h - 2.5 }
  mapa.muebles = {
    cama = { x = 4.5, y = 4.5 },
    cofre = { x = w - 4.5, y = 4.5 },
    estandarte = { x = 4.5, y = 9.5 },
    mesa = { x = puerta + 0.5, y = 8.5 },
  }
  return mapa
end

-- Zonas de criaturas del mundo para el mapa: una por bioma con sus criaturas y niveles (centradas
-- donde están sus campamentos) y una por cada zona elevada. Se calcula una vez y se guarda.
function M.zonas(mapa)
  if mapa._zonas then return mapa._zonas end
  -- una zona por ciudad y franja de nivel: cercanias (1-10), tierras medias (11-20) y tierras salvajes (21-30)
  local FRANJAS = { { 1, 10, "cercanias" }, { 11, 20, "tierras medias" }, { 21, 99, "tierras salvajes" } }
  local nombres = {}
  for _, c in ipairs(mapa.ciudades or {}) do nombres[c.id] = c.nombre end
  nombres.cicatriz = "Isla de la Cicatriz"
  -- Un marcador por grupo de campamentos: de la misma ciudad, cercanos entre sí y con como mucho
  -- NIVEL_GRUPO niveles de diferencia entre sus criaturas. El marcador va sobre un campamento real del grupo
  -- (el más cercano al centro), nunca en medio del mar.
  local NIVEL_GRUPO, DIST_GRUPO = 3, 45
  local camps = {}
  for _, camp in ipairs(mapa.campamentos or {}) do
    if not camp.z and camp.ciudad then
      local mon = Datos.monstruo(camp.monstruo)
      if mon then camps[#camps + 1] = { camp = camp, mon = mon } end
    end
  end
  table.sort(camps, function(a, b)
    if a.mon.nivel ~= b.mon.nivel then return a.mon.nivel < b.mon.nivel end
    if a.camp.x ~= b.camp.x then return a.camp.x < b.camp.x end
    return a.camp.y < b.camp.y
  end)
  local grupos = {}
  for _, c in ipairs(camps) do
    local nivel, elegido = c.mon.nivel, nil
    for _, g in ipairs(grupos) do
      if g.ciudad == c.camp.ciudad and nivel - g.min <= NIVEL_GRUPO
        and Util.dist(g.ax, g.ay, c.camp.x, c.camp.y) <= DIST_GRUPO then
        elegido = g
        break
      end
    end
    if not elegido then
      elegido = { ciudad = c.camp.ciudad, min = nivel, max = nivel, ax = c.camp.x, ay = c.camp.y, items = {} }
      grupos[#grupos + 1] = elegido
    end
    elegido.max = math.max(elegido.max, nivel)
    elegido.items[#elegido.items + 1] = c
  end
  local lista = {}
  for _, g in ipairs(grupos) do
    local sx, sy = 0, 0
    for _, c in ipairs(g.items) do sx, sy = sx + c.camp.x, sy + c.camp.y end
    local cx, cy = sx / #g.items, sy / #g.items
    local mejor, md
    for _, c in ipairs(g.items) do
      local d2 = (c.camp.x - cx) ^ 2 + (c.camp.y - cy) ^ 2
      if not md or d2 < md then mejor, md = c.camp, d2 end
    end
    local monstruos, vistos = {}, {}
    for _, c in ipairs(g.items) do
      if not vistos[c.mon.id] then
        vistos[c.mon.id] = true
        monstruos[#monstruos + 1] = { id = c.mon.id, nombre = c.mon.nombre, nivel = c.mon.nivel }
      end
    end
    table.sort(monstruos, function(a, b)
      if a.nivel ~= b.nivel then return a.nivel < b.nivel end
      return a.id < b.id
    end)
    local fi = 3
    for i, f in ipairs(FRANJAS) do if g.min >= f[1] and g.min <= f[2] then fi = i break end end
    lista[#lista + 1] = {
      nombre = (nombres[g.ciudad] or g.ciudad) .. ": " .. FRANJAS[fi][3], ciudad = g.ciudad, franja = fi,
      x = mejor.x, y = mejor.y, nivelMin = g.min, nivelMax = g.max, monstruos = monstruos,
    }
  end
  for _, ms in ipairs(mapa.mesetas or {}) do
    local vistos, ms_lista = {}, {}
    for _, camp in ipairs(mapa.campamentos) do
      if camp.z and camp.x >= ms.x and camp.x < ms.x + ms.w and camp.y >= ms.y and camp.y < ms.y + ms.h and not vistos[camp.monstruo] then
        vistos[camp.monstruo] = true
        local mon = Datos.monstruo(camp.monstruo)
        ms_lista[#ms_lista + 1] = { id = mon.id, nombre = mon.nombre, nivel = camp.nivel or mon.nivel }
      end
    end
    table.sort(ms_lista, function(a, b) return a.nivel < b.nivel end)
    lista[#lista + 1] = {
      nombre = ms.nombre, bioma = ms.bioma, elevada = true, x = ms.x + ms.w / 2, y = ms.y + ms.h / 2,
      nivelMin = ms.nivelMin, nivelMax = ms.nivelMax, monstruos = ms_lista, ancho = ms.w, alto = ms.h,
    }
  end
  table.sort(lista, function(a, b)
    if a.nivelMin ~= b.nivelMin then return a.nivelMin < b.nivelMin end
    return a.nombre < b.nombre
  end)
  mapa._zonas = lista
  return lista
end

return M
