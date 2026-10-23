-- Mascotas de ataque como las de Free Angels Online: siguen al jugador, pelean a su lado, suben de nivel con él y EVOLUCIONAN SOLAS al llegar a ciertos niveles
-- (mascotas.xml: cada forma apunta a la siguiente con evo y evoNivel). El osito se compra con oro en la tienda del mercado; el dragón, las dos pelusas y las
-- recolectoras (que recogen el botín por ti), con Monedas Corona en el Item Mall. Una mascota nunca pasa del nivel de su dueño.
-- Se pueden tener fuera DOS a la vez: una de ataque (p.mascotaActiva / p.mascotaId) y una recolectora (p.recolectoraActiva / p.recolectoraId).
-- La recolectora es invulnerable y no ataca a nadie: solo recoge el botín.
local Util = require("compartido.dominio.util")
local Balance = require("compartido.dominio.balance")

local M = {}
require("compartido.dominio.configuracion").aplicar(M, "mascotas")


-- Las especies están en compartido/datos/mascotas.xml; el orden del archivo es el de la tienda.
local todas, ordenTodas = require("compartido.dominio.configuracion").mapaOrden("mascotas", "especie", false)
M.especies = todas
-- La tienda del mercado vende con oro la forma inicial de las líneas que no son del mall; el Item Mall, las suyas y las recolectoras (ORDEN_MALL).
M.orden, M.ORDEN_MALL = {}, {}
for _, id in ipairs(ordenTodas) do
  local d = todas[id]
  if (d.etapa or 1) == 1 then
    if d.mall then M.ORDEN_MALL[#M.ORDEN_MALL + 1] = id else M.orden[#M.orden + 1] = id end
  end
end
-- Las recolectoras del Item Mall (se pagan con Monedas Corona) tienen su propio elemento en el XML.
local recolectoras, ordenRec = require("compartido.dominio.configuracion").mapaOrden("mascotas", "recolectora", false)
for id, d in pairs(recolectoras) do M.especies[id] = d end
for _, id in ipairs(ordenRec) do M.ORDEN_MALL[#M.ORDEN_MALL + 1] = id end

-- ¿Es la misma línea de evolución (o la misma recolectora)? Solo se puede tener una mascota de cada línea.
function M.mismaLinea(a, b)
  local x, y = M.especies[a], M.especies[b]
  if not (x and y) then return a == b end
  return (x.linaje or a) == (y.linaje or b)
end

-- ¿Es una recolectora (las del Item Mall que recogen el botín)?
function M.esRecolectora(especie)
  local d = M.especies[especie]
  return d ~= nil and d.radio ~= nil
end

function M.xpPara(nivel)
  nivel = math.max(1, nivel or 1)
  return math.floor(40 + 30 * nivel + 8 * nivel * nivel)
end

-- Ataque de una mascota de ese nivel.
function M.atk(especie, nivel)
  local d = M.especies[especie]
  return (3 + 1.7 * (nivel or 1)) * (d and d.atk or 1)
end

-- Vida y defensas de una mascota: crecen con la etapa.
function M.aguante(especie, nivel)
  local d = M.especies[especie]
  nivel = nivel or 1
  local mul = 1 + 0.25 * ((d and d.etapa or 1) - 1)
  return {
    hpMax = math.floor((50 + 22 * nivel) * mul),
    def = 2 + 1.4 * nivel,
    mdef = 2 + 1.1 * nivel,
  }
end

-- (Ya no hay mascotas que protejan al dueño: todas son de ataque.)
function M.proteccion() return 0 end

-- La forma a la que evoluciona una mascota concreta si ya tiene el nivel (o nil).
function M.siguienteForma(m)
  local d = M.especies[m.especie]
  if not (d and d.evo and M.especies[d.evo] and (m.nivel or 1) >= (d.evoNivel or 99)) then return nil end
  return d.evo
end

function M.instalar(Mundo)

  function Mundo:mascotaActiva(p)
    return p.mascotaActiva and p.mascotas and p.mascotas[p.mascotaActiva] or nil
  end

  -- Recalcula lo que la mascota activa da al dueño (la protección del limo).
  function Mundo:actualizarBonoMascota(p)
    local m = self:mascotaActiva(p)
    p.mascotaBono = (m and p.mascotaId and M.proteccion(m.especie, m.nivel)) or 0
  end

  -- La mascota cae: se desmaya y su dueño la recupera tras un descanso.
  function Mundo:caeMascota(e)
    local dueno = self.entidades[e.dueno]
    e.borrar = true
    if dueno and dueno.mascotaId == e.id then
      dueno.mascotaId = nil
      dueno.mascotaBono = 0
      dueno.mascotaDescanso = self.tiempo + M.DESCANSO_SEG
      self:mensaje("sistema", "", e.nombre .. " se desmaya. Volverá en " .. M.DESCANSO_SEG .. " segundos.", dueno)
    end
  end

  -- Guarda la mascota de ataque ("ataque"), la recolectora ("recolectora") o las dos (sin argumento).
  function Mundo:retirarMascota(p, cual)
    if cual ~= "recolectora" then
      local e = p.mascotaId and self.entidades[p.mascotaId]
      if e then e.borrar = true end
      p.mascotaId = nil
      p.mascotaBono = 0
    end
    if cual ~= "ataque" then
      local r = p.recolectoraId and self.entidades[p.recolectoraId]
      if r then r.borrar = true end
      p.recolectoraId = nil
    end
  end

  function Mundo:adoptarMascota(p, especie)
    if p.kind ~= "jugador" then return "Solo los jugadores adoptan mascotas." end
    local d = M.especies[especie]
    if not d then return "Esa mascota no existe." end
    if d.mall then return "Esa mascota solo se compra en el Item Mall." end
    if (d.etapa or 1) > 1 then return "Esa forma solo se consigue evolucionando." end
    p.mascotas = p.mascotas or {}
    for _, m in ipairs(p.mascotas) do
      if M.mismaLinea(m.especie, especie) then return "Ya tienes esa mascota." end
    end
    if #p.mascotas >= M.MAX_MASCOTAS then return "No puedes cuidar más mascotas." end
    if (p.nivel or 1) < d.nivel then return "Necesitas nivel " .. d.nivel .. "." end
    if (p.oro or 0) < d.precio then return "Cuesta " .. d.precio .. " de oro." end
    p.oro = p.oro - d.precio
    p.mascotas[#p.mascotas + 1] = { especie = especie, nivel = 1, xp = 0 }
    self:marcarProgreso(p)
    self:mensaje("sistema", "", d.nombre .. " se une a ti.", p)
    return nil
  end

  -- Llama a la mascota número idx (o la guarda si ya estaba fuera).
  function Mundo:invocarMascota(p, idx)
    if p.kind ~= "jugador" then return end
    idx = tonumber(idx)
    local m = idx and p.mascotas and p.mascotas[idx]
    if not m then return "No tienes esa mascota." end
    -- hay dos ranuras: la de ataque y la de recolectora; invocar una no toca la otra
    local rec = M.esRecolectora(m.especie)
    local campoActiva, campoId = rec and "recolectoraActiva" or "mascotaActiva", rec and "recolectoraId" or "mascotaId"
    local estaba = p[campoActiva] == idx and p[campoId] and self.entidades[p[campoId]]
    self:retirarMascota(p, rec and "recolectora" or "ataque")
    if estaba then
      p[campoActiva] = nil
      self:marcarProgreso(p)
      return nil
    end
    if not rec then self:evolucionarMascota(p, m) end
    p[campoActiva] = idx
    local d = M.especies[m.especie]
    local id = self:idNuevo()
    self.entidades[id] = {
      id = id, kind = "mascota", especie = m.especie, nombre = d.nombre .. " de " .. p.nombre,
      dueno = p.id, faccion = p.faccion, nivel = m.nivel, reg = m, recolectora = rec or nil, invulnerable = rec or nil,
      x = p.x, y = p.y, z = p.z or 0, modo = p.modo, casaId = p.casaId, dir = p.dir or 1,
      vivo = true, cds = {}, velx = 0, vely = 0, tipoDano = "fisico",
    }
    local ag = M.aguante(m.especie, m.nivel)
    local ent = self.entidades[id]
    ent.hpMax, ent.hp, ent.def, ent.mdef = ag.hpMax, ag.hpMax, ag.def, ag.mdef
    p[campoId] = id
    self:colocarCerca(self.entidades[id], p.x, p.y)
    self:actualizarBonoMascota(p)
    self:marcarProgreso(p)
    return nil
  end

  function Mundo:mascotaGanaXp(p, exp)
    local m = self:mascotaActiva(p)
    if not m or not p.mascotaId then return end
    if m.nivel >= math.min(M.NIVEL_MAX, p.nivel or 1) then return end
    m.xp = (m.xp or 0) + math.floor(exp * 0.6)
    local subio = false
    while m.nivel < math.min(M.NIVEL_MAX, p.nivel or 1) and m.xp >= M.xpPara(m.nivel) do
      m.xp = m.xp - M.xpPara(m.nivel)
      m.nivel = m.nivel + 1
      subio = true
    end
    if subio then
      self:mensaje("sistema", "", M.especies[m.especie].nombre .. " sube al nivel " .. m.nivel .. ".", p)
      self:evolucionarMascota(p, m)
      self:refrescarMascota(p, m)
      self:actualizarBonoMascota(p)
      self:marcarProgreso(p)
    end
  end

  -- Pone la entidad de la mascota activa al día con su forma, nivel y aguante.
  function Mundo:refrescarMascota(p, m)
    local e = p.mascotaId and self.entidades[p.mascotaId]
    if not e then return end
    local d = M.especies[m.especie]
    local ag = M.aguante(m.especie, m.nivel)
    e.especie, e.nombre = m.especie, d.nombre .. " de " .. p.nombre
    e.nivel, e.hpMax, e.def, e.mdef = m.nivel, ag.hpMax, ag.def, ag.mdef
    e.hp = e.hpMax
  end

  -- Evolución automática: si la mascota ya tiene el nivel de su forma, pasa a la siguiente (y otra vez, si también cumple la nueva).
  function Mundo:evolucionarMascota(p, m)
    local evolucion = false
    for _ = 1, 3 do
      local sig = M.siguienteForma(m)
      if not sig then break end
      local antes = M.especies[m.especie]
      m.especie = sig
      evolucion = true
      self:mensaje("sistema", "", "¡" .. antes.nombre .. " evoluciona y se convierte en " .. M.especies[sig].nombre .. "!", p)
    end
    if evolucion then
      self:refrescarMascota(p, m)
      self:marcarProgreso(p)
    end
    return evolucion
  end

  -- La mascota hostil más cercana a la que puede atacar: el objetivo del dueño o quien lo ataque.
  -- Dónde espera una mascota junto a su dueño: detrás de él y a un lado (la de ataque a la izquierda, la recolectora a la derecha), para que no se amontonen.
  local DIR_MUNDO = { [1] = { 0, 1 }, [2] = { 0, -1 }, [3] = { 1, 0 }, [4] = { -1, 0 } }
  local function puestoSeguir(e, dueno)
    local v = DIR_MUNDO[dueno.dir or 1] or DIR_MUNDO[1]
    local lado = e.recolectora and -1 or 1
    return dueno.x - v[1] * 1.7 - v[2] * lado * 1.1, dueno.y - v[2] * 1.7 + v[1] * lado * 1.1
  end

  -- Empujón para separarse de quien tiene demasiado cerca (su dueño, otros jugadores y las demás mascotas).
  local function separacion(self, e)
    local rx, ry = 0, 0
    for _, o in pairs(self.entidades) do
      if o ~= e and o.vivo and (o.kind == "jugador" or o.kind == "bot" or o.kind == "mascota") and self:mismoLugar(e, o) then
        local d = Util.dist(e.x, e.y, o.x, o.y)
        if d < 1.05 then
          if d < 0.05 then rx, ry = rx + (e.id % 2 == 0 and 1 or -1), ry + 0.5
          else rx, ry = rx + (e.x - o.x) / d * (1.05 - d), ry + (e.y - o.y) / d * (1.05 - d) end
        end
      end
    end
    return rx, ry
  end

  local function blancoDe(self, e, dueno)
    local t = dueno.objetivo and self.entidades[dueno.objetivo]
    if t and t.vivo and self:mismoLugar(e, t) and self:puedeDanar(dueno, t) and t.kind ~= "estatua" and t.kind ~= "puerta" then
      return t
    end
    local mejor, md = nil, 5
    for _, o in pairs(self.entidades) do
      if o.kind == "monstruo" and o.vivo and o.objetivo == dueno.id and self:mismoLugar(e, o) then
        local d = Util.dist(e.x, e.y, o.x, o.y)
        if d < md then mejor, md = o, d end
      end
    end
    return mejor
  end

  -- El botín más cercano al dueño que él mismo podría recoger y que está dentro del radio de la mascota.
  function Mundo:botinParaMascota(e, dueno, radio)
    if not dueno.vivo then return nil end
    local mejor, md = nil, radio
    for _, o in pairs(self.entidades) do
      if o.kind == "loot" and o.vivo and not o.borrar and self:mismoLugar(e, o)
        and (not o.dueno or o.dueno == dueno.id or (o.grupo and dueno.grupoId == o.grupo) or self.tiempo > (o.hasta or 0) - 20)
        and ((e.ignorar and e.ignorar[o.id]) or 0) <= self.tiempo then
        local d = Util.dist(dueno.x, dueno.y, o.x, o.y)
        if d < md then mejor, md = o, d end
      end
    end
    return mejor
  end

  function Mundo:actualizarMascota(e, dt)
    local dueno = self.entidades[e.dueno]
    local propia = dueno and ((e.recolectora and dueno.recolectoraId == e.id) or (not e.recolectora and dueno.mascotaId == e.id))
    if not propia then e.borrar = true return end
    local m = e.reg
    if not m then e.borrar = true return end
    -- en las guerras no hay mascotas: vuelve al terminar
    if dueno.modo == "batalla" or dueno.modo == "estandarte" or dueno.modo == "moba" then self:retirarMascota(dueno) return end
    if not self:mismoLugar(e, dueno) then
      e.modo, e.casaId, e.z = dueno.modo, dueno.casaId, dueno.z or 0
      e.tramo = nil
      self:colocarCerca(e, dueno.x, dueno.y)
    end
    local dd = Util.dist(e.x, e.y, dueno.x, dueno.y)
    if dd > 12 then self:colocarCerca(e, dueno.x, dueno.y) dd = 0 end
    -- se recupera sola si lleva un rato sin recibir golpes
    if e.hp < e.hpMax and (self.tiempo - (e.ultimoGolpe or -10)) > 5 then
      e.hp = math.min(e.hpMax, e.hp + e.hpMax * 0.04 * dt)
    end
    if not dueno.vivo then return end
    local d = M.especies[m.especie]
    e.cds = e.cds or {}
    local blanco = (not e.recolectora) and blancoDe(self, e, dueno) or nil       -- (la recolectora no ataca a nadie)
    local dx, dy = 0, 0
    local botin = d.radio and self:botinParaMascota(e, dueno, d.radio)
    if botin then
      -- recolectora: va a por el botín de su dueño y se lo mete en la bolsa
      local dist = Util.dist(e.x, e.y, botin.x, botin.y)
      if not e.buscaBotin or e.buscaBotin.id ~= botin.id then e.buscaBotin = { id = botin.id, desde = self.tiempo } end
      if self.tiempo - e.buscaBotin.desde > 5 and dist > 1.0 and not e.buscaBotin.salto then
        e.buscaBotin.salto = true
        self:colocarCerca(e, botin.x, botin.y)         -- atascada (un muro en medio): se planta junto al botín
        dist = Util.dist(e.x, e.y, botin.x, botin.y)
      end
      if dist <= 1.0 or (e.buscaBotin.salto and dist <= 2.4) then
        self:recoger(dueno, botin)
        if not botin.borrar then
          e.ignorar = e.ignorar or {}
          e.ignorar[botin.id] = self.tiempo + 12      -- (bolsa llena u otra razón: no insiste)
        end
        e.buscaBotin = nil
      else
        dx, dy = botin.x - e.x, botin.y - e.y
      end
    else
      e.buscaBotin = nil
    end
    if botin then
      -- (ya va a por el botín: no pelea ni vuelve con el dueño hasta terminar)
    elseif blanco then
      local dist = Util.dist(e.x, e.y, blanco.x, blanco.y)
      if dist > 1.45 then
        dx, dy = blanco.x - e.x, blanco.y - e.y
      else
        if not e.tramo then self:encarar(e, blanco.x - e.x, blanco.y - e.y) end
        if (e.cds.ataque or 0) <= self.tiempo then
          e.cds.ataque = self.tiempo + 1.5
          local atk = M.atk(m.especie, m.nivel)
          local dano, critico = Balance.tirarDano(atk, blanco.def or 0, 1)
          dano = math.max(1, math.floor(dano * Balance.modNivel(m.nivel, blanco.nivel) + 0.5))
          self:marcarAtaque(e, blanco, false, true)
          self:efecto("impacto", blanco.x, blanco.y, 0.3)
          self:danar(blanco, dano, dueno, critico)
        end
      end
    else
      -- sigue a su dueño hacia su sitio (detrás y a un lado); si ya está cerca, se queda quieta
      local px, py = puestoSeguir(e, dueno)
      if dd > 2.8 or Util.dist(e.x, e.y, px, py) > 2.0 then dx, dy = px - e.x, py - e.y end
    end
    -- sin nada que hacer, que no se solape con su dueño ni con otras mascotas
    if dx == 0 and dy == 0 then
      local rx, ry = separacion(self, e)
      if rx ~= 0 or ry ~= 0 then dx, dy = rx, ry end
    end
    local ddx, ddy = 0, 0
    if dx ~= 0 or dy ~= 0 then
      if e.tramo then ddx, ddy = Util.signo(dx), Util.signo(dy)
      else ddx, ddy = self:mejorDireccion(e, dx, dy) end
    end
    self:avanzar(e, dt, ddx, ddy, math.max(4.3, (dueno.spd or 4.4) * 1.08) * (d.radio and 1.35 or 1))
  end
end

return M
