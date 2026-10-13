-- Casa de subastas: los jugadores ponen objetos a la venta con un precio de salida (y,
-- si quieren, un precio de compra inmediata) durante un tiempo; otros pujan.
--   * El objeto se retira de la bolsa y queda en depósito hasta que termina la subasta.
--   * Quien puja deja su oro en depósito; al superarlo se le devuelve.
--   * Una puja en los últimos minutos alarga la subasta (para que no se gane en el último segundo).
--   * Al terminar, el ganador recibe el objeto y el vendedor el oro menos el impuesto; si nadie
--     pujó, el objeto vuelve a su dueño. Todo lo pendiente espera en el buzón de cada personaje.
-- El tiempo es el del reloj real (os.time), así las subastas siguen corriendo con el servidor
-- apagado. El dominio guarda todo en memoria y avisa de los cambios por los puertos
-- guardarSubasta, borrarSubasta, guardarBuzon y guardarJugador.
local Datos = require("compartido.dominio.datos")

local M = {}
require("compartido.dominio.configuracion").aplicar(M, "subastas")



local function categoriaDe(it)
  if not it then return "otros" end
  if it.hueco == "arma" then return "arma" end
  if it.hueco == "cabeza" or it.hueco == "pecho" or it.hueco == "piernas" or it.hueco == "pies" or it.hueco == "escudo" then
    return "armadura"
  end
  if it.hueco == "anillo" or it.hueco == "amuleto" or it.hueco == "mochila" then return "accesorio" end
  return "otros"
end
M.categoriaDe = categoriaDe

function M.subidaMinima(s)
  if s.oferta and s.oferta > 0 then
    return s.oferta + math.max(1, math.floor(s.oferta * M.SUBIDA_MINIMA))
  end
  return s.salida
end

function M.instalar(Mundo)
  function Mundo:ahoraSubastas()
    return (self.relojSubastas or os.time)()
  end

  function Mundo:iniciarSubastas()
    self.subastas = self.subastas or {}
    self.buzones = self.buzones or {}
    self.siguienteSubasta = self.siguienteSubasta or 1
  end

  -- Carga lo que da el almacén: subastas = lista, buzones = { [dbId] = { entregas } }.
  function Mundo:cargarSubastas(subastas, buzones)
    self.subastas, self.buzones, self.siguienteSubasta = {}, buzones or {}, 1
    for _, s in ipairs(subastas or {}) do
      self.subastas[s.id] = s
      if s.id >= self.siguienteSubasta then self.siguienteSubasta = s.id + 1 end
    end
  end

  local function guardarSub(self, s)
    if self.puertos.guardarSubasta then self.puertos.guardarSubasta(s) end
  end
  local function borrarSub(self, id)
    if self.puertos.borrarSubasta then self.puertos.borrarSubasta(id) end
  end
  local function guardarBuzon(self, dbId)
    if self.puertos.guardarBuzon then self.puertos.guardarBuzon(dbId, self.buzones[dbId] or {}) end
  end
  -- El oro y los objetos de un jugador se guardan ya: no puede quedar una puja sin descontar.
  local function guardarYa(self, p)
    if self.puertos.guardarJugador then self.puertos.guardarJugador(p) end
  end

  local function jugadorPorDbId(self, dbId)
    for _, e in pairs(self.entidades) do
      if e.kind == "jugador" and e.dbId == dbId and not e.borrar then return e end
    end
  end

  -- Pone algo en el buzón de un personaje (oro, un objeto o ambos).
  function Mundo:aBuzon(dbId, entrega)
    self:iniciarSubastas()
    local lista = self.buzones[dbId]
    if not lista then
      lista = {}
      self.buzones[dbId] = lista
    end
    lista[#lista + 1] = entrega
    guardarBuzon(self, dbId)
    local e = jugadorPorDbId(self, dbId)
    if e then self:mensaje("sistema", "", (entrega.nota or "Tienes algo nuevo") .. " Recógelo en la casa de subastas.", e) end
  end

  function Mundo:contarBuzon(p)
    self:iniciarSubastas()
    return p.dbId and self.buzones[p.dbId] and #self.buzones[p.dbId] or 0
  end

  -- ------------------------------------------------------------------ publicar
  function Mundo:publicarSubasta(p, idx, cant, salida, compra, horas)
    self:iniciarSubastas()
    if p.kind ~= "jugador" or not p.dbId then return "No puedes vender aquí." end
    local slot = p.bolsa[tonumber(idx) or 0]
    if not slot then return "Elige un objeto de la bolsa." end
    local it = Datos.item(slot.id)
    if not it or it.quest then return "Ese objeto no se puede subastar." end
    cant = math.floor(tonumber(cant) or 1)
    if cant < 1 or cant > (slot.cant or 1) then return "Cantidad no válida." end
    salida = math.floor(tonumber(salida) or 0)
    if salida < 1 or salida > 100000000 then return "El precio de salida no es válido." end
    compra = compra and math.floor(tonumber(compra) or 0) or 0
    if compra > 0 and compra <= salida then return "El precio de compra debe superar al de salida." end
    if compra > 100000000 then return "El precio de compra no es válido." end
    local ok = false
    for _, h in ipairs(M.DURACIONES) do if h == horas then ok = true end end
    if not ok then return "Duración no válida." end
    local propias = 0
    for _, s in pairs(self.subastas) do
      if s.vendedor == p.dbId then propias = propias + 1 end
    end
    if propias >= M.MAX_POR_JUGADOR then return "Ya tienes " .. M.MAX_POR_JUGADOR .. " subastas activas." end
    local comision = math.max(5, math.floor(salida * M.COMISION))
    if (p.oro or 0) < comision then return "La comisión de publicar es " .. comision .. " de oro." end
    p.oro = p.oro - comision
    local enc = slot.enc
    if cant >= (slot.cant or 1) then table.remove(p.bolsa, tonumber(idx))
    else slot.cant = slot.cant - cant end
    local ahora = self:ahoraSubastas()
    local s = {
      id = self.siguienteSubasta, vendedor = p.dbId, vendedorNombre = p.nombre, item = slot.id, cant = cant, enc = enc,
      salida = salida, compra = compra > 0 and compra or nil, oferta = 0, postor = nil, postorNombre = nil,
      creada = ahora, termina = ahora + horas * 3600,
    }
    self.siguienteSubasta = s.id + 1
    self.subastas[s.id] = s
    guardarSub(self, s)
    self:marcarProgreso(p)
    guardarYa(self, p)
    self:mensaje("sistema", "", "Publicas " .. it.nombre .. " (comisión " .. comision .. " de oro).", p)
    return nil
  end

  -- ------------------------------------------------------------------ cierre
  local function nombreObjeto(s)
    local it = Datos.item(s.item)
    return ((s.enc or 0) > 0 and ("+" .. s.enc .. " ") or "") .. (it and it.nombre or s.item) .. (s.cant > 1 and (" x" .. s.cant) or "")
  end
  M.nombreObjeto = nombreObjeto

  -- Reparte el resultado de una subasta terminada y la borra.
  function Mundo:cerrarSubasta(s, comprado)
    self.subastas[s.id] = nil
    borrarSub(self, s.id)
    if s.postor then
      local neto = s.oferta - math.floor(s.oferta * M.IMPUESTO)
      self:aBuzon(s.postor, { item = s.item, cant = s.cant, enc = s.enc, oro = 0,
        nota = "Ganas la subasta de " .. nombreObjeto(s) .. "." })
      local v = jugadorPorDbId(self, s.vendedor)
      self:aBuzon(s.vendedor, { oro = neto, nota = "Vendes " .. nombreObjeto(s) .. " por " .. s.oferta .. " (cobras " .. neto .. ")." })
      if v then self:marcarProgreso(v) end
    else
      self:aBuzon(s.vendedor, { item = s.item, cant = s.cant, enc = s.enc, oro = 0,
        nota = "Nadie compró " .. nombreObjeto(s) .. ": vuelve a ti." })
    end
  end

  function Mundo:actualizarSubastas(dt)
    self._subT = (self._subT or 0) + dt
    if self._subT < 5 then return end
    self._subT = 0
    self:iniciarSubastas()
    local ahora = self:ahoraSubastas()
    local vencidas
    for _, s in pairs(self.subastas) do
      if s.termina <= ahora then
        vencidas = vencidas or {}
        vencidas[#vencidas + 1] = s
      end
    end
    for _, s in ipairs(vencidas or {}) do self:cerrarSubasta(s) end
  end

  -- ------------------------------------------------------------------ pujar y comprar
  -- Devuelve el oro de la puja anterior a su dueño.
  local function devolverPuja(self, s)
    if not s.postor or s.oferta <= 0 then return end
    local e = jugadorPorDbId(self, s.postor)
    if e then
      e.oro = (e.oro or 0) + s.oferta
      self:marcarProgreso(e)
      self:mensaje("sistema", "", "Te superan en la subasta de " .. nombreObjeto(s) .. ": recuperas " .. s.oferta .. " de oro.", e)
    else
      self:aBuzon(s.postor, { oro = s.oferta, nota = "Te superan en la subasta de " .. nombreObjeto(s) .. "." })
    end
  end

  function Mundo:pujarSubasta(p, id, oferta)
    self:iniciarSubastas()
    local s = self.subastas[tonumber(id) or 0]
    if not s then return "Esa subasta ya terminó." end
    if p.kind ~= "jugador" or not p.dbId then return "No puedes pujar." end
    if s.termina <= self:ahoraSubastas() then return "Esa subasta ya terminó." end
    if s.vendedor == p.dbId then return "No puedes pujar por tu propio objeto." end
    if s.postor == p.dbId then return "Ya eres el mejor postor." end
    oferta = math.floor(tonumber(oferta) or 0)
    local minima = M.subidaMinima(s)
    if oferta < minima then return "La puja mínima es " .. minima .. "." end
    if s.compra and oferta >= s.compra then return self:comprarSubasta(p, id) end
    if (p.oro or 0) < oferta then return "No tienes " .. oferta .. " de oro." end
    p.oro = p.oro - oferta
    devolverPuja(self, s)
    s.oferta, s.postor, s.postorNombre = oferta, p.dbId, p.nombre
    local ahora = self:ahoraSubastas()
    if s.termina - ahora < M.TIEMPO_EXTRA then s.termina = ahora + M.TIEMPO_EXTRA end
    guardarSub(self, s)
    self:marcarProgreso(p)
    guardarYa(self, p)
    self:mensaje("sistema", "", "Pujas " .. oferta .. " por " .. nombreObjeto(s) .. ".", p)
    local v = jugadorPorDbId(self, s.vendedor)
    if v then self:mensaje("sistema", "", p.nombre .. " puja " .. oferta .. " por " .. nombreObjeto(s) .. ".", v) end
    return nil
  end

  function Mundo:comprarSubasta(p, id)
    self:iniciarSubastas()
    local s = self.subastas[tonumber(id) or 0]
    if not s then return "Esa subasta ya terminó." end
    if p.kind ~= "jugador" or not p.dbId then return "No puedes comprar." end
    if not s.compra then return "Esta subasta no tiene compra inmediata." end
    if s.termina <= self:ahoraSubastas() then return "Esa subasta ya terminó." end
    if s.vendedor == p.dbId then return "No puedes comprar tu propio objeto." end
    -- si ya era el mejor postor, su oro en depósito cuenta
    local aPagar = s.compra - ((s.postor == p.dbId) and s.oferta or 0)
    if (p.oro or 0) < aPagar then return "Necesitas " .. aPagar .. " de oro." end
    p.oro = p.oro - aPagar
    if s.postor ~= p.dbId then devolverPuja(self, s) end
    s.oferta, s.postor, s.postorNombre = s.compra, p.dbId, p.nombre
    self:marcarProgreso(p)
    guardarYa(self, p)
    self:cerrarSubasta(s, true)
    return nil
  end

  function Mundo:cancelarSubasta(p, id)
    self:iniciarSubastas()
    local s = self.subastas[tonumber(id) or 0]
    if not s then return "Esa subasta ya terminó." end
    if s.vendedor ~= p.dbId then return "No es tuya." end
    if s.postor then return "Ya tiene pujas: no se puede cancelar." end
    self.subastas[s.id] = nil
    borrarSub(self, s.id)
    self:aBuzon(s.vendedor, { item = s.item, cant = s.cant, enc = s.enc, oro = 0, nota = "Cancelas la subasta de " .. nombreObjeto(s) .. "." })
    return nil
  end

  -- ------------------------------------------------------------------ buzón
  -- Recoge lo pendiente: el oro entra siempre; los objetos mientras quepan en la bolsa.
  function Mundo:cobrarBuzon(p)
    self:iniciarSubastas()
    local lista = p.dbId and self.buzones[p.dbId]
    if not lista or #lista == 0 then return "Tu buzón está vacío." end
    local quedan, oro, objetos = {}, 0, 0
    for _, e in ipairs(lista) do
      if (e.oro or 0) > 0 then
        p.oro = (p.oro or 0) + e.oro
        oro = oro + e.oro
      end
      if e.item then
        if self:darItem(p, e.item, e.cant or 1, e.enc) then objetos = objetos + 1
        else quedan[#quedan + 1] = { item = e.item, cant = e.cant, enc = e.enc, oro = 0, nota = e.nota } end
      end
    end
    self.buzones[p.dbId] = #quedan > 0 and quedan or nil
    guardarBuzon(self, p.dbId)
    self:marcarProgreso(p)
    guardarYa(self, p)
    local texto = "Recoges " .. oro .. " de oro"
    texto = texto .. (objetos > 0 and (" y " .. objetos .. " objeto(s)") or "") .. "."
    if #quedan > 0 then texto = texto .. " La bolsa está llena: " .. #quedan .. " objeto(s) esperan en el buzón." end
    self:mensaje("sistema", "", texto, p)
    return nil
  end

  -- ------------------------------------------------------------------ lo que ve el panel
  function Mundo:infoSubastas(p, cat, pagina)
    self:iniciarSubastas()
    cat = M.CATEGORIAS[cat] and cat or "todo"
    pagina = math.max(1, math.floor(tonumber(pagina) or 1))
    local ahora = self:ahoraSubastas()
    local todas, mias = {}, {}
    for _, s in pairs(self.subastas) do
      local fila = {
        id = s.id, item = s.item, cant = s.cant, enc = s.enc, vendedor = s.vendedorNombre, salida = s.salida, compra = s.compra,
        oferta = s.oferta, postor = s.postorNombre, resta = math.max(0, s.termina - ahora), minima = M.subidaMinima(s),
        mia = s.vendedor == p.dbId, lider = s.postor == p.dbId,
      }
      if s.vendedor == p.dbId then mias[#mias + 1] = fila end
      if cat == "todo" or categoriaDe(Datos.item(s.item)) == cat then todas[#todas + 1] = fila end
    end
    local function porTiempo(a, b)
      if a.resta ~= b.resta then return a.resta < b.resta end
      return a.id < b.id
    end
    table.sort(todas, porTiempo)
    table.sort(mias, porTiempo)
    local paginas = math.max(1, math.ceil(#todas / M.POR_PAGINA))
    pagina = math.min(pagina, paginas)
    local pag = {}
    for i = (pagina - 1) * M.POR_PAGINA + 1, math.min(#todas, pagina * M.POR_PAGINA) do pag[#pag + 1] = todas[i] end
    local buzon = {}
    local oro = 0
    for _, e in ipairs(p.dbId and self.buzones[p.dbId] or {}) do
      oro = oro + (e.oro or 0)
      buzon[#buzon + 1] = { item = e.item, cant = e.cant, enc = e.enc, oro = e.oro, nota = e.nota }
    end
    return {
      cat = cat, pagina = pagina, paginas = paginas, total = #todas, lista = pag, mias = mias,
      buzon = buzon, buzonOro = oro, maxPropias = M.MAX_POR_JUGADOR,
      comision = M.COMISION, impuesto = M.IMPUESTO, duraciones = M.DURACIONES,
      cerca = self:npcCerca(p, "subastas"),
    }
  end

  -- ------------------------------------------------------------------ acciones del cliente
  function Mundo:accionSubasta(p, nombre, datos)
    local err
    if nombre ~= "subasta_info" and not self:npcCerca(p, "subastas") then
      err = "Acércate al subastador."
    elseif nombre == "subasta_publicar" then
      err = self:publicarSubasta(p, datos.idx, datos.cant, datos.salida, datos.compra, datos.horas)
    elseif nombre == "subasta_pujar" then err = self:pujarSubasta(p, datos.id, datos.oferta)
    elseif nombre == "subasta_comprar" then err = self:comprarSubasta(p, datos.id)
    elseif nombre == "subasta_cancelar" then err = self:cancelarSubasta(p, datos.id)
    elseif nombre == "subasta_cobrar" then err = self:cobrarBuzon(p)
    end
    if err then self:mensaje("sistema", "", err, p) end
    return { panel = "subastas", datos = self:infoSubastas(p, datos.cat, datos.pagina) }
  end
end

return M
