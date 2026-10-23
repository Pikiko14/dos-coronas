"""Equipo FAO propio para los escalones 3, 5 y 7 (niveles 8, 16 y 25), que hasta ahora repetían el dibujo del escalón anterior (hornear_equipos.py solo tiene 5 etapas
de FAO para los ocho escalones). Para cada clase elige, entre las piezas reales de FAO, conjuntos y armas con un nivel entre el del escalón anterior y el siguiente que NO se
usen en ningún otro escalón, y los hornea desde los .pak.

Uso:  python -X utf8 herramientas/generar_personajes/equipo_intermedio.py     (variable FAO_PAK = carpeta con data1.pak y update*.pak; por defecto Descargas)
Escribe:
  juego/arte/fao/<capa>/<Anim>_<f|m>.png                     las capas nuevas (mismo formato que hornear_equipos.py y equipo_altos.py)
  juego/src/presentacion/render/fao_datos_medios.lua         capas y looks de los escalones 3, 5 y 7 (fao.lua los suma a fao_datos.lua, campo por campo)
Después hay que regenerar los iconos de inventario con iconos_equipo.py (lee este archivo). Arte de un juego ajeno (FAO): prototipo."""
import collections
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import equipo_altos as A
import iconos_equipo as I

RAIZ = A.RAIZ
LUA = os.path.join(RAIZ, "juego", "src", "presentacion", "render", "fao_datos_medios.lua")

ESCALONES = (3, 5, 7)
# nivel de FAO (技能等限 de la armadura, 物品等級 del arma) que se busca en cada escalón nuevo
OBJETIVO = {3: 20, 5: 65, 7: 240}
LIMITES = {3: (5, 60), 5: (46, 130), 7: (150, 330)}
# grupo de clases de la armadura (技能限制1): 33 combatientes, 32 arqueros, 34 magos y afines
GRUPO = {"guerrero": "33", "lancero": "33", "cazador": "32", "mago": "34", "clerigo": "34", "nigromante": "34"}
# familia de arma del juego -> categoría de FAO y sufijo de carpeta (los arcos llevan "l")
ARMA = {"espada": ("劍", ""), "hacha": ("斧", ""), "lanza": ("槍", ""), "arco": ("弓箭", "l"), "baston": ("杖", ""), "maza": ("杖", ""), "baculo": ("杖", "")}
FAMILIAS = {"guerrero": ["espada", "hacha"], "lancero": ["lanza"], "cazador": ["arco"], "mago": ["baston"], "clerigo": ["maza"], "nigromante": ["baculo"]}


def usados():
    """Números de apariencia ya empleados en cualquier escalón (fao_datos.lua y fao_datos_altos.lua)."""
    res = set()
    for n in ("fao_datos.lua", "fao_datos_altos.lua"):
        t = open(os.path.join(RAIZ, "juego", "src", "presentacion", "render", n), encoding="utf-8").read()
        res |= {int(x) for x in re.findall(r'"i(\d+)(?:b|g)?l?"', t)}
    return res


def existe_conjunto(n):
    """El cuerpo n existe en los dos géneros (la cabeza n-1, las manos n+1 y los pies n+2 son opcionales: si no existen, esa pieza va sin cubrir)."""
    for letra in ("b", "g"):
        try:
            A.capa_de(n, letra)
        except SystemExit:
            return False
    return True


def existe_arma(n, suf):
    for letra in ("b", "g"):
        try:
            A.capa_de(n, letra + suf)
        except SystemExit:
            return False
    return True


def main():
    items = A.cargar_items()
    cuerpos = collections.defaultdict(list)
    armas = collections.defaultdict(list)
    for d in items:
        if "原型外觀" not in d or not d["原型外觀"].isdigit():
            continue
        n = int(d["原型外觀"])
        if d.get("物品類別") == "衣服":
            cuerpos[n].append(d)
        elif d.get("物品類別") in ("劍", "斧", "槍", "弓箭", "杖"):
            armas[n].append(d)
    piezas = {(d.get("物品類別"), int(d["原型外觀"])) for d in items if "原型外觀" in d and d["原型外觀"].isdigit()}
    por_cat = collections.defaultdict(lambda: collections.defaultdict(list))        # categoría -> apariencia -> objetos
    for d in items:
        if "原型外觀" in d and d["原型外觀"].isdigit() and d.get("物品類別") in ("頭飾", "手套", "鞋子"):
            por_cat[d["物品類別"]][int(d["原型外觀"])].append(d)
    ocupado = usados()
    elegidos = {}                                   # (clase, escalón) -> n del conjunto
    arma_elegida = {}                               # (clase, familia, escalón) -> n del arma
    suelta = {}                                     # (clase, escalón, hueco) -> apariencia de la pieza
    tomados = set(ocupado)

    for clase in I.CLASES:
        for esc in ESCALONES:
            lo, hi = LIMITES[esc]
            mejor = None
            for n, ds in cuerpos.items():
                if n in tomados:
                    continue
                grupos = {d.get("技能限制1") for d in ds}
                niveles = [int(d.get("技能等限", "0") or 0) for d in ds if (d.get("技能等限", "") or "").isdigit()]
                if GRUPO[clase] not in grupos or not niveles or not (lo <= min(niveles) <= hi):
                    continue
                if not existe_conjunto(n):
                    continue
                dist = abs(min(niveles) - OBJETIVO[esc])
                if mejor is None or dist < mejor[0]:
                    mejor = (dist, n)
            if mejor is None:
                raise SystemExit("no hay conjunto para %s en el escalón %d" % (clase, esc))
            elegidos[(clase, esc)] = mejor[1]
            tomados |= {mejor[1]}
            # cabeza, manos y pies: los del conjunto si FAO los numera así; si no, la pieza suelta de ese hueco que más se acerque en nivel (sin repetir ninguna)
            for hueco, d, cat in A.HUECOS:
                if hueco == "pecho":
                    continue
                if (cat, mejor[1] + d) in piezas and mejor[1] + d not in tomados:
                    suelta[(clase, esc, hueco)] = mejor[1] + d
                    tomados.add(mejor[1] + d)
                    continue
                mp = None
                for ap, ds in por_cat[cat].items():
                    if ap in tomados:
                        continue
                    grupos = {d2.get("技能限制1") for d2 in ds}
                    niveles = [int(d2.get("技能等限", "0") or 0) for d2 in ds if (d2.get("技能等限", "") or "").isdigit()]
                    if (GRUPO[clase] not in grupos and grupos != {None}) or not niveles or not (lo <= min(niveles) <= hi):
                        continue
                    try:
                        A.capa_de(ap, "b")
                        A.capa_de(ap, "g")
                    except SystemExit:
                        continue
                    dist = abs(min(niveles) - OBJETIVO[esc])
                    if mp is None or dist < mp[0]:
                        mp = (dist, ap)
                if mp is not None:
                    suelta[(clase, esc, hueco)] = mp[1]
                    tomados.add(mp[1])
            for fam in FAMILIAS[clase]:
                cat, suf = ARMA[fam]
                mej = None
                for n, ds in armas.items():
                    if n in tomados:
                        continue
                    niveles = [int(d.get("物品等級", "0") or 0) for d in ds if d.get("物品類別") == cat and (d.get("物品等級", "") or "").isdigit()]
                    if not niveles or not (0 <= min(niveles) <= hi * 1.3):
                        continue
                    if not existe_arma(n, suf):
                        continue
                    dist = abs(min(niveles) - OBJETIVO[esc])
                    if mej is None or dist < mej[0]:
                        mej = (dist, n)
                if mej is None:
                    raise SystemExit("no hay arma %s para %s en el escalón %d" % (fam, clase, esc))
                arma_elegida[(clase, fam, esc)] = mej[1]
                tomados.add(mej[1])
            print(clase, esc, "conjunto", elegidos[(clase, esc)], {f: arma_elegida[(clase, f, esc)] for f in FAMILIAS[clase]})

    meta, looks, total = {}, {}, 0
    for clase in I.CLASES:
        looks[clase] = {"h": {}, "m": {}}
        for gen, letra in (("h", "b"), ("m", "g")):
            for esc in ESCALONES:
                n = elegidos[(clase, esc)]
                fila = {"arma": {}}
                for hueco, d, cat in A.HUECOS:
                    ap = n if hueco == "pecho" else suelta.get((clase, esc, hueco))
                    if ap is None:
                        continue                                  # (FAO no tiene esa pieza a ese nivel: se queda sin cubrir)
                    try:
                        cap, cod = A.capa_de(ap, letra)
                    except SystemExit:
                        continue                                  # (pieza que FAO no tiene en ese conjunto)
                    fila[hueco] = cap
                    if cap not in meta:
                        total += A.hornear_capa(cap, cod, meta)
                for fam in FAMILIAS[clase]:
                    cap, cod = A.capa_de(arma_elegida[(clase, fam, esc)], letra + ARMA[fam][1])
                    fila["arma"][fam] = cap
                    if cap not in meta:
                        total += A.hornear_capa(cap, cod, meta)
                looks[clase][gen][str(esc)] = fila
        print("capas listas para", clase)
    print("tamaño total", total // 1024, "KB")

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

    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERADO por herramientas/generar_personajes/equipo_intermedio.py: capas y looks propios de los escalones 3, 5 y 7 (se suman a fao_datos.lua, campo por campo). No editar a mano.\n")
        f.write("return " + lua({"capas": meta, "looks": looks}) + "\n")
    print("escrito", LUA)


if __name__ == "__main__":
    main()
