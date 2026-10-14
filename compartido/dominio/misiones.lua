-- Misiones: encargos que dan los PNJ de las ciudades y de los puestos repartidos por el mapa.
--   * cazar: derrotar N criaturas de un tipo (hay una para CADA criatura del juego: normales, élites y jefes).
--   * recolectar: reunir N trofeos que suelta una criatura (solo mientras la misión está activa) y llevarlos.
--   * entregar: llevar un paquete o una carta de un PNJ a otro.
--   * cadenas: una misión pide haber entregado la anterior (requiere); algunas cadenas difíciles dan un addon o una montura.
-- Las misiones curadas están en compartido/datos/misiones.xml; el resto se genera aquí a partir de las criaturas y del mapa
-- (con la misma semilla en el servidor y en el juego, así los dos ven las mismas misiones y los mismos PNJ).
-- Las recompensas salen de la dificultad y del nivel de la misión: ver M.recompensa.
local Datos = require("compartido.dominio.datos")
local Balance = require("compartido.dominio.balance")

local M = {}

M.lista, M.por_id, M.npcs, M.camps, M.porNpc = {}, {}, {}, {}, {}

-- cuánto pesa cada dificultad en la recompensa (normal: cazar un puñado; difícil: jefes y repeticiones; épica: élites y finales)
M.MULT = { normal = 2, dificil = 3.5, epica = 6 }
-- cuántos niveles por debajo de la misión se puede estar y aún aceptarla
M.MARGEN = { normal = 5, dificil = 2, epica = 2 }
M.PROB_TROFEO = 0.6        -- probabilidad de que la criatura suelte su trofeo si lo necesitas
M.MAX_ACTIVAS = 15
M.DISTANCIA_PNJ = 6        -- a cuántas casillas del PNJ hay que estar para aceptar o entregar

M.NOMBRE_DIF = { normal = "Normal", dificil = "Difícil", epica = "Épica" }
M.COLOR_DIF = { normal = { 0.7, 0.9, 0.7 }, dificil = { 1, 0.75, 0.3 }, epica = { 1, 0.45, 0.4 } }

-- ------------------------------------------------------------------------------------------------ recompensas
-- Lo que vale una misión: oro y experiencia en proporción a lo que darían las criaturas, multiplicado por la dificultad.
-- factor: 2 = el doble de lo habitual (los finales de cadena).
function M.recompensa(nivel, cantidad, dif, peso, factor)
  local mult = M.MULT[dif or "normal"] or M.MULT.normal
  peso = peso or 1
  factor = factor or 1
  local xp = math.floor(cantidad * (10 + 6 * nivel) * peso * mult * factor)
  local oro = math.floor(cantidad * (6 + 2 * nivel) * (peso > 1 and 2.5 or 1) * mult * factor)
  return oro, xp
end

-- La experiencia de una misión se ajusta al nivel de quien la entrega: más baja si ya la superaste de sobra, algo más alta
-- si vas por debajo (igual que las criaturas).
function M.factorNivel(nivelJugador, nivelMision)
  local d = (nivelMision or 1) - (nivelJugador or 1)
  if d >= 0 then return math.min(1.6, 1 + d * 0.1) end
  return math.max(0.25, 1 + d * 0.1)
end

-- Experiencia que da de verdad una misión a este jugador: ajustada a su nivel y sin pasar de un nivel entero de golpe
-- (la mayor parte de lo que se gana sigue saliendo de cazar).
M.TOPE_XP = 0.9
function M.xpFinal(p, q)
  local xp = (q.xp or 0) * M.factorNivel(p.nivel, q.nivel)
  local tope = Balance.xpPara(p.nivel or 1) * M.TOPE_XP
  return math.max(1, math.floor(math.min(xp, tope) + 0.5))
end

function M.nivelMinimo(q)
  return math.max(1, (q.nivel or 1) - (M.MARGEN[q.dif or "normal"] or 5))
end

-- ------------------------------------------------------------------------------------------------ objetos de misión
-- Cada criatura tiene su trofeo (mat_<id>), una misión de recolectar lo pide. Los paquetes y cartas de las entregas se crean al
-- preparar las misiones (paq_*, carta_*). Ninguno se vende.
local ICONOS_TROFEO = { 720, 721, 723, 724, 725, 726, 727, 764, 702, 703 }
function M.registrarObjetos()
  for i, m in ipairs(Datos.monstruos) do
    local id = "mat_" .. m.id
    if not Datos.items[id] then
      Datos.agregarItem({ id = id, nombre = "Trofeo: " .. m.nombre, apila = 99, hoja = "equipment", sprite = ICONOS_TROFEO[i % #ICONOS_TROFEO + 1],
        quest = true, precio = 1, texto = "Lo suelta " .. m.nombre .. " mientras una misión lo pide." })
    end
  end
end

-- ------------------------------------------------------------------------------------------------ construcción
local function distancia(ax, ay, bx, by)
  local dx, dy = ax - bx, ay - by
  return math.sqrt(dx * dx + dy * dy)
end

local function esElite(m) return m.elite and true or false end
local function esJefe(m) return m.categoria == "party" or m.categoria == "gigante" end

local PISTAS = {
  party = "Sale al paso de grupos de 2 o más jugadores que cazan juntos en campo abierto.",
  gigante = "Sale al paso de grupos de 3 o más jugadores que cazan juntos en campo abierto.",
  elite = "Es una criatura única: aparece en los eventos de guerra.",
  bandido = "Asalta las caravanas que viajan por los caminos.",
}

local function parsePremios(s)
  local lista = {}
  for id, cant in tostring(s or ""):gmatch("([%w_]+):(%d+)") do lista[#lista + 1] = { id = id, cant = tonumber(cant) } end
  return lista
end

-- Datos fijos de los PNJ de misiones: ciudades (tablón de encargos) y puestos del mapa.
local function registrarNpcs(mapa)
  M.npcs = {}
  for _, c in ipairs(mapa.ciudades or {}) do
    for _, n in ipairs(c.npcs or {}) do
      if n.rol == "encargos" then
        local qid = "c_" .. c.id
        M.npcs[qid] = { qid = qid, nombre = n.nombre, x = n.x, y = n.y, lugar = c.nombre or c.id, ciudad = c.id, faccion = c.faccion, tipo = "ciudad" }
      end
    end
  end
  for _, pu in ipairs(mapa.puestos or {}) do
    for _, n in ipairs(pu.npcs or {}) do
      if n.rol == "misiones" then
        local qid = "p" .. pu.id
        M.npcs[qid] = { qid = qid, nombre = n.nombre, x = n.x, y = n.y, lugar = pu.nombre, puesto = pu.id, faccion = n.faccion, tipo = "puesto" }
      end
    end
  end
  M.ordenNpcs = {}
  for qid in pairs(M.npcs) do M.ordenNpcs[#M.ordenNpcs + 1] = qid end
  table.sort(M.ordenNpcs)
end

local function registrarCamps(mapa)
  M.camps = {}
  for _, c in ipairs(mapa.campamentos or {}) do
    if not c.z then
      local l = M.camps[c.monstruo]
      if not l then l = {} M.camps[c.monstruo] = l end
      l[#l + 1] = { x = c.x, y = c.y, nivel = c.nivel }
    end
  end
end

-- Nivel de la zona de un PNJ: el promedio de los campamentos más cercanos.
local function nivelLocal(npc)
  local cercanos = {}
  for _, l in pairs(M.camps) do
    for _, c in ipairs(l) do cercanos[#cercanos + 1] = { d = distancia(npc.x, npc.y, c.x, c.y), nivel = c.nivel or 1 } end
  end
  if #cercanos == 0 then return 1 end
  table.sort(cercanos, function(a, b) return a.d < b.d end)
  local suma, n = 0, math.min(8, #cercanos)
  for i = 1, n do suma = suma + cercanos[i].nivel end
  return suma / n
end

local function agregar(q)
  q.dif = q.dif or "normal"
  q.tipo = q.tipo or "cazar"
  q.cantidad = tonumber(q.cantidad) or 1
  if not q.destino then q.destino = q.npc end
  if q.oro == nil or q.xp == nil then
    local peso = q.peso or 1
    local cant = q.cantidad
    if q.tipo == "recolectar" then cant = cant * 1.4 end
    if q.tipo == "entregar" then cant = (q.esfuerzo or 5) end
    local oro, xp = M.recompensa(q.nivel or 1, cant, q.dif, peso, q.factor)
    if q.oro == nil then q.oro = oro end
    if q.xp == nil then q.xp = xp end
  end
  if type(q.premios) == "string" then q.premios = parsePremios(q.premios) end
  M.lista[#M.lista + 1] = q
  M.por_id[q.id] = q
  if q.npc then
    local l = M.porNpc[q.npc]
    if not l then l = {} M.porNpc[q.npc] = l end
    l[#l + 1] = q
  end
end

function M.preparar(mapa)
  M.lista, M.por_id, M.porNpc = {}, {}, {}
  M.registrarObjetos()
  registrarNpcs(mapa)
  registrarCamps(mapa)
  local carga = {}
  for qid in pairs(M.npcs) do carga[qid] = 0 end
  local nivelesNpc = {}
  for qid, n in pairs(M.npcs) do nivelesNpc[qid] = nivelLocal(n) end

  -- 1) misiones curadas (misiones.xml): cadenas con premios, entregas y los encargos de cada ciudad
  local curadas = {}
  for _, d in ipairs(Datos.misiones) do
    local q = {}
    for k, v in pairs(d) do q[k] = v end
    q.curada = true
    if not q.npc and q.ciudad then q.npc = "c_" .. q.ciudad end
    if not q.nivel then
      local mdef = q.monstruo and Datos.monstruo(q.monstruo) or (q.de and Datos.monstruo(q.de))
      q.nivel = mdef and mdef.nivel or 1
    end
    if q.destino == nil and q.paquete == nil then q.destino = q.npc end
    if q.tipo == "entregar" and not q.item then
      q.item = "paq_" .. q.id
      Datos.agregarItem({ id = q.item, nombre = q.paquete or "Paquete", apila = 1, hoja = "equipment", sprite = 699, quest = true, precio = 1,
        texto = "Llévalo a " .. tostring(q.destino) .. "." })
    end
    if q.tipo == "recolectar" and not q.item and q.de then q.item = "mat_" .. q.de end
    if not q.tipo or q.tipo == "cazar" then q.tipo = "cazar" end
    if M.npcs[q.npc] then
      carga[q.npc] = carga[q.npc] + 1
      curadas[#curadas + 1] = q
    end
  end
  for _, q in ipairs(curadas) do agregar(q) end

  -- 2) una misión de cazar para CADA criatura (más una segunda, difícil, de repetición) y otra de recolectar para muchas
  local CAP = 9
  local function elegirNpc(m)
    local camps = M.camps[m.id]
    local candidatos = {}
    for _, qid in ipairs(M.ordenNpcs) do
      local n = M.npcs[qid]
      local score
      if camps and #camps > 0 then
        score = math.huge
        for _, c in ipairs(camps) do score = math.min(score, distancia(n.x, n.y, c.x, c.y)) end
      else
        score = math.abs(nivelesNpc[qid] - m.nivel) * 40
      end
      candidatos[#candidatos + 1] = { qid = qid, score = score }
    end
    table.sort(candidatos, function(a, b) if a.score ~= b.score then return a.score < b.score end return a.qid < b.qid end)
    for _, c in ipairs(candidatos) do
      if carga[c.qid] < CAP then return c.qid end
    end
    return candidatos[1] and candidatos[1].qid
  end

  for i, m in ipairs(Datos.monstruos) do
    local npc = elegirNpc(m)
    if npc then
      local jefe, elite = esJefe(m), esElite(m)
      local nivel = m.nivel
      local pista = (elite and PISTAS.elite) or (m.categoria == "party" and PISTAS.party) or (m.categoria == "gigante" and PISTAS.gigante)
        or (m.bandido and PISTAS.bandido) or nil
      local cant1
      if elite then cant1 = 1 elseif jefe then cant1 = (m.categoria == "gigante") and 1 or 2
      else cant1 = math.max(6, math.min(16, 6 + math.floor(nivel / 3))) end
      local dif1 = elite and "epica" or (jefe and "dificil" or "normal")
      local peso = elite and 4 or (jefe and 3 or 1)
      agregar({
        id = "h1_" .. m.id, tipo = "cazar", npc = npc, monstruo = m.id, cantidad = cant1, nivel = nivel, dif = dif1, peso = peso, pista = pista,
        titulo = (elite and "Caza mayor: " or (jefe and "Jefe: " or "Cacería: ")) .. m.nombre,
        texto = (elite or jefe) and ("Derrota a " .. m.nombre .. (cant1 > 1 and (" (" .. cant1 .. " veces)") or "") .. ".") or ("Derrota " .. cant1 .. " de " .. m.nombre .. "."),
        dialogo = (elite or jefe) and ("Hay una amenaza que nadie se atreve a enfrentar: " .. m.nombre .. ". ¿Te encargas?") or ("Esas criaturas (" .. m.nombre .. ") no dejan vivir en paz. Haz que se lo piensen dos veces."),
        final = "Buen trabajo. Aquí tienes lo prometido.",
      })
      carga[npc] = carga[npc] + 1
      if not elite then
        local cant2 = jefe and 3 or math.min(40, math.floor(cant1 * 2.5))
        agregar({
          id = "h2_" .. m.id, tipo = "cazar", npc = npc, monstruo = m.id, cantidad = cant2, nivel = nivel, dif = jefe and "epica" or "dificil", peso = peso, pista = pista,
          requiere = "h1_" .. m.id,
          titulo = (jefe and "Azote de jefes: " or "Exterminio: ") .. m.nombre,
          texto = "Derrota " .. cant2 .. (jefe and " veces a " or " de ") .. m.nombre .. ".",
          dialogo = "No basta con asustarlas. Acaba con muchas más de esas criaturas.",
          final = "Impresionante. Pocos llegan hasta aquí.",
        })
        carga[npc] = carga[npc] + 1
      end
      -- recolectar el trofeo: para las criaturas normales de las que no hay ya una misión curada
      if not elite and not jefe and not m.bandido and i % 2 == 1 and nivel >= 2 then
        local cant = math.max(4, math.min(12, 4 + math.floor(nivel / 4)))
        agregar({
          id = "r1_" .. m.id, tipo = "recolectar", npc = npc, de = m.id, item = "mat_" .. m.id, cantidad = cant, nivel = nivel, dif = "normal", pista = pista,
          titulo = "Trofeos: " .. m.nombre,
          texto = "Reúne " .. cant .. " trofeos de " .. m.nombre .. " y tráemelos.",
          dialogo = "Pago bien los trofeos de " .. m.nombre .. ". Tráeme " .. cant .. " y hablamos.",
          final = "Justo lo que necesitaba. Aquí tienes tu parte.",
        })
        carga[npc] = carga[npc] + 1
      end
    end
  end

  -- 3) entregas: cada puesto recibe suministros de la ciudad más cercana y devuelve una carta
  for _, qid in ipairs(M.ordenNpcs) do
    local n = M.npcs[qid]
    if n.tipo == "puesto" then
      local ciudad, mejor = nil, math.huge
      for _, cq in ipairs(M.ordenNpcs) do
        local c = M.npcs[cq]
        if c.tipo == "ciudad" and c.faccion == n.faccion then
          local d = distancia(n.x, n.y, c.x, c.y)
          if d < mejor then mejor, ciudad = d, cq end
        end
      end
      if ciudad then
        local nivel = math.max(1, math.floor(nivelesNpc[qid] + 0.5))
        local esfuerzo = math.max(3, math.floor(mejor / 25))
        local idA, idB = "e1_" .. qid, "e2_" .. qid
        local paq, carta = "paq_" .. idA, "carta_" .. idB
        Datos.agregarItem({ id = paq, nombre = "Suministros para " .. n.lugar, apila = 1, hoja = "equipment", sprite = 699, quest = true, precio = 1,
          texto = "Llévalos a " .. n.nombre .. " (" .. n.lugar .. ")." })
        Datos.agregarItem({ id = carta, nombre = "Carta de " .. n.nombre, apila = 1, hoja = "equipment", sprite = 697, quest = true, precio = 1,
          texto = "Llévala a " .. M.npcs[ciudad].nombre .. "." })
        agregar({
          id = idA, tipo = "entregar", npc = ciudad, destino = qid, item = paq, cantidad = 1, nivel = nivel, dif = "normal", esfuerzo = esfuerzo,
          titulo = "Suministros para " .. n.lugar,
          texto = "Lleva los suministros a " .. n.nombre .. " (" .. n.lugar .. ").",
          dialogo = "En " .. n.lugar .. " andan escasos. Lleva esto a " .. n.nombre .. " y no te entretengas.",
          final = "Justo a tiempo. Gracias por traerlo hasta aquí.",
        })
        agregar({
          id = idB, tipo = "entregar", npc = qid, destino = ciudad, item = carta, cantidad = 1, nivel = nivel, dif = "normal", esfuerzo = esfuerzo * 1.2,
          requiere = idA,
          titulo = "Respuesta para " .. M.npcs[ciudad].nombre,
          texto = "Lleva la carta de " .. n.nombre .. " a " .. M.npcs[ciudad].nombre .. " (" .. M.npcs[ciudad].lugar .. ").",
          dialogo = "Quiero que esta carta llegue a " .. M.npcs[ciudad].nombre .. ". Es importante.",
          final = "Ah, la respuesta que esperaba. Toma por las molestias.",
        })
      end
    end
  end
end

-- ------------------------------------------------------------------------------------------------ consulta (servidor y juego)
function M.nombreNpc(qid)
  local n = M.npcs[qid]
  return n and n.nombre or tostring(qid)
end

-- Cuántas unidades lleva el jugador de un objeto.
local function contar(p, id)
  local n = 0
  for _, s in ipairs(p.bolsa or {}) do if s.id == id then n = n + (s.cant or 1) end end
  return n
end
M.contar = contar

-- Avance de una misión para quien la tiene: cazar = bajas; recolectar = trofeos en la bolsa; entregar = tiene el objeto.
function M.progreso(p, q, st)
  if q.tipo == "recolectar" then return math.min(q.cantidad, contar(p, q.item)) end
  if q.tipo == "entregar" then return math.min(q.cantidad, contar(p, q.item)) end
  return math.min(q.cantidad, (st and st.progreso) or 0)
end

function M.completa(p, q, st)
  return M.progreso(p, q, st) >= q.cantidad
end

function M.estado(p, q)
  local st = p.misiones and p.misiones[q.id]
  if st and st.entregada then return "entregada", st end
  if st and st.aceptada then
    if M.completa(p, q, st) then return "lista", st end
    return "activa", st
  end
  return "nueva", st
end

-- ¿Puede aceptarla? Devuelve nil o el motivo.
function M.puedeAceptar(p, q)
  if q.requiere then
    local prev = p.misiones and p.misiones[q.requiere]
    if not (prev and prev.entregada) then
      local d = M.por_id[q.requiere]
      return "Antes debes completar: " .. (d and d.titulo or q.requiere) .. "."
    end
  end
  if (p.nivel or 1) < M.nivelMinimo(q) then return "Necesitas nivel " .. M.nivelMinimo(q) .. "." end
  return nil
end

-- Lo que ve el jugador sobre un PNJ de misiones: "!" si tiene algo nuevo que ofrecer, "?" si puedes entregar algo allí.
function M.marcaNpc(p, qid)
  if not p or not p.misiones then return nil end
  local marca
  for _, q in ipairs(M.lista) do
    local est = M.estado(p, q)
    if q.destino == qid and est == "lista" then return "?" end
    if q.npc == qid and est == "nueva" and not M.puedeAceptar(p, q) then marca = "!" end
  end
  return marca
end

-- Dónde hay que ir ahora para esta misión: lista de puntos { x, y, tipo = "npc"|"criatura", texto }.
-- Para cazar o recolectar, los campamentos de la criatura (los más cercanos al jugador primero).
function M.destinos(p, q, st)
  local lista = {}
  local est = M.estado(p, q)
  local function npc(qid, texto)
    local n = M.npcs[qid]
    if n then lista[#lista + 1] = { x = n.x, y = n.y, tipo = "npc", texto = texto or n.nombre, lugar = n.lugar } end
  end
  if est == "nueva" then npc(q.npc, "Habla con " .. M.nombreNpc(q.npc)) return lista end
  if est == "lista" or q.tipo == "entregar" then npc(q.destino, (q.tipo == "entregar" and "Entrega a " or "Vuelve con ") .. M.nombreNpc(q.destino)) return lista end
  local mon = q.tipo == "recolectar" and q.de or q.monstruo
  local def = Datos.monstruo(mon)
  local camps = M.camps[mon]
  if camps and #camps > 0 then
    local px, py = p.x or 0, p.y or 0
    local copia = {}
    for _, c in ipairs(camps) do copia[#copia + 1] = c end
    table.sort(copia, function(a, b) return distancia(px, py, a.x, a.y) < distancia(px, py, b.x, b.y) end)
    for i = 1, math.min(4, #copia) do
      lista[#lista + 1] = { x = copia[i].x, y = copia[i].y, tipo = "criatura", texto = (def and def.nombre or mon) .. " (nivel " .. tostring(copia[i].nivel or (def and def.nivel) or "?") .. ")" }
    end
  end
  return lista
end

return M
