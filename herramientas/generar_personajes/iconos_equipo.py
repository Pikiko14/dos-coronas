"""Iconos de inventario de FAO para el equipo de los escalones 1 a 8: cada pieza lleva el icono de la pieza real de FAO que se dibuja sobre el personaje
(la misma apariencia i<NNN> de render/fao_datos.lua), en vez de los dibujos de la lámina antigua.

Uso:  python -X utf8 herramientas/generar_personajes/iconos_equipo.py     (variable FAO_PAK = carpeta con data1.pak y update*.pak; por defecto Descargas)
Escribe juego/arte/hojas/equipo_fao.png (casillas de 32 px, 8 columnas) y compartido/datos/equipo_iconos_fao.xml (casilla de cada pieza por clase, hueco y
escalón; -1 = sin icono en FAO, se queda el de la lámina antigua). Los escalones 9 y 10 los hace equipo_altos.py. Arte de un juego ajeno (FAO): prototipo."""
import os
import re
import sys

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, "..", "generar_mobs"))
import pak_fao

sys.path.insert(0, AQUI)
RAIZ = os.path.abspath(os.path.join(AQUI, "..", ".."))
DATOS_LUA = os.path.join(RAIZ, "juego", "src", "presentacion", "render", "fao_datos.lua")
HOJA = os.path.join(RAIZ, "juego", "arte", "hojas", "equipo_fao.png")
XML = os.path.join(RAIZ, "compartido", "datos", "equipo_iconos_fao.xml")

CLASES = ("guerrero", "lancero", "cazador", "mago", "clerigo", "nigromante")
HUECOS = (("cabeza", "頭飾"), ("pecho", "衣服"), ("piernas", "手套"), ("pies", "鞋子"))
ARMAS = ("劍", "斧", "刀", "槍", "弓箭", "杖", "錘", "影刃")
# casillas por clase: cabeza, pecho, piernas, pies, arma y segunda arma (el hacha del guerrero) x 8 escalones
SLOTS = ("cabeza", "pecho", "piernas", "pies", "arma", "arma2")


def casilla(clase, slot, t):
    return ((CLASES.index(clase) * len(SLOTS) + SLOTS.index(slot)) * 8) + (t - 1)


def leer_looks():
    """{clase: {escalón: {hueco: apariencia, 'arma': [apariencias]}}} del género masculino de fao_datos.lua."""
    res = {}
    # fao_datos.lua y, encima, los escalones 3, 5 y 7 de fao_datos_medios.lua (equipo_intermedio.py), que sustituyen a los de la misma etapa
    for ruta, solo in ((DATOS_LUA, None), (DATOS_LUA.replace("fao_datos.lua", "fao_datos_medios.lua"), (3, 5, 7))):
        if not os.path.exists(ruta):
            continue
        s = open(ruta, encoding="utf-8").read()
        for clase in CLASES:
            i = s.index("    %s = {\n      h = {" % clase)
            j = s.index("      m = {", i)
            seg = s[i:j]
            res.setdefault(clase, {})
            for m in re.finditer(r'\["(\d+)"\] = \{\n(.*?)\n        \},', seg, re.S):
                t, cuerpo = int(m.group(1)), m.group(2)
                if solo and t not in solo:
                    continue
                fila = {}
                armas = re.search(r"arma = \{(.*?)\}", cuerpo, re.S)
                fila["arma"] = [int(n) for n in re.findall(r'"i(\d+)b?l?"', armas.group(1))] if armas else []
                for hueco, _ in HUECOS:
                    mm = re.search(r'\b%s = "i(\d+)b"' % hueco, cuerpo)
                    if mm:
                        fila[hueco] = int(mm.group(1))
                res[clase][t] = fila
    # orden de los escalones de más sencillo a más elaborado (ordenar_escalones.py): el escalón t usa el dibujo del escalón orden[t]
    ruta = DATOS_LUA.replace("fao_datos.lua", "fao_orden.lua")
    if os.path.exists(ruta):
        txt = open(ruta, encoding="utf-8").read()
        for clase in CLASES:
            m = re.search(r"%s = \{([\d, ]+)\}" % clase, txt)
            if m:
                orden = [int(x) for x in m.group(1).split(",")]
                viejo = dict(res[clase])
                for t in range(1, 9):
                    if orden[t - 1] in viejo:
                        res[clase][t] = viejo[orden[t - 1]]
    return res


def cargar_items():
    items = []
    for n in ["item"] + ["item%d" % i for i in range(2, 10)]:
        t = pak_fao.datos("setting/eng/%s.xml" % n).decode("utf-8", "replace")
        for m in re.finditer(r"<道具\s([^>]*?)/?>", t):
            items.append(dict(re.findall(r'(\S+?)="([^"]*)"', m.group(1))))
    return items


_iconos = None


def tabla_iconos():
    global _iconos
    if _iconos is None:
        _iconos = {}
        for n in ("itemicon", "itemicon1", "itemicon2", "itemicon3", "itemicon4"):
            t = pak_fao.datos("setting/%s.xml" % n).decode("utf-8", "replace")
            for m in re.finditer(r'<icon id="(\d+)"[^>]*?normal="(\w+)"', t):
                _iconos.setdefault(int(m.group(1)), m.group(2))
    return _iconos


def buscar_icono(items, ap, categorias):
    idx = pak_fao.indice()
    tabla = tabla_iconos()
    for d in items:
        if d.get("原型外觀") == str(ap) and d.get("物品類別") in categorias and d.get("原型介面", "").isdigit():
            n = int(d["原型介面"])
            candidatos = ["shape/item/%s.shp" % tabla[n]] if n in tabla else []
            candidatos += ["shape/item/i%04d.shp" % n, "shape/item/i%05d.shp" % n]
            for k in candidatos:
                if k in idx:
                    r = pak_fao.decodificar_shp(pak_fao.datos(k))
                    if r:
                        return r[0]
    return None


def main():
    looks = leer_looks()
    items = cargar_items()
    filas = len(CLASES) * len(SLOTS) * 8 // 8
    hoja = Image.new("RGBA", (256, filas * 32), (0, 0, 0, 0))
    listas = {}                       # (clase, slot) -> [casilla o -1] x 8
    faltan = []
    for clase in CLASES:
        for slot in SLOTS:
            listas[(clase, slot)] = [-1] * 8
        for t in range(1, 9):
            fila = looks[clase].get(t, {})
            piezas = [(h, fila.get(h), (cat,)) for h, cat in HUECOS]
            armas = fila.get("arma", [])
            for k, ap in enumerate(armas[:2]):
                piezas.append((SLOTS[4 + k], ap, ARMAS))
            for slot, ap, cats in piezas:
                if not ap:
                    continue
                im = buscar_icono(items, ap, cats)
                if im is None:
                    faltan.append((clase, slot, t, ap))
                    continue
                i = casilla(clase, slot, t)
                im = im.copy()
                im.thumbnail((30, 30), Image.LANCZOS)
                hoja.alpha_composite(im, ((i % 8) * 32 + (32 - im.width) // 2, (i // 8) * 32 + (32 - im.height) // 2))
                listas[(clase, slot)][t - 1] = i
    hoja.save(HOJA, optimize=True)
    # el hacha del guerrero comparte apariencia con la espada: se deja su lista como la de la espada si no tiene propia
    sal = ['<?xml version="1.0" encoding="UTF-8"?>',
           "<!--",
           "  Iconos de FAO de las piezas de los escalones 1 a 8: casilla de cada una (en juego/arte/hojas/equipo_fao.png) por clase, hueco y escalón. -1 = sin icono en FAO (se queda el de la lámina antigua).",
           "  GENERADO por herramientas/generar_personajes/iconos_equipo.py: edita allí, no aquí.",
           "-->", "<iconos_fao>"]
    for clase in CLASES:
        sal.append("  <%s>" % clase)
        for slot in SLOTS:
            sal.append('    <%s lista="%s"/>' % (slot, ",".join(str(v) for v in listas[(clase, slot)])))
        sal.append("  </%s>" % clase)
    sal.append("</iconos_fao>")
    open(XML, "w", encoding="utf-8", newline="\n").write("\n".join(sal) + "\n")
    print("iconos escritos:", sum(1 for v in listas.values() for x in v if x >= 0), "| sin icono en FAO:", faltan)


if __name__ == "__main__":
    main()
