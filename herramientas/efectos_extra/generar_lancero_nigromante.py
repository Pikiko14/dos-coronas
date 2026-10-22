"""Genera los efectos del paquete de poderes de lancero y nigromante (carpeta <poderes>/assets/assets/<clase>/<poder>/01.png..16.png, 256x256) como extras:
herramientas/efectos_extra/<id>/efecto.json + sheets/. Uso: python -X utf8 herramientas/efectos_extra/generar_lancero_nigromante.py <carpeta que contiene lancero y nigromante>
Después: python -I -X utf8 herramientas/efectos_extra/fusionar.py <ids>  (sin necesitar fao-clases-dc)."""
import json
import os
import sys

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
FUENTE = sys.argv[1] if len(sys.argv) > 1 else None
C = 256


def cuadros(carpeta, nombre, idx):
    return [Image.open(os.path.join(FUENTE, carpeta, nombre, "%02d.png" % (i + 1))).convert("RGBA") for i in idx]


def guardar(pid, nombre, fr, ms, recorte=False):
    d = os.path.join(AQUI, pid, "sheets")
    os.makedirs(d, exist_ok=True)
    x0, x1 = 0, C
    if recorte:
        bx = [f.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox() for f in fr]
        bx = [b for b in bx if b]
        x0, x1 = min(b[0] for b in bx), max(b[2] for b in bx)
    w = x1 - x0
    hoja = Image.new("RGBA", (w * len(fr), C), (0, 0, 0, 0))
    for i, f in enumerate(fr):
        hoja.paste(f.crop((x0, 0, x1, C)), (i * w, 0))
    hoja.save(os.path.join(d, nombre + ".png"), optimize=True)
    return dict(sheet="sheets/%s.png" % nombre, frames=len(fr), cell=[w, C], origin=[0 if recorte else w // 2, C // 2], ms_per_frame=ms * 1000)


def L(s, w, t0, ms, sc, modo="once", **k):
    d = dict(s=s, w=w, t0=t0, ms=ms, sc=sc, a=1.0, modo=modo)
    d.update(k)
    return d


def S(pid, clase, nombre, carpeta, src, idx, capas, dur, golpes, recorte=False, ms=0.055):
    sec = guardar(pid, "fx", cuadros(carpeta, src, idx), ms, recorte)
    j = dict(id_dos_coronas=pid, clase=clase, nombre=nombre, poder_fao="(secuencia propia: paquete de clases)", secuencias=dict(fx=sec),
             composicion=dict(inferida=True, duracion_s=dur, golpes_s=golpes, capas=capas),
             nota="%s/%s del paquete de poderes." % (carpeta, src))
    json.dump(j, open(os.path.join(AQUI, pid, "efecto.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)


T16 = range(16)
# ---- lancero
S("estocada", "lancero", "Estocada", "lancero", "avance_implacable", range(2, 15), [L("fx", "T", 0.0, 0.025, 0.8, "estela", t1=0.3)], 0.55, [0.2], True)
S("barrido", "lancero", "Barrido", "lancero", "lanza_giratoria", T16, [L("fx", "GC", 0.05, 0.055, 0.85)], 0.95, [0.3])
S("muro_lanzas", "lancero", "Muro de lanzas", "lancero", "guardia_imperial", T16, [L("fx", "GC", 0.0, 0.07, 0.85)], 1.15, [])
S("embestida", "lancero", "Embestida", "lancero", "embestida_perforante", range(2, 15), [L("fx", "T", 0.0, 0.03, 0.9, "estela", t1=0.4)], 0.8, [0.4], True)
S("jabalina", "lancero", "Jabalina", "lancero", "estocada_celestial", T16, [L("fx", "GT", 0.1, 0.06, 0.8)], 1.1, [0.5])
S("tormenta_lanzas", "lancero", "Tormenta de lanzas", "lancero", "lluvia_de_lanzas", T16, [L("fx", "GT", 0.05, 0.07, 0.95)], 1.2, [0.5])
S("fisura_del_lancero", "lancero", "Fisura del lancero", "lancero", "fisura_del_lancero", T16, [L("fx", "GT", 0.0, 0.06, 0.95)], 1.0, [0.4])
S("pulso_terrestre", "lancero", "Pulso terrestre", "lancero", "pulso_terrestre", T16, [L("fx", "GC", 0.0, 0.06, 0.95)], 1.0, [0.35])
S("torbellino_lanzas", "lancero", "Torbellino de lanzas", "lancero", "torbellino_lanzas", T16, [L("fx", "GC", 0.0, 0.1, 0.85)], 1.7, [0.4, 0.8, 1.2, 1.6])
S("juicio_final", "lancero", "Juicio final", "lancero", "juicio_final", T16, [L("fx", "GT", 0.05, 0.075, 1.0)], 1.3, [0.5, 0.8, 1.1])
# ---- nigromante
S("toque_necro", "nigromante", "Toque necrótico", "nigromante", "drenaje_vital", T16, [L("fx", "T", 0.1, 0.05, 0.6)], 0.95, [0.35])
S("espinas", "nigromante", "Espinas de hueso", "nigromante", "campo_de_huesos", T16, [L("fx", "GT", 0.05, 0.06, 0.9)], 1.05, [0.35])
S("maldecir", "nigromante", "Maldición", "nigromante", "manos_del_abismo", T16, [L("fx", "GT", 0.05, 0.065, 0.9)], 1.1, [0.4])
S("alzar_esqueletos", "nigromante", "Alzar esqueletos", "nigromante", "invocacion_esqueletos", T16, [L("fx", "GC", 0.05, 0.07, 0.95)], 1.2, [])
S("drenar", "nigromante", "Drenar vida", "nigromante", "sifon_de_almas", T16, [L("fx", "T", 0.05, 0.07, 0.7)], 1.2, [0.5])
S("espectro", "nigromante", "Alma en pena", "nigromante", "tormenta_de_almas", T16, [L("fx", "GC", 0.05, 0.07, 0.8)], 1.2, [])
S("apocalipsis_necromantico", "nigromante", "Apocalipsis necromántico", "nigromante", "apocalipsis_necromantico", T16, [L("fx", "GT", 0.0, 0.075, 1.1)], 1.3, [0.5, 0.9])
S("explosion_cadaverica", "nigromante", "Explosión cadavérica", "nigromante", "explosion_cadaverica", T16, [L("fx", "GT", 0.0, 0.06, 0.95)], 1.0, [0.4])
S("lluvia_profana", "nigromante", "Lluvia profana", "nigromante", "lluvia_profana", T16, [L("fx", "GT", 0.05, 0.07, 1.0)], 1.25, [0.5, 0.75, 1.0, 1.25])
S("nova_oscura", "nigromante", "Nova oscura", "nigromante", "nova_oscura", T16, [L("fx", "GC", 0.0, 0.06, 0.95)], 1.0, [0.4])
print("ok")
