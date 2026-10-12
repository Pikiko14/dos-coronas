-- Sistema de oficios: comercio, protección y robo de mercancías.
--   Comerciante (trader): compra mercancías donde sobran y las vende donde faltan; lleva carga.
--   Cazarrecompensas (hunter): protege caravanas y caza a los ladrones que se buscan.
--   Ladrón (thief): roba mercancías de comerciantes y caravanas y las vende al contacto.
-- Un personaje tiene un oficio activo a la vez; cada oficio conserva su nivel.
local Util = require("compartido.dominio.util")

local M = {}

M.NIVEL_MAX = 10
M.COSTE_CAMBIO = 300

M.OFICIOS = {
  trader = {
    nombre = "Comerciante", icono = "C",
    desc = "Compra mercancías donde sobran y véndelas donde faltan. Cuanto más lejos, más ganas. Cuidado con los ladrones.",
  },
  hunter = {
    nombre = "Cazarrecompensas", icono = "H",
    desc = "Escolta caravanas y caza a los ladrones que se buscan: cobras recompensa por cada uno.",
  },
  thief = {
    nombre = "Ladrón", icono = "L",
    desc = "Roba mercancías de comerciantes y caravanas (fuera de las ciudades) y véndelas a un contacto. Te buscarán.",
  },
}
M.ORDEN = { "trader", "hunter", "thief" }

-- Mercancías: precio base y peso (1 unidad de carga cada una).
M.BIENES = {
  trigo = { nombre = "Trigo", base = 30, sprite = 699 },
  pescado = { nombre = "Pescado", base = 38, sprite = 699 },
  madera = { nombre = "Madera", base = 45, sprite = 699 },
  tela = { nombre = "Telas", base = 70, sprite = 699 },
  vino = { nombre = "Vino", base = 95, sprite = 699 },
  hierro = { nombre = "Hierro", base = 120, sprite = 699 },
  especias = { nombre = "Especias", base = 140, sprite = 699 },
  gemas = { nombre = "Gemas", base = 260, sprite = 699 },
}
M.ORDEN_BIENES = { "trigo", "pescado", "madera", "tela", "vino", "hierro", "especias", "gemas" }

-- Cuánto cuesta cada nivel de oficio (experiencia para pasar al siguiente).
function M.xpPara(nivel)
  return 150 + 100 * nivel * nivel
end

-- Capacidad de carga base según oficio y nivel.
function M.capacidadBase(job, nivel)
  if job == "trader" then return 20 + 4 * nivel end
  if job == "thief" then return 10 + 2 * nivel end
  return 0
end

-- Ventajas por nivel.
function M.descuentoCompra(nivel) return math.min(0.10, 0.01 * nivel) end
function M.bonoVenta(nivel) return math.min(0.12, 0.012 * nivel) end
function M.probRobo(nivel) return math.min(0.85, 0.50 + 0.03 * nivel) end
function M.tiempoRobo(nivel) return math.max(1.6, 3.4 - 0.18 * nivel) end
function M.precioPerista(nivel) return math.min(0.70, 0.52 + 0.02 * nivel) end
function M.bonoRecompensa(nivel) return 1 + 0.05 * nivel end

-- Hash estable de un texto -> [0, 1).
local function hash(t)
  local h = 2166136261
  for i = 1, #t do h = (h * 16777619 + t:byte(i)) % 4294967296 end
  return (h % 100003) / 100003
end
M.hash = hash

-- Perfil económico de un sitio: qué produce (barato) y qué demanda (caro).
function M.perfilDe(id, indice)
  local n = #M.ORDEN_BIENES
  local base = math.floor(hash(id .. "p") * n)
  local a = M.ORDEN_BIENES[(base % n) + 1]
  local b = M.ORDEN_BIENES[((base + 3) % n) + 1]
  local c = M.ORDEN_BIENES[((base + 4) % n) + 1]
  local d = M.ORDEN_BIENES[((base + 7) % n) + 1]
  return { produce = { a, b }, demanda = { c, d } }
end

local DIVISOR_PRESION = 300 -- segundos en recuperar buena parte de la presión de oferta/demanda

function M.instalar(Mundo)
  -- ------------------------------------------------------------------ sitios de comercio
  function Mundo:sitiosComercio()
    if self._sitios then return self._sitios end
    local mapa = self.mapas.mundo
    local lista = {}
    for _, c in ipairs(mapa.ciudades) do
      lista[#lista + 1] = { id = c.id, nombre = c.nombre, x = c.x + c.w / 2, y = c.y + c.h / 2, tipo = "ciudad" }
    end
    for _, pu in ipairs(mapa.puestos or {}) do
      for _, n in ipairs(pu.npcs) do
        if n.rol == "comercio" then
          lista[#lista + 1] = { id = "puesto" .. pu.id, nombre = pu.nombre, x = pu.x, y = pu.y, tipo = "puesto" }
          break
        end
      end
    end
    for _, s in ipairs(lista) do s.perfil = M.perfilDe(s.id) end
    self._sitios = lista
    self.presion = self.presion or {}
    return lista
  end

  function Mundo:sitioPorId(id)
    for _, s in ipairs(self:sitiosComercio()) do
      if s.id == id then return s end
    end
  end

  -- El sitio de comercio del jugador: el del mercader mayor que tiene cerca.
  function Mundo:sitioCerca(p)
    local mejor, md = nil, 5
    for _, e in pairs(self.entidades) do
      if e.kind == "npc" and e.rol == "comercio" and self:mismoLugar(p, e) then
        local d = Util.dist(p.x, p.y, e.x, e.y)
        if d < md then mejor, md = e, d end
      end
    end
    if not mejor then return nil end
    local s, sd = nil, 60
    for _, sitio in ipairs(self:sitiosComercio()) do
      local d = Util.dist(mejor.x, mejor.y, sitio.x, sitio.y)
      if d < sd then s, sd = sitio, d end
    end
    return s
  end

  -- ------------------------------------------------------------------ precios
  local function etiquetaPresion(self, sitioId, bien)
    self.presion = self.presion or {}
    self.presion[sitioId] = self.presion[sitioId] or {}
    return self.presion[sitioId]
  end

  -- Factor de oferta y demanda del sitio para un bien (sin la presión de las compraventas).
  function Mundo:factorSitio(sitio, bien)
    local f = 1
    for _, b in ipairs(sitio.perfil.produce) do if b == bien then f = 0.6 end end
    for _, b in ipairs(sitio.perfil.demanda) do if b == bien then f = 1.45 end end
    -- cada sitio tiene su pequeña variación
    return f * (0.95 + 0.1 * hash(sitio.id .. bien))
  end

  function Mundo:presionDe(sitio, bien)
    local t = etiquetaPresion(self, sitio.id)
    return t[bien] or 0
  end

  -- Precio por unidad para comprar o vender en un sitio.
  function Mundo:precioBien(sitio, bien, comprando)
    local d = M.BIENES[bien]
    local base = d.base * self:factorSitio(sitio, bien) * (1 + self:presionDe(sitio, bien))
    return math.max(1, math.floor(base * (comprando and 1.04 or 0.92) + 0.5))
  end

  -- Las compraventas mueven el precio y con el tiempo se recupera.
  function Mundo:mover(sitio, bien, unidades)
    local t = etiquetaPresion(self, sitio.id)
    t[bien] = math.max(-0.4, math.min(0.4, (t[bien] or 0) + unidades * 0.012))
  end

  function Mundo:recuperarPresion(dt)
    for _, t in pairs(self.presion or {}) do
      for bien, v in pairs(t) do
        v = v * (1 - dt / DIVISOR_PRESION)
        t[bien] = math.abs(v) < 0.002 and nil or v
      end
    end
  end

  -- ------------------------------------------------------------------ carga
  local function sumar(carga)
    local n = 0
    for _, c in pairs(carga or {}) do n = n + c end
    return n
  end

  function Mundo:pesoCarga(p)
    return sumar(p.carga) + sumar(p.cargaRobada)
  end

  function Mundo:oficioNivel(p, job)
    local o = p.oficios and p.oficios[job or p.job]
    return o and o.nivel or 1
  end

  function Mundo:capacidadCarga(p)
    local _, extra = 0, 0
    if self.bonoMontura then _, extra = self:bonoMontura(p) end
    return M.capacidadBase(p.job, self:oficioNivel(p)) + extra
  end

  -- Recalcula el peso y la lentitud por ir cargado (una montura la reduce).
  function Mundo:recalcularCarga(p)
    local cap = self:capacidadCarga(p)
    local peso = self:pesoCarga(p)
    p.capacidadCarga, p.pesoCarga = cap, peso
    local ratio = cap > 0 and math.min(1.5, peso / cap) or 0
    p.penalCarga = 0.3 * ratio * (p.montado and 0.3 or 1)
  end

  -- ------------------------------------------------------------------ oficios
  function Mundo:elegirOficio(p, job, lugar)
    if p.kind ~= "jugador" then return "Solo los jugadores tienen oficio." end
    if not M.OFICIOS[job] then return "Ese oficio no existe." end
    if job == p.oficioElegido then return "Ya eres " .. M.OFICIOS[job].nombre:lower() .. "." end
    if lugar == "ladron" and job ~= "thief" then return "Aquí solo se aprende el oficio de ladrón." end
    if lugar == "ciudad" and job == "thief" then return "El oficio de ladrón se aprende en un refugio de ladrones." end
    if lugar == "capitan" and job ~= "hunter" then return "Aquí solo se aprende el oficio de cazarrecompensas." end
    p.oficios = p.oficios or {}
    local nuevo = p.oficios[job] == nil
    local coste = p.oficioElegido and M.COSTE_CAMBIO or 0
    if (p.oro or 0) < coste then return "Cambiar de oficio cuesta " .. coste .. " de oro." end
    if self:pesoCarga(p) > 0 then return "Vende o suelta tu carga antes de cambiar de oficio." end
    if p.buscado and p.buscado > self.tiempo then return "Con la ley detrás de ti, no puedes cambiar de oficio." end
    p.oro = p.oro - coste
    p.oficios[job] = p.oficios[job] or { nivel = 1, xp = 0 }
    p.oficioElegido, p.job = job, nil -- se elige aqui y se activa con la tecla Y
    p.contrato = nil
    p.escolta = nil
    self:recalcularCarga(p)
    self:marcarProgreso(p)
    self:mensaje("sistema", "", "Ahora eres " .. M.OFICIOS[job].nombre .. (nuevo and "." or (" (nivel " .. p.oficios[job].nivel .. ")."))
      .. " Pulsa Y para activar el oficio cuando quieras usarlo.", p)
    return nil
  end

  -- Mensaje de error: si el oficio es el tuyo pero no está activo, di como activarlo.
  function Mundo:avisoOficio(p, job, texto)
    if p.oficioElegido == job and not p.job then return "Activa tu oficio con la tecla Y." end
    return texto
  end

  -- Activa o desactiva el oficio elegido (tecla Y). Con el oficio activo se usa su sistema y
  -- el personaje cambia de aspecto.
  function Mundo:alternarOficio(p)
    if p.kind ~= "jugador" then return "Solo los jugadores tienen oficio." end
    if p.job then
      if self:pesoCarga(p) > 0 then return "Vende o suelta tu carga antes de desactivar el oficio." end
      if self:esBuscado(p) then return "Con la ley detrás de ti, no puedes dejar el oficio." end
      if p.robo then return "No puedes dejar el oficio en pleno robo." end
      p.job, p.contrato, p.escolta = nil, nil, nil
      self:recalcularCarga(p)
      self:mensaje("sistema", "", "Oficio desactivado. Pulsa Y para activarlo de nuevo.", p)
      return nil
    end
    if not p.oficioElegido then return "Aún no tienes oficio: aprende uno con un maestro de oficios." end
    if p.modo ~= "mundo" then return "Aquí no puedes activar el oficio." end
    p.job = p.oficioElegido
    self:recalcularCarga(p)
    self:marcarProgreso(p)
    self:mensaje("sistema", "", "Oficio activado: " .. M.OFICIOS[p.job].nombre .. ". Pulsa Y para desactivarlo.", p)
    return nil
  end

  -- Al morir, la mercancía que llevabas cae al suelo (una pieza por tipo) y cualquier comerciante
  -- o ladrón puede cargarla. Lo robado que llevaba un ladrón se pierde con la ley (ver caeBuscado).
  function Mundo:soltarCargaMuerto(p)
    if p.kind ~= "jugador" and p.kind ~= "bot" then return end
    local cargada = false
    for bien, c in pairs(p.carga or {}) do
      if c > 0 then
        cargada = true
        self:dejarEnSuelo({
          nombre = M.BIENES[bien] and M.BIENES[bien].nombre or "Mercancía", bien = bien, oro = 0, items = {},
          bienes = { [bien] = c }, hasta = self.tiempo + 90,
        }, p.x, p.y, p.modo, p.z)
      end
    end
    if cargada then
      p.carga = {}
      self:recalcularCarga(p)
      self:mensaje("sistema", "", "Tu mercancía cae al suelo: otros pueden llevársela.", p)
    end
  end

  function Mundo:ganarXpOficio(p, cant)
    local o = p.job and p.oficios and p.oficios[p.job]
    if not o or cant <= 0 then return end
    o.xp = o.xp + math.floor(cant)
    local subio = false
    while o.nivel < M.NIVEL_MAX and o.xp >= M.xpPara(o.nivel) do
      o.xp = o.xp - M.xpPara(o.nivel)
      o.nivel = o.nivel + 1
      subio = true
    end
    if o.nivel >= M.NIVEL_MAX then o.xp = math.min(o.xp, M.xpPara(M.NIVEL_MAX)) end
    if subio then
      self:recalcularCarga(p)
      self:mensaje("sistema", "", "Tu oficio de " .. M.OFICIOS[p.job].nombre:lower() .. " sube al nivel " .. o.nivel .. ".", p)
      self:numero(p, "OFICIO " .. o.nivel, { 0.5, 0.95, 1 })
    end
    self:marcarProgreso(p)
  end

  -- ------------------------------------------------------------------ comercio
  function Mundo:comprarBien(p, bien, cant)
    if p.job ~= "trader" then return self:avisoOficio(p, "trader", "Solo los comerciantes compran mercancías.") end
    local sitio = self:sitioCerca(p)
    if not sitio then return "Acércate a un mercader mayor." end
    if not M.BIENES[bien] then return "Esa mercancía no existe." end
    cant = math.floor(tonumber(cant) or 0)
    if cant < 1 then return nil end
    local libre = self:capacidadCarga(p) - self:pesoCarga(p)
    if libre < 1 then return "Vas cargado hasta arriba." end
    cant = math.min(cant, libre)
    local nivel = self:oficioNivel(p)
    local total, unidad = 0, 0
    -- el precio sube con cada unidad comprada
    local presionGuardada = self:presionDe(sitio, bien)
    for _ = 1, cant do
      unidad = math.floor(self:precioBien(sitio, bien, true) * (1 - M.descuentoCompra(nivel)) + 0.5)
      total = total + unidad
      self:mover(sitio, bien, 1)
    end
    if (p.oro or 0) < total then
      -- no alcanza: deshacer la presión y avisar
      local t = etiquetaPresion(self, sitio.id)
      t[bien] = presionGuardada ~= 0 and presionGuardada or nil
      return "Necesitas " .. total .. " de oro."
    end
    p.oro = p.oro - total
    p.carga = p.carga or {}
    p.carga[bien] = (p.carga[bien] or 0) + cant
    p.origenCarga = p.origenCarga or {}
    p.origenCarga[bien] = sitio.id
    -- coste medio para calcular la ganancia al vender
    p.costes = p.costes or {}
    local previo = p.costes[bien] or { cant = 0, total = 0 }
    p.costes[bien] = { cant = previo.cant + cant, total = previo.total + total }
    self:recalcularCarga(p)
    self:marcarProgreso(p)
    self:mensaje("sistema", "", "Compras " .. cant .. " de " .. M.BIENES[bien].nombre .. " por " .. total .. " de oro.", p)
    return nil
  end

  -- Distancia entre dos sitios: premia los trayectos largos.
  local function bonoDistancia(a, b)
    if not a or not b then return 0 end
    return math.min(0.5, Util.dist(a.x, a.y, b.x, b.y) / 1500)
  end

  function Mundo:venderBien(p, bien, cant)
    if p.job ~= "trader" then return self:avisoOficio(p, "trader", "Solo los comerciantes venden mercancías.") end
    local sitio = self:sitioCerca(p)
    if not sitio then return "Acércate a un mercader mayor." end
    local tengo = p.carga and p.carga[bien] or 0
    cant = math.min(math.floor(tonumber(cant) or 0), tengo)
    if cant < 1 then return "No llevas eso." end
    local nivel = self:oficioNivel(p)
    local origen = p.origenCarga and p.origenCarga[bien] and self:sitioPorId(p.origenCarga[bien])
    local total = 0
    for _ = 1, cant do
      local u = self:precioBien(sitio, bien, false) * (1 + M.bonoVenta(nivel)) * (1 + bonoDistancia(origen, sitio))
      total = total + math.floor(u + 0.5)
      self:mover(sitio, bien, -1)
    end
    local coste
    local c = p.costes and p.costes[bien]
    if c and c.cant > 0 then
      coste = math.floor(c.total * cant / c.cant)
      c.cant, c.total = c.cant - cant, c.total - coste
      if c.cant <= 0 then p.costes[bien] = nil end
    else
      -- carga de antes de entrar al mundo: se supone que costó el 70%
      coste = math.floor(total * 0.7)
    end
    p.oro = p.oro + total
    p.carga[bien] = tengo - cant
    if p.carga[bien] <= 0 then p.carga[bien] = nil end
    local ganancia = total - coste
    self:recalcularCarga(p)
    self:mensaje("sistema", "", "Vendes " .. cant .. " de " .. M.BIENES[bien].nombre .. " por " .. total ..
      " de oro" .. (ganancia > 0 and (" (ganas " .. ganancia .. ")") or (ganancia < 0 and (" (pierdes " .. -ganancia .. ")") or "")) .. ".", p)
    if ganancia > 0 then self:ganarXpOficio(p, ganancia / 4) end
    self:marcarProgreso(p)
    return nil
  end

  -- Lista que ve el panel de mercancías del sitio.
  function Mundo:infoMercancias(p)
    local sitio = self:sitioCerca(p)
    if not sitio then return { lejos = true } end
    local bienes = {}
    for _, id in ipairs(M.ORDEN_BIENES) do
      local etiqueta
      for _, b in ipairs(sitio.perfil.produce) do if b == id then etiqueta = "sobra" end end
      for _, b in ipairs(sitio.perfil.demanda) do if b == id then etiqueta = "falta" end end
      bienes[#bienes + 1] = {
        id = id, nombre = M.BIENES[id].nombre, compra = self:precioBien(sitio, id, true),
        venta = self:precioBien(sitio, id, false), tengo = p.carga and p.carga[id] or 0, etiqueta = etiqueta,
      }
    end
    self:recalcularCarga(p)
    return {
      sitio = sitio.nombre, bienes = bienes, peso = p.pesoCarga, capacidad = p.capacidadCarga,
      job = p.job, nivel = p.job and self:oficioNivel(p) or nil,
    }
  end

  -- ------------------------------------------------------------------ acciones del cliente
  -- Dónde está el jugador respecto a los maestros de oficio.
  function Mundo:lugarOficio(p)
    if self:npcCerca(p, "contacto") then return "ladron" end
    if self:npcCerca(p, "capitan") then return "capitan" end
    if self:npcCerca(p, "oficios") then return "ciudad" end
    return nil
  end

  function Mundo:infoOficios(p)
    local o = {}
    for _, id in ipairs(M.ORDEN) do
      local d = p.oficios and p.oficios[id]
      o[id] = d and { nivel = d.nivel, xp = d.xp, sig = M.xpPara(d.nivel) } or nil
    end
    local lugar = self:lugarOficio(p)
    local info = {
      lugar = lugar, job = p.oficioElegido, activo = p.job ~= nil, oficios = o, coste = M.COSTE_CAMBIO,
      peso = p.pesoCarga, capacidad = p.capacidadCarga,
      buscado = self:esBuscado(p) and { resta = p.buscado - self.tiempo, recompensa = p.recompensa } or nil,
    }
    if lugar == "ladron" then
      info.robado = p.cargaRobada
      info.valorRobado = 0
      local f = M.precioPerista(self:oficioNivel(p, "thief"))
      for bien, c in pairs(p.cargaRobada or {}) do info.valorRobado = info.valorRobado + math.floor(M.BIENES[bien].base * f * c) end
    end
    if lugar == "capitan" then
      info.buscados = self:buscadosVisibles(p) or {}
      info.caravanas = self:caravanasVisibles() or {}
    end
    return info
  end

  function Mundo:infoMonturas(p)
    local Monturas = require("compartido.dominio.monturas")
    local cat = {}
    for _, id in ipairs(Monturas.orden) do
      local d = Monturas.especies[id]
      local tengo = false
      for _, t in ipairs(p.monturas or {}) do if t == id then tengo = true end end
      cat[#cat + 1] = { id = id, nombre = d.nombre, nivel = d.nivel, precio = d.precio, vel = d.vel, carga = d.carga,
        oficio = d.oficio, desc = d.desc, tengo = tengo }
    end
    return { catalogo = cat, montado = p.montado, cerca = self:npcCerca(p, "establo") }
  end

  function Mundo:accionOficio(p, nombre, datos)
    local err
    local panel, info = "oficios", nil
    if nombre == "oficio_elegir" then
      local lugar = self:lugarOficio(p)
      if not lugar then err = "Acércate a un maestro de oficios."
      else err = self:elegirOficio(p, datos.job, lugar) end
    elseif nombre == "oficio_alternar" then
      err = self:alternarOficio(p)
      panel = nil
    elseif nombre == "mercancia_comprar" then
      err = self:comprarBien(p, datos.bien, datos.cant)
      panel = "mercancias"
    elseif nombre == "mercancia_vender" then
      err = self:venderBien(p, datos.bien, datos.cant)
      panel = "mercancias"
    elseif nombre == "mercancia_info" then
      panel = "mercancias"
    elseif nombre == "perista_vender" then
      if self:npcCerca(p, "contacto") then err = self:venderRobado(p)
      else err = "Acércate a tu contacto." end
    elseif nombre == "montura_comprar" then
      if self:npcCerca(p, "establo") then err = self:comprarMontura(p, datos.especie)
      else err = "Acércate a la cuadra." end
      panel = "establo"
    elseif nombre == "montura_alternar" then
      err = self:alternarMontura(p, datos.especie)
      panel = "establo"
    elseif nombre == "montura_info" then
      panel = "establo"
    elseif nombre == "escoltar" then
      err = self:escoltarCaravana(p, datos.id)
    elseif nombre == "robar" then
      err = self:iniciarRobo(p, datos.id)
      if err then self:mensaje("sistema", "", err, p) end
      return nil
    end
    if err then self:mensaje("sistema", "", err, p) end
    if panel == "mercancias" then info = self:infoMercancias(p)
    elseif panel == "establo" then info = self:infoMonturas(p)
    else info = self:infoOficios(p) end
    return { panel = panel, datos = info }
  end

  -- ------------------------------------------------------------------ recuperar carga
  -- Lo que un ladrón lleva robado (por tipo) y su valor aproximado.
  function Mundo:valorCarga(carga)
    local v = 0
    for bien, c in pairs(carga or {}) do v = v + c * M.BIENES[bien].base end
    return v
  end
end

return M
