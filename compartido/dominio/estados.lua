-- Estados alterados (quemar, sangrar, veneno, drenajes, lentitud, aturdimiento) y
-- poderes de las criaturas. Lo usan los poderes de los jugadores (con una probabilidad
-- de aplicar el estado) y los monstruos (al golpear o con un poder propio).
-- Los daños periódicos salen del ataque de quien aplica el estado; un estado nuevo del
-- mismo tipo renueva al anterior.
local Util = require("compartido.dominio.util")
local Balance = require("compartido.dominio.balance")

local E = {}

-- Los estados y los poderes de criaturas están en compartido/datos/estados.xml (los comentarios de cada campo,
-- también): tipo = con qué ataque se calcula el daño; dur y pct = valores por defecto (pct es la fracción del
-- ataque que pega cada segundo); ignora = el daño no baja con la defensa; en los poderes, estado = lo que aplica
-- y area = radio si pega a varios con coef.
local Config = require("compartido.dominio.configuracion")
E.def = Config.mapaOrden("estados", "estado", false)
E.poderes = Config.mapaOrden("estados", "poder", false)

function E.instalar(Mundo)
  -- Daño de un golpe de estado: parte del ataque de la fuente y se reduce con la defensa.
  local function danoPorSegundo(d, fuente, objetivo, pct)
    local tipo = d.tipo
    if not tipo then tipo = (fuente and fuente.tipoDano) or "fisico" end
    local atk = fuente and ((tipo == "magico") and (fuente.matk or fuente.atk) or fuente.atk) or 0
    if fuente and fuente.buffs then atk = atk * Mundo:buffMul(fuente, "atk") end
    local v = atk * pct * Balance.modNivel(fuente and fuente.nivel, objetivo.nivel)
    if not d.ignora then
      local def = (tipo == "magico") and (objetivo.mdef or 0) or (objetivo.def or 0)
      v = v * (1 - Balance.reduccion(def))
    end
    return math.max(1, math.floor(v + 0.5))
  end

  function Mundo:aplicarEstado(objetivo, tipo, dur, pct, fuente)
    local d = E.def[tipo]
    if not d or not objetivo or not objetivo.vivo or type(objetivo.hp) ~= "number" then return false end
    local kind = objetivo.kind
    if kind ~= "jugador" and kind ~= "bot" and kind ~= "monstruo" and kind ~= "guardia" then return false end
    if d.mana and not objetivo.mpMax then return false end
    dur = dur or d.dur
    pct = pct or d.pct
    if tipo == "aturdir" and objetivo.elite then dur = dur * 0.4 end
    objetivo.estados = objetivo.estados or {}
    local s = { hasta = self.tiempo + dur, fuente = fuente and fuente.id or nil }
    if d.dano then
      s.valor = danoPorSegundo(d, fuente, objetivo, pct)
      s.prox = self.tiempo + 1
    elseif d.mana then
      s.valor = math.max(2, math.floor(objetivo.mpMax * pct))
      s.prox = self.tiempo + 1
    elseif tipo == "lentitud" then
      objetivo.lentitud = { mul = pct, hasta = s.hasta }
    elseif tipo == "aturdir" then
      objetivo.aturdido = math.max(objetivo.aturdido or 0, dur)
    end
    objetivo.estados[tipo] = s
    self:numero(objetivo, d.nombre, d.color)
    return true
  end

  -- Intenta aplicar un estado de la lista de efectos de un poder o de un golpe.
  function Mundo:probarEstado(fuente, objetivo, ef)
    if not ef or not objetivo or not objetivo.vivo then return false end
    if math.random() >= (ef.prob or 1) then return false end
    return self:aplicarEstado(objetivo, ef.tipo, ef.dur, ef.pct, fuente)
  end

  -- Un tic de cada estado activo; retira los que terminaron.
  function Mundo:actualizarEstados(e)
    local est = e.estados
    if not est then return end
    if not e.vivo then e.estados = nil return end
    local alguno = false
    for tipo, s in pairs(est) do
      if self.tiempo >= s.hasta then
        est[tipo] = nil
      else
        alguno = true
        if s.prox and self.tiempo >= s.prox then
          s.prox = s.prox + 1
          local d = E.def[tipo]
          local fuente = s.fuente and self.entidades[s.fuente]
          if fuente and not fuente.vivo then fuente = nil end
          if d.mana then
            local quita = math.min(e.mp or 0, s.valor)
            if quita > 0 then
              e.mp = e.mp - quita
              self:numero(e, "-" .. quita .. " mp", d.color)
              if fuente then
                if fuente.mpMax then fuente.mp = math.min(fuente.mpMax, (fuente.mp or 0) + quita)
                else self:curar(fuente, quita * 0.8) end
              end
            end
          else
            self:danar(e, s.valor, fuente, false, d.color)
            if not e.vivo then break end
            if d.roba and fuente then self:curar(fuente, s.valor) end
          end
        end
      end
    end
    if not alguno then e.estados = nil end
  end

  -- Lista de nombres de estados activos, para dibujar sus animaciones en el cliente.
  function Mundo:estadosVisibles(e)
    if not e.estados then return nil end
    local lista
    for tipo in pairs(e.estados) do
      lista = lista or {}
      lista[#lista + 1] = tipo
    end
    if lista then table.sort(lista) end
    return lista
  end

  function Mundo:limpiarEstados(e)
    e.estados = nil
    e.lentitud = nil
  end

  -- Efectos de golpe de una criatura (golpe = { {tipo=, prob=, ...}, ... }).
  function Mundo:alGolpear(origen, objetivo)
    for _, ef in ipairs(origen.golpe or {}) do
      self:probarEstado(origen, objetivo, ef)
    end
  end

  -- Poderes propios de una criatura; los lanza cuando el objetivo está a su alcance.
  function Mundo:poderesMonstruo(e, o, d)
    e.cds = e.cds or {}
    for _, id in ipairs(e.poderes or {}) do
      local pw = E.poderes[id]
      if pw and d <= pw.rango and (e.cds[id] or 0) <= self.tiempo and self:puedeDanar(e, o) then
        e.cds[id] = self.tiempo + pw.cd + math.random() * 2
        self:numero(e, pw.nombre, { 1, 0.95, 0.7 })
        self:sonar(pw.sonido or "magia")
        if pw.area then
          self:efecto(pw.anim, o.x, o.y, 0.6)
          for _, v in pairs(self.entidades) do
            if v.vivo and self:mismoLugar(o, v) and Util.dist(o.x, o.y, v.x, v.y) <= pw.area and self:puedeDanar(e, v) then
              if pw.coef then self:golpear(e, v, pw.coef, 0.85) end
              self:probarEstado(e, v, pw.estado)
            end
          end
        else
          self:efecto(pw.anim, o.x, o.y, 0.5)
          self:probarEstado(e, o, pw.estado)
        end
        return true
      end
    end
    return false
  end
end

return E
