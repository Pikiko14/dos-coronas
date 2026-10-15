"""Hornea el equipo FAO por etapas (fao-equipos) para el juego, con el mismo layout que hornear.py.

Uso:  python herramientas/generar_personajes/hornear_equipos.py [carpeta_fao_equipos]

Lee fao-equipos/clases.json (por defecto ../arte-fuente/fao-equipos, fuera del proyecto) (cada clase tiene 5 etapas: niveles 1, 8, 15, 22 y 30, con arma y set de cabeza, torso, guantes y botas),
las hojas originales de sprites_piezas/ y sus anclas (sprites_piezas/anclas.json: celda y, por cuadro, w, h, ox, oy). Escribe SOLO las capas
usadas en juego/arte/fao/<capa>/<Anim>_f.png (todos los cuadros de la animación en una fila, recolocados en una casilla común cuyo origen son
los pies) y regenera juego/src/presentacion/render/fao_datos.lua (qué capas lleva cada clase, género y escalón de equipo, y las medidas).

Orden de los cuadros de una hoja (comprobado contra los nombres de las 3.314 hojas): para una animación de P pasos, los cuadros van
  paso 1 con las direcciones 4, 5, 6, 7; paso 2 con 3, 4, 5, 6, 7; ... paso P con 3..7; y al final el cuadro que falta, paso 1 dirección 3.
Se recolocan como indice = (paso - 1) * 5 + (direccion - 3), es decir cuadro = paso * 5 + hoja de dirección, con las hojas: 0 frente, 1 espalda,
2 espalda-izquierda, 3 izquierda, 4 frente-izquierda (las otras tres direcciones del juego se obtienen volteando 4, 3 y 2). Las capas con código +5000 (35xxx, 85xxx...) son del personaje montado: no se usan.

Escalones del juego (1 a 8) -> etapas FAO (1 a 5): 1->1, 2->2, 3->2, 4->3, 5->3, 6->4, 7->4, 8->5."""
import json, math, os, re, sys
from PIL import Image

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FUENTE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(RAIZ, "..", "arte-fuente", "fao-equipos")      # fuera del proyecto
SALIDA = os.path.join(RAIZ, "juego", "arte", "fao")
DATOS_LUA = os.path.join(RAIZ, "juego", "src", "presentacion", "render", "fao_datos.lua")
ESC = 1.0                                  # las hojas van a tamaño original: el juego las dibuja a la mitad (ESCALA_JUEGO) con filtro suave

# animaciones que se hornean: nombre en el juego -> (nombre en el arte, pasos normales)
ANIMS = {"wait": ("Wait", 3), "run": ("Run", 6), "att": ("Att", 4), "att2": ("Att2", 4), "att3": ("Att3", 4), "cast": ("Cast", 3),
         "sht": ("Sht", 4), "hurt": ("Hurt", 2), "dead": ("Dead", 6)}

CLASES = {"guerrero": "guerrero", "lancero": "lancero", "cazador": "arquero", "mago": "mago", "clerigo": "sacerdote", "nigromante": "invocador"}
# familias de arma del juego que se dibujan con el arma de la etapa
ARMAS = {"guerrero": ["espada", "hacha"], "lancero": ["lanza"], "cazador": ["arco"], "mago": ["baston"], "clerigo": ["maza"], "nigromante": ["baculo"]}
HUECOS = {"pecho": "body", "cabeza": "head", "piernas": "hands", "pies": "feet"}      # hueco del juego -> pieza FAO
ESCALON_A_ETAPA = {1: 1, 2: 2, 3: 2, 4: 3, 5: 3, 6: 4, 7: 4, 8: 5}
CUERPO = {"h": ("p001b", "999"), "m": ("p001g", "1100")}

datos = json.load(open(os.path.join(FUENTE, "clases.json"), encoding="utf-8"))
anclas = json.load(open(os.path.join(FUENTE, "sprites_piezas", "anclas.json"), encoding="utf-8"))

# carpetas reales (mayúsculas y minúsculas mezcladas) por nombre en minúsculas
carpetas = {d.lower(): d for d in os.listdir(os.path.join(FUENTE, "sprites_piezas")) if os.path.isdir(os.path.join(FUENTE, "sprites_piezas", d))}


def genero_de(carpeta):
    m = re.search(r"\d([bg])l?$", carpeta.lower())
    return m.group(1) if m else None


def elegir_carpeta(lista, gen):
    """De las carpetas de una pieza (i001b, i001bl, i001g, i001gl) la del género pedido; la variante 'l' solo si no hay otra."""
    letra = "b" if gen == "h" else "g"
    propias = [c for c in lista if genero_de(c) == letra and c.lower() in carpetas]
    propias.sort(key=lambda c: c.lower().endswith("l"))
    return propias[0].lower() if propias else None


def codigo_delantero(carpeta):
    """Código de la capa delantera de una carpeta: el menor (el +5000 es del personaje montado)."""
    d = os.path.join(FUENTE, "sprites_piezas", carpetas[carpeta])
    codigos = sorted({int(m.group(1)) for f in os.listdir(d) for m in [re.match(r"^(\d+)_", f)] if m})
    return codigos[0] if codigos else None


def archivo_de(carpeta, codigo, anim):
    d = os.path.join(FUENTE, "sprites_piezas", carpetas[carpeta])
    nombre = ANIMS[anim][0].lower()
    for f in os.listdir(d):
        if f.lower() == f"{codigo}_{nombre}.png":
            return f
    return None


# ---------------------------------------------------------------- qué capas lleva cada clase, género y escalón
looks = {}
capas = {}                              # capa (carpeta en minúsculas) -> código delantero
for clase, fao in CLASES.items():
    looks[clase] = {}
    etapas = {e["nivel"]: e for e in datos["clases"][fao]["etapas"]}
    niveles = sorted(etapas)
    for gen in ("h", "m"):
        looks[clase][gen] = {}
        for esc in range(1, 9):
            e = etapas[niveles[ESCALON_A_ETAPA[esc] - 1]]
            fila = {"arma": {}}
            for hueco, pieza in HUECOS.items():
                p = e["armadura"].get(pieza)
                c = p and elegir_carpeta(p["carpetas_sprite"], gen)
                if c:
                    fila[hueco] = c
                    capas[c] = None
            c = elegir_carpeta(e["arma"]["carpetas_sprite"], gen)
            if c:
                for fam in ARMAS[clase]:
                    fila["arma"][fam] = c
                capas[c] = None
            looks[clase][gen][str(esc)] = fila
for gen, (carp, cod) in CUERPO.items():
    capas[carp] = int(cod)
for c in capas:
    if capas[c] is None:
        capas[c] = codigo_delantero(c)
print("capas distintas:", len(capas))

# ---------------------------------------------------------------- hornear cada hoja
if os.path.isdir(SALIDA):
    for r, _, fs in os.walk(SALIDA, topdown=False):
        for f in fs:
            os.remove(os.path.join(r, f))
        os.rmdir(r)
os.makedirs(SALIDA, exist_ok=True)
meta_capas = {}
total = 0
for cap, cod in sorted(capas.items()):
    meta_capas[cap] = {}
    for anim in ANIMS:
        arch = archivo_de(cap, cod, anim)
        if not arch:
            continue
        clave = f"{carpetas[cap]}/{arch}"
        a = anclas.get(clave)
        if not a:
            continue
        frames = a["frames"]
        pasos = len(frames) // 5
        validos = [fr for fr in frames if fr.get("w")]
        if not validos or pasos < 1:
            continue
        izq = max(fr["ox"] for fr in validos)
        der = max(fr["w"] - fr["ox"] for fr in validos)
        arr = max(fr["oy"] for fr in validos)
        aba = max(fr["h"] - fr["oy"] for fr in validos)
        cw = math.ceil((izq + der) * ESC) + 2
        ch = math.ceil((arr + aba) * ESC) + 2
        orx, ory = math.ceil(izq * ESC) + 1, math.ceil(arr * ESC) + 1
        hoja = Image.open(os.path.join(FUENTE, "sprites_piezas", clave)).convert("RGBA")
        cw0 = a["cell"][0]
        salida = Image.new("RGBA", (cw * pasos * 5, ch), (0, 0, 0, 0))
        n = len(frames)
        for i, fr in enumerate(frames):
            if not fr.get("w"):
                continue
            # posición de este cuadro: ver la cabecera del archivo (el último es el paso 1, dirección 3)
            if i == n - 1:
                j = 0                                   # el cuadro que falta: paso 1, dirección 3
            elif i < 4:
                j = i + 1                               # paso 1, direcciones 4 a 7
            else:
                k = i - 4
                j = (1 + k // 5) * 5 + k % 5            # pasos 2.., direcciones 3 a 7
            recorte = hoja.crop((i * cw0, 0, i * cw0 + fr["w"], fr["h"]))
            x = j * cw + max(0, round(orx - fr["ox"] * ESC))
            y = max(0, round(ory - fr["oy"] * ESC))
            salida.alpha_composite(recorte, (x, y))
        carpeta = os.path.join(SALIDA, cap)
        os.makedirs(carpeta, exist_ok=True)
        ruta = os.path.join(carpeta, ANIMS[anim][0] + "_f.png")
        salida.quantize(colors=128, method=Image.FASTOCTREE, dither=Image.NONE).save(ruta, optimize=True)
        total += os.path.getsize(ruta)
        meta_capas[cap][anim + "_f"] = {"w": cw, "h": ch, "x": orx, "y": ory, "pasos": pasos}
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
    "looks": looks,
    "capas": meta_capas,
}
with open(DATOS_LUA, "w", encoding="utf-8", newline="\n") as f:
    f.write("-- GENERADO por herramientas/generar_personajes/hornear_equipos.py: qué capas lleva cada clase, género y escalón. No editar a mano.\n")
    f.write("return " + lua(tabla) + "\n")
print("escrito", DATOS_LUA)
