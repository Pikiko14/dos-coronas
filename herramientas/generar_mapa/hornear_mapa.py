"""Hornea el arte de mapa FAO (adornos: árboles, rocas, plantas, props, muros) para el juego.

Uso:  python herramientas/generar_mapa/hornear_mapa.py [carpeta_mapa_adornos]

Lee los sprites isométricos sueltos de ../arte-fuente/mapa-adornos (fuera del proyecto: son de terceros y no se publican), recorta
cada variante elegida a sus píxeles visibles y la reduce a la escala del juego (ESC = 0,375: una casilla del arte original son 64 px de
paso en el eje y la del juego 24, igual que las casas). Escribe juego/arte/mapa/<nombre>_<n>.png y regenera
juego/src/presentacion/render/mapa_fao_datos.lua con las medidas. Los muros de las ciudades se cortan en rodajas de una casilla."""
import json, math, os, re, sys
from PIL import Image

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FUENTE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(RAIZ, "..", "arte-fuente", "mapa-adornos")
SALIDA = os.path.join(RAIZ, "juego", "arte", "mapa")
DATOS_LUA = os.path.join(RAIZ, "juego", "src", "presentacion", "render", "mapa_fao_datos.lua")
ESC = 0.75       # el zoom normal del juego es 2: el arte se hornea al doble de lo que mide en el mundo (24 px de paso por casilla)

V, R, A, H = "vegetacion_y_plantas", "rocas_y_piedras", "adornos_y_props", "huesos_y_cementerio"

# nombre del objeto del juego -> [(categoría, carpeta del set, variantes (None = todas), multiplicador de tamaño)]
OBJETOS = {
    "arbol": [(V, "set22_001", None, 0.7), (V, "set22_004", [1, 2, 4, 8], 0.65)],
    "arbol_pino": [(V, "set22_038", [1, 2, 3, 4, 5, 6], 0.55)],
    "arbol_pino_umbra": [(V, "set22_037", [1, 2, 3, 4, 5, 6], 0.55)],
    "arbol_seco": [(V, "set22_009", [1], 0.4)],
    "palma": [(V, "set22_013", [1, 3, 4], 0.7)],
    "roca": [(R, "set23_004", [6, 7, 8], 0.8), (R, "set24_018", [4, 5, 7, 8], 0.9), (R, "set23_023", [1], 1.0)],
    "piedra": [(R, "set23_024", [1], 1.0), (R, "set23_025", [1], 1.2), (R, "set25_015", [1, 5, 9], 1.0)],
    "matorral": [(V, "set21_004", [5, 6, 7, 8], 0.8), (V, "set21_003", [3, 6], 0.7)],
    "arbusto": [(V, "set21_001", [1, 2, 3, 4], 1.0), (V, "set21_002", [1, 2, 4], 0.9)],
    "arbusto_rosa": [(V, "set21_024", [1, 2], 0.6)],
    "seta_marron": [(V, "set21_011", [1, 2], 0.8), (V, "set21_014", [1, 2], 0.8)],
    "seta_roja": [(V, "set21_012", [1, 2], 0.8)],
    "tocon": [(V, "set22_027", [3], 0.09)],
    "tronco": [(V, "set22_027", [4], 0.08), (V, "set22_027", [5], 0.1)],
    "helecho": [(V, "set21_018", [1, 2, 3, 4], 0.7), (V, "set21_041", [1, 2], 0.7), (V, "set21_019", [1], 0.7)],
    "hierba_seca": [(V, "set21_006", [3, 4], 0.6)],
    "hierba_alta": [(V, "set21_006", [2, 5, 6], 0.55)],
    "matas": [(V, "set21_005", [1, 2], 0.8), (V, "set21_006", [1], 0.8)],
    "hojas": [(V, "set21_015", [1], 0.7), (V, "set21_016", [1, 2], 0.7)],
    "flor_amarilla": [(V, "set21_028", [1, 2], 0.55), (V, "set21_036", [1, 2], 0.55)],
    "flor_blanca": [(V, "set21_026", [1, 2], 0.55), (V, "set21_032", [1, 2], 0.55)],
    "flor_roja": [(V, "set21_030", [1, 2], 0.55), (V, "set21_027", [1, 2], 0.55)],
    "flores_mixtas": [(V, "set21_009", [1, 2, 3], 0.6), (V, "set21_022", [1], 0.6), (V, "set21_038", [1, 2], 0.5), (V, "set21_049", [1, 2], 0.5)],
    "flores_naranja": [(V, "set21_031", [1, 2], 0.55), (V, "set21_033", [1, 2], 0.55)],
    # props de las ciudades
    "barril": [(A, "set24_065", [1, 2], 1.0), (A, "set24_066", [1, 2], 1.0)],
    "caja": [(A, "set24_062", [1, 2, 3, 4, 5, 6], 1.0)],
    "pozo": [(A, "set24_060", [1], 1.0), (A, "set24_061", [1], 1.0)],
    "farol": [(A, "set24_055", [1, 2], 1.0)],
    "banco": [(A, "set24_103", [1], 1.0)],
    "fogata": [(A, "set24_054", [1], 1.0)],
    "circulo_piedras": [(A, "set24_051", [1], 0.8)],
    "jarron": [(A, "set24_093", [1, 2, 3, 6, 9], 1.4)],
    "cubo": [(A, "set24_067", [1], 1.0)],
    "madera_apilada": [(A, "set24_049", [1], 1.0)],
    "cartel": [(A, "set24_094", [1, 2, 3], 1.4)],
    "estatua_albor": [(A, "set24_110", [1], 1.0)],
    "estatua_umbra": [(A, "set24_110", [3], 1.0)],
    "estatua": [(A, "set24_085", [1], 1.4)],
    "columna_albor": [(R, "set24_020", [4, 5], 1.0)],
    "columna_umbra": [(R, "set24_020", [6], 1.0)],
    "cultivo": [(V, "set21_006", [3, 4], 0.45), (V, "set21_007", [1, 2], 0.5)],
    # montañas: una sola familia de formas (mesas de arenisca / agujas oscuras), todas al mismo ancho (negativo = ancho final en píxeles)
    "montana_albor": [(R, "set23_055", [1, 2, 9], -118), (R, "set23_057", [3, 5, 6], -112)],
    "montana_umbra": [(R, "set28_028", [2, 7, 8], -104), (R, "set23_007", [1, 5, 7], -104)],
    "heno": [(V, "set21_006", [3, 4, 5], 0.8), (V, "set21_007", [1, 2], 0.7)],
    # campo de batalla y mazmorras: marcas del suelo y restos
    "hueco": [(R, "set25_016", [1, 2], 1.0)],
    "mancha": [(R, "set25_033", [1, 2, 3, 4], 0.9)],
    "brasas": [(R, "set23_036", [4, 5], 0.55), (R, "set25_020", [1, 4], 0.7)],
    "grietita": [(R, "set25_020", [2, 6], 0.55)],
    "guijarros": [(R, "set23_024", [1], 1.0), (R, "set25_015", [1, 5, 9], 1.0)],
    "restos": [(H, "set23_010", [1, 2, 3, 4], 0.9), (H, "set23_011", [1, 2, 3, 4], 0.9), (H, "set23_013", [1, 2, 3], 0.8)],
    "calavera_pila": [(H, "set23_014", [1, 4], 0.8)],
    "tumba": [(A, "set24_122", [1], 1.0)],
}

OBJETOS["risco_albor"] = OBJETOS["montana_albor"]
OBJETOS["risco_umbra"] = OBJETOS["montana_umbra"]


def variantes(cat, s):
    d = os.path.join(FUENTE, cat, s)
    res = {}
    for f in os.listdir(d):
        m = re.search(r"-(\d+)U[01]\.png$", f)
        if m and f.endswith(".png"):
            res[int(m.group(1))] = os.path.join(d, f)
    return res


def hornear(ruta, mult, ancho=None):
    im = Image.open(ruta).convert("RGBA")
    caja = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    if not caja:
        return None
    im = im.crop(caja)
    k = (ancho * ESC / 0.375 / im.width) if ancho else ESC * mult      # ancho: tamaño final fijo en píxeles del juego (piezas de distinto tamaño original)
    w, h = max(1, round(im.width * k)), max(1, round(im.height * k))
    return im.resize((w, h), Image.LANCZOS)


def guardar(im, nombre):
    ruta = os.path.join(SALIDA, nombre + ".png")
    im.quantize(colors=200, method=Image.FASTOCTREE, dither=Image.NONE).save(ruta, optimize=True)
    return os.path.getsize(ruta)


def lua(v, nivel=0):
    pad = "  " * (nivel + 1)
    if isinstance(v, dict):
        partes = [f"{pad}[{json.dumps(k)}] = {lua(x, nivel + 1)}," if not re.match(r"^[A-Za-z_]\w*$", str(k)) else f"{pad}{k} = {lua(x, nivel + 1)}," for k, x in v.items()]
        return "{\n" + "\n".join(partes) + "\n" + "  " * nivel + "}"
    if isinstance(v, list):
        return "{ " + ", ".join(lua(x, nivel + 1) for x in v) + " }"
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, bool):
        return "true" if v else "false"
    return str(v)


if __name__ == "__main__":
    if os.path.isdir(SALIDA):
        for f in os.listdir(SALIDA):
            os.remove(os.path.join(SALIDA, f))
    os.makedirs(SALIDA, exist_ok=True)
    tabla = {}
    total = 0
    for nombre, fuentes in OBJETOS.items():
        lista = []
        for cat, s, vs, mult in fuentes:
            ancho = None
            if mult < 0:
                ancho, mult = -mult, 1.0
            todas = variantes(cat, s)
            for n in (vs or sorted(todas)):
                if n not in todas:
                    print("falta", s, n)
                    continue
                im = hornear(todas[n], mult, ancho)
                if im is None:
                    continue
                arch = f"{nombre}_{len(lista) + 1}"
                total += guardar(im, arch)
                lista.append({"f": arch, "w": im.width, "h": im.height})
        tabla[nombre] = lista
        print(nombre, len(lista))
    extra = {}
    try:
        import muros_mapa
        extra = muros_mapa.hornear(FUENTE, SALIDA, ESC, guardar)
    except ImportError:
        pass
    datos = {"esc": ESC, "objetos": tabla, "muros": extra}
    with open(DATOS_LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERADO por herramientas/generar_mapa/hornear_mapa.py: medidas de los sprites de mapa (arte/mapa/). No editar a mano.\n")
        f.write("return " + lua(datos) + "\n")
    print("tamaño total", total // 1024, "KB;", DATOS_LUA)
