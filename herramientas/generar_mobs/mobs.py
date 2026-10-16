"""Bestiario de Dos Coronas: hornea el arte FAO de las criaturas y genera sus datos.

Uso:  python herramientas/generar_mobs/mobs.py            (todo)
      python herramientas/generar_mobs/mobs.py --sin-arte  (solo los datos: monstruos.xml y render/mob_anim_datos.lua)

Fuente: ../arte-fuente/hojas-brutas/mon/<carpeta>/<codigo>_<Anim>.png (fuera del proyecto: arte de terceros, no se publica).
Salida:
  juego/arte/monstruos/<id>/{wait,run,att,hurt,dead}.png   tiras horneadas: pasos x 2 direcciones (cuadro = paso * 2 + hoja: 0 espalda-izquierda,
                                                           1 frente-izquierda; las otras dos diagonales salen volteando). Cada cuadro lleva un margen
                                                           transparente (PAD) para que el filtro no mezcle cuadros vecinos ni corte la silueta.
  juego/src/presentacion/render/mob_anim_datos.lua         tamaño en pantalla, aura y tinte de cada criatura
  compartido/datos/monstruos.xml                           datos de juego (nivel, bioma, golpes, poderes...)

Reparto de cuadros del original: 15 de espera, 30 de carrera, 20 de ataque, 10 de daño, 30 de muerte (3, 6, 4, 2 y 6 pasos de 5 direcciones).
Cuadros: el original trae el paso 1 con las direcciones 4 a 7, los pasos siguientes con 3 a 7 y al final el cuadro que falta (paso 1, dir. 3)."""
import json, os, re, sys
from PIL import Image
import numpy as np

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FUENTE = os.path.join(RAIZ, "..", "arte-fuente", "hojas-brutas", "mon")
SALIDA = os.path.join(RAIZ, "juego", "arte", "monstruos")
XML = os.path.join(RAIZ, "compartido", "datos", "monstruos.xml")
LUA = os.path.join(RAIZ, "juego", "src", "presentacion", "render", "mob_anim_datos.lua")
PAD = 3          # píxeles de margen transparente alrededor de cada cuadro
CUADROS = {"wait": 15, "run": 30, "att": 20, "hurt": 10, "dead": 30}

# ------------------------------------------------------------------------------------------------------------------ criaturas normales
# (id, nombre, nivel, bioma, carpeta, alto en pantalla, agresiva, golpes, poderes, opciones, descripción)
# golpes: lista de (tipo, prob, extras); opciones: magico, vuela
S, N = False, True
R = [
 ("seta_azul", "Seta azul", 1, "trigal", "M1521", 30, S, [("veneno", .1)], [], {}, "Una seta de sombrero azul que despierta cuando alguien pisa su círculo."),
 ("espantapajaros", "Espantapájaros vivo", 2, "trigal", "M004", 58, S, [("sangrar", .12)], [], {}, "Se bajó del palo para ahuyentar a quien se acerca al maíz."),
 ("hongo_palido", "Hongo pálido", 2, "velo", "M2848", 34, S, [("veneno", .12)], [], {}, "Crece entre las tumbas y suelta esporas cuando lo pisan."),
 ("larva_verde", "Larva verde", 3, "trigal", "M2664", 26, S, [("veneno", .15)], [], {}, "Devora hojas y a veces, dedos."),
 ("pinguino_aprendiz", "Pingüino aprendiz", 3, "muelle", "M1412", 36, N, [("lentitud", .2, {"dur": 2, "pct": 0.3})], [], {}, "Va a la escuela de magos del muelle y practica con quien pasa."),
 ("sapo", "Sapo ponzoñoso", 6, "muelle", "M052", 36, S, [("veneno", .25)], [], {}, "Hincha el cuello entre los juncos del muelle y escupe un veneno que escuece."),
 ("ent", "Ent del sendero", 14, "senda", "M043", 76, S, [("aturdir", .12, {"dur": 0.9})], [], {}, "Un tronco viejo que echó raíces y rencor. Pesa como un árbol y golpea como dos."),
 ("yeti", "Yeti del velo", 20, "velo", "M1422", 64, N, [("lentitud", .3, {"dur": 3, "pct": 0.4})], [], {}, "Pelaje de escarcha y un cuenco en la cabeza. Su abrazo deja los huesos fríos."),
 ("hongo_rojo", "Hongo rojo", 4, "campos", "M2850", 38, S, [("veneno", .2)], [], {}, "Sombrero rojo y malas pulgas."),
 ("rana_hojas", "Rana de hojas", 4, "muelle", "M050", 34, S, [("veneno", .2)], [], {}, "Se camufla entre los juncos y salta a la cara."),
 ("sapo_dorado", "Sapo dorado", 5, "muelle", "M051", 32, N, [("veneno", .25)], [], {}, "Brilla como una moneda; su piel quema las manos."),
 ("duende_bruma", "Duende de la bruma", 5, "senda", "M2676", 40, N, [("sangrar", .2)], [], {}, "Pequeño, rápido y con una daga demasiado grande."),
 ("libelula_cian", "Libélula cian", 6, "campos", "M2024", 40, N, [("veneno", .25)], [], {"vuela": True}, "Zumba sobre los sembrados y pica sin avisar."),
 ("polilla_rosa", "Polilla rosa", 7, "campos", "M2026", 40, N, [("lentitud", .3, {"dur": 3, "pct": 0.35})], [], {"vuela": True}, "Su polvo de alas adormece las piernas."),
 ("escarabajo_dorado", "Escarabajo dorado", 8, "campos", "M2249", 46, N, [("lentitud", .25)], [], {}, "Coraza de oro viejo y mandíbulas pacientes."),
 ("cocodrilo_arena", "Cocodrilo de arena", 8, "muelle", "M2153", 32, N, [("sangrar", .25)], [], {}, "Esperaba bajo la arena de los muelles. Sigue esperando."),
 ("pinguino_centinela", "Pingüino centinela", 8, "muelle", "M1413", 48, N, [("aturdir", .1, {"dur": 0.8})], [], {}, "Guarda la costa con una pala y un casco prestado."),
 ("rabano_guerrero", "Rábano guerrero", 9, "campos", "M1802", 54, N, [("sangrar", .3)], [], {}, "Un rábano con cuchillo. No preguntes."),
 ("girasol_lancero", "Girasol lancero", 10, "campos", "M1823", 68, N, [("sangrar", .2)], [], {}, "Gira hacia el sol y hacia quien se acerca, siempre con la lanza lista."),
 ("murcielago_purpura", "Murciélago púrpura", 10, "velo", "M2565", 34, N, [("drenar_mana", .25)], ["succion"], {"vuela": True, "magico": True}, "Cuelga de las torres de Nocturnia y baja al anochecer."),
 ("larva_espinosa", "Larva espinosa", 11, "senda", "M2665", 36, N, [("veneno", .3)], [], {}, "Cada pincho es un recuerdo de algo que no logró comérsela."),
 ("flor_lanza", "Flor de lanza", 12, "campos", "M1840", 68, N, [("sangrar", .25)], [], {}, "Florece rosa y pincha como acero."),
 ("diablillo_azul", "Diablillo azul", 12, "senda", "M2851", 46, N, [("quemar", .2)], [], {}, "Un duende con tridente que cree ser un demonio."),
 ("leon_crin", "León de crin roja", 13, "colina", "M1938", 48, N, [("sangrar", .25)], [], {}, "Cuando ruge, la colina entera se acuerda de él."),
 ("cangrejo_calabaza", "Cangrejo calabaza", 13, "marea", "M812", 46, N, [("lentitud", .25)], [], {}, "Lleva una calabaza como casa y la defiende a pinzazos."),
 ("ogro_palido", "Ogro pálido", 14, "colina", "m062", 66, N, [("aturdir", .15, {"dur": 0.9})], [], {}, "Pálido como la cal y pesado como una losa."),
 ("escarabajo_ciervo", "Escarabajo ciervo", 14, "senda", "M2251", 54, N, [("sangrar", .25), ("aturdir", .1, {"dur": 0.8})], [], {}, "Sus cuernos son dos espadas pequeñas."),
 ("esqueleto", "Esqueleto errante", 14, "colina", "M021", 50, N, [("sangrar", .25)], [], {}, "Un soldado que no sabe que ya perdió."),
 ("cocodrilo_verde", "Cocodrilo verde", 15, "cienaga", "M2152", 42, N, [("sangrar", .3)], [], {}, "Flota como un tronco hasta que muerde."),
 ("espiritu_velo", "Espíritu del velo", 15, "velo", "M641", 58, N, [("drenar_mana", .3)], ["drenaje"], {"magico": True}, "Una sombra encapuchada que recita nombres de muertos."),
 ("golem_musgo", "Gólem de musgo", 15, "colina", "M2264", 48, N, [("aturdir", .12, {"dur": 0.9})], ["pisoton"], {}, "Piedra viva tapizada de musgo y cristales."),
 ("medusa_violeta", "Medusa violeta", 16, "velo", "M2036", 46, N, [("lentitud", .35, {"dur": 4, "pct": 0.45})], [], {"magico": True}, "Flota con la marea del velo y pica con la corriente."),
 ("lancero_dorado", "Lancero dorado", 16, "colina", "M2930", 62, N, [("sangrar", .25), ("aturdir", .1, {"dur": 0.8})], [], {}, "Un mercenario de armadura dorada y una lanza que no perdona."),
 ("tortuga_espinosa", "Tortuga espinosa", 16, "cienaga", "M1040", 40, N, [("veneno", .3)], [], {}, "Lenta, dura y con espinas venenosas."),
 ("esqueleto_soldado", "Esqueleto soldado", 16, "colina", "M022", 50, N, [("sangrar", .3)], [], {}, "Conserva el escudo y la disciplina."),
 ("arana_azul", "Araña azul", 17, "cienaga", "m082", 46, N, [("veneno", .4)], [], {}, "Teje redes en las ramas secas de la ciénaga."),
 ("diablillo_acorazado", "Diablillo acorazado", 17, "pinar", "M2852", 48, N, [("quemar", .25)], [], {}, "Armadura de oro falso y tridente de verdad."),
 ("troll_cavernario", "Troll cavernario", 17, "colina", "M1037", 58, N, [("aturdir", .15, {"dur": 1.0})], [], {}, "Vive en las cuevas del Alba y no comparte."),
 ("golem_trepador", "Gólem trepador", 18, "pinar", "M625", 62, N, [("aturdir", .15, {"dur": 1.0})], ["pisoton"], {}, "Trepa por los pinos del bosque cubierto de hojas."),
 ("cangrejo_espinoso", "Cangrejo espinoso", 17, "marea", "M814", 48, N, [("sangrar", .25)], [], {}, "Pinzas largas y un lomo lleno de pinchos."),
 ("dama_velo", "Dama del velo", 18, "velo", "M645", 64, N, [("drenar_mana", .2)], ["maldicion"], {"magico": True}, "Conoce el nombre de quien pisa su círculo."),
 ("esqueleto_arquero", "Esqueleto arquero", 18, "colina", "M023", 50, N, [("sangrar", .3)], [], {}, "Dispara huesos con un arco que ya no tiene cuerda."),
 ("ogro_hacha", "Ogro del hacha", 19, "pinar", "M2945", 62, N, [("sangrar", .3), ("aturdir", .1, {"dur": 0.9})], [], {}, "Hacha, calaveras de recuerdo y mal humor."),
 ("anquilosaurio", "Lagarto acorazado", 19, "marea", "M2409", 40, N, [("aturdir", .2, {"dur": 1.0})], [], {}, "Escamas de hierro y una cola que parte escudos."),
 ("momia", "Momia errante", 19, "colina", "M027", 56, N, [("veneno", .3)], [], {}, "Vendas, polvo y una maldición en cada paso."),
 ("centauro", "Centauro bandolero", 20, "colina", "M628", 68, N, [("sangrar", .3)], [], {}, "Galopa por las colinas y no deja nada a su paso."),
 ("medusa_guerrera", "Medusa guerrera", 20, "cienaga", "M1166", 66, N, [("veneno", .3)], ["succion"], {"magico": True}, "Mil serpientes por cabello y una mirada de piedra."),
 ("bestia_cornuda", "Bestia cornuda", 21, "pinar", "M2154", 44, N, [("aturdir", .2, {"dur": 1.0})], ["pisoton"], {}, "Un lagarto morado con astas de hueso."),
 ("tortuga_coral", "Tortuga de coral", 21, "marea", "M1043", 44, N, [("lentitud", .3)], [], {}, "Su caparazón es un arrecife con patas."),
 ("vampiro", "Vampiro encapuchado", 21, "velo", "M029", 62, N, [("drenar_mana", .25), ("sangrar", .2)], ["drenaje"], {"magico": True}, "Capa roja y sed antigua."),
 ("calamar_espectral", "Calamar espectral", 22, "marea", "M2155", 46, N, [("lentitud", .35, {"dur": 4, "pct": 0.5})], ["succion"], {"magico": True}, "Llega con la niebla y se lleva el aliento."),
 ("escorpion_hielo", "Escorpión de hielo", 22, "velo", "M650", 56, N, [("lentitud", .35, {"dur": 4, "pct": 0.5})], [], {}, "Su aguijón congela lo que toca."),
 ("espiritu_cristal", "Espíritu de cristal", 23, "eclipse", "M2563", 36, N, [("drenar_mana", .3)], ["drenaje"], {"vuela": True, "magico": True}, "Un fragmento de luz fría con alas."),
 ("cangrejo_loto", "Cangrejo de loto", 24, "marea", "M816", 56, N, [("veneno", .3)], [], {}, "Cría lotos sobre el caparazón y escupe su veneno."),
 ("calamar_puas", "Calamar de púas", 24, "marea", "M2156", 46, N, [("veneno", .3), ("lentitud", .2)], ["succion"], {"magico": True}, "Tentáculos con púas y un pico de loro."),
 ("reina_velo", "Reina del velo", 25, "velo", "M647", 68, N, [("drenar_mana", .3)], ["succion", "maldicion"], {"magico": True}, "Gobierna un reino de sombras con una mirada."),
 ("bestia_espectral", "Bestia espectral", 25, "eclipse", "M1841", 58, N, [("lentitud", .3, {"dur": 3, "pct": 0.4}), ("aturdir", .1, {"dur": 0.9})], [], {"magico": True}, "Una fiera de escarcha y niebla que no deja huellas."),
 ("troll_escarcha", "Troll de escarcha", 26, "velo", "M2562", 66, N, [("lentitud", .3, {"dur": 4, "pct": 0.5}), ("aturdir", .1, {"dur": 0.9})], ["pisoton"], {}, "Su aliento deja la hierba blanca."),
 ("diablillo_lancero", "Diablillo lancero", 26, "pinar", "M1163", 50, N, [("quemar", .3), ("sangrar", .2)], [], {}, "Una lanza roja tan larga como su rencor."),
 ("elemental_brasas", "Elemental de brasas", 27, "pinar", "M2684", 80, N, [("quemar", .35)], ["aliento"], {"magico": True}, "Llama con rabia y una armadura de carbón."),
 ("planta_jarro", "Planta jarro", 27, "cienaga", "M1437", 58, N, [("veneno", .35), ("sangrar", .2)], ["drenaje"], {"magico": True}, "Su jarro digiere lo que cae dentro, incluidos aventureros."),
 ("golem_cristal", "Gólem de cristal", 28, "eclipse", "M2265", 60, N, [("aturdir", .2, {"dur": 1.0})], ["pisoton"], {}, "Cristales vivos que cantan cuando se rompen."),
 ("reina_espejos", "Reina de los espejos", 29, "velo", "M1441", 84, N, [("drenar_mana", .3), ("lentitud", .25)], ["succion", "drenaje", "maldicion"], {"magico": True}, "Cada espejo que la rodea guarda un alma."),
 ("troll_acorazado", "Troll acorazado", 30, "eclipse", "M2669", 64, N, [("aturdir", .2, {"dur": 1.0}), ("sangrar", .25)], ["pisoton"], {}, "Armadura de hierro, espinas y una orden: destruir."),
]

# criaturas que ya estaban horneadas (se conservan): id -> (carpeta, escala de dibujo, alto, dirs5)
EXISTENTES = {
    "calabaza": ("calabaza", 0.62, 40, False),
    "limo": ("limo", 0.50, 42, False),
}
# datos de juego de las que ya existían
R_EXIST = [
 ("calabaza", "Calabaza viva", 1, "trigal", S, [("sangrar", .1)], [], {}, "Una calabaza que despertó en el huerto y muerde a quien se acerca."),
 ("limo", "Limo del velo", 1, "velo", S, [("veneno", .1)], [], {}, "Un grumo pestilente que se arrastra entre las tumbas de Nocturnia."),
]

# ---------------------------------------------------------------------------------------------------------- jefes del mundo (5 por continente)
# (id, nombre, nivel, continente, carpeta, alto, desc, aura, poderes, golpes, transformación de color o None)
J = [
 ("jefe_gorila_bosque", "Gorila del Bosque", 10, 1, "M480", 112, "Rey de las lianas: arranca árboles para abrirse camino.", (0.4, 0.9, 0.3), ["pisoton"], [("aturdir", .2, {"dur": 1.0}), ("sangrar", .2)], None),
 ("jefe_estegosaurio_musgo", "Estegosaurio de Musgo", 15, 1, "M1097", 112, "Una cresta de hojas doradas y una cola que parte puertas.", (0.7, 0.9, 0.3), ["pisoton"], [("aturdir", .2, {"dur": 1.0}), ("sangrar", .25)], None),
 ("jefe_orco_glacial", "Capitán Orco Glacial", 20, 1, "M3249", 118, "Mandó a mil guerreros y a todos los dejó fríos.", (0.5, 0.8, 1.0), ["pisoton"], [("lentitud", .3, {"dur": 4, "pct": 0.5}), ("aturdir", .15, {"dur": 1.0})], None),
 ("jefe_senor_astado", "Señor Astado", 25, 1, "M1167", 112, "Cuernos de hueso, una cola de lanzas y la corona del Alba entre los dientes.", (1.0, 0.85, 0.4), ["pisoton", "aliento"], [("sangrar", .3), ("aturdir", .15, {"dur": 1.0})], None),
 ("jefe_basilisco_dorado", "Basilisco Dorado", 30, 1, "M1091", 126, "Un dragón de escamas de oro que vigila el último camino del Alba.", (1.0, 0.8, 0.3), ["aliento", "pisoton"], [("quemar", .3), ("sangrar", .3), ("aturdir", .15, {"dur": 1.0})], None),
 ("jefe_gorila_ceniza", "Gorila Ceniciento", 10, 2, "M476", 112, "Su pelaje es ceniza y su puño, un martillo.", (0.8, 0.5, 0.9), ["pisoton"], [("aturdir", .2, {"dur": 1.0}), ("sangrar", .2)], dict(sat=0.25, bri=0.72)),
 ("jefe_estegosaurio_venenoso", "Estegosaurio Venenoso", 15, 2, "M1094", 112, "Sus púas gotean un veneno que nubla la vista.", (0.7, 0.4, 0.95), ["pisoton"], [("veneno", .4), ("aturdir", .15, {"dur": 1.0})], dict(giro=175, sat=1.0, bri=0.95)),
 ("jefe_rey_esqueleto", "Rey Esqueleto Dorado", 20, 2, "m1213", 122, "Un rey sin carne y con todo el oro: gobierna a sus muertos con una vara de hueso.", (1.0, 0.8, 0.3), ["maldicion", "succion"], [("sangrar", .3), ("aturdir", .15, {"dur": 1.0})], None),
 ("jefe_wyvern_carmesi", "Wyvern Carmesí", 25, 2, "m2690", 114, "Alas de cuero, aliento de brasa y una cola que corta.", (1.0, 0.35, 0.3), ["aliento", "pisoton"], [("quemar", .3), ("sangrar", .3)], None),
 ("jefe_dragon_sombra", "Dragón de las Sombras", 30, 2, "M1088", 126, "Escamas negras y un aliento que apaga las velas del Ocaso.", (0.7, 0.2, 0.9), ["aliento", "drenaje"], [("quemar", .3), ("drenar_mana", .3), ("aturdir", .15, {"dur": 1.0})], dict(giro=130, sat=0.9, bri=0.78)),
]

# ---------------------------------------------------------------------------------------------------------- jefes de mazmorra
# (id, nombre, nivel, carpeta, alto, desc, aura, poderes, golpes, transformación)
Z = [
 ("jefe_rey_momia", "Rey Momia", 17, "M027", 110, "El señor de la cripta: vendas, polvo y una orden que ya nadie dio.", (0.9, 0.85, 0.5), ["succion", "maldicion"], [("veneno", .3), ("aturdir", .15, {"dur": 0.9})], None),
 ("jefe_diablo_brasas", "Diablo de las Brasas", 26, "M1160", 104, "Una sierra al rojo vivo y el fuego de todo el foso.", (1.0, 0.45, 0.2), ["aliento", "pisoton"], [("quemar", .35), ("sangrar", .25)], None),
 ("jefe_soberano_eclipse", "Soberano del Eclipse", 30, "M3375", 82, "Una máscara sin rostro que gobierna el templo donde la luz se apaga.", (0.6, 0.4, 1.0), ["drenaje", "maldicion", "succion"], [("drenar_mana", .3), ("lentitud", .3, {"dur": 4, "pct": 0.5})], dict(giro=85, sat=1.0, bri=0.95)),
]

# --------------------------------------------------------------------------------------------- criaturas de grupo, gigantes y bandidos
# Comparten el arte de otra criatura (arte = id de la que toman la imagen), con tinte, tamaño y aura propios.
# (id, nombre, nivel, arte, alto, tinte, aura, desc, atributos del xml, golpes, poderes, magico, vuela)
G = [
 ("jefe_manada", "Jefe de la manada", 10, "M1938", 80, (1, 0.72, 0.55), None, "Guía a la manada y no caza solo.",
  dict(categoria="party", hpMul=3.5, atkMul=1.5, xpMul=4), [("sangrar", .3)], [], False, False),
 ("sectario_mayor", "Sectario mayor", 10, "M645", 88, (0.82, 0.68, 1), None, "Su culto pide sacrificios en grupo.",
  dict(categoria="party", hpMul=3.2, atkMul=1.6, xpMul=4), [], ["drenaje", "maldicion"], True, False),
 ("reina_avispa", "Reina medusa", 10, "M1166", 84, (1, 0.9, 0.55), (1.0, 0.85, 0.3), "Mil serpientes por cabello y un enjambre a su servicio.",
  dict(categoria="party", hpMul=3.3, atkMul=1.5, xpMul=4), [("veneno", .4)], ["maldicion"], False, False),
 ("oso_gigante", "Troll gigante", 10, "M1037", 96, (0.92, 0.8, 0.7), None, "Del tamaño de una casa.",
  dict(categoria="gigante", hpMul=4.5, atkMul=1.9, xpMul=10, velocidad=2.4, tam=2), [("sangrar", .3), ("aturdir", .15, {"dur": 1.0})], ["pisoton"], False, False),
 ("coloso", "Coloso de piedra", 10, "M2264", 104, (0.78, 0.8, 0.92), None, "El suelo tiembla a su paso.",
  dict(categoria="gigante", hpMul=5, atkMul=1.8, xpMul=10, velocidad=2.2, tam=2), [("lentitud", .3)], ["pisoton"], False, False),
 ("gigante_guerra", "Gigante de guerra", 10, "M2669", 108, (1, 0.78, 0.74), None, "Bajó de las montañas buscando pelea.",
  dict(categoria="gigante", hpMul=4.5, atkMul=2, xpMul=10, velocidad=2.5, tam=2), [("aturdir", .2, {"dur": 1.0}), ("sangrar", .25)], ["pisoton"], False, False),
 ("bandido", "Bandido del camino", 8, "lancero_dorado", 54, (0.8, 0.7, 0.7), None, "Asalta caravanas con un cuchillo oxidado.",
  dict(bandido="true"), [("sangrar", .2)], [], False, False),
 ("asaltante", "Asaltante", 16, "centauro", 62, (1, 0.9, 0.85), None, "Curtido en cien emboscadas.",
  dict(bandido="true"), [("sangrar", .25), ("aturdir", .1, {"dur": 0.9})], [], False, False),
 ("saqueador", "Saqueador de rutas", 24, "ogro_hacha", 66, (0.9, 0.85, 1), None, "Lidera bandas que arrasan los convoyes.",
  dict(bandido="true"), [("sangrar", .3), ("aturdir", .15, {"dur": 0.9})], [], False, False),
]


# ------------------------------------------------------------------------------------------------------------------------------ horneado
def slot(i, n):
    if i == n - 1:
        return 0
    if i < 4:
        return i + 1
    k = i - 4
    return (1 + k // 5) * 5 + k % 5


def hsv(im, giro=0, sat=1.0, bri=1.0):
    a = np.asarray(im.convert("RGBA")).astype(np.float32) / 255
    rgb, al = a[..., :3], a[..., 3]
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn + 1e-6
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6.0
    s = np.where(mx < 1e-6, 0, d / np.maximum(mx, 1e-6))
    v = mx
    h = (h + giro / 360.0) % 1.0
    s = np.clip(s * sat, 0, 1)
    v = np.clip(v * bri, 0, 1)
    i = np.floor(h * 6).astype(int) % 6
    f = h * 6 - np.floor(h * 6)
    p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    Rr = np.choose(i, [v, q, p, p, t, v])
    Gg = np.choose(i, [t, v, v, q, p, p])
    Bb = np.choose(i, [p, p, t, v, v, q])
    return Image.fromarray((np.dstack([Rr, Gg, Bb, al]) * 255).astype(np.uint8), "RGBA")


def hornear(idm, carpeta, tr=None, alto=60):
    d = os.path.join(FUENTE, carpeta)
    sal = os.path.join(SALIDA, idm)
    os.makedirs(sal, exist_ok=True)
    medidas = None
    # escala de horneado: la imagen horneada mide ~2 veces la altura "alto" (el zoom normal del juego es 2: así se ve nítida en pantalla), sin pasar
    # nunca del tamaño original (ampliar solo da borrosidad)
    arch0 = [f for f in os.listdir(d) if f.lower().endswith("_wait.png")][0]
    im0 = Image.open(os.path.join(d, arch0)).convert("RGBA")
    w0 = im0.width // CUADROS["wait"]
    c0 = im0.crop((0, 0, w0, im0.height)).getchannel("A").point(lambda a: 255 if a > 10 else 0).getbbox()
    alto_orig = (c0[3] - c0[1]) if c0 else im0.height
    esc = max(0.16, min(1.0, 2.0 * alto / alto_orig))
    # (el cuadro horneado mide esc veces el original; con el margen PAD queda un poco más ancho)
    # suelo común POR ANIMACIÓN Y DIRECCIÓN: cada tira original tiene su propio alto de celda y su propia línea del suelo (la carrera y el ataque no
    # comparten baseline con la espera). En cada animación y dirección, el hueco transparente más pequeño bajo los pies se recorta de sus cuadros:
    # así los pies quedan en el borde de abajo y la criatura no "flota"; los saltos y golpes suben, no bajan del suelo.
    huecos = {}
    for anim, n in CUADROS.items():
        arch = [f for f in os.listdir(d) if f.lower().endswith("_" + anim + ".png")][0]
        im = Image.open(os.path.join(d, arch)).convert("RGBA")
        w = im.width // n
        alfa = np.asarray(im)[:, :, 3] > 10
        m = {2: 10 ** 9, 4: 10 ** 9}
        for i in range(n):
            hoja = slot(i, n) % 5
            if hoja not in m:
                continue
            filas = np.where(alfa[:, i * w:(i + 1) * w].any(1))[0]
            if len(filas):
                m[hoja] = min(m[hoja], im.height - 1 - int(filas.max()))
        huecos[anim] = {k: (0 if v == 10 ** 9 else v) for k, v in m.items()}
    for anim, n in CUADROS.items():
        arch = [f for f in os.listdir(d) if f.lower().endswith("_" + anim + ".png")][0]
        im = Image.open(os.path.join(d, arch)).convert("RGBA")
        w, h = im.width // n, im.height
        fw, fh = max(1, round(w * esc)), max(1, round(h * esc))
        cw, ch = fw + 2 * PAD, fh + 2 * PAD
        pasos = n // 5
        tira = Image.new("RGBA", (cw * pasos * 2, ch), (0, 0, 0, 0))
        for i in range(n):
            sl = slot(i, n)
            hoja = sl % 5
            if hoja not in (2, 4):
                continue          # en la vista isométrica solo se usan las dos hojas de tres cuartos (las demás direcciones salen volteando)
            c = im.crop((i * w, 0, (i + 1) * w, h - huecos[anim][hoja]))
            if tr:
                c = hsv(c, tr.get("giro", 0), tr.get("sat", 1.0), tr.get("bri", 1.0))
            c = c.resize((fw, max(1, round(c.height * esc))), Image.LANCZOS)
            tira.alpha_composite(c, (((sl // 5) * 2 + (1 if hoja == 4 else 0)) * cw + PAD, ch - PAD - c.height))
        if anim == "wait":
            cuadro = tira.crop((1 * cw, 0, 2 * cw, ch))
            caja = cuadro.getchannel("A").point(lambda a: 255 if a > 10 else 0).getbbox()
            medidas = (cw, ch, caja[3] - caja[1] if caja else fh)
        ruta = os.path.join(sal, anim + ".png")
        tira.quantize(colors=256, method=Image.FASTOCTREE, dither=Image.NONE).save(ruta, optimize=True)
    return medidas


# ------------------------------------------------------------------------------------------------------------------------------ salida
def golpe_xml(golpes):
    if not golpes:
        return ""
    filas = []
    for g in golpes:
        extra = g[2] if len(g) > 2 else {}
        at = "".join(' %s="%s"' % (k, v) for k, v in extra.items())
        filas.append('      <i tipo="%s"%s prob="%s"/>' % (g[0], at, g[1]))
    return "    <golpe>\n" + "\n".join(filas) + "\n    </golpe>\n"


def entrada(idm, nombre, nivel, bioma, agr, golpes, poderes, opc, desc, extra=None):
    at = ['id="%s"' % idm, 'nombre="%s"' % nombre, 'nivel="%d"' % nivel, 'agresivo="%s"' % ("true" if agr else "false")]
    if bioma:
        at.append('bioma="%s"' % bioma)
    at.append('desc="%s"' % desc.replace('"', "'"))
    if opc.get("magico"):
        at.append('magico="true"')
    if opc.get("vuela"):
        at.append('vuela="true"')
    for k, v in (extra or {}).items():
        at.append('%s="%s"' % (k, v))
    cuerpo = golpe_xml(golpes)
    if poderes:
        cuerpo += '    <poderes lista="%s"/>\n' % ",".join(poderes)
    return "  <monstruo %s>\n%s  </monstruo>\n" % (" ".join(at), cuerpo)


def lua_tabla(d):
    partes = []
    for idm, v in d.items():
        campos = []
        for k, x in v.items():
            if isinstance(x, str):
                campos.append('%s = "%s"' % (k, x))
            elif isinstance(x, bool):
                campos.append("%s = %s" % (k, "true" if x else "false"))
            elif isinstance(x, (list, tuple)):
                campos.append("%s = { %s }" % (k, ", ".join(str(round(y, 3)) for y in x)))
            else:
                campos.append("%s = %s" % (k, round(x, 4) if isinstance(x, float) else x))
        partes.append("  %s = { %s }," % (idm, ", ".join(campos)))
    return "\n".join(partes)


def main():
    sin_arte = "--sin-arte" in sys.argv
    medidas = {}
    if not sin_arte:
        import shutil
        # se borran las criaturas horneadas que ya no existen en el bestiario
        validos = {x[0] for x in R} | {x[0] for x in J} | {x[0] for x in Z} | set(EXISTENTES) | {x[0] for x in G if re.match(r"^[Mm]\d+$", x[3])}
        if os.path.isdir(SALIDA):
            for nombre in os.listdir(SALIDA):
                if nombre not in validos:
                    shutil.rmtree(os.path.join(SALIDA, nombre))
        for (idm, nombre, nivel, bioma, car, alto, agr, golpes, poderes, opc, desc) in R:
            medidas[idm] = hornear(idm, car, None, alto)
            print("normal", idm, medidas[idm])
        for (idm, nombre, nivel, cont, car, alto, desc, aura, poderes, golpes, tr) in J:
            medidas[idm] = hornear(idm, car, tr, alto)
            print("jefe", idm, medidas[idm])
        for (idm, nombre, nivel, car, alto, desc, aura, poderes, golpes, tr) in Z:
            medidas[idm] = hornear(idm, car, tr, alto)
            print("mazmorra", idm, medidas[idm])
        for (idm, nombre, nivel, arte, alto, tinte, aura, desc, attrs, golpes, poderes, magico, vuela) in G:
            if re.match(r"^[Mm]\d+$", arte):
                medidas[idm] = hornear(idm, arte, None, alto)
                print("grupo", idm, medidas[idm])
    else:
        for carpeta in os.listdir(SALIDA):
            im = Image.open(os.path.join(SALIDA, carpeta, "wait.png")).convert("RGBA")
            cw = im.width // 6
            caja = im.crop((cw, 0, 2 * cw, im.height)).getchannel("A").point(lambda a: 255 if a > 10 else 0).getbbox()
            medidas[carpeta] = (cw, im.height, caja[3] - caja[1] if caja else im.height)

    # --- datos de dibujo
    datos = {}
    for (idm, nombre, nivel, bioma, car, alto, agr, golpes, poderes, opc, desc) in R:
        datos[idm] = dict(carpeta=idm, alto=alto, escala=alto / medidas[idm][2], dirs2=True, pad=PAD)
    for idm, (carpeta, esc, alto, d5) in EXISTENTES.items():
        datos[idm] = dict(carpeta=carpeta, alto=alto, escala=esc, dirs2=d5)
    for (idm, nombre, nivel, cont, car, alto, desc, aura, poderes, golpes, tr) in J:
        datos[idm] = dict(carpeta=idm, alto=alto, escala=alto / medidas[idm][2], dirs2=True, pad=PAD, aura=list(aura))
    for (idm, nombre, nivel, car, alto, desc, aura, poderes, golpes, tr) in Z:
        datos[idm] = dict(carpeta=idm, alto=alto, escala=alto / medidas[idm][2], dirs2=True, pad=PAD, aura=list(aura))
    for (idm, nombre, nivel, arte, alto, tinte, aura, desc, attrs, golpes, poderes, magico, vuela) in G:
        if re.match(r"^[Mm]\d+$", arte):
            d = dict(carpeta=idm, alto=alto, escala=alto / medidas[idm][2], dirs2=True, pad=PAD, tinte=list(tinte))
        else:
            base = datos[arte]
            d = dict(carpeta=base["carpeta"], alto=alto, escala=alto / medidas[base["carpeta"]][2], dirs2=base.get("dirs2", False), pad=base.get("pad", 0), tinte=list(tinte))
        if aura:
            d["aura"] = list(aura)
        datos[idm] = d
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERADO por herramientas/generar_mobs/mobs.py: tamaño en pantalla, aura y tinte de cada criatura. No editar a mano.\n")
        f.write("return {\n" + lua_tabla(datos) + "\n}\n")

    # --- datos de juego
    x = ['<?xml version="1.0" encoding="UTF-8"?>\n<!--\n  Criaturas (GENERADO por herramientas/generar_mobs/mobs.py: edita allí, no aquí).\n'
         '  Normales: nivel y bioma deciden dónde salen. jefeMundo + continente: un jefe único por zona (5 por continente).\n'
         '  elite: jefe (más vida y daño). categoria party/gigante: criaturas de encuentro de grupo (hpMul, atkMul, xpMul).\n'
         '  golpe: estados que puede aplicar al pegar; poderes: poderes propios (ver estados.xml). El dibujo está en render/mob_anim_datos.lua.\n-->\n<monstruos>\n']
    for (idm, nombre, nivel, bioma, car, alto, agr, golpes, poderes, opc, desc) in R:
        x.append(entrada(idm, nombre, nivel, bioma, agr, golpes, poderes, opc, desc))
    for (idm, nombre, nivel, bioma, agr, golpes, poderes, opc, desc) in R_EXIST:
        x.append(entrada(idm, nombre, nivel, bioma, agr, golpes, poderes, opc, desc))
    for (idm, nombre, nivel, cont, car, alto, desc, aura, poderes, golpes, tr) in J:
        x.append(entrada(idm, nombre, nivel, None, True, golpes, poderes, {"magico": False}, desc,
                         dict(elite="true", noCampamento="true", jefeMundo="true", continente=cont, tam=2)))
    for (idm, nombre, nivel, car, alto, desc, aura, poderes, golpes, tr) in Z:
        # el jefe de mazmorra recibe su multiplicador de vida en mazmorras.xml: solo el último es élite de por sí (como el Behemot de antes)
        extra = dict(elite="true", noCampamento="true", tam=2) if idm == "jefe_soberano_eclipse" else dict(noCampamento="true")
        x.append(entrada(idm, nombre, nivel, None, True, golpes, poderes, {}, desc, extra))
    for (idm, nombre, nivel, arte, alto, tinte, aura, desc, attrs, golpes, poderes, magico, vuela) in G:
        x.append(entrada(idm, nombre, nivel, None, True, golpes, poderes, {"magico": magico, "vuela": vuela}, desc, dict(attrs, noCampamento="true")))
    x.append("</monstruos>\n")
    with open(XML, "w", encoding="utf-8", newline="\n") as f:
        f.write("".join(x))
    total = len(R) + len(R_EXIST) + len(J) + len(Z) + len(G)
    print("criaturas:", total, "| normales:", len(R) + len(R_EXIST), "| jefes del mundo:", len(J), "| jefes de mazmorra:", len(Z), "| de grupo y bandidos:", len(G))


if __name__ == "__main__":
    main()
