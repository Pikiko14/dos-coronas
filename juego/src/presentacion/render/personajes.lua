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

-- Aspecto de cada oficio mientras esta activo (sustituye al de la clase).
P.oficios = {
  trader = { hoja = "Characters/People3.png", idx = 0 },
  hunter = { hoja = "Characters/People3.png", idx = 1 },
  thief = { hoja = "Characters/People3.png", idx = 4 },
}

-- Addons del Item Mall: sprites de personaje únicos (compartido/dominio/mall.lua, M.ADDONS).
P.skins = {
  skin_rey = { hoja = "Characters/People4.png", idx = 0 },
  skin_princesa = { hoja = "Characters/People4.png", idx = 3 },
  skin_explorador = { hoja = "Characters/Actor1.png", idx = 2 },
  skin_fuego = { hoja = "Characters/Actor1.png", idx = 0 },
  skin_marea = { hoja = "Characters/Actor1.png", idx = 3 },
  skin_sombra = { hoja = "Characters/Actor1.png", idx = 6 },
  skin_hada_cristal = { generada = "hada_cristal", idx = 0 },
  skin_caballero_solar = { generada = "caballero_solar", idx = 0 },
  skin_marino = { hoja = "Characters/People8.png", idx = 0 },
  skin_plata = { hoja = "Characters/People8.png", idx = 1 },
  skin_chico = { hoja = "Characters/People8.png", idx = 2 },
  skin_coletas = { hoja = "Characters/People8.png", idx = 3 },
  skin_noel = { hoja = "Characters/People8.png", idx = 4 },
  skin_noel_saco = { hoja = "Characters/People8.png", idx = 5 },
  skin_reno = { hoja = "Characters/People8.png", idx = 6 },
  skin_ayudante = { hoja = "Characters/People8.png", idx = 7 },
  skin_esp_fuego = { hoja = "Characters/Spiritual.png", idx = 0 },
  skin_esp_agua = { hoja = "Characters/Spiritual.png", idx = 1 },
  skin_esp_bruma = { hoja = "Characters/Spiritual.png", idx = 2 },
  skin_esp_bosque = { hoja = "Characters/Spiritual.png", idx = 3 },
  skin_hada = { hoja = "Characters/Spiritual.png", idx = 4 },
  skin_angel_fuego = { hoja = "Characters/Spiritual.png", idx = 5 },
  skin_angel_plata = { hoja = "Characters/Spiritual.png", idx = 6 },
  skin_sabio = { hoja = "Characters/Spiritual.png", idx = 7 },
  skin_jinete_pardo = { hoja = "Characters/Riding.png", idx = 0, celda = 48 },
  skin_jinete_blanco = { hoja = "Characters/Riding.png", idx = 1, celda = 48 },
  skin_jinete_negro = { hoja = "Characters/Riding.png", idx = 2, celda = 48 },
  skin_jinete_dorado = { hoja = "Characters/Riding.png", idx = 3, celda = 48 },
  skin_abanderado = { hoja = "Characters/Riding.png", idx = 4, celda = 48 },
  skin_rey_jinete = { hoja = "Characters/Riding.png", idx = 5, celda = 48 },
  skin_dama_jinete = { hoja = "Characters/Riding.png", idx = 6, celda = 48 },
  skin_jinete_capucha = { hoja = "Characters/Riding.png", idx = 7, celda = 48 },
  skin_cazador_verde = { hoja = "Characters/Evil.png", idx = 0 },
  skin_desierto = { hoja = "Characters/Evil.png", idx = 1 },
  skin_sombra_capucha = { hoja = "Characters/Evil.png", idx = 2 },
  skin_gran_capucha = { hoja = "Characters/Evil.png", idx = 3 },
  skin_hechicera = { hoja = "Characters/Evil.png", idx = 4 },
  skin_enmascarado = { hoja = "Characters/Evil.png", idx = 5 },
  skin_centinela = { hoja = "Characters/Evil.png", idx = 6 },
  skin_caballero_oscuro = { hoja = "Characters/Evil.png", idx = 7 },
}

P.npc = {
  mercado = { hoja = "Characters/Actor1.png", idx = 7 },
  heraldo = { hoja = "Characters/People4.png", idx = 0 },
  mayordomo = { hoja = "Characters/People4.png", idx = 5 },
  encargos = { hoja = "Characters/People1.png", idx = 4 },
  encantador = { hoja = "Characters/Actor2.png", idx = 7 },
  criador = { hoja = "Characters/People1.png", idx = 2 },
  gremio = { hoja = "Characters/People2.png", idx = 3 },
  oficios = { hoja = "Characters/People4.png", idx = 4 },
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
  gallina = { hoja = "Characters/Animal.png", idx = 2 },
  planta_roja = { hoja = "Characters/Monster2.png", idx = 0 },
  esqueleto = { hoja = "Characters/Monster1.png", idx = 1 },
  arpia = { hoja = "Characters/Monster2.png", idx = 7 },
  medusa = { hoja = "Characters/Monster3.png", idx = 3 },
  flor_sangrienta = { hoja = "Characters/Monster2.png", idx = 4, tinte = { 1, 0.55, 0.6 } },
  esqueleto_real = { hoja = "Characters/Monster1.png", idx = 1, tinte = { 1, 0.9, 0.5 } },
  escorpion_carmesi = { hoja = "Characters/Monster3.png", idx = 6, tinte = { 1, 0.6, 0.5 } },
  dragon_brasas = { hoja = "Characters/Monster2.png", idx = 5, tinte = { 1, 0.75, 0.45 } },
  medusa_abisal = { hoja = "Characters/Monster3.png", idx = 3, tinte = { 0.55, 0.6, 0.95 } },
  ojo_abismo = { hoja = "Characters/Monster3.png", idx = 1, tinte = { 0.7, 0.55, 1 } },
  rey_espectral = { hoja = "Characters/Monster1.png", idx = 0, tinte = { 0.8, 0.65, 1 } },
  demonio_rey = { hoja = "Characters/Monster1.png", idx = 7, tinte = { 0.8, 0.5, 0.5 } },
  hidra_ceniza = { hoja = "Characters/$BigMonster1.png", fila = 3, tinte = { 0.65, 0.6, 0.6 } },
}

-- Definición de dibujo de una entidad, o nil si no es una criatura.
function P.de(e)
  local k = e.kind
  if k == "jugador" or k == "bot" or k == "cuerpo" then
    if e.job and P.oficios[e.job] then return P.oficios[e.job] end
    if e.addon and P.skins[e.addon] then return P.skins[e.addon] end
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
  -- las skins propias del mall se dibujan por cÃ³digo (render/propias.lua)
  local img = def.generada and require("src.presentacion.render.propias").hoja(def.generada) or Arte.img(def.hoja)
  local col = mov and CICLO[(math.floor(reloj * 8) % 4) + 1] or 1
  local c = tinte or def.tinte
  if c then love.graphics.setColor(c[1], c[2], c[3], alfa or 1)
  else love.graphics.setColor(1, 1, 1, alfa or 1) end
  if def.fila then
    local q = Arte.quad(img, col * 64, def.fila * 64, 64, 64)
    love.graphics.draw(img, q, sx, sy, 0, 1, 1, 32, 62)
    return 64
  end
  -- hojas con casillas de 32 px (la mayoria) o de 48 px (jinetes, hoja Riding)
  local c = def.celda or 32
  local ox = (def.idx % 4) * c * 3
  local oy = math.floor(def.idx / 4) * c * 4
  local fila = FILA_DIR[dir or 1] or 0
  love.graphics.draw(img, Arte.quad(img, ox + col * c, oy + fila * c, c, c), sx, sy, 0, 1, 1, c / 2, c - 2)
  return c
end

-- Cuerpo de un personaje caído: la misma imagen, en escala de grises.
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
