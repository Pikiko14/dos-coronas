"""Armas originales de Dos Coronas: 12 familias x 8 escalones, dibujadas por código con el estilo de las referencias (contorno oscuro
fino, sombreado suave desde arriba a la izquierda, brillos). Cada arma sale en vertical, con el puño abajo en el centro (ancla 64,118)."""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFont
from dibujo_real import Lienzo

def sh(c, k): return tuple(max(0, min(255, int(v * k))) for v in c[:3])
def par(c, a=1.25, b=0.62): return (sh(c, a), sh(c, b))

# materiales por escalón: tosco, de soldado, de veterano, de capitán, de campeón, de élite, legendario, de corona
METAL = [(124, 112, 100), (158, 162, 170), (198, 208, 222), (150, 194, 240), (246, 212, 106), (168, 126, 234), (244, 134, 64), (252, 250, 240)]
MADERA = [(120, 84, 52), (140, 98, 58), (160, 112, 64), (150, 104, 80), (170, 120, 70), (96, 64, 110), (120, 60, 40), (210, 190, 150)]
BRILLO = [None, None, None, (170, 225, 255), (255, 236, 150), (214, 170, 255), (255, 170, 90), (255, 255, 255)]
GEMA = [(150, 150, 150), (120, 200, 120), (110, 170, 240), (110, 220, 255), (255, 210, 90), (200, 120, 255), (255, 120, 70), (255, 255, 255)]
ORO = par((246, 206, 96))
CUERO = par((130, 86, 50))
NOMBRES_TIER = ["tosco", "de soldado", "de veterano", "de capitán", "de campeón", "de élite", "legendario", "de corona"]


def aura(L, x, y, r, col):
    from PIL import ImageFilter, ImageDraw as D
    from dibujo_real import N, K
    g = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    D.Draw(g).ellipse(((x - r) * K, (y + 4 - r) * K, (x + r) * K, (y + 4 + r) * K), fill=col + (95,))
    L.im.alpha_composite(g.filter(ImageFilter.GaussianBlur(r * K * 0.45)))


def runa(L, x, y0, y1, col, n=3):
    for i in range(n):
        y = y0 + (y1 - y0) * (i + 0.5) / n
        L.punto(x, y, 1.1, col + (230,))


def mango(L, x, y0, y1, ancho, col):
    L.pieza(("r", (x - ancho, y0, x + ancho, y1, ancho * 0.7)), col, 175)


# ---------------------------------------------------------------- familias
def espada(t):
    L = Lienzo(); m = par(METAL[t]); md = par(sh(METAL[t], 0.78)); br = BRILLO[t]
    ancho = 5.2 + t * 0.35
    if br: aura(L, 64, 50, 26, br)
    L.pieza(("p", [(64 - ancho, 88), (64 - ancho * 0.9, 24), (64, 4), (64 + ancho * 0.9, 24), (64 + ancho, 88)]), m, 110, brillo=0.7)
    L.pieza(("p", [(64, 8), (64 + ancho, 88), (64, 88)]), md, 110, contorno=False)
    L.linea([(64, 14), (64, 84)], (255, 255, 255, 120), 0.9)
    if t >= 3:
        L.linea([(62.2, 30), (62.2, 82)], sh(METAL[t], 0.6) + (160,), 0.8)
    if t >= 5: runa(L, 64, 34, 80, br or (255, 255, 255), 4)
    guard = ORO if t >= 4 else par(sh(METAL[t], 0.7))
    L.pieza(("r", (46 - t, 88, 82 + t, 94, 3)), guard, 100)
    L.pieza(("e", (42 - t, 86, 50 - t, 96)), guard, 100); L.pieza(("e", (78 + t, 86, 86 + t, 96)), guard, 100)
    mango(L, 64, 94, 112, 3.2, CUERO)
    L.linea([(61, 98), (67, 100), (61, 104), (67, 106), (61, 110)], (40, 24, 14, 200), 0.7)
    L.pieza(("e", (59, 110, 69, 120)), ORO if t >= 2 else par(sh(METAL[t], 0.8)), 100)
    if t >= 4: L.punto(64, 115, 2.2, GEMA[t] + (255,))
    return L.salida()


def hacha(t):
    L = Lienzo(); m = par(METAL[t]); md = par(sh(METAL[t], 0.75)); br = BRILLO[t]
    if br: aura(L, 78, 36, 28, br)
    L.pieza(("r", (61.5, 8, 66.5, 118, 2)), par(MADERA[t]), 170)
    cab = 6 + t * 0.6
    L.pieza(("p", [(66, 14), (90 + cab, 8), (96 + cab, 28), (90 + cab, 50), (66, 44), (66, 36)]), m, 115, brillo=0.7)
    L.pieza(("p", [(66, 36), (90 + cab, 50), (66, 44)]), md, 115, contorno=False)
    L.linea([(70, 20), (92 + cab, 14), (95 + cab, 28), (91 + cab, 44)], (255, 255, 255, 150), 0.9)
    if t >= 5: L.pieza(("p", [(58, 14), (36 - cab * 0.5, 12), (30 - cab * 0.5, 28), (36 - cab * 0.5, 44), (58, 40)]), m, 115, brillo=0.5)
    L.pieza(("p", [(64, 2), (68, 12), (60, 12)]), m, 120)
    L.pieza(("r", (59, 40, 69, 46, 2)), ORO if t >= 3 else CUERO, 110)
    mango(L, 64, 90, 112, 3.6, CUERO)
    L.pieza(("e", (58, 112, 70, 122)), par(sh(METAL[t], 0.85)), 100)
    if t >= 4: runa(L, 78 + cab, 22, 40, br or GEMA[t], 3)
    return L.salida()


def lanza(t):
    L = Lienzo(); m = par(METAL[t]); br = BRILLO[t]
    if br: aura(L, 64, 18, 22, br)
    L.pieza(("r", (62.4, 28, 65.6, 120, 1.6)), par(MADERA[t]), 170)
    ancho = 6 + t * 0.4
    L.pieza(("p", [(64, -2), (64 + ancho, 22), (64, 36), (64 - ancho, 22)]), m, 110, brillo=0.8)
    L.linea([(64, 4), (64, 32)], (255, 255, 255, 140), 0.8)
    L.pieza(("r", (60, 34, 68, 40, 2)), ORO if t >= 3 else par(sh(METAL[t], 0.7)), 100)
    L.pieza(("p", [(64, 38), (72, 58), (68, 72), (64, 64), (60, 72), (56, 58)]), par((206, 56, 64)) if t < 5 else par(GEMA[t]), 110)
    mango(L, 64, 90, 104, 2.6, CUERO)
    L.pieza(("p", [(62, 116), (66, 116), (64, 124)]), m, 100)
    return L.salida()


def alabarda(t):
    L = Lienzo(); m = par(METAL[t]); md = par(sh(METAL[t], 0.75)); br = BRILLO[t]
    if br: aura(L, 72, 24, 26, br)
    L.pieza(("r", (62.4, 20, 65.6, 120, 1.6)), par(MADERA[t]), 170)
    L.pieza(("p", [(64, -4), (68, 16), (64, 24), (60, 16)]), m, 110, brillo=0.7)
    L.pieza(("p", [(66, 22), (92 + t, 16), (98 + t, 34), (90 + t, 52), (66, 44)]), m, 115, brillo=0.6)
    L.pieza(("p", [(66, 44), (90 + t, 52), (66, 36)]), md, 115, contorno=False)
    L.pieza(("p", [(62, 28), (46 - t * 0.5, 40), (62, 48)]), m, 115)
    L.pieza(("r", (59, 42, 69, 48, 2)), ORO if t >= 3 else CUERO, 110)
    mango(L, 64, 92, 106, 2.8, CUERO)
    L.pieza(("p", [(62, 116), (66, 116), (64, 125)]), m, 100)
    if t >= 4: runa(L, 80 + t, 28, 46, br or GEMA[t], 3)
    return L.salida()


def arco(t):
    L = Lienzo(); br = BRILLO[t]; mad = par(MADERA[t])
    if br: aura(L, 92, 62, 34, br)
    pts = []
    for i in range(0, 21):
        a = -math.pi / 2 + math.pi * i / 20
        pts.append((74 - 38 * math.cos(a - math.pi / 2 + math.pi / 2) * 0.0 + 22 * math.cos(a) * 1.0 + 8, 62 + 52 * math.sin(a)))
    # curva del arco: cuerpo grueso de dos pasadas
    L.linea(pts, mad[1] + (255,), 5.2 + t * 0.1)
    L.linea(pts, mad[0] + (255,), 3.4 + t * 0.1)
    L.linea(pts, (255, 255, 255, 70), 1.0)
    L.linea([(pts[0][0], pts[0][1]), (pts[-1][0], pts[-1][1])], (232, 228, 214, 255), 0.9)
    L.pieza(("r", (92, 54, 98, 72, 2)), CUERO, 175)
    cuerno = ORO if t >= 3 else par(sh(METAL[t], 0.9))
    L.pieza(("e", (pts[0][0] - 3, pts[0][1] - 3, pts[0][0] + 3, pts[0][1] + 3)), cuerno, 100)
    L.pieza(("e", (pts[-1][0] - 3, pts[-1][1] - 3, pts[-1][0] + 3, pts[-1][1] + 3)), cuerno, 100)
    return L.salida()


def ballesta(t):
    L = Lienzo(); m = par(METAL[t]); mad = par(MADERA[t]); br = BRILLO[t]
    if br: aura(L, 64, 40, 30, br)
    L.pieza(("p", [(60, 10), (68, 10), (70, 100), (64, 110), (58, 100)]), mad, 170)
    L.linea([(28, 40), (40, 24), (64, 30), (88, 24), (100, 40)], m[1] + (255,), 5.0)
    L.linea([(28, 40), (40, 24), (64, 30), (88, 24), (100, 40)], m[0] + (255,), 3.2)
    L.linea([(28, 40), (64, 54), (100, 40)], (232, 228, 214, 255), 0.9)
    L.pieza(("r", (62, 18, 66, 60, 1)), par(sh(METAL[t], 0.7)), 170)
    L.pieza(("p", [(64, 6), (68, 18), (60, 18)]), m, 110)
    L.pieza(("r", (58, 70, 70, 76, 2)), ORO if t >= 3 else CUERO, 110)
    L.pieza(("e", (58, 98, 70, 112)), CUERO, 120)
    if t >= 4: runa(L, 64, 66, 94, br or GEMA[t], 3)
    return L.salida()


def baston(t):
    L = Lienzo(); mad = par(MADERA[t]); br = BRILLO[t]; g = GEMA[t]
    aura(L, 64, 20, 30 if br else 18, g if not br else br)
    L.pieza(("r", (61.8, 30, 66.2, 122, 2.2)), mad, 170)
    L.linea([(58, 36), (56, 20), (64, 6), (72, 20), (70, 36)], mad[1] + (255,), 3.4)
    L.linea([(58, 36), (56, 20), (64, 6), (72, 20), (70, 36)], mad[0] + (255,), 2.0)
    L.pieza(("e", (54, 10, 74, 32)), par(g), 120, brillo=0.8)
    L.punto(60, 16, 2.6, (255, 255, 255, 190))
    L.pieza(("r", (58, 34, 70, 40, 2)), ORO if t >= 2 else CUERO, 110)
    for y in (70, 90):
        L.pieza(("r", (60.5, y, 67.5, y + 3, 1)), CUERO, 110)
    return L.salida()


def vara(t):
    L = Lienzo(); mad = par(sh(MADERA[t], 0.9)); br = BRILLO[t]; g = GEMA[t]
    aura(L, 64, 22, 24, g)
    L.pieza(("p", [(62, 40), (66, 40), (67, 120), (61, 120)]), mad, 170)
    L.pieza(("p", [(64, 0), (74, 18), (64, 40), (54, 18)]), par(g), 120, brillo=0.9)
    L.linea([(64, 4), (64, 36)], (255, 255, 255, 120), 0.8)
    L.pieza(("r", (57, 38, 71, 44, 3)), ORO, 110)
    L.pieza(("e", (58, 86, 70, 98)), par(g), 120)
    L.pieza(("r", (58, 112, 70, 118, 2)), ORO if t >= 3 else CUERO, 110)
    return L.salida()


def maza(t):
    L = Lienzo(); m = par(METAL[t]); md = par(sh(METAL[t], 0.75)); br = BRILLO[t]
    if br: aura(L, 64, 28, 28, br)
    L.pieza(("r", (61.6, 30, 66.4, 120, 2)), par(MADERA[t]), 170)
    L.pieza(("e", (46, 4, 82, 40)), m, 115, brillo=0.7)
    for i in range(6):
        a = i * math.pi / 3
        x, y = 64 + 18 * math.cos(a), 22 + 18 * math.sin(a)
        L.pieza(("p", [(x - 3, y - 3), (x + 3, y - 3), (x + 4 * math.cos(a) * 2 + 0, y + 4 * math.sin(a) * 2)]), md, 115, contorno=False)
    L.pieza(("p", [(42, 22), (46, 14), (46, 30)]), m, 120); L.pieza(("p", [(86, 22), (82, 14), (82, 30)]), m, 120)
    L.pieza(("p", [(64, -2), (70, 6), (58, 6)]), m, 120)
    L.pieza(("e", (56, 40, 72, 50)), ORO if t >= 3 else par(sh(METAL[t], 0.8)), 100)
    mango(L, 64, 92, 108, 3.2, CUERO)
    L.pieza(("e", (58, 112, 70, 124)), par(sh(METAL[t], 0.85)), 100)
    if t >= 4: runa(L, 64, 8, 36, br or GEMA[t], 3)
    return L.salida()


def cetro(t):
    L = Lienzo(); m = par(METAL[t]); br = BRILLO[t]; g = GEMA[t]
    aura(L, 64, 22, 28, g)
    L.pieza(("r", (62, 36, 66, 120, 2)), ORO if t >= 2 else par(MADERA[t]), 170)
    # sol / cruz del clérigo
    for a in range(8):
        ang = a * math.pi / 4
        x1, y1 = 64 + 12 * math.cos(ang), 22 + 12 * math.sin(ang)
        x2, y2 = 64 + 22 * math.cos(ang), 22 + 22 * math.sin(ang)
        L.linea([(x1, y1), (x2, y2)], ORO[1] + (255,), 3.6); L.linea([(x1, y1), (x2, y2)], ORO[0] + (255,), 2.0)
    L.pieza(("e", (52, 10, 76, 34)), ORO, 115, brillo=0.8)
    L.pieza(("e", (57, 15, 71, 29)), par(g), 120)
    L.punto(62, 20, 2, (255, 255, 255, 200))
    L.pieza(("r", (57, 36, 71, 42, 3)), ORO, 110)
    L.pieza(("e", (58, 100, 70, 112)), ORO, 110)
    return L.salida()


def baculo(t):
    L = Lienzo(); br = BRILLO[t]; g = GEMA[t]; mad = par((74, 56, 70))
    aura(L, 64, 22, 30, g if t >= 2 else (110, 255, 170))
    L.pieza(("r", (61.8, 36, 66.2, 122, 2)), mad, 170)
    # media luna con calavera
    L.linea([(50, 28), (48, 14), (58, 4), (64, 10), (70, 4), (80, 14), (78, 28)], (30, 22, 40, 255), 4.6)
    L.linea([(50, 28), (48, 14), (58, 4), (64, 10), (70, 4), (80, 14), (78, 28)], par(sh(METAL[t], 0.7))[0] + (255,), 2.8)
    L.pieza(("e", (54, 12, 74, 36)), par((236, 232, 222)), 120, brillo=0.7)
    L.pieza(("e", (58, 20, 63, 26)), ((20, 14, 30), (20, 14, 30)), 90, contorno=False)
    L.pieza(("e", (65, 20, 70, 26)), ((20, 14, 30), (20, 14, 30)), 90, contorno=False)
    L.punto(60.5, 23, 1.4, g + (255,)); L.punto(67.5, 23, 1.4, g + (255,))
    L.pieza(("r", (58, 36, 70, 42, 2)), par(sh(METAL[t], 0.7)), 110)
    L.pieza(("p", [(62, 118), (66, 118), (64, 126)]), par(sh(METAL[t], 0.8)), 100)
    return L.salida()


def grimorio(t):
    L = Lienzo(); br = BRILLO[t]; g = GEMA[t]
    aura(L, 64, 62, 34, g)
    cuero = par((96, 54, 110)) if t < 6 else par((140, 40, 50))
    L.pieza(("r", (34, 30, 94, 96, 5)), cuero, 120, brillo=0.5)
    L.pieza(("r", (38, 34, 90, 92, 3)), par(sh((96, 54, 110), 1.15)), 120, contorno=False)
    L.pieza(("r", (34, 30, 42, 96, 3)), par(sh((60, 34, 70), 0.9)), 120)
    cu = ORO if t >= 2 else par(sh(METAL[t], 0.9))
    L.pieza(("p", [(34, 30), (48, 30), (34, 44)]), cu, 110); L.pieza(("p", [(94, 96), (80, 96), (94, 82)]), cu, 110)
    L.pieza(("e", (54, 50, 74, 70)), cu, 115)
    L.pieza(("e", (58, 54, 70, 66)), par(g), 120)
    L.punto(62, 58, 1.6, (255, 255, 255, 200))
    L.linea([(46, 44), (82, 44)], cu[0] + (200,), 0.9); L.linea([(46, 82), (82, 82)], cu[0] + (200,), 0.9)
    L.pieza(("r", (88, 52, 98, 62, 2)), cu, 110)
    return L.salida()


FAMILIAS = [
    ("guerrero", "espada", "Espada", espada), ("guerrero", "hacha", "Hacha", hacha),
    ("lancero", "lanza", "Lanza", lanza), ("lancero", "alabarda", "Alabarda", alabarda),
    ("cazador", "arco", "Arco", arco), ("cazador", "ballesta", "Ballesta", ballesta),
    ("mago", "baston", "Bastón", baston), ("mago", "vara", "Vara", vara),
    ("clerigo", "maza", "Maza", maza), ("clerigo", "cetro", "Cetro", cetro),
    ("nigromante", "baculo", "Báculo", baculo), ("nigromante", "grimorio", "Grimorio", grimorio),
]

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out + "/armas", exist_ok=True)
    meta = {}
    for clase, fam, nombre, fn in FAMILIAS:
        meta[fam] = {"clase": clase, "nombre": nombre, "ancla_puño": [64, 118], "tam": 128, "escalones": []}
        for t in range(8):
            im = fn(t)
            im.save(f"{out}/armas/{fam}_{t + 1}.png")
            meta[fam]["escalones"].append({"n": t + 1, "nombre": f"{nombre} {NOMBRES_TIER[t]}"})
    json.dump(meta, open(out + "/armas/armas.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    # hojas de contacto: una por clase (2 familias x 8 escalones)
    fuente = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 15)
    for clase in ["guerrero", "lancero", "cazador", "mago", "clerigo", "nigromante"]:
        fams = [f for f in FAMILIAS if f[0] == clase]
        hoja = Image.new("RGBA", (8 * 140, 2 * 168 + 30), (34, 46, 78, 255))
        d = ImageDraw.Draw(hoja)
        d.text((8, 5), f"{clase.capitalize()}: armas por escalón (tosco, soldado, veterano, capitán, campeón, élite, legendario, corona)", font=fuente, fill=(255, 255, 255, 255))
        for r, (_, fam, nombre, _) in enumerate(fams):
            for t in range(8):
                im = Image.open(f"{out}/armas/{fam}_{t + 1}.png").resize((136, 136), Image.LANCZOS)
                hoja.alpha_composite(im, (t * 140 + 2, 30 + r * 168))
            d.text((8, 30 + r * 168 + 140), nombre, font=fuente, fill=(255, 236, 170, 255))
        hoja.save(f"{out}/armas_{clase}.png")
    print("ok")
