-- Síntesis de los sonidos del juego: no hay archivos de audio, cada efecto se genera al arrancar con un pequeño motor de audio:
-- osciladores sin aliasing (PolyBLEP), ruido blanco y rosa, filtros resonantes de barrido (variable de estado), síntesis FM para
-- metales y cristales, cuerdas pulsadas (Karplus-Strong), voces por formantes para los rugidos y una reverb de salas (Schroeder).
-- A 44,1 kHz y con la señal pasada por filtros y reverb no suena a "pitidos" de consola: cada sonido tiene cuerpo, ataque y cola.
-- Todos los sonidos son mono. Familias de criaturas: ataque_<familia>, herido_<familia>, muerte_<familia>.
local S = {}

local TASA = 44100
local DT = 1 / TASA
local PI, PI2 = math.pi, math.pi * 2
local sin, cos, exp, floor, abs, random, tanh, sqrt = math.sin, math.cos, math.exp, math.floor, math.abs, math.random, math.tanh, math.sqrt

-- ------------------------------------------------------------------------------------------------ utilidades básicas
local function clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end
local function mezcla(a, b, k) return a + (b - a) * k end
local function ruido() return random() * 2 - 1 end

-- Envolventes: 0..1 con ataque y caída exponencial.
local function env(t, ataque, dur, curva)
  if t < 0 then return 0 end
  local a = (ataque > 0 and t < ataque) and (t / ataque) or 1
  local r = 1 - t / dur
  if r <= 0 then return 0 end
  return a * (r ^ (curva or 1.5))
end

-- Campana de amplitud (sube y baja suavemente).
local function campana(t, dur, pico)
  local x = clamp(t / dur, 0, 1)
  pico = pico or 0.35
  if x < pico then return sin(x / pico * PI / 2) end
  return cos((x - pico) / (1 - pico) * PI / 2)
end

-- Ruido rosa (filtro de Paul Kellet): más grave y natural que el blanco.
local function rosa()
  local b0, b1, b2, b3, b4, b5, b6 = 0, 0, 0, 0, 0, 0, 0
  return function()
    local w = ruido()
    b0 = 0.99886 * b0 + w * 0.0555179
    b1 = 0.99332 * b1 + w * 0.0750759
    b2 = 0.96900 * b2 + w * 0.1538520
    b3 = 0.86650 * b3 + w * 0.3104856
    b4 = 0.55000 * b4 + w * 0.5329522
    b5 = -0.7616 * b5 - w * 0.0168980
    local y = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.11
    b6 = w * 0.115926
    return y
  end
end

-- Filtro de variable de estado (paso bajo, paso banda y paso alto a la vez) con frecuencia y resonancia que se pueden mover
-- muestra a muestra. q = 1/Q (menor = más resonante).
local function svf()
  local low, band = 0, 0
  return function(x, fc, q)
    local f = 2 * sin(PI * clamp(fc, 20, 7000) * DT)
    low = low + f * band
    local alto = x - low - (q or 1) * band
    band = f * alto + band
    return low, band, alto
  end
end

-- Oscilador de sierra sin aliasing (PolyBLEP). Devuelve la muestra y la nueva fase.
local function blep(t, dt)
  if t < dt then
    t = t / dt
    return t + t - t * t - 1
  elseif t > 1 - dt then
    t = (t - 1) / dt
    return t * t + t + t + 1
  end
  return 0
end
local function sierra(fase, dt) return 2 * fase - 1 - blep(fase, dt) end
local function cuadrada(fase, dt)
  local v = (fase < 0.5) and 1 or -1
  v = v + blep(fase, dt)
  local f2 = fase + 0.5
  if f2 >= 1 then f2 = f2 - 1 end
  return v - blep(f2, dt)
end
local function avanza(fase, f) fase = fase + f * DT if fase >= 1 then fase = fase - floor(fase) end return fase end

-- ------------------------------------------------------------------------------------------------------ reverb y cierre
-- Reverb de Schroeder: cuatro filtros peine en paralelo con amortiguación y dos pasa-todo. sala = { mezcla, cola (s), amort }.
local function reverberar(buf, sala)
  if not sala or sala.mezcla <= 0 then return buf end
  local cola = sala.cola or 0.5
  local retardos = { 0.0297, 0.0371, 0.0411, 0.0437 }
  local peines = {}
  for i, r in ipairs(retardos) do
    local n = floor(r * TASA * (sala.tam or 1))
    local g = 10 ^ (-3 * n * DT / cola)
    peines[i] = { n = n, g = g, mem = {}, i = 0, lp = 0 }
    for k = 1, n do peines[i].mem[k] = 0 end
  end
  local pasos = {}
  for i, r in ipairs({ 0.005, 0.0017 }) do
    local n = floor(r * TASA)
    pasos[i] = { n = n, mem = {}, i = 0 }
    for k = 1, n do pasos[i].mem[k] = 0 end
  end
  local amort = sala.amort or 0.3
  local largo = #buf
  local extra = floor(cola * 0.8 * TASA)
  local fuera = {}
  local mix = sala.mezcla
  for i = 1, largo + extra do
    local x = buf[i] or 0
    local suma = 0
    for _, p in ipairs(peines) do
      p.i = p.i % p.n + 1
      local y = p.mem[p.i]
      p.lp = y * (1 - amort) + p.lp * amort
      p.mem[p.i] = x + p.lp * p.g
      suma = suma + y
    end
    suma = suma * 0.25
    for _, a in ipairs(pasos) do
      a.i = a.i % a.n + 1
      local y = a.mem[a.i]
      local v = suma + y * 0.5
      a.mem[a.i] = v
      suma = y - suma * 0.5
    end
    fuera[i] = x * (1 - mix * 0.5) + suma * mix
  end
  return fuera
end

-- Cierra un sonido: reverb opcional, normalización al nivel pedido y un limitador suave; devuelve el SoundData.
local function cerrar(buf, opc)
  opc = opc or {}
  buf = reverberar(buf, opc.sala)
  local n = #buf
  local pico = 1e-6
  for i = 1, n do local v = abs(buf[i]) if v > pico then pico = v end end
  local gan = (opc.nivel or 0.8) / pico
  local d = love.sound.newSoundData(n, TASA, 16, 1)
  -- fundido final corto para que no haya clic al cortarse
  local fund = math.min(floor(0.01 * TASA), n)
  for i = 1, n do
    local v = tanh(buf[i] * gan * 1.15) / tanh(1.15)
    if i > n - fund then v = v * ((n - i) / fund) end
    d:setSample(i - 1, v)
  end
  return d
end

-- Genera dur segundos llamando a f(t, i) y devuelve el búfer (sin cerrar).
local function render(dur, f)
  local n = floor(dur * TASA)
  local buf = {}
  for i = 1, n do buf[i] = f((i - 1) * DT, i) end
  return buf
end

-- Suma un búfer al otro desde un instante (en segundos).
local function sumar(dest, orig, t0, ganancia)
  local o = floor(t0 * TASA)
  ganancia = ganancia or 1
  for i = 1, #orig do dest[o + i] = (dest[o + i] or 0) + orig[i] * ganancia end
end

-- ------------------------------------------------------------------------------------------------ instrumentos básicos
-- Campana / metal por síntesis FM con parciales inarmónicos: golpes metálicos, cristales y destellos.
local function campanaFM(f0, dur, brillo, ratios, caida)
  ratios = ratios or { 1, 2.756, 5.404, 8.933 }
  caida = caida or 4
  return render(dur, function(t)
    local v = 0
    for k, r in ipairs(ratios) do
      local a = (1 / k) * exp(-t * caida * (0.6 + 0.4 * k) / dur * 3)
      v = v + sin(PI2 * f0 * r * t + brillo * exp(-t * 18) * sin(PI2 * f0 * 1.41 * t)) * a
    end
    return v * (t < 0.002 and t / 0.002 or 1)
  end)
end

-- Cuerda pulsada (Karplus-Strong): arco, laúd, cuerdas.
local function cuerda(f0, dur, brillo, amort)
  local n = floor(TASA / f0)
  local anillo = {}
  for i = 1, n do anillo[i] = ruido() end
  local lp = 0
  local suave = brillo or 0.5
  return render(dur, function(_, i)
    local idx = (i - 1) % n + 1
    local y = anillo[idx]
    local sig = anillo[idx % n + 1]
    lp = (y + sig) * 0.5 * (amort or 0.996)
    anillo[idx] = lp * (1 - suave * 0.02)
    return y
  end)
end

-- Voz por formantes: fuente glotal (sierra sin aliasing con jitter) más aliento, pasada por tres filtros de banda que
-- representan la boca. fo = { f0 inicial, f0 final }, vocal = { {f1,f2,f3} inicial, {f1,f2,f3} final }.
local function voz(p)
  local dur = p.dur
  local f1a, f1b = svf(), svf()
  local f2a, f2b = svf(), svf()
  local f3a, f3b = svf(), svf()
  local lp = svf()
  local fase, faseSub, fv = 0, 0, 0
  local rs = rosa()
  return render(dur, function(t)
    local u = t / dur
    local f0 = mezcla(p.f0[1], p.f0[2], u ^ (p.curvaF0 or 1))
    f0 = f0 * (1 + (p.vib or 0.02) * sin(PI2 * (p.vibHz or 6) * t) + (p.jitter or 0.01) * ruido())
    fase = avanza(fase, f0)
    local fuente = sierra(fase, f0 * DT)
    if p.sub then faseSub = avanza(faseSub, f0 * 0.5) fuente = fuente + p.sub * cuadrada(faseSub, f0 * 0.5 * DT) end
    -- rugosidad: modulación de amplitud grave
    if p.aspereza then fuente = fuente * (1 - p.aspereza + p.aspereza * (0.5 + 0.5 * sin(PI2 * (p.asperezaHz or 28) * t))) end
    local aire = (p.aire or 0.1) * (p.rosa and rs() * 4 or ruido())
    local x = fuente * (1 - (p.aire or 0.1)) + aire
    local v1, v2, v3 = mezcla(p.vocal[1][1], p.vocal[2][1], u), mezcla(p.vocal[1][2], p.vocal[2][2], u), mezcla(p.vocal[1][3], p.vocal[2][3], u)
    local _, b1 = f1a(x, v1, 0.18)
    local _, b2 = f2a(x, v2, 0.16)
    local _, b3 = f3a(x, v3, 0.2)
    local y = b1 * 1.0 + b2 * 0.6 + b3 * 0.3
    -- cuerpo grave
    local bajo = lp(x, p.cuerpo or 300, 0.9)
    y = y * 1.6 + bajo * (p.graves or 0.5)
    if p.distorsion then y = tanh(y * p.distorsion) end
    return y * env(t, p.ataque or 0.02, dur, p.curva or 1.2) * (p.tremolo and (1 - p.tremolo + p.tremolo * (0.5 + 0.5 * sin(PI2 * 7 * t))) or 1)
  end)
end

-- Ruido filtrado con un barrido de frecuencia (estelas, soplidos, rugidos de fuego).
local function soplido(dur, f0, f1, q, ampl, rosado, alto)
  local fl = svf()
  local gen = rosado and rosa() or ruido
  return render(dur, function(t)
    local u = t / dur
    local fc = mezcla(f0, f1, u)
    local lo, ba, hi = fl(gen() * (rosado and 3 or 1), fc, q)
    local v = alto and hi or ba
    return v * ampl(t, u)
  end)
end

-- ----------------------------------------------------------------------------------------------------------- poderes
local F = {}

-- Corte de espada: soplido con barrido agudo, "shing" metálico y un golpe seco de aire.
function F.corte()
  local dur = 0.3
  local b = soplido(dur, 1200, 6000, 0.7, function(_, u) return campana(u, 1, 0.25) ^ 1.5 * 0.9 end, true, false)
  local metal = campanaFM(2400, 0.28, 2.2, { 1, 2.32, 4.25, 6.63 }, 5)
  sumar(b, metal, 0.05, 0.28)
  local tac = render(0.02, function(t) return ruido() * (1 - t / 0.02) * 0.5 end)
  sumar(b, tac, 0.03, 0.4)
  return cerrar(b, { nivel = 0.8, sala = { mezcla = 0.18, cola = 0.35, tam = 0.7, amort = 0.35 } })
end

-- Estocada / lanza: soplido grave, golpe de punta y un breve tono de madera.
function F.lanza()
  local dur = 0.34
  local b = soplido(dur, 500, 2600, 0.6, function(_, u) return campana(u, 1, 0.3) * 0.8 end, true, false)
  local trueno = render(0.22, function(t) return sin(PI2 * (150 - 90 * t / 0.22) * t) * exp(-t * 22) * 0.9 end)
  sumar(b, trueno, 0.1, 0.8)
  local fl = svf()
  local roce = render(0.12, function(t) local lo = fl(ruido(), 900, 1) return lo * exp(-t * 28) * 1.2 end)
  sumar(b, roce, 0.1, 0.6)
  return cerrar(b, { nivel = 0.8, sala = { mezcla = 0.15, cola = 0.3, tam = 0.6, amort = 0.4 } })
end

-- Grito de guerra: voz humana grave y áspera.
function F.grito()
  local b = voz({ dur = 0.55, f0 = { 210, 150 }, vocal = { { 700, 1100, 2600 }, { 500, 850, 2500 } }, aire = 0.18, aspereza = 0.35, asperezaHz = 40,
    distorsion = 1.8, vib = 0.03, graves = 0.4, ataque = 0.03, curva = 1.0, jitter = 0.02 })
  return cerrar(b, { nivel = 0.8, sala = { mezcla = 0.2, cola = 0.45, tam = 0.9, amort = 0.35 } })
end

-- Conjuro arcano: marea de brillos que sube, con campanas y una nota que se abre.
function F.magia()
  local dur = 0.6
  local b = soplido(dur, 1500, 6500, 0.5, function(_, u) return campana(u, 1, 0.55) * 0.5 end, false, true)
  -- nota de pad que sube (tres sierras desafinadas)
  local f1, f2, f3 = 0, 0, 0
  local fl = svf()
  local pad = render(dur, function(t)
    local u = t / dur
    local f = mezcla(330, 660, u ^ 1.3)
    f1, f2, f3 = avanza(f1, f), avanza(f2, f * 1.007), avanza(f3, f * 0.994)
    local s = sierra(f1, f * DT) + sierra(f2, f * 1.007 * DT) + sierra(f3, f * 0.994 * DT)
    local lo = fl(s, mezcla(700, 3200, u), 0.8)
    return lo * 0.35 * campana(u, 1, 0.5)
  end)
  sumar(b, pad, 0, 0.8)
  sumar(b, campanaFM(1318, 0.5, 1.5, nil, 5), 0.12, 0.16)
  sumar(b, campanaFM(1976, 0.45, 1.2, nil, 5), 0.2, 0.12)
  return cerrar(b, { nivel = 0.75, sala = { mezcla = 0.4, cola = 0.9, tam = 1.1, amort = 0.25 } })
end

-- Fuego: soplido grave que ruge, con chasquidos de brasas.
function F.fuego()
  local dur = 0.65
  local rr = rosa()
  local fl = svf()
  local chasq = 0
  local b = render(dur, function(t)
    local u = t / dur
    local lo = fl(rr() * 4, mezcla(300, 1500, campana(u, 1, 0.35)), 1.1)
    if random() < 0.012 then chasq = 0.9 end
    chasq = chasq * 0.93
    return lo * campana(u, 1, 0.3) * 1.3 + chasq * ruido() * 0.35 * campana(u, 1, 0.5) + sin(PI2 * 62 * t) * 0.12 * campana(u, 1, 0.2)
  end)
  return cerrar(b, { nivel = 0.8, sala = { mezcla = 0.22, cola = 0.5, tam = 0.9, amort = 0.5 } })
end

-- Hielo: campanillas de cristal con un soplo helado.
function F.hielo()
  local b = soplido(0.5, 3500, 6800, 0.6, function(_, u) return campana(u, 1, 0.2) * 0.35 end, false, true)
  local notas = { { 1760, 0 }, { 2349, 0.06 }, { 2794, 0.12 }, { 3520, 0.19 } }
  for _, n in ipairs(notas) do sumar(b, campanaFM(n[1], 0.55, 1.1, { 1, 2.76, 5.4, 8.93 }, 4), n[2], 0.3) end
  sumar(b, campanaFM(880, 0.7, 0.8, { 1, 2.76, 5.4 }, 3), 0, 0.25)
  return cerrar(b, { nivel = 0.75, sala = { mezcla = 0.45, cola = 1.1, tam = 1.2, amort = 0.15 } })
end

-- Flecha: la cuerda del arco al soltarse y el silbido.
function F.flecha()
  local twang = cuerda(196, 0.35, 0.6, 0.994)
  local fl = svf()
  for i = 1, #twang do twang[i] = fl(twang[i], 2200, 1.2) * exp(-(i - 1) * DT * 11) end
  local b = soplido(0.3, 2600, 900, 0.8, function(_, u) return campana(u, 1, 0.2) * 0.55 end, true, false)
  sumar(b, twang, 0, 1.6)
  return cerrar(b, { nivel = 0.8, sala = { mezcla = 0.14, cola = 0.3, tam = 0.6, amort = 0.4 } })
end

-- Cura: un acorde cálido que se abre con brillos de luz, sin arpegios de consola.
function F.cura()
  local dur = 0.9
  local notas = { 392, 494, 587, 784 }
  local fases = { 0, 0, 0, 0, 0, 0, 0, 0 }
  local fl = svf()
  local b = render(dur, function(t)
    local u = t / dur
    local v = 0
    for k, f in ipairs(notas) do
      local ff = f * (1 + 0.002 * sin(PI2 * 4.5 * t + k))
      fases[k * 2 - 1] = avanza(fases[k * 2 - 1], ff)
      fases[k * 2] = avanza(fases[k * 2], ff * 1.004)
      v = v + sierra(fases[k * 2 - 1], ff * DT) + sierra(fases[k * 2], ff * 1.004 * DT)
    end
    local lo = fl(v * 0.14, mezcla(500, 2200, campana(u, 1, 0.45)), 0.9)
    return lo * env(t, 0.12, dur, 1.2)
  end)
  local picos = { { 2349, 0.18 }, { 3136, 0.3 }, { 2637, 0.42 } }
  for _, p in ipairs(picos) do sumar(b, campanaFM(p[1], 0.4, 0.6, { 1, 2.01, 3.99 }, 5), p[2], 0.1) end
  return cerrar(b, { nivel = 0.72, sala = { mezcla = 0.42, cola = 1.0, tam = 1.1, amort = 0.2 } })
end

-- Sagrado: coro de vocales abiertas sobre un acorde, con vibrato y brillo.
function F.sagrado()
  local dur = 0.95
  local b = {}
  for _, par in ipairs({ { 262, 0 }, { 330, 0.01 }, { 392, 0.02 }, { 523, 0.03 } }) do
    local v = voz({ dur = dur, f0 = { par[1], par[1] * 1.01 }, vocal = { { 450, 800, 2830 }, { 800, 1150, 2900 } }, aire = 0.05, vib = 0.012, vibHz = 5.5,
      jitter = 0.004, graves = 0.25, ataque = 0.18, curva = 1.1 })
    sumar(b, v, par[2], 0.7)
  end
  sumar(b, campanaFM(2093, 0.8, 0.5, { 1, 2.01, 3.02 }, 3), 0.1, 0.1)
  return cerrar(b, { nivel = 0.75, sala = { mezcla = 0.5, cola = 1.3, tam = 1.3, amort = 0.25 } })
end

-- Oscuro: subgrave, gruñido y soplo que se abre.
function F.oscuro()
  local dur = 0.7
  local fl = svf()
  local fl2 = svf()
  local fase, fase2 = 0, 0
  local b = render(dur, function(t)
    local u = t / dur
    local f = mezcla(95, 52, u)
    fase, fase2 = avanza(fase, f), avanza(fase2, f * 2.01)
    local s = sierra(fase, f * DT) * 0.7 + cuadrada(fase2, f * 2.01 * DT) * 0.3
    local lo = fl(s, mezcla(500, 120, u), 0.7)
    local sub = sin(PI2 * 48 * t) * 0.6
    local aire = select(2, fl2(ruido(), mezcla(250, 900, campana(u, 1, 0.6)), 0.5))
    local anillo = 0.75 + 0.25 * sin(PI2 * 22 * t)
    return (lo * 1.0 + sub + aire * 0.9) * anillo * env(t, 0.04, dur, 1.0)
  end)
  return cerrar(b, { nivel = 0.85, sala = { mezcla = 0.5, cola = 1.2, tam = 1.3, amort = 0.55 } })
end

-- Muerte del personaje: un golpe sordo y tres notas de cuerda que bajan.
function F.muerte_jugador()
  local dur = 1.5
  local fl = svf()
  local b = render(0.3, function(t) return (fl(ruido(), 220, 1) * 1.2 + sin(PI2 * (90 - 40 * t) * t) * 1.1) * exp(-t * 11) end)
  local notas = { { 220, 0.12 }, { 175, 0.48 }, { 147, 0.84 } }
  for _, n in ipairs(notas) do
    local f0 = n[1]
    local a1, a2, a3 = 0, 0, 0
    local fx = svf()
    local nota = render(0.7, function(t)
      local f = f0 * (1 + 0.006 * sin(PI2 * 5.2 * t))
      a1, a2, a3 = avanza(a1, f), avanza(a2, f * 1.005), avanza(a3, f * 0.995)
      local s = sierra(a1, f * DT) + sierra(a2, f * 1.005 * DT) + sierra(a3, f * 0.995 * DT)
      local lo = fx(s * 0.3, mezcla(1400, 380, t / 0.7), 0.9)
      return lo * env(t, 0.06, 0.7, 1.4)
    end)
    sumar(b, nota, n[2], 0.9)
  end
  return cerrar(b, { nivel = 0.8, sala = { mezcla = 0.45, cola = 1.0, tam = 1.2, amort = 0.35 } })
end

-- --------------------------------------------------------------------------------------------- voces de las criaturas
-- Cada familia tiene tres sonidos: ataque, herido y muerte. Todos se hacen con voz por formantes, soplidos o metales.
local V = {}

local VOCAL = {
  a = { 800, 1150, 2900 }, o = { 450, 800, 2830 }, u = { 325, 700, 2700 }, e = { 400, 1600, 2700 }, i = { 270, 2140, 2950 },
  hueca = { 350, 600, 2400 }, grave = { 500, 850, 2300 },
}

-- bestias: gruñidos de garganta
V.bestia = {
  ataque = function()
    local b = voz({ dur = 0.5, f0 = { 105, 70 }, vocal = { VOCAL.a, VOCAL.o }, aire = 0.28, aspereza = 0.45, asperezaHz = 32, distorsion = 1.6,
      vib = 0.03, graves = 0.5, ataque = 0.04, curva = 1.1, sub = 0.3, jitter = 0.03, rosa = true })
    return cerrar(b, { nivel = 0.8, sala = { mezcla = 0.14, cola = 0.4, tam = 0.8, amort = 0.4 } })
  end,
  herido = function()
    local b = voz({ dur = 0.24, f0 = { 330, 190 }, vocal = { VOCAL.a, VOCAL.e }, aire = 0.12, distorsion = 1.3, vib = 0.04, graves = 0.3,
      ataque = 0.008, curva = 1.6, jitter = 0.02 })
    return cerrar(b, { nivel = 0.75, sala = { mezcla = 0.1, cola = 0.3, tam = 0.6, amort = 0.4 } })
  end,
  muerte = function()
    local b = voz({ dur = 0.9, f0 = { 160, 38 }, vocal = { VOCAL.a, VOCAL.u }, aire = 0.3, aspereza = 0.35, asperezaHz = 20, distorsion = 1.5,
      vib = 0.04, graves = 0.5, ataque = 0.03, curva = 0.9, sub = 0.25, jitter = 0.03, rosa = true })
    return cerrar(b, { nivel = 0.85, sala = { mezcla = 0.2, cola = 0.7, tam = 1.0, amort = 0.4 } })
  end,
}

-- criaturas pequeñas: chillidos nasales
V.pequeno = {
  ataque = function()
    local b = voz({ dur = 0.16, f0 = { 1100, 1700 }, vocal = { VOCAL.i, VOCAL.e }, aire = 0.1, vib = 0.05, vibHz = 14, graves = 0.1, ataque = 0.006,
      curva = 1.8, jitter = 0.02, cuerpo = 900 })
    return cerrar(b, { nivel = 0.7, sala = { mezcla = 0.1, cola = 0.25, tam = 0.5, amort = 0.3 } })
  end,
  herido = function()
    local b = voz({ dur = 0.12, f0 = { 1800, 900 }, vocal = { VOCAL.i, VOCAL.a }, aire = 0.08, vib = 0.03, graves = 0.1, ataque = 0.004, curva = 1.6, cuerpo = 900 })
    return cerrar(b, { nivel = 0.7, sala = { mezcla = 0.1, cola = 0.25, tam = 0.5, amort = 0.3 } })
  end,
  muerte = function()
    local b = voz({ dur = 0.4, f0 = { 1500, 260 }, vocal = { VOCAL.i, VOCAL.o }, aire = 0.12, vib = 0.05, vibHz = 12, graves = 0.15, ataque = 0.005,
      curva = 1.3, jitter = 0.03, cuerpo = 800 })
    return cerrar(b, { nivel = 0.72, sala = { mezcla = 0.15, cola = 0.4, tam = 0.6, amort = 0.3 } })
  end,
}

-- insectos: zumbidos y chasquidos de quitina
V.insecto = {
  ataque = function()
    local fl = svf()
    local fase = 0
    local b = render(0.34, function(t, i)
      local f = mezcla(180, 240, t / 0.34)
      fase = avanza(fase, f)
      local s = sierra(fase, f * DT) * (0.5 + 0.5 * sin(PI2 * 62 * t)) + ruido() * 0.12
      local _, ba = fl(s, mezcla(1200, 2200, t / 0.34), 0.35)
      return ba * 1.6 * env(t, 0.015, 0.34, 1.1)
    end)
    return cerrar(b, { nivel = 0.72, sala = { mezcla = 0.12, cola = 0.3, tam = 0.6, amort = 0.3 } })
  end,
  herido = function()
    local b = voz({ dur = 0.14, f0 = { 900, 420 }, vocal = { VOCAL.e, VOCAL.a }, aire = 0.3, aspereza = 0.5, asperezaHz = 70, graves = 0.1, ataque = 0.004, curva = 1.4, cuerpo = 900 })
    return cerrar(b, { nivel = 0.7, sala = { mezcla = 0.1, cola = 0.25, tam = 0.5, amort = 0.3 } })
  end,
  muerte = function()
    local fl = svf()
    local fase = 0
    local b = render(0.45, function(t)
      local u = t / 0.45
      local f = mezcla(480, 70, u ^ 0.7)
      fase = avanza(fase, f)
      local s = sierra(fase, f * DT) * (0.6 + 0.4 * sin(PI2 * 45 * t)) + ruido() * 0.2 * (1 - u)
      local _, ba = fl(s, mezcla(1800, 500, u), 0.4)
      return ba * 1.5 * env(t, 0.01, 0.45, 1.0)
    end)
    return cerrar(b, { nivel = 0.75, sala = { mezcla = 0.14, cola = 0.35, tam = 0.6, amort = 0.3 } })
  end,
}

-- no muertos: lamentos huecos y aliento
V.no_muerto = {
  ataque = function()
    local b = voz({ dur = 0.6, f0 = { 300, 210 }, vocal = { VOCAL.hueca, VOCAL.u }, aire = 0.55, rosa = true, vib = 0.04, vibHz = 5, graves = 0.3,
      ataque = 0.08, curva = 1.1, tremolo = 0.4, jitter = 0.02 })
    return cerrar(b, { nivel = 0.75, sala = { mezcla = 0.45, cola = 1.1, tam = 1.2, amort = 0.3 } })
  end,
  herido = function()
    local b = voz({ dur = 0.3, f0 = { 400, 280 }, vocal = { VOCAL.u, VOCAL.hueca }, aire = 0.5, rosa = true, vib = 0.05, graves = 0.2, ataque = 0.02, curva = 1.4 })
    return cerrar(b, { nivel = 0.72, sala = { mezcla = 0.4, cola = 0.9, tam = 1.1, amort = 0.3 } })
  end,
  muerte = function()
    local b = voz({ dur = 1.0, f0 = { 360, 55 }, vocal = { VOCAL.o, VOCAL.u }, aire = 0.6, rosa = true, vib = 0.05, vibHz = 4.5, graves = 0.3,
      ataque = 0.06, curva = 0.9, tremolo = 0.5, jitter = 0.03 })
    return cerrar(b, { nivel = 0.78, sala = { mezcla = 0.5, cola = 1.4, tam = 1.3, amort = 0.3 } })
  end,
}

-- demonios: graves distorsionados
V.demonio = {
  ataque = function()
    local b = voz({ dur = 0.5, f0 = { 75, 56 }, vocal = { VOCAL.grave, VOCAL.o }, aire = 0.22, aspereza = 0.5, asperezaHz = 45, distorsion = 3.2,
      vib = 0.03, graves = 0.6, ataque = 0.03, curva = 1.1, sub = 0.5, jitter = 0.04, rosa = true })
    return cerrar(b, { nivel = 0.82, sala = { mezcla = 0.3, cola = 0.8, tam = 1.0, amort = 0.5 } })
  end,
  herido = function()
    local b = voz({ dur = 0.28, f0 = { 150, 92 }, vocal = { VOCAL.a, VOCAL.grave }, aire = 0.2, aspereza = 0.4, distorsion = 2.5, graves = 0.5, ataque = 0.01, curva = 1.5, jitter = 0.03 })
    return cerrar(b, { nivel = 0.78, sala = { mezcla = 0.25, cola = 0.6, tam = 0.9, amort = 0.5 } })
  end,
  muerte = function()
    local b = voz({ dur = 0.95, f0 = { 105, 30 }, vocal = { VOCAL.o, VOCAL.u }, aire = 0.35, aspereza = 0.45, asperezaHz = 25, distorsion = 3, vib = 0.04,
      graves = 0.6, ataque = 0.03, curva = 0.9, sub = 0.5, jitter = 0.04, rosa = true })
    return cerrar(b, { nivel = 0.85, sala = { mezcla = 0.4, cola = 1.2, tam = 1.2, amort = 0.5 } })
  end,
}

-- dragones: rugidos largos con ruido
V.dragon = {
  ataque = function()
    local dur = 0.7
    local r = voz({ dur = dur, f0 = { 95, 58 }, vocal = { VOCAL.a, VOCAL.o }, aire = 0.4, aspereza = 0.4, asperezaHz = 35, distorsion = 2.2, graves = 0.6,
      ataque = 0.06, curva = 1.0, sub = 0.4, jitter = 0.04, rosa = true })
    local aliento = soplido(dur, 350, 1800, 0.7, function(_, u) return campana(u, 1, 0.4) * 0.7 end, true, false)
    sumar(r, aliento, 0, 0.8)
    return cerrar(r, { nivel = 0.85, sala = { mezcla = 0.35, cola = 1.0, tam = 1.1, amort = 0.4 } })
  end,
  herido = function()
    local b = voz({ dur = 0.34, f0 = { 190, 110 }, vocal = { VOCAL.a, VOCAL.o }, aire = 0.3, aspereza = 0.3, distorsion = 2, graves = 0.5, ataque = 0.01, curva = 1.3, rosa = true })
    return cerrar(b, { nivel = 0.8, sala = { mezcla = 0.3, cola = 0.7, tam = 1.0, amort = 0.4 } })
  end,
  muerte = function()
    local dur = 1.1
    local r = voz({ dur = dur, f0 = { 125, 28 }, vocal = { VOCAL.o, VOCAL.u }, aire = 0.45, aspereza = 0.4, asperezaHz = 22, distorsion = 2.4, graves = 0.6,
      ataque = 0.05, curva = 0.8, sub = 0.5, jitter = 0.05, rosa = true })
    local aliento = soplido(dur, 600, 120, 0.8, function(_, u) return campana(u, 1, 0.3) * 0.6 end, true, false)
    sumar(r, aliento, 0, 0.9)
    return cerrar(r, { nivel = 0.88, sala = { mezcla = 0.45, cola = 1.4, tam = 1.3, amort = 0.4 } })
  end,
}

-- constructos y gigantes de piedra: golpes de metal y derrumbes
V.constructo = {
  ataque = function()
    local b = campanaFM(190, 0.4, 3, { 1, 1.59, 2.14, 2.65, 3.16 }, 6)
    local golpe = render(0.12, function(t) return sin(PI2 * (110 - 50 * t / 0.12) * t) * exp(-t * 26) * 1.2 end)
    sumar(b, golpe, 0, 0.9)
    local fl = svf()
    local rozar = render(0.1, function(t) local _, ba = fl(ruido(), 3000, 0.5) return ba * exp(-t * 35) end)
    sumar(b, rozar, 0, 0.8)
    return cerrar(b, { nivel = 0.8, sala = { mezcla = 0.3, cola = 0.6, tam = 1.0, amort = 0.45 } })
  end,
  herido = function()
    local b = campanaFM(420, 0.3, 2.5, { 1, 1.59, 2.14, 2.65 }, 7)
    return cerrar(b, { nivel = 0.7, sala = { mezcla = 0.25, cola = 0.5, tam = 0.9, amort = 0.4 } })
  end,
  muerte = function()
    local fl = svf()
    local rr = rosa()
    local b = render(1.0, function(t)
      local u = t / 1.0
      local lo = fl(rr() * 4, mezcla(1200, 150, u), 1.0)
      local choque = (random() < 0.012 * (1 - u)) and ruido() * 1.2 or 0
      return (lo * 1.2 + choque) * env(t, 0.01, 1.0, 1.1) + sin(PI2 * (70 - 35 * u) * t) * 0.5 * exp(-t * 4)
    end)
    sumar(b, campanaFM(140, 0.5, 2, { 1, 1.59, 2.14, 2.65 }, 5), 0, 0.3)
    return cerrar(b, { nivel = 0.85, sala = { mezcla = 0.35, cola = 1.0, tam = 1.1, amort = 0.45 } })
  end,
}

-- plantas: chasquidos y succiones húmedas
V.planta = {
  ataque = function()
    local snap = soplido(0.2, 4500, 1200, 1.2, function(_, u) return (1 - u) ^ 2.2 * 0.9 end, false, false)
    local fl = svf()
    local chof = render(0.18, function(t)
      local u = t / 0.18
      local _, ba = fl(ruido() + sin(PI2 * mezcla(500, 200, u) * t) * 0.8, mezcla(900, 250, u), 0.3)
      return ba * (1 - u) ^ 1.6 * 0.9
    end)
    sumar(snap, chof, 0.02, 0.8)
    return cerrar(snap, { nivel = 0.75, sala = { mezcla = 0.15, cola = 0.3, tam = 0.6, amort = 0.4 } })
  end,
  herido = function()
    local fl = svf()
    local b = render(0.18, function(t)
      local u = t / 0.18
      local _, ba = fl(ruido(), mezcla(1400, 300, u), 0.25)
      return ba * (1 - u) ^ 1.4 + sin(PI2 * mezcla(520, 240, u) * t) * 0.25 * (1 - u)
    end)
    return cerrar(b, { nivel = 0.72, sala = { mezcla = 0.15, cola = 0.3, tam = 0.6, amort = 0.4 } })
  end,
  muerte = function()
    local fl = svf()
    local b = render(0.6, function(t)
      local u = t / 0.6
      local _, ba = fl(ruido(), mezcla(1500, 120, u ^ 0.6), 0.3)
      return ba * (0.6 + 0.4 * sin(PI2 * 14 * t)) * env(t, 0.01, 0.6, 1.0) * 1.3
    end)
    return cerrar(b, { nivel = 0.75, sala = { mezcla = 0.2, cola = 0.5, tam = 0.7, amort = 0.4 } })
  end,
}

-- humanoides: gruñidos de pecho
V.humanoide = {
  ataque = function()
    local b = voz({ dur = 0.3, f0 = { 170, 125 }, vocal = { VOCAL.a, VOCAL.o }, aire = 0.2, aspereza = 0.2, distorsion = 1.3, vib = 0.03, graves = 0.4,
      ataque = 0.02, curva = 1.3, jitter = 0.03 })
    return cerrar(b, { nivel = 0.78, sala = { mezcla = 0.14, cola = 0.35, tam = 0.7, amort = 0.4 } })
  end,
  herido = function()
    local b = voz({ dur = 0.26, f0 = { 240, 150 }, vocal = { VOCAL.a, VOCAL.e }, aire = 0.15, vib = 0.04, graves = 0.3, ataque = 0.01, curva = 1.5, jitter = 0.03 })
    return cerrar(b, { nivel = 0.75, sala = { mezcla = 0.14, cola = 0.3, tam = 0.6, amort = 0.4 } })
  end,
  muerte = function()
    local b = voz({ dur = 0.7, f0 = { 200, 55 }, vocal = { VOCAL.a, VOCAL.u }, aire = 0.25, aspereza = 0.2, vib = 0.04, graves = 0.4, ataque = 0.02,
      curva = 1.0, jitter = 0.04, rosa = true })
    return cerrar(b, { nivel = 0.8, sala = { mezcla = 0.2, cola = 0.5, tam = 0.8, amort = 0.4 } })
  end,
}

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

S.TASA = TASA
return S
