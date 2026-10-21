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
    if e and e.modo == "moba" then self:asegurarArenaMoba() end
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

  -- Portales de los continentes: en cada continente hay un portal por cada mapa de FAO (se crean solos con los mapas de M.MAPAS: un mapa nuevo del editor tiene su portal sin tocar código).
  -- Cada portal sale junto a los campamentos del continente que tienen las criaturas de la configuración de ese mapa (sus campamentos): el portal de la Granja de pinchos, entre setas y larvas;
  -- así los portales quedan repartidos por el continente, no juntos. Un mapa sin campamentos (o sin esas criaturas en el continente) usa un sitio en su dirección alrededor de la capital.
  -- Pisar el portal entra en el mapa; al salir se vuelve junto a él (a unos pasos, y con unos segundos sin volver a entrar). Se puede entrar montado.
  local RADIO_PORTAL = 0.9
  function Mundo:crearPortalesFao()
    self.portalesFao = {}
    local mundo = self.mapas.mundo
    local nombres = M.nombres()
    local usados = {}
    local function contDe(x, y) return mundo.cont[math.floor(x)] and mundo.cont[math.floor(x)][math.floor(y)] end
    local function libreParaPortal(x, y, cont, sep)
      if not (x > 3 and y > 3 and x < mundo.w - 3 and y < mundo.h - 3) or self:ciudadEn(x + 0.5, y + 0.5) then return false end
      for dx = -1, 1 do for dy = -1, 1 do
        if not (Mapa.transitable(mundo, x + dx, y + dy) and mundo.suelo[x + dx][y + dy] ~= "agua") then return false end
      end end
      if contDe(x, y) ~= cont then return false end
      for _, u in ipairs(usados) do if math.abs(u[1] - x) < sep and math.abs(u[2] - y) < sep then return false end end
      return true
    end
    for _, faccion in ipairs({ "albor", "umbra" }) do
      local capital
      for _, c in ipairs(mundo.ciudades) do if c.faccion == faccion and c.spawn and not capital then capital = c end end
      if capital then
        local cont = contDe(capital.spawn.x, capital.spawn.y)
        for i, nombre in ipairs(nombres) do
          local hallado
          -- campamentos del continente con criaturas del mapa (ordenados para que el reparto sea siempre el mismo)
          local suyas = {}
          for _, c in ipairs(self.mapas[nombre].campamentos or {}) do suyas[c.monstruo] = true end
          local camps = {}
          for _, camp in ipairs(mundo.campamentos or {}) do
            if suyas[camp.monstruo] and not camp.z and contDe(camp.x, camp.y) == cont and not self:ciudadEn(camp.x, camp.y) then camps[#camps + 1] = camp end
          end
          table.sort(camps, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
          if #camps > 0 then
            -- se elige un campamento repartido (sin los más cercanos a otro portal) y un sitio libre a 2-6 casillas de él
            local ordenados = {}
            for k, camp in ipairs(camps) do
              local d = 1e9
              for _, u in ipairs(usados) do d = math.min(d, math.abs(u[1] - camp.x) + math.abs(u[2] - camp.y)) end
              ordenados[#ordenados + 1] = { camp = camp, d = d, k = (k * 7 + i * 13) % (#camps + 1) }
            end
            local function rango(d) return d >= 30 and 0 or (d >= 15 and 1 or 2) end     -- primero los campamentos lejos de otros portales
            table.sort(ordenados, function(a, b)
              if rango(a.d) ~= rango(b.d) then return rango(a.d) < rango(b.d) end
              if a.d ~= b.d and rango(a.d) == 0 then return a.d > b.d end
              return a.k < b.k
            end)
            for _, o in ipairs(ordenados) do
              for r = 2, 6 do
                for g = 0, 11 do
                  local ang = g / 12 * math.pi * 2 + i
                  local x, y = math.floor(o.camp.x + math.cos(ang) * r), math.floor(o.camp.y + math.sin(ang) * r)
                  if libreParaPortal(x, y, cont, 6) then hallado = { x + 0.5, y + 0.5 } break end
                end
                if hallado then break end
              end
              if hallado then break end
            end
          end
          if not hallado then
            -- sin campamentos: en su dirección alrededor de la capital, o en direcciones vecinas y radios mayores
            local ang0 = (i - 0.5) / #nombres * math.pi * 2
            for _, giro in ipairs({ 0, 0.25, -0.25, 0.5, -0.5, 0.75, -0.75, 1.0, -1.0, 1.5, -1.5, 2.0, -2.0, 3.0 }) do
              for r = 14, 60 do
                local ang = ang0 + giro
                local x, y = math.floor(capital.spawn.x + math.cos(ang) * r), math.floor(capital.spawn.y + math.sin(ang) * r)
                if libreParaPortal(x, y, cont, 4) then hallado = { x + 0.5, y + 0.5 } break end
              end
              if hallado then break end
            end
          end
          if hallado then
            usados[#usados + 1] = hallado
            local e = {
              id = self:idNuevo(), kind = "portal", nombre = "Portal: " .. (self.mapas[nombre].nombre or nombre), mapaFao = nombre, faccion = faccion,
              x = hallado[1], y = hallado[2], modo = "mundo", z = 0, vivo = true, dir = 1,
            }
            self.entidades[e.id] = e
            self.portalesFao[#self.portalesFao + 1] = e
          end
        end
      end
    end
  end

  function Mundo:vigilarPortalesFao(p)
    if not p.vivo or (p.portalHasta or 0) > self.tiempo then return end
    for _, pt in ipairs(self.portalesFao or {}) do
      if math.abs(pt.x - p.x) < RADIO_PORTAL and math.abs(pt.y - p.y) < RADIO_PORTAL then
        if (p.ultimoGolpe or -99) + 6 > self.tiempo then
          p.portalHasta = self.tiempo + 3
          self:mensaje("sistema", "", "No puedes cruzar el portal en combate.", p)
          return
        end
        -- vuelta: unos pasos al lado del portal, hacia de donde venías
        local dx, dy = p.x - pt.x, p.y - pt.y
        local l = math.max(0.1, math.sqrt(dx * dx + dy * dy))
        local rx, ry = pt.x + dx / l * 2.5, pt.y + dy / l * 2.5
        if not Mapa.transitable(self.mapas.mundo, math.floor(rx), math.floor(ry)) then rx, ry = p.x, p.y end
        local err = self:entrarMapaFao(p, pt.mapaFao)
        if not err then p.retorno = { x = rx, y = ry, modo = "mundo" } end
        return
      end
    end
  end

  function Mundo:salirMapaFao(p)
    local m = self:enMapaFao(p)
    if not m then return end
    local r = p.retorno or p.vinculo or { x = p.x, y = p.y }
    p.modo, p.z, p.casaId = "mundo", 0, nil
    p.x, p.y = r.x, r.y
    p.objetivo, p.camino, p.persigue = nil, nil, false
    p.zona = nil
    p.portalHasta = self.tiempo + 3
    self:mensaje("sistema", "", "Sales de " .. m.nombre .. ".", p)
  end

  -- Cada tick de un jugador: si pisa una de las salidas (los triángulos de los puntos 1 y 2 del .mpc), sale.
  function Mundo:vigilarSalidaFao(p)
    local m = self:enMapaFao(p)
    if not m or not p.vivo or p.modo == "moba" then return end        -- (en el asedio se sale con el evento)
    local px, py = p.x * MapaMpc.CELDA, p.y * MapaMpc.CELDA          -- (los triángulos del .mpc están en píxeles de FAO)
    for _, s in ipairs(m.mpc.salidas) do
      if MapaMpc.puntoEnPoligono(s.puntos, px, py) then self:salirMapaFao(p) return end
    end
  end
end

M.Mapa = Mapa

return M
