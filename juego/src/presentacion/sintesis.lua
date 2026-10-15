-- Síntesis de los sonidos del juego: no hay archivos de audio, cada efecto se genera con ondas (senos, sierras, ruido filtrado) al
-- arrancar. Cada función devuelve un SoundData mono. Familias de criaturas: ataque_<familia>, herido_<familia>, muerte_<familia>.
local S = {}

local TASA = 22050
local PI2 = math.pi * 2

local function datos(dur, f)
  local n = math.floor(TASA * dur)
  local d = love.sound.newSoundData(n, TASA, 16, 1)
  for i = 0, n - 1 do
    local v = f(i / TASA, dur)
    if v > 1 then v = 1 elseif v < -1 then v = -1 end
    d:setSample(i, v)
  end
  return d
end

local sin, floor, random = math.sin, math.floor, math.random
local function sen(x) return sin(x * PI2) end
local function sierra(x) return 2 * (x - floor(x)) - 1 end
local function cuad(x) return (x - floor(x) < 0.5) and 1 or -1 end
local function ruido() return random() * 2 - 1 end
-- fase de un barrido lineal de frecuencia de f0 a f1 durante dur segundos
local function barrido(f0, f1, t, dur) return f0 * t + (f1 - f0) * t * t / (2 * dur) end
local function entra(t, a) return t >= a and 1 or t / a end
local function cae(t, dur, k) local x = 1 - t / dur if x < 0 then x = 0 end return x ^ k end
-- filtro paso bajo de un polo (devuelve una función con su propio estado)
local function paso(c)
  local y = 0
  return function(x) y = y + c * (x - y) return y end
end

local F = {}

-- ----------------------------------------------------------------------------------------------------------- poderes
function F.corte()
  local lp = paso(0.35)
  return datos(0.22, function(t, d)
    local r = ruido()
    local alto = r - lp(r)
    return (alto * 0.6 * cae(t, d, 2.4) + sen(barrido(1500, 420, t, d)) * 0.22 * cae(t, d, 3)) * entra(t, 0.004)
  end)
end

function F.lanza()
  local lp = paso(0.22)
  return datos(0.28, function(t, d)
    local r = ruido()
    local silbido = (r - lp(r)) * 0.5 * (sin(math.pi * t / d) ^ 1.5)
    local golpe = sen(barrido(130, 55, t, d)) * 0.45 * cae(t, d, 5) * ((t > 0.07) and 1 or 0)
    return silbido + golpe
  end)
end

function F.grito()
  local lp = paso(0.4)
  return datos(0.45, function(t, d)
    local f = barrido(250, 150, t, d) + 0.03 * sen(6 * t)
    return (lp(sierra(f)) * 0.55 + ruido() * 0.08) * entra(t, 0.02) * cae(t, d, 1.2)
  end)
end

function F.magia()
  return datos(0.5, function(t, d)
    local trem = 1 + 0.3 * sen(14 * t)
    return (sen(barrido(500, 1500, t, d)) * 0.34 * trem + sen(barrido(750, 2250, t, d)) * 0.14) * entra(t, 0.03) * cae(t, d, 1.5)
  end)
end

function F.fuego()
  local lp = paso(0.09)
  local chasquido = 0
  return datos(0.55, function(t, d)
    if random() < 0.004 then chasquido = 0.7 end
    chasquido = chasquido * 0.9
    return (lp(ruido()) * 2.4 * (sin(math.pi * t / d) ^ 0.7) + chasquido * ruido() * 0.5) * 0.7
  end)
end

function F.hielo()
  return datos(0.6, function(t, d)
    local v = 0
    local notas = { { 1320, 0 }, { 1760, 0.05 }, { 2093, 0.1 }, { 2637, 0.15 } }
    for _, n in ipairs(notas) do
      local u = t - n[2]
      if u > 0 then v = v + sen(n[1] * u) * 0.2 * ((1 - u / 0.45 > 0) and (1 - u / 0.45) ^ 2 or 0) end
    end
    return v
  end)
end

function F.flecha()
  local lp = paso(0.3)
  return datos(0.22, function(t, d)
    local r = ruido()
    return ((r - lp(r)) * 0.4 * cae(t, 0.13, 2) + sierra(barrido(900, 250, t, d)) * 0.22 * cae(t, d, 3)) * entra(t, 0.003)
  end)
end

function F.cura()
  return datos(0.6, function(t)
    local v = 0
    local notas = { { 523, 0 }, { 659, 0.1 }, { 784, 0.2 }, { 1047, 0.3 } }
    for _, n in ipairs(notas) do
      local u = t - n[2]
      if u > 0 then v = v + sen(n[1] * u) * 0.24 * math.exp(-u * 7) end
    end
    return v
  end)
end

function F.sagrado()
  return datos(0.7, function(t, d)
    local v = (sen(523 * t) + sen(659 * t) + sen(784 * t) + sen(1047 * t) * 0.6) * 0.16
    return (v + sen(2093 * t) * 0.05 * (0.5 + 0.5 * sen(9 * t))) * entra(t, 0.08) * cae(t, d, 1.4)
  end)
end

function F.oscuro()
  local lp = paso(0.2)
  return datos(0.55, function(t, d)
    local anillo = 0.7 + 0.3 * sen(30 * t)
    local v = sierra(barrido(120, 70, t, d)) * 0.34 + sen(barrido(60, 45, t, d)) * 0.3 + lp(ruido()) * 0.2
    return v * anillo * entra(t, 0.02) * cae(t, d, 1.3)
  end)
end

-- ------------------------------------------------------------------------------------------------ voces de criaturas
-- Cada familia tiene tres sonidos: ataque, herido y muerte.
local V = {}

-- bestias: gruñidos graves
V.bestia = {
  ataque = function()
    local lp = paso(0.3)
    return datos(0.38, function(t, d)
      return (lp(sierra(barrido(150, 95, t, d) + 0.02 * sen(9 * t))) * 0.6 + ruido() * 0.1) * entra(t, 0.03) * cae(t, d, 1.3)
    end)
  end,
  herido = function()
    local lp = paso(0.35)
    return datos(0.2, function(t, d) return lp(sierra(barrido(420, 230, t, d))) * 0.55 * entra(t, 0.01) * cae(t, d, 1.6) end)
  end,
  muerte = function()
    local lp = paso(0.28)
    return datos(0.65, function(t, d)
      return (lp(sierra(barrido(170, 45, t, d) + 0.03 * sen(7 * t))) * 0.6 + ruido() * 0.06) * entra(t, 0.02) * cae(t, d, 1.0)
    end)
  end,
}

-- criaturas pequeñas: chillidos agudos
V.pequeno = {
  ataque = function() return datos(0.13, function(t, d) return (sen(barrido(1500, 2000, t, d)) + sen(barrido(3000, 4000, t, d)) * 0.25) * 0.38 * entra(t, 0.005) * cae(t, d, 2) end) end,
  herido = function() return datos(0.1, function(t, d) return sen(barrido(2000, 900, t, d)) * 0.4 * cae(t, d, 1.5) end) end,
  muerte = function() return datos(0.3, function(t, d) return sen(barrido(1400, 250, t, d) + 0.04 * sen(18 * t)) * 0.42 * entra(t, 0.005) * cae(t, d, 1.2) end) end,
}

-- insectos: zumbidos
V.insecto = {
  ataque = function() return datos(0.28, function(t, d) return sierra(barrido(190, 230, t, d)) * (0.5 + 0.5 * sen(60 * t)) * 0.4 * entra(t, 0.01) * cae(t, d, 1.2) end) end,
  herido = function() return datos(0.12, function(t, d) return sierra(barrido(700, 350, t, d)) * 0.3 * cae(t, d, 1.5) end) end,
  muerte = function() return datos(0.32, function(t, d) return sierra(barrido(450, 100, t, d)) * (0.6 + 0.4 * sen(40 * t)) * 0.38 * cae(t, d, 1.2) end) end,
}

-- no muertos: lamentos huecos
V.no_muerto = {
  ataque = function()
    local lp = paso(0.3)
    return datos(0.5, function(t, d)
      return (lp(sierra(barrido(320, 250, t, d))) * (0.6 + 0.4 * sen(7 * t)) * 0.55 + ruido() * 0.05) * entra(t, 0.05) * cae(t, d, 1.2)
    end)
  end,
  herido = function() return datos(0.25, function(t, d) return (sen(barrido(420, 300, t, d)) * 0.4 + sen(barrido(840, 600, t, d)) * 0.15) * entra(t, 0.01) * cae(t, d, 1.5) end) end,
  muerte = function()
    local lp = paso(0.18)
    return datos(0.8, function(t, d)
      return (sen(barrido(450, 70, t, d)) * (0.65 + 0.35 * sen(8 * t)) * 0.45 + lp(ruido()) * 0.25 * t / d) * entra(t, 0.03) * cae(t, d, 0.9)
    end)
  end,
}

-- demonios: graves y ásperos
V.demonio = {
  ataque = function() return datos(0.4, function(t, d) return math.tanh((sierra(barrido(95, 80, t, d)) + cuad(barrido(48, 40, t, d)) * 0.5) * 1.8) * 0.45 * entra(t, 0.02) * cae(t, d, 1.2) end) end,
  herido = function() return datos(0.22, function(t, d) return math.tanh(sierra(barrido(180, 110, t, d)) * 1.6) * 0.45 * cae(t, d, 1.5) end) end,
  muerte = function() return datos(0.75, function(t, d) return (math.tanh(sierra(barrido(130, 40, t, d)) * 1.7) * 0.45 + ruido() * 0.08 * (1 - t / d)) * entra(t, 0.02) * cae(t, d, 1.0) end) end,
}

-- dragones: rugidos largos
V.dragon = {
  ataque = function()
    local lp = paso(0.2)
    return datos(0.6, function(t, d)
      return (lp(ruido()) * 2 * (0.6 + 0.4 * sen(25 * t)) * 0.45 + sierra(barrido(110, 60, t, d)) * 0.4) * entra(t, 0.05) * cae(t, d, 1.1)
    end)
  end,
  herido = function() return datos(0.3, function(t, d) return sierra(barrido(200, 120, t, d)) * 0.5 * entra(t, 0.01) * cae(t, d, 1.5) end) end,
  muerte = function()
    local lp = paso(0.15)
    return datos(0.95, function(t, d)
      return (sierra(barrido(150, 35, t, d) + 0.02 * sen(6 * t)) * 0.5 + lp(ruido()) * 0.9 * (sin(math.pi * t / d) ^ 0.8) * 0.5) * entra(t, 0.03) * cae(t, d, 0.8)
    end)
  end,
}

-- constructos y gigantes de piedra: golpes metálicos
V.constructo = {
  ataque = function()
    local lp = paso(0.5)
    return datos(0.32, function(t, d)
      local r = ruido()
      return (cuad(barrido(230, 210, t, d)) * 0.28 + (r - lp(r)) * 0.3 * cae(t, 0.06, 2)) * entra(t, 0.004) * cae(t, d, 2)
    end)
  end,
  herido = function() return datos(0.2, function(t, d) return (sen(700 * t) + sen(1130 * t) * 0.6 + sen(1710 * t) * 0.3) * 0.2 * cae(t, d, 3) end) end,
  muerte = function()
    local lp = paso(0.12)
    return datos(0.7, function(t, d)
      local clic = (random() < 0.01) and ruido() or 0
      return (lp(ruido()) * 2.2 * 0.4 + clic * 0.5) * entra(t, 0.01) * cae(t, d, 1.0)
    end)
  end,
}

-- plantas: chasquidos húmedos
V.planta = {
  ataque = function()
    local lp = paso(0.4)
    return datos(0.18, function(t, d) local r = ruido() return (r - lp(r)) * 0.55 * entra(t, 0.003) * cae(t, d, 2.2) end)
  end,
  herido = function() return datos(0.15, function(t, d) return (sen(barrido(500, 250, t, d)) * 0.35 + ruido() * 0.1) * cae(t, d, 1.5) end) end,
  muerte = function()
    local lp = paso(0.2)
    return datos(0.45, function(t, d) return (sen(barrido(400, 60, t, d)) * 0.4 + lp(ruido()) * 0.3) * entra(t, 0.01) * cae(t, d, 1.2) end)
  end,
}

-- humanoides: gruñidos y quejidos
V.humanoide = {
  ataque = function()
    local lp = paso(0.35)
    return datos(0.22, function(t, d) return (lp(sierra(barrido(190, 140, t, d))) * 0.55 + ruido() * 0.06) * entra(t, 0.02) * cae(t, d, 1.4) end)
  end,
  herido = function()
    local lp = paso(0.35)
    return datos(0.2, function(t, d) return lp(sierra(barrido(260, 170, t, d))) * 0.5 * entra(t, 0.01) * cae(t, d, 1.5) end)
  end,
  muerte = function()
    local lp = paso(0.3)
    return datos(0.55, function(t, d) return lp(sierra(barrido(210, 55, t, d) + 0.02 * sen(8 * t))) * 0.55 * entra(t, 0.02) * cae(t, d, 1.0) end)
  end,
}

-- ------------------------------------------------------------------------------------------------ muerte del personaje
-- Tres notas que bajan, suaves y tristes.
function F.muerte_jugador()
  local lp = paso(0.3)
  return datos(1.2, function(t, d)
    local notas = { { 392, 0, 0.4 }, { 330, 0.38, 0.4 }, { 262, 0.76, 0.44 } }
    local v = 0
    for _, n in ipairs(notas) do
      local u = t - n[2]
      if u > 0 and u < n[3] then
        v = v + lp(sierra(n[1] * u + 0.01 * sen(5 * u))) * 0.5 * entra(u, 0.02) * (1 - u / n[3]) ^ 1.2
      end
    end
    return v + sen(98 * t) * 0.16 * cae(t, d, 1.5)
  end)
end

-- Todos los sonidos: nombre -> función que lo genera.
function S.catalogo()
  local lista = {}
  for nombre, f in pairs(F) do lista[nombre] = f end
  for familia, voces in pairs(V) do
    lista["ataque_" .. familia] = voces.ataque
    lista["herido_" .. familia] = voces.herido
    lista["muerte_" .. familia] = voces.muerte
  end
  return lista
end

return S
