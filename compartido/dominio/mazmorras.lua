-- Mazmorras: tres cuevas con su puerta en distintos puntos del mapa (la entrada se coloca en
-- Mapa.mundo). Cada una es su propio mapa (modo = "mz1", "mz2", "mz3"): salas con criaturas, un
-- jefe al fondo y, al caer, un cofre con un premio por jugador: cualquier objeto o addon del mall,
-- o un arma o armadura del escalón más alto. Se entra y se sale con la tecla de interactuar junto a
-- la puerta; los datos de cada una están en Datos.mazmorras.
local Datos = require("compartido.dominio.datos")
local Mapa = require("compartido.dominio.mapa")
local Util = require("compartido.dominio.util")
local Items = require("compartido.dominio.items")
local Mall = require("compartido.dominio.mall")

local M = {}
require("compartido.dominio.configuracion").aplicar(M, "mazmorras")


-- Planos de cada mazmorra (compartido/datos/mazmorras.xml): tamaño, la sala de entrada y la del jefe (rectángulos
-- { x, y, ancho, alto } en casillas), cuántas salas intermedias y campos de trampas lleva y la semilla con que se
-- genera. El resto (salas, pasillos y trampas) se genera con esa semilla: el mismo plano da siempre la misma
-- mazmorra, pero no es una fila de salas: hay ramas, bucles, callejones sin salida y varias rutas hasta el jefe.
local DISENOS = require("compartido.dominio.configuracion").mapaOrden("mazmorras", "plano", false)

local function tallar(mapa, r)
  for x = r[1], r[1] + r[3] - 1 do
    for y = r[2], r[2] + r[4] - 1 do
      mapa.suelo[x][y] = "mazmorra"
      mapa.bloque[x][y] = nil
    end
  end
end

local function pilar(mapa, x, y)
  for dx = 0, 1 do
    for dy = 0, 1 do
      mapa.suelo[x + dx][y + dy] = "muralla"
      mapa.bloque[x + dx][y + dy] = true
    end
  end
end

-- Trampas del suelo. Cada una es una casilla que cicla entre reposo, aviso (asoman las púas o el fuego) y activa
-- (hace daño a quien pise). La fase depende solo del reloj del mundo, así servidor y cliente la ven igual.
--   pinchos: púas que salen del suelo (golpe seco)   fuego: chorro de llamas (daño fuerte)
--   gas: nube venenosa (daño pequeño cada medio segundo mientras dure)
-- dano = fracción de la vida máxima del jugador por golpe; cada = segundos entre golpes mientras siga encima.
M.TRAMPAS = {
  pinchos = { ciclo = 3.4, aviso = 0.9, dur = 0.9, dano = 0.09, cada = 1.0 },
  fuego = { ciclo = 4.6, aviso = 1.0, dur = 1.5, dano = 0.12, cada = 0.8 },
  gas = { ciclo = 5.4, aviso = 1.2, dur = 2.4, dano = 0.035, cada = 0.5 },
}

-- Estado de una trampa en el instante t: "reposo", "aviso" o "activa".
function M.faseTrampa(tr, t)
  local d = M.TRAMPAS[tr.tipo]
  local u = (t + tr.fase) % d.ciclo
  if u >= d.ciclo - d.dur then return "activa" end
  if u >= d.ciclo - d.dur - d.aviso then return "aviso" end
  return "reposo"
end

-- Mapa de una mazmorra. grupos: sitios donde sale cada grupo de criaturas; jefe y entrada.
function M.mapa(def)
  local d = DISENOS[def.id]
  local mapa = Mapa.nuevo(d.w, d.h)
  mapa.mazmorra, mapa.tinte, mapa.nombre = def.id, def.tinte, def.nombre
  for x = 0, d.w - 1 do
    mapa.suelo[x], mapa.bioma[x], mapa.lado[x], mapa.bloque[x] = {}, {}, {}, {}
    for y = 0, d.h - 1 do
      mapa.suelo[x][y], mapa.bioma[x][y], mapa.bloque[x][y] = "muralla", "mazmorra", true
    end
  end
  -- generador pseudoaleatorio con semilla (determinista)
  local semilla = d.semilla or 1
  local function rnd()
    semilla = (semilla * 1103515245 + 12345) % 2147483648
    return semilla / 2147483648
  end
  local function entre(a, b) return a + math.floor(rnd() * (b - a + 1)) end

  local E, J = d.entrada, d.jefe
  tallar(mapa, E)
  tallar(mapa, J)
  -- salas intermedias de tamaños distintos, sin pisarse entre sí ni a la entrada ni al jefe
  local salas = {}
  local function solapa(r, o, margen)
    return r[1] < o[1] + o[3] + margen and r[1] + r[3] + margen > o[1] and r[2] < o[2] + o[4] + margen and r[2] + r[4] + margen > o[2]
  end
  local intentos = 0
  while #salas < (d.salas or 6) and intentos < 600 do
    intentos = intentos + 1
    local w, h = entre(8, 15), entre(7, 12)
    local r = { entre(3, d.w - w - 3), entre(3, d.h - h - 3), w, h }
    local ok = not solapa(r, E, 4) and not solapa(r, J, 4)
    for _, o in ipairs(salas) do if ok and solapa(r, o, 4) then ok = false end end
    if ok then salas[#salas + 1] = r end
  end
  local nodos = { E }
  for _, r in ipairs(salas) do nodos[#nodos + 1] = r end
  nodos[#nodos + 1] = J
  for _, r in ipairs(salas) do tallar(mapa, r) end
  local function centro(r) return math.floor(r[1] + r[3] / 2), math.floor(r[2] + r[4] / 2) end

  -- conexiones: árbol mínimo (todas las salas alcanzables) más algunos pasillos extra que forman bucles
  local function dist(a, b)
    local ax, ay = centro(a)
    local bx, by = centro(b)
    return math.abs(ax - bx) + math.abs(ay - by)
  end
  local unidos, aristas, par = { [1] = true }, {}, {}
  local n = #nodos
  for _ = 2, n do
    local mejor, mi, mj = math.huge, nil, nil
    for i = 1, n do
      if unidos[i] then
        for j = 1, n do
          if not unidos[j] then
            local dd = dist(nodos[i], nodos[j])
            if dd < mejor then mejor, mi, mj = dd, i, j end
          end
        end
      end
    end
    unidos[mj] = true
    aristas[#aristas + 1] = { mi, mj }
    par[mi .. "_" .. mj], par[mj .. "_" .. mi] = true, true
  end
  for i = 1, n do
    if rnd() < 0.6 then
      local mejor, mj = math.huge, nil
      for j = 1, n do
        if j ~= i and not par[i .. "_" .. j] then
          local dd = dist(nodos[i], nodos[j])
          if dd < mejor then mejor, mj = dd, j end
        end
      end
      if mj and mejor < 38 then
        aristas[#aristas + 1] = { i, mj }
        par[i .. "_" .. mj], par[mj .. "_" .. i] = true, true
      end
    end
  end
  -- pasillos de 3 casillas en L (un tramo horizontal y otro vertical, en orden al azar)
  local pasillos = {}
  for _, ar in ipairs(aristas) do
    local ax, ay = centro(nodos[ar[1]])
    local bx, by = centro(nodos[ar[2]])
    local tramos = {}
    if rnd() < 0.5 then
      tramos[1] = { math.min(ax, bx) - 1, ay - 1, math.abs(bx - ax) + 3, 3, "h" }
      tramos[2] = { bx - 1, math.min(ay, by) - 1, 3, math.abs(by - ay) + 3, "v" }
    else
      tramos[1] = { ax - 1, math.min(ay, by) - 1, 3, math.abs(by - ay) + 3, "v" }
      tramos[2] = { math.min(ax, bx) - 1, by - 1, math.abs(bx - ax) + 3, 3, "h" }
    end
    for _, tr in ipairs(tramos) do
      tallar(mapa, tr)
      pasillos[#pasillos + 1] = tr
    end
  end
  -- pilares en las esquinas de las salas grandes, solo donde no estorban a ningún pasillo
  local function sobrePasillo(x, y)
    for _, tr in ipairs(pasillos) do
      if x + 1 >= tr[1] - 1 and x <= tr[1] + tr[3] and y + 1 >= tr[2] - 1 and y <= tr[2] + tr[4] then return true end
    end
    return false
  end
  for _, r in ipairs(salas) do
    if r[3] >= 11 and r[4] >= 11 then
      for _, q in ipairs({ { r[1] + 3, r[2] + 3 }, { r[1] + r[3] - 5, r[2] + 3 }, { r[1] + 3, r[2] + r[4] - 5 }, { r[1] + r[3] - 5, r[2] + r[4] - 5 } }) do
        if not sobrePasillo(q[1], q[2]) then pilar(mapa, q[1], q[2]) end
      end
    end
  end

  mapa.grupos = {}
  for _, r in ipairs(salas) do
    local cx, cy = centro(r)
    mapa.grupos[#mapa.grupos + 1] = { x = cx + 0.5, y = cy + 0.5 }
    mapa.grupos[#mapa.grupos + 1] = { x = r[1] + r[3] * 0.25, y = cy + 0.5 }
    mapa.grupos[#mapa.grupos + 1] = { x = r[1] + r[3] * 0.75, y = cy + 0.5 }
  end
  -- ningún grupo puede salir sobre un pilar o una pared: se desplaza a la casilla libre más cercana
  local function suelo(x, y) return x >= 1 and y >= 1 and x < d.w - 1 and y < d.h - 1 and not mapa.bloque[x][y] and mapa.suelo[x][y] == "mazmorra" end
  for _, g in ipairs(mapa.grupos) do
    if not suelo(math.floor(g.x), math.floor(g.y)) then
      local hallado
      for r = 1, 6 do
        for dy = -r, r do
          for dx = -r, r do
            if not hallado and suelo(math.floor(g.x) + dx, math.floor(g.y) + dy) then hallado = { math.floor(g.x) + dx, math.floor(g.y) + dy } end
          end
        end
        if hallado then break end
      end
      if hallado then g.x, g.y = hallado[1] + 0.5, hallado[2] + 0.5 end
    end
  end
  local j = J
  pilar(mapa, j[1] + 3, j[2] + j[4] - 6)
  pilar(mapa, j[1] + j[3] - 5, j[2] + j[4] - 6)
  mapa.jefe = { x = j[1] + j[3] / 2, y = j[2] + 3.5 }
  mapa.grupos[#mapa.grupos + 1] = { x = j[1] + j[3] * 0.3, y = j[2] + j[4] * 0.6 }
  mapa.grupos[#mapa.grupos + 1] = { x = j[1] + j[3] * 0.7, y = j[2] + j[4] * 0.6 }
  local e = E
  local cx = e[1] + math.floor(e[3] / 2)
  mapa.entrada = { x = cx + 0.5, y = e[2] + e[4] - 2.5 }
  mapa.salida = { x = cx + 0.5, y = e[2] + e[4] - 1.5 }
  mapa.props[#mapa.props + 1] = { x = cx, y = e[2] + e[4] - 1, tipo = "puerta_mazmorra", mz = def.id, salida = true }

  -- trampas: campos en los pasillos (hay que cruzarlos con el compás justo) y salpicadas por las salas
  mapa.trampas, mapa.trampasIdx = {}, {}
  local function libre(x, y)
    if x < 1 or y < 1 or x >= d.w - 1 or y >= d.h - 1 then return false end
    if mapa.bloque[x][y] or mapa.suelo[x][y] ~= "mazmorra" or mapa.trampasIdx[x * 1000 + y] then return false end
    if x >= E[1] - 1 and x <= E[1] + E[3] and y >= E[2] - 1 and y <= E[2] + E[4] then return false end   -- ni en la entrada
    return true
  end
  local function poner(x, y, tipo, fase)
    if not libre(x, y) then return end
    local tr = { x = x, y = y, tipo = tipo, fase = fase }
    mapa.trampas[#mapa.trampas + 1] = tr
    mapa.trampasIdx[x * 1000 + y] = tr
  end
  local TIPOS = { "pinchos", "fuego", "gas" }
  for k = 1, d.trampas or 10 do
    local tipo = TIPOS[((k - 1) % 3) + 1]
    if k % 2 == 1 and #pasillos > 0 then
      -- campo de 3 de ancho en medio de un pasillo (casillas desfasadas: una ola de púas o llamas)
      local tr = pasillos[entre(1, #pasillos)]
      local largo = tr[5] == "h" and tr[3] or tr[4]
      if largo > 12 then
        local pos = entre(5, largo - 6)
        for a = 0, entre(1, 2) - 1 do
          for b = 0, 2 do
            local x, y
            if tr[5] == "h" then x, y = tr[1] + pos + a, tr[2] + b else x, y = tr[1] + b, tr[2] + pos + a end
            poner(x, y, tipo, (a * 0.7 + b * 0.25) % 2 + k * 0.37)
          end
        end
      end
    elseif #salas > 0 then
      -- salpicadas dentro de una sala (no en la entrada)
      local r = salas[entre(1, #salas)]
      for _ = 1, entre(3, 6) do
        poner(entre(r[1] + 1, r[1] + r[3] - 2), entre(r[2] + 1, r[2] + r[4] - 2), tipo, rnd() * 4)
      end
    end
  end
  return mapa
end

function M.instalar(Mundo)
  -- Mapas propios de cada mazmorra (se añaden a self.mapas con su id como clave).
  function Mundo:crearMapasMazmorras()
    for _, def in ipairs(Datos.mazmorras) do self.mapas[def.id] = M.mapa(def) end
  end

  -- Trampas del suelo: quien pisa una casilla activa recibe un golpe (un porcentaje de su vida máxima) y, mientras
  -- siga encima, otro cada pocos instantes. Solo afecta a los jugadores.
  function Mundo:trampasMazmorra(e)
    local mapa = self.mapas[e.modo]
    local idx = mapa and mapa.trampasIdx
    if not idx or not e.vivo then return end
    local tr = idx[math.floor(e.x) * 1000 + math.floor(e.y)]
    if not tr or M.faseTrampa(tr, self.tiempo) ~= "activa" then return end
    if (e.trampaHasta or 0) > self.tiempo then return end
    local d = M.TRAMPAS[tr.tipo]
    e.trampaHasta = self.tiempo + d.cada
    local antes = e.hp
    self:danar(e, (e.hpMax or 100) * d.dano, nil, false)
    if e.hp < antes then
      self:mensaje("sistema", "", ({ pinchos = "¡Pinchos!", fuego = "¡Llamas!", gas = "¡Gas venenoso!" })[tr.tipo], e)
    end
  end

  function Mundo:enMazmorra(e)
    local m = e and self.mapas[e.modo]
    return m and m.mazmorra and Datos.mazmorra(m.mazmorra) or nil
  end

  -- Criaturas y jefe de cada mazmorra.
  function Mundo:poblarMazmorras()
    for _, def in ipairs(Datos.mazmorras) do
      local mapa = self.mapas[def.id]
      for i, g in ipairs(mapa.grupos) do
        local mon = def.monstruos[((i - 1) % #def.monstruos) + 1]
        local cant = 3
        for k = 1, cant do
          local a = (k / cant) * math.pi * 2
          local e = self:spawnMonstruo(mon[1], g.x + math.cos(a) * 1.6, g.y + math.sin(a) * 1.6, nil, mon[2])
          if e then e.modo, e.mz = def.id, def.id end
        end
      end
      local jd = def.jefe
      local jefe = self:spawnMonstruo(jd.monstruo, mapa.jefe.x, mapa.jefe.y, nil, jd.nivel)
      if jefe then
        jefe.modo, jefe.mz, jefe.jefeMz = def.id, def.id, true
        jefe.nombre, jefe.elite = jd.nombre, true
        jefe.hpMax = math.floor(jefe.hpMax * jd.vida)
        jefe.hp = jefe.hpMax
        jefe.atk = jefe.atk * jd.dano
        jefe.matk = jefe.matk * jd.dano
        jefe.def = jefe.def * 1.2
        jefe.mdef = jefe.mdef * 1.2
        jefe.agresivo = true
      end
    end
  end

  -- ¿Hay una puerta de mazmorra a mano? Devuelve su definición y su sitio.
  function Mundo:puertaMazmorraCerca(p)
    for _, z in ipairs(self.mapas.mundo.mazmorras or {}) do
      if Util.dist(p.x, p.y, z.x + 0.5, z.y + 0.5) < 2.6 then return z, Datos.mazmorra(z.id) end
    end
  end

  function Mundo:entrarMazmorra(p, z, def)
    if p.kind ~= "jugador" then return "Solo los jugadores entran en las mazmorras." end
    if p.modo ~= "mundo" or (p.z or 0) > 0 then return "No puedes entrar desde aquí." end
    if (p.nivel or 1) < def.nivelMin then
      return def.nombre .. " pide nivel " .. def.nivelMin .. " (tienes " .. (p.nivel or 1) .. ")."
    end
    if (p.ultimoGolpe or -10) + 4 > self.tiempo then return "No puedes entrar en pleno combate." end
    local mapa = self.mapas[def.id]
    p.retorno = { x = z.x + 0.5, y = z.y + 1.8, modo = "mundo" }
    p.modo, p.casaId, p.z = def.id, nil, 0
    p.zona = def.nombre
    p.x, p.y = mapa.entrada.x, mapa.entrada.y
    p.objetivo, p.camino, p.persigue = nil, nil, false
    self:mensaje("sistema", "", "Entras en " .. def.nombre .. " (nivel " .. def.nivelMin .. "+). Al fondo hay un jefe con un cofre. Sal por la puerta con E.", p)
    return nil
  end

  function Mundo:salirMazmorra(p)
    local def = self:enMazmorra(p)
    if not def then return end
    local r = p.retorno or p.vinculo
    p.modo, p.z, p.casaId = "mundo", 0, nil
    p.x, p.y = r.x, r.y
    p.objetivo, p.camino, p.persigue = nil, nil, false
    p.zona = nil
    self:mensaje("sistema", "", "Sales de " .. def.nombre .. ".", p)
  end

  -- El jefe cae: respawn lento y un cofre en el sitio donde murió.
  function Mundo:jefeMazmorraCae(jefe, origen)
    local def = Datos.mazmorra(jefe.mz)
    if not def then return end
    jefe.respawn = self.tiempo + M.RESPAWN_JEFE
    local id = self:idNuevo()
    self.entidades[id] = {
      id = id, kind = "cofre_mz", nombre = "Cofre de " .. def.nombre, x = jefe.x, y = jefe.y, z = 0,
      modo = jefe.modo, vivo = true, hasta = self.tiempo + M.DURA_COFRE, reclamado = {}, mz = def.id,
    }
    self:anunciar(jefe.nombre .. " ha caído en " .. def.nombre .. (origen and origen.nombre and (" a manos de " .. origen.nombre) or "") .. ".")
    for _, e in pairs(self.entidades) do
      if e.kind == "jugador" and e.modo == jefe.modo and e.vivo then
        self:mensaje("sistema", "", "¡Un cofre de premio ha aparecido! Acércate y pulsa E (dura " .. M.DURA_COFRE .. " s).", e)
      end
    end
  end

  -- Cuando reaparece el jefe, la mazmorra se reinicia: vuelven todas las criaturas caídas.
  function Mundo:reiniciarMazmorra(id)
    for _, e in pairs(self.entidades) do
      if e.kind == "monstruo" and e.mz == id and not e.vivo and not e.jefeMz then self:revivir(e) end
    end
    for _, e in pairs(self.entidades) do
      if e.kind == "jugador" and e.modo == id and e.vivo then
        self:mensaje("sistema", "", "La mazmorra se ha reiniciado: las criaturas han vuelto.", e)
      end
    end
  end

  -- Reparte el premio de p: lo que toca cae al suelo junto al cofre (solo p puede recogerlo un buen rato). Los
  -- addons y las monedas del mall se entregan al momento. Devuelve true y el texto de lo que cae.
  function Mundo:premioMazmorra(p, x, y)
    local r = math.random()
    local texto
    local base = { dueno = p.id, grupo = p.grupoId, hasta = self.tiempo + M.DURA_BOTIN }
    local function suelo(extra)
      local t = {}
      for k, v in pairs(base) do t[k] = v end
      for k, v in pairs(extra) do t[k] = v end
      self:dejarEnSuelo(t, x or p.x, y or p.y, p.modo, p.z)
    end
    if r < M.PROB_ADDON then
      local libres = {}
      for _, id in ipairs(Mall.ORDEN_ADDONS) do
        if not (p.addons and p.addons[id]) then libres[#libres + 1] = id end
      end
      if #libres > 0 then
        local id = libres[math.random(#libres)]
        p.addons = p.addons or {}
        p.addons[id] = true
        texto = "el addon " .. Mall.ADDONS[id].nombre .. " (ya es tuyo, pruébalo en el Item Mall)"
      else
        p.monedas = (p.monedas or 0) + 150
        texto = "150 " .. Mall.MONEDA .. " (ya tenías todos los addons)"
      end
    else
      local id
      if r < M.PROB_ADDON + M.PROB_MALL then
        local lista = {}
        for _, o in ipairs(Mall.OBJETOS) do
          if Datos.item(o.id) and not o.polvo then lista[#lista + 1] = o end
        end
        id = lista[math.random(#lista)].id
      else
        -- equipo del escalón máximo de cualquier oficio
        id = Items.aleatorioCualquiera(Datos, #Items.TIER, math.random)
      end
      local def = Datos.item(id)
      suelo({ oro = 0, items = { { id = id, cant = 1 } }, item = id, nombre = def and def.nombre or "Objeto" })
      texto = (def and def.nombre or id)
    end
    suelo({ oro = M.ORO_COFRE, items = {}, nombre = "Oro" })
    return true, texto
  end

  -- Abrir el cofre: el premio de cada jugador que está en la mazmorra cae al suelo junto a él y el cofre desaparece.
  function Mundo:reclamarCofre(p, cofre)
    if not p.vivo or cofre.borrar then return end
    for _, e in pairs(self.entidades) do
      if e.kind == "jugador" and e.modo == cofre.modo and e.vivo then
        local ok, texto = self:premioMazmorra(e, cofre.x, cofre.y)
        if ok then
          self:marcarProgreso(e)
          self:mensaje("sistema", "", "¡El cofre se abre! Cae al suelo: " .. texto .. " y " .. M.ORO_COFRE .. " de oro. Recógelos antes de que se pierdan.", e)
        end
      end
    end
    cofre.vivo, cofre.borrar = false, true
    self:sonar("cura")
  end

  -- E dentro de una mazmorra: abrir el cofre cercano o salir por la puerta.
  function Mundo:interactuarMazmorra(p)
    for _, e in pairs(self.entidades) do
      if e.kind == "cofre_mz" and e.modo == p.modo and Util.dist(p.x, p.y, e.x, e.y) < 2.6 then
        self:reclamarCofre(p, e)
        return { panel = nil }
      end
    end
    local mapa = self.mapas[p.modo]
    if Util.dist(p.x, p.y, mapa.salida.x, mapa.salida.y) < 3.2 then
      self:salirMazmorra(p)
      return { panel = nil }
    end
    self:mensaje("sistema", "", "Aquí no hay nada. La puerta de salida está en la sala de entrada.", p)
    return { panel = nil }
  end

  -- E en el mundo junto a una puerta de mazmorra.
  function Mundo:interactuarPuertaMazmorra(p)
    local z, def = self:puertaMazmorraCerca(p)
    if not z then return nil end
    local err = self:entrarMazmorra(p, z, def)
    if err then self:mensaje("sistema", "", err, p) end
    return { panel = nil }
  end
end

return M
