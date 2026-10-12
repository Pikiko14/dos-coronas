local Datos = require("compartido.dominio.datos")
local Util = require("compartido.dominio.util")

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
  npc(medio - 4, medioY, "mercado", "Mercader de " .. ciudad.nombre)
  npc(medio + 4, medioY, "heraldo", "Heraldo")
  npc(medio - 4, medioY + 3, "mayordomo", "Mayordomo")
  npc(medio + 4, medioY + 3, "encargos", "Tablón de encargos")
  local gy = (ciudad.acceso == "norte" and not grande) and 2 or (h - 3)
  npc(medio - 2, gy, "guardia", "Guardia de " .. ciudad.nombre)
  npc(medio + 2, gy, "guardia", "Guardia de " .. ciudad.nombre)
end

function M.mundo(rng)
  local mapa = M.nuevo(Datos.MAPA_W, Datos.MAPA_H)
  local cx, cy = mapa.w / 2, mapa.h / 2
  local rx, ry = mapa.w * 0.46, mapa.h * 0.46
  local ARTERIA_N, ARTERIA_S = 168, 292
  local CAMINO_O, CAMINO_E = 144, 576
  for y = 0, mapa.h - 1 do
    for x = 0, mapa.w - 1 do
      local d = math.sqrt(((x - cx) / rx) ^ 2 + ((y - cy) / ry) ^ 2) + ruido(x, y)
      local lado = x < cx and "albor" or "umbra"
      local onda = math.sin(x * 0.04) * 10
      local claro = math.sin(x * 0.05 + 1.2) * math.sin(y * 0.05)
      local cicatriz = math.abs(x - cx) < (12 + math.sin(y * 0.08) * 3)
      if d > 0.97 then
        setSuelo(mapa, x, y, "agua", "agua", nil)
        setBloque(mapa, x, y, true)
      elseif d > 0.90 then
        setSuelo(mapa, x, y, "arena", "costa", lado)
      elseif cicatriz and d < 0.90 then
        setSuelo(mapa, x, y, "cicatriz", "cicatriz", nil)
      elseif d < 0.86 and (y > cy + 70 + onda or claro > 0.62) then
        setSuelo(mapa, x, y, "bosque", "bosque", lado)
      elseif lado == "umbra" then
        setSuelo(mapa, x, y, "hierba_osc", "umbra", "umbra")
      else
        setSuelo(mapa, x, y, "hierba", "albor", "albor")
      end
    end
  end
  local function centroCiudad(c)
    local ancho = c.capital and 72 or 48
    local alto = c.capital and 56 or 36
    return c.x + ancho / 2, c.y + alto / 2
  end
  for y = 1, mapa.h - 2 do
    for x = 1, mapa.w - 2 do
      local b = mapa.bioma[x] and mapa.bioma[x][y]
      if b and b ~= "agua" and b ~= "cicatriz" then
        local mejor, md
        for _, c in ipairs(Datos.ciudades) do
          local ccx, ccy = centroCiudad(c)
          local dx, dy = x - ccx, y - ccy
          local d2 = dx * dx + dy * dy
          if not md or d2 < md then mejor, md = c, d2 end
        end
        if mejor and md <= 110 * 110 and Datos.biomas[mejor.bioma] then
          local def = Datos.biomas[mejor.bioma]
          setSuelo(mapa, x, y, def.suelo, mejor.bioma, mejor.faccion)
        end
      end
    end
  end
  for _, c in ipairs(Datos.ciudades) do
    local copia = {}
    for k, v in pairs(c) do copia[k] = v end
    estamparCiudad(mapa, copia)
    mapa.ciudades[#mapa.ciudades + 1] = copia
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
          if s and actual ~= "agua" and actual ~= "cicatriz" and actual ~= "ciudad" then
            setSuelo(mapa, x, y, suelo, bio, c.faccion)
            setBloque(mapa, x, y, false)
          end
        end
      end
    end
  end
  for _, c in ipairs(mapa.ciudades) do despejar(c, 5) end
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
  linea(CAMINO_O, ARTERIA_N, CAMINO_E, ARTERIA_N)
  linea(CAMINO_O, ARTERIA_S, CAMINO_E, ARTERIA_S)
  linea(204, ARTERIA_N, 204, ARTERIA_S)
  linea(516, ARTERIA_N, 516, ARTERIA_S)
  linea(cx, ARTERIA_N, cx, ARTERIA_S)
  for _, c in ipairs(mapa.ciudades) do
    for _, a in ipairs(c.accesos) do
      local meta = math.abs(a.y - ARTERIA_N) <= math.abs(a.y - ARTERIA_S) and ARTERIA_N or ARTERIA_S
      local paso = meta > a.y and 1 or -1
      local y = a.y + paso
      local guardia = 0
      while guardia < 80 do
        guardia = guardia + 1
        pintar(a.x, y)
        if y == meta then break end
        y = y + paso
      end
    end
  end
  local px0, px1 = math.floor(cx) - 14, math.floor(cx) + 14
  local py0, py1 = math.floor(cy) - 10, math.floor(cy) + 10
  for y = py0, py1 do
    for x = px0, px1 do
      local cruz = math.abs(x - cx) <= 1 or math.abs(y - cy) <= 1
      if M.get(mapa, x, y) and not cruz then
        local lado = mapa.lado[x] and mapa.lado[x][y]
        setSuelo(mapa, x, y, "plaza", "cicatriz", lado)
        setBloque(mapa, x, y, false)
      end
    end
  end
  mapa.portal = { x = cx + 0.5, y = cy + 0.5 }
  local function cercaCiudad(x, y, margen)
    for _, c in ipairs(mapa.ciudades) do
      if x >= c.x - margen and x < c.x + c.w + margen and y >= c.y - margen and y < c.y + c.h + margen then
        return true
      end
    end
  end
  -- Cordilleras: picos de 2x2 casillas a lo largo de la frontera entre las zonas de
  -- dos ciudades vecinas, con huecos para pasar. Nunca pisan caminos, plazas, costa
  -- ni la cicatriz, así que las ciudades siguen conectadas por los caminos.
  local centros = {}
  for _, c in ipairs(Datos.ciudades) do
    local ccx, ccy = centroCiudad(c)
    centros[#centros + 1] = { x = ccx, y = ccy }
  end
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
      local d1, d2
      for _, c in ipairs(centros) do
        local d = math.sqrt((x - c.x) ^ 2 + (y - c.y) ^ 2)
        if not d1 or d < d1 then d1, d2 = d, d1
        elseif not d2 or d < d2 then d2 = d end
      end
      local ancho = 1.5 + 3.5 * azar(math.floor(x / 6), math.floor(y / 6), 21)
      if d2 and d2 - d1 < ancho and d1 > 14 and azar(math.floor(x / 20), math.floor(y / 20), 22) >= 0.28
        and azar(x, y, 23) < 0.8 and not cercaCiudad(x, y, 10)
        and libre(x, y) and libre(x + 1, y) and libre(x, y + 1) and libre(x + 1, y + 1) then
        for dy = 0, 1 do
          for dx = 0, 1 do
            setSuelo(mapa, x + dx, y + dy, "montana", nil, nil)
            setBloque(mapa, x + dx, y + dy, true)
          end
        end
        mapa.props[#mapa.props + 1] = {
          x = x, y = y, ancho = 2, alto = 2,
          tipo = x < cx and "montana_albor" or "montana_umbra",
        }
      end
    end
  end
  for y = 2, mapa.h - 3 do
    for x = 2, mapa.w - 3 do
      local b = mapa.bioma[x] and mapa.bioma[x][y]
      local s = M.get(mapa, x, y)
      if s and s ~= "camino" and s ~= "plaza" and s ~= "agua" and s ~= "montana" and b ~= "ciudad" and b ~= "costa" and not cercaCiudad(x, y, 6) then
        local bosque = b == "senda" or b == "pinar" or b == "bosque"
        local seco = b == "cienaga" or b == "velo" or b == "eclipse" or b == "cicatriz"
        local mata = (b == "trigal" or b == "campos" or b == "colina") and azar(x, y, 7) < 0.012 and math.sin(x * 0.05) * math.sin(y * 0.05) > 0.3
        if (bosque and azar(x, y, 1) < 0.085) or (seco and azar(x, y, 2) < 0.045) or mata then
          local tipo = "arbol"
          if seco then tipo = "arbol_seco"
          elseif bosque then tipo = "arbol_pino" end
          setBloque(mapa, x, y, true)
          mapa.props[#mapa.props + 1] = { x = x, y = y, tipo = tipo }
        end
      end
    end
  end
  local function punto(bioma)
    for _ = 1, 400 do
      local x = rng:int(2, mapa.w - 3)
      local y = rng:int(2, mapa.h - 3)
      local b = mapa.bioma[x] and mapa.bioma[x][y]
      local s = M.get(mapa, x, y)
      local ok = M.transitable(mapa, x, y) and b == bioma and b ~= "ciudad" and s ~= "camino" and s ~= "plaza"
      if ok and cercaCiudad(x, y, 8) then ok = false end
      if ok and not dentroCiudad(mapa.ciudades, x, y) then return x + 0.5, y + 0.5 end
    end
  end
  for _, mon in ipairs(Datos.monstruos) do
    local camps = mon.elite and 1 or (mon.nivel <= 8 and 3 or 2)
    local cant = mon.elite and 1 or (mon.nivel >= 20 and 1 or 2)
    for _ = 1, camps do
      local x, y = punto(mon.bioma)
      if x then
        mapa.campamentos[#mapa.campamentos + 1] = {
          x = x, y = y, monstruo = mon.id, cantidad = cant, radio = 4,
        }
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
  return mapa
end

function M.batalla()
  local w, h = 96, 64
  local mapa = M.nuevo(w, h)
  local medio = math.floor(h / 2)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local enCalle = math.abs(y - medio) <= 1 or math.abs(x - w / 2) <= 1
      setSuelo(mapa, x, y, enCalle and "camino" or "cicatriz", "cicatriz", nil)
      if x == 0 or y == 0 or x == w - 1 or y == h - 1 then setBloque(mapa, x, y, true) end
    end
  end
  local function base(x0, y0, bw, bh)
    for y = 0, bh - 1 do
      for x = 0, bw - 1 do
        setSuelo(mapa, x0 + x, y0 + y, "plaza", "cicatriz", nil)
        setBloque(mapa, x0 + x, y0 + y, false)
      end
    end
  end
  base(4, medio - 8, 16, 16)
  base(w - 20, medio - 8, 16, 16)
  local function muro(x, faccion, puertaY)
    for y = 1, h - 2 do
      if y ~= puertaY then
        setBloque(mapa, x, y, true)
        setSuelo(mapa, x, y, "muralla", "cicatriz", nil)
      end
    end
    mapa.puerta = mapa.puerta or {}
    mapa.puerta[x .. "_" .. puertaY] = { faccion = faccion, viva = true, x = x, y = puertaY }
    setBloque(mapa, x, puertaY, true)
    setSuelo(mapa, x, puertaY, "camino", "cicatriz", nil)
  end
  muro(22, "albor", medio)
  muro(w - 23, "umbra", medio)
  mapa.spawns = { albor = { x = 8.5, y = medio + 0.5 }, umbra = { x = w - 8.5, y = medio + 0.5 } }
  mapa.objetivos = {
    { tipo = "altar", faccion = "albor", x = 12.5, y = medio + 0.5 },
    { tipo = "altar", faccion = "umbra", x = w - 12.5, y = medio + 0.5 },
    { tipo = "estatua", faccion = "albor", x = 30.5, y = medio - 14.5 },
    { tipo = "estatua", faccion = "albor", x = 30.5, y = medio + 14.5 },
    { tipo = "estatua", faccion = "umbra", x = w - 30.5, y = medio - 14.5 },
    { tipo = "estatua", faccion = "umbra", x = w - 30.5, y = medio + 14.5 },
    { tipo = "puerta", faccion = "albor", x = 22.5, y = medio + 0.5 },
    { tipo = "puerta", faccion = "umbra", x = (w - 23) + 0.5, y = medio + 0.5 },
  }
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

return M
