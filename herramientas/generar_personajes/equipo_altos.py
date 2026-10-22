"""Equipo FAO nuevo para los escalones 9 (nivel 40) y 10 (nivel 50): conjuntos y armas de FAO que no se usan en los escalones 1 a 8, sacados de los .pak.

Uso:  python -X utf8 herramientas/generar_personajes/equipo_altos.py     (variable FAO_PAK = carpeta con data1.pak y update*.pak; por defecto Descargas)
Escribe, SIN tocar lo que hornea hornear_equipos.py (ojo: si se vuelve a ejecutar hornear_equipos.py, que borra juego/arte/fao, hay que volver a ejecutar este):
  juego/arte/fao/<capa>/<Anim>_<f|m>.png                          las capas de cada pieza (mismo formato que hornear_equipos.py)
  juego/src/presentacion/render/fao_datos_altos.lua               medidas de esas capas y qué lleva cada clase, género y escalón 9 y 10
  juego/arte/hojas/equipo_altos.png                               iconos de inventario de las piezas nuevas (casillas de 32 px, ver ICONOS)
Cada conjunto es cabeza (n-1), cuerpo (n), manos (n+1) y pies (n+2) del número de apariencia n (así vienen numerados en FAO). Arte de un juego ajeno (FAO): prototipo."""
import math
import os
import pickle
import re
import sys

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, "..", "generar_mobs"))
import pak_fao

RAIZ = os.path.abspath(os.path.join(AQUI, "..", ".."))
SALIDA = os.path.join(RAIZ, "juego", "arte", "fao")
LUA = os.path.join(RAIZ, "juego", "src", "presentacion", "render", "fao_datos_altos.lua")
HOJA_ICONOS = os.path.join(RAIZ, "juego", "arte", "hojas", "equipo_altos.png")

ANIMS = {"wait": ("Wait", 3), "run": ("Run", 6), "att": ("Att", 4), "att2": ("Att2", 4), "att3": ("Att3", 4), "cast": ("Cast", 3),
         "sht": ("Sht", 4), "hurt": ("Hurt", 2), "dead": ("Dead", 6)}
ANIMS_MONTADO = ("wait", "run", "att", "att2", "att3", "cast", "sht", "hurt")

# conjunto de armadura (número de apariencia del cuerpo) por clase y escalón (9, 10)
CONJUNTOS = {
    "guerrero": (5987, 6466), "lancero": (6016, 7419), "cazador": (5983, 6012),
    "mago": (6470, 7080), "clerigo": (5666, 6020), "nigromante": (5991, 1563),
}
# arma por clase, familia y escalón: (apariencia, sufijo de carpeta; los arcos son "bl"/"gl")
ARMAS = {
    "guerrero": {"espada": ((6801, ""), (1541, "")), "hacha": ((7384, ""), (1546, ""))},
    "lancero": {"lanza": ((6803, ""), (1542, ""))},
    "cazador": {"arco": ((6804, "l"), (1548, "l"))},
    "mago": {"baston": ((6805, ""), (1544, ""))},
    "clerigo": {"maza": ((7045, ""), (379, ""))},
    "nigromante": {"baculo": ((6267, ""), (6435, ""))},
}
TIPO_ARMADURA = {"guerrero": "pesada", "lancero": "lancero", "cazador": "ligera", "mago": "tela", "nigromante": "necro"}   # (el clérigo comparte la túnica del mago en los iconos)
HUECOS = (("cabeza", -1, "頭飾"), ("pecho", 0, "衣服"), ("piernas", 1, "手套"), ("pies", 2, "鞋子"))

# Iconos: casilla de cada uno en equipo_altos.png. Armadura: ((tipo * 4 + hueco) * 2 + (escalón - 9)); armas desde 40: familia * 2 + (escalón - 9).
ORDEN_TIPOS = ("pesada", "ligera", "tela", "lancero", "necro")
ORDEN_FAMILIAS = ("espada", "hacha", "lanza", "arco", "baston", "maza", "baculo")
ORDEN_HUECOS = ("cabeza", "pecho", "piernas", "pies")


def icono_armadura(tipo, hueco, esc):
    return (ORDEN_TIPOS.index(tipo) * 4 + ORDEN_HUECOS.index(hueco)) * 2 + (esc - 9)


def icono_arma(fam, esc):
    return 40 + ORDEN_FAMILIAS.index(fam) * 2 + (esc - 9)


def carpetas():
    cods = {}
    for k in pak_fao.indice():
        m = re.match(r"shape/chr/(i\d+[a-z]*)/(\d+)_wait\.spr$", k)
        if m:
            cods.setdefault(m.group(1), []).append(int(m.group(2)))
    return cods


COD = carpetas()


def capa_de(n, letra):
    """(carpeta, código delantero) de la pieza n en el género `letra` (b | g | bl | gl)."""
    for fmt in ("i%03d%s", "i%d%s"):
        c = fmt % (n, letra)
        if c in COD:
            return c, min(COD[c])
    raise SystemExit("no existe la capa de la apariencia %d (%s)" % (n, letra))


def hornear_capa(cap, cod_f, meta):
    total = 0
    for sufijo, cod in (("f", cod_f), ("m", cod_f + 5000)):
        for anim, (Anim, _) in ANIMS.items():
            if sufijo == "m" and anim not in ANIMS_MONTADO:
                continue
            clave = "shape/chr/%s/%d_%s.spr" % (cap, cod, anim)
            if clave not in pak_fao.indice():
                continue
            frames = pak_fao.cuadros_spr(clave)
            validos = [(im, o) for im, o in frames if im is not None]
            pasos = len(frames) // 5
            if not validos or pasos < 1:
                continue
            izq = max(o[0] for im, o in validos)
            der = max(im.width - o[0] for im, o in validos)
            arr = max(o[1] for im, o in validos)
            aba = max(im.height - o[1] for im, o in validos)
            cw = math.ceil(izq + der) + 2
            ch = math.ceil(arr + aba) + 2
            orx, ory = math.ceil(izq) + 1, math.ceil(arr) + 1
            salida = Image.new("RGBA", (cw * pasos * 5, ch), (0, 0, 0, 0))
            n = len(frames)
            for i, (im, o) in enumerate(frames):
                if im is None:
                    continue
                if i == n - 1:
                    j = 0                                # el cuadro que falta: paso 1, dirección 3
                elif i < 4:
                    j = i + 1                            # paso 1, direcciones 4 a 7
                else:
                    k = i - 4
                    j = (1 + k // 5) * 5 + k % 5         # pasos 2.., direcciones 3 a 7
                salida.alpha_composite(im, (j * cw + max(0, orx - o[0]), max(0, ory - o[1])))
            carpeta = os.path.join(SALIDA, cap)
            os.makedirs(carpeta, exist_ok=True)
            ruta = os.path.join(carpeta, Anim + "_" + sufijo + ".png")
            salida.quantize(colors=128, method=Image.FASTOCTREE, dither=Image.NONE).save(ruta, optimize=True)
            total += os.path.getsize(ruta)
            meta.setdefault(cap, {})[anim + "_" + sufijo] = {"w": cw, "h": ch, "x": orx, "y": ory, "pasos": pasos}
    return total


# ---------------------------------------------------------------- iconos de inventario
def buscar_icono(items, ap, categorias):
    """Imagen 32x32 del icono de inventario de la apariencia ap (un objeto de esas categorías que tenga icono)."""
    idx = pak_fao.indice()
    for d in items:
        if d.get("原型外觀") == str(ap) and d.get("物品類別") in categorias and d.get("原型介面", "").isdigit():
            n = int(d["原型介面"])
            for fmt in ("shape/item/i%04d.shp", "shape/item/i%05d.shp"):
                k = fmt % n
                if k in idx:
                    r = pak_fao.decodificar_shp(pak_fao.datos(k))
                    if r:
                        return r[0]
    return None


def cargar_items():
    items = []
    for n in ["item"] + ["item%d" % i for i in range(2, 10)]:
        t = pak_fao.datos("setting/eng/%s.xml" % n).decode("utf-8", "replace")
        for m in re.finditer(r"<道具\s([^>]*?)/?>", t):
            items.append(dict(re.findall(r'(\S+?)="([^"]*)"', m.group(1))))
    return items


def main():
    meta, looks, total = {}, {}, 0
    for clase, (t9, t10) in CONJUNTOS.items():
        looks[clase] = {"h": {}, "m": {}}
        for gen, letra in (("h", "b"), ("m", "g")):
            for esc, n in ((9, t9), (10, t10)):
                fila = {"arma": {}}
                for hueco, d, cat in HUECOS:
                    cap, cod = capa_de(n + d, letra)
                    fila[hueco] = cap
                    if cap not in meta:
                        total += hornear_capa(cap, cod, meta)
                for fam, tiers in ARMAS[clase].items():
                    ap, suf = tiers[esc - 9]
                    cap, cod = capa_de(ap, letra + suf)
                    fila["arma"][fam] = cap
                    if cap not in meta:
                        total += hornear_capa(cap, cod, meta)
                looks[clase][gen][str(esc)] = fila
        print("capas listas para", clase)
    print("tamaño total", total // 1024, "KB")

    def lua(v, nivel=0):
        pad = "  " * (nivel + 1)
        if isinstance(v, dict):
            partes = []
            for k, x in v.items():
                nombre = str(k) if re.match(r"^[A-Za-z_]\w*$", str(k)) else "[%s]" % ('"%s"' % k)
                partes.append("%s%s = %s," % (pad, nombre, lua(x, nivel + 1)))
            return "{\n" + "\n".join(partes) + "\n" + "  " * nivel + "}"
        if isinstance(v, str):
            return '"%s"' % v
        return str(v)

    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERADO por herramientas/generar_personajes/equipo_altos.py: capas y looks de los escalones 9 y 10 del equipo (se suman a fao_datos.lua). No editar a mano.\n")
        f.write("return " + lua({"capas": meta, "looks": looks}) + "\n")
    print("escrito", LUA)

    # iconos
    items = cargar_items()
    hoja = Image.new("RGBA", (256, 256), (0, 0, 0, 0))

    hecho = {}

    def poner(i, im):
        if im is None and i % 2 == 1 and (i - 1) in hecho:
            # sin icono propio (las piezas "(P)" no lo traen en el .pak): el del escalón anterior teñido de dorado
            base = hecho[i - 1].copy()
            r, g, bb, al = base.split()
            r, g, bb = r.point(lambda v: min(255, int(v * 1.25))), g.point(lambda v: int(v * 1.0)), bb.point(lambda v: int(v * 0.6))
            im = Image.merge("RGBA", (r, g, bb, al))
        if im is None:
            return False
        hecho[i] = im
        im = im.copy()
        im.thumbnail((30, 30), Image.LANCZOS)
        hoja.alpha_composite(im, ((i % 8) * 32 + (32 - im.width) // 2, (i // 8) * 32 + (32 - im.height) // 2))
        return True

    faltan = []
    for clase, tipo in TIPO_ARMADURA.items():
        for esc, n in ((9, CONJUNTOS[clase][0]), (10, CONJUNTOS[clase][1])):
            for hueco, d, cat in HUECOS:
                if not poner(icono_armadura(tipo, hueco, esc), buscar_icono(items, n + d, (cat,))):
                    faltan.append((clase, hueco, esc))
        for fam, tiers in ARMAS[clase].items():
            for esc in (9, 10):
                ap = tiers[esc - 9][0]
                if not poner(icono_arma(fam, esc), buscar_icono(items, ap, ("劍", "斧", "刀", "槍", "弓箭", "杖", "錘", "影刃"))):
                    faltan.append((clase, fam, esc))
    for clase, tiers in (("clerigo", ARMAS["clerigo"]),):
        for fam, t in tiers.items():
            for esc in (9, 10):
                if not poner(icono_arma(fam, esc), buscar_icono(items, t[esc - 9][0], ("劍", "斧", "刀", "槍", "弓箭", "杖", "錘", "影刃"))):
                    faltan.append((clase, fam, esc))
    hoja.save(HOJA_ICONOS, optimize=True)
    print("iconos sin encontrar:", faltan)


if __name__ == "__main__":
    main()
