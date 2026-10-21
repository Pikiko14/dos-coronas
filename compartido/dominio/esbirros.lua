-- Esbirros del nigromante: criaturas invocadas que siguen a su dueño y atacan a sus enemigos un tiempo.
-- No sufren daño: desaparecen al acabar el tiempo del poder, si su dueño cae, se desconecta o entra en una
-- guerra. Lo que pegan sale del ataque mágico de su dueño (compartido/datos/esbirros.xml: coef, cd, rango).
local Util = require("compartido.dominio.util")
local Balance = require("compartido.dominio.balance")
local Config = require("compartido.dominio.configuracion")

local M = {}
Config.aplicar(M, "esbirros")
M.especies = Config.mapa("esbirros", "esbirro", false)

function M.instalar(Mundo)

  -- Esbirros vivos de un jugador (más antiguos primero).
  function Mundo:esbirrosDe(p)
    local lista = {}
    for _, e in pairs(self.entidades) do
      if e.kind == "esbirro" and e.dueno == p.id and not e.borrar then lista[#lista + 1] = e end
    end
    table.sort(lista, function(a, b) return a.id < b.id end)
    return lista
  end

  function Mundo:retirarEsbirros(p)
    for _, e in ipairs(self:esbirrosDe(p)) do e.borrar = true end
  end

  -- Invoca h.cantidad esbirros de la especie h.esbirro durante h.dur segundos. Si se pasa del máximo, los más
  -- antiguos se desvanecen para dejar sitio.
  function Mundo:invocarEsbirros(p, h)
    local d = M.especies[h.esbirro]
    if not d then return end
    local cantidad = h.cantidad or 1
    local vivos = self:esbirrosDe(p)
    local sobran = #vivos + cantidad - M.MAX
    for i = 1, math.max(0, sobran) do
      if vivos[i] then vivos[i].borrar = true end
    end
    for i = 1, cantidad do
      local id = self:idNuevo()
      local e = {
        id = id, kind = "esbirro", especie = h.esbirro, nombre = d.nombre .. " de " .. p.nombre,
        dueno = p.id, faccion = p.faccion, nivel = p.nivel, pot = h.pot or 1,
        x = p.x, y = p.y, z = p.z or 0, modo = p.modo, casaId = p.casaId, dir = p.dir or 1,
        vivo = true, cds = {}, velx = 0, vely = 0, tipoDano = "magico",
        hasta = self.tiempo + (h.dur or 30),
      }
      self.entidades[id] = e
      self:colocarCerca(e, p.x + (i - 1.5) * 0.9, p.y + 0.8)
      self:efecto("alzar_esqueletos", e.x, e.y, 0.5)
    end
  end

  -- El blanco de un esbirro: el objetivo de su dueño o quien lo esté atacando.
  local function blancoDe(self, e, dueno)
    local t = dueno.objetivo and self.entidades[dueno.objetivo]
    if t and t.vivo and self:mismoLugar(e, t) and self:puedeDanar(dueno, t) and t.kind ~= "estatua" and t.kind ~= "puerta" then
      return t
    end
    local mejor, md = nil, 6
    for _, o in pairs(self.entidades) do
      if o.kind == "monstruo" and o.vivo and o.objetivo == dueno.id and self:mismoLugar(e, o) then
        local dd = Util.dist(e.x, e.y, o.x, o.y)
        if dd < md then mejor, md = o, dd end
      end
    end
    return mejor
  end

  function Mundo:actualizarEsbirro(e, dt)
    local dueno = self.entidades[e.dueno]
    if not dueno or not dueno.vivo or self.tiempo >= (e.hasta or 0)
      or dueno.modo == "batalla" or dueno.modo == "estandarte" or dueno.modo == "moba" then
      e.borrar = true
      return
    end
    if not self:mismoLugar(e, dueno) then
      e.modo, e.casaId, e.z = dueno.modo, dueno.casaId, dueno.z or 0
      e.tramo = nil
      self:colocarCerca(e, dueno.x, dueno.y)
    end
    local dd = Util.dist(e.x, e.y, dueno.x, dueno.y)
    if dd > M.DISTANCIA_MAX then self:colocarCerca(e, dueno.x, dueno.y) dd = 0 end
    local d = M.especies[e.especie]
    local blanco = blancoDe(self, e, dueno)
    local dx, dy = 0, 0
    if blanco then
      local dist = Util.dist(e.x, e.y, blanco.x, blanco.y)
      if dist > d.rango - 0.1 then
        dx, dy = blanco.x - e.x, blanco.y - e.y
      end
      if dist <= d.rango + 0.2 then
        if not e.tramo then self:encarar(e, blanco.x - e.x, blanco.y - e.y) end
        if (e.cds.ataque or 0) <= self.tiempo then
          e.cds.ataque = self.tiempo + d.cd
          local atk = (dueno.matk or dueno.atk or 1) * d.coef * (e.pot or 1)
          local dano, critico = Balance.tirarDano(atk, blanco.mdef or 0, 1)
          dano = math.max(1, math.floor(dano * Balance.modNivel(dueno.nivel, blanco.nivel) + 0.5))
          self:efecto(d.proyectil and "toque_necro" or "impacto", blanco.x, blanco.y, 0.35)
          self:danar(blanco, dano, dueno, critico)
        end
      end
    elseif dd > M.DISTANCIA_SEGUIR then
      dx, dy = dueno.x - e.x, dueno.y - e.y
    end
    local ddx, ddy = 0, 0
    if dx ~= 0 or dy ~= 0 then
      if e.tramo then ddx, ddy = Util.signo(dx), Util.signo(dy)
      else ddx, ddy = self:mejorDireccion(e, dx, dy) end
    end
    self:avanzar(e, dt, ddx, ddy, math.max(4.2, (dueno.spd or 4.4) * d.vel))
  end
end

return M
