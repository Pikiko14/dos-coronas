-- Caravanas de comerciantes (PNJ): salen de una ciudad con mercancías y recorren los caminos
-- hasta otra. Los ladrones pueden asaltarlas, a veces las emboscan bandidos y los
-- cazarrecompensas pueden escoltarlas para cobrar al llegar.
local Util = require("compartido.dominio.util")
local Oficios = require("compartido.dominio.oficios")
local Datos = require("compartido.dominio.datos")

local M = {}

M.MAX = 0            -- caravanas automáticas del servidor: ninguna (las caravanas son los comerciantes jugadores)
M.INTERVALO = 70        -- segundos entre salidas
M.VELOCIDAD = 2.4
M.RADIO_ESCOLTA = 22    -- hasta dónde cuenta la escolta al llegar
M.DISTANCIA_MAX = 620   -- no se mandan caravanas más lejos que esto

function M.instalar(Mundo)
  -- ------------------------------------------------------------------ rutas
  -- Puerta de la ciudad más cercana a una artería (arriba o abajo).
  local function puertaHacia(ciudad, y)
    local mejor, md
    for _, a in ipairs(ciudad.accesos) do
      local d = math.abs(a.y - y)
      if not md or d < md then mejor, md = a, d end
    end
    return mejor
  end

  local function arteriaDe(mapa, y)
    local ar = mapa.arterias
    return math.abs(y - ar.norte) <= math.abs(y - ar.sur) and ar.norte or ar.sur
  end

  -- Puntos por los que pasa una caravana de una ciudad a otra, siguiendo los caminos.
  function Mundo:rutaCaravana(a, b)
    local mapa = self.mapas.mundo
    local ga = puertaHacia(a, b.y + b.h / 2)
    local gb = puertaHacia(b, a.y + a.h / 2)
    local ya, yb = arteriaDe(mapa, ga.y), arteriaDe(mapa, gb.y)
    local sale = ga.y < ya and 1 or -1
    local entra = gb.y < yb and 1 or -1
    local ruta = {
      { x = ga.x + 0.5, y = ga.y + sale * 1.5 },
      { x = ga.x + 0.5, y = ya + 0.5 },
    }
    if ya ~= yb then
      local cx = math.floor(mapa.w / 2)
      ruta[#ruta + 1] = { x = cx + 0.5, y = ya + 0.5 }
      ruta[#ruta + 1] = { x = cx + 0.5, y = yb + 0.5 }
    end
    ruta[#ruta + 1] = { x = gb.x + 0.5, y = yb + 0.5 }
    ruta[#ruta + 1] = { x = gb.x + 0.5, y = gb.y + entra * 1.5 }
    return ruta
  end

  local function largoRuta(ruta)
    local n = 0
    for i = 2, #ruta do n = n + Util.dist(ruta[i - 1].x, ruta[i - 1].y, ruta[i].x, ruta[i].y) end
    return n
  end

  -- ------------------------------------------------------------------ salida
  function Mundo:contarCaravanas()
    local n = 0
    for _, e in pairs(self.entidades) do
      if e.kind == "caravana" and e.vivo then n = n + 1 end
    end
    return n
  end

  function Mundo:salirCaravana(a, b)
    local mapa = self.mapas.mundo
    if not a then
      local c = mapa.ciudades
      a = c[math.random(#c)]
    end
    if not b then
      local opciones = {}
      for _, c in ipairs(mapa.ciudades) do
        if c ~= a and Util.dist(a.x, a.y, c.x, c.y) <= M.DISTANCIA_MAX then opciones[#opciones + 1] = c end
      end
      if #opciones == 0 then return nil end
      b = opciones[math.random(#opciones)]
    end
    local ruta = self:rutaCaravana(a, b)
    local sitio = self:sitioPorId(a.id)
    local carga, valor = {}, 0
    local bienes = sitio and sitio.perfil.produce or { "trigo", "madera" }
    for _, bien in ipairs(bienes) do
      local cant = math.random(10, 26)
      carga[bien] = cant
      valor = valor + cant * Oficios.BIENES[bien].base
    end
    valor = math.floor(valor * 0.9)
    local largo = largoRuta(ruta)
    local id = self:idNuevo()
    local hpMax = 500 + math.floor(valor * 0.25)
    local e = {
      id = id, kind = "caravana", nombre = "Caravana de " .. a.nombre, faccion = a.faccion,
      x = ruta[1].x, y = ruta[1].y, z = 0, modo = "mundo", dir = 1, vivo = true,
      hp = hpMax, hpMax = hpMax, def = 12, mdef = 8, nivel = 8 + math.floor(valor / 220),
      carga = carga, valor = valor, origen = a.id, destino = b.id, nombreDestino = b.nombre,
      ruta = ruta, paso = 2, spd = M.VELOCIDAD, velx = 0, vely = 0, cds = {},
      salio = self.tiempo,
    }
    -- una de cada tres sufre una emboscada por el camino
    if math.random() < 0.34 then
      e.emboscada = { cuando = self.tiempo + (largo * 0.35 + math.random() * largo * 0.25) / M.VELOCIDAD, hecho = false }
    end
    self.entidades[id] = e
    return e
  end

  -- ------------------------------------------------------------------ bandidos
  local function bandidoPara(valor)
    if valor < 450 then return "bandido" end
    if valor < 900 then return "asaltante" end
    return "saqueador"
  end

  function Mundo:emboscar(e)
    local id = bandidoPara(e.valor)
    local n = 2 + math.random(0, 1)
    for i = 1, n do
      local ang = math.random() * math.pi * 2
      local x, y = e.x + math.cos(ang) * 5, e.y + math.sin(ang) * 5
      local m = self:spawnMonstruo(id, x, y, { x = e.x, y = e.y })
      if m then
        self:colocarCerca(m, x, y)
        m.efimero = self.tiempo + 150
        m.objetivo = e.id
        m.agresivo = true
      end
    end
    self:mensaje("sistema", "", "¡Bandidos atacan a la " .. e.nombre .. "!", e)
  end

  -- ------------------------------------------------------------------ movimiento
  function Mundo:llegaCaravana(e)
    local pago = 0
    for _, p in pairs(self.entidades) do
      if (p.kind == "jugador" or p.kind == "bot") and p.escolta == e.id and p.vivo then
        if Util.dist(p.x, p.y, e.x, e.y) <= M.RADIO_ESCOLTA then
          local nivel = self:oficioNivel(p, "hunter")
          local cobro = math.floor(e.valor * 0.10 * Oficios.bonoRecompensa(nivel) + 40)
          p.oro = (p.oro or 0) + cobro
          self:ganarXpOficio(p, cobro / 3)
          self:mensaje("sistema", "", "La " .. e.nombre .. " llega a " .. e.nombreDestino .. ". Cobras " .. cobro .. " de oro por la escolta.", p)
          self:marcarProgreso(p)
          pago = pago + cobro
        else
          self:mensaje("sistema", "", "Te quedaste atrás: la caravana llegó sin tu escolta.", p)
        end
        p.escolta = nil
      end
    end
    e.borrar = true
  end

  function Mundo:actualizarCaravana(e, dt)
    if not e.vivo then return end
    if e.emboscada and not e.emboscada.hecho and self.tiempo >= e.emboscada.cuando then
      e.emboscada.hecho = true
      self:emboscar(e)
    end
    local destino = e.ruta[e.paso]
    if not destino then self:llegaCaravana(e) return end
    -- se detiene si la están atacando para que se la pueda defender
    local d = Util.dist(e.x, e.y, destino.x, destino.y)
    if d < 1.0 then
      e.paso = e.paso + 1
      e.atasco = 0
      return
    end
    local ddx, ddy = 0, 0
    if (e.ultimoGolpe or -10) + 1.5 < self.tiempo then
      if e.tramo then ddx, ddy = Util.signo(destino.x - e.x), Util.signo(destino.y - e.y)
      else ddx, ddy = self:mejorDireccion(e, destino.x - e.x, destino.y - e.y) end
    end
    local antes = e.x + e.y
    self:avanzar(e, dt, ddx, ddy, e.spd)
    if ddx ~= 0 or ddy ~= 0 then
      if math.abs((e.x + e.y) - antes) < 0.001 and not e.tramo then
        e.atasco = (e.atasco or 0) + dt
        -- atascada: salta al siguiente punto del camino
        if e.atasco > 8 then
          e.x, e.y, e.atasco, e.tramo = destino.x, destino.y, 0, nil
        end
      else
        e.atasco = 0
      end
    end
  end

  -- La caravana cae: suelta lo que le quede.
  function Mundo:cayeCaravana(e, origen)
    local id = self:idNuevo()
    local bienes = {}
    local n = 0
    for bien, c in pairs(e.carga or {}) do
      local resto = math.floor(c * (e.valor and e.valor > 0 and 0.6 or 0))
      if resto > 0 then bienes[bien] = resto n = n + resto end
    end
    e.borrar = true
    if n > 0 then
      self.entidades[id] = {
        id = id, kind = "loot", nombre = "Mercancías", x = e.x, y = e.y, modo = "mundo", vivo = true, z = 0,
        oro = 0, items = {}, bienes = bienes, hasta = self.tiempo + 90,
      }
    end
    self:mensaje("mundo", "", "La " .. e.nombre .. " ha sido destruida.", nil)
    for _, p in pairs(self.entidades) do
      if p.escolta == e.id then
        p.escolta = nil
        self:mensaje("sistema", "", "La caravana ha caído: la escolta fracasa.", p)
      end
    end
  end

  -- ------------------------------------------------------------------ escolta (cazarrecompensas)
  function Mundo:escoltarCaravana(p, caravanaId)
    if p.job ~= "hunter" then return "Solo los cazarrecompensas escoltan." end
    local e = self.entidades[caravanaId]
    if not e or e.kind ~= "caravana" or not e.vivo then return "Esa caravana no existe." end
    if Util.dist(p.x, p.y, e.x, e.y) > 5 then return "Acércate a la caravana." end
    p.escolta = e.id
    self:mensaje("sistema", "", "Escoltas la " .. e.nombre .. " hasta " .. e.nombreDestino .. ". Mantente cerca y defiéndela.", p)
    return nil
  end

  -- ------------------------------------------------------------------ gestor
  function Mundo:actualizarCaravanas(dt)
    self._salidaCaravana = (self._salidaCaravana or (M.INTERVALO * 0.3)) - dt
    if self._salidaCaravana > 0 then return end
    self._salidaCaravana = M.INTERVALO
    if self:contarCaravanas() < M.MAX then self:salirCaravana() end
  end

  -- Lo que saben los oficios de las caravanas en marcha (para el mapa de los jugadores).
  function Mundo:caravanasVisibles()
    local lista
    for _, e in pairs(self.entidades) do
      if e.kind == "caravana" and e.vivo then
        lista = lista or {}
        lista[#lista + 1] = {
          id = e.id, x = math.floor(e.x), y = math.floor(e.y), destino = e.nombreDestino,
          valor = e.valor, escoltada = false,
        }
      end
    end
    return lista
  end
end

return M
