"""Genera juego/arte/hojas/armas.png: 12 familias de armas (una fila cada una) x 8 escalones (columnas), celdas de 32 px.
Uso:  python herramientas/generar_armas/generar_hoja.py
Las armas se dibujan por código (familias.py, con el estilo de las referencias: colores apagados, contorno marrón, acabado pixelado).
Espada, hacha, arco y ballesta se giran 45 grados (como los iconos antiguos); el resto queda en vertical, que es como las dibuja el juego en la mano."""
import os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dibujo_real
dibujo_real.OUT = (44, 28, 22, 255)
import familias as A

A.METAL[:] = [(140, 128, 114), (178, 178, 176), (208, 206, 200), (150, 170, 198), (214, 192, 126), (156, 134, 196), (204, 124, 84), (238, 234, 222)]
A.MADERA[:] = [(112, 80, 52), (130, 92, 56), (146, 104, 62), (128, 96, 76), (156, 110, 66), (92, 66, 104), (112, 62, 44), (206, 190, 152)]
A.BRILLO[:] = [None, None, None, (150, 190, 220), (230, 210, 140), (190, 160, 230), (230, 150, 100), (255, 250, 235)]
A.GEMA[:] = [(150, 150, 146), (110, 176, 116), (110, 150, 214), (110, 196, 220), (226, 186, 90), (176, 120, 220), (222, 110, 70), (246, 242, 230)]
A.ORO = A.par((214, 178, 92))
A.CUERO = A.par((120, 84, 54))
_aura = A.aura
A.aura = lambda L, x, y, r, col: _aura(L, x, y, r * 0.8, tuple(int(v * 0.8) for v in col))

GIRAR = {"espada", "hacha", "arco", "ballesta"}


def celda(im, girar):
    if girar:
        im = im.rotate(-45, resample=Image.BICUBIC, expand=True)
    bb = im.getbbox()
    im = im.crop(bb)
    k = min(30 / im.size[0], 30 / im.size[1])
    im = im.resize((max(1, round(im.size[0] * k)), max(1, round(im.size[1] * k))), Image.LANCZOS)
    a = np.array(im)
    a[..., 3] = np.where(a[..., 3] > 100, 255, 0)
    im = Image.fromarray(a, "RGBA")
    c = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    c.alpha_composite(im, ((32 - im.size[0]) // 2, (32 - im.size[1]) // 2 + (0 if girar else 1)))
    return c


raiz = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
hoja = Image.new("RGBA", (8 * 32, len(A.FAMILIAS) * 32), (0, 0, 0, 0))
for fila, (clase, fam, nombre, fn) in enumerate(A.FAMILIAS):
    for t in range(8):
        hoja.alpha_composite(celda(fn(t), fam in GIRAR), (t * 32, fila * 32))
destino = os.path.join(raiz, "juego", "arte", "hojas", "armas.png")
hoja.save(destino, optimize=True)
print("guardado", destino, hoja.size)
for i, (clase, fam, nombre, _) in enumerate(A.FAMILIAS):
    print(f"{fam}: iconos {i * 8}..{i * 8 + 7}")
