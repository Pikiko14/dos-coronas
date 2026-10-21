-- Asedio: un MOBA sencillo entre Albor y Umbra, como tercer evento de guerra (junto a la batalla por cristales y la captura del estandarte; mismas colas, avisos y premios).
-- Se juega en un mapa de Free Angels Online (prototipo: el de M.CANDIDATOS que mejor deje separados tres carriles; ya se hará uno propio con el editor).
--   * TRES CARRILES (superior, central e inferior) unen las dos bases. Cada equipo tiene un NEXO y DOS TORRES en cada carril.
--   * El nexo es invulnerable hasta que el equipo rival abra DOS carriles (las dos torres de ese carril derribadas).
--   * Cada pocos segundos salen oleadas de esbirros por cada carril, que avanzan hacia el nexo enemigo atacando lo que encuentren.
--   * Todos empiezan en el nivel 1 (sin equipo ni árbol) y suben hasta el 18 dentro de la partida; los poderes se van desbloqueando con el nivel y mejoran de rango.
--     Al terminar recuperas tu nivel, tu experiencia y tus poderes. Se gana experiencia con el tiempo, con esbirros, torres y bajas.
--   * Cada base tiene una fuente: cura a los suyos que estén cerca. Morir te devuelve a tu base tras unos segundos.
--   * Gana quien destruya el nexo enemigo; si se acaba el tiempo, el que más puntos tenga (torres, esbirros y bajas).
-- Las bases y los carriles salen de las propias casillas del mapa (el mayor continente de casillas), no hace falta nada a mano.
local Mapa = require("compartido.dominio.mapa")
local Util = require("compartido.dominio.util")

local M = {}

M.CANDIDATOS = { "granja_de_pinchos", "pozo_sin_fondo", "decierto_ardiente", "graveyar", "canal_mariam", "minas_de_la_muerte", "riprap" }
M.PRIMERA_OLEADA = 6                     -- segundos hasta la primera oleada
M.OLEADA_CADA = 22                       -- segundos entre oleadas
M.OLEADA_N = 2                           -- esbirros por oleada, equipo y carril (crece uno cada 5 oleadas)
M.MAX_ESBIRROS = 70                      -- tope de esbirros vivos a la vez
M.NEXO = { hp = 3200 }
M.TORRE = { hp = 1300, atk = 42, nivel = 6, alcance = 6.5, cada = 1.8 }
M.ESBIRRO = { hp = 170, atk = 13, def = 3, spd = 2.7, rango = 1.5 }
M.ESBIRROS = { albor = "seta_azul", umbra = "calabaza" }
M.FUENTE = { radio = 4.5, cura = 0.08 }  -- fracción de vida por segundo cerca del propio nexo
M.PUNTOS = { esbirro = 1, jugador = 10, torre = 100, nexo = 500 }
M.CARRILES_PARA_NEXO = 2                 -- carriles que hay que abrir para poder dañar el nexo
M.NOMBRES_CARRIL = { "Superior", "Central", "Inferior" }
-- progresión dentro de la partida
M.NIVEL_MAX = 18
M.DESBLOQUEO = { 1, 3, 5, 7, 9, 11, 13, 14, 16, 18 }     -- nivel al que se desbloquea cada poder de la barra (los 4 últimos solo los tiene el mago)
M.RANGO_CADA = 5                         -- cada 5 niveles tras desbloquearlo, el poder sube de rango (máximo 3)
M.XP_TIEMPO = 2.5                        -- experiencia por segundo para todos
M.XP = { esbirro = 22, torre = 90, baja = 130, baja_equipo = 40 }

-- Experiencia que hace falta para pasar del nivel n al siguiente.
function M.xpPara(n) return 40 + 28 * n end

function M.instalar(Mundo)
  local function nombreEquipo(f) return f == "albor" and "Albor" or "Umbra" end

  -- ---------------------------------------------------------------------------------------------------------- arena y carriles
  local function libre3(mapa, x, y)
    for dx = -1, 1 do for dy = -1, 1 do
      if not Mapa.transitable(mapa, x + dx, y + dy) then return false end
    end end
    return mapa.suelo[x][y] ~= "agua"
  end

  -- La casilla del continente (libre y con margen) más cercana a (tx, ty).
  local function casillaCerca(mapa, tx, ty)
    local w, h = mapa.w, mapa.h
    local id = mapa.continente.id
    local mejor, md
    for y = 3, h - 4 do
      for x = 3, w - 4 do
        if mapa.comp[y * w + x] == id and libre3(mapa, x, y) then
          local d = (x - tx) ^ 2 + (y - ty) ^ 2
          if not md or d < md then mejor, md = { x = x, y = y }, d end
        end
      end
    end
    return mejor
  end

  local function unir(a, b)
    local r = {}
    for _, p in ipairs(a) do r[#r + 1] = p end
    for i, p in ipairs(b) do
      if not (i == 1 and r[#r] and r[#r].x == p.x and r[#r].y == p.y) then r[#r + 1] = p end
    end
    return r
  end

  -- Tapa temporalmente un pasillo alrededor del carril central (salvo cerca de las bases) para que el carril superior y el inferior no vayan por el mismo sitio.
  local function tapar(mapa, ruta, radio, margen)
    local guardado = {}
    for i = margen, #ruta - margen do
      local c = ruta[i]
      for dx = -radio, radio do
        for dy = -radio, radio do
          local x, y = math.floor(c.x) + dx, math.floor(c.y) + dy
          if mapa.bloque[x] and mapa.bloque[x][y] == nil and dx * dx + dy * dy <= radio * radio then
            guardado[#guardado + 1] = { x, y }
            mapa.bloque[x][y] = true
          end
        end
      end
    end
    return guardado
  end

  local function destapar(mapa, guardado)
    for _, c in ipairs(guardado) do mapa.bloque[c[1]][c[2]] = nil end
  end

  -- Calcula las bases y los tres carriles de un mapa; devuelve la arena y su puntuación (qué tan separados quedan los carriles) o nil.
  local function trazarArena(mapa)
    if not (mapa and mapa.comp and mapa.continente) then return nil end
    local w, h = mapa.w, mapa.h
    local id = mapa.continente.id
    local a, b
    for y = 2, h - 3 do
      for x = 2, w - 3 do
        if mapa.comp[y * w + x] == id and libre3(mapa, x, y) then
          local fy = math.abs(y - h / 2)
          if not a or x < a.x - 3 or (x <= a.x + 3 and fy < a.fy) then a = { x = x, y = y, fy = fy } end
          if not b or x > b.x + 3 or (x >= b.x - 3 and fy < b.fy) then b = { x = x, y = y, fy = fy } end
        end
      end
    end
    if not a or not b or b.x - a.x < w * 0.4 then return nil end
    local central = Mapa.buscar(mapa, a.x, a.y, b.x, b.y)
    if not central or #central < 50 then return nil end
    local carriles = { nil, { nombre = M.NOMBRES_CARRIL[2], ruta = central }, nil }
    -- los otros dos pasan por un punto lejos del central: arriba (y pequeña) y abajo (y grande)
    local tapado = tapar(mapa, central, 7, 26)
    local resultado = {}
    for k, fy in ipairs({ 0.16, 0.84 }) do
      local punto = casillaCerca(mapa, (a.x + b.x) / 2, h * fy)
      local ruta
      if punto then
        local r1 = Mapa.buscar(mapa, a.x, a.y, punto.x, punto.y)
        local r2 = r1 and Mapa.buscar(mapa, punto.x, punto.y, b.x, b.y)
        if r1 and r2 then ruta = unir(r1, r2) end
      end
      resultado[k] = ruta
    end
    destapar(mapa, tapado)
    for k = 1, 2 do
      -- sin pasillo propio: va por el central (se juega igual, solo que los carriles se superponen)
      carriles[k == 1 and 1 or 3] = { nombre = M.NOMBRES_CARRIL[k == 1 and 1 or 3], ruta = resultado[k] or central }
    end
    -- puntuación: separación media de los carriles superior e inferior respecto al central (a mitad de camino)
    local function sep(ruta)
      local suma, n = 0, 0
      for i = math.floor(#central * 0.25), math.floor(#central * 0.75), 4 do
        local c = central[i]
        local md = 1e9
        for j = 1, #ruta, 3 do
          local d = (ruta[j].x - c.x) ^ 2 + (ruta[j].y - c.y) ^ 2
          if d < md then md = d end
        end
        suma, n = suma + math.sqrt(md), n + 1
      end
      return n > 0 and suma / n or 0
    end
    local puntuacion = math.min(sep(carriles[1].ruta), sep(carriles[3].ruta))
    return { carriles = carriles, a = a, b = b, puntuacion = puntuacion }
  end

  -- Prepara el mapa de la arena (una sola vez y bajo demanda: es un cálculo de unos instantes): elige el mapa candidato que mejor separe los carriles y coloca las bases.
  function Mundo:asegurarArenaMoba()
    if self._arenaMoba ~= nil then return self._arenaMoba end
    self._arenaMoba = false
    local mejor, mapaMejor
    for _, nombre in ipairs(M.CANDIDATOS) do
      local mapa = self.mapas[nombre]
      local t = trazarArena(mapa)
      if t and (not mejor or t.puntuacion > mejor.puntuacion) then mejor, mapaMejor = t, mapa end
      if mejor and mejor.puntuacion >= 14 then break end         -- ya sirve de sobra: no hace falta probar más
    end
    if not mejor then return false end
    local mapa = mapaMejor
    local central = mejor.carriles[2].ruta
    local n = #central
    mapa.spawns = mapa.spawns or {}
    mapa.spawns.albor = { x = central[3].x, y = central[3].y }
    mapa.spawns.umbra = { x = central[n - 2].x, y = central[n - 2].y }
    local function en(ruta, frac) return ruta[math.max(1, math.min(#ruta, math.floor(#ruta * frac + 0.5)))] end
    self.moba = {
      mapa = mapa, carriles = mejor.carriles, puntuacion = mejor.puntuacion,
      nexo = { albor = central[6], umbra = central[n - 5] },
      torres = {},
    }
    for ci, c in ipairs(mejor.carriles) do
      self.moba.torres[ci] = { albor = { en(c.ruta, 0.2), en(c.ruta, 0.36) }, umbra = { en(c.ruta, 0.8), en(c.ruta, 0.64) } }
    end
    self.mapas.moba = mapa
    self._arenaMoba = true
    return true
  end

  -- Quita todo lo del asedio (estructuras y esbirros).
  function Mundo:limpiarMoba()
    for id, e in pairs(self.entidades) do
      if e.moba then self.entidades[id] = nil end
    end
    if self.moba then self.moba.nexos, self.moba.torreras = nil, nil end
    local inst = self.instancia.moba
    if inst then inst.torres, inst.nexoPct, inst.carriles, inst.nexoProt, inst.oleadaEn = nil, nil, nil, nil, nil end
  end

  -- Coloca nexos y torres y reinicia las oleadas (al empezar una edición).
  function Mundo:armarMoba()
    if not self:asegurarArenaMoba() then return false end
    self:limpiarMoba()
    local m = self.moba
    m.nexos, m.torreras, m.oleada = {}, {}, 0
    m.proxima = self.tiempo + M.PRIMERA_OLEADA
    m.fuente = self.tiempo + 1
    m.xpT = self.tiempo + 1
    for _, f in ipairs({ "albor", "umbra" }) do
      local pos = m.nexo[f]
      local e = {
        id = self:idNuevo(), kind = "altar", nombre = "Nexo de " .. nombreEquipo(f), faccion = f, x = pos.x, y = pos.y, modo = "moba", z = 0, vivo = true,
        hp = M.NEXO.hp, hpMax = M.NEXO.hp, def = 0, estructura = true, moba = true, nexo = true, invulnerable = true,
      }
      self.entidades[e.id] = e
      m.nexos[f] = e
      m.torreras[f] = {}
    end
    for ci, c in ipairs(m.carriles) do
      for _, f in ipairs({ "albor", "umbra" }) do
        for i, pos in ipairs(m.torres[ci][f]) do
          local t = {
            id = self:idNuevo(), kind = "estatua", nombre = "Torre " .. i .. " " .. c.nombre:lower() .. " de " .. nombreEquipo(f), faccion = f, x = pos.x, y = pos.y, modo = "moba", z = 0,
            vivo = true, hp = M.TORRE.hp, hpMax = M.TORRE.hp, def = 10, atk = M.TORRE.atk, nivel = M.TORRE.nivel, estructura = true, moba = true, torre = true,
            carril = ci, cds = {}, sensor = 0,
          }
          self.entidades[t.id] = t
          m.torreras[f][#m.torreras[f] + 1] = t
        end
      end
    end
    return true
  end

  -- ---------------------------------------------------------------------------------------------------------- nivel y poderes dentro de la partida
  -- Rango de un poder según el nivel de la partida (0 = sin desbloquear).
  local function rangoMoba(nivel, slot)
    local d = M.DESBLOQUEO[slot]
    if not d or nivel < d then return 0 end
    return math.min(3, 1 + math.floor((nivel - d) / M.RANGO_CADA))
  end

  function Mundo:habilidadesMoba(p)
    local Datos = require("compartido.dominio.datos")
    local barra = Datos.barra[p.clase]
    local h = {}
    for slot, id in ipairs(barra or {}) do
      local r = rangoMoba(p.nivel, slot)
      if r > 0 then h[id] = r end
    end
    return h
  end

  -- Al entrar: el jugador empieza de cero (nivel 1, sin experiencia y con solo el primer poder); su nivel, experiencia y poderes reales se guardan aparte.
  function Mundo:prepararMoba(p)
    if p.kind ~= "jugador" or p.mobaOrig then return end
    p.mobaOrig = { nivel = p.nivel, xp = p.xp, habilidades = p.habilidades, hp = p.hp, mp = p.mp }
    p.nivel, p.xp = 1, 0
    p.habilidades = self:habilidadesMoba(p)
    p.cds = {}
    self:recalcular(p)
    p.hp, p.mp = p.hpMax, p.mpMax
    self:marcarProgreso(p)
  end

  -- Al salir (acabe como acabe): vuelve lo que tenía.
  function Mundo:restaurarMoba(p)
    local o = p.mobaOrig
    if not o then return end
    p.mobaOrig = nil
    p.nivel, p.xp, p.habilidades = o.nivel, o.xp, o.habilidades
    p.cds = {}
    self:recalcular(p)
    p.hp, p.mp = p.hpMax, p.mpMax
    self:marcarProgreso(p)
  end

  -- Experiencia de la partida: sube de nivel hasta el 18 y desbloquea o mejora poderes.
  function Mundo:xpMoba(p, cant)
    if not p.mobaOrig or p.nivel >= M.NIVEL_MAX then return end
    p.xp = (p.xp or 0) + cant
    local subio = false
    while p.nivel < M.NIVEL_MAX and p.xp >= M.xpPara(p.nivel) do
      p.xp = p.xp - M.xpPara(p.nivel)
      p.nivel = p.nivel + 1
      subio = true
      local Datos = require("compartido.dominio.datos")
      local antes = p.habilidades
      p.habilidades = self:habilidadesMoba(p)
      local nuevos = {}
      for _, id in ipairs(Datos.barra[p.clase] or {}) do
        if (p.habilidades[id] or 0) > (antes[id] or 0) then
          local d = Datos.habilidades[id]
          nuevos[#nuevos + 1] = (d and d.nombre or id) .. ((antes[id] or 0) > 0 and (" (rango " .. p.habilidades[id] .. ")") or "")
        end
      end
      local vida = p.hp / math.max(1, p.hpMax)
      self:recalcular(p)
      p.hp = math.min(p.hpMax, math.floor(p.hpMax * math.max(vida, 0.35) + 0.5))
      self:mensaje("sistema", "", "¡Nivel " .. p.nivel .. "!" .. (#nuevos > 0 and (" Desbloqueas: " .. table.concat(nuevos, ", ") .. ".") or ""), p)
      self:efecto("nivel", p.x, p.y, 0.8)
    end
    if p.nivel >= M.NIVEL_MAX then p.xp = 0 end
    if subio then self:marcarProgreso(p) end
  end

  -- ---------------------------------------------------------------------------------------------------------- esbirros, torres y fuente
  local function oleada(self, f)
    local m = self.moba
    local vivos = 0
    for _, e in pairs(self.entidades) do if e.moba and e.kind == "monstruo" then vivos = vivos + 1 end end
    local cant = M.OLEADA_N + math.floor(m.oleada / 5)
    local fuerza = 1 + math.min(0.7, m.oleada * 0.04)
    local nivel = math.min(12, 2 + m.oleada)
    for ci, c in ipairs(m.carriles) do
      local dir = f == "albor" and 1 or -1
      local base = f == "albor" and 10 or (#c.ruta - 9)
      for i = 1, cant do
        if vivos >= M.MAX_ESBIRROS then return end
        local idx = base + dir * (i - 1) * 2
        local pos = c.ruta[math.max(1, math.min(#c.ruta, idx))]
        local e = self:spawnMonstruo(M.ESBIRROS[f], pos.x, pos.y, nil, nivel)
        if e then
          vivos = vivos + 1
          e.modo, e.faccion, e.moba, e.agresivo, e.elite = "moba", f, true, false, nil
          e.nombre = "Esbirro de " .. nombreEquipo(f)
          e.hp, e.hpMax = math.floor(M.ESBIRRO.hp * fuerza), math.floor(M.ESBIRRO.hp * fuerza)
          e.atk, e.matk, e.def, e.mdef, e.spd, e.rango = M.ESBIRRO.atk * fuerza, M.ESBIRRO.atk * fuerza, M.ESBIRRO.def, M.ESBIRRO.def, M.ESBIRRO.spd, M.ESBIRRO.rango
          e.nivel = nivel
          e.carril, e.mobaIdx, e.mobaDir = ci, idx, dir
          e.xp, e.oro = 0, 0
        end
      end
    end
  end

  local function enemigoDe(self, e, o)
    return o.vivo and not o.borrar and o.modo == "moba" and o.faccion and o.faccion ~= e.faccion and not o.staff
  end

  -- IA de un esbirro: ataca lo más cercano que sea enemigo (esbirros y jugadores primero, estructuras si no hay otra cosa) y si no sigue su carril hacia el nexo enemigo.
  function Mundo:actualizarEsbirroMoba(e, dt)
    if (e.aturdido or 0) > 0 then e.aturdido = e.aturdido - dt return end
    e.sensor = (e.sensor or 0) - dt
    if e.sensor <= 0 then
      e.sensor = 0.4
      local mejor, md = nil, 1e9
      for _, o in pairs(self.entidades) do
        if o.moba or o.kind == "jugador" or o.kind == "bot" then
          if enemigoDe(self, e, o) then
            local d = Util.dist(e.x, e.y, o.x, o.y)
            local alcanza = (o.estructura and 3.2) or 5.5
            if o.nexo and o.invulnerable then alcanza = 0 end         -- no pierde el tiempo con un nexo protegido
            local pesada = d + (o.estructura and 1.5 or 0)
            if d <= alcanza and pesada < md then mejor, md = o, pesada end
          end
        end
      end
      e.mobaObjetivo = mejor and mejor.id or nil
    end
    local o = e.mobaObjetivo and self.entidades[e.mobaObjetivo]
    local dx, dy = 0, 0
    if o and o.vivo and not o.borrar then
      local d = Util.dist(e.x, e.y, o.x, o.y)
      if d <= e.rango + 0.4 then
        if not e.tramo then self:encarar(e, o.x - e.x, o.y - e.y) end
        if ((e.cds or {}).auto or 0) <= self.tiempo then
          e.cds = e.cds or {}
          e.cds.auto = self.tiempo + 1.2
          self:golpear(e, o, 1)
        end
      else
        dx, dy = o.x - e.x, o.y - e.y
      end
    else
      e.mobaObjetivo = nil
      local carril = self.moba and self.moba.carriles[e.carril or 2]
      local ruta = carril and carril.ruta
      if ruta then
        local destino = ruta[math.max(1, math.min(#ruta, e.mobaIdx + e.mobaDir * 3))]
        if Util.dist(e.x, e.y, destino.x, destino.y) < 1.3 then e.mobaIdx = e.mobaIdx + e.mobaDir * 2 end
        dx, dy = destino.x - e.x, destino.y - e.y
      end
    end
    local ddx, ddy = 0, 0
    if dx ~= 0 or dy ~= 0 then
      if e.tramo then ddx, ddy = (dx > 0 and 1 or dx < 0 and -1 or 0), (dy > 0 and 1 or dy < 0 and -1 or 0)
      else ddx, ddy = self:mejorDireccion(e, dx, dy) end
    end
    local vel = e.spd or 2.5
    if e.lentitud and e.lentitud.hasta > self.tiempo then vel = vel * (1 - e.lentitud.mul) end
    self:avanzar(e, dt, ddx, ddy, vel)
  end

  -- Torres: disparan flechas al enemigo más cercano a su alcance (esbirros antes que jugadores).
  local function torres(self, dt)
    for _, f in ipairs({ "albor", "umbra" }) do
      for _, t in ipairs(self.moba.torreras[f]) do
        if t.vivo then
          t.sensor = t.sensor - dt
          if t.sensor <= 0 and (t.cds.auto or 0) <= self.tiempo then
            t.sensor = 0.3
            local mejor, md = nil, 1e9
            for _, o in pairs(self.entidades) do
              if o.moba or o.kind == "jugador" or o.kind == "bot" then
                if enemigoDe(self, t, o) and not o.estructura then
                  local d = Util.dist(t.x, t.y, o.x, o.y)
                  local pesada = d + ((o.kind == "jugador" or o.kind == "bot") and 3 or 0)       -- prefiere esbirros
                  if d <= M.TORRE.alcance and pesada < md and self:lineaLibre(t, o) then mejor, md = o, pesada end
                end
              end
            end
            if mejor then
              t.cds.auto = self.tiempo + M.TORRE.cada
              self:proyectil(t, mejor, { coef = 1, dano = "fisico", proyectil = "flecha" })
            end
          end
        end
      end
    end
  end

  -- Torres en pie y carriles abiertos (las dos torres del carril derribadas) de un equipo.
  local function estadoEquipo(self, f)
    local m = self.moba
    local vivas, porCarril = 0, {}
    for _, t in ipairs(m.torreras[f]) do
      if t.vivo then vivas = vivas + 1 porCarril[t.carril] = (porCarril[t.carril] or 0) + 1 end
    end
    local abiertos = 0
    for ci = 1, #m.carriles do if (porCarril[ci] or 0) == 0 then abiertos = abiertos + 1 end end
    return vivas, abiertos
  end

  -- Se llama en cada tick.
  function Mundo:actualizarMoba(dt)
    local inst = self.instancia.moba
    local m = self.moba
    if not (m and m.nexos and inst.activa and not inst.fin) then return end
    if self.tiempo >= m.proxima then
      m.oleada = m.oleada + 1
      m.proxima = self.tiempo + M.OLEADA_CADA
      oleada(self, "albor")
      oleada(self, "umbra")
      self:registrarEvento("moba", "Oleada " .. m.oleada .. " de esbirros en camino", nil)
    end
    inst.oleadaEn, inst.oleada = math.max(0, math.ceil(m.proxima - self.tiempo)), m.oleada
    torres(self, dt)
    -- el nexo es invulnerable hasta abrir los carriles necesarios; resumen para el marcador del cliente
    inst.torres, inst.nexoPct, inst.carriles, inst.nexoProt = inst.torres or {}, inst.nexoPct or {}, inst.carriles or {}, inst.nexoProt or {}
    for _, f in ipairs({ "albor", "umbra" }) do
      local vivas, abiertos = estadoEquipo(self, f)
      local protegido = abiertos < M.CARRILES_PARA_NEXO
      if m.nexos[f].invulnerable and not protegido then
        self:avisoEvento("mundo", "", "¡El nexo de " .. nombreEquipo(f) .. " queda al descubierto!", nil)
        self:registrarEvento("moba", "El nexo de " .. nombreEquipo(f) .. " está al descubierto", f == "albor" and "umbra" or "albor")
      end
      m.nexos[f].invulnerable = protegido
      inst.torres[f], inst.carriles[f], inst.nexoProt[f] = vivas, abiertos, protegido
      inst.nexoPct[f] = math.max(0, math.floor(m.nexos[f].hp / m.nexos[f].hpMax * 100))
    end
    -- experiencia con el tiempo y fuentes: curan a los suyos cerca de su nexo
    if self.tiempo >= m.xpT then
      local paso = self.tiempo - m.xpT + 1
      m.xpT = self.tiempo + 1
      for _, p in pairs(self.entidades) do
        if p.kind == "jugador" and p.modo == "moba" and p.vivo and p.mobaOrig then self:xpMoba(p, M.XP_TIEMPO * paso) end
      end
    end
    if self.tiempo >= m.fuente then
      m.fuente = self.tiempo + 1
      for _, f in ipairs({ "albor", "umbra" }) do
        local nx = m.nexos[f]
        if nx.vivo then
          for _, o in pairs(self.entidades) do
            if o.modo == "moba" and o.faccion == f and o.vivo and o.hp and o.hpMax and o.hp < o.hpMax and not o.estructura
              and (o.kind == "jugador" or o.kind == "bot" or o.moba) and Util.dist(o.x, o.y, nx.x, nx.y) <= M.FUENTE.radio then
              o.hp = math.min(o.hpMax, o.hp + math.max(1, math.floor(o.hpMax * M.FUENTE.cura)))
            end
          end
        end
      end
    end
  end

  -- Experiencia para todo el equipo (torres).
  local function xpEquipo(self, f, cant)
    for _, p in pairs(self.entidades) do
      if p.kind == "jugador" and p.modo == "moba" and p.faccion == f and p.mobaOrig then self:xpMoba(p, cant) end
    end
  end

  -- Una baja entre jugadores en el asedio: experiencia al autor y a sus compañeros cercanos.
  function Mundo:bajaMoba(autor, caido)
    if not (autor and autor.mobaOrig) then return end
    self:xpMoba(autor, M.XP.baja + (caido.nivel or 1) * 8)
    for _, p in pairs(self.entidades) do
      if p ~= autor and p.kind == "jugador" and p.modo == "moba" and p.faccion == autor.faccion and p.mobaOrig and p.vivo and Util.dist(p.x, p.y, caido.x, caido.y) < 12 then
        self:xpMoba(p, M.XP.baja_equipo)
      end
    end
  end

  -- Muerte de un esbirro, una torre o un nexo (la llama Mundo:morir).
  function Mundo:morirMoba(e, origen)
    local inst = self.instancia.moba
    local ganador = origen and origen.faccion
    local autor = origen
    if autor and autor.dueno and self.entidades[autor.dueno] then autor = self.entidades[autor.dueno] end
    if e.nexo then
      e.borrar = true
      self:avisoEvento("mundo", "", e.nombre .. " ha caído. ¡" .. nombreEquipo(ganador or "albor") .. " gana el asedio!", nil)
      self:registrarEvento("moba", e.nombre .. " destruido", ganador)
      if inst.activa and not inst.fin and ganador then
        inst.puntos[ganador] = inst.puntos[ganador] + M.PUNTOS.nexo
        self:cerrarInstancia("moba", ganador)
      end
    elseif e.torre then
      e.borrar = true
      if ganador and inst.activa then inst.puntos[ganador] = inst.puntos[ganador] + M.PUNTOS.torre end
      self:avisoEvento("mundo", "", e.nombre .. " ha caído.", nil)
      self:registrarEvento("moba", e.nombre .. " destruida", ganador)
      self:contarEvento(autor, "torres")
      if ganador then xpEquipo(self, ganador, M.XP.torre) end
      if autor and autor.kind == "jugador" then
        autor.oro = (autor.oro or 0) + 60
        self:mensaje("sistema", "", e.nombre .. " destruida. +60 de oro.", autor)
      end
    else
      -- esbirro: sin botín ni experiencia de criatura; unas monedas, puntos y experiencia de la partida para quien lo abatió
      e.borrar = true
      if ganador and inst.activa then inst.puntos[ganador] = inst.puntos[ganador] + M.PUNTOS.esbirro end
      if autor and (autor.kind == "jugador" or autor.kind == "bot") then
        self:contarEvento(autor, "esbirros")
        autor.oro = (autor.oro or 0) + 8
        if autor.mobaOrig then self:xpMoba(autor, M.XP.esbirro) end
      end
    end
  end
end

return M
