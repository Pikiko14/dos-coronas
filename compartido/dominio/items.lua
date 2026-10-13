-- Equipo del juego: armas, armaduras, escudos, anillos y amuletos en ocho escalones.
--
-- Hay tres tipos de armadura, uno por oficio:
--   pesada (guerrero): mucha defensa física y poca mágica, algo de vida; pesa y frena.
--   ligera (cazador):  defensa media, da velocidad y un poco de ataque.
--   tela   (mago y clérigo): poca defensa física, mucha mágica, maná y ataque mágico.
-- Cada pieza de un escalón vale (valor base de su casilla) x (potencia del escalón) x (factor
-- del tipo), así que todo el equipo se calibra tocando las tablas de este archivo.
local M = {}

-- nivel mínimo y potencia de cada escalón
M.TIER = {
  { nivel = 1, mul = 1.0 },
  { nivel = 4, mul = 1.7 },
  { nivel = 8, mul = 2.6 },
  { nivel = 12, mul = 3.6 },
  { nivel = 16, mul = 4.8 },
  { nivel = 20, mul = 6.2 },
  { nivel = 25, mul = 7.8 },
  { nivel = 30, mul = 10.0 },
}

M.ARMADURA = { guerrero = "pesada", cazador = "ligera", mago = "tela", clerigo = "tela" }

-- Adjetivo del escalón según el género y el número del objeto.
local ADJ = {
  m = { "tosco", "de soldado", "de veterano", "de capitán", "de campeón", "de élite", "legendario", "de corona" },
  f = { "tosca", "de soldado", "de veterano", "de capitán", "de campeón", "de élite", "legendaria", "de corona" },
  mp = { "toscos", "de soldado", "de veterano", "de capitán", "de campeón", "de élite", "legendarios", "de corona" },
  fp = { "toscas", "de soldado", "de veterano", "de capitán", "de campeón", "de élite", "legendarias", "de corona" },
}

-- Valor base por casilla y por escalón (potencia 1).
local CASILLA = {
  cabeza = { def = 1.6, hp = 4 },
  pecho = { def = 2.6, hp = 8 },
  piernas = { def = 2.0, hp = 5 },
  pies = { def = 1.0, hp = 0 },
}

-- Factores por tipo de armadura. atk/matk/mp: bonos por potencia y peso de la pieza.
local TIPO = {
  pesada = { def = 1.0, mdef = 0.35, hp = 1.0, spd = -0.02, botas = 0.0 },
  ligera = { def = 0.6, mdef = 0.45, hp = 0.8, spd = 0.03, botas = 0.10, atk = 0.35 },
  tela = { def = 0.3, mdef = 1.0, hp = 0.6, spd = 0.0, botas = 0.06, mp = 2.5, matk = 0.35 },
}

local NOMBRE_ARMADURA = {
  pesada = { cabeza = { "Yelmo", "m" }, pecho = { "Coraza", "f" }, piernas = { "Grebas", "fp" }, pies = { "Botas", "fp" } },
  ligera = { cabeza = { "Capucha", "f" }, pecho = { "Jubón", "m" }, piernas = { "Pantalón", "m" }, pies = { "Botas", "fp" } },
  tela = { cabeza = { "Sombrero", "m" }, pecho = { "Túnica", "f" }, piernas = { "Calzas", "fp" }, pies = { "Sandalias", "fp" } },
}

-- Iconos de la lámina de objetos (una lista de ocho por casilla y tipo).
local ICONO = {
  pesada = {
    cabeza = { 459, 458, 465, 473, 470, 486, 444, 449 },
    pecho = { 513, 517, 524, 529, 545, 553, 561, 581 },
    piernas = { 628, 632, 634, 636, 637, 639, 635, 633 },
    pies = { 663, 667, 668, 662, 665, 664, 661, 660 },
  },
  ligera = {
    cabeza = { 453, 432, 455, 439, 445, 451, 457, 460 },
    pecho = { 512, 515, 541, 569, 543, 559, 573, 577 },
    piernas = { 626, 624, 640, 642, 643, 631, 627, 630 },
    pies = { 657, 666, 656, 659, 669, 658, 660, 664 },
  },
  tela = {
    cabeza = { 481, 492, 504, 445, 438, 436, 468, 495 },
    pecho = { 519, 527, 540, 522, 539, 567, 566, 568 },
    piernas = { 625, 641, 629, 638, 631, 627, 626, 630 },
    pies = { 658, 661, 656, 660, 659, 665, 664, 662 },
  },
}

-- Armas: dos familias por oficio. atk/matk son por potencia; los bonos extra también.
local ARMAS = {
  guerrero = {
    { id = "arma", nombre = "Espada", g = "f", arma = "espada", atk = 5.5, def = 0.4, iconos = { 49, 52, 101, 116, 148, 86, 62, 165 } },
    { id = "hacha", nombre = "Hacha", g = "f", arma = "espada", atk = 6.9, hp = -1.5, iconos = { 224, 225, 241, 247, 251, 259, 262, 260 } },
  },
  cazador = {
    { id = "arma", nombre = "Arco", g = "m", arma = "arco", atk = 5.8, spd = 0.01, iconos = { 288, 290, 296, 300, 301, 303, 302, 319 } },
    { id = "ballesta", nombre = "Ballesta", g = "f", arma = "arco", atk = 7.0, spd = -0.012, iconos = { 304, 305, 306, 307, 308, 319, 321, 322 } },
  },
  mago = {
    { id = "arma", nombre = "Bastón", g = "m", arma = "baston", atk = 0.8, matk = 6.0, mp = 4, iconos = { 352, 359, 367, 342, 364, 365, 368, 366 } },
    { id = "vara", nombre = "Vara", g = "f", arma = "baston", atk = 0.8, matk = 6.9, iconos = { 343, 344, 345, 346, 347, 363, 362, 361 } },
  },
  clerigo = {
    { id = "arma", nombre = "Maza", g = "f", arma = "maza", atk = 1.0, matk = 4.6, hp = 4, iconos = { 176, 178, 183, 190, 196, 199, 204, 201 } },
    { id = "cetro", nombre = "Cetro", g = "m", arma = "maza", atk = 0.6, matk = 5.4, mp = 3, iconos = { 197, 198, 200, 202, 203, 205, 184, 186 } },
  },
}

local ESCUDOS = { 386, 400, 392, 395, 398, 408, 415, 422 }
local ANILLOS = { 736, 738, 739, 740, 741, 742, 743, 744 }
local AMULETOS = { 720, 721, 722, 723, 724, 725, 726, 727 }

local function redondear(v) return math.floor(v + 0.5) end

-- Precio: crece más rápido que la potencia para que lo bueno cueste.
-- FACTOR_PRECIO sube o baja los precios de todo el equipo de una vez.
M.FACTOR_PRECIO = 1.7
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
  local function add(it) D.items[it.id] = redondeado(it) end
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
          precio = precio(55, u), hoja = "equipment", sprite = a.iconos[t],
        })
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
          precio = precio(c.def * 17, u), hoja = "equipment", sprite = ICONO[tipo][hueco][t],
        }
        if hueco == "pies" then it.spd = f.botas * (1 + 0.15 * (t - 1)) + (tipo == "pesada" and -0.02 or 0) end
        add(it)
      end
    end
    -- escudos: el guerrero para aguantar golpes; el clérigo, sobre todo para la magia
    add({
      id = "guerrero_escudo_" .. t, nombre = "Escudo " .. ADJ.m[t], hueco = "escudo", clase = "guerrero",
      tier = t, nivel = tier.nivel, armadura = "pesada",
      def = 2.4 * u, mdef = 0.9 * u, hp = 3 * u, precio = precio(40, u), hoja = "equipment", sprite = ESCUDOS[t],
    })
    add({
      id = "clerigo_escudo_" .. t, nombre = "Escudo " .. ADJ.m[t], hueco = "escudo", clase = "clerigo",
      tier = t, nivel = tier.nivel, armadura = "tela",
      def = 1.0 * u, mdef = 2.4 * u, precio = precio(40, u), hoja = "equipment", sprite = ESCUDOS[t],
    })
    add({
      id = "anillo_" .. t, nombre = "Anillo " .. ADJ.m[t], hueco = "anillo", tier = t, nivel = tier.nivel,
      atk = 0.6 * u, matk = 0.6 * u, mp = 5 * u, precio = precio(45, u), hoja = "equipment", sprite = ANILLOS[t],
    })
    add({
      id = "amuleto_" .. t, nombre = "Amuleto " .. ADJ.m[t], hueco = "amuleto", tier = t, nivel = tier.nivel,
      hp = 10 * u, def = 0.5 * u, mdef = 0.5 * u, precio = precio(50, u), hoja = "equipment", sprite = AMULETOS[t],
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

local HUECOS_BOTIN = { "arma", "arma", "cabeza", "pecho", "piernas", "pies", "escudo", "anillo", "amuleto" }

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
return M
