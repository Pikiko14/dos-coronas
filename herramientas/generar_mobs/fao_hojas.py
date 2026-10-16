"""Hornea una hoja de animación de FAO (cuadros en fila: 5 direcciones x N pasos) con las CINCO direcciones, para monturas y PNJ.

Orden de los cuadros del original (comprobado con los anclajes y los nombres de cada hoja): el archivo trae un cuadro por paso y dirección,
corrido uno: para P pasos va el paso 1 con las direcciones 1 a 4 (espalda, espalda-izquierda, izquierda, frente-izquierda), después
el paso 2 con la 0 (frente) y 1 a 4, y así hasta el paso P, y al final el cuadro que falta, el paso 1 de frente. Aquí se recolocan como
cuadro = paso * 5 + hoja, con las hojas: 0 frente, 1 espalda, 2 espalda-izquierda, 3 izquierda, 4 frente-izquierda (las otras tres direcciones
del juego se dibujan volteando 4, 3 y 2). Es el mismo orden que usan los personajes por capas (hornear_equipos.py)."""
import numpy as np
from PIL import Image


def indice_original(paso, hoja, n):
    """Índice, en la hoja original de n cuadros, del cuadro (paso, hoja)."""
    if hoja >= 1:
        return paso * 5 + hoja - 1
    return paso * 5 - 1 if paso >= 1 else n - 1


def hornear(im, pasos, bake, pad, anclas=None):
    """im: hoja original RGBA. bake: tamaño del horneado respecto al original. anclas: lista [w, h, ox, oy] por cuadro original (opcional).
    Devuelve (tira, cw, ch, alto, asiento): la tira con cuadro = paso * 5 + hoja, el tamaño de casilla, el alto del cuadro de espera de frente
    (en píxeles horneados) y, si hay anclajes, la lista plana [dx, dy, ...] por cuadro con el origen del arte original respecto al centro y la
    base de la casilla."""
    n = pasos * 5
    w, h = im.width // n, im.height
    alfa = np.asarray(im)[:, :, 3] > 10
    # suelo por dirección: se recorta el hueco bajo los pies (cada hoja tiene su línea del suelo)
    hueco = {}
    for hoja in range(5):
        m = 10 ** 9
        for p in range(pasos):
            i = indice_original(p, hoja, n)
            filas = np.where(alfa[:, i * w:(i + 1) * w].any(1))[0]
            if len(filas):
                m = min(m, h - 1 - int(filas.max()))
        hueco[hoja] = 0 if m == 10 ** 9 else m
    cw, ch = int(w * bake) + 2 * pad, int(h * bake) + 2 * pad
    tira = Image.new("RGBA", (cw * n, ch), (0, 0, 0, 0))
    plano = []
    for p in range(pasos):
        for hoja in range(5):
            i = indice_original(p, hoja, n)
            c = im.crop((i * w, 0, (i + 1) * w, h - hueco[hoja]))
            if bake != 1:
                c = c.resize((max(1, int(c.width * bake)), max(1, int(c.height * bake))), Image.LANCZOS)
            arriba = ch - pad - c.height
            tira.alpha_composite(c, ((p * 5 + hoja) * cw + pad, arriba))
            if anclas:
                aw, ah, aox, aoy = anclas[i]
                plano += [round(pad + aox * bake - cw / 2, 1), round(arriba + aoy * bake - (ch - pad), 1)]
    caja = tira.crop((4 * cw, 0, 5 * cw, ch)).getchannel("A").point(lambda a: 255 if a > 10 else 0).getbbox()
    alto = (caja[3] - caja[1]) if caja else ch
    return tira, cw, ch, alto, plano


def guardar(tira, ruta):
    """PNG con paleta de 256 colores (sin tramado: los bordes quedan limpios) para que pesen poco."""
    tira.quantize(colors=256, method=Image.FASTOCTREE, dither=Image.NONE).save(ruta, optimize=True)
