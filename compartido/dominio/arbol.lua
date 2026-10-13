-- Árbol de poderes de cada oficio. Cada nivel que se sube da un punto para
-- aprender un poder nuevo o subirlo de rango (hasta MAX).
--   activa: uno de los cuatro poderes de la barra (casilla fija). El primero de cada
--           oficio se sabe desde el principio y no cuesta punto.
--   pasiva: bonificación permanente que crece con el rango.
-- Un nodo pide un nivel mínimo para aprenderlo (subirlo de rango solo cuesta puntos) y, a veces, que otro
-- nodo esté en cierto rango. Todo es dato puro: lo usan el servidor y el cliente.
local Datos = require("compartido.dominio.datos")

local A = {}

-- Los nodos de cada oficio y lo que mejora cada poder por rango están en compartido/datos/arbol.xml.
local datosArbol = require("compartido.dominio.configuracion").tabla("arbol")
A.MAX = datosArbol.max
A.arboles = datosArbol.arboles
local MEJORA = datosArbol.mejoras

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
