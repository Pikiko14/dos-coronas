-- Item Mall: una tienda especial que se paga con una moneda propia (Monedas Corona), distinta del oro.
--   * Tarjeta de experiencia doble y pergaminos de bonificación: se compran, van a la bolsa y se
--     usan desde ella (clic en la bolsa). Dan un bono temporal; el tiempo corre aunque estés
--     desconectado y se guarda con el personaje.
--   * Addons: sprites de personaje únicos (skins) que se compran una vez y se pueden poner o quitar.
-- Las monedas, de momento, las reparte un administrador (/admin monedas).
local M = {}

M.MONEDA = "Monedas Corona"
M.DURACION_SEG = 1800        -- pergaminos de combate
M.DURACION_EXP_SEG = 3600    -- tarjeta de experiencia doble

-- Bonos temporales. mult = multiplicador de lo que se gana; pct = fracción que se suma.
M.BONOS = {
  exp   = { nombre = "Experiencia doble", mult = 2, largo = true, color = { 1, 0.85, 0.3 }, etiqueta = "x2 EXP" },
  atk   = { nombre = "Ataque", pct = 0.15, color = { 0.95, 0.4, 0.3 }, etiqueta = "ATK" },
  def   = { nombre = "Defensa", pct = 0.15, color = { 0.45, 0.6, 0.95 }, etiqueta = "DEF" },
  int   = { nombre = "Inteligencia", pct = 0.20, matk = 0.08, color = { 0.7, 0.45, 0.95 }, etiqueta = "INT" },
  mdef  = { nombre = "Defensa mágica", pct = 0.15, color = { 0.35, 0.8, 0.85 }, etiqueta = "MDEF" },
  matk  = { nombre = "Ataque mágico", pct = 0.15, color = { 0.95, 0.5, 0.85 }, etiqueta = "MATK" },
  mvel  = { nombre = "Velocidad mágica", pct = 0.20, color = { 0.5, 0.9, 0.5 }, etiqueta = "MSPD" },
}
M.ORDEN_BONOS = { "exp", "atk", "def", "int", "mdef", "matk", "mvel" }

-- Objetos del mall (se registran en Datos.items). precio = en monedas.
M.OBJETOS = {
  { id = "tarjeta_exp", bono = "exp", nombre = "Tarjeta de experiencia doble", precio = 50, sprite = 699,
    texto = "Durante 1 hora ganas el doble de experiencia." },
  { id = "pergamino_atk", bono = "atk", nombre = "Pergamino de ataque", precio = 20, sprite = 697,
    texto = "+15% de ataque durante 30 minutos." },
  { id = "pergamino_def", bono = "def", nombre = "Pergamino de defensa", precio = 20, sprite = 697,
    texto = "+15% de defensa durante 30 minutos." },
  { id = "pergamino_int", bono = "int", nombre = "Pergamino de inteligencia", precio = 25, sprite = 697,
    texto = "+20% de maná y +8% de ataque mágico durante 30 minutos." },
  { id = "pergamino_mdef", bono = "mdef", nombre = "Pergamino de defensa mágica", precio = 20, sprite = 697,
    texto = "+15% de defensa mágica durante 30 minutos." },
  { id = "pergamino_matk", bono = "matk", nombre = "Pergamino de ataque mágico", precio = 20, sprite = 697,
    texto = "+15% de ataque mágico durante 30 minutos." },
  { id = "pergamino_mvel", bono = "mvel", nombre = "Pergamino de velocidad mágica", precio = 30, sprite = 697,
    texto = "Los poderes se recargan un 20% más rápido durante 30 minutos." },
}

-- Addons: sprites de personaje Ãºnicos (skins). Cambian el aspecto mientras no tengas un oficio
-- activo (el oficio activo usa su propio sprite). La imagen de cada uno estÃ¡ en el cliente
-- (render/personajes.lua, P.skins).
M.ADDONS = {
  skin_rey = { nombre = "Rey", precio = 300, desc = "Corona, capa y porte de monarca." },
  skin_princesa = { nombre = "Princesa", precio = 300, desc = "Cabello dorado y vestido real." },
  skin_explorador = { nombre = "Explorador", precio = 200, desc = "Pelo verde y ropa de viaje." },
  skin_fuego = { nombre = "Pelirrojo", precio = 200, desc = "Melena de fuego y mirada decidida." },
  skin_marea = { nombre = "Hija de la marea", precio = 250, desc = "Pelo turquesa como el mar." },
  skin_sombra = { nombre = "Sombra del bosque", precio = 250, desc = "Capucha oscura de cazador nocturno." },
}
M.ORDEN_ADDONS = { "skin_rey", "skin_princesa", "skin_explorador", "skin_fuego", "skin_marea", "skin_sombra" }
function M.duracion(bono)
  local d = M.BONOS[bono]
  return (d and d.largo) and M.DURACION_EXP_SEG or M.DURACION_SEG
end

function M.objeto(id)
  for _, o in ipairs(M.OBJETOS) do if o.id == id then return o end end
end

-- Segundos que quedan del bono (0 si no está activo). Los bonos guardan su fin en hora Unix.
function M.resta(p, bono, ahora)
  local fin = p.bonos and p.bonos[bono]
  if not fin then return 0 end
  return math.max(0, fin - ahora)
end

function M.instalar(Mundo)
  local function ahora(self) return self:reloj() end

  function Mundo:bonoActivo(p, bono)
    return M.resta(p, bono, ahora(self)) > 0
  end

  -- Multiplicador de experiencia por bono (1 si no hay).
  function Mundo:bonoExp(p)
    return self:bonoActivo(p, "exp") and M.BONOS.exp.mult or 1
  end

  -- Fracción que se recorta a los enfriamientos de los poderes.
  function Mundo:bonoVelocidadMagica(p)
    return self:bonoActivo(p, "mvel") and M.BONOS.mvel.pct or 0
  end

  -- Aplica los bonos de atributos (se llama al final de Mundo:recalcular).
  function Mundo:aplicarBonos(e)
    if not e.bonos or next(e.bonos) == nil then return end
    local t = ahora(self)
    local function on(b) return (e.bonos[b] or 0) > t end
    if on("atk") then e.atk = e.atk * (1 + M.BONOS.atk.pct) end
    if on("def") then e.def = e.def * (1 + M.BONOS.def.pct) end
    if on("mdef") then e.mdef = e.mdef * (1 + M.BONOS.mdef.pct) end
    if on("matk") then e.matk = e.matk * (1 + M.BONOS.matk.pct) end
    if on("int") then
      e.mpMax = e.mpMax * (1 + M.BONOS.int.pct)
      e.matk = e.matk * (1 + M.BONOS.int.matk)
    end
  end

  -- Usa una tarjeta o pergamino de la bolsa (clic en la bolsa). Si el bono ya está activo, suma tiempo.
  function Mundo:usarBono(p, idx)
    local slot = p.bolsa[idx]
    local def = slot and require("compartido.dominio.datos").item(slot.id)
    if not def or not def.bono then return "No se puede usar." end
    local b = M.BONOS[def.bono]
    if not b then return "No se puede usar." end
    local t = ahora(self)
    p.bonos = p.bonos or {}
    local base = math.max(p.bonos[def.bono] or 0, t)
    p.bonos[def.bono] = base + M.duracion(def.bono)
    slot.cant = (slot.cant or 1) - 1
    if slot.cant <= 0 then table.remove(p.bolsa, idx) end
    self:recalcular(p)
    self:marcarProgreso(p)
    self:mensaje("sistema", "", b.nombre .. " activo durante " .. math.floor(M.duracion(def.bono) / 60) .. " minutos.", p)
    return nil
  end

  -- Compra un objeto del mall con monedas: va a la bolsa.
  function Mundo:comprarMall(p, id)
    if p.kind ~= "jugador" then return "Solo los jugadores compran en el mall." end
    local o = M.objeto(id)
    if not o then return "Ese objeto no está en el mall." end
    if (p.monedas or 0) < o.precio then return "Te faltan monedas: cuesta " .. o.precio .. "." end
    if not self:darItem(p, o.id, 1) then return "Tu bolsa está llena." end
    p.monedas = p.monedas - o.precio
    self:marcarProgreso(p)
    self:mensaje("sistema", "", "Compras " .. o.nombre .. " por " .. o.precio .. " " .. M.MONEDA .. ". Úsala desde la bolsa.", p)
    return nil
  end

  -- Compra un addon (permanente) y lo pone.
  function Mundo:comprarAddon(p, id)
    if p.kind ~= "jugador" then return "Solo los jugadores compran addons." end
    local a = M.ADDONS[id]
    if not a then return "Ese addon no existe." end
    p.addons = p.addons or {}
    if p.addons[id] then return "Ya tienes ese addon." end
    if (p.monedas or 0) < a.precio then return "Te faltan monedas: cuesta " .. a.precio .. "." end
    p.monedas = p.monedas - a.precio
    p.addons[id] = true
    p.addonActivo = id
    self:marcarProgreso(p)
    self:mensaje("sistema", "", a.nombre .. " es tuyo y ya lo llevas puesto.", p)
    return nil
  end

  -- Pone o quita un addon que ya tienes.
  function Mundo:alternarAddon(p, id)
    if p.kind ~= "jugador" then return "Solo los jugadores llevan addons." end
    if not (p.addons and p.addons[id]) then return "Aún no tienes ese addon." end
    p.addonActivo = (p.addonActivo ~= id) and id or nil
    self:marcarProgreso(p)
    return nil
  end

  -- Acciones del cliente.
  function Mundo:accionMall(p, nombre, datos)
    local err
    if nombre == "mall_comprar" then err = self:comprarMall(p, tostring(datos.id))
    elseif nombre == "mall_addon_comprar" then err = self:comprarAddon(p, tostring(datos.id))
    elseif nombre == "mall_addon" then err = self:alternarAddon(p, tostring(datos.id))
    end
    if err then self:mensaje("sistema", "", err, p) end
    return nil
  end

  -- Caduca los bonos terminados y avisa. Una vez por segundo.
  function Mundo:actualizarBonos(dt)
    self._bonoT = (self._bonoT or 0) + dt
    if self._bonoT < 1 then return end
    self._bonoT = 0
    local t = ahora(self)
    for _, e in pairs(self.entidades) do
      if e.kind == "jugador" and e.bonos then
        local cambio = false
        for bono, fin in pairs(e.bonos) do
          if fin <= t then
            e.bonos[bono] = nil
            cambio = true
            self:mensaje("sistema", "", "Termina tu bono: " .. (M.BONOS[bono] and M.BONOS[bono].nombre or bono) .. ".", e)
          end
        end
        if cambio then self:recalcular(e) end
      end
    end
  end

  -- Lo que ve el cliente: monedas, bonos con su resta y addons.
  function Mundo:resumenMall(p)
    local bonos
    local t = ahora(self)
    for bono, fin in pairs(p.bonos or {}) do
      if fin > t then
        bonos = bonos or {}
        bonos[bono] = math.floor(fin - t)
      end
    end
    local addons = {}
    for id in pairs(p.addons or {}) do addons[#addons + 1] = id end
    table.sort(addons)
    return { monedas = p.monedas or 0, bonos = bonos, addons = addons, addonActivo = p.addonActivo }
  end
end

return M
