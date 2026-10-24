"""Agranda las monturas más pequeñas (hámsteres, cerditos, focas...) para que el jinete, que no se reduce, no sea mucho mayor que ellas.
Escribe `escala = <factor>, jinete = <factor>` en juego/src/presentacion/render/montura_ajustes.lua (el tamaño final de la montura es su escala de montura_anim_datos.lua por ese factor);
no toca las monturas que ya tengan ajustes a mano (posición o tamaño). El factor es OBJETIVO / alto en pantalla, con un tope de MAXIMO.
Uso: python -I -X utf8 herramientas/generar_mobs/escala_pequenas.py [OBJETIVO] [MAXIMO] [JINETE]"""
import os
import re
import sys

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RENDER = os.path.join(RAIZ, "juego", "src", "presentacion", "render")
OBJETIVO = float(sys.argv[1]) if len(sys.argv) > 1 else 42.0
MAXIMO = float(sys.argv[2]) if len(sys.argv) > 2 else 1.6
JINETE = float(sys.argv[3]) if len(sys.argv) > 3 else 0.85       # tamaño del jinete en esas monturas pequeñas (1 = el de siempre)

anim = open(os.path.join(RENDER, "montura_anim_datos.lua"), encoding="utf-8").read()
altos = {m.group(1): int(m.group(2)) for m in re.finditer(r'(mnt_\d+) = \{ carpeta = "[^"]+", alto = (\d+)', anim)}
ruta = os.path.join(RENDER, "montura_ajustes.lua")
texto = open(ruta, encoding="utf-8").read()
cabecera = texto[:texto.index("return {")]
cuerpo = texto[texto.index("return {") + len("return {"):texto.rindex("}")]
filas = {}
for linea in cuerpo.strip("\n").split("\n"):
    m = re.match(r"\s*(mnt_\d+) = \{(.*)\},?\s*$", linea)
    if m:
        filas[m.group(1)] = m.group(2).strip()
n = 0
for idn, alto in altos.items():
    if alto >= OBJETIVO:
        continue
    if idn in filas and not filas[idn].startswith("escala"):
        continue                                   # (ya tiene ajustes de posición a mano: no se toca)
    filas[idn] = "escala = %g, jinete = %g" % (round(min(MAXIMO, OBJETIVO / alto), 2), JINETE)
    n += 1
salida = cabecera + "return {\n" + "".join("  %s = { %s },\n" % (k, filas[k]) for k in sorted(filas)) + "}\n"
open(ruta, "w", encoding="utf-8", newline="\n").write(salida)
print("%d monturas pequeñas agrandadas (objetivo %g px, tope x%g)" % (n, OBJETIVO, MAXIMO))
