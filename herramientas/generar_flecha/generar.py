"""Flecha del ataque básico del arquero a partir de la lámina origen.png (flecha con estela en tres filas: la PRIMERA fila es la flecha básica, 6 cuadros;
la segunda, una flecha más potente; la tercera, el impacto). Escribe juego/arte/hojas/new-sprites/Animations/Proyectil_flecha.png: 6 cuadros del mismo tamaño
con la flecha (su cuerpo) siempre en el centro de la casilla y la punta mirando a la derecha, reducidos a que el cuerpo mida ANCHO_FLECHA px.
Uso: python -X utf8 herramientas/generar_flecha/generar.py"""
import os

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", ".."))
DESTINO = os.path.join(RAIZ, "juego", "arte", "hojas", "new-sprites", "Animations", "Proyectil_flecha.png")
ANCHO_FLECHA = 30           # px que mide el cuerpo de la flecha en la hoja final (se dibuja a 0,9 y con zoom 2)
FILA = 0                    # 0 = primera fila (flecha básica)


def grupos(perfil, hueco):
    res, ini, vac = [], None, 0
    for i, v in enumerate(list(perfil) + [0] * (hueco + 1)):
        if v:
            if ini is None:
                ini = i
            fin, vac = i, 0
        elif ini is not None:
            vac += 1
            if vac >= hueco:
                res.append((ini, fin))
                ini = None
                vac = 0
    return res


im = Image.open(os.path.join(AQUI, "origen.png")).convert("RGBA")
a = np.asarray(im)
suave = a[..., 3] > 20
filas = grupos(suave.sum(axis=1), 15)
y0, y1 = filas[FILA]
y0, y1 = max(0, y0 - 20), min(im.height, y1 + 20)
# las estelas de cuadros vecinos se tocan: se separan por los cuerpos opacos de las flechas (uno por cuadro) y el corte va a mitad de camino entre ellos
opaco = a[..., 3] > 200
nucleos = grupos(opaco[y0:y1].sum(axis=0), 40)
centros = [(n0 + n1) / 2 for n0, n1 in nucleos]
cortes = [0] + [int((centros[i] + centros[i + 1]) / 2) for i in range(len(centros) - 1)] + [im.width]
print("cuadros de la fila:", len(nucleos))
cuadros = []
for i in range(len(nucleos)):
    rec = im.crop((cortes[i], y0, cortes[i + 1], y1))
    nucleo = np.asarray(rec)[..., 3] > 200            # el cuerpo opaco de la flecha (la estela es translúcida)
    ys, xs = np.where(nucleo)
    cuadros.append((rec, (xs.min() + xs.max()) / 2.0, (ys.min() + ys.max()) / 2.0, xs.max() - xs.min() + 1))
largo0 = cuadros[0][3]
esc = ANCHO_FLECHA / largo0
izq = max(c[1] for c in cuadros) * esc
der = max((c[0].width - c[1]) for c in cuadros) * esc
arr = max(c[2] for c in cuadros) * esc
aba = max((c[0].height - c[2]) for c in cuadros) * esc
mitad_x, mitad_y = int(round(max(izq, der))) + 2, int(round(max(arr, aba))) + 2
cw, ch = 2 * mitad_x, 2 * mitad_y
hoja = Image.new("RGBA", (cw * len(cuadros), ch), (0, 0, 0, 0))
for i, (rec, cx, cy, _) in enumerate(cuadros):
    r = rec.resize((max(1, round(rec.width * esc)), max(1, round(rec.height * esc))), Image.LANCZOS)
    hoja.alpha_composite(r, (i * cw + mitad_x - round(cx * esc), mitad_y - round(cy * esc)))
hoja.save(DESTINO, optimize=True)
print("escrito", DESTINO, hoja.size, "casilla", cw, "x", ch)
