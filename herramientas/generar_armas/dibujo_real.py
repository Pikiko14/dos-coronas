"""Lancero de Albor en estilo semirrealista (HD, sombreado suave): cuadro de 128x128, dibujado con 4x de supersampling."""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

K = 4
N = 128 * K
OY = 4
OUT = (24, 20, 34, 255)


def c(r, g, b): return (r, g, b)


STEEL = ((222, 232, 246), (128, 142, 170))
STEEL_D = ((170, 182, 206), (84, 96, 124))
GOLD = ((250, 214, 110), (176, 124, 38))
BLUE = ((96, 144, 224), (34, 58, 124))
CAPE = ((248, 244, 234), (178, 168, 150))
SKIN = ((248, 214, 178), (200, 150, 112))
LEATHER = ((150, 104, 62), (74, 46, 28))
WOOD = ((190, 142, 84), (96, 62, 34))
BOOT = ((120, 82, 50), (46, 30, 22))
RED = ((232, 66, 72), (128, 26, 38))
PANTS = ((96, 108, 138), (44, 52, 78))


class Lienzo:
    def __init__(self):
        self.im = Image.new("RGBA", (N, N), (0, 0, 0, 0))

    def _mascara(self, forma):
        m = Image.new("L", (N, N), 0)
        d = ImageDraw.Draw(m)
        if forma[0] == "p":
            d.polygon([(x * K, (y + OY) * K) for x, y in forma[1]], fill=255)
        elif forma[0] == "e":
            x0, y0, x1, y1 = forma[1]
            d.ellipse((x0 * K, (y0 + OY) * K, x1 * K, (y1 + OY) * K), fill=255)
        elif forma[0] == "r":
            x0, y0, x1, y1, r = forma[1]
            d.rounded_rectangle((x0 * K, (y0 + OY) * K, x1 * K, (y1 + OY) * K), radius=r * K, fill=255)
        return m

    def pieza(self, forma, col, angulo=125, contorno=True, brillo=0.0):
        """Rellena una forma con degradado (luz arriba a la izquierda) y un contorno fino."""
        m = self._mascara(forma)
        bb = m.getbbox()
        if not bb:
            return
        x0, y0, x1, y1 = bb
        w, h = max(1, x1 - x0), max(1, y1 - y0)
        a = math.radians(angulo)
        dx, dy = math.cos(a), math.sin(a)
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        t = ((xx / w - 0.5) * dx * -1 + (yy / h - 0.5) * dy) + 0.5
        t = np.clip(t, 0, 1)[..., None]
        c1 = np.array(col[0], dtype=np.float32)
        c2 = np.array(col[1], dtype=np.float32)
        img = (c1 * (1 - t) + c2 * t).astype(np.uint8)
        capa = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        tile = Image.fromarray(img, "RGB").convert("RGBA")
        capa.paste(tile, (x0, y0))
        capa.putalpha(m)
        self.im.alpha_composite(capa)
        if contorno:
            borde = m.filter(ImageFilter.MaxFilter(5)).point(lambda v: v)
            borde = Image.composite(borde, Image.new("L", (N, N), 0), borde)
            interior = m.filter(ImageFilter.MinFilter(1)) if False else m
            anillo = Image.new("L", (N, N), 0)
            anillo.paste(borde, (0, 0))
            from PIL import ImageChops
            anillo = ImageChops.subtract(borde, m)
            linea = Image.new("RGBA", (N, N), OUT)
            linea.putalpha(anillo)
            self.im.alpha_composite(linea)
        if brillo > 0:
            # destello: franja clara en el lado de la luz
            sh = Image.new("RGBA", (N, N), (255, 255, 255, 0))
            md = Image.new("L", (N, N), 0)
            ImageDraw.Draw(md).polygon([(x0 + w * 0.12, y0 + h * 0.08), (x0 + w * 0.38, y0 + h * 0.05), (x0 + w * 0.30, y0 + h * 0.85), (x0 + w * 0.10, y0 + h * 0.8)], fill=int(255 * brillo))
            md = ImageChops.multiply(md, m) if False else md
            from PIL import ImageChops as IC
            md = IC.multiply(md, m)
            sh.putalpha(md.filter(ImageFilter.GaussianBlur(K)))
            self.im.alpha_composite(sh)

    def linea(self, pts, col, ancho):
        d = ImageDraw.Draw(self.im, "RGBA")
        d.line([(x * K, (y + OY) * K) for x, y in pts], fill=col, width=int(ancho * K), joint="curve")

    def punto(self, x, y, r, col):
        d = ImageDraw.Draw(self.im, "RGBA")
        d.ellipse(((x - r) * K, (y + OY - r) * K, (x + r) * K, (y + OY + r) * K), fill=col)

    def sombra(self):
        s = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        ImageDraw.Draw(s).ellipse((34 * K, (114 + OY) * K, 94 * K, (126 + OY) * K), fill=(0, 0, 0, 90))
        self.im.alpha_composite(s.filter(ImageFilter.GaussianBlur(3 * K)))

    def salida(self):
        return self.im.resize((128, 128), Image.LANCZOS)


def lanza(L, x, y0, y1):
    L.pieza(("r", (x - 1.1, y1 + 4, x + 1.1, y0, 1)), WOOD, 180)
    L.pieza(("p", [(x - 3.6, y1 + 7), (x, y1 - 12), (x + 3.6, y1 + 7), (x, y1 + 4)]), STEEL, 150, brillo=0.5)
    L.linea([(x, y1 - 8), (x, y1 + 4)], (255, 255, 255, 120), 0.6)
    L.pieza(("r", (x - 2.4, y1 + 6, x + 2.4, y1 + 9, 1)), GOLD, 120)
    L.pieza(("p", [(x - 3, y1 + 9), (x + 3, y1 + 9), (x + 5, y1 + 21), (x + 1, y1 + 18), (x - 1, y1 + 22), (x - 4, y1 + 17)]), RED, 120, contorno=True)


def frente():
    L = Lienzo()
    L.sombra()
    # capa por detrás
    L.pieza(("p", [(42, 36), (86, 36), (94, 96), (88, 108), (64, 104), (40, 108), (34, 96)]), CAPE, 100)
    for x in (48, 58, 70, 80):
        L.linea([(x, 44), (x - (64 - x) * 0.18, 102)], (150, 138, 118, 120), 0.8)
    L.linea([(36, 105), (62, 101), (92, 105)], GOLD[1] + (255,), 1.2)
    # piernas
    L.pieza(("p", [(50, 70), (63, 70), (62, 96), (52, 96)]), PANTS, 120)
    L.pieza(("p", [(65, 70), (78, 70), (76, 96), (66, 96)]), PANTS, 120)
    # grebas
    L.pieza(("p", [(52, 92), (62, 92), (61, 112), (53, 112)]), STEEL, 125, brillo=0.5)
    L.pieza(("p", [(66, 92), (76, 92), (75, 112), (67, 112)]), STEEL, 125, brillo=0.5)
    L.pieza(("e", (51, 84, 63, 96)), GOLD, 125)
    L.pieza(("e", (65, 84, 77, 96)), GOLD, 125)
    # botas
    L.pieza(("p", [(51, 110), (62, 110), (64, 121), (48, 121)]), BOOT, 125)
    L.pieza(("p", [(66, 110), (77, 110), (80, 121), (63, 121)]), BOOT, 125)
    # torso
    L.pieza(("p", [(46, 34), (82, 34), (78, 56), (74, 74), (54, 74), (50, 56)]), STEEL, 125, brillo=0.55)
    L.pieza(("p", [(58, 36), (70, 36), (72, 78), (64, 86), (56, 78)]), BLUE, 120)
    L.linea([(64, 40), (64, 80)], (255, 255, 255, 90), 0.6)
    # faldones
    for i, x in enumerate((48, 56, 64, 72)):
        L.pieza(("p", [(x, 72), (x + 9, 72), (x + 8, 86), (x + 1, 86)]), STEEL_D, 125)
    L.pieza(("r", (47, 69, 81, 74, 1)), LEATHER, 120)
    L.pieza(("r", (60, 68, 68, 76, 2)), GOLD, 120)
    # hombreras y brazos
    L.pieza(("e", (33, 31, 53, 47)), STEEL, 125, brillo=0.55)
    L.pieza(("e", (75, 31, 95, 47)), STEEL, 125, brillo=0.4)
    L.linea([(35, 37), (51, 37)], GOLD[0] + (255,), 1.2)
    L.linea([(77, 37), (93, 37)], GOLD[0] + (255,), 1.2)
    L.pieza(("p", [(34, 44), (44, 44), (43, 72), (35, 72)]), STEEL_D, 120)
    L.pieza(("p", [(84, 44), (94, 44), (93, 66), (85, 66)]), STEEL_D, 120)
    L.pieza(("e", (33, 70, 45, 80)), LEATHER, 125)
    L.pieza(("e", (84, 62, 98, 74)), LEATHER, 125)
    lanza(L, 101, 124, 8)
    L.pieza(("e", (95, 62, 107, 74)), LEATHER, 125)
    # cuello y cabeza
    L.pieza(("r", (60, 24, 68, 36, 2)), SKIN, 120)
    L.pieza(("e", (52, 6, 76, 34)), SKIN, 120)
    # yelmo abierto
    L.pieza(("p", [(50, 20), (52, 6), (64, -1), (76, 6), (78, 20), (72, 14), (64, 11), (56, 14)]), STEEL, 125, brillo=0.6)
    L.pieza(("p", [(61, 6), (67, 6), (66, 24), (62, 24)]), STEEL_D, 120)
    L.pieza(("p", [(50, 18), (56, 16), (57, 32), (52, 30)]), STEEL, 125)
    L.pieza(("p", [(78, 18), (72, 16), (71, 32), (76, 30)]), STEEL, 125)
    # rostro
    L.linea([(55, 20), (61, 19)], (70, 46, 30, 255), 1.0)
    L.linea([(67, 19), (73, 20)], (70, 46, 30, 255), 1.0)
    L.punto(58, 22.2, 1.5, (30, 24, 44, 255)); L.punto(70, 22.2, 1.5, (30, 24, 44, 255))
    L.punto(58.5, 21.6, 0.5, (255, 255, 255, 255)); L.punto(70.5, 21.6, 0.5, (255, 255, 255, 255))
    L.linea([(64, 22), (63, 27), (65, 27)], (170, 120, 90, 255), 0.7)
    L.linea([(60, 30), (64, 31), (68, 30)], (150, 84, 70, 255), 0.8)
    # penacho
    L.pieza(("p", [(60, 4), (68, 4), (78, -3), (84, 4), (76, 12), (70, 8)]), RED, 120)
    L.linea([(66, 2), (80, 0), (82, 5)], (255, 160, 150, 160), 0.8)
    return L.salida()


def lado():
    L = Lienzo()
    L.sombra()
    L.pieza(("p", [(54, 36), (66, 36), (62, 100), (44, 108), (36, 96), (46, 64)]), CAPE, 100)
    L.linea([(40, 100), (60, 98)], GOLD[1] + (255,), 1.2)
    # pierna trasera
    L.pieza(("p", [(58, 70), (70, 70), (70, 96), (60, 96)]), PANTS, 120)
    L.pieza(("p", [(60, 92), (69, 92), (69, 112), (61, 112)]), STEEL_D, 125)
    L.pieza(("p", [(58, 110), (70, 110), (76, 121), (58, 121)]), BOOT, 125)
    # pierna delantera
    L.pieza(("p", [(52, 70), (64, 70), (62, 96), (52, 96)]), PANTS, 120)
    L.pieza(("p", [(52, 92), (62, 92), (62, 112), (53, 112)]), STEEL, 125, brillo=0.5)
    L.pieza(("e", (50, 84, 63, 96)), GOLD, 125)
    L.pieza(("p", [(50, 110), (63, 110), (70, 121), (48, 121)]), BOOT, 125)
    # torso de perfil
    L.pieza(("p", [(52, 34), (76, 34), (74, 56), (72, 74), (56, 74), (54, 56)]), STEEL, 125, brillo=0.55)
    L.pieza(("p", [(66, 36), (76, 36), (74, 78), (66, 84)]), BLUE, 120)
    L.pieza(("r", (53, 69, 75, 74, 1)), LEATHER, 120)
    L.pieza(("r", (68, 68, 75, 76, 2)), GOLD, 120)
    for x in (54, 62):
        L.pieza(("p", [(x, 72), (x + 9, 72), (x + 8, 86), (x + 1, 86)]), STEEL_D, 125)
    L.pieza(("e", (51, 31, 71, 47)), STEEL, 125, brillo=0.55)
    L.linea([(53, 37), (69, 37)], GOLD[0] + (255,), 1.2)
    # brazo adelantado con la lanza
    L.pieza(("p", [(60, 42), (70, 44), (74, 64), (66, 66)]), STEEL_D, 120)
    lanza(L, 84, 124, 8)
    L.pieza(("e", (72, 58, 88, 72)), LEATHER, 125)
    # cabeza de perfil
    L.pieza(("r", (58, 24, 68, 36, 2)), SKIN, 120)
    L.pieza(("p", [(54, 12), (60, 6), (72, 8), (78, 16), (76, 26), (70, 32), (60, 32), (54, 24)]), SKIN, 120)
    L.pieza(("p", [(52, 18), (54, 5), (66, -2), (78, 6), (79, 14), (70, 12), (60, 14), (58, 30), (52, 28)]), STEEL, 125, brillo=0.6)
    L.pieza(("p", [(55, 16), (61, 14), (62, 32), (56, 30)]), STEEL, 125)
    L.linea([(70, 17), (75, 18)], (70, 46, 30, 255), 1.0)
    L.punto(73, 21, 1.5, (30, 24, 44, 255)); L.punto(73.4, 20.5, 0.5, (255, 255, 255, 255))
    L.linea([(78, 20), (80, 25), (77, 25)], (170, 120, 90, 255), 0.7)
    L.linea([(71, 29), (75, 29.5)], (150, 84, 70, 255), 0.8)
    L.pieza(("p", [(52, 4), (60, 3), (50, -3), (40, 0), (36, 8), (46, 10), (54, 10)]), RED, 120)
    return L.salida()


if __name__ == "__main__":
    import sys
    f, s = frente(), lado()
    out = sys.argv[1]
    f.save(out + "/real_frente.png")
    s.save(out + "/real_lado.png")
    fondo = Image.new("RGBA", (128 * 3 * 3 + 20, 128 * 3), (30, 40, 70, 255))
    for i, im in enumerate([f, s.transpose(Image.FLIP_LEFT_RIGHT), s]):
        fondo.alpha_composite(im.resize((384, 384), Image.LANCZOS), (i * 384 + 10, 0))
    fondo.save(out + "/real_ampliada.png")
    print("ok")
