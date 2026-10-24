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
         armas=dict(espada=2526, hacha=3469, lanza=4977, arco=4338, baston=3466, maza=3468, baculo=4965)),
    dict(id="pd_espacio_tiempo", nombre="Espacio-Tiempo", precio=900, h=3688, m=3688, espalda=4556,
         armas=dict(espada=4615, hacha=2526, lanza=4959, arco=2021, baston=4105, maza=3470, baculo=3466)),
    dict(id="pd_imperial", nombre="Imperial", precio=800, h=1949, m=1953, espalda=4558,
         armas=dict(espada=3267, hacha=2526, lanza=4965, arco=2021, baston=4105, maza=3469, baculo=3466)),
    dict(id="pd_armadura_dorada", nombre="Armadura Dorada", precio=1000, h=4560, m=4560, espalda=4556,
         armas=dict(espada=5084, hacha=3469, lanza=4977, arco=4338, baston=4965, maza=4105, baculo=3466)),
    dict(id="pd_sacerdote_sagrado", nombre="Sacerdote Sagrado", precio=800, h=5636, m=5640, espalda=3010,
         armas=dict(espada=3267, hacha=2526, lanza=4959, arco=2021, baston=4105, maza=3466, baculo=4965)),
    dict(id="pd_esperanza", nombre="Esperanza", precio=800, h=5658, m=5662, espalda=4558,
         armas=dict(espada=4615, hacha=5084, lanza=4977, arco=4338, baston=3466, maza=4105, baculo=4965)),
    dict(id="pd_gala_esmeralda", nombre="Gala Esmeralda", precio=700, h=2676, m=2680, espalda=4556,
         armas=dict(espada=5084, hacha=2526, lanza=4977, arco=4338, baston=2771, maza=3468, baculo=3466)),
    dict(id="pd_lobo_nevado", nombre="Lobo Nevado", precio=700, h=1753, m=1757, espalda=4558,
         armas=dict(espada=2268, hacha=4615, lanza=4977, arco=2021, baston=4105, maza=3468, baculo=4965)),
    dict(id="pd_lobo_gris", nombre="Lobo Gris", precio=700, h=1745, m=1749, espalda=4556,
         armas=dict(espada=4615, hacha=3469, lanza=4959, arco=4338, baston=3466, maza=3470, baculo=2771)),
    dict(id="pd_pasion", nombre="Pasión", precio=700, h=2684, m=2688, espalda=5344,
         armas=dict(espada=5084, hacha=4615, lanza=4959, arco=4338, baston=2771, maza=3466, baculo=4965)),
]
# 20 sets más (mismos criterios: ninguna pieza es del equipo de los escalones ni de los 10 primeros sets; hombre y mujer llevan la misma apariencia). Las armas y las
# espaldas se reparten por turnos entre las piezas de apariencia que se ven bien.
_EXTRA = [  # (id, nombre, precio, apariencia del pecho)
    ("pd_marfil", "Armadura de Marfil", 800, 1551), ("pd_nieve", "Túnica de Nieve", 700, 1554), ("pd_vikingo_acero", "Vikingo de Acero", 900, 1557),
    ("pd_cobrizo", "Guerrero Cobrizo", 700, 1725), ("pd_sombras", "Cazador de Sombras", 800, 1728), ("pd_escarlata", "Guardia Escarlata", 800, 1732),
    ("pd_barbaro_norte", "Bárbaro del Norte", 900, 1739), ("pd_zafiro", "Mago Zafiro", 700, 1960), ("pd_alado_plata", "Alado Plateado", 1000, 2435),
    ("pd_escarcha", "Caballero de Escarcha", 900, 2439), ("pd_dorado", "Guerrero Dorado", 1100, 5360), ("pd_hechicero_azul", "Hechicero Azul", 700, 2695),
    ("pd_lunar", "Sacerdote Lunar", 800, 3486), ("pd_brasa", "Brasa Ardiente", 800, 3490), ("pd_rey_vikingo", "Rey Vikingo", 1000, 3941),
    ("pd_violeta", "Yelmo Violeta", 800, 4185), ("pd_cuernos_oro", "Cuernos de Oro", 900, 4399), ("pd_sombrio", "Cazacuernos Sombrío", 900, 4431),
    ("pd_cristal_plata", "Cristal de Plata", 1000, 4434), ("pd_lobo_sombrio", "Lobo Sombrío", 800, 4568),
]
_ARMAS_POR_FAMILIA = dict(
    espada=(2526, 5084, 4615, 3267, 2268, 3468, 4959), hacha=(3469, 2526, 4615, 3468), lanza=(4977, 4965, 4959, 3470), arco=(4338, 2021, 3469),
    baston=(4105, 3466, 2771, 4965, 3468), maza=(3468, 4105, 3470, 3466), baculo=(3466, 4965, 2771, 4105))
_ESPALDAS = (3010, 5344, 5643, 4556, 4558, 2812)
for _i, (_id, _nombre, _precio, _n) in enumerate(_EXTRA):
    SETS.append(dict(id=_id, nombre=_nombre, precio=_precio, h=_n, m=_n, espalda=_ESPALDAS[_i % len(_ESPALDAS)],
                     armas={fam: lista[(_i + k) % len(lista)] for k, (fam, lista) in enumerate(_ARMAS_POR_FAMILIA.items())}))
HUECOS = (("cabeza", -1), ("pecho", 0), ("piernas", 1), ("pies", 2))      # (hueco del juego, desplazamiento): piernas = las manos (guantes)


def capa(n, letra, suf=""):
    """(carpeta, código) de la apariencia n; con suf = 'l' prueba antes la versión de arco. Si la pieza solo existe en una de las dos versiones (normal o 'l'), se usa esa."""
    for sufijo in ((suf, "", "l") if suf else ("", "l")):
        try:
            return A.capa_de(n, letra + sufijo)
        except SystemExit:
            pass
    raise SystemExit("no existe la capa de la apariencia %d (%s)" % (n, letra))


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
            arma = p["arma"].get("espada" if gen == "h" else "baston")
            if arma:
                lista.append(arma)
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


RANURAS_ICONO = ("cabeza", "pecho", "piernas", "pies", "espalda", "arma")      # orden de los seis iconos de cada set en la lámina


def hacer_iconos():
    """Lámina de iconos de las piezas (32 px, 8 columnas): seis por set, en el orden de RANURAS_ICONO; cada icono es el dibujo de la pieza (de frente, versión masculina)."""
    from PIL import Image
    n = len(SETS) * len(RANURAS_ICONO)
    hoja = Image.new("RGBA", (256, ((n + 7) // 8) * 32), (0, 0, 0, 0))
    for i, s in enumerate(SETS):
        p = piezas_de(s, "h")
        for k, ranura in enumerate(RANURAS_ICONO):
            par = p["arma"].get("espada") if ranura == "arma" else p.get(ranura)
            if not par:
                continue
            cap, cod = par
            clave = "shape/chr/%s/%d_wait.spr" % (cap, cod)
            im = None
            for fr, _o in reversed(pak_fao.cuadros_spr(clave)):
                if fr is not None:
                    im = fr.convert("RGBA")
                    break
            if im is None:
                continue
            caja = im.getchannel("A").point(lambda a: 255 if a > 20 else 0).getbbox()
            if not caja:
                continue
            im = im.crop(caja)
            esc = 28.0 / max(im.size)
            im = im.resize((max(1, round(im.width * esc)), max(1, round(im.height * esc))), Image.LANCZOS)
            idx = i * len(RANURAS_ICONO) + k
            hoja.alpha_composite(im, ((idx % 8) * 32 + (32 - im.width) // 2, (idx // 8) * 32 + (32 - im.height) // 2))
    ruta = os.path.join(RAIZ, "juego", "arte", "hojas", "apariencias_iconos.png")
    hoja.save(ruta, optimize=True)
    print("iconos:", n, "->", ruta)


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
    if "--iconos" in sys.argv:
        hacer_iconos()
        return
    previas = set()
    if os.path.exists(LUA):
        previas = set(re.findall(r'^    (i\d+\w*) = \{', open(LUA, encoding="utf-8").read(), re.M))
    meta, total, sets = {}, 0, {}
    for s in SETS:
        sets[s["id"]] = {"nombre": s["nombre"], "precio": s["precio"], "icono": SETS.index(s) * len(RANURAS_ICONO), "h": {}, "m": {}}
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
    # capas de una versión anterior de los sets que ya no usa nadie (ni el equipo de los escalones): se borran
    ajenos = ""
    for n in ("fao_datos.lua", "fao_datos_altos.lua", "fao_datos_medios.lua"):
        ajenos += open(os.path.join(os.path.dirname(LUA), n), encoding="utf-8").read()
    import shutil
    for cap in sorted(previas - set(meta)):
        if '"%s"' % cap not in ajenos and ("    %s = {" % cap) not in ajenos:
            shutil.rmtree(os.path.join(A.SALIDA, cap), ignore_errors=True)
            print("capa antigua borrada", cap)
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERADO por herramientas/generar_personajes/apariencias.py: capas y sets de apariencia (PD de FAO). No editar a mano.\n")
        f.write("return " + lua({"capas": meta, "sets": sets}) + "\n")
    print("escrito", LUA)
    hacer_iconos()


if __name__ == "__main__":
    main()
