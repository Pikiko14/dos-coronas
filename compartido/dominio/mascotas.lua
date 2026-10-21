-- Mascotas: compañeras que siguen al jugador, pelean a su lado y suben de nivel con él.
-- No se les puede hacer daño ni mueren; cada especie ayuda de una manera distinta:
--   ataque (gatito): el que más pega.
--   vampiro (murciélago): cura al dueño con lo que muerde.
--   guardian (limo): reduce el daño que recibe el dueño.
--   sanador (flor): cura al dueño poco a poco.
--   mana (hada): le devuelve maná.
--   veneno (avispa): su picadura envenena.
-- Una mascota nunca pasa del nivel de su dueño.
local Util = require("compartido.dominio.util")
local Balance = require("compartido.dominio.balance")

local M = {}
require("compartido.dominio.configuracion").aplicar(M, "mascotas")


-- Las especies están en compartido/datos/mascotas.xml; el orden del archivo es el de la tienda.
M.especies, M.orden = require("compartido.dominio.configuracion").mapaOrden("mascotas", "especie", false)

function M.xpPara(nivel)
  nivel = math.max(1, nivel or 1)
  return math.floor(40 + 30 * nivel + 8 * nivel * nivel)
end

-- Ataque de una mascota de ese nivel.
function M.atk(especie, nivel)
  local d = M.especies[especie]
  return (3 + 1.7 * (nivel or 1)) * (d and d.atk or 1)
end

-- Vida y defensas de una mascota: el limo guardián aguanta más.
function M.aguante(especie, nivel)
  local d = M.especies[especie]
  nivel = nivel or 1
  local mul = (d and d.rol == "guardian") and 1.6 or 1
  return {
    hpMax = math.floor((50 + 22 * nivel) * mul),
    def = 2 + 1.4 * nivel,
    mdef = 2 + 1.1 * nivel,
  }
end


-- Reducción de daño que da el limo guardián al dueño (0 si no es esa especie).
function M.proteccion(especie, nivel)
  local d = M.especies[especie]
  if not d or d.rol ~= "guardian" then return 0 end
  return math.min(0.2, 0.06 + 0.005 * (nivel or 1))
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

  function Mundo:retirarMascota(p)
    local e = p.mascotaId and self.entidades[p.mascotaId]
    if e then e.borrar = true end
    p.mascotaId = nil
    p.mascotaBono = 0
  end

  function Mundo:adoptarMascota(p, especie)
    if p.kind ~= "jugador" then return "Solo los jugadores adoptan mascotas." end
    local d = M.especies[especie]
    if not d then return "Esa mascota no existe." end
    p.mascotas = p.mascotas or {}
    for _, m in ipairs(p.mascotas) do
      if m.especie == especie then return "Ya tienes esa mascota." end
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
    local estaba = p.mascotaActiva == idx and p.mascotaId and self.entidades[p.mascotaId]
    self:retirarMascota(p)
    if estaba then
      p.mascotaActiva = nil
      self:marcarProgreso(p)
      return nil
    end
    p.mascotaActiva = idx
    local d = M.especies[m.especie]
    local id = self:idNuevo()
    self.entidades[id] = {
      id = id, kind = "mascota", especie = m.especie, nombre = d.nombre .. " de " .. p.nombre,
      dueno = p.id, faccion = p.faccion, nivel = m.nivel,
      x = p.x, y = p.y, z = p.z or 0, modo = p.modo, casaId = p.casaId, dir = p.dir or 1,
      vivo = true, cds = {}, velx = 0, vely = 0, tipoDano = "fisico",
    }
    local ag = M.aguante(m.especie, m.nivel)
    local ent = self.entidades[id]
    ent.hpMax, ent.hp, ent.def, ent.mdef = ag.hpMax, ag.hpMax, ag.def, ag.mdef
    p.mascotaId = id
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
      local e = self.entidades[p.mascotaId]
      if e then
        local ag = M.aguante(m.especie, m.nivel)
        e.nivel, e.hpMax, e.def, e.mdef = m.nivel, ag.hpMax, ag.def, ag.mdef
        e.hp = e.hpMax
      end
      self:actualizarBonoMascota(p)
      self:marcarProgreso(p)
      self:mensaje("sistema", "", M.especies[m.especie].nombre .. " sube al nivel " .. m.nivel .. ".", p)
    end
  end

  -- La mascota hostil más cercana a la que puede atacar: el objetivo del dueño o quien lo ataque.
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

  function Mundo:actualizarMascota(e, dt)
    local dueno = self.entidades[e.dueno]
    if not dueno or dueno.mascotaId ~= e.id then e.borrar = true return end
    local m = self:mascotaActiva(dueno)
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
    local blanco = blancoDe(self, e, dueno)
    local dx, dy = 0, 0
    if blanco then
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
          self:efecto("impacto", blanco.x, blanco.y, 0.3)
          self:danar(blanco, dano, dueno, critico)
          if d.rol == "vampiro" and dueno.vivo then self:curar(dueno, math.max(1, math.floor(dano * 0.35))) end
          if d.rol == "veneno" and blanco.vivo and math.random() < 0.3 then
            self:aplicarEstado(blanco, "veneno", 5, 0.1, { id = dueno.id, atk = atk * 2.2, matk = atk * 2.2, nivel = m.nivel, tipoDano = "fisico" })
          end
        end
      end
    elseif dd > 2.4 then
      dx, dy = dueno.x - e.x, dueno.y - e.y
    end
    -- ayuda de la especie al dueño mientras pelea
    if d.rol == "sanador" and dueno.vivo and (e.cds.ayuda or 0) <= self.tiempo and dueno.hp < dueno.hpMax then
      e.cds.ayuda = self.tiempo + 5
      self:curar(dueno, math.floor(dueno.hpMax * 0.025 + 2 * m.nivel))
    elseif d.rol == "mana" and dueno.vivo and (e.cds.ayuda or 0) <= self.tiempo and dueno.mp < dueno.mpMax then
      e.cds.ayuda = self.tiempo + 4
      local v = math.floor(dueno.mpMax * 0.02 + m.nivel)
      dueno.mp = math.min(dueno.mpMax, dueno.mp + v)
      self:numero(dueno, "+" .. v .. " mp", { 0.45, 0.65, 1 })
    end
    local ddx, ddy = 0, 0
    if dx ~= 0 or dy ~= 0 then
      if e.tramo then ddx, ddy = Util.signo(dx), Util.signo(dy)
      else ddx, ddy = self:mejorDireccion(e, dx, dy) end
    end
    self:avanzar(e, dt, ddx, ddy, math.max(4.3, (dueno.spd or 4.4) * 1.08))
  end
end

return M
