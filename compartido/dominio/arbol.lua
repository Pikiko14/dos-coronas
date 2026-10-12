-- Árbol de poderes de cada oficio. Cada nivel que se sube da un punto para
-- aprender un poder nuevo o subirlo de rango (hasta MAX).
--   activa: uno de los cuatro poderes de la barra (casilla fija). El primero de cada
--           oficio se sabe desde el principio y no cuesta punto.
--   pasiva: bonificación permanente que crece con el rango.
-- Un nodo pide un nivel mínimo para aprenderlo (subirlo de rango solo cuesta puntos) y, a veces, que otro
-- nodo esté en cierto rango. Todo es dato puro: lo usan el servidor y el cliente.
local Datos = require("compartido.dominio.datos")

local A = {}

A.MAX = 5

local function activa(id, slot, nivel, requiere, gratis)
  return { id = id, tipo = "activa", slot = slot, nivel = nivel, requiere = requiere, gratis = gratis }
end

local function pasiva(id, nombre, desc, icono, nivel, requiere, por)
  return {
    id = id, tipo = "pasiva", nombre = nombre, desc = desc, nivel = nivel,
    requiere = requiere, por = por, icono = { hoja = "equipment", sprite = icono },
  }
end

-- Casillas de la hoja de objetos usadas como icono de las pasivas.
local ESPADA, ESCUDO, BOTAS, ANILLO, POCION_VIDA, POCION_MANA, YELMO, PETO, BASTON, MAZA =
  4, 384, 656, 736, 704, 711, 449, 512, 352, 178

A.arboles = {
  guerrero = {
    activa("golpe", 1, 1, nil, true),
    activa("tajo", 2, 3, { "golpe", 2 }),
    activa("grito", 3, 12, { "tajo", 2 }),
    activa("carga", 4, 7, { "golpe", 2 }),
    activa("desgarro", 5, 15, { "golpe", 3 }),
    activa("furia", 6, 20, { "grito", 2 }),
    pasiva("vigor", "Vigor", "Más vida máxima.", POCION_VIDA, 1, nil, { hp = 0.06 }),
    pasiva("fuerza", "Fuerza bruta", "Más ataque físico.", ESPADA, 2, { "golpe", 2 }, { atk = 0.08 }),
    pasiva("piel", "Piel de acero", "Más defensa física y mágica.", ESCUDO, 3, { "vigor", 2 }, { def = 0.08, mdef = 0.05 }),
    pasiva("impulso", "Impulso", "Caminas más rápido.", BOTAS, 4, { "carga", 1 }, { spd = 0.07 }),
  },
  mago = {
    activa("misil", 1, 1, nil, true),
    activa("fuego", 2, 7, { "misil", 2 }),
    activa("escudo", 3, 3, { "misil", 2 }),
    activa("nova", 4, 12, { "fuego", 2 }),
    activa("sombra", 5, 15, { "misil", 3 }),
    activa("meteoro", 6, 20, { "fuego", 3 }),
    pasiva("mente", "Mente aguda", "Más ataque mágico.", BASTON, 1, nil, { matk = 0.08 }),
    pasiva("reserva", "Reserva arcana", "Más maná máximo.", POCION_MANA, 2, { "mente", 1 }, { mp = 0.08 }),
    pasiva("barrera", "Barrera mental", "Más defensa mágica.", ANILLO, 3, { "reserva", 2 }, { mdef = 0.08 }),
    pasiva("prisa", "Prisa arcana", "Caminas más rápido.", BOTAS, 4, { "nova", 1 }, { spd = 0.07 }),
  },
  cazador = {
    activa("disparo", 1, 1, nil, true),
    activa("lluvia", 2, 7, { "disparo", 2 }),
    activa("trampa", 3, 3, { "disparo", 2 }),
    activa("preciso", 4, 12, { "disparo", 2 }),
    activa("flecha_veneno", 5, 15, { "disparo", 3 }),
    activa("paso_agil", 6, 20, { "trampa", 2 }),
    pasiva("punteria", "Puntería", "Más ataque físico.", ANILLO, 1, nil, { atk = 0.08 }),
    pasiva("agilidad", "Agilidad", "Caminas más rápido.", BOTAS, 2, { "punteria", 1 }, { spd = 0.09 }),
    pasiva("cuero", "Cuero curtido", "Más defensa física.", PETO, 3, { "agilidad", 2 }, { def = 0.08 }),
    pasiva("temple", "Temple", "Más vida máxima.", POCION_VIDA, 4, { "cuero", 1 }, { hp = 0.06 }),
  },
  clerigo = {
    activa("curar", 1, 1, nil, true),
    activa("bendicion", 2, 7, { "curar", 2 }),
    activa("castigo", 3, 3, { "curar", 1 }),
    activa("consagrar", 4, 12, { "castigo", 2 }),
    activa("sanacion", 5, 15, { "curar", 3 }),
    activa("juicio", 6, 20, { "castigo", 3 }),
    pasiva("fe", "Fe", "Más ataque mágico.", MAZA, 1, nil, { matk = 0.08 }),
    pasiva("devocion", "Devoción", "Más maná máximo.", POCION_MANA, 2, { "fe", 1 }, { mp = 0.08 }),
    pasiva("gracia", "Gracia", "Más defensa mágica.", YELMO, 3, { "devocion", 2 }, { mdef = 0.08 }),
    pasiva("temple", "Temple", "Más vida máxima.", POCION_VIDA, 4, { "gracia", 1 }, { hp = 0.06 }),
  },
}

-- Cuánto mejora cada poder por rango adicional. pot: potencia (daño, curación, escudo,
-- fuerza de los efectos); cd y mana: reducción; dur: segundos de efecto de más.
local MEJORA = {
  golpe = { pot = 0.10, cd = 0.03 },
  tajo = { pot = 0.10, cd = 0.05, mana = 0.03 },
  grito = { pot = 0.10, cd = 0.04, dur = 1 },
  carga = { pot = 0.10, cd = 0.05, mana = 0.04 },
  misil = { pot = 0.10, cd = 0.03 },
  fuego = { pot = 0.12, cd = 0.04, mana = 0.03 },
  escudo = { pot = 0.15, cd = 0.04, dur = 1 },
  nova = { pot = 0.10, cd = 0.05, mana = 0.03 },
  disparo = { pot = 0.10, cd = 0.03 },
  lluvia = { pot = 0.10, cd = 0.05, mana = 0.03 },
  trampa = { pot = 0, cd = 0.07, mana = 0.05 },
  preciso = { pot = 0.12, cd = 0.05, mana = 0.03 },
  curar = { pot = 0.12, cd = 0.03, mana = 0.03 },
  bendicion = { pot = 0.12, cd = 0.04, dur = 1.5 },
  castigo = { pot = 0.10, cd = 0.03 },
  consagrar = { pot = 0.10, cd = 0.05, mana = 0.03 },
  desgarro = { pot = 0.10, cd = 0.04, mana = 0.03 },
  furia = { pot = 0.10, cd = 0.03, dur = 1.5 },
  sombra = { pot = 0.10, cd = 0.04, mana = 0.03 },
  meteoro = { pot = 0.12, cd = 0.04, mana = 0.03 },
  flecha_veneno = { pot = 0.10, cd = 0.04, mana = 0.03 },
  paso_agil = { pot = 0.10, cd = 0.05, dur = 0.7 },
  sanacion = { pot = 0.12, cd = 0.04, mana = 0.03 },
  juicio = { pot = 0.10, cd = 0.04, mana = 0.03 },
}

function A.nodos(clase)
  return A.arboles[clase] or {}
end

function A.nodo(clase, id)
  for _, n in ipairs(A.nodos(clase)) do
    if n.id == id then return n end
  end
end

function A.nombre(n)
  if n.tipo == "activa" then
    local h = Datos.habilidades[n.id]
    return h and h.nombre or n.id
  end
  return n.nombre
end

-- Rangos con los que empieza un personaje: el poder inicial a rango 1.
function A.iniciales(clase)
  local r = {}
  for _, n in ipairs(A.nodos(clase)) do
    if n.gratis then r[n.id] = 1 end
  end
  return r
end

-- Rango de un poder del personaje. Sin árbol (bots y datos antiguos) vale lo que
-- permitía antes el nivel.
function A.rango(p, id)
  if p.habilidades then return p.habilidades[id] or 0 end
  local Balance = require("compartido.dominio.balance")
  local n = A.nodo(p.clase, id)
  if n and n.tipo == "activa" and Balance.slotDisponible(p.nivel or 1, n.slot) then return 1 end
  return 0
end

-- Puntos que cuestan los rangos ya comprados (el rango gratis no cuenta).
function A.gastados(p)
  local total = 0
  for _, n in ipairs(A.nodos(p.clase)) do
    local r = p.habilidades and p.habilidades[n.id] or 0
    if r > 0 then total = total + r - (n.gratis and 1 or 0) end
  end
  return total
end

-- Se gana un punto por cada nivel que se sube.
function A.puntos(p)
  return math.max(0, (p.nivel or 1) - 1 - A.gastados(p))
end

-- Qué impide comprar el siguiente rango (texto) o nil si se puede.
function A.motivo(p, id)
  local n = A.nodo(p.clase, id)
  if not n then return "Ese poder no es de tu oficio." end
  local r = A.rango(p, id)
  if r >= A.MAX then return "Ya está al máximo." end
  if r == 0 and (p.nivel or 1) < n.nivel then return "Necesitas nivel " .. n.nivel .. "." end
  if n.requiere then
    local previo = A.nodo(p.clase, n.requiere[1])
    if A.rango(p, n.requiere[1]) < n.requiere[2] then
      return "Primero sube " .. (previo and A.nombre(previo) or n.requiere[1]) .. " a rango " .. n.requiere[2] .. "."
    end
  end
  if A.puntos(p) < 1 then return "No tienes puntos de habilidad." end
  return nil
end

local cache = {}

-- El poder tal como queda con su rango: coef, cura, cd, mana y dur ya ajustados,
-- y pot (multiplicador de potencia) para escudos y efectos.
function A.efectiva(id, rango)
  rango = math.max(1, math.min(A.MAX, rango or 1))
  local clave = id .. "#" .. rango
  local e = cache[clave]
  if e then return e end
  local base = Datos.habilidades[id]
  if not base then return nil end
  local m = MEJORA[id] or {}
  local k = rango - 1
  e = {}
  for campo, v in pairs(base) do e[campo] = v end
  e.pot = 1 + (m.pot or 0.1) * k
  if base.coef then e.coef = base.coef * e.pot end
  if base.cura then e.cura = base.cura * e.pot end
  if base.curaN then e.curaN = base.curaN * e.pot end
  e.cd = math.max(0.6, base.cd * (1 - (m.cd or 0.04) * k))
  e.mana = math.floor(base.mana * (1 - (m.mana or 0) * k) + 0.5)
  if base.dur then e.dur = base.dur + (m.dur or 0) * k end
  if base.estado then
    -- el rango también hace más probable el estado y lo alarga un poco
    local ef = {}
    for k, v in pairs(base.estado) do ef[k] = v end
    local def = require("compartido.dominio.estados").def[ef.tipo]
    ef.prob = math.min(0.95, (ef.prob or 1) * e.pot)
    ef.dur = (ef.dur or (def and def.dur) or 3) + 0.25 * k
    e.estado = ef
  end
  e.rango_poder = rango
  cache[clave] = e
  return e
end

-- Suma las pasivas al final de recalcular: porcentajes sobre lo ya calculado.
function A.aplicarPasivas(e)
  if not e.habilidades then return end
  for _, n in ipairs(A.nodos(e.clase)) do
    local r = n.tipo == "pasiva" and e.habilidades[n.id] or 0
    if r > 0 and n.por then
      local por = n.por
      if por.hp then e.hpMax = math.floor(e.hpMax * (1 + por.hp * r)) end
      if por.mp then e.mpMax = math.floor(e.mpMax * (1 + por.mp * r)) end
      if por.atk then e.atk = e.atk * (1 + por.atk * r) end
      if por.matk then e.matk = e.matk * (1 + por.matk * r) end
      if por.def then e.def = e.def * (1 + por.def * r) end
      if por.mdef then e.mdef = e.mdef * (1 + por.mdef * r) end
      if por.spd then e.spd = e.spd + por.spd * r end
    end
  end
end

return A
