-- Personajes y criaturas con las hojas "Characters" del pack nuevo.
-- Hoja normal: 4x2 personajes, cada uno de 3 cuadros x 4 filas (abajo, izquierda,
-- derecha, arriba) con cuadros de 32x32. Hoja "$": un solo personaje o una criatura
-- grande por fila, con cuadros de 64x64.
local Arte = require("src.presentacion.render.arte")

local P = {}

local FILA_DIR = { [1] = 0, [2] = 3, [3] = 2, [4] = 1 } -- sur, norte, este, oeste
local CICLO = { 0, 1, 2, 1 }

-- Qué personaje usa cada oficio y facción.
P.clases = {
  guerrero = {
    albor = { hoja = "Characters/Actor3.png", idx = 6 },
    umbra = { hoja = "Characters/Evil.png", idx = 7 },
  },
  mago = {
    albor = { hoja = "Characters/Actor2.png", idx = 7 },
    umbra = { hoja = "Characters/Evil.png", idx = 3 },
  },
  cazador = {
    albor = { hoja = "Characters/Actor5.png", idx = 2 },
    umbra = { hoja = "Characters/Evil.png", idx = 0 },
  },
  clerigo = {
    albor = { hoja = "Characters/Actor5.png", idx = 5 },
    umbra = { hoja = "Characters/Actor5.png", idx = 6 },
  },
}

P.npc = {
  mercado = { hoja = "Characters/Actor1.png", idx = 7 },
  heraldo = { hoja = "Characters/People4.png", idx = 0 },
  mayordomo = { hoja = "Characters/People4.png", idx = 5 },
  encargos = { hoja = "Characters/People1.png", idx = 4 },
  encantador = { hoja = "Characters/Actor2.png", idx = 7 },
  criador = { hoja = "Characters/People1.png", idx = 2 },
  gremio = { hoja = "Characters/People2.png", idx = 3 },
  oficios = { hoja = "Characters/People3.png", idx = 1 },
  comercio = { hoja = "Characters/People3.png", idx = 3 },
  establo = { hoja = "Characters/People7.png", idx = 6 },
  capitan = { hoja = "Characters/People4.png", idx = 7 },
  contacto = { hoja = "Characters/Evil.png", idx = 3 },
  subastas = { hoja = "Characters/People2.png", idx = 5 },
  guardia = {
    albor = { hoja = "Characters/People4.png", idx = 6 },
    umbra = { hoja = "Characters/Evil.png", idx = 7 },
  },
}

-- Mascotas (compartido/dominio/mascotas.lua): la hoja y la casilla de cada especie.
P.mascotas = {
  gatito = { hoja = "Characters/Animal.png", idx = 1 },
  murcielago = { hoja = "Characters/Monster3.png", idx = 0 },
  limo = { hoja = "Characters/Monster2.png", idx = 2 },
  flor = { hoja = "Characters/Monster2.png", idx = 0 },
  hada = { hoja = "Characters/Monster2.png", idx = 3 },
  avispa = { hoja = "Characters/Monster3.png", idx = 2 },
}

-- Monturas de transporte (compartido/dominio/monturas.lua).
P.monturas = {
  buey = { hoja = "Characters/Animal.png", idx = 4 },
  caballo = { hoja = "Characters/Animal.png", idx = 5 },
  carreta = { vehiculo = true },
}

P.monstruos = {
  jefe_manada = { hoja = "Characters/Animal.png", idx = 6, tinte = { 1, 0.55, 0.5 } },
  sectario_mayor = { hoja = "Characters/Evil.png", idx = 5, tinte = { 0.85, 0.7, 1 } },
  reina_avispa = { hoja = "Characters/Monster3.png", idx = 2, tinte = { 1, 0.9, 0.5 } },
  oso_gigante = { hoja = "Characters/$BigMonster1.png", fila = 2, tinte = { 0.85, 0.7, 0.55 } },
  coloso = { hoja = "Characters/$BigMonster1.png", fila = 1, tinte = { 0.7, 0.75, 0.85 } },
  gigante_guerra = { hoja = "Characters/$BigMonster2.png", fila = 2, tinte = { 1, 0.7, 0.7 } },
  bandido = { hoja = "Characters/People7.png", idx = 1, tinte = { 0.85, 0.75, 0.75 } },
  asaltante = { hoja = "Characters/Actor3.png", idx = 6 },
  saqueador = { hoja = "Characters/Evil.png", idx = 6, tinte = { 0.9, 0.8, 0.8 } },
  gato = { hoja = "Characters/Animal.png", idx = 1 },
  cuervo = { hoja = "Characters/Monster3.png", idx = 0 },
  jabali = { hoja = "Characters/Animal.png", idx = 6 },
  rata = { hoja = "Characters/Monster3.png", idx = 4 },
  escarabajo = { hoja = "Characters/Monster3.png", idx = 7 },
  jabali_fuego = { hoja = "Characters/Animal.png", idx = 6, tinte = { 1, 0.55, 0.45 } },
  aguila = { hoja = "Characters/Monster3.png", idx = 2 },
  oso = { hoja = "Characters/$BigMonster1.png", fila = 2 },
  elefante = { hoja = "Characters/$BigMonster1.png", fila = 0 },
  espectro = { hoja = "Characters/Monster1.png", idx = 0 },
  gargola = { hoja = "Characters/Monster1.png", idx = 3 },
  automata = { hoja = "Characters/Monster1.png", idx = 7 },
  alma = { hoja = "Characters/Monster1.png", idx = 5 },
  troll = { hoja = "Characters/Monster1.png", idx = 2 },
  caballero = { hoja = "Characters/People4.png", idx = 7, tinte = { 0.62, 0.62, 0.78 } },
  alma_verde = { hoja = "Characters/Monster2.png", idx = 6 },
  cultista = { hoja = "Characters/Monster1.png", idx = 6 },
  alma_hielo = { hoja = "Characters/Monster2.png", idx = 2 },
  demonio_musgo = { hoja = "Characters/Monster2.png", idx = 1 },
  saurio = { hoja = "Characters/Monster3.png", idx = 6 },
  bruja = { hoja = "Characters/Monster2.png", idx = 3 },
  demonio_marea = { hoja = "Characters/Monster3.png", idx = 5 },
  quimera = { hoja = "Characters/Monster3.png", idx = 1 },
  hidra = { hoja = "Characters/$BigMonster1.png", fila = 3 },
  golem = { hoja = "Characters/Monster1.png", idx = 4 },
  demonio_foso = { hoja = "Characters/Monster2.png", idx = 5 },
  titan = { hoja = "Characters/$BigMonster1.png", fila = 1 },
  dragon = { hoja = "Characters/$BigMonster2.png", fila = 1 },
  liche = { hoja = "Characters/Evil.png", idx = 5 },
  behemot = { hoja = "Characters/$BigMonster2.png", fila = 2 },
}

-- Definición de dibujo de una entidad, o nil si no es una criatura.
function P.de(e)
  local k = e.kind
  if k == "jugador" or k == "bot" then
    local c = P.clases[e.clase or "guerrero"] or P.clases.guerrero
    return c[e.faccion or "albor"] or c.albor
  elseif k == "guardia" then
    return P.npc.guardia[e.faccion or "albor"] or P.npc.guardia.albor
  elseif k == "npc" then
    return P.npc[e.rol or "mercado"] or P.npc.mercado
  elseif k == "monstruo" then
    return P.monstruos[e.monstruo or ""] or P.monstruos.gato
  elseif k == "mascota" then
    return P.mascotas[e.especie or ""] or P.mascotas.gatito
  end
end

-- Dibuja la criatura con los pies en (sx, sy). mov: está andando; reloj: segundos.
function P.dibujar(def, dir, mov, reloj, sx, sy, tinte, alfa)
  local img = Arte.img(def.hoja)
  local col = mov and CICLO[(math.floor(reloj * 8) % 4) + 1] or 1
  local c = tinte or def.tinte
  if c then love.graphics.setColor(c[1], c[2], c[3], alfa or 1)
  else love.graphics.setColor(1, 1, 1, alfa or 1) end
  if def.fila then
    local q = Arte.quad(img, col * 64, def.fila * 64, 64, 64)
    love.graphics.draw(img, q, sx, sy, 0, 1, 1, 32, 62)
    return 64
  end
  local ox = (def.idx % 4) * 96
  local oy = math.floor(def.idx / 4) * 128
  local fila = FILA_DIR[dir or 1] or 0
  love.graphics.draw(img, Arte.quad(img, ox + col * 32, oy + fila * 32, 32, 32), sx, sy, 0, 1, 1, 16, 30)
  return 32
end

-- Cuerpo de un personaje caÃ­do: la misma imagen, en escala de grises.
local sombreadorGris
function P.dibujarGris(def, dir, sx, sy, alfa)
  if sombreadorGris == nil then
    local ok, sh = pcall(love.graphics.newShader, [[
      vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
        vec4 p = Texel(tex, uv) * color;
        float g = dot(p.rgb, vec3(0.299, 0.587, 0.114)) * 0.8;
        return vec4(g, g, g, p.a);
      }]])
    sombreadorGris = ok and sh or false
  end
  if sombreadorGris then love.graphics.setShader(sombreadorGris) end
  local alto = P.dibujar(def, dir, false, 0, sx, sy, sombreadorGris and { 1, 1, 1 } or { 0.5, 0.5, 0.55 }, alfa or 0.9)
  love.graphics.setShader()
  return alto
end

return P
