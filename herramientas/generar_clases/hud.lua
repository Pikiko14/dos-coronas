-- Iconos de los cuatro botones bajo el minimapa (mapa, ayuda, menú, recompensa diaria) y de las siete pestañas del chat, en píxeles con el mismo
-- motor que el resto de sprites. Hoja de 352 x 32: once iconos de 32 x 32 en fila (los cuatro botones y las pestañas Todo, Mundo, Facción, Sistema, Gremio, Grupo y Eventos).
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

-- ---------------------------------------------------------------- pestañas del chat
-- Todo: dos globos de diálogo.
local function chatTodo()
  local f = P.nuevo(32, 32)
  poli(f, { 3, 5, 21, 5, 21, 17, 11, 17, 7, 22, 7, 17, 3, 17 }, pal(0.92, 0.94, 1.0), true)
  poli(f, { 12, 12, 29, 12, 29, 23, 25, 23, 25, 28, 20, 23, 12, 23 }, pal(0.30, 0.52, 0.92), true)
  for i = 0, 2 do poner(f, 7 + i * 4, 11, { 0.35, 0.4, 0.55, 1 }) poner(f, 7 + i * 4 + 1, 11, { 0.35, 0.4, 0.55, 1 }) end
  for i = 0, 2 do poner(f, 16 + i * 4, 17, { 1, 1, 1, 1 }) poner(f, 16 + i * 4 + 1, 17, { 1, 1, 1, 1 }) end
  return acabar(f)
end
-- Mundo: globo terráqueo.
local function chatMundo()
  local f = P.nuevo(32, 32)
  elipse(f, 16, 16, 12, 12, pal(0.28, 0.55, 0.92))
  poli(f, { 8, 9, 14, 7, 17, 11, 13, 16, 9, 15 }, pal(0.35, 0.68, 0.32), true)
  poli(f, { 18, 16, 25, 14, 26, 21, 21, 25, 18, 21 }, pal(0.35, 0.68, 0.32), true)
  local l = { 1, 1, 1, 0.55 }
  linea(f, 16, 5, 16, 27, l)
  linea(f, 5, 16, 27, 16, l)
  return acabar(f)
end
-- Facción: estandarte dorado en un asta.
local function chatFaccion()
  local f = P.nuevo(32, 32)
  rect(f, 7, 3, 8, 29, pal(0.6, 0.45, 0.28))
  poli(f, { 9, 5, 27, 5, 23, 11, 27, 17, 9, 17 }, pal(0.86, 0.18, 0.22), true)
  poli(f, { 11, 7, 23, 7, 21, 11, 23, 15, 11, 15 }, pal(0.98, 0.8, 0.25), true)
  elipse(f, 7, 3, 2, 2, pal(0.98, 0.8, 0.25))
  return acabar(f)
end
-- Sistema: insignia verde con una "i".
local function chatSistema()
  local f = P.nuevo(32, 32)
  elipse(f, 16, 16, 12, 12, pal(0.28, 0.72, 0.5))
  local b = { 1, 1, 1, 1 }
  rect(f, 14, 8, 17, 11, b, true)
  rect(f, 14, 14, 17, 23, b, true)
  rect(f, 12, 23, 19, 24, b, true)
  return acabar(f)
end
-- Gremio: escudo azul con dos espadas cruzadas.
local function chatGremio()
  local f = P.nuevo(32, 32)
  poli(f, { 5, 4, 27, 4, 27, 17, 16, 29, 5, 17 }, pal(0.28, 0.4, 0.82), true)
  local oro = { 0.98, 0.82, 0.3, 1 }
  linea(f, 9, 8, 22, 21, oro) linea(f, 10, 8, 23, 21, oro)
  linea(f, 23, 8, 10, 21, oro) linea(f, 22, 8, 9, 21, oro)
  rect(f, 7, 18, 9, 18, oro, true) rect(f, 22, 18, 24, 18, oro, true)
  return acabar(f)
end
-- Grupo: tres figuras.
local function chatGrupo()
  local f = P.nuevo(32, 32)
  local function figura(x, y, c, r)
    elipse(f, x, y, r, r, pal(0.95, 0.8, 0.65))
    poli(f, { x - r - 2, y + r + 11, x - r, y + r + 1, x + r, y + r + 1, x + r + 2, y + r + 11 }, pal(c[1], c[2], c[3]), true)
  end
  figura(9, 12, { 0.35, 0.6, 0.9 }, 3)
  figura(23, 12, { 0.85, 0.4, 0.4 }, 3)
  figura(16, 9, { 0.4, 0.75, 0.45 }, 3.5)
  return acabar(f)
end
-- Eventos: copa dorada.
local function chatEventos()
  local f = P.nuevo(32, 32)
  local oro = pal(0.98, 0.8, 0.25)
  poli(f, { 8, 5, 24, 5, 22, 15, 18, 19, 14, 19, 10, 15 }, oro, true)
  linea(f, 8, 7, 4, 8, oro[2]) linea(f, 4, 8, 6, 14, oro[2]) linea(f, 6, 14, 10, 15, oro[2])
  linea(f, 24, 7, 28, 8, oro[2]) linea(f, 28, 8, 26, 14, oro[2]) linea(f, 26, 14, 22, 15, oro[2])
  rect(f, 14, 19, 17, 23, oro, true)
  rect(f, 10, 24, 21, 27, pal(0.85, 0.62, 0.2), true)
  poner(f, 12, 8, { 1, 1, 0.8, 1 }) poner(f, 12, 9, { 1, 1, 0.8, 1 })
  return acabar(f)
end

function H.generar(raiz, guardar)
  local datos = love.image.newImageData(352, 32)
  for i, g in ipairs({ mapa, ayuda, menu, diaria, chatTodo, chatMundo, chatFaccion, chatSistema, chatGremio, chatGrupo, chatEventos }) do
    P.volcar(datos, g(), (i - 1) * 32, 0)
  end
  guardar(datos, raiz .. "juego/arte/hojas/iconos_hud.png")
  -- vista previa ampliada
  local cv = love.graphics.newCanvas(352 * 3 + 20, 32 * 3 + 20)
  love.graphics.setCanvas(cv)
  love.graphics.clear(0.14, 0.2, 0.4, 1)
  love.graphics.setColor(1, 1, 1, 1)
  local img = love.graphics.newImage(datos)
  img:setFilter("nearest", "nearest")
  love.graphics.draw(img, 10, 10, 0, 3, 3)
  love.graphics.setCanvas()
  local fp = io.open(os.getenv("TEMP") .. "/hud_previa.png", "wb")
  fp:write(cv:newImageData():encode("png"):getString())
  fp:close()
end

return H
