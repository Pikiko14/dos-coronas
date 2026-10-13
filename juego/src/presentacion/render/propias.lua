-- Skins exclusivas del Item Mall, hechas a partir de personajes del pack (misma línea gráfica que el
-- resto del juego) y retocadas por código: se recolorea el sprite con un sombreador y se le añaden
-- complementos dibujados (alas, tiara, penacho, emblema, brillos). Cada skin es una hoja de 96 x 128
-- con el mismo orden que las del pack (3 cuadros de caminar x 4 direcciones: abajo, izquierda,
-- derecha, arriba), así que se dibuja igual que cualquier otro personaje.
--   * hada_cristal: un personaje de pelo claro vestido de hielo, con alas translúcidas y tiara.
--   * caballero_solar: un caballero de armadura plateada vuelta de oro, con penacho y emblema de sol.
local Arte = require("src.presentacion.render.arte")

local P = {}
local cache = {}

-- ----------------------------------------------------------------------------------- recoloreado
local SOMBREADOR = [[
  extern number modo;
  extern vec4 ra;     // regla A: tono min, tono max, giro de tono, mult. de saturacion
  extern vec4 rb;     // regla B (igual)
  extern vec2 vab;    // mult. de brillo de las reglas A y B
  extern vec3 neutro; // mult. de color para los grises y blancos (metal, pelaje claro)
  extern number plus; // brillo que se suma a los neutros
  bool enTono(float h, float lo, float hi) {
    return lo <= hi ? (h >= lo && h <= hi) : (h >= lo || h <= hi);
  }
  vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
  }
  vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
  }
  vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 p = Texel(tex, uv);
    if (p.a < 0.01) return p;
    vec3 hsv = rgb2hsv(p.rgb);
    float lum = dot(p.rgb, vec3(0.299, 0.587, 0.114));
    if (modo > 1.5) {
      // paleta de clase o de montura: dos reglas por tono y un multiplicador para los neutros
      if (hsv.y < 0.14) return vec4(clamp(p.rgb * neutro + vec3(plus), 0.0, 1.0), p.a);
      if (enTono(hsv.x, ra.x, ra.y)) {
        hsv.x = fract(hsv.x + ra.z); hsv.y = clamp(hsv.y * ra.w, 0.0, 1.0); hsv.z = clamp(hsv.z * vab.x, 0.0, 1.0);
      } else if (enTono(hsv.x, rb.x, rb.y)) {
        hsv.x = fract(hsv.x + rb.z); hsv.y = clamp(hsv.y * rb.w, 0.0, 1.0); hsv.z = clamp(hsv.z * vab.y, 0.0, 1.0);
      }
      return vec4(hsv2rgb(hsv), p.a);
    }
    if (modo < 0.5) {
      // hielo: el vestido morado pasa a blanco azulado, el pelo azul se aclara; la piel no cambia
      if (hsv.x > 0.68 && hsv.x < 0.92 && hsv.y > 0.15) {
        hsv.x = 0.52;
        hsv.y = hsv.y * 0.42;
        hsv.z = clamp(hsv.z * 1.3 + 0.08, 0.0, 1.0);
      } else if (hsv.x > 0.45 && hsv.x <= 0.68 && hsv.y > 0.15) {
        hsv.x = 0.53;
        hsv.y = hsv.y * 0.8;
        hsv.z = clamp(hsv.z * 1.12 + 0.05, 0.0, 1.0);
      }
      return vec4(hsv2rgb(hsv), p.a);
    } else {
      // oro: la armadura (grises y azulados poco saturados) pasa a una rampa dorada con contraste
      if (hsv.y < 0.30) {
        float t = clamp(pow(lum, 1.15) * 1.25, 0.0, 1.0);
        vec3 a = vec3(0.14, 0.07, 0.02);
        vec3 b = vec3(0.62, 0.38, 0.06);
        vec3 c = vec3(0.98, 0.76, 0.18);
        vec3 d = vec3(1.0, 0.96, 0.66);
        vec3 o = t < 0.33 ? mix(a, b, t / 0.33) : (t < 0.66 ? mix(b, c, (t - 0.33) / 0.33) : mix(c, d, (t - 0.66) / 0.34));
        return vec4(o, p.a);
      }
      return p;
    }
  }]]
local sombreador

local function usarSombreador(modo, d)
  if sombreador == nil then
    local ok, sh = pcall(love.graphics.newShader, SOMBREADOR)
    sombreador = ok and sh or false
  end
  if sombreador then
    sombreador:send("modo", modo)
    d = d or {}
    sombreador:send("ra", d.ra or { 0, 0, 0, 1 })
    sombreador:send("rb", d.rb or { 0, 0, 0, 1 })
    sombreador:send("vab", { d.va or 1, d.vb or 1 })
    sombreador:send("neutro", d.neutro or { 1, 1, 1 })
    sombreador:send("plus", d.plus or 0)
    love.graphics.setShader(sombreador)
  end
end

-- ------------------------------------------------------------------------------------- utilidades
local function poli(pts, r, g, b, a)
  love.graphics.setColor(r, g, b, a or 1)
  love.graphics.polygon("fill", pts)
end

local function contorno(pts, r, g, b, a)
  love.graphics.setColor(r, g, b, a or 1)
  love.graphics.setLineWidth(1)
  love.graphics.polygon("line", pts)
end

local function elipse(cx, cy, rx, ry, r, g, b, a)
  love.graphics.setColor(r, g, b, a or 1)
  love.graphics.ellipse("fill", cx, cy, rx, ry, 20)
end

local function destello(x, y, r, g, b)
  love.graphics.setColor(r, g, b, 0.95)
  love.graphics.points(x, y)
  love.graphics.setColor(r, g, b, 0.55)
  love.graphics.points(x - 1, y, x + 1, y, x, y - 1, x, y + 1)
end

-- Hojas de partida y complementos de cada diseño. fila: 0 abajo, 1 izquierda, 2 derecha, 3 arriba.
local function lado_de(fila) return fila == 1 and -1 or (fila == 2 and 1 or 0) end

-- Alas translúcidas con plumas, un poco más abiertas en los pasos de caminar.
local function ala(pts, r, g, b)
  poli(pts, r, g, b, 0.62)
  contorno(pts, r * 0.5, g * 0.7, b * 0.95, 0.95)
end

local function alasHada(fila, col)
  local lado = lado_de(fila)
  local k = (col == 1) and 0 or 1   -- en los pasos las alas se abren un poco
  if lado == 0 then
    local l = { 11, 17, 7, 14, 3, 8 - k, 1, 2 - k, 6, 4, 10, 8, 12, 12 }
    local r = {}
    for n = 1, #l, 2 do r[#r + 1] = 31 - l[n]; r[#r + 1] = l[n + 1] end
    ala(l, 0.72, 0.93, 1.0)
    ala(r, 0.72, 0.93, 1.0)
    -- plumas interiores
    local li = { 11, 16, 8, 13, 5, 8 - k, 4, 5 - k, 8, 7, 10, 10 }
    local ri = {}
    for n = 1, #li, 2 do ri[#ri + 1] = 31 - li[n]; ri[#ri + 1] = li[n + 1] end
    poli(li, 1, 1, 1, 0.55)
    poli(ri, 1, 1, 1, 0.55)
  else
    local dir = -lado
    local sx = 16 + dir * -1
    local pts = { sx, 17, sx + dir * 5, 13, sx + dir * 10, 6 - k, sx + dir * 12, 1 - k, sx + dir * 6, 3, sx + dir * 2, 8, sx + dir * 1, 13 }
    ala(pts, 0.72, 0.93, 1.0)
    poli({ sx, 16, sx + dir * 4, 12, sx + dir * 8, 6 - k, sx + dir * 4, 7, sx + dir * 2, 11 }, 1, 1, 1, 0.55)
  end
end
local function tiaraHada(fila, col)
  local lado = lado_de(fila)
  if fila == 3 then return end
  local x = 16 + lado * 2
  local y = 6
  -- aro de plata sobre la frente y un cristal central
  love.graphics.setColor(0.9, 0.97, 1, 1)
  love.graphics.rectangle("fill", x - 5, y, 10, 1)
  love.graphics.setColor(0.55, 0.78, 0.95, 1)
  love.graphics.rectangle("fill", x - 5, y + 1, 10, 1)
  poli({ x, y - 5, x - 2, y, x + 2, y }, 0.62, 0.95, 1)
  poli({ x, y - 5, x - 1, y - 1, x + 1, y - 1 }, 1, 1, 1)
  poli({ x - 4, y - 2, x - 5, y, x - 3, y }, 0.62, 0.95, 1)
  poli({ x + 4, y - 2, x + 3, y, x + 5, y }, 0.62, 0.95, 1)
end

local function brillosHada(fila, col)
  local d = (col * 2) % 5
  destello(3 + d, 14 + d, 0.85, 0.98, 1)
  destello(28 - d, 18, 1, 1, 1)
  destello(5, 27 - d, 0.8, 0.95, 1)
  destello(27, 9 + d, 1, 1, 1)
end

-- Resplandor dorado detras del caballero.
local function auraSol(fila, col)
  elipse(16, 18, 14, 15, 1, 0.8, 0.25, 0.14)
  elipse(16, 18, 10, 12, 1, 0.9, 0.4, 0.14)
end

-- Cresta roja sobre el yelmo (de frente y de espalda una franja; de lado, con cola hacia atras).
local function penacho(fila, col)
  local lado = lado_de(fila)
  local ond = col == 1 and 0 or (col == 0 and -1 or 1)
  if lado == 0 then
    poli({ 14.5, 1, 17.5, 1, 18, 7, 14, 7 }, 0.82, 0.1, 0.14)
    poli({ 14.5, 1, 15.5, 1, 15.5, 7, 14, 7 }, 1, 0.45, 0.4, 0.8)
    poli({ 16.5, 1, 17.5, 1, 18, 7, 16.5, 7 }, 0.5, 0.04, 0.08, 0.8)
  else
    local b = -lado
    local x = 16 + lado
    poli({ x - 3, 1.5, x + 3, 1.5, x + b * 5, 4 + ond, x + b * 8, 8 + ond, x + b * 4, 7, x - 1, 5 }, 0.82, 0.1, 0.14)
    poli({ x - 3, 1.5, x + 1, 1.5, x + b * 4, 4 + ond, x - 1, 4.5 }, 1, 0.45, 0.4, 0.75)
  end
end

local function emblemaSol(fila, col)
  if fila ~= 0 then return end
  local cx, cy = 16, 21
  love.graphics.setColor(0.2, 0.08, 0.02, 0.9)
  love.graphics.setLineWidth(1)
  love.graphics.circle("line", cx, cy, 3.6)
  elipse(cx, cy, 3, 3, 1, 0.55, 0.1)
  elipse(cx, cy, 1.8, 1.8, 1, 0.93, 0.5)
  love.graphics.setColor(1, 0.62, 0.15, 1)
  for i = 0, 7 do
    local a = i * math.pi / 4
    love.graphics.points(cx + math.cos(a) * 4.8, cy + math.sin(a) * 4.8)
  end
end

local function brillosSol(fila, col)
  local d = (col * 2) % 3
  destello(3 + d, 12, 1, 0.95, 0.6)
  destello(28 - d, 10 + d, 1, 0.9, 0.5)
  destello(27, 26 - d, 1, 0.85, 0.4)
end

-- ------------------------------------------------------------------- clases y monturas por facción
-- Cada clase tiene su personaje del pack con la paleta de su facción (Alba: acero azulado, blanco y
-- oro; Ocaso: negro, violeta y carmesí) y un escudo en el pecho: el color de la facción con el signo
-- de la clase. Las monturas usan los animales del pack con la misma paleta, así que jinete y
-- montura combinan.
local COLOR_FACCION = {
  albor = { fondo = { 0.12, 0.25, 0.6 }, borde = { 1, 0.85, 0.35 }, signo = { 1, 0.95, 0.7 } },
  umbra = { fondo = { 0.3, 0.08, 0.38 }, borde = { 0.85, 0.2, 0.3 }, signo = { 1, 0.8, 0.9 } },
}

-- Signos de 3 x 5 (1 = pixel) de cada clase.
local SIGNOS = {
  guerrero = { "010", "010", "010", "111", "010" },   -- espada
  mago = { "010", "111", "111", "010", "101" },       -- estrella
  cazador = { "010", "011", "111", "011", "010" },    -- flecha
  clerigo = { "010", "010", "111", "010", "010" },    -- cruz
}

local function escudoPecho(clase, faccion)
  return function(fila, col)
    if fila ~= 0 then return end
    local c = COLOR_FACCION[faccion]
    local x, y = 14, 19
    love.graphics.setColor(c.borde[1], c.borde[2], c.borde[3], 1)
    love.graphics.rectangle("fill", x - 1, y - 1, 5, 7)
    love.graphics.setColor(c.fondo[1], c.fondo[2], c.fondo[3], 1)
    love.graphics.rectangle("fill", x, y, 3, 5)
    love.graphics.setColor(c.signo[1], c.signo[2], c.signo[3], 1)
    for j, fila_s in ipairs(SIGNOS[clase]) do
      for i = 1, 3 do
        if fila_s:sub(i, i) == "1" then love.graphics.points(x + i - 0.5, y + j - 0.5) end
      end
    end
  end
end

local function clase(id, hoja, idx, extra)
  local d = { hoja = hoja, idx = idx, modo = 2 }
  for k, v in pairs(extra or {}) do d[k] = v end
  return d
end

local function montura(idx, extra)
  local d = { hoja = "Characters/Animal.png", idx = idx, modo = 2 }
  for k, v in pairs(extra or {}) do d[k] = v end
  return d
end

local DISENOS = {
  hada_cristal = { hoja = "Characters/Spiritual.png", idx = 1, modo = 0, detras = { alasHada }, delante = { tiaraHada, brillosHada } },
  caballero_solar = { hoja = "Characters/People4.png", idx = 6, modo = 1, detras = { auraSol }, delante = { emblemaSol, penacho, brillosSol } },

  clase_guerrero_albor = clase("g", "Characters/Actor3.png", 6, { neutro = { 0.92, 1.0, 1.2 }, delante = { escudoPecho("guerrero", "albor") } }),
  clase_guerrero_umbra = clase("g", "Characters/Evil.png", 7, { neutro = { 1.12, 0.85, 1.2 }, delante = { escudoPecho("guerrero", "umbra") } }),
  clase_mago_albor = clase("m", "Characters/Actor2.png", 7, { ra = { 0.6, 0.95, -0.1, 1.0 }, va = 1.1, delante = { escudoPecho("mago", "albor") } }),
  clase_mago_umbra = clase("m", "Characters/Evil.png", 3, { neutro = { 1.0, 0.8, 1.25 }, delante = { escudoPecho("mago", "umbra") } }),
  clase_cazador_albor = clase("c", "Characters/Actor5.png", 2, { delante = { escudoPecho("cazador", "albor") } }),
  clase_cazador_umbra = clase("c", "Characters/Evil.png", 0, { ra = { 0.2, 0.48, 0.58, 1.0 }, delante = { escudoPecho("cazador", "umbra") } }),
  clase_clerigo_albor = clase("l", "Characters/Actor5.png", 5, { delante = { escudoPecho("clerigo", "albor") } }),
  clase_clerigo_umbra = clase("l", "Characters/Actor5.png", 6, { ra = { 0.78, 0.04, -0.12, 0.8 }, va = 0.85, delante = { escudoPecho("clerigo", "umbra") } }),

  montura_corcel_albor = montura(5, { ra = { 0.03, 0.16, 0.0, 0.12 }, va = 1.7, rb = { 0.9, 0.03, 0.62, 1.0 }, vb = 1.0 }),
  montura_corcel_umbra = montura(5, { ra = { 0.03, 0.16, 0.7, 0.35 }, va = 0.42, rb = { 0.9, 0.03, -0.08, 1.0 }, vb = 1.0 }),
  montura_lobo_albor = montura(6, { neutro = { 1.2, 1.3, 1.5 }, plus = 0.06 }),
  montura_lobo_umbra = montura(6, { neutro = { 0.5, 0.42, 0.65 } }),
  montura_bisonte_albor = montura(4, { neutro = { 1.0, 0.82, 0.58 } }),
  montura_bisonte_umbra = montura(4, { neutro = { 0.58, 0.46, 0.7 } }),
  -- dragon del Item Mall: la criatura roja de la hoja Monster2, dorada en el Alba y violeta en el Ocaso
  montura_dragon_albor = montura(5, { hoja = "Characters/Monster2.png", ra = { 0.9, 0.16, 0.09, 1.2 }, va = 1.08, rb = { 0.5, 0.75, 0.0, 1.0 }, vb = 1.0 }),
  montura_dragon_umbra = montura(5, { hoja = "Characters/Monster2.png", ra = { 0.9, 0.16, -0.2, 0.8 }, va = 0.7, rb = { 0.5, 0.75, 0.0, 1.0 }, vb = 1.0 }),
  -- corcel de fuego: dorado con silla azul en el Alba; ascua con silla violeta en el Ocaso
  montura_fuego_albor = montura(5, { ra = { 0.03, 0.16, 0.04, 1.25 }, va = 1.5, rb = { 0.9, 0.03, 0.62, 1.0 }, vb = 1.0 }),
  montura_fuego_umbra = montura(5, { ra = { 0.03, 0.16, -0.075, 1.3 }, va = 0.75, rb = { 0.9, 0.03, -0.2, 1.0 }, vb = 1.1 }),
}

-- Hoja de 96 x 128 del personaje (imagen lista para dibujar con quads de 32 x 32).
function P.hoja(id)
  if cache[id] then return cache[id] end
  local d = DISENOS[id]
  if not d then return nil end
  local base = Arte.img(d.hoja)
  local cv = love.graphics.newCanvas(96, 128)
  local anterior = love.graphics.getCanvas()
  love.graphics.push("all")
  love.graphics.setCanvas(cv)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.origin()
  love.graphics.setBlendMode("alpha")
  local ox, oy = (d.idx % 4) * 96, math.floor(d.idx / 4) * 128
  for fila = 0, 3 do
    for col = 0, 2 do
      love.graphics.push()
      love.graphics.translate(col * 32, fila * 32)
      for _, f in ipairs(d.detras or {}) do f(fila, col) end
      love.graphics.setColor(1, 1, 1, 1)
      usarSombreador(d.modo, d)
      love.graphics.draw(base, Arte.quad(base, ox + col * 32, oy + fila * 32, 32, 32), 0, 0)
      love.graphics.setShader()
      for _, f in ipairs(d.delante or {}) do f(fila, col) end
      love.graphics.pop()
    end
  end
  love.graphics.pop()
  love.graphics.setCanvas(anterior)
  cv:setFilter("nearest", "nearest")
  cache[id] = cv
  return cv
end

function P.olvidar() cache = {} end

return P
