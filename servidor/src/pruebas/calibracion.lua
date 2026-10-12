-- Informe de calibración del combate: pone a cada oficio frente a criaturas de su nivel (y
-- de niveles más altos) con el equipo de su escalón y los puntos del árbol gastados, y mide cuánto
-- tarda en ganar y cuánta vida pierde. Se ejecuta con: love servidor --calibrar
-- Escribe servidor/calibracion.txt (o la carpeta de logs).
local Datos = require("compartido.dominio.datos")
local Mundo = require("compartido.dominio.mundo")
local Arbol = require("compartido.dominio.arbol")
local Log = require("compartido.infraestructura.log")

local C = {}

-- Criatura (no élite) cuyo nivel se acerque más a n.
local function monstruoDeNivel(n)
  local mejor
  for _, m in ipairs(Datos.monstruos) do
    if not m.elite and not m.noCampamento and (not mejor or math.abs(m.nivel - n) < math.abs(mejor.nivel - n)) then mejor = m end
  end
  return mejor
end

local function gastarPuntos(mundo, p)
  local nodos = Arbol.nodos(p.clase)
  local avance = true
  while avance do
    avance = false
    for _, n in ipairs(nodos) do
      if mundo:aprenderHabilidad(p, n.id) == nil then avance = true end
    end
  end
end

local OFENSIVOS = { enemigo = true, alrededor = true, punto = true, mixto = true }

-- Un duelo sin movimiento ni pociones: devuelve segundos, vida perdida (fracción) y si ganó.
local function duelo(mundo, clase, nivel, mon, opciones)
  opciones = opciones or {}
  local p = mundo:crearPersonaje({ nombre = "Sim", faccion = "albor", clase = clase, nivel = nivel })
  gastarPuntos(mundo, p)
  p.hp, p.mp = p.hpMax, p.mpMax
  local m = mundo:spawnMonstruo(mon.id, p.x + (opciones.distancia or 1.2), p.y, { x = p.x, y = p.y })
  m.agresivo = true
  m.objetivo, m.amenaza = p.id, p.id
  p.objetivo = m.id
  -- poderes ofensivos ordenados por daño por segundo
  local orden = {}
  for slot, id in ipairs(Datos.barra[clase]) do
    local h = Arbol.rango(p, id) > 0 and Arbol.efectiva(id, Arbol.rango(p, id))
    if h and (OFENSIVOS[h.tipo] or h.tipo == "aliado" and id == "curar") then
      orden[#orden + 1] = { slot = slot, id = id, valor = (h.coef or 0) / h.cd }
    end
  end
  table.sort(orden, function(a, b) return a.valor > b.valor end)
  local t, minHp = 0, p.hp
  while t < 240 and m.vivo and p.vivo do
    t = t + 0.05
    if clase == "clerigo" and p.hp < p.hpMax * 0.5 then
      p.objetivo = p.id
      mundo:usarHabilidad(p, 1)
      p.objetivo = m.id
    end
    for _, o in ipairs(orden) do
      if o.id ~= "curar" and mundo:usarHabilidad(p, o.slot) == nil then break end
    end
    mundo:actualizar(0.05)
    minHp = math.min(minHp, p.hp)
  end
  local res = { t = t, perdida = 1 - math.max(0, minHp) / p.hpMax, gano = not m.vivo and p.vivo, hp = m.hpMax }
  p.borrar, m.borrar = true, true
  mundo.entidades[p.id], mundo.entidades[m.id] = nil, nil
  return res
end

C.duelo = duelo
C.monstruoDeNivel = monstruoDeNivel

function C.correr()
  collectgarbage()
  local m0, t0 = collectgarbage("count"), os.clock()
  local mundo = Mundo.nuevo()
  collectgarbage()
  local n = 0
  for _ in pairs(mundo.entidades) do n = n + 1 end
  Log.info(string.format("generar el mundo: %.2f s, %.0f MB, %d entidades", os.clock() - t0, (collectgarbage("count") - m0) / 1024, n))
  -- mundo vacío: sin guardias ni criaturas que estorben el duelo
  mundo.entidades = {}
  local lineas = {}
  local function out(s) lineas[#lineas + 1] = s end
  out("Calibración de combate (sin pociones, sin moverse, puntos del árbol gastados, equipo del escalón)")
  out(string.format("%-8s %3s  %-22s %3s | %6s %6s %s", "oficio", "nv", "criatura", "nv", "tiempo", "vida-", "resultado"))
  local casos = {
    { 5, 0 }, { 10, 0 }, { 20, 0 }, { 30, 0 },
    { 8, 3 }, { 8, 5 }, { 8, 13 }, { 12, 5 }, { 20, 6 },
  }
  for _, clase in ipairs({ "guerrero", "mago", "cazador", "clerigo" }) do
    for _, caso in ipairs(casos) do
      local nivel, mas = caso[1], caso[2]
      local mon = monstruoDeNivel(nivel + mas)
      local ok, r = pcall(duelo, mundo, clase, nivel, mon)
      if ok then
        out(string.format("%-8s %3d  %-22s %3d | %5.1fs %5.0f%%  %s", clase, nivel, mon.nombre, mon.nivel,
          r.t, r.perdida * 100, r.gano and "gana" or "PIERDE"))
      else
        out(clase .. " " .. nivel .. " EX " .. tostring(r))
      end
    end
  end
  local texto = table.concat(lineas, "\n")
  Log.volcar("calibracion.txt", texto)
  print(texto)
  return texto
end

return C
