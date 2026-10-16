-- Personajes por capas (arte/fao/, horneado por herramientas/generar_personajes/hornear.py): cuerpo masculino o femenino y, encima, la
-- armadura (cabeza, pecho, manos, pies), el arma y el escudo que lleva equipados. Ocho direcciones (cinco hojas y las otras tres
-- volteadas) y las animaciones de espera, correr, atacar, lanzar, disparar, daño y muerte.
-- DC_FAO=0 en el entorno (o Ajustes.personajesCapas = false) vuelve a los personajes antiguos.
local Iso = require("src.presentacion.render.iso")
local Ajustes = require("src.presentacion.ajustes")

local M = {}

-- Las hojas están horneadas a tamaño original (86 px de alto): con el zoom del juego (x2) se dibujan a la mitad, que es su tamaño real en pantalla.
local ESCALA_JUEGO = 0.5

local datos
local activoCache

-- Las pruebas de los personajes antiguos lo apagan un momento (M.forzar(false)) y lo dejan como estaba (M.forzar(nil)).
function M.forzar(v) activoCache = v end

function M.activo()
  if activoCache == nil then
    if os.getenv("DC_FAO") == "0" or Ajustes.personajesCapas == false then
      activoCache = false
    else
      local ok, d = pcall(require, "src.presentacion.render.fao_datos")
      datos = ok and d or nil
      activoCache = datos ~= nil and love.filesystem.getInfo("arte/fao/p001b/Wait_f.png") ~= nil
    end
  end
  return activoCache
end

-- Arma principal de cada oficio (id "<clase>_arma_<escalón>").
local PRINCIPAL = { guerrero = "espada", lancero = "lanza", cazador = "arco", mago = "baston", clerigo = "maza", nigromante = "baculo" }
-- Orden de dibujo (de atrás hacia delante) de las capas delanteras; las traseras van todas detrás del cuerpo.
local ORDEN = { "pies", "pecho", "piernas", "cabeza", "escudo", "arma" }
local ORDEN_TRAS = { "arma", "escudo", "cabeza", "piernas", "pecho", "pies" }

-- ---------------------------------------------------------------- qué lleva puesto
local function escalon(id)
  return tonumber(tostring(id or ""):match("_(%d+)$"))
end

-- Capas de un personaje: { cuerpo = "p001b", pecho = "i086b", ... }. equipo: hueco -> id de objeto (o nil: todo de escalón 1).
local function capasDe(clase, gen, equipo)
  local L = datos.looks[clase] and datos.looks[clase][gen]
  if not L then return nil end
  local res = { cuerpo = datos.cuerpo[gen] }
  local function de(tier, campo)
    local t = L[tostring(math.max(1, math.min(8, tier or 1)))]
    return t and t[campo]
  end
  for _, hueco in ipairs({ "cabeza", "pecho", "piernas", "pies" }) do
    local id = equipo and equipo[hueco]
    if equipo == nil then res[hueco] = de(1, hueco)
    elseif id then res[hueco] = de(escalon(id), hueco) end
  end
  local arma = equipo and equipo.arma
  if equipo == nil then
    local t = L["1"]
    res.arma = t and t.arma and t.arma[PRINCIPAL[clase]]
  elseif arma then
    local fam = tostring(arma):match("^%a+_(%a+)_%d+$")
    if fam == "arma" then fam = PRINCIPAL[clase] end
    local t = L[tostring(math.max(1, math.min(8, escalon(arma) or 1)))]
    res.arma = t and t.arma and (t.arma[fam] or t.arma[PRINCIPAL[clase]])
  end
  local esc = equipo and equipo.escudo
  if esc then res.escudo = de(escalon(esc), "escudo") end
  return res
end

-- ---------------------------------------------------------------- hojas
local hojas = {}
local quads = {}

local function hoja(cap, anim, lado)
  local k = cap .. "/" .. anim .. "_" .. lado
  local h = hojas[k]
  if h == nil then
    local meta = datos.capas[cap] and datos.capas[cap][anim .. "_" .. lado]
    local ruta = "arte/fao/" .. cap .. "/" .. datos.anims[anim].archivo .. "_" .. (lado == "f" and "f" or lado == "m" and "m" or "b") .. ".png"
    if meta and love.filesystem.getInfo(ruta) then
      local img = love.graphics.newImage(ruta, { mipmaps = true })
      img:setFilter("linear", "linear")
      img:setMipmapFilter("linear", 0)
      h = { img = img, w = meta.w, h = meta.h, x = meta.x, y = meta.y, quads = {} }
    else
      h = false
    end
    hojas[k] = h
  end
  return h or nil
end

local function capa(cap, anim, lado, idx, flip, sx, sy, k)
  local h = hoja(cap, anim, lado)
  if not h then return end
  local q = h.quads[idx]
  if not q then
    q = love.graphics.newQuad(idx * h.w, 0, h.w, h.h, h.img:getDimensions())
    h.quads[idx] = q
  end
  love.graphics.draw(h.img, q, sx, sy, 0, flip and -k or k, k, h.x, h.y)
end

-- Qué animación usa una pieza cuando no tiene la pedida (muchas piezas exóticas solo traen Wait, Run, Hurt y Att2). Para las armaduras
-- nunca se oculta la pieza (el personaje se vería desnudo): Cast -> Att, Dead -> Hurt (su última pose). Las armas se ocultan al morir y
-- en Cast usan la pose de Wait. Si la animación sustituta tiene menos pasos, se repite su último cuadro.
local CADENA = {
  wait = { "wait" }, run = { "run", "wait" }, hurt = { "hurt", "wait" },
  att = { "att", "att2", "att3", "wait" }, sht = { "sht", "att", "att2", "att3", "wait" },
  cast = { "cast", "att", "att2", "att3", "wait" }, dead = { "dead", "hurt", "wait" },
}
local CADENA_ARMA = { cast = { "cast", "wait" }, sht = { "sht", "att", "att2", "att3", "wait" } }

-- Dibuja la capa `cap` en la animación `anim` (paso, dirección 0..4); es_arma elige la cadena de sustitución.
local function capaAnim(cap, anim, paso, d5, es_arma, flip, sx, sy, k, lado)
  lado = lado or "f"
  if es_arma and anim == "dead" then return end
  local cadena = (es_arma and CADENA_ARMA[anim]) or CADENA[anim] or { anim }
  for _, a in ipairs(cadena) do
    local h = hoja(cap, a, lado)
    if h then
      local meta = datos.capas[cap][a .. "_" .. lado]
      local p = math.min(paso, (meta.pasos or datos.anims[a].pasos) - 1)
      capa(cap, a, lado, p * 5 + d5, flip, sx, sy, k)
      return
    end
  end
end

-- ---------------------------------------------------------------- dirección
-- Ocho direcciones en pantalla -> (hoja 0..4, volteada). Las hojas miran: 0 frente, 1 espalda, 2 espalda-izquierda, 3 izquierda,
-- 4 frente-izquierda. Octante 0 = derecha, y de ahí en el sentido de las agujas del reloj (la pantalla crece hacia abajo).
local OCTANTE = {
  [0] = { 3, true }, [1] = { 4, true }, [2] = { 0, false }, [3] = { 4, false },
  [4] = { 3, false }, [5] = { 2, false }, [6] = { 1, false }, [7] = { 2, true },
}
local DIR_MUNDO = { [1] = { 0, 1 }, [2] = { 0, -1 }, [3] = { 1, 0 }, [4] = { -1, 0 } }

local function octante(ang)
  return math.floor((ang + math.pi / 8) / (math.pi / 4)) % 8
end

-- Dirección de pantalla de un movimiento del mundo (dx, dy).
local function angulo(dx, dy)
  if Iso.activo() then return math.atan2((dx + dy) * Iso.HH, (dx - dy) * Iso.HW) end
  return math.atan2(dy, dx)
end

-- Estado de dibujo de cada sujeto (dirección, velocidad, si corre). OJO: el servidor manda una foto cada 0,1 s y Mundo:aplicarFoto REEMPLAZA
-- cada entidad por la tabla nueva (solo conserva `anim`), así que nada de lo que se guarde en `e` sobrevive entre fotos. Por eso este estado
-- vive aquí, por id: si estuviera en `e`, la dirección se reiniciaría diez veces por segundo y volvería a la de las cuatro direcciones
-- cardinales (el personaje parpadeaba entre hojas y se veía deformado al ir en diagonal o en zigzag).
local ESTADO = {}
local ultimaLimpieza = 0

local function est(e)
  local t = love.timer.getTime()
  if t - ultimaLimpieza > 20 then
    ultimaLimpieza = t
    for k, s in pairs(ESTADO) do if t - s.visto > 30 then ESTADO[k] = nil end end
  end
  local k = e.id
  if k == nil then k = e end
  local s = ESTADO[k]
  if not s then s = {}; ESTADO[k] = s end
  s.visto = t
  return s
end

-- Recuerda hacia dónde mira el sujeto: hacia donde se mueve, hacia donde ataca o, quieto, hacia donde miraba.
local function direccion(e, atq)
  local s = est(e)
  if e._f8 and not s.f8 then s.f8 = e._f8 end        -- (las pruebas fijan el octante inicial)
  if atq and atq.ax then
    s.f8 = octante(math.atan2(atq.ay, atq.ax))
    s.fx = nil
    return s.f8
  end
  -- Se acumula lo recorrido y solo se cambia de dirección cuando ya hay un trozo de camino claro y se aleja del octante actual (histéresis):
  -- el servidor manda las posiciones a saltos y, mirando cada cuadro suelto, la dirección parpadeaba entre hojas distintas.
  if e.x and s.fx then
    s.ax = (s.ax or 0) + (e.x - s.fx)
    s.ay = (s.ay or 0) + (e.y - s.fy)
    if math.sqrt(s.ax * s.ax + s.ay * s.ay) > 0.12 then
      local ang = angulo(s.ax, s.ay)
      local nuevo = octante(ang)
      if s.f8 and nuevo ~= s.f8 then
        local actual = (s.f8 * math.pi / 4)
        local d = math.abs((ang - actual + math.pi) % (2 * math.pi) - math.pi)
        if d > math.pi / 4 * 0.85 then s.f8 = nuevo end       -- solo si se aleja claramente del octante actual
      else
        s.f8 = nuevo
      end
      s.ax, s.ay = 0, 0
    end
  end
  s.fx, s.fy = e.x, e.y
  if os.getenv("DC_DEBUG_DIR") and s.f8 ~= s.f8log then s.f8log = s.f8 require("compartido.infraestructura.log").info("DIR " .. tostring(e.nombre) .. " octante=" .. tostring(s.f8)) end
  if not s.f8 then
    if Iso.activo() then
      -- en isométrico Dibujo ya traduce e.dir a dirección de PANTALLA (1 abajo, 2 arriba, 3 derecha, 4 izquierda)
      s.f8 = ({ [1] = 2, [2] = 6, [3] = 1, [4] = 3 })[e.dir or 1] or 2    -- quieto: de tres cuartos (cara visible), no de perfil
    else
      local v = DIR_MUNDO[e.dir or 1] or DIR_MUNDO[1]
      s.f8 = octante(angulo(v[1], v[2]))
    end
  end
  return s.f8
end

M.direccion = direccion      -- (las pruebas lo usan para comprobar que la dirección no parpadea; también render/mob_anim.lua para PNJ y monturas)

-- Hoja de dirección (0 frente ... 4 frente-izquierda) y si se voltea, para un octante de pantalla.
function M.hojaDeOctante(oc)
  local o = OCTANTE[oc] or OCTANTE[2]
  return o[1], o[2]
end

-- ---------------------------------------------------------------- dibujo
local function semilla(e)
  if type(e.id) == "number" then return e.id end
  local n = 0
  for i = 1, #tostring(e.id or "") do n = n + tostring(e.id):byte(i) end
  return n
end

-- Dibuja a un personaje con sus pies en (sx, sy). e es la entidad (clase, gen, equipo...). Devuelve su altura en píxeles.
function M.dibujar(e, mov, sx, sy, tinte, alfa, estado)
  local gen = e.gen or e.genero or "h"
  local clase = e.clase or "guerrero"
  local c = capasDe(clase, gen, e.equipo)
  if not c then return 40 end
  local atq = e._faoAtq
  local anim, paso = "wait", 0
  local t = love.timer.getTime()
  -- "Caminando" a partir de la velocidad real (no del aviso suelto del servidor, que llega a saltos y alternaba correr y esperar), con
  -- histéresis: empieza a correr por encima de 0,6 casillas/s y solo se para por debajo de 0,25, y el cambio dura un instante (0,12 s).
  do
    local s = est(e)
    local dt = t - (s.velT or t)
    if s.velT and dt > 0 and e.x and s.velX then
      local v = math.sqrt((e.x - s.velX) ^ 2 + (e.y - s.velY) ^ 2) / dt
      s.vel = (s.vel or 0) * 0.85 + v * 0.15            -- velocidad suavizada
    end
    s.velT, s.velX, s.velY = t, e.x, e.y
    local v = s.vel or 0
    if v > 0.6 then s.corre = true elseif v < 0.25 then s.corre = false end
    if mov and v > 0.25 then s.corre = true end
    if s.corre then s.movHasta = t + 0.12 end
  end
  local oc = direccion(e, atq and atq.st)
  local d5, flip = OCTANTE[oc][1], OCTANTE[oc][2]
  if estado and estado.d5 then d5, flip = estado.d5, false end      -- (las pruebas fijan la hoja de dirección)
  if e.kind == "cuerpo" or e.vivo == false then
    anim, paso = "dead", datos.anims.dead.pasos - 1       -- (la última pose; las piezas con menos pasos repiten su último cuadro)
  elseif atq then
    local lejos = atq.st.lejos
    if clase == "cazador" then anim = "sht"   -- el arco no tiene animación de golpe: siempre dispara
    elseif lejos and (clase == "mago" or clase == "clerigo" or clase == "nigromante") then anim = "cast"
    else anim = "att" end
    paso = math.min(datos.anims[anim].pasos - 1, math.floor(math.max(0, atq.u) * datos.anims[anim].pasos))
  elseif (e.flash or 0) > 0 then
    anim, paso = "hurt", math.floor(t * 8) % 2
  elseif est(e).movHasta and t < est(e).movHasta then
    anim, paso = "run", math.floor(t * 12 + semilla(e)) % datos.anims.run.pasos
  else
    anim, paso = "wait", math.floor(t * 3.5 + semilla(e)) % datos.anims.wait.pasos
  end
  if estado then anim, paso = estado.anim or anim, estado.paso or paso end
  if os.getenv("DC_DEBUG_FAO") and not e._dbg then e._dbg = true require("compartido.infraestructura.log").info("FAO " .. tostring(e.nombre) .. " dir=" .. tostring(e.dir) .. " oc=" .. tostring(oc) .. " d5=" .. d5 .. " flip=" .. tostring(flip) .. " anim=" .. anim) end
  local col = tinte or { 1, 1, 1 }
  -- aro de la facción bajo los pies: el reino se distingue de un vistazo
  if e.faccion then
    local f = e.faccion == "umbra" and { 0.65, 0.4, 1 } or { 1, 0.85, 0.35 }
    love.graphics.setColor(f[1], f[2], f[3], 0.38 * (alfa or 1))
    love.graphics.ellipse("line", sx, sy - 1, 13, 5)
  end
  love.graphics.setColor(col[1], col[2], col[3], alfa or 1)
  local k = ESCALA_JUEGO
  capaAnim(c.cuerpo, anim, paso, d5, false, flip, sx, sy, k)
  for _, hueco in ipairs(ORDEN) do
    if c[hueco] then capaAnim(c[hueco], anim, paso, d5, hueco == "arma", flip, sx, sy, k) end
  end
  return 50
end

-- ---------------------------------------------------------------- montado
-- ¿Hay hojas del jinete sentado (<Anim>_m, herramientas/generar_personajes/hornear_equipos.py)?
function M.tieneMontado()
  if not M.activo() then return false end
  local c = datos.capas[datos.cuerpo and datos.cuerpo.h or "p001b"]
  return c ~= nil and c.wait_m ~= nil
end

-- Dibuja al jinete sentado sobre una montura de FAO (render/mob_anim.lua). La montura ya está dibujada con sus pies en (sx, pies): el jinete va
-- en el asiento que ella indica (el origen común de las hojas de FAO, cuadro a cuadro), con su mismo paso de animación y su misma dirección,
-- encima de ella. Devuelve false si no se puede (montura sin datos de asiento): el que llama usa entonces el dibujo de siempre.
-- Cuando ataca o recibe daño sigue sobre el mismo cuadro de montura y usa la animación de ataque o de daño del jinete sentado.
function M.dibujarMontado(e, nomMontura, sx, pies, tinte, alfa, subir)
  if not M.tieneMontado() then return false end
  local MobAnim = require("src.presentacion.render.mob_anim")
  local dx, dy, pasoM, estadoM, hoja, flip = MobAnim.asiento(nomMontura, e.dir)
  if not dx then return false end
  local gen = e.gen or e.genero or "h"
  local clase = e.clase or "guerrero"
  local c = capasDe(clase, gen, e.equipo)
  if not c then return false end
  local atq = e._faoAtq
  local anim, paso = estadoM, pasoM
  if e.kind == "cuerpo" or e.vivo == false then
    anim, paso = "hurt", 1
  elseif atq then
    local lejos = atq.st.lejos
    if clase == "cazador" then anim = "sht"
    elseif lejos and (clase == "mago" or clase == "clerigo" or clase == "nigromante") then anim = "cast"
    else anim = "att" end
    paso = math.min(datos.anims[anim].pasos - 1, math.floor(math.max(0, atq.u) * datos.anims[anim].pasos))
  elseif (e.flash or 0) > 0 then
    anim, paso = "hurt", math.floor(love.timer.getTime() * 8) % 2
  end
  local d5 = hoja         -- la misma hoja de dirección que la montura (0 frente ... 4 frente-izquierda)
  local col = tinte or { 1, 1, 1 }
  love.graphics.setColor(col[1], col[2], col[3], alfa or 1)
  -- El jinete conserva siempre su tamaño original (también sobre las monturas pequeñas): lo que se ajusta es dónde se sienta (monturas.py).
  local x, y, k = sx + dx, pies + dy - (subir or 0), ESCALA_JUEGO
  capaAnim(c.cuerpo, anim, paso, d5, false, flip, x, y, k, "m")
  for _, hueco in ipairs(ORDEN) do
    if c[hueco] then capaAnim(c[hueco], anim, paso, d5, hueco == "arma", flip, x, y, k, "m") end
  end
  return true
end

-- Retrato estático (selección y creación de personaje): de frente, en reposo. equipo = nil -> equipo de escalón 1.
function M.retrato(clase, gen, equipo, sx, sy, k)
  k = (k or 1) * 0.5     -- (las hojas están a tamaño original)
  local e = { clase = clase, gen = gen, equipo = equipo, id = 0 }
  e._f8 = 2
  local c = capasDe(clase, gen or "h", equipo)
  if not c then return end
  love.graphics.setColor(1, 1, 1, 1)
  local idx = 0
  capa(c.cuerpo, "wait", "f", idx, false, sx, sy, k)
  for _, hueco in ipairs(ORDEN) do if c[hueco] then capa(c[hueco], "wait", "f", idx, false, sx, sy, k) end end
end

return M
