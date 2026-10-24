-- Criaturas con animación por cuadros (arte/monstruos/<carpeta>/{wait,run,att,hurt,dead}.png): cada tira trae sus cuadros en horizontal.
-- Reparto de pasos: 3 de espera, 6 de carrera, 4 de ataque, 2 de daño y 6 de muerte. Las criaturas con dirs2 (casi todas) traen cada paso en dos
-- direcciones: cuadro = paso * 2 + hoja, con la hoja 0 espalda-izquierda y la 1 frente-izquierda (en la vista isométrica los ejes del mundo
-- son diagonales: las otras dos diagonales salen volteando). Cada cuadro lleva un margen transparente (pad) para que el filtro no mezcle
-- cuadros vecinos ni corte la silueta. Las que no (calabaza y limo) traen todos los cuadros seguidos y miran a un lado.
-- Tamaño, aura y tinte de cada criatura: render/mob_anim_datos.lua (lo genera herramientas/generar_mobs/mobs.py).
local M = {}

local CUADROS = { wait = 15, run = 30, att = 20, hurt = 10, dead = 30 }
local VELOCIDAD = { wait = 10, run = 26, att = 28, hurt = 22, dead = 18 }   -- cuadros por segundo (criaturas sin direcciones)
local PASOS = { wait = 2.6, run = 7.5, dead = 4.5 }                          -- pasos por segundo (criaturas con direcciones)

M.DEFS = require("src.presentacion.render.mob_anim_datos")
for id, d in pairs(require("src.presentacion.render.mob_anim_altos")) do M.DEFS[id] = d end         -- criaturas de nivel 31-50 (variantes)
for id, d in pairs(require("src.presentacion.render.mob_anim_mascotas")) do M.DEFS[id] = d end      -- formas de las mascotas de ataque (mascotas_fao.py)
-- PNJ de FAO (herramientas/generar_mobs/npcs.py): mismo formato, con 3 pasos de espera y 6 de carrera
for k, d in pairs(require("src.presentacion.render.npc_anim_datos")) do M.DEFS[k] = d end
-- monturas de FAO (herramientas/generar_mobs/monturas.py)
for k, d in pairs(require("src.presentacion.render.montura_anim_datos")) do M.DEFS[k] = d end
for _, d in pairs(M.DEFS) do d.mira = d.mira or "izq" end
-- asiento del jinete de cada montura de FAO por cuadro (herramientas/generar_mobs/monturas.py)
local ASIENTO = require("src.presentacion.render.montura_asiento_datos")
local ultimoPaso = {}       -- nombre -> { estado, paso } del último cuadro dibujado (para colocar al jinete)
-- ajustes hechos a mano del asiento (montura_ajustes.lua; los guardados desde el juego en la carpeta de datos mandan sobre los del paquete)
local AJUSTES = require("src.presentacion.render.montura_ajustes")
do
  local ok, f = pcall(love.filesystem.load, "montura_ajustes.lua")
  if ok and f then
    local ok2, t = pcall(f)
    if ok2 and type(t) == "table" then for k, v in pairs(t) do AJUSTES[k] = v end end
  end
end
M.AJUSTES = AJUSTES
function M.ultimo(nombre) return ultimoPaso[nombre] end

local cache = {}

local function tira(carpeta, tipo, dirs2, dirs5)
  local k = carpeta .. "/" .. tipo
  local t = cache[k]
  if t == nil then
    local ruta = "arte/monstruos/" .. carpeta .. "/" .. tipo .. ".png"
    if love.filesystem.getInfo(ruta) then
      local img = love.graphics.newImage(ruta, { mipmaps = true })
      img:setFilter("linear", "linear")
      img:setMipmapFilter("linear", 0)
      local n = dirs2 and (CUADROS[tipo] * 2 / 5) or CUADROS[tipo]       -- (con dirs5 la tira trae los cuadros de las cinco direcciones: paso * 5 + hoja)
      t = { img = img, n = n, w = img:getWidth() / n, h = img:getHeight(), quads = {} }
    else
      t = false
    end
    cache[k] = t
  end
  return t or nil
end

local function cuadro(t, i)
  local q = t.quads[i]
  if not q then
    q = love.graphics.newQuad(i * t.w, 0, t.w, t.h, t.img:getDimensions())
    t.quads[i] = q
  end
  return q
end

function M.existe(nombre) return M.DEFS[nombre] ~= nil end

-- Hoja (0 espalda-izquierda, 1 frente-izquierda) y si se voltea, según la dirección del mundo de la criatura (1 y+, 2 y-, 3 x+, 4 x-): en la
-- vista isométrica y+ baja a la izquierda, y- sube a la derecha, x+ baja a la derecha y x- sube a la izquierda.
-- Con las cinco direcciones (dirs5) las hojas son las de los personajes por capas: 0 frente, 1 espalda, 2 espalda-izquierda, 3 izquierda,
-- 4 frente-izquierda (las de la derecha, volteadas). Sin saber hacia dónde camina, se usa la dirección del mundo de la criatura (diagonales).
local HOJA_MUNDO = { [1] = { 4, false }, [2] = { 2, true }, [3] = { 4, true }, [4] = { 2, false } }

local function hojaDe(dir)
  if dir == 1 then return 1, false end        -- hacia abajo-izquierda: frente-izquierda
  if dir == 2 then return 0, true end         -- hacia arriba-derecha: espalda-izquierda volteada
  if dir == 3 then return 1, true end         -- hacia abajo-derecha: frente-izquierda volteada
  return 0, false                             -- hacia arriba-izquierda: espalda-izquierda
end

-- Aura de los jefes: un charco de luz con latido en el suelo y unas chispas que giran.
local function aura(d, sx, pies, alfa)
  if not d.aura then return end
  local t = love.timer.getTime()
  local c = d.aura
  local r = d.alto * 0.62
  local latido = 0.5 + 0.5 * math.sin(t * 2.4)
  for k = 3, 1, -1 do
    love.graphics.setColor(c[1], c[2], c[3], (0.06 + 0.04 * latido) * (4 - k) * 0.6 * (alfa or 1))
    love.graphics.ellipse("fill", sx, pies + 2, r * (0.55 + 0.22 * k), r * (0.55 + 0.22 * k) * 0.42)
  end
  love.graphics.setColor(c[1], c[2], c[3], (0.35 + 0.2 * latido) * (alfa or 1))
  love.graphics.setLineWidth(1.5)
  love.graphics.ellipse("line", sx, pies + 2, r * 0.95, r * 0.95 * 0.42)
  love.graphics.setLineWidth(1)
  for i = 1, 6 do
    local a = t * 0.9 + i * math.pi / 3
    local yy = pies + 2 - ((t * 0.5 + i * 0.17) % 1) * d.alto * 0.7
    love.graphics.setColor(c[1], c[2], c[3], (0.7 - ((t * 0.5 + i * 0.17) % 1) * 0.7) * (alfa or 1))
    love.graphics.circle("fill", sx + math.cos(a) * r * 0.7, yy, 1.6)
  end
end

-- Dibuja un cuadro de la tira. i es el cuadro (o el paso en las criaturas con direcciones); u (0..1) elige por progreso si no se da i.
local function dibujar(nombre, tipo, i, u, sx, pies, dir, alfa, tinte, hoja5, flip5, corteY)
  local d = M.DEFS[nombre]
  if not d then return 32 end
  local t = tira(d.carpeta, tipo, d.dirs2, d.dirs5)
  if not t and tipo ~= "wait" and (d.dirs5 or d.dirs2) then      -- (sin la animación pedida -- ataque, daño -- se queda en la pose de espera)
    t, i = tira(d.carpeta, "wait", d.dirs2, d.dirs5), 0
  end
  if not t then return d.alto end
  local voltear
  if d.dirs5 then
    local pasos = math.floor(t.n / 5)
    if not i then i = math.floor((u or 0) * pasos) end
    i = math.max(0, math.min(pasos - 1, i))
    local hoja, flip = hoja5, flip5
    if not hoja then hoja, flip = HOJA_MUNDO[dir or 1][1], HOJA_MUNDO[dir or 1][2] end
    voltear = flip
    i = i * 5 + hoja
  elseif d.dirs2 then
    local pasos = math.floor(t.n / 2)
    if not i then i = math.floor((u or 0) * pasos) end
    i = math.max(0, math.min(pasos - 1, i))
    local hoja, flip = hojaDe(dir or 1)
    voltear = flip
    i = i * 2 + hoja
  else
    if not i then i = math.floor((u or 0) * t.n) end
    i = math.max(0, math.min(t.n - 1, i))
    voltear = (d.mira == "izq") == ((dir or 1) == 3)
  end
  local e = d.escala
  local c = tinte or { 1, 1, 1 }
  local k = d.tinte
  if k then c = { c[1] * k[1], c[2] * k[2], c[3] * k[3] } end
  aura(d, sx, pies, alfa)
  love.graphics.setColor(c[1], c[2], c[3], alfa or 1)
  if corteY then
    -- solo la parte del cuadro que queda por debajo de la línea corteY (y de pantalla)
    local suelo = t.h - (d.pad or 0)
    local y0 = math.max(0, math.min(t.h - 1, (corteY - (pies + 2)) / e + suelo))
    local q = love.graphics.newQuad(i * t.w, y0, t.w, t.h - y0, t.img:getDimensions())
    love.graphics.draw(t.img, q, sx, pies + 2 + (y0 - suelo) * e, 0, voltear and -e or e, e, t.w / 2, 0)
    return d.alto
  end
  love.graphics.draw(t.img, cuadro(t, i), sx, pies + 2, 0, voltear and -e or e, e, t.w / 2, t.h - (d.pad or 0))
  return d.alto
end

-- Criatura viva. estado: "wait" | "run" | "att" | "hurt"; u: progreso 0..1 para ataque y daño; dir: dirección del mundo (1..4); semilla:
-- desfase para que las del mismo tipo no se muevan a la vez. Devuelve su altura para la placa.
function M.dibujar(nombre, estado, u, sx, pies, dir, tinte, semilla, sujeto, repetir, corteY)
  local d = M.DEFS[nombre]
  local i
  if d and (estado == "wait" or estado == "run") then
    local t = tira(d.carpeta, estado, d.dirs2, d.dirs5)
    local desfase = (semilla or 0) * 3.7
    if d.dirs5 then
      i = math.floor(love.timer.getTime() * PASOS[estado] + desfase) % math.max(1, math.floor((t and t.n or 5) / 5))
    elseif d.dirs2 then
      i = math.floor(love.timer.getTime() * PASOS[estado] + desfase) % math.max(1, math.floor((t and t.n or 2) / 2))
    else
      i = math.floor(love.timer.getTime() * VELOCIDAD[estado] + desfase) % (t and t.n or 1)
    end
  end
  -- repetir: se vuelve a pintar el mismo cuadro que la última vez (la montura de frente se repinta sobre las piernas del jinete)
  if repetir and ultimoPaso[nombre] and (estado == "wait" or estado == "run") then i = ultimoPaso[nombre].paso end
  -- hacia dónde mira: con el sujeto (la entidad) se usa su dirección de movimiento, con histéresis (la misma de los personajes por capas), en
  -- ocho direcciones; sin él, la dirección del mundo
  local hoja5, flip5
  if d and d.dirs5 and sujeto then
    local Fao = require("src.presentacion.render.fao")
    hoja5, flip5 = Fao.hojaDeOctante(Fao.direccion(sujeto, sujeto._faoAtq and sujeto._faoAtq.st))   -- (al atacar, la montura y el jinete miran al objetivo)
  end
  -- Monturas de FAO: el origen del arte (el punto del suelo bajo la montura) no cae en el centro de la casilla del cuadro, y cambia con el paso y
  -- la dirección. Se corre el dibujo para que ese punto quede exactamente en (sx, pies): así la sombra, el jinete y el objetivo coinciden con la montura.
  local corrido = 0
  if d and d.dirs5 and ASIENTO[nombre] and ASIENTO[nombre][estado] and i and (estado == "wait" or estado == "run") then
    local h5, f5 = hoja5, flip5
    if not h5 then h5, f5 = HOJA_MUNDO[dir or 1][1], HOJA_MUNDO[dir or 1][2] end
    local dx = ASIENTO[nombre][estado][(i * 5 + h5) * 2 + 1]
    if dx then corrido = (f5 and -dx or dx) * d.escala end
  end
  if d and (d.dirs2 or d.dirs5) and (estado == "wait" or estado == "run") then
    ultimoPaso[nombre] = { estado = estado, paso = i, hoja = hoja5, flip = flip5, corrido = corrido }
  end
  return dibujar(nombre, estado, i, u, sx - corrido, pies, dir, 1, tinte, hoja5, flip5, corteY)
end

-- Dónde cae el asiento del jinete de una montura de FAO (el origen de las hojas del personaje montado), tal como se dibujó en su último cuadro:
-- devuelve dx, dy (píxeles de pantalla respecto a los pies con que se dibujó la montura), el paso de la animación, la hoja de dirección
-- (en las monturas de cinco direcciones, la de los personajes por capas: 0 frente ... 4 frente-izquierda; si no, 0 espalda-izquierda y 1 frente-izquierda) y si va volteada. Hay que llamarla justo después de M.dibujar, para que jinete y montura compartan cuadro.
function M.asiento(nombre, dir)
  local d, u = M.DEFS[nombre], ultimoPaso[nombre]
  local datos = ASIENTO[nombre]
  if not (d and u and datos and datos[u.estado]) then return nil end
  local hoja, flip
  local k
  if d.dirs5 then
    hoja, flip = u.hoja, u.flip
    if not hoja then hoja, flip = HOJA_MUNDO[dir or 1][1], HOJA_MUNDO[dir or 1][2] end
    k = (u.paso * 5 + hoja) * 2
  else
    hoja, flip = hojaDe(dir or 1)
    k = (u.paso * 2 + hoja) * 2
  end
  local dx, dy = datos[u.estado][k + 1], datos[u.estado][k + 2]
  if not dx then return nil end
  local e = d.escala
  local aj = AJUSTES[nombre] and AJUSTES[nombre][hoja]
  local ax, ay = aj and aj[1] or 0, aj and aj[2] or 0
  return (flip and -dx or dx) * e - (u.corrido or 0) + (flip and -ax or ax), 2 + dy * e + ay, u.paso, u.estado, hoja, flip
end

-- Cadáver: la animación de muerte y, al terminar, el último cuadro que se va apagando. transcurrido: segundos desde que murió.
function M.muerto(nombre, transcurrido, sx, pies, dir, alfa)
  local d = M.DEFS[nombre]
  if not d then return end
  local t = tira(d.carpeta, "dead", d.dirs2)
  if not t then return end
  local pasos = d.dirs2 and math.floor(t.n / 2) or t.n
  local i = math.min(pasos - 1, math.floor(math.max(0, transcurrido) * (d.dirs2 and PASOS.dead or VELOCIDAD.dead)))
  dibujar(nombre, "dead", i, nil, sx, pies, dir, alfa, nil)
end

return M
