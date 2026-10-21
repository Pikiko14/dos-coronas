"""Genera los efectos del paquete de poderes de guerrero, cazador y clérigo (carpeta poderes/assets/<clase>/<poder>/sheet.png: 16 cuadros de 256x256) como extras:
herramientas/efectos_extra/<id>/efecto.json + sheets/. Uso: python -X utf8 herramientas/efectos_extra/generar_clases.py <carpeta poderes>
Después: fusionar con herramientas/efectos_extra/fusionar.py (o generar_efectos_fao_poderes.py si se tiene fao-clases-dc)."""
import json
import os
import sys

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
FUENTE = os.path.join(sys.argv[1], "assets") if len(sys.argv) > 1 else None
C = 256
CLASES = {"guerrero": "guerrero", "arquero": "cazador", "clerigo": "clerigo"}


def cuadros(carpeta, nombre, idx):
    im = Image.open(os.path.join(FUENTE, carpeta, nombre, "sheet.png")).convert("RGBA")
    return [im.crop((i * C, 0, (i + 1) * C, C)) for i in idx]


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


# id del juego: (clase del juego, nombre, carpeta, poder del paquete, cuadros, ¿recorte (estela)?, capas, duración, golpes, nota)
def S(pid, clase, nombre, src, idx, capas, dur, golpes, recorte=False, ms=0.055):
    carpeta = {v: k for k, v in CLASES.items()}[clase]
    sec = guardar(pid, "fx", cuadros(carpeta, src, idx), ms, recorte)
    j = dict(id_dos_coronas=pid, clase=clase, nombre=nombre, poder_fao="(secuencia propia: paquete de clases)", secuencias=dict(fx=sec),
             composicion=dict(inferida=True, duracion_s=dur, golpes_s=golpes, capas=capas),
             nota="%s/%s del paquete de poderes." % (carpeta, src))
    json.dump(j, open(os.path.join(AQUI, pid, "efecto.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)


T16 = range(16)
# ---- guerrero
S("golpe", "guerrero", "Golpe", "corte_poderoso", T16, [L("fx", "T", 0.1, 0.05, 0.8, off=[0, -8])], 0.95, [0.35])
S("tajo", "guerrero", "Tajo", "torbellino", T16, [L("fx", "GC", 0.05, 0.06, 0.8)], 1.05, [0.35])
S("grito", "guerrero", "Grito de guerra", "rugido_guerra", T16, [L("fx", "GC", 0.05, 0.065, 0.95)], 1.1, [])
S("carga", "guerrero", "Carga", "embestida", range(3, 16), [L("fx", "T", 0.0, 0.035, 0.7, "estela", t1=0.45)], 0.9, [0.45], True)
S("pantera", "guerrero", "Pantera asesina", "lanza_fuego", range(3, 16), [L("fx", "T", 0.1, 0.04, 0.9, "estela", t1=0.5)], 0.9, [0.5], True)
S("furia", "guerrero", "Furia", "golpe_multiple", T16, [L("fx", "C", 0.0, 0.06, 0.7)], 1.0, [])
S("golpe_terrestre", "guerrero", "Golpe terrestre", "golpe_terrestre", T16, [L("fx", "GT", 0.05, 0.06, 0.9)], 1.05, [0.5])
S("salto_impacto", "guerrero", "Salto de impacto", "salto_impacto", T16, [L("fx", "GT", 0.0, 0.07, 0.9)], 1.15, [0.6])
S("estocada_lineal", "guerrero", "Estocada lineal", "estocada_lineal", range(2, 16), [L("fx", "T", 0.05, 0.03, 0.8, "estela", t1=0.4)], 0.75, [0.4], True)
S("ejecucion", "guerrero", "Ejecución", "ejecucion", T16, [L("fx", "GT", 0.0, 0.06, 1.0)], 1.0, [0.5])
# ---- cazador (arquero)
S("disparo", "cazador", "Disparo", "flecha_penetrante", range(3, 14), [L("fx", "T", 0.0, 0.035, 0.7, "estela", t1=0.4)], 0.75, [0.4], True)
S("lluvia", "cazador", "Lluvia de flechas", "lluvia_flechas", T16, [L("fx", "GT", 0.05, 0.07, 0.9)], 1.2, [0.5, 0.8])
S("trampa", "cazador", "Trampa", "trampa_raices", T16, [L("fx", "GC", 0.05, 0.07, 0.8)], 1.2, [])
S("preciso", "cazador", "Tiro preciso", "disparo_triple", range(3, 14), [L("fx", "T", 0.0, 0.04, 0.9, "estela", t1=0.45)], 0.8, [0.45], True)
S("flecha_veneno", "cazador", "Flecha envenenada", "flecha_envenenada", range(3, 14), [L("fx", "T", 0.0, 0.04, 0.8, "estela", t1=0.45)], 0.8, [0.45], True)
S("paso_agil", "cazador", "Paso ágil", "flecha_viento", T16, [L("fx", "C", 0.0, 0.06, 0.8)], 1.0, [])
S("disparo_multiple", "cazador", "Disparo múltiple", "disparo_multiple", range(3, 14), [L("fx", "T", 0.0, 0.04, 1.0, "estela", t1=0.45)], 0.8, [0.45], True)
S("disparo_explosivo", "cazador", "Disparo explosivo", "disparo_explosivo", T16, [L("fx", "GT", 0.3, 0.06, 0.9)], 1.3, [0.4])
S("disparo_helado", "cazador", "Disparo helado", "disparo_helado", range(3, 14), [L("fx", "T", 0.0, 0.04, 0.9, "estela", t1=0.45)], 0.8, [0.45], True)
S("marca_cazador", "cazador", "Marca del cazador", "marca_cazador", T16, [L("fx", "GT", 0.05, 0.07, 0.85)], 1.2, [0.3])
# ---- clérigo
S("curar", "clerigo", "Curación", "cura", T16, [L("fx", "GT", 0.05, 0.06, 0.8)], 1.05, [0.3])
S("bendicion", "clerigo", "Rayo bendito", "luz_sagrada", T16, [L("fx", "GT", 0.1, 0.06, 0.8)], 1.1, [0.4])
S("castigo", "clerigo", "Castigo", "purificacion", T16, [L("fx", "GT", 0.05, 0.05, 0.75)], 0.9, [0.3])
S("consagrar", "clerigo", "Consagración", "oracion_proteccion", T16, [L("fx", "GC", 0.05, 0.07, 0.95)], 1.2, [0.5])
S("sanacion", "clerigo", "Luz sanadora", "cura_area", T16, [L("fx", "GC", 0.05, 0.07, 1.0)], 1.2, [0.5])
S("juicio", "clerigo", "Juicio divino", "juicio_sagrado", T16, [L("fx", "GT", 0.05, 0.06, 0.9)], 1.05, [0.5])
S("escudo_divino", "clerigo", "Escudo divino", "escudo_divino", T16, [L("fx", "T", 0.0, 0.065, 0.7)], 1.05, [0.2])
S("cadena_sanacion", "clerigo", "Cadena de sanación", "cadena_sanacion", T16, [L("fx", "T", 0.0, 0.06, 0.8)], 1.0, [0.3])
S("tormenta_divina", "clerigo", "Tormenta divina", "tormenta_divina", T16, [L("fx", "GT", 0.05, 0.07, 1.0)], 1.2, [0.5, 0.75, 1.0])
S("resurreccion", "clerigo", "Resurrección", "resurreccion", T16, [L("fx", "GT", 0.0, 0.07, 0.85)], 1.2, [0.5])
print("ok")
