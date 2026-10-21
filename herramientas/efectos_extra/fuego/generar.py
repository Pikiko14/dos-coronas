"""Corta la imagen origen.webp (la secuencia de la bola de fuego: 8 cuadros de carga, 8 de trayectoria y 8 de impacto, con sus rótulos) en tiras de cuadros y escribe su efecto.json
en el mismo formato que los de fao-clases-dc; herramientas/generar_efectos_fao_poderes.py lo recoge junto a los demás poderes (poder "fuego" del mago).
Los fondos negros pasan a alfa (la imagen está pensada para mezcla aditiva) y se recortan los rótulos. Uso: python -X utf8 herramientas/efectos_extra/fuego/generar.py"""
import json
import os

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
IMG = Image.open(os.path.join(AQUI, "origen.webp")).convert("RGB")
A = np.asarray(IMG).astype(np.float32)
FONDO = 9.0                                  # brillo del fondo casi negro de la imagen
CELDA = 250                                  # ancho de cada cuadro (8 columnas en 2000 px)

# franjas verticales con el dibujo de cada fila (sin los rótulos de debajo)
FILAS = {"carga": (30, 180), "tray": (268, 352), "impacto": (430, 593)}


def a_rgba(trozo):
    m = trozo.max(axis=2)
    alfa = np.clip((m - FONDO) / (255.0 - FONDO), 0, 1)
    rgb = np.where(alfa[..., None] > 1e-3, np.clip((trozo - FONDO * 0.0) / np.maximum(m[..., None], 1e-3) * 255.0, 0, 255), 0)
    return np.concatenate([rgb, alfa[..., None] * 255.0], axis=2).astype(np.uint8)


def tira(nombre, fila, columnas):
    y0, y1 = FILAS[fila]
    cuadros = [a_rgba(A[y0:y1, c * CELDA:(c + 1) * CELDA]) for c in columnas]
    h = y1 - y0
    t = np.concatenate(cuadros, axis=1)
    os.makedirs(os.path.join(AQUI, "sheets"), exist_ok=True)
    Image.fromarray(t, "RGBA").save(os.path.join(AQUI, "sheets", nombre + ".png"), optimize=True)
    return len(columnas), h


secs = {}
n, h = tira("carga", "carga", range(8))
secs["carga"] = dict(sheet="sheets/carga.png", frames=n, cell=[CELDA, h], origin=[CELDA // 2, h // 2], ms_per_frame=40.0)
n, h = tira("inicio", "tray", [0])
secs["inicio"] = dict(sheet="sheets/inicio.png", frames=n, cell=[CELDA, h], origin=[CELDA // 2, h // 2], ms_per_frame=100.0)
n, h = tira("tray", "tray", range(1, 8))
secs["tray"] = dict(sheet="sheets/tray.png", frames=n, cell=[CELDA, h], origin=[4, h // 2], ms_per_frame=35.0)
n, h = tira("impacto", "impacto", range(8))
secs["impacto"] = dict(sheet="sheets/impacto.png", frames=n, cell=[CELDA, h], origin=[CELDA // 2, h // 2], ms_per_frame=60.0)

# tiempos: el original dura ~2 s de carga + ~0,8 s de vuelo + ~0,8 s de impacto; aquí se comprime para que el impacto coincida con la llegada del proyectil del servidor (~0,4-0,7 s)
capas = [
    dict(s="carga", w="C", t0=0.0, ms=0.04, sc=0.7, a=1.0, modo="once"),
    dict(s="inicio", w="C", t0=0.30, ms=0.1, sc=0.7, a=1.0, modo="once"),
    dict(s="tray", w="T", t0=0.30, t1=0.56, ms=0.035, sc=0.55, a=1.0, modo="estela"),
    dict(s="impacto", w="T", t0=0.55, ms=0.06, sc=1.0, a=1.0, modo="once", off=[0, 26]),
]
j = dict(
    id_dos_coronas="fuego", clase="mago", nombre="Bola de fuego", poder_fao="(secuencia propia)", secuencias=secs,
    composicion=dict(inferida=True, duracion_s=0.55 + 8 * 0.06, golpes_s=[0.55], capas=capas),
    nota="Secuencia de la bola de fuego a partir de origen.webp (carga, trayectoria e impacto). La trayectoria se estira de la mano al objetivo (modo estela).",
)
json.dump(j, open(os.path.join(AQUI, "efecto.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
print("ok:", {k: (v["frames"], v["cell"]) for k, v in secs.items()})
