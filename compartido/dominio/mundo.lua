local Datos = require("compartido.dominio.datos")
local Mapa = require("compartido.dominio.mapa")
local Util = require("compartido.dominio.util")
local Balance = require("compartido.dominio.balance")
local Arbol = require("compartido.dominio.arbol")
local Estados = require("compartido.dominio.estados")
local Items = require("compartido.dominio.items")
local Encanto = require("compartido.dominio.encanto")
local Mascotas = require("compartido.dominio.mascotas")
local Esbirros = require("compartido.dominio.esbirros")
local Diaria = require("compartido.dominio.diaria")
local Gremios = require("compartido.dominio.gremios")
local Oficios = require("compartido.dominio.oficios")
local Ley = require("compartido.dominio.ley")
local Caravanas = require("compartido.dominio.caravanas")
local Monturas = require("compartido.dominio.monturas")
local Subastas = require("compartido.dominio.subastas")
local Programacion = require("compartido.dominio.programacion")
local Grupos = require("compartido.dominio.grupos")
local Encuentros = require("compartido.dominio.encuentros")
local Admin = require("compartido.dominio.admin")
local Comercio = require("compartido.dominio.comercio")
local Mall = require("compartido.dominio.mall")
local Misiones = require("compartido.dominio.misiones")
local Voces = require("compartido.dominio.voces")
local Mazmorras = require("compartido.dominio.mazmorras")
local MapasFao = require("compartido.dominio.mapas_fao")
local Moba = require("compartido.dominio.moba")
local PoderesFao = require("compartido.datos.efectos_fao_poderes")       -- efectos de capas de FAO de los poderes (duración, capas): el servidor solo usa la duración
local Viaje = require("compartido.dominio.viaje")

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
  -- identifica esta vida del mundo: los clientes que siguen conectados al reiniciar el servidor
  -- reconocen que los numeros de mensaje empezaron de nuevo
  self.epoca = tostring(os.time()) .. "-" .. tostring(math.floor(os.clock() * 1000))
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
  self:iniciarSubastas()
  self:iniciarGrupos()
  self.gloria = { albor = 0, umbra = 0 }
  self.evento = { tipo = nil, hasta = 0 }
  self.instancia = {
    batalla = { activa = false, tiempo = 0, duracion = Datos.EVENTO_DURACION.batalla, puntos = { albor = 0, umbra = 0 }, fin = nil },
    estandarte = { activa = false, tiempo = 0, duracion = Datos.EVENTO_DURACION.estandarte, puntos = { albor = 0, umbra = 0 }, fin = nil },
    moba = { activa = false, tiempo = 0, duracion = Datos.EVENTO_DURACION.moba or 900, puntos = { albor = 0, umbra = 0 }, fin = nil },
  }
  self.mapas = {
    mundo = Mapa.mundo(self.rng),
    batalla = Mapa.batalla(),
    estandarte = Mapa.estandarte(),
    casa = Mapa.casa(22, 16),
    casaPequena = Mapa.casa(14, 11),
    casaMediana = Mapa.casa(18, 13),
  }
  self:crearMapasMazmorras()
  self:crearMapasFao()
  Misiones.preparar(self.mapas.mundo)
  self:poblar()
  self:poblarMazmorras()
  self:poblarMapasFao()           -- (después de poblar el mundo: no cambia el azar ni las criaturas de los continentes)
  self:crearPortalesFao()
  -- el mundo se genera con semilla fija; después el azar del juego vuelve a ser libre
  math.randomseed(os.time() + math.floor((os.clock() * 1000) % 100000))
  return self
end

function Mundo:idNuevo()
  self.seq = self.seq + 1
  return "e" .. self.seq
end

function Mundo:interior(p)
  local t = p and (p.casaTamano or p.tamano)
  if t == "pequena" then return self.mapas.casaPequena end
  if t == "mediana" then return self.mapas.casaMediana end
  return self.mapas.casa
end

function Mundo:mapaDe(e)
  if not e then return self.mapas.casa end
  if e.modo == "casa" then return self:interior(e) end
  if e.modo == "batalla" then return self.mapas.batalla end
  if e.modo == "estandarte" then return self.mapas.estandarte end
  if e.modo == "moba" then self:asegurarArenaMoba() end          -- (la arena del asedio se calcula la primera vez que se necesita)
  return self.mapas[e.modo] or self.mapas.mundo
end

-- ¿Se mueve por rutas calculadas (mundo abierto a ras de suelo o mazmorra)?
function Mundo:enRutas(e)
  if e.modo == "mundo" then return (e.z or 0) == 0 end
  local m = self.mapas[e.modo]
  return m ~= nil and (m.mazmorra ~= nil or m.fao == true)
end

function Mundo:ciudadEn(x, y)
  for _, c in ipairs(self.mapas.mundo.ciudades) do
    if x >= c.x and x < c.x + c.w and y >= c.y and y < c.y + c.h then return c end
  end
end

-- Las ciudades y el interior de las casas son zonas seguras: dentro nadie puede ser herido
-- (jugadores, bots, mascotas ni caravanas), ni por criaturas ni por jugadores de ninguna corona.
-- En la ciudad solo se persigue a los buscados por robo (guardias y cazadores). En una casa, a nadie.
function Mundo:enSantuario(e)
  if not e then return false end
  if e.modo == "casa" then return true end
  if e.modo ~= "mundo" or (e.z or 0) > 0 then return false end
  return self:ciudadEn(e.x, e.y) ~= nil
end

function Mundo:mismoLugar(a, b)
  if not a or not b then return false end
  if a.modo ~= b.modo then return false end
  if a.modo == "casa" and a.casaId ~= b.casaId then return false end
  if (a.z or 0) ~= (b.z or 0) then return false end
  return true
end

-- Un sonido del mundo: nombre y, si lo hace una entidad (e), solo lo oyen quienes están cerca de ella y en su mismo sitio (el cliente
-- baja el volumen con la distancia). Los nombres los sintetiza el juego (juego/src/presentacion/sintesis.lua).
function Mundo:sonar(nombre, e)
  local lista = self.sonidos
  if #lista >= 40 then return end
  lista[#lista + 1] = { n = nombre, x = e and e.x, y = e and e.y, e = e }
end

-- Ángulo de cada dirección de mirada (1 abajo, 2 arriba, 3 derecha, 4 izquierda), con 0 = derecha y positivo hacia abajo.
Mundo.ANGULO_DIR = { [1] = math.pi / 2, [2] = -math.pi / 2, [3] = 0, [4] = math.pi }

-- rot: hacia dónde apunta el efecto (ángulo en radianes, 0 = derecha, positivo = hacia abajo); lo usan los poderes con dirección
-- (estocada, embestida): el cliente gira la animación para que vaya de quien ataca hacia su objetivo.
-- Duración (s) de los efectos que se alargan más que un golpe: la pantera corre hasta el enemigo y estalla; la ventisca de la nova cae en varias oleadas.
Mundo.DURACION_EFECTO = { pantera = 0.95, nova = 1.4, tajo = 1.0, golpe = 0.85 }
Mundo.PODERES_FAO = PoderesFao
for id, p in pairs(PoderesFao) do Mundo.DURACION_EFECTO[id] = p.dur end

-- (x0, y0): de dónde sale, para los efectos que viajan (la pantera).
function Mundo:efecto(tipo, x, y, dur, rot, x0, y0)
  self.efectos[#self.efectos + 1] = {
    tipo = tipo, x = x, y = y, t = 0, dur = dur or 0.42, rot = rot, x0 = x0, y0 = y0,
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
    grupo = (canal == "grupo" and origen) and origen.grupoId or nil,
    x = origen and origen.x or 0, y = origen and origen.y or 0,
    modo = origen and origen.modo or "mundo",
    tiempo = self.tiempo,
    id = (self._msgId or 0) + 1, epoca = self.epoca,
  }
  self._msgId = (self._msgId or 0) + 1
  if #self.mensajes > 80 then table.remove(self.mensajes, 1) end
  if origen and canal == "local" then origen.burbuja = { texto = texto, hasta = self.tiempo + 4 } end
end

-- Aviso global del sistema: sale en el chat de todos y en una marquesina que cruza la parte de
-- arriba de la pantalla de derecha a izquierda.
function Mundo:anunciar(texto)
  self:mensaje("sistema", "", texto, nil)
  local m = self.mensajes[#self.mensajes]
  m.marquesina, m.evento = true, true
end

-- Mensaje sobre un evento (próximo, empieza, termina, cancelado): sale en su canal de siempre y
-- también en la pestaña "Eventos" del chat.
function Mundo:avisoEvento(canal, de, texto, origen)
  self:mensaje(canal, de, texto, origen)
  local m = self.mensajes[#self.mensajes]
  -- los avisos de eventos (empieza, termina, programado, cancelado...) también cruzan la pantalla
  m.evento, m.marquesina = true, true
end

function Mundo:decir(p, texto)
  texto = Util.limpiar(texto)
  if texto == "" then return end
  if texto:sub(1, 6) == "/admin" and (#texto == 6 or texto:sub(7, 7) == " ") then return self:comandoAdmin(p, texto) end
  if p.silenciadoHasta then
    if os.time() < p.silenciadoHasta then
      self:mensaje("sistema", "", "Estás silenciado: te quedan " .. math.ceil((p.silenciadoHasta - os.time()) / 60) .. " minuto(s).", p)
      return
    end
    p.silenciadoHasta = nil
  end
  local canal = "local"
  if texto:sub(1, 3) == "/m " then canal, texto = "mundo", texto:sub(4)
  elseif texto:sub(1, 3) == "/f " then canal, texto = "faccion", texto:sub(4)
  elseif texto:sub(1, 3) == "/p " then
    if not p.grupoId then self:mensaje("sistema", "", "No estás en ningún grupo.", p) return end
    canal, texto = "grupo", texto:sub(4)
  elseif texto:sub(1, 3) == "/g " then
    if not p.gremioId then self:mensaje("sistema", "", "No perteneces a ningún gremio.", p) return end
    canal, texto = "gremio", texto:sub(4)
  elseif texto == "/ayuda" then
    self:mensaje("sistema", "", "Mover: clic o WASD. Atacar: clic en enemigo. Poderes: 1-6 (árbol: K). Curar: selecciona aliado y pulsa 1. E interactúa. I bolsa, P equipo, T comercio, M mapa.", p)
    return
  end
  self:mensaje(canal, p.staff and ("[" .. p.staff:upper() .. "] " .. p.nombre) or p.nombre, texto, p)
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
  for hueco, itemId in pairs(not e.mobaOrig and e.equipo or {}) do        -- (en el asedio nadie lleva equipo: todos parten igual)
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
  if not e.mobaOrig then
    Arbol.aplicarPasivas(e)
    self:aplicarBonos(e)
  end
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
    genero = opts.genero == "m" and "m" or "h",      -- aspecto del personaje: h = hombre, m = mujer
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

function Mundo:spawnMonstruo(idMon, x, y, hogar, nivel)
  local def = Datos.monstruo(idMon)
  if not def then return end
  if nivel then
    -- criaturas de grupo: su nivel se fija al aparecer
    local c = {}
    for k, v in pairs(def) do c[k] = v end
    c.nivel = nivel
    def = c
  end
  local st = Datos.statsMonstruo(def)
  local e = {
    id = self:idNuevo(),
    kind = "monstruo",
    monstruo = def.id,
    nombre = def.nombre,
    nivel = def.nivel,
    x = x, y = y, z = hogar and hogar.z or 0,
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
    golpe = def.golpe, poderes = def.poderes, bandido = def.bandido,
    categoria = def.categoria, xpMul = def.xpMul,
    medidor = def.jefeMundo and true or nil,   -- los jefes del mundo cuentan el daño de cada jugador (el botín es de quien más hace)
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
        nombre = n.nombre, rol = n.rol, faccion = n.faccion, qid = n.rol == "encargos" and ("c_" .. c.id) or nil,
        x = n.x, y = n.y, modo = "mundo", dir = 1, vivo = true,
        clase = ({ mercado = "clerigo", maestro_guerrero = "guerrero", maestro_lancero = "lancero", maestro_cazador = "cazador", maestro_mago = "mago", maestro_clerigo = "clerigo", maestro_nigromante = "nigromante", heraldo = "clerigo", mayordomo = "guerrero", encargos = "cazador", guardia = "guerrero", encantador = "mago", criador = "cazador", gremio = "guerrero", oficios = "guerrero", comercio = "guerrero", establo = "cazador", subastas = "mago" })[n.rol] or "guerrero",
        nivel = 12, hp = 400, hpMax = 400, atk = 28, def = 14, matk = 8, mdef = 7, spd = 3.2, rango = 1.4,
        cds = {},
        equipo = { arma = "guerrero_arma_2", pecho = "guerrero_pecho_2", cabeza = "guerrero_cabeza_2" },
      }
      e.puestoX, e.puestoY = e.x, e.y
      e.ruta = n.ruta or self:rutaPatrulla(e)
      e.paso, e.espera = 1, 0.6
      self.entidades[e.id] = e
    end
  end
  -- puestos del camino y refugios repartidos por el mapa
  for _, pu in ipairs(self.mapas.mundo.puestos or {}) do
    for _, n in ipairs(pu.npcs) do
      local e = {
        id = self:idNuevo(), kind = "npc", nombre = n.nombre, rol = n.rol, faccion = n.faccion, qid = n.rol == "misiones" and ("p" .. pu.id) or nil,
        x = n.x, y = n.y, modo = "mundo", dir = 1, vivo = true, clase = "guerrero",
        nivel = 12, hp = 400, hpMax = 400, atk = 28, def = 14, matk = 8, mdef = 7, spd = 3.2, rango = 1.4,
        cds = {}, equipo = {},
      }
      self.entidades[e.id] = e
    end
  end
  for _, camp in ipairs(self.mapas.mundo.campamentos) do
    for i = 1, camp.cantidad do
      local ang = (i / camp.cantidad) * math.pi * 2
      local x = camp.x + math.cos(ang) * 1.2
      local y = camp.y + math.sin(ang) * 1.2
      local mon = self:spawnMonstruo(camp.monstruo, x, y, camp, camp.nivel)
      if mon and camp.z then mon.z = camp.z end
      -- en los campamentos no todos son agresivos: una parte solo pelea si la atacan
      if mon and mon.agresivo and not mon.elite and not camp.z and math.random() < 0.4 then mon.agresivo = false end
    end
  end
  self:crearObjetivos()
end

function Mundo:crearObjetivos()
  for id, e in pairs(self.entidades) do
    if e.modo == "batalla" or e.modo == "estandarte" then self.entidades[id] = nil end
  end
  for _, o in ipairs(self.mapas.batalla.objetivos) do
    local hp = o.tipo == "altar" and 1500 or (o.tipo == "puerta" and (o.principal and 1100 or 800) or 780)
    local e = {
      id = self:idNuevo(),
      kind = o.tipo,
      nombre = (o.tipo == "altar" and "Altar de cristales" or o.tipo == "puerta" and "Puerta" or "Estatua") .. " de " .. (o.faccion == "albor" and "Albor" or "Umbra"),
      faccion = o.faccion, x = o.x, y = o.y, modo = "batalla", vivo = true,
      hp = hp, hpMax = hp, nucleo = o.tipo == "altar" or nil,
      def = 0, estructura = true,
      tx = math.floor(o.x), ty = math.floor(o.y), principal = o.principal,
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
  local celdas = self._celdas
  if celdas then
    -- rejilla de celdas de 8x8 casillas armada una vez por fotograma: solo se miran las cercanas
    local cx, cy = math.floor(tx / 8), math.floor(ty / 8)
    for dx = -1, 1 do
      for dy = -1, 1 do
        local lista = celdas[(cx + dx) * 4096 + (cy + dy)]
        if lista then
          for i = 1, #lista do
            local o = lista[i]
            if o ~= e and o.vivo ~= false and self:mismoLugar(e, o) then
              local ox, oy = self:casilla(o)
              if ox == tx and oy == ty then return true end
            end
          end
        end
      end
    end
    return false
  end
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

-- Ruta hacia (x, y). Si queda lejos se va por tramos: se calcula hasta un punto intermedio y, al
-- llegar, se vuelve a calcular (así se puede viajar de una punta a otra del mapa).
local function rutaHacia(self, e, x, y)
  local dx, dy = x - e.x, y - e.y
  local d = math.sqrt(dx * dx + dy * dy)
  local mapa = self:mapaDe(e)
  if d <= 110 then
    local cam = Mapa.buscar(mapa, e.x, e.y, x, y)
    if not cam then return nil, false end
    return cortarCamino(cam), #cam > 80
  end
  -- lejos: se busca un punto intermedio hacia la meta; si cae en un lago o una montana se prueban otros
  -- rumbos y distancias
  local base = math.atan2(dy, dx)
  for _, dist in ipairs({ 100, 60, 35 }) do
    for _, desv in ipairs({ 0, 0.4, -0.4, 0.9, -0.9, 1.4, -1.4 }) do
      local a = base + desv
      local cam = Mapa.buscar(mapa, e.x, e.y, e.x + math.cos(a) * dist, e.y + math.sin(a) * dist)
      if cam and #cam > 0 then return cortarCamino(cam), true end
    end
  end
  return nil, false
end

function Mundo:fijarDestino(e, x, y)
  e.metaX, e.metaY = x, y
  if self:enRutas(e) then
    local cam, mas = rutaHacia(self, e, x, y)
    e.camino, e.caminoCortado = cam or { { x = x, y = y } }, mas
  else
    e.camino, e.caminoCortado = { { x = x, y = y } }, false
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
    -- ruta larga: terminó un tramo, se calcula el siguiente hacia la meta
    if e.caminoCortado and e.metaX and self:enRutas(e) and not e.persigue
      and Util.dist(e.x, e.y, e.metaX, e.metaY) > 2.5 then
      local nuevo, mas = rutaHacia(self, e, e.metaX, e.metaY)
      if nuevo and #nuevo > 0 then
        e.camino, e.caminoCortado = nuevo, mas
        return 0, 0
      end
    end
    e.camino, e.bloqueado, e.caminoCortado = nil, nil, nil
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
    if e.metaX and self:enRutas(e) then
      local nuevo, mas = rutaHacia(self, e, e.metaX, e.metaY)
      e.camino, e.caminoCortado = nuevo, mas
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
    if self:enRutas(e) then
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
  local b = { id = id, dur = dur, max = dur }
  if extra then for k, v in pairs(extra) do b[k] = v end end
  e.buffs[#e.buffs + 1] = b
end

-- Todo lo sólido tapa la vista y frena los ataques: muros, casas, montañas, paredes de mazmorra, puertas cerradas del enemigo y también
-- árboles y demás decorado macizo.

function Mundo.casillaOpaca(mapa, x, y, faccion)
  local tx, ty = math.floor(x), math.floor(y)
  if not (mapa.bloque[tx] and mapa.bloque[tx][ty]) then return false end
  return Mapa.bloqueado(mapa, x, y, faccion)
end

-- ¿Se puede ir en línea recta de a a b sin cruzar una pared? Ignora la casilla del que ataca y la del objetivo (una puerta o una
-- estatua que se ataca está en una casilla bloqueada).
function Mundo:lineaLibre(a, b)
  if not a or not b or not a.x or not b.x then return true end
  if (a.z or 0) > 0 or (b.z or 0) > 0 then return true end
  local mapa = self:mapaDe(a)
  if not mapa or not mapa.bloque then return true end
  local dx, dy = b.x - a.x, b.y - a.y
  local d = math.sqrt(dx * dx + dy * dy)
  if d < 0.9 then return true end
  local ax, ay = math.floor(a.x), math.floor(a.y)
  local bx, by = math.floor(b.x), math.floor(b.y)
  local pasos = math.ceil(d / 0.4)
  for i = 1, pasos - 1 do
    local x, y = a.x + dx * i / pasos, a.y + dy * i / pasos
    local tx, ty = math.floor(x), math.floor(y)
    if not (tx == ax and ty == ay) and not (tx == bx and ty == by) then
      if Mundo.casillaOpaca(mapa, x, y, a.faccion) then return false end
    end
  end
  return true
end

function Mundo:puedeDanar(origen, objetivo)
  if not origen or not objetivo or not objetivo.vivo then return false end
  -- asedio: nadie daña a los de su propio equipo (esbirros y estructuras incluidos)
  if (origen.moba or objetivo.moba) and origen.faccion and origen.faccion == objetivo.faccion then return false end
  local kind = objetivo.kind
  -- el personal (GM y CM) no recibe daño de las criaturas
  if origen.kind == "monstruo" and objetivo.staff then return false end
  if (kind == "jugador" or kind == "bot" or kind == "mascota" or kind == "caravana")
    and (self:enSantuario(objetivo) or (origen.kind ~= "monstruo" and self:enSantuario(origen))) then
    if origen.modo == "casa" or objetivo.modo == "casa" then return false end
    -- zona segura: solo se persigue al buscado por robo
    return (kind == "jugador" or kind == "bot") and origen.kind ~= "monstruo" and self:esBuscado(objetivo)
      and (origen.kind == "guardia" or ((origen.kind == "jugador" or origen.kind == "bot") and origen.job == "hunter")) or false
  end
  if kind == "mascota" then
    -- solo las criaturas hostiles pueden herir a una mascota
    return origen.kind == "monstruo"
  end
  if kind == "caravana" then
    -- a una caravana solo la atacan los bandidos
    return origen.kind == "monstruo" and origen.bandido == true
  end
  if (kind == "jugador" or kind == "bot") and origen.kind ~= "monstruo" and self:legitimoPorOficio(origen, objetivo) then
    return true
  end
  if kind ~= "jugador" and kind ~= "bot" and kind ~= "guardia" and kind ~= "monstruo" and kind ~= "estatua" and kind ~= "puerta" and kind ~= "altar" then
    return false
  end
  if kind == "estatua" or kind == "puerta" or kind == "altar" then
    return origen.faccion and origen.faccion ~= objetivo.faccion
  end
  if kind == "monstruo" or origen.kind == "monstruo" then return true end
  if self:enSantuario(objetivo) then return false end
  -- con un oficio activo (comerciante, ladrón, cazarrecompensas) la facción no cuenta: se puede atacar y ser
  -- atacado aunque sea de la misma (fuera de las ciudades)
  if (origen.kind == "jugador" or origen.kind == "bot") and (kind == "jugador" or kind == "bot") and (origen.job or objetivo.job) then
    return true
  end
  if origen.faccion and objetivo.faccion and origen.faccion == objetivo.faccion then return false end
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
-- Anota que una criatura acaba de atacar (el cliente anima el ataque a partir de atqN, que sube con cada uno). Un mismo
-- ataque que golpea a varios (área) o que llama dos veces solo cuenta una vez. lejos: es un disparo o un conjuro, no un golpe.
local SONIDO_BASICO = { guerrero = "corte", lancero = "lanza", cazador = "flecha", mago = "magia", clerigo = "sagrado", nigromante = "oscuro" }

function Mundo:marcarAtaque(e, objetivo, lejos, silencio)
  if not e or e.kind == "proyectil" then return end
  if self.tiempo - (e.atqT or -9) < 0.25 then return end
  if not silencio then
    if e.kind == "monstruo" then self:sonar("ataque_" .. Voces.de(e.monstruo), e)
    elseif e.kind == "jugador" or e.kind == "bot" then self:sonar(SONIDO_BASICO[e.clase] or (lejos and "flecha" or "corte"), e) end
  end
  e.atqT = self.tiempo
  e.atqN = (e.atqN or 0) + 1
  e.atqLejos = lejos and true or nil
  if objetivo and objetivo.x and e.x then
    local dx, dy = objetivo.x - e.x, objetivo.y - e.y
    local d = math.max(0.01, math.sqrt(dx * dx + dy * dy))
    e.atqX, e.atqY = math.floor(dx / d * 100 + 0.5) / 100, math.floor(dy / d * 100 + 0.5) / 100
  else
    e.atqX, e.atqY = nil, nil
  end
end

-- sinAnim: el golpe es el impacto de algo ya lanzado (proyectil, trampa, aura); no es un ataque nuevo de quien lo lanzó.
function Mundo:golpear(origen, objetivo, coef, mult, tipo, sinAnim)
  if not origen or not objetivo then return end
  if origen ~= objetivo and not self:lineaLibre(origen, objetivo) then return end
  if not sinAnim then self:marcarAtaque(origen, objetivo, false) end
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
  if objetivo.invulnerable then
    if objetivo.moba and objetivo.nexo then self:numero(objetivo, "protegido", { 0.6, 0.8, 1 }) end     -- el nexo del asedio no cae hasta derribar sus torres
    return
  end
  if origen and not self:puedeDanar(origen, objetivo) then return end
  cantidad = math.max(1, math.floor(cantidad))
  if objetivo.montado and self:danarMontura(objetivo, cantidad, origen) then return end
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
  if objetivo.medidor and origen then
    -- medidor de daño: cuenta lo que hace cada jugador (también sus esbirros y mascotas, que llegan aquí con su dueño como origen)
    local autor = origen
    if autor.dueno and self.entidades[autor.dueno] then autor = self.entidades[autor.dueno] end
    if autor.kind == "jugador" then
      objetivo.danos = objetivo.danos or {}
      objetivo.danoNombres = objetivo.danoNombres or {}
      objetivo.danos[autor.id] = (objetivo.danos[autor.id] or 0) + math.min(cantidad, math.max(0, objetivo.hp))
      objetivo.danoNombres[autor.id] = autor.nombre
      autor.jefeAtacado, autor.jefeAtacadoT = objetivo.id, self.tiempo
    end
  end
  objetivo.hp = objetivo.hp - cantidad
  objetivo.ultimoGolpe = self.tiempo
  objetivo.flashHasta = self.tiempo + 0.12   -- destello rojo de daño: dura un instante y se apaga solo
  if origen then objetivo.amenaza = origen.id end
  if objetivo.kind == "monstruo" and objetivo.hp > 0 and self.tiempo - (objetivo.sndHerido or -9) > 0.45 then
    objetivo.sndHerido = self.tiempo
    self:sonar("herido_" .. Voces.de(objetivo.monstruo), objetivo)
  end
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
  cant = math.floor(cant * Balance.XP_MULTIPLICADOR * self:bonoExp(p) + 0.5)
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

-- Deja una pieza en el suelo cerca de (x, y): cada objeto, montón de oro o mercancía cae por
-- separado, repartido alrededor, y se recoge pasando por encima.
function Mundo:dejarEnSuelo(pieza, x, y, modo, z)
  local px, py = x, y
  for _ = 1, 8 do
    local ang, d = math.random() * math.pi * 2, 0.5 + math.random() * 1.1
    local cx, cy = x + math.cos(ang) * d, y + math.sin(ang) * d
    if (modo or "mundo") == "mundo" and (z or 0) == 0 then
      if require("compartido.dominio.mapa").transitable(self.mapas.mundo, math.floor(cx), math.floor(cy)) then px, py = cx, cy break end
    else
      px, py = cx, cy break
    end
  end
  pieza.id = self:idNuevo()
  pieza.kind, pieza.vivo, pieza.x, pieza.y, pieza.modo, pieza.z = "loot", true, px, py, modo or "mundo", z or 0
  pieza.nombre = pieza.nombre or "Botín"
  self.entidades[pieza.id] = pieza
  return pieza
end

-- Ranking de daño de un jefe: lista { id, nombre, dano, pct } de mayor a menor.
function Mundo:rankingDano(e)
  local lista, total = {}, 0
  for id, d in pairs(e.danos or {}) do
    lista[#lista + 1] = { id = id, nombre = e.danoNombres and e.danoNombres[id] or "?", dano = d }
    total = total + d
  end
  table.sort(lista, function(a, b) if a.dano ~= b.dano then return a.dano > b.dano end return a.id < b.id end)
  for _, f in ipairs(lista) do f.pct = total > 0 and (f.dano / total) or 0 end
  return lista, total
end

Mundo.DANO_MINIMO_JEFE = 0.02    -- quien hace menos de este % del daño total no recibe experiencia ni oro

-- Cae un jefe con medidor de daño: la experiencia y el oro se reparten en proporción al daño, y el BOTÍN es de quien hizo más (y de su grupo).
function Mundo:repartirJefe(e)
  local ranking = self:rankingDano(e)
  if #ranking == 0 then return end
  local oroTotal = math.floor((e.oro or 5) * 0.3)
  local ganador
  for _, f in ipairs(ranking) do
    local p = self.entidades[f.id]
    if p and (p.kind == "jugador") and not p.borrar then
      ganador = ganador or p
      if f.pct >= Mundo.DANO_MINIMO_JEFE then
        local exp = Balance.xpMonstruo(p.nivel or 1, e.nivel or 1, e.elite) * (e.xpMul or 1) * f.pct * (1 + 0.1 * (math.min(#ranking, 5) - 1))   -- el grupo da un pequeño extra sobre el total
        exp = math.floor(exp * self:bonoGremio(p) + 0.5)
        if exp > 0 then self:ganarXp(p, exp) self:mascotaGanaXp(p, exp) end
        p.oro = (p.oro or 0) + math.floor(oroTotal * f.pct)
      end
      p.caceria = p.caceria or {}
      p.caceria[e.monstruo] = (p.caceria[e.monstruo] or 0) + 1
      self:avanzarMisiones(p, e.monstruo)
    end
  end
  e.ganadorBotin = ganador and ganador.id or nil
  if ganador then self:soltarBotin(e, ganador) end
  -- aviso al servidor: quién ganó el jefe y los tres que más daño hicieron
  local partes = {}
  for i = 1, math.min(3, #ranking) do partes[#partes + 1] = string.format("%s %d%%", ranking[i].nombre, math.floor(ranking[i].pct * 100 + 0.5)) end
  self:avisoEvento("mundo", "", "¡" .. e.nombre .. " ha caído! Más daño: " .. table.concat(partes, ", ") .. ".", nil)
end

-- Datos del medidor de daño que ve el jugador p: el jefe que tiene como objetivo o el último que atacó (unos segundos), con su ranking.
function Mundo:medidorDe(p)
  local e = p.objetivo and self.entidades[p.objetivo]
  if not (e and e.medidor and e.danos and e.vivo) then
    e = p.jefeAtacado and self.entidades[p.jefeAtacado]
    if not (e and e.medidor and e.danos and e.vivo and (self.tiempo - (p.jefeAtacadoT or -99)) < 20) then return nil end
  end
  local ranking = self:rankingDano(e)
  local filas, yoDentro = {}, false
  for i, f in ipairs(ranking) do
    if i <= 6 then
      filas[#filas + 1] = { f.nombre, f.dano, math.floor(f.pct * 100 + 0.5), f.id == p.id and 1 or 0 }
      if f.id == p.id then yoDentro = true end
    elseif f.id == p.id then
      filas[#filas + 1] = { f.nombre, f.dano, math.floor(f.pct * 100 + 0.5), 1, i }
      yoDentro = true
    end
  end
  return { n = e.nombre, hp = e.hp, hpMax = e.hpMax, f = filas }
end

function Mundo:soltarBotin(m, asesino)
  if not asesino or asesino.kind == "bot" then
    if asesino and asesino.kind == "bot" then asesino.oro = (asesino.oro or 0) + m.oro end
    return
  end
  local loot = { oro = m.oro, items = {} }
  for _, it in ipairs(Balance.tirar(m)) do
    loot.items[#loot.items + 1] = it
  end
  if m.categoria then
    -- criaturas de grupo: mejor botín (polvo arcano con más probabilidad, pero no seguro)
    if (m.nivel or 1) > Balance.POLVO_NIVEL_MIN and math.random() < (m.categoria == "gigante" and 0.6 or 0.35) then
      loot.items[#loot.items + 1] = { id = "polvo_arcano", cant = math.random(2, 4) }
    end
    if m.categoria == "gigante" and math.random() < 0.5 then
      loot.items[#loot.items + 1] = { id = Items.aleatorioCualquiera(Datos, math.min(8, Items.tierPara(m.nivel) + 1)), cant = 1 }
    end
  end
  if math.random() < (m.categoria == "gigante" and 1 or m.categoria == "party" and 0.6 or 0.12) then
    local tier = Items.tierPara(m.nivel)
    if m.categoria then tier = math.min(8, tier + 1)
    elseif tier > 1 and math.random() < 0.35 then tier = tier - 1 end
    local id = Items.aleatorioCualquiera(Datos, tier)
    if Datos.item(id) then loot.items[#loot.items + 1] = { id = id, cant = 1 } end
  end
  -- polvo arcano para encantar: difícil de conseguir y solo de criaturas por encima del nivel 10
  if (m.nivel or 1) > Balance.POLVO_NIVEL_MIN and math.random() < Balance.POLVO_PROB then
    loot.items[#loot.items + 1] = { id = "polvo_arcano", cant = math.random(1, 1 + math.floor((m.nivel or 1) / 16)) }
  end
  if math.random() < 0.04 then
    local tier = math.min(4, math.floor((m.nivel or 1) / 6) + 1)
    loot.items[#loot.items + 1] = { id = "mochila_" .. tier, cant = 1 }
  end
  -- cada cosa cae al suelo por separado
  local base = { dueno = asesino.id, grupo = asesino.grupoId, hasta = self.tiempo + 45 }
  local function pieza(extra)
    local t = {}
    for k, v in pairs(base) do t[k] = v end
    for k, v in pairs(extra) do t[k] = v end
    self:dejarEnSuelo(t, m.x, m.y, m.modo, m.z)
  end
  if (loot.oro or 0) > 0 then pieza({ oro = loot.oro, items = {}, nombre = "Oro" }) end
  for _, it in ipairs(loot.items) do
    local d = Datos.item(it.id)
    pieza({ oro = 0, items = { it }, item = it.id, nombre = d and d.nombre or "Objeto" })
  end
end

function Mundo:morir(e, origen)
  e.vivo = false
  e.hp = 0
  self:limpiarEstados(e)
  if e.moba then self:morirMoba(e, origen) return end        -- esbirros, torres y nexos del asedio
  if e.kind == "mascota" then
    self:caeMascota(e)
    return
  end
  if e.kind == "caravana" then
    self:cayeCaravana(e, origen)
    return
  end
  if (e.kind == "jugador" or e.kind == "bot") then
    self:soltarCargaMuerto(e)
    e.robo = nil
    if e.escolta then e.escolta = nil end
    self:caeBuscado(e, origen)
  end
  if e.kind == "monstruo" then
    self:sonar("muerte_" .. Voces.de(e.monstruo), e)
    if e.medidor and e.danos and next(e.danos) then
      self:repartirJefe(e)
    elseif origen and origen.kind == "jugador" and origen.grupoId and self:recompensaGrupo(e, origen) then
      -- recompensa repartida entre el grupo
    elseif origen and (origen.kind == "jugador" or origen.kind == "bot") then
      local exp = Balance.xpMonstruo(origen.nivel or 1, e.nivel or 1, e.elite) * (e.xpMul or 1)
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
    e.respawn = self.tiempo + (e.elite and Datos.RESPAWN_ELITE or Datos.RESPAWN_MONSTRUO)
    -- los jefes del mundo vuelven 20 minutos después de caer (RESPAWN_JEFE_MUNDO)
    local defRes = Datos.monstruo(e.monstruo)
    if defRes and defRes.jefeMundo then e.respawn = self.tiempo + (Datos.RESPAWN_JEFE_MUNDO or 1200) end
    -- en las mazmorras las criaturas no reaparecen una a una: todas vuelven cuando reaparece el jefe
    if e.mz and not e.jefeMz then e.respawn = 1e12 end
    if e.efimero then e.borrar = true end
    if e.jefeMz then self:jefeMazmorraCae(e, origen) end
    if e.elite and not e.jefeMz then
      self:mensaje("sistema", "", e.nombre .. " ha caído.", origen)
    end
  elseif e.kind == "jugador" or e.kind == "bot" then
    self:sonar("muerte_jugador", e)
    e.respawn = self.tiempo + 6
    if e.modo == "mundo" then self:dejarCuerpo(e) end
    -- por encima del nivel 10 morir cuesta experiencia (sin bajar de nivel)
    if e.modo == "mundo" and (e.nivel or 1) > Balance.MUERTE_NIVEL_MIN and Balance.MUERTE_XP_PERDIDA > 0 then
      local perdida = math.min(e.xp or 0, math.floor(Datos.xpPara(e.nivel) * Balance.MUERTE_XP_PERDIDA))
      if perdida > 0 then
        e.xp = e.xp - perdida
        self:marcarProgreso(e)
        self:mensaje("sistema", "", "Pierdes " .. perdida .. " de experiencia al morir.", e)
      end
    end
    if e.modo == "estandarte" and e.llevaBandera then self:soltarBandera(e) end
    -- los cristales que llevaba caen al suelo donde muere: el rival puede cogerlos
    if e.modo == "batalla" and (e.llevaCristales or 0) > 0 then
      for _ = 1, e.llevaCristales do self:dejarCristal(e.x, e.y, e.faccion == "albor" and "umbra" or "albor") end
      e.llevaCristales = nil
    end
    if origen and origen.faccion and origen.faccion ~= e.faccion then
      if e.modo ~= "moba" then self.gloria[origen.faccion] = (self.gloria[origen.faccion] or 0) + 8 end
      local inst = self.instancia[e.modo]
      if inst and inst.activa then
        -- las bajas suman puntos en la batalla y en el asedio; en el estandarte los puntos son las CAPTURAS (tres ganan): matar a alguien no cuenta, solo lo devuelve a su base
        if e.modo == "moba" then inst.puntos[origen.faccion] = inst.puntos[origen.faccion] + 10 end
        inst.bajas = inst.bajas or { albor = 0, umbra = 0 }
        inst.bajas[origen.faccion] = (inst.bajas[origen.faccion] or 0) + 1
        local autor = origen
        if autor.dueno and self.entidades[autor.dueno] then autor = self.entidades[autor.dueno] end
        self:contarEvento(e, "muertes")
        self:contarEvento(autor, "bajas")
        if e.modo == "moba" then self:bajaMoba(autor, e) end
        self:registrarEvento(e.modo, (autor.nombre or "?") .. " derriba a " .. e.nombre, origen.faccion)
      end
    end
    self:mensaje("sistema", "", e.nombre .. " ha caído.", e)
  elseif e.kind == "estatua" or e.kind == "puerta" or e.kind == "altar" then
    local fac = origen and origen.faccion
    if fac then
      local inst = self.instancia.batalla
      local pts = e.kind == "altar" and 200 or (e.kind == "puerta" and (e.principal and 160 or 120) or 100)
      inst.puntos[fac] = inst.puntos[fac] + pts
      local quien = fac == "albor" and "Albor" or "Umbra"
      if e.kind == "altar" then
        -- el núcleo: solo al destruirlo sale el cristal, que hay que llevar al altar propio
        self:dejarCristal(e.x, e.y, e.faccion)
        e.respawn = self.tiempo + 120
        if origen.kind == "jugador" or origen.kind == "bot" then origen.cristales = (origen.cristales or 0) + 1 end
        self:avisoEvento("mundo", "", e.nombre .. " destruido por " .. quien .. ". ¡Su cristal está en el suelo!", nil)
        self:mensaje("sistema", "", e.nombre .. " destruido. +" .. pts .. " puntos. ¡Recoge el cristal y llévalo a tu altar!", origen)
      else
        self:mensaje("sistema", "", e.nombre .. " cae. " .. quien .. " gana +" .. pts .. " puntos.", origen)
      end
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

-- Una criatura cae: avanzan las misiones de cazar que la piden y, en las de recolectar, puede soltar su trofeo.
function Mundo:avanzarMisiones(p, monId)
  for id, st in pairs(p.misiones or {}) do
    local q = Misiones.por_id[id]
    if q and st.aceptada and not st.entregada then
      if q.tipo == "cazar" and q.monstruo == monId then
        local antes = Misiones.completa(p, q, st)
        st.progreso = math.min(q.cantidad, (st.progreso or 0) + 1)
        if st.progreso >= q.cantidad and not antes then
          self:mensaje("sistema", "", "Misión cumplida: " .. q.titulo .. ". Vuelve con " .. Misiones.nombreNpc(q.destino) .. ".", p)
        else
          self:mensaje("sistema", "", q.titulo .. ": " .. st.progreso .. "/" .. q.cantidad, p)
        end
        self:marcarProgreso(p)
      elseif q.tipo == "recolectar" and q.de == monId and not Misiones.completa(p, q, st) and math.random() < Misiones.PROB_TROFEO then
        if self:darItem(p, q.item, 1) then
          local n = Misiones.progreso(p, q, st)
          local def = Datos.item(q.item)
          if n >= q.cantidad then
            self:mensaje("sistema", "", "Misión cumplida: " .. q.titulo .. ". Vuelve con " .. Misiones.nombreNpc(q.destino) .. ".", p)
          else
            self:mensaje("sistema", "", (def and def.nombre or "Trofeo") .. ": " .. n .. "/" .. q.cantidad, p)
          end
          self:marcarProgreso(p)
        else
          self:mensaje("sistema", "", "Tu bolsa está llena: no puedes recoger el trofeo.", p)
        end
      end
    end
  end
end

-- El cuerpo de un personaje caído se queda donde murió (sin vida, en gris) un buen rato; el
-- personaje reaparece en la ciudad de su corona.
Mundo.CUERPO_SEG = 300
Mundo.CRISTALES_META = 5       -- cristales entregados que dan la victoria en la batalla
Mundo.PUNTOS_CRISTAL = 300      -- lo que vale entregar el cristal del núcleo enemigo
Mundo.DISTANCIA_DESPIERTA = 45    -- casillas: lejos de todo jugador, las criaturas se actualizan 1 vez por segundo
Mundo.POCION_CD = 3          -- segundos hasta poder repetir ESA poción (cada poción tiene su propio enfriamiento)
Mundo.AUTOPOCION_UMBRAL = 0.5 -- con la autopoción encendida, bebe vida al bajar de esta fracción
function Mundo:dejarCuerpo(e)
  local id = self:idNuevo()
  self.entidades[id] = {
    id = id, kind = "cuerpo", nombre = e.nombre, faccion = e.faccion, clase = e.clase, job = e.job, addon = e.addonActivo, genero = e.genero, equipo = e.equipo,
    dir = e.dir or 1, x = e.x, y = e.y, z = e.z or 0, modo = e.modo, vivo = true,
    hasta = self.tiempo + Mundo.CUERPO_SEG,
  }
end

-- Spawn de la ciudad de la corona de e más cercana a (x, y).
function Mundo:ciudadPropiaCerca(e, x, y)
  local mejor, md
  for _, c in ipairs(self.mapas.mundo.ciudades) do
    if c.faccion == e.faccion and c.spawn then
      local d = (c.spawn.x - x) ^ 2 + (c.spawn.y - y) ^ 2
      if not md or d < md then mejor, md = c, d end
    end
  end
  return mejor
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
    e.danos, e.danoNombres = nil, nil
    e.x, e.y = e.hogarx, e.hogary
    e.hp = e.hpMax
    if e.jefeMz then self:reiniciarMazmorra(e.mz) end
  elseif e.kind == "jugador" or e.kind == "bot" then
    local v = e.vinculo or { x = e.x, y = e.y, modo = "mundo" }
    if e.modo == "batalla" or e.modo == "estandarte" or e.modo == "moba" then
      local sp = self.mapas[e.modo].spawns[e.faccion]
      e.x, e.y = sp.x, sp.y
    elseif self:enMazmorra(e) or self:enMapaFao(e) then
      -- muere en una mazmorra o en un mapa aparte de FAO: vuelve al punto de reaparición del mundo
      e.modo, e.z, e.zona = "mundo", 0, nil
      e.x, e.y = v.x, v.y
    else
      local c = self:ciudadPropiaCerca(e, e.x, e.y)
      if v.ciudad then
        for _, cc in ipairs(self.mapas.mundo.ciudades) do
          if cc.id == v.ciudad and cc.faccion == e.faccion and cc.spawn then c = cc break end
        end
      end
      if c then
        e.modo, e.z = "mundo", 0
        e.x, e.y = c.spawn.x, c.spawn.y
      else
        e.modo = v.modo or "mundo"
        e.x, e.y = v.x, v.y
      end
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
  loot.items, loot.oro = {}, 0
  -- mercancías de una caravana caída: las llevan comerciantes y ladrones
  if loot.bienes and next(loot.bienes) then
    loot.aviso = loot.aviso or {}
    local avisar = (self.tiempo - (loot.aviso[p.id] or -10)) > 3
    if avisar then loot.aviso[p.id] = self.tiempo end
    if p.job ~= "trader" and p.job ~= "thief" then
      if avisar then self:mensaje("sistema", "", "Solo comerciantes y ladrones pueden cargar mercancías.", p) end
      return
    end
    local destino = p.job == "thief" and "cargaRobada" or "carga"
    p[destino] = p[destino] or {}
    local libre = self:capacidadCarga(p) - self:pesoCarga(p)
    local tomadas = 0
    for bien, c in pairs(loot.bienes) do
      local n = math.min(c, libre)
      if n > 0 then
        p[destino][bien] = (p[destino][bien] or 0) + n
        loot.bienes[bien] = c - n > 0 and (c - n) or nil
        libre = libre - n
        tomadas = tomadas + n
      end
    end
    self:recalcularCarga(p)
    if tomadas > 0 then self:mensaje("sistema", "", "Recoges " .. tomadas .. " unidades de mercancía.", p) end
    if next(loot.bienes) then return end
  end
  loot.borrar = true
end

-- Sonido de cada poder (lo usa también el cliente para el eco instantáneo al lanzarlo).
Mundo.SONIDO_PODER = {
  golpe = "corte", tajo = "corte", carga = "corte", grito = "grito",
  misil = "magia", fuego = "fuego", escudo = "magia", nova = "hielo",
  rayo_hielo = "hielo", rayo_arcano = "magia", lluvia_fuego = "fuego", teletransporte = "magia", torbellino = "magia",
  disparo = "flecha", lluvia = "flecha", preciso = "flecha", trampa = "flecha",
  curar = "cura", bendicion = "sagrado", castigo = "sagrado", consagrar = "sagrado",
  pantera = "fuego", furia = "grito", sombra = "magia", meteoro = "fuego",
  flecha_veneno = "flecha", paso_agil = "flecha", sanacion = "cura", juicio = "sagrado",
  estocada = "lanza", barrido = "lanza", embestida = "lanza", jabalina = "flecha", tormenta_lanzas = "lanza",
  muro_lanzas = "grito", toque_necro = "oscuro", espinas = "oscuro", maldecir = "oscuro", alzar_esqueletos = "oscuro",
  drenar = "oscuro", espectro = "oscuro",
}

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
    if not self:lineaLibre(p, objetivo) then return "Hay una pared en medio." end
  elseif h.tipo == "aliado" then
    if not objetivo or not self:aliado(p, objetivo) then objetivo = p end
    if not enRango(objetivo, h.rango) then
      p.persigue = true
      p.habilidadPendiente = slot
      return "Te acercas."
    end
  end
  p.mp = p.mp - h.mana
  p.cds[idh] = self.tiempo + h.cd * (1 - self:bonoVelocidadMagica(p))
  p.gcd = self.tiempo + 0.35
  p.swing = 0.2
  p.ultimoGolpe = self.tiempo
  self:marcarAtaque(p, objetivo ~= p and objetivo or nil, (h.rango or 0) > 3 or objetivo == nil or objetivo == p, true)
  -- el personaje se vuelve hacia su objetivo al lanzar el poder (si no, el efecto y el cuerpo mirarían a lados distintos)
  if objetivo and objetivo ~= p and objetivo.x and not p.tramo then self:encarar(p, objetivo.x - p.x, objetivo.y - p.y) end
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
    local px, py = tx or (objetivo and objetivo.x), ty or (objetivo and objetivo.y)
    if not px then
      -- sin objetivo ni punto: cae delante del personaje, hacia donde mira
      local d = math.min(h.rango or 5, 4)
      local mx = ({ [1] = 0, [2] = 0, [3] = 1, [4] = -1 })[p.dir or 1] or 0
      local my = ({ [1] = 1, [2] = -1, [3] = 0, [4] = 0 })[p.dir or 1] or 0
      px, py = p.x + mx * d, p.y + my * d
    end
    if h.blink then
      -- teletransporte: te mueves al punto (como mucho hasta el alcance, y a la casilla libre más cercana)
      local d = Util.dist(p.x, p.y, px, py)
      if d > (h.rango or 7) then px, py = p.x + (px - p.x) * h.rango / d, p.y + (py - p.y) * h.rango / d end
      local ox, oy = p.x, p.y
      if not self:colocarCerca(p, px, py) then p.cds[idh], p.mp = 0, p.mp + h.mana; return "No puedes ir ahí." end
      p.blinkDesde = { ox, oy }
      p.persigue, p.objetivoMover = nil, nil
      px, py = p.x, p.y
    else
      p.impactoX, p.impactoY = px, py
      for _, o in pairs(self.entidades) do
        if o.vivo and self:mismoLugar(p, o) and self:puedeDanar(p, o) and Util.dist(px, py, o.x, o.y) <= (h.aoe or 2) then
          golpe(o, h.coef)
          if h.lentitud and o.vivo then self:aplicarEstado(o, "lentitud", 3, h.lentitud, p) end
        end
      end
      if h.pulsos and h.pulsos > 1 then
        -- torbellino: los golpes siguientes llegan cada 0,35 s mientras gira
        self.pulsos = self.pulsos or {}
        for i = 1, h.pulsos - 1 do
          self.pulsos[#self.pulsos + 1] = { t = self.tiempo + 0.45 + 0.35 * (i - 1), p = p, x = px, y = py, h = h }
        end
      end
    end
  elseif h.tipo == "aliado" then
    if h.cura then self:curar(objetivo, self:potenciaCura(p, h), p) end
    if h.buff == "bendicion" then self:ponerBuff(objetivo, "bendicion", h.dur, { def = 0.18 * h.pot, regen = 4 * h.pot, habilidad = idh }) end
  elseif h.tipo == "propio" then
    if h.buff == "escudo" then
      local abs = (30 + p.nivel * 4) * h.pot
      self:ponerBuff(p, "escudo", h.dur, { absorbe = abs, habilidad = idh })
      self:numero(p, "escudo", { 0.55, 0.7, 1 })
    else
      -- potenciadores propios (furia, paso ágil...): sus cifras crecen con el rango
      local ef = {}
      for k, v in pairs(h.efecto or {}) do ef[k] = v * h.pot end
      ef.habilidad = idh
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
        self:ponerBuff(o, "grito", h.dur, { atk = 0.22 * h.pot, habilidad = idh })
      end
    end
    self:ponerBuff(p, "grito", h.dur, { atk = 0.22 * h.pot, habilidad = idh })
  elseif h.tipo == "mixto" then
    for _, o in pairs(self.entidades) do
      if o.vivo and self:mismoLugar(p, o) and Util.dist(p.x, p.y, o.x, o.y) <= h.rango then
        if self:puedeDanar(p, o) then golpe(o, h.coef)
        elseif self:aliado(p, o) then self:curar(o, self:potenciaCura(p, h), p) end
      end
    end
    self:curar(p, self:potenciaCura(p, h), p)
  elseif h.tipo == "invocar" then
    self:invocarEsbirros(p, h)
    self:numero(p, h.nombre, { 0.6, 1, 0.7 })
  elseif h.tipo == "suelo" then
    local id = self:idNuevo()
    self.entidades[id] = {
      id = id, kind = "trampa", nombre = "Trampa", faccion = p.faccion,
      x = p.x, y = p.y, modo = p.modo, vivo = true, dueno = p.id,
      hasta = self.tiempo + 12, casaId = p.casaId,
    }
  end
  self:sonar(Mundo.SONIDO_PODER[idh] or "magia", p)
  local ex = objetivo and objetivo.x or p.x
  local ey = objetivo and objetivo.y or p.y
  if PoderesFao[idh] then
    -- poder con efecto de capas de FAO: un solo efecto con toda la animación (el proyectil del servidor viaja sin dibujarse); x, y = objetivo o punto; x0, y0 = lanzador
    local X, Y, rot = ex, ey, (objetivo and objetivo ~= p) and math.atan2(ey - p.y, ex - p.x) or nil
    if h.tipo == "alrededor" or h.tipo == "buff_alrededor" or h.tipo == "mixto" or h.tipo == "propio" or h.tipo == "suelo" or h.tipo == "aliados" or h.tipo == "invocar" then
      X, Y, rot = p.x, p.y, Mundo.ANGULO_DIR[p.dir or 1]       -- (los de alrededor se abren hacia donde mira el personaje)
    elseif h.tipo == "punto" then X, Y, rot = p.impactoX or tx or ex, p.impactoY or ty or ey, nil end
    if p.blinkDesde then
      self:efecto(idh, p.blinkDesde[1], p.blinkDesde[2], Mundo.DURACION_EFECTO[idh], nil, p.blinkDesde[1], p.blinkDesde[2])
      X, Y = p.x, p.y
      p.blinkDesde = nil
    end
    self:efecto(idh, X, Y, Mundo.DURACION_EFECTO[idh], rot, p.x, p.y)
    p.impactoX, p.impactoY = nil, nil
  elseif h.tipo == "alrededor" or h.tipo == "buff_alrededor" or h.tipo == "mixto" or h.tipo == "propio" or h.tipo == "suelo" or h.tipo == "aliados" or h.tipo == "invocar" then
    -- los de alrededor (el barrido) se abren hacia donde mira el personaje
    self:efecto(idh, p.x, p.y, Mundo.DURACION_EFECTO[idh] or 0.5, Mundo.ANGULO_DIR[p.dir or 1])
  elseif h.tipo == "punto" then
    self:efecto(idh, p.impactoX or tx or ex, p.impactoY or ty or ey, Mundo.DURACION_EFECTO[idh] or 0.55)
    p.impactoX, p.impactoY = nil, nil
  elseif not h.proyectil then
    -- con objetivo, el efecto mira de quien ataca hacia él (si estás debajo del enemigo, la estocada sube)
    local rot = (objetivo and objetivo ~= p) and math.atan2(ey - p.y, ex - p.x) or nil
    self:efecto(idh, ex, ey, Mundo.DURACION_EFECTO[idh] or 0.4, rot, p.x, p.y)
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
  self:sonar("cura", p)
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
  self:marcarAtaque(origen, objetivo, true)
  local id = self:idNuevo()
  self.entidades[id] = {
    id = id, kind = "proyectil",
    x = origen.x, y = origen.y, modo = origen.modo, casaId = origen.casaId,
    objetivo = objetivo.id, tx = objetivo.x, ty = objetivo.y,
    dueno = origen.id, coef = h.coef or 1, aoe = h.aoe, tipo = h.proyectil, dano = h.dano, estado = h.estado,
    vivo = true, vida = 1.4, oculto = (h.id and PoderesFao[h.id]) and true or nil,   -- (oculto: el efecto de FAO del poder ya dibuja el vuelo y el impacto)
  }
end

function Mundo:autoataque(p)
  local o = p.objetivo and self.entidades[p.objetivo]
  if not o or not o.vivo or not self:puedeDanar(p, o) then return end
  if not self:mismoLugar(p, o) then return end
  local rango = self:alcance(p)
  if Util.dist(p.x, p.y, o.x, o.y) > rango then return end
  if not self:lineaLibre(p, o) then return end
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
      proyectil = ({ clerigo = "sagrado", mago = "misil", nigromante = "necro" })[p.clase] or "flecha",
    })
  else
    self:golpear(p, o, 1)
  end
end

function Mundo:actualizarJugador(e, dt)
  if e.mobaOrig and e.modo ~= "moba" then self:restaurarMoba(e) end        -- salga como salga del asedio (comandos, desconexión...), recupera lo suyo
  if e.modo == "mundo" and e.kind == "jugador" and (e.z or 0) == 0 then self:vigilarPortalesFao(e) end
  if e.modo ~= "mundo" and e.modo ~= "casa" then
    self:trampasMazmorra(e)
    if self.mapas[e.modo] and self.mapas[e.modo].fao then self:vigilarSalidaFao(e) end
  end
  if not e.vivo then
    if self.tiempo >= (e.respawn or 0) then self:revivir(e) end
    return
  end
  if e.kind == "jugador" then self:beberAutopocion(e) end
  -- la mascota vuelve sola tras una muerte o una guerra
  if e.kind == "jugador" and e.mascotaActiva and not e.mascotaId and e.modo ~= "batalla" and e.modo ~= "estandarte" and e.modo ~= "moba"
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
  -- montura y carga: la montura acelera y ir cargado frena
  if e.montado and ((e.modo ~= "mundo" and not self:enMapaFao(e)) or e.modo == "moba" or (e.z or 0) > 0) then
    e.montado = nil
    self:recalcularCarga(e)
  end
  if e.job or e.montado then
    local vel = self:bonoMontura(e)
    mul = mul * (1 + vel) * (1 - (e.penalCarga or 0))
  end
  if e.robo then self:actualizarRobo(e) end
  if e.buscado then self:actualizarLey(e) end
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
    if o.kind == "loot" and o.vivo and self:mismoLugar(e, o)
      and (not o.dueno or o.dueno == e.id or (o.grupo and e.grupoId == o.grupo) or self.tiempo > (o.hasta or 0) - 20) then
      if Util.dist(e.x, e.y, o.x, o.y) < 0.8 and e.kind == "jugador" then self:recoger(e, o) end
    end
  end
  self:pisarEscalera(e)
  if e.modo == "casa" and e.kind == "jugador" then
    local puerta = self:interior(e).puerta
    if puerta and Util.dist(e.x, e.y, puerta.x, puerta.y) < 0.45 then self:salirCasa(e) end
  end
  if e.modo == "estandarte" then self:tocarBandera(e) end
  if e.modo == "batalla" and (e.kind == "jugador" or e.kind == "bot") then self:cristalesCerca(e) end
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

-- A quien pueden atacar las criaturas: jugadores, bots, guardias y caravanas. Se arma una lista por
-- fotograma (en Mundo:actualizar) para no recorrer todas las entidades por cada criatura.
local function objetivosPosibles(self)
  if self._objMon then return ipairs(self._objMon) end
  return pairs(self.entidades)
end

function Mundo:actualizarMonstruo(e, dt)
  if not e.vivo then
    if self.tiempo >= (e.respawn or 0) then self:revivir(e) end
    return
  end
  if e.moba then return self:actualizarEsbirroMoba(e, dt) end
  if e.efimero and self.tiempo > e.efimero then e.borrar = true return end
  if (e.aturdido or 0) > 0 then e.aturdido = e.aturdido - dt return end
  e.sensor = (e.sensor or 0) - dt
  if e.sensor <= 0 then
    e.sensor = 0.45
    local mejor, md = nil, (e.agresivo and 6.5 or 0)
    local amenaza = e.amenaza and self.entidades[e.amenaza]
    if amenaza and amenaza.vivo and not amenaza.staff and not (amenaza.kind ~= "guardia" and self:enSantuario(amenaza)) and self:mismoLugar(e, amenaza) and Util.dist(e.x, e.y, amenaza.x, amenaza.y) < 12 then
      mejor = amenaza
    else
      for _, o in objetivosPosibles(self) do
        if o.vivo and o.id ~= e.id and not o.staff and self:mismoLugar(e, o) and (o.kind == "guardia" or not self:enSantuario(o))
          and (o.kind == "jugador" or o.kind == "bot" or o.kind == "guardia" or (e.bandido and o.kind == "caravana")) then
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
  if o and o.kind ~= "guardia" and o.kind ~= "monstruo" and self:enSantuario(o) then o, e.objetivo = nil, nil end -- zona segura
  if o and o.staff then o, e.objetivo = nil, nil end -- los monstruos ignoran al personal
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
      local buscado = (o.kind == "jugador" or o.kind == "bot") and self:esBuscado(o)
      -- en la ciudad (zona segura) solo se persigue a los buscados; fuera, a los enemigos
      if o.vivo and o.faccion and ((o.faccion ~= e.faccion and (o.kind == "monstruo" or not self:enSantuario(o))) or buscado) and self:mismoLugar(e, o) and (o.kind == "jugador" or o.kind == "bot" or o.kind == "monstruo") then
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
  elseif self:patrullar(e, dt) then
    return
  elseif Util.dist(e.x, e.y, e.puestoX, e.puestoY) > 1.2 then
    ddx, ddy = self:mejorDireccion(e, e.puestoX - e.x, e.puestoY - e.y)
  end
  self:avanzar(e, dt, ddx, ddy, e.spd or 3)
end

-- Ida y vuelta por la calle: dos puntos fijos, una pausa en cada extremo.
function Mundo:rutaPatrulla(e)
  local mapa = self:mapaDe(e)
  local ciudad = self:ciudadEn(e.x, e.y)
  local function dentro(x, y)
    if Mapa.bloqueado(mapa, x, y, e.faccion) then return false end
    if not ciudad then return true end
    local tx, ty = math.floor(x), math.floor(y)
    return tx > ciudad.x and ty > ciudad.y and tx < ciudad.x + ciudad.w - 1 and ty < ciudad.y + ciudad.h - 1
  end
  local function largo(dx, dy)
    local n, px, py = 0, e.x, e.y
    for _ = 1, 4 do
      local nx, ny = px + dx, py + dy
      if not dentro(nx, ny) then break end
      px, py, n = nx, ny, n + 1
    end
    return n
  end
  local horizontal = largo(1, 0) + largo(-1, 0)
  local vertical = largo(0, 1) + largo(0, -1)
  local dx, dy = horizontal >= vertical and 1 or 0, horizontal >= vertical and 0 or 1
  local atras, adelante = largo(-dx, -dy), largo(dx, dy)
  if atras + adelante < 2 then return nil end
  return {
    { x = e.x - dx * atras, y = e.y - dy * atras },
    { x = e.x + dx * adelante, y = e.y + dy * adelante },
  }
end

function Mundo:patrullar(e, dt)
  local ruta = e.ruta
  if not ruta or #ruta < 2 or e.modo ~= "mundo" then return false end
  for _, o in pairs(self.entidades) do
    if (o.kind == "jugador" or o.kind == "bot") and o.vivo and self:mismoLugar(e, o) and Util.dist(e.x, e.y, o.x, o.y) < 2.6 then
      self:avanzar(e, dt, 0, 0, 2.2)
      return true
    end
  end
  e.espera = (e.espera or 0) - dt
  if e.espera > 0 then
    self:avanzar(e, dt, 0, 0, 2.2)
    return true
  end
  local meta = ruta[e.paso or 1] or ruta[1]
  if Util.dist(e.x, e.y, meta.x, meta.y) < 0.2 then
    e.paso = (e.paso or 1) % #ruta + 1
    e.espera = 1.6
    self:avanzar(e, dt, 0, 0, 2.2)
    return true
  end
  local ddx, ddy = self:mejorDireccion(e, meta.x - e.x, meta.y - e.y)
  self:avanzar(e, dt, ddx, ddy, 2.2)
  return true
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
  -- con pasos largos de simulación (30 por segundo) el proyectil avanza 0,37 casillas por paso: si el paso alcanza la distancia, impacta
  if d < 0.3 or d <= 11 * dt or p.vida <= 0 then
    if d <= 11 * dt then p.x, p.y = tx, ty end
    local dueno = p.dueno and self.entidades[p.dueno]
    if dueno and obj and obj.vivo then
      if p.aoe then
        for _, o in pairs(self.entidades) do
          if o.vivo and self:mismoLugar(obj, o) and Util.dist(obj.x, obj.y, o.x, o.y) <= p.aoe and self:puedeDanar(dueno, o) then
            self:golpear(dueno, o, p.coef or 1, 0.85, p.dano or "fisico", true)
            if o.vivo then self:probarEstado(dueno, o, p.estado) end
          end
        end
      else
        self:golpear(dueno, obj, p.coef or 1, nil, p.dano or "fisico", true)
        if obj.vivo then self:probarEstado(dueno, obj, p.estado) end
      end
    end
    p.borrar = true
    if not p.oculto then self:efecto(p.tipo or "misil", p.x, p.y, 0.32) end
    return
  end
  local nx, ny = p.x + dx / d * 11 * dt, p.y + dy / d * 11 * dt
  local duenoP = p.dueno and self.entidades[p.dueno]
  local mapaP = self:mapaDe(p)
  if (p.z or 0) == 0 and mapaP and mapaP.bloque and Mundo.casillaOpaca(mapaP, nx, ny, duenoP and duenoP.faccion)
    and not (obj and math.floor(nx) == math.floor(obj.x) and math.floor(ny) == math.floor(obj.y)) then
    p.borrar = true
    if not p.oculto then self:efecto(p.tipo or "misil", p.x, p.y, 0.32) end
    return
  end
  p.x, p.y = nx, ny
end

function Mundo:actualizarTrampa(t, dt)
  if self.tiempo > t.hasta then t.borrar = true return end
  for _, o in pairs(self.entidades) do
    if o.vivo and o.faccion ~= t.faccion and self:mismoLugar(t, o) and Util.dist(t.x, t.y, o.x, o.y) < 0.7 then
      if o.kind == "jugador" or o.kind == "bot" or o.kind == "monstruo" then
        self:aplicarEstado(o, "aturdir", 1.6, nil, nil)
        local dueno = self.entidades[t.dueno]
        if dueno then self:golpear(dueno, o, 0.6, nil, "fisico", true) end
        t.borrar = true
        return
      end
    end
  end
end

-- Aviso del estandarte para todos los que están dentro del evento: chat y marquesina de derecha a izquierda.
function Mundo:avisarEstandarte(texto)
  for _, e in pairs(self.entidades) do
    if e.kind == "jugador" and e.modo == "estandarte" then
      self:mensaje("sistema", "", texto, e)
      self.mensajes[#self.mensajes].marquesina = true
    end
  end
end

function Mundo:tocarBandera(p)
  for _, f in pairs(self.entidades) do
    if f.kind == "bandera" and f.modo == "estandarte" then
      if not f.portador and f.faccion ~= p.faccion and Util.dist(p.x, p.y, f.x, f.y) < 1.15 and not p.llevaBandera then
        f.portador = p.id
        p.llevaBandera = f.faccion
        self:avisarEstandarte(p.nombre .. " toma el estandarte enemigo.")
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
    self:avisarEstandarte(p.nombre .. " captura el estandarte. " .. inst.puntos[p.faccion] .. "/3")
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

-- Cristal enemigo en el suelo del campo de batalla: se recoge pasando por encima.
function Mundo:dejarCristal(x, y, faccion)
  local id = self:idNuevo()
  local ang, d = math.random() * math.pi * 2, 0.4 + math.random() * 0.9
  self.entidades[id] = {
    id = id, kind = "cristal", nombre = "Cristal", faccion = faccion, modo = "batalla", vivo = true, z = 0,
    x = x + math.cos(ang) * d, y = y + math.sin(ang) * d, hasta = self.tiempo + 300,
  }
  return self.entidades[id]
end

-- Recoge cristales cercanos y, si llevas alguno, los entrega al llegar al altar de tu corona.
function Mundo:cristalesCerca(p)
  if p.modo ~= "batalla" or not p.vivo then return end
  for _, o in pairs(self.entidades) do
    if o.kind == "cristal" and o.vivo and not o.borrar and Util.dist(p.x, p.y, o.x, o.y) < 1.1 then
      o.vivo, o.borrar = false, true
      p.llevaCristales = (p.llevaCristales or 0) + 1
      self:mensaje("sistema", "", "Coges un cristal enemigo (" .. p.llevaCristales .. "). Llévalo a tu altar.", p)
    end
  end
  if (p.llevaCristales or 0) > 0 then
    for _, o in pairs(self.entidades) do
      if o.kind == "altar" and o.vivo and o.faccion == p.faccion and o.modo == "batalla" and Util.dist(p.x, p.y, o.x, o.y) < 2.4 then
        self:entregarCristales(p)
        break
      end
    end
  end
end

function Mundo:entregarCristales(p)
  local n = p.llevaCristales or 0
  p.llevaCristales = nil
  for i = #p.bolsa, 1, -1 do
    if p.bolsa[i].id == "cristal" then
      n = n + p.bolsa[i].cant
      table.remove(p.bolsa, i)
    end
  end
  if n <= 0 then return "No llevas cristales." end
  local inst = self.instancia.batalla
  inst.puntos[p.faccion] = inst.puntos[p.faccion] + n * Mundo.PUNTOS_CRISTAL          -- (los puntos solo desempatan si se acaba el tiempo)
  inst.cristales = inst.cristales or { albor = 0, umbra = 0 }
  inst.cristales[p.faccion] = inst.cristales[p.faccion] + n
  p.entregados = (p.entregados or 0) + n
  self:mensaje("sistema", "", "Entregas " .. n .. (n == 1 and " cristal enemigo" or " cristales enemigos") .. ". Tu equipo lleva " .. inst.cristales[p.faccion] .. "/" .. Mundo.CRISTALES_META .. ".", p)
  if inst.activa and not inst.fin then
    self:registrarEvento("batalla", p.nombre .. " entrega un cristal (" .. inst.cristales[p.faccion] .. "/" .. Mundo.CRISTALES_META .. ")", p.faccion)
    -- gana el primer equipo con 5 cristales entregados; matar a alguien no termina la batalla
    if inst.cristales[p.faccion] >= Mundo.CRISTALES_META then self:cerrarInstancia("batalla", p.faccion) end
  end
  return nil
end

function Mundo:nombreEvento(modo)
  if modo == "moba" then return "Asedio (MOBA)" end
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
    programa = self:programaDe(modo), min = self:minimoEvento(modo),
  }
end

function Mundo:meterEnCampo(p, modo)
  local nombre = self:nombreEvento(modo)
  p.colaGuerra = nil
  local inst0 = self.instancia[modo]
  if inst0 and (not p.eventoStats or p.eventoEdicion ~= inst0.edicion or p.eventoModo ~= modo) then
    p.eventoStats, p.eventoEdicion, p.eventoModo = { bajas = 0, muertes = 0, esbirros = 0, torres = 0 }, inst0.edicion, modo
  end
  p.retorno = { x = p.x, y = p.y, modo = p.modo == "casa" and "mundo" or p.modo }
  p.modo = modo
  p.casaId = nil
  if modo == "moba" then self:prepararMoba(p) end          -- (nivel 1 y sin poderes: se van ganando en la partida)
  local sp = self.mapas[modo].spawns[p.faccion]
  p.x, p.y = sp.x, sp.y
  p.objetivo, p.camino, p.persigue = nil, nil, false
  p.zona = nombre
  if p.kind == "jugador" then
    local hoy = os.date("%Y-%m-%d")
    local clave = self:claveEdicion(modo)
    p.eventosDia = p.eventosDia or {}
    p.eventosDia[clave] = hoy
    if p.dbId then
      if self.puertos.marcarEvento then self.puertos.marcarEvento(p.dbId, clave) end
    end
  end
  self:mensaje("sistema", "", p.nombre .. " entra en " .. nombre .. ".", p)
end

-- Jugadores por equipo que hacen falta para empezar un evento (el asedio es más pequeño).
function Mundo:minimoEvento(modo)
  if modo == "moba" then return Datos.JUGADORES_MOBA or 2 end
  return Datos.JUGADORES_EVENTO
end

function Mundo:empezarEvento(modo)
  local min = self:minimoEvento(modo)
  local n, lista = self:contarCola(modo)
  if n.albor < min or n.umbra < min then return false end
  self:reiniciarInstancia(modo)
  for _, fac in ipairs({ "albor", "umbra" }) do
    for _, e in ipairs(lista[fac]) do
      self:meterEnCampo(e, modo)
    end
  end
  self:avisoEvento("mundo", "", self:nombreEvento(modo) .. " empieza. Albor y Umbra entran al campo.", nil)
  return true
end

function Mundo:entrarGuerra(p, modo)
  if modo ~= "batalla" and modo ~= "estandarte" and modo ~= "moba" then return "Ese evento no existe." end
  if modo == "moba" and not self:asegurarArenaMoba() then return "El asedio no está disponible (no hay mapa)." end
  if not p.vivo then return "No puedes entrar así." end
  if p.kind ~= "jugador" then return "Los eventos se juegan entre jugadores." end
  if p.modo == modo then return "Ya estás dentro." end
  if p.colaGuerra == modo then return "Ya estás en la cola." end
  if p.colaGuerra and p.colaGuerra ~= modo then return "Sal de la otra cola antes de apuntarte." end
  -- todos pueden participar en cada evento, las veces que haga falta (sin límite por edición)
  if (p.ultimoGolpe or 0) + 4 > self.tiempo and p.modo == "mundo" then
    return "Sal del combate antes de entrar."
  end
  local inst = self.instancia[modo]
  if inst.activa and not inst.fin then
    self:anunciar(p.nombre .. " (" .. (p.faccion == "albor" and "Albor" or "Umbra") .. ") se une a " .. self:nombreEvento(modo) .. ", que ya está en marcha.")
    self:meterEnCampo(p, modo)
    return nil
  end
  p.colaGuerra = modo
  local n = self:contarCola(modo)
  local min = self:minimoEvento(modo)
  local programa = self:programaDe(modo)
  self:anunciar(string.format("%s (%s) se anota a %s. Albor %d/%d · Umbra %d/%d.", p.nombre,
    p.faccion == "albor" and "Albor" or "Umbra", self:nombreEvento(modo), n.albor, min, n.umbra, min))
  if programa then
    -- el servidor lo lanza a su hora: aquí solo queda inscrito
    self:mensaje("sistema", "", string.format("Quedas inscrito en %s: empieza a las %s si hay %d jugadores por corona (ahora Albor %d, Umbra %d).",
      self:nombreEvento(modo), programa.hora, min, n.albor, n.umbra), p)
    return nil
  end
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

-- Apunta una línea en el registro del evento (las últimas se ven en pantalla): texto y equipo al que pertenece (para el color).
function Mundo:registrarEvento(modo, texto, faccion)
  local inst = self.instancia[modo]
  if not inst then return end
  inst.registro = inst.registro or {}
  inst.registro[#inst.registro + 1] = { t = math.floor(inst.tiempo), texto = texto, faccion = faccion }
  while #inst.registro > 6 do table.remove(inst.registro, 1) end
end

-- Cuenta una acción en las estadísticas del jugador dentro del evento (bajas, muertes, esbirros, torres).
function Mundo:contarEvento(p, que)
  if p and p.eventoStats then p.eventoStats[que] = (p.eventoStats[que] or 0) + 1 end
end

function Mundo:reiniciarInstancia(modo)
  local inst = self.instancia[modo]
  inst.tiempo = 0
  inst.puntos = { albor = 0, umbra = 0 }
  inst.bajas = { albor = 0, umbra = 0 }
  inst.cristales = { albor = 0, umbra = 0 }
  inst.registro = {}
  inst.edicion = (inst.edicion or 0) + 1
  inst.fin = nil
  inst.activa = true
  if modo == "batalla" then
    for id, e in pairs(self.entidades) do
      if e.modo == "batalla" and (e.kind == "estatua" or e.kind == "puerta" or e.kind == "altar") then
        e.vivo = true
        e.hp = e.hpMax
      elseif e.kind == "cristal" then
        self.entidades[id] = nil
      end
      if e.llevaCristales then e.llevaCristales = nil end
    end
    if self.mapas.batalla.puerta then
      for _, puerta in pairs(self.mapas.batalla.puerta) do
        puerta.viva = true
        self.mapas.batalla.bloque[puerta.x][puerta.y] = true
      end
    end
  end
  if modo == "moba" then self:armarMoba() end
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
  local titulo = modo == "batalla" and "La batalla por cristales" or (modo == "moba" and "El asedio" or "Captura el estandarte")
  self:avisoEvento("mundo", "", titulo .. " termina. Victoria: " .. (ganador == "albor" and "Albor" or ganador == "umbra" and "Umbra" or "nadie") .. ".", nil)
  if ganador == "albor" or ganador == "umbra" then
    self.gloria[ganador] = self.gloria[ganador] + 40
  end
  for _, e in pairs(self.entidades) do
    if e.modo == modo and (e.kind == "jugador" or e.kind == "bot") then
      local gano = e.faccion == ganador
      local oro = gano and (modo == "estandarte" and 1000 or 220) or 70
      local xp = gano and 280 or 90
      if e.kind == "jugador" then
        -- los cristales sin entregar valen algo de oro
        oro = oro + (e.llevaCristales or 0) * 100
        e.llevaCristales = nil
        for i = #e.bolsa, 1, -1 do
          if e.bolsa[i].id == "cristal" then
            oro = oro + e.bolsa[i].cant * 15
            table.remove(e.bolsa, i)
          end
        end
        e.oro = e.oro + oro
        self:ganarXp(e, xp)
        -- premios del evento: material de encantamiento y un pergamino de atributos al azar
        local polvo = gano and math.random(8, 12) or math.random(2, 4)
        local premios = { polvo .. " de polvo arcano" }
        if not self:darItem(e, "polvo_arcano", polvo) then premios[1] = "polvo arcano (bolsa llena)" end
        if gano or math.random() < 0.4 then
          local ids = {}
          for _, o in ipairs(Mall.OBJETOS) do
            if o.id:sub(1, 10) == "pergamino_" then ids[#ids + 1] = o.id end
          end
          local id = ids[math.random(#ids)]
          local def = Datos.item(id)
          if self:darItem(e, id, 1) then premios[#premios + 1] = def.nombre
          else premios[#premios + 1] = def.nombre .. " (bolsa llena, se pierde)" end
        end
        -- los eventos dan también Monedas Corona del Item Mall: 5 al ganar y 2 al perder
        local monedas = gano and 5 or 2
        e.monedas = (e.monedas or 0) + monedas
        premios[#premios + 1] = monedas .. " Monedas Corona"
        self:marcarProgreso(e)
        self:mensaje("sistema", "", (gano and "Victoria" or "Derrota") .. ". +" .. oro .. " de oro, " .. table.concat(premios, " y ") .. ".", e)
        self.mensajes[#self.mensajes].marquesina = true
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
  if modo == "moba" then
    for _, e in pairs(self.entidades) do if e.mobaOrig then self:restaurarMoba(e) end end       -- cada uno recupera su nivel, su experiencia y sus poderes
    self:limpiarMoba()
  end
end

function Mundo:salirGuerra(p)
  if p.colaGuerra and p.modo ~= "batalla" and p.modo ~= "estandarte" and p.modo ~= "moba" then
    local nombre = self:nombreEvento(p.colaGuerra)
    p.colaGuerra = nil
    self:mensaje("sistema", "", "Sales de la cola de " .. nombre .. ".", p)
    return
  end
  if p.modo ~= "batalla" and p.modo ~= "estandarte" and p.modo ~= "moba" then return end
  local ret = p.retorno
  p.modo = "mundo"
  if ret then p.x, p.y = ret.x, ret.y end
  p.llevaBandera = nil
  self:restaurarMoba(p)
  self:mensaje("sistema", "", "Abandonas el campo.", p)
end

-- Pergamino de teletransporte: te lleva al sitio donde renaces (la estatua que guardaste o, si no, la ciudad propia más cercana).
function Mundo:usarPergamino(p, index)
  local slot = p.bolsa[index]
  if not slot then return "No hay objeto." end
  if not p.vivo then return "No puedes actuar." end
  if p.modo ~= "mundo" or (p.z or 0) > 0 then return "Aquí no funciona: sal primero al mundo." end
  if self:enMazmorra(p) or self:enMapaFao(p) then return "Aquí no funciona: sal primero de la mazmorra." end
  if (p.ultimoGolpe or 0) + 6 > self.tiempo then return "No se puede usar en combate." end
  if (p.cds.pergamino or 0) > self.tiempo then return "El pergamino aún se enfría." end
  local v = p.vinculo or {}
  local c
  if v.ciudad then
    for _, cc in ipairs(self.mapas.mundo.ciudades) do
      if cc.id == v.ciudad and cc.faccion == p.faccion and cc.spawn then c = cc end
    end
  end
  c = c or self:ciudadPropiaCerca(p, p.x, p.y)
  if not c or not c.spawn then return "No hay adónde ir." end
  self:efecto("nivel", p.x, p.y, 0.7)
  self:sonar("cura", p)
  p.x, p.y = c.spawn.x, c.spawn.y
  p.camino, p.tramo, p.objetivo, p.persigue = nil, nil, nil, nil
  p.cds.pergamino = self.tiempo + 30
  slot.cant = (slot.cant or 1) - 1
  if slot.cant <= 0 then table.remove(p.bolsa, index) end
  self:efecto("nivel", p.x, p.y, 0.7)
  self:sonar("cura", p)
  self:marcarProgreso(p)
  self:mensaje("sistema", "", "El pergamino se deshace y apareces en " .. c.nombre .. ".", p)
  return nil
end

function Mundo:equipar(p, index)
  self:marcarProgreso(p)
  local slot = p.bolsa[index]
  if not slot then return "No hay objeto." end
  local it = Datos.item(slot.id)
  if not it or not it.hueco then
    if it and it.bono then return self:usarBono(p, index) end
    if it and (it.cura or it.mana) then return self:usarPocionId(p, slot.id) end
    if it and it.teletransporte then return self:usarPergamino(p, index) end
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
    self:sonar("magia", p)
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
  if ((p.cdPociones or {})[id] or 0) > self.tiempo then return "La poción aún no." end
  local it = Datos.item(id)
  if not it or not (it.cura or it.mana) then return "No tienes esa poción." end
  if it.nivel and (p.nivel or 1) < it.nivel then return "Necesitas nivel " .. it.nivel .. "." end
  local idx
  for i, s in ipairs(p.bolsa) do if s.id == id then idx = i break end end
  if not idx then return "No tienes esa poción." end
  local function tirada(minimo, maximo)
    minimo = math.floor(tonumber(minimo) or 0)
    maximo = math.floor(tonumber(maximo) or minimo)
    if maximo < minimo then minimo, maximo = maximo, minimo end
    if minimo >= maximo then return minimo end
    return math.random(minimo, maximo)
  end
  if it.cura then p.hp = math.min(p.hpMax, p.hp + tirada(it.cura, it.curaMax)) end
  if it.mana then p.mp = math.min(p.mpMax, p.mp + tirada(it.mana, it.manaMax)) end
  p.bolsa[idx].cant = p.bolsa[idx].cant - 1
  if p.bolsa[idx].cant <= 0 then table.remove(p.bolsa, idx) end
  p.cdPociones = p.cdPociones or {}
  p.cdPociones[id] = self.tiempo + Mundo.POCION_CD
  return nil
end

-- Bebe la poción de vida o la de maná si el jugador la dejó encendida y está por debajo de su umbral.
-- Cada poción tiene su enfriamiento: la de vida y la de maná pueden beberse a la vez.
-- Si no hay poción o aún está el enfriamiento, no dice nada: se reintenta en el siguiente paso.
function Mundo:beberAutopocion(p)
  local function intentar(id, on, umbral, campo, color)
    if not on then return false end
    local maximo = p[campo .. "Max"]
    if not maximo or maximo <= 0 then return false end
    if p[campo] / maximo > (umbral or Mundo.AUTOPOCION_UMBRAL) then return false end
    local antes = p[campo]
    if self:usarPocionId(p, id) then return false end
    local ganada = math.floor(p[campo] - antes)
    if ganada > 0 then self:numero(p, "+" .. ganada, color) end
    return true
  end
  local idVida = Datos.elegirPocion(p.bolsa, p.nivel, "vida")
  local idMana = Datos.elegirPocion(p.bolsa, p.nivel, "mana")
  if idVida then intentar(idVida, p.autoPocion, p.autoPocionUmbral, "hp", { 0.45, 1, 0.5 }) end
  if idMana then intentar(idMana, p.autoMana, p.autoManaUmbral, "mp", { 0.55, 0.75, 1 }) end
end

function Mundo:configurarAutopocion(p, datos)
  datos = datos or {}
  local mana = datos.cual == "mana"
  local on = datos.on and true or false
  local claveOn = mana and "autoMana" or "autoPocion"
  local claveUmbral = mana and "autoManaUmbral" or "autoPocionUmbral"
  local umbral = datos.umbral or p[claveUmbral] or Mundo.AUTOPOCION_UMBRAL
  local cambio = on ~= (p[claveOn] and true or false) or math.abs(umbral - (p[claveUmbral] or Mundo.AUTOPOCION_UMBRAL)) > 0.001
  p[claveOn] = on
  p[claveUmbral] = umbral
  if not cambio then return end
  local pct = math.floor(umbral * 100 + 0.5)
  local nombre = mana and "maná" or "vida"
  self:mensaje("sistema", "", on
    and ("Autopoción de " .. nombre .. " activada: al bajar del " .. pct .. "%.")
    or ("Autopoción de " .. nombre .. " desactivada. El umbral queda en " .. pct .. "%."), p)
  self:marcarProgreso(p)
end

-- Quién vende cada cosa: la enfermera, las pociones; cada maestro, el equipo de su clase (y lo que no es de ninguna clase, todos).
function Mundo:puestoDe(it)
  if it.hueco == "arma" or it.hueco == "cabeza" or it.hueco == "pecho" or it.hueco == "piernas" or it.hueco == "pies"
    or it.hueco == "escudo" or it.hueco == "anillo" or it.hueco == "amuleto" or it.hueco == "mochila" then
    return it.clase and ("maestro_" .. it.clase) or "maestro"
  end
  if (it.cura or it.mana or it.teletransporte) and not it.hueco then return "mercado" end
end

-- ¿El maestro más cercano (a la vista) es de esa clase, o de cualquiera si no se da clase? Los maestros están en fila y varios caen a la
-- vista a la vez: se compra al que tienes al lado.
function Mundo:maestroCerca(p, clase)
  local mejor, md = nil, 4
  for _, e in pairs(self.entidades) do
    if e.kind == "npc" and e.rol and e.rol:sub(1, 8) == "maestro_" and self:mismoLugar(p, e) then
      local d = Util.dist(p.x, p.y, e.x, e.y)
      if d <= md then mejor, md = e, d end
    end
  end
  if not mejor then return false end
  return clase == nil or mejor.rol == "maestro_" .. clase
end

function Mundo:comprar(p, itemId)
  self:marcarProgreso(p)
  local it = Datos.item(itemId)
  if not it or it.quest or it.mall then return "No está a la venta." end
  if (it.cura or it.mana) and it.nivel and (p.nivel or 1) < it.nivel then return "Necesitas nivel " .. it.nivel .. "." end
  local puesto = self:puestoDe(it)
  if puesto == "mercado" and not self:npcCerca(p, "mercado") then return "Las pociones se compran a la enfermera." end
  if puesto == "maestro" and not self:maestroCerca(p) then return "Eso se compra a un maestro." end
  if puesto and puesto:sub(1, 8) == "maestro_" and not self:maestroCerca(p, it.clase) then
    return "Eso lo vende el maestro de su clase."
  end
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
  if not it or (it.quest and not it.vendible) or it.mall then return "No se puede vender." end
  local cant = slot.cant or 1
  p.oro = p.oro + math.floor((it.precio or 1) * Datos.FACTOR_VENTA) * cant
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

function Mundo:precioDeCasa(parcela)
  local t = parcela and parcela.tamano or "mediana"
  local tabla = Datos.precioCasa or {}
  return tabla[t] or tabla.mediana or 75000
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
  local precio = self:precioDeCasa(parcela)
  if p.oro < precio then return "Necesitas " .. precio .. " de oro." end
  p.oro = p.oro - precio
  parcela.dueno = p.id
  p.casas[parcelaId] = { muebles = {}, cofre = {}, tamano = parcela.tamano or "mediana" }
  local nombreTam = ({ pequena = "pequeña", mediana = "mediana", grande = "grande" })[parcela.tamano or "mediana"]
  self:mensaje("sistema", "", "La casa " .. nombreTam .. " de " .. ciudad.nombre .. " es tuya.", p)
  return nil
end

function Mundo:entrarCasa(p, parcelaId)
  local parcela, ciudad
  for _, c in ipairs(self.mapas.mundo.ciudades) do
    for _, par in ipairs(c.parcelas) do
      if par.id == parcelaId then parcela, ciudad = par, c end
    end
  end
  if not parcela or parcela.dueno ~= p.id or not (p.casas and p.casas[parcelaId]) then return "No es tu casa." end
  if p.modo ~= "mundo" and p.modo ~= "casa" then return "Aquí no puedes entrar en casa." end
  local enPuerta = Util.dist(p.x, p.y, parcela.x + 0.5, parcela.y + 0.5) <= 2.2
  local enMayordomo = self:npcCerca(p, "mayordomo") and self:ciudadEn(p.x, p.y) == ciudad
  if p.modo == "mundo" and not enPuerta and not enMayordomo then
    return "Acércate a la puerta o habla con el mayordomo."
  end
  local casa = p.casas[parcelaId]
  casa.tamano = casa.tamano or parcela.tamano or "grande"
  p.retorno = { x = parcela.x + 0.5, y = parcela.y + 1.4, modo = "mundo", z = p.z or 0 }
  p.modo = "casa"
  p.z = 0
  p.zona = "Tu casa"
  p.casaId = parcelaId
  p.casaTamano = casa.tamano
  p.x, p.y = self:interior(p).salida.x, self:interior(p).salida.y
  p.camino, p.deseoX, p.deseoY = nil, 0, 0
  return nil
end

function Mundo:salirCasa(p)
  if p.modo ~= "casa" then return end
  local r = p.retorno or p.vinculo
  p.modo = (r and r.modo) or "mundo"
  p.x, p.y = r.x, r.y
  if r.z then p.z = r.z end
  p.casaId = nil
  p.casaTamano = nil
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
  local def = self:interior(p).muebles[tipo]
  casa.muebles[tipo] = { x = def.x, y = def.y, rot = 0 }
  return nil
end

-- Posición del mueble colocado. `true` (casas antiguas) usa el sitio por defecto.
function Mundo:posMueble(casa, tipo)
  local base = self:interior(casa).muebles[tipo]
  local v = casa and casa.muebles and casa.muebles[tipo]
  if not base or not v then return nil end
  if type(v) == "table" then return v.x or base.x, v.y or base.y, (v.rot or 0) % 4 end
  return base.x, base.y, 0
end

function Mundo:sitioMueble(x, y, tamano)
  local mapa = self:interior({ casaTamano = tamano })
  local tx, ty = math.floor(x), math.floor(y)
  if tx < 1 or ty < 1 or tx > mapa.w - 2 or ty > mapa.h - 2 then return nil end
  local puerta = mapa.puerta
  if puerta and math.floor(puerta.x) == tx and math.floor(puerta.y) == ty then return nil end
  return tx + 0.5, ty + 0.5
end

function Mundo:moverMueble(p, tipo, x, y)
  self:marcarProgreso(p)
  local casa = p.casaId and p.casas and p.casas[p.casaId]
  if not casa or not casa.muebles[tipo] then return "Ese mueble no está colocado." end
  if not Datos.muebles[tipo] then return end
  local nx, ny = self:sitioMueble(x, y, casa.tamano or p.casaTamano)
  if not nx then return "Ahí no cabe." end
  for otro in pairs(casa.muebles) do
    if otro ~= tipo then
      local ox, oy = self:posMueble(casa, otro)
      if ox and math.abs(ox - nx) < 0.2 and math.abs(oy - ny) < 0.2 then return "Ahí ya hay un mueble." end
    end
  end
  local _, _, rot = self:posMueble(casa, tipo)
  casa.muebles[tipo] = { x = nx, y = ny, rot = rot or 0 }
  return nil
end

function Mundo:rotarMueble(p, tipo)
  self:marcarProgreso(p)
  local casa = p.casaId and p.casas and p.casas[p.casaId]
  if not casa or not casa.muebles[tipo] then return "Ese mueble no está colocado." end
  if not Datos.muebles[tipo] then return end
  local x, y, rot = self:posMueble(casa, tipo)
  if not x then return end
  casa.muebles[tipo] = { x = x, y = y, rot = ((rot or 0) + 1) % 4 }
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

-- ¿Está el jugador junto al PNJ de misiones con ese id (c_<ciudad> o p<puesto>)?
function Mundo:npcQuestCerca(p, qid)
  if not qid then return false end
  for _, e in pairs(self.entidades) do
    if e.kind == "npc" and e.qid == qid and self:mismoLugar(p, e) and Util.dist(p.x, p.y, e.x, e.y) <= Misiones.DISTANCIA_PNJ then return true end
  end
  return false
end

-- Acepta una misión (junto a quien la da). Devuelve el motivo si no puede.
function Mundo:aceptarMision(p, id)
  self:marcarProgreso(p)
  if type(id) ~= "string" then return "Esa misión no existe." end
  local q = Misiones.por_id[id]
  if not q then return "Esa misión no existe." end
  local st = p.misiones[id]
  if st and (st.aceptada or st.entregada) then return "Ya la tienes." end
  if not self:npcQuestCerca(p, q.npc) then return "Acércate a " .. Misiones.nombreNpc(q.npc) .. "." end
  local motivo = Misiones.puedeAceptar(p, q)
  if motivo then return motivo end
  local activas = 0
  for mid, s in pairs(p.misiones) do if s.aceptada and not s.entregada and Misiones.por_id[mid] then activas = activas + 1 end end
  if activas >= Misiones.MAX_ACTIVAS then return "Ya llevas " .. Misiones.MAX_ACTIVAS .. " misiones: entrega o abandona alguna." end
  if q.tipo == "entregar" then
    if not self:darItem(p, q.item, 1) then return "Libera un espacio en la bolsa para llevar el encargo." end
  end
  p.misiones[id] = { aceptada = true, entregada = false, progreso = 0 }
  self:mensaje("sistema", "", "Aceptas: " .. q.titulo, p)
  self:marcarProgreso(p)
  return nil
end

-- Entrega una misión cumplida (junto a quien la recibe): recompensas de oro, experiencia, objetos, addon, montura y monedas.
function Mundo:entregarMision(p, id)
  self:marcarProgreso(p)
  if type(id) ~= "string" then return "Nada que entregar." end
  local q = Misiones.por_id[id]
  local st = p.misiones[id]
  if not q or not st or not st.aceptada or st.entregada then return "Nada que entregar." end
  if not self:npcQuestCerca(p, q.destino) then return "Acércate a " .. Misiones.nombreNpc(q.destino) .. "." end
  if not Misiones.completa(p, q, st) then return "Aún no está completo." end
  local premios = q.premios or {}
  local necesita = 0
  for _, pr in ipairs(premios) do necesita = necesita + 1 end
  local libres = Datos.capacidadBolsa(p.equipo) - #p.bolsa
  -- las entregas y los trofeos que se gastan dejan sitio
  if q.tipo ~= "cazar" then libres = libres + 1 end
  if necesita > libres then return "Libera " .. (necesita - libres) .. " espacio(s) en la bolsa para recibir el premio." end
  if q.tipo == "recolectar" or q.tipo == "entregar" then self:gastarItem(p, q.item, q.cantidad) end
  st.entregada = true
  st.aceptada = false
  local xp = Misiones.xpFinal(p, q)
  p.oro = (p.oro or 0) + (q.oro or 0)
  self:ganarXp(p, xp)
  local texto = "Misión entregada: " .. q.titulo .. ". +" .. (q.oro or 0) .. " de oro, +" .. xp .. " de experiencia."
  for _, pr in ipairs(premios) do
    if self:darItem(p, pr.id, pr.cant) then
      local def = Datos.item(pr.id)
      texto = texto .. " " .. pr.cant .. " " .. (def and def.nombre or pr.id) .. "."
    end
  end
  if q.monedas and q.monedas > 0 then
    p.monedas = (p.monedas or 0) + q.monedas
    texto = texto .. " " .. q.monedas .. " " .. Mall.MONEDA .. "."
  end
  self:mensaje("sistema", "", texto, p)
  if q.addon and Mall.ADDONS[q.addon] then
    p.addons = p.addons or {}
    if not p.addons[q.addon] then
      p.addons[q.addon] = true
      self:mensaje("sistema", "", "¡Recibes el addon " .. Mall.ADDONS[q.addon].nombre .. "!", p)
    end
  end
  if q.montura and Monturas.especies[q.montura] then
    p.monturas = p.monturas or {}
    local tiene = false
    for _, m in ipairs(p.monturas) do if m == q.montura then tiene = true end end
    if not tiene then
      p.monturas[#p.monturas + 1] = q.montura
      self:mensaje("sistema", "", "¡Recibes la montura " .. (Monturas.especies[q.montura].nombre or q.montura) .. "!", p)
    end
  end
  -- siguiente paso de la cadena, si lo da el mismo PNJ que tienes delante
  local sig = q.siguiente and Misiones.por_id[q.siguiente]
  if sig and self:npcQuestCerca(p, sig.npc) and not (p.misiones[sig.id] and (p.misiones[sig.id].aceptada or p.misiones[sig.id].entregada)) then
    local err = self:aceptarMision(p, sig.id)
    if err then self:mensaje("sistema", "", "Siguiente paso de la cadena: " .. err, p) end
  end
  self:sonar("magia", p)
  return nil
end

-- Abandona una misión en curso (se pierde el avance y los objetos del encargo).
function Mundo:abandonarMision(p, id)
  if type(id) ~= "string" then return "Nada que abandonar." end
  local q = Misiones.por_id[id]
  local st = p.misiones[id]
  if not st or not st.aceptada or st.entregada then return "Nada que abandonar." end
  if q and (q.tipo == "recolectar" or q.tipo == "entregar") and q.item then
    self:gastarItem(p, q.item, Misiones.contar(p, q.item))
  end
  p.misiones[id] = nil
  self:mensaje("sistema", "", "Abandonas: " .. (q and q.titulo or id), p)
  self:marcarProgreso(p)
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
  if self:enMazmorra(p) then return self:interactuarMazmorra(p) end
  if p.modo == "casa" then
    local puerta = self:interior(p).puerta
    if puerta and Util.dist(p.x, p.y, puerta.x, puerta.y) < 1.45 then
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
  -- una caravana a la vista: un cazarrecompensas se ofrece a escoltarla
  for _, e in pairs(self.entidades) do
    if e.kind == "caravana" and e.vivo and self:mismoLugar(p, e) and Util.dist(p.x, p.y, e.x, e.y) < 3 then
      if p.job == "hunter" then
        local err = self:escoltarCaravana(p, e.id)
        if err then self:mensaje("sistema", "", err, p) end
      else
        self:mensaje("sistema", "", e.nombre .. " va a " .. e.nombreDestino .. ". Solo los cazarrecompensas la escoltan.", p)
      end
      return { panel = nil }
    end
  end
  -- la estatua de la plaza de la ciudad propia: ahí se guarda dónde renacer
  if p.modo == "mundo" then
    for _, c in ipairs(self.mapas.mundo.ciudades) do
      for _, pr in ipairs(self.mapas.mundo.props) do
        if pr.tipo == "estatua_" .. c.faccion and self:ciudadEn(pr.x, pr.y) == c and Util.dist(p.x, p.y, pr.x + 0.5, pr.y + 0.5) <= 2.2 then
          if c.faccion ~= p.faccion then
            self:mensaje("sistema", "", "Esta estatua no es la de tu reino.", p)
          elseif p.vinculo and p.vinculo.ciudad == c.id then
            self:mensaje("sistema", "", "Ya renaces en " .. c.nombre .. ".", p)
          else
            p.vinculo = { x = c.spawn.x, y = c.spawn.y, modo = "mundo", ciudad = c.id }
            self:marcarProgreso(p)
            self:mensaje("sistema", "", "Tu alma queda ligada a la estatua de " .. c.nombre .. ": aquí renacerás.", p)
          end
          return { panel = nil }
        end
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
    if mejor.rol == "mercado" then return { panel = "mercado", tienda = "mercado" } end
    if mejor.rol:sub(1, 8) == "maestro_" then return { panel = "mercado", tienda = mejor.rol } end
    if mejor.rol == "heraldo" then return { panel = "guerra" } end
    if mejor.rol == "barquero" then return { panel = "viaje" } end
    if mejor.rol == "encantador" then return { panel = "encantar" } end
    if mejor.rol == "oficios" or mejor.rol == "capitan" or mejor.rol == "contacto" then return { panel = "oficios" } end
    if mejor.rol == "comercio" then return { panel = "mercancias" } end
    if mejor.rol == "establo" then return { panel = "establo" } end
    if mejor.rol == "subastas" then return { panel = "subastas" } end
    if mejor.rol == "criador" then return { panel = "mascotas" } end
    if mejor.rol == "gremio" then return { panel = "gremio" } end
    if mejor.rol == "mayordomo" then return { panel = "vivienda", ciudad = self:ciudadEn(p.x, p.y) and self:ciudadEn(p.x, p.y).id } end
    if mejor.rol == "encargos" or mejor.rol == "misiones" then
      local cid = self:ciudadEn(p.x, p.y)
      cid = cid and cid.id
      if mejor.qid then
        for _, q in ipairs(Misiones.porNpc[mejor.qid] or {}) do
          local est = Misiones.estado(p, q)
          if est == "activa" and q.dialogo then
            self:mensaje("local", mejor.nombre, q.dialogo, mejor)
          end
        end
      end
      return { panel = "misiones", ciudad = cid, npc = mejor.qid }
    end
    if mejor.rol == "aldeano" then
      local frases = {
        "Buen día, viajero. La ciudad está tranquila.", "Dicen que más allá de las murallas hay criaturas muy fuertes.",
        "Si buscas casa, habla con el mayordomo.", "El pan de esta ciudad es el mejor del reino.",
        "Cuida tu montura: en el camino hay ladrones.", "Yo solo quiero paz y una buena cosecha.",
      }
      self:mensaje("local", mejor.nombre, frases[math.random(#frases)], mejor)
      return { panel = nil }
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
  if p.modo == "mundo" then
    local r = self:interactuarPuertaMazmorra(p)
    if r then return r end
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
  if self.pulsos and #self.pulsos > 0 then
    -- golpes diferidos de los poderes de varios impactos (torbellino arcano)
    local resto = {}
    for _, q in ipairs(self.pulsos) do
      if q.t > self.tiempo then resto[#resto + 1] = q
      elseif q.p.vivo then
        for _, o in pairs(self.entidades) do
          if o.vivo and self:mismoLugar(q.p, o) and self:puedeDanar(q.p, o) and Util.dist(q.x, q.y, o.x, o.y) <= (q.h.aoe or 2) then
            self:golpear(q.p, o, q.h.coef, nil, q.h.dano or "fisico")
            if o.vivo and q.h.lentitud then self:aplicarEstado(o, "lentitud", 3, q.h.lentitud, q.p) end
          end
        end
      end
    end
    self.pulsos = resto
  end
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
  -- criaturas dormidas: las que no tienen ningun jugador cerca se actualizan una vez por segundo
  local vivos = self._pos
  if not vivos then vivos = {} self._pos = vivos end
  local nv = 0
  for i = 1, n do
    local o = self.entidades[ids[i]]
    if o and (o.kind == "jugador" or o.kind == "bot") and not o.borrar then
      nv = nv + 1
      local t = vivos[nv]
      if not t then t = {} vivos[nv] = t end
      t.x, t.y, t.modo, t.z = o.x, o.y, o.modo, o.z or 0
    end
  end
  for i = nv + 1, #vivos do vivos[i] = nil end
  local celdas = {}
  for i = 1, n do
    local o = self.entidades[ids[i]]
    if o and not o.borrar and o.vivo ~= false and ocupa(o.kind) and o.x then
      local k = math.floor(o.x / 8) * 4096 + math.floor(o.y / 8)
      local l = celdas[k]
      if not l then l = {} celdas[k] = l end
      l[#l + 1] = o
    end
  end
  self._celdas = celdas
  local objs = self._objMon
  if not objs then objs = {} self._objMon = objs end
  local no = 0
  for i = 1, n do
    local o = self.entidades[ids[i]]
    if o and o.vivo and not o.borrar and (o.kind == "jugador" or o.kind == "bot" or o.kind == "guardia" or o.kind == "caravana") then
      no = no + 1
      objs[no] = o
    end
  end
  for i = no + 1, #objs do objs[i] = nil end
  local DISTANCIA_DESPIERTA2 = Mundo.DISTANCIA_DESPIERTA * Mundo.DISTANCIA_DESPIERTA
  for i = 1, n do
    local id = ids[i]
    local e = self.entidades[id]
    if e and not e.borrar then
      if e.kind == "jugador" then self:actualizarJugador(e, dt)
      elseif e.kind == "bot" then
        if e.ia then self:pensarBot(e, dt) end
        self:actualizarJugador(e, dt)
      elseif e.kind == "monstruo" then
        local cerca = false
        for k = 1, nv do
          local t = vivos[k]
          if t.modo == e.modo then
            local dx, dy = t.x - e.x, t.y - e.y
            if dx * dx + dy * dy < DISTANCIA_DESPIERTA2 then cerca = true break end
          end
        end
        if cerca or e.objetivo then
          self:actualizarMonstruo(e, (e._dormido or 0) + dt)
          e._dormido = nil
        else
          e._dormido = (e._dormido or 0) + dt
          if e._dormido >= 1 then
            self:actualizarMonstruo(e, e._dormido)
            e._dormido = 0
          end
        end
      elseif e.kind == "guardia" then self:actualizarGuardia(e, dt)
      elseif e.kind == "npc" then self:patrullar(e, dt)
      elseif e.kind == "proyectil" then self:actualizarProyectil(e, dt)
      elseif e.kind == "trampa" then self:actualizarTrampa(e, dt)
      elseif e.kind == "mascota" then self:actualizarMascota(e, dt)
      elseif e.kind == "esbirro" then self:actualizarEsbirro(e, dt)
      elseif e.kind == "caravana" then self:actualizarCaravana(e, dt)
      elseif e.kind == "bandera" then self:actualizarBandera(e)
      elseif (e.kind == "loot" or e.kind == "cuerpo" or e.kind == "cristal" or e.kind == "cofre_mz") and self.tiempo > (e.hasta or 0) then e.borrar = true
      elseif e.kind == "altar" and not e.vivo and e.respawn and self.tiempo >= e.respawn then
        -- el núcleo se regenera pasado un tiempo
        e.vivo, e.hp, e.respawn = true, e.hpMax, nil
        self:avisoEvento("mundo", "", e.nombre .. " se ha regenerado.", nil)
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
  self:actualizarCaravanas(dt)
  self:actualizarSubastas(dt)
  self:actualizarProgramacion(dt)
  self:actualizarGrupos(dt)
  self:actualizarBonos(dt)
  self:actualizarComercio(dt)
  self:actualizarMonturas(dt)
  self:actualizarEncuentros(dt)
  self._presionT = (self._presionT or 0) + dt
  if self._presionT >= 5 then
    self:recuperarPresion(self._presionT)
    self._presionT = 0
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
  self:actualizarMoba(dt)
  for _, modo in ipairs({ "batalla", "estandarte", "moba" }) do
    local inst = self.instancia[modo]
    if inst.activa and not inst.fin then
      inst.tiempo = inst.tiempo + dt
      -- la batalla se gana entregando 5 cristales (al entregarlos) y el estandarte con 3 capturas (al capturar); el asedio, destruyendo el nexo. Aquí solo se vigila el tiempo
      local limite = modo == "estandarte" and 3 or 1e9
      if inst.puntos.albor >= limite then self:cerrarInstancia(modo, "albor")
      elseif inst.puntos.umbra >= limite then self:cerrarInstancia(modo, "umbra")
      elseif inst.tiempo >= inst.duracion then
        local g = "empate"
        local a, u = inst.puntos.albor, inst.puntos.umbra
        if modo == "batalla" and inst.cristales and (inst.cristales.albor ~= inst.cristales.umbra) then a, u = inst.cristales.albor, inst.cristales.umbra end        -- primero los cristales, luego los puntos
        if a > u then g = "albor" elseif u > a then g = "umbra" end
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
    nivel = p.mobaOrig and p.mobaOrig.nivel or p.nivel, xp = p.mobaOrig and p.mobaOrig.xp or p.xp, oro = p.oro,          -- (dentro del asedio se guarda lo real, no lo de la partida)
    x = x, y = y, modo = "mundo",
    equipo = p.equipo, bolsa = p.bolsa, misiones = misiones,
    casas = p.casas, vinculo = p.vinculo, caceria = p.caceria,
    habilidades = p.mobaOrig and p.mobaOrig.habilidades or p.habilidades, encantos = p.encantos,
    mascotas = p.mascotas, mascotaActiva = p.mascotaActiva,
    job = p.oficioElegido, oficios = p.oficios, carga = p.carga, cargaRobada = p.cargaRobada,
    monturas = p.monturas, monturaPreferida = p.monturaPreferida, diaria = p.diaria,
    autoPocion = p.autoPocion and true or false,
    autoPocionUmbral = p.autoPocionUmbral or Mundo.AUTOPOCION_UMBRAL,
    autoMana = p.autoMana and true or false,
    autoManaUmbral = p.autoManaUmbral or Mundo.AUTOPOCION_UMBRAL,
    monedas = p.monedas, regaloMall = p.regaloMall, addons = p.addons, addonActivo = p.addonActivo, bonos = p.bonos,
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
  p.oficioElegido, p.oficios = data.job, data.oficios or {}
  p.carga, p.cargaRobada = data.carga or {}, data.cargaRobada or {}
  -- el oficio empieza desactivado; si traes carga, sigue activo para poder venderla
  p.job = nil
  if p.oficioElegido and self:pesoCarga(p) > 0 then p.job = p.oficioElegido end
  p.monturas, p.monturaPreferida = data.monturas or {}, data.monturaPreferida
  p.diaria = type(data.diaria) == "table" and data.diaria or nil
  p.autoPocion = data.autoPocion and true or false
  p.autoMana = data.autoMana and true or false
  local function umbralGuardado(v)
    v = tonumber(v)
    if v and v >= 0.2 and v <= 0.9 then return v end
    return Mundo.AUTOPOCION_UMBRAL
  end
  p.autoPocionUmbral = umbralGuardado(data.autoPocionUmbral)
  p.autoManaUmbral = umbralGuardado(data.autoManaUmbral)
  -- item mall: monedas, addons y bonos (los ya terminados se descartan)
  -- las monedas iniciales del mall se dan UNA vez a cada personaje (nuevo o ya existente)
  p.monedas = data.monedas or 0
  if not data.regaloMall then p.monedas = p.monedas + Mall.MONEDAS_INICIALES end
  p.regaloMall = true
  p.addons, p.addonActivo = data.addons or {}, data.addonActivo
  if p.addonActivo and not p.addons[p.addonActivo] then p.addonActivo = nil end
  p.bonos = {}
  for bono, fin in pairs(data.bonos or {}) do
    if tonumber(fin) and tonumber(fin) > self:reloj() then p.bonos[bono] = tonumber(fin) end
  end
  self:recalcularCarga(p)
  -- equipo retirado al igualar los objetos con lo que puede llevar cada clase (arte FAO): las armas secundarias pasan a ser el arma
  -- principal de su oficio y el escudo del clérigo se devuelve en oro (al precio del escudo del guerrero)
  do
    local RETIRADAS = { ballesta = true, alabarda = true, vara = true, cetro = true, grimorio = true }
    local function nuevo(id)
      local clase, fam, t = tostring(id):match("^(%a+)_(%a+)_(%d+)$")
      if clase and RETIRADAS[fam] then return clase .. "_arma_" .. t end
      return nil
    end
    local oroDevuelto = 0
    local function escudoClerigo(id)
      local t = tostring(id):match("^clerigo_escudo_(%d+)$")
      local ref = t and Datos.item("guerrero_escudo_" .. t)
      return ref and math.floor((ref.precio or 0) * Datos.FACTOR_VENTA) or nil
    end
    for _, s in ipairs(p.bolsa) do
      local n = nuevo(s.id)
      if n and Datos.item(n) then s.id = n end
    end
    for hueco, id in pairs(p.equipo or {}) do
      local n = nuevo(id)
      if n and Datos.item(n) then p.equipo[hueco] = n end
      local o = escudoClerigo(id)
      if o then p.equipo[hueco] = nil oroDevuelto = oroDevuelto + o end
    end
    for i = #p.bolsa, 1, -1 do
      local o = escudoClerigo(p.bolsa[i].id)
      if o then oroDevuelto = oroDevuelto + o * (p.bolsa[i].cant or 1) table.remove(p.bolsa, i) end
    end
    if oroDevuelto > 0 then
      p.oro = (p.oro or 0) + oroDevuelto
      self:mensaje("sistema", "", "El clérigo ya no lleva escudo: se te devolvieron " .. oroDevuelto .. " de oro.", p)
    end
  end
  -- objetos retirados del juego (ya no existen en los datos) se quitan de la bolsa; los pergaminos de forja, que se
  -- vendían en el Item Mall, se devuelven en Monedas Corona al precio que tenían
  do
    local REEMBOLSO = { pergamino_forja = 60, pergamino_forja_sagrado = 160 }
    local devuelto = 0
    for i = #p.bolsa, 1, -1 do
      local s = p.bolsa[i]
      if not s or not Datos.item(s.id) then
        if s then devuelto = devuelto + (REEMBOLSO[s.id] or 0) * (s.cant or 1) end
        table.remove(p.bolsa, i)
      end
    end
    if devuelto > 0 then
      p.monedas = (p.monedas or 0) + devuelto
      self:mensaje("sistema", "", "Los pergaminos de forja se retiraron del juego: se te devolvieron " .. devuelto .. " " .. Mall.MONEDA .. ".", p)
    end
  end
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
  -- Una posición guardada solo vale si sigue siendo tierra firme de tu continente (o de la isla de la
  -- Cicatriz a partir del nivel 20): así los personajes de un mundo anterior no aparecen en el mar.
  local mapaMundo = self.mapas.mundo
  local function posValida(x, y)
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return false end
    local tx, ty = math.floor(x), math.floor(y)
    if not Mapa.transitable(mapaMundo, tx, ty) then return false end
    local cont = mapaMundo.cont[tx] and mapaMundo.cont[tx][ty] or 0
    return cont == (p.faccion == "umbra" and 2 or 1) or (cont == 3 and (p.nivel or 1) >= 20)
  end
  local inicio = { x = p.x, y = p.y }
  if data.vinculo and posValida(data.vinculo.x, data.vinculo.y) then p.vinculo = data.vinculo end
  p.z = data.z or 0
  if data.x and data.y and not (tonumber(data.x) == 0 and tonumber(data.y) == 0) then
    if posValida(data.x, data.y) then
      p.x, p.y = data.x, data.y
    else
      p.x, p.y, p.z = inicio.x, inicio.y, 0
    end
  end
  -- si estaba en un piso alto que ya no existe (la plataforma de las capitales), baja al suelo
  if (p.z or 0) > 0 then
    local alto = mapaMundo.alto
    local tx, ty = math.floor(p.x), math.floor(p.y)
    if not (alto and alto[tx] and alto[tx][ty]) then p.z = 0 end
  end
  for _, c in ipairs(self.mapas.mundo.ciudades) do
    for _, par in ipairs(c.parcelas) do
      if p.casas[par.id] then par.dueno = p.id end
    end
  end
  self:recalcular(p)
  p.hp, p.mp = p.hpMax, p.mpMax
end

-- Redondeos: las posiciones a centésimas y la vida y el maná a enteros (cada cifra de más son bytes en cada foto de cada jugador).
-- El equipo se copia: la foto no debe apuntar a la tabla viva (se cambia en el sitio y las diferencias no verían el cambio).
local function copiaSup(t)
  if not t then return nil end
  local c = {}
  for k, v in pairs(t) do c[k] = v end
  return c
end
local function r2(v) return v and math.floor(v * 100 + 0.5) / 100 or nil end
local function r0(v) return v and math.floor(v + 0.5) or nil end

function Mundo:compactar(e)
  return {
    id = e.id, kind = e.kind, nombre = e.nombre, oculto = e.oculto, faccion = e.faccion, clase = e.clase, gen = e.genero,
    monstruo = e.monstruo, x = r2(e.x), y = r2(e.y), z = e.z or 0, dir = e.dir or 1, vivo = e.vivo ~= false,
    modo = e.modo, hp = r0(e.hp), hpMax = r0(e.hpMax), mp = r0(e.mp), mpMax = r0(e.mpMax),
    nivel = e.nivel, hoja = e.hoja, base = e.base, cuadros = e.cuadros,
    tam = e.tam, paso = e.paso, porDir = e.porDir, elite = e.elite,
    estructura = e.estructura, llevaBandera = e.llevaBandera, llevaCristales = e.llevaCristales, equipo = copiaSup(e.equipo),
    rol = e.rol, qid = e.qid, staff = e.staff, casaId = e.casaId, casaTamano = e.casaTamano, anim = e.anim, portador = e.portador,
    mov = e.mov and true or nil, objetivo = (e.kind == "monstruo") and e.objetivo or nil,
    respawn = (e.kind == "monstruo" or e.kind == "puerta") and e.respawn or nil,
    flash = (e.flashHasta or 0) > self.tiempo and 0.1 or nil,
    atqN = (e.atqN and self.tiempo - (e.atqT or -9) < 1.2) and e.atqN or nil, atqX = (e.atqN and self.tiempo - (e.atqT or -9) < 1.2) and e.atqX or nil, atqY = (e.atqN and self.tiempo - (e.atqT or -9) < 1.2) and e.atqY or nil, atqL = (e.atqN and self.tiempo - (e.atqT or -9) < 1.2) and e.atqLejos or nil,
    burbuja = e.burbuja,
    est = self:estadosVisibles(e), especie = e.especie, gremio = e.gremioEtiqueta,
    montado = e.montado, monturaFrac = (e.montado and e.job and require("compartido.dominio.monturas").especies[e.montado] and require("compartido.dominio.monturas").especies[e.montado].requiereOficio) and (function() local hp, mx = self:vidaMontura(e, e.montado) return hp / mx end)() or nil, job = e.job, addon = e.kind == "jugador" and e.addonActivo or nil,
    item = e.kind == "loot" and e.item or nil, bien = e.kind == "loot" and e.bien or nil,
    oroSuelo = (e.kind == "loot" and (e.oro or 0) > 0) and true or nil, buscado = (e.kind == "jugador" and self:esBuscado(e)) and true or nil,
    categoria = e.categoria, enGrupo = (e.kind == "jugador" and e.grupoId) and true or nil,
    -- proyectiles: de qué tipo son y a dónde van
    tipo = e.kind == "proyectil" and e.tipo or nil,
    tx = e.kind == "proyectil" and e.tx or nil, ty = e.kind == "proyectil" and e.ty or nil,
  }
end

-- Área de interés: radio (en casillas) de lo que cada jugador recibe en su foto.
Mundo.RADIO_FOTO = 28
local CELDA_FOTO = 16

-- Índice espacial de las entidades para las fotos: se construye UNA vez por ronda de fotos y cada jugador consulta solo las celdas
-- que tiene a su alrededor, en vez de recorrer todas las entidades del mundo por cada jugador. Lo que se ve siempre (estatuas,
-- puertas, altares, banderas) y lo que no tiene posición van en una lista aparte.
function Mundo:indiceFoto()
  local celdas, siempre = {}, {}
  for _, e in pairs(self.entidades) do
    local k = e.kind
    if k == "estatua" or k == "puerta" or k == "altar" or k == "bandera" or not e.x then
      siempre[#siempre + 1] = e
    else
      local clave = math.floor(e.x / CELDA_FOTO) * 4096 + math.floor(e.y / CELDA_FOTO)
      local l = celdas[clave]
      if not l then l = {} celdas[clave] = l end
      l[#l + 1] = e
    end
  end
  return { celdas = celdas, siempre = siempre }
end

-- Entidades que ve p (las de su área de interés), con el índice espacial de la ronda si lo hay.
function Mundo:visibles(p, indice)
  local lista = {}
  if p and indice then
    local r = Mundo.RADIO_FOTO
    local c0x, c1x = math.floor((p.x - r) / CELDA_FOTO), math.floor((p.x + r) / CELDA_FOTO)
    local c0y, c1y = math.floor((p.y - r) / CELDA_FOTO), math.floor((p.y + r) / CELDA_FOTO)
    for cx = c0x, c1x do
      for cy = c0y, c1y do
        local l = indice.celdas[cx * 4096 + cy]
        if l then
          for i = 1, #l do
            local e = l[i]
            if self:mismoLugar(p, e) and Util.dist(p.x, p.y, e.x, e.y) < r then lista[#lista + 1] = e end
          end
        end
      end
    end
    for _, e in ipairs(indice.siempre) do
      if self:mismoLugar(p, e) then lista[#lista + 1] = e end
    end
  else
    for _, e in pairs(self.entidades) do
      if p and self:mismoLugar(p, e) then
        local d = Util.dist(p.x, p.y, e.x or p.x, e.y or p.y)
        if d < Mundo.RADIO_FOTO or e.kind == "estatua" or e.kind == "puerta" or e.kind == "altar" or e.kind == "bandera" then
          lista[#lista + 1] = e
        end
      end
    end
  end
  return lista
end

function Mundo:construirTu(p)
  local pid = p.id
    local tu = {
      bolsa = p.bolsa, equipo = p.equipo, oro = p.oro, xp = p.xp, nivel = p.nivel,
      hp = p.hp, hpMax = p.hpMax, mp = p.mp, mpMax = p.mpMax, cds = {},
      misiones = p.misiones, casas = p.casas, sesion = p.sesion, zona = p.zona,
      atk = p.atk, def = p.def, matk = p.matk, mdef = p.mdef, spd = p.spd, clase = p.clase, faccion = p.faccion,
      nombre = p.nombre, modo = p.modo, casaId = p.casaId, casaTamano = p.casaTamano, objetivo = p.objetivo,
      z = p.z or 0, habilidades = p.habilidades, encantos = p.encantos, xpSig = Datos.xpPara(p.nivel),
      mascotas = p.mascotas, mascotaActiva = p.mascotaActiva,
      job = p.job, oficioElegido = p.oficioElegido, oficios = p.oficios, carga = p.carga, cargaRobada = p.cargaRobada,
      capacidadCarga = p.capacidadCarga, pesoCarga = p.pesoCarga, monturas = p.monturas, montado = p.montado,
      buscadoResta = self:esBuscado(p) and (p.buscado - self.tiempo) or nil, recompensa = self:esBuscado(p) and p.recompensa or nil,
      escolta = p.escolta,
      robo = p.robo and { desde = p.robo.desde, hasta = p.robo.hasta } or nil,
      gremioRango = p.gremioRango, gremioEtiqueta = p.gremioEtiqueta,
      invGremio = (p.invitacionGremio and p.invitacionGremio.hasta > self.tiempo) and p.invitacionGremio or nil,
      estadosResta = {}, buffsResta = {},
    }
    if p.gremioId and self.gremios[p.gremioId] then tu.gremioNombre = self.gremios[p.gremioId].nombre end
    tu.grupo = self:resumenGrupo(p)
    tu.mall = self:resumenMall(p)
    tu.cdPociones = p.cdPociones
    tu.medidor = self:medidorDe(p)
    tu.autoPocion = p.autoPocion and true or false
    tu.autoPocionUmbral = p.autoPocionUmbral or Mundo.AUTOPOCION_UMBRAL
    tu.autoMana = p.autoMana and true or false
    tu.autoManaUmbral = p.autoManaUmbral or Mundo.AUTOPOCION_UMBRAL
    tu.invComercio = self:resumenInvitacionComercio(p)
    tu.llevaCristales = p.llevaCristales
    if p.mobaOrig then
      tu.xpSig = Moba.xpPara(p.nivel)                          -- barra de experiencia de la partida
      tu.mobaNiveles, tu.mobaMax = Moba.DESBLOQUEO, Moba.NIVEL_MAX
    end
    tu.eventoStats = (p.modo == "batalla" or p.modo == "estandarte" or p.modo == "moba") and p.eventoStats or nil
    tu.respawnResta = (not p.vivo and p.respawn) and math.max(0, math.ceil(p.respawn - self.tiempo)) or nil
    local defMontura = p.montado and require("compartido.dominio.monturas").especies[p.montado]
    if defMontura and defMontura.requiereOficio then
      local hp, mx = self:vidaMontura(p, p.montado)
      tu.monturaHp, tu.monturaHpMax = math.floor(hp), mx
    end
    tu.monturasEstado = self:estadoMonturas(p)
    tu.diaria = self:estadoDiaria(p)
    tu.diariaError = (p.diariaError and p.diariaError.hasta > self.tiempo) and p.diariaError.texto or nil
    if p.invitacionGrupo and p.invitacionGrupo.hasta > self.tiempo then
      tu.invGrupo = { nombre = p.invitacionGrupo.nombre }
    end
    if p.job then
      tu.caravanas = self:caravanasVisibles()
      if p.job == "hunter" then tu.buscados = self:buscadosVisibles(p) end
    end
    for tipo, st in pairs(p.estados or {}) do tu.estadosResta[tipo] = math.max(0, st.hasta - self.tiempo) end
    -- potenciadores activos (escudo arcano, furia, grito...): quién los dio, cuánto queda y cuánto duraban
    for _, b in ipairs(p.buffs or {}) do
      tu.buffsResta[#tu.buffsResta + 1] = { id = b.id, hab = b.habilidad, resta = math.max(0, b.dur), max = b.max or b.dur }
    end
    for k, v in pairs(p.cds or {}) do tu.cds[k] = v end
    return tu
end

function Mundo:efectosCercanos(p)
  -- Efectos de poderes, números de daño y sonidos en curso cerca del jugador.
  local efectos, numeros = {}, {}
  if p then
    for _, fx in ipairs(self.efectos) do
      if Util.dist(p.x, p.y, fx.x, fx.y) < 30 then
        efectos[#efectos + 1] = { tipo = fx.tipo, x = fx.x, y = fx.y, t = fx.t, dur = fx.dur, rot = fx.rot and math.floor(fx.rot * 100) / 100 or nil, x0 = fx.x0, y0 = fx.y0 }
      end
    end
    for _, n in ipairs(self.numeros) do
      if Util.dist(p.x, p.y, n.x, n.y) < 30 then
        numeros[#numeros + 1] = { x = n.x, y = n.y, texto = n.texto, color = n.color, vida = n.vida }
      end
    end
  end
  local sonidos = {}
  for _, ev in ipairs(self.sonidos) do
    if #sonidos >= 14 then break end
    if ev.e and ev.x then
      if p and self:mismoLugar(p, ev.e) and Util.dist(p.x, p.y, ev.x, ev.y) < 26 then
        sonidos[#sonidos + 1] = { n = ev.n, x = math.floor(ev.x * 10) / 10, y = math.floor(ev.y * 10) / 10 }
      end
    end
  end
  return efectos, numeros, sonidos
end

function Mundo:foto(pid, indice)
  local p = self.entidades[pid]
  local ents = {}
  for _, e in ipairs(self:visibles(p, indice)) do ents[#ents + 1] = self:compactar(e) end
  local tu = p and self:construirTu(p) or nil
  local msgs = {}
  for i = #self.mensajes, 1, -1 do
    local m = self.mensajes[i]
    -- lo anterior a su entrada al mundo no se le manda (los mensajes van en orden de id)
    if p and p.chatDesde and m.id <= p.chatDesde then break end
    local visible = true
    if m.canal == "sistema" and m.para and m.para ~= pid then visible = false end
    if m.canal == "gremio" and (not p or m.gremio ~= p.gremioId) then visible = false end
    if m.canal == "grupo" and (not p or not p.grupoId or m.grupo ~= p.grupoId) then visible = false end
    if visible then
      table.insert(msgs, 1, m)
      if #msgs >= 40 then break end
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
  local efectos, numeros, sonidos = {}, {}, {}
  if p then efectos, numeros, sonidos = self:efectosCercanos(p) end
  return {
    ents = ents, tu = tu, msgs = msgs, gloria = self.gloria, instancia = self.instancia,
    resumen = self._resumen, duenos = duenos, sesiones = sesiones,
    tiempo = self.tiempo, efectos = efectos, numeros = numeros, sonidos = sonidos,
  }
end

-- ------------------------------------------------------------------------------------------------------------------ fotos diferenciales
-- Con muchos jugadores la foto completa de cada uno (todas las entidades con todos sus campos, 15 veces por segundo) es inviable: pesa
-- cientos de KB por segundo por jugador y se codifica a JSON una vez POR JUGADOR. La foto diferencial manda, por cada jugador, solo:
--   nuevos: las entidades que entran en su área (completas)          mods: de las que ya conoce, solo los campos que cambiaron
--   sal:    los ids de las que salen                                  tu: solo los campos propios que cambiaron (4 veces por segundo)
-- y el resto (chat nuevo, efectos...) cuando hay algo. Cada entidad se compacta y se codifica UNA vez por ronda y el texto se reutiliza
-- en la foto de todos los que la ven. Si una foto no pudo enviarse (cola llena) se marca para empezar de cero: foto completa con reset.
-- Copia independiente de lo enviado: la foto lleva referencias a tablas VIVAS del mundo (bolsa, equipo, misiones...) que luego se modifican
-- en el sitio; si lo "ya enviado" fuese la misma tabla, comparar daría siempre "igual" y el cambio no llegaría nunca al cliente.
local function copiaProf(v)
  if type(v) ~= "table" then return v end
  local c = {}
  for k, x in pairs(v) do c[k] = copiaProf(x) end
  return c
end

local function iguales(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do if not iguales(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

-- Campos que el cliente lleva por su cuenta y no se mandan en las diferencias (la fase de la animación cambia cada vuelta en el servidor).
local SIN_DELTA = { anim = true }

local function diferencia(prev, c, conId)
  local d, quitar, hay = {}, nil, false
  for k, v in pairs(c) do
    if not SIN_DELTA[k] and not iguales(v, prev[k]) then d[k] = v hay = true end
  end
  for k in pairs(prev) do
    if c[k] == nil and not SIN_DELTA[k] then quitar = quitar or {} quitar[#quitar + 1] = k hay = true end
  end
  if not hay then return false end
  if conId then d.id = c.id end
  if quitar then d["~"] = quitar end
  return d
end

Mundo.TU_CADA = 4        -- la parte propia (inventario, misiones...) se manda cada 4 fotos, o al momento si el jugador hizo algo (est.forzarTu)
Mundo.META_CADA = 15     -- gloria, eventos, parcelas y sesiones: cada 15 fotos (~1 s)

-- Una ronda de fotos: el índice espacial y las cajas donde se guarda lo que es común a todos los jugadores.
function Mundo:rondaFoto()
  return { indice = self:indiceFoto(), compact = {}, diff = {}, dstr = {}, enc = {}, n = (self._rondaN or 0) + 1 }
end

-- est: el estado de ese cliente (lo que ya conoce). Devuelve el mensaje ya codificado a JSON.
function Mundo:fotoDelta(pid, est, ronda)
  local p = self.entidades[pid]
  if not p then return nil end
  self._rondaN = ronda.n
  local completo = est.completo ~= false
  if completo or not est.conocido then est.conocido = {} end
  local conocido = est.conocido
  est.vueltas = (est.vueltas or 0) + 1
  local nuevos, mods, vistos = {}, {}, {}
  for _, e in ipairs(self:visibles(p, ronda.indice)) do
    local c = ronda.compact[e]
    if not c then c = self:compactar(e) ronda.compact[e] = c end
    local id = c.id
    vistos[id] = true
    local prev = conocido[id]
    if not prev then
      local t = ronda.enc[c]
      if not t then t = Util.jsonEnc(c) ronda.enc[c] = t end
      nuevos[#nuevos + 1] = t
      conocido[id] = c
    elseif prev ~= c then
      local d = ronda.diff[prev]
      if d == nil then
        d = diferencia(prev, c, true)
        ronda.diff[prev] = d
        if d then ronda.dstr[prev] = Util.jsonEnc(d) end
      end
      if d then mods[#mods + 1] = ronda.dstr[prev] end
      conocido[id] = c
    end
  end
  local sal
  for id in pairs(conocido) do
    if not vistos[id] then
      sal = sal or {}
      sal[#sal + 1] = id
      conocido[id] = nil
    end
  end
  local partes = { '"delta":1,"tiempo":' .. Util.jsonEnc(self.tiempo) }
  if completo then partes[#partes + 1] = '"reset":1' end
  if #nuevos > 0 then partes[#partes + 1] = '"nuevos":[' .. table.concat(nuevos, ",") .. "]" end
  if #mods > 0 then partes[#partes + 1] = '"mods":[' .. table.concat(mods, ",") .. "]" end
  if sal then partes[#partes + 1] = '"sal":' .. Util.jsonEnc(sal) end
  -- la parte propia, solo lo que cambió
  if completo or est.forzarTu or est.vueltas % Mundo.TU_CADA == 1 then
    local tu = self:construirTu(p)
    local previo = est.tuPrev
    est.tuPrev, est.forzarTu = copiaProf(tu), nil
    if not previo or completo then
      partes[#partes + 1] = '"tu":' .. Util.jsonEnc(tu)
    else
      local d = diferencia(previo, tu, false)
      if d then partes[#partes + 1] = '"tu":' .. Util.jsonEnc(d) end
    end
  end
  -- chat nuevo desde la última foto
  local desde = est.msgUlt or p.chatDesde or 0
  local msgs
  for i = #self.mensajes, 1, -1 do
    local m = self.mensajes[i]
    if m.id <= desde then break end
    local visible = true
    if m.canal == "sistema" and m.para and m.para ~= pid then visible = false end
    if m.canal == "gremio" and m.gremio ~= p.gremioId then visible = false end
    if m.canal == "grupo" and (not p.grupoId or m.grupo ~= p.grupoId) then visible = false end
    if visible then
      msgs = msgs or {}
      table.insert(msgs, 1, m)
      if #msgs >= 40 then break end
    end
  end
  est.msgUlt = self._msgId or desde
  if msgs then partes[#partes + 1] = '"msgs":' .. Util.jsonEnc(msgs) end
  -- lo que cambia poco: gloria, eventos, parcelas con dueño y la sesión propia
  if completo or est.vueltas % Mundo.META_CADA == 1 or est.forzarMeta then
    est.forzarMeta = nil
    if not ronda.meta then
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
      ronda.meta = '"gloria":' .. Util.jsonEnc(self.gloria) .. ',"instancia":' .. Util.jsonEnc(self.instancia)
        .. ',"resumen":' .. Util.jsonEnc(self._resumen) .. ',"duenos":' .. Util.jsonEnc(duenos)
    end
    partes[#partes + 1] = ronda.meta
    local ses = p.sesion and self.sesiones[p.sesion]
    partes[#partes + 1] = '"sesiones":' .. (ses and Util.jsonEnc({ [p.sesion] = ses }) or "false")
  end
  local efectos, numeros, sonidos = self:efectosCercanos(p)
  if #efectos > 0 or est.hayEfectos then partes[#partes + 1] = '"efectos":' .. Util.jsonEnc(efectos) end
  if #numeros > 0 or est.hayNumeros then partes[#partes + 1] = '"numeros":' .. Util.jsonEnc(numeros) end
  if #sonidos > 0 then partes[#partes + 1] = '"sonidos":' .. Util.jsonEnc(sonidos) end
  est.hayEfectos, est.hayNumeros = #efectos > 0, #numeros > 0
  est.completo = false
  return '{"t":"snap","snap":{' .. table.concat(partes, ",") .. "}}"
end

function Mundo:aplicarFoto(snap, pid)
  if not snap then return end
  local viejo = self.entidades
  local p
  if snap.delta then
    -- foto diferencial: se aplica sobre las entidades que ya hay (ver Mundo:fotoDelta)
    local nuevo = viejo
    if snap.reset then nuevo = {} end
    for _, id in ipairs(snap.sal or {}) do nuevo[id] = nil end
    for _, e in ipairs(snap.nuevos or {}) do
      local prev = viejo[e.id]
      if prev and prev.anim then e.anim = prev.anim end
      e.vivo = e.vivo ~= false
      e.sx, e.sy = e.x, e.y          -- posición según el servidor (la que se ve se desliza hacia ella)
      nuevo[e.id] = e
    end
    for _, m in ipairs(snap.mods or {}) do
      local e = nuevo[m.id]
      if e then
        for k, v in pairs(m) do
          if k == "x" then e.sx = v
          elseif k == "y" then e.sy = v
          elseif k ~= "id" and k ~= "~" then e[k] = v end
        end
        if m.vivo ~= nil then e.vivo = m.vivo ~= false end
        for _, k in ipairs(m["~"] or {}) do e[k] = nil end
      end
    end
    self.entidades = nuevo
    p = nuevo[pid]
    if p and snap.tu then
      for k, v in pairs(snap.tu) do p[k] = v end
      for _, k in ipairs(snap.tu["~"] or {}) do p[k] = nil end
      p["~"] = nil
    end
  else
    local nuevo = {}
    for _, e in ipairs(snap.ents or {}) do
      local prev = viejo[e.id]
      if prev and prev.anim then e.anim = prev.anim end
      e.vivo = e.vivo ~= false
      nuevo[e.id] = e
    end
    self.entidades = nuevo
    p = nuevo[pid]
    if p and snap.tu then
      for k, v in pairs(snap.tu) do p[k] = v end
    end
  end
  if snap.msgs then
    -- el chat se acumula desde que entras: cada foto trae lo reciente y aquí se añade lo que aún no se tenía
    local chat = self._chatAcum
    if not chat then
      chat = { ultimo = 0, epoca = nil }
      self._chatAcum = chat
      self.mensajes = {}
    end
    for _, m in ipairs(snap.msgs) do
      if m.epoca ~= chat.epoca then
        -- el servidor se reinició: sus números de mensaje empiezan de cero
        chat.epoca, chat.ultimo = m.epoca, 0
        self.mensajes = {}
      end
      if m.id > chat.ultimo then
        self.mensajes[#self.mensajes + 1] = m
        chat.ultimo = m.id
      end
    end
    while #self.mensajes > 300 do table.remove(self.mensajes, 1) end
  end
  if snap.gloria then self.gloria = snap.gloria end
  if snap.instancia then self.instancia = snap.instancia end
  if not snap.delta or snap.resumen ~= nil then self.resumenes = snap.resumen end
  if not snap.delta or snap.sesiones ~= nil then self.sesiones = snap.sesiones or {} end
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
  if nombre == "diaria_reclamar" then
    local err = self:reclamarDiaria(p)
    if err then
      self:mensaje("sistema", "", err, p)
      -- el motivo también sale en el propio panel (antes solo iba al chat y parecía que el botón no hacía nada)
      p.diariaError = { texto = err, hasta = self.tiempo + 10 }
    else
      p.diariaError = nil
    end
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
  if nombre == "autopocion" then self:configurarAutopocion(p, datos) end
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
  if nombre == "mueble_mover" then
    local err = self:moverMueble(p, datos.tipo, datos.x, datos.y)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "mueble_rotar" then
    local err = self:rotarMueble(p, datos.tipo)
    if err then self:mensaje("sistema", "", err, p) end
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
  if nombre == "mision_aceptar" then
    local err = self:aceptarMision(p, datos.id)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "mision_entregar" then
    local err = self:entregarMision(p, datos.id)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "mision_abandonar" then
    local err = self:abandonarMision(p, datos.id)
    if err then self:mensaje("sistema", "", err, p) end
  end
  if nombre == "viaje" and p then return self:accionViaje(p, datos or {}) end
  if nombre:sub(1, 9) == "comercio_" and p then return self:accionComercio(p, nombre, datos or {}) end
  if nombre:sub(1, 7) == "gremio_" and p then return self:accionGremio(p, nombre, datos or {}) end
  if nombre:sub(1, 6) == "grupo_" and p then return self:accionGrupo(p, nombre, datos or {}) end
  if nombre:sub(1, 8) == "subasta_" and p then return self:accionSubasta(p, nombre, datos or {}) end
  if nombre:sub(1, 5) == "mall_" and p then return self:accionMall(p, nombre, datos or {}) end
  if p and (nombre:sub(1, 7) == "oficio_" or nombre:sub(1, 10) == "mercancia_" or nombre:sub(1, 8) == "montura_"
    or nombre == "robar" or nombre == "perista_vender" or nombre == "escoltar") then
    return self:accionOficio(p, nombre, datos or {})
  end
  return nil
end

Estados.instalar(Mundo)
Mascotas.instalar(Mundo)
Esbirros.instalar(Mundo)
Diaria.instalar(Mundo)
Gremios.instalar(Mundo)
Oficios.instalar(Mundo)
Ley.instalar(Mundo)
Caravanas.instalar(Mundo)
Monturas.instalar(Mundo)
Subastas.instalar(Mundo)
Programacion.instalar(Mundo)
Grupos.instalar(Mundo)
Encuentros.instalar(Mundo)
Admin.instalar(Mundo)
Comercio.instalar(Mundo)
Mall.instalar(Mundo)
Mazmorras.instalar(Mundo)
MapasFao.instalar(Mundo)
Moba.instalar(Mundo)
Viaje.instalar(Mundo)

return Mundo
