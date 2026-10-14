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

-- --------------------------------------------------------------------- complementos de los addons de clase
-- Un complemento por addon (cuernos, sombrero, aureola, lanza...), dibujado por código sobre el sprite recoloreado.
-- Todos usan el mismo sistema: fila 0 de frente, 1 izquierda, 2 derecha y 3 de espaldas; col 0 a 2 es el cuadro de
-- caminar (en los pasos se mueven un poco las llamas, las plumas y los brillos).
local function cuernos(fila, col)
  local lado = lado_de(fila)
  local function cuerno(x0, dir)
    local pts = { x0, 6, x0 + dir * 2, 6, x0 + dir * 4.5, 1, x0 + dir * 3.2, 0, x0 + dir * 0.5, 3.5 }
    poli(pts, 0.96, 0.93, 0.82)
    contorno(pts, 0.45, 0.38, 0.3, 0.95)
  end
  if lado == 0 then
    cuerno(10.5, -1)
    cuerno(21.5, 1)
  else
    cuerno(16 + lado * 0.5, -lado)
  end
  love.graphics.setColor(0.55, 0.57, 0.65, 1)
  love.graphics.rectangle("fill", 11, 6, 10, 2)    -- aro del yelmo
  love.graphics.setColor(0.85, 0.87, 0.95, 1)
  love.graphics.rectangle("fill", 11, 6, 10, 1)
end

local function sombreroMago(fila, col)
  local lado = lado_de(fila)
  local c = { 0.2, 0.18, 0.55 }
  -- ala ancha y cono con la punta caída hacia un lado
  elipse(16, 6.4, 10.5, 2.1, c[1] * 0.6, c[2] * 0.6, c[3] * 0.85)
  elipse(16, 5.8, 10, 1.8, c[1], c[2], c[3])
  poli({ 10.5, 6, 21.5, 6, 20 + lado * 1.5, 2.5, 16 + lado * 2.5, 0.2, 13, 3 }, c[1], c[2], c[3])
  poli({ 10.5, 6, 14, 6, 14, 3, 13, 3 }, 0.32, 0.3, 0.75, 0.9)
  love.graphics.setColor(0.98, 0.8, 0.25, 1)
  love.graphics.rectangle("fill", 11, 5, 10, 1)     -- cinta dorada
  if fila == 0 then
    love.graphics.setColor(1, 0.9, 0.4, 1)
    love.graphics.points(16, 3, 15, 4, 17, 4, 16, 4)  -- estrellita
  end
end

local function sombreroPluma(fila, col)
  local lado = lado_de(fila)
  elipse(16, 5.5, 8.5, 2.3, 0.16, 0.34, 0.14)
  poli({ 9, 6, 23, 6, 21, 2.5, 11, 2.5 }, 0.22, 0.46, 0.2)
  love.graphics.setColor(0.5, 0.3, 0.12, 1)
  love.graphics.rectangle("fill", 10, 5, 12, 1)
  -- pluma roja
  local o = col == 1 and 0 or 1
  local x = 21 + (lado == -1 and -9 or 0)
  poli({ x, 4, x + 3, 0 + o, x + 5, 1, x + 3.5, 3.5, x + 1, 5 }, 0.86, 0.18, 0.16)
  love.graphics.setColor(1, 0.7, 0.6, 1)
  love.graphics.points(x + 2, 3)
end

local function aureola(fila, col)
  local k = col == 1 and 0 or 0.4
  love.graphics.setColor(1, 0.95, 0.55, 0.28)
  love.graphics.ellipse("fill", 16, 2.4, 9, 3, 24)
  love.graphics.setColor(1, 0.9, 0.35, 1)
  love.graphics.setLineWidth(1)
  love.graphics.ellipse("line", 16, 2.4 + k, 6.5, 1.8, 24)
  love.graphics.setColor(1, 1, 0.8, 1)
  love.graphics.points(12, 2.5, 20, 2.5)
end

local function diademaElfico(fila, col)
  if fila == 3 then
    love.graphics.setColor(0.85, 0.9, 0.95, 1)
    love.graphics.rectangle("fill", 10, 8, 12, 1)
    return
  end
  local x = 16 + lado_de(fila) * 2
  love.graphics.setColor(0.88, 0.93, 0.98, 1)
  love.graphics.rectangle("fill", x - 6, 7, 12, 1)
  love.graphics.setColor(0.55, 0.7, 0.8, 1)
  love.graphics.rectangle("fill", x - 6, 8, 12, 1)
  poli({ x, 4.5, x - 1.6, 7, x + 1.6, 7 }, 0.3, 0.95, 0.55)
  poli({ x, 5, x - 0.6, 6.4, x + 0.6, 6.4 }, 0.85, 1, 0.9)
  destello(x - 7, 9 + (col % 2), 0.6, 1, 0.7)
end

-- Arma sujeta con la mano derecha del personaje: de frente a la izquierda del dibujo, de espaldas a la derecha (la
-- misma mano), y de lado junto al cuerpo, hacia delante. Siempre se dibuja ENCIMA del personaje y con el puño sobre
-- el asta, así parece que la lleva en la mano y no que flota a un lado.
local function puñoArma(fila)
  if fila == 0 then return 8 end
  if fila == 3 then return 19 end    -- de espaldas el arma cruza por delante del cuerpo, sobre la capa
  if fila == 1 then return 10 end
  return 21
end

local function manoSobre(x, y)
  love.graphics.setColor(0.96, 0.78, 0.62, 1)
  love.graphics.rectangle("fill", x - 1, y, 3.6, 3)
  love.graphics.setColor(0.7, 0.5, 0.38, 1)
  love.graphics.rectangle("fill", x - 1, y + 2.4, 3.6, 0.8)
end

local function lanzaLateral(fila, col)
  local x = puñoArma(fila)
  love.graphics.setColor(0.12, 0.07, 0.04, 0.9)
  love.graphics.rectangle("fill", x - 1, 5, 3.6, 26)
  love.graphics.setColor(0.6, 0.38, 0.18, 1)
  love.graphics.rectangle("fill", x, 5, 1.6, 26)
  love.graphics.setColor(0.4, 0.24, 0.1, 1)
  love.graphics.rectangle("fill", x, 25, 1.6, 3)
  poli({ x + 0.8, 0, x + 3.2, 4.6, x + 0.8, 6, x - 1.6, 4.6 }, 0.85, 0.9, 1)
  poli({ x + 0.8, 0.6, x + 1.5, 4, x + 0.8, 5, x - 0.2, 4 }, 1, 1, 1, 0.9)
  poli({ x - 0.5, 6, x + 2.2, 6, x + 3 + (col - 1), 9.5, x - 1 + (col - 1), 9.5 }, 0.86, 0.14, 0.16)
  if fila ~= 3 then manoSobre(x, 20) end   -- de espaldas no se ve la mano
end

local function bastonCalavera(fila, col)
  local x = puñoArma(fila)
  love.graphics.setColor(0.08, 0.05, 0.1, 0.9)
  love.graphics.rectangle("fill", x - 1, 6, 3.6, 25)
  love.graphics.setColor(0.42, 0.3, 0.22, 1)
  love.graphics.rectangle("fill", x, 6, 1.6, 25)
  love.graphics.setColor(0.93, 0.92, 0.84, 1)
  love.graphics.ellipse("fill", x + 0.8, 4, 3.3, 3.5, 16)
  love.graphics.rectangle("fill", x - 0.8, 6, 3.2, 2)
  love.graphics.setColor(0.2, 0.1, 0.3, 1)
  love.graphics.points(x - 0.5, 3.5, x - 0.5, 4.5, x + 2, 3.5, x + 2, 4.5, x + 0.8, 6.5)
  if fila ~= 3 then manoSobre(x, 20) end   -- de espaldas no se ve la mano
  -- ascuas violeta que suben del cráneo
  local d = (col * 2) % 4
  destello(x - 2, 2 - d * 0.3, 0.75, 0.4, 1)
  destello(x + 4, 1 + d * 0.3, 0.65, 0.35, 0.95)
end

local function coronaLich(fila, col)
  if fila == 3 then
    love.graphics.setColor(0.8, 0.85, 0.75, 1)
    love.graphics.rectangle("fill", 11, 4, 10, 2)
    return
  end
  local x = 16 + lado_de(fila) * 1.5
  love.graphics.setColor(0.55, 1, 0.65, 0.3)
  love.graphics.ellipse("fill", x, 4, 8, 4, 20)
  local pts = { x - 6, 6.5, x - 6, 1.5, x - 3, 4, x - 1.5, 0.5, x, 4, x + 1.5, 0.5, x + 3, 4, x + 6, 1.5, x + 6, 6.5 }
  poli(pts, 0.86, 0.9, 0.78)
  contorno(pts, 0.3, 0.4, 0.3, 0.9)
  love.graphics.setColor(0.4, 1, 0.55, 1)
  love.graphics.points(x, 5, x - 1, 5, x + 1, 5)
  destello(x - 7, 8 + (col % 2), 0.5, 1, 0.65)
  destello(x + 7, 9 - (col % 2), 0.5, 1, 0.65)
end

local function llamasFuego(fila, col)
  local o = (col * 1.5) % 3
  local function llama(x, y, h)
    poli({ x - 1.6, y, x + 1.6, y, x + 0.5, y - h - o * 0.3, x - 0.4, y - h * 0.5 }, 1, 0.42, 0.08, 0.95)
    poli({ x - 0.9, y, x + 0.9, y, x, y - h * 0.65 }, 1, 0.85, 0.3, 0.95)
  end
  llama(7, 17, 5)
  llama(25, 17, 5)
  llama(16, 3, 4)
  llama(12, 4, 3)
  llama(20, 4, 3)
  destello(4, 12 + o, 1, 0.7, 0.2)
  destello(28, 10 - o, 1, 0.6, 0.15)
end

local function brillosHueso(fila, col)
  local d = (col * 2) % 5
  destello(3 + d, 14, 0.8, 0.55, 1)
  destello(28 - d, 20, 0.9, 0.8, 1)
  destello(6, 27 - d, 0.7, 0.45, 1)
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

-- Cuerno dorado del unicornio: en el centro de la frente de frente, hacia delante y arriba de lado.
local function cuernoUnicornio(fila, col)
  if fila == 3 then return end
  local function X(x) return fila == 2 and (31 - x) or x end
  love.graphics.setLineWidth(1)
  if fila == 0 then
    local cuerpo = { 14.4, 6.4, 17.6, 6.4, 16, 0 }
    poli(cuerpo, 1, 0.84, 0.28)
    poli({ 15.2, 6, 16, 1, 16.4, 6 }, 1, 0.97, 0.72, 0.9)
    contorno(cuerpo, 0.5, 0.3, 0.05)
    love.graphics.setColor(0.8, 0.52, 0.1, 1)
    love.graphics.line(14.9, 4.8, 17.1, 3.8)
    love.graphics.line(15.4, 3, 16.7, 2.3)
  else
    local cuerpo = { X(6.5), 6.6, X(9.8), 4.4, X(1.2), 0.2 }
    poli(cuerpo, 1, 0.84, 0.28)
    poli({ X(7), 6, X(2.4), 1, X(8.2), 4.8 }, 1, 0.97, 0.72, 0.9)
    contorno(cuerpo, 0.5, 0.3, 0.05)
    love.graphics.setColor(0.8, 0.52, 0.1, 1)
    love.graphics.line(X(6.6), 5.2, X(8.2), 6.2)
    love.graphics.line(X(4.8), 3.6, X(6.2), 4.8)
  end
end

local DISENOS = {
  hada_cristal = { hoja = "Characters/Spiritual.png", idx = 1, modo = 0, detras = { alasHada }, delante = { tiaraHada, brillosHada } },
  caballero_solar = { hoja = "Characters/People4.png", idx = 6, modo = 1, detras = { auraSol }, delante = { emblemaSol, penacho, brillosSol } },

  -- addons de clase del Item Mall: un sprite del pack recoloreado + un complemento dibujado por código
  gladiador = clase("g", "Characters/Actor3.png", 6, { neutro = { 1.25, 0.82, 0.48 }, plus = 0.03, delante = { penacho } }),
  barbaro = clase("b", "Characters/Actor3.png", 0, { neutro = { 0.85, 0.95, 1.18 }, delante = { cuernos } }),
  archimago = clase("a", "Characters/Actor2.png", 4, { ra = { 0.55, 0.75, 0.05, 1.3 }, va = 0.95, neutro = { 0.9, 0.85, 1.25 }, delante = { sombreroMago, brillosHueso } }),
  hechicero_fuego = clase("h", "Characters/Actor5.png", 6, { ra = { 0.0, 0.1, 0.03, 1.4 }, va = 1.1, rb = { 0.9, 1.0, 0.0, 1.4 }, vb = 1.1, delante = { llamasFuego } }),
  montaraz = clase("m", "Characters/Actor4.png", 6, { ra = { 0.4, 0.62, -0.08, 1.25 }, va = 0.9, neutro = { 0.95, 1.05, 0.9 }, delante = { sombreroPluma } }),
  arquero_elfico = clase("e", "Characters/Actor3.png", 5, { neutro = { 0.95, 1.1, 1.05 }, delante = { diademaElfico } }),
  sacerdotisa_alba = clase("s", "Characters/People2.png", 5, { neutro = { 1.1, 1.08, 0.96 }, plus = 0.05, delante = { aureola } }),
  hoplita = clase("o", "Characters/People4.png", 6, { neutro = { 1.25, 0.86, 0.5 }, plus = 0.04, delante = { penacho, lanzaLateral } }),
  senor_huesos = clase("z", "Characters/Actor1.png", 7, { ra = { 0.05, 0.2, 0.7, 0.7 }, va = 0.7, neutro = { 0.75, 0.7, 0.9 }, delante = { bastonCalavera } }),
  dama_lich = clase("l", "Characters/Actor4.png", 7, { ra = { 0.9, 1.0, 0.65, 1.1 }, va = 0.9, rb = { 0.0, 0.1, 0.5, 1.1 }, vb = 0.85, neutro = { 0.75, 1.1, 0.95 }, delante = { coronaLich, brillosHueso } }),

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

-- Monturas vistosas nuevas (la cuadra y el Item Mall): cada una parte de un animal del pack recoloreado con el
-- sombreador y es igual para las dos facciones. Sus efectos (alas, aura y partículas) los pone
-- render/monturas_fx.lua. Parámetros como en las demás: ra/rb = reglas de tono, va/vb = brillo, neutro = color de
-- grises y blancos.
local function nueva(id, idx, extra)
  DISENOS["montura_" .. id .. "_albor"] = montura(idx, extra)
  DISENOS["montura_" .. id .. "_umbra"] = montura(idx, extra)
end
-- caballo (Animal 5): pelaje pardo (tonos 0.03-0.16) y silla roja (0.9-0.03)
nueva("unicornio", 5, { ra = { 0.03, 0.16, 0.0, 0.1 }, va = 1.8, rb = { 0.9, 0.03, 0.11, 1.1 }, vb = 1.25, neutro = { 1.1, 1.1, 1.25 }, plus = 0.05, delante = { cuernoUnicornio } })
nueva("pegaso", 5, { ra = { 0.03, 0.16, 0.5, 0.22 }, va = 1.75, rb = { 0.9, 0.03, 0.11, 1.0 }, vb = 1.2, neutro = { 1.0, 1.1, 1.3 }, plus = 0.05 })
nueva("fenix", 5, { ra = { 0.03, 0.16, -0.02, 2.4 }, va = 1.45, rb = { 0.9, 0.03, 0.14, 1.3 }, vb = 1.5, neutro = { 1.4, 0.9, 0.5 }, plus = 0.04 })
nueva("corcel_astral", 5, { ra = { 0.03, 0.16, 0.72, 1.2 }, va = 0.55, rb = { 0.9, 0.03, 0.55, 1.2 }, vb = 1.6, neutro = { 0.55, 0.5, 0.95 }, plus = 0.03 })
-- lobo (Animal 6) y toro (Animal 4): casi todo grises, se tiñen con el multiplicador de neutros
nueva("lobo_ascua", 6, { neutro = { 1.7, 0.78, 0.45 }, plus = 0.04 })
nueva("lobo_escarcha", 6, { neutro = { 0.85, 1.2, 1.5 }, plus = 0.14 })
nueva("toro_trueno", 4, { neutro = { 0.5, 0.58, 1.2 }, plus = 0.02, ra = { 0.03, 0.16, 0.55, 1.2 }, va = 0.9 })
-- dragones (Monster2: 5 rojo, 1 verde) y gárgola (Monster1 3): grandes, como el dragón del mall
nueva("dragon_hielo", 5, { hoja = "Characters/Monster2.png", ra = { 0.9, 0.16, 0.5, 0.9 }, va = 1.25, rb = { 0.5, 0.75, 0.0, 1.0 }, vb = 1.1, neutro = { 0.9, 1.1, 1.3 }, plus = 0.08 })
nueva("dragon_sombra", 1, { hoja = "Characters/Monster2.png", ra = { 0.18, 0.5, 0.55, 0.85 }, va = 0.55, rb = { 0.5, 0.75, 0.0, 1.0 }, vb = 0.8, neutro = { 0.5, 0.45, 0.7 } })
nueva("gargola_oro", 3, { hoja = "Characters/Monster1.png", ra = { 0.4, 0.62, -0.33, 1.3 }, va = 1.25, rb = { 0.7, 0.99, 0.0, 1.0 }, vb = 1.0, neutro = { 1.3, 1.1, 0.6 }, plus = 0.03 })

-- Hoja de 96 x 128 del personaje (imagen lista para dibujar con quads de 32 x 32).
function P.hoja(id)
  if cache[id] then return cache[id] end
  local d = DISENOS[id]
  if not d then return nil end
  local base = Arte.img(d.hoja)
  local cv = love.graphics.newCanvas(96, 128)
  local anterior = love.graphics.getCanvas()
  love.graphics.push("all")
  -- sin el recorte de pantalla de quien nos llama (si no, la hoja se genera recortada y queda vacía)
  love.graphics.setScissor()
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
