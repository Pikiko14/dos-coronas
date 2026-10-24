"""Recoloca el asiento del jinete de TODAS las monturas para que se vea montándola: la cadera del jinete queda sobre el lomo de la montura (la silueta del
cuadro, justo bajo su punto más alto en la columna donde va sentado) y no dentro de ella ni flotando encima.

Lee juego/src/presentacion/render/montura_asiento_datos.lua (dx, dy por cuadro: los de FAO) y las tiras horneadas juego/arte/monstruos/<id>/{wait,run}.png.
Conserva el dx de cada cuadro (la posición a lo largo del lomo, de FAO) y recalcula el dy: cadera = punto más alto de la silueta bajo ese dx + LOMO * alto.
Uso: python -I -X utf8 herramientas/generar_mobs/asiento_sobre_lomo.py [LOMO]      (hay que volver a ejecutarlo si se vuelve a hornear con monturas.py)"""
import os
import re
import sys

import numpy as np
from PIL import Image

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ARCHIVO = os.path.join(RAIZ, "juego", "src", "presentacion", "render", "montura_asiento_datos.lua")
ARTE = os.path.join(RAIZ, "juego", "arte", "monstruos")
PAD = 3
ABAJO = 28                   # el punto más bajo del jinete sentado (rodillas y botas) queda 28 px sobre su origen: medido en las hojas Wait_m del cuerpo (23 a 34)
LOMO = float(sys.argv[1]) if len(sys.argv) > 1 else 0.42      # cuánto bajo el lomo (fracción del alto de la montura) llegan las piernas del jinete (cuelgan por el costado)
LOMO_PEQUENA = 0.65          # en las monturas pequeñas (alto en pantalla <= PEQUENA) el jinete es más grande que ellas: las piernas llegan más abajo
PEQUENA = 40                 # (px de pantalla; render/dibujo.lua repinta entonces la montura sobre las piernas del jinete en todas las direcciones)
ESCALA = 0.5
MAX_MOV = 110                 # lo máximo que se mueve el asiento respecto al original (px horneados)
PASOS = {"wait": 3, "run": 6}


def leer():
    texto = open(ARCHIVO, encoding="utf-8").read()
    res = {}
    for m in re.finditer(r"^  (mnt_\d+) = \{\n(.*?)\n  \},\n", texto, re.M | re.S):
        anims = {}
        for a in PASOS:
            linea = re.search(r"^    %s = \{ ([^}]*) \}," % a, m.group(2), re.M)
            anims[a] = [float(x) for x in linea.group(1).split(",")]
        res[m.group(1)] = anims
    return res


def recolocar(idn, anim, plano):
    im = Image.open(os.path.join(ARTE, idn, anim + ".png")).convert("RGBA")
    n = PASOS[anim] * 5
    cw = im.width // n
    alfa = np.asarray(im)[:, :, 3] > 10
    base = im.height - PAD
    nuevo = list(plano)
    for i in range(n):
        celda = alfa[:, i * cw:(i + 1) * cw]
        filas = np.where(celda.any(1))[0]
        cols = np.where(celda.any(0))[0]
        if not len(filas):
            continue
        y0, y1, x0, x1 = filas.min(), filas.max(), cols.min(), cols.max()
        alto = max(1, y1 - y0)
        dx, dy = plano[2 * i], plano[2 * i + 1]
        xh = int(round(min(max(cw / 2 + dx, x0 + 0.15 * (x1 - x0)), x1 - 0.15 * (x1 - x0))))
        ventana = celda[:, max(0, xh - 4):xh + 5]
        f = np.where(ventana.any(1))[0]
        ytop = f.min() if len(f) else y0
        # el lomo es la primera fila (de arriba abajo) en que la silueta ya es ancha como el cuerpo: así un cuello, unos cuernos o una cola que
        # sobresalen justo en la columna del asiento no suben al jinete por encima del animal
        anchos = celda.sum(1)
        ancho_cuerpo = np.percentile(anchos[anchos > 0], 85)
        cuerpo = np.where(anchos >= 0.55 * ancho_cuerpo)[0]
        if len(cuerpo):
            ytop = max(ytop, cuerpo.min())
        lomo = LOMO_PEQUENA if (np.where(alfa[:, :].any(1))[0].size and alto * ESCALA <= PEQUENA) else LOMO
        piernas = ytop + lomo * alto - base              # dónde acaban las piernas del jinete (px respecto a la base, hacia abajo)
        origen = piernas + ABAJO
        nuevo[2 * i + 1] = round(max(dy - MAX_MOV, min(dy + MAX_MOV, origen)), 1)
    return nuevo


def main():
    datos = leer()
    salida = ["-- GENERADO por herramientas/generar_mobs/monturas.py (dx, dy de FAO) y recolocado por asiento_sobre_lomo.py (dy: la cadera del jinete sobre el lomo).\n"
              "-- Asiento del jinete (origen de las hojas del personaje montado) en cada cuadro de cada montura, en píxeles de la tira horneada respecto al centro y\n"
              "-- la base de su casilla: pares dx, dy por cuadro (paso * 5 + hoja). No editar a mano.\nreturn {\n"]
    for idn, anims in datos.items():
        salida.append("  %s = {\n" % idn)
        for a, plano in anims.items():
            salida.append("    %s = { %s },\n" % (a, ", ".join("%g" % x for x in recolocar(idn, a, plano))))
        salida.append("  },\n")
    salida.append("}\n")
    open(ARCHIVO, "w", encoding="utf-8", newline="\n").write("".join(salida))
    print("asiento recolocado en %d monturas (LOMO %.2f)" % (len(datos), LOMO))


main()
