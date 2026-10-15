-- Personajes y criaturas con las hojas "Characters" del pack nuevo.
-- Hoja normal: 4x2 personajes, cada uno de 3 cuadros x 4 filas (abajo, izquierda,
-- derecha, arriba) con cuadros de 32x32. Hoja "$": una criatura grande por fila,
-- con 3 cuadros de caminar. BigMonster1 usa 64 px; BigMonster2 usa 80 px (celda).
local Arte = require("src.presentacion.render.arte")

local P = {}

local FILA_DIR = { [1] = 0, [2] = 3, [3] = 2, [4] = 1 } -- sur, norte, este, oeste
local CICLO = { 0, 1, 2, 1 }

-- Qué personaje usa cada oficio y facción.
-- Los personajes de clase se dibujan por codigo sobre sprites del pack (render/propias.lua): paleta
-- de la facción y escudo de la clase en el pecho.
local function claseGenerada(clase, faccion)
  return { generada = "clase_" .. clase .. "_" .. faccion, hoja = "Characters/Actor1.png", idx = 0 }
end
P.clases = {}
for _, clase in ipairs({ "guerrero", "mago", "cazador", "clerigo" }) do
  P.clases[clase] = { albor = claseGenerada(clase, "albor"), umbra = claseGenerada(clase, "umbra") }
end

-- Clases nuevas: personajes dibujados a mano (herramientas/generar_clases) que sirven para las dos facciones.
P.clases.lancero = { albor = { hoja = "Characters/Lancero.png", idx = 0 }, umbra = { hoja = "Characters/Lancero.png", idx = 0 } }
P.clases.nigromante = { albor = { hoja = "Characters/Nigromante.png", idx = 0 }, umbra = { hoja = "Characters/Nigromante.png", idx = 0 } }

-- Esbirros invocados por el nigromante.
P.esbirros = {
  esqueleto = { hoja = "Characters/Esbirro_esqueleto.png", idx = 0 },
  espectro = { hoja = "Characters/Esbirro_espectro.png", idx = 0 },
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
  skin_gladiador = { generada = "gladiador", idx = 0 },
  skin_barbaro = { generada = "barbaro", idx = 0 },
  skin_archimago = { generada = "archimago", idx = 0 },
  skin_hechicero_fuego = { generada = "hechicero_fuego", idx = 0 },
  skin_montaraz = { generada = "montaraz", idx = 0 },
  skin_arquero_elfico = { generada = "arquero_elfico", idx = 0 },
  skin_sacerdotisa_alba = { generada = "sacerdotisa_alba", idx = 0 },
  skin_hoplita = { generada = "hoplita", idx = 0 },
  skin_senor_huesos = { generada = "senor_huesos", idx = 0 },
  skin_dama_lich = { generada = "dama_lich", idx = 0 },
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

-- Los addons que vienen de las láminas del pack llevan además un arma dibujada por código (render/propias.lua): su sprite
-- pasa a ser el diseño generado "arma_<id>", que es la misma hoja con el arma en la mano.
do
  local Propias = require("src.presentacion.render.propias")
  for id, def in pairs(P.skins) do
    if not def.generada then
      local diseno = Propias.registrarArma(id, def)
      if diseno then P.skins[id] = { generada = diseno, idx = 0, celda = def.celda } end
    end
  end
end

P.npc = {
  mercado = {
    albor = { generada = "clase_clerigo_albor", hoja = "Characters/Actor5.png", idx = 0 },
    umbra = { generada = "clase_clerigo_umbra", hoja = "Characters/Actor5.png", idx = 0 },
  },
  heraldo = { hoja = "Characters/People4.png", idx = 0 },
  aldeano = { variantes = {
    { hoja = "Characters/People1.png", idx = 0 }, { hoja = "Characters/People1.png", idx = 1 },
    { hoja = "Characters/People1.png", idx = 3 }, { hoja = "Characters/People1.png", idx = 5 },
    { hoja = "Characters/People2.png", idx = 0 }, { hoja = "Characters/People2.png", idx = 1 },
    { hoja = "Characters/People2.png", idx = 2 }, { hoja = "Characters/People2.png", idx = 4 },
    { hoja = "Characters/People3.png", idx = 0 }, { hoja = "Characters/People3.png", idx = 1 },
    { hoja = "Characters/People3.png", idx = 2 }, { hoja = "Characters/People3.png", idx = 4 },
  } },
  mayordomo = { hoja = "Characters/People4.png", idx = 5 },
  -- PNJ de misiones de los puestos del mapa: viajeros y exploradores de aspecto variado
  misiones = { variantes = {
    { hoja = "Characters/People3.png", idx = 1 }, { hoja = "Characters/People3.png", idx = 4 },
    { hoja = "Characters/People1.png", idx = 4 }, { hoja = "Characters/People2.png", idx = 3 },
  } },
  encargos = { hoja = "Characters/People1.png", idx = 4 },
  encantador = { hoja = "Characters/Actor2.png", idx = 7 },
  criador = { hoja = "Characters/People1.png", idx = 2 },
  gremio = { hoja = "Characters/People2.png", idx = 3 },
  oficios = { hoja = "Characters/People4.png", idx = 4 },
  comercio = { hoja = "Characters/People3.png", idx = 3 },
  barquero = { hoja = "Characters/People3.png", idx = 1 },
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
  -- las cuatro monturas nuevas se dibujan por codigo con la paleta de la facción del jinete
  corcel_real = { porFaccion = "montura_corcel" },
  lobo_guerra = { porFaccion = "montura_lobo" },
  bisonte_guerra = { porFaccion = "montura_bisonte" },
  corcel_fuego = { porFaccion = "montura_fuego" },
  -- el dragon del Item Mall es mas grande: se dibuja a escala y el jinete va mas alto
  dragon = { porFaccion = "montura_dragon", escala = 1.35, altura = 20, extraFrente = 14 },
  -- monturas vistosas de la cuadra y del Item Mall (efectos en render/monturas_fx.lua)
  unicornio = { porFaccion = "montura_unicornio" },
  lobo_ascua = { porFaccion = "montura_lobo_ascua" },
  lobo_escarcha = { porFaccion = "montura_lobo_escarcha" },
  toro_trueno = { porFaccion = "montura_toro_trueno" },
  pegaso = { porFaccion = "montura_pegaso" },
  fenix = { porFaccion = "montura_fenix", escala = 1.4, altura = 18, extraFrente = 12 },
  corcel_astral = { porFaccion = "montura_corcel_astral" },
  dragon_hielo = { porFaccion = "montura_dragon_hielo", escala = 1.35, altura = 20, extraFrente = 14 },
  dragon_sombra = { porFaccion = "montura_dragon_sombra", escala = 1.35, altura = 20, extraFrente = 14 },
  gargola_oro = { porFaccion = "montura_gargola_oro", escala = 1.25, altura = 16, extraFrente = 12 },
}

-- Dibujo de una montura para un jinete de esa facción.
local cacheMonturas = {}
function P.monturaDe(especie, faccion)
  local m = P.monturas[especie]
  if not m or not m.porFaccion then return m end
  local f = faccion == "umbra" and "umbra" or "albor"
  local k = especie .. "|" .. f
  if not cacheMonturas[k] then
    cacheMonturas[k] = { generada = m.porFaccion .. "_" .. f, hoja = "Characters/Animal.png", idx = 0, escala = m.escala, altura = m.altura, extraFrente = m.extraFrente }
  end
  return cacheMonturas[k]
end

P.monstruos = {
  jefe_manada = { hoja = "Characters/Animal.png", idx = 6, tinte = { 1, 0.55, 0.5 } },
  sectario_mayor = { hoja = "Characters/Evil.png", idx = 5, tinte = { 0.85, 0.7, 1 } },
  reina_avispa = { hoja = "Characters/Monster3.png", idx = 2, tinte = { 1, 0.9, 0.5 } },
  oso_gigante = { hoja = "Characters/$BigMonster1.png", fila = 2, tinte = { 0.85, 0.7, 0.55 } },
  coloso = { hoja = "Characters/$BigMonster1.png", fila = 1, tinte = { 0.7, 0.75, 0.85 } },
  gigante_guerra = { hoja = "Characters/$BigMonster2.png", fila = 2, celda = 80, tinte = { 1, 0.7, 0.7 } },
  bandido = { hoja = "Characters/People7.png", idx = 1, tinte = { 0.85, 0.75, 0.75 } },
  asaltante = { hoja = "Characters/Actor3.png", idx = 6 },
  saqueador = { hoja = "Characters/Evil.png", idx = 6, tinte = { 0.9, 0.8, 0.8 } },
  gato = { hoja = "Characters/Animal.png", idx = 1 },
  -- criaturas con animación por cuadros (render/mob_anim.lua); la hoja es solo un respaldo para otros usos
  calabaza = { anim = "calabaza", hoja = "Characters/Animal.png", idx = 1 },
  limo = { anim = "limo", hoja = "Characters/Animal.png", idx = 1 },
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
  dragon = { hoja = "Characters/$BigMonster2.png", fila = 1, celda = 80 },
  liche = { hoja = "Characters/Evil.png", idx = 5 },
  behemot = { hoja = "Characters/$BigMonster2.png", fila = 2, celda = 80 },
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
    -- personajes por capas (arte/fao): sin addon ni oficio con aspecto propio
    if require("src.presentacion.render.fao").activo() then return { fao = e } end
    local c = P.clases[e.clase or "guerrero"] or P.clases.guerrero
    return c[e.faccion or "albor"] or c.albor
  elseif k == "guardia" then
    return P.npc.guardia[e.faccion or "albor"] or P.npc.guardia.albor
  elseif k == "npc" then
    local d = P.npc[e.rol or "mercado"] or P.npc.mercado
    if d.variantes then
      local suma = 0
      for i = 1, #tostring(e.id or "") do suma = suma + tostring(e.id):byte(i) end
      return d.variantes[suma % #d.variantes + 1]
    end
    if d.albor then return d[e.faccion or "albor"] or d.albor end
    return d
  elseif k == "monstruo" then
    return P.monstruos[e.monstruo or ""] or P.monstruos.gato
  elseif k == "mascota" then
    return P.mascotas[e.especie or ""] or P.mascotas.gatito
  elseif k == "esbirro" then
    return P.esbirros[e.especie or ""] or P.esbirros.esqueleto
  end
end

-- Aspecto de quien va montado: igual que a pie, salvo los addons de jinete (hoja Riding), que ya traen
-- su propio caballo: sobre una montura se usa el personaje base de su clase, asi todas las monturas
-- se ven igual con cualquier addon y no se montan dos caballos uno sobre otro.
function P.jineteDe(e, def)
  def = def or P.de(e)
  if e.montado and def and def.celda then
    local c = P.clases[e.clase or "guerrero"] or P.clases.guerrero
    return c[e.faccion or "albor"] or c.albor
  end
  return def
end

-- Dibuja la criatura con los pies en (sx, sy). mov: está andando; reloj: segundos.
function P.dibujar(def, dir, mov, reloj, sx, sy, tinte, alfa)
  if def.fao then return require("src.presentacion.render.fao").dibujar(def.fao, mov, sx, sy, tinte, alfa) end
  -- las skins propias del mall se dibujan por código (render/propias.lua)
  local img = def.generada and require("src.presentacion.render.propias").hoja(def.generada) or Arte.img(def.hoja)
  local col = mov and CICLO[(math.floor(reloj * 8) % 4) + 1] or 1
  local c = tinte or def.tinte
  if c then love.graphics.setColor(c[1], c[2], c[3], alfa or 1)
  else love.graphics.setColor(1, 1, 1, alfa or 1) end
  if def.fila then
    local celda = def.celda or 64
    local q = Arte.quad(img, col * celda, def.fila * celda, celda, celda)
    love.graphics.draw(img, q, sx, sy, 0, 1, 1, celda / 2, celda - 2)
    return celda
  end
  -- hojas con casillas de 32 px (la mayoria) o de 48 px (jinetes, hoja Riding)
  local c = def.celda or 32
  local ox = (def.idx % 4) * c * 3
  local oy = math.floor(def.idx / 4) * c * 4
  local fila = FILA_DIR[dir or 1] or 0
  local k = def.escala or 1
  love.graphics.draw(img, Arte.quad(img, ox + col * c, oy + fila * c, c, c), sx, sy, 0, k, k, c / 2, c - 2)
  return c * k
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
