-- Mazmorras: tres cuevas con su puerta en distintos puntos del mapa (la entrada se coloca en
-- Mapa.mundo). Cada una es su propio mapa (modo = "mz1", "mz2", "mz3"): salas con criaturas, un
-- jefe al fondo y, al caer, un cofre con un premio por jugador: cualquier objeto o addon del mall,
-- o un arma o armadura del escalón más alto. Se entra y se sale con la tecla de interactuar junto a
-- la puerta; los datos de cada una están en Datos.mazmorras.
local Datos = require("compartido.dominio.datos")
local Mapa = require("compartido.dominio.mapa")
local Util = require("compartido.dominio.util")
local Items = require("compartido.dominio.items")
local Mall = require("compartido.dominio.mall")

local M = {}
require("compartido.dominio.configuracion").aplicar(M, "mazmorras")


-- Planos de cada mazmorra (compartido/datos/mazmorras.xml): rectángulos { x, y, ancho, alto } en casillas. La
-- entrada está en la sala "entrada": el jugador aparece ahí y la puerta de salida está en su muro de abajo.
local DISENOS = require("compartido.dominio.configuracion").mapaOrden("mazmorras", "plano", false)

local function tallar(mapa, r)
  for x = r[1], r[1] + r[3] - 1 do
    for y = r[2], r[2] + r[4] - 1 do
      mapa.suelo[x][y] = "mazmorra"
      mapa.bloque[x][y] = nil
    end
  end
end

local function pilar(mapa, x, y)
  for dx = 0, 1 do
    for dy = 0, 1 do
      mapa.suelo[x + dx][y + dy] = "muralla"
      mapa.bloque[x + dx][y + dy] = true
    end
  end
end

-- Mapa de una mazmorra. grupos: sitios donde sale cada grupo de criaturas; jefe y entrada.
function M.mapa(def)
  local d = DISENOS[def.id]
  local mapa = Mapa.nuevo(d.w, d.h)
  mapa.mazmorra, mapa.tinte, mapa.nombre = def.id, def.tinte, def.nombre
  for x = 0, d.w - 1 do
    mapa.suelo[x], mapa.bioma[x], mapa.lado[x], mapa.bloque[x] = {}, {}, {}, {}
    for y = 0, d.h - 1 do
      mapa.suelo[x][y], mapa.bioma[x][y], mapa.bloque[x][y] = "muralla", "mazmorra", true
    end
  end
  tallar(mapa, d.entrada)
  for _, r in ipairs(d.pasillos) do tallar(mapa, r) end
  mapa.grupos = {}
  for _, r in ipairs(d.salas) do
    tallar(mapa, r)
    pilar(mapa, r[1] + 3, r[2] + 3)
    pilar(mapa, r[1] + r[3] - 5, r[2] + 3)
    pilar(mapa, r[1] + 3, r[2] + r[4] - 5)
    pilar(mapa, r[1] + r[3] - 5, r[2] + r[4] - 5)
    local cx, cy = r[1] + r[3] / 2, r[2] + r[4] / 2
    mapa.grupos[#mapa.grupos + 1] = { x = cx, y = cy }
    mapa.grupos[#mapa.grupos + 1] = { x = r[1] + r[3] * 0.25, y = cy }
    mapa.grupos[#mapa.grupos + 1] = { x = r[1] + r[3] * 0.75, y = cy }
  end
  local j = d.jefe
  tallar(mapa, j)
  pilar(mapa, j[1] + 3, j[2] + j[4] - 6)
  pilar(mapa, j[1] + j[3] - 5, j[2] + j[4] - 6)
  mapa.jefe = { x = j[1] + j[3] / 2, y = j[2] + 3.5 }
  mapa.grupos[#mapa.grupos + 1] = { x = j[1] + j[3] * 0.3, y = j[2] + j[4] * 0.6 }
  mapa.grupos[#mapa.grupos + 1] = { x = j[1] + j[3] * 0.7, y = j[2] + j[4] * 0.6 }
  local e = d.entrada
  local cx = e[1] + math.floor(e[3] / 2)
  mapa.entrada = { x = cx + 0.5, y = e[2] + e[4] - 2.5 }
  mapa.salida = { x = cx + 0.5, y = e[2] + e[4] - 1.5 }
  mapa.props[#mapa.props + 1] = { x = cx, y = e[2] + e[4] - 1, tipo = "puerta_mazmorra", mz = def.id, salida = true }
  return mapa
end

function M.instalar(Mundo)
  -- Mapas propios de cada mazmorra (se añaden a self.mapas con su id como clave).
  function Mundo:crearMapasMazmorras()
    for _, def in ipairs(Datos.mazmorras) do self.mapas[def.id] = M.mapa(def) end
  end

  function Mundo:enMazmorra(e)
    local m = e and self.mapas[e.modo]
    return m and m.mazmorra and Datos.mazmorra(m.mazmorra) or nil
  end

  -- Criaturas y jefe de cada mazmorra.
  function Mundo:poblarMazmorras()
    for _, def in ipairs(Datos.mazmorras) do
      local mapa = self.mapas[def.id]
      for i, g in ipairs(mapa.grupos) do
        local mon = def.monstruos[((i - 1) % #def.monstruos) + 1]
        local cant = 3
        for k = 1, cant do
          local a = (k / cant) * math.pi * 2
          local e = self:spawnMonstruo(mon[1], g.x + math.cos(a) * 1.6, g.y + math.sin(a) * 1.6, nil, mon[2])
          if e then e.modo, e.mz = def.id, def.id end
        end
      end
      local jd = def.jefe
      local jefe = self:spawnMonstruo(jd.monstruo, mapa.jefe.x, mapa.jefe.y, nil, jd.nivel)
      if jefe then
        jefe.modo, jefe.mz, jefe.jefeMz = def.id, def.id, true
        jefe.nombre, jefe.elite = jd.nombre, true
        jefe.hpMax = math.floor(jefe.hpMax * jd.vida)
        jefe.hp = jefe.hpMax
        jefe.atk = jefe.atk * jd.dano
        jefe.matk = jefe.matk * jd.dano
        jefe.def = jefe.def * 1.2
        jefe.mdef = jefe.mdef * 1.2
        jefe.agresivo = true
      end
    end
  end

  -- ¿Hay una puerta de mazmorra a mano? Devuelve su definición y su sitio.
  function Mundo:puertaMazmorraCerca(p)
    for _, z in ipairs(self.mapas.mundo.mazmorras or {}) do
      if Util.dist(p.x, p.y, z.x + 0.5, z.y + 0.5) < 2.6 then return z, Datos.mazmorra(z.id) end
    end
  end

  function Mundo:entrarMazmorra(p, z, def)
    if p.kind ~= "jugador" then return "Solo los jugadores entran en las mazmorras." end
    if p.modo ~= "mundo" or (p.z or 0) > 0 then return "No puedes entrar desde aquí." end
    if (p.nivel or 1) < def.nivelMin then
      return def.nombre .. " pide nivel " .. def.nivelMin .. " (tienes " .. (p.nivel or 1) .. ")."
    end
    if (p.ultimoGolpe or -10) + 4 > self.tiempo then return "No puedes entrar en pleno combate." end
    local mapa = self.mapas[def.id]
    p.retorno = { x = z.x + 0.5, y = z.y + 1.8, modo = "mundo" }
    p.modo, p.casaId, p.z = def.id, nil, 0
    p.zona = def.nombre
    p.x, p.y = mapa.entrada.x, mapa.entrada.y
    p.objetivo, p.camino, p.persigue = nil, nil, false
    self:mensaje("sistema", "", "Entras en " .. def.nombre .. " (nivel " .. def.nivelMin .. "+). Al fondo hay un jefe con un cofre. Sal por la puerta con E.", p)
    return nil
  end

  function Mundo:salirMazmorra(p)
    local def = self:enMazmorra(p)
    if not def then return end
    local r = p.retorno or p.vinculo
    p.modo, p.z, p.casaId = "mundo", 0, nil
    p.x, p.y = r.x, r.y
    p.objetivo, p.camino, p.persigue = nil, nil, false
    p.zona = nil
    self:mensaje("sistema", "", "Sales de " .. def.nombre .. ".", p)
  end

  -- El jefe cae: respawn lento y un cofre en el sitio donde murió.
  function Mundo:jefeMazmorraCae(jefe, origen)
    local def = Datos.mazmorra(jefe.mz)
    if not def then return end
    jefe.respawn = self.tiempo + M.RESPAWN_JEFE
    local id = self:idNuevo()
    self.entidades[id] = {
      id = id, kind = "cofre_mz", nombre = "Cofre de " .. def.nombre, x = jefe.x, y = jefe.y, z = 0,
      modo = jefe.modo, vivo = true, hasta = self.tiempo + M.DURA_COFRE, reclamado = {}, mz = def.id,
    }
    self:anunciar(jefe.nombre .. " ha caído en " .. def.nombre .. (origen and origen.nombre and (" a manos de " .. origen.nombre) or "") .. ".")
    for _, e in pairs(self.entidades) do
      if e.kind == "jugador" and e.modo == jefe.modo and e.vivo then
        self:mensaje("sistema", "", "¡Un cofre de premio ha aparecido! Acércate y pulsa E (dura " .. M.DURA_COFRE .. " s).", e)
      end
    end
  end

  -- Elige y entrega el premio. Devuelve true y el texto, o false si la bolsa está llena.
  function Mundo:premioMazmorra(p)
    local r = math.random()
    local texto
    if r < M.PROB_ADDON then
      local libres = {}
      for _, id in ipairs(Mall.ORDEN_ADDONS) do
        if not (p.addons and p.addons[id]) then libres[#libres + 1] = id end
      end
      if #libres > 0 then
        local id = libres[math.random(#libres)]
        p.addons = p.addons or {}
        p.addons[id] = true
        texto = "el addon " .. Mall.ADDONS[id].nombre .. " (ya es tuyo, pruébalo en el Item Mall)"
      else
        p.monedas = (p.monedas or 0) + 150
        texto = "150 " .. Mall.MONEDA .. " (ya tenías todos los addons)"
      end
    elseif r < M.PROB_ADDON + M.PROB_MALL then
      local lista = {}
      for _, o in ipairs(Mall.OBJETOS) do
        if Datos.item(o.id) then lista[#lista + 1] = o end
      end
      local o = lista[math.random(#lista)]
      if not self:darItem(p, o.id, 1) then return false end
      texto = o.nombre
    else
      local id = Items.aleatorio(Datos, p.clase, #Items.TIER, math.random)
      if not self:darItem(p, id, 1) then return false end
      local it = Datos.item(id)
      texto = (it and it.nombre or id) .. " (escalón máximo)"
    end
    p.oro = (p.oro or 0) + M.ORO_COFRE
    return true, texto
  end

  function Mundo:reclamarCofre(p, cofre)
    if cofre.reclamado[p.id] then
      self:mensaje("sistema", "", "Ya abriste este cofre.", p)
      return
    end
    if not p.vivo then return end
    local ok, texto = self:premioMazmorra(p)
    if not ok then
      self:mensaje("sistema", "", "Tu bolsa está llena: haz sitio y vuelve a abrir el cofre.", p)
      return
    end
    cofre.reclamado[p.id] = true
    self:marcarProgreso(p)
    self:mensaje("sistema", "", "¡Abres el cofre! Recibes " .. texto .. " y " .. M.ORO_COFRE .. " de oro.", p)
    self:sonar("cura")
  end

  -- E dentro de una mazmorra: abrir el cofre cercano o salir por la puerta.
  function Mundo:interactuarMazmorra(p)
    for _, e in pairs(self.entidades) do
      if e.kind == "cofre_mz" and e.modo == p.modo and Util.dist(p.x, p.y, e.x, e.y) < 2.6 then
        self:reclamarCofre(p, e)
        return { panel = nil }
      end
    end
    local mapa = self.mapas[p.modo]
    if Util.dist(p.x, p.y, mapa.salida.x, mapa.salida.y) < 3.2 then
      self:salirMazmorra(p)
      return { panel = nil }
    end
    self:mensaje("sistema", "", "Aquí no hay nada. La puerta de salida está en la sala de entrada.", p)
    return { panel = nil }
  end

  -- E en el mundo junto a una puerta de mazmorra.
  function Mundo:interactuarPuertaMazmorra(p)
    local z, def = self:puertaMazmorraCerca(p)
    if not z then return nil end
    local err = self:entrarMazmorra(p, z, def)
    if err then self:mensaje("sistema", "", err, p) end
    return { panel = nil }
  end
end

return M
