-- Monturas de transporte: se compran en las cuadras (y en las posadas del camino), se montan con
-- una tecla y dan velocidad y/o capacidad de carga para las mercancías de los comerciantes.
--   vel:   fracción extra de velocidad al ir montado.
--   carga: unidades de mercancía extra que se pueden llevar.
-- Se bajan solas dentro de casas y campos de batalla.
local M = {}

M.MAX = 7
-- Vida de las monturas: si vas montado, los golpes bajan primero la vida de la montura. Al
-- llegar a cero cae (la carga queda en el suelo), te bajas y no puedes usarla un rato.
M.VIDA_MULT = 1
M.RECUPERA_SEG = 300       -- cuánto tarda en poder usarse de nuevo una montura caída
M.REGEN_FRAC = 0.02        -- fracción de su vida que recupera por segundo si no la golpean
M.REGEN_ESPERA = 15        -- segundos sin golpes antes de empezar a recuperar

M.especies = {
  buey = {
    nombre = "Buey de carga", nivel = 5, precio = 900, vel = 0.10, carga = 22, requiereOficio = true, vida = 500,
    desc = "Lento pero fuerte: carga mucho más. Solo con el oficio activo.",
  },
  caballo = {
    nombre = "Caballo", nivel = 10, precio = 1000, vel = 0.40, carga = 6, vida = 350, requiereOficio = true,
    desc = "El más rápido para cruzar el mapa. Solo con el oficio activo.",
  },
  carreta = {
    nombre = "Carreta cubierta", nivel = 14, precio = 4500, vel = 0.06, carga = 90, oficio = "trader", requiereOficio = true, vida = 1100,
    desc = "Una carreta de mercader: carga enorme. Solo para comerciantes con el oficio activo.",
  },
}
-- Monturas de viaje: no llevan mercancía ni exigen oficio activo. Su aspecto sigue la facción del
-- jinete (Alba: blanco y oro; Ocaso: negro y violeta). Ir montado no permite atacar.
M.especies.corcel_real = {
  nombre = "Corcel real", nivel = 12, precio = 2500, vel = 0.38, carga = 0, vida = 420,
  desc = "El caballo de tu reino: blanco del Alba o negro del Ocaso. Rápido y noble.",
}
M.especies.lobo_guerra = {
  nombre = "Lobo de guerra", nivel = 16, precio = 3600, vel = 0.45, carga = 0, vida = 380,
  desc = "Pelaje de escarcha o de sombra. El más veloz entre árboles y caminos.",
}
M.especies.bisonte_guerra = {
  nombre = "Bisonte acorazado", nivel = 20, precio = 4800, vel = 0.28, carga = 0, vida = 1000,
  desc = "Lento pero casi imposible de derribar: su vida es la más alta.",
}
M.especies.corcel_fuego = {
  nombre = "Corcel de fuego", nivel = 25, precio = 7000, vel = 0.50, carga = 0, vida = 520,
  desc = "Dorado como el sol del Alba o rojo como el ascua del Ocaso. El más rápido.",
}
M.orden = { "buey", "caballo", "carreta", "corcel_real", "lobo_guerra", "bisonte_guerra", "corcel_fuego" }

function M.instalar(Mundo)
  function M.vidaMax(especie)
  local d = M.especies[especie]
  return math.max(1, math.floor(((d and d.vida) or 300) * M.VIDA_MULT))
end

-- Vida actual y máxima de una montura de p (llena si aún no se ha tocado).
function Mundo:vidaMontura(p, especie)
  p.monturaVida = p.monturaVida or {}
  local max = M.vidaMax(especie)
  if p.monturaVida[especie] == nil then p.monturaVida[especie] = max end
  return p.monturaVida[especie], max
end

-- Los golpes al jinete bajan antes la vida de su montura. Devuelve true si la montura los absorbe.
function Mundo:danarMontura(p, cantidad, origen)
  if not p.montado or p.kind ~= "jugador" then return false end
  local hp, max = self:vidaMontura(p, p.montado)
  hp = hp - cantidad
  p.monturaVida[p.montado] = math.max(0, hp)
  p.monturaGolpe = self.tiempo
  p.ultimoGolpe = self.tiempo
  p.flash = 0.12
  if origen then p.amenaza = origen.id end
  self:numero(p, tostring(-cantidad), { 0.9, 0.65, 0.3 })
  -- quien ataca a un comerciante montado comete un delito y abre pelea
  if origen and (origen.kind == "jugador" or origen.kind == "bot") and origen.job == "thief" and p.job == "trader" then
    self:abrirCombate(origen, p)
    if not self:esBuscado(origen) then self:marcarBuscado(origen, 120, self:valorCarga(p.carga)) end
  end
  if hp <= 0 then self:romperMontura(p, origen) end
  return true
end

-- La montura cae: la carga se queda en el suelo, el jinete baja (vivo) y la montura descansa.
function Mundo:romperMontura(p, origen)
  local especie = p.montado
  local d = especie and M.especies[especie]
  p.montado = nil
  p.monturaCaida = p.monturaCaida or {}
  p.monturaCaida[especie] = self.tiempo + M.RECUPERA_SEG
  self:soltarCargaMuerto(p)
  self:recalcularCarga(p)
  self:mensaje("sistema", "", "¡Tu " .. (d and d.nombre or "montura") .. " ha caído! Se recupera en " .. math.floor(M.RECUPERA_SEG / 60) .. " minutos.", p)
  if origen and origen ~= p then
    self:mensaje("sistema", "", "Derribas la montura de " .. p.nombre .. ": su mercancía queda en el suelo.", origen)
  end
end

-- Cada segundo: las monturas heridas se recuperan y las caídas vuelven a estar listas.
function Mundo:actualizarMonturas(dt)
  self._montT = (self._montT or 0) + dt
  if self._montT < 1 then return end
  local paso = self._montT
  self._montT = 0
  for _, e in pairs(self.entidades) do
    if e.kind == "jugador" and e.monturaVida then
      for especie, hp in pairs(e.monturaVida) do
        local max = M.vidaMax(especie)
        local hasta = e.monturaCaida and e.monturaCaida[especie]
        if hasta then
          if self.tiempo >= hasta then
            e.monturaCaida[especie] = nil
            e.monturaVida[especie] = max
          end
        elseif hp < max and (e.montado ~= especie or (self.tiempo - (e.monturaGolpe or -99)) > M.REGEN_ESPERA)
          and (self.tiempo - (e.monturaGolpe or -99)) > M.REGEN_ESPERA then
          e.monturaVida[especie] = math.min(max, hp + max * M.REGEN_FRAC * paso)
        end
      end
    end
  end
end

function Mundo:comprarMontura(p, especie)
    if p.kind ~= "jugador" then return "Solo los jugadores compran monturas." end
    local d = M.especies[especie]
    if not d then return "Esa montura no existe." end
    p.monturas = p.monturas or {}
    for _, t in ipairs(p.monturas) do
      if t == especie then return "Ya tienes esa montura." end
    end
    if #p.monturas >= M.MAX then return "No puedes cuidar más monturas." end
    if (p.nivel or 1) < d.nivel then return "Necesitas nivel " .. d.nivel .. "." end
    if d.oficio and p.job ~= d.oficio then return "Solo para el oficio de comerciante." end
    if (p.oro or 0) < d.precio then return "Cuesta " .. d.precio .. " de oro." end
    p.oro = p.oro - d.precio
    p.monturas[#p.monturas + 1] = especie
    self:marcarProgreso(p)
    self:mensaje("sistema", "", d.nombre .. " es tuya. Pulsa O para montar.", p)
    return nil
  end

  -- Monta la montura indicada (o la primera) o se baja si ya iba montado en ella.
  function Mundo:alternarMontura(p, especie)
    if p.kind ~= "jugador" then return end
    local lista = p.monturas or {}
    if p.montado and (especie == nil or especie == p.montado) then
      p.montado = nil
      self:recalcularCarga(p)
      return nil
    end
    especie = especie or p.monturaPreferida or lista[1]
    local d = M.especies[especie]
    local tiene = false
    for _, t in ipairs(lista) do if t == especie then tiene = true end end
    if not d or not tiene then return "No tienes monturas: compra una en la cuadra." end
    if p.modo ~= "mundo" then return "Aquí no se puede montar." end
    if (p.z or 0) > 0 then return "No se monta en las alturas." end
    if d.oficio and p.job ~= d.oficio then return "Solo para el oficio de comerciante." end
    if d.requiereOficio and not p.job then return "Las monturas solo se usan con el oficio activo (activa tu oficio en el menú o con Y)." end
    local hasta = p.monturaCaida and p.monturaCaida[especie]
    if hasta and hasta > self.tiempo then
      return "Tu " .. d.nombre .. " está herida: se recupera en " .. math.ceil(hasta - self.tiempo) .. " s."
    end
    p.montado, p.monturaPreferida = especie, especie
    self:recalcularCarga(p)
    return nil
  end

  -- Si el oficio se desactiva (o cambia), las monturas de carga se bajan solas.
  function Mundo:revisarMontura(p)
    local d = p.montado and M.especies[p.montado]
    if d and d.requiereOficio and (not p.job or (d.oficio and p.job ~= d.oficio)) then
      p.montado = nil
      self:recalcularCarga(p)
      self:mensaje("sistema", "", "Bajas de la montura de carga: solo se usa con el oficio activo.", p)
    end
  end

  -- Bonos de la montura puesta.
  function Mundo:bonoMontura(p)
    local d = p.montado and M.especies[p.montado]
    return d and d.vel or 0, d and d.carga or 0
  end
end

return M
