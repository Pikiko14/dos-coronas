-- Comercio entre jugadores.
--   1. Uno invita a otro (tecla T o botón Trato): al invitado le sale una alerta con Aceptar y
--      Rechazar. Si acepta, se abre la ventana de comercio para los dos.
--   2. Cada uno pone objetos (de su bolsa) y oro en su oferta. El oro nunca puede pasar de lo que
--      el jugador tiene; el servidor lo valida aunque el cliente falle. Lo ofrecido sale de la bolsa
--      y queda en depósito hasta que se cierra o se cancela el trato.
--   3. Cuando los dos aceptan, el intercambio es de todo o nada: si a alguno no le cabe en la
--      bolsa, se deshace y cada uno recupera lo suyo.
local Util = require("compartido.dominio.util")
local Datos = require("compartido.dominio.datos")

local M = {}

M.INVITACION_SEG = 30
M.DISTANCIA_INVITAR = 3.2
M.DISTANCIA_MAX = 10          -- si se alejan más que esto, el trato se cancela
M.MAX_OBJETOS = 16            -- objetos distintos en una oferta
M.MAX_ORO = 1000000000

local function copiaBolsa(p)
  local c = {}
  for i, s in ipairs(p.bolsa or {}) do c[i] = { id = s.id, cant = s.cant, enc = s.enc } end
  return c
end

function M.instalar(Mundo)
  -- ------------------------------------------------------------------ invitación
  function Mundo:invitarComercio(a, b)
    if not b or b == a or (b.kind ~= "jugador" and b.kind ~= "bot") or not b.vivo or not a.vivo then
      return "No hay nadie a quien proponer un trato."
    end
    if a.kind ~= "jugador" then return "Solo los jugadores comercian." end
    if not self:mismoLugar(a, b) or Util.dist(a.x, a.y, b.x, b.y) > M.DISTANCIA_INVITAR then
      return "Demasiado lejos."
    end
    if a.sesion or b.sesion then return "Alguien ya está comerciando." end
    if b.invitacionComercio and b.invitacionComercio.hasta > self.tiempo then
      return b.nombre .. " ya tiene una invitación de comercio pendiente."
    end
    if b.kind == "bot" then return self:abrirSesionComercio(a, b) end
    b.invitacionComercio = { de = a.id, nombre = a.nombre, hasta = self.tiempo + M.INVITACION_SEG }
    self:mensaje("sistema", "", a.nombre .. " quiere comerciar contigo.", b)
    self:mensaje("sistema", "", "Invitación de comercio enviada a " .. b.nombre .. ".", a)
    return nil
  end

  function Mundo:responderInvitacionComercio(p, acepta)
    local inv = p.invitacionComercio
    p.invitacionComercio = nil
    if not inv then return "No tienes invitaciones de comercio." end
    local a = self.entidades[inv.de]
    if not acepta then
      if a then self:mensaje("sistema", "", p.nombre .. " rechaza tu invitación de comercio.", a) end
      return nil
    end
    if inv.hasta < self.tiempo then return "La invitación caducó." end
    if not a or a.borrar or not a.vivo then return "Quien te invitó ya no está." end
    if not self:mismoLugar(a, p) or Util.dist(a.x, a.y, p.x, p.y) > M.DISTANCIA_INVITAR + 4 then
      return a.nombre .. " está demasiado lejos."
    end
    if a.sesion or p.sesion then return "Alguien ya está comerciando." end
    return self:abrirSesionComercio(a, p)
  end

  function Mundo:abrirSesionComercio(a, b)
    local id = self:idNuevo()
    local s = {
      id = id, a = a.id, b = b.id,
      oferta = {
        [a.id] = { oro = 0, items = {}, ok = false },
        [b.id] = { oro = 0, items = {}, ok = false },
      },
    }
    self.sesiones[id] = s
    a.sesion, b.sesion = id, id
    self:mensaje("sistema", "", "Comercio con " .. b.nombre .. ".", a)
    self:mensaje("sistema", "", "Comercio con " .. a.nombre .. ".", b)
    if b.kind == "bot" then
      s.oferta[b.id].oro = 10
      s.oferta[b.id].items = { { id = "pocion_vida", cant = 1 } }
      if b.oro >= 10 then b.oro = b.oro - 10 else s.oferta[b.id].oro = 0 end
      self:mensaje("local", b.nombre, "Acepto si ofreces al menos el valor de lo mío.", b)
    end
    return nil, id
  end

  -- ------------------------------------------------------------------ la oferta
  local function sesionDe(self, p)
    local s = p.sesion and self.sesiones[p.sesion]
    return s, s and s.oferta[p.id]
  end

  local function reabrir(s)
    s.oferta[s.a].ok = false
    s.oferta[s.b].ok = false
  end

  -- Pone el oro de la oferta de p. Devuelve un mensaje de error si pide más de lo que tiene.
  function Mundo:ofrecerOro(p, cantidad)
    local s, of = sesionDe(self, p)
    if not s then return "No hay comercio." end
    cantidad = tonumber(cantidad)
    if not cantidad or cantidad ~= cantidad or cantidad == math.huge or cantidad == -math.huge then
      return "Esa cantidad de oro no es válida."
    end
    cantidad = math.floor(cantidad)
    if cantidad < 0 then return "Esa cantidad de oro no es válida." end
    if cantidad > M.MAX_ORO then cantidad = M.MAX_ORO end
    local disponible = (p.oro or 0) + of.oro       -- lo que tiene en total (lo ofrecido está en depósito)
    if cantidad > disponible then
      return "No tienes tanto oro: tienes " .. disponible .. "."
    end
    p.oro = disponible - cantidad
    of.oro = cantidad
    reabrir(s)
    return nil
  end

  -- Pasa un objeto de la bolsa a la oferta.
  function Mundo:ofrecerItem(p, index)
    local s, of = sesionDe(self, p)
    if not s then return "No hay comercio." end
    index = tonumber(index)
    local slot = index and p.bolsa[math.floor(index)]
    if not slot then return "Ese objeto no está en tu bolsa." end
    local def = Datos.item(slot.id)
    if not def or def.quest then return "Ese objeto no se puede comerciar." end
    if #of.items >= M.MAX_OBJETOS then return "La oferta no admite más objetos distintos." end
    of.items[#of.items + 1] = { id = slot.id, cant = slot.cant, enc = slot.enc }
    table.remove(p.bolsa, math.floor(index))
    reabrir(s)
    return nil
  end

  -- Devuelve un objeto de la oferta a la bolsa.
  function Mundo:quitarItemOferta(p, index)
    local s, of = sesionDe(self, p)
    if not s then return "No hay comercio." end
    index = tonumber(index)
    local it = index and of.items[math.floor(index)]
    if not it then return "Ese objeto no está en tu oferta." end
    if not self:darItem(p, it.id, it.cant, it.enc) then return "Tu bolsa está llena." end
    table.remove(of.items, math.floor(index))
    reabrir(s)
    return nil
  end

  function Mundo:aceptarComercio(p)
    local s, of = sesionDe(self, p)
    if not s then return end
    of.ok = true
    local otro = self.entidades[s.a == p.id and s.b or s.a]
    if otro and otro.kind == "bot" then
      local vo = self:valorOferta(s.oferta[p.id])
      local vb = self:valorOferta(s.oferta[otro.id])
      if vo >= vb and vo > 0 then s.oferta[otro.id].ok = true end
    end
    if s.oferta[s.a].ok and s.oferta[s.b].ok then return self:cerrarComercio(s, true) end
  end

  -- Cierra el trato: todo o nada.
  function Mundo:cerrarComercio(s, ok)
    local a, b = self.entidades[s.a], self.entidades[s.b]
    local oa, ob = s.oferta[s.a], s.oferta[s.b]
    local function devolver(p, of)
      if not p or not of then return end
      p.oro = p.oro + (of.oro or 0)
      for _, it in ipairs(of.items) do self:darItem(p, it.id, it.cant, it.enc) end
    end
    local exito = false
    if ok and a and b then
      -- copia de seguridad: si algo no cabe se deshace sin duplicar ni perder nada
      local ba, bb, oroA, oroB = copiaBolsa(a), copiaBolsa(b), a.oro, b.oro
      local cabe = true
      local function entra(p, of)
        p.oro = p.oro + (of.oro or 0)
        for _, it in ipairs(of.items) do
          if not self:darItem(p, it.id, it.cant, it.enc) then cabe = false end
        end
      end
      entra(a, ob)
      entra(b, oa)
      if cabe then
        exito = true
        self:marcarProgreso(a)
        self:marcarProgreso(b)
        self:mensaje("sistema", "", "Comercio cerrado con " .. b.nombre .. ".", a)
        self:mensaje("sistema", "", "Comercio cerrado con " .. a.nombre .. ".", b)
      else
        a.bolsa, b.bolsa, a.oro, b.oro = ba, bb, oroA, oroB
        self:mensaje("sistema", "", "El comercio no cabe en la bolsa: se cancela.", a)
        self:mensaje("sistema", "", "El comercio no cabe en la bolsa: se cancela.", b)
      end
    end
    if not exito then
      devolver(a, a and oa)
      devolver(b, b and ob)
      if a and not ok then self:mensaje("sistema", "", "Comercio cancelado.", a) end
      if b and not ok then self:mensaje("sistema", "", "Comercio cancelado.", b) end
    end
    if a then a.sesion = nil end
    if b then b.sesion = nil end
    self.sesiones[s.id] = nil
  end

  function Mundo:cancelarComercio(p)
    local s = p.sesion and self.sesiones[p.sesion]
    if s then self:cerrarComercio(s, false) end
  end

  -- Una vez por segundo: caducan invitaciones y se cancelan los tratos de quien se aleja o se va.
  function Mundo:actualizarComercio(dt)
    self._comT = (self._comT or 0) + dt
    if self._comT < 1 then return end
    self._comT = 0
    for _, e in pairs(self.entidades) do
      local inv = e.invitacionComercio
      if inv and inv.hasta <= self.tiempo then
        e.invitacionComercio = nil
        local a = self.entidades[inv.de]
        if a then self:mensaje("sistema", "", e.nombre .. " no respondió a tu invitación de comercio.", a) end
      end
    end
    for _, s in pairs(self.sesiones) do
      if s.a and s.b and s.oferta then
        local a, b = self.entidades[s.a], self.entidades[s.b]
        local roto = not a or not b or a.borrar or b.borrar or not a.vivo or not b.vivo
          or not self:mismoLugar(a, b) or Util.dist(a.x, a.y, b.x, b.y) > M.DISTANCIA_MAX
        if roto then self:cerrarComercio(s, false) end
      end
    end
  end

  -- Lo que ve el cliente de su invitación.
  function Mundo:resumenInvitacionComercio(p)
    local inv = p.invitacionComercio
    if inv and inv.hasta > self.tiempo then return { de = inv.nombre, hasta = inv.hasta } end
    return nil
  end

  -- Acciones del cliente.
  function Mundo:accionComercio(p, nombre, datos)
    local err
    if nombre == "comercio_invitar" then err = self:invitarComercio(p, self.entidades[datos.id])
    elseif nombre == "comercio_responder" then err = self:responderInvitacionComercio(p, datos.acepta == true)
    elseif nombre == "comercio_oro" then err = self:ofrecerOro(p, datos.oro)
    elseif nombre == "comercio_item" then err = self:ofrecerItem(p, datos.i)
    elseif nombre == "comercio_quitar" then err = self:quitarItemOferta(p, datos.i)
    elseif nombre == "comercio_ok" then self:aceptarComercio(p)
    elseif nombre == "comercio_no" then self:cancelarComercio(p)
    end
    if err then self:mensaje("sistema", "", err, p) end
    return nil
  end
end

return M
