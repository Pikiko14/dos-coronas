"""(Versión anterior: para el equipo por etapas usa hornear_equipos.py, que regenera arte/fao y fao_datos.lua.) Hornea los personajes por capas del arte fuente (fao-clases) para el juego.

Uso:  python herramientas/generar_personajes/hornear.py [carpeta_fao_clases] [manifest.jsonl]

Lee clases.json y los sprites originales (hojas de cuadros) y el manifest con los anclajes de cada cuadro. Para cada clase, género y
escalón de equipo (1-8) elige qué pieza de cada hueco se lleva, y escribe SOLO las capas usadas, ya reducidas, en juego/arte/fao/<capa>/.
Cada capa es una hoja por animación (arte/fao/<capa>/<Anim>_f.png capa delantera, _b.png capa trasera) con todos los cuadros en una fila,
recolocados en una casilla común cuyo origen está en los pies. También escribe juego/src/presentacion/render/fao_datos.lua con las tablas.
Cuadros por hoja: 5 direcciones x N pasos, en este orden: indice = paso * 5 + direccion (0 frente, 1 espalda, 2 espalda-izquierda,
3 izquierda, 4 frente-izquierda); las otras tres direcciones (derecha) se dibujan volteadas."""
import json, os, sys, re, math
from PIL import Image

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FAO = sys.argv[1] if len(sys.argv) > 1 else "C:/Users/User/juegos/arte-fuente/fao-clases"
MANIFEST = sys.argv[2] if len(sys.argv) > 2 else "C:/Users/User/Downloads/fao-sprites/manifest.jsonl"
SALIDA = os.path.join(RAIZ, "juego", "arte", "fao")
DATOS_LUA = os.path.join(RAIZ, "juego", "src", "presentacion", "render", "fao_datos.lua")
ESC = 1.0                                      # tamaño original: el juego los reduce al dibujar (con filtro suave), así se ven nítidos y sin pixelar

# animación del juego -> archivo original y pasos por dirección
ANIMS = {"wait": ("Wait", 3), "run": ("Run", 6), "att": ("Att", 4), "cast": ("Cast", 3), "sht": ("Sht", 4), "hurt": ("Hurt", 2), "dead": ("Dead", 6)}

# clase del juego -> clase del arte fuente
CLASES = {"guerrero": "guerrero", "lancero": "lancero", "cazador": "arquero", "mago": "mago", "clerigo": "sacerdote", "nigromante": "invocador"}
# familias de arma del juego -> tipo de arma del arte fuente
ARMAS = {
    "guerrero": {"espada": "sword", "hacha": "axe"}, "lancero": {"lanza": "spear", "alabarda": "spear"},
    "cazador": {"arco": "bow", "ballesta": "bow"}, "mago": {"baston": "staff", "vara": "staff"},
    "clerigo": {"maza": "staff", "cetro": "staff"}, "nigromante": {"baculo": "staff", "grimorio": "staff"},
}
HUECOS = {"pecho": "body", "cabeza": "head", "piernas": "hands", "pies": "feet"}     # hueco del juego -> pieza del arte fuente
GENEROS = {"h": "b", "m": "g"}
CUERPO = {"h": ("p001b", "999"), "m": ("p001g", "1100")}


def sprites_de(lista_items, saltar_test=False):
    """Sprites distintos (en orden de nivel) de una lista {nivel: [items]}."""
    vistos, orden = set(), []
    for nivel, items in sorted(lista_items.items(), key=lambda kv: int(kv[0])):
        for it in items:
            if saltar_test and it["name"].startswith("Test"):
                continue
            s = it["sprites"][0]
            if s not in vistos:
                vistos.add(s)
                orden.append(s)
    # los conjuntos especiales (códigos de 4 cifras) van los últimos: son los del escalón más alto
    return sorted(orden, key=lambda s: (int(re.sub(r"\D", "", s)) >= 1000, orden.index(s)))


def genero(s, g):
    """i086b -> i086g (mujer); los sufijos 'l' (mano izquierda) se conservan."""
    if g == "h":
        return s
    return re.sub(r"b(l?)$", r"g\1", s)


def elegir(lista, tier):
    if not lista:
        return None
    return lista[round((tier - 1) * (len(lista) - 1) / 7)]


def existe(carpeta):
    return os.path.isdir(f"{FAO}/sprites/{carpeta}")


# ---------------------------------------------------------------- qué capas lleva cada combinación
datos = json.load(open(f"{FAO}/clases.json", encoding="utf-8"))
looks = {}                 # looks[clase][genero][tier] = { cuerpo=, cabeza=, manos=, pies=, arma = {familia: capa}, escudo= }
capas = set()
for clase, fao in CLASES.items():
    c = datos["clases"][fao]
    looks[clase] = {}
    for g in GENEROS:
        looks[clase][g] = {}
        for t in range(1, 9):
            fila = {}
            for hueco, pieza in HUECOS.items():
                s = elegir(sprites_de(c["armadura"][pieza], False), t)
                if s:
                    s = genero(s, g)
                    if existe(s):
                        fila[hueco] = s
                        capas.add(s)
            fila["arma"] = {}
            for fam, tipo in ARMAS[clase].items():
                lista_a = sprites_de(c["armas"].get(tipo, {}), True)
                if tipo == "staff":
                    # solo los bastones sencillos de madera: los de cristal y luna del arte original salen enormes y desentonan
                    lista_a = [x for x in lista_a if x in ("i019b", "i020b", "i021b")] or lista_a
                s = elegir(lista_a, t)
                if s:
                    s = genero(s, g)
                    if not existe(s) and s.endswith("l"):
                        s = s[:-1]
                    if existe(s):
                        fila["arma"][fam] = s
                        capas.add(s)
            if c["escudos"]:
                s = elegir(sprites_de(c["escudos"], True), t)
                s = genero(s, g)
                if s and existe(s):
                    fila["escudo"] = s
                    capas.add(s)
            looks[clase][g][t] = fila
for g, (carp, cod) in CUERPO.items():
    capas.add(carp)
print("capas distintas:", len(capas))

# ---------------------------------------------------------------- anclajes del manifest
necesarias = {}
for cap in capas:
    for f in os.listdir(f"{FAO}/sprites/{cap}"):
        necesarias[f"shape/chr/{cap}/{f}"] = True
man = {}
with open(MANIFEST, encoding="utf-8") as fh:
    for linea in fh:
        if '"shape/chr/' not in linea:
            continue
        try:
            d = json.loads(linea)
        except ValueError:
            continue
        if d.get("file") in necesarias:
            man[d["file"]] = d
print("anclajes encontrados:", len(man), "de", len(necesarias))


def archivos_de(cap):
    """Por animación: (ruta delantera, ruta trasera) de la capa."""
    res = {}
    for anim, (nombre, pasos) in ANIMS.items():
        frente = trasera = None
        for f in sorted(os.listdir(f"{FAO}/sprites/{cap}")):
            m = re.match(r"^(\d+)_" + nombre + r"\.png$", f)
            if not m:
                continue
            cod = m.group(1)
            if cap in ("p001b", "p001g"):
                if cod in ("999", "1100"):
                    frente = f
            elif cod[:2] in ("30", "31", "32", "33", "34", "20", "21", "22", "23", "24"):
                frente = f      # los arcos usan 32xxx
            elif cod[:2] in ("35", "36", "37", "38", "39", "25", "26", "27", "28", "29"):
                trasera = f
        if frente or trasera:
            res[anim] = (frente, trasera)
    return res


# ---------------------------------------------------------------- hojas (cada una con su propia casilla, ajustada a sus cuadros)
os.makedirs(SALIDA, exist_ok=True)
total = 0
meta_capas = {}
for cap in sorted(capas):
    meta_capas[cap] = {}
    carpeta = f"{SALIDA}/{cap}"
    os.makedirs(carpeta, exist_ok=True)
    for anim, (frente, trasera) in archivos_de(cap).items():
        # las capas 35xxx/25xxx son otra variante de las mismas piezas (arma y armadura duplicadas): solo se usan las 30xxx
        for lado, archivo in (("f", frente),):
            if not archivo:
                continue
            d = man.get(f"shape/chr/{cap}/{archivo}")
            if not d:
                continue
            esperado = 5 * ANIMS[anim][1]
            validos = [fr for fr in d["frames"][:esperado] if fr.get("w")]
            if not validos:
                continue
            izq = max(fr["ox"] for fr in validos)
            der = max(fr["w"] - fr["ox"] for fr in validos)
            arr = max(fr["oy"] for fr in validos)
            aba = max(fr["h"] - fr["oy"] for fr in validos)
            cw = math.ceil((izq + der) * ESC) + 2
            ch = math.ceil((arr + aba) * ESC) + 2
            orx, ory = math.ceil(izq * ESC) + 1, math.ceil(arr * ESC) + 1
            hoja = Image.open(f"{FAO}/sprites/{cap}/{archivo}").convert("RGBA")
            cw0 = d["cell"][0]
            salida = Image.new("RGBA", (cw * esperado, ch), (0, 0, 0, 0))
            # El orden de los cuadros en la hoja sigue el NOMBRE (f?PPD: paso P, dirección D de 3 a 7), y el cuadro sin nombre es el que
            # falta (paso 1, dirección 3). Se recolocan como paso * 5 + dirección.
            destino = {}
            usados = set()
            for i, fr in enumerate(d["frames"][:esperado]):
                m = re.search(r"(\d)(\d)(\d)\.SHP$", fr.get("name", ""))
                if m:
                    pos = (int(m.group(2)) - 1) * 5 + (int(m.group(3)) - 3)
                    destino[i] = pos
                    usados.add(pos)
            libres = [k for k in range(esperado) if k not in usados]
            for i, fr in enumerate(d["frames"][:esperado]):
                if i not in destino and libres:
                    destino[i] = libres.pop(0)
            for i in range(min(esperado, hoja.size[0] // cw0, len(d["frames"]))):
                fr = d["frames"][i]
                j = destino.get(i, i)
                if not fr.get("w"):
                    continue
                recorte = hoja.crop((i * cw0, 0, i * cw0 + fr["w"], fr["h"]))
                nw, nh = max(1, round(fr["w"] * ESC)), max(1, round(fr["h"] * ESC))
                recorte = recorte.resize((nw, nh), Image.NEAREST)
                x = j * cw + max(0, round(orx - fr["ox"] * ESC))
                y = max(0, round(ory - fr["oy"] * ESC))
                salida.alpha_composite(recorte, (x, y)) if x + nw <= salida.size[0] and y + nh <= ch else salida.paste(recorte, (x, y), recorte)
            nombre = f"{ANIMS[anim][0]}_{lado}.png"
            # paleta de 128 colores con transparencia: las hojas pesan la tercera parte y el pixel art no pierde nada visible
            salida.quantize(colors=128, method=Image.FASTOCTREE, dither=Image.NONE).save(f"{carpeta}/{nombre}", optimize=True)
            total += os.path.getsize(f"{carpeta}/{nombre}")
            meta_capas[cap][f"{anim}_{lado}"] = {"w": cw, "h": ch, "x": orx, "y": ory}
print("tamaño total", total // 1024, "KB")

# ---------------------------------------------------------------- tablas para el juego
def lua(v, nivel=0):
    pad = "  " * (nivel + 1)
    if isinstance(v, dict):
        partes = [f"{pad}[{json.dumps(k)}] = {lua(x, nivel + 1)}," if not re.match(r"^[A-Za-z_]\w*$", str(k)) else f"{pad}{k} = {lua(x, nivel + 1)}," for k, x in v.items()]
        return "{\n" + "\n".join(partes) + "\n" + "  " * nivel + "}"
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, bool):
        return "true" if v else "false"
    return str(v)


tabla = {
    "esc": ESC,
    "anims": {k: {"archivo": v[0], "pasos": v[1]} for k, v in ANIMS.items()},
    "cuerpo": {g: c[0] for g, c in CUERPO.items()},
    "looks": {c: {g: {str(t): looks[c][g][t] for t in range(1, 9)} for g in GENEROS} for c in looks},
    "capas": meta_capas,
}
with open(DATOS_LUA, "w", encoding="utf-8", newline="\n") as f:
    f.write("-- GENERADO por herramientas/generar_personajes/hornear.py: qué capas lleva cada clase, género y escalón. No editar a mano.\n")
    f.write("return " + lua(tabla) + "\n")
print("escrito", DATOS_LUA)
