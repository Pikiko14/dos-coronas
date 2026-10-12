local Datos = require("compartido.dominio.datos")
local Mapa = require("compartido.dominio.mapa")
local Util = require("compartido.dominio.util")
local Balance = require("compartido.dominio.balance")
local Arbol = require("compartido.dominio.arbol")
local Estados = require("compartido.dominio.estados")
local Items = require("compartido.dominio.items")
local Encanto = require("compartido.dominio.encanto")
local Mascotas = require("compartido.dominio.mascotas")
local Gremios = require("compartido.dominio.gremios")

local Mundo = {}
Mundo.__index = Mundo

local function copia(t)
  local n = {}
  for k, v in pairs(t) do
    if type(v) == "table" then n[k] = copia(v) else n[k] = v end
  end
  return n
end

function Mundo.nuevo()
  local self = setmetatable({}, Mundo)
  self.rng = Util.rng(Datos.SEMILLA)
  math.randomseed(Datos.SEMILLA)
  self.tiempo = 0
  self.seq = 0
  self.entidades = {}
  self.mensajes = {}
  self.numeros = {}
  self.efectos = {}
  self.sonidos = {}
  self.sesiones = {}
  -- puertos de salida que la aplicación enchufa (el dominio no conoce la base de datos)
  self.puertos = {}
  self:iniciarGremios()
  self.gloria = { albor = 0, umbra = 0 }
  self.evento = { tipo = nil, hasta = 0 }
  self.instancia = {
    batalla = { activa = false, tiempo = 0, duracion = 300, puntos = { albor = 0, umbra = 0 }, fin = nil },
    estandarte = { activa = false, tiempo = 0, duracion = 300, puntos = { albor = 0, umbra = 0 }, fin = nil },
  }
  self.mapas = {
    mundo = Mapa.mundo(self.rng),
    batalla = Mapa.batalla(),
    estandarte = Mapa.estandarte(),
    casa = Mapa.casa(),
  }
  self:poblar()
  -- el mundo se genera con semilla fija; después el azar del juego vuelve a ser libre
  math.randomseed(os.time() + math.floor((os.clock() * 1000) % 100000))
  return self
end

function Mundo:idNuevo()
  self.seq = self.seq + 1
  return "e" .. self.seq
end

function Mundo:mapaDe(e)
  if not e or e.modo == "casa" then return self.mapas.casa end
  if e.modo == "batalla" then return self.mapas.batalla end
  if e.modo == "estandarte" then return self.mapas.estandarte end
  return self.mapas.mundo
end

function Mundo:ciudadEn(x, y)
  for _, c in ipairs(self.mapas.mundo.ciudades) do
    if x >= c.x and x < c.x + c.w and y >= c.y and y < c.y + c.h then return c end
  end
end

function Mundo:enSantuario(e)
  if not e or e.modo ~= "mundo" then return false end
  local c = self:ciudadEn(e.x, e.y)
  return c and c.faccion == e.faccion
end

function Mundo:mismoLugar(a, b)
  if not a or not b then return false end
  if a.modo ~= b.modo then return false end
  if a.modo == "casa" and a.casaId ~= b.casaId then return false end
  if (a.z or 0) ~= (b.z or 0) then return false end
  return true
end

function Mundo:sonar(nombre) self.sonidos[#self.sonidos + 1] = nombre end

function Mundo:efecto(tipo, x, y, dur)
  self.efectos[#self.efectos + 1] = {
    tipo = tipo, x = x, y = y, t = 0, dur = dur or 0.42,
  }
end

function Mundo:numero(e, texto, color)
  self.numeros[#self.numeros + 1] = { x = e.x, y = e.y, texto = texto, color = color, vida = 0.9 }
  if #self.numeros > 40 then table.remove(self.numeros, 1) end
end

function Mundo:mensaje(canal, de, texto, origen)
  self.mensajes[#self.mensajes + 1] = {
    canal = canal, de = de or "", texto = texto,
    faccion = origen and origen.faccion or nil,
    -- los avisos del sistema son de quien los recibe; el chat de gremio, solo de su gremio
    para = (canal == "sistema" and origen) and origen.id or nil,
    gremio = (canal == "gremio" and origen) and origen.gremioId or nil,
    x = origen and origen.x or 0, y = origen and origen.y or 0,
    modo = origen and origen.modo or "mundo",
    tiempo = self.tiempo,
  }
  if #self.mensajes > 80 then table.remove(self.mensajes, 1) end
  if origen and canal == "local" then origen.burbuja = { texto = texto, hasta = self.tiempo + 4 } end
end

function Mundo:decir(p, texto)
  texto = Util.limpiar(texto)
  if texto == "" then return end
  local canal = "local"
  if texto:sub(1, 3) == "/m " then canal, texto = "mundo", texto:sub(4)
  elseif texto:sub(1, 3) == "/f " then canal, texto = "faccion", texto:sub(4)
  elseif texto:sub(1, 3) == "/g " then
    if not p.gremioId then self:mensaje("sistema", "", "No perteneces a ningÃºn gremio.", p) return end
    canal, texto = "gremio", texto:sub(4)
  elseif texto == "/ayuda" then
    self:mensaje("sistema", "", "Mover: clic o WASD. Atacar: clic en enemigo. Poderes: 1-6 (árbol: K). Curar: selecciona aliado y pulsa 1. E interactúa. I bolsa, P equipo, T comercio, M mapa, B guerra.", p)
    return
  end
  self:mensaje(canal, p.nombre, texto, p)
end

function Mundo:recalcular(e)
  local c = Datos.clases[e.clase]
  if not c then return end
  local hp, mp = e.hp, e.mp
  e.hpMax = c.hp + (e.nivel - 1) * c.hpN
  e.mpMax = c.mp + (e.nivel - 1) * c.mpN
  e.atk = c.atk + (e.nivel - 1) * c.atkN
  e.def = c.def + (e.nivel - 1) * c.defN
  e.matk = (c.matk or 0) + (e.nivel - 1) * (c.matkN or 0)
  e.mdef = (c.mdef or 0) + (e.nivel - 1) * (c.mdefN or 0)
  e.spd = c.spd
  e.rango = c.rango
  for hueco, itemId in pairs(e.equipo) do
    local it = Datos.item(itemId)
    if it then
      local m = Encanto.mult(e.encantos and e.encantos[hueco])
      e.atk = e.atk + (it.atk or 0) * m
      e.def = e.def + (it.def or 0) * m
      e.matk = e.matk + (it.matk or 0) * m
      e.mdef = e.mdef + (it.mdef or 0) * m
      e.hpMax = e.hpMax + (it.hp or 0) * m
      e.mpMax = e.mpMax + (it.mp or 0) * m
      e.spd = e.spd + (it.spd or 0)
    end
  end
  Arbol.aplicarPasivas(e)
  e.hp = math.min(hp or e.hpMax, e.hpMax)
  e.mp = math.min(mp or e.mpMax, e.mpMax)
end

function Mundo:darItem(p, id, cant, enc)
  local it = Datos.item(id)
  if not it then return false end
  cant = cant or 1
  if it.apila then
    for _, s in ipairs(p.bolsa) do
      if s.id == id and s.cant < it.apila then
        local add = math.min(cant, it.apila - s.cant)
        s.cant = s.cant + add
        cant = cant - add
        if cant <= 0 then return true end
      end
    end
  end
  while cant > 0 do
    if #p.bolsa >= Datos.capacidadBolsa(p.equipo) then return false end
    local add = it.apila and math.min(cant, it.apila) or 1
    p.bolsa[#p.bolsa + 1] = { id = id, cant = add, enc = (not it.apila and enc and enc > 0) and enc or nil }
    cant = cant - add
    if not it.apila then break end
  end
  return true
end

function Mundo:equiparInicial(e)
  for hueco, id in pairs(Items.equipoDe(e.clase, 1)) do e.equipo[hueco] = id end
  self:darItem(e, "pocion_vida", 5)
  self:darItem(e, "pocion_mana", 3)
end

function Mundo:crearPersonaje(opts)
  local ciudad = Datos.capital(opts.faccion)
  local spawn = { x = 30, y = 30 }
  for _, c in ipairs(self.mapas.mundo.ciudades) do
    if c.id == ciudad.id then spawn = { x = c.spawn.x, y = c.spawn.y } end
  end
  local e = {
    id = self:idNuevo(),
    kind = opts.kind or "jugador",
    nombre = opts.nombre or "Aventurero",
    faccion = opts.faccion,
    clase = opts.clase,
    nivel = opts.nivel or 1,
    xp = 0,
    oro = opts.oro or 140,
    x = spawn.x, y = spawn.y, z = 0,
    modo = "mundo",
    dir = 1,
    vivo = true,
    equipo = {},
    bolsa = {},
    misiones = {},
    casas = {},
    caceria = {},
    cds = {},
    buffs = {},
    velx = 0, vely = 0,
    -- los bots no usan el árbol: tienen los poderes que da su nivel
    habilidades = opts.kind ~= "bot" and Arbol.iniciales(opts.clase) or nil,
  }
  self:equiparInicial(e)
  self:recalcular(e)
  e.hp, e.mp = e.hpMax, e.mpMax
  e.vinculo = { x = e.x, y = e.y, modo = "mundo" }
  if opts.kind ~= "bot" then
    local tier = Items.tierPara(opts.nivel)
    if tier > 1 then
      for hueco, id in pairs(Items.equipoDe(e.clase, tier)) do e.equipo[hueco] = id end
      self:recalcular(e)
      e.hp, e.mp = e.hpMax, e.mpMax
    end
  end
  self.entidades[e.id] = e
  return e
end

function Mundo:spawnMonstruo(idMon, x, y, hogar)
  local def = Datos.monstruo(idMon)
  if not def then return end
  local st = Datos.statsMonstruo(def)
  local e = {
    id = self:idNuevo(),
    kind = "monstruo",
    monstruo = def.id,
    nombre = def.nombre,
    nivel = def.nivel,
    x = x, y = y,
    hogarx = hogar and hogar.x or x,
    hogary = hogar and hogar.y or y,
    modo = "mundo",
    dir = 1,
    vivo = true,
    hp = st.hp, hpMax = st.hp,
    atk = st.atk, def = st.def, matk = st.matk, mdef = st.mdef, tipoDano = st.dano,
    spd = st.velocidad, rango = st.rango,
    xp = st.xp, oro = st.oro,
    agresivo = def.agresivo,
    elite = def.elite,
    cds = {},
    hoja = def.hoja, base = def.base, cuadros = def.cuadros,
    tam = def.tam, paso = def.paso, porDir = def.porDir,
    sensor = math.random(),
    respawn = 0,
    golpe = def.golpe, poderes = def.poderes,
  }
  -- que no lancen todos sus poderes a la vez al aparecer
  for _, id in ipairs(def.poderes or {}) do
    local pw = Estados.poderes[id]
    if pw then e.cds[id] = self.tiempo + math.random() * pw.cd end
  end
  self.entidades[e.id] = e
  return e
end

function Mundo:poblar()
  for _, c in ipairs(self.mapas.mundo.ciudades) do
    for _, n in ipairs(c.npcs) do
      local e = {
        id = self:idNuevo(), kind = n.rol == "guardia" and "guardia" or "npc",
        nombre = n.nombre, rol = n.rol, faccion = n.faccion,
        x = n.x, y = n.y, modo = "mundo", dir = 1, vivo = true,
        clase = ({ mercado = "mago", heraldo = "clerigo", mayordomo = "guerrero", encargos = "cazador", guardia = "guerrero", encantador = "mago", criador = "cazador", gremio = "guerrero" })[n.rol] or "guerrero",
        nivel = 12, hp = 400, hpMax = 400, atk = 28, def = 14, matk = 8, mdef = 7, spd = 3.2, rango = 1.4,
        cds = {},
        equipo = { arma = "guerrero_arma_2", pecho = "guerrero_pecho_2", cabeza = "guerrero_cabeza_2" },
      }
      self.entidades[e.id] = e
    end
  end
  for _, camp in ipairs(self.mapas.mundo.campamentos) do
    for i = 1, camp.cantidad do
      local ang = (i / camp.cantidad) * math.pi * 2
      local x = camp.x + math.cos(ang) * 1.2
      local y = camp.y + math.sin(ang) * 1.2
      self:spawnMonstruo(camp.monstruo, x, y, camp)
    end
  end
  self:crearObjetivos()
end

function Mundo:crearObjetivos()
  for id, e in pairs(self.entidades) do
    if e.modo == "batalla" or e.modo == "estandarte" then self.entidades[id] = nil end
  end
  for _, o in ipairs(self.mapas.batalla.objetivos) do
    local hp = o.tipo == "puerta" and 1100 or 780
    local e = {
      id = self:idNuevo(),
      kind = o.tipo,
      nombre = (o.tipo == "altar" and "Altar de cristales" or o.tipo == "puerta" and "Puerta" or "Estatua") .. " de " .. (o.faccion == "albor" and "Albor" or "Umbra"),
      faccion = o.faccion, x = o.x, y = o.y, modo = "batalla", vivo = true,
      hp = o.tipo == "altar" and 1 or hp,
      hpMax = o.tipo == "altar" and 1 or hp,
      def = 0, estructura = o.tipo ~= "altar",
      tx = math.floor(o.x), ty = math.floor(o.y),
    }
    self.entidades[e.id] = e
  end
  for fac, pos in pairs(self.mapas.estandarte.banderas) do
    local e = {
      id = self:idNuevo(), kind = "bandera",
      nombre = "Estandarte de " .. (fac == "albor" and "Albor" or "Umbra"),
      faccion = fac, x = pos.x, y = pos.y, origenx = pos.x, origeny = pos.y,
      modo = "estandarte", vivo = true, portador = nil,
    }
    self.entidades[e.id] = e
  end
  local function cerrar(mapa)
    if not mapa.puerta then return end
    for _, p in pairs(mapa.puerta) do
      p.viva = true
      mapa.bloque[p.x] = mapa.bloque[p.x] or {}
      mapa.bloque[p.x][p.y] = true
    end
  end
  cerrar(self.mapas.batalla)
end

-- Movimiento por casillas, como Tibia: cada paso lleva a la casilla vecina
-- (8 direcciones, la diagonal tarda √2), nadie atraviesa a nadie y la
-- casilla de destino queda reservada desde que empieza el paso.
local RAIZ2 = 1.41421
local VECINOS = {
  { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
  { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 },
}
local ESPERA_BLOQUEO = 1.2

local function ocupa(kind)
  return kind == "jugador" or kind == "bot" or kind == "monstruo" or kind == "guardia" or kind == "npc"
end

local function signo(n)
  if n > 0 then return 1 end
  if n < 0 then return -1 end
  return 0
end

-- Casilla que la criatura ocupa o ha reservado.
function Mundo:casilla(e)
  if e.tramo then return e.tx, e.ty end
  return math.floor(e.x), math.floor(e.y)
end

function Mundo:terrenoLibre(e, tx, ty)
  local mapa = self:mapaDe(e)
  if (e.z or 0) > 0 and e.modo == "mundo" then
    return (mapa.alto and mapa.alto[tx] and mapa.alto[tx][ty]) and true or false
  end
  return not Mapa.bloqueado(mapa, tx + 0.5, ty + 0.5, e.faccion)
end

function Mundo:casillaOcupada(e, tx, ty)
  for _, o in pairs(self.entidades) do
    if o ~= e and o.vivo ~= false and ocupa(o.kind) and self:mismoLugar(e, o) then
      local ox, oy = self:casilla(o)
      if ox == tx and oy == ty then return true end
    end
  end
  return false
end

-- ¿Puede e pasar de su casilla (tx, ty) a la vecina (tx+ddx, ty+ddy)?
function Mundo:puedePasar(e, tx, ty, ddx, ddy)
  local nx, ny = tx + ddx, ty + ddy
  if not self:terrenoLibre(e, nx, ny) then return false end
  if ddx ~= 0 and ddy ~= 0 then
    if not self:terrenoLibre(e, nx, ty) or not self:terrenoLibre(e, tx, ny) then return false end
  end
  return not self:casillaOcupada(e, nx, ny)
end

function Mundo:encarar(e, dx, dy)
  if dx == 0 and dy == 0 then return end
  if math.abs(dx) > 0.05 and (math.abs(dx) >= math.abs(dy) * 0.7 or dy == 0) then
    e.dir = dx > 0 and 3 or 4
  else
    e.dir = dy > 0 and 1 or 2
  end
end

function Mundo:iniciarPaso(e, ddx, ddy, spd)
  local tx, ty = math.floor(e.x), math.floor(e.y)
  if not self:puedePasar(e, tx, ty, ddx, ddy) then
    -- Una diagonal bloqueada se desliza por el eje que sí está libre.
    local ok = false
    if ddx ~= 0 and ddy ~= 0 then
      if self:puedePasar(e, tx, ty, ddx, 0) then ddy, ok = 0, true
      elseif self:puedePasar(e, tx, ty, 0, ddy) then ddx, ok = 0, true end
    end
    if not ok then
      self:encarar(e, ddx, ddy)
      return false
    end
  end
  local nx, ny = tx + ddx, ty + ddy
  local largo = (ddx ~= 0 and ddy ~= 0) and RAIZ2 or 1
  e.tramo = {
    ox = e.x, oy = e.y, dx = nx + 0.5, dy = ny + 0.5,
    t = 0, dur = largo / math.max(0.2, spd or 1), cx = e.x, cy = e.y,
  }
  e.tx, e.ty = nx, ny
  self:encarar(e, ddx, ddy)
  return true
end

-- Avanza el paso en curso y encadena los siguientes mientras haya dirección.
function Mundo:avanzar(e, dt, ddx, ddy, spd)
  local p = e.tramo
  if p and (math.abs(e.x - p.cx) > 0.5 or math.abs(e.y - p.cy) > 0.5) then
    e.tramo = nil
  end
  local resto, movio = dt, false
  for _ = 1, 3 do
    p = e.tramo
    if p then
      movio = true
      local falta = p.dur - p.t
      if resto < falta then
        p.t = p.t + resto
        local k = p.t / p.dur
        e.x = p.ox + (p.dx - p.ox) * k
        e.y = p.oy + (p.dy - p.oy) * k
        p.cx, p.cy = e.x, e.y
        break
      end
      resto = resto - falta
      e.x, e.y = p.dx, p.dy
      e.tramo = nil
    end
    if ddx == 0 and ddy == 0 then break end
    if not self:iniciarPaso(e, ddx, ddy, spd) then break end
  end
  e.mov = e.tramo ~= nil
  if movio or e.tramo then e.anim = (e.anim or 0) + dt * (e.kind == "monstruo" and 6 or 8) end
  e.velx, e.vely = e.mov and ddx or 0, e.mov and ddy or 0
  return e.mov
end

-- Mejor dirección libre hacia (dx, dy); rodea lo que estorba.
function Mundo:mejorDireccion(e, dx, dy)
  local d = math.sqrt(dx * dx + dy * dy)
  if d < 1e-6 then return 0, 0 end
  dx, dy = dx / d, dy / d
  local tx, ty = math.floor(e.x), math.floor(e.y)
  local cand = {}
  for _, v in ipairs(VECINOS) do
    local largo = (v[1] ~= 0 and v[2] ~= 0) and RAIZ2 or 1
    local punto = (v[1] * dx + v[2] * dy) / largo
    if punto > 0.35 then cand[#cand + 1] = { v[1], v[2], punto } end
  end
  table.sort(cand, function(a, b) return a[3] > b[3] end)
  for _, c in ipairs(cand) do
    if self:puedePasar(e, tx, ty, c[1], c[2]) then return c[1], c[2] end
  end
  return 0, 0
end

-- Coloca a e en la casilla libre más cercana a (x, y), sin animar el paso.
function Mundo:colocarCerca(e, x, y)
  local cx, cy = math.floor(x), math.floor(y)
  local mejor, md
  for r = 0, 2 do
    for dy = -r, r do
      for dx = -r, r do
        local tx, ty = cx + dx, cy + dy
        if self:terrenoLibre(e, tx, ty) and not self:casillaOcupada(e, tx, ty) then
          local d = (tx + 0.5 - x) ^ 2 + (ty + 0.5 - y) ^ 2
          if not md or d < md then mejor, md = { tx, ty }, d end
        end
      end
    end
    if mejor then break end
  end
  if not mejor then return false end
  e.tramo = nil
  e.x, e.y = mejor[1] + 0.5, mejor[2] + 0.5
  return true
end

local function cortarCamino(cam)
  if not cam or #cam <= 80 then return cam end
  local corto = {}
  for i = 1, 80 do corto[i] = cam[i] end
  return corto
end

function Mundo:fijarDestino(e, x, y)
  e.metaX, e.metaY = x, y
  local mapa = self:mapaDe(e)
  if e.modo == "mundo" and (e.z or 0) == 0 then
    e.camino = cortarCamino(Mapa.buscar(mapa, e.x, e.y, x, y)) or { { x = x, y = y } }
  else
    e.camino = { { x = x, y = y } }
  end
  e.persigue = false
end

-- Siguiente dirección de la ruta de e, casilla a casilla.
function Mundo:direccionCamino(e, dt)
  local cam = e.camino
  if not cam or #cam == 0 then return 0, 0 end
  local tx, ty = math.floor(e.x), math.floor(e.y)
  while cam[1] and math.floor(cam[1].x) == tx and math.floor(cam[1].y) == ty do
    table.remove(cam, 1)
  end
  local w = cam[1]
  if not w then
    e.camino, e.bloqueado = nil, nil
    return 0, 0
  end
  local ddx, ddy = signo(math.floor(w.x) - tx), signo(math.floor(w.y) - ty)
  local ok = self:puedePasar(e, tx, ty, ddx, ddy)
  if not ok and ddx ~= 0 and ddy ~= 0 then
    ok = self:puedePasar(e, tx, ty, ddx, 0) or self:puedePasar(e, tx, ty, 0, ddy)
  end
  if ok then
    e.bloqueado = nil
    return ddx, ddy
  end
  e.bloqueado = (e.bloqueado or 0) + (dt or 0)
  if e.bloqueado > ESPERA_BLOQUEO then
    e.bloqueado = nil
    if e.metaX and e.modo == "mundo" and (e.z or 0) == 0 then
      e.camino = cortarCamino(Mapa.buscar(self:mapaDe(e), e.x, e.y, e.metaX, e.metaY))
    else
      e.camino = nil
    end
  end
  return 0, 0
end

-- Alcance de ataque de e: el cuerpo a cuerpo llega a las diagonales.
function Mundo:alcance(e)
  local r = e.rango or 1.4
  if r < 2 then r = 1.5 end
  return r
end

-- Dirección que lleva a e tras su objetivo (persecución) o por su ruta.
function Mundo:direccionAutomatica(e, dt)
  local o = e.persigue and e.objetivo and self.entidades[e.objetivo]
  if o and o.vivo and self:mismoLugar(e, o) then
    local rango = self:alcance(e)
    local d = Util.dist(e.x, e.y, o.x, o.y)
    local parar = rango > 3 and rango * 0.85 or rango
    if d <= parar then
      e.camino = nil
      self:encarar(e, o.x - e.x, o.y - e.y)
      return 0, 0
    end
    if e.modo == "mundo" and (e.z or 0) == 0 then
      if (e.recalc or 0) <= self.tiempo then
        e.recalc = self.tiempo + 0.45
        e.metaX, e.metaY = o.x, o.y
        e.camino = cortarCamino(Mapa.buscar(self:mapaDe(e), e.x, e.y, o.x, o.y))
      end
      if e.camino and #e.camino > 0 then return self:direccionCamino(e, dt) end
    end
    return self:mejorDireccion(e, o.x - e.x, o.y - e.y)
  end
  return self:direccionCamino(e, dt)
end

function Mundo:buffMul(e, campo)
  local m = 1
  for _, b in ipairs(e.buffs or {}) do
    if b[campo] then m = m + b[campo] end
  end
  return m
end

function Mundo:tieneBuff(e, id)
  for _, b in ipairs(e.buffs or {}) do
    if b.id == id then return b end
  end
end

function Mundo:ponerBuff(e, id, dur, extra)
  e.buffs = e.buffs or {}
  for i, b in ipairs(e.buffs) do
    if b.id == id then table.remove(e.buffs, i) break end
  end
  local b = { id = id, dur = dur }
  if extra then for k, v in pairs(extra) do b[k] = v end end
  e.buffs[#e.buffs + 1] = b
end

function Mundo:puedeDanar(origen, objetivo)
  if not origen or not objetivo or not objetivo.vivo then return false end
  local kind = objetivo.kind
  if kind == "mascota" then
    -- solo las criaturas hostiles pueden herir a una mascota
    return origen.kind == "monstruo"
  end
  if kind ~= "jugador" and kind ~= "bot" and kind ~= "guardia" and kind ~= "monstruo" and kind ~= "estatua" and kind ~= "puerta" then
    return false
  end
  if kind == "estatua" or kind == "puerta" then
    return origen.faccion and origen.faccion ~= objetivo.faccion
  end
  if kind == "monstruo" or origen.kind == "monstruo" then return true end
  if origen.faccion and objetivo.faccion and origen.faccion == objetivo.faccion then return false end
  if self:enSantuario(objetivo) then return false end
  return true
end

function Mundo:aliado(a, b)
  if not a or not b or not b.vivo then return false end
  local kind = b.kind
  if kind ~= "jugador" and kind ~= "bot" and kind ~= "guardia" then return false end
  return a.faccion and a.faccion == b.faccion
end

-- Con qué pega por defecto una criatura: los monstruos según su perfil, los
-- personajes según su oficio (guerrero y cazador, físico; mago y clérigo, mágico).
function Mundo:tipoDanoBasico(e)
  if e.tipoDano then return e.tipoDano end
  local c = Datos.clases[e.clase]
  return (c and c.danoBasico) or "fisico"
end

-- Un golpe de origen a objetivo: se tira entre el mínimo y el máximo que da el
-- ataque de origen (ver Balance.tirarDano). tipo es "fisico" (ataque contra defensa)
-- o "magico" (ataque mágico contra defensa mágica). coef es el poder del golpe y
-- mult un factor extra (por ejemplo 0.85 en daño en área).
function Mundo:golpear(origen, objetivo, coef, mult, tipo)
  if not origen or not objetivo then return end
  tipo = tipo or self:tipoDanoBasico(origen)
  local atk, def
  if tipo == "magico" then
    atk, def = origen.matk or origen.atk or 0, objetivo.mdef or 0
  else
    atk, def = origen.atk or 0, objetivo.def or 0
  end
  atk = atk * self:buffMul(origen, "atk")
  local c = Datos.clases[origen.clase]
  if c and c.danoMul then atk = atk * c.danoMul end
  local dano, critico = Balance.tirarDano(atk, def, coef)
  dano = math.max(1, math.floor(dano * Balance.modNivel(origen.nivel, objetivo.nivel) + 0.5))
  if mult then dano = math.max(1, math.floor(dano * mult + 0.5)) end
  self:danar(objetivo, dano, origen, critico)
  return dano, critico
end

function Mundo:danar(objetivo, cantidad, origen, critico, color)
  if not objetivo or not objetivo.vivo or type(objetivo.hp) ~= "number" then return end
  if origen and not self:puedeDanar(origen, objetivo) then return end
  cantidad = math.max(1, math.floor(cantidad))
  if (objetivo.mascotaBono or 0) > 0 then cantidad = math.max(1, math.floor(cantidad * (1 - objetivo.mascotaBono))) end
  local esc = self:tieneBuff(objetivo, "escudo")
  if esc and esc.absorbe and esc.absorbe > 0 then
    local uso = math.min(esc.absorbe, cantidad)
    esc.absorbe = esc.absorbe - uso
    cantidad = cantidad - uso
    if cantidad <= 0 then
      self:numero(objetivo, "absorb", { 0.6, 0.75, 1 })
      return
    end
  end
  objetivo.hp = objetivo.hp - cantidad
  objetivo.ultimoGolpe = self.tiempo
  objetivo.flash = 0.12
  if origen then objetivo.amenaza = origen.id end
  if critico then
    self:numero(objetivo, "-" .. cantidad .. "!", { 1, 0.85, 0.2 })
  else
    self:numero(objetivo, tostring(-cantidad), color or { 1, 0.45, 0.35 })
  end
  if objetivo.hp <= 0 then self:morir(objetivo, origen) end
end

-- Pide guardar a este jugador en breve (el servicio lo recoge en su ronda de guardado).
function Mundo:marcarProgreso(p)
  if p and p.kind == "jugador" then p.pendienteGuardar = true end
end

function Mundo:curar(objetivo, cantidad, origen)
  if not objetivo.vivo or not objetivo.hp or not objetivo.hpMax then return end
  cantidad = math.floor(cantidad)
  objetivo.hp = math.min(objetivo.hpMax, objetivo.hp + cantidad)
  self:numero(objetivo, "+" .. cantidad, { 0.4, 1, 0.45 })
  if origen then origen.ultimoApoyo = self.tiempo end
end

function Mundo:ganarXp(p, cant)
  if p.kind ~= "jugador" and p.kind ~= "bot" then return end
  p.xp = (p.xp or 0) + cant
  local subio = false
  while p.nivel < Datos.NIVEL_MAX and p.xp >= Datos.xpPara(p.nivel) do
    p.xp = p.xp - Datos.xpPara(p.nivel)
    p.nivel = p.nivel + 1
    subio = true
  end
  if subio then
    self:marcarProgreso(p)
    self:recalcular(p)
    p.hp, p.mp = p.hpMax, p.mpMax
    self:mensaje("sistema", "", p.nombre .. " alcanza el nivel " .. p.nivel .. ".", p)
    if p.habilidades and Arbol.puntos(p) > 0 then
      self:mensaje("sistema", "", "Tienes " .. Arbol.puntos(p) .. " punto(s) de habilidad: abre el árbol con K.", p)
    end
    self:numero(p, "NIVEL " .. p.nivel, { 1, 0.9, 0.35 })
  end
end

function Mundo:soltarBotin(m, asesino)
  if not asesino or asesino.kind == "bot" then
    if asesino and asesino.kind == "bot" then asesino.oro = (asesino.oro or 0) + m.oro end
    return
  end
  local loot = {
    id = self:idNuevo(), kind = "loot", nombre = "Botín",
    x = m.x, y = m.y,     modo = m.modo, vivo = true, z = m.z or 0,
    oro = m.oro, items = {}, dueno = asesino.id, hasta = self.tiempo + 45,
  }
  for _, it in ipairs(Balance.tirar(m)) do
    loot.items[#loot.items + 1] = it
  end
  if math.random() < 0.12 then
    local tier = Items.tierPara(m.nivel)
    if tier > 1 and math.random() < 0.35 then tier = tier - 1 end
    local id = Items.aleatorio(Datos, asesino.clase or "guerrero", tier)
    if Datos.item(id) then loot.items[#loot.items + 1] = { id = id, cant = 1 } end
  end
  -- polvo arcano para encantar: casi todas las criaturas lo sueltan, más las de más nivel
  if math.random() < 0.45 then
    loot.items[#loot.items + 1] = { id = "polvo_arcano", cant = math.random(1, 1 + math.floor((m.nivel or 1) / 8)) }
  end
  if math.random() < 0.04 then
    local tier = math.min(4, math.floor((m.nivel or 1) / 6) + 1)
    loot.items[#loot.items + 1] = { id = "mochila_" .. tier, cant = 1 }
  end
  self.entidades[loot.id] = loot
end

function Mundo:morir(e, origen)
  e.vivo = false
  e.hp = 0
  self:limpiarEstados(e)
  if e.kind == "mascota" then
    self:caeMascota(e)
    return
  end
  if e.kind == "monstruo" then
    if origen and (origen.kind == "jugador" or origen.kind == "bot") then
      local exp = Balance.xpMonstruo(origen.nivel or 1, e.nivel or 1, e.elite)
      if exp > 0 then
        exp = math.floor(exp * self:bonoGremio(origen) + 0.5)
        self:ganarXp(origen, exp)
        self:mascotaGanaXp(origen, exp)
      end
      origen.oro = (origen.oro or 0) + math.floor((e.oro or 5) * 0.3)
      origen.caceria = origen.caceria or {}
      origen.caceria[e.monstruo] = (origen.caceria[e.monstruo] or 0) + 1
      self:avanzarMisiones(origen, e.monstruo)
      if origen.kind == "jugador" then self:soltarBotin(e, origen) end
    end
    e.respawn = self.tiempo + (e.elite and 90 or 22)
    if e.elite then
      self:mensaje("sistema", "", e.nombre .. " ha caído.", origen)
    end
  elseif e.kind == "jugador" or e.kind == "bot" then
    e.respawn = self.tiempo + 6
    if e.modo == "estandarte" and e.llevaBandera then self:soltarBandera(e) end
    if origen and origen.faccion and origen.faccion ~= e.faccion then
      self.gloria[origen.faccion] = (self.gloria[origen.faccion] or 0) + 8
      local inst = self.instancia[e.modo]
      if inst and inst.activa then
        inst.puntos[origen.faccion] = inst.puntos[origen.faccion] + (e.modo == "batalla" and 20 or 10)
      end
    end
    self:mensaje("sistema", "", e.nombre .. " ha caído.", e)
  elseif e.kind == "estatua" or e.kind == "puerta" then
    local fac = origen and origen.faccion
    if fac then
      local inst = self.instancia.batalla
      local pts = e.kind == "puerta" and 160 or 100
      inst.puntos[fac] = inst.puntos[fac] + pts
      if origen.kind == "jugador" or origen.kind == "bot" then
        self:darItem(origen, "cristal", 1)
        origen.cristales = (origen.cristales or 0) + 1
      end
      self:mensaje("sistema", "", e.nombre .. " cae. " .. (fac == "albor" and "Albor" or "Umbra") .. " obtiene un cristal enemigo. +" .. pts .. " puntos.", origen)
      if e.kind == "puerta" then
        local mapa = self.mapas.batalla
        if mapa.puerta then
          local p = mapa.puerta[e.tx .. "_" .. e.ty]
          if p then p.viva = false end
        end
        if mapa.bloque[e.tx] then mapa.bloque[e.tx][e.ty] = nil end
      end
    end
  end
end

function Mundo:avanzarMisiones(p, monId)
  for _, q in pairs(p.misiones) do
    if q.aceptada and not q.entregada and q.monstruo == monId then
      q.progreso = math.min(q.cantidad, (q.progreso or 0) + 1)
      if q.progreso >= q.cantidad then
        self:mensaje("sistema", "", "Encargo cumplido: " .. q.titulo .. ". Vuelve al tablón.", p)
      end
    end
  end
end

function Mundo:revivir(e)
  e.vivo = true
  self:limpiarEstados(e)
  e.hp, e.mp = e.hpMax or e.hp, e.mpMax or 0
  e.aturdido = 0
  e.camino = nil
  e.tramo = nil
  e.objetivo = nil
  if e.kind == "monstruo" then
    e.x, e.y = e.hogarx, e.hogary
    e.hp = e.hpMax
  elseif e.kind == "jugador" or e.kind == "bot" then
    local v = e.vinculo or { x = e.x, y = e.y, modo = "mundo" }
    if e.modo == "batalla" or e.modo == "estandarte" then
      local sp = self.mapas[e.modo].spawns[e.faccion]
      e.x, e.y = sp.x, sp.y
    else
      e.modo = v.modo or "mundo"
      e.x, e.y = v.x, v.y
    end
    e.hp = e.hpMax
    e.mp = e.mpMax or e.mp
  elseif e.estructura then
    e.hp = e.hpMax
  end
end

function Mundo:recoger(p, loot)
  self:marcarProgreso(p)
  p.oro = p.oro + (loot.oro or 0)
  for _, it in ipairs(loot.items or {}) do
    if not self:darItem(p, it.id, it.cant) then
      self:mensaje("sistema", "", "La bolsa está llena.", p)
    else
      local d = Datos.item(it.id)
      self:mensaje("sistema", "", "Recoges " .. (d and d.nombre or it.id) .. ".", p)
    end
  end
  if (loot.oro or 0) > 0 then
    self:mensaje("sistema", "", "Recoges " .. loot.oro .. " de oro.", p)
  end
  loot.borrar = true
end

function Mundo:usarHabilidad(p, slot, tx, ty)
  if not p.vivo or (p.aturdido or 0) > 0 then return "No puedes actuar." end
  local idh = Datos.barra[p.clase][slot]
  local rango = idh and Arbol.rango(p, idh) or 0
  if rango < 1 then return idh and "Aún no conoces ese poder: abre el árbol (K)." or nil end
  local h = Arbol.efectiva(idh, rango)
  if not h then return end
  if (p.cds[idh] or 0) > self.tiempo then return "Aún no." end
  if p.mp < h.mana then return "Sin maná." end
  local objetivo = p.objetivo and self.entidades[p.objetivo]
  local function enRango(obj, r)
    return obj and self:mismoLugar(p, obj) and Util.dist(p.x, p.y, obj.x, obj.y) <= r + 0.3
  end
  if h.tipo == "enemigo" then
    if not objetivo or not self:puedeDanar(p, objetivo) then return "Elige un enemigo." end
    if not enRango(objetivo, h.rango) then
      p.persigue = true
      p.habilidadPendiente = slot
      return "Te acercas."
    end
  elseif h.tipo == "aliado" then
    if not objetivo or not self:aliado(p, objetivo) then objetivo = p end
    if not enRango(objetivo, h.rango) then
      p.persigue = true
      p.habilidadPendiente = slot
      return "Te acercas."
    end
  end
  p.mp = p.mp - h.mana
  p.cds[idh] = self.tiempo + h.cd
  p.gcd = self.tiempo + 0.35
  p.swing = 0.2
  p.ultimoGolpe = self.tiempo
  if h.dash and objetivo then
    local dx, dy = objetivo.x - p.x, objetivo.y - p.y
    local d = math.max(0.1, math.sqrt(dx * dx + dy * dy))
    self:colocarCerca(p, objetivo.x - dx / d, objetivo.y - dy / d)
  end
  local function golpe(obj, coef)
    self:golpear(p, obj, coef, nil, h.dano or "fisico")
    if obj.vivo then self:probarEstado(p, obj, h.estado) end
  end
  if h.proyectil and objetivo then
    self:proyectil(p, objetivo, h)
  elseif h.tipo == "enemigo" and objetivo then
    golpe(objetivo, h.coef)
    if h.aturde and objetivo.vivo then self:aplicarEstado(objetivo, "aturdir", h.aturde, nil, p) end
  elseif h.tipo == "alrededor" then
    for _, o in pairs(self.entidades) do
      if o.vivo and self:mismoLugar(p, o) and self:puedeDanar(p, o) and Util.dist(p.x, p.y, o.x, o.y) <= h.rango then
        golpe(o, h.coef)
        if h.lentitud and o.vivo then self:aplicarEstado(o, "lentitud", 3, h.lentitud, p) end
      end
    end
  elseif h.tipo == "punto" then
    local px, py = tx or (objetivo and objetivo.x) or p.x, ty or (objetivo and objetivo.y) or p.y
    for _, o in pairs(self.entidades) do
      if o.vivo and self:mismoLugar(p, o) and self:puedeDanar(p, o) and Util.dist(px, py, o.x, o.y) <= (h.aoe or 2) then
        golpe(o, h.coef)
      end
    end
  elseif h.tipo == "aliado" then
    if h.cura then self:curar(objetivo, self:potenciaCura(p, h), p) end
    if h.buff == "bendicion" then self:ponerBuff(objetivo, "bendicion", h.dur, { def = 0.18 * h.pot, regen = 4 * h.pot }) end
  elseif h.tipo == "propio" then
    if h.buff == "escudo" then
      local abs = (30 + p.nivel * 4) * h.pot
      self:ponerBuff(p, "escudo", h.dur, { absorbe = abs })
      self:numero(p, "escudo", { 0.55, 0.7, 1 })
    else
      -- potenciadores propios (furia, paso ágil...): sus cifras crecen con el rango
      local ef = {}
      for k, v in pairs(h.efecto or {}) do ef[k] = v * h.pot end
      self:ponerBuff(p, h.buff, h.dur, ef)
      self:numero(p, h.nombre, { 1, 0.85, 0.4 })
    end
  elseif h.tipo == "aliados" then
    for _, o in pairs(self.entidades) do
      if o.vivo and self:mismoLugar(p, o) and self:aliado(p, o) and Util.dist(p.x, p.y, o.x, o.y) <= h.rango then
        self:curar(o, self:potenciaCura(p, h), p)
      end
    end
  elseif h.tipo == "buff_alrededor" then
    for _, o in pairs(self.entidades) do
      if o.vivo and self:aliado(p, o) and Util.dist(p.x, p.y, o.x, o.y) <= h.rango then
        self:ponerBuff(o, "grito", h.dur, { atk = 0.22 * h.pot })
      end
    end
    self:ponerBuff(p, "grito", h.dur, { atk = 0.22 * h.pot })
  elseif h.tipo == "mixto" then
    for _, o in pairs(self.entidades) do
      if o.vivo and self:mismoLugar(p, o) and Util.dist(p.x, p.y, o.x, o.y) <= h.rango then
        if self:puedeDanar(p, o) then golpe(o, h.coef)
        elseif self:aliado(p, o) then self:curar(o, self:potenciaCura(p, h), p) end
      end
    end
    self:curar(p, self:potenciaCura(p, h), p)
  elseif h.tipo == "suelo" then
    local id = self:idNuevo()
    self.entidades[id] = {
      id = id, kind = "trampa", nombre = "Trampa", faccion = p.faccion,
      x = p.x, y = p.y, modo = p.modo, vivo = true, dueno = p.id,
      hasta = self.tiempo + 12, casaId = p.casaId,
    }
  end
  local sonidos = {
    golpe = "corte", tajo = "corte", carga = "corte", grito = "grito",
    misil = "magia", fuego = "fuego", escudo = "magia", nova = "hielo",
    disparo = "flecha", lluvia = "flecha", preciso = "flecha", trampa = "flecha",
    curar = "cura", bendicion = "sagrado", castigo = "sagrado", consagrar = "sagrado",
    desgarro = "corte", furia = "grito", sombra = "magia", meteoro = "fuego",
    flecha_veneno = "flecha", paso_agil = "flecha", sanacion = "cura", juicio = "sagrado",
  }
  self:sonar(sonidos[idh] or "magia")
  local ex = objetivo and objetivo.x or p.x
  local ey = objetivo and objetivo.y or p.y
  if h.tipo == "alrededor" or h.tipo == "buff_alrededor" or h.tipo == "mixto" or h.tipo == "propio" or h.tipo == "suelo" or h.tipo == "aliados" then
    self:efecto(idh, p.x, p.y, 0.5)
  elseif h.tipo == "punto" then
    self:efecto(idh, tx or ex, ty or ey, 0.55)
  elseif not h.proyectil then
    self:efecto(idh, ex, ey, 0.4)
  end
  p.habilidadPendiente = nil
  return nil
end

-- Aprende un poder o lo sube un rango, gastando un punto de habilidad.
function Mundo:aprenderHabilidad(p, id)
  if p.kind ~= "jugador" then return "Solo los jugadores aprenden poderes." end
  p.habilidades = p.habilidades or Arbol.iniciales(p.clase)
  local motivo = Arbol.motivo(p, id)
  if motivo then return motivo end
  local nodo = Arbol.nodo(p.clase, id)
  local nuevo = (p.habilidades[id] or 0) + 1
  p.habilidades[id] = nuevo
  self:marcarProgreso(p)
  self:recalcular(p)
  local nombre = Arbol.nombre(nodo)
  self:mensaje("sistema", "", (nuevo == 1 and "Aprendes " or "Mejoras ") .. nombre .. " (rango " .. nuevo .. ").", p)
  self:sonar("cura")
  return nil
end

function Mundo:costeReinicio(p)
  return (p.nivel or 1) * 15
end

-- Devuelve todos los puntos a cambio de oro: queda solo el poder inicial.
function Mundo:reiniciarHabilidades(p)
  if p.kind ~= "jugador" then return end
  if Arbol.gastados(p) == 0 then return "No tienes nada que reiniciar." end
  local coste = self:costeReinicio(p)
  if (p.oro or 0) < coste then return "Reiniciar cuesta " .. coste .. " de oro." end
  p.oro = p.oro - coste
  p.habilidades = Arbol.iniciales(p.clase)
  self:marcarProgreso(p)
  self:recalcular(p)
  self:mensaje("sistema", "", "Tus puntos de habilidad vuelven a estar libres.", p)
  return nil
end

-- Vida que cura un poder: su base, lo que sube con el nivel y el ataque mágico del que cura.
function Mundo:potenciaCura(p, h)
  return (h.cura or 0) + p.nivel * (h.curaN or 0) + (p.matk or 0) * 0.4
end

function Mundo:proyectil(origen, objetivo, h)
  local id = self:idNuevo()
  self.entidades[id] = {
    id = id, kind = "proyectil",
    x = origen.x, y = origen.y, modo = origen.modo, casaId = origen.casaId,
    objetivo = objetivo.id, tx = objetivo.x, ty = objetivo.y,
    dueno = origen.id, coef = h.coef or 1, aoe = h.aoe, tipo = h.proyectil, dano = h.dano, estado = h.estado,
    vivo = true, vida = 1.4,
  }
end

function Mundo:autoataque(p)
  local o = p.objetivo and self.entidades[p.objetivo]
  if not o or not o.vivo or not self:puedeDanar(p, o) then return end
  if not self:mismoLugar(p, o) then return end
  local rango = self:alcance(p)
  if Util.dist(p.x, p.y, o.x, o.y) > rango then return end
  if (p.cds.auto or 0) > self.tiempo then return end
  if (p.gcd or 0) > self.tiempo then return end
  p.cds.auto = self.tiempo + (rango > 3 and 1.35 or 1.15)
  p.swing = 0.18
  p.ultimoGolpe = self.tiempo
  if not p.tramo then self:encarar(p, o.x - p.x, o.y - p.y) end
  local c = Datos.clases[p.clase]
  if c and (c.proyectil or rango > 3) then
    self:proyectil(p, o, {
      coef = 1, dano = self:tipoDanoBasico(p),
      proyectil = p.clase == "clerigo" and "sagrado" or (p.clase == "mago" and "misil" or "flecha"),
    })
  else
    self:golpear(p, o, 1)
  end
end

function Mundo:actualizarJugador(e, dt)
  if not e.vivo then
    if self.tiempo >= (e.respawn or 0) then self:revivir(e) end
    return
  end
  -- la mascota vuelve sola tras una muerte o una guerra
  if e.kind == "jugador" and e.mascotaActiva and not e.mascotaId and e.modo ~= "batalla" and e.modo ~= "estandarte"
    and (e.mascotaDescanso or 0) <= self.tiempo then
    e.mascotaEspera = (e.mascotaEspera or 0) - dt
    if e.mascotaEspera <= 0 then
      e.mascotaEspera = 2
      self:invocarMascota(e, e.mascotaActiva)
    end
  end
  e.buffs = e.buffs or {}
  for i = #e.buffs, 1, -1 do
    e.buffs[i].dur = e.buffs[i].dur - dt
    if e.buffs[i].dur <= 0 then table.remove(e.buffs, i) end
  end
  if (e.aturdido or 0) > 0 then
    e.aturdido = e.aturdido - dt
    e.velx, e.vely, e.mov = 0, 0, false
    return
  end
  local fuera = (self.tiempo - (e.ultimoGolpe or -10)) > 6
  if fuera then e.hp = math.min(e.hpMax, e.hp + e.hpMax * 0.04 * dt) end
  local regen = 3 + (self:tieneBuff(e, "bendicion") and 4 or 0)
  e.mp = math.min(e.mpMax, e.mp + regen * dt)
  if e.lentoHasta and self.tiempo > e.lentoHasta then e.lentitud = nil end
  local mul = 1
  if e.lentitud and e.lentitud.hasta > self.tiempo then mul = mul * (1 - e.lentitud.mul) end
  if e.llevaBandera then mul = mul * 0.85 end
  mul = mul * self:buffMul(e, "vel")
  local ddx, ddy = Util.signo(e.deseoX or 0), Util.signo(e.deseoY or 0)
  if ddx ~= 0 or ddy ~= 0 then
    e.camino = nil
  else
    ddx, ddy = self:direccionAutomatica(e, dt)
  end
  self:avanzar(e, dt, ddx, ddy, (e.spd or 4) * mul)
  if e.habilidadPendiente and (e.gcd or 0) <= self.tiempo then
    self:usarHabilidad(e, e.habilidadPendiente)
  end
  if e.persigue or (e.objetivo and self:puedeDanar(e, self.entidades[e.objetivo] or {})) then
    self:autoataque(e)
  end
  if e.modo == "mundo" then
    local c = self:ciudadEn(e.x, e.y)
    local zona = c and c.nombre or self:nombreZona(e.x, e.y)
    if zona ~= e.zona then
      e.zona = zona
      e.zonaAviso = 2.6
      if zona == "La Cicatriz" and e.nivel < 8 and e.kind == "jugador" then
        self:mensaje("sistema", "", "La Cicatriz es peligrosa antes del nivel 8.", e)
      end
    elseif e.zonaAviso then
      e.zonaAviso = e.zonaAviso - dt
    end
  end
  for _, o in pairs(self.entidades) do
    if o.kind == "loot" and o.vivo and self:mismoLugar(e, o) and (not o.dueno or o.dueno == e.id or self.tiempo > (o.hasta or 0) - 20) then
      if Util.dist(e.x, e.y, o.x, o.y) < 0.8 and e.kind == "jugador" then self:recoger(e, o) end
    end
  end
  self:pisarEscalera(e)
  if e.modo == "estandarte" then self:tocarBandera(e) end
end

function Mundo:pisarEscalera(e)
  if not e or (e.escaleraEn or 0) > self.tiempo then return end
  local mapa = self:mapaDe(e)
  if not mapa or not mapa.escaleras then return end
  local z = e.z or 0
  for _, s in ipairs(mapa.escaleras) do
    if s.de == z and math.abs(e.x - (s.x + 0.5)) < 0.45 and math.abs(e.y - (s.y + 0.5)) < 0.45 then
      e.z = s.a
      e.escaleraEn = self.tiempo + 0.8
      return
    end
  end
end

function Mundo:nombreZona(x, y)
  local c = self:ciudadEn(x, y)
  if c then return c.nombre end
  local tx, ty = math.floor(x), math.floor(y)
  local b = self.mapas.mundo.bioma[tx] and self.mapas.mundo.bioma[tx][ty]
  local def = b and Datos.biomas[b]
  if def then return def.nombre end
  if b == "cicatriz" then return "La Cicatriz" end
  if b == "costa" then return "Costa" end
  if b == "bosque" then return "Bosque" end
  if b == "umbra" then return "Tierras de Umbra" end
  if b == "albor" then return "Tierras de Albor" end
  return "Dos Coronas"
end

function Mundo:actualizarMonstruo(e, dt)
  if not e.vivo then
    if self.tiempo >= (e.respawn or 0) then self:revivir(e) end
    return
  end
  if (e.aturdido or 0) > 0 then e.aturdido = e.aturdido - dt return end
  e.sensor = (e.sensor or 0) - dt
  if e.sensor <= 0 then
    e.sensor = 0.45
    local mejor, md = nil, (e.agresivo and 6.5 or 0)
    local amenaza = e.amenaza and self.entidades[e.amenaza]
    if amenaza and amenaza.vivo and self:mismoLugar(e, amenaza) and Util.dist(e.x, e.y, amenaza.x, amenaza.y) < 12 then
      mejor = amenaza
    else
      for _, o in pairs(self.entidades) do
        if o.vivo and o.id ~= e.id and self:mismoLugar(e, o) and (o.kind == "jugador" or o.kind == "bot" or o.kind == "guardia") then
          if not (o.kind == "jugador" and o.nivel + 3 < e.nivel and not e.amenaza) then
            local d = Util.dist(e.x, e.y, o.x, o.y)
            local limite = e.agresivo and 6.2 or 1.2
            if d < limite and (not md or d < md) then mejor, md = o, d end
          end
        end
      end
    end
    if mejor then e.objetivo = mejor.id end
  end
  local o = e.objetivo and self.entidades[e.objetivo]
  local dx, dy = 0, 0
  if o and o.vivo and self:mismoLugar(e, o) then
    local d = Util.dist(e.x, e.y, o.x, o.y)
    local rango = self:alcance(e)
    if d > 14 then e.objetivo = nil
    else
      if e.poderes and d <= 7 then self:poderesMonstruo(e, o, d) end
    end
    if d > 14 then
    elseif d > rango then dx, dy = o.x - e.x, o.y - e.y
    else
      if not e.tramo then self:encarar(e, o.x - e.x, o.y - e.y) end
      if ((e.cds or {}).auto or 0) <= self.tiempo then
        e.cds = e.cds or {}
        e.cds.auto = self.tiempo + 1.3
        if rango > 2 and e.tipoDano == "magico" then
          -- los magos de la oscuridad lanzan desde lejos
          self:proyectil(e, o, { coef = 1, dano = "magico", proyectil = "sombra", estado = nil })
          if o.vivo then self:alGolpear(e, o) end
        else
          -- a veces el golpe se lo lleva la mascota del jugador (el limo guardián atrae más)
          local blanco = o
          local pet = o.mascotaId and self.entidades[o.mascotaId]
          if pet and pet.vivo and Util.dist(e.x, e.y, pet.x, pet.y) <= rango + 0.3
            and math.random() < (pet.especie == "limo" and 0.5 or 0.3) then
            blanco = pet
          end
          self:golpear(e, blanco, 1)
          if blanco.vivo then self:alGolpear(e, blanco) end
        end
      end
    end
  else
    e.vagar = (e.vagar or 0) - dt
    if e.vagar <= 0 then
      e.vagar = 1.5 + math.random() * 2.5
      if math.random() < 0.4 then
        e.vx, e.vy = 0, 0
      else
        local ang = math.random() * math.pi * 2
        e.vx, e.vy = math.cos(ang), math.sin(ang)
      end
    end
    if Util.dist(e.x, e.y, e.hogarx or e.x, e.hogary or e.y) > 8 then
      dx, dy = (e.hogarx or e.x) - e.x, (e.hogary or e.y) - e.y
    else
      dx, dy = e.vx or 0, e.vy or 0
    end
  end
  local ddx, ddy = 0, 0
  if dx ~= 0 or dy ~= 0 then
    if e.tramo then
      ddx, ddy = signo(dx), signo(dy)
    else
      ddx, ddy = self:mejorDireccion(e, dx, dy)
    end
  end
  local vel = e.spd or 1.6
  if e.lentitud and e.lentitud.hasta > self.tiempo then vel = vel * (1 - e.lentitud.mul) end
  self:avanzar(e, dt, ddx, ddy, vel)
end

function Mundo:actualizarGuardia(e, dt)
  e.sensor = (e.sensor or 0) - dt
  if e.sensor <= 0 then
    e.sensor = 0.4
    local ciudad = self:ciudadEn(e.x, e.y)
    for _, o in pairs(self.entidades) do
      if o.vivo and o.faccion and o.faccion ~= e.faccion and self:mismoLugar(e, o) and (o.kind == "jugador" or o.kind == "bot" or o.kind == "monstruo") then
        if Util.dist(e.x, e.y, o.x, o.y) < 7 and (not ciudad or self:ciudadEn(o.x, o.y) == ciudad or o.kind == "monstruo") then
          e.objetivo = o.id
        end
      end
    end
  end
  e.puestoX, e.puestoY = e.puestoX or e.x, e.puestoY or e.y
  local o = e.objetivo and self.entidades[e.objetivo]
  local ddx, ddy = 0, 0
  if o and o.vivo and Util.dist(e.x, e.y, o.x, o.y) < 8 then
    if Util.dist(e.x, e.y, o.x, o.y) > self:alcance(e) then
      ddx, ddy = self:mejorDireccion(e, o.x - e.x, o.y - e.y)
    else
      if not e.tramo then self:encarar(e, o.x - e.x, o.y - e.y) end
      if ((e.cds or {}).auto or 0) <= self.tiempo then
        e.cds = e.cds or {}
        e.cds.auto = self.tiempo + 1.1
        self:golpear(e, o, 1)
      end
    end
  elseif Util.dist(e.x, e.y, e.puestoX, e.puestoY) > 1.2 then
    ddx, ddy = self:mejorDireccion(e, e.puestoX - e.x, e.puestoY - e.y)
  end
  self:avanzar(e, dt, ddx, ddy, e.spd or 3)
end

function Mundo:pensarBot(e, dt)
  e.iaT = (e.iaT or 0) - dt
  if e.iaT > 0 then return end
  e.iaT = 0.6
  if not e.vivo then return end
  local enemigo, md = nil, 7
  local herido = nil
  for _, o in pairs(self.entidades) do
    if o.vivo and o.id ~= e.id and self:mismoLugar(e, o) then
      local d = Util.dist(e.x, e.y, o.x, o.y)
      if self:puedeDanar(e, o) and d < md and o.kind ~= "estatua" then enemigo, md = o, d end
      if e.clase == "clerigo" and self:aliado(e, o) and o.hp and o.hpMax and o.hp < o.hpMax * 0.6 and d < 7 then herido = o end
    end
  end
  if e.modo == "batalla" and math.random() < 0.35 then
    for _, o in pairs(self.entidades) do
      if o.vivo and o.estructura and o.faccion ~= e.faccion and o.modo == "batalla" then
        enemigo = o
        break
      end
    end
  end
  if herido and e.hp and e.hpMax and e.hp > e.hpMax * 0.45 then
    e.objetivo = herido.id
    e.persigue = true
    self:usarHabilidad(e, 1)
    return
  end
  if e.hp and e.hpMax and e.hp < e.hpMax * 0.45 and e.clase == "clerigo" then
    e.objetivo = e.id
    self:usarHabilidad(e, 1)
  end
  if enemigo then
    e.objetivo = enemigo.id
    e.persigue = true
    if math.random() < 0.4 then self:usarHabilidad(e, math.random(2, 4)) end
  elseif e.modo == "mundo" and math.random() < 0.4 then
    e.camino = { { x = e.x + math.random(-6, 6), y = e.y + math.random(-6, 6) } }
    e.persigue = false
  end
end

function Mundo:actualizarProyectil(p, dt)
  local obj = p.objetivo and self.entidades[p.objetivo]
  local tx, ty = p.tx, p.ty
  if obj and obj.vivo then tx, ty = obj.x, obj.y end
  local dx, dy = tx - p.x, ty - p.y
  local d = math.sqrt(dx * dx + dy * dy)
  p.vida = p.vida - dt
  if d < 0.3 or p.vida <= 0 then
    local dueno = p.dueno and self.entidades[p.dueno]
    if dueno and obj and obj.vivo then
      if p.aoe then
        for _, o in pairs(self.entidades) do
          if o.vivo and self:mismoLugar(obj, o) and Util.dist(obj.x, obj.y, o.x, o.y) <= p.aoe and self:puedeDanar(dueno, o) then
            self:golpear(dueno, o, p.coef or 1, 0.85, p.dano or "fisico")
            if o.vivo then self:probarEstado(dueno, o, p.estado) end
          end
        end
      else
        self:golpear(dueno, obj, p.coef or 1, nil, p.dano or "fisico")
        if obj.vivo then self:probarEstado(dueno, obj, p.estado) end
      end
    end
    p.borrar = true
    self:efecto(p.tipo or "misil", p.x, p.y, 0.32)
    return
  end
  p.x = p.x + dx / d * 11 * dt
  p.y = p.y + dy / d * 11 * dt
end

function Mundo:actualizarTrampa(t, dt)
  if self.tiempo > t.hasta then t.borrar = true return end
  for _, o in pairs(self.entidades) do
    if o.vivo and o.faccion ~= t.faccion and self:mismoLugar(t, o) and Util.dist(t.x, t.y, o.x, o.y) < 0.7 then
      if o.kind == "jugador" or o.kind == "bot" or o.kind == "monstruo" then
        self:aplicarEstado(o, "aturdir", 1.6, nil, nil)
        local dueno = self.entidades[t.dueno]
        if dueno then self:golpear(dueno, o, 0.6, nil, "fisico") end
        t.borrar = true
        return
      end
    end
  end
end

function Mundo:tocarBandera(p)
  for _, f in pairs(self.entidades) do
    if f.kind == "bandera" and f.modo == "estandarte" then
      if not f.portador and f.faccion ~= p.faccion and Util.dist(p.x, p.y, f.x, f.y) < 1.15 and not p.llevaBandera then
        f.portador = p.id
        p.llevaBandera = f.faccion
        self:mensaje("sistema", "", p.nombre .. " toma el estandarte enemigo.", p)
      end
    end
  end
  if not p.llevaBandera then return end
  local propia
  for _, f in pairs(self.entidades) do
    if f.kind == "bandera" and f.faccion == p.faccion then propia = f end
  end
  if propia and not propia.portador and Util.dist(p.x, p.y, propia.origenx, propia.origeny) < 1.4 then
    for _, f in pairs(self.entidades) do
      if f.kind == "bandera" and f.portador == p.id then
        f.portador = nil
        f.x, f.y = f.origenx, f.origeny
      end
    end
    p.llevaBandera = nil
    local inst = self.instancia.estandarte
    inst.puntos[p.faccion] = inst.puntos[p.faccion] + 1
    self:mensaje("sistema", "", p.nombre .. " captura el estandarte. " .. inst.puntos[p.faccion] .. "/3", p)
    if inst.puntos[p.faccion] >= 3 then self:cerrarInstancia("estandarte", p.faccion) end
  end
end

function Mundo:soltarBandera(p)
  for _, f in pairs(self.entidades) do
    if f.kind == "bandera" and f.portador == p.id then
      f.portador = nil
      f.x, f.y = p.x, p.y
    end
  end
  p.llevaBandera = nil
end

function Mundo:actualizarBandera(f)
  if f.portador then
    local p = self.entidades[f.portador]
    if not p or not p.vivo or p.modo ~= "estandarte" then
      if p then p.llevaBandera = nil end
      f.portador = nil
    else
      f.x, f.y = p.x, p.y
    end
  end
end

function Mundo:entregarCristales(p)
  local n = 0
  for i = #p.bolsa, 1, -1 do
    if p.bolsa[i].id == "cristal" then
      n = n + p.bolsa[i].cant
      table.remove(p.bolsa, i)
    end
  end
  if n <= 0 then return "No llevas cristales." end
  local inst = self.instancia.batalla
  inst.puntos[p.faccion] = inst.puntos[p.faccion] + n * 45
  p.entregados = (p.entregados or 0) + n
  self:mensaje("sistema", "", "Entregas " .. n .. " cristales enemigos. +" .. (n * 45) .. " puntos.", p)
  return nil
end

function Mundo:nombreEvento(modo)
  if modo == "batalla" then return "Batalla por cristales" end
  if modo == "estandarte" then return "Captura del estandarte" end
  return "Evento"
end

function Mundo:contarCola(modo)
  local n = { albor = 0, umbra = 0 }
  local lista = { albor = {}, umbra = {} }
  for _, e in pairs(self.entidades) do
    if e.kind == "jugador" and e.vivo and not e.borrar and e.colaGuerra == modo and e.modo ~= modo then
      if lista[e.faccion] then
        n[e.faccion] = n[e.faccion] + 1
        lista[e.faccion][#lista[e.faccion] + 1] = e
      end
    end
  end
  return n, lista
end

function Mundo:resumenEvento(modo)
  if self.resumenes and self.resumenes[modo] then return self.resumenes[modo] end
  local cola = self:contarCola(modo)
  local dentro = { albor = 0, umbra = 0 }
  for _, e in pairs(self.entidades) do
    if e.kind == "jugador" and e.vivo and not e.borrar and e.modo == modo and dentro[e.faccion] then
      dentro[e.faccion] = dentro[e.faccion] + 1
    end
  end
  local inst = self.instancia[modo]
  return {
    cola = cola,
    dentro = dentro,
    activa = inst and inst.activa and not inst.fin or false,
  }
end

function Mundo:meterEnCampo(p, modo)
  local nombre = self:nombreEvento(modo)
  p.colaGuerra = nil
  p.retorno = { x = p.x, y = p.y, modo = p.modo == "casa" and "mundo" or p.modo }
  p.modo = modo
  p.casaId = nil
  local sp = self.mapas[modo].spawns[p.faccion]
  p.x, p.y = sp.x, sp.y
  p.objetivo, p.camino, p.persigue = nil, nil, false
  p.zona = nombre
  if p.kind == "jugador" then
    local hoy = os.date("%Y-%m-%d")
    p.eventosDia = p.eventosDia or {}
    p.eventosDia[modo] = hoy
    if p.dbId then
      if self.puertos.marcarEvento then self.puertos.marcarEvento(p.dbId, modo) end
    end
  end
  self:mensaje("sistema", "", p.nombre .. " entra en " .. nombre .. ". Hoy ya no podrás repetirlo.", p)
end

function Mundo:empezarEvento(modo)
  local min = Datos.JUGADORES_EVENTO
  local n, lista = self:contarCola(modo)
  if n.albor < min or n.umbra < min then return false end
  self:reiniciarInstancia(modo)
  for _, fac in ipairs({ "albor", "umbra" }) do
    for _, e in ipairs(lista[fac]) do
      self:meterEnCampo(e, modo)
    end
  end
  self:mensaje("mundo", "", self:nombreEvento(modo) .. " empieza. Albor y Umbra entran al campo.", nil)
  return true
end

function Mundo:entrarGuerra(p, modo)
  if modo ~= "batalla" and modo ~= "estandarte" then return "Ese evento no existe." end
  if not p.vivo then return "No puedes entrar así." end
  if p.kind ~= "jugador" then return "Los eventos se juegan entre jugadores." end
  if p.modo == modo then return "Ya estás dentro." end
  if p.colaGuerra == modo then return "Ya estás en la cola." end
  if p.colaGuerra and p.colaGuerra ~= modo then return "Sal de la otra cola antes de apuntarte." end
  local hoy = os.date("%Y-%m-%d")
  p.eventosDia = p.eventosDia or {}
  if p.eventosDia[modo] == hoy then
    return "Ya jugaste " .. self:nombreEvento(modo) .. " hoy. Cada evento es una vez al día."
  end
  if (p.ultimoGolpe or 0) + 4 > self.tiempo and p.modo == "mundo" then
    return "Sal del combate antes de entrar."
  end
  local inst = self.instancia[modo]
  if inst.activa and not inst.fin then
    self:meterEnCampo(p, modo)
    return nil
  end
  p.colaGuerra = modo
  local n = self:contarCola(modo)
  local min = Datos.JUGADORES_EVENTO
  self:mensaje("sistema", "", string.format(
    "Te apuntas a %s. Albor %d/%d, Umbra %d/%d.",
    self:nombreEvento(modo), n.albor, min, n.umbra, min
  ), p)
  if n.albor >= min and n.umbra >= min then
    self:empezarEvento(modo)
  else
    self:mensaje("sistema", "", "Empieza cuando haya " .. min .. " jugadores en cada equipo.", p)
  end
  return nil
end

function Mundo:reiniciarInstancia(modo)
  local inst = self.instancia[modo]
  inst.tiempo = 0
  inst.puntos = { albor = 0, umbra = 0 }
  inst.fin = nil
  inst.activa = true
  if modo == "batalla" then
    for _, e in pairs(self.entidades) do
      if e.modo == "batalla" and (e.kind == "estatua" or e.kind == "puerta" or e.kind == "altar") then
        e.vivo = true
        e.hp = e.hpMax
      end
    end
    if self.mapas.batalla.puerta then
      for _, puerta in pairs(self.mapas.batalla.puerta) do
        puerta.viva = true
        self.mapas.batalla.bloque[puerta.x][puerta.y] = true
      end
    end
  end
  if modo == "estandarte" then
    for _, e in pairs(self.entidades) do
      if e.kind == "bandera" then
        e.portador = nil
        e.x, e.y = e.origenx, e.origeny
      end
      if e.llevaBandera then e.llevaBandera = nil end
    end
  end
end

function Mundo:cerrarInstancia(modo, ganador)
  local inst = self.instancia[modo]
  if inst.fin then return end
  inst.fin = ganador or "empate"
  inst.activa = false
  local titulo = modo == "batalla" and "La batalla por cristales" or "Captura el estandarte"
  self:mensaje("mundo", "", titulo .. " termina. Victoria: " .. (ganador == "albor" and "Albor" or ganador == "umbra" and "Umbra" or "nadie") .. ".", nil)
  if ganador == "albor" or ganador == "umbra" then
    self.gloria[ganador] = self.gloria[ganador] + 40
  end
  for _, e in pairs(self.entidades) do
    if e.modo == modo and (e.kind == "jugador" or e.kind == "bot") then
      local gano = e.faccion == ganador
      local oro = gano and 220 or 70
      local xp = gano and 280 or 90
      if e.kind == "jugador" then
        for i = #e.bolsa, 1, -1 do
          if e.bolsa[i].id == "cristal" then
            oro = oro + e.bolsa[i].cant * 15
            table.remove(e.bolsa, i)
          end
        end
        e.oro = e.oro + oro
        self:ganarXp(e, xp)
        self:mensaje("sistema", "", (gano and "Victoria" or "Derrota") .. ". +" .. oro .. " de oro.", e)
      end
      local ret = e.retorno
      if e.kind == "jugador" and ret then
        e.modo = "mundo"
        e.x, e.y = ret.x, ret.y
      elseif e.temporal then
        e.borrar = true
      else
        e.modo = "mundo"
        local cap = Datos.capital(e.faccion)
        for _, c in ipairs(self.mapas.mundo.ciudades) do
          if c.id == cap.id then e.x, e.y = c.spawn.x, c.spawn.y end
        end
      end
      e.llevaBandera = nil
      e.objetivo = nil
    end
  end
end

function Mundo:salirGuerra(p)
  if p.colaGuerra and p.modo ~= "batalla" and p.modo ~= "estandarte" then
    local nombre = self:nombreEvento(p.colaGuerra)
    p.colaGuerra = nil
    self:mensaje("sistema", "", "Sales de la cola de " .. nombre .. ".", p)
    return
  end
  if p.modo ~= "batalla" and p.modo ~= "estandarte" then return end
  local ret = p.retorno
  p.modo = "mundo"
  if ret then p.x, p.y = ret.x, ret.y end
  p.llevaBandera = nil
  self:mensaje("sistema", "", "Abandonas el campo.", p)
end

function Mundo:equipar(p, index)
  self:marcarProgreso(p)
  local slot = p.bolsa[index]
  if not slot then return "No hay objeto." end
  local it = Datos.item(slot.id)
  if not it or not it.hueco then
    if it and (it.cura or it.mana) then return self:usarPocionId(p, slot.id) end
    return "No se puede equipar."
  end
  if it.clase and it.clase ~= p.clase then return "Esa pieza no es de tu clase." end
  if it.nivel and p.nivel < it.nivel then return "Necesitas nivel " .. it.nivel .. "." end
  local previo = p.equipo[it.hueco]
  if it.hueco == "mochila" then
    -- la bolsa que queda no puede pasar de lo que cabe en la mochila nueva
    local quedan = previo and #p.bolsa or (#p.bolsa - 1)
    if quedan > it.slots then return "Tu bolsa no cabe en esa mochila: libera espacio." end
  end
  p.encantos = p.encantos or {}
  local encPrevio = p.encantos[it.hueco]
  p.equipo[it.hueco] = slot.id
  p.encantos[it.hueco] = slot.enc
  if previo then p.bolsa[index] = { id = previo, cant = 1, enc = encPrevio } else table.remove(p.bolsa, index) end
  self:recalcular(p)
  return nil
end

function Mundo:desequipar(p, hueco)
  self:marcarProgreso(p)
  local id = p.equipo[hueco]
  if not id then return end
  if hueco == "mochila" then
    if #p.bolsa + 1 > Datos.BOLSA_BASE then return "Vacía la bolsa antes de quitarte la mochila." end
    p.equipo[hueco] = nil
    p.bolsa[#p.bolsa + 1] = { id = id, cant = 1, enc = p.encantos and p.encantos[hueco] }
    if p.encantos then p.encantos[hueco] = nil end
    self:recalcular(p)
    return
  end
  if #p.bolsa >= Datos.capacidadBolsa(p.equipo) then return "Bolsa llena." end
  p.equipo[hueco] = nil
  self:darItem(p, id, 1, p.encantos and p.encantos[hueco])
  if p.encantos then p.encantos[hueco] = nil end
  self:recalcular(p)
end

-- Cuenta el material de encantamiento que lleva el jugador.
function Mundo:contarItem(p, id)
  local n = 0
  for _, s in ipairs(p.bolsa) do
    if s.id == id then n = n + (s.cant or 1) end
  end
  return n
end

function Mundo:gastarItem(p, id, cant)
  for i = #p.bolsa, 1, -1 do
    local s = p.bolsa[i]
    if s.id == id then
      local quita = math.min(cant, s.cant or 1)
      s.cant = (s.cant or 1) - quita
      cant = cant - quita
      if s.cant <= 0 then table.remove(p.bolsa, i) end
      if cant <= 0 then return end
    end
  end
end

-- Intenta subir un nivel de encantamiento a una pieza, equipada (donde = "equipo", ref = hueco)
-- o en la bolsa (donde = "bolsa", ref = posición). Devuelve un texto de error o nil.
function Mundo:encantar(p, donde, ref)
  local id, enc
  if donde == "equipo" then
    id, enc = p.equipo[ref], p.encantos and p.encantos[ref]
  else
    local slot = p.bolsa[tonumber(ref) or 0]
    id, enc = slot and slot.id, slot and slot.enc
  end
  local it = id and Datos.item(id)
  if not Encanto.encantable(it) then return "Eso no se puede encantar." end
  enc = enc or 0
  if enc >= Encanto.MAX then return "Ya está al máximo (+" .. Encanto.MAX .. ")." end
  local coste = Encanto.coste(it, enc)
  if (p.oro or 0) < coste.oro then return "Necesitas " .. coste.oro .. " de oro." end
  if self:contarItem(p, Encanto.MATERIAL) < coste.polvo then
    return "Necesitas " .. coste.polvo .. " de polvo arcano."
  end
  p.oro = p.oro - coste.oro
  self:gastarItem(p, Encanto.MATERIAL, coste.polvo)
  local nuevo = enc
  if math.random() < Encanto.prob(enc) then
    nuevo = enc + 1
    self:mensaje("sistema", "", it.nombre .. " sube a +" .. nuevo .. ".", p)
    self:sonar("magia")
    self:numero(p, "+" .. nuevo, { 0.7, 0.9, 1 })
  elseif Encanto.bajaAlFallar(enc) then
    nuevo = enc - 1
    self:mensaje("sistema", "", "El encantamiento falla y " .. it.nombre .. " baja a +" .. nuevo .. ".", p)
    self:numero(p, "falla", { 1, 0.4, 0.35 })
  else
    self:mensaje("sistema", "", "El encantamiento falla; no pierdes el nivel.", p)
    self:numero(p, "falla", { 1, 0.6, 0.4 })
  end
  if donde == "equipo" then
    p.encantos = p.encantos or {}
    p.encantos[ref] = nuevo > 0 and nuevo or nil
    self:recalcular(p)
  else
    p.bolsa[tonumber(ref)].enc = nuevo > 0 and nuevo or nil
  end
  self:marcarProgreso(p)
  return nil
end

function Mundo:usarPocionId(p, id)
  if (p.cdPocion or 0) > self.tiempo then return "La poción aún no." end
  local idx
  for i, s in ipairs(p.bolsa) do if s.id == id then idx = i break end end
  if not idx then return "No tienes esa poción." end
  local it = Datos.item(id)
  if it.cura then p.hp = math.min(p.hpMax, p.hp + math.floor(p.hpMax * it.cura)) end
  if it.mana then p.mp = math.min(p.mpMax, p.mp + math.floor(p.mpMax * it.mana)) end
  p.bolsa[idx].cant = p.bolsa[idx].cant - 1
  if p.bolsa[idx].cant <= 0 then table.remove(p.bolsa, idx) end
  p.cdPocion = self.tiempo + 6
  return nil
end

function Mundo:comprar(p, itemId)
  self:marcarProgreso(p)
  local it = Datos.item(itemId)
  if not it or it.quest then return "No está a la venta." end
  if p.oro < it.precio then return "Oro insuficiente." end
  if not self:darItem(p, itemId, 1) then return "Bolsa llena." end
  p.oro = p.oro - it.precio
  return nil
end

function Mundo:vender(p, index)
  self:marcarProgreso(p)
  local slot = p.bolsa[index]
  if not slot then return end
  local it = Datos.item(slot.id)
  if not it or it.quest then return "No se puede vender." end
  local cant = slot.cant or 1
  p.oro = p.oro + math.floor((it.precio or 1) * 0.45) * cant
  table.remove(p.bolsa, index)
end

function Mundo:valorOferta(of)
  local v = of.oro or 0
  for _, it in ipairs(of.items) do
    local d = Datos.item(it.id)
    v = v + math.floor(((d and d.precio) or 5) * 0.5) * (it.cant or 1)
  end
  return v
end

function Mundo:invitarComercio(a, b)
  if not b or not self:mismoLugar(a, b) or Util.dist(a.x, a.y, b.x, b.y) > 3.2 then
    return "Demasiado lejos."
  end
  if a.sesion or b.sesion then return "Alguien ya está comerciando." end
  local id = self:idNuevo()
  local s = {
    id = id, a = a.id, b = b.id,
    oferta = {
      [a.id] = { oro = 0, items = {}, ok = false },
      [b.id] = { oro = 0, items = {}, ok = false },
    },
  }
  self.sesiones[id] = s
  a.sesion, b.sesion = id, id
  self:mensaje("sistema", "", "Comercio con " .. b.nombre .. ".", a)
  if b.kind == "bot" then
    if self:darItem(b, "pocion_vida", 1) or true then
      s.oferta[b.id].oro = 10
      s.oferta[b.id].items = { { id = "pocion_vida", cant = 1 } }
      if b.oro >= 10 then b.oro = b.oro - 10 else s.oferta[b.id].oro = 0 end
    end
    self:mensaje("local", b.nombre, "Acepto si ofreces al menos el valor de lo mío.", b)
  end
  return nil, id
end

function Mundo:ofrecerOro(p, cantidad)
  local s = p.sesion and self.sesiones[p.sesion]
  if not s then return end
  cantidad = math.max(0, math.floor(cantidad or 0))
  local of = s.oferta[p.id]
  p.oro = p.oro + of.oro
  if cantidad > p.oro then cantidad = p.oro end
  p.oro = p.oro - cantidad
  of.oro = cantidad
  s.oferta[s.a].ok = false
  s.oferta[s.b].ok = false
end

function Mundo:ofrecerItem(p, index)
  local s = p.sesion and self.sesiones[p.sesion]
  if not s then return "No hay comercio." end
  local slot = p.bolsa[index]
  if not slot then return end
  local of = s.oferta[p.id]
  of.items[#of.items + 1] = { id = slot.id, cant = slot.cant, enc = slot.enc }
  table.remove(p.bolsa, index)
  s.oferta[s.a].ok = false
  s.oferta[s.b].ok = false
end

function Mundo:aceptarComercio(p)
  local s = p.sesion and self.sesiones[p.sesion]
  if not s then return end
  s.oferta[p.id].ok = true
  local otro = self.entidades[s.a == p.id and s.b or s.a]
  if otro and otro.kind == "bot" then
    local vo = self:valorOferta(s.oferta[p.id])
    local vb = self:valorOferta(s.oferta[otro.id])
    if vo >= vb and vo > 0 then s.oferta[otro.id].ok = true end
  end
  if s.oferta[s.a].ok and s.oferta[s.b].ok then return self:cerrarComercio(s, true) end
end

function Mundo:cerrarComercio(s, ok)
  local a, b = self.entidades[s.a], self.entidades[s.b]
  local function devolver(p, of)
    if not p or not of then return end
    p.oro = p.oro + (of.oro or 0)
    for _, it in ipairs(of.items) do self:darItem(p, it.id, it.cant, it.enc) end
  end
  if ok and a and b then
    local function entra(p, of)
      p.oro = p.oro + (of.oro or 0)
      for _, it in ipairs(of.items) do
        if not self:darItem(p, it.id, it.cant, it.enc) then
          ok = false
        end
      end
    end
    local oa, ob = s.oferta[a.id], s.oferta[b.id]
    entra(a, ob)
    entra(b, oa)
    if ok then
      self:marcarProgreso(a)
      self:marcarProgreso(b)
      self:mensaje("sistema", "", "Comercio cerrado con " .. b.nombre .. ".", a)
    else
      devolver(a, oa)
      devolver(b, ob)
      self:mensaje("sistema", "", "El comercio no cabe en la bolsa.", a)
    end
  else
    devolver(a, a and s.oferta[a.id])
    devolver(b, b and s.oferta[b.id])
  end
  if a then a.sesion = nil end
  if b then b.sesion = nil end
  self.sesiones[s.id] = nil
end

function Mundo:cancelarComercio(p)
  if p.sesion then self:cerrarComercio(self.sesiones[p.sesion], false) end
end

function Mundo:comprarCasa(p, parcelaId)
  self:marcarProgreso(p)
  local parcela, ciudad
  for _, c in ipairs(self.mapas.mundo.ciudades) do
    for _, par in ipairs(c.parcelas) do
      if par.id == parcelaId then parcela, ciudad = par, c end
    end
  end
  if not parcela then return "Esa parcela no existe." end
  if parcela.dueno then return "Ya tiene dueño." end
  if ciudad.faccion ~= p.faccion then return "Solo puedes comprar en tu facción." end
  local precio = ciudad.capital and Datos.precioCasa.capital or Datos.precioCasa.normal
  if p.oro < precio then return "Necesitas " .. precio .. " de oro." end
  p.oro = p.oro - precio
  parcela.dueno = p.id
  p.casas[parcelaId] = { muebles = {}, cofre = {} }
  self:mensaje("sistema", "", "La casa de " .. ciudad.nombre .. " es tuya.", p)
  return nil
end

function Mundo:entrarCasa(p, parcelaId)
  local parcela
  for _, c in ipairs(self.mapas.mundo.ciudades) do
    for _, par in ipairs(c.parcelas) do
      if par.id == parcelaId then parcela = par end
    end
  end
  if not parcela or parcela.dueno ~= p.id then return "No es tu casa." end
  if Util.dist(p.x, p.y, parcela.x + 0.5, parcela.y + 0.5) > 2.2 and p.modo == "mundo" then
    return "Acércate a la puerta."
  end
  p.retorno = { x = parcela.x + 0.5, y = parcela.y + 1.4, modo = "mundo" }
  p.modo = "casa"
  p.zona = "Tu casa"
  p.casaId = parcelaId
  p.x, p.y = self.mapas.casa.salida.x, self.mapas.casa.salida.y
  p.camino = nil
  return nil
end

function Mundo:salirCasa(p)
  if p.modo ~= "casa" then return end
  local r = p.retorno or p.vinculo
  p.modo = "mundo"
  p.x, p.y = r.x, r.y
  p.casaId = nil
end

function Mundo:ponerMueble(p, tipo)
  self:marcarProgreso(p)
  local casa = p.casaId and p.casas[p.casaId]
  if not casa then return "No estás en tu casa." end
  local m = Datos.muebles[tipo]
  if not m then return end
  if casa.muebles[tipo] then
    if tipo == "cama" then
      p.vinculo = { x = p.retorno.x, y = p.retorno.y, modo = "mundo" }
      return nil, "Esta cama es tu punto de retorno."
    end
    return "Ya está colocado."
  end
  if p.oro < m.precio then return "Cuesta " .. m.precio .. " de oro." end
  p.oro = p.oro - m.precio
  casa.muebles[tipo] = true
  return nil
end

function Mundo:guardarEnCofre(p, index)
  local casa = p.casaId and p.casas[p.casaId]
  if not casa or not casa.muebles.cofre then return "Necesitas un cofre." end
  local slot = p.bolsa[index]
  if not slot then return end
  if #casa.cofre >= 16 then return "Cofre lleno." end
  casa.cofre[#casa.cofre + 1] = slot
  table.remove(p.bolsa, index)
end

function Mundo:sacarDelCofre(p, index)
  local casa = p.casaId and p.casas[p.casaId]
  if not casa then return end
  local slot = casa.cofre[index]
  if not slot then return end
  if not self:darItem(p, slot.id, slot.cant, slot.enc) then return "Bolsa llena." end
  table.remove(casa.cofre, index)
end

function Mundo:aceptarMision(p, id)
  self:marcarProgreso(p)
  for _, q in ipairs(Datos.misiones) do
    if q.id == id then
      p.misiones[id] = {
        titulo = q.titulo, monstruo = q.monstruo, cantidad = q.cantidad,
        progreso = 0, aceptada = true, entregada = false, oro = q.oro, xp = q.xp, ciudad = q.ciudad,
      }
      self:mensaje("sistema", "", "Aceptas: " .. q.titulo, p)
      return
    end
  end
end

function Mundo:entregarMision(p, id)
  self:marcarProgreso(p)
  local q = p.misiones[id]
  if not q or not q.aceptada or q.entregada then return "Nada que entregar." end
  if (q.progreso or 0) < q.cantidad then return "Aún no está completo." end
  q.entregada = true
  p.oro = p.oro + q.oro
  self:ganarXp(p, q.xp)
  self:mensaje("sistema", "", "Encargo entregado. +" .. q.oro .. " de oro.", p)
  for _, def in ipairs(Datos.misiones) do
    if def.id == id and def.siguiente then
      local ya = p.misiones[def.siguiente]
      if not ya or not ya.aceptada then self:aceptarMision(p, def.siguiente) end
    end
  end
  return nil
end

-- ¿Hay un PNJ de ese rol a la vista del jugador (a unos pasos)?
function Mundo:npcCerca(p, rol)
  for _, e in pairs(self.entidades) do
    if e.kind == "npc" and e.rol == rol and self:mismoLugar(p, e) and Util.dist(p.x, p.y, e.x, e.y) <= 4 then
      return true
    end
  end
  return false
end

function Mundo:interactuar(p)
  if p.modo == "casa" then
    if Util.dist(p.x, p.y, self.mapas.casa.salida.x, self.mapas.casa.salida.y) < 1.3 then
      self:salirCasa(p)
      return { panel = nil }
    end
    return { panel = "casa" }
  end
  if p.modo == "batalla" then
    for _, e in pairs(self.entidades) do
      if e.kind == "altar" and e.faccion == p.faccion and Util.dist(p.x, p.y, e.x, e.y) < 1.8 then
        local err = self:entregarCristales(p)
        if err then self:mensaje("sistema", "", err, p) end
        return { panel = nil }
      end
    end
  end
  local mejor, md = nil, 1.8
  for _, e in pairs(self.entidades) do
    if e.vivo and e.kind == "npc" or (e.kind == "guardia") then
      if e.kind == "npc" or e.kind == "guardia" then
        if self:mismoLugar(p, e) then
          local d = Util.dist(p.x, p.y, e.x, e.y)
          if d < md then mejor, md = e, d end
        end
      end
    end
  end
  if mejor then
    if mejor.rol == "mercado" then return { panel = "mercado" } end
    if mejor.rol == "heraldo" then return { panel = "guerra" } end
    if mejor.rol == "encantador" then return { panel = "encantar" } end
    if mejor.rol == "criador" then return { panel = "mascotas" } end
    if mejor.rol == "gremio" then return { panel = "gremio" } end
    if mejor.rol == "mayordomo" then return { panel = "vivienda", ciudad = self:ciudadEn(p.x, p.y) and self:ciudadEn(p.x, p.y).id } end
    if mejor.rol == "encargos" then
      local cid = self:ciudadEn(p.x, p.y)
      cid = cid and cid.id
      for _, q in ipairs(Datos.misiones) do
        if q.ciudad == cid then
          local st = p.misiones[q.id]
          if st and st.aceptada and not st.entregada then
            self:mensaje("local", mejor.nombre, q.dialogo or q.texto, mejor)
          end
        end
      end
      return { panel = "misiones", ciudad = cid }
    end
    if mejor.kind == "guardia" then
      self:mensaje("local", mejor.nombre, "Mantén la corona en alto.", mejor)
      return { panel = nil }
    end
  end
  for _, c in ipairs(self.mapas.mundo.ciudades) do
    for _, par in ipairs(c.parcelas) do
      if Util.dist(p.x, p.y, par.x + 0.5, par.y + 0.5) < 1.6 then
        if par.dueno == p.id then
          self:entrarCasa(p, par.id)
          return { panel = "casa" }
        else
          self:mensaje("sistema", "", par.dueno and "Esta casa ya tiene dueño." or "Parcela en venta. Habla con el mayordomo.", p)
          return { panel = "vivienda", ciudad = c.id }
        end
      end
    end
  end
  if p.modo == "mundo" and Util.dist(p.x, p.y, self.mapas.mundo.portal.x, self.mapas.mundo.portal.y) < 2.2 then
    return { panel = "guerra" }
  end
  return { panel = nil }
end

-- Descripción de lo que se ve al mirar una criatura (Shift + clic), como en Tibia.
function Mundo:mirarA(p, e)
  if not e then return end
  local txt
  if e.kind == "monstruo" then
    local def = Datos.monstruo(e.monstruo)
    txt = string.format("Ves %s (nivel %d). %s", e.nombre, e.nivel or 1, (def and def.desc) or "")
  elseif e.kind == "jugador" or e.kind == "bot" then
    local c = Datos.clases[e.clase]
    local f = Datos.facciones[e.faccion]
    txt = string.format("Ves a %s. Es %s de %s, nivel %d.", e.nombre, c and c.nombre:lower() or "aventurero", f and f.nombre or "?", e.nivel or 1)
  elseif e.kind == "guardia" or e.kind == "npc" then
    txt = "Ves a " .. (e.nombre or "alguien") .. "."
  else
    txt = "Ves " .. (e.nombre or "algo") .. "."
  end
  self:mensaje("sistema", "", txt, p)
end

function Mundo:objetivoCercano(p, x, y, hostil)
  local mejor, md = nil, 1.1
  for _, e in pairs(self.entidades) do
    if e.vivo and e.id ~= p.id and self:mismoLugar(p, e) and e.kind ~= "loot" and e.kind ~= "proyectil" and e.kind ~= "trampa" then
      local d = Util.dist(x, y, e.x, e.y)
      local radio = (e.tam or 1) * 0.8
      if d < md + radio then
        if not hostil or self:puedeDanar(p, e) or self:aliado(p, e) then
          mejor, md = e, d
        end
      end
    end
  end
  return mejor
end

function Mundo:actualizar(dt)
  self.tiempo = self.tiempo + dt
  local ids = self._ids
  if not ids then
    ids = {}
    self._ids = ids
  end
  local n = 0
  for id in pairs(self.entidades) do
    n = n + 1
    ids[n] = id
  end
  for i = n + 1, #ids do ids[i] = nil end
  for i = 1, n do
    local id = ids[i]
    local e = self.entidades[id]
    if e and not e.borrar then
      if e.kind == "jugador" then self:actualizarJugador(e, dt)
      elseif e.kind == "bot" then
        if e.ia then self:pensarBot(e, dt) end
        self:actualizarJugador(e, dt)
      elseif e.kind == "monstruo" then self:actualizarMonstruo(e, dt)
      elseif e.kind == "guardia" then self:actualizarGuardia(e, dt)
      elseif e.kind == "proyectil" then self:actualizarProyectil(e, dt)
      elseif e.kind == "trampa" then self:actualizarTrampa(e, dt)
      elseif e.kind == "mascota" then self:actualizarMascota(e, dt)
      elseif e.kind == "bandera" then self:actualizarBandera(e)
      elseif e.kind == "loot" and self.tiempo > (e.hasta or 0) then e.borrar = true
      elseif e.estructura and e.vivo and e.modo == "batalla" then
        e.pulso = (e.pulso or 2) - dt
        if e.pulso <= 0 then
          e.pulso = 2.4
          for _, o in pairs(self.entidades) do
            if o.vivo and o.faccion and o.faccion ~= e.faccion and o.modo == "batalla" and Util.dist(e.x, e.y, o.x, o.y) < 2.1 then
              if o.kind == "jugador" or o.kind == "bot" then self:danar(o, 8, e) end
            end
          end
        end
      end
    end
  end
  for i = 1, n do
    local e = self.entidades[ids[i]]
    if e and e.estados then self:actualizarEstados(e) end
  end
  for id, e in pairs(self.entidades) do
    if e.borrar then self.entidades[id] = nil end
  end
  for _, n in ipairs(self.numeros) do n.vida = n.vida - dt n.y = n.y - dt * 0.4 end
  for i = #self.numeros, 1, -1 do
    if self.numeros[i].vida <= 0 then table.remove(self.numeros, i) end
  end
  for i = #self.efectos, 1, -1 do
    local fx = self.efectos[i]
    fx.t = fx.t + dt
    if fx.t >= fx.dur then table.remove(self.efectos, i) end
  end
  for _, modo in ipairs({ "batalla", "estandarte" }) do
    local inst = self.instancia[modo]
    if inst.activa and not inst.fin then
      inst.tiempo = inst.tiempo + dt
      local limite = modo == "batalla" and 500 or 3
      if inst.puntos.albor >= limite then self:cerrarInstancia(modo, "albor")
      elseif inst.puntos.umbra >= limite then self:cerrarInstancia(modo, "umbra")
      elseif inst.tiempo >= inst.duracion then
        local g = "empate"
        if inst.puntos.albor > inst.puntos.umbra then g = "albor"
        elseif inst.puntos.umbra > inst.puntos.albor then g = "umbra" end
        self:cerrarInstancia(modo, g)
      end
    end
  end
end

function Mundo:exportar(p)
  local misiones = {}
  for id, q in pairs(p.misiones or {}) do misiones[id] = q end
  -- Si está dentro de una casa o de un campo de batalla, sus coordenadas son de
  -- otro mapa: se guarda el sitio del mundo al que volvería.
  local x, y, z = p.x, p.y, p.z or 0
  if p.modo ~= "mundo" then
    local v = p.retorno or p.vinculo
    if v and v.x and v.y then x, y, z = v.x, v.y, 0 end
  end
  return {
    guardado = true,
    nombre = p.nombre, faccion = p.faccion, clase = p.clase,
    nivel = p.nivel, xp = p.xp, oro = p.oro,
    x = x, y = y, modo = "mundo",
    equipo = p.equipo, bolsa = p.bolsa, misiones = misiones,
    casas = p.casas, vinculo = p.vinculo, caceria = p.caceria,
    habilidades = p.habilidades, encantos = p.encantos,
    mascotas = p.mascotas, mascotaActiva = p.mascotaActiva,
    z = z,
  }
end

function Mundo:aplicarGuardado(p, data)
  if not data or data.clase ~= p.clase then return end
  p.nivel = data.nivel or p.nivel
  p.xp = data.xp or 0
  p.oro = data.oro or 0
  p.equipo = data.equipo or p.equipo
  p.bolsa = data.bolsa or p.bolsa
  p.encantos = data.encantos or {}
  p.mascotas = data.mascotas or {}
  p.mascotaActiva = data.mascotaActiva
  self:vincularGremio(p)
  -- Un guardado antiguo con más objetos de los que caben sin mochila recibe la
  -- más pequeña que los aguante.
  if #p.bolsa > Datos.capacidadBolsa(p.equipo) then
    for tier = 1, 4 do
      local m = Datos.item("mochila_" .. tier)
      if m and #p.bolsa <= m.slots then p.equipo.mochila = m.id break end
    end
  end
  p.misiones = data.misiones or {}
  p.casas = data.casas or {}
  p.caceria = data.caceria or {}
  if p.kind == "jugador" then
    -- guardados anteriores al árbol: solo el poder inicial y todos los puntos por gastar
    p.habilidades = data.habilidades or Arbol.iniciales(p.clase)
  end
  p.vinculo = data.vinculo or p.vinculo
  p.z = data.z or 0
  if data.x and data.y and not (tonumber(data.x) == 0 and tonumber(data.y) == 0) then
    p.x, p.y = data.x, data.y
  end
  for _, c in ipairs(self.mapas.mundo.ciudades) do
    for _, par in ipairs(c.parcelas) do
      if p.casas[par.id] then par.dueno = p.id end
    end
  end
  self:recalcular(p)
  p.hp, p.mp = p.hpMax, p.mpMax
end

function Mundo:compactar(e)
  return {
    id = e.id, kind = e.kind, nombre = e.nombre, faccion = e.faccion, clase = e.clase,
    monstruo = e.monstruo, x = e.x, y = e.y, z = e.z or 0, dir = e.dir or 1, vivo = e.vivo ~= false,
    modo = e.modo, hp = e.hp, hpMax = e.hpMax, mp = e.mp, mpMax = e.mpMax,
    nivel = e.nivel, hoja = e.hoja, base = e.base, cuadros = e.cuadros,
    tam = e.tam, paso = e.paso, porDir = e.porDir, elite = e.elite,
    estructura = e.estructura, llevaBandera = e.llevaBandera, equipo = e.equipo,
    rol = e.rol, casaId = e.casaId, anim = e.anim, portador = e.portador,
    mov = e.mov and true or nil, objetivo = (e.kind == "monstruo") and e.objetivo or nil,
    respawn = (e.kind == "monstruo" or e.kind == "puerta") and e.respawn or nil,
    flash = (e.flash or 0) > 0 and e.flash or nil,
    burbuja = e.burbuja,
    est = self:estadosVisibles(e), especie = e.especie, gremio = e.gremioEtiqueta,
    -- proyectiles: de qué tipo son y a dónde van
    tipo = e.kind == "proyectil" and e.tipo or nil,
    tx = e.kind == "proyectil" and e.tx or nil, ty = e.kind == "proyectil" and e.ty or nil,
  }
end

function Mundo:foto(pid)
  local p = self.entidades[pid]
  local ents = {}
  for _, e in pairs(self.entidades) do
    if p and self:mismoLugar(p, e) then
      local d = Util.dist(p.x, p.y, e.x or p.x, e.y or p.y)
      if d < 28 or e.kind == "estatua" or e.kind == "puerta" or e.kind == "altar" or e.kind == "bandera" then
        ents[#ents + 1] = self:compactar(e)
      end
    end
  end
  local tu = nil
  if p then
    tu = {
      bolsa = p.bolsa, equipo = p.equipo, oro = p.oro, xp = p.xp, nivel = p.nivel,
      hp = p.hp, hpMax = p.hpMax, mp = p.mp, mpMax = p.mpMax, cds = {},
      misiones = p.misiones, casas = p.casas, sesion = p.sesion, zona = p.zona,
      atk = p.atk, def = p.def, matk = p.matk, mdef = p.mdef, spd = p.spd, clase = p.clase, faccion = p.faccion,
      nombre = p.nombre, modo = p.modo, casaId = p.casaId, objetivo = p.objetivo,
      z = p.z or 0, habilidades = p.habilidades, encantos = p.encantos,
      mascotas = p.mascotas, mascotaActiva = p.mascotaActiva,
      gremioRango = p.gremioRango, gremioEtiqueta = p.gremioEtiqueta,
      invGremio = (p.invitacionGremio and p.invitacionGremio.hasta > self.tiempo) and p.invitacionGremio or nil,
      estadosResta = {},
    }
    if p.gremioId and self.gremios[p.gremioId] then tu.gremioNombre = self.gremios[p.gremioId].nombre end
    for tipo, st in pairs(p.estados or {}) do tu.estadosResta[tipo] = math.max(0, st.hasta - self.tiempo) end
    for k, v in pairs(p.cds or {}) do tu.cds[k] = v end
  end
  local msgs = {}
  for i = #self.mensajes, 1, -1 do
    local m = self.mensajes[i]
    local visible = true
    if m.canal == "sistema" and m.para and m.para ~= pid then visible = false end
    if m.canal == "gremio" and (not p or m.gremio ~= p.gremioId) then visible = false end
    if visible then
      table.insert(msgs, 1, m)
      if #msgs >= 13 then break end
    end
  end
  if not self._resumen or self.tiempo - (self._resumenT or 0) > 0.5 then
    self._resumenT = self.tiempo
    self._resumen = { batalla = self:resumenEvento("batalla"), estandarte = self:resumenEvento("estandarte") }
  end
  local duenos = {}
  for _, c in ipairs(self.mapas.mundo.ciudades) do
    for _, par in ipairs(c.parcelas) do
      if par.dueno then duenos[par.id] = par.dueno end
    end
  end
  local sesiones
  if p and p.sesion and self.sesiones[p.sesion] then sesiones = { [p.sesion] = self.sesiones[p.sesion] } end
  -- Efectos de poderes, números de daño y sonidos en curso cerca del jugador.
  local efectos, numeros = {}, {}
  if p then
    for _, fx in ipairs(self.efectos) do
      if Util.dist(p.x, p.y, fx.x, fx.y) < 30 then
        efectos[#efectos + 1] = { tipo = fx.tipo, x = fx.x, y = fx.y, t = fx.t, dur = fx.dur }
      end
    end
    for _, n in ipairs(self.numeros) do
      if Util.dist(p.x, p.y, n.x, n.y) < 30 then
        numeros[#numeros + 1] = { x = n.x, y = n.y, texto = n.texto, color = n.color, vida = n.vida }
      end
    end
  end
  local sonidos = {}
  for i = 1, math.min(#self.sonidos, 8) do sonidos[i] = self.sonidos[i] end
  return {
    ents = ents, tu = tu, msgs = msgs, gloria = self.gloria, instancia = self.instancia,
    resumen = self._resumen, duenos = duenos, sesiones = sesiones,
    tiempo = self.tiempo, efectos = efectos, numeros = numeros, sonidos = sonidos,
  }
end

function Mundo:aplicarFoto(snap, pid)
  if not snap then return end
  local viejo = self.entidades
  local nuevo = {}
  for _, e in ipairs(snap.ents or {}) do
    local prev = viejo[e.id]
    if prev and prev.anim then e.anim = prev.anim end
    e.vivo = e.vivo ~= false
    nuevo[e.id] = e
  end
  self.entidades = nuevo
  local p = nuevo[pid]
  if p and snap.tu then
    for k, v in pairs(snap.tu) do p[k] = v end
  end
  if snap.msgs then self.mensajes = snap.msgs end
  if snap.gloria then self.gloria = snap.gloria end
  if snap.instancia then self.instancia = snap.instancia end
  self.resumenes = snap.resumen
  self.sesiones = snap.sesiones or {}
  -- El reloj del servidor manda: los enfriamientos y los efectos dependen de él.
  if snap.tiempo then
    if math.abs(self.tiempo - snap.tiempo) > 0.25 then
      self.tiempo = snap.tiempo
    else
      self.tiempo = self.tiempo + (snap.tiempo - self.tiempo) * 0.3
    end
  end
  self.efectos = snap.efectos or {}
  self.numeros = snap.numeros or {}
  self.sonidosRed = snap.sonidos or {}
  if snap.duenos then
    for _, c in ipairs(self.mapas.mundo.ciudades) do
      for _, par in ipairs(c.parcelas) do par.dueno = snap.duenos[par.id] end
    end
  end
  self.jugadorRed = pid
end

function Mundo:accion(pid, nombre, datos)
  local p = self.entidades[pid]
  if not p then return end
  datos = datos or {}
  if nombre == "destino" then self:fijarDestino(p, datos.x, datos.y) end
  if nombre == "deseo" then p.deseoX, p.deseoY = datos.x or 0, datos.y or 0 end
  if nombre == "objetivo" then
    p.objetivo = datos.id
    p.persigue = datos.persigue and true or false
  end
  if nombre == "habilidad" then
    local err = self:usarHabilidad(p, datos.slot, datos.x, datos.y)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "chat" then self:decir(p, datos.texto or "") end
  if nombre == "mirar" then self:mirarA(p, self.entidades[datos.id]) end
  if nombre == "equipar" then
    local err = self:equipar(p, datos.i)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "desequipar" then
    local err = self:desequipar(p, datos.hueco)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "mascota_adoptar" then
    local err
    if self:npcCerca(p, "criador") then err = self:adoptarMascota(p, datos.especie)
    else err = "Acércate al criador de mascotas." end
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "mascota_invocar" then
    local err = self:invocarMascota(p, datos.idx)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "encantar" then
    local err
    if self:npcCerca(p, "encantador") then err = self:encantar(p, datos.donde, datos.ref)
    else err = "Acércate al maestro de encantos." end
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "aprender" then
    local err = self:aprenderHabilidad(p, datos.id)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "olvidar" then
    local err = self:reiniciarHabilidades(p)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "pocion" then
    local err = self:usarPocionId(p, datos.id)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "comprar" then
    local err = self:comprar(p, datos.id)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "vender" then
    local err = self:vender(p, datos.i)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "interactuar" then return self:interactuar(p) end
  if nombre == "guerra" then
    local err = self:entrarGuerra(p, datos.modo)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "salir_guerra" then self:salirGuerra(p) end
  if nombre == "casa_comprar" then
    local err = self:comprarCasa(p, datos.id)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "casa_entrar" then
    local err = self:entrarCasa(p, datos.id)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "casa_salir" then self:salirCasa(p) end
  if nombre == "mueble" then
    local err, extra = self:ponerMueble(p, datos.tipo)
    if err then self:mensaje("sistema", "", err, p) end
    if extra then self:mensaje("sistema", "", extra, p) end
  end
  if nombre == "cofre_guardar" then
    local err = self:guardarEnCofre(p, datos.i)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "cofre_sacar" then
    local err = self:sacarDelCofre(p, datos.i)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "mover_bolsa" then
    local a, b = tonumber(datos.a), tonumber(datos.b)
    local cap = Datos.capacidadBolsa(p.equipo)
    if a and b and p.bolsa and a ~= b and a >= 1 and b >= 1 and a <= cap and b <= cap and p.bolsa[a] then
      if p.bolsa[b] then
        p.bolsa[a], p.bolsa[b] = p.bolsa[b], p.bolsa[a]
      else -- casilla vacía: el objeto pasa al final sin dejar huecos en la lista
        p.bolsa[#p.bolsa + 1] = table.remove(p.bolsa, a)
      end
    end
  end
  if nombre == "mision_aceptar" then self:aceptarMision(p, datos.id) end
  if nombre == "mision_entregar" then
    local err = self:entregarMision(p, datos.id)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "comercio_invitar" then
    local otro = self.entidades[datos.id]
    local err = self:invitarComercio(p, otro)
    if err then self:mensaje("sistema", "", err, p) end
    if not err then return { panel = "comercio" } end
  end
  if nombre == "comercio_oro" then self:ofrecerOro(p, datos.oro) end
  if nombre == "comercio_item" then self:ofrecerItem(p, datos.i) end
  if nombre == "comercio_ok" then self:aceptarComercio(p) end
  if nombre == "comercio_no" then self:cancelarComercio(p) return { panel = nil } end
  if nombre:sub(1, 7) == "gremio_" and p then return self:accionGremio(p, nombre, datos or {}) end
  return nil
end

Estados.instalar(Mundo)
Mascotas.instalar(Mundo)
Gremios.instalar(Mundo)

return Mundo
