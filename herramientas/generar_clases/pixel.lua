-- Motor mínimo de pixel-art para las herramientas que dibujan sprites a mano (personajes, esbirros e
-- iconos de equipo). Un cuadro es una rejilla de píxeles RGBA; las formas se rellenan con tres tonos
-- (luz, base y sombra, con la luz arriba a la izquierda) y al final se les pone un contorno oscuro de un
-- tono parecido al de la propia forma, como en los sprites del pack.
local P = {}

local floor, ceil, max, min, abs = math.floor, math.ceil, math.max, math.min, math.abs

function P.nuevo(w, h)
  return { w = w, h = h, p = {} }
end

function P.copia(f)
  local c = P.nuevo(f.w, f.h)
  for k, v in pairs(f.p) do c.p[k] = v end
  return c
end

function P.poner(f, x, y, c)
  x, y = floor(x), floor(y)
  if x >= 0 and y >= 0 and x < f.w and y < f.h then f.p[y * f.w + x] = c end
end

function P.leer(f, x, y)
  if x < 0 or y < 0 or x >= f.w or y >= f.h then return nil end
  return f.p[y * f.w + x]
end

-- Paleta de tres tonos a partir de un color base: { base, sombra, luz }.
function P.pal(r, g, b, a)
  a = a or 1
  -- [1] base, [2] sombra, [3] luz, [4] brillo, [5] sombra profunda
  return {
    { r, g, b, a },
    { r * 0.66, g * 0.62, min(1, b * 0.76 + 0.03), a },
    { min(1, r + (1 - r) * 0.32), min(1, g + (1 - g) * 0.32), min(1, b + (1 - b) * 0.30), a },
    { min(1, r + (1 - r) * 0.68), min(1, g + (1 - g) * 0.68), min(1, b + (1 - b) * 0.66), a },
    { r * 0.38, g * 0.34, min(1, b * 0.5 + 0.05), a },
  }
end

function P.mezcla(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, (a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * t }
end

local function tono(pal, s)
  if pal[4] then
    if s < -0.78 then return pal[4] end
    if s < -0.28 then return pal[3] end
    if s < 0.32 then return pal[1] end
    if s < 0.72 then return pal[2] end
    return pal[5]
  end
  if s < -0.42 then return pal[3] end
  if s > 0.42 then return pal[2] end
  return pal[1]
end

-- Elipse rellena con sombreado.
function P.elipse(f, cx, cy, rx, ry, pal)
  for y = floor(cy - ry), ceil(cy + ry) do
    for x = floor(cx - rx), ceil(cx + rx) do
      local dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
      if dx * dx + dy * dy <= 1 then
        P.poner(f, x, y, tono(pal, dx * 0.55 + dy * 0.85))
      end
    end
  end
end

-- Rectángulo con sombreado vertical (luz a la izquierda, sombra a la derecha) o plano.
function P.rect(f, x0, y0, x1, y1, pal, plano)
  -- un color suelto en lugar de una paleta se pinta plano
  if type(pal[1]) == "number" then pal, plano = { pal, pal, pal }, true end
  local ancho = max(1, x1 - x0 + 1)
  for y = y0, y1 do
    for x = x0, x1 do
      local c = pal[1]
      if not plano then
        local u = (x - x0) / ancho
        if ancho >= 3 then
          if u < 0.2 then c = pal[4] or pal[3] elseif u < 0.38 then c = pal[3]
          elseif u >= 0.84 then c = pal[5] or pal[2] elseif u >= 0.64 then c = pal[2] end
        end
      end
      P.poner(f, x, y, c)
    end
  end
end

-- Polígono relleno (pares de coordenadas) con un tono (sombreado según la altura del píxel si pal es paleta).
function P.poli(f, pts, pal, sombrear)
  local ymin, ymax = 1e9, -1e9
  for i = 2, #pts, 2 do ymin = min(ymin, pts[i]); ymax = max(ymax, pts[i]) end
  local xmin, xmax = 1e9, -1e9
  for i = 1, #pts, 2 do xmin = min(xmin, pts[i]); xmax = max(xmax, pts[i]) end
  local n = #pts / 2
  for y = floor(ymin), ceil(ymax) do
    local yc = y + 0.5
    local xs = {}
    for i = 1, n do
      local j = i % n + 1
      local x1, y1, x2, y2 = pts[i * 2 - 1], pts[i * 2], pts[j * 2 - 1], pts[j * 2]
      if (y1 <= yc and y2 > yc) or (y2 <= yc and y1 > yc) then
        xs[#xs + 1] = x1 + (yc - y1) * (x2 - x1) / (y2 - y1)
      end
    end
    table.sort(xs)
    for k = 1, #xs - 1, 2 do
      for x = floor(xs[k] + 0.5), ceil(xs[k + 1] - 0.5) - 1 do
        local c = pal
        if pal[1] and type(pal[1]) == "table" then
          local u = (x + 0.5 - xmin) / max(1, xmax - xmin)
          local v = (yc - ymin) / max(1, ymax - ymin)
          c = tono(pal, (u - 0.5) * 0.9 + (v - 0.5) * 0.9)
          if not sombrear then c = pal[1] end
        end
        P.poner(f, x, y, c)
      end
    end
  end
end

function P.linea(f, x0, y0, x1, y1, c)
  x0, y0, x1, y1 = floor(x0), floor(y0), floor(x1), floor(y1)
  local dx, dy = abs(x1 - x0), -abs(y1 - y0)
  local sx, sy = x0 < x1 and 1 or -1, y0 < y1 and 1 or -1
  local err = dx + dy
  while true do
    P.poner(f, x0, y0, c)
    if x0 == x1 and y0 == y1 then break end
    local e2 = 2 * err
    if e2 >= dy then err = err + dy; x0 = x0 + sx end
    if e2 <= dx then err = err + dx; y0 = y0 + sy end
  end
end

-- Línea gruesa (ancho 2): pinta también el píxel vecino.
function P.lineaGruesa(f, x0, y0, x1, y1, c, c2)
  P.linea(f, x0, y0, x1, y1, c)
  P.linea(f, x0 + 1, y0, x1 + 1, y1, c2 or c)
end

-- Contorno: cada píxel vacío pegado a uno pintado toma el color de ese vecino oscurecido.
function P.contorno(f, factor)
  factor = factor or 0.3
  local nuevo = {}
  for y = 0, f.h - 1 do
    for x = 0, f.w - 1 do
      if not f.p[y * f.w + x] then
        local mejor, lum
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
          local c = P.leer(f, x + d[1], y + d[2])
          if c and (c[4] or 1) > 0.3 then
            local l = c[1] + c[2] + c[3]
            if not lum or l < lum then mejor, lum = c, l end
          end
        end
        if mejor then
          nuevo[y * f.w + x] = { mejor[1] * factor, mejor[2] * factor * 0.92, min(1, mejor[3] * factor * 1.15 + 0.02), min(1, (mejor[4] or 1) + 0.15) }
        end
      end
    end
  end
  for k, v in pairs(nuevo) do f.p[k] = v end
end

-- Luz de borde: los píxeles del límite de la silueta se oscurecen abajo y a la derecha y se aclaran arriba y a
-- la izquierda (luz desde arriba a la izquierda), que es lo que da volumen a los iconos del pack.
function P.volumen(f, oscuro, claro)
  oscuro, claro = oscuro or 0.72, claro or 0.26
  local nuevo = {}
  for y = 0, f.h - 1 do
    for x = 0, f.w - 1 do
      local c = f.p[y * f.w + x]
      if c then
        local arriba, izq = not P.leer(f, x, y - 1), not P.leer(f, x - 1, y)
        local abajo, der = not P.leer(f, x, y + 1), not P.leer(f, x + 1, y)
        if abajo or der then
          nuevo[y * f.w + x] = { c[1] * oscuro, c[2] * oscuro, c[3] * oscuro, c[4] }
        elseif arriba or izq then
          nuevo[y * f.w + x] = { c[1] + (1 - c[1]) * claro, c[2] + (1 - c[2]) * claro, c[3] + (1 - c[3]) * claro, c[4] }
        end
      end
    end
  end
  for k, v in pairs(nuevo) do f.p[k] = v end
end

-- Puntos sueltos (remaches, destellos) con un color.
function P.puntos(f, lista, c)
  for _, q in ipairs(lista) do P.poner(f, q[1], q[2], c) end
end

-- Espeja un cuadro de izquierda a derecha.
function P.espejo(f)
  local c = P.nuevo(f.w, f.h)
  for y = 0, f.h - 1 do
    for x = 0, f.w - 1 do
      c.p[y * f.w + x] = f.p[y * f.w + (f.w - 1 - x)]
    end
  end
  return c
end

-- Copia un cuadro dentro de una imagen en (ox, oy).
function P.volcar(datos, f, ox, oy)
  for y = 0, f.h - 1 do
    for x = 0, f.w - 1 do
      local c = f.p[y * f.w + x]
      if c then datos:setPixel(ox + x, oy + y, c[1], c[2], c[3], c[4] or 1) end
    end
  end
end

return P
