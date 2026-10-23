"""Mascotas de ataque de Free Angels Online: las líneas de evolución (forma inicial -> media -> alta) con su arte real.

Cada forma es una criatura de shape/mon/<carpeta>/<código>_<anim>.spr (la misma estructura que las criaturas), así que se hornea igual que las del bestiario:
  juego/arte/monstruos/<id>/{wait,run,att,hurt,dead}.png          las tiras horneadas
  juego/src/presentacion/render/mob_anim_mascotas.lua             tamaño en pantalla de cada forma
Los datos de juego (nombre, ataque, evolución) están a mano en compartido/datos/mascotas.xml.
Uso:  python -X utf8 herramientas/generar_mobs/mascotas_fao.py            (variable FAO_PAK = carpeta con data1.pak y update*.pak; por defecto Descargas)
Arte de un juego ajeno (FAO): prototipo."""
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mobs
import pak_fao

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
LUA = os.path.join(RAIZ, "juego", "src", "presentacion", "render", "mob_anim_mascotas.lua")
PAD = mobs.PAD

# (id de la forma, carpeta de FAO, alto en pantalla). Las líneas salen de setting/eng/pet.xml (tipos de ataque con arte completo):
#   osito   Baby Bear (44007) -> Hula Bear (44008) -> Bear Man (44076)
#   dragon  Baby Dragon (44027) -> Wing Dragon (44091) -> Earth Dragon (44028)
#   angel   Purple Fuzz Ball (44145) -> Blue Angel (44147) -> Seraphim (44151)
#   demonio Purple Fuzz Ball (44145) -> Swamp Devil (44149) -> Hell Spawn (44154)
FORMAS = [
    ("masc_osito_1", "p007", 30), ("masc_osito_2", "p008", 38), ("masc_osito_3", "p076", 48),
    ("masc_dragon_1", "p027", 30), ("masc_dragon_2", "p091", 40), ("masc_dragon_3", "p028", 50),
    ("masc_pelusa_1", "p145", 30),
    ("masc_angel_2", "p147", 40), ("masc_angel_3", "p151", 50),
    ("masc_demonio_2", "p149", 40), ("masc_demonio_3", "p154", 50),
]


def main():
    tmp = tempfile.mkdtemp(prefix="mascotas_")
    mobs.FUENTE = tmp
    medidas = {}
    for idm, carpeta, alto in FORMAS:
        cuenta = pak_fao.hojas_criatura(carpeta, os.path.join(tmp, carpeta))
        if cuenta != {"wait": 15, "run": 30, "att": 20, "hurt": 10, "dead": 30}:
            raise SystemExit("%s (%s): número de cuadros no estándar %s" % (idm, carpeta, cuenta))
        medidas[idm] = mobs.hornear(idm, carpeta, None, alto)
        print("horneada", idm, medidas[idm])
    shutil.rmtree(tmp, ignore_errors=True)
    datos = {}
    for idm, carpeta, alto in FORMAS:
        datos[idm] = dict(carpeta=idm, alto=alto, escala=alto / medidas[idm][2], dirs2=True, pad=PAD)
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERADO por herramientas/generar_mobs/mascotas_fao.py: tamaño en pantalla de las formas de las mascotas de ataque. No editar a mano.\n")
        f.write("return {\n" + mobs.lua_tabla(datos) + "\n}\n")
    print("escrito", LUA)


if __name__ == "__main__":
    main()
