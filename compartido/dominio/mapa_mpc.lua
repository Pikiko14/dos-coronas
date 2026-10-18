-- Lector de mapas de Free Angels Online (.mpc) para Dos Coronas. Lua puro (sin LÖVE en la parte de datos): lo usan el servidor y el cliente con el mismo resultado.
-- Material de un juego ajeno (FAO): prototipo. Formato y reglas: herramientas/generar_mapa/mpc.py y reglas_mpc.py (aquí está su versión en Lua).
--
--   M.leer(bytes)              -> crudo: { w, h, celda, tilesets, ts[], tile[] (casilla y*w+x+1), objetos = { {id, x, y, ...} }, rutas, puntos, eventos, dialogos }
--   M.aMapa(crudo, datos)      -> tabla de mapa del juego (w, h, suelo, bloque, bioma, ...) + mapa.mpc con lo que necesita el cliente para dibujarlo
--   M.cargar(num)              -> lo anterior leyendo compartido/datos/mapas_fao/mapNNN.mpc y su archivo de datos horneado (mapNNN_datos.lua); en caché
--
-- Los datos horneados (herramientas/generar_mapa/hornear_mpc.py) traen la clase de cada tileset usado y la huella de cada objeto. La colisión sale del atributo de cada celda (byte 1).
local Xml = require("compartido.dominio.xml")

local M = {}

local function u32(s, p)
  local a, b, c, d = s:byte(p, p + 3)
  if not d then error("mpc: lectura fuera del archivo en " .. p, 0) end
  return a + b * 256 + c * 65536 + d * 16777216
end

-- ------------------------------------------------------------------------------------------------------------------------------ lectura
function M.leer(bytes)
  if type(bytes) ~= "string" or #bytes < 96 or bytes:sub(1, 4) ~= "MAP\0" then error("mpc: no es un archivo .mpc", 0) end
  local h = {}
  for i = 0, 23 do h[i] = u32(bytes, 1 + i * 4) end
  local w, alto = h[1], h[2]
  if w < 1 or alto < 1 or w > 4096 or alto > 4096 then error("mpc: tamaño de mapa no válido", 0) end
  if 96 + w * alto * 6 > #bytes then error("mpc: la cuadrícula no cabe en el archivo", 0) end
  local crudo = { w = w, h = alto, celda = h[4], version = h[3], bytes = #bytes, ts = {}, tile = {}, objetos = {}, rutas = {}, puntos = {}, tilesets = {} }
  -- cuadrícula: celdas de 6 bytes (tileset de pincel, índice del tile, 0, capa de agua profunda, 0, 0)
  local p = 97
  local ts, tile = crudo.ts, crudo.tile
  for i = 1, w * alto do
    ts[i], tile[i] = bytes:byte(p, p + 1)
    p = p + 6
  end
  -- tilesets que usa el mapa (un byte cada uno, en decimal; el archivo es brush/brush.bNN con NN en hexadecimal)
  for i = 0, h[14] - 1 do crudo.tilesets[#crudo.tilesets + 1] = bytes:byte(h[13] + 1 + i) end
  -- objetos: h[7] registros de 74 bytes
  for i = 0, h[7] - 1 do
    local q = h[6] + 1 + i * 74
    if q + 73 > #bytes then error("mpc: la lista de objetos se sale del archivo", 0) end
    crudo.objetos[#crudo.objetos + 1] = { id = u32(bytes, q), x = u32(bytes, q + 4), y = u32(bytes, q + 8), a = u32(bytes, q + 12), espejo = u32(bytes, q + 16), c = u32(bytes, q + 20) }
  end
  -- eventos y diálogos: u32 longitud + XML UTF-8
  local function xml(desde)
    local ln = u32(bytes, desde + 1)
    return bytes:sub(desde + 5, desde + 4 + ln)
  end
  crudo.eventosXml = xml(h[8])
  crudo.dialogosXml = xml(h[15])
  -- rutas: u32 n; n * { id, 1, puntos, 0, puntos * (x, y, tipo, 0, 0, 0) }
  do
    local q = h[17] + 1
    local n = u32(bytes, q)
    q = q + 4
    for _ = 1, n do
      local id, npts = u32(bytes, q), u32(bytes, q + 8)
      q = q + 16
      local pts = {}
      for _ = 1, npts do
        pts[#pts + 1] = { x = u32(bytes, q), y = u32(bytes, q + 4), tipo = u32(bytes, q + 8) }
        q = q + 24
      end
      crudo.rutas[#crudo.rutas + 1] = { id = id, puntos = pts }
    end
  end
  -- puntos: h[20] registros { id, n, n * (x, y) } hasta el final del archivo (ids 1-2: salidas en el borde; 31-44: puntos sueltos; 71-83: zonas)
  do
    local q = h[19] + 1
    for _ = 1, h[20] do
      local id, npts = u32(bytes, q), u32(bytes, q + 4)
      q = q + 8
      local pts = {}
      for _ = 1, npts do
        pts[#pts + 1] = { x = u32(bytes, q), y = u32(bytes, q + 4) }
        q = q + 8
      end
      crudo.puntos[#crudo.puntos + 1] = { id = id, puntos = pts }
    end
  end
  return crudo
end

-- Eventos y diálogos de FAO convertidos a tablas simples. No se conectan a nada todavía (apuntan a mapas, NPC y mensajes de FAO): quedan inertes.
--   eventos[id]  = { id, cursor, disparadores = { { id, contacto, veces, acciones = { { id, params = { valores } } } } } }
--   dialogos[id] = { id, mensaje (número de setting/eng/msg.xml), condiciones, siguiente }
local function hijos(el, tag)
  local l = {}
  for _, h in ipairs(el.hijos) do if h.tag == tag then l[#l + 1] = h end end
  return l
end

function M.eventos(crudo)
  if crudo._eventos then return crudo._eventos end
  local out = {}
  local ok, raiz = pcall(Xml.leer, crudo.eventosXml, "mpc:eventos")
  if ok then
    for _, ev in ipairs(hijos(raiz, "事件")) do
      local e = { id = tonumber(ev.attrs["編號"]), cursor = tonumber(ev.attrs["游標"]), disparadores = {} }
      for _, tr in ipairs(hijos(ev, "觸發器")) do
        local t = { id = tonumber(tr.attrs["編號"]), contacto = tonumber(tr.attrs["觸發"]), veces = tonumber(tr.attrs["次數"]), acciones = {} }
        for _, ac in ipairs(hijos(tr, "動作")) do
          local a = { id = tonumber(ac.attrs["編號"]), params = {} }
          for _, pa in ipairs(hijos(ac, "參數")) do a.params[#a.params + 1] = tonumber(pa.attrs["數值"]) end
          t.acciones[#t.acciones + 1] = a
        end
        e.disparadores[#e.disparadores + 1] = t
      end
      if e.id then out[e.id] = e end
    end
  end
  crudo._eventos = out
  return out
end

function M.dialogos(crudo)
  if crudo._dialogos then return crudo._dialogos end
  local out = {}
  local ok, raiz = pcall(Xml.leer, crudo.dialogosXml, "mpc:dialogos")
  if ok then
    for _, d in ipairs(hijos(raiz, "對話")) do
      local id = tonumber(d.attrs["編號"])
      if id then
        local sig
        for _, s in ipairs(hijos(d, "成立")) do sig = tonumber(s.attrs["下一句"]) end
        out[id] = { id = id, mensaje = tonumber(d.attrs["訊息"]), condiciones = tonumber(d.attrs["條件"]), siguiente = sig }
      end
    end
  end
  crudo._dialogos = out
  return out
end

-- ------------------------------------------------------------------------------------------------------------------------------ del .mpc al mapa del juego
-- clase de tileset de FAO (por su color medio) -> tipo de suelo del juego
local SUELO = { agua = "agua", agua_somera = "agua", arena = "arena", hierba = "hierba", tierra = "tierra", roca = "montana" }

function M.puntoEnPoligono(pts, x, y)
  local dentro = false
  local j = #pts
  for i = 1, #pts do
    local xi, yi, xj, yj = pts[i].x, pts[i].y, pts[j].x, pts[j].y
    if (yi > y) ~= (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi then dentro = not dentro end
    j = i
  end
  return dentro
end

-- Escala del mapa de FAO al juego. FAO dibuja su mapa en vista cenital con celdas de 32 px y sus personajes y objetos a tamaño nativo; Dos Coronas dibuja a la mitad (zoom 2: un píxel de
-- FAO = un píxel de pantalla) y su casilla de juego (32 px de mundo) son 64 px de FAO = 2 x 2 celdas del .mpc (el .mpc cambia de tileset en bloques de 2 x 2). Las posiciones de los objetos
-- siguen en píxeles de FAO; x / 64 son las casillas del juego.
M.CELDA = 64             -- píxeles de FAO por casilla del juego
M.FINA = 2               -- celdas del .mpc por casilla del juego (por lado)

-- Objetos que cierran su casilla además del atributo del terreno: los que FAO coloca sobre agua o suelo libre y no marca en la cuadrícula (barcas, mesas, puestos, estantes, muebles).
-- Solo cuentan los que tienen ZBUFFER (los de suelo, tablones y pilotes, nunca bloquean) y no son de puente. Nombres de setting/mapobj.obd (en chino).
local BLOQUEAN_OBJ = { "船", "桌", "攤", "架", "椅", "凳", "櫃", "箱", "桶", "籃", "缸", "罈" }
local NUNCA_OBJ = { "橋", "欄", "板", "墩" }

local function contiene(nombre, lista)
  for _, k in ipairs(lista) do if nombre:find(k, 1, true) then return true end end
  return false
end

-- ¿Bloquea este objeto? def = datos.objetos[id]; reglas (opcional, mapNNN_reglas.lua) = { bloquean = { id o parte del nombre... }, pasan = { ... }, huellas = { [id o nombre] = { w, d } } }.
-- Devuelve nil o el rectángulo de su casco en píxeles de FAO relativo al punto de apoyo: ancho (80 % del sprite), fondo (1 casilla; el de la regla si la hay).
local function huellaObjeto(id, def, reglas)
  local function en(lista)
    for _, k in ipairs(lista or {}) do
      if k == id or (type(k) == "string" and def.n:find(k, 1, true)) then return true end
    end
    return false
  end
  local bloquea
  if reglas and en(reglas.pasan) then bloquea = false
  elseif reglas and en(reglas.bloquean) then bloquea = true
  else bloquea = def.z == true and not def.p and contiene(def.n, BLOQUEAN_OBJ) and not contiene(def.n, NUNCA_OBJ) end
  if not bloquea then return nil end
  local f = def.f[1]
  local ancho, fondo = math.max(M.CELDA * 0.8, f[3] * 0.8), M.CELDA
  local h = reglas and reglas.huellas
  if h then
    local r = h[id]
    if not r then for k, v in pairs(h) do if type(k) == "string" and def.n:find(k, 1, true) then r = v break end end end
    if r then ancho, fondo = (r.w or ancho / M.CELDA) * M.CELDA, (r.d or 1) * M.CELDA end
  end
  return ancho, fondo
end

M.huellaObjeto = huellaObjeto

function M.aMapa(crudo, datos, reglas)
  local Mapa = require("compartido.dominio.mapa")
  local F = M.FINA
  local w, h = math.ceil(crudo.w / F), math.ceil(crudo.h / F)
  local mapa = Mapa.nuevo(w, h)
  local tilesets = datos.tilesets
  -- suelo, colisión y bioma por casilla de juego (2 x 2 celdas del .mpc). El byte 1 de cada celda es el ATRIBUTO del terreno (no un índice de tile): 0 libre, 1 obstáculo (árboles, rocas,
  -- cajas), 2 agua o risco, 3 y 10 casos sueltos. Una casilla se cierra si tiene un obstáculo (1, 3 o 10) o dos o más celdas de agua/risco (2): así los árboles cierran su casilla y los bordes
  -- de agua no se comen la orilla. El tipo de suelo sale del color medio del tileset de la casilla (solo para minimapa, ambiente y búsquedas).
  for x = 0, w - 1 do
    mapa.suelo[x], mapa.bloque[x], mapa.bioma[x], mapa.lado[x] = {}, {}, {}, {}
  end
  local sinTile = 0
  for gy = 0, h - 1 do
    for gx = 0, w - 1 do
      local i0 = (gy * F) * crudo.w + (gx * F) + 1
      local t = tilesets[crudo.ts[i0]]
      local obstaculos, agua = 0, 0
      for dy = 0, F - 1 do
        for dx = 0, F - 1 do
          local x, y = gx * F + dx, gy * F + dy
          if x < crudo.w and y < crudo.h then
            local a = crudo.tile[y * crudo.w + x + 1]
            if a == 2 then agua = agua + 1 elseif a ~= 0 then obstaculos = obstaculos + 1 end
          end
        end
      end
      local tipo
      if t then tipo = SUELO[t.clase] or "tierra" else sinTile = sinTile + 1 tipo = "agua" end
      local bloqueada = (not t) or obstaculos > 0 or agua >= 2
      if bloqueada then mapa.bloque[gx][gy] = true end
      if tipo == "agua" and not bloqueada then tipo = "arena" end       -- (una casilla libre nunca es "agua": Mapa.transitable la rechazaría)
      mapa.suelo[gx][gy] = (bloqueada and t and t.clase == "agua") and "agua" or tipo
      mapa.bioma[gx][gy] = (mapa.suelo[gx][gy] == "agua") and "agua" or "riprap"
    end
  end
  -- objetos dibujables (los inertes del servidor, NPC y luces no cuentan); la colisión de los árboles y las rocas ya está en el atributo del terreno
  local objetos = {}
  local defs = datos.objetos
  for _, o in ipairs(crudo.objetos) do
    if defs[o.id] then objetos[#objetos + 1] = o end
  end
  -- colisión de los objetos grandes sin marca en el terreno (barcas, mesas...): el casco cierra las casillas que toca
  local cerrados = {}
  for _, o in ipairs(objetos) do
    local ancho, fondo = huellaObjeto(o.id, defs[o.id], reglas)
    if ancho then
      local x0, x1 = math.floor((o.x - ancho / 2) / M.CELDA), math.floor((o.x + ancho / 2 - 1) / M.CELDA)
      local y0, y1 = math.floor((o.y - fondo) / M.CELDA), math.floor((o.y - 1) / M.CELDA)
      for gx = math.max(0, x0), math.min(w - 1, x1) do
        for gy = math.max(0, y0), math.min(h - 1, y1) do
          if not mapa.bloque[gx][gy] then mapa.bloque[gx][gy] = true cerrados[#cerrados + 1] = gx * 100000 + gy end
        end
      end
    end
  end
  -- salidas: los triángulos de los puntos 1 y 2 (en FAO son los saltos a otros mapas: eventos 1 y 2)
  local salidas, zonas = {}, {}
  for _, p in ipairs(crudo.puntos) do
    if p.id == 1 or p.id == 2 then salidas[#salidas + 1] = { id = p.id, puntos = p.puntos }
    elseif p.id >= 71 and p.id <= 83 then zonas[#zonas + 1] = { id = p.id, puntos = p.puntos } end
  end
  mapa.fao = true
  mapa.nombre = datos.nombre
  mapa.musica = datos.musica
  mapa.mpc = {
    id = datos.id, fw = crudo.w, fh = crudo.h, ts = crudo.ts, tile = crudo.tile, tilesets = tilesets, objetos = objetos, defs = defs,
    atlasSuelo = datos.atlasSuelo, atlasObjetos = datos.atlasObjetos, clima = datos.clima, salidas = salidas, zonas = zonas, rutas = crudo.rutas,
    puntos = crudo.puntos, inertes = datos.inertes, sinTile = sinTile, cerradosPorObjetos = #cerrados,
  }
  mapa.eventos = M.eventos(crudo)
  mapa.dialogos = M.dialogos(crudo)
  -- entrada: la casilla transitable del mayor continente de casillas más cercana a la playa del oeste (a ~35 % del ancho y ~60 % del alto); las salidas quedan lejos
  local comp, mejorN, mejor = {}, 0, nil
  local function libre(x, y)
    return x >= 1 and y >= 1 and x < w - 1 and y < h - 1 and not (mapa.bloque[x] and mapa.bloque[x][y]) and mapa.suelo[x][y] ~= "agua"
  end
  local id = 0
  for y = 1, h - 2 do
    for x = 1, w - 2 do
      local k = y * w + x
      if libre(x, y) and not comp[k] then
        id = id + 1
        local pila, n = { k }, 0
        comp[k] = id
        while #pila > 0 do
          local c = table.remove(pila)
          n = n + 1
          local cx, cy = c % w, math.floor(c / w)
          for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local nx, ny = cx + d[1], cy + d[2]
            local kk = ny * w + nx
            if libre(nx, ny) and not comp[kk] then comp[kk] = id pila[#pila + 1] = kk end
          end
        end
        if n > mejorN then mejorN, mejor = n, id end
      end
    end
  end
  local bx, by, bd = nil, nil, math.huge
  local ox, oy = w * 0.35, h * 0.6
  for y = 1, h - 2 do
    for x = 1, w - 2 do
      if comp[y * w + x] == mejor then
        local d = (x - ox) ^ 2 + (y - oy) ^ 2
        if d < bd then bx, by, bd = x, y, d end
      end
    end
  end
  mapa.entrada = { x = (bx or 2) + 0.5, y = (by or 2) + 0.5 }
  mapa.continente = { id = mejor, casillas = mejorN }
  mapa.comp = comp
  return mapa
end

-- ------------------------------------------------------------------------------------------------------------------------------ archivos
local function leerArchivo(ruta)
  local contenido
  if love and love.filesystem and love.filesystem.getSource then
    local base = love.filesystem.getSource():gsub("\\", "/")
    for _, subida in ipairs({ "/../", "/../../" }) do
      local f = io.open(base .. subida .. ruta, "rb")
      if f then contenido = f:read("*a") f:close() break end
    end
    if not contenido then contenido = love.filesystem.read(ruta) end
  else
    local f = io.open(ruta, "rb")
    if f then contenido = f:read("*a") f:close() end
  end
  return contenido
end

M.leerArchivo = leerArchivo

local cache = {}

-- Campamentos de criaturas puestos con el editor de mapas (mapNNN_campamentos.lua, junto al .mpc): lista de { monstruo, cantidad, radio, x, y, jefe?, nivel? } con x, y y radio en CELDAS del
-- .mpc (así trabaja el editor; la casilla del juego son 2 x 2 celdas). Aquí se pasan a casillas del juego y se validan; sin archivo, lista vacía. Un campamento en una casilla del juego no
-- transitable (cuadrícula gruesa: basta una celda de obstáculo para cerrar la casilla) se mueve a la libre más cercana (hasta 3 casillas); si no hay ninguna, error.
local function cargarCampamentos(mapa, nombre)
  local Datos = require("compartido.dominio.datos")
  local Mapa = require("compartido.dominio.mapa")
  local modulo = "compartido.datos.mapas_fao." .. nombre .. "_campamentos"
  local ok, lista = pcall(require, modulo)
  if not ok then
    if tostring(lista):find("module '" .. modulo .. "' not found", 1, true) then return {} end
    error(nombre .. "_campamentos.lua: " .. tostring(lista), 0)
  end
  local function fallo(i, campo, msg) error(string.format("%s_campamentos.lua: campamento %d, campo '%s': %s", nombre, i, campo, msg), 0) end
  if type(lista) ~= "table" then error(nombre .. "_campamentos.lua: debe devolver una lista de campamentos", 0) end
  local salida = {}
  for i, c in ipairs(lista) do
    if type(c.monstruo) ~= "string" or not Datos.monstruo(c.monstruo) then fallo(i, "monstruo", "'" .. tostring(c.monstruo) .. "' no existe en monstruos.xml") end
    for _, campo in ipairs({ "cantidad", "radio", "x", "y" }) do
      if type(c[campo]) ~= "number" then fallo(i, campo, "debe ser un número, es " .. tostring(c[campo])) end
    end
    if c.cantidad < 1 or c.cantidad ~= math.floor(c.cantidad) then fallo(i, "cantidad", "debe ser un entero de 1 o más, es " .. c.cantidad) end
    if c.radio < 0 then fallo(i, "radio", "no puede ser negativo") end
    if c.nivel ~= nil and type(c.nivel) ~= "number" then fallo(i, "nivel", "debe ser un número") end
    if c.x < 0 or c.y < 0 or c.x >= mapa.mpc.fw or c.y >= mapa.mpc.fh then
      fallo(i, "x,y", string.format("(%s, %s) cae fuera del mapa de %dx%d celdas", c.x, c.y, mapa.mpc.fw, mapa.mpc.fh))
    end
    local gx, gy = c.x / M.FINA, c.y / M.FINA
    local tx, ty = math.floor(gx), math.floor(gy)
    if not Mapa.transitable(mapa, tx, ty) then
      local mejor, md
      for dy = -3, 3 do
        for dx = -3, 3 do
          if Mapa.transitable(mapa, tx + dx, ty + dy) then
            local d = dx * dx + dy * dy
            if not md or d < md then mejor, md = { tx + dx, ty + dy }, d end
          end
        end
      end
      if not mejor then fallo(i, "x,y", string.format("la casilla (%d, %d) no es transitable y no hay ninguna libre a 3 casillas", tx, ty)) end
      gx, gy = mejor[1] + 0.5, mejor[2] + 0.5
    end
    salida[#salida + 1] = { monstruo = c.monstruo, cantidad = c.cantidad, radio = c.radio / M.FINA, x = gx, y = gy, jefe = c.jefe, nivel = c.nivel, fao = nombre }
  end
  return salida
end
function M.cargar(num)
  if cache[num] then return cache[num] end
  local nombre = string.format("map%03d", num)
  local bytes = leerArchivo("compartido/datos/mapas_fao/" .. nombre .. ".mpc")
  if not bytes then error("falta compartido/datos/mapas_fao/" .. nombre .. ".mpc", 0) end
  local datos = require("compartido.datos.mapas_fao." .. nombre .. "_datos")
  -- correcciones manuales de colisión de objetos (opcional): mapNNN_reglas.lua, ver huellaObjeto
  local okr, reglas = pcall(require, "compartido.datos.mapas_fao." .. nombre .. "_reglas")
  if not okr then
    if not tostring(reglas):find("module 'compartido.datos.mapas_fao." .. nombre .. "_reglas' not found", 1, true) then error(nombre .. "_reglas.lua: " .. tostring(reglas), 0) end
    reglas = nil
  end
  local mapa = M.aMapa(M.leer(bytes), datos, reglas)
  mapa.campamentos = cargarCampamentos(mapa, nombre)
  cache[num] = mapa
  return mapa
end

function M.olvidar() cache = {} end

return M
