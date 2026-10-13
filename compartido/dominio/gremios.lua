-- Gremios: grupos de jugadores de una misma corona, con rangos, chat propio y una pequeña
-- ventaja de experiencia al cazar juntos. Un personaje solo está en un gremio.
--   rangos: líder (3) > oficial (2) > miembro (1)
--   el líder lo puede todo; el oficial invita y expulsa miembros; el miembro solo habla y sale.
-- El dominio guarda los gremios en memoria (mundo.gremios) y avisa de cada cambio por los
-- puertos guardarGremio / borrarGremio; la aplicación los lleva a la base de datos.
local Util = require("compartido.dominio.util")

local M = {}

M.NIVEL_MINIMO = 8
M.COSTE = 2500
M.MAX_MIEMBROS = 25
M.INVITACION_SEG = 60

M.RANGOS = { lider = 3, oficial = 2, miembro = 1 }
M.NOMBRE_RANGO = { lider = "Líder", oficial = "Oficial", miembro = "Miembro" }

-- Ventaja de experiencia por cada compañero de gremio cerca (hasta TOPE_COMPANEROS).
M.BONO_POR_COMPANERO = 0.05
M.TOPE_COMPANEROS = 3
M.DISTANCIA_BONO = 14

local function recortar(t)
  return (t:gsub("^%s+", ""):gsub("%s+$", ""))
end
M.recortar = recortar

-- Nombre de 3 a 20 letras (con acentos y ñ) y espacios sueltos.
function M.nombreValido(n)
  if type(n) ~= "string" then return false end
  n = recortar(n)
  local largo = 0
  for i = 1, #n do
    local c = n:byte(i)
    if c >= 128 then
      if c >= 192 then largo = largo + 1 end -- primer byte de cada letra no ASCII
    else
      local letra = (c >= 65 and c <= 90) or (c >= 97 and c <= 122)
      if not (letra or c == 32) then return false end
      largo = largo + 1
    end
  end
  if largo < 3 or largo > 20 then return false end
  return not n:find("  ", 1, true)
end

-- Etiqueta: 2 a 4 letras o números.
function M.etiquetaValida(t)
  return type(t) == "string" and #t >= 2 and #t <= 4 and t:match("^%w+$") ~= nil
end

function M.instalar(Mundo)
  function Mundo:iniciarGremios()
    self.gremios = self.gremios or {}
    self.gremioDe = self.gremioDe or {}
    self.siguienteGremio = self.siguienteGremio or 1
  end

  -- Carga la lista del almacén: { id, nombre, etiqueta, faccion, miembros = { { id, nombre, rango } } }.
  function Mundo:cargarGremios(lista)
    self.gremios, self.gremioDe, self.siguienteGremio = {}, {}, 1
    for _, g in ipairs(lista or {}) do
      local miembros = {}
      for _, m in ipairs(g.miembros or {}) do
        miembros[m.id] = { nombre = m.nombre, rango = m.rango }
        self.gremioDe[m.id] = g.id
      end
      self.gremios[g.id] = { id = g.id, nombre = g.nombre, etiqueta = g.etiqueta, faccion = g.faccion, miembros = miembros }
      if g.id >= self.siguienteGremio then self.siguienteGremio = g.id + 1 end
    end
  end

  local function guardar(self, g)
    if self.puertos.guardarGremio then self.puertos.guardarGremio(g) end
  end

  function Mundo:gremioPropio(p)
    self:iniciarGremios()
    return p.gremioId and self.gremios[p.gremioId] or nil
  end

  function Mundo:contarMiembros(g)
    local n = 0
    for _ in pairs(g.miembros) do n = n + 1 end
    return n
  end

  -- Pone en el jugador los datos de su gremio (al entrar al mundo o tras un cambio).
  function Mundo:vincularGremio(p)
    self:iniciarGremios()
    local gid = p.dbId and self.gremioDe[p.dbId]
    local g = gid and self.gremios[gid]
    local m = g and g.miembros[p.dbId]
    if g and m then
      p.gremioId, p.gremioRango, p.gremioEtiqueta = g.id, m.rango, g.etiqueta
      m.nombre = p.nombre
    else
      p.gremioId, p.gremioRango, p.gremioEtiqueta = nil, nil, nil
    end
  end

  local function jugadorPorDbId(self, dbId)
    for _, e in pairs(self.entidades) do
      if e.kind == "jugador" and e.dbId == dbId and not e.borrar then return e end
    end
  end

  function Mundo:crearGremio(p, nombre, etiqueta)
    self:iniciarGremios()
    if p.kind ~= "jugador" or not p.dbId then return "No puedes fundar un gremio." end
    if p.gremioId then return "Ya perteneces a un gremio." end
    if (p.nivel or 1) < M.NIVEL_MINIMO then return "Hace falta nivel " .. M.NIVEL_MINIMO .. " para fundar un gremio." end
    if not M.nombreValido(nombre) then return "El nombre usa de 3 a 20 letras." end
    nombre = recortar(nombre)
    if not M.etiquetaValida(etiqueta) then return "La etiqueta usa de 2 a 4 letras o números." end
    etiqueta = etiqueta:upper()
    for _, g in pairs(self.gremios) do
      if g.nombre:lower() == nombre:lower() then return "Ya existe un gremio con ese nombre." end
      if g.etiqueta == etiqueta then return "Esa etiqueta ya está en uso." end
    end
    if (p.oro or 0) < M.COSTE then return "Fundar un gremio cuesta " .. M.COSTE .. " de oro." end
    p.oro = p.oro - M.COSTE
    local g = {
      id = self.siguienteGremio, nombre = nombre, etiqueta = etiqueta, faccion = p.faccion,
      miembros = { [p.dbId] = { nombre = p.nombre, rango = "lider" } },
    }
    self.siguienteGremio = g.id + 1
    self.gremios[g.id] = g
    self.gremioDe[p.dbId] = g.id
    self:vincularGremio(p)
    guardar(self, g)
    self:marcarProgreso(p)
    self:mensaje("sistema", "", "Has fundado el gremio " .. nombre .. " [" .. etiqueta .. "].", p)
    return nil
  end

  function Mundo:invitarGremio(p, objetivoId)
    local g = self:gremioPropio(p)
    if not g then return "No tienes gremio." end
    if M.RANGOS[p.gremioRango] < M.RANGOS.oficial then return "Solo líder y oficiales invitan." end
    local o = self.entidades[objetivoId]
    if not o or o.kind ~= "jugador" or not o.vivo then return "No hay nadie a quien invitar." end
    if o.faccion ~= g.faccion then return "Solo puedes invitar a tu misma corona." end
    if o.gremioId then return o.nombre .. " ya está en un gremio." end
    if self:contarMiembros(g) >= M.MAX_MIEMBROS then return "El gremio está lleno." end
    if not self:mismoLugar(p, o) or Util.dist(p.x, p.y, o.x, o.y) > 12 then return o.nombre .. " está demasiado lejos." end
    o.invitacionGremio = { gremio = g.id, nombre = g.nombre, de = p.nombre, hasta = self.tiempo + M.INVITACION_SEG }
    self:mensaje("sistema", "", p.nombre .. " te invita al gremio " .. g.nombre .. ". Acepta o rechaza en el panel de gremio (tecla G).", o)
    self:mensaje("sistema", "", "Invitación enviada a " .. o.nombre .. ".", p)
    return nil
  end

  function Mundo:responderInvitacionGremio(p, acepta)
    local inv = p.invitacionGremio
    p.invitacionGremio = nil
    if not inv then return "No tienes invitaciones." end
    if not acepta then return nil end
    if inv.hasta < self.tiempo then return "La invitación caducó." end
    self:iniciarGremios()
    local g = self.gremios[inv.gremio]
    if not g then return "Ese gremio ya no existe." end
    if p.gremioId then return "Ya perteneces a un gremio." end
    if self:contarMiembros(g) >= M.MAX_MIEMBROS then return "El gremio está lleno." end
    g.miembros[p.dbId] = { nombre = p.nombre, rango = "miembro" }
    self.gremioDe[p.dbId] = g.id
    self:vincularGremio(p)
    guardar(self, g)
    self:marcarProgreso(p)
    self:mensaje("gremio", "Gremio", p.nombre .. " se une al gremio.", p)
    return nil
  end

  local function quitar(self, g, dbId)
    g.miembros[dbId] = nil
    self.gremioDe[dbId] = nil
    local e = jugadorPorDbId(self, dbId)
    if e then
      self:vincularGremio(e)
      self:marcarProgreso(e)
    end
  end

  function Mundo:disolverGremio(p)
    local g = self:gremioPropio(p)
    if not g then return "No tienes gremio." end
    if p.gremioRango ~= "lider" then return "Solo el líder puede disolverlo." end
    local ids = {}
    for dbId in pairs(g.miembros) do ids[#ids + 1] = dbId end
    for _, dbId in ipairs(ids) do quitar(self, g, dbId) end
    self.gremios[g.id] = nil
    if self.puertos.borrarGremio then self.puertos.borrarGremio(g.id) end
    self:mensaje("sistema", "", "El gremio " .. g.nombre .. " se ha disuelto.", p)
    return nil
  end

  function Mundo:salirGremio(p)
    local g = self:gremioPropio(p)
    if not g then return "No tienes gremio." end
    local eraLider = p.gremioRango == "lider"
    quitar(self, g, p.dbId)
    if next(g.miembros) == nil then
      self.gremios[g.id] = nil
      if self.puertos.borrarGremio then self.puertos.borrarGremio(g.id) end
    else
      if eraLider then
        -- el mando pasa al de mayor rango y, a igualdad, al que lleva más tiempo (id más bajo)
        local mejor, rango
        for dbId, m in pairs(g.miembros) do
          local r = M.RANGOS[m.rango]
          if not mejor or r > rango or (r == rango and dbId < mejor) then mejor, rango = dbId, r end
        end
        g.miembros[mejor].rango = "lider"
        local nuevo = jugadorPorDbId(self, mejor)
        if nuevo then self:vincularGremio(nuevo) end
      end
      guardar(self, g)
    end
    self:mensaje("sistema", "", "Has salido del gremio " .. g.nombre .. ".", p)
    return nil
  end

  function Mundo:expulsarGremio(p, dbId)
    local g = self:gremioPropio(p)
    if not g then return "No tienes gremio." end
    dbId = tonumber(dbId)
    local m = dbId and g.miembros[dbId]
    if not m then return "Ese jugador no está en tu gremio." end
    if dbId == p.dbId then return "Para irte, usa Salir." end
    if M.RANGOS[p.gremioRango] <= M.RANGOS[m.rango] or M.RANGOS[p.gremioRango] < M.RANGOS.oficial then
      return "No puedes expulsar a alguien de tu rango o superior."
    end
    quitar(self, g, dbId)
    guardar(self, g)
    self:mensaje("sistema", "", m.nombre .. " ya no está en el gremio.", p)
    return nil
  end

  -- El líder asciende a miembro -> oficial o degrada a oficial -> miembro.
  function Mundo:cambiarRangoGremio(p, dbId, sube)
    local g = self:gremioPropio(p)
    if not g then return "No tienes gremio." end
    if p.gremioRango ~= "lider" then return "Solo el líder cambia rangos." end
    dbId = tonumber(dbId)
    local m = dbId and g.miembros[dbId]
    if not m or dbId == p.dbId then return "Ese jugador no es válido." end
    if sube and m.rango == "miembro" then m.rango = "oficial"
    elseif not sube and m.rango == "oficial" then m.rango = "miembro"
    else return "No se puede cambiar más." end
    local e = jugadorPorDbId(self, dbId)
    if e then self:vincularGremio(e) end
    guardar(self, g)
    self:mensaje("sistema", "", m.nombre .. " es ahora " .. M.NOMBRE_RANGO[m.rango]:lower() .. ".", p)
    return nil
  end

  -- Acciones de gremio que llegan del cliente. Devuelve el panel actualizado.
  function Mundo:accionGremio(p, nombre, datos)
    local err
    if nombre == "gremio_crear" then
      if self:npcCerca(p, "gremio") then err = self:crearGremio(p, datos.nombre, datos.etiqueta)
      else err = "Acércate al escribano del gremio." end
    elseif nombre == "gremio_invitar" then err = self:invitarGremio(p, datos.id)
    elseif nombre == "gremio_responder" then err = self:responderInvitacionGremio(p, datos.acepta == true)
    elseif nombre == "gremio_salir" then err = self:salirGremio(p)
    elseif nombre == "gremio_expulsar" then err = self:expulsarGremio(p, datos.id)
    elseif nombre == "gremio_rango" then err = self:cambiarRangoGremio(p, datos.id, datos.sube == true)
    elseif nombre == "gremio_disolver" then err = self:disolverGremio(p)
    end
    if err then self:mensaje("sistema", "", err, p) end
    local info = self:resumenGremio(p) or { sin = true, coste = M.COSTE, nivel = M.NIVEL_MINIMO }
    return { panel = "gremio", datos = info }
  end

  -- Compañeros de gremio cerca de p (sin contarlo a él).
  function Mundo:companerosCerca(p)
    if not p.gremioId then return 0 end
    local n = 0
    for _, e in pairs(self.entidades) do
      if e ~= p and e.kind == "jugador" and e.vivo and e.gremioId == p.gremioId and self:mismoLugar(p, e)
        and Util.dist(p.x, p.y, e.x, e.y) <= M.DISTANCIA_BONO then
        n = n + 1
      end
    end
    return n
  end

  function Mundo:bonoGremio(p)
    return 1 + M.BONO_POR_COMPANERO * math.min(M.TOPE_COMPANEROS, self:companerosCerca(p))
  end

  -- Lo que ve el panel: datos del gremio con sus miembros ordenados por rango y conexión.
  function Mundo:resumenGremio(p)
    local g = self:gremioPropio(p)
    if not g then return nil end
    local lista = {}
    for dbId, m in pairs(g.miembros) do
      local e = jugadorPorDbId(self, dbId)
      lista[#lista + 1] = { id = dbId, nombre = m.nombre, rango = m.rango, conectado = e ~= nil, nivel = e and e.nivel or nil }
    end
    table.sort(lista, function(a, b)
      if M.RANGOS[a.rango] ~= M.RANGOS[b.rango] then return M.RANGOS[a.rango] > M.RANGOS[b.rango] end
      if a.conectado ~= b.conectado then return a.conectado end
      return a.nombre < b.nombre
    end)
    return { id = g.id, nombre = g.nombre, etiqueta = g.etiqueta, miembros = lista, max = M.MAX_MIEMBROS }
  end
end

return M
