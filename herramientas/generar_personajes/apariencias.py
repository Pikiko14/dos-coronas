"""Apariencias («PD», 紙娃娃, los objetos de apariencia de FAO): 10 sets completos que cambian cómo se ve el personaje sin tocar sus estadísticas.

Cada set trae todas las ranuras: cabeza, pecho, manos, pies, espalda (alas o capa) y un arma para cada familia de arma del juego. Las piezas son
apariencias reales de FAO (setting/*.xml, categoría 紙娃娃); un set es un bloque de números consecutivos (cabeza n-1, pecho n, manos n+1, pies n+2).
Los sets sin versión propia para cada género usan la apariencia equivalente del otro (mismo tema, "h" = hombre, "m" = mujer).

Uso:  python -X utf8 herramientas/generar_personajes/apariencias.py [--previa]     (FAO_PAK = carpeta con los .pak; por defecto Descargas)
Escribe:
  juego/arte/fao/<capa>/<Anim>_<f|m>.png                     las capas nuevas (mismo formato que equipo_altos.py)
  juego/src/presentacion/render/fao_datos_apariencias.lua    capas y sets (fao.lua los suma a fao_datos.lua)
Con --previa solo dibuja una hoja de comprobación (juego/capturas/apariencias_previa.png), sin hornear. Arte de un juego ajeno (FAO): prototipo."""
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
sys.path.insert(0, os.path.join(AQUI, "..", "generar_mobs"))
import equipo_altos as A
import pak_fao

RAIZ = A.RAIZ
LUA = os.path.join(RAIZ, "juego", "src", "presentacion", "render", "fao_datos_apariencias.lua")

# familias de arma del juego (iguales a las de equipo_intermedio.py): qué arma de PD se pone a cada una
FAMILIAS = ("espada", "hacha", "lanza", "arco", "baston", "maza", "baculo")

# id, nombre, precio en Monedas Corona, número del pecho para cada género (cabeza n-1, manos n+1, pies n+2), espalda y armas
SETS = [
    dict(id="pd_ciudad_demoniaca", nombre="Ciudad Demoníaca", precio=900, h=3473, m=3473, espalda=5344,
         armas=dict(espada=3476, hacha=3477, lanza=3478, arco=3479, baston=3480, maza=3480, baculo=3480)),
    dict(id="pd_espacio_tiempo", nombre="Espacio-Tiempo", precio=900, h=3688, m=3688, espalda=4556,
         armas=dict(espada=3691, hacha=3692, lanza=4617, arco=5985, baston=4557, maza=4557, baculo=4557)),
    dict(id="pd_noche_brujas", nombre="Noche de Brujas", precio=700, h=3277, m=3281, espalda=5344,
         armas=dict(espada=2268, hacha=5836, lanza=3478, arco=3479, baston=4404, maza=4404, baculo=4404)),
    dict(id="pd_armadura_dorada", nombre="Armadura Dorada", precio=1000, h=4560, m=4560, espalda=4556,
         armas=dict(espada=4555, hacha=3477, lanza=4617, arco=3479, baston=4557, maza=4557, baculo=4557)),
    dict(id="pd_sacerdote_sagrado", nombre="Sacerdote Sagrado", precio=800, h=5636, m=5640, espalda=3010,
         armas=dict(espada=3271, hacha=5836, lanza=3828, arco=3829, baston=4834, maza=4834, baculo=4834)),
    dict(id="pd_esperanza", nombre="Esperanza", precio=800, h=5658, m=5662, espalda=4558,
         armas=dict(espada=4407, hacha=3692, lanza=4840, arco=5666, baston=5667, maza=5667, baculo=5667)),
    dict(id="pd_rey_guerra", nombre="Rey de la Guerra", precio=1100, h=6012, m=6016, espalda=4556,
         armas=dict(espada=5363, hacha=5836, lanza=4617, arco=5666, baston=4834, maza=4834, baculo=4834)),
    dict(id="pd_lobo_nevado", nombre="Lobo Nevado", precio=700, h=1753, m=1757, espalda=4558,
         armas=dict(espada=2268, hacha=3477, lanza=4840, arco=5985, baston=4105, maza=4105, baculo=4105)),
    dict(id="pd_imperial", nombre="Imperial", precio=800, h=1949, m=1953, espalda=4558,
         armas=dict(espada=4407, hacha=3692, lanza=3478, arco=3479, baston=4557, maza=4557, baculo=4557)),
    dict(id="pd_pasion", nombre="Pasión", precio=700, h=2684, m=2688, espalda=5344,
         armas=dict(espada=3274, hacha=5836, lanza=3828, arco=3829, baston=3747, maza=3747, baculo=3747)),
]
HUECOS = (("cabeza", -1), ("pecho", 0), ("piernas", 1), ("pies", 2))      # (hueco del juego, desplazamiento): piernas = las manos (guantes)


def capa(n, letra, suf=""):
    """(carpeta, código) de la apariencia n; con suf = 'l' prueba la versión de arco y si no existe, la normal."""
    if suf:
        try:
            return A.capa_de(n, letra + suf)
        except SystemExit:
            pass
    return A.capa_de(n, letra)


def piezas_de(s, gen):
    """{hueco: (carpeta, código)} del set s para el género gen ('h' o 'm'), sin las piezas que FAO no tiene en este cliente."""
    letra = "b" if gen == "h" else "g"
    n = s[gen]
    res = {}
    for hueco, d in HUECOS:
        try:
            res[hueco] = A.capa_de(n + d, letra)
        except SystemExit:
            pass
    try:
        res["espalda"] = A.capa_de(s["espalda"], letra)
    except SystemExit:
        pass
    arma = {}
    for fam in FAMILIAS:
        try:
            arma[fam] = capa(s["armas"][fam], letra, "l" if fam == "arco" else "")
        except SystemExit:
            pass
    res["arma"] = arma
    return res


def previa():
    from PIL import Image, ImageDraw
    codp = {}
    for k in pak_fao.indice():
        m = re.match(r"shape/chr/(p001[bg])/(\d+)_wait\.spr$", k)
        if m:
            codp[m.group(1)] = min(codp.get(m.group(1), 10 ** 9), int(m.group(2)))

    def frente(cap, cod):
        clave = "shape/chr/%s/%d_wait.spr" % (cap, cod)
        if clave not in pak_fao.indice():
            return None
        for im, o in reversed(pak_fao.cuadros_spr(clave)):
            if im is not None:
                return im, o
        return None

    W, H = 170, 200
    hoja = Image.new("RGB", (len(SETS) * W, 2 * (H + 16)), (30, 30, 34))
    dr = ImageDraw.Draw(hoja)
    for i, s in enumerate(SETS):
        for j, gen in enumerate(("h", "m")):
            p = piezas_de(s, gen)
            capas = [("p001" + ("b" if gen == "h" else "g"), codp["p001" + ("b" if gen == "h" else "g")])]
            orden = ["espalda", "pies", "pecho", "piernas", "cabeza"]
            lista = [p[k] for k in orden if k in p]
            if p["arma"].get("espada"):
                lista.append(p["arma"]["espada"])
            cv = Image.new("RGBA", (W, H), (60, 70, 90, 255))
            for cap, cod in capas + lista:
                r = frente(cap, cod)
                if r:
                    cv.alpha_composite(r[0].convert("RGBA"), (int(W / 2 - r[1][0]), int(H - 55 - r[1][1])))
            hoja.paste(cv.convert("RGB"), (i * W, j * (H + 16)))
            falta = [k for k, _ in HUECOS if k not in p]
            dr.text((i * W + 2, j * (H + 16) + H), "%s %s %s" % (s["nombre"][:16], gen, ("sin " + ",".join(falta)) if falta else ""), fill=(255, 255, 0))
    ruta = os.path.join(RAIZ, "juego", "capturas", "apariencias_previa.png")
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    hoja.save(ruta)
    print("previa en", ruta)


def lua(v, nivel=0):
    pad = "  " * (nivel + 1)
    if isinstance(v, dict):
        partes = []
        for k, x in v.items():
            nombre = str(k) if re.match(r"^[A-Za-z_]\w*$", str(k)) else '["%s"]' % k
            partes.append("%s%s = %s," % (pad, nombre, lua(x, nivel + 1)))
        return "{\n" + "\n".join(partes) + "\n" + "  " * nivel + "}"
    if isinstance(v, str):
        return '"%s"' % v
    return str(v)


def main():
    if "--previa" in sys.argv:
        previa()
        return
    meta, total, sets = {}, 0, {}
    for s in SETS:
        sets[s["id"]] = {"nombre": s["nombre"], "precio": s["precio"], "h": {}, "m": {}}
        for gen in ("h", "m"):
            fila = {"arma": {}}
            p = piezas_de(s, gen)
            for hueco, par in p.items():
                if hueco == "arma":
                    for fam, (cap, cod) in par.items():
                        fila["arma"][fam] = cap
                        if cap not in meta:
                            total += A.hornear_capa(cap, cod, meta)
                else:
                    cap, cod = par
                    fila[hueco] = cap
                    if cap not in meta:
                        total += A.hornear_capa(cap, cod, meta)
            sets[s["id"]][gen] = fila
        print("set", s["id"], "listo")
    print("tamaño total", total // 1024, "KB")
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERADO por herramientas/generar_personajes/apariencias.py: capas y sets de apariencia (PD de FAO). No editar a mano.\n")
        f.write("return " + lua({"capas": meta, "sets": sets}) + "\n")
    print("escrito", LUA)


if __name__ == "__main__":
    main()
