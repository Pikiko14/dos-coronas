"""Ordena el dibujo del equipo de los escalones 2 a 8 de cada clase de más sencillo a más elaborado (el 1 es siempre el de partida y el 9 y el 10 van al final).

Hace falta la hoja de comprobación del cliente SIN reordenar: borra juego/src/presentacion/render/fao_orden.lua, ejecuta
    DC_PRUEBA_EQUIPOS=1 lovec juego --test         (deja juego/capturas/equipos_wait_d0.png: una fila por clase y género, una columna por escalón)
y después:  python -X utf8 herramientas/generar_personajes/ordenar_escalones.py
Puntúa cada figura (casillas que ocupa y variedad de colores: más piezas, adornos y color = más elaborada) y escribe fao_orden.lua:
orden[clase][escalón] = de qué escalón original se toma el dibujo. fao.lua lo aplica al cargar e iconos_equipo.py lo lee para los iconos."""
import os

import numpy as np
from PIL import Image

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CAP = os.path.join(RAIZ, "juego", "capturas", "equipos_wait_d0.png")
SAL = os.path.join(RAIZ, "juego", "src", "presentacion", "render", "fao_orden.lua")
CLASES = ("guerrero", "lancero", "cazador", "mago", "clerigo", "nigromante")
FILAS = (0, 2, 4, 6, 8, 10)          # una por clase (la masculina)


def puntuar(celda, fondo):
    a = np.asarray(celda).astype(int)
    m = (np.abs(a[:, :, :3] - np.array(fondo)).sum(2) > 12) & (a[:, :, 3] > 10)
    n = int(m.sum())
    if n == 0:
        return 0
    px = a[:, :, :3][m] // 32
    colores = len({tuple(x) for x in px})
    return n + 8 * colores


def main():
    im = Image.open(CAP).convert("RGBA")
    ancho, alto = im.width // 10, im.height // 12
    fondo = im.getpixel((2, 2))[:3]
    orden = {}
    for clase, fila in zip(CLASES, FILAS):
        pts = {}
        for t in range(1, 11):
            pts[t] = puntuar(im.crop(((t - 1) * ancho, fila * alto, t * ancho, (fila + 1) * alto)), fondo)
        medios = sorted(range(2, 9), key=lambda t: (pts[t], t))
        orden[clase] = [1] + medios + [9, 10]
        print(clase, "puntos", [pts[t] for t in range(1, 11)], "->", orden[clase])
    lineas = ["-- GENERADO por herramientas/generar_personajes/ordenar_escalones.py: de qué escalón original se toma el dibujo de cada escalón (de más sencillo a más elaborado). No editar a mano.", "return {"]
    for clase in CLASES:
        lineas.append("  %s = { %s }," % (clase, ", ".join(str(x) for x in orden[clase])))
    lineas.append("}")
    with open(SAL, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lineas) + "\n")
    print("escrito", SAL)


if __name__ == "__main__":
    main()
