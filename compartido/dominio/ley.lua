-- La ley del camino: robos, ladrones buscados y cazarrecompensas.
--   * Un ladrón roba a comerciantes y caravanas FUERA de las ciudades: hay que quedarse junto al
--     objetivo unos segundos sin que te golpeen. Los cazarrecompensas cerca lo ponen difícil.
--   * Robar (con éxito o no) lo convierte en buscado: los guardias y los cazarrecompensas
--     pueden atacarlo, y su cabeza vale una recompensa.
--   * El contacto de los ladrones compra lo robado a mitad de precio.
local Util = require("compartido.dominio.util")
local Oficios = require("compartido.dominio.oficios")

local M = {}
require("compartido.dominio.configuracion").aplicar(M, "ley")


function M.instalar(Mundo)
  function Mundo:esBuscado(p)
    return p and p.buscado ~= nil and p.buscado > self.tiempo
  end

  function Mundo:marcarBuscado(p, seg, valor)
    local nuevo = self.tiempo + seg
    if not self:esBuscado(p) or nuevo > p.buscado then p.buscado = nuevo end
    p.recompensa = math.max(p.recompensa or 0, math.floor(60 + (valor or 0) * 0.6))
    self:mensaje("sistema", "", "¡Te buscan! Recompensa: " .. p.recompensa .. " de oro.", p)
  end

  -- Pelea abierta entre dos jugadores (por un robo): se pueden herir aunque sean de la misma corona.
  function Mundo:abrirCombate(a, b)
    a.combateCon = a.combateCon or {}
    b.combateCon = b.combateCon or {}
    a.combateCon[b.id] = self.tiempo + M.COMBATE_SEG
    b.combateCon[a.id] = self.tiempo + M.COMBATE_SEG
  end

  -- ¿Puede origen herir a objetivo por motivos de oficio? (se suma a las reglas normales)
  function Mundo:legitimoPorOficio(origen, objetivo)
    if objetivo.kind ~= "jugador" and objetivo.kind ~= "bot" then return false end
    if origen.combateCon and (origen.combateCon[objetivo.id] or 0) > self.tiempo then return true end
    -- un ladrón puede atacar a un comerciante montado (el golpe baja la vida de su montura)
    if (origen.kind == "jugador" or origen.kind == "bot") and origen.job == "thief" and objetivo.job == "trader" and objetivo.montado then
      return true
    end
    if self:esBuscado(objetivo) then
      if origen.kind == "guardia" then return true end
      if (origen.kind == "jugador" or origen.kind == "bot") and origen.job == "hunter" then return true end
    end
    return false
  end

  -- ------------------------------------------------------------------ robo
  local function cargaDe(obj)
    if obj.kind == "caravana" then return obj.carga end
    return obj.carga
  end

  local function totalCarga(carga)
    local n = 0
    for _, c in pairs(carga or {}) do n = n + c end
    return n
  end

  function Mundo:iniciarRobo(p, objetivoId)
    if p.job ~= "thief" then return "Solo los ladrones roban." end
    if p.robo then return "Ya estás robando." end
    if not p.vivo or (p.aturdido or 0) > 0 then return "No puedes actuar." end
    if p.modo ~= "mundo" then return "Aquí no se puede robar." end
    local o = self.entidades[objetivoId]
    if not o or not o.vivo or o == p then return "No hay nadie a quien robar." end
    if o.kind ~= "jugador" and o.kind ~= "caravana" then return "Solo se roba a comerciantes y caravanas." end
    if not self:mismoLugar(p, o) then return "No hay nadie a quien robar." end
    if Util.dist(p.x, p.y, o.x, o.y) > M.ALCANCE_ROBO then return "Acércate más." end
    if self:ciudadEn(o.x, o.y) or self:ciudadEn(p.x, p.y) then return "Dentro de las ciudades no se roba: hay guardias." end
    if o.kind == "jugador" and o.job ~= "trader" then return "Ese jugador no lleva mercancías." end
    if totalCarga(cargaDe(o)) < 1 then return "No lleva nada que robar." end
    local libre = self:capacidadCarga(p) - self:pesoCarga(p)
    if libre < 1 then return "Vas cargado: vende primero lo robado." end
    local nivel = self:oficioNivel(p)
    p.robo = { objetivo = o.id, hasta = self.tiempo + Oficios.tiempoRobo(nivel), x = p.x, y = p.y, desde = self.tiempo }
    self:mensaje("sistema", "", "Robando... no te muevas.", p)
    if o.kind == "jugador" then
      self:mensaje("sistema", "", "¡Alguien intenta robarte la carga!", o)
    end
    return nil
  end

  function Mundo:cancelarRobo(p, motivo)
    if not p.robo then return end
    p.robo = nil
    if motivo then self:mensaje("sistema", "", motivo, p) end
  end

  -- Cuántos cazarrecompensas (que no son el ladrón) hay cerca del objetivo.
  local function cazadoresCerca(self, o, excepto)
    local n = 0
    for _, e in pairs(self.entidades) do
      if e ~= excepto and e ~= o and (e.kind == "jugador" or e.kind == "bot") and e.vivo and e.job == "hunter"
        and self:mismoLugar(o, e) and Util.dist(o.x, o.y, e.x, e.y) <= 10 then
        n = n + 1
      end
    end
    return math.min(2, n)
  end
  M.cazadoresCerca = cazadoresCerca

  -- Quita una fracción de la carga de un objetivo hasta caber en el hueco del ladrón.
  local function sacar(carga, fraccion, limite)
    local total = totalCarga(carga)
    local quiere = math.max(1, math.floor(total * fraccion + 0.5))
    quiere = math.min(quiere, limite, total)
    local robado = {}
    local restante = quiere
    local ids = {}
    for bien in pairs(carga) do ids[#ids + 1] = bien end
    -- primero lo más valioso
    table.sort(ids, function(a, b) return Oficios.BIENES[a].base > Oficios.BIENES[b].base end)
    for _, bien in ipairs(ids) do
      if restante <= 0 then break end
      local n = math.min(carga[bien], restante)
      robado[bien] = n
      carga[bien] = carga[bien] - n
      if carga[bien] <= 0 then carga[bien] = nil end
      restante = restante - n
    end
    return robado
  end

  function Mundo:resolverRobo(p)
    local r = p.robo
    p.robo = nil
    local o = self.entidades[r.objetivo]
    if not o or not o.vivo then return end
    local nivel = self:oficioNivel(p)
    local prob = Oficios.probRobo(nivel) - 0.25 * cazadoresCerca(self, o, p)
    if o.kind == "jugador" then prob = prob - 0.04 * math.max(0, (o.nivel or 1) - (p.nivel or 1)) / 2 end
    prob = math.max(0.1, prob)
    if math.random() < prob then
      local libre = self:capacidadCarga(p) - self:pesoCarga(p)
      local robado = sacar(cargaDe(o), M.FRACCION_ROBO, libre)
      local valor = self:valorCarga(robado)
      p.cargaRobada = p.cargaRobada or {}
      local n = 0
      for bien, c in pairs(robado) do
        p.cargaRobada[bien] = (p.cargaRobada[bien] or 0) + c
        n = n + c
      end
      if o.kind == "caravana" then
        o.valor = math.max(0, math.floor((o.valor or 0) - valor))
        o.alerta = self.tiempo + 30
      else
        self:recalcularCarga(o)
        self:mensaje("sistema", "", "¡" .. p.nombre .. " te ha robado " .. n .. " unidades de mercancía!", o)
        self:abrirCombate(p, o)
      end
      self:recalcularCarga(p)
      self:marcarBuscado(p, M.BUSCADO_SEG, valor)
      self:ganarXpOficio(p, valor / 5)
      self:numero(p, "+" .. n .. " robado", { 1, 0.85, 0.3 })
      self:mensaje("sistema", "", "Robo con éxito: " .. n .. " unidades (valen unos " .. valor .. " de oro).", p)
      self:sonar("corte")
    else
      self:marcarBuscado(p, M.BUSCADO_FALLO_SEG, 0)
      if o.kind == "jugador" then
        self:abrirCombate(p, o)
        self:mensaje("sistema", "", "¡Has descubierto a " .. p.nombre .. " intentando robarte!", o)
      else
        o.alerta = self.tiempo + 30
      end
      self:mensaje("sistema", "", "Te han descubierto: el robo falla.", p)
    end
    self:marcarProgreso(p)
  end

  -- Se llama cada tick del jugador: avanza el robo en curso.
  function Mundo:actualizarRobo(p)
    local r = p.robo
    if not r then return end
    local o = self.entidades[r.objetivo]
    if not o or not o.vivo or not self:mismoLugar(p, o) then self:cancelarRobo(p, "El objetivo ya no está.") return end
    if Util.dist(p.x, p.y, o.x, o.y) > M.ALCANCE_ROBO + 0.8 then self:cancelarRobo(p, "Te alejas: el robo se interrumpe.") return end
    if Util.dist(p.x, p.y, r.x, r.y) > 1.3 then self:cancelarRobo(p, "Te mueves: el robo se interrumpe.") return end
    if (p.ultimoGolpe or -10) > r.desde then self:cancelarRobo(p, "Te golpean: el robo se interrumpe.") return end
    if self.tiempo >= r.hasta then self:resolverRobo(p) end
  end

  -- ------------------------------------------------------------------ el contacto
  function Mundo:venderRobado(p)
    if p.job ~= "thief" then return "Solo los ladrones tratan con el contacto." end
    local carga = p.cargaRobada
    if not carga or totalCarga(carga) < 1 then return "No llevas nada robado." end
    local nivel = self:oficioNivel(p)
    local f = Oficios.precioPerista(nivel)
    local total, unidades = 0, 0
    for bien, c in pairs(carga) do
      total = total + math.floor(Oficios.BIENES[bien].base * f * c)
      unidades = unidades + c
    end
    p.cargaRobada = {}
    p.oro = (p.oro or 0) + total
    self:recalcularCarga(p)
    self:ganarXpOficio(p, total / 8)
    self:marcarProgreso(p)
    self:mensaje("sistema", "", "El contacto te paga " .. total .. " de oro por " .. unidades .. " unidades.", p)
    return nil
  end

  -- ------------------------------------------------------------------ recompensas
  -- Llamado desde morir(): un buscado cae.
  function Mundo:caeBuscado(e, origen)
    if not self:esBuscado(e) then return end
    local recompensa = e.recompensa or 0
    local perdido = self:valorCarga(e.cargaRobada)
    e.buscado, e.recompensa = nil, nil
    e.cargaRobada = {}
    self:recalcularCarga(e)
    self:mensaje("sistema", "", "Pierdes lo robado y la ley te deja marchar.", e)
    if origen and (origen.kind == "jugador" or origen.kind == "bot") and origen.job == "hunter" then
      local nivel = self:oficioNivel(origen, "hunter")
      local pago = math.floor((recompensa + perdido * 0.3) * Oficios.bonoRecompensa(nivel))
      origen.oro = (origen.oro or 0) + pago
      self:ganarXpOficio(origen, pago / 3)
      self:mensaje("sistema", "", "Cobras " .. pago .. " de oro de recompensa por " .. e.nombre .. ".", origen)
    elseif origen and origen.kind == "guardia" then
      self:mensaje("sistema", "", "Los guardias te han detenido.", e)
    end
  end

  -- Buscados cercanos que ve un cazarrecompensas (para rastrearlos en el mapa).
  function Mundo:buscadosVisibles(p)
    local lista
    for _, e in pairs(self.entidades) do
      if e ~= p and e.kind == "jugador" and e.vivo and self:esBuscado(e) and e.modo == "mundo" then
        lista = lista or {}
        lista[#lista + 1] = {
          id = e.id, nombre = e.nombre, x = math.floor(e.x), y = math.floor(e.y), recompensa = e.recompensa or 0,
        }
      end
    end
    return lista
  end

  -- Fin del plazo de búsqueda.
  function Mundo:actualizarLey(p)
    if p.buscado and p.buscado <= self.tiempo then
      p.buscado, p.recompensa = nil, nil
      self:mensaje("sistema", "", "Ya no te buscan.", p)
    end
  end
end

return M
