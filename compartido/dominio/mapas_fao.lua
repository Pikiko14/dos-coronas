-- Mapas aparte con el terreno de Free Angels Online (.mpc, ver mapa_mpc.lua): instancias como las mazmorras, fuera de los continentes. Prototipo con un solo mapa (map002 "Riprap Coast").
-- Arte y datos de FAO (juego ajeno): no se publican sin sustituirlos.
--
-- Entrar: el administrador escribe /admin mapa riprap (de momento no hay puerta en los continentes: no se toca la generación del mundo). Salir: caminar hasta uno de los dos
-- triángulos del borde (en FAO son los eventos 1 y 2, saltos a otros mapas; aquí vuelven al sitio de donde entraste) o /admin mapa salir.
-- Nada de FAO se conecta todavía al juego: sin criaturas, PNJ, misiones ni eventos (el mapa trae sus eventos y diálogos leídos, inertes).
local Mapa = require("compartido.dominio.mapa")
local MapaMpc = require("compartido.dominio.mapa_mpc")

local M = {}

-- nombre del modo (mundo.mapas[nombre]) -> número del .mpc
-- Los mapas escritos a mano (mandan si el índice repite el nombre) más los que el editor de mapas apunta en compartido/datos/mapas_fao/indice.lua al pulsar "Enviar a Dos Coronas"
-- (`return { nombre = numero, ... }`): un mapa nuevo queda disponible (/admin mapa nombre, ayuda del administrador) solo reiniciando el servidor. El índice se valida: nombre válido,
-- número entero y existen mapNNN.mpc y mapNNN_datos.lua.
local A_MANO = { riprap = 2, minas_de_la_muerte = 323 }
local RESERVADOS = { salir = true, mundo = true, batalla = true, estandarte = true, casa = true, casaPequena = true, casaMediana = true }

local function leerIndice()
  local modulo = "compartido.datos.mapas_fao.indice"
  local ok, lista = pcall(require, modulo)
  if not ok then
    if tostring(lista):find("module '" .. modulo .. "' not found", 1, true) then return {} end
    error("mapas_fao/indice.lua: " .. tostring(lista), 0)
  end
  if type(lista) ~= "table" then error("mapas_fao/indice.lua: debe devolver una tabla { nombre = numero }", 0) end
  local salida = {}
  for nombre, num in pairs(lista) do
    local function fallo(msg) error("mapas_fao/indice.lua: '" .. tostring(nombre) .. "': " .. msg, 0) end
    if type(nombre) ~= "string" or not nombre:match("^[a-z][a-z0-9_]*$") or RESERVADOS[nombre] then fallo("nombre no válido (minúsculas, cifras y _, empezando por letra, y no reservado)") end
    if type(num) ~= "number" or num ~= math.floor(num) or num < 0 then fallo("el número del mapa debe ser un entero, es " .. tostring(num)) end
    local base = string.format("map%03d", num)
    if not MapaMpc.leerArchivo("compartido/datos/mapas_fao/" .. base .. ".mpc") then fallo("falta compartido/datos/mapas_fao/" .. base .. ".mpc") end
    if not pcall(require, "compartido.datos.mapas_fao." .. base .. "_datos") then fallo("falta o falla compartido/datos/mapas_fao/" .. base .. "_datos.lua (hay que hornearlo con hornear_mpc.py)") end
    salida[nombre] = num
  end
  return salida
end

M.MAPAS = leerIndice()
for nombre, num in pairs(A_MANO) do M.MAPAS[nombre] = num end

-- Nombres ordenados (para la ayuda del administrador).
function M.nombres()
  local l = {}
  for n in pairs(M.MAPAS) do l[#l + 1] = n end
  table.sort(l)
  return l
end

function M.instalar(Mundo)
  function Mundo:crearMapasFao()
    for nombre, num in pairs(M.MAPAS) do self.mapas[nombre] = MapaMpc.cargar(num) end
  end

  -- Criaturas de los campamentos de cada mapa de FAO, con modo = nombre del mapa: solo se ven y pelean con ellas los jugadores que están dentro. Igual que Mundo:poblar()
  -- (en círculo de 1,2 casillas alrededor del campamento; el 40 % de las agresivas pasa a no agresiva), pero sin salirse de las casillas transitables. Devuelve cuántas creó.
  function Mundo:poblarMapasFao()
    local creadas = 0
    for nombre in pairs(M.MAPAS) do
      local mapa = self.mapas[nombre]
      for _, camp in ipairs(mapa.campamentos or {}) do
        for i = 1, camp.cantidad do
          local ang = (i / camp.cantidad) * math.pi * 2
          local x, y = camp.x + math.cos(ang) * 1.2, camp.y + math.sin(ang) * 1.2
          if not Mapa.transitable(mapa, math.floor(x), math.floor(y)) then x, y = camp.x, camp.y end
          local mon = self:spawnMonstruo(camp.monstruo, x, y, camp, camp.nivel)
          if mon then
            mon.modo = nombre
            mon.hogarx, mon.hogary = camp.x, camp.y
            if mon.agresivo and not mon.elite and math.random() < 0.4 then mon.agresivo = false end
            creadas = creadas + 1
          end
        end
      end
    end
    return creadas
  end

  -- El mapa de FAO en el que está e (o nil).
  function Mundo:enMapaFao(e)
    local m = e and self.mapas[e.modo]
    return m and m.fao and m or nil
  end

  function Mundo:entrarMapaFao(p, nombre)
    local m = self.mapas[nombre]
    if not (m and m.fao) then return "No existe ese mapa." end
    if p.kind ~= "jugador" then return "Solo los jugadores entran." end
    if p.modo ~= "mundo" or (p.z or 0) > 0 then return "No puedes entrar desde aquí." end
    p.retorno = { x = p.x, y = p.y, modo = "mundo" }
    p.modo, p.casaId, p.z = nombre, nil, 0
    p.zona = m.nombre
    p.x, p.y = m.entrada.x, m.entrada.y
    p.objetivo, p.camino, p.persigue = nil, nil, false
    self:mensaje("sistema", "", "Entras en " .. m.nombre .. " (mapa de Free Angels Online, prueba). Sal por los triángulos del borde del mapa.", p)
    return nil
  end

  function Mundo:salirMapaFao(p)
    local m = self:enMapaFao(p)
    if not m then return end
    local r = p.retorno or p.vinculo or { x = p.x, y = p.y }
    p.modo, p.z, p.casaId = "mundo", 0, nil
    p.x, p.y = r.x, r.y
    p.objetivo, p.camino, p.persigue = nil, nil, false
    p.zona = nil
    self:mensaje("sistema", "", "Sales de " .. m.nombre .. ".", p)
  end

  -- Cada tick de un jugador: si pisa una de las salidas (los triángulos de los puntos 1 y 2 del .mpc), sale.
  function Mundo:vigilarSalidaFao(p)
    local m = self:enMapaFao(p)
    if not m or not p.vivo then return end
    local px, py = p.x * MapaMpc.CELDA, p.y * MapaMpc.CELDA          -- (los triángulos del .mpc están en píxeles de FAO)
    for _, s in ipairs(m.mpc.salidas) do
      if MapaMpc.puntoEnPoligono(s.puntos, px, py) then self:salirMapaFao(p) return end
    end
  end
end

M.Mapa = Mapa

return M
