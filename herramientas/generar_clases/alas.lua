-- Alas de las monturas voladoras (pegaso y fénix), dibujadas en píxeles con el mismo motor que los personajes.
-- Cada hoja tiene 3 cuadros de 64 x 64 en fila (ala arriba, a medias y abajo) de UN ala, la izquierda vista de
-- frente: el hombro está en (50, 46) y el ala se abre hacia arriba y a la izquierda. El juego la espeja para la
-- derecha y la anima alternando los cuadros (render/monturas_fx.lua).
local P = require("pixel")
local pal, poli, linea, elipse = P.pal, P.poli, P.linea, P.elipse

local A = {}

local HX, HY = 50, 46          -- hombro
local pi, sin, cos = math.pi, math.sin, math.cos

-- Una pluma: óvalo alargado desde el hombro, con un ángulo (grados, 0 = derecha, 270 = arriba), largo y ancho.
local function pluma(f, ang, largo, ancho, paletas)
  local a = ang * pi / 180
  local ca, sa = cos(a), sin(a)
  local nx, ny = -sa, ca
  -- contorno de la pluma: raíz fina, panza ancha a 2/3 y punta redondeada
  local pts = {}
  local perfil = { { 0.0, 0.35 }, { 0.25, 0.8 }, { 0.55, 1.0 }, { 0.8, 0.9 }, { 0.95, 0.6 }, { 1.0, 0.0 } }
  for _, q in ipairs(perfil) do
    pts[#pts + 1] = HX + ca * largo * q[1] + nx * ancho * q[2]
    pts[#pts + 1] = HY + sa * largo * q[1] + ny * ancho * q[2]
  end
  for i = #perfil - 1, 1, -1 do
    local q = perfil[i]
    pts[#pts + 1] = HX + ca * largo * q[1] - nx * ancho * q[2]
    pts[#pts + 1] = HY + sa * largo * q[1] - ny * ancho * q[2]
  end
  poli(f, pts, paletas[1], true)
  -- tramo medio y punta con otros tonos (pluma bicolor: más viva hacia la punta)
  local function tramo(t0, t1, paleta)
    local sub = {}
    local function pos(t, lado)
      -- ancho del perfil en t
      local w = 0
      for i = 1, #perfil - 1 do
        if t >= perfil[i][1] and t <= perfil[i + 1][1] then
          local u = (t - perfil[i][1]) / (perfil[i + 1][1] - perfil[i][1])
          w = perfil[i][2] + (perfil[i + 1][2] - perfil[i][2]) * u
        end
      end
      return HX + ca * largo * t + nx * ancho * w * lado, HY + sa * largo * t + ny * ancho * w * lado
    end
    local n = 5
    for i = 0, n do local x, y = pos(t0 + (t1 - t0) * i / n, 1) sub[#sub + 1] = x sub[#sub + 1] = y end
    for i = n, 0, -1 do local x, y = pos(t0 + (t1 - t0) * i / n, -1) sub[#sub + 1] = x sub[#sub + 1] = y end
    poli(f, sub, paleta, true)
  end
  if paletas[2] then tramo(0.45, 0.78, paletas[2]) end
  if paletas[3] then tramo(0.78, 1.0, paletas[3]) end
  -- nervio central
  linea(f, HX + ca * largo * 0.1, HY + sa * largo * 0.1, HX + ca * largo * 0.92, HY + sa * largo * 0.92, paletas[1][5])
end

local function ala(pose, paletas, n, abanico)
  local f = P.nuevo(64, 64)
  -- ángulo central según la pose: arriba, a medias, abajo
  local centro = ({ 252, 222, 192 })[pose + 1]
  -- plumas largas y estrechas, las de la punta (arriba) más largas que las del cuerpo
  for i = n, 1, -1 do
    local u = (i - 1) / (n - 1)            -- 0 = la más baja, 1 = la de arriba
    local ang = centro - abanico / 2 + abanico * u
    local largo = 46 - 15 * math.abs(u - 0.72) - (pose == 2 and 3 or 0)
    pluma(f, ang, largo, 3.6 - 0.5 * math.abs(u - 0.6), paletas)
  end
  -- segunda fila de plumas más cortas, entre las largas
  for i = 1, n - 1 do
    local u = (i - 0.5) / (n - 1)
    local ang = centro - abanico / 2 + abanico * u
    pluma(f, ang, 24, 3.2, { paletas[2] and { paletas[2][1], paletas[2][2], paletas[2][3], paletas[2][4], paletas[2][5] } or paletas[1], paletas[4] })
  end
  -- hueso del borde de ataque: arco oscuro desde el hombro hasta la punta
  local a1 = (centro + abanico / 2) * pi / 180
  local ex, ey = HX + cos(a1) * 40, HY + sin(a1) * 40
  linea(f, HX, HY, HX + (ex - HX) * 0.5 + 2, HY + (ey - HY) * 0.5 - 3, paletas[1][5])
  linea(f, HX + (ex - HX) * 0.5 + 2, HY + (ey - HY) * 0.5 - 3, ex, ey, paletas[1][5])
  elipse(f, HX, HY, 3.2, 3.2, paletas[1])
  P.contorno(f, 0.15)
  P.volumen(f)
  return f
end

local function hoja(paletas, n, abanico)
  local datos = love.image.newImageData(192, 64)
  for pose = 0, 2 do
    P.volcar(datos, ala(pose, paletas, n, abanico), pose * 64, 0)
  end
  return datos
end

-- Pegaso: plumas blancas con sombras azuladas y puntas celestes; cobertoras casi blancas.
function A.pegaso()
  return hoja({ pal(0.90, 0.94, 1.0), pal(0.74, 0.86, 1.0), pal(0.52, 0.76, 1.0), pal(0.98, 0.98, 1.0) }, 8, 96)
end

-- Fénix: llamas de amarillo en la raíz a rojo en la punta.
function A.fenix()
  return hoja({ pal(1.0, 0.82, 0.25), pal(1.0, 0.52, 0.12), pal(0.92, 0.18, 0.1), pal(1.0, 0.94, 0.55) }, 8, 100)
end

return A
