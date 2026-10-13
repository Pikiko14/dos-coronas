local Balance = require("compartido.dominio.balance")
local Mall = require("compartido.dominio.mall")

local D = {}
require("compartido.dominio.configuracion").aplicar(D, "datos")

D.MAPA_W = math.floor(720 * D.ESCALA)
D.MAPA_H = math.floor(520 * D.ESCALA)

-- La configuración (facciones, clases, poderes, ciudades, biomas, misiones y criaturas) está en
-- compartido/datos/*.xml: ahí se edita (ver LEEME.txt, "Configuración en XML"). Este módulo la carga y
-- comprueba los campos imprescindibles para que un error de edición salga con su archivo y su registro.
local Config = require("compartido.dominio.configuracion")

D.facciones = Config.mapa("facciones", "faccion")
D.clases = Config.mapa("clases", "clase")
D.habilidades = Config.mapa("habilidades", "habilidad", false, { barra = true })
D.barra = Config.seccion("habilidades", "barra")
D.biomas = Config.mapa("biomas", "bioma", false)
D.misiones = Config.lista("misiones", "mision")
D.monstruos = Config.lista("monstruos", "monstruo")

-- Las diez ciudades: cinco en el continente del Alba (oeste) y cinco en el de Umbra (este); caminos curvos
-- unen las de cada continente y los puertos (puerto = true) tienen barquero para cruzar el mar. Cada
-- ciudad trae su bioma: el halo alrededor y las criaturas que lo habitan. En el XML su posición es una
-- fracción del mapa (fx, fy); aquí se convierte en casillas.
D.ciudades = Config.lista("ciudades", "ciudad")
local W, H = D.MAPA_W, D.MAPA_H
for _, c in ipairs(D.ciudades) do
  local ancho = c.capital and 72 or 48
  local alto = c.capital and 56 or 36
  c.x = math.floor(W * c.fx - ancho / 2)
  c.y = math.floor(H * c.fy - alto / 2)
  c.fx, c.fy = nil, nil
end

-- Comprobaciones de la configuración cargada
for id, f in pairs(D.facciones) do
  Config.validar("facciones.xml", "faccion", id, f, { nombre = "texto", titulo = "texto", color = "tabla", texto = "texto" })
end
for id, c in pairs(D.clases) do
  Config.validar("clases.xml", "clase", id, c, {
    nombre = "texto", hp = "numero", mp = "numero", atk = "numero", def = "numero", spd = "numero",
    hpN = "numero", mpN = "numero", atkN = "numero", defN = "numero", matk = "numero", mdef = "numero",
    matkN = "numero", mdefN = "numero", danoBasico = "texto", rango = "numero", desc = "texto",
  })
  if not D.barra[id] or #D.barra[id] ~= 6 then error("habilidades.xml: la barra de " .. id .. " debe tener 6 poderes", 0) end
end
for id, h in pairs(D.habilidades) do
  Config.validar("habilidades.xml", "habilidad", id, h, { nombre = "texto", clase = "texto", cd = "numero", mana = "numero", tipo = "texto", desc = "texto" })
  if not D.clases[h.clase] then error("habilidades.xml: habilidad '" .. id .. "': la clase '" .. h.clase .. "' no existe", 0) end
end
for clase, lista in pairs(D.barra) do
  for _, id in ipairs(lista) do
    if not D.habilidades[id] then error("habilidades.xml: la barra de " .. clase .. " usa un poder que no existe: " .. tostring(id), 0) end
  end
end
for _, m in ipairs(D.monstruos) do
  Config.validar("monstruos.xml", "monstruo", m.id, m, { id = "texto", nombre = "texto", nivel = "numero", hoja = "texto", base = "numero", cuadros = "numero", desc = "texto" })
end
for _, c in ipairs(D.ciudades) do
  Config.validar("ciudades.xml", "ciudad", c.id, c, { nombre = "texto", faccion = "texto", bioma = "texto" })
  if not D.biomas[c.bioma] then error("ciudades.xml: ciudad '" .. c.id .. "': el bioma '" .. c.bioma .. "' no existe", 0) end
end
for _, q in ipairs(D.misiones) do
  Config.validar("misiones.xml", "mision", q.id, q, { ciudad = "texto", titulo = "texto", monstruo = "texto", cantidad = "numero", oro = "numero", xp = "numero" })
end

D.tiles = {
  hierba = { 48, 49 },
  hierba_osc = { 66, 67 },
  bosque = { 64 },
  arena = { 112, 113, 116 },
  tierra = { 120, 121 },
  camino = { 120, 121 },
  agua = { 736, 737, 738, 739 },
  empedrado = { 309 },
  madera = { 282 },
  plaza = { 309 },
  adoquin = { 309 },
  muralla = { 270 },
  calle = { 120 },
  teja = { 294 },
  teja_umbra = { 286 },
  cicatriz = { 124 },
  tejado = { 294 },
}

D.props = {
  muro = { hoja = "walls", indice = 1 },
  muro_rojo = { hoja = "walls", indice = 65 },
  puerta = { hoja = "doors", indice = 9 },
  puerta_hierro = { hoja = "doors", indice = 15 },
  arbol = { hoja = "nature", indice = 449 },
  arbol_seco = { hoja = "nature", indice = 560 },
  arbol_pino = { hoja = "nature", indice = 470 },
  cofre = { hoja = "town", indice = 65 },
  caja = { hoja = "town", indice = 73 },
  barril = { hoja = "town", indice = 23 },
  mesa = { hoja = "town", indice = 7 },
  cama = { hoja = "town", indice = 18 },
  estatua = { hoja = "equipment", indice = 455 },
  cristal = { hoja = "equipment", indice = 359 },
  altar = { hoja = "town", indice = 22 },
}


function D.statsMonstruo(m)
  local n = m.nivel
  local elite = m.elite and 6 or 1
  local grande = (m.tam or 1) > 1 and 1.8 or 1
  local curva = n * n
  -- Un monstruo físico pega con atk y se defiende sobre todo con def; uno mágico,
  -- al revés. Lo que no es lo suyo vale el 30% (ataque) o el 50% (defensa).
  local atk0 = math.floor((4 + n * 1.45 + curva * 0.035) * D.MONSTRUO_ATK * (m.elite and 2.1 or 1) * (m.atkMul or 1))
  local def0 = math.floor((n * 0.9 + curva * 0.02) * (m.elite and 1.4 or 1))
  local magico = m.magico and true or false
  return {
    hp = math.floor((28 + n * 16 + curva * 0.85) * D.MONSTRUO_HP * elite * (m.elite and 1 or grande) * (m.hpMul or 1)),
    atk = magico and math.floor(atk0 * 0.3) or atk0,
    matk = magico and atk0 or math.floor(atk0 * 0.3),
    def = magico and math.floor(def0 * 0.5) or def0,
    mdef = magico and def0 or math.floor(def0 * 0.5),
    dano = magico and "magico" or "fisico",
    xp = Balance.xpMonstruo(n, n, m.elite),
    oro = math.floor((4 + n * 3 + curva * 0.08) * (m.elite and 4 or 1)),
    rango = m.vuela and 5.5 or (magico and 4.5 or 1.25),
    velocidad = m.velocidad or (m.elite and 3.4 or (2.5 + math.min(1.6, n * 0.055))),
  }
end

function D.xpPara(nivel)
  return Balance.xpPara(nivel)
end

D.items = {}
local function add(it)
  D.items[it.id] = it
end

-- Armas, armaduras, escudos, anillos y amuletos: ver items.lua.
require("compartido.dominio.items").generar(D)

-- Pociones, materiales y mochilas (la mochila equipada decide cuántos espacios tiene la bolsa): ver
-- compartido/datos/items.xml.
for _, it in ipairs(Config.lista("items", "item")) do add(it) end

-- Espacios que da el equipo: el de la mochila puesta o los básicos.
function D.capacidadBolsa(equipo)
  local it = equipo and equipo.mochila and D.items[equipo.mochila]
  return it and it.slots or D.BOLSA_BASE
end
-- Objetos del Item Mall (se pagan con monedas especiales, ver dominio/mall.lua)
for _, o in ipairs(Mall.OBJETOS) do
  add({ id = o.id, nombre = o.nombre, apila = 20, mall = true, monedas = o.precio, bono = o.bono, forja = o.forja,
    hoja = o.hoja or "equipment", sprite = o.sprite, texto = o.texto, tinte = o.color or (o.bono and Mall.BONOS[o.bono].color) })
end

D.muebles = Config.mapa("muebles", "mueble", false)


function D.capital(faccion)
  for _, c in ipairs(D.ciudades) do
    if c.faccion == faccion and c.capital then return c end
  end
end

function D.monstruo(id)
  for _, m in ipairs(D.monstruos) do
    if m.id == id then return m end
  end
end

function D.item(id)
  return D.items[id]
end

-- Una poción de vida tiene cura; una de maná tiene mana y no cura.
function D.esTipoPocion(it, tipo)
  if not it or it.quest or it.mall then return false end
  if tipo == "mana" then return it.mana ~= nil and it.cura == nil end
  return it.cura ~= nil
end

-- La más fuerte que el nivel permite beber. Si hay empate, gana la de más nivel.
function D.elegirPocion(bolsa, nivel, tipo)
  local mejor, fuerza, nv
  nivel = nivel or 1
  for _, s in ipairs(bolsa or {}) do
    local it = D.items[s.id]
    if D.esTipoPocion(it, tipo) and (s.cant or 1) > 0 and nivel >= (it.nivel or 1) then
      local f = tipo == "mana" and it.mana or it.cura
      local ln = it.nivel or 1
      if not mejor or f > fuerza or (f == fuerza and ln > nv) then
        mejor, fuerza, nv = s.id, f, ln
      end
    end
  end
  return mejor
end

function D.contarPociones(bolsa, tipo)
  local n = 0
  for _, s in ipairs(bolsa or {}) do
    if D.esTipoPocion(D.items[s.id], tipo) then n = n + (s.cant or 1) end
  end
  return n
end

-- La que se bebe con la tecla: la mejor usable, o cualquiera que tengas para que el servidor diga el nivel.
function D.pocionAlUsar(bolsa, nivel, tipo)
  local id = D.elegirPocion(bolsa, nivel, tipo)
  if id then return id end
  for _, s in ipairs(bolsa or {}) do
    if D.esTipoPocion(D.items[s.id], tipo) and (s.cant or 1) > 0 then return s.id end
  end
  return tipo == "mana" and "pocion_mana" or "pocion_vida"
end

function D.cuadro(def, dir, frame)
  local porDir = def.porDir or 3
  local paso = def.paso or 1
  local total = def.cuadros or (porDir * 4)
  local grupos = math.max(1, math.floor(total / porDir))
  local mapa = { [2] = 0, [3] = 1, [1] = 2, [4] = 3 }
  local g = mapa[dir] or 0
  if g >= grupos then g = g % grupos end
  local f = (frame or 0) % porDir
  local maxFrame = math.floor(total / paso) - 1
  local n = g * porDir + f
  if n > maxFrame then n = n % (maxFrame + 1) end
  return def.base + n * paso
end

-- Mazmorras: tres cuevas con su puerta en distintos lugares del mapa. Dentro hay salas con criaturas
-- y, al fondo, un jefe; al caer deja un cofre con un premio (cualquier objeto o addon del mall, o un
-- arma o armadura del escalón más alto). Cada mazmorra es su propio mapa (modo = id).
--   biomas: donde se busca el sitio de su puerta. tinte: color del suelo. jefe.vida/dano: multiplicadores.
-- Los datos de cada una (y los planos de sus salas) están en compartido/datos/mazmorras.xml.
D.mazmorras = Config.registros("mazmorras", "mazmorra")

function D.mazmorra(id)
  for _, m in ipairs(D.mazmorras) do
    if m.id == id then return m end
  end
end

return D
