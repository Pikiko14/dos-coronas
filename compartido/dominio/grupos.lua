-- Grupos (party): hasta 5 jugadores de una misma corona que cazan juntos.
--   * El que invita crea el grupo; hay líder (invita, expulsa, pasa el mando) y miembros.
--   * Al matar una criatura, la experiencia se reparte a partes iguales entre los miembros que están
--     cerca, con un +10 % de experiencia total por ir en grupo (de dos o más cerca). El oro, el
--     progreso de los encargos y el botín también se comparten.
--   * Cerca de los grupos salen criaturas "de grupo" y gigantes (ver encuentros.lua).
-- Los grupos viven solo mientras sus miembros están conectados.
local Util = require("compartido.dominio.util")
local Balance = require("compartido.dominio.balance")

local M = {}
require("compartido.dominio.configuracion").aplicar(M, "grupos")


function M.instalar(Mundo)
  function Mundo:iniciarGrupos()
    self.grupos = self.grupos or {}
    self.siguienteGrupo = self.siguienteGrupo or 1
  end

  function Mundo:grupoDe(p)
    self:iniciarGrupos()
    return p.grupoId and self.grupos[p.grupoId] or nil
  end

  -- Jugadores conectados de un grupo.
  function Mundo:miembrosGrupo(g)
    local lista = {}
    for _, id in ipairs(g.miembros) do
      local e = self.entidades[id]
      if e and not e.borrar and e.kind == "jugador" then lista[#lista + 1] = e end
    end
    return lista
  end

  local function quitar(self, g, id)
    for i, m in ipairs(g.miembros) do
      if m == id then table.remove(g.miembros, i) break end
    end
    local e = self.entidades[id]
    if e then e.grupoId = nil end
    if #g.miembros < 2 then
      -- un grupo de uno no es grupo
      for _, otro in ipairs(g.miembros) do
        local e2 = self.entidades[otro]
        if e2 then
          e2.grupoId = nil
          self:mensaje("sistema", "", "El grupo se disuelve.", e2)
        end
      end
      self.grupos[g.id] = nil
      return
    end
    if g.lider == id then
      -- si se va el líder, el mando pasa al siguiente y el grupo lo sabe
      g.lider = g.miembros[1]
      local nuevo = self.entidades[g.lider]
      if nuevo then
        for _, m in ipairs(self:miembrosGrupo(g)) do
          self:mensaje("grupo", "Grupo", nuevo.nombre .. " es el nuevo líder.", m)
        end
      end
    end
  end

  -- ------------------------------------------------------------------ invitar y responder
  function Mundo:invitarGrupo(p, objetivoId)
    self:iniciarGrupos()
    if p.kind ~= "jugador" then return "Solo los jugadores forman grupo." end
    local g = self:grupoDe(p)
    if g and g.lider ~= p.id then return "Solo el líder invita." end
    local o = self.entidades[objetivoId]
    if not o or o.kind ~= "jugador" or not o.vivo or o == p then return "No hay nadie a quien invitar." end
    if o.faccion ~= p.faccion then return "Solo puedes agrupar con tu corona." end
    if o.grupoId then return o.nombre .. " ya está en un grupo." end
    if g and #g.miembros >= M.MAX then return "El grupo está lleno (" .. M.MAX .. ")." end
    if not self:mismoLugar(p, o) or Util.dist(p.x, p.y, o.x, o.y) > 20 then return o.nombre .. " está demasiado lejos." end
    o.invitacionGrupo = { de = p.id, nombre = p.nombre, hasta = self.tiempo + M.INVITACION_SEG }
    self:mensaje("sistema", "", p.nombre .. " te invita a su grupo. Acepta o rechaza en el panel de grupo (tecla J).", o)
    self:mensaje("sistema", "", "Invitación enviada a " .. o.nombre .. ".", p)
    return nil
  end

  function Mundo:responderInvitacionGrupo(p, acepta)
    local inv = p.invitacionGrupo
    p.invitacionGrupo = nil
    if not inv then return "No tienes invitaciones." end
    if not acepta then return nil end
    if inv.hasta < self.tiempo then return "La invitación caducó." end
    self:iniciarGrupos()
    local anfitrion = self.entidades[inv.de]
    if not anfitrion or anfitrion.borrar then return "Quien te invitó ya no está." end
    if p.grupoId then return "Ya estás en un grupo." end
    local g = self:grupoDe(anfitrion)
    if not g then
      g = { id = self.siguienteGrupo, lider = anfitrion.id, miembros = { anfitrion.id }, creado = self.tiempo }
      self.siguienteGrupo = g.id + 1
      self.grupos[g.id] = g
      anfitrion.grupoId = g.id
    end
    if #g.miembros >= M.MAX then return "El grupo está lleno." end
    g.miembros[#g.miembros + 1] = p.id
    p.grupoId = g.id
    for _, m in ipairs(self:miembrosGrupo(g)) do
      self:mensaje("grupo", "Grupo", p.nombre .. " se une al grupo.", m)
    end
    return nil
  end

  function Mundo:salirGrupo(p)
    local g = self:grupoDe(p)
    if not g then return "No estás en un grupo." end
    quitar(self, g, p.id)
    -- el resto del grupo (si sigue existiendo) se entera de quién se va
    local resto = self.grupos[g.id] and self:miembrosGrupo(g) or {}
    for _, m in ipairs(resto) do
      self:mensaje("grupo", "Grupo", p.nombre .. " sale del grupo.", m)
    end
    self:mensaje("sistema", "", "Sales del grupo.", p)
    return nil
  end

  function Mundo:expulsarGrupo(p, id)
    local g = self:grupoDe(p)
    if not g then return "No estás en un grupo." end
    if g.lider ~= p.id then return "Solo el líder expulsa." end
    if id == p.id then return "Para irte, usa Salir." end
    local en = false
    for _, m in ipairs(g.miembros) do if m == id then en = true end end
    if not en then return "Ese jugador no está en tu grupo." end
    local e = self.entidades[id]
    quitar(self, g, id)
    if e then self:mensaje("sistema", "", "Te han expulsado del grupo.", e) end
    return nil
  end

  function Mundo:ascenderGrupo(p, id)
    local g = self:grupoDe(p)
    if not g then return "No estás en un grupo." end
    if g.lider ~= p.id then return "Solo el líder pasa el mando." end
    local e = self.entidades[id]
    if not e or e.grupoId ~= g.id or e == p then return "Ese jugador no es válido." end
    g.lider = id
    for _, m in ipairs(self:miembrosGrupo(g)) do
      self:mensaje("grupo", "Grupo", e.nombre .. " es el nuevo líder.", m)
    end
    return nil
  end

  function Mundo:disolverGrupo(p)
    local g = self:grupoDe(p)
    if not g then return "No estás en un grupo." end
    if g.lider ~= p.id then return "Solo el líder disuelve el grupo." end
    for _, m in ipairs(self:miembrosGrupo(g)) do
      m.grupoId = nil
      self:mensaje("sistema", "", "El grupo se ha disuelto.", m)
    end
    self.grupos[g.id] = nil
    return nil
  end

  -- Quita del grupo a quien se desconectó y caduca invitaciones.
  function Mundo:actualizarGrupos(dt)
    self._grupoT = (self._grupoT or 0) + dt
    if self._grupoT < 2 then return end
    self._grupoT = 0
    self:iniciarGrupos()
    local vacios
    for id, g in pairs(self.grupos) do
      for i = #g.miembros, 1, -1 do
        local e = self.entidades[g.miembros[i]]
        if not e or e.borrar or e.kind ~= "jugador" then table.remove(g.miembros, i) end
      end
      if #g.miembros < 2 then
        vacios = vacios or {}
        vacios[#vacios + 1] = g
      elseif not self.entidades[g.lider] then
        g.lider = g.miembros[1]
      end
    end
    for _, g in ipairs(vacios or {}) do
      for _, id in ipairs(g.miembros) do
        local e = self.entidades[id]
        if e then
          e.grupoId = nil
          self:mensaje("sistema", "", "El grupo se disuelve.", e)
        end
      end
      self.grupos[g.id] = nil
    end
  end

  -- ------------------------------------------------------------------ reparto
  -- Miembros del grupo de p que están cerca y vivos (incluido p).
  function Mundo:companerosDeGrupo(p, x, y)
    local g = self:grupoDe(p)
    if not g then return { p } end
    local lista = {}
    for _, e in ipairs(self:miembrosGrupo(g)) do
      if e.vivo and self:mismoLugar(p, e) and Util.dist(e.x, e.y, x or p.x, y or p.y) <= M.DISTANCIA then
        lista[#lista + 1] = e
      end
    end
    if #lista == 0 then lista[1] = p end
    return lista
  end

  -- Recompensa de una criatura muerta por alguien en grupo. Devuelve true si la repartió
  -- (si el que mata va solo o no hay compañeros cerca, lo trata la ruta normal).
  function Mundo:recompensaGrupo(e, origen)
    local lista = self:companerosDeGrupo(origen, e.x, e.y)
    local n = #lista
    if n < 2 then return false end
    local mul = e.xpMul or 1
    local oroCada = math.floor(math.floor((e.oro or 5) * 0.3 * mul) / n)
    for _, m in ipairs(lista) do
      local exp = Balance.xpMonstruo(m.nivel or 1, e.nivel or 1, e.elite) * mul
      if exp > 0 then
        -- el grupo da un extra sobre el total y se reparte entre los que están
        exp = exp * (1 + M.BONO_XP) / n
        exp = math.floor(exp * self:bonoGremio(m) + 0.5)
        self:ganarXp(m, exp)
        self:mascotaGanaXp(m, exp)
      end
      m.oro = (m.oro or 0) + oroCada
      m.caceria = m.caceria or {}
      m.caceria[e.monstruo] = (m.caceria[e.monstruo] or 0) + 1
      self:avanzarMisiones(m, e.monstruo)
      self:marcarProgreso(m)
    end
    self:soltarBotin(e, origen)
    return true
  end

  -- ------------------------------------------------------------------ lo que ve el cliente
  function Mundo:resumenGrupo(p)
    local g = self:grupoDe(p)
    if not g then return nil end
    local miembros = {}
    for _, e in ipairs(self:miembrosGrupo(g)) do
      miembros[#miembros + 1] = {
        id = e.id, nombre = e.nombre, nivel = e.nivel, clase = e.clase, hp = math.floor(e.hp or 0), hpMax = math.floor(e.hpMax or 1),
        x = math.floor(e.x), y = math.floor(e.y), modo = e.modo,
        cerca = e == p or (e.vivo and self:mismoLugar(p, e) and Util.dist(e.x, e.y, p.x, p.y) <= M.DISTANCIA) or false,
      }
    end
    return { lider = g.lider, miembros = miembros, max = M.MAX, bono = M.BONO_XP }
  end

  -- ------------------------------------------------------------------ acciones del cliente
  function Mundo:accionGrupo(p, nombre, datos)
    local err
    if nombre == "grupo_invitar" then err = self:invitarGrupo(p, datos.id)
    elseif nombre == "grupo_responder" then err = self:responderInvitacionGrupo(p, datos.acepta == true)
    elseif nombre == "grupo_salir" then err = self:salirGrupo(p)
    elseif nombre == "grupo_expulsar" then err = self:expulsarGrupo(p, datos.id)
    elseif nombre == "grupo_lider" then err = self:ascenderGrupo(p, datos.id)
    elseif nombre == "grupo_disolver" then err = self:disolverGrupo(p)
    end
    if err then self:mensaje("sistema", "", err, p) end
    return nil
  end
end

return M
