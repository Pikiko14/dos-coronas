local Datos = require("compartido.dominio.datos")
local Util = require("compartido.dominio.util")
local Continentes = require("compartido.dominio.continentes")

local M = {}
M.NIVEL_ZONAS = 30          -- las ciudades reparten los niveles 1 a 30; del 31 al 50 (nivel máximo) son la isla de la Cicatriz y las mazmorras altas

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
  -- Más grandes que antes (72x56 y 48x36): las casas isométricas son altas y necesitan aire entre ellas y los muros. La ciudad crece
  -- hacia todos lados desde su centro de siempre.
  local w = grande and 84 or 60
  local h = grande and 66 or 46
  local viejoW, viejoH = grande and 72 or 48, grande and 56 or 36
  ciudad.x, ciudad.y = ciudad.x - math.floor((w - viejoW) / 2), ciudad.y - math.floor((h - viejoH) / 2)
  local x0, y0 = ciudad.x, ciudad.y
  ciudad.w, ciudad.h = w, h
  ciudad.npcs = {}
  ciudad.parcelas = {}
  local techo = ciudad.faccion == "umbra" and "teja_umbra" or "teja"
  local puertaTipo = ciudad.faccion == "umbra" and "puerta_hierro" or "puerta"
  local medio = math.floor(w / 2)
  local medioY = math.floor(h / 2)
  -- Ciudad asimétrica: la plaza se desplaza del centro (distinto en cada ciudad) y la avenida horizontal pasa por ella; la vertical
  -- sigue en el eje de los accesos. Así cada ciudad tiene su propio trazado, sin una cruz perfecta.
  local semAsim = 0
  for i = 1, #ciudad.id do semAsim = (semAsim * 31 + ciudad.id:byte(i)) % 9973 end
  local cx = medio + (semAsim % 7) - 3
  local cy = medioY + (math.floor(semAsim / 7) % 5) - 2
  local prx = grande and 8 or 5
  local pry = grande and 6 or 4
  local function avenida(x, y)
    return math.abs(x - medio) <= 2 or math.abs(y - cy) <= 2
  end
  local function enPlaza(x, y)
    return math.abs(x - cx) <= prx and math.abs(y - cy) <= pry
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
  setBloque(mapa, x0 + cx, y0 + cy, true)
  mapa.props[#mapa.props + 1] = {
    x = x0 + cx, y = y0 + cy,
    tipo = ciudad.faccion == "umbra" and "estatua_umbra" or "estatua_albor",
  }
  -- farolas en las cuatro esquinas de la plaza y pozos a los lados
  for _, sx in ipairs({ -1, 1 }) do
    for _, sy in ipairs({ -1, 1 }) do
      local fx, fy = x0 + cx + sx * prx, y0 + cy + sy * pry
      setBloque(mapa, fx, fy, true)
      mapa.props[#mapa.props + 1] = { x = fx, y = fy, tipo = "farol" }
    end
    local px = x0 + cx + sx * (prx - 2)
    setBloque(mapa, px, y0 + cy - pry + 1, true)
    mapa.props[#mapa.props + 1] = { x = px, y = y0 + cy - pry + 1, tipo = (sx < 0) and "pozo" or "barril" }
  end
  -- mobiliario de la plaza: cada cuadrante (las avenidas que la cruzan quedan libres) se amuebla distinto, con una semilla
  -- propia de la ciudad y del cuadrante: filas de bancos de 1 a 3 en sitios distintos, macetas, jarrones, setos, barriles,
  -- cajas, algún pino en las plazas grandes y flores sueltas en el suelo
  do
    local ocupado = {}
    for _, p in ipairs(mapa.props) do ocupado[p.x .. "," .. p.y] = true end
    local fac = ciudad.faccion
    local base = 17
    for i = 1, #ciudad.id do base = (base * 131 + ciudad.id:byte(i)) % 1000003 end
    local function mueble(dx, dy, tipo, solido)
      local tx, ty = x0 + cx + dx, y0 + cy + dy
      if not enPlaza(tx - x0, ty - y0) or avenida(tx - x0, ty - y0) or ocupado[tx .. "," .. ty] then return false end
      ocupado[tx .. "," .. ty] = true
      if solido ~= false then setBloque(mapa, tx, ty, true) end
      mapa.props[#mapa.props + 1] = { x = tx, y = ty, tipo = tipo, fac = fac }
      return true
    end
    local PIEZAS = {
      { "maceta", 3 }, { "jarron", 2 }, { "arbusto", 2 }, { "barril", 1 }, { "caja", 1 }, { "cubo", 1 },
    }
    if grande then PIEZAS[#PIEZAS + 1] = { "arbol_pino", 1 } end
    local totalPiezas = 0
    for _, pz in ipairs(PIEZAS) do totalPiezas = totalPiezas + pz[2] end
    local SUELO = { "flores_mixtas", "flor_roja", "flor_blanca", "flor_amarilla", "matas", "hierba_alta" }
    for qi, par in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
      local sx, sy = par[1], par[2]
      local semillaQ = (base * 7919 + qi * 104729) % 2147483647
      local function azar()
        semillaQ = (semillaQ * 1103515245 + 12345) % 2147483648
        return semillaQ / 2147483648
      end
      local anchoQ, altoQ = prx - 2, pry - 2     -- dx = 3..prx, dy = 3..pry
      -- filas de bancos
      for _ = 1, 1 + math.floor(azar() * 2.4) do
        local largo = 1 + math.floor(azar() * 3)
        local ax = 3 + math.floor(azar() * math.max(1, anchoQ - largo + 1))
        local ay = 3 + math.floor(azar() * altoQ)
        local libre = true
        for k = 0, largo - 1 do if ocupado[(x0 + cx + sx * (ax + k)) .. "," .. (y0 + cy + sy * ay)] then libre = false end end
        if libre then for k = 0, largo - 1 do mueble(sx * (ax + k), sy * ay, "banco") end end
      end
      -- piezas sueltas y flores en lo que queda
      for ay = 3, pry do
        for ax = 3, prx do
          local r = azar()
          if r < 0.30 then
            local pick = azar() * totalPiezas
            for _, pz in ipairs(PIEZAS) do
              pick = pick - pz[2]
              if pick <= 0 then mueble(sx * ax, sy * ay, pz[1]) break end
            end
          elseif r < 0.52 then
            mueble(sx * ax, sy * ay, SUELO[1 + math.floor(azar() * #SUELO)], false)
          end
        end
      end
    end
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
  ciudad.plaza = { x = x0 + cx, y = y0 + cy }
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
  -- Formas de casa: ancho x alto, filas de tejado (techo) y, por columna, cuántas filas se recortan por
  -- arriba (cima). Cada columna lleva su propio tejado sobre su fachada, así las alas más bajas de las
  -- casas en L y en T tienen tejado y no quedan paredes sin cubrir. La puerta va en la fila de abajo.
  local FORMAS = {
    { tamano = "pequena", w = 4, h = 4, techo = 2 },
    { tamano = "mediana", w = 5, h = 4, techo = 2 },
    { tamano = "grande", w = 6, h = 5, techo = 2 },
  }
  local function recorte(forma, xx) return forma.cima and forma.cima[xx + 1] or 0 end
  local function hueco(forma, xx, yy) return yy < recorte(forma, xx) end
  local puertas = {}
  local reservado = {}
  -- Variedad por ciudad: una semilla sacada de su id (cada ciudad se reparte distinto) y un azar repetible.
  local semilla = 0
  for i = 1, #ciudad.id do semilla = (semilla * 31 + ciudad.id:byte(i)) % 9973 end
  local function azar(a, b, c)
    return ((a * 73856093 + b * 19349663 + (c or 0) * 3571 + semilla * 83492791) % 1000003) / 1000003
  end
  -- Decoración (árboles, flores, cajas...). Nunca sobre las avenidas ni la plaza; lo sólido bloquea el paso.
  local ocupado = {}
  local function deco(lx, ly, tipo, solido)
    if lx <= 1 or ly <= 1 or lx >= w - 2 or ly >= h - 2 then return end
    if avenida(lx, ly) or enPlaza(lx, ly) then return end
    local k = lx .. "," .. ly
    if ocupado[k] then return end
    ocupado[k] = true
    if solido ~= false then setBloque(mapa, x0 + lx, y0 + ly, true) end
    mapa.props[#mapa.props + 1] = { x = x0 + lx, y = y0 + ly, tipo = tipo }
  end
  local FLORES = { "flor_amarilla", "flor_blanca", "flor_roja", "flores_mixtas" }
  local function flor(lx, ly, r) deco(lx, ly, FLORES[math.floor(r * 40) % 4 + 1], false) end
  local function rectLibre(rx, ry, rw, rh)
    for yy = ry - 1, ry + rh do
      for xx = rx - 1, rx + rw do
        if xx <= 5 or yy <= 5 or xx >= w - 6 or yy >= h - 6 then return false end
        if avenida(xx, yy) or enPlaza(xx, yy) or reservado[xx .. "," .. yy] then return false end
      end
    end
    return true
  end
  local function reservar(rx, ry, rw, rh)
    for yy = ry - 1, ry + rh do for xx = rx - 1, rx + rw do reservado[xx .. "," .. yy] = true end end
  end
  -- Las casas isométricas son altas: pegadas a un muro lo tapan (o las tapa él). Se dejan SEPARACION casillas de aire entre las
  -- casas y los muros, algo más por el norte y el oeste, donde el muro queda detrás y la casa lo cubre con su tejado.
  local SEP_NO, SEP_SE = 8, 6
  local function libre(forma, ex, ey)
    if ex < SEP_NO or ey < SEP_NO or ex + forma.w > w - SEP_SE or ey + forma.h > h - SEP_SE then return false end
    for yy = 0, forma.h - 1 do
      for xx = 0, forma.w - 1 do
        if not hueco(forma, xx, yy) then
          local lx, ly = ex + xx, ey + yy
          if lx <= 0 or ly <= 0 or lx >= w - 1 or ly >= h - 1 then return false end
          if avenida(lx, ly) or enPlaza(lx, ly) or reservado[lx .. "," .. ly] then return false end
        end
      end
    end
    -- la casilla delante de la puerta (abajo, en el medio) tiene que estar libre para poder entrar
    local fx, fy = ex + math.ceil(forma.w / 2) - 1, ey + forma.h
    if fy >= h - 1 or reservado[fx .. "," .. fy] or M.bloqueado(mapa, x0 + fx + 0.5, y0 + fy + 0.5) then return false end
    return true
  end
  -- Tiendas: una casita de aspecto normal (tejado, fachada con ventanas y puerta) con un letrero de un
  -- icono sobre la puerta que dice qué vende (lo dibuja el cliente, render/dibujo.lua). El PNJ pasea por la
  -- calle delante de su puerta. La puerta da a la avenida. "sur": el local queda al norte y la puerta abajo;
  -- "norte": al sur de la calle y la puerta arriba.
  local function tienda(ex, ey, ancho, alto, rol, nombre, rotulo, frente)
    frente = frente or "sur"
    local puertaFx = math.floor(ancho / 2)
    local puertaFy = frente == "norte" and 0 or (alto - 1)
    local techoFy = frente == "norte" and (alto - 1) or 0
    for yy = 0, alto - 1 do
      for xx = 0, ancho - 1 do
        local puerta = xx == puertaFx and yy == puertaFy
        local lx, ly = ex + xx, ey + yy
        reservado[lx .. "," .. ly] = true
        local tx, ty = x0 + lx, y0 + ly
        if puerta then
          setBloque(mapa, tx, ty, false)
          setSuelo(mapa, tx, ty, "adoquin", "ciudad", ciudad.faccion)
        else
          setBloque(mapa, tx, ty, true)
          setSuelo(mapa, tx, ty, yy == techoFy and techo or "fachada", "ciudad", ciudad.faccion)
        end
      end
    end
    local puertaX, puertaY = x0 + ex + puertaFx, y0 + ey + puertaFy
    mapa.edificios[#mapa.edificios + 1] = {
      x = x0 + ex, y = y0 + ey, w = ancho, h = alto,
      faccion = ciudad.faccion, puertaX = puertaX, puertaY = puertaY,
      techo = 1, techoSur = frente == "norte" or nil, vacio = {}, tienda = rol, rotulo = rotulo,
      estilo = rol == "establo" and "establo" or nil,
    }
    local iy = frente == "norte" and (puertaY - 1) or (puertaY + 1)
    if rol ~= "maestros" then   -- el gremio de maestros no lleva PNJ: los maestros están repartidos por las avenidas
    ciudad.npcs[#ciudad.npcs + 1] = {
      x = puertaX + 0.5, y = iy + 0.5,
      rol = rol, nombre = nombre, faccion = ciudad.faccion,
      ruta = {
        { x = puertaX - 1 + 0.5, y = iy + 0.5 },
        { x = puertaX + 1 + 0.5, y = iy + 0.5 },
      },
    }
    end
    -- el establo: pacas de heno a los lados de la puerta grande
    if rol == "establo" then
      for _, sx in ipairs({ -2, 2 }) do
        setBloque(mapa, puertaX + sx, iy, true)
        mapa.props[#mapa.props + 1] = { x = puertaX + sx, y = iy, tipo = "heno" }
      end
    end
  end
  local altoLocal = 3
  local eyLocal = (cy - 3) - (altoLocal - 1)
  local anchoTienda = 5
  tienda((cx - prx) - anchoTienda - 1, eyLocal, anchoTienda, altoLocal, "mercado", "Enfermera de " .. ciudad.nombre, "Pociones")
  tienda(cx + prx + 2, eyLocal, anchoTienda, altoLocal, "maestros", "Maestros de " .. ciudad.nombre, "Maestros")
  -- El establo, en la misma fila al oeste de la clériga, con el tejado arriba y la puerta a la avenida.
  tienda(3, eyLocal, 9, altoLocal, "establo", "Establo de " .. ciudad.nombre, "Establo")
  -- detrás del establo no se construyen casas: queda un patio despejado
  for yy = eyLocal - 5, eyLocal - 1 do
    for xx = 3 - 1, 3 + 9 do reservado[xx .. "," .. yy] = true end
  end
  -- ...y decorado como corral: heno, abrevadero, barriles, leña, arbustos y flores
  do
    local px0, py0 = 2, eyLocal - 5
    for _, d in ipairs({
      { 0, 0, "arbol_pino" }, { 10, 0, "arbol_pino" }, { 2, 0, "arbusto" }, { 8, 0, "arbusto" }, { 5, 0, "arbusto" },
      { 3, 1, "heno" }, { 4, 1, "heno" }, { 7, 2, "barril" }, { 8, 2, "cubo" }, { 1, 3, "madera_apilada" },
      { 2, 3, "madera_apilada" }, { 9, 3, "caja" }, { 10, 3, "caja" }, { 5, 3, "cubo" }, { 6, 4, "barril" },
      { 1, 1, "matas", false }, { 9, 1, "flores_mixtas", false }, { 4, 3, "hierba_alta", false },
      { 6, 1, "flor_amarilla", false }, { 3, 4, "flor_blanca", false }, { 8, 4, "matas", false },
    }) do deco(px0 + d[1], py0 + d[2], d[3], d[4]) end
  end
  -- Rincones temáticos: cada ciudad tiene los suyos (jardín, huerto, mercadillo, bosquecillo, cementerio...)
  local TEMAS = {}
  TEMAS.jardin = { 9, 7, function(rx, ry, rw, rh)
    for yy = ry, ry + rh - 1 do
      for xx = rx, rx + rw - 1 do
        local r = azar(xx, yy, 1)
        if xx == rx or xx == rx + rw - 1 or yy == ry or yy == ry + rh - 1 then
          if r < 0.55 then deco(xx, yy, "arbusto") end
        elseif r < 0.55 then flor(xx, yy, r) end
      end
    end
    deco(rx + math.floor(rw / 2), ry + math.floor(rh / 2), "pozo")
    deco(rx + 1, ry + 1, "farol")
  end }
  TEMAS.huerto = { 10, 6, function(rx, ry, rw, rh)
    for yy = ry + 1, ry + rh - 2, 2 do
      for xx = rx + 1, rx + rw - 2 do deco(xx, yy, "cultivo", false) end
    end
    deco(rx, ry + rh - 1, "heno")
    deco(rx + rw - 1, ry + rh - 1, "madera_apilada")
  end }
  TEMAS.mercadillo = { 9, 5, function(rx, ry, rw, rh)
    local puestos = { "caja", "barril", "madera_apilada", "cubo" }
    for i = 0, math.floor(rw / 3) - 1 do
      local xx = rx + 1 + i * 3
      deco(xx, ry + 1, puestos[(i + semilla) % 4 + 1])
      deco(xx + 1, ry + 1, puestos[(i + semilla + 1) % 4 + 1])
      deco(xx, ry + 3, puestos[(i + semilla + 2) % 4 + 1])
      deco(xx + 1, ry + 3, "jarron")
    end
    deco(rx + math.floor(rw / 2), ry + 2, "cartel")
  end }
  TEMAS.bosquecillo = { 8, 7, function(rx, ry, rw, rh)
    for yy = ry, ry + rh - 1 do
      for xx = rx, rx + rw - 1 do
        local r = azar(xx, yy, 2)
        if r < 0.3 then deco(xx, yy, r < 0.15 and "arbol_pino" or "arbusto")
        elseif r < 0.5 then deco(xx, yy, "matas", false)
        elseif r < 0.55 then deco(xx, yy, "tocon") end
      end
    end
  end }
  TEMAS.cementerio = { 8, 6, function(rx, ry, rw, rh)
    for yy = ry + 1, ry + rh - 2, 2 do
      for xx = rx + 1, rx + rw - 2, 2 do deco(xx, yy, azar(xx, yy, 3) < 0.25 and "roca" or "tumba") end
    end
    deco(rx, ry, "arbol_seco")
    deco(rx + rw - 1, ry, "arbol_seco")
  end }
  do
    local lista = ciudad.faccion == "umbra" and { "cementerio", "mercadillo", "bosquecillo", "jardin", "huerto" }
      or { "jardin", "huerto", "mercadillo", "bosquecillo" }
    for i = 0, (grande and 2 or 1) do
      local tema = TEMAS[lista[(i + semilla) % #lista + 1]]
      for intento = 1, 80 do
        local rx = 3 + math.floor(azar(intento, i, 4) * (w - tema[1] - 7))
        local ry = 3 + math.floor(azar(intento, i, 5) * (h - tema[2] - 7))
        if rectLibre(rx, ry, tema[1], tema[2]) then
          reservar(rx, ry, tema[1], tema[2])
          tema[3](rx, ry, tema[1], tema[2])
          break
        end
      end
    end
  end
  local function poner(forma, ex, ey)
    local fondo = {}
    for yy = 0, forma.h - 1 do
      for xx = 0, forma.w - 1 do
        if not hueco(forma, xx, yy) and yy == forma.h - 1 then fondo[#fondo + 1] = xx end
      end
    end
    local dx = ex + fondo[math.ceil(#fondo / 2)]
    local dy = ey + forma.h - 1
    local vacio = {}
    for yy = 0, forma.h - 1 do
      for xx = 0, forma.w - 1 do
        local sinCasa = hueco(forma, xx, yy)
        local puerta = xx + ex == dx and yy + ey == dy
        if sinCasa then vacio[xx .. "," .. yy] = true end
        if not sinCasa then
          local tx, ty = x0 + ex + xx, y0 + ey + yy
          if puerta then
            setBloque(mapa, tx, ty, false)
            setSuelo(mapa, tx, ty, "adoquin", "ciudad", ciudad.faccion)
          else
            setBloque(mapa, tx, ty, true)
            setSuelo(mapa, tx, ty, (yy - recorte(forma, xx)) < forma.techo and techo or "fachada", "ciudad", ciudad.faccion)
          end
        end
      end
    end
    mapa.edificios[#mapa.edificios + 1] = {
      x = x0 + ex, y = y0 + ey, w = forma.w, h = forma.h,
      faccion = ciudad.faccion, puertaX = x0 + dx, puertaY = y0 + dy,
      techo = forma.techo, vacio = vacio, tamano = forma.tamano, cima = forma.cima,
    }
    puertas[#puertas + 1] = { x = x0 + dx, y = y0 + dy, tamano = forma.tamano }
    -- una casilla libre alrededor de cada casa (y delante de su puerta): las demás no se pegan a ella
    -- (dos casillas de aire alrededor: las casas isométricas son altas y, más juntas, se tapan unas a otras)
    for yy = ey - 2, ey + forma.h + 1 do
      for xx = ex - 2, ex + forma.w + 1 do reservado[xx .. "," .. yy] = true end
    end
  end
  local n = 0
  -- la rejilla de casas arranca en un punto distinto en cada ciudad pequeña y deja algunas parcelas vacías
  local cx0, cy0 = grande and 2 or (2 + semilla % 3), grande and 2 or (2 + math.floor(semilla / 3) % 3)
  for ey = cy0, h - 7, 7 do
    for ex = cx0, w - 9, 9 do
      n = n + 1
      local puesta = (not grande) and azar(ex, ey, 6) < 0.2
      for k = 0, #FORMAS - 1 do
        if puesta then break end
        local forma = FORMAS[((n + k - 1 + (grande and 0 or semilla)) % #FORMAS) + 1]
        if libre(forma, ex, ey) then poner(forma, ex, ey) puesta = true break end
      end
      if not puesta and libre(FORMAS[1], ex, ey) then poner(FORMAS[1], ex, ey) end
    end
  end
  -- Ciudades pequeñas: las casas de la rejilla dejan huecos grandes; se rellenan con más casas donde caben.
  if not grande then
    local eys, exs = {}, {}
    for ey = 2, h - 6 do eys[#eys + 1] = ey end
    for ex = 2, w - 8 do exs[#exs + 1] = ex end
    local function invertir(l) local r = {} for i = #l, 1, -1 do r[#r + 1] = l[i] end return r end
    if semilla % 2 == 1 then eys = invertir(eys) end
    if math.floor(semilla / 2) % 2 == 1 then exs = invertir(exs) end
    for _, ey in ipairs(eys) do
      for _, ex in ipairs(exs) do
        n = n + 1
        if azar(ex, ey, 7) > 0.15 then
          for k = 0, #FORMAS - 1 do
            local forma = FORMAS[((n + k - 1 + semilla) % #FORMAS) + 1]
            if libre(forma, ex, ey) then poner(forma, ex, ey) break end
          end
        end
      end
    end
  end
  -- Ciudades grandes: un lago a cada lado de la avenida, en el espacio verde de debajo de las últimas casas
  if grande then
    for _, cxl in ipairs({ medio - 17, medio + 17 }) do
      local cyl, rxl, ryl = h - 5, 11, 2.6
      for yy = cyl - 4, cyl + 4 do
        for xx = cxl - rxl - 2, cxl + rxl + 2 do
          if xx >= 3 and xx <= w - 4 and yy >= 3 and yy <= h - 3
            and not avenida(xx, yy) and not enPlaza(xx, yy) and not reservado[xx .. "," .. yy] then
            local d = ((xx - cxl) / rxl) ^ 2 + ((yy - cyl) / ryl) ^ 2 + (azar(xx, yy, 15) - 0.5) * 0.25
            if d <= 1 then
              setSuelo(mapa, x0 + xx, y0 + yy, "agua", "ciudad", ciudad.faccion)
              reservado[xx .. "," .. yy] = true
              ocupado[xx .. "," .. yy] = true
            elseif d <= 1.55 then
              setSuelo(mapa, x0 + xx, y0 + yy, "arena", "ciudad", ciudad.faccion)
              reservado[xx .. "," .. yy] = true
              ocupado[xx .. "," .. yy] = true
            end
          end
        end
      end
    end
  end
  -- Detalles: macetas junto a las puertas, árboles y faroles a los lados de las avenidas y flores sueltas
  for i, pu in ipairs(puertas) do
    local lx, ly = pu.x - x0, pu.y - y0
    local r = azar(lx, ly, 8)
    if r < 0.5 then deco(lx - 1, ly + 1, ({ "jarron", "cubo", "matas" })[i % 3 + 1], i % 3 == 2 and false or nil) end
    if r > 0.3 and r < 0.8 then deco(lx + 1, ly + 1, ({ "barril", "jarron", "flores_mixtas" })[i % 3 + 1], i % 3 == 2 and false or nil) end
  end
  local function calle(lx, ly, i)
    if reservado[lx .. "," .. ly] then return end
    if i % 3 == 0 then deco(lx, ly, "farol") else deco(lx, ly, i % 3 == 1 and "arbol_pino" or "arbusto") end
  end
  do
    local i = 0
    for yy = 3 + semilla % 3, h - 4, 4 do
      i = i + 1
      calle(medio - 4, yy, i)
      calle(medio + 4, yy, i + 1)
    end
    for xx = 3 + semilla % 3, w - 4, 4 do
      i = i + 1
      calle(xx, cy - 4, i)
      calle(xx, cy + 4, i + 1)
    end
  end
  for yy = 3, h - 4 do
    for xx = 3, w - 4 do
      if not reservado[xx .. "," .. yy] and azar(xx, yy, 9) < 0.06 then flor(xx, yy, azar(xx, yy, 10)) end
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
    ciudad.parcelas[n] = { id = ciudad.id .. "_" .. n, x = p.x, y = p.y, dueno = nil, tamano = p.tamano or "mediana" }
  end
  for i = 1, #puertas do tomar(i) end
  local function npc(nx, ny, rol, nombre)
    ciudad.npcs[#ciudad.npcs + 1] = {
      x = x0 + nx + 0.5, y = y0 + ny + 0.5,
      rol = rol, nombre = nombre, faccion = ciudad.faccion,
    }
  end
  -- Los PNJ se reparten por las avenidas de la ciudad, no en el centro de la plaza.
  local k = grande and 1.5 or 1
  -- (los PNJ van siempre sobre una avenida: a lo largo de la vertical con x entre -2 y 2 del eje, a lo largo de la horizontal con y entre -2 y 2)
  local function en(dx, dy)
    local ax, ay = math.floor(dx * k), math.floor(dy * k)
    if math.abs(ay) >= math.abs(ax) then ax = math.max(-2, math.min(2, ax)) else ay = math.max(-2, math.min(2, ay)) end
    return medio + ax, cy + ay
  end
  local function npcEn(dx, dy, rol, nombre)
    local nx, ny = en(dx, dy)
    npc(nx, ny, rol, nombre)
  end
  npc(cx + 2, cy, "heraldo", "Heraldo")   -- al lado de la estatua de la plaza
  do
    local clases = ciudad.faccion == "umbra" and { "guerrero", "nigromante", "cazador", "mago", "clerigo" }
      or { "guerrero", "lancero", "cazador", "mago", "clerigo" }
    local NOMBRES = { guerrero = "Guerrero", lancero = "Lancero", cazador = "Arquero", mago = "Mago", clerigo = "Clérigo", nigromante = "Nigromante" }
    local FEM = { guerrero = "Guerrera", lancero = "Lancera", cazador = "Arquera", mago = "Maga", clerigo = "Clériga", nigromante = "Nigromante" }
    -- repartidos por los extremos de las avenidas, lejos unos de otros: { horizontal?, fracción del largo, desvío en la avenida }
    local SITIOS = { { true, -0.85, 1 }, { true, 0.85, -1 }, { false, -0.8, 1 }, { false, 0.8, -1 }, { true, 0.45, 1 } }
    for i, c in ipairs(clases) do
      local mujer = (i + (ciudad.faccion == "umbra" and 1 or 0)) % 2 == 0
      local st = SITIOS[i]
      local nx, ny
      if st[1] then nx, ny = medio + math.floor(st[2] * (medio - 6)), cy + st[3]
      else nx, ny = medio + st[3], cy + math.floor(st[2] * (cy - 5)) end
      npc(nx, ny, "maestro_" .. c, (mujer and "Maestra " .. FEM[c] or "Maestro " .. NOMBRES[c]) .. " de " .. ciudad.nombre)
    end
  end
  -- el mercader mayor, en la esquina oeste de la plaza (junto a la acera, lejos de la estatua)
  npc(cx - prx + 1, cy + pry - 1, "comercio", "Mercader mayor")
  npcEn(-2, -9, "mayordomo", "Mayordomo")
  npcEn(2, -9, "encargos", "Tablón de encargos")
  npcEn(-2, 9, "encantador", "Maestro de encantos")
  npcEn(-17, 0, "gremio", "Escribano del gremio")
  npcEn(17, 0, "oficios", "Maestro de oficios")
  npcEn(-14, 2, "subastas", "Subastador")
  local gy = (ciudad.acceso == "norte" and not grande) and 2 or (h - 3)
  npc(medio - 2, gy, "guardia", "Guardia de " .. ciudad.nombre)
  npc(medio + 2, gy, "guardia", "Guardia de " .. ciudad.nombre)
  -- Vecinos: dan vida a las avenidas yendo y viniendo (no venden nada y no salen en el mapa).
  local NOMBRES_VECINOS = { "Vecino", "Vecina", "Aldeano", "Aldeana", "Campesino", "Panadera", "Pescador", "Anciano", "Niña", "Leñador" }
  for i = 1, grande and 8 or 5 do
    local lado = (i + semilla) % 4
    local o = ({ -2, -1, 1, 2, 0 })[(i + semilla) % 5 + 1]
    local a, b
    if lado == 0 then
      local ya = 3 + math.floor(azar(i, 1, 11) * math.max(1, cy - pry - 9))
      a, b = { x = medio + o, y = ya }, { x = medio + o, y = ya + 5 }
    elseif lado == 1 then
      local ya = cy + pry + 3 + math.floor(azar(i, 1, 12) * math.max(1, h - cy - pry - 10))
      a, b = { x = medio + o, y = ya }, { x = medio + o, y = ya + 5 }
    elseif lado == 2 then
      local xa = 3 + math.floor(azar(i, 1, 13) * math.max(1, medio - prx - 9))
      a, b = { x = xa, y = cy + o }, { x = xa + 5, y = cy + o }
    else
      local xa = medio + prx + 3 + math.floor(azar(i, 1, 14) * math.max(1, w - medio - prx - 10))
      a, b = { x = xa, y = cy + o }, { x = xa + 5, y = cy + o }
    end
    if not M.bloqueado(mapa, x0 + a.x + 0.5, y0 + a.y + 0.5) and not M.bloqueado(mapa, x0 + b.x + 0.5, y0 + b.y + 0.5) then
      ciudad.npcs[#ciudad.npcs + 1] = {
        x = x0 + a.x + 0.5, y = y0 + a.y + 0.5, rol = "aldeano",
        nombre = NOMBRES_VECINOS[(i + semilla) % #NOMBRES_VECINOS + 1], faccion = ciudad.faccion,
        ruta = { { x = x0 + a.x + 0.5, y = y0 + a.y + 0.5 }, { x = x0 + b.x + 0.5, y = y0 + b.y + 0.5 } },
      }
    end
  end
  -- Ningún edificio ha de tapar a un PNJ: una casa dibujada delante (al sur o al este) esconde a quien está detrás. Quien quede a la
  -- sombra de una casa se corre a la casilla de avenida o plaza más cercana que esté a la vista.
  local function tapado(wx, wy)
    for _, b in ipairs(mapa.edificios) do
      for a = 0, 3 do
        for c = 0, 3 do
          if math.abs(a - c) <= 1 then
            local px, py = math.floor(wx) + a, math.floor(wy) + c
            if px >= b.x and px < b.x + b.w and py >= b.y and py < b.y + b.h then return true end
          end
        end
      end
    end
    return false
  end
  local ocupadas = {}
  for _, n in ipairs(ciudad.npcs) do ocupadas[#ocupadas + 1] = n end
  for _, n in ipairs(ciudad.npcs) do
    if n.rol ~= "guardia" and (tapado(n.x, n.y) or M.bloqueado(mapa, n.x, n.y)) then
      local mejor, md = nil, 1e9
      for dy = -7, 7 do
        for dx = -7, 7 do
          local wx, wy = math.floor(n.x) + dx + 0.5, math.floor(n.y) + dy + 0.5
          local lx, ly = wx - x0, wy - y0
          local d = dx * dx + dy * dy
          if d < md and (avenida(lx, ly) or enPlaza(lx, ly)) and not M.bloqueado(mapa, wx, wy) and not tapado(wx, wy) then
            local libre = true
            for _, o in ipairs(ocupadas) do
              if o ~= n and math.abs(o.x - wx) < 1.2 and math.abs(o.y - wy) < 1.2 then libre = false break end
            end
            if libre then mejor, md = { wx, wy }, d end
          end
        end
      end
      if mejor then
        local ddx, ddy = mejor[1] - n.x, mejor[2] - n.y
        n.x, n.y = mejor[1], mejor[2]
        for _, r in ipairs(n.ruta or {}) do r.x, r.y = r.x + ddx, r.y + ddy end
      end
    end
  end
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
  -- 5) puertos: cada puerto es un muelle en la costa con su barco y su barquero (se construyen al final, con los puestos)
  mapa.puertos = {}
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
      local bx, by, bw, bh = c.x, c.y, c.w, c.h
      if x >= bx - margen and x < bx + bw + margen and y >= by - margen and y < by + bh + margen then
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
        if (bosque and azar(x, y, 1) < pb) or mata then
          local tipo = bosque and "arbol_pino" or "arbol"
          setBloque(mapa, x, y, true)
          mapa.props[#mapa.props + 1] = { x = x, y = y, tipo = tipo }
        end
        -- El árbol seco salía cortado: no se coloca. Los huevos y los restos sí frenan el paso.
        if seco and not (mapa.bloque[x] and mapa.bloque[x][y]) then
          local solido
          if azar(x, y, 31) < 0.02 then solido = "huevo"
          else
            local listas = {
              eclipse = { { "grieta", 0.04 }, { "piedra", 0.025 }, { "hierba_seca", 0.025 } },
              cicatriz = { { "grieta", 0.045 }, { "piedra", 0.025 } },
            }
            local lista = listas[b]
            if lista then
              local r, acum = azar(x, y, 7), 0
              for _, d in ipairs(lista) do
                acum = acum + d[2]
                if r < acum then
                  if d[1] == "restos" then solido = "restos" end
                  break
                end
              end
            end
          end
          if solido then
            setBloque(mapa, x, y, true)
            mapa.adorno = mapa.adorno or {}
            mapa.adorno[x] = mapa.adorno[x] or {}
            mapa.adorno[x][y] = solido
          end
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
    -- el PNJ de misiones del puesto (compartido/dominio/misiones.lua): da encargos de cazar, recolectar y entregar por la zona
    local nombreMisiones = ({ comercio = "Guardacaminos", cazadores = "Rastreador", ladrones = "Informante", torre = "Aprendiz de la torre", ermita = "Ermitaño" })[tipo]
    if nombreMisiones then
      local o = sitios[#roles + 1] or { 0, 3 }
      pu.npcs[#pu.npcs + 1] = { x = px + o[1] + 0.5, y = py + o[2] + 0.5, rol = "misiones", nombre = nombreMisiones, faccion = lado }
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
          -- sin PNJ: el comercio y las monturas solo se atienden en las ciudades
          nuevoPuesto("comercio", "Puesto del camino", x, y, {})
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
    { { "capitan", "Capitán de cazadores" } }, 30)
  repartir(4, { "marea", "cienaga", "eclipse", "muelle", "velo" }, "ladrones", "Refugio de ladrones",
    { { "contacto", "Contacto en las sombras" } }, 40)
  repartir(2, { "velo", "campos", "colina" }, "torre", "Torre de encantos",
    { { "encantador", "Maestro de encantos" } }, 40)
  repartir(2, { "trigal", "senda", "cienaga" }, "ermita", "Ermita", {}, 40)
  -- Muelles: cada puerto (Puerto del Sol, Puerto Sombra y el embarcadero de la Cicatriz) tiene un embarcadero de
  -- madera que se adentra en el mar desde la orilla más cercana, con un barco amarrado, un bote y su barquero.
  local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
  local function orilla(x0, y0, cont)
    local mejor, md
    for y = math.max(14, y0 - 150), math.min(mapa.h - 15, y0 + 150) do
      for x = math.max(14, x0 - 150), math.min(mapa.w - 15, x0 + 150) do
        if mapa.cont[x][y] == cont and M.transitable(mapa, x, y) and M.get(mapa, x, y) ~= "agua" and mapa.bioma[x][y] ~= "ciudad" then
          local d = (x - x0) ^ 2 + (y - y0) ^ 2
          if not md or d < md then
            for _, dir in ipairs(DIRS) do
              local ok = true
              for i = 1, 14 do
                for w = -4, 4 do
                  if M.get(mapa, x + dir[1] * i - dir[2] * w, y + dir[2] * i + dir[1] * w) ~= "agua" then ok = false break end
                end
                if not ok then break end
              end
              -- y el arranque en tierra firme, sin ciudad ni camino cortado
              if ok and M.transitable(mapa, x - dir[1], y - dir[2]) then mejor, md = { x = x, y = y, dx = dir[1], dy = dir[2] }, d break end
            end
          end
        end
      end
    end
    return mejor
  end
  local function muelle(id, nombre, x0, y0, cont, faccion)
    local o = orilla(x0, y0, cont)
    if not o then return end
    local px, py = -o.dy, o.dx
    limpiar(o.x, o.y, 3)
    for i = 0, 12 do
      local ancho = i >= 10 and 3 or 1
      for w = -ancho, ancho do
        local x, y = o.x + o.dx * i + px * w, o.y + o.dy * i + py * w
        setSuelo(mapa, x, y, "madera", "muelle", nil)
        mapa.cont[x][y] = cont
        setBloque(mapa, x, y, false)
      end
    end
    -- farolas en las esquinas del final, un cartel y cajas en el arranque
    for _, w in ipairs({ -3, 3 }) do
      local x, y = o.x + o.dx * 12 + px * w, o.y + o.dy * 12 + py * w
      mapa.props[#mapa.props + 1] = { x = x, y = y, tipo = "farol" }
      setBloque(mapa, x, y, true)
    end
    mapa.props[#mapa.props + 1] = { x = o.x - o.dx + px * 2, y = o.y - o.dy + py * 2, tipo = "cartel" }
    mapa.props[#mapa.props + 1] = { x = o.x + o.dx * 2 - px * 2, y = o.y + o.dy * 2 - py * 2, tipo = "caja" }
    -- el barco, amarrado junto al final del muelle, y un bote más cerca de tierra
    mapa.props[#mapa.props + 1] = { x = o.x + o.dx * 9 + px * 5, y = o.y + o.dy * 9 + py * 5, tipo = "barco", rx = o.dx, ry = o.dy }
    mapa.props[#mapa.props + 1] = { x = o.x + o.dx * 4 - px * 3, y = o.y + o.dy * 4 - py * 3, tipo = "bote", rx = o.dx, ry = o.dy }
    local npc = { x = o.x + o.dx * 4 + 0.5, y = o.y + o.dy * 4 + 0.5, rol = "barquero", nombre = "Barquero de " .. nombre, faccion = faccion }
    local pu = { id = #mapa.puestos + 1, tipo = "muelle", nombre = "Muelle de " .. nombre, x = o.x, y = o.y, npcs = { npc } }
    mapa.puestos[#mapa.puestos + 1] = pu
    mapa.puertos[#mapa.puertos + 1] = {
      id = id, nombre = "Muelle de " .. nombre, x = o.x + o.dx * 6 + 0.5, y = o.y + o.dy * 6 + 0.5, cont = cont, faccion = faccion,
    }
    return o
  end
  for _, c in ipairs(mapa.ciudades) do
    if c.puerto then muelle(c.id, c.nombre, c.x + math.floor(c.w / 2), c.y + math.floor(c.h / 2), c.cont, c.faccion) end
  end
  -- el de la isla de la Cicatriz, al sur de su centro
  if mapa.cont[math.floor(cx)][math.floor(cy)] == 3 then
    local o = muelle("cicatriz", "la Cicatriz", math.floor(cx), math.floor(cy) + 26, 3, nil)
    if o then linea(math.floor(cx), math.floor(cy) + 10, o.x, o.y) end
  end
  -- 3) lista de todos los PNJ para los iconos del mapa
  mapa.npcsMapa = {}
  for _, c in ipairs(mapa.ciudades) do
    for _, n in ipairs(c.npcs) do
      if n.rol ~= "guardia" and n.rol ~= "aldeano" then mapa.npcsMapa[#mapa.npcsMapa + 1] = { x = n.x, y = n.y, rol = n.rol, nombre = n.nombre } end
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
  -- Campamentos de criaturas. Cada ciudad de un continente se ESPECIALIZA en un tramo de niveles (su "banda"): la capital en
  -- el primero (1-6 si hay cinco ciudades), la siguiente en el segundo... hasta el último (25-30). Así, caminando desde una
  -- ciudad, las criaturas de alrededor son de su banda y el nivel sube poco a poco hacia las ciudades de la banda vecina: nunca
  -- se pasa de un nivel 1 a un nivel 29 en unos pasos. Las bandas se reparten para que las ciudades unidas por camino tengan
  -- bandas lo más parecidas posible (se prueban todos los órdenes, con la capital siempre en la primera).
  local bandas = {}
  do
    for _, k in pairs(mapa.continentes) do
      local ciudades = {}
      for _, cid in ipairs(k.ciudades or {}) do
        for _, c in ipairs(mapa.ciudades) do if c.id == cid then ciudades[#ciudades + 1] = c end end
      end
      local n = #ciudades
      if n >= 1 then
        table.sort(ciudades, function(a, b) return a.id < b.id end)
        local capital = 1
        for i, c in ipairs(ciudades) do if c.capital then capital = i end end
        -- caminos entre las ciudades de este continente
        local aristas = {}
        for _, cam in ipairs(mapa.caminos or {}) do
          local ia, ib
          for i, c in ipairs(ciudades) do
            if c.id == cam.a then ia = i end
            if c.id == cam.b then ib = i end
          end
          if ia and ib then aristas[#aristas + 1] = { ia, ib } end
        end
        local function costo(orden)         -- orden[i] = posición (banda) de la ciudad i
          local t = 0
          for _, e in ipairs(aristas) do t = t + math.abs(orden[e[1]] - orden[e[2]]) end
          return t
        end
        local mejorOrden, mejorCosto
        local usado, orden = {}, {}
        local function permutar(i)
          if i > n then
            local c = costo(orden)
            if not mejorCosto or c < mejorCosto then mejorCosto, mejorOrden = c, { unpack(orden) } end
            return
          end
          if i == capital then
            orden[i] = 1
            usado[1] = true
            permutar(i + 1)
            usado[1] = nil
            return
          end
          for pos = 2, n do
            if not usado[pos] then
              usado[pos] = true
              orden[i] = pos
              permutar(i + 1)
              usado[pos] = nil
            end
          end
        end
        if n == 1 then mejorOrden = { 1 } else permutar(1) end
        for i, c in ipairs(ciudades) do
          local p = mejorOrden[i]
          -- las ciudades reparten los niveles 1 a 30 (6 por banda); del 31 al 50 son la isla de la Cicatriz y las mazmorras altas
          local lo = math.floor((p - 1) * M.NIVEL_ZONAS / n) + 1
          local hi = math.floor(p * M.NIVEL_ZONAS / n)
          bandas[c.id] = { lo = lo, hi = hi, mid = (lo + hi) / 2, orden = p }
          c.nivelMin, c.nivelMax = lo, hi
        end
      end
    end
  end
  M.bandas = bandas
  local function puntoCerca(c, dmin, dmax, nivelBuscado)
    local ccx, ccy = c.x + c.w / 2, c.y + c.h / 2
    for _ = 1, 400 do
      local ang = rng:int(0, 359) * math.pi / 180
      local d = rng:int(dmin, dmax)
      local x, y = math.floor(ccx + math.cos(ang) * d), math.floor(ccy + math.sin(ang) * d)
      if x > 2 and y > 2 and x < mapa.w - 3 and y < mapa.h - 3 then
        local s = M.get(mapa, x, y)
        local b = mapa.bioma[x] and mapa.bioma[x][y]
        local ok = M.transitable(mapa, x, y) and mapa.cont[x][y] == c.cont and b ~= "ciudad" and b ~= "cicatriz" and s ~= "camino" and s ~= "plaza"
        if ok and cercaCiudad(x, y, 10) then ok = false end
        if ok and cercaDePuesto(x, y, 12) then ok = false end
        if ok and nivelBuscado and math.abs(M.nivelZona(x, y) - nivelBuscado) > M.TOLERANCIA_NIVEL then ok = false end
        if ok then return x + 0.5, y + 0.5 end
      end
    end
  end
  -- Nivel de la zona en un punto: mezcla suave de las bandas de las ciudades de su continente (cada una pesa más cuanto más
  -- cerca está), así junto a una ciudad manda su banda y entre dos ciudades el nivel sube o baja poco a poco.
  local function nivelZona(x, y)
    local k = mapa.cont[math.floor(x)] and mapa.cont[math.floor(x)][math.floor(y)]
    if k == 3 then return Datos.NIVEL_MAX - 2 end   -- la isla de la Cicatriz es la zona de guerra: siempre alta
    local num, den = 0, 0
    for _, c in ipairs(mapa.ciudades) do
      local b = bandas[c.id]
      if b and (k == c.cont or k == nil or k > 2) then
        -- (el -6 compensa lo que creció la ciudad: los niveles de la zona siguen igual medidos desde su borde)
        local d = math.max(4, math.sqrt((c.x + c.w / 2 - x) ^ 2 + (c.y + c.h / 2 - y) ^ 2) + 14 - 6)
        local w = 1 / (d * d * d)
        num = num + w * b.mid
        den = den + w
      end
    end
    if den == 0 then return 1 end
    return math.max(1, math.min(Datos.NIVEL_MAX, math.floor(num / den + 0.5)))
  end
  M.nivelZona = nivelZona
  M.TOLERANCIA_NIVEL = 3     -- una banda ancha (6 niveles) deja el nivel de la zona a ±3 del de sus criaturas
  for _, mon in ipairs(Datos.monstruos) do
    if not mon.noCampamento then
      local cant = mon.elite and 2 or (mon.nivel <= 8 and 4 or 3)
      for _, c in ipairs(mapa.ciudades) do
        local b = bandas[c.id]
        -- solo las ciudades cuya banda incluye (o roza) el nivel de la criatura
        if b and mon.nivel >= b.lo - 1 and mon.nivel <= b.hi + 1 then
          local propia = mon.bioma == c.bioma
          local camps = mon.elite and (propia and 1 or 0) or (propia and 3 or 2)
          for _ = 1, camps do
            local x, y = puntoCerca(c, 24, 140, mon.nivel)
            if x then
              mapa.campamentos[#mapa.campamentos + 1] = {
                x = x, y = y, monstruo = mon.id, cantidad = cant, radio = 4, ciudad = c.id,
              }
            end
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
            local nivel = nivelZona(x, y)
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
      if not mon.noCampamento and not mon.elite and mon.nivel > M.NIVEL_ZONAS then altas[#altas + 1] = mon end
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
  -- Jefes del mundo (monstruos.xml: jefeMundo + continente): uno por zona, cinco por continente, siempre en el mismo sitio. Para cada uno se
  -- rastrea su continente en orden fijo y se queda con el punto despejado cuyo nivel de zona se parece más al suyo, lejos de ciudades, puestos y
  -- de los demás jefes. Salen solos (cantidad 1) con su aura; al caer reaparecen como cualquier élite.
  mapa.jefes = {}
  do
    local lista = {}
    for _, mon in ipairs(Datos.monstruos) do
      if mon.jefeMundo then lista[#lista + 1] = mon end
    end
    table.sort(lista, function(a, b)
      if a.continente ~= b.continente then return a.continente < b.continente end
      return a.nivel < b.nivel
    end)
    local function lejosDeJefes(x, y, d)
      for _, j in ipairs(mapa.jefes) do
        if (j.x - x) ^ 2 + (j.y - y) ^ 2 < d * d then return false end
      end
      return true
    end
    for _, mon in ipairs(lista) do
      local mejor, mejorPuntos
      for y = 20, mapa.h - 20, 6 do
        for x = 20, mapa.w - 20, 6 do
          local k = mapa.cont[x] and mapa.cont[x][y]
          if k == mon.continente and areaBuena(x, y, 4) and not cercaCiudad(x, y, 18) and not cercaDePuesto(x, y, 16) and lejosDeJefes(x, y, 70) then
            local puntos = math.abs(nivelZona(x, y) - mon.nivel) * 100 + math.abs(x - mapa.w / 2) * 0.01
            if not mejorPuntos or puntos < mejorPuntos then mejorPuntos, mejor = puntos, { x, y } end
          end
        end
      end
      if mejor then
        mapa.jefes[#mapa.jefes + 1] = { id = mon.id, nombre = mon.nombre, nivel = mon.nivel, continente = mon.continente, x = mejor[1] + 0.5, y = mejor[2] + 0.5 }
        mapa.campamentos[#mapa.campamentos + 1] = { x = mejor[1] + 0.5, y = mejor[2] + 0.5, monstruo = mon.id, cantidad = 1, radio = 3, jefe = true }
      end
    end
  end
  mapa.escaleras = {}
  mapa.alto = {}
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
  -- La puerta de cada mazmorra está SIEMPRE en el mismo sitio: se busca sin azar, rastreando el continente indicado en
  -- mazmorras.xml en orden fijo, y se queda con el punto despejado cuyo nivel de zona se parece más al nivel de la mazmorra.
  -- Así no se mueve aunque cambie cualquier otra parte de la generación del mapa.
  local function sitioFijoMazmorra(def)
    local mejor, mejorPuntos
    for y = 20, mapa.h - 20, 6 do
      for x = 20, mapa.w - 20, 6 do
        local k = mapa.cont[x] and mapa.cont[x][y]
        if k == (def.continente or 1) and areaBuena(x, y, 4) and not cercaCiudad(x, y, 26) and not cercaDePuesto(x, y, 20) and lejosDeOtras(x, y, 110) then
          local puntos = math.abs(M.nivelZona(x, y) - (def.nivelMin or 1)) * 100 + math.abs(x - mapa.w / 2) * 0.01
          if not mejorPuntos or puntos < mejorPuntos then mejorPuntos, mejor = puntos, { x, y } end
        end
      end
    end
    if mejor then return mejor[1], mejor[2] end
  end
  for _, def in ipairs(Datos.mazmorras) do
    local x, y = sitioFijoMazmorra(def)
    for _, d in ipairs({ 260, 160, 80, 0 }) do
      if x then break end
      for _, biomas in ipairs({ def.biomas, TODOS }) do
        for _ = 1, 25 do
          x, y = buscarSitio(biomas, 26, 20)
          if x and lejosDeOtras(x, y, d) then break end
          x = nil
        end
        if x then break end
      end
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
  local cx = w / 2
  mapa.decorado = {}
  local function umbra(x) return x >= cx end
  local function lado(x) return umbra(x) and "umbra" or nil end
  -- zona de guerra del centro: una franja quemada de borde irregular entre los dos reinos
  local function mitadFranja(y) return 11 + 3 * math.sin(y * 0.2) + 2 * math.sin(y * 0.47 + 1) end
  local function enGuerra(x, y) return math.abs(x + 0.5 - cx) <= mitadFranja(y) end
  local reservado = {}
  local function reservar(x, y, r)
    r = r or 0
    for dx = -r, r do
      for dy = -r, r do reservado[(x + dx) * 1000 + (y + dy)] = true end
    end
  end
  local function esReservado(x, y) return reservado[x * 1000 + y] end

  -- 1) suelo: Alba (hierba clara) al oeste, Umbra (hierba oscura) al este y la tierra quemada en medio
  -- (bioma "batalla": sin la decoración al azar del resto del mundo; todo se coloca a mano)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      if enGuerra(x, y) then setSuelo(mapa, x, y, "cicatriz", "batalla", lado(x))
      elseif umbra(x) then setSuelo(mapa, x, y, "hierba_osc", "batalla", "umbra")
      else setSuelo(mapa, x, y, "hierba", "batalla", nil) end
      if x == 0 or y == 0 or x == w - 1 or y == h - 1 then setBloque(mapa, x, y, true) end
    end
  end
  local function base(x0, y0, bw, bh)
    for y = 0, bh - 1 do
      for x = 0, bw - 1 do
        setSuelo(mapa, x0 + x, y0 + y, "plaza", "batalla", lado(x0 + x))
        setBloque(mapa, x0 + x, y0 + y, false)
      end
    end
  end
  base(4, medio - 8, 16, 16)
  base(w - 20, medio - 8, 16, 16)
  for y = 1, h - 2 do
    for x = 1, 23 do reservar(x, y) end
    for x = w - 24, w - 2 do reservar(x, y) end
  end
  -- Cada muro tiene varias entradas: la puerta principal en el centro y dos laterales.
  local ENTRADAS = { medio, medio - 14, medio + 14 }
  local function muro(x, faccion)
    local esPuerta = {}
    for _, py in ipairs(ENTRADAS) do esPuerta[py] = true end
    for y = 1, h - 2 do
      if not esPuerta[y] then
        setBloque(mapa, x, y, true)
        setSuelo(mapa, x, y, "muralla", "batalla", lado(x))
      end
    end
    mapa.puerta = mapa.puerta or {}
    for _, py in ipairs(ENTRADAS) do
      mapa.puerta[x .. "_" .. py] = { faccion = faccion, viva = true, x = x, y = py }
      setBloque(mapa, x, py, true)
      setSuelo(mapa, x, py, "camino", "batalla", lado(x))
    end
  end
  muro(22, "albor")
  muro(w - 23, "umbra")
  mapa.spawns = { albor = { x = 8.5, y = medio + 0.5 }, umbra = { x = w - 8.5, y = medio + 0.5 } }
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
  for _, o in ipairs(mapa.objetivos) do reservar(math.floor(o.x), math.floor(o.y), 3) end

  local function decor(x, y, tipo)
    mapa.decorado[x] = mapa.decorado[x] or {}
    mapa.decorado[x][y] = tipo
    setBloque(mapa, x, y, true)
  end
  local function prop(x, y, tipo, bloquea)
    mapa.props[#mapa.props + 1] = { x = x, y = y, tipo = tipo }
    if bloquea then setBloque(mapa, x, y, true) end
  end

  -- 2) caminos que serpentean desde cada puerta hasta la plaza central, y la plaza en ruinas
  local function camino(xa, ya, xb, yb, ancho, amp, fase)
    local dir = xb >= xa and 1 or -1
    local n = math.abs(xb - xa)
    local anterior
    for i = 0, n do
      local x = xa + i * dir
      local t = n > 0 and i / n or 0
      local s = t * t * (3 - 2 * t)
      local y = math.floor(ya + (yb - ya) * s + amp * math.sin(t * math.pi * 2 + fase) * math.sin(t * math.pi) + 0.5)
      local desde, hasta = y, y
      if anterior then desde, hasta = math.min(y, anterior), math.max(y, anterior) end
      for yy = desde - math.floor(ancho / 2), hasta + math.floor((ancho - 1) / 2) do
        if not (mapa.puerta and mapa.puerta[x .. "_" .. yy]) then
          setSuelo(mapa, x, yy, "camino", "batalla", lado(x))
          setBloque(mapa, x, yy, false)
        end
        reservar(x, yy, 1)
      end
      anterior = y
    end
  end
  local RPLAZA = 6
  for yy = medio - RPLAZA, medio + RPLAZA do
    for xx = math.floor(cx) - RPLAZA, math.floor(cx) + RPLAZA do
      if (xx + 0.5 - cx) ^ 2 + (yy - medio) ^ 2 <= RPLAZA * RPLAZA then
        setSuelo(mapa, xx, yy, "plaza", "batalla", lado(xx))
        setBloque(mapa, xx, yy, false)
        reservar(xx, yy, 1)
      end
    end
  end
  local salidas = { { medio, 3, 3, 0.4 }, { medio - 14, 2, 7, 1.9 }, { medio + 14, 2, 7, 3.6 } }
  local destinoY = { medio, medio - 3, medio + 3 }
  for i, s in ipairs(salidas) do
    camino(23, s[1], math.floor(cx) - RPLAZA, destinoY[i], s[2], s[3], s[4])
    camino(w - 24, s[1], math.floor(cx) + RPLAZA, destinoY[i], s[2], s[3], s[4] + 2.3)
  end
  -- columnas en ruinas alrededor de la plaza: de cada reino a su lado, con huecos para entrar
  for k = 0, 11 do
    local a = k / 12 * math.pi * 2 + 0.26
    local px, py = math.floor(cx + math.cos(a) * (RPLAZA + 1.5)), math.floor(medio + math.sin(a) * (RPLAZA + 1.5))
    if not (mapa.puerta and mapa.puerta[px .. "_" .. py]) and M.get(mapa, px, py) ~= "camino" then
      prop(px, py, umbra(px) and "columna_umbra" or "columna_albor", true)
    end
  end

  -- 3) la zona de guerra: crestas de montaña, huecos y rocas (siempre fuera de los caminos)
  local function libre(x, y)
    if x < 2 or y < 2 or x > w - 3 or y > h - 3 or esReservado(x, y) then return false end
    return not (mapa.bloque[x] and mapa.bloque[x][y])
  end
  local function libre2(x, y)
    for dy = 0, 1 do
      for dx = 0, 1 do
        if not libre(x + dx, y + dy) or not enGuerra(x + dx, y + dy) then return false end
      end
    end
    return true
  end
  for y = 4, h - 6, 2 do
    for x = 24, w - 26, 2 do
      local n = math.sin(x * 0.21 + y * 0.09) + math.sin(x * 0.07 - y * 0.23) + azar(x, y, 99) * 0.9
      if n > 1.2 and libre2(x, y) then
        for dy = 0, 1 do
          for dx = 0, 1 do setBloque(mapa, x + dx, y + dy, true) end
        end
        -- risco dibujado por el cliente (render/campo.lua)
        mapa.props[#mapa.props + 1] = { x = x, y = y, ancho = 2, alto = 2, tipo = x < cx and "risco_albor" or "risco_umbra" }
      end
    end
  end
  for y = 5, h - 7, 4 do
    for x = 25, w - 30, 5 do
      local px, py = x + math.floor(azar(x, y, 101) * 3), y + math.floor(azar(x, y, 102) * 2)
      if azar(x, y, 103) < 0.45 then
        local ancho = 2 + math.floor(azar(x, y, 104) * 2)
        local ok = true
        for dy = 0, 1 do
          for dx = 0, ancho - 1 do
            local tx, ty = px + dx, py + dy
            if not libre(tx, ty) or M.get(mapa, tx, ty) ~= "cicatriz" then ok = false end
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
  for y = 3, h - 4 do
    for x = 24, w - 25 do
      if libre(x, y) and M.get(mapa, x, y) == "cicatriz" and not (mapa.decorado[x] and mapa.decorado[x][y]) then
        local r = azar(x, y, 91)
        if r < 0.09 then decor(x, y, "piedra") end
      end
    end
  end
  -- marcas del suelo (sin colisión; los huesos sí la tienen)
  for y = 3, h - 4 do
    for x = 24, w - 25 do
      if not (mapa.bloque[x] and mapa.bloque[x][y]) and not (mapa.decorado[x] and mapa.decorado[x][y]) then
        if M.get(mapa, x, y) == "cicatriz" then
          local r = azar(x, y, 105)
          local tipo
          if r < 0.006 then tipo = "mancha"
          elseif r < 0.07 then tipo = "mancha"
          elseif r < 0.10 then tipo = "guijarros"
          elseif r < 0.125 then tipo = "grietita"
          elseif r < 0.14 then tipo = "brasas" end
          if tipo then decor(x, y, tipo) end
        end
      end
    end
  end

  -- 4) el patio de cada reino, con su identidad: Alba con bosque claro, flores y farolas; Umbra con árboles
  -- secos, tumbas, setas y fogatas
  for y = 3, h - 4 do
    for x = 24, w - 25 do
      if libre(x, y) and not enGuerra(x, y) and not (mapa.decorado[x] and mapa.decorado[x][y]) then
        local n = math.sin(x * 0.33 + y * 0.17) + math.sin(x * 0.13 - y * 0.37) + azar(x, y, 71) * 0.9
        local r = azar(x, y, 72)
        if n > 1.4 then
          local tipo
          if umbra(x) then tipo = r < 0.6 and "arbol_seco" or (r < 0.8 and "tumba" or "roca")
          else tipo = r < 0.7 and "arbol_pino" or (r < 0.85 and "arbusto" or "roca") end
          prop(x, y, tipo, true)
        else
          local d = azar(x, y, 81)
          if umbra(x) then
            if d < 0.025 then prop(x, y, "seta_roja")
            elseif d < 0.05 then prop(x, y, "hierba_seca")
            end
          else
            if d < 0.03 then prop(x, y, "flores_mixtas")
            elseif d < 0.05 then prop(x, y, "flor_amarilla")
            elseif d < 0.065 then prop(x, y, "hierba_alta") end
          end
        end
      end
    end
  end
  -- farolas (Alba) y fogatas (Umbra) a lo largo de los caminos de cada reino
  for _, lado_ in ipairs({ "albor", "umbra" }) do
    local x0, x1 = 24, math.floor(cx) - 9
    for x = x0, x1, 6 do
      local xx = lado_ == "albor" and x or (w - 1 - x)
      for yy = 4, h - 5 do
        if M.get(mapa, xx, yy) == "camino" and M.get(mapa, xx, yy - 1) ~= "camino" and not (mapa.bloque[xx] and mapa.bloque[xx][yy - 1]) and not enGuerra(xx, yy - 1) then
          prop(xx, yy - 1, lado_ == "albor" and "farol" or "fogata", lado_ == "albor")
          break
        end
      end
    end
  end
  -- estatuas de cada reino a la entrada de su muro
  for _, py in ipairs(ENTRADAS) do
    for _, dy in ipairs({ -2, 2 }) do
      if libre(24, py + dy) then prop(24, py + dy, "estatua_albor", true) end
      if libre(w - 25, py + dy) then prop(w - 25, py + dy, "estatua_umbra", true) end
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
  mapa.props = mapa.props or {}
  -- Todo se coloca de forma determinista (servidor y cliente generan el mismo mapa).
  local reservado = {}          -- casillas que ningún obstáculo puede ocupar (caminos, plazas, pasos del río)
  local function reservar(x, y, r)
    r = r or 0
    for dx = -r, r do
      for dy = -r, r do
        reservado[(x + dx) * 1000 + (y + dy)] = true
      end
    end
  end
  local function esReservado(x, y) return reservado[x * 1000 + y] end
  local function umbra(x) return x >= centro end
  local function lado(x) return umbra(x) and "umbra" or nil end
  local function prop(x, y, tipo, bloquea)
    mapa.props[#mapa.props + 1] = { x = x, y = y, tipo = tipo }
    if bloquea then setBloque(mapa, x, y, true) end
  end

  -- 1) suelo: Alba (hierba clara) al oeste y Umbra (hierba oscura teñida) al este; el borde, bloqueado
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      if umbra(x) then setSuelo(mapa, x, y, "hierba_osc", "campo", "umbra") else setSuelo(mapa, x, y, "hierba", "campo", nil) end
      if x == 0 or y == 0 or x == w - 1 or y == h - 1 then setBloque(mapa, x, y, true) end
    end
  end

  -- 2) el río que parte el campo en dos: serpentea de norte a sur y solo se cruza por puentes y vados
  local function ejeRio(y) return centro + math.floor(4.5 * math.sin(y * 0.21) + 2.2 * math.sin(y * 0.53 + 1.3) + 0.5) end
  for y = 1, h - 2 do
    local rx = ejeRio(y)
    for x = rx - 1, rx + 1 do setSuelo(mapa, x, y, "agua", "campo", lado(x)) end
    setSuelo(mapa, rx - 2, y, "arena", "campo", lado(rx - 2))
    setSuelo(mapa, rx + 2, y, "arena", "campo", lado(rx + 2))
  end
  -- pasos: tres puentes (anchos, con camino) y dos vados de arena (estrechos, entre árboles)
  local PUENTES = { medio, medio - 16, medio + 15 }
  local VADOS = { medio - 8, medio + 8 }
  local function paso(yc, tipo)
    for y = yc - 1, yc + 1 do
      local rx = ejeRio(y)
      for x = rx - 2, rx + 2 do
        setSuelo(mapa, x, y, tipo, "campo", lado(x))
        setBloque(mapa, x, y, false)
        reservar(x, y, 1)
      end
    end
  end
  for _, y in ipairs(PUENTES) do paso(y, "madera") end
  for _, y in ipairs(VADOS) do paso(y, "arena") end

  -- 3) fuertes con plaza, y caminos que serpentean hasta los pasos (cada uno distinto)
  local function fuerte(x0)
    for y = medio - 6, medio + 6 do
      for x = x0, x0 + 10 do
        setSuelo(mapa, x, y, "plaza", "campo", lado(x))
        reservar(x, y, 2)
      end
    end
  end
  fuerte(6)
  fuerte(w - 17)
  local function camino(xa, ya, xb, yb, ancho, amp, fase)
    local dir = xb >= xa and 1 or -1
    local n = math.abs(xb - xa)
    local anterior
    for i = 0, n do
      local x = xa + i * dir
      local t = n > 0 and i / n or 0
      local s = t * t * (3 - 2 * t)
      local y = math.floor(ya + (yb - ya) * s + amp * math.sin(t * math.pi * 2 + fase) * math.sin(t * math.pi) + 0.5)
      local desde, hasta = y, y
      if anterior then desde, hasta = math.min(y, anterior), math.max(y, anterior) end
      for yy = desde - math.floor(ancho / 2), hasta + math.floor((ancho - 1) / 2) do
        setSuelo(mapa, x, yy, "camino", "campo", lado(x))
        setBloque(mapa, x, yy, false)
        reservar(x, yy, 1)
      end
      anterior = y
    end
  end
  local salidas = { { medio, 3, 3, 0.0 }, { medio - 16, 2, 6, 1.7 }, { medio + 15, 2, 6, 3.4 } }
  local origenes = { medio, medio - 4, medio + 4 }
  for i, s in ipairs(salidas) do
    local yb, ancho, amp, fase = s[1], s[2], s[3], s[4]
    local rx = ejeRio(yb)
    -- oeste: del fuerte de Alba al puente; este: del puente al fuerte de Umbra (otro vaivén)
    camino(17, origenes[i], rx - 3, yb, ancho, amp, fase)
    camino(rx + 3, yb, w - 18, origenes[i], ancho, amp, fase + 2.1)
  end
  -- los vados también tienen un sendero corto por cada orilla
  for _, yv in ipairs(VADOS) do
    local rx = ejeRio(yv)
    local dy = yv < medio and 2 or -2
    camino(rx - 8, yv + dy, rx - 3, yv, 1, 1, 0.5)
    camino(rx + 3, yv, rx + 8, yv + dy, 1, 1, 2.0)
  end
  for _, sp in ipairs({ { 18, medio }, { w - 19, medio } }) do reservar(sp[1], sp[2], 2) end

  -- 4) lagunas pequeñas y parches de terreno propios de cada reino
  local function laguna(cx, cy, rx, ry)
    for y = cy - ry - 1, cy + ry + 1 do
      for x = cx - rx - 1, cx + rx + 1 do
        if esReservado(x, y) then return end
      end
    end
    for y = cy - ry - 1, cy + ry + 1 do
      for x = cx - rx - 1, cx + rx + 1 do
        local d = ((x - cx) / rx) ^ 2 + ((y - cy) / ry) ^ 2
        if d <= 1 then setSuelo(mapa, x, y, "agua", "campo", lado(x)) else setSuelo(mapa, x, y, "arena", "campo", lado(x)) end
        reservar(x, y, 0)
      end
    end
  end
  laguna(30, 10, 3, 2)
  laguna(28, 53, 4, 2)
  laguna(63, 12, 3, 2)
  laguna(68, 51, 4, 3)
  for y = 3, h - 4 do
    for x = 3, w - 4 do
      if not esReservado(x, y) then
        local n = math.sin(x * 0.27 + y * 0.11) + math.sin(x * 0.09 - y * 0.29) + azar(x, y, 61) * 0.6
        if umbra(x) then
          -- Umbra: tierra quemada y suelo de bosque oscuro
          if n > 1.25 then setSuelo(mapa, x, y, "tierra", "campo", "umbra")
          elseif n < -1.0 then setSuelo(mapa, x, y, "bosque", "campo", "umbra") end
        else
          -- Alba: prados con trozos de bosque claro
          if n < -1.0 then setSuelo(mapa, x, y, "bosque", "campo", nil) end
        end
      end
    end
  end

  -- 5) bosquecillos y rocas (con colisión) en grupos, siempre fuera de los caminos
  local function libre(x, y)
    if x < 2 or y < 2 or x > w - 3 or y > h - 3 or esReservado(x, y) then return false end
    return not (mapa.bloque[x] and mapa.bloque[x][y])
  end
  for y = 2, h - 3 do
    for x = 2, w - 3 do
      if libre(x, y) then
        local n = math.sin(x * 0.33 + y * 0.17) + math.sin(x * 0.13 - y * 0.37) + azar(x, y, 71) * 0.9
        if n > 1.45 then
          local r = azar(x, y, 72)
          local tipo
          if umbra(x) then tipo = r < 0.6 and "arbol_seco" or (r < 0.8 and "tumba" or "roca")
          else tipo = r < 0.7 and "arbol_pino" or (r < 0.85 and "arbusto" or "roca") end
          prop(x, y, tipo, true)
        end
      end
    end
  end
  -- 6) decoración sin colisión según el reino
  for y = 2, h - 3 do
    for x = 2, w - 3 do
      if libre(x, y) then
        local r = azar(x, y, 81)
        if umbra(x) then
          if r < 0.025 then prop(x, y, "seta_roja")
          elseif r < 0.05 then prop(x, y, "hierba_seca")
          elseif r < 0.075 then prop(x, y, "matorral") end
        else
          if r < 0.03 then prop(x, y, "flores_mixtas")
          elseif r < 0.05 then prop(x, y, "flor_amarilla")
          elseif r < 0.065 then prop(x, y, "hierba_alta")
          elseif r < 0.075 then prop(x, y, "flor_blanca") end
        end
      end
    end
  end
  -- 7) los fuertes y los pasos, con su propia identidad
  for _, bando in ipairs({ "albor", "umbra" }) do
    local x0 = bando == "albor" and 6 or w - 17
    for _, cx in ipairs({ x0, x0 + 10 }) do
      for _, cy in ipairs({ medio - 6, medio + 6 }) do prop(cx, cy, "columna_" .. bando, true) end
    end
    prop(x0 + 5, medio - 6, "farol", true)
    prop(x0 + 5, medio + 6, "farol", true)
    prop(bando == "albor" and x0 + 1 or x0 + 9, medio - 3, "estatua_" .. bando, true)
    prop(bando == "albor" and x0 + 1 or x0 + 9, medio + 3, "estatua_" .. bando, true)
  end
  -- ruinas a orillas de los puentes: columnas de cada reino que miran el paso
  for _, yb in ipairs(PUENTES) do
    local rx = ejeRio(yb)
    for _, dy in ipairs({ -3, 3 }) do
      if libre(rx - 4, yb + dy) then prop(rx - 4, yb + dy, "columna_albor", true) end
      if libre(rx + 4, yb + dy) then prop(rx + 4, yb + dy, "columna_umbra", true) end
    end
  end
  for _, yv in ipairs(VADOS) do
    local rx = ejeRio(yv)
    local dy = yv < medio and -3 or 3
    if libre(rx - 5, yv + dy) then prop(rx - 5, yv + dy, "estatua_albor", true) end
    if libre(rx + 5, yv + dy) then prop(rx + 5, yv + dy, "estatua_umbra", true) end
  end
  -- farolas de Alba junto al camino central y fogatas de Umbra
  for x = 22, centro - 10, 8 do
    for yy = medio - 12, medio + 12 do
      if M.get(mapa, x, yy) == "camino" and M.get(mapa, x, yy - 1) ~= "camino" and not (mapa.bloque[x] and mapa.bloque[x][yy - 1]) then
        prop(x, yy - 1, "farol", true)
        break
      end
    end
  end
  for x = centro + 14, w - 22, 8 do
    for yy = medio - 12, medio + 12 do
      if M.get(mapa, x, yy) == "camino" and M.get(mapa, x, yy - 1) ~= "camino" and not (mapa.bloque[x] and mapa.bloque[x][yy - 1]) then
        prop(x, yy - 1, "fogata", false)
        break
      end
    end
  end

  mapa.spawns = { albor = { x = 18.5, y = medio + 0.5 }, umbra = { x = w - 18.5, y = medio + 0.5 } }
  mapa.banderas = { albor = { x = 11.5, y = medio + 0.5 }, umbra = { x = w - 11.5, y = medio + 0.5 } }
  return mapa
end

function M.casa(w, h)
  w, h = w or 22, h or 16
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
  mapa.puerta = { x = puerta + 0.5, y = h - 0.5 }
  mapa.muebles = {
    cama = { x = 3.5, y = 3.5 },
    cofre = { x = w - 3.5, y = 3.5 },
    estandarte = { x = 3.5, y = math.max(5.5, h - 6.5) },
    mesa = { x = puerta + 0.5, y = math.max(5.5, math.floor(h * 0.5) + 0.5) },
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
