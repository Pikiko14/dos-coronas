-- Personajes de las dos clases nuevas y sus esbirros, dibujados a mano en píxeles con las proporciones de
-- los sprites de RPG Maker del pack (medidas sobre sus hojas): cabeza redonda de unos 20 px de ancho en las
-- 17 filas de arriba, cuello estrecho, hombros de 24 px, cuerpo corto y piernas de 11 px de ancho; sombreado
-- de cinco tonos, ojos grandes con brillo y contorno oscuro fino del color de cada parte.
-- Cada personaje es una hoja de 96 x 128: 3 cuadros de caminar por 4 direcciones (abajo, izquierda,
-- derecha, arriba). dir: "abajo", "izq", "arriba"; "der" es el espejo de "izq". fase: -1, 0 o 1.
local P = require("pixel")
local pal, rect, elipse, poli, linea, poner = P.pal, P.rect, P.elipse, P.poli, P.linea, P.poner

local C = {}

local function elipseRec(f, cx, cy, rx, ry, paleta, ymin, ymax)
  local t = P.nuevo(f.w, f.h)
  elipse(t, cx, cy, rx, ry, paleta)
  for k, v in pairs(t.p) do
    local y = math.floor(k / f.w)
    if y >= (ymin or -1e9) and y <= (ymax or 1e9) then f.p[k] = v end
  end
end

local OSC = { 0.10, 0.08, 0.14, 1 }
local BLANCOPX = { 1, 1, 1, 1 }

-- Ojo grande de estilo RPG Maker: pestaña oscura, iris con brillo blanco y reflejo claro abajo.
local function ojo(f, x, y, iris)
  local i1, i2, i3 = iris[1], iris[3], iris[2]
  rect(f, x, y, x + 2, y, OSC, true)
  poner(f, x, y + 1, BLANCOPX); poner(f, x + 1, y + 1, i1); poner(f, x + 2, y + 1, i1)
  poner(f, x, y + 2, i1); poner(f, x + 1, y + 2, i3); poner(f, x + 2, y + 2, i3)
  poner(f, x, y + 3, i2); poner(f, x + 1, y + 3, i2); poner(f, x + 2, y + 3, i1)
end

local function ojoLado(f, x, y, iris)
  local i1, i2, i3 = iris[1], iris[3], iris[2]
  rect(f, x, y, x + 1, y, OSC, true)
  poner(f, x, y + 1, BLANCOPX); poner(f, x + 1, y + 1, i1)
  poner(f, x, y + 2, i1); poner(f, x + 1, y + 2, i3)
  poner(f, x, y + 3, i2); poner(f, x + 1, y + 3, i2)
end

-- =============================================================================== LANCERO (Alba)
local ACERO, AZUL, AZULO = pal(0.68, 0.74, 0.86), pal(0.16, 0.34, 0.78), pal(0.09, 0.20, 0.52)
local ORO, BLANCO = pal(0.97, 0.80, 0.28), pal(0.97, 0.97, 1.0)
local PIEL = { { 0.98, 0.80, 0.66, 1 }, { 0.90, 0.64, 0.52, 1 }, { 1, 0.88, 0.77, 1 }, { 1, 0.95, 0.89, 1 }, { 0.78, 0.50, 0.42, 1 } }
local PELO, CUERO = pal(0.60, 0.33, 0.15), pal(0.46, 0.28, 0.15)
local MADERA = pal(0.78, 0.54, 0.28)
local IRIS_AZUL = pal(0.22, 0.46, 0.95)
local BOCA = { 0.66, 0.34, 0.30, 1 }

-- Lanza: asta de 2 px, punta de laurel y borla azul.
local function lanza(f, x, fase)
  rect(f, x, 7, x + 1, 31, MADERA)
  rect(f, x, 24, x + 1, 27, CUERO, true)
  rect(f, x, 30, x + 1, 31, ACERO, true)
  poli(f, { x + 1, 0, x + 3.4, 3.6, x + 1, 7, x - 1.4, 3.6 }, ACERO, true)
  linea(f, x + 1, 1, x + 1, 5, ACERO[4])
  rect(f, x - 1, 7, x + 2, 8, ORO, true)
  local o = fase
  poli(f, { x - 1, 9, x + 2, 9, x + 2 + o, 13, x - 1 + o, 13 }, AZUL, true)
end

local function lanceroFrente(f, fase, atras)
  local dyL, dyR = (fase == -1) and -1 or 0, (fase == 1) and -1 or 0
  -- piernas, falda y botas
  rect(f, 11, 25 + dyL, 14, 29 + dyL, AZULO); rect(f, 17, 25 + dyR, 20, 29 + dyR, AZULO)
  poli(f, { 10, 24, 22, 24, 23.5, 28, 8.5, 28 }, AZUL, true)
  rect(f, 9, 28, 23, 28, ORO, true)
  rect(f, 10, 29 + dyL, 15, 31 + dyL, ACERO); rect(f, 16, 29 + dyR, 21, 31 + dyR, ACERO)
  -- tronco: peto o capa
  rect(f, 10, 17, 21, 25, AZUL)
  if atras then
    poli(f, { 9, 17, 23, 17, 25, 29, 7, 29 }, AZUL, true)
    rect(f, 7, 28, 25, 29, ORO, true)
    linea(f, 16, 19, 16, 27, AZULO[2]); linea(f, 12, 20, 11, 27, AZULO[2]); linea(f, 20, 20, 21, 27, AZULO[2])
  else
    poli(f, { 10, 17, 22, 17, 21, 24, 11, 24 }, ACERO, true)
    rect(f, 15, 18, 16, 23, ORO, true)
    elipse(f, 16, 20.5, 1.4, 1.4, { { 0.35, 0.6, 1, 1 }, { 0.2, 0.4, 0.8, 1 }, { 0.8, 0.9, 1, 1 }, { 1, 1, 1, 1 }, { 0.1, 0.2, 0.5, 1 } })
  end
  rect(f, 10, 24, 21, 25, CUERO, true); rect(f, 14, 24, 17, 25, ORO, true)
  -- brazo libre y hombreras
  local aR = (fase == 1) and 1 or ((fase == -1) and -1 or 0)
  rect(f, 22, 19, 25, 23 + aR, AZUL); rect(f, 22, 24 + aR, 25, 24 + aR, ACERO, true); rect(f, 22, 25 + aR, 25, 26 + aR, PIEL, true)
  rect(f, 6, 19, 9, 23, AZUL)
  elipse(f, 8, 18.5, 3.6, 2.8, ACERO); elipse(f, 24, 18.5, 3.6, 2.8, ACERO)
  rect(f, 5, 20, 11, 20, ORO, true); rect(f, 21, 20, 27, 20, ORO, true)
  -- cuello y cabeza
  rect(f, 14, 15, 17, 17, PIEL, true)
  elipse(f, 16, 8.5, 9.8, 8.4, atras and ACERO or PIEL)
  if atras then
    elipseRec(f, 16, 5.5, 10.6, 6.2, ACERO, -10, 17)
    rect(f, 6, 7, 26, 7, ORO, true)
    poli(f, { 14, 0, 18, 0, 19, 14, 13, 14 }, AZUL, true)
  else
    poli(f, { 6, 6, 26, 6, 26, 9, 24.5, 8, 22.5, 10, 20, 8, 17.5, 10, 15, 8, 12.5, 10, 10, 8, 8, 10, 6, 9 }, PELO, true)
    elipseRec(f, 16, 5.2, 10.6, 5.6, ACERO, -10, 5)
    rect(f, 5, 6, 27, 6, ORO, true)
    poli(f, { 14.5, 0, 17.5, 0, 18.5, 5, 13.5, 5 }, AZUL, true)
    poli(f, { 4.5, 6, 7, 6, 7, 13, 5.5, 12 }, ACERO, true)
    poli(f, { 27.5, 6, 25, 6, 25, 13, 26.5, 12 }, ACERO, true)
    ojo(f, 9, 9, IRIS_AZUL); ojo(f, 20, 9, IRIS_AZUL)
    poner(f, 16, 12, PIEL[2]); rect(f, 15, 14, 17, 14, BOCA, true)
    poner(f, 8, 13, { 1, 0.6, 0.55, 0.7 }); poner(f, 24, 13, { 1, 0.6, 0.55, 0.7 })
  end
  -- lanza por delante con antebrazo y mano
  local function mx(x) return atras and (31 - x) or x end
  local ax = atras and 28 or 3
  poli(f, { mx(7), 20, mx(9), 21, mx(6), 25, mx(3), 24 }, AZUL, true)
  lanza(f, ax, fase)
  rect(f, atras and 26 or 2, 24, atras and 29 or 5, 26, PIEL, true)
  rect(f, atras and 26 or 2, 23, atras and 29 or 5, 23, ACERO, true)
end

local function lanceroLado(f, fase)
  local sw = fase * 2
  rect(f, 15 - sw, 25, 18 - sw, 29, AZULO); rect(f, 14 - sw, 29, 19 - sw, 31, pal(0.5, 0.56, 0.7))
  rect(f, 11 + sw, 25, 14 + sw, 29, AZUL); rect(f, 9 + sw, 29, 15 + sw, 31, ACERO)
  poli(f, { 17, 17, 23, 19, 25, 29, 16, 28 }, AZULO, true)
  rect(f, 10, 17, 20, 25, AZUL)
  poli(f, { 10, 17, 19, 17, 18, 24, 11, 24 }, ACERO, true)
  rect(f, 10, 24, 20, 25, CUERO, true); rect(f, 11, 24, 13, 25, ORO, true)
  poli(f, { 9, 23, 21, 23, 22, 28, 8, 28 }, AZUL, true)
  rect(f, 8, 28, 22, 28, ORO, true)
  poli(f, { 11, 20, 14, 20, 9, 25, 6, 25 }, AZUL, true)
  elipse(f, 14, 18.5, 3.8, 2.8, ACERO)
  rect(f, 5, 24, 8, 26, PIEL, true)
  -- cabeza de perfil hacia la izquierda
  rect(f, 12, 15, 16, 17, PIEL, true)
  elipse(f, 15, 8.5, 9.4, 8.4, PIEL)
  rect(f, 19, 6, 24, 14, PELO, true)
  poli(f, { 6, 6, 19, 6, 19, 9, 16, 8, 13, 10, 10, 8, 8, 9.5, 6, 8 }, PELO, true)
  poner(f, 6, 11, PIEL[4]); poner(f, 6, 12, PIEL[3]); poner(f, 7, 12, PIEL[1])
  elipseRec(f, 15.5, 5.2, 10.4, 5.6, ACERO, -10, 5)
  rect(f, 5, 6, 26, 6, ORO, true)
  poli(f, { 14, 0, 18, 0, 19, 5, 13, 5 }, AZUL, true)
  poli(f, { 18, 7, 24, 7, 25, 13, 20, 12 }, ACERO, true)
  ojoLado(f, 8, 9, IRIS_AZUL)
  rect(f, 7, 14, 9, 14, BOCA, true)
  lanza(f, 5, fase)
  rect(f, 4, 23, 8, 25, PIEL, true)
  rect(f, 4, 22, 8, 22, ACERO, true)
end

function C.lancero(dir, fase)
  local f = P.nuevo(32, 32)
  if dir == "izq" then lanceroLado(f, fase)
  elseif dir == "arriba" then lanceroFrente(f, fase, true)
  else lanceroFrente(f, fase, false) end
  P.contorno(f, 0.15)
  return f
end

-- ============================================================================ NIGROMANTE (Ocaso)
local TUNICA = pal(0.34, 0.14, 0.48)
local CARMESI, HUESO = pal(0.82, 0.16, 0.32), pal(0.95, 0.93, 0.82)
local PALIDO = pal(0.78, 0.82, 0.84)
local VERDE, SOMBRA_CAPA = { 0.50, 1.0, 0.60, 1 }, { 0.04, 0.02, 0.07, 1 }
local VERDE_HALO = { 0.16, 0.55, 0.28, 1 }
local MADERA_OSCURA = pal(0.34, 0.22, 0.18)
local SOCALO = { 0.05, 0.02, 0.07, 1 }
local NEGRO3 = { SOMBRA_CAPA, SOMBRA_CAPA, SOMBRA_CAPA }

local function baculo(f, x, fase)
  rect(f, x, 8, x + 1, 31, MADERA_OSCURA)
  poner(f, x - 1, 14, MADERA_OSCURA[1]); poner(f, x + 2, 20, MADERA_OSCURA[1]); poner(f, x - 1, 25, MADERA_OSCURA[2])
  elipse(f, x + 1, 4.6, 3.8, 3.4, HUESO)
  rect(f, x - 1, 7, x + 3, 8, HUESO, true)
  rect(f, x - 1, 3, x, 5, SOCALO, true); rect(f, x + 2, 3, x + 3, 5, SOCALO, true)
  poner(f, x - 1, 4, VERDE); poner(f, x + 2, 4, VERDE)
  poner(f, x + 1, 6, SOCALO)
  local o = fase
  poli(f, { x - 2, 1.5, x + 1 + o, -2, x + 4, 1.5 }, { { 0.4, 1, 0.5, 1 }, { 0.15, 0.6, 0.3, 1 }, { 0.75, 1, 0.8, 1 }, { 1, 1, 0.9, 1 }, { 0.1, 0.4, 0.2, 1 } }, true)
end

local function manto(f, y0, y1, ancho, fase)
  local pts = { 10, y0, 22, y0 }
  pts[#pts + 1] = 24 + ancho; pts[#pts + 1] = y1 - 1
  for i = 6, 0, -1 do
    local x = 8 - ancho + (16 + 2 * ancho) * i / 6
    pts[#pts + 1] = x; pts[#pts + 1] = y1 + ((i + fase) % 2 == 0 and 1 or -1) * 0.9
  end
  pts[#pts + 1] = 8 - ancho; pts[#pts + 1] = y1 - 1
  poli(f, pts, TUNICA, true)
  for i = 1, 3 do linea(f, 11 + i * 3, y0 + 4, 9 + i * 4, y1 - 1, TUNICA[5]) end
end

local function nigromanteFrente(f, fase, atras)
  local bx = atras and 2 or 28
  local dyL, dyR = (fase == -1) and -1 or 0, (fase == 1) and -1 or 0
  baculo(f, bx, fase)
  rect(f, 11, 29 + dyL, 14, 31 + dyL, pal(0.2, 0.1, 0.26), true)
  rect(f, 17, 29 + dyR, 20, 31 + dyR, pal(0.2, 0.1, 0.26), true)
  manto(f, 16, 30, 2, fase)
  rect(f, 9, 23, 23, 24, CARMESI, true)
  if not atras then
    rect(f, 15, 18, 16, 22, CARMESI, true)
    elipse(f, 16, 23.5, 2.2, 2, HUESO); poner(f, 15, 23, SOCALO); poner(f, 17, 23, SOCALO)
  end
  local aL, aR = (fase == -1) and 1 or ((fase == 1) and -1 or 0), (fase == 1) and 1 or ((fase == -1) and -1 or 0)
  poli(f, { 5, 18, 10, 18, 9, 25 + aL, 3, 27 + aL }, TUNICA, true)
  poli(f, { 22, 18, 27, 18, 29, 27 + aR, 23, 25 + aR }, TUNICA, true)
  rect(f, 2, 27 + aL, 5, 28 + aL, PALIDO, true)
  rect(f, 26, 27 + aR, 29, 28 + aR, PALIDO, true)
  elipse(f, 8, 18.5, 3.6, 2.6, HUESO); poli(f, { 6, 17, 7.5, 14, 9, 17 }, HUESO, true)
  elipse(f, 24, 18.5, 3.6, 2.6, HUESO); poli(f, { 23, 17, 24.5, 14, 26, 17 }, HUESO, true)
  -- capucha
  elipse(f, 16, 8.5, 11, 9, TUNICA)
  poli(f, { 8, 14, 24, 14, 26, 19, 6, 19 }, TUNICA, true)
  if atras then
    linea(f, 16, 1, 16, 15, TUNICA[5]); linea(f, 11, 2, 8, 14, TUNICA[5]); linea(f, 21, 2, 24, 14, TUNICA[5])
  else
    elipse(f, 16, 10.5, 7.2, 6.2, NEGRO3)
    rect(f, 9, 8, 14, 12, VERDE_HALO, true); rect(f, 18, 8, 23, 12, VERDE_HALO, true)
    rect(f, 10, 9, 13, 11, VERDE, true); rect(f, 19, 9, 22, 11, VERDE, true)
    rect(f, 11, 9, 12, 10, { 0.9, 1, 0.95, 1 }, true); rect(f, 20, 9, 21, 10, { 0.9, 1, 0.95, 1 }, true)
    linea(f, 9, 7, 14, 9, SOMBRA_CAPA); linea(f, 23, 7, 18, 9, SOMBRA_CAPA)
    for x = 7, 25 do local y = 2 + math.floor(math.abs(x - 16) * 0.42); poner(f, x, y, CARMESI[1]); poner(f, x, y - 1, CARMESI[3]) end
    elipse(f, 16, 17.5, 1.7, 1.7, { { 0.9, 0.15, 0.25, 1 }, { 0.6, 0.05, 0.12, 1 }, { 1, 0.5, 0.5, 1 }, { 1, 0.8, 0.8, 1 }, { 0.3, 0.02, 0.06, 1 } })
  end
end

local function nigromanteLado(f, fase)
  baculo(f, 4, fase)
  local sw = fase
  rect(f, 12 + sw, 29, 17 + sw, 31, pal(0.2, 0.1, 0.26), true)
  manto(f, 16, 30, 1, fase)
  rect(f, 9, 23, 22, 24, CARMESI, true)
  elipse(f, 11, 23.5, 2.2, 2, HUESO); poner(f, 10, 23, SOCALO)
  poli(f, { 11, 19, 17, 19, 10, 27, 4, 26 }, TUNICA, true)
  rect(f, 3, 26, 6, 28, PALIDO, true)
  elipse(f, 14, 18.5, 3.8, 2.8, HUESO); poli(f, { 12, 17, 13.5, 14, 15, 17 }, HUESO, true)
  elipse(f, 15.5, 8.5, 10.4, 9, TUNICA)
  poli(f, { 9, 14, 22, 14, 25, 19, 7, 19 }, TUNICA, true)
  poli(f, { 21, 4, 27, 10, 25, 18, 20, 15 }, TUNICA, true)
  elipse(f, 9, 10.5, 5.6, 5.6, NEGRO3)
  rect(f, 5, 8, 9, 12, VERDE_HALO, true)
  rect(f, 6, 9, 8, 11, VERDE, true); rect(f, 6, 9, 7, 10, { 0.9, 1, 0.95, 1 }, true)
  for x = 6, 21 do local y = 1 + math.floor(math.abs(x - 13) * 0.4); poner(f, x, y, CARMESI[1]); poner(f, x, y - 1, CARMESI[3]) end
end

function C.nigromante(dir, fase)
  local f = P.nuevo(32, 32)
  if dir == "izq" then nigromanteLado(f, fase)
  elseif dir == "arriba" then nigromanteFrente(f, fase, true)
  else nigromanteFrente(f, fase, false) end
  P.contorno(f, 0.14)
  return f
end

-- ============================================================================ ESBIRROS
local OXIDO = pal(0.66, 0.62, 0.62)
local MANGO = pal(0.46, 0.30, 0.18)

local function craneo(f, cx, cy, atras)
  elipse(f, cx, cy, 9.6, 8.4, HUESO)
  rect(f, cx - 6, cy + 5, cx + 5, cy + 8, HUESO, true)
  if atras then
    linea(f, cx, cy - 7, cx, cy + 3, HUESO[2]); linea(f, cx - 5, cy - 4, cx - 6, cy + 3, HUESO[2])
    return
  end
  elipse(f, cx - 3.8, cy + 0.3, 3, 3.4, NEGRO3); elipse(f, cx + 3.8, cy + 0.3, 3, 3.4, NEGRO3)
  poner(f, cx - 3, cy - 0.5, { 0.6, 1, 0.7, 1 }); poner(f, cx + 4, cy - 0.5, { 0.6, 1, 0.7, 1 })
  poli(f, { cx - 1.1, cy + 3.5, cx + 1.1, cy + 3.5, cx, cy + 5.5 }, NEGRO3)
  for x = cx - 5, cx + 4, 2 do poner(f, x, cy + 7, SOCALO); poner(f, x, cy + 8, HUESO[2]) end
end

local function esqueletoFrente(f, fase, atras)
  local dyL, dyR = (fase == -1) and -1 or 0, (fase == 1) and -1 or 0
  local sx = atras and 28 or 2
  rect(f, sx, 13, sx + 2, 25, OXIDO, true); poli(f, { sx, 13, sx + 1, 8, sx + 3, 13 }, OXIDO, true)
  rect(f, sx - 1, 25, sx + 3, 26, pal(0.6, 0.45, 0.2), true)
  rect(f, sx, 27, sx + 1, 30, MANGO, true)
  rect(f, 12, 24 + dyL, 13, 29 + dyL, HUESO, true); rect(f, 18, 24 + dyR, 19, 29 + dyR, HUESO, true)
  rect(f, 10, 29 + dyL, 14, 31 + dyL, HUESO, true); rect(f, 17, 29 + dyR, 21, 31 + dyR, HUESO, true)
  rect(f, 11, 23, 20, 24, HUESO, true)
  rect(f, 15, 17, 16, 23, HUESO, true)
  for y = 17, 21, 2 do
    rect(f, 10, y, 21, y, HUESO, true)
    rect(f, 10, y + 1, 11, y + 1, HUESO[2], true); rect(f, 20, y + 1, 21, y + 1, HUESO[2], true)
  end
  local aL, aR = (fase == -1) and 1 or ((fase == 1) and -1 or 0), (fase == 1) and 1 or ((fase == -1) and -1 or 0)
  rect(f, 6, 18, 8, 24 + aL, HUESO, true); rect(f, 23, 18, 25, 24 + aR, HUESO, true)
  elipse(f, 7, 18, 2.2, 1.8, HUESO); elipse(f, 24, 18, 2.2, 1.8, HUESO)
  craneo(f, 16, 8.6, atras)
end

local function esqueletoLado(f, fase)
  local sw = fase * 2
  rect(f, 4, 13, 6, 25, OXIDO, true); poli(f, { 4, 13, 5, 8, 7, 13 }, OXIDO, true)
  rect(f, 3, 25, 7, 26, pal(0.6, 0.45, 0.2), true); rect(f, 4, 27, 5, 30, MANGO, true)
  rect(f, 15 - sw, 24, 16 - sw, 29, pal(0.78, 0.76, 0.66), true); rect(f, 13 - sw, 29, 18 - sw, 31, pal(0.78, 0.76, 0.66), true)
  rect(f, 12 + sw, 24, 13 + sw, 29, HUESO, true); rect(f, 10 + sw, 29, 15 + sw, 31, HUESO, true)
  rect(f, 11, 23, 19, 24, HUESO, true)
  rect(f, 13, 17, 15, 23, HUESO, true)
  for y = 17, 21, 2 do rect(f, 10, y, 19, y, HUESO, true) end
  rect(f, 8, 19, 9, 25, HUESO, true); rect(f, 11, 18, 12, 23, HUESO, true)
  elipse(f, 15, 8.6, 9.4, 8.4, HUESO)
  rect(f, 7, 13, 14, 16, HUESO, true)
  elipse(f, 9.5, 9, 3, 3.4, NEGRO3); poner(f, 9, 8, { 0.6, 1, 0.7, 1 })
  poli(f, { 6, 12, 8, 12, 6, 14 }, NEGRO3)
  for x = 8, 14, 2 do poner(f, x, 15, SOCALO) end
end

function C.esqueleto(dir, fase)
  local f = P.nuevo(32, 32)
  if dir == "izq" then esqueletoLado(f, fase)
  elseif dir == "arriba" then esqueletoFrente(f, fase, true)
  else esqueletoFrente(f, fase, false) end
  P.contorno(f, 0.12)
  return f
end

local ESPEC = pal(0.46, 0.86, 0.96, 0.84)
local ESPEC_CLARO = { 0.8, 0.98, 1, 0.92 }
local function espectro(f, fase, dir)
  local b = (fase == 0) and 0 or -1
  local atras = dir == "arriba"
  local lado = dir == "izq" and 1 or 0
  local pts = { 8, 15 + b, 24, 15 + b }
  for i = 6, 0, -1 do
    local x = 6 + (20 * i) / 6
    pts[#pts + 1] = x
    pts[#pts + 1] = 26 + b + ((i + fase) % 2 == 0 and 3 or 0)
  end
  poli(f, pts, ESPEC, true)
  poli(f, { 8, 16 + b, 11, 19 + b, 5, 25 + b, 2, 22 + b }, ESPEC, true)
  poli(f, { 24, 16 + b, 21, 19 + b, 27, 25 + b, 30, 22 + b }, ESPEC, true)
  elipse(f, 16 - lado * 1.5, 9 + b, 10, 8.8, ESPEC)
  if not atras then
    elipse(f, 16 - lado * 3.5, 10 + b, 6.2, 5.4, { { 0.03, 0.1, 0.18, 0.96 }, { 0.03, 0.1, 0.18, 0.96 }, { 0.03, 0.1, 0.18, 0.96 } })
    rect(f, 11 - lado * 3, 8 + b, 13 - lado * 3, 11 + b, { 0.55, 0.95, 1, 1 }, true)
    rect(f, 11 - lado * 3, 9 + b, 12 - lado * 3, 9 + b, { 1, 1, 1, 1 }, true)
    if lado == 0 then
      rect(f, 19, 8 + b, 21, 11 + b, { 0.55, 0.95, 1, 1 }, true)
      rect(f, 19, 9 + b, 20, 9 + b, { 1, 1, 1, 1 }, true)
    end
  end
  for i = 0, 2 do poner(f, 3 + i * 12, 6 + b - ((fase + i) % 2) * 2, ESPEC_CLARO) end
end

function C.espectro(dir, fase)
  local f = P.nuevo(32, 32)
  espectro(f, fase, dir)
  P.contorno(f, 0.2)
  return f
end

-- ============================================================================ HOJAS
function C.hoja(nombre)
  local datos = love.image.newImageData(96, 128)
  local fn = C[nombre]
  local filas = { "abajo", "izq", "der", "arriba" }
  for fila, dir in ipairs(filas) do
    for col = 0, 2 do
      local fase = col - 1
      local f
      if dir == "der" then f = P.espejo(fn("izq", fase)) else f = fn(dir, fase) end
      P.volcar(datos, f, col * 32, (fila - 1) * 32)
    end
  end
  return datos
end

return C
