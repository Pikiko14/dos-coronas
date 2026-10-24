"""Efectos de los 10 poderes del nigromante (paquete necromante_10_poderes: <poder>/01.png..08.png de 640x640 + animaciones.json) como extras:
herramientas/efectos_extra/<id>/efecto.json + sheets/fx.png. Cada hoja se recorta a lo visible (la unión de sus 8 cuadros) para que pese poco en memoria.
Uso: python -X utf8 herramientas/efectos_extra/generar_necromante_10.py [carpeta del paquete]
Después: python -I -X utf8 herramientas/efectos_extra/fusionar.py toque_necro espinas maldecir alzar_esqueletos drenar escudo_huesos explosion_cadaverica nova_oscura lluvia_profana lanza_osea
(y borrar los efectos de los poderes que dejan de existir: espectro y apocalipsis_necromantico). Arte del paquete de poderes del proyecto."""
import json
import os
import sys

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
FUENTE = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\User\Downloads\cap\necromante\necromante_10_poderes"
CELDA = 640


def L(w, t0, ms, sc, modo="once", **k):
    d = dict(s="fx", w=w, t0=t0, ms=ms, sc=sc, a=1.0, modo=modo)
    d.update(k)
    return d


# id del poder, nombre, carpeta del paquete, dónde se ancla el origen (centro | suelo | base | barrido), capas, duración, golpes
EFECTOS = [
    ("toque_necro", "Calavera espectral", "01_calavera_espectral", "centro",
     [L("C", 0.0, 0.05, 0.55, "vuelo", t1=0.42, giro="espejo")], 0.62, [0.42]),
    ("espinas", "Manos de ultratumba", "02_manos_ultratumba", "suelo",
     [L("GT", 0.0, 0.1, 0.85)], 1.0, [0.35]),
    ("maldecir", "Flor de maldición", "09_flor_maldicion", "suelo",
     [L("GT", 0.0, 0.11, 0.8)], 1.1, [0.4]),
    ("alzar_esqueletos", "Portal sombrío", "10_portal_sombrio", "base",
     [L("GC", 0.0, 0.13, 0.8)], 1.15, []),
    ("drenar", "Torbellino de almas", "04_torbellino_almas", "suelo",
     [L("GT", 0.0, 0.11, 0.85)], 1.0, [0.45]),
    ("escudo_huesos", "Escudo de huesos", "05_escudo_huesos", "centro",
     [L("C", 0.0, 0.12, 0.7)], 1.0, []),
    ("explosion_cadaverica", "Erupción necrótica", "06_erupcion_necrotica", "suelo",
     [L("GT", 0.0, 0.1, 0.9)], 0.9, [0.4]),
    ("nova_oscura", "Guadaña de sombras", "03_guadana_sombras", "barrido",
     [L("GC", 0.0, 0.1, 1.0)], 0.9, [0.3]),
    ("lluvia_profana", "Cadenas condenadas", "07_cadenas_condenadas", "suelo",
     [L("GT", 0.0, 0.13, 0.9, "loop", t1=1.25)], 1.45, [0.4, 0.8, 1.2]),
    ("lanza_osea", "Lanza ósea", "08_lanza_osea", "centro",
     [L("C", 0.0, 0.05, 0.65, "vuelo", t1=0.36, giro="libre")], 0.55, [0.36]),
]
ANCLAS = {s["name"]: s["anchor"] for s in json.load(open(os.path.join(FUENTE, "animaciones.json")))["spells"]}
MS = json.load(open(os.path.join(FUENTE, "animaciones.json")))["suggested_frame_ms"]

for pid, nombre, carpeta, origen, capas, dur, golpes in EFECTOS:
    fr = [Image.open(os.path.join(FUENTE, carpeta, "%02d.png" % (i + 1))).convert("RGBA") for i in range(8)]
    cajas = [f.getchannel("A").point(lambda v: 255 if v > 12 else 0).getbbox() for f in fr]
    cajas = [c for c in cajas if c]
    x0, y0 = max(0, min(c[0] for c in cajas) - 4), max(0, min(c[1] for c in cajas) - 4)
    x1, y1 = min(CELDA, max(c[2] for c in cajas) + 4), min(CELDA, max(c[3] for c in cajas) + 4)
    w, h = x1 - x0, y1 - y0
    hoja = Image.new("RGBA", (w * 8, h), (0, 0, 0, 0))
    for i, f in enumerate(fr):
        hoja.paste(f.crop((x0, y0, x1, y1)), (i * w, 0))
    d = os.path.join(AQUI, pid, "sheets")
    os.makedirs(d, exist_ok=True)
    hoja.save(os.path.join(d, "fx.png"), optimize=True)
    ax, ay = ANCLAS[carpeta]
    if origen == "suelo":
        org = [ax - x0, ay - y0]                     # el ancla del paquete: el suelo del efecto
    elif origen == "base":
        org = [w // 2, int(h * 0.97)]                # un portal de pie sobre el suelo
    elif origen == "barrido":
        org = [w // 2, int(h * 0.55)]                # un barrido alrededor de los pies
    else:
        org = [w // 2, h // 2]
    sec = dict(sheet="sheets/fx.png", frames=8, cell=[w, h], origin=org, ms_per_frame=float(sum(MS) / len(MS)))
    j = dict(id_dos_coronas=pid, clase="nigromante", nombre=nombre, poder_fao="(secuencia propia: paquete de poderes del nigromante)", secuencias=dict(fx=sec),
             composicion=dict(inferida=False, duracion_s=dur, golpes_s=golpes, capas=capas),
             nota="necromante_10_poderes/%s (640x640, recortado a %dx%d)." % (carpeta, w, h))
    json.dump(j, open(os.path.join(AQUI, pid, "efecto.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print(pid, w, h, org)
