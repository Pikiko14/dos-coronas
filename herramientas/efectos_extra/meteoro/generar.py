"""Corta la imagen origen.webp (el meteoro: 10 fases en filas y 8 direcciones en columnas, con rótulos) en tiras de cuadros y escribe su efecto.json en el mismo formato que los de fao-clases-dc;
herramientas/generar_efectos_fao_poderes.py lo recoge junto a los demás poderes (poder "meteoro" del mago). Los fondos negros pasan a alfa (la imagen está pensada para mezcla aditiva)
y se recortan los rótulos. Uso: python -X utf8 herramientas/efectos_extra/meteoro/generar.py"""
import json
import os

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
IMG = Image.open(os.path.join(AQUI, "origen.webp")).convert("RGB")
A = np.asarray(IMG).astype(np.float32)
FONDO = 8.0

# bandas de la rejilla (entre los huecos oscuros): 8 direcciones (columnas) y 10 fases (filas)
COLS = [(185, 339), (339, 497), (497, 663), (663, 835), (835, 1006), (1006, 1181), (1181, 1352), (1352, 1516)]
FILAS = [(50, 150), (150, 256), (256, 357), (357, 456), (456, 547), (547, 653), (653, 743), (743, 836), (836, 924), (924, 1004)]
ANCHO, ALTO = 176, 112            # cuadro de salida, centrado en la banda de cada celda
ABAJO, ARRIBA = 1, 0              # columnas "Abajo" (cae en vertical) y "Arriba" (el suelo: la onda de choque es una elipse limpia)


def a_rgba(trozo):
    m = trozo.max(axis=2)
    alfa = np.clip((m - FONDO) / (255.0 - FONDO), 0, 1)
    rgb = np.where(alfa[..., None] > 1e-3, np.clip(trozo / np.maximum(m[..., None], 1e-3) * 255.0, 0, 255), 0)
    return np.concatenate([rgb, alfa[..., None] * 255.0], axis=2).astype(np.uint8)


def celda(fila, col):
    x0, x1 = COLS[col]
    y0, y1 = FILAS[fila]
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    sub = np.zeros((ALTO, ANCHO, 3), np.float32)
    # solo lo que cae dentro de la banda de la celda (los vecinos y los rótulos quedan fuera)
    ya, yb = max(y0, cy - ALTO // 2), min(y1, cy + ALTO // 2)
    xa, xb = max(x0, cx - ANCHO // 2), min(x1, cx + ANCHO // 2)
    sub[ya - (cy - ALTO // 2):yb - (cy - ALTO // 2), xa - (cx - ANCHO // 2):xb - (cx - ANCHO // 2)] = A[ya:yb, xa:xb]
    return a_rgba(sub)


def tira(nombre, celdas):
    t = np.concatenate([celda(f, c) for f, c in celdas], axis=1)
    os.makedirs(os.path.join(AQUI, "sheets"), exist_ok=True)
    Image.fromarray(t, "RGBA").save(os.path.join(AQUI, "sheets", nombre + ".png"), optimize=True)
    return len(celdas)


def sec(nombre, celdas, ms):
    n = tira(nombre, celdas)
    return dict(sheet="sheets/%s.png" % nombre, frames=n, cell=[ANCHO, ALTO], origin=[ANCHO // 2, ALTO // 2], ms_per_frame=ms)


secs = {
    "caida": sec("caida", [(f, ABAJO) for f in range(0, 4)], 125.0),        # fases 1-4: el meteoro baja
    "impacto": sec("impacto", [(f, ARRIBA) for f in range(4, 6)], 90.0),    # fases 5-6: impacto y explosión
    "onda": sec("onda", [(6, ARRIBA)], 450.0),                              # fase 7: onda de choque (elipse en el suelo)
    "residual": sec("residual", [(f, ARRIBA) for f in range(7, 10)], 350.0),  # fases 8-10: fuego residual, disipación y fin
}

# tiempos: el original dura 3 s (vuelo 0,8 s); aquí se comprime a ~2 s para que el impacto llegue cerca del daño del servidor (que se aplica al lanzar sobre la zona)
capas = [
    dict(s="caida", w="T", t0=0.0, t1=0.5, ms=0.125, sc=1.3, a=1.0, modo="caida", off=[0, -300]),
    dict(s="impacto", w="T", t0=0.5, ms=0.09, sc=2.0, a=1.0, modo="once", off=[0, 30]),
    dict(s="onda", w="GT", t0=0.55, ms=0.45, sc=1.0, a=1.0, modo="once"),
    dict(s="residual", w="GT", t0=0.9, ms=0.35, sc=1.0, a=1.0, modo="once"),
]
j = dict(
    id_dos_coronas="meteoro", clase="mago", nombre="Meteoro", poder_fao="(secuencia propia)", secuencias=secs,
    composicion=dict(inferida=True, duracion_s=0.9 + 3 * 0.35, golpes_s=[0.5], capas=capas),
    nota="Meteoro a partir de origen.webp: cae en vertical (fases 1-4), impacta y estalla (5-6) y deja una onda de choque y fuego residual en el suelo (7-10), escalados al área del poder.",
)
json.dump(j, open(os.path.join(AQUI, "efecto.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
print("ok:", {k: v["frames"] for k, v in secs.items()})
