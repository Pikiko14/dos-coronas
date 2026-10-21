"""Genera los efectos del paquete de poderes del mago (poderes_mago_love2d.zip: tiras de cuadros de 128x128) como extras:
herramientas/efectos_extra/<id>/efecto.json + sheets/. Uso: python -X utf8 herramientas/efectos_extra/generar_mago.py <carpeta con assets/spells>
Luego: python -X utf8 herramientas/generar_efectos_fao_poderes.py"""
import json
import os
import sys

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
FUENTE = os.path.join(sys.argv[1], "assets", "spells") if len(sys.argv) > 1 else None
C = 128


def limpiar(f, hueco=3):
    """Algunos cuadros del paquete traen trozos del dibujo vecino cortados en los bordes: se queda con el grupo de columnas con más contenido."""
    a = f.getchannel("A")
    cols = [sum(1 for y in range(C) if a.getpixel((x, y)) > 24) for x in range(C)]
    grupos, ini, vacias = [], None, 0
    for x in range(C + 1):
        lleno = x < C and cols[x] > 0
        if lleno:
            if ini is None: ini = x
            vacias, fin = 0, x
        elif ini is not None:
            vacias += 1
            if vacias >= hueco or x == C:
                grupos.append((ini, fin)); ini = None; vacias = 0
    if len(grupos) <= 1: return f
    mejor = max(grupos, key=lambda g: sum(cols[g[0]:g[1] + 1]))
    r = f.copy()
    for x in range(C):
        if not (mejor[0] <= x <= mejor[1]):
            for y in range(C): r.putpixel((x, y), (0, 0, 0, 0))
    return r


def cuadros(nombre, idx, limpio=False):
    im = Image.open(os.path.join(FUENTE, nombre + ".png")).convert("RGBA")
    fr = [im.crop((i * C, 0, (i + 1) * C, C)) for i in idx]
    return [limpiar(f) for f in fr] if limpio else fr


def guardar(pid, nombre, fr, ms, origen_x=None, recorte=False):
    """Escribe sheets/<nombre>.png con los cuadros fr; recorte=True recorta en horizontal al contenido (rayos: el origen queda a la izquierda)."""
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


def escribir(pid, nombre, secs, capas, dur, golpes, nota):
    j = dict(id_dos_coronas=pid, clase="mago", nombre=nombre, poder_fao="(secuencia propia: paquete del mago)", secuencias=secs,
             composicion=dict(inferida=True, duracion_s=dur, golpes_s=golpes, capas=capas), nota=nota)
    json.dump(j, open(os.path.join(AQUI, pid, "efecto.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)


def L(s, w, t0, ms, sc, modo="once", **k):
    d = dict(s=s, w=w, t0=t0, ms=ms, sc=sc, a=1.0, modo=modo)
    d.update(k)
    return d


# misil arcano <- orbe_arcano (0-5 orbe, 6-10 estallido)
secs = dict(orbe=guardar("misil", "orbe", cuadros("orbe_arcano", range(0, 6)), 0.07), impacto=guardar("misil", "impacto", cuadros("orbe_arcano", range(6, 11)), 0.07))
escribir("misil", "Misil arcano", secs, [L("orbe", "C", 0.05, 0.07, 0.8, "proj", t1=0.42), L("impacto", "T", 0.42, 0.07, 1.1)], 0.8, [0.42], "orbe_arcano: el orbe viaja y estalla.")

# rayo de hielo <- rayo_hielo (0 chispa, 1-6 lanza, 7-11 estallido)
secs = dict(chispa=guardar("rayo_hielo", "chispa", cuadros("rayo_hielo", [0]), 0.12),
            lanza=guardar("rayo_hielo", "lanza", cuadros("rayo_hielo", range(1, 7)), 0.05, recorte=True),
            impacto=guardar("rayo_hielo", "impacto", cuadros("rayo_hielo", range(7, 12)), 0.08))
escribir("rayo_hielo", "Rayo de hielo", secs, [L("chispa", "C", 0.0, 0.12, 0.9), L("lanza", "T", 0.15, 0.05, 0.9, "estela", t1=0.5), L("impacto", "T", 0.5, 0.08, 1.2)], 0.95, [0.5], "rayo_hielo: la lanza se estira de la mano al objetivo y estalla en cristales.")

# rayo arcano <- rayo_arcano (0, 2 carga, 3-8 haz, 9-11 estallido)
secs = dict(carga=guardar("rayo_arcano", "carga", cuadros("rayo_arcano", [0, 2], True), 0.09),
            haz=guardar("rayo_arcano", "haz", cuadros("rayo_arcano", range(4, 9)), 0.05, recorte=True),
            impacto=guardar("rayo_arcano", "impacto", cuadros("rayo_arcano", range(9, 12)), 0.08))
escribir("rayo_arcano", "Rayo arcano", secs, [L("carga", "C", 0.0, 0.09, 0.9), L("haz", "T", 0.2, 0.05, 1.0, "estela", t1=0.6), L("impacto", "T", 0.5, 0.08, 1.4)], 0.9, [0.5], "rayo_arcano: carga, haz que une lanzador y objetivo y estallido.")

# lluvia de fuego <- lluvia_fuego (0-6 caída, 7-11 impacto y llamas en el suelo)
secs = dict(caida=guardar("lluvia_fuego", "caida", cuadros("lluvia_fuego", range(0, 7)), 0.07),
            suelo=guardar("lluvia_fuego", "suelo", cuadros("lluvia_fuego", range(7, 12)), 0.12))
escribir("lluvia_fuego", "Lluvia de fuego", secs, [L("caida", "GT", 0.0, 0.07, 1.6, "once", off=[0, -10]), L("suelo", "GT", 0.49, 0.12, 1.6, "once")], 1.1, [0.5, 0.8], "lluvia_fuego: caen las llamas sobre la zona y arden en el suelo.")

# teletransporte <- teletransporte (columna que sube, anillos, se disipa)
secs = dict(portal=guardar("teletransporte", "portal", cuadros("teletransporte", range(0, 12)), 0.07))
escribir("teletransporte", "Teletransporte", secs, [L("portal", "GT", 0.0, 0.07, 1.3, "once", off=[0, -10])], 0.85, [], "teletransporte: se juega en el origen y en el destino.")

# escudo arcano <- escudo_magico (cúpula que se forma y se disipa)
secs = dict(cupula=guardar("escudo", "cupula", cuadros("escudo_magico", [0, 1, 2, 3, 4, 6, 7, 8, 9]), 0.09))
escribir("escudo", "Escudo arcano", secs, [L("cupula", "C", 0.0, 0.09, 1.2, "once", off=[0, 4])], 0.9, [], "escudo_magico: la cúpula se forma alrededor del mago (sin el cuadro 5, que trae tres cúpulas sueltas).")

# torbellino arcano <- torbellino_arcano (0-10 torbellino que crece, 11 estallido)
secs = dict(giro=guardar("torbellino", "giro", cuadros("torbellino_arcano", range(7, 11), True), 0.15), fin=guardar("torbellino", "fin", cuadros("torbellino_arcano", [11]), 0.3))
escribir("torbellino", "Torbellino arcano", secs, [L("giro", "GT", 0.0, 0.15, 1.1, "loop", t1=1.3, off=[0, -6]), L("fin", "GT", 1.3, 0.3, 1.1, "once")], 1.6, [0.45, 0.8, 1.15, 1.5], "torbellino_arcano: el torbellino gira (cuadros 7-10, los completos) y se deshace; el servidor golpea 4 veces.")
print("ok")

# bola de fuego <- bola_fuego (0-4 carga, 5-8 orbe con estela, 9-11 estallido)
secs = dict(carga=guardar("fuego", "carga", cuadros("bola_fuego", range(0, 5)), 0.06),
            estela=guardar("fuego", "estela", cuadros("bola_fuego", range(5, 9), True), 0.05, recorte=True),
            impacto=guardar("fuego", "impacto", cuadros("bola_fuego", range(9, 12)), 0.08))
escribir("fuego", "Bola de fuego", secs, [L("carga", "C", 0.0, 0.06, 0.8), L("estela", "T", 0.3, 0.05, 0.9, "estela", t1=0.56), L("impacto", "T", 0.55, 0.08, 1.4)], 0.85, [0.55], "bola_fuego: carga, estela de la mano al objetivo y estallido.")

# meteoro <- meteoro (0-5 cae, 6-11 impacto y llamas)
secs = dict(caida=guardar("meteoro", "caida", cuadros("meteoro", range(0, 6)), 0.1),
            impacto=guardar("meteoro", "impacto", cuadros("meteoro", range(6, 12)), 0.12))
escribir("meteoro", "Meteoro", secs, [L("caida", "T", 0.0, 0.1, 1.2, "caida", t1=0.5, off=[-90, -300]), L("impacto", "GT", 0.5, 0.12, 1.5, "once", off=[0, -10])], 1.3, [0.5], "meteoro: cae en diagonal y estalla en llamas sobre la zona.")

# ventisca (nova) <- nova_hielo (sin el cuadro 3, que trae dos dibujos)
secs = dict(hielo=guardar("nova", "hielo", cuadros("nova_hielo", [0, 1, 2, 4, 5, 6, 7, 8, 9, 10]), 0.09))
escribir("nova", "Ventisca", secs, [L("hielo", "GT", 0.0, 0.09, 1.4, "once", off=[0, -6])], 0.95, [0.35], "nova_hielo: el anillo de hielo se abre en cristales sobre la zona.")
print("ok2")
