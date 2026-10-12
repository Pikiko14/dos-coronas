local Balance = require("compartido.dominio.balance")

local D = {}

D.SEMILLA = 20261011
-- El continente se dibuja sobre un lienzo de 720x520 que se amplía por ESCALA: las ciudades
-- se separan (conservan su tamaño) y entre ellas queda mucho más camino que recorrer.
D.ESCALA = 1.6
D.MAPA_W = math.floor(720 * D.ESCALA)
D.MAPA_H = math.floor(520 * D.ESCALA)
D.TILE = 32
D.ZOOM = 2
D.NIVEL_MAX = 30
-- Espacios de la bolsa: sin mochila hay BOLSA_BASE; cada mochila trae su propio total.
-- BOLSA es el máximo posible (la mejor mochila).
D.BOLSA_BASE = 8
D.BOLSA = 24
D.JUGADORES_EVENTO = 3

D.facciones = {
  albor = {
    id = "albor", nombre = "Albor",
    titulo = "Corona del Amanecer",
    color = { 0.95, 0.78, 0.28 },
    texto = "Tierras de trigo, puertos dorados y muros claros. Albor guarda la corona del día.",
  },
  umbra = {
    id = "umbra", nombre = "Umbra",
    titulo = "Corona del Ocaso",
    color = { 0.62, 0.42, 0.95 },
    texto = "Ciénagas, puertos negros y fe de sombras. Umbra reclama la corona de la noche.",
  },
}

D.clases = {
  guerrero = {
    id = "guerrero", nombre = "Guerrero", rol = "Tanque y daño cuerpo a cuerpo",
    hp = 160, mp = 50, atk = 15, def = 9, spd = 4.4,
    hpN = 24, mpN = 4, atkN = 2.3, defN = 1.5,
    matk = 4, mdef = 3, matkN = 0.5, mdefN = 0.6, danoBasico = "fisico", danoMul = 1.0,
    rango = 1.35, cuerpo = "cuerpo", arma = "espada",
    hoja = "humanos", base = 0, cuadros = 1, porDir = 1,
    recorte = { x = 52, y = 124, w = 68, h = 84, mano = { x = 14, y = 34 } },
    desc = "Aguanta el frente, parte a los enemigos en área y se lanza contra las líneas.",
  },
  mago = {
    id = "mago", nombre = "Mago", rol = "Daño mágico a distancia",
    hp = 100, mp = 150, atk = 5, def = 3, spd = 4.5,
    hpN = 13, mpN = 18, atkN = 0.7, defN = 0.5,
    matk = 17, mdef = 8, matkN = 2.7, mdefN = 1.3, danoBasico = "magico", danoMul = 0.75,
    rango = 6.6, cuerpo = "cuerpo", arma = "baston",
    hoja = "humanos", base = 0, cuadros = 1, porDir = 1,
    recorte = { x = 340, y = 20, w = 68, h = 84, mano = { x = 50, y = 40 } },
    desc = "Quema y hiela desde lejos. Frágil, y devastador si lo dejan lanzar.",
  },
  cazador = {
    id = "cazador", nombre = "Cazador", rol = "Daño físico a distancia",
    hp = 118, mp = 90, atk = 16, def = 5, spd = 4.9,
    hpN = 15, mpN = 8, atkN = 2.5, defN = 0.8,
    matk = 5, mdef = 4, matkN = 0.6, mdefN = 0.7, danoBasico = "fisico", danoMul = 0.8,
    rango = 6.8, cuerpo = "cuerpo", arma = "arco",
    hoja = "humanos", base = 0, cuadros = 1, porDir = 1,
    recorte = { x = 228, y = 24, w = 96, h = 84, mano = { x = 52, y = 50 } },
    desc = "Dispara, coloca trampas y hace llover flechas sobre el campo.",
  },
  clerigo = {
    id = "clerigo", nombre = "Clérigo", rol = "Curación, apoyo y castigo",
    hp = 128, mp = 140, atk = 5, def = 6, spd = 4.55,
    hpN = 17, mpN = 15, atkN = 0.6, defN = 1.2,
    matk = 11, mdef = 8, matkN = 1.8, mdefN = 1.4, danoBasico = "magico", danoMul = 1.0,
    rango = 5.8, cuerpo = "cuerpo", arma = "maza", proyectil = true,
    hoja = "humanos", base = 0, cuadros = 1, porDir = 1,
    recorte = { x = 56, y = 220, w = 68, h = 88, mano = { x = 58, y = 56 } },
    desc = "Cura y bendice a los suyos, y castiga con luz a quien se acerque.",
  },
}

D.habilidades = {
  golpe = { nombre = "Golpe", clase = "guerrero", cd = 1.6, mana = 0, tipo = "enemigo", coef = 1.15, rango = 1.45, desc = "Un golpe firme con el arma." },
  tajo = { nombre = "Tajo", clase = "guerrero", cd = 7, mana = 14, tipo = "alrededor", coef = 0.9, rango = 2.1, desc = "Golpea a todos los enemigos cercanos." },
  grito = { nombre = "Grito de guerra", clase = "guerrero", cd = 16, mana = 18, tipo = "buff_alrededor", buff = "grito", dur = 8, rango = 4.5, desc = "Aumenta el ataque de los aliados cercanos." },
  desgarro = { nombre = "Desgarro", clase = "guerrero", cd = 9, mana = 20, tipo = "enemigo", coef = 1.6, rango = 1.45, desc = "Un tajo profundo que abre una herida." },
  furia = { nombre = "Furia", clase = "guerrero", cd = 32, mana = 28, tipo = "propio", buff = "furia", dur = 10, efecto = { atk = 0.3 }, desc = "Tu ataque crece mucho durante un rato." },
  carga = { nombre = "Carga", clase = "guerrero", cd = 11, mana = 12, tipo = "enemigo", coef = 0.75, rango = 5.5, dash = true, aturde = 0.8, desc = "Te lanzas al objetivo y lo aturdes un instante." },

  misil = { nombre = "Misil arcano", clase = "mago", cd = 1.0, mana = 8, tipo = "enemigo", coef = 1.25, rango = 7.2, proyectil = "misil", dano = "magico", desc = "Un dardo de energía." },
  fuego = { nombre = "Bola de fuego", clase = "mago", cd = 3, mana = 24, tipo = "enemigo", coef = 1.55, rango = 7.2, proyectil = "fuego", aoe = 1.8, dano = "magico", desc = "Estalla al impactar." },
  escudo = { nombre = "Escudo arcano", clase = "mago", cd = 14, mana = 20, tipo = "propio", buff = "escudo", dur = 8, desc = "Absorbe parte del daño." },
  sombra = { nombre = "Descarga de sombras", clase = "mago", cd = 6, mana = 26, tipo = "enemigo", coef = 1.2, rango = 7, proyectil = "sombra", dano = "magico", desc = "Una descarga oscura que drena vida." },
  meteoro = { nombre = "Meteoro", clase = "mago", cd = 22, mana = 45, tipo = "punto", coef = 2.3, rango = 8, aoe = 2.6, dano = "magico", desc = "Una roca en llamas cae sobre la zona." },
  nova = { nombre = "Nova de hielo", clase = "mago", cd = 10, mana = 22, tipo = "alrededor", coef = 0.85, rango = 2.8, lentitud = 0.45, dano = "magico", desc = "Hiela y ralentiza alrededor." },

  disparo = { nombre = "Disparo", clase = "cazador", cd = 1.05, mana = 6, tipo = "enemigo", coef = 1.15, rango = 7.4, proyectil = "flecha", desc = "Una flecha rápida." },
  lluvia = { nombre = "Lluvia de flechas", clase = "cazador", cd = 8, mana = 22, tipo = "punto", coef = 0.8, rango = 7.4, aoe = 2.2, desc = "Flechas sobre una zona." },
  flecha_veneno = { nombre = "Flecha envenenada", clase = "cazador", cd = 7, mana = 16, tipo = "enemigo", coef = 1.0, rango = 7.4, proyectil = "flecha", desc = "Una flecha untada que envenena." },
  paso_agil = { nombre = "Paso ágil", clase = "cazador", cd = 18, mana = 14, tipo = "propio", buff = "agil", dur = 5, efecto = { vel = 0.5 }, desc = "Corres mucho más rápido un momento." },
  trampa = { nombre = "Trampa", clase = "cazador", cd = 14, mana = 16, tipo = "suelo", rango = 1.2, desc = "Inmoviliza al primer enemigo que la pisa." },
  preciso = { nombre = "Tiro preciso", clase = "cazador", cd = 8, mana = 18, tipo = "enemigo", coef = 2.05, rango = 8.2, proyectil = "flecha", desc = "Un disparo devastador." },

  curar = { nombre = "Curación", clase = "clerigo", cd = 2.1, mana = 16, tipo = "aliado", cura = 28, curaN = 5, rango = 6.5, desc = "Restaura vida a un aliado o a ti." },
  bendicion = { nombre = "Bendición", clase = "clerigo", cd = 12, mana = 20, tipo = "aliado", buff = "bendicion", dur = 10, rango = 6.5, desc = "Sube la defensa y regenera." },
  castigo = { nombre = "Castigo", clase = "clerigo", cd = 1.35, mana = 10, tipo = "enemigo", coef = 1.12, rango = 6.4, proyectil = "sagrado", dano = "magico", desc = "Luz que hiere. El clérigo también ataca." },
  sanacion = { nombre = "Luz sanadora", clase = "clerigo", cd = 15, mana = 38, tipo = "aliados", cura = 22, curaN = 4, rango = 4.5, desc = "Cura a todos los aliados cercanos." },
  juicio = { nombre = "Juicio divino", clase = "clerigo", cd = 16, mana = 34, tipo = "enemigo", coef = 2.3, rango = 6.4, proyectil = "sagrado", dano = "magico", aturde = 1.2, desc = "Un haz de luz que hiere y aturde." },
  consagrar = { nombre = "Consagración", clase = "clerigo", cd = 10, mana = 28, tipo = "mixto", coef = 0.9, cura = 18, curaN = 2, rango = 2.8, dano = "magico", desc = "Daña enemigos y cura aliados a tu alrededor." },
}

-- Estado que cada poder puede aplicar al golpear y con qué probabilidad (sube con el rango).
-- Los valores no puestos (duración, fuerza) salen de Estados.def.
local ESTADO_PODER = {
  golpe = { tipo = "sangrar", prob = 0.12 },
  tajo = { tipo = "sangrar", prob = 0.30 },
  misil = { tipo = "lentitud", prob = 0.12, dur = 2, pct = 0.3 },
  fuego = { tipo = "quemar", prob = 0.30 },
  disparo = { tipo = "sangrar", prob = 0.12 },
  lluvia = { tipo = "lentitud", prob = 0.25, dur = 3, pct = 0.35 },
  preciso = { tipo = "sangrar", prob = 0.40, dur = 6 },
  castigo = { tipo = "quemar", prob = 0.20 },
  consagrar = { tipo = "aturdir", prob = 0.15, dur = 1.0 },
  desgarro = { tipo = "sangrar", prob = 0.85, dur = 6 },
  sombra = { tipo = "drenar_vida", prob = 0.9 },
  meteoro = { tipo = "quemar", prob = 0.6, dur = 5 },
  flecha_veneno = { tipo = "veneno", prob = 1, dur = 7 },
}
for id, ef in pairs(ESTADO_PODER) do D.habilidades[id].estado = ef end
D.barra = {
  guerrero = { "golpe", "tajo", "grito", "carga", "desgarro", "furia" },
  mago = { "misil", "fuego", "escudo", "nova", "sombra", "meteoro" },
  cazador = { "disparo", "lluvia", "trampa", "preciso", "flecha_veneno", "paso_agil" },
  clerigo = { "curar", "bendicion", "castigo", "consagrar", "sanacion", "juicio" },
}

-- Continente ampliado (ver ESCALA). Las arterias de camino unen las ciudades de cada fila.
-- Cada ciudad trae su bioma: el halo alrededor y los monstruos que lo habitan.
D.ciudades = {
  { id = "auroria", nombre = "Auroria", faccion = "albor", x = 168, y = 190, capital = true, bioma = "trigal" },
  { id = "puerto_sol", nombre = "Puerto del Sol", faccion = "albor", x = 120, y = 108, acceso = "sur", bioma = "muelle" },
  { id = "henar", nombre = "Campos de Henar", faccion = "albor", x = 250, y = 108, acceso = "sur", bioma = "campos" },
  { id = "liria", nombre = "Liria", faccion = "albor", x = 120, y = 312, acceso = "norte", bioma = "senda" },
  { id = "alba", nombre = "Bastión del Alba", faccion = "albor", x = 250, y = 312, acceso = "norte", bioma = "colina" },
  { id = "nocturnia", nombre = "Nocturnia", faccion = "umbra", x = 480, y = 190, capital = true, bioma = "velo" },
  { id = "puerto_sombra", nombre = "Puerto Sombra", faccion = "umbra", x = 430, y = 108, acceso = "sur", bioma = "marea" },
  { id = "velo", nombre = "Ciénaga del Velo", faccion = "umbra", x = 552, y = 108, acceso = "sur", bioma = "cienaga" },
  { id = "nox", nombre = "Nox", faccion = "umbra", x = 430, y = 312, acceso = "norte", bioma = "pinar" },
  { id = "eclipse", nombre = "Bastión del Eclipse", faccion = "umbra", x = 552, y = 312, acceso = "norte", bioma = "eclipse" },
}

-- Aleja las ciudades: la posición de cada centro se amplía respecto al centro del mapa.
for _, c in ipairs(D.ciudades) do
  local ancho = c.capital and 72 or 48
  local alto = c.capital and 56 or 36
  local cx0, cy0 = c.x + ancho / 2, c.y + alto / 2
  local ncx = D.MAPA_W / 2 + (cx0 - 360) * D.ESCALA
  local ncy = D.MAPA_H / 2 + (cy0 - 260) * D.ESCALA
  c.x = math.floor(ncx - ancho / 2)
  c.y = math.floor(ncy - alto / 2)
end

D.biomas = {
  trigal = { suelo = "hierba", nombre = "Trigal de Auroria" },
  muelle = { suelo = "arena", nombre = "Muelles del Sol" },
  campos = { suelo = "tierra", nombre = "Campos de Henar" },
  senda = { suelo = "bosque", nombre = "Senda de Liria" },
  colina = { suelo = "hierba", nombre = "Colinas del Alba" },
  velo = { suelo = "hierba_osc", nombre = "Velo de Nocturnia" },
  marea = { suelo = "arena", nombre = "Marea de Sombra" },
  cienaga = { suelo = "hierba_osc", nombre = "Ciénaga del Velo" },
  pinar = { suelo = "bosque", nombre = "Pinar de Nox" },
  eclipse = { suelo = "cicatriz", nombre = "Ruinas del Eclipse" },
}

D.misiones = {
  { id = "q_auroria", ciudad = "auroria", titulo = "Gatos en el granero", texto = "Los gatos umbríos se han vuelto bravos. Derrota 6.", dialogo = "Esos gatos no dejan en paz el granero. Derrota seis.", siguiente = "q_auroria_2", monstruo = "gato", cantidad = 6, oro = 90, xp = 80 },
  { id = "q_auroria_2", ciudad = "auroria", requiere = "q_auroria", titulo = "El nido del granero", texto = "Quedan las crías entre la paja. Derrota 4.", dialogo = "El granero sigue inquieto. Acaba con cuatro más.", monstruo = "gato", cantidad = 4, oro = 70, xp = 60 },
  { id = "q_puerto_sol", ciudad = "puerto_sol", titulo = "Ratones de muelle", texto = "Las ratas gigantes muerden las redes. Derrota 8.", monstruo = "rata", cantidad = 8, oro = 100, xp = 90 },
  { id = "q_liria", ciudad = "liria", titulo = "Jabalíes en la senda", texto = "Derrota 6 jabalíes al sur de Liria.", monstruo = "jabali", cantidad = 6, oro = 120, xp = 110 },
  { id = "q_henar", ciudad = "henar", titulo = "Escarabajos del trigo", texto = "Derrota 8 escarabajos.", monstruo = "escarabajo", cantidad = 8, oro = 110, xp = 100 },
  { id = "q_alba", ciudad = "alba", titulo = "Murciélagos del bastión", texto = "Derrota 8 murciélagos.", monstruo = "cuervo", cantidad = 8, oro = 130, xp = 120 },
  { id = "q_nocturnia", ciudad = "nocturnia", titulo = "Almas del velo", texto = "Derrota 6 almas verdes.", monstruo = "alma_verde", cantidad = 6, oro = 160, xp = 150 },
  { id = "q_puerto_sombra", ciudad = "puerto_sombra", titulo = "Demonios de marea", texto = "Derrota 5 demonios de marea.", monstruo = "demonio_marea", cantidad = 5, oro = 180, xp = 170 },
  { id = "q_nox", ciudad = "nox", titulo = "Avispones de Nox", texto = "Derrota 6 avispones.", monstruo = "aguila", cantidad = 6, oro = 140, xp = 130 },
  { id = "q_velo", ciudad = "velo", titulo = "Espectros de la ciénaga", texto = "Derrota 6 espectros.", monstruo = "espectro", cantidad = 6, oro = 170, xp = 160 },
  { id = "q_eclipse", ciudad = "eclipse", titulo = "Gárgolas del eclipse", texto = "Derrota 5 gárgolas.", monstruo = "gargola", cantidad = 5, oro = 200, xp = 180 },
}

-- 30 criaturas. Los índices salen de las láminas otsp_creatures_*.
-- tam=2 y paso=2: sprite de 64×64 (2×2 celdas) con el siguiente cuadro dos celdas a la derecha.
D.monstruos = {
  { id = "gato", nombre = "Gato umbrío", nivel = 1, bioma = "trigal", hoja = "creatures_01", base = 1, cuadros = 12, agresivo = false, desc = "Pequeño, rápido y más bravo de lo que parece." },
  { id = "cuervo", nombre = "Murciélago gris", nivel = 2, bioma = "trigal", hoja = "creatures_02", base = 16, cuadros = 12, agresivo = false, desc = "Cuelga de los graneros y baja al anochecer." },
  { id = "jabali", nombre = "Jabalí bronco", nivel = 3, bioma = "trigal", hoja = "creatures_01", base = 67, cuadros = 8, agresivo = true, desc = "Carga si te acercas al matorral." },
  { id = "rata", nombre = "Rata de muelle", nivel = 3, bioma = "muelle", hoja = "creatures_01", base = 48, cuadros = 8, agresivo = true, desc = "Sale de los muelles en manada." },
  { id = "escarabajo", nombre = "Escarabajo de seto", nivel = 5, bioma = "muelle", hoja = "creatures_02", base = 1, cuadros = 12, agresivo = true, desc = "Caparazón duro y mandíbulas pacientes." },
  { id = "jabali_fuego", nombre = "Jabalí de brasas", nivel = 7, bioma = "muelle", hoja = "creatures_01", base = 75, cuadros = 4, agresivo = true, desc = "El pelaje le humea. Duele más de cerca." },
  { id = "aguila", nombre = "Avispón de Henar", nivel = 6, bioma = "campos", hoja = "creatures_01", base = 32, cuadros = 12, agresivo = true, vuela = true, desc = "Cae en picado sobre los sembrados con su aguijón." },
  { id = "oso", nombre = "Oso de colina", nivel = 9, bioma = "campos", hoja = "creatures_01", base = 112, cuadros = 8, tam = 2, paso = 2, porDir = 2, agresivo = true, desc = "Ocupa el camino entero." },
  { id = "elefante", nombre = "Bestia de asedio", nivel = 12, bioma = "campos", hoja = "creatures_01", base = 176, cuadros = 8, tam = 2, paso = 2, porDir = 2, agresivo = true, desc = "Una bestia de asedio suelta." },
  { id = "espectro", nombre = "Espectro pálido", nivel = 8, bioma = "senda", hoja = "creatures_01", base = 56, cuadros = 8, agresivo = true, desc = "Un muerto que no recuerda su nombre." },
  { id = "gargola", nombre = "Gárgola", nivel = 10, bioma = "senda", hoja = "creatures_01", base = 16, cuadros = 12, agresivo = true, desc = "Piedra viva que despega de los muros." },
  { id = "automata", nombre = "Autómata", nivel = 12, bioma = "senda", hoja = "creatures_01", base = 28, cuadros = 4, porDir = 1, agresivo = true, desc = "Engranajes y un hacha oxidada." },
  { id = "alma", nombre = "Alma pálida", nivel = 11, bioma = "colina", hoja = "creatures_03", base = 752, cuadros = 12, agresivo = true, desc = "Luz fría sin cuerpo." },
  { id = "troll", nombre = "Troll de puente", nivel = 14, bioma = "colina", hoja = "creatures_02", base = 224, cuadros = 12, agresivo = true, desc = "Cobra peaje en huesos." },
  { id = "caballero", nombre = "Caballero caído", nivel = 16, bioma = "colina", hoja = "creatures_01", base = 816, cuadros = 12, agresivo = true, desc = "Sigue una orden que ya nadie dio." },
  { id = "alma_verde", nombre = "Alma del velo", nivel = 10, bioma = "velo", hoja = "creatures_03", base = 768, cuadros = 12, agresivo = true, desc = "Flota sobre la ciudad oscura." },
  { id = "cultista", nombre = "Cultista de Umbra", nivel = 13, bioma = "velo", hoja = "creatures_02", base = 48, cuadros = 8, agresivo = true, desc = "Reza en voz baja y golpea con el báculo." },
  { id = "alma_hielo", nombre = "Alma glacial", nivel = 16, bioma = "velo", hoja = "creatures_03", base = 784, cuadros = 12, agresivo = true, desc = "Quien la toca se queda lento." },
  { id = "demonio_musgo", nombre = "Demonio de musgo", nivel = 13, bioma = "cienaga", hoja = "creatures_03", base = 704, cuadros = 12, agresivo = true, desc = "Alas verdes y garras de raíz." },
  { id = "saurio", nombre = "Escorpión de ciénaga", nivel = 16, bioma = "cienaga", hoja = "creatures_02", base = 96, cuadros = 4, agresivo = true, desc = "Pinzas antiguas, hambre nueva." },
  { id = "bruja", nombre = "Bruja de la ciénaga", nivel = 18, bioma = "cienaga", hoja = "creatures_02", base = 832, cuadros = 12, agresivo = true, desc = "Conoce el nombre de quien pisa su círculo." },
  { id = "demonio_marea", nombre = "Demonio de marea", nivel = 17, bioma = "marea", hoja = "creatures_03", base = 720, cuadros = 12, agresivo = true, desc = "Sale del agua con la marea alta." },
  { id = "quimera", nombre = "Quimera menor", nivel = 19, bioma = "marea", hoja = "creatures_02", base = 192, cuadros = 12, agresivo = true, desc = "Varias fauces, un solo hambre." },
  { id = "hidra", nombre = "Hidra sombría", nivel = 21, bioma = "marea", hoja = "creatures_02", base = 320, cuadros = 8, tam = 2, paso = 2, porDir = 2, agresivo = true, desc = "Cada cuello muerde por su cuenta." },
  { id = "golem", nombre = "Gólem de escoria", nivel = 18, bioma = "pinar", hoja = "creatures_01", base = 256, cuadros = 12, agresivo = true, desc = "Piedra fundida que aún camina." },
  { id = "demonio_foso", nombre = "Demonio de foso", nivel = 22, bioma = "pinar", hoja = "creatures_03", base = 736, cuadros = 12, agresivo = true, desc = "El pinar lo escupe de noche." },
  { id = "titan", nombre = "Titán de escoria", nivel = 25, bioma = "pinar", hoja = "creatures_04", base = 64, cuadros = 4, tam = 2, paso = 2, porDir = 2, agresivo = true, desc = "El suelo se queja cuando anda." },
  { id = "dragon", nombre = "Dragón joven", nivel = 24, bioma = "eclipse", hoja = "creatures_04", base = 0, cuadros = 4, tam = 2, paso = 2, porDir = 2, agresivo = true, desc = "Aún no es antiguo. Ya es bastante." },
  { id = "liche", nombre = "Liche de Eclipse", nivel = 27, bioma = "eclipse", hoja = "creatures_03", base = 800, cuadros = 12, agresivo = true, desc = "Corona de hueso y un libro que no se cierra." },
  { id = "behemot", nombre = "Behemot de guerra", nivel = 30, bioma = "eclipse", hoja = "creatures_04", base = 128, cuadros = 4, tam = 2, paso = 2, porDir = 2, elite = true, agresivo = true, desc = "Uno solo. Cuando cae, la guerra lo nota." },
}

-- Efectos de las criaturas: golpe = estados que pueden aplicar al pegar; poderes = poderes
-- propios (ver Estados.poderes). Cada una tiene los suyos para que no se parezcan.
local EFECTOS_MONSTRUO = {
  gato = { golpe = { { tipo = "sangrar", prob = 0.15 } } },
  cuervo = { poderes = { "succion" } },
  jabali = { golpe = { { tipo = "aturdir", prob = 0.10, dur = 0.8 } } },
  rata = { golpe = { { tipo = "veneno", prob = 0.25 } } },
  escarabajo = { golpe = { { tipo = "lentitud", prob = 0.25 } } },
  jabali_fuego = { golpe = { { tipo = "quemar", prob = 0.25 } } },
  aguila = { golpe = { { tipo = "veneno", prob = 0.30 } } },
  oso = { golpe = { { tipo = "sangrar", prob = 0.20 } } },
  elefante = { poderes = { "pisoton" } },
  espectro = { poderes = { "drenaje" } },
  gargola = { golpe = { { tipo = "aturdir", prob = 0.10, dur = 0.9 } } },
  automata = { golpe = { { tipo = "sangrar", prob = 0.25 } } },
  alma = { golpe = { { tipo = "drenar_mana", prob = 0.30 } } },
  troll = { golpe = { { tipo = "aturdir", prob = 0.15 } } },
  caballero = { golpe = { { tipo = "sangrar", prob = 0.25 } } },
  alma_verde = { golpe = { { tipo = "veneno", prob = 0.30 } } },
  cultista = { poderes = { "succion" } },
  alma_hielo = { golpe = { { tipo = "lentitud", prob = 0.40, dur = 4, pct = 0.5 } } },
  demonio_musgo = { golpe = { { tipo = "veneno", prob = 0.30 } }, poderes = { "maldicion" } },
  saurio = { golpe = { { tipo = "veneno", prob = 0.40 } } },
  bruja = { golpe = { { tipo = "drenar_mana", prob = 0.20 } }, poderes = { "maldicion" } },
  demonio_marea = { poderes = { "drenaje" } },
  quimera = { golpe = { { tipo = "quemar", prob = 0.25 } } },
  hidra = { golpe = { { tipo = "veneno", prob = 0.35 }, { tipo = "sangrar", prob = 0.20 } } },
  golem = { poderes = { "pisoton" } },
  demonio_foso = { golpe = { { tipo = "quemar", prob = 0.30 } }, poderes = { "succion" } },
  titan = { golpe = { { tipo = "lentitud", prob = 0.25 } }, poderes = { "pisoton" } },
  dragon = { golpe = { { tipo = "quemar", prob = 0.20 } }, poderes = { "aliento" } },
  liche = { poderes = { "succion", "drenaje" } },
  behemot = { golpe = { { tipo = "aturdir", prob = 0.20 }, { tipo = "sangrar", prob = 0.25 } }, poderes = { "pisoton" } },
}
for _, m in ipairs(D.monstruos) do
  local x = EFECTOS_MONSTRUO[m.id]
  if x then m.golpe, m.poderes = x.golpe, x.poderes end
end
-- Bandidos: no tienen campamento; salen a emboscar caravanas (ver caravanas.lua).
for _, b in ipairs({
  { id = "bandido", nombre = "Bandido del camino", nivel = 8, desc = "Asalta caravanas con un cuchillo oxidado." },
  { id = "asaltante", nombre = "Asaltante", nivel = 16, desc = "Curtido en cien emboscadas." },
  { id = "saqueador", nombre = "Saqueador de rutas", nivel = 24, desc = "Lidera bandas que arrasan los convoyes." },
}) do
  b.hoja, b.base, b.cuadros, b.agresivo, b.bandido, b.noCampamento = "creatures_01", 0, 4, true, true, true
  b.golpe = ({
    bandido = { { tipo = "sangrar", prob = 0.20 } },
    asaltante = { { tipo = "sangrar", prob = 0.25 }, { tipo = "aturdir", prob = 0.10 } },
    saqueador = { { tipo = "sangrar", prob = 0.30 }, { tipo = "aturdir", prob = 0.15 } },
  })[b.id]
  D.monstruos[#D.monstruos + 1] = b
end

-- Criaturas que pegan con magia: tienen más ataque y defensa mágicos que físicos.
local MAGICOS = {
  espectro = true, alma = true, alma_verde = true, alma_hielo = true, cultista = true,
  demonio_musgo = true, bruja = true, demonio_marea = true, quimera = true,
  demonio_foso = true, liche = true, dragon = true,
}
for _, m in ipairs(D.monstruos) do
  if MAGICOS[m.id] then m.magico = true end
end

D.tiles = {
  hierba = { 48, 49 },
  hierba_osc = { 66, 67 },
  bosque = { 64 },
  arena = { 112, 113, 116 },
  tierra = { 120, 121 },
  camino = { 120, 121 },
  agua = { 736, 737, 738, 739 },
  empedrado = { 309 },
  madera = { 282 },
  plaza = { 309 },
  adoquin = { 309 },
  muralla = { 270 },
  calle = { 120 },
  teja = { 294 },
  teja_umbra = { 286 },
  cicatriz = { 124 },
  tejado = { 294 },
}

D.props = {
  muro = { hoja = "walls", indice = 1 },
  muro_rojo = { hoja = "walls", indice = 65 },
  puerta = { hoja = "doors", indice = 9 },
  puerta_hierro = { hoja = "doors", indice = 15 },
  arbol = { hoja = "nature", indice = 449 },
  arbol_seco = { hoja = "nature", indice = 560 },
  arbol_pino = { hoja = "nature", indice = 470 },
  cofre = { hoja = "town", indice = 65 },
  caja = { hoja = "town", indice = 73 },
  barril = { hoja = "town", indice = 23 },
  mesa = { hoja = "town", indice = 7 },
  cama = { hoja = "town", indice = 18 },
  estatua = { hoja = "equipment", indice = 455 },
  cristal = { hoja = "equipment", indice = 359 },
  altar = { hoja = "town", indice = 22 },
}

-- Ajustes globales de las criaturas (ver servidor --calibrar): vida y ataque respecto a la fórmula base.
D.MONSTRUO_HP = 3.0
D.MONSTRUO_ATK = 1.05

function D.statsMonstruo(m)
  local n = m.nivel
  local elite = m.elite and 6 or 1
  local grande = (m.tam or 1) > 1 and 1.8 or 1
  local curva = n * n
  -- Un monstruo físico pega con atk y se defiende sobre todo con def; uno mágico,
  -- al revés. Lo que no es lo suyo vale el 30% (ataque) o el 50% (defensa).
  local atk0 = math.floor((4 + n * 1.45 + curva * 0.035) * D.MONSTRUO_ATK * (m.elite and 2.1 or 1))
  local def0 = math.floor((n * 0.9 + curva * 0.02) * (m.elite and 1.4 or 1))
  local magico = m.magico and true or false
  return {
    hp = math.floor((28 + n * 16 + curva * 0.85) * D.MONSTRUO_HP * elite * (m.elite and 1 or grande)),
    atk = magico and math.floor(atk0 * 0.3) or atk0,
    matk = magico and atk0 or math.floor(atk0 * 0.3),
    def = magico and math.floor(def0 * 0.5) or def0,
    mdef = magico and def0 or math.floor(def0 * 0.5),
    dano = magico and "magico" or "fisico",
    xp = Balance.xpMonstruo(n, n, m.elite),
    oro = math.floor((4 + n * 3 + curva * 0.08) * (m.elite and 4 or 1)),
    rango = m.vuela and 5.5 or (magico and 4.5 or 1.25),
    velocidad = m.elite and 3.4 or (2.5 + math.min(1.6, n * 0.055)),
  }
end

function D.xpPara(nivel)
  return Balance.xpPara(nivel)
end

D.items = {}
local function add(it)
  D.items[it.id] = it
end

-- Armas, armaduras, escudos, anillos y amuletos: ver items.lua.
require("compartido.dominio.items").generar(D)

-- Mochilas: el tipo de mochila equipada decide cuántos espacios tiene la bolsa.
local MOCHILAS = {
  { nombre = "Morral de tela", slots = 12, nivel = 1, precio = 45, sprite = 672 },
  { nombre = "Mochila de cuero", slots = 16, nivel = 5, precio = 180, sprite = 674 },
  { nombre = "Mochila de viajero", slots = 20, nivel = 10, precio = 520, sprite = 675 },
  { nombre = "Mochila de corona", slots = 24, nivel = 15, precio = 1300, sprite = 676 },
}
for tier, m in ipairs(MOCHILAS) do
  add({
    id = "mochila_" .. tier, nombre = m.nombre, hueco = "mochila", tier = tier, nivel = m.nivel,
    slots = m.slots, precio = m.precio, hoja = "equipment", sprite = m.sprite,
    texto = "Bolsa de " .. m.slots .. " espacios.",
  })
end

-- Espacios que da el equipo: el de la mochila puesta o los básicos.
function D.capacidadBolsa(equipo)
  local it = equipo and equipo.mochila and D.items[equipo.mochila]
  return it and it.slots or D.BOLSA_BASE
end

add({ id = "pocion_vida", nombre = "Poción de vida", apila = 20, precio = 18, cura = 0.42, hoja = "equipment", sprite = 704 })
add({ id = "pocion_mana", nombre = "Poción de maná", apila = 20, precio = 16, mana = 0.42, hoja = "equipment", sprite = 711 })
add({ id = "cristal", nombre = "Cristal enemigo", apila = 20, precio = 1, hoja = "equipment", sprite = 359, quest = true })
add({ id = "polvo_arcano", nombre = "Polvo arcano", apila = 99, precio = 6, hoja = "equipment", sprite = 699, texto = "Material para encantar el equipo." })

D.muebles = {
  cama = { nombre = "Cama", precio = 80, sprite = { hoja = "town", indice = 18 }, texto = "Al dormir aquí fijas tu retorno." },
  cofre = { nombre = "Cofre", precio = 70, sprite = { hoja = "town", indice = 65 }, texto = "Guarda objetos aparte de la bolsa." },
  estandarte = { nombre = "Estandarte", precio = 50, sprite = { hoja = "equipment", indice = 455 }, texto = "Tu facción, en la pared." },
  mesa = { nombre = "Mesa", precio = 40, sprite = { hoja = "town", indice = 7 }, texto = "Un lugar para dejar el mapa." },
}

D.precioCasa = { normal = 380, capital = 720 }

function D.capital(faccion)
  for _, c in ipairs(D.ciudades) do
    if c.faccion == faccion and c.capital then return c end
  end
end

function D.monstruo(id)
  for _, m in ipairs(D.monstruos) do
    if m.id == id then return m end
  end
end

function D.item(id)
  return D.items[id]
end

function D.cuadro(def, dir, frame)
  local porDir = def.porDir or 3
  local paso = def.paso or 1
  local total = def.cuadros or (porDir * 4)
  local grupos = math.max(1, math.floor(total / porDir))
  local mapa = { [2] = 0, [3] = 1, [1] = 2, [4] = 3 }
  local g = mapa[dir] or 0
  if g >= grupos then g = g % grupos end
  local f = (frame or 0) % porDir
  local maxFrame = math.floor(total / paso) - 1
  local n = g * porDir + f
  if n > maxFrame then n = n % (maxFrame + 1) end
  return def.base + n * paso
end


return D
