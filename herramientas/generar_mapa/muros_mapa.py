"""Muros de las ciudades: se cortan en rodajas de una casilla (64 px de paso en el arte original) de la parte recta de un muro largo.
Cada rodaja se recorta a sus píxeles visibles, se reduce a la escala del juego y se anota dónde está su base (el borde de abajo en la
columna del centro), para que el juego la apoye sobre el eje de la casilla."""
import os, re
from PIL import Image

PASO = 64.0          # píxeles del arte original que avanza una casilla a lo largo de un eje
# estilo -> (categoría, set, variante, x donde empieza la parte recta, rodajas, multiplicador de tamaño)
ESTILOS = {
    "albor": ("muros_y_vallas", "set26_044", "1U1", 128, 2, 0.7),
    "umbra": ("muros_y_vallas", "set25_019", "1U0", 40, 4, 1.6),
}


def hornear(fuente, salida, esc, guardar):
    res = {}
    for nombre, (cat, s, var, x0, n, mult) in ESTILOS.items():
        d = os.path.join(fuente, cat, s)
        arch = [f for f in os.listdir(d) if f.endswith("-" + var + ".png")][0]
        im = Image.open(os.path.join(d, arch)).convert("RGBA")
        p = PASO / mult
        lista = []
        for i in range(n):
            xa, xb = round(x0 + i * p), round(x0 + (i + 1) * p)
            rodaja = im.crop((xa, 0, xb, im.height))
            alfa = rodaja.getchannel("A").point(lambda a: 255 if a > 8 else 0)
            caja = alfa.getbbox()
            cx = (xb - xa) // 2
            col = alfa.crop((cx, 0, cx + 1, im.height)).getbbox()
            base = col[3] if col else caja[3]           # borde de abajo en la columna del centro
            rodaja = rodaja.crop((0, caja[1], rodaja.width, caja[3]))
            k = esc * mult
            w, h = round(rodaja.width * k), max(1, round(rodaja.height * k))
            red = rodaja.resize((w, h), Image.LANCZOS)
            arch2 = f"muro_{nombre}_{i + 1}"
            guardar(red, arch2)
            lista.append({"f": arch2, "w": w, "h": h, "by": round((base - caja[1]) * k)})
        res[nombre] = lista
        print("muro", nombre, [(r["w"], r["h"], r["by"]) for r in lista])
    return res
