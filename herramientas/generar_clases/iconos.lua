-- Iconos de objetos de las clases nuevas (32 x 32) para la lámina equipo_extra.png: 16 columnas x 6 filas; el
-- índice de un icono es fila * 16 + columna.
--   0..7   lanza (8 escalones)          8..15  alabarda
--   16..23 báculo del nigromante        24..31 grimorio
--   32..39 casco del lancero            40..47 coraza          48..55 grebas          56..63 botas
--   64..71 capucha del nigromante       72..79 túnica          80..87 faldón          88..95 botas
-- Para que tengan exactamente el arte de los demás objetos, salen de iconos de la lámina del pack
-- (otsp_equipment_01.png) elegidos de menos a más vistosos y recoloreados por escalón: el lancero hacia el
-- acero azulado y el dorado, el nigromante hacia tonos oscuros (morado, índigo, carmesí, verde azulado).
local I = {}

-- Selección: icono del pack y ajuste de color de cada escalón.
-- ajuste = { h = giro de tono (0..1), s = saturación x, v = brillo x, tinte = {r,g,b}, fuerza = mezcla del tinte en los
-- grises (metal) }. Sin ajuste, el icono se copia tal cual.
local ACERO_AZUL, CIAN = { 0.55, 0.72, 1.0 }, { 0.45, 0.95, 0.95 }
local INDIGO, VERDEAZ, ROJO = { 0.30, 0.30, 0.85 }, { 0.1, 0.6, 0.6 }, { 0.85, 0.12, 0.1 }

local SELECCION = {
  -- lanza: lanzas del pack, de la más sencilla a las doradas
  { 0, { { 210 }, { 216 }, { 230 }, { 368 },
    { 216, { tinte = CIAN, fuerza = 0.6, v = 1.15 } }, { 261 }, { 351 }, { 368, { h = -0.02, s = 1.4, v = 1.2 } } } },
  -- alabarda: hachas de asta larga
  { 8, { { 218 }, { 264 }, { 265 }, { 273 },
    { 263 }, { 217, { tinte = CIAN, fuerza = 0.5, v = 1.2 } }, { 259 }, { 253 } } },
  -- báculo del nigromante: báculos verdes y de cristal llevados a morados
  { 16, { { 342, { h = 0.5, s = 0.8 } }, { 343, { h = 0.5 } }, { 344, { h = 0.5, s = 1.2 } }, { 340, { h = 0.12 } },
    { 341, { h = 0.2 } }, { 363 }, { 364, { h = 0.4 } }, { 366 } } },
  -- grimorio: libros
  { 24, { { 339 }, { 348 }, { 349, { h = 0.78 } }, { 370, { tinte = INDIGO, fuerza = 0.5 } },
    { 349, { h = 0.95, s = 1.2 } }, { 349, { h = 0.5 } }, { 349 }, { 371 } } },
  -- casco del lancero: cascos con alas y cimeras
  { 32, { { 460, { s = 0.5, v = 0.9 } }, { 465 }, { 466 }, { 483 },
    { 449 }, { 482, { tinte = CIAN, fuerza = 0.5, v = 1.2 } }, { 444 }, { 452 } } },
  -- coraza del lancero: petos de placas
  { 40, { { 544, { s = 0.6 } }, { 560 }, { 577 }, { 592 },
    { 585 }, { 596, { tinte = CIAN, fuerza = 0.5, v = 1.15 } }, { 517 }, { 525 } } },
  -- grebas del lancero
  { 48, { { 624, { s = 0.5 } }, { 632 }, { 628 }, { 625 },
    { 636 }, { 633, { tinte = CIAN, fuerza = 0.4 } }, { 627 }, { 629 } } },
  -- botas del lancero
  { 56, { { 666, { s = 0.6 } }, { 663 }, { 667 }, { 658 },
    { 668 }, { 664 }, { 665 }, { 662 } } },
  -- capucha del nigromante: capuchas con tintes oscuros
  { 64, { { 455, { s = 0.4, v = 0.8 } }, { 432, { s = 0.5, v = 0.7 } }, { 432, { h = 0.45, s = 0.9 } }, { 439, { tinte = INDIGO, fuerza = 0.45 } },
    { 494, { h = 0.72 } }, { 432, { h = 0.3, s = 1.4, v = 0.9 } }, { 439, { tinte = ROJO, fuerza = 0.55 } }, { 439, { v = 0.55, s = 0.8 } } } },
  -- túnica del nigromante
  { 72, { { 522, { s = 0.5, v = 0.85 } }, { 519, { s = 0.5, v = 0.8 } }, { 539 }, { 567, { h = 0.03 } },
    { 566, { h = 0.95 } }, { 540, { h = 0.35, s = 1.1 } }, { 527, { s = 1.3 } }, { 521, { v = 0.8 } } } },
  -- faldón del nigromante
  { 80, { { 626, { s = 0.5, v = 0.8 } }, { 632, { s = 0.6, v = 0.8 } }, { 638 }, { 625 },
    { 631, { h = 0.9, s = 1.2 } }, { 631, { h = 0.45, s = 1.3 } }, { 626, { tinte = ROJO, fuerza = 0.6 } }, { 638, { v = 0.6 } } } },
  -- botas del nigromante
  { 88, { { 657, { s = 0.5, v = 0.8 } }, { 656, { s = 0.5, v = 0.8 } }, { 661 }, { 658, { h = 0.05 } },
    { 660, { h = 0.9, s = 1.1 } }, { 659, { h = 0.45, s = 1.2 } }, { 665, { tinte = ROJO, fuerza = 0.5 } }, { 661, { v = 0.6 } } } },
}

-- ------------------------------------------------------------------------------------------ color
local function rgb2hsv(r, g, b)
  local mx, mn = math.max(r, g, b), math.min(r, g, b)
  local d = mx - mn
  local h = 0
  if d > 0 then
    if mx == r then h = ((g - b) / d) % 6
    elseif mx == g then h = (b - r) / d + 2
    else h = (r - g) / d + 4 end
    h = h / 6
  end
  return h, (mx == 0) and 0 or d / mx, mx
end

local function hsv2rgb(h, s, v)
  h = h % 1
  local i = math.floor(h * 6)
  local f = h * 6 - i
  local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
  i = i % 6
  if i == 0 then return v, t, p elseif i == 1 then return q, v, p elseif i == 2 then return p, v, t
  elseif i == 3 then return p, q, v elseif i == 4 then return t, p, v else return v, p, q end
end

local function ajustar(r, g, b, aj)
  if not aj then return r, g, b end
  local h, s, v = rgb2hsv(r, g, b)
  if aj.tinte and s < 0.28 then
    -- metal y tela grises: toman el tinte conservando la luz
    local lum = r * 0.3 + g * 0.59 + b * 0.11
    local k = (aj.fuerza or 0.5)
    local t = aj.tinte
    r, g, b = r + (lum * t[1] * 1.5 - r) * k, g + (lum * t[2] * 1.5 - g) * k, b + (lum * t[3] * 1.5 - b) * k
    r, g, b = math.min(1, r), math.min(1, g), math.min(1, b)
    h, s, v = rgb2hsv(r, g, b)
  end
  h = h + (aj.h or 0)
  s = math.min(1, s * (aj.s or 1))
  v = math.min(1, v * (aj.v or 1))
  return hsv2rgb(h, s, v)
end

-- ------------------------------------------------------------------------------------------ hoja
function I.generar(raiz, guardar)
  local fh = assert(io.open(raiz .. "juego/arte/hojas/otsp_equipment_01.png", "rb"))
  local bytes = fh:read("*a")
  fh:close()
  local pack = love.image.newImageData(love.filesystem.newFileData(bytes, "pack.png"))
  local datos = love.image.newImageData(512, 192)
  for _, grupo in ipairs(SELECCION) do
    for t = 1, 8 do
      local origen, aj = grupo[2][t][1], grupo[2][t][2]
      local idx = grupo[1] + t - 1
      local sx, sy = (origen % 16) * 32, math.floor(origen / 16) * 32
      local dx, dy = (idx % 16) * 32, math.floor(idx / 16) * 32
      for y = 0, 31 do
        for x = 0, 31 do
          local r, g, b, a = pack:getPixel(sx + x, sy + y)
          -- el magenta de la lámina es transparente
          if a > 0.1 and not (r > 0.97 and g < 0.05 and b > 0.97) then
            local nr, ng, nb = ajustar(r, g, b, aj)
            datos:setPixel(dx + x, dy + y, nr, ng, nb, a)
          end
        end
      end
    end
  end
  guardar(datos, raiz .. "juego/arte/hojas/equipo_extra.png")
  -- vista previa x3 sobre fondo oscuro
  local img = love.graphics.newImage(datos)
  img:setFilter("nearest", "nearest")
  local cv = love.graphics.newCanvas(512 * 3, 192 * 3)
  love.graphics.setCanvas(cv)
  love.graphics.clear(0.18, 0.2, 0.26, 1)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(img, 0, 0, 0, 3, 3)
  love.graphics.setCanvas()
  local fp = io.open(os.getenv("TEMP") .. "/iconos_previa.png", "wb")
  fp:write(cv:newImageData():encode("png"):getString())
  fp:close()
end

return I
