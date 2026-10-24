-- Motor de capas de los efectos de poder de Free Angels Online (compartido/datos/efectos_fao_poderes.lua, generado por herramientas/generar_efectos_fao_poderes.py): cada poder es una lista
-- de capas con su timeline (secuencia, anclaje, inicio, modo, escala, opacidad, desplazamiento). Arte de un juego ajeno (FAO): prototipo.
--   w     C/T  pecho del lanzador / del objetivo (se centra lo visible del dibujo)   GC/GT  suelo del lanzador / del objetivo (se usa el ancla `origin`)   proj  viaja de la mano al pecho del objetivo
--   modo  once (una vez), loop (en bucle de t0 a t1, con fundido), hold (reproduce y se queda en el último cuadro hasta t1), step (un cuadro de dirección durante `dur`), proj
--   dir   el cuadro se elige por la dirección (5 cuadros: 0 arriba, 2 izquierda, 4 abajo; 9: giro de 180°; la derecha es el espejo)
-- Se dibuja en dos pasadas: "suelo" (capas GC/GT, bajo los personajes) y "cuerpo" (el resto, sobre ellos). Los personajes de FAO se dibujan a 0,5, así que estos sprites también (K).
-- Las capas de suelo de los poderes con área se escalan para cubrir el radio real del poder (aoe o rango de habilidades.xml).
local Iso = require("src.presentacion.render.iso")
local Poderes = require("compartido.datos.efectos_fao_poderes")
local Seqs = require("src.presentacion.render.efectos_fao_poderes_datos")
local DatosJuego = require("compartido.dominio.datos")

local M = {}
M.poderes = Poderes

local K = 0.5
local PECHO = 34           -- px de pantalla sobre los pies (el pecho de un personaje de FAO a 0,5)
local imagenes, quads, centros = {}, {}, {}

local function imagen(sec)
  local i = imagenes[sec]
  if i == nil then
    local ruta = "arte/fao_efectos/" .. sec .. ".png"
    if love.filesystem.getInfo(ruta) then
      i = love.graphics.newImage(ruta)
      i:setFilter("linear", "linear")
    else
      i = false
    end
    imagenes[sec] = i
  end
  return i
end

local function quad(sec, k)
  local clave = sec .. "#" .. k
  local q = quads[clave]
  if not q then
    local d, img = Seqs[sec], imagen(sec)
    q = love.graphics.newQuad(k * d.w, 0, d.w, d.h, img:getWidth(), img:getHeight())
    quads[clave] = q
  end
  return q
end

-- Centro de lo visible de la secuencia (unión de todos sus cuadros: no baila al animarse).
local function centro(sec)
  local c = centros[sec]
  if c then return c[1], c[2] end
  local d = Seqs[sec]
  local datos = love.image.newImageData("arte/fao_efectos/" .. sec .. ".png")
  local x0, y0, x1, y1 = d.w, d.h, -1, -1
  for k = 0, d.n - 1 do
    for y = 0, d.h - 1, 2 do
      for x = 0, d.w - 1, 2 do
        local _, _, _, a = datos:getPixel(k * d.w + x, y)
        if a > 0.1 then
          if x < x0 then x0 = x end
          if x > x1 then x1 = x end
          if y < y0 then y0 = y end
          if y > y1 then y1 = y end
        end
      end
    end
  end
  datos:release()
  c = x1 >= 0 and { (x0 + x1) / 2, (y0 + y1) / 2 } or { d.w / 2, d.h / 2 }
  centros[sec] = c
  return c[1], c[2]
end

local function limitar(v, a, b) return math.max(a, math.min(b, v)) end
local function seg(t, a, b) return limitar((t - a) / (b - a), 0, 1) end

-- Cuadro de dirección y espejo según el ángulo de avance en pantalla (grados, 0 = derecha, y hacia abajo).
local function cuadroDir(th, n)
  local espejo = math.cos(math.rad(th)) >= 0
  local ang = espejo and (180 - th) or th
  while ang > -90 do ang = ang - 360 end
  while ang < -270 do ang = ang + 360 end
  return math.floor(limitar((-90 - ang) / 180 * (n - 1), 0, n - 1) + 0.5), espejo
end

local function delta(x, y, x0, y0)
  local ax, ay = Iso.pos(x, y)
  local bx, by = Iso.pos(x0, y0)
  return ax - bx, ay - by
end

-- Radio del poder en casillas (aoe o alcance de los poderes de alrededor), o nil.
local function radioDe(id)
  local h = DatosJuego.habilidades[id]
  if not h then return nil end
  if h.aoe then return h.aoe end
  if h.tipo == "alrededor" or h.tipo == "mixto" or h.tipo == "buff_alrededor" or h.tipo == "aliados" then return h.rango end
  return nil
end

-- Factor de escala de las capas de suelo para que el conjunto cubra el radio del poder (1 si no tiene área). Se calcula una vez por poder y por proyección.
local factores = {}
local function factorArea(id, x, y)
  local clave = id .. (Iso.activo() and "i" or "c")
  local f = factores[clave]
  if f then return f end
  f = 1
  local R = radioDe(id)
  local p = Poderes[id]
  if R and p then
    local ex, ey = delta(x + R, y, x, y)
    local sx, sy = delta(x, y + R, x, y)
    local hw = math.sqrt(ex * ex + sx * sx)
    local extension, hay = 0, false
    for _, c in ipairs(p.capas) do
      if c.w == "GT" or c.w == "GC" then
        local d = Seqs[c.s]
        local off = c.off and math.abs(c.off[1]) or 0
        extension = math.max(extension, (off + d.vw * c.sc / 2) * K)
        hay = true
      end
    end
    if hay and extension > 1 then f = limitar(hw / extension, 0.3, 1.5) end
  end
  factores[clave] = f
  return f
end

-- Dibuja las capas del poder `id` para el efecto fx (x, y = objetivo; x0, y0 = lanzador) a los t segundos. (sx, sy) = el suelo del objetivo en pantalla. pasada: "suelo" | "cuerpo".
function M.dibujar(id, fx, t, sx, sy, pasada)
  local p = Poderes[id]
  if not p then return end
  local cdx, cdy = 0, 0
  if fx.x0 then cdx, cdy = delta(fx.x0, fx.y0, fx.x, fx.y) end
  local cx, cy = sx + cdx, sy + cdy                       -- el suelo del lanzador
  local vx, vy = sx - cx, sy - cy                          -- del lanzador al objetivo (pantalla)
  local ang = 0
  if vx * vx + vy * vy > 4 then ang = math.deg(math.atan2(vy, vx))
  elseif fx.rot then ang = math.deg(Iso.angulo(math.cos(fx.rot), math.sin(fx.rot))) end     -- (de alrededor / propio: hacia donde mira el personaje)
  local area = factorArea(id, fx.x, fx.y)
  local previo = nil
  for _, c in ipairs(p.capas) do
    local suelo = c.w == "GC" or c.w == "GT"
    if (pasada == "suelo") == suelo then
      local d, img = Seqs[c.s], imagen(c.s)
      if img then
        local k, alfa = nil, c.a
        local u = t - c.t0
        local modo = c.modo
        if u >= 0 then
          if modo == "once" then
            k = math.floor(u / c.ms)
            if k >= d.n then k = nil end
          elseif modo == "loop" then
            if t <= (c.t1 or c.t0 + 1) then
              k = math.floor(u / c.ms) % d.n
              alfa = alfa * math.min(1, u / 0.12) * (1 - seg(t, (c.t1 or c.t0 + 1) - 0.25, c.t1 or c.t0 + 1))
            end
          elseif modo == "hold" then
            if t <= (c.t1 or c.t0 + 1) then
              k = math.min(d.n - 1, math.floor(u / c.ms))
              alfa = alfa * (1 - seg(t, (c.t1 or c.t0 + 1) - 0.3, c.t1 or c.t0 + 1))
            end
          elseif modo == "step" then
            if u <= (c.dur or 0.05) then k = 0 end
          elseif modo == "proj" then
            if t <= (c.t1 or c.t0 + 0.3) then k = 0 end
          elseif modo == "vuelo" then
            -- vuela del lanzador al objetivo repartiendo los cuadros a lo largo del trayecto (se forma al salir, se deshace al llegar)
            local fin = c.t1 or c.t0 + 0.4
            if t <= fin then k = math.min(d.n - 1, math.floor(limitar(u / math.max(0.01, fin - c.t0), 0, 1) * d.n)) end
          elseif modo == "caida" then
            -- cae desde el desplazamiento `off` (arriba, en el cielo) hasta el suelo del objetivo, acelerando; los cuadros van creciendo
            local fin = c.t1 or c.t0 + 0.5
            if t <= fin then
              k = math.min(d.n - 1, math.floor(u / ((fin - c.t0) / d.n)))
              alfa = alfa * math.min(1, u / 0.05)
            end
          elseif modo == "estela" then
            -- una estela de brasas que va de la mano al objetivo (los cuadros parpadean); entra y sale suave
            if t <= (c.t1 or c.t0 + 0.3) then
              k = math.floor(u / c.ms) % d.n
              alfa = alfa * math.min(1, u / 0.04) * (1 - seg(t, (c.t1 or c.t0 + 0.3) - 0.07, c.t1 or c.t0 + 0.3))
            end
          end
        end
        if k and modo == "estela" then
          -- estirada de la mano (pecho del lanzador) al pecho del objetivo: gira hacia él y su largo es la distancia; el grosor sigue la escala
          local x0, y0, x1, y1 = cx, cy - PECHO, sx, sy - PECHO * 0.62       -- (acaba en el centro del cuerpo del objetivo, más bajo que el pecho de un personaje: las criaturas son bajas)
          local largo = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
          if c.mezcla == "add" then love.graphics.setBlendMode("add") end
          love.graphics.setColor(1, 1, 1, limitar(alfa, 0, 1))
          love.graphics.draw(img, quad(c.s, k), x0, y0, math.atan2(y1 - y0, x1 - x0), largo / math.max(1, d.vw), K * c.sc, d.ox, d.oy)
          if c.mezcla == "add" then love.graphics.setBlendMode("alpha") end
        elseif k and modo == "caida" then
          local uu = limitar((t - c.t0) / math.max(0.01, (c.t1 or c.t0 + 0.5) - c.t0), 0, 1) ^ 1.6
          local ox, oy = (c.off and c.off[1] or 0) * K, (c.off and c.off[2] or -300) * K
          if c.mezcla == "add" then love.graphics.setBlendMode("add") end
          love.graphics.setColor(1, 1, 1, limitar(alfa, 0, 1))
          love.graphics.draw(img, quad(c.s, k), sx + ox * (1 - uu), sy - 8 + oy * (1 - uu), 0, K * c.sc, K * c.sc, d.ox, d.oy)
          if c.mezcla == "add" then love.graphics.setBlendMode("alpha") end
        elseif k then
          -- posición base
          local bx, by, esc = sx, sy, K * c.sc
          if c.w == "C" then bx, by = cx, cy - PECHO
          elseif c.w == "T" then bx, by = sx, sy - PECHO
          elseif c.w == "GC" then bx, by = cx, cy end
          if suelo then esc = esc * area end
          local ox, oy = 0, 0
          if c.off then ox, oy = c.off[1] * K * (suelo and area or 1), c.off[2] * K * (suelo and area or 1) end
          local espejo = c.flip or false
          local rotar = 0
          if modo == "vuelo" then
            local uu = limitar((t - c.t0) / math.max(0.01, (c.t1 or c.t0 + 0.4) - c.t0), 0, 1)
            bx = cx + (sx - cx) * uu
            by = (cy - PECHO) + ((sy - PECHO * 0.62) - (cy - PECHO)) * uu
            if c.giro == "libre" then
              rotar = math.rad(ang)                                   -- (apunta hacia donde va: lanzas, flechas)
            elseif c.giro == "espejo" then
              -- mira a izquierda o derecha según hacia dónde vuela y se inclina con la pendiente del tiro
              local izq = math.cos(math.rad(ang)) < 0
              local tilt = izq and (ang - 180) or ang
              tilt = ((tilt + 180) % 360) - 180
              rotar = math.rad(limitar(tilt, -60, 60))
              espejo = izq
            end
          end
          if c.dir then
            local n = d.n
            local frame, mir = cuadroDir(ang, n)
            if modo == "step" then
              -- el desplazamiento está pensado para th (derecha por defecto): se gira hasta la dirección real
              local giro = math.rad(ang - (c.th or 0))
              ox, oy = ox * math.cos(giro) - oy * math.sin(giro), ox * math.sin(giro) + oy * math.cos(giro)
            end
            if modo == "proj" then
              local uu = limitar((t - c.t0) / math.max(0.01, (c.t1 - c.t0)), 0, 1)
              local giro = math.rad(ang)
              ox, oy = ox * math.cos(giro) - oy * math.sin(giro), ox * math.sin(giro) + oy * math.cos(giro)
              bx = cx + (sx - cx) * uu
              by = (cy - PECHO) + ((sy - PECHO) - (cy - PECHO)) * uu
            end
            k = frame
            if mir ~= espejo then espejo = true else espejo = false end
          elseif modo == "proj" then
            local uu = limitar((t - c.t0) / math.max(0.01, (c.t1 - c.t0)), 0, 1)
            bx = cx + (sx - cx) * uu
            by = (cy - PECHO) + ((sy - PECHO) - (cy - PECHO)) * uu
            k = math.floor((t - c.t0) / c.ms) % d.n
          elseif modo == "step" then
            k = 0
          end
          local ax, ay = d.ox, d.oy
          if c.w == "C" or c.w == "T" then ax, ay = centro(c.s) end
          local sxe = esc
          if espejo then ax = d.w - ax sxe = -esc end
          if c.mezcla == "add" then love.graphics.setBlendMode("add") end
          love.graphics.setColor(1, 1, 1, limitar(alfa, 0, 1))
          love.graphics.draw(img, quad(c.s, k), bx + ox, by + oy, rotar, sxe, esc, ax, ay)
          if c.mezcla == "add" then love.graphics.setBlendMode("alpha") end
        end
      end
    end
  end
  love.graphics.setBlendMode("alpha")
end

function M.tieneSuelo(id)
  local p = Poderes[id]
  if not p then return false end
  for _, c in ipairs(p.capas) do if c.w == "GC" or c.w == "GT" then return true end end
  return false
end

-- Miniatura para la barra de poderes: un cuadro de la capa más grande, centrado en el cuadrado.
function M.icono(id, x, y, lado)
  local p = Poderes[id]
  if not p then return end
  local mejor, ma = nil, -1
  for _, c in ipairs(p.capas) do
    local d = Seqs[c.s]
    local a = d.vw * d.vh * c.sc * c.sc
    if a > ma and imagen(c.s) then mejor, ma = c, a end
  end
  if not mejor then return end
  local d = Seqs[mejor.s]
  local k = (mejor.dir and math.floor(d.n / 2)) or math.floor(d.n * 0.45)
  if d.n > 1 and d.n <= 5 and mejor.s:find("__impacto$") then k = 1 end         -- (los estallidos cortos del mago: el segundo cuadro es el más lleno)
  local esc = lado / math.max(d.vw, d.vh) * 0.9
  local cx, cy = centro(mejor.s)
  love.graphics.setBlendMode("add")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(imagen(mejor.s), quad(mejor.s, k), x + lado / 2, y + lado / 2, 0, esc, esc, cx, cy)
  love.graphics.setBlendMode("alpha")
end

return M
