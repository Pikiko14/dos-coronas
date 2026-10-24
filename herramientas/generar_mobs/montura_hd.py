"""Añade una montura que llega ya en alta resolución (Wait.png: 15 cuadros = 3 pasos x 5 direcciones, Run.png: 30 = 6 x 5, cuadros de 384 px) sin el arte
fuente de FAO (../arte-fuente no está): la hornea con fao_hojas igual que monturas.py y, como no trae los anclajes del asiento, copia los de una montura
parecida (`--como`) escalados a su tamaño.

Uso: python -I -X utf8 herramientas/generar_mobs/montura_hd.py <id> <carpeta con Wait.png y Run.png> --como mnt_250 [--bake 0.5]
Escribe juego/arte/monstruos/<id>/{wait,run}.png y añade (o sustituye) la montura en montura_anim_datos.lua y montura_asiento_datos.lua.
Los datos de juego (monturas.xml) se añaden a mano."""
import argparse
import os
import re
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import fao_hojas

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SALIDA = os.path.join(RAIZ, "juego", "arte", "monstruos")
RENDER = os.path.join(RAIZ, "juego", "src", "presentacion", "render")
PAD, ESCALA = 3, 0.5
PASOS = {"wait": 3, "run": 6}


def leer_asiento(como):
    texto = open(os.path.join(RENDER, "montura_asiento_datos.lua"), encoding="utf-8").read()
    m = re.search(r"  %s = \{\n(.*?)\n  \},\n" % como, texto, re.S)
    res = {}
    for anim in PASOS:
        linea = re.search(r"    %s = \{ ([^}]*) \}," % anim, m.group(1)).group(1)
        res[anim] = [float(x) for x in linea.split(",")]
    return res


def alto_de(como):
    texto = open(os.path.join(RENDER, "montura_anim_datos.lua"), encoding="utf-8").read()
    return int(re.search(r"%s = \{ carpeta = \"%s\", alto = (\d+)" % (como, como), texto).group(1)) / ESCALA


def reemplazar(ruta, idn, bloque):
    texto = open(ruta, encoding="utf-8", newline="").read().replace("\r\n", "\n")
    texto = re.sub(r"  %s = \{.*?(?:\n  \},|\},)\n" % idn, "", texto, flags=re.S) if re.search(r"  %s = \{" % idn, texto) else texto
    i = texto.rindex("}")
    open(ruta, "w", encoding="utf-8", newline="\n").write(texto[:i] + bloque + texto[i:])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("id")
    ap.add_argument("carpeta")
    ap.add_argument("--como", default="mnt_250")
    ap.add_argument("--bake", type=float, default=0.5)
    a = ap.parse_args()
    sal = os.path.join(SALIDA, a.id)
    os.makedirs(sal, exist_ok=True)
    alto = None
    for anim, pasos in PASOS.items():
        im = Image.open(os.path.join(a.carpeta, anim.capitalize() + ".png")).convert("RGBA")
        tira, cw, ch, alto_c, _ = fao_hojas.hornear(im, pasos, a.bake, PAD, None, directo=True)
        fao_hojas.guardar(tira, os.path.join(sal, anim + ".png"))
        if anim == "wait":
            alto = alto_c
    s = alto / alto_de(a.como)
    asiento = leer_asiento(a.como)
    pant = round(alto * ESCALA)
    altura = max(8, min(30, round(pant * 0.45)))
    reemplazar(os.path.join(RENDER, "montura_anim_datos.lua"), a.id,
               '  %s = { carpeta = "%s", alto = %d, escala = %.4f, dirs5 = true, pad = %d, altura = %d },\n' % (a.id, a.id, pant, ESCALA, PAD, altura))
    bloque = "  %s = {\n" % a.id
    for anim in PASOS:
        bloque += "    %s = { %s },\n" % (anim, ", ".join("%g" % round(x * s, 1) for x in asiento[anim]))
    bloque += "  },\n"
    reemplazar(os.path.join(RENDER, "montura_asiento_datos.lua"), a.id, bloque)
    print("%s: alto %d (escala del asiento %.2f respecto a %s)" % (a.id, pant, s, a.como))


main()
