-- Viajes en barco entre los continentes. Cada puerto (Puerto del Sol, Puerto Sombra y el
-- Embarcadero de la Cicatriz) tiene un barquero que lleva, al instante y por oro, a cualquiera de los
-- otros puertos. Los puertos salen del mapa (mapa.puertos).
local Util = require("compartido.dominio.util")

local M = {}

M.PRECIO_BASE = 40
M.POR_CASILLA = 0.12
M.ALCANCE = 10          -- a qué distancia del puerto se puede embarcar

function M.precio(a, b)
  return math.floor(M.PRECIO_BASE + Util.dist(a.x, a.y, b.x, b.y) * M.POR_CASILLA)
end

-- Puerto más cercano a un punto dentro del alcance (o nil).
function M.puertoCerca(mapa, x, y)
  local mejor, md
  for _, pu in ipairs(mapa.puertos or {}) do
    local d = Util.dist(x, y, pu.x, pu.y)
    if d <= M.ALCANCE and (not md or d < md) then mejor, md = pu, d end
  end
  return mejor
end

function M.instalar(Mundo)
  -- Embarca a p en el puerto donde está hacia el puerto destinoId. Devuelve un mensaje de error o nil.
  function Mundo:navegar(p, destinoId)
    if p.kind ~= "jugador" then return "Solo los jugadores viajan en barco." end
    if not p.vivo then return nil end
    if p.modo ~= "mundo" or (p.z or 0) > 0 then return "No puedes embarcar desde aquí." end
    local mapa = self.mapas.mundo
    local origen = M.puertoCerca(mapa, p.x, p.y)
    if not origen or not self:npcCerca(p, "barquero") then return "Acércate al barquero de un puerto." end
    local destino
    for _, pu in ipairs(mapa.puertos or {}) do
      if pu.id == destinoId then destino = pu end
    end
    if not destino or destino.id == origen.id then return "Ese destino no existe." end
    if (p.ultimoGolpe or -10) + 4 > self.tiempo then return "No puedes embarcar en pleno combate." end
    local precio = M.precio(origen, destino)
    if (p.oro or 0) < precio then return "El pasaje cuesta " .. precio .. " de oro." end
    p.oro = p.oro - precio
    if p.montado then
      p.montado = nil
      self:recalcularCarga(p)
    end
    p.x, p.y = destino.x, destino.y
    p.camino, p.tramo, p.objetivo, p.persigue = nil, nil, nil, false
    p.deseoX, p.deseoY = 0, 0
    self:marcarProgreso(p)
    self:mensaje("sistema", "", "Cruzas el mar hasta " .. destino.nombre .. " (" .. precio .. " de oro).", p)
    return nil
  end

  function Mundo:accionViaje(p, datos)
    local err = self:navegar(p, datos.destino)
    if err then self:mensaje("sistema", "", err, p) end
    return nil
  end
end

return M
