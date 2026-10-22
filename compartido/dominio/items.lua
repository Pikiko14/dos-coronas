-- Equipo del juego: armas, armaduras, escudos, anillos y amuletos en diez escalones.
--
-- Hay tres tipos de armadura, uno por oficio:
--   pesada (guerrero): mucha defensa física y poca mágica, algo de vida; pesa y frena.
--   ligera (cazador):  defensa media, da velocidad y un poco de ataque.
--   tela   (mago y clérigo): poca defensa física, mucha mágica, maná y ataque mágico.
-- Cada pieza de un escalón vale (valor base de su casilla) x (potencia del escalón) x (factor
-- del tipo), así que todo el equipo se calibra tocando las tablas de este archivo.
local M = {}
require("compartido.dominio.configuracion").aplicar(M, "items")

-- Los escalones, factores, nombres e iconos viven en compartido/datos/equipo.xml.
local EQ = require("compartido.dominio.configuracion").tabla("equipo")

-- nivel mínimo y potencia de cada escalón
M.TIER = EQ.escalones
M.ARMADURA = EQ.armadura_por_clase

local ADJ = EQ.adjetivos
local CASILLA = EQ.casillas
local TIPO = EQ.tipos_armadura
local ICONO = EQ.iconos_armadura
local HOJA_ARMADURA = EQ.hojas_armadura or {}
local ARMAS = EQ.armas
local ESCUDOS = EQ.escudos.iconos
local ANILLOS = EQ.anillos.iconos
local AMULETOS = EQ.amuletos.iconos

local NOMBRE_ARMADURA = {}
for tipo, huecos in pairs(EQ.nombres_armadura) do
  NOMBRE_ARMADURA[tipo] = {}
  for hueco, par in pairs(huecos) do NOMBRE_ARMADURA[tipo][hueco] = { par.nombre, par.g } end
end

local function redondear(v) return math.floor(v + 0.5) end

-- Icono de un escalón: los escalones sin icono propio (los últimos) usan el del último que lo tiene y se distinguen por su tinte.
local function icono(lista, t) return lista[t] or lista[#lista] end

-- Iconos de FAO de los escalones 1 a 8 (equipo_iconos_fao.xml, lo genera herramientas/generar_personajes/iconos_equipo.py): casilla de cada pieza por clase,
-- hueco y escalón en la lámina equipo_fao.png (-1 = sin icono: se queda el de la lámina antigua).
local FAOI = require("compartido.dominio.configuracion").tabla("equipo_iconos_fao")
local function iconoFao(clase, slot, t)
  local lista = FAOI and FAOI[clase] and FAOI[clase][slot]
  local c = lista and lista[t]
  if c and c >= 0 then return c end
end

-- Los escalones con lámina propia de iconos (tier.hoja: 9 y 10, equipo_altos.png) tienen sus casillas en equipo.xml (iconos_altos).
local ALTOS = EQ.iconos_altos
local function altos(tier, t, tipo, hueco_o_arma)
  if not (tier.hoja and ALTOS) then return nil end
  local lista = tipo and ALTOS[tipo] and ALTOS[tipo][hueco_o_arma] or (not tipo and ALTOS.armas and ALTOS.armas[hueco_o_arma])
  return lista and lista[t - #EQ.escalones + 2]       -- (los dos últimos escalones: 1 y 2 de la lista)
end

local function precio(base, mul) return math.floor(base * mul ^ 1.5 * M.FACTOR_PRECIO) end

local function redondeado(it)
  for _, k in ipairs({ "atk", "matk", "def", "mdef", "hp", "mp" }) do
    if it[k] then
      it[k] = redondear(it[k])
      if it[k] == 0 then it[k] = nil end
    end
  end
  if it.spd then it.spd = math.floor(it.spd * 1000 + 0.5) / 1000 end
  return it
end

-- Registra todo el equipo en D.items (D.items ya existe).
function M.generar(D)
  local function add(it) it.botin = it.tier and M.TIER[it.tier].botin or nil; D.items[it.id] = redondeado(it) end
  for t, tier in ipairs(M.TIER) do
    local u = tier.mul
    for clase, armas in pairs(ARMAS) do
      local tipo = M.ARMADURA[clase]
      local f = TIPO[tipo]
      -- armas
      for _, a in ipairs(armas) do
        local g = a.g
        add({
          id = clase .. "_" .. a.id .. "_" .. t, nombre = a.nombre .. " " .. ADJ[g][t],
          hueco = "arma", clase = clase, tier = t, nivel = tier.nivel, familia = a.id, arma = a.arma,
          atk = a.atk and a.atk * u or nil, matk = a.matk and a.matk * u or nil,
          def = a.def and a.def * u or nil, hp = a.hp and a.hp * u or nil, mp = a.mp and a.mp * u or nil,
          spd = a.spd and a.spd * (1 + 0.15 * (t - 1)) or nil,
          precio = precio(55, u), hoja = a.hoja or "equipment", sprite = icono(a.iconos, t),
        })
        local propio = altos(tier, t, nil, a.id == "hacha" and "hacha" or a.arma)
        if propio then D.items[clase .. "_" .. a.id .. "_" .. t].hoja, D.items[clase .. "_" .. a.id .. "_" .. t].sprite = tier.hoja, propio end
        local fao = not tier.hoja and iconoFao(clase, a.id == "hacha" and "arma2" or "arma", t)
        if fao then D.items[clase .. "_" .. a.id .. "_" .. t].hoja, D.items[clase .. "_" .. a.id .. "_" .. t].sprite = "fao", fao end
      end
      -- armadura de su tipo
      for _, hueco in ipairs({ "cabeza", "pecho", "piernas", "pies" }) do
        local c = CASILLA[hueco]
        local peso = c.def / 2.6
        local nombre, g = NOMBRE_ARMADURA[tipo][hueco][1], NOMBRE_ARMADURA[tipo][hueco][2]
        local it = {
          id = clase .. "_" .. hueco .. "_" .. t, nombre = nombre .. " " .. ADJ[g][t],
          hueco = hueco, clase = clase, tier = t, nivel = tier.nivel, armadura = tipo,
          def = math.max(1, c.def * u * f.def), mdef = math.max(1, c.def * u * f.mdef),
          hp = c.hp * u * f.hp, spd = f.spd * peso,
          atk = f.atk and f.atk * u * peso or nil, matk = f.matk and f.matk * u * peso or nil,
          mp = f.mp and f.mp * u * peso or nil,
          precio = precio(c.def * 17, u), hoja = HOJA_ARMADURA[tipo] or "equipment", sprite = icono(ICONO[tipo][hueco], t),
        }
        if hueco == "pies" then it.spd = f.botas * (1 + 0.15 * (t - 1)) + (tipo == "pesada" and -0.02 or 0) end
        local propio = altos(tier, t, tipo, hueco)
        if propio then it.hoja, it.sprite = tier.hoja, propio end
        local fao = not tier.hoja and iconoFao(clase, hueco, t)
        if fao then it.hoja, it.sprite = "fao", fao end
        add(it)
      end
    end
    -- escudos: el guerrero para aguantar golpes; el clérigo, sobre todo para la magia
    add({
      id = "guerrero_escudo_" .. t, nombre = "Escudo " .. ADJ.m[t], hueco = "escudo", clase = "guerrero",
      tier = t, nivel = tier.nivel, armadura = "pesada",
      def = 2.4 * u, mdef = 0.9 * u, hp = 3 * u, precio = precio(40, u), hoja = "equipment", sprite = icono(ESCUDOS, t), tinte = tier.tinte,
    })
    add({
      id = "anillo_" .. t, nombre = "Anillo " .. ADJ.m[t], hueco = "anillo", tier = t, nivel = tier.nivel,
      atk = 0.6 * u, matk = 0.6 * u, mp = 5 * u, precio = precio(45, u), hoja = "equipment", sprite = icono(ANILLOS, t), tinte = tier.tinte,
    })
    add({
      id = "amuleto_" .. t, nombre = "Amuleto " .. ADJ.m[t], hueco = "amuleto", tier = t, nivel = tier.nivel,
      hp = 10 * u, def = 0.5 * u, mdef = 0.5 * u, precio = precio(50, u), hoja = "equipment", sprite = icono(AMULETOS, t), tinte = tier.tinte,
    })
  end
end

-- Escalón más alto que puede llevar alguien de ese nivel.
function M.tierPara(nivel)
  local mejor = 1
  for t, tier in ipairs(M.TIER) do
    if (nivel or 1) >= tier.nivel then mejor = t end
  end
  return mejor
end

-- Todo el equipo de un escalón para un oficio (arma principal, armadura, escudo si lleva).
function M.equipoDe(clase, tier)
  local e = {
    arma = clase .. "_arma_" .. tier,
    cabeza = clase .. "_cabeza_" .. tier,
    pecho = clase .. "_pecho_" .. tier,
    piernas = clase .. "_piernas_" .. tier,
    pies = clase .. "_pies_" .. tier,
  }
  if clase == "guerrero" or clase == "clerigo" then e.escudo = clase .. "_escudo_" .. tier end
  return e
end

local HUECOS_BOTIN = EQ.botin_huecos.lista

-- Una pieza al azar de un escalón para un oficio (la usa el botín). azar(n) da 1..n.
function M.aleatorio(D, clase, tier, azar)
  azar = azar or math.random
  local hueco = HUECOS_BOTIN[azar(#HUECOS_BOTIN)]
  local id
  if hueco == "arma" then
    local familias = ARMAS[clase] or ARMAS.guerrero
    id = clase .. "_" .. familias[azar(#familias)].id .. "_" .. tier
  elseif hueco == "anillo" or hueco == "amuleto" then
    id = hueco .. "_" .. tier
  else
    id = clase .. "_" .. hueco .. "_" .. tier
  end
  if D.items[id] then return id end
  return clase .. "_arma_" .. tier
end

-- Una pieza al azar de cualquier oficio (el botín de las criaturas y de los cofres no depende de la clase de quien
-- lo recoge). Las clases se recorren en orden fijo para que el azar sea repetible con una misma semilla.
local CLASES_BOTIN = {}
for clase in pairs(ARMAS) do CLASES_BOTIN[#CLASES_BOTIN + 1] = clase end
table.sort(CLASES_BOTIN)
function M.aleatorioCualquiera(D, tier, azar)
  azar = azar or math.random
  return M.aleatorio(D, CLASES_BOTIN[azar(#CLASES_BOTIN)], tier, azar)
end
return M
