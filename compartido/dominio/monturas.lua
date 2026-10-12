-- Monturas de transporte: se compran en las cuadras (y en las posadas del camino), se montan con
-- una tecla y dan velocidad y/o capacidad de carga para las mercancías de los comerciantes.
--   vel:   fracción extra de velocidad al ir montado.
--   carga: unidades de mercancía extra que se pueden llevar.
-- Se bajan solas dentro de casas y campos de batalla.
local M = {}

M.MAX = 4

M.especies = {
  buey = {
    nombre = "Buey de carga", nivel = 5, precio = 900, vel = 0.10, carga = 22,
    desc = "Lento pero fuerte: carga mucho más.",
  },
  caballo = {
    nombre = "Caballo", nivel = 10, precio = 2400, vel = 0.40, carga = 6,
    desc = "El más rápido para cruzar el mapa.",
  },
  carreta = {
    nombre = "Carreta cubierta", nivel = 14, precio = 4500, vel = 0.06, carga = 90, oficio = "trader",
    desc = "Una carreta de mercader: carga enorme. Solo para comerciantes.",
  },
}
M.orden = { "buey", "caballo", "carreta" }

function M.instalar(Mundo)
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
    p.montado, p.monturaPreferida = especie, especie
    self:recalcularCarga(p)
    return nil
  end

  -- Bonos de la montura puesta.
  function Mundo:bonoMontura(p)
    local d = p.montado and M.especies[p.montado]
    return d and d.vel or 0, d and d.carga or 0
  end
end

return M
