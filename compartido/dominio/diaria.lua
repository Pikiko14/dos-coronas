-- Recompensas diarias: cada personaje puede reclamar un premio al día; con días seguidos sube la racha y el premio
-- (ciclo de siete días). Los premios están en compartido/datos/diaria.xml. El reloj es el del servidor.
local Datos = require("compartido.dominio.datos")
local Config = require("compartido.dominio.configuracion")

local M = {}

M.dias = Config.lista("diaria", "dia")
table.sort(M.dias, function(a, b) return a.n < b.n end)
for i, d in ipairs(M.dias) do
  Config.validar("diaria.xml", "día", d.n, d, { n = "numero", oro = "numero" })
  if d.n ~= i then error("diaria.xml: los días deben ser 1, 2, 3... sin saltos (falla el " .. i .. ")", 0) end
  for _, it in ipairs(d.items or {}) do
    if not Datos.item(it.id) then error("diaria.xml: día " .. d.n .. ": el objeto '" .. tostring(it.id) .. "' no existe", 0) end
  end
end
M.CICLO = #M.dias

-- Fecha de hoy y de ayer (texto AAAA-MM-DD), con el reloj del servidor. Las pruebas pueden fijar M.ahora().
M.ahora = function() return os.time() end
local function fecha(t) return os.date("%Y-%m-%d", t) end
function M.hoy() return fecha(M.ahora()) end
function M.ayer() return fecha(M.ahora() - 86400) end

-- Segundos que faltan para medianoche (cuando se puede volver a reclamar).
function M.hastaManana()
  local t = M.ahora()
  local d = os.date("*t", t)
  return (24 - d.hour) * 3600 - d.min * 60 - d.sec
end

-- Lo que da el día n del ciclo a un personaje de ese nivel.
function M.premio(n, nivel)
  local d = M.dias[((n - 1) % M.CICLO) + 1]
  return {
    dia = d.n,
    oro = math.floor((d.oro or 0) + (d.oroN or 0) * (nivel or 1)),
    xp = d.xp or 0,
    monedas = d.monedas or 0,
    items = d.items or {},
  }
end

function M.instalar(Mundo)
  -- Dónde va la racha de p: día del ciclo que toca reclamar y si ya reclamó hoy.
  function Mundo:estadoDiaria(p)
    local d = p.diaria or {}
    local hoy = M.hoy()
    local reclamada = d.ultimo == hoy
    local racha = d.racha or 0
    -- si el último premio no fue ayer ni hoy, la racha se rompió
    local viva = reclamada or d.ultimo == M.ayer()
    local siguiente = reclamada and racha or ((viva and racha or 0) + 1)
    return {
      reclamada = reclamada, racha = viva and racha or 0, dia = ((siguiente - 1) % M.CICLO) + 1,
      resta = M.hastaManana(), premio = M.premio(siguiente, p.nivel),
    }
  end

  -- Reclama el premio de hoy. Devuelve un mensaje de error o nil.
  function Mundo:reclamarDiaria(p)
    if p.kind ~= "jugador" then return "Solo los jugadores reclaman la recompensa diaria." end
    local est = self:estadoDiaria(p)
    if est.reclamada then return "Ya reclamaste la recompensa de hoy. Vuelve mañana." end
    local premio = est.premio
    -- los objetos tienen que caber: se comprueba antes de dar nada
    local copia = {}
    for i, s in ipairs(p.bolsa) do copia[i] = { id = s.id, cant = s.cant, enc = s.enc } end
    local bolsaOriginal = p.bolsa
    p.bolsa = copia
    local cabe = true
    for _, it in ipairs(premio.items) do
      if not self:darItem(p, it.id, it.cant) then cabe = false break end
    end
    p.bolsa = bolsaOriginal
    if not cabe then return "Libera espacio en la bolsa para recibir los objetos de hoy." end
    for _, it in ipairs(premio.items) do self:darItem(p, it.id, it.cant) end
    p.oro = (p.oro or 0) + premio.oro
    if premio.monedas > 0 then p.monedas = (p.monedas or 0) + premio.monedas end
    if premio.xp > 0 then self:ganarXp(p, math.floor(Datos.xpPara(p.nivel) * premio.xp)) end
    p.diaria = { ultimo = M.hoy(), racha = est.racha + 1 }
    self:marcarProgreso(p)
    local partes = { premio.oro .. " de oro" }
    if premio.monedas > 0 then partes[#partes + 1] = premio.monedas .. " Monedas Corona" end
    if premio.xp > 0 then partes[#partes + 1] = "experiencia" end
    for _, it in ipairs(premio.items) do
      partes[#partes + 1] = it.cant .. " × " .. (Datos.item(it.id).nombre or it.id)
    end
    self:mensaje("sistema", "", "Recompensa diaria (día " .. premio.dia .. ", racha " .. p.diaria.racha .. "): " .. table.concat(partes, ", ") .. ".", p)
    self:sonar("cura", p)
    return nil
  end

  -- Al entrar al mundo: recuerda que hay premio esperando.
  function Mundo:avisoDiaria(p)
    if p.kind ~= "jugador" then return end
    local est = self:estadoDiaria(p)
    if not est.reclamada then
      self:mensaje("sistema", "", "Tienes tu recompensa diaria esperando (día " .. est.dia .. "). Ábrela con el botón Diaria o la tecla F2.", p)
    end
  end
end

return M
