-- Batalla por cristales en el mapa captura_cristal (editor de mapas, mapa 47): UN cristal aparece en el centro del mapa, avisando a todo el mundo, y las dos coronas
-- van a por él. Se puede pelear en cualquier momento; quien recoge el cristal lo lleva a una zona de su corona y gana. Si el portador cae, el cristal queda en el suelo
-- donde murió (lo puede recoger cualquiera, también un rival).
--   Albor sale en las zonas 84 y 85 (a la izquierda del mapa); Umbra, en las 83 y 86 (a la derecha). El cristal sale en el centro (zonas 81 y 82).
--   Los puntos 1 a 4 del .mpc (los cuatro rincones, con los teletransportes de FAO a otros mapas) no se usan: aquí no hay más salida que la del propio juego (salir del evento).
-- Si el mapa no está instalado (no hay captura_cristal en mapas_fao/indice.lua), la batalla sigue siendo la de siempre (estatuas, puertas y altares: Mapa.batalla).
local Util = require("compartido.dominio.util")
local Mapa = require("compartido.dominio.mapa")
local MapaMpc = require("compartido.dominio.mapa_mpc")

local M = {}

M.MAPA = "captura_cristal"
M.ZONAS = { albor = { 84, 85 }, umbra = { 83, 86 } }
M.CENTRO = { 81, 82 }
M.RETRASO = 20                 -- segundos desde que empieza el evento hasta que aparece el cristal
M.RADIO_COGER = 1.2            -- casillas: a esa distancia se recoge el cristal
M.PUNTOS_BAJA = 10
M.PUNTOS_CRISTAL = 100

local function nombreCorona(f) return f == "albor" and "Albor" or "Umbra" end

function M.instalar(Mundo)
  -- Prepara (una vez) las bases y el centro: casillas transitables dentro de las zonas del mapa. Devuelve nil si no hay mapa.
  function Mundo:prepararCristal()
    if self._cristal ~= nil then return self._cristal or nil end
    self._cristal = false
    local mapa = self.mapas[M.MAPA]
    if not (mapa and mapa.mpc and mapa.mpc.puntos) then return nil end
    local zonas = {}
    for _, p in ipairs(mapa.mpc.puntos) do zonas[p.id] = p.puntos end
    local function celdas(ids)
      local lista = {}
      for _, id in ipairs(ids) do
        local poli = zonas[id]
        if poli then
          local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
          for _, q in ipairs(poli) do x0, y0, x1, y1 = math.min(x0, q.x), math.min(y0, q.y), math.max(x1, q.x), math.max(y1, q.y) end
          for y = math.floor(y0 / MapaMpc.CELDA), math.floor(y1 / MapaMpc.CELDA) do
            for x = math.floor(x0 / MapaMpc.CELDA), math.floor(x1 / MapaMpc.CELDA) do
              -- (casillas con sus ocho vecinas libres: así nadie sale encajado entre objetos)
              local libre = Mapa.transitable(mapa, x, y) and mapa.suelo[x][y] ~= "agua"
              for dx = -1, 1 do for dy = -1, 1 do
                if libre and not Mapa.transitable(mapa, x + dx, y + dy) then libre = false end
              end end
              if libre and MapaMpc.puntoEnPoligono(poli, (x + 0.5) * MapaMpc.CELDA, (y + 0.5) * MapaMpc.CELDA) then
                lista[#lista + 1] = { x = x + 0.5, y = y + 0.5 }
              end
            end
          end
        end
      end
      return lista
    end
    local bases = { albor = celdas(M.ZONAS.albor), umbra = celdas(M.ZONAS.umbra) }
    local centro = celdas(M.CENTRO)
    if #bases.albor == 0 or #bases.umbra == 0 or #centro == 0 then return nil end
    -- el cristal sale en la casilla del centro más cercana al medio de las zonas 81 y 82
    local cx, cy = 0, 0
    for _, c in ipairs(centro) do cx, cy = cx + c.x, cy + c.y end
    cx, cy = cx / #centro, cy / #centro
    local mejor, md = centro[1], math.huge
    for _, c in ipairs(centro) do
      local d = (c.x - cx) ^ 2 + (c.y - cy) ^ 2
      if d < md then mejor, md = c, d end
    end
    self._cristal = { bases = bases, zonas = zonas, centro = { x = mejor.x, y = mejor.y } }
    -- (las reapariciones y entradas «normales» del mapa también caen en su base)
    mapa.spawns = mapa.spawns or {}
    mapa.spawns.albor = { x = bases.albor[1].x, y = bases.albor[1].y }
    mapa.spawns.umbra = { x = bases.umbra[1].x, y = bases.umbra[1].y }
    return self._cristal
  end

  -- Vuelve a la batalla de siempre (estatuas, puertas y altares) aunque esté instalado el mapa nuevo; la usan las pruebas de ese campo.
  function Mundo:usarBatallaClasica()
    self.mapas.batalla, self.batallaFao = Mapa.batalla(), false
    self:crearObjetivos()
  end

  -- ¿Se juega la batalla en el mapa nuevo?
  function Mundo:batallaCristal()
    return self.batallaFao == true and self:prepararCristal() ~= nil
  end

  -- Una casilla de la base de una corona (al azar entre sus zonas) para entrar o reaparecer.
  function Mundo:puntoBaseCristal(faccion)
    local c = self:prepararCristal()
    local lista = c.bases[faccion] or c.bases.albor
    return lista[math.random(#lista)]
  end

  -- ¿Está p dentro de una zona de su corona?
  function Mundo:enZonaPropia(p)
    local c = self:prepararCristal()
    if not c then return false end
    for _, id in ipairs(M.ZONAS[p.faccion] or {}) do
      local poli = c.zonas[id]
      if poli and MapaMpc.puntoEnPoligono(poli, p.x * MapaMpc.CELDA, p.y * MapaMpc.CELDA) then return true end
    end
    return false
  end

  local function quitarCristales(self)
    for id, e in pairs(self.entidades) do
      if e.kind == "cristal" and e.central then self.entidades[id] = nil end
    end
  end

  -- El cristal en el suelo (en x, y; por defecto, el centro del mapa).
  function Mundo:ponerCristalCentral(x, y)
    local c = self:prepararCristal()
    quitarCristales(self)
    local id = self:idNuevo()
    local e = {
      id = id, kind = "cristal", central = true, nombre = "Cristal", faccion = nil, modo = "batalla", vivo = true, z = 0,
      x = x or c.centro.x, y = y or c.centro.y, hasta = 1e12,
    }
    self.entidades[id] = e
    local inst = self.instancia.batalla
    inst.cristal = { estado = "libre", x = e.x, y = e.y }
    return e
  end

  -- Empieza la edición: el cristal aún no está; sale en M.RETRASO segundos.
  function Mundo:empezarCristal()
    local inst = self.instancia.batalla
    quitarCristales(self)
    inst.cristal = { estado = "espera", resta = M.RETRASO }
    inst.cristalAparece = M.RETRASO
    for _, e in pairs(self.entidades) do e.llevaCristales = nil end
  end

  -- Fin de la edición: se limpia todo.
  function Mundo:acabarCristal()
    local inst = self.instancia.batalla
    quitarCristales(self)
    inst.cristal, inst.cristalAparece = nil, nil
    for _, e in pairs(self.entidades) do e.llevaCristales = nil end
  end

  -- El portador deja el cristal en el suelo (muere o abandona): queda donde está (o vuelve al centro si ya no hay dónde dejarlo).
  function Mundo:soltarCristalPortador(p, alCentro, motivo)
    if (p.llevaCristales or 0) <= 0 then return end
    p.llevaCristales = nil
    local inst = self.instancia.batalla
    if not (inst.activa and not inst.fin) then return end
    local e = self:ponerCristalCentral((not alCentro) and p.x or nil, (not alCentro) and p.y or nil)
    local donde = alCentro and "vuelve al centro del mapa" or "cae al suelo"
    self:avisoEvento("mundo", "", "¡El cristal " .. donde .. "! " .. (motivo or (p.nombre .. " (" .. nombreCorona(p.faccion) .. ") lo soltó")), nil)
    self:registrarEvento("batalla", "El cristal " .. donde, p.faccion)
    return e
  end

  -- Cada tick de un jugador en la batalla: recoge el cristal si pasa junto a él y, si lo lleva, lo entrega al entrar en una zona de su corona.
  function Mundo:cristalFao(p)
    if p.modo ~= "batalla" or not p.vivo then return end
    local inst = self.instancia.batalla
    if not (inst.activa and not inst.fin) then return end
    if (p.llevaCristales or 0) <= 0 then
      for _, o in pairs(self.entidades) do
        if o.kind == "cristal" and o.central and o.vivo and not o.borrar and Util.dist(p.x, p.y, o.x, o.y) < M.RADIO_COGER then
          o.vivo, o.borrar = false, true
          p.llevaCristales = 1
          inst.cristal = { estado = "llevado", portador = p.nombre, faccion = p.faccion, id = p.id }
          inst.puntos[p.faccion] = inst.puntos[p.faccion] + M.PUNTOS_CRISTAL
          self:contarEvento(p, "cristales")
          self:avisoEvento("mundo", "", "¡" .. p.nombre .. " (" .. nombreCorona(p.faccion) .. ") tiene el cristal! Hay que quitárselo o llevarlo a su zona.", nil)
          self:registrarEvento("batalla", p.nombre .. " coge el cristal", p.faccion)
          self:mensaje("sistema", "", "Tienes el cristal: llévalo a una zona de " .. nombreCorona(p.faccion) .. " (la " .. (p.faccion == "albor" and "izquierda" or "derecha") .. " del mapa) sin que te lo quiten.", p)
          break
        end
      end
    elseif self:enZonaPropia(p) then
      p.llevaCristales = nil
      inst.cristales[p.faccion] = (inst.cristales[p.faccion] or 0) + 1
      inst.cristal = { estado = "entregado", faccion = p.faccion }
      p.entregados = (p.entregados or 0) + 1
      self:registrarEvento("batalla", p.nombre .. " entrega el cristal", p.faccion)
      self:avisoEvento("mundo", "", "¡" .. p.nombre .. " entrega el cristal en su zona! Gana " .. nombreCorona(p.faccion) .. ".", nil)
      self:cerrarInstancia("batalla", p.faccion)
    end
  end

  -- Cada tick del servidor: el cristal aparece al acabar la cuenta atrás y se vigila al portador.
  function Mundo:actualizarCristal(dt)
    local inst = self.instancia.batalla
    if not (inst.activa and not inst.fin) or not self:batallaCristal() then return end
    local c = inst.cristal
    if inst.cristalAparece then
      inst.cristalAparece = inst.cristalAparece - dt
      if inst.cristal and inst.cristal.estado == "espera" then inst.cristal.resta = math.max(0, math.ceil(inst.cristalAparece)) end
      if inst.cristalAparece <= 0 then
        inst.cristalAparece = nil
        self:ponerCristalCentral()
        self:avisoEvento("mundo", "", "¡El cristal ha aparecido en el centro del mapa! Albor y Umbra, a por él.", nil)
        self:registrarEvento("batalla", "El cristal aparece en el centro", nil)
      end
      return
    end
    if c and c.estado == "llevado" then
      local p = c.id and self.entidades[c.id]
      -- el portador se desconectó o salió del evento sin soltarlo: el cristal vuelve al centro
      if not (p and p.vivo and not p.borrar and p.modo == "batalla" and (p.llevaCristales or 0) > 0) then
        if p then p.llevaCristales = nil end
        self:ponerCristalCentral()
        self:avisoEvento("mundo", "", "¡El cristal vuelve al centro del mapa!", nil)
      end
    end
  end
end

return M
