-- Ambiente gráfico: ciclo de día y noche, luces puntuales, bloom, reflejos en el agua, sombras del sol, clima, atmósfera de mazmorras y
-- postproceso. Todo es del cliente: el mundo se dibuja en un lienzo, se ilumina con un mapa de luz y se compone en pantalla.
-- Calidad (Ajustes.graficos): "alto" (todo), "medio" (sin reflejos ni grano, bloom ligero), "bajo" (solo luz ambiente y puntuales),
-- "apagado" (se dibuja como antes). Si la tarjeta no soporta los shaders se apaga sola.
local Ajustes = require("src.presentacion.ajustes")

local A = {}
local TILE = 32

A.NIVELES = { "alto", "medio", "bajo", "apagado" }
A.fallo = false
A.horaFija = nil          -- las pruebas y las fotos pueden fijar la hora (0-24)
A.climaFijo = nil         -- y el clima
local CICLO_SEG = 48 * 60  -- un día completo dura 48 minutos reales (reloj de pared: todos los jugadores ven la misma hora)

local function calidad()
  if A.fallo then return "apagado" end
  local env = os.getenv("DC_GRAFICOS")
  if env and env ~= "" then return env end
  return Ajustes.graficos or "alto"
end
function A.activo() return calidad() ~= "apagado" end

local function hash(a, b, c)
  local n = (a * 73856093 + b * 19349663 + (c or 0) * 83492791) % 2147483647
  n = (n * 1103515245 + 12345) % 2147483647
  return (n % 10007) / 10007
end

local function mezcla(a, b, t) return a + (b - a) * t end
local function limitar(v, a, b) return math.max(a, math.min(b, v)) end

-- ---------------------------------------------------------------- hora y luz del día
function A.hora()
  if A.horaFija then return A.horaFija end
  local env = os.getenv("DC_HORA")
  if env and tonumber(env) then return tonumber(env) % 24 end
  return (os.time() % CICLO_SEG) / CICLO_SEG * 24
end

-- Color de la luz ambiente según la hora (se multiplica sobre el dibujo). Nunca baja de lo jugable.
local CLAVES = {
  { 0.0, { 0.30, 0.37, 0.62 } }, { 4.5, { 0.32, 0.38, 0.64 } }, { 6.0, { 0.78, 0.60, 0.62 } }, { 7.2, { 1.00, 0.80, 0.66 } },
  { 9.0, { 1.00, 0.97, 0.90 } }, { 12.0, { 1.00, 1.00, 1.00 } }, { 16.5, { 1.00, 0.96, 0.88 } }, { 18.2, { 1.00, 0.74, 0.52 } },
  { 19.5, { 0.62, 0.42, 0.58 } }, { 21.0, { 0.34, 0.38, 0.64 } }, { 24.0, { 0.30, 0.37, 0.62 } },
}

local function colorAmbiente(h)
  for i = 1, #CLAVES - 1 do
    local a, b = CLAVES[i], CLAVES[i + 1]
    if h >= a[1] and h <= b[1] then
      local t = (h - a[1]) / (b[1] - a[1])
      return mezcla(a[2][1], b[2][1], t), mezcla(a[2][2], b[2][2], t), mezcla(a[2][3], b[2][3], t)
    end
  end
  return 1, 1, 1
end

-- 0 de día, 1 de noche cerrada (para saber cuánto pesan las luces puntuales)
local function noche(h)
  if h >= 7.5 and h <= 17.5 then return 0 end
  if h > 17.5 and h < 20.5 then return (h - 17.5) / 3 end
  if h >= 20.5 or h <= 4.5 then return 1 end
  if h > 4.5 and h < 7.5 then return 1 - (h - 4.5) / 3 end
  return 1
end

-- ---------------------------------------------------------------- clima
A.clima = { tipo = "despejado", lluvia = 0, nieve = 0, niebla = 0, nubes = 0, rayo = 0, proxRayo = 6 }

local function climaDe(mapa, jugador)
  if A.climaFijo then return A.climaFijo end
  local env = os.getenv("DC_CLIMA")
  if env and env ~= "" then return env end
  if jugador.modo ~= "mundo" then return "despejado" end
  local slot = math.floor(os.time() / 420)
  local r = hash(slot, math.floor(jugador.x / 120) * 31 + math.floor(jugador.y / 120), 5)
  local sx, sy = math.floor(jugador.x), math.floor(jugador.y)
  local s = mapa.suelo and mapa.suelo[sx] and mapa.suelo[sx][sy]
  local frio = s == "nieve"
  if r < 0.52 then return "despejado" end
  if r < 0.68 then return "nublado" end
  if r < 0.84 then return frio and "nieve" or "lluvia" end
  if r < 0.94 then return "niebla" end
  return frio and "nieve" or "tormenta"
end

local function actualizarClima(dt, mapa, jugador)
  local c = A.clima
  local tipo = climaDe(mapa, jugador)
  c.tipo = tipo
  local meta = {
    lluvia = (tipo == "lluvia" and 1) or (tipo == "tormenta" and 1.3) or 0,
    nieve = tipo == "nieve" and 1 or 0,
    niebla = (tipo == "niebla" and 1) or (tipo == "nieve" and 0.25) or 0,
    nubes = ({ nublado = 0.5, lluvia = 0.75, tormenta = 1, nieve = 0.55, niebla = 0.4 })[tipo] or 0,
  }
  local k = (A.climaFijo or os.getenv("DC_CLIMA")) and 1 or math.min(1, dt * 0.35)
  for clave, v in pairs(meta) do c[clave] = c[clave] + (v - c[clave]) * k end
  if tipo == "tormenta" then
    c.proxRayo = c.proxRayo - dt
    if c.proxRayo <= 0 then c.rayo = 1 c.proxRayo = 5 + love.math.random() * 9 end
  end
  c.rayo = math.max(0, c.rayo - dt * 3.2)
end

-- ---------------------------------------------------------------- recursos
local R = nil   -- canvases y shaders

local SHADER_COMPONER = [[
extern Image luz;
extern Image emis;
extern Image agua;
extern vec2 ventana;
extern vec4 vista;
extern float zoom;
extern float tiempo;
extern float niebla;
extern vec2 cam;
extern float rayo;
extern float reflejos;
extern float modoIso;
float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float ruido(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * ruido(p); p = p * 2.03 + 11.7; a *= 0.5; } return v; }
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec3 base = min(Texel(tex, uv).rgb, vec3(1.0));
  if (reflejos > 0.5) {
    vec4 m = Texel(agua, uv);
    if (m.g > 0.5) {
      float d = m.r * 256.0 * zoom;
      float prof = clamp(d / (7.0 * 32.0 * zoom), 0.0, 1.0);
      if (modoIso > 0.5) {
        // isométrico: la distancia hasta la orilla se mide hacia arriba en la pantalla, hasta salir del agua
        d = 0.0;
        for (int i = 1; i < 60; i++) {
          float paso = float(i) * 3.0;
          d = paso;
          if (Texel(agua, vec2(uv.x, uv.y - paso / ventana.y)).g < 0.5) break;
        }
        prof = clamp(d / (80.0 * zoom), 0.0, 1.0);
      }
      float rip = fbm(vec2(uv.x * ventana.x / (46.0 * zoom), uv.y * ventana.y / (8.0 * zoom) + tiempo * 0.7)) - 0.5;
      vec2 r = vec2(uv.x + rip * 0.010 * (0.4 + prof), uv.y - 2.0 * d / ventana.y + rip * 0.006);
      r = clamp(r, vista.xy + vec2(0.002), vista.xy + vista.zw - vec2(0.002));
      vec3 refl = min(Texel(tex, r).rgb, vec3(1.0)) * vec3(0.70, 0.86, 1.0);
      base = mix(base, refl, 0.42 * (1.0 - prof * 0.8));
      base += vec3(0.5, 0.6, 0.7) * smoothstep(0.15, 0.4, rip) * 0.07;
    }
  }
  vec3 L = Texel(luz, uv).rgb;
  vec3 col = base * L + Texel(emis, uv).rgb;
  if (niebla > 0.01) {
    float n = fbm((uv * ventana + cam * 0.35) / (260.0 * zoom) + vec2(tiempo * 0.015, 0.0));
    vec3 fc = vec3(0.72, 0.76, 0.82) * clamp(dot(L, vec3(0.34)), 0.18, 1.0);
    col = mix(col, fc, clamp(niebla * (0.12 + 0.34 * n), 0.0, 0.6));
  }
  col += vec3(0.55, 0.6, 0.8) * rayo;
  return vec4(col, 1.0);
}
]]

local SHADER_BRILLO = [[
extern float umbral;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec3 c = Texel(tex, uv).rgb;
  float l = max(c.r, max(c.g, c.b));
  return vec4(c * smoothstep(umbral, umbral + 1.1, l), 1.0);
}
]]

local SHADER_BLUR = [[
extern vec2 dir;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec3 s = Texel(tex, uv).rgb * 0.2270270270;
  s += Texel(tex, uv + dir * 1.3846153846).rgb * 0.3162162162;
  s += Texel(tex, uv - dir * 1.3846153846).rgb * 0.3162162162;
  s += Texel(tex, uv + dir * 3.2307692308).rgb * 0.0702702703;
  s += Texel(tex, uv - dir * 3.2307692308).rgb * 0.0702702703;
  return vec4(s, 1.0);
}
]]

local SHADER_FINAL = [[
extern Image bloom;
extern vec2 ventana;
extern vec4 vista;
extern vec3 grado;
extern float fuerzaBloom;
extern float vineta;
extern float grano;
extern float tiempo;
extern float desatura;
float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
vec3 suave(vec3 x) {
  vec3 e = max(x - 0.82, 0.0);
  return min(x, 0.82) + e / (1.0 + e * 1.6);
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec3 col = Texel(tex, uv).rgb + Texel(bloom, uv).rgb * fuerzaBloom;
  col = suave(col);
  float l = dot(col, vec3(0.299, 0.587, 0.114));
  col = mix(col, vec3(l), desatura);
  col *= grado;
  vec2 q = (uv - vista.xy) / vista.zw - 0.5;
  col *= 1.0 - vineta * smoothstep(0.25, 0.95, length(q * vec2(1.15, 1.0)));
  col += (hash(uv * ventana + tiempo) - 0.5) * grano;
  return vec4(col, 1.0);
}
]]

local LUZ_IMG = nil

local function imagenLuz()
  if LUZ_IMG then return LUZ_IMG end
  local d = love.image.newImageData(128, 128)
  d:mapPixel(function(x, y)
    local dx, dy = (x + 0.5) / 64 - 1, (y + 0.5) / 64 - 1
    local k = math.max(0, 1 - math.sqrt(dx * dx + dy * dy))
    return 1, 1, 1, k * k * (3 - 2 * k)
  end)
  LUZ_IMG = love.graphics.newImage(d)
  LUZ_IMG:setFilter("linear", "linear")
  return LUZ_IMG
end

local function formato16()
  local f = love.graphics.getCanvasFormats and love.graphics.getCanvasFormats() or {}
  return f["rgba16f"] and "rgba16f" or "rgba8"
end

local function crearLienzo(w, h, formato)
  local c = love.graphics.newCanvas(math.max(1, w), math.max(1, h), { format = formato })
  c:setFilter("linear", "linear")
  return c
end

local function asegurar(w, h)
  if R and R.w == w and R.h == h then return true end
  local ok, err = pcall(function()
    local f = formato16()
    local nuevo = {
      w = w, h = h,
      esc = crearLienzo(w, h, f),
      lit = crearLienzo(w, h, f),
      luz = crearLienzo(math.floor(w / 2), math.floor(h / 2), f),
      emi = crearLienzo(math.floor(w / 2), math.floor(h / 2), f),
      agua = crearLienzo(math.floor(w / 2), math.floor(h / 2), "rgba8"),
      b1 = crearLienzo(math.floor(w / 4), math.floor(h / 4), f),
      b2 = crearLienzo(math.floor(w / 4), math.floor(h / 4), f),
    }
    nuevo.esc:setFilter("nearest", "nearest")
    if R then
      for _, k in ipairs({ "esc", "lit", "luz", "emi", "agua", "b1", "b2" }) do if R[k] then R[k]:release() end end
      nuevo.sComponer, nuevo.sBrillo, nuevo.sBlur, nuevo.sFinal = R.sComponer, R.sBrillo, R.sBlur, R.sFinal
    else
      nuevo.sComponer = love.graphics.newShader(SHADER_COMPONER)
      nuevo.sBrillo = love.graphics.newShader(SHADER_BRILLO)
      nuevo.sBlur = love.graphics.newShader(SHADER_BLUR)
      nuevo.sFinal = love.graphics.newShader(SHADER_FINAL)
    end
    R = nuevo
  end)
  if not ok then
    A.fallo = true
    R = nil
    require("compartido.infraestructura.log").info("ambiente gráfico apagado: " .. tostring(err))
    return false
  end
  return true
end

-- ---------------------------------------------------------------- estado de cada cuadro
local E = {}   -- lo que se calcula al empezar y se usa al terminar

function A.empezar(vx, vy, vw, vh)
  if not A.activo() then return false end
  local w, h = love.graphics.getDimensions()
  if not asegurar(w, h) then return false end
  E.vx, E.vy, E.vw, E.vh = vx, vy, vw, vh
  E.prev = { love.graphics.getCanvas() }
  love.graphics.setCanvas(R.esc)
  love.graphics.clear(0, 0, 0, 1)
  return true
end

-- Calor/frío y color por zona: se suaviza para que el cambio de bioma no sea brusco.
local gradoActual = { 1, 1, 1 }

local function gradoDeZona(mapa, jugador, mundo)
  local r, g, b = 1, 1, 1
  if jugador.modo == "mundo" then
    local sx, sy = math.floor(jugador.x), math.floor(jugador.y)
    local s = mapa.suelo and mapa.suelo[sx] and mapa.suelo[sx][sy]
    local lado = mapa.lado and mapa.lado[sx] and mapa.lado[sx][sy]
    if s == "nieve" then r, g, b = 0.94, 1.0, 1.08
    elseif s == "pantano" then r, g, b = 0.93, 1.03, 0.92
    elseif s == "arena" then r, g, b = 1.05, 1.0, 0.92
    elseif s == "roca" then r, g, b = 0.98, 0.98, 1.03
    elseif lado == "umbra" then r, g, b = 0.97, 0.95, 1.05 end
  elseif mapa.tinte then
    local t = mapa.tinte
    r, g, b = mezcla(1, t[1], 0.5), mezcla(1, t[2], 0.5), mezcla(1, t[3], 0.5)
  end
  return r, g, b
end

-- Luz de cada efecto de poder: color e intensidad.
local LUZ_EFECTO = {
  fuego = { 1.0, 0.55, 0.2, 1.3 }, meteoro = { 1.0, 0.5, 0.15, 1.6 }, nova = { 0.6, 0.8, 1.0, 1.2 }, misil = { 0.55, 0.75, 1.0, 1.0 },
  curar = { 0.5, 1.0, 0.65, 1.0 }, sanacion = { 0.5, 1.0, 0.65, 1.2 }, bendicion = { 1.0, 0.92, 0.55, 1.0 }, castigo = { 1.0, 0.9, 0.5, 1.2 },
  consagrar = { 1.0, 0.9, 0.5, 1.1 }, golpe = { 1.0, 0.9, 0.7, 0.8 }, tajo = { 1.0, 0.85, 0.7, 0.7 }, furia = { 1.0, 0.4, 0.3, 1.0 },
  sombra = { 0.6, 0.35, 0.9, 0.9 }, rayo = { 0.7, 0.85, 1.0, 1.4 }, disparo = { 1.0, 0.95, 0.7, 0.7 },
}
local LUZ_PROYECTIL = {
  misil = { 0.55, 0.78, 1.0, 1.1 }, fuego = { 1.0, 0.55, 0.2, 1.2 }, sagrado = { 1.0, 0.95, 0.55, 1.1 }, necro = { 0.55, 1.0, 0.6, 0.9 },
  sombra = { 0.62, 0.38, 0.95, 0.9 },
}

local Casas = require("src.presentacion.render.casas")
local CasasIso = require("src.presentacion.render.casas_iso")
local Iso = require("src.presentacion.render.iso")
local antorchasVisibles, dibujarRayos   -- (se definen más abajo)

-- Recoge las luces visibles. Cada una: x, y (casillas), r (radio en casillas), color, intensidad, emisivo (círculo brillante opcional).
local function recogerLuces(mundo, jugador, mapa, cam, radio, nocheV, dentroCasa, enMazmorra)
  local luces, emis = {}, {}
  local t = love.timer.getTime()
  local function luz(x, y, r, cr, cg, cb, k, alt) luces[#luces + 1] = { x, y, r, cr, cg, cb, k, alt or 0 } end
  local peso = 0.10 + 0.90 * nocheV
  if enMazmorra then peso = 1 end
  -- el jugador lleva una luz cálida: más fuerte donde hace falta
  local fuerza = dentroCasa and 0.35 or (enMazmorra and 1.15 or peso * 0.75)
  local alcance = enMazmorra and 6.5 or (dentroCasa and 4.0 or 4.8)
  luz(jugador.x, jugador.y, alcance, 1.0, 0.82, 0.5, fuerza, 10)
  if jugador.modo == "casa" then
    -- la casa tiene su lámpara sobre la mesa y la luz de sus ventanas del fondo
    local ms = mapa.muebles and mapa.muebles.mesa
    if ms then luz(ms.x, ms.y, 7.5, 1.0, 0.82, 0.55, 0.55, 13) end
    local w = mapa.w or 22
    for _, vxx in ipairs({ 5, w - 6 }) do luz(vxx + 0.5, 3.2, 5.5, 0.85, 0.92, 1.0, 0.45) end
  end
  if jugador.modo ~= "casa" then
    -- faroles y luces de las casas
    for _, prop in ipairs(mapa.props or {}) do
      if math.abs(prop.x - jugador.x) < radio and math.abs(prop.y - jugador.y) < radio then
        local tp = prop.tipo
        if tp == "farol" then
          local f = 0.93 + 0.07 * math.sin(t * 2.3 + prop.x)
          luz(prop.x + 0.5, prop.y + 0.5, 6.0, 1.0, 0.82, 0.45, 0.95 * peso * f, 38)
          emis[#emis + 1] = { prop.x + 0.5, prop.y + 0.5, 0.16, 1.4 * nocheV + 0.15, 1.0, 0.8, 0.45, false, 38 }
        elseif tp == "antorcha" or tp == "brasero" or tp == "hoguera" then
          local f = 0.85 + 0.15 * math.sin(t * 9 + prop.x * 3)
          luz(prop.x + 0.5, prop.y + 0.5, 5.5, 1.0, 0.6, 0.25, 1.1 * f, 8)
          emis[#emis + 1] = { prop.x + 0.5, prop.y + 0.5, 0.2, 1.5, 1.0, 0.65, 0.25, false, 10 }
        elseif tp == "estatua_albor" then
          luz(prop.x + 0.5, prop.y + 0.5, 3.2, 1.0, 0.92, 0.6, 0.35 * peso, 20)
        elseif tp == "estatua_umbra" then
          luz(prop.x + 0.5, prop.y + 0.5, 3.2, 0.7, 0.5, 1.0, 0.45 * peso, 20)
        end
      end
    end
    if jugador.modo == "mundo" and (jugador.z or 0) == 0 and not CasasIso.activo() then
      for _, e in ipairs(mapa.edificios or {}) do
        if math.abs(e.x + e.w / 2 - jugador.x) < radio + 3 and math.abs(e.y + e.h / 2 - jugador.y) < radio + 3 then
          if nocheV > 0.15 then
            for i, v in ipairs(Casas.ventanasPos(e)) do
              local f = 0.88 + 0.12 * math.sin(t * 2.7 + e.x * 1.7 + i)
              luz(v.x, v.y, 3.0, 1.0, 0.72, 0.36, 0.5 * nocheV * f)
              emis[#emis + 1] = { v.x, v.y - 0.02, 0.32, 1.1 * nocheV * f, 1.0, 0.72, 0.32, true }
            end
          end
          local fx, fy = Casas.farolPos(e)
          if fx then
            luz(fx, fy, 2.6, 1.0, 0.8, 0.42, 0.55 * peso)
            emis[#emis + 1] = { fx, fy, 0.13, 1.4 * nocheV + 0.15, 1.0, 0.82, 0.4 }
          end
        end
      end
    end
  end
  -- criaturas, cristales y otros que brillan
  for _, e in pairs(mundo.entidades) do
    if e.vivo ~= false and mundo:mismoLugar(jugador, e) and math.abs(e.x - jugador.x) < radio and math.abs(e.y - jugador.y) < radio then
      if e.kind == "altar" then
        local c = e.faccion == "umbra" and { 0.65, 0.4, 1.0 } or { 1.0, 0.85, 0.45 }
        luz(e.x, e.y, 3.6, c[1], c[2], c[3], 0.9, 14)
      elseif e.kind == "puerta" and e.tipo == "puerta_mazmorra" then
        luz(e.x, e.y, 3.2, 0.7, 0.45, 1.0, 0.9)
      elseif (e.kind == "jugador" or e.kind == "bot") and e.id ~= jugador.id and not dentroCasa then
        luz(e.x, e.y, 2.8, 1.0, 0.85, 0.55, 0.45 * peso, 8)
      elseif e.kind == "monstruo" and (e.elite or e.jefe or e.jefeMz) then
        luz(e.x, e.y, 3.0, 1.0, 0.45, 0.35, 0.55, 10)
      elseif e.kind == "cofre_mz" then
        luz(e.x, e.y, 3.2, 1.0, 0.85, 0.35, 0.9 + 0.1 * math.sin(t * 4), 10)
      end
    end
  end
  -- hechizos en el aire
  for _, fx in ipairs(mundo.efectos or {}) do
    local def = LUZ_EFECTO[fx.tipo]
    if def and math.abs(fx.x - jugador.x) < radio and math.abs(fx.y - jugador.y) < radio then
      local v = 1 - math.abs((fx.t or 0) / math.max(0.01, fx.dur or 0.4) * 2 - 1) * 0.6
      luz(fx.x, fx.y, 2.0, def[1], def[2], def[3], def[4] * v * 0.28 * (enMazmorra and 0.7 or (0.02 + 0.35 * nocheV)), 10)
    end
  end
  for _, e in pairs(mundo.entidades) do
    if e.kind == "proyectil" and mundo:mismoLugar(jugador, e) then
      local def = LUZ_PROYECTIL[e.tipo]
      if def then luz(e.x, e.y, 1.9, def[1], def[2], def[3], def[4] * 0.3 * (enMazmorra and 0.7 or (0.02 + 0.35 * nocheV)), 10) end
    end
  end
  -- chispas que salen de los hechizos y estelas de los proyectiles (brillan y entran al bloom)
  for _, fx in ipairs(mundo.efectos or {}) do
    local def = LUZ_EFECTO[fx.tipo]
    if def and math.abs(fx.x - jugador.x) < radio and math.abs(fx.y - jugador.y) < radio then
      local u = limitar((fx.t or 0) / math.max(0.01, fx.dur or 0.4), 0, 1)
      for i = 1, 7 do
        local ang = hash(math.floor(fx.x * 13), math.floor(fx.y * 17), i) * math.pi * 2
        local dist = u * (0.35 + 0.8 * hash(i, 5, 9))
        local px, py = fx.x + math.cos(ang) * dist, fx.y + math.sin(ang) * dist * 0.8
        emis[#emis + 1] = { px, py, 0.035, (1 - u) * 0.7, def[1], def[2], def[3], false, 10 + u * 16 }
      end
    end
  end
  for _, e in pairs(mundo.entidades) do
    if e.kind == "proyectil" and mundo:mismoLugar(jugador, e) then
      local def = LUZ_PROYECTIL[e.tipo]
      if def then
        local ang = math.atan2((e.ty or e.y) - e.y, (e.tx or e.x) - e.x)
        for i = 1, 6 do
          local d = i * 0.17
          emis[#emis + 1] = { e.x - math.cos(ang) * d + (hash(i, math.floor(t * 20), 4) - 0.5) * 0.12, e.y - math.sin(ang) * d + (hash(i, math.floor(t * 20), 5) - 0.5) * 0.12,
            0.05 * (1 - i / 8), (1 - i / 7) * 0.8, def[1], def[2], def[3], false, 10 }
        end
      end
    end
  end
  if enMazmorra then
    for _, a in ipairs(antorchasVisibles(mapa, cam, E.vw, E.vh, cam.zoom)) do
      local f = 0.85 + 0.15 * math.sin(t * 11 + a.x * 3)
      luz(a.x, a.y, 6.2, 1.0, 0.58, 0.25, 1.05 * f, 14)
      emis[#emis + 1] = { a.x, a.y, 0.18, 1.7 * f, 1.0, 0.6, 0.25, false, 17 }
    end
  end
  return luces, emis
end

local function dibujarLuces(luces, cam, z, escala)
  local img = imagenLuz()
  love.graphics.setBlendMode("add")
  local n = math.min(#luces, 140)
  local iso = Iso.activo()
  for i = 1, n do
    local l = luces[i]
    local gx, gy = Iso.suelo(l[1], l[2])
    local sx = (E.vx + (gx - cam.x) * z) * escala
    local sy = (E.vy + (gy - (l[8] or 0) - cam.y) * z) * escala
    -- un círculo en el suelo se ve como una elipse de 2:1 en la vista isométrica
    local rx = l[3] * (iso and Iso.HW * 1.414 or TILE) * z * escala
    local ry = iso and (l[3] * Iso.HH * 1.414 * z * escala) or rx
    love.graphics.setColor(l[4], l[5], l[6], l[7])
    love.graphics.draw(img, sx - rx, sy - ry, 0, rx * 2 / 128, ry * 2 / 128)
  end
  love.graphics.setBlendMode("alpha")
end

local function dibujarEmisivos(emis, cam, z, escala)
  local img = imagenLuz()
  love.graphics.setBlendMode("add")
  for _, m in ipairs(emis) do
    local gx, gy = Iso.suelo(m[1], m[2])
    local sx = (E.vx + (gx - cam.x) * z) * escala
    local sy = (E.vy + (gy - (m[9] or 0) - cam.y) * z) * escala
    local rpx = m[3] * TILE * z * escala
    love.graphics.setColor(m[5] * m[4], m[6] * m[4], m[7] * m[4], 1)
    if m[8] then
      -- cristal de ventana: rectángulo con brillo
      love.graphics.rectangle("fill", sx - rpx * 0.55, sy - rpx * 0.6, rpx * 1.1, rpx * 1.2)
    else
      love.graphics.draw(img, sx - rpx * 2, sy - rpx * 2, 0, rpx * 4 / 128, rpx * 4 / 128)
    end
  end
  love.graphics.setBlendMode("alpha")
end

-- Máscara del agua: por cada casilla de agua, cuántos píxeles hay hasta la orilla de arriba (para reflejar).
local function dibujarAgua(mapa, cam, z, escala)
  if Iso.activo() then
    -- isométrico: cada casilla de agua es un rombo blanco en la máscara (el shader mide hacia arriba hasta la orilla)
    local suelo = mapa.suelo
    if not suelo then return end
    local x0, y0, x1, y1 = Iso.rango(cam.x, cam.y, E.vw / z, E.vh / z, 1)
    love.graphics.setColor(0, 1, 0, 1)
    for tx = x0, x1 do
      local col = suelo[tx]
      if col then
        for ty = y0, y1 do
          if col[ty] == "agua" then
            local function p(ax, ay)
              local gx, gy = Iso.suelo(ax, ay)
              return (E.vx + (gx - cam.x) * z) * escala, (E.vy + (gy - cam.y) * z) * escala
            end
            local ax, ay = p(tx, ty)
            local bx, by = p(tx + 1, ty)
            local cx, cy = p(tx + 1, ty + 1)
            local dx, dy = p(tx, ty + 1)
            love.graphics.polygon("fill", ax, ay, bx, by, cx, cy, dx, dy)
          end
        end
      end
    end
    return
  end
  local x0, y0 = math.floor(cam.x / TILE), math.floor(cam.y / TILE)
  local x1, y1 = math.floor((cam.x + E.vw / z) / TILE), math.floor((cam.y + E.vh / z) / TILE)
  local suelo = mapa.suelo
  if not suelo then return end
  local function esAgua(x, y) return suelo[x] and suelo[x][y] == "agua" end
  local verts, n = {}, 0
  for tx = x0, x1 do
    for ty = y0, y1 do
      if esAgua(tx, ty) then
        local k = 0
        while k < 7 and esAgua(tx, ty - k - 1) do k = k + 1 end
        local rA, rB = k * TILE / 256, (k + 1) * TILE / 256
        local sx = (E.vx + (tx * TILE - cam.x) * z) * escala
        local sy = (E.vy + (ty * TILE - cam.y) * z) * escala
        local s = TILE * z * escala
        verts[n + 1] = { sx, sy, 0, 0, rA, 1, 0, 1 }
        verts[n + 2] = { sx + s, sy, 0, 0, rA, 1, 0, 1 }
        verts[n + 3] = { sx + s, sy + s, 0, 0, rB, 1, 0, 1 }
        verts[n + 4] = { sx, sy, 0, 0, rA, 1, 0, 1 }
        verts[n + 5] = { sx + s, sy + s, 0, 0, rB, 1, 0, 1 }
        verts[n + 6] = { sx, sy + s, 0, 0, rB, 1, 0, 1 }
        n = n + 6
      end
    end
  end
  if n > 0 then
    local malla = love.graphics.newMesh(verts, "triangles", "stream")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(malla)
    malla:release()
  end
end

-- Lluvia, nieve y motas de polvo (se dibujan en el lienzo del mundo, así también las ilumina la luz).
local function dibujarParticulas(cam, z, mapa, jugador, enMazmorra, dentroCasa, cal)
  local c = A.clima
  local t = love.timer.getTime()
  local vx, vy, vw, vh = E.vx, E.vy, E.vw, E.vh
  local factor = cal == "alto" and 1 or (cal == "medio" and 0.55 or 0.3)
  love.graphics.setScissor(vx, vy, vw, vh)
  if not enMazmorra and not dentroCasa then
    if c.lluvia > 0.05 then
      local n = math.floor(320 * c.lluvia * factor)
      love.graphics.setLineWidth(math.max(1, z * 0.9))
      for i = 1, n do
        local hx, hy, hv = (i * 0.61803) % 1, (i * 0.75487) % 1, hash(i, 3, 1)
        local x = vx + ((hx * vw * 1.4 + t * 150) % (vw * 1.4)) - vw * 0.2
        local y = vy + ((hy * vh + t * (900 + 380 * hv)) % vh)
        love.graphics.setColor(0.75, 0.84, 1.0, (0.32 + 0.35 * hv) * math.min(1, c.lluvia))
        love.graphics.line(x, y, x - 7 * z, y - 20 * z)
      end
      love.graphics.setLineWidth(1)
    end
    if c.nieve > 0.05 then
      local n = math.floor(260 * c.nieve * factor)
      for i = 1, n do
        local hx, hy, hv = (i * 0.61803) % 1, (i * 0.75487) % 1, hash(i, 4, 2)
        local x = vx + (hx * vw + math.sin(t * (0.6 + hv) + i) * 24 * z) % vw
        local y = vy + ((hy * vh + t * (55 + 55 * hv) * z) % vh)
        love.graphics.setColor(1, 1, 1, 0.55 + 0.4 * hv)
        love.graphics.circle("fill", x, y, (1.1 + 1.5 * hv) * z * 0.8)
      end
    end
  end
  if enMazmorra then
    local n = math.floor(70 * factor)
    for i = 1, n do
      local hx, hy, hv = (i * 0.61803) % 1, (i * 0.75487) % 1, hash(i, 6, 3)
      local x = vx + (hx * vw + t * (6 + 8 * hv) * z) % vw
      local y = vy + (hy * vh + math.sin(t * 0.4 + i) * 20 * z) % vh
      love.graphics.setColor(0.85, 0.85, 1.0, 0.10 + 0.14 * hv)
      love.graphics.circle("fill", x, y, (0.8 + 1.1 * hv) * z)
    end
  end
  love.graphics.setScissor()
end

local function desenfocar(origen, destino, shader, dx, dy)
  love.graphics.setCanvas(destino)
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setShader(shader)
  shader:send("dir", { dx, dy })
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(origen, 0, 0, 0, destino:getWidth() / origen:getWidth(), destino:getHeight() / origen:getHeight())
  love.graphics.setShader()
end

-- Compone el mundo ya dibujado: luz, reflejos, niebla, bloom, gradación y viñeta, y lo pinta en pantalla dentro de la vista.
function A.terminar(mundo, jugador, mapa, cam)
  local cal = calidad()
  local z = cam.zoom
  local w, h = R.w, R.h
  local dt = math.min(0.1, love.timer.getDelta())
  local hora = A.hora()
  local nocheV = noche(hora)
  local enMazmorra = mundo:enMazmorra(jugador) ~= nil
  local dentroCasa = jugador.modo == "casa"
  actualizarClima(dt, mapa, jugador)
  local clima = A.clima
  local t = love.timer.getTime()
  local radio = Iso.radio(E.vw / z, E.vh / z) + 1

  -- partículas del clima en el lienzo del mundo
  dibujarParticulas(cam, z, mapa, jugador, enMazmorra, dentroCasa, cal)
  love.graphics.setCanvas()

  -- luz ambiente
  local ar, ag, ab
  if enMazmorra then
    local tn = mapa.tinte or { 1, 1, 1 }
    ar, ag, ab = 0.24 + 0.1 * tn[1], 0.25 + 0.1 * tn[2], 0.34 + 0.1 * tn[3]
    nocheV = 1
  elseif dentroCasa then
    ar, ag, ab = 0.86, 0.85, 0.84
    nocheV = math.max(0.35, nocheV)
  else
    ar, ag, ab = colorAmbiente(hora)
    local oscuro = 1 - 0.22 * clima.nubes
    ar, ag, ab = ar * oscuro, ag * oscuro, ab * (1 - 0.14 * clima.nubes)
  end
  local luces, emis = recogerLuces(mundo, jugador, mapa, cam, radio, nocheV, dentroCasa, enMazmorra)

  -- mapa de luz (mitad de resolución)
  love.graphics.setCanvas(R.luz)
  love.graphics.clear(ar, ag, ab, 1)
  love.graphics.setScissor()
  dibujarLuces(luces, cam, z, 0.5)
  love.graphics.setCanvas(R.emi)
  love.graphics.clear(0, 0, 0, 1)
  dibujarEmisivos(emis, cam, z, 0.5)
  local conReflejos = cal == "alto" and not os.getenv("DC_SIN_REFLEJO") and jugador.modo == "mundo" and (jugador.z or 0) == 0
  if conReflejos then
    love.graphics.setCanvas(R.agua)
    love.graphics.clear(0, 0, 0, 0)
    dibujarAgua(mapa, cam, z, 0.5)
  end
  love.graphics.setCanvas()

  -- 1) mundo * luz + reflejos + niebla -> lit
  local sc = R.sComponer
  sc:send("luz", R.luz)
  sc:send("emis", R.emi)
  sc:send("agua", R.agua)
  sc:send("ventana", { w, h })
  sc:send("vista", { E.vx / w, E.vy / h, E.vw / w, E.vh / h })
  sc:send("zoom", z)
  sc:send("tiempo", t)
  sc:send("niebla", clima.niebla)
  sc:send("cam", { cam.x, cam.y })
  sc:send("rayo", clima.rayo)
  sc:send("reflejos", conReflejos and 1 or 0)
  sc:send("modoIso", Iso.activo() and 1 or 0)
  love.graphics.setCanvas(R.lit)
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setShader(sc)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(R.esc, 0, 0)
  love.graphics.setShader()

  -- rayos de sol sobre la imagen ya iluminada (se suman: también alimentan el bloom)
  if cal ~= "bajo" then
    love.graphics.setCanvas(R.lit)
    dibujarRayos(cam, jugador, cal)
  end
  -- 2) bloom
  local fuerzaBloom = 0
  if cal ~= "bajo" then
    fuerzaBloom = (cal == "alto" and 0.28 or 0.2) * (0.45 + 0.55 * nocheV)
    R.sBrillo:send("umbral", 1.05)
    love.graphics.setCanvas(R.b1)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setShader(R.sBrillo)
    love.graphics.draw(R.lit, 0, 0, 0, R.b1:getWidth() / w, R.b1:getHeight() / h)
    love.graphics.setShader()
    local pasadas = cal == "alto" and 3 or 1
    for _ = 1, pasadas do
      desenfocar(R.b1, R.b2, R.sBlur, 1 / R.b2:getWidth(), 0)
      desenfocar(R.b2, R.b1, R.sBlur, 0, 1 / R.b1:getHeight())
    end
  end
  love.graphics.setCanvas()

  -- 3) gradación y salida a pantalla
  local gr, gg, gb = gradoDeZona(mapa, jugador, mundo)
  local k = math.min(1, dt * 1.5)
  gradoActual[1], gradoActual[2], gradoActual[3] = gradoActual[1] + (gr - gradoActual[1]) * k, gradoActual[2] + (gg - gradoActual[2]) * k, gradoActual[3] + (gb - gradoActual[3]) * k
  local sf = R.sFinal
  sf:send("bloom", R.b1)
  sf:send("ventana", { w, h })
  sf:send("vista", { E.vx / w, E.vy / h, E.vw / w, E.vh / h })
  sf:send("grado", gradoActual)
  sf:send("fuerzaBloom", fuerzaBloom)
  sf:send("vineta", cal == "bajo" and 0.12 or 0.28)
  sf:send("grano", cal == "alto" and 0.018 or 0)
  sf:send("tiempo", t)
  sf:send("desatura", 0.10 * clima.nubes + 0.06 * clima.lluvia)
  love.graphics.setScissor(E.vx, E.vy, E.vw, E.vh)
  love.graphics.setShader(sf)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(R.lit, 0, 0)
  love.graphics.setShader()
  love.graphics.setScissor()
  if E.prev and E.prev[1] then love.graphics.setCanvas(E.prev[1]) end
  E.sol = nil
end

-- ---------------------------------------------------------------- sombras del sol (y de la luna, más tenues)
-- Se dibujan en el suelo, antes de lo que se mueve: una mancha alargada hacia el lado contrario a la luz. Cubren árboles, faroles y
-- estatuas, casas y edificios, y a todos los que caminan.
local ALTURA_PROP = { arbol_pino = 3.2, arbol = 3.0, arbol_robusto = 3.0, farol = 2.4, estatua_albor = 2.6, estatua_umbra = 2.6, pozo = 1.2, barril = 0.9 }

-- Dirección y largo de la sombra según la hora. nil si no hay luz suficiente para sombras.
local function luzSolar()
  local h = A.hora()
  local dia = h >= 6 and h <= 18
  local fase = dia and (h - 6) / 12 or ((h - 18) % 24) / 12
  local altura = math.sin(fase * math.pi)
  if altura < 0.08 then return nil end
  local alfa = (dia and 0.30 or 0.13) * math.min(1, altura * 2.2) * (1 - 0.7 * A.clima.nubes)
  if alfa < 0.01 then return nil end
  return -math.cos(fase * math.pi), 0.30 + 1.5 * (1 - altura), alfa, dia
end

local function manchaSombra(sx, sy, ancho, dx, dy, alfa)
  for i = 1, 3 do
    local f = i / 3
    love.graphics.setColor(0.02, 0.03, 0.08, alfa * 0.42)
    love.graphics.polygon("fill", sx - ancho * (1.3 - f * 0.4), sy, sx + ancho * (1.3 - f * 0.4), sy,
      sx + ancho * 0.35 + dx * (0.55 + f * 0.45), sy + dy * (0.55 + f * 0.45),
      sx - ancho * 0.35 + dx * (0.55 + f * 0.45), sy + dy * (0.55 + f * 0.45))
  end
end

function A.sombrasSuelo(mundo, mapa, jugador, radio, cam)
  if not A.activo() or calidad() == "bajo" then return end
  if jugador.modo ~= "mundo" and jugador.modo ~= "batalla" and jugador.modo ~= "estandarte" then return end
  local dirx, largo, alfa = luzSolar()
  if not dirx then return end
  Iso.empujar(cam)
  local iso = Iso.activo()
  -- árboles, faroles, estatuas
  for _, prop in ipairs(mapa.props or {}) do
    local alto = ALTURA_PROP[prop.tipo]
    if not alto and prop.tipo:find("arbol") then alto = 2.8 end
    if alto and math.abs(prop.x - jugador.x) < radio and math.abs(prop.y - jugador.y) < radio then
      local sx = (prop.x + (prop.ancho or 1) / 2) * TILE
      local sy = (prop.y + (prop.alto or 1) / 2 + (iso and 0.25 or 0.5 * (prop.alto or 1))) * TILE - 2
      local l = alto * largo * TILE
      manchaSombra(sx, sy, prop.tipo:find("arbol") and 15 or 6, dirx * l, l * 0.22 + 2, alfa)
    end
  end
  -- casas y edificios: la sombra cae junto a su base y, con el sol bajo, también hacia un lado
  if jugador.modo == "mundo" and not CasasIso.activo() and not iso then
    for _, e in ipairs(mapa.edificios or {}) do
      if math.abs(e.x + e.w / 2 - jugador.x) < radio + 4 and math.abs(e.y + e.h / 2 - jugador.y) < radio + 4 then
        local x0, x1 = e.x * TILE - cam.x, (e.x + e.w) * TILE - cam.x
        local yb = (e.y + e.h) * TILE - cam.y
        local yt = (e.y + e.h * 0.35) * TILE - cam.y
        local l = (e.h * 0.55 + 0.8) * largo * TILE
        local dx, dy = dirx * l, l * 0.20 + 3
        for i = 1, 3 do
          local f = 0.55 + i / 3 * 0.45
          love.graphics.setColor(0.02, 0.03, 0.08, alfa * 0.40)
          love.graphics.polygon("fill", x0, yb, x1, yb, x1 + dx * f, yb + dy * f, x0 + dx * f, yb + dy * f)
          local lado = dx > 0 and x1 or x0
          love.graphics.polygon("fill", lado, yt, lado, yb, lado + dx * f, yb + dy * f, lado + dx * f, yt + dy * f)
        end
      end
    end
  end
  -- los que caminan: criaturas, jugadores y vecinos
  for _, e in pairs(mundo.entidades) do
    local k = e.kind
    if e.vivo ~= false and (k == "jugador" or k == "bot" or k == "monstruo" or k == "npc" or k == "guardia")
      and mundo:mismoLugar(jugador, e) and math.abs(e.x - jugador.x) < radio and math.abs(e.y - jugador.y) < radio then
      local grande = e.jefe or e.jefeMz
      local alto = grande and 2.6 or ((e.elite or k == "monstruo") and 1.7 or 1.5)
      local ancho = grande and 17 or (e.elite and 11 or 8)
      local sx, sy = e.x * TILE, e.y * TILE + (iso and 2 or 13)
      local l = alto * largo * TILE * 0.75
      manchaSombra(sx, sy, ancho, dirx * l, l * 0.20 + 1, alfa * 0.9)
    end
  end
  Iso.sacar()
end

-- ---------------------------------------------------------------- antorchas de las mazmorras
function antorchasVisibles(mapa, cam, vw, vh, z)
  local lista = {}
  local x0, y0, x1, y1 = Iso.rango(cam.x, cam.y, vw / z, vh / z, 1)
  local bloque, suelo = mapa.bloque, mapa.suelo
  if not bloque or not suelo then return lista end
  for tx = x0, x1 do
    for ty = y0, y1 do
      if bloque[tx] and bloque[tx][ty] and hash(tx, ty, 77) < 0.13 then
        -- pared vista de frente (con suelo al norte): la antorcha cuelga de su cara
        if not (bloque[tx][ty - 1]) and suelo[tx] and suelo[tx][ty - 1] == "mazmorra" then
          lista[#lista + 1] = { x = tx + 0.5, y = ty + 0.85 }
        elseif not (bloque[tx][ty + 1]) and suelo[tx] and suelo[tx][ty + 1] == "mazmorra" then
          lista[#lista + 1] = { x = tx + 0.5, y = ty + 1 }
        end
      end
    end
  end
  return lista
end

-- Dibuja las antorchas de la pared (en el mundo, antes de lo que se mueve).
function A.dibujarAntorchas(mapa, cam, z, vw, vh)
  if not A.activo() or not mapa.mazmorra then return end
  local t = love.timer.getTime()
  for _, a in ipairs(antorchasVisibles(mapa, cam, vw, vh, z)) do
    local gx, gy = Iso.suelo(a.x, a.y)
    local sx, sy = gx - cam.x, gy - cam.y - 11
    local f = 0.85 + 0.15 * math.sin(t * 11 + a.x * 3)
    love.graphics.setColor(0.18, 0.12, 0.08, 1)
    love.graphics.rectangle("fill", sx - 2, sy, 4, 11)
    love.graphics.setColor(0.35, 0.28, 0.2, 1)
    love.graphics.rectangle("fill", sx - 4, sy - 1, 8, 3)
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1.0, 0.45, 0.12, 0.85 * f)
    love.graphics.ellipse("fill", sx, sy - 5, 4.2, 7 * f)
    love.graphics.setColor(1.0, 0.8, 0.3, 0.9 * f)
    love.graphics.ellipse("fill", sx, sy - 4, 2.6, 4.6 * f)
    love.graphics.setColor(1, 1, 0.85, 0.9)
    love.graphics.ellipse("fill", sx, sy - 3, 1.2, 2.2 * f)
    love.graphics.setBlendMode("alpha")
  end
end

-- ---------------------------------------------------------------- rayos de sol entre la bruma
function dibujarRayos(cam, jugador, cal)
  if cal == "bajo" or jugador.modo ~= "mundo" then return end
  local dirx, largo, _, dia = luzSolar()
  if not dirx or not dia then return end
  local k = limitar((largo - 0.8) / 0.9, 0, 1) * (1 - A.clima.nubes) * (1 - 0.5 * A.clima.lluvia)
  if k < 0.05 then return end
  local t = love.timer.getTime()
  local vx, vy, vw, vh = E.vx, E.vy, E.vw, E.vh
  local solx = -dirx
  love.graphics.setScissor(vx, vy, vw, vh)
  love.graphics.setBlendMode("add")
  for i = 0, 6 do
    local fi = i / 6
    local base = vx + vw * (0.5 + solx * 0.5 + (fi - 0.5) * 0.9)
    local ancho = vw * (0.02 + 0.02 * hash(i, 9, 1))
    local pulso = 0.55 + 0.45 * math.sin(t * 0.35 + i * 1.7)
    local a = 0.032 * k * pulso
    local tope = vy - 10
    local dx = -solx * vw * 0.45
    local malla = love.graphics.newMesh({
      { base - ancho, tope, 0, 0, 1.0, 0.86, 0.55, a },
      { base + ancho, tope, 0, 0, 1.0, 0.86, 0.55, a },
      { base + ancho * 2.4 + dx, vy + vh, 0, 0, 1.0, 0.86, 0.55, 0 },
      { base - ancho * 2.4 + dx, vy + vh, 0, 0, 1.0, 0.86, 0.55, 0 },
    }, "fan", "stream")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(malla)
    malla:release()
  end
  love.graphics.setBlendMode("alpha")
  love.graphics.setScissor()
end

-- Ajustes: cambia al siguiente nivel de calidad.
function A.siguienteNivel()
  local actual = Ajustes.graficos or "alto"
  for i, n in ipairs(A.NIVELES) do
    if n == actual then Ajustes.graficos = A.NIVELES[i % #A.NIVELES + 1] return Ajustes.graficos end
  end
  Ajustes.graficos = "alto"
  return "alto"
end

return A
