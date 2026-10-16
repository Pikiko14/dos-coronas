"""Hornea los PNJ FAO (../arte-fuente/fao-npc/npcs/<id>/1x/{Wait,Run}.png) para el juego.

Uso:  python herramientas/generar_mobs/npcs.py
Salida: juego/arte/monstruos/npc_<id>/{wait,run}.png  (las cinco direcciones: cuadro = paso * 5 + hoja, ver fao_hojas.py;
        el juego elige la hoja según hacia dónde camina y voltea las tres de la derecha) y juego/src/presentacion/render/npc_anim_datos.lua.
El orden de los cuadros del original (corrido un lugar) está explicado en fao_hojas.py."""
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import fao_hojas

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FUENTE = os.path.join(RAIZ, "..", "arte-fuente", "fao-npc", "npcs")
SALIDA = os.path.join(RAIZ, "juego", "arte", "monstruos")
LUA = os.path.join(RAIZ, "juego", "src", "presentacion", "render", "npc_anim_datos.lua")
PAD = 3
PASOS = {"wait": 3, "run": 6}
ESCALA_PANTALLA = 0.5        # los personajes FAO se dibujan a la mitad de su tamaño original (a zoom 2 se ven al original)

# ids de FAO usados por el juego (ver render/personajes.lua, P.npcFao)
IDS = """enfermera maestro_guerrero maestra_guerrera maestro_lancero maestra_lancera maestro_arquero maestra_arquera maestro_mago maestra_maga
maestro_clerigo maestra_clerigo maestro_nigromante maestra_nigromante general generala consejero_real noble escriba mensajero mensajera
tendero tendera mercader_viajero encantador encantadora vendedor_de_mascotas cuidadora_de_mascotas bibliotecario bibliotecaria maestro_herrero
subastador subastadora guardia_de_la_ciudad guardia_de_la_ciudad_f pescador pescadora pirata pirata_f ninja_informante explorador exploradora
cazador_veterano cazadora maestro_de_establos granjero granjera lenador florista minero bardo bardo_f sastre sastra""".split()


def main():
    datos = {}
    for idn in IDS:
        d = os.path.join(FUENTE, idn, "1x")
        if not os.path.isdir(d):
            print("FALTA", idn)
            continue
        sal = os.path.join(SALIDA, "npc_" + idn)
        os.makedirs(sal, exist_ok=True)
        alto = None
        for anim, pasos in PASOS.items():
            im = Image.open(os.path.join(d, anim.capitalize() + ".png")).convert("RGBA")
            tira, cw, ch, alto_c, _ = fao_hojas.hornear(im, pasos, 1.0, PAD)       # las cinco direcciones: cuadro = paso * 5 + hoja
            if anim == "wait":
                alto = alto_c
            fao_hojas.guardar(tira, os.path.join(sal, anim + ".png"))
        datos["npc_" + idn] = dict(carpeta="npc_" + idn, alto=round(alto * ESCALA_PANTALLA), escala=ESCALA_PANTALLA, pad=PAD)
        print(idn, alto)
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERADO por herramientas/generar_mobs/npcs.py: tamaño de cada PNJ FAO (se dibujan con render/mob_anim.lua). No editar a mano.\nreturn {\n")
        for k, v in datos.items():
            f.write('  %s = { carpeta = "%s", alto = %d, escala = %s, dirs5 = true, pad = %d },\n' % (k, v["carpeta"], v["alto"], v["escala"], v["pad"]))
        f.write("}\n")
    print(len(datos), "PNJ")


if __name__ == "__main__":
    main()
