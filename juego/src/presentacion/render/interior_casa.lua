-- Interior de la casa: pared del fondo de yeso con zócalo de madera, ventanas con cortinas y haces de luz, sombras junto a los
-- muros, vetas del parquet y una alfombra bajo la mesa. Devuelve true si dibujó la casilla (si no, el terreno usa su arte normal).
local M = {}
local TILE = 32

local function hash(x, y, sal)
  local n = (x * 73856093 + y * 19349663 + (sal or 0) * 83492791) % 2147483647
  n = (n * 1103515245 + 12345) % 2147483647
  return (n % 10007) / 10007
end

local function suelo(mapa, x, y, px, py)
  local w, h = mapa.w, mapa.h
  local r = hash(x, y, 71)
  love.graphics.setColor(r < 0.5 and 0 or 1, r < 0.5 and 0 or 0.85, r < 0.5 and 0 or 0.6, 0.05 + 0.07 * math.abs(r - 0.5))
  love.graphics.rectangle("fill", px, py, TILE, TILE)
  if hash(x, y, 72) < 0.25 then
    love.graphics.setColor(0, 0, 0, 0.10)
    love.graphics.rectangle("fill", px + 4 + hash(x, y, 73) * 18, py + 3, 1, 26)
  end
  -- sombra junto a los muros
  if y == 1 then
    for i = 0, 11 do
      love.graphics.setColor(0.05, 0.02, 0, 0.42 * (1 - i / 12))
      love.graphics.rectangle("fill", px, py + i, TILE, 1)
    end
  end
  if x == 1 then
    for i = 0, 7 do
      love.graphics.setColor(0.05, 0.02, 0, 0.28 * (1 - i / 8))
      love.graphics.rectangle("fill", px + i, py, 1, TILE)
    end
  end
  if x == w - 2 then
    for i = 0, 7 do
      love.graphics.setColor(0.05, 0.02, 0, 0.28 * (1 - i / 8))
      love.graphics.rectangle("fill", px + TILE - 1 - i, py, 1, TILE)
    end
  end
  if y == h - 2 then
    for i = 0, 6 do
      love.graphics.setColor(0.05, 0.02, 0, 0.22 * (1 - i / 7))
      love.graphics.rectangle("fill", px, py + TILE - 1 - i, TILE, 1)
    end
  end
  -- haces de luz de las ventanas del fondo
  for _, vx in ipairs({ 5, w - 6 }) do
    if y >= 1 and y <= 4 and x >= vx - 1 and x <= vx + 1 then
      local k = (y - 1) / 4
      love.graphics.setColor(1, 0.92, 0.6, 0.13 * (1 - k * 0.7))
      if x == vx - 1 then love.graphics.polygon("fill", px + 12, py, px + TILE, py, px + TILE, py + TILE, px + 20, py + TILE) end
      if x == vx then love.graphics.rectangle("fill", px, py, TILE, TILE) end
      if x == vx + 1 then love.graphics.polygon("fill", px, py, px + 20, py, px + 28, py + TILE, px, py + TILE) end
    end
  end
  -- alfombra bajo la mesa: anillo exterior granate, hilo dorado por dentro y campo con rombos
  local cx, cy = mapa.muebles.mesa.x, mapa.muebles.mesa.y
  local function anillo(tx, ty)
    local ax, ay = tx + 0.5 - cx, ty + 0.5 - cy
    return math.abs(ax) > 3.5 or math.abs(ay) > 2
  end
  local ax, ay = x + 0.5 - cx, y + 0.5 - cy
  if math.abs(ax) <= 4.5 and math.abs(ay) <= 3 then
    if anillo(x, y) then
      if math.abs(ax) <= 4 and math.abs(ay) <= 3 then
        love.graphics.setColor(0.36, 0.08, 0.1, 1)
        love.graphics.rectangle("fill", px, py, TILE, TILE)
        love.graphics.setColor(0.78, 0.62, 0.28, 1)
        if not anillo(x, y - 1) then love.graphics.rectangle("fill", px, py + TILE - 3, TILE, 2) end
        if not anillo(x, y + 1) then love.graphics.rectangle("fill", px, py + 1, TILE, 2) end
        if not anillo(x - 1, y) then love.graphics.rectangle("fill", px + TILE - 3, py, 2, TILE) end
        if not anillo(x + 1, y) then love.graphics.rectangle("fill", px + 1, py, 2, TILE) end
      end
    else
      love.graphics.setColor(0.55, 0.12, 0.12, 1)
      love.graphics.rectangle("fill", px, py, TILE, TILE)
      love.graphics.setColor(0.78, 0.62, 0.28, 0.55)
      love.graphics.polygon("line", px + 16, py + 6, px + 26, py + 16, px + 16, py + 26, px + 6, py + 16)
      love.graphics.setColor(0.78, 0.62, 0.28, 1)
      if anillo(x, y - 1) then love.graphics.rectangle("fill", px, py, TILE, 2) end
      if anillo(x, y + 1) then love.graphics.rectangle("fill", px, py + TILE - 2, TILE, 2) end
      if anillo(x - 1, y) then love.graphics.rectangle("fill", px, py, 2, TILE) end
      if anillo(x + 1, y) then love.graphics.rectangle("fill", px + TILE - 2, py, 2, TILE) end
    end
  end
end

local function paredFondo(mapa, x, y, px, py)
  local w = mapa.w
  love.graphics.setColor(0.86, 0.78, 0.64, 1)
  love.graphics.rectangle("fill", px, py, TILE, TILE)
  love.graphics.setColor(0.7, 0.6, 0.46, 0.35)
  love.graphics.rectangle("fill", px + 7 + hash(x, y, 81) * 14, py + 4, 1, 10)
  love.graphics.setColor(0.42, 0.27, 0.15, 1)
  love.graphics.rectangle("fill", px, py + 15, TILE, 17)
  love.graphics.setColor(0.52, 0.34, 0.19, 1)
  love.graphics.rectangle("fill", px + 2, py + 18, TILE - 4, 11)
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.rectangle("line", px + 2.5, py + 18.5, TILE - 5, 10)
  love.graphics.setColor(1, 1, 1, 0.16)
  love.graphics.rectangle("fill", px + 3, py + 19, TILE - 6, 1)
  love.graphics.setColor(0.3, 0.19, 0.1, 1)
  love.graphics.rectangle("fill", px, py + 14, TILE, 2)
  love.graphics.setColor(1, 1, 1, 0.22)
  love.graphics.rectangle("fill", px, py + 14, TILE, 1)
  love.graphics.setColor(0.22, 0.13, 0.07, 1)
  love.graphics.rectangle("fill", px, py, TILE, 3)
  love.graphics.setColor(1, 1, 1, 0.18)
  love.graphics.rectangle("fill", px, py + 3, TILE, 1)
  love.graphics.setColor(0.18, 0.1, 0.05, 1)
  love.graphics.rectangle("fill", px, py + TILE - 4, TILE, 4)
  love.graphics.setColor(1, 1, 1, 0.14)
  love.graphics.rectangle("fill", px, py + TILE - 4, TILE, 1)
  for _, vx in ipairs({ 5, w - 6 }) do
    if x == vx then
      love.graphics.setColor(0.2, 0.12, 0.06, 1)
      love.graphics.rectangle("fill", px + 4, py + 2, 24, 26)
      love.graphics.setColor(0.55, 0.8, 0.95, 1)
      love.graphics.rectangle("fill", px + 6, py + 4, 20, 20)
      love.graphics.setColor(0.85, 0.95, 1, 1)
      love.graphics.rectangle("fill", px + 6, py + 4, 20, 8)
      love.graphics.setColor(1, 1, 1, 0.6)
      love.graphics.polygon("fill", px + 8, py + 22, px + 14, py + 22, px + 20, py + 6, px + 14, py + 6)
      love.graphics.setColor(0.2, 0.12, 0.06, 1)
      love.graphics.rectangle("fill", px + 15, py + 4, 2, 20)
      love.graphics.rectangle("fill", px + 6, py + 13, 20, 2)
      love.graphics.setColor(0.62, 0.12, 0.14, 1)
      love.graphics.polygon("fill", px + 4, py + 2, px + 11, py + 2, px + 9, py + 27, px + 4, py + 27)
      love.graphics.polygon("fill", px + 28, py + 2, px + 21, py + 2, px + 23, py + 27, px + 28, py + 27)
      love.graphics.setColor(0, 0, 0, 0.22)
      love.graphics.rectangle("fill", px + 7, py + 3, 1, 24)
      love.graphics.rectangle("fill", px + 24, py + 3, 1, 24)
      love.graphics.setColor(0.8, 0.65, 0.3, 1)
      love.graphics.rectangle("fill", px + 3, py, 26, 2)
    end
  end
end

function M.interior(mapa, x, y, px, py, tipo)
  if not mapa.muebles or not mapa.w then return false end
  local w, h = mapa.w, mapa.h
  if tipo == "madera" then
    suelo(mapa, x, y, px, py)
    return true
  end
  if y == 0 then
    paredFondo(mapa, x, y, px, py)
    return true
  end
  if y == h - 1 and x == math.floor(w / 2) then
    -- vano de la puerta: umbral de madera y jambas
    love.graphics.setColor(0.12, 0.09, 0.07, 1)
    love.graphics.rectangle("fill", px, py, TILE, TILE)
    love.graphics.setColor(0.45, 0.3, 0.16, 1)
    love.graphics.rectangle("fill", px + 3, py, TILE - 6, 6)
    love.graphics.setColor(0.3, 0.19, 0.1, 1)
    love.graphics.rectangle("fill", px, py, 4, TILE)
    love.graphics.rectangle("fill", px + TILE - 4, py, 4, TILE)
    love.graphics.setColor(1, 0.92, 0.7, 0.18)
    love.graphics.rectangle("fill", px + 4, py + 6, TILE - 8, TILE - 6)
    return true
  end
  return false
end


-- Paredes levantadas de la vista isométrica: las dos paredes del fondo (la de arriba a la derecha, con sus ventanas, y la de arriba a la
-- izquierda) se dibujan como paneles verticales sobre el borde del suelo. Se pintan antes que los muebles y los personajes.
local Iso = require("src.presentacion.render.iso")
local ALTO_PARED = 78

local function panel(ax, ay, bx, by, cam, h, col, colZ)
  local x1, y1 = Iso.suelo(ax, ay)
  local x2, y2 = Iso.suelo(bx, by)
  x1, y1, x2, y2 = x1 - cam.x, y1 - cam.y, x2 - cam.x, y2 - cam.y
  local zoc = h * 0.34
  -- friso de madera abajo y yeso arriba
  love.graphics.setColor(colZ[1], colZ[2], colZ[3], 1)
  love.graphics.polygon("fill", x1, y1, x2, y2, x2, y2 - zoc, x1, y1 - zoc)
  love.graphics.setColor(col[1], col[2], col[3], 1)
  love.graphics.polygon("fill", x1, y1 - zoc, x2, y2 - zoc, x2, y2 - h, x1, y1 - h)
  love.graphics.setColor(0.2, 0.12, 0.06, 1)
  love.graphics.setLineWidth(2)
  love.graphics.line(x1, y1 - zoc, x2, y2 - zoc)
  love.graphics.line(x1, y1 - h, x2, y2 - h)
  love.graphics.setLineWidth(1)
  return x1, y1, x2, y2
end

function M.paredesIso(mapa, cam)
  if not Iso.activo() or not mapa.muebles or not mapa.w then return end
  local w, h = mapa.w, mapa.h
  local yeso, madera = { 0.86, 0.78, 0.64 }, { 0.46, 0.30, 0.17 }
  -- pared de arriba a la izquierda (columna x = 0): se ve su cara que mira hacia abajo a la derecha
  for y = 0, h - 2 do
    panel(1, y, 1, y + 1, cam, ALTO_PARED, { 0.74, 0.66, 0.53 }, { 0.38, 0.25, 0.14 })
  end
  -- pared de arriba a la derecha (fila y = 0), con sus dos ventanas con cortinas
  for x = 0, w - 2 do
    local x1, y1, x2, y2 = panel(x, 1, x + 1, 1, cam, ALTO_PARED, yeso, madera)
    for _, vx in ipairs({ 5, w - 6 }) do
      if x == vx then
        local mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        local a, b = (x2 - x1) * 0.3, (y2 - y1) * 0.3
        love.graphics.setColor(0.2, 0.12, 0.06, 1)
        love.graphics.polygon("fill", mx - a - 3, my - b - 26, mx + a + 3, my + b - 26, mx + a + 3, my + b - 66, mx - a - 3, my - b - 66)
        love.graphics.setColor(0.6, 0.82, 0.96, 1)
        love.graphics.polygon("fill", mx - a, my - b - 29, mx + a, my + b - 29, mx + a, my + b - 63, mx - a, my - b - 63)
        love.graphics.setColor(0.62, 0.12, 0.14, 1)
        love.graphics.polygon("fill", mx - a - 3, my - b - 26, mx - a * 0.4, my - b * 0.4 - 26, mx - a * 0.4, my - b * 0.4 - 66, mx - a - 3, my - b - 66)
        love.graphics.polygon("fill", mx + a + 3, my + b - 26, mx + a * 0.4, my + b * 0.4 - 26, mx + a * 0.4, my + b * 0.4 - 66, mx + a + 3, my + b - 66)
      end
    end
  end
end

return M
