"""Hornea los efectos de poder de las demás clases con sus secuencias originales de Free Angels Online (carpeta fao-clases-dc de Downloads: una carpeta por poder con sheets/ y efecto.json).
Escribe:
  juego/arte/fao_efectos/<id>__<secuencia>.png                  las tiras de cada poder (sin pérdida)
  juego/src/presentacion/render/efectos_fao_poderes_datos.lua   por secuencia: cuadros, celda, ancla (origin), ms por cuadro y tamaño visible (px nativos de FAO)
  compartido/datos/efectos_fao_poderes.lua                      por poder: duración, instantes de golpe y capas con su timeline (el servidor solo usa la duración)
Los poderes golpe, tajo y pantera (y la nova del mago) tienen su propia versión ya integrada y no se tocan. Arte de un juego ajeno (FAO): prototipo.
Uso: python -X utf8 herramientas/generar_efectos_fao_poderes.py"""
import json
import os
import shutil

import numpy as np
from PIL import Image

FUENTE = os.environ.get("FAO_CLASES", r"C:\Users\User\Downloads\fao-clases-dc")
RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OMITIR = {"golpe", "tajo", "pantera"}


def num(v):
    return ("%.4f" % v).rstrip("0").rstrip(".") if isinstance(v, float) else str(v)


def lua_valor(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return num(v)
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua_valor(x) for x in v) + " }"
    raise TypeError(v)


def visible(ruta, n, w, h):
    """(ancho, alto) máximos de lo visible (alfa > 25 de 255) entre los cuadros de la tira."""
    a = np.asarray(Image.open(ruta).convert("RGBA"))[..., 3] > 25
    vw = vh = 0
    for k in range(n):
        sub = a[:, k * w:(k + 1) * w]
        ys, xs = np.where(sub)
        if len(xs):
            vw = max(vw, int(xs.max() - xs.min() + 1))
            vh = max(vh, int(ys.max() - ys.min() + 1))
    return vw, vh


def main():
    poderes = json.load(open(os.path.join(FUENTE, "poderes.json"), encoding="utf-8"))
    arte = os.path.join(RAIZ, "juego", "arte", "fao_efectos")
    secs, datos = {}, {}
    for p in poderes:
        pid = p["id"]
        if pid in OMITIR:
            continue
        carpeta = os.path.join(FUENTE, p["carpeta"].replace("/", os.sep))
        j = json.load(open(os.path.join(carpeta, "efecto.json"), encoding="utf-8"))
        if "composicion" not in j:
            continue
        for nombre, s in j["secuencias"].items():
            clave = "%s__%s" % (pid, nombre)
            destino = os.path.join(arte, clave + ".png")
            shutil.copy(os.path.join(carpeta, s["sheet"]), destino)
            vw, vh = visible(destino, s["frames"], s["cell"][0], s["cell"][1])
            secs[clave] = dict(n=s["frames"], w=s["cell"][0], h=s["cell"][1], ox=s["origin"][0], oy=s["origin"][1], ms=round(s["ms_per_frame"] / 1000, 4), vw=vw, vh=vh,
                               mezcla="alpha" if any(f in ("SP_ATTRIB_ALPHA", "SP_ATTRIB_DARKLIGHT") for f in s.get("mezcla_fao", [])) else "add")
        c = j["composicion"]
        capas = []
        for l in c["capas"]:
            sec = secs["%s__%s" % (pid, l["s"])]
            capa = dict(s="%s__%s" % (pid, l["s"]), w=l["w"], t0=round(l["t0"], 4), ms=round(l["ms"], 4) if "ms" in l else sec["ms"], sc=l.get("sc", 1.0), a=l.get("a", 1.0))
            modo = l.get("modo") or ("proj" if l["w"] == "proj" else "once")
            capa["modo"] = modo
            if "t1" in l:
                capa["t1"] = round(l["t1"], 4)
            if "off" in l:
                capa["off"] = l["off"]
            if l.get("flip"):
                capa["flip"] = True
            if "dur" in l:
                capa["dur"] = round(l["dur"], 4)
            if "th" in l:
                capa["th"] = l["th"]
            capa["dir"] = modo in ("proj", "step") and sec["n"] in (5, 9)
            capa["mezcla"] = sec["mezcla"]
            capas.append(capa)
        datos[pid] = dict(clase=p["clase"], dur=round(c["duracion_s"], 3), golpes=[round(x, 3) for x in c.get("golpes_s", [])], capas=capas)
    # datos de las secuencias (cliente)
    out = ["-- GENERADO por herramientas/generar_efectos_fao_poderes.py: secuencias de los efectos de FAO de los poderes (cuadros, celda, ancla en px nativos, ms por cuadro, tamaño visible).",
           "-- Arte de un juego ajeno (FAO): prototipo.", "return {"]
    for k in sorted(secs):
        s = secs[k]
        out.append('  ["%s"] = { n = %d, w = %d, h = %d, ox = %d, oy = %d, ms = %s, vw = %d, vh = %d, mezcla = "%s" },' % (k, s["n"], s["w"], s["h"], s["ox"], s["oy"], num(s["ms"]), s["vw"], s["vh"], s["mezcla"]))
    out.append("}")
    open(os.path.join(RAIZ, "juego", "src", "presentacion", "render", "efectos_fao_poderes_datos.lua"), "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    # capas de cada poder (compartido: el servidor usa la duración)
    out = ["-- GENERADO por herramientas/generar_efectos_fao_poderes.py desde fao-clases-dc: por poder, duración (s), instantes de golpe y capas con su timeline.",
           "-- capa: s secuencia, w (C/T pecho del lanzador/objetivo, GC/GT suelo, proj viaja de la mano al pecho del objetivo), t0/t1 (s), ms por cuadro (s), sc escala, a opacidad, off desplazamiento (px de FAO),",
           "--       flip, modo (once, loop, hold, step, proj), dur (step), th (ángulo de referencia del step), dir (elige el cuadro por dirección), mezcla (add | alpha).",
           "-- Arte y datos de un juego ajeno (FAO): prototipo.", "return {"]
    for pid in sorted(datos):
        d = datos[pid]
        out.append('  %s = { clase = "%s", dur = %s, golpes = %s, capas = {' % (pid, d["clase"], num(d["dur"]), lua_valor(d["golpes"])))
        for c in d["capas"]:
            partes = ", ".join("%s = %s" % (k, lua_valor(v)) for k, v in c.items())
            out.append("    { %s }," % partes)
        out.append("  } },")
    out.append("}")
    open(os.path.join(RAIZ, "compartido", "datos", "efectos_fao_poderes.lua"), "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    print("ok:", len(datos), "poderes,", len(secs), "secuencias")


main()
