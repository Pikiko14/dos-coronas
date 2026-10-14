-- Iconos de los cuatro botones bajo el minimapa (mapa, ayuda, menú, recompensa diaria), en píxeles con el mismo
-- motor que el resto de sprites. Hoja de 128 x 32: cuatro iconos de 32 x 32 en fila, en ese orden.
local P = require("pixel")
local pal, poli, linea, elipse, rect, poner = P.pal, P.poli, P.linea, P.elipse, P.rect, P.poner

local H = {}

local function acabar(f)
  P.contorno(f, 0.17)
  P.volumen(f)
  return f
end

-- Mapa: pergamino plegado en tres paneles con río, isla verde, camino punteado y una X roja.
local function mapa()
  local f = P.nuevo(32, 32)
  local papel = pal(0.90, 0.80, 0.55)
  local paneles = { { 3, 11 }, { 11, 21 }, { 21, 29 } }
  for i, q in ipairs(paneles) do
    local dy = (i == 2) and 0 or 2
    poli(f, { q[1], 6 + dy, q[2], 6 + (i == 2 and 0 or (i == 1 and 2 or 2)) - (i == 2 and 0 or 0), q[2], 26 - dy, q[1], 26 - dy }, i == 2 and papel or pal(0.80, 0.68, 0.42), true)
  end
  -- mar azul en la esquina y río
  poli(f, { 4, 9, 10, 9, 10, 15, 4, 17 }, pal(0.30, 0.55, 0.85), true)
  linea(f, 14, 7, 15, 11, { 0.3, 0.55, 0.85, 1 })
  linea(f, 15, 11, 17, 15, { 0.3, 0.55, 0.85, 1 })
  linea(f, 17, 15, 17, 25, { 0.3, 0.55, 0.85, 1 })
  -- isla / bosque verde
  elipse(f, 24, 19, 4, 3, pal(0.35, 0.65, 0.30))
  elipse(f, 13, 21, 3, 2, pal(0.35, 0.65, 0.30))
  -- camino punteado hasta la X
  for _, q in ipairs({ { 7, 22 }, { 10, 20 }, { 13, 18 }, { 17, 17 }, { 20, 14 } }) do poner(f, q[1], q[2], { 0.45, 0.25, 0.1, 1 }) end
  local rojo = { 0.85, 0.12, 0.1, 1 }
  linea(f, 21, 9, 26, 14, rojo) linea(f, 26, 9, 21, 14, rojo)
  linea(f, 22, 9, 27, 14, rojo) linea(f, 27, 9, 22, 14, rojo)
  return acabar(f)
end

-- Ayuda: insignia azul redonda con borde dorado y un "?" blanco de píxeles.
local function ayuda()
  local f = P.nuevo(32, 32)
  elipse(f, 16, 16, 12, 12, pal(0.88, 0.7, 0.2))
  elipse(f, 16, 16, 10, 10, pal(0.25, 0.45, 0.9))
  local glifo = {
    "01110",
    "10001",
    "00001",
    "00010",
    "00100",
    "00000",
    "00100",
  }
  local blanco = { 1, 1, 1, 1 }
  for gy = 1, 7 do
    for gx = 1, 5 do
      if glifo[gy]:sub(gx, gx) == "1" then
        local x, y = 11 + (gx - 1) * 2, 8 + (gy - 1) * 2
        poner(f, x, y, blanco) poner(f, x + 1, y, blanco) poner(f, x, y + 1, blanco) poner(f, x + 1, y + 1, blanco)
      end
    end
  end
  return acabar(f)
end

-- Menú: engranaje de acero con ocho dientes y el agujero oscuro en el centro.
local function menu()
  local f = P.nuevo(32, 32)
  local acero = pal(0.66, 0.7, 0.78)
  for i = 0, 7 do
    local a = i * math.pi / 4
    local cx, cy = 16 + math.cos(a) * 11, 16 + math.sin(a) * 11
    elipse(f, cx, cy, 3, 3, acero)
  end
  elipse(f, 16, 16, 10, 10, acero)
  elipse(f, 16, 16, 7, 7, pal(0.55, 0.6, 0.7))
  elipse(f, 16, 16, 4, 4, pal(0.12, 0.14, 0.2))
  return acabar(f)
end

-- Recompensa diaria: caja de regalo roja con lazo dorado y destellos.
local function diaria()
  local f = P.nuevo(32, 32)
  local rojo, oro = pal(0.85, 0.15, 0.2), pal(0.98, 0.8, 0.25)
  rect(f, 6, 14, 25, 27, rojo)
  rect(f, 4, 10, 27, 15, pal(0.92, 0.22, 0.26))
  rect(f, 14, 10, 17, 27, oro)
  rect(f, 4, 11, 27, 12, oro, true)
  -- lazo
  elipse(f, 12, 7, 4, 3, oro)
  elipse(f, 20, 7, 4, 3, oro)
  elipse(f, 16, 8, 2, 2, pal(0.95, 0.65, 0.15))
  -- destellos
  local b = { 1, 0.98, 0.7, 1 }
  for _, q in ipairs({ { 4, 3 }, { 28, 4 }, { 29, 20 } }) do
    poner(f, q[1], q[2], b) poner(f, q[1] - 1, q[2], b) poner(f, q[1] + 1, q[2], b)
    poner(f, q[1], q[2] - 1, b) poner(f, q[1], q[2] + 1, b)
  end
  return acabar(f)
end

function H.generar(raiz, guardar)
  local datos = love.image.newImageData(128, 32)
  for i, g in ipairs({ mapa, ayuda, menu, diaria }) do
    P.volcar(datos, g(), (i - 1) * 32, 0)
  end
  guardar(datos, raiz .. "juego/arte/hojas/iconos_hud.png")
  -- vista previa ampliada
  local cv = love.graphics.newCanvas(128 * 6 + 20, 32 * 6 + 20)
  love.graphics.setCanvas(cv)
  love.graphics.clear(0.14, 0.2, 0.4, 1)
  love.graphics.setColor(1, 1, 1, 1)
  local img = love.graphics.newImage(datos)
  img:setFilter("nearest", "nearest")
  love.graphics.draw(img, 10, 10, 0, 6, 6)
  love.graphics.setCanvas()
  local fp = io.open(os.getenv("TEMP") .. "/hud_previa.png", "wb")
  fp:write(cv:newImageData():encode("png"):getString())
  fp:close()
end

return H
