"""Iconos del HUD (poderes, item mall, monturas, mascotas, autopoción) dibujados por código con motor.py, a 64x64 con fondo transparente.
Uso:  python herramientas/generar_hud/iconos.py   ->  juego/arte/hud/<nombre>.png"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from motor import Lienzo

SALIDA = os.path.join(os.path.dirname(__file__), "..", "..", "juego", "arte", "hud")


def estrella(cx, cy, R, r, puntas=4, giro=-math.pi / 2):
    pts = []
    for i in range(puntas * 2):
        a = giro + i * math.pi / puntas
        rad = R if i % 2 == 0 else r
        pts.append((cx + math.cos(a) * rad, cy + math.sin(a) * rad))
    return pts


def poderes():
    L = Lienzo()
    # orbe arcano violeta con una estrella dorada de cuatro puntas y chispas
    L.elipsoide(32, 34, 21, 21, (96, 70, 200), brillo=0.7, oscuro=0.35)
    L.elipsoide(32, 34, 15, 15, (150, 120, 245), brillo=0.5, oscuro=0.6)
    L.poligono(estrella(32, 32, 27, 7, 4), (255, 214, 92), brillo=0.8, oscuro=0.55)
    L.poligono(estrella(32, 32, 14, 5, 4, giro=-math.pi / 4), (255, 236, 160), brillo=0.6, oscuro=0.7)
    for (x, y, r) in [(11, 14, 2.4), (53, 16, 2.0), (50, 51, 2.6), (13, 49, 1.8)]:
        L.poligono(estrella(x, y, r * 2.0, r * 0.6, 4), (255, 240, 190), brillo=0.4, oscuro=0.8)
    L.contorno()
    L.brillo(24, 22, 9, 0.7)
    return L.imagen()


def mall():
    L = Lienzo()
    # caja de regalo roja con lazo dorado y una moneda
    L.poligono([(10, 28), (54, 28), (54, 56), (10, 56)], (198, 52, 60), curvatura=0.9, brillo=0.5, oscuro=0.45)
    L.poligono([(7, 20), (57, 20), (57, 31), (7, 31)], (224, 74, 78), curvatura=0.9, brillo=0.6, oscuro=0.45)
    L.poligono([(28, 20), (36, 20), (36, 56), (28, 56)], (255, 208, 80), curvatura=0.8, brillo=0.7, oscuro=0.5)
    # lazo
    L.elipsoide(22, 13, 11, 8, (255, 208, 80), giro=-0.5, brillo=0.7, oscuro=0.5)
    L.elipsoide(42, 13, 11, 8, (255, 208, 80), giro=0.5, brillo=0.7, oscuro=0.5)
    L.elipsoide(32, 17, 5, 5, (255, 232, 130), brillo=0.7, oscuro=0.6)
    # moneda de la corona sobresaliendo
    L.elipsoide(50, 49, 11, 11, (255, 200, 60), brillo=0.9, oscuro=0.35)
    L.elipsoide(50, 49, 7.2, 7.2, (255, 226, 120), brillo=0.5, oscuro=0.6)
    L.poligono([(46, 53), (46, 46), (48.5, 49), (50, 45), (51.5, 49), (54, 46), (54, 53)], (190, 120, 20), curvatura=0.3, brillo=0.2, oscuro=0.8)
    L.contorno()
    L.brillo(14, 24, 8, 0.6)
    return L.imagen()


def monturas():
    L = Lienzo()
    # herradura de hierro con clavos y destello dorado
    pts = []
    n = 26
    for i in range(n + 1):
        a = math.radians(-215 + i * (250 / n))
        pts.append((32 + math.cos(a) * 20, 33 + math.sin(a) * 22))
    for i in range(len(pts) - 1):
        t = i / (len(pts) - 1)
        r = 6.4 - 0.9 * abs(t - 0.5)
        L.capsula(pts[i], pts[i + 1], r, r, (170, 178, 196), brillo=0.8, oscuro=0.4)
    # remates
    L.elipsoide(pts[0][0], pts[0][1] + 1, 7.2, 5.5, (186, 194, 212), brillo=0.7, oscuro=0.45)
    L.elipsoide(pts[-1][0], pts[-1][1] + 1, 7.2, 5.5, (186, 194, 212), brillo=0.7, oscuro=0.45)
    for k in (3, 7, 10, 13, 16, 19, 23):
        x, y = pts[k]
        L.elipsoide(x, y, 1.9, 1.9, (60, 66, 84), brillo=0.0, oscuro=1.0)
    # silla pequeña dorada encima
    L.poligono([(20, 14), (44, 14), (47, 22), (17, 22)], (214, 150, 52), curvatura=0.8, brillo=0.6, oscuro=0.45)
    L.elipsoide(32, 13, 7, 4.5, (240, 190, 90), brillo=0.7, oscuro=0.55)
    L.contorno()
    L.brillo(22, 24, 8, 0.6)
    return L.imagen()


def mascotas():
    L = Lienzo()
    # huella de pata (almohadilla grande y cuatro dedos) en tonos cálidos, con un corazoncito rosa
    L.elipsoide(32, 41, 17, 14, (222, 140, 72), brillo=0.8, oscuro=0.4)
    L.elipsoide(32, 44, 11, 7, (246, 176, 112), brillo=0.6, oscuro=0.6)
    for (x, y, rx, ry, giro) in [(13, 27, 6.5, 8.5, -0.5), (25, 16, 6.5, 9, -0.15), (39, 16, 6.5, 9, 0.15), (51, 27, 6.5, 8.5, 0.5)]:
        L.elipsoide(x, y, rx, ry, (232, 154, 84), giro=giro, brillo=0.8, oscuro=0.4)
        L.elipsoide(x, y + 1, rx * 0.55, ry * 0.5, (250, 190, 130), giro=giro, brillo=0.5, oscuro=0.7)
    L.elipsoide(28, 38, 3.4, 3.4, (255, 110, 150), brillo=0.7, oscuro=0.5)
    L.elipsoide(36, 38, 3.4, 3.4, (255, 110, 150), brillo=0.7, oscuro=0.5)
    L.poligono([(24.6, 40), (39.4, 40), (32, 50)], (255, 110, 150), curvatura=0.4, brillo=0.7, oscuro=0.5)
    L.contorno()
    L.brillo(22, 30, 8, 0.7)
    return L.imagen()


def autopocion():
    L = Lienzo()
    # frasco de poción roja con corcho y flechas verdes circulares
    L.elipsoide(32, 40, 17, 17, (214, 48, 70), brillo=0.9, oscuro=0.32)
    L.capsula((32, 26), (32, 17), 7, 6, (222, 232, 245), brillo=0.7, oscuro=0.5)
    L.elipsoide(32, 14, 8, 4.5, (176, 120, 70), brillo=0.4, oscuro=0.5)
    L.mancha(32, 43, 12, 8, (255, 120, 140), alfa=0.8, suave=0.9)
    # arcos verdes (auto) alrededor, con punta de flecha
    def arco(a0, a1, color=(70, 220, 120)):
        pts = []
        n = 14
        for i in range(n + 1):
            a = math.radians(a0 + (a1 - a0) * i / n)
            pts.append((32 + math.cos(a) * 27, 36 + math.sin(a) * 25))
        for i in range(len(pts) - 1):
            L.capsula(pts[i], pts[i + 1], 3.4, 3.4, color, brillo=0.9, oscuro=0.45)
        # punta de flecha
        (x1, y1), (x0, y0) = pts[-1], pts[-3]
        ang = math.atan2(y1 - y0, x1 - x0)
        s = 8
        L.poligono([(x1 + math.cos(ang) * s, y1 + math.sin(ang) * s),
                    (x1 + math.cos(ang + 2.4) * s, y1 + math.sin(ang + 2.4) * s),
                    (x1 + math.cos(ang - 2.4) * s, y1 + math.sin(ang - 2.4) * s)], color, curvatura=0.5, brillo=0.8, oscuro=0.5)
    arco(150, 280)
    arco(-30, 100)
    L.contorno()
    L.brillo(25, 33, 7, 0.8)
    return L.imagen()


if __name__ == "__main__":
    os.makedirs(SALIDA, exist_ok=True)
    for nombre, f in [("poderes", poderes), ("mall", mall), ("monturas", monturas), ("mascotas", mascotas), ("autopocion", autopocion)]:
        f().save(os.path.join(SALIDA, nombre + ".png"), optimize=True)
        print("icono", nombre)
