"""Dibuja la flecha del ataque básico del arquero: juego/arte/hojas/new-sprites/Animations/Proyectil_flecha.png (4 cuadros de 64x64, mira a la derecha).
Pixel art con contorno oscuro, asta de madera con luz y sombra, punta de acero biselada y plumas rojas y blancas, con una estela que parpadea.
Uso: python -I -X utf8 herramientas/generar_flecha.py"""
import os

from PIL import Image

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DESTINO = os.path.join(RAIZ, "juego", "arte", "hojas", "new-sprites", "Animations", "Proyectil_flecha.png")

CONTORNO = (38, 24, 18, 255)
MADERA = [(214, 160, 92, 255), (170, 114, 58, 255), (118, 74, 38, 255)]       # luz, medio, sombra
ACERO = [(240, 246, 255, 255), (186, 198, 216, 255), (118, 132, 156, 255)]
ACERO_CONT = (34, 40, 58, 255)
ROJO = [(236, 92, 76, 255), (196, 48, 44, 255), (132, 30, 36, 255)]
BLANCO = [(255, 252, 240, 255), (222, 216, 200, 255)]


def punto(im, x, y, c):
    if 0 <= x < 64 and 0 <= y < 64:
        im.putpixel((x, y), c)


def flecha(cuadro):
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    cy = 32
    # estela: unas rayas tenues detrás de las plumas, que cambian de largo en cada cuadro
    for fila, largo in zip((-3, -1, 1, 3), ((6, 11, 7, 9), (10, 6, 12, 7), (8, 12, 6, 10), (12, 8, 9, 6))[cuadro]):
        for i in range(largo):
            a = int(120 * (1 - i / largo))
            punto(im, 13 - i, cy + fila, (255, 244, 214, a))
    # asta (de la cola x=16 a la punta x=47): contorno arriba y abajo y tres tonos de madera
    for x in range(16, 48):
        punto(im, x, cy - 2, CONTORNO)
        punto(im, x, cy + 2, CONTORNO)
        punto(im, x, cy - 1, MADERA[0])
        punto(im, x, cy, MADERA[1])
        punto(im, x, cy + 1, MADERA[2])
    # vetas
    for x in range(20, 46, 6):
        punto(im, x, cy, MADERA[2])
    # punta de acero: rombo alargado de x=46 a x=59
    largo = 13
    for i in range(largo):
        x = 46 + i
        alto = max(0, 4 - (i * 5) // largo)         # 4,4,3,3,... 0
        for dy in range(-alto - 1, alto + 2):
            if abs(dy) == alto + 1:
                punto(im, x, cy + dy, ACERO_CONT)
            else:
                t = 0 if dy < 0 else (1 if dy == 0 else 2)
                punto(im, x, cy + dy, ACERO[t])
    punto(im, 59, cy, ACERO_CONT)
    punto(im, 60, cy, ACERO_CONT)
    # destello en la punta (parpadea)
    if cuadro in (1, 3):
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            punto(im, 55 + dx, cy - 2 + dy, (255, 255, 255, 255))
    # plumas: dos aletas en cuña (cortas en la cola y más altas junto al asta), con rayas rojas y blancas
    for i in range(12):
        x = 8 + i
        alto = 1 + (i * 4) // 11
        for sgn in (-1, 1):
            for dy in range(1, alto + 1):
                y = cy + sgn * (dy + 1)
                franja = ((i + dy) // 3) % 2 == 0
                tono = (ROJO[0] if sgn < 0 else ROJO[1]) if franja else (BLANCO[0] if sgn < 0 else BLANCO[1])
                punto(im, x, y, tono)
            punto(im, x, cy + sgn * (alto + 2), CONTORNO)
            if i == 11:
                for dy in range(1, alto + 2):
                    punto(im, x + 1, cy + sgn * (dy + 1), CONTORNO)
    # cola (muesca)
    punto(im, 7, cy, CONTORNO)
    punto(im, 8, cy, CONTORNO)
    punto(im, 8, cy - 1, MADERA[2])
    punto(im, 8, cy + 1, MADERA[2])
    return im


hoja = Image.new("RGBA", (256, 64), (0, 0, 0, 0))
for k in range(4):
    hoja.paste(flecha(k), (k * 64, 0))
hoja.save(DESTINO, optimize=True)
print("ok", DESTINO)
