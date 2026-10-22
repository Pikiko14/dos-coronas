"""Criaturas de nivel 31 a 50 con arte NUEVO de FAO (sin repetir dibujos): las saca de los .pak (shape/mon/m####/<código>_<anim>.spr), las hornea con el mismo
código que el resto del bestiario (mobs.hornear) y escribe
  juego/arte/monstruos/<id>/{wait,run,att,hurt,dead}.png          las tiras horneadas
  juego/src/presentacion/render/mob_anim_altos.lua                tamaño en pantalla y aura de cada una
  compartido/datos/monstruos_altos.xml                            datos de juego (nivel, golpes, poderes...)
Uso:  python -X utf8 herramientas/generar_mobs/altos.py            (variable FAO_PAK = carpeta con data1.pak y update*.pak; por defecto Descargas)
Arte de un juego ajeno (FAO): prototipo."""
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mobs
import pak_fao

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
XML = os.path.join(RAIZ, "compartido", "datos", "monstruos_altos.xml")
LUA = os.path.join(RAIZ, "juego", "src", "presentacion", "render", "mob_anim_altos.lua")
PAD = mobs.PAD

# (id, nombre, nivel, bioma, código FAO, alto en pantalla, magico, golpes, poderes, descripción)
NORMALES = [
    ("minotauro_guerra", "Minotauro de guerra", 31, "colina", "m2545", 70, False, [("sangrar", .3), ("aturdir", .15, {"dur": 1.0})], [], "Casco con cuernos, hacha de dos manos y ninguna intención de negociar."),
    ("diablo_acorazado", "Diablo acorazado", 32, "eclipse", "m2553", 72, False, [("sangrar", .3), ("quemar", .2)], [], "Un demonio con peto de acero y alas que ya no hacen falta para asustar."),
    ("lancero_sombras", "Lancero de las sombras", 33, "velo", "m2410", 62, False, [("sangrar", .3)], [], "Su lanza es más larga que él y más rápida que tú."),
    ("reptil_huesos", "Reptil de huesos", 34, "cienaga", "m2407", 54, False, [("sangrar", .3), ("aturdir", .12, {"dur": 0.9})], [], "Un lagarto de la ciénaga que se levantó con escudo y todo."),
    ("duende_guerra", "Duende de guerra", 35, "senda", "m2677", 58, False, [("sangrar", .3)], [], "Orejas grandes, yelmo mayor y un alfanje que sabe lo que hace."),
    ("titan_hielo", "Titán de hielo", 36, "pinar", "m2560", 84, False, [("lentitud", .35, {"dur": 3, "pct": 0.4}), ("aturdir", .15, {"dur": 1.0})], ["pisoton"], "Puños de glaciar y una paciencia que se congeló hace siglos."),
    ("golem_amatista", "Gólem de amatista", 37, "eclipse", "m604", 80, False, [("aturdir", .2, {"dur": 1.0})], ["pisoton"], "Roca violeta que late despacio, como un corazón muy grande."),
    ("demonio_astado", "Demonio astado", 38, "eclipse", "m554", 74, False, [("quemar", .35), ("sangrar", .25)], ["aliento"], "Cadenas rotas, cuernos retorcidos y un humor de volcán."),
    ("ent_ardiente", "Ent ardiente", 39, "colina", "m1555", 86, True, [("quemar", .4)], ["aliento"], "Un árbol viejo con una antorcha donde debería tener la copa."),
    ("golem_escarcha", "Gólem de escarcha", 40, "pinar", "m2946", 84, False, [("lentitud", .4, {"dur": 3, "pct": 0.45}), ("aturdir", .15, {"dur": 1.0})], ["pisoton"], "Hielo azul que camina; donde pisa, el suelo cruje."),
    ("golem_cristal_oro", "Gólem de cristal dorado", 41, "marea", "m2948", 88, True, [("drenar_mana", .3)], ["drenaje"], "Cristales con vetas de oro que absorben la magia de quien se acerca."),
    ("samurai_dorado", "Samurái de oro", 42, "senda", "m1651", 68, False, [("sangrar", .35), ("aturdir", .12, {"dur": 0.9})], [], "Armadura de laca y una katana que corta antes de sacarse."),
    ("barbaro_ancestral", "Bárbaro ancestral", 43, "campos", "m2944", 76, False, [("sangrar", .35), ("aturdir", .15, {"dur": 1.0})], [], "El hacha le pesa más que a ti y la maneja con una mano."),
    ("sacerdotisa_felina", "Sacerdotisa felina", 44, "velo", "m2681", 70, True, [("drenar_vida", .3)], ["maldicion"], "Oro, sedas y una sonrisa que no augura nada bueno."),
    ("monje_carmesi", "Monje del desierto", 45, "marea", "m2554", 74, False, [("sangrar", .3), ("lentitud", .25, {"dur": 3, "pct": 0.4})], [], "Túnica color brasa y manos que golpean como mazas."),
    ("samurai_espectral", "Samurái espectral", 46, "eclipse", "m3376", 66, True, [("drenar_mana", .3), ("lentitud", .3, {"dur": 3, "pct": 0.4})], ["maldicion"], "Un yelmo sin cuerpo que sigue defendiendo a un señor que ya no existe."),
    ("lancero_esqueleto", "Jinete de huesos", 47, "cienaga", "m1557", 56, False, [("sangrar", .35)], [], "Cabalga un lagarto de huesos y no ha perdido una sola carga."),
    ("verdugo_esqueleto", "Verdugo de huesos", 48, "cienaga", "m1558", 56, False, [("sangrar", .4), ("aturdir", .15, {"dur": 1.0})], [], "Un hacha, una capucha y siglos de oficio."),
    ("golem_musgo_antiguo", "Gólem rúnico", 49, "pinar", "m828", 90, False, [("aturdir", .25, {"dur": 1.2})], ["pisoton"], "Piedra verde cubierta de runas que nadie sabe leer."),
    ("espectro_hielo", "Espectro de hielo", 50, "marea", "m2683", 84, True, [("lentitud", .4, {"dur": 4, "pct": 0.5}), ("drenar_vida", .3)], ["succion"], "Cristal con rostro: lo que queda de un hechicero que se negó a morir."),
]
# jefes del mundo: (id, nombre, nivel, continente, código, alto, aura, golpes, poderes, descripción)
JEFES = [
    ("jefe_dragon_pardo", "Dragón Pardo", 40, 1, "m2691", 112, (0.85, 0.6, 0.3), [("quemar", .3), ("sangrar", .3), ("aturdir", .15, {"dur": 1.0})], ["aliento", "pisoton"], "Escamas de roca y un aliento que calienta la montaña entera."),
    ("jefe_dragon_carmesi", "Dragón Carmesí", 50, 1, "m2692", 120, (1.0, 0.3, 0.25), [("quemar", .35), ("sangrar", .3), ("aturdir", .15, {"dur": 1.0})], ["aliento", "pisoton"], "Rojo de brasa, dorado de avaricia: duerme sobre todo lo que quemó."),
    ("jefe_dragon_abisal", "Dragón Abisal", 45, 2, "m2693", 118, (0.3, 0.9, 0.7), [("veneno", .3), ("lentitud", .3, {"dur": 4, "pct": 0.5}), ("aturdir", .15, {"dur": 1.2})], ["aliento", "drenaje"], "Verde de fondo de mar, frío como lo que guarda."),
    ("jefe_gorila_ancestral", "Gorila Ancestral", 50, 2, "m733", 122, (0.65, 0.5, 0.95), [("aturdir", .25, {"dur": 1.2}), ("sangrar", .3)], ["pisoton", "maldicion"], "El primero de todos los gorilas: no ha olvidado ni una afrenta."),
]
# jefes de las mazmorras mz4 y mz5 (mazmorras.xml): no salen en el mundo
MAZMORRAS = [
    ("jefe_maestro_forja", "Maestro de la Forja", 42, "m2555", 112, (1.0, 0.5, 0.2), [("quemar", .35), ("aturdir", .2, {"dur": 1.2})], ["aliento", "pisoton"], "Quien templó el primer acero y no ha dejado de golpearlo."),
    ("jefe_behemot_abismo", "Behemot del Abismo", 50, "m2682", 116, (0.6, 0.3, 0.9), [("drenar_mana", .3), ("lentitud", .3, {"dur": 4, "pct": 0.5}), ("aturdir", .2, {"dur": 1.2})], ["drenaje", "maldicion", "succion"], "Lo que queda del mundo cuando se apaga todo lo demás."),
]


def main():
    tmp = tempfile.mkdtemp(prefix="altos_")
    mobs.FUENTE = tmp
    medidas = {}
    todos = [(i, c, a) for (i, n, nv, b, c, a, m, g, p, d) in NORMALES] + [(i, c, a) for (i, n, nv, ct, c, a, au, g, p, d) in JEFES] \
        + [(i, c, a) for (i, n, nv, c, a, au, g, p, d) in MAZMORRAS]
    for idm, codigo, alto in todos:
        cuenta = pak_fao.hojas_criatura(codigo, os.path.join(tmp, codigo))
        if cuenta != {"wait": 15, "run": 30, "att": 20, "hurt": 10, "dead": 30}:
            raise SystemExit("%s (%s): número de cuadros no estándar %s" % (idm, codigo, cuenta))
        medidas[idm] = mobs.hornear(idm, codigo, None, alto)
        print("horneada", idm, medidas[idm])
    shutil.rmtree(tmp, ignore_errors=True)
    # datos de dibujo
    datos = {}
    for (idm, n, nv, b, c, alto, m, g, p, d) in NORMALES:
        datos[idm] = dict(carpeta=idm, alto=alto, escala=alto / medidas[idm][2], dirs2=True, pad=PAD)
    for (idm, n, nv, ct, c, alto, aura, g, p, d) in JEFES:
        datos[idm] = dict(carpeta=idm, alto=alto, escala=alto / medidas[idm][2], dirs2=True, pad=PAD, aura=list(aura))
    for (idm, n, nv, c, alto, aura, g, p, d) in MAZMORRAS:
        datos[idm] = dict(carpeta=idm, alto=alto, escala=alto / medidas[idm][2], dirs2=True, pad=PAD, aura=list(aura))
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERADO por herramientas/generar_mobs/altos.py: tamaño en pantalla y aura de las criaturas de nivel 31 a 50. No editar a mano.\n")
        f.write("return {\n" + mobs.lua_tabla(datos) + "\n}\n")
    # datos de juego
    x = ['<?xml version="1.0" encoding="UTF-8"?>\n<!--\n  Criaturas de nivel 31 a 50 (el nivel máximo es 50), con arte nuevo de FAO. GENERADO por herramientas/generar_mobs/altos.py: edita allí, no aquí.\n'
         '  Mismos campos que monstruos.xml. Los jefes del mundo salen en su continente; los de mazmorra (jefe_maestro_forja, jefe_behemot_abismo) solo en mz4 y mz5.\n-->\n<monstruos>\n']
    for (idm, nombre, nivel, bioma, c, alto, magico, golpes, poderes, desc) in NORMALES:
        x.append(mobs.entrada(idm, nombre, nivel, bioma, True, golpes, poderes, {"magico": magico}, desc))
    for (idm, nombre, nivel, cont, c, alto, aura, golpes, poderes, desc) in JEFES:
        x.append(mobs.entrada(idm, nombre, nivel, None, True, golpes, poderes, {"magico": False}, desc,
                              dict(elite="true", noCampamento="true", jefeMundo="true", continente=cont, tam=2)))
    for (idm, nombre, nivel, c, alto, aura, golpes, poderes, desc) in MAZMORRAS:
        x.append(mobs.entrada(idm, nombre, nivel, None, True, golpes, poderes, {}, desc, dict(elite="true", noCampamento="true", tam=2)))
    x.append("</monstruos>\n")
    with open(XML, "w", encoding="utf-8", newline="\n") as f:
        f.write("".join(x))
    print("criaturas:", len(NORMALES) + len(JEFES) + len(MAZMORRAS))


if __name__ == "__main__":
    main()
