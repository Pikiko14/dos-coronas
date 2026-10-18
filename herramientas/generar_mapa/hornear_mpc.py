"""Hornea un mapa de Free Angels Online (.mpc) para Dos Coronas: copia el .mpc al proyecto, y genera el atlas del suelo, el atlas de objetos y un archivo de datos Lua.
Material de un juego ajeno (FAO): prototipo. El cargador del juego (compartido/dominio/mapa_mpc.lua) es genérico: para otro mapa basta correr esta herramienta con su .mpc.

Uso:  python herramientas/generar_mapa/hornear_mpc.py [mapa ...]          (por defecto: 2 -> map002.mpc)

Salida (por mapa NNN):
  compartido/datos/mapas_fao/mapNNN.mpc          copia del mapa (los .mpc que usa el juego viven dentro del proyecto, no en Descargas)
  compartido/datos/mapas_fao/mapNNN_datos.lua     datos horneados: tipo y colisión de cada tile usado, atlas, objetos (sprite, ancla, huella, bloqueo), ids inertes
  juego/arte/mapas_fao/mapNNN_suelo.png           atlas del suelo: la textura continua de 512x512 de cada tileset usado, con 2 px de borde del lado contrario (sin costuras)
  juego/arte/mapas_fao/mapNNN_objetos.png         atlas de los sprites de objetos (shape/stage), reducidos a ESC_OBJ (0,75, igual que arte/mapa/ de las casas y los árboles)

Reescalado: el suelo de FAO son texturas pintadas (no pixel art) de 16x16 tiles; el juego hornea el suelo en bloques al doble de resolución (ESC_BLOQUE = 2) y las dibuja a escala 1 (un píxel de la textura = 2 de canvas,
con filtro bilineal: en una textura pintada no se nota). Los objetos se reducen a 0,75 (FAO los dibuja a 64 px de paso por casilla; el juego a 24, y el zoom normal
es 2) con alfa premultiplicado para no dejar halos oscuros; el cargador los dibuja a 0,5 para que cada píxel de pantalla salga de un píxel real."""
import json
import math
import os
import re
import shutil
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import mpc
import reglas_mpc as R

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MAPAS = os.environ.get("FAO_MAPAS", os.path.join(mpc.DOWNLOADS, "map"))
DATOS = os.path.join(RAIZ, "compartido", "datos", "mapas_fao")
ARTE = os.path.join(RAIZ, "juego", "arte", "mapas_fao")
SPRITES = os.path.join(mpc.DOWNLOADS, "fao-sprites")
ESC_OBJ = 1.0
ANCHO_ATLAS = 2048
PAD = 2


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if v is None:
        return "nil"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return ("%.3f" % v).rstrip("0").rstrip(".")
    if isinstance(v, str):
        return '"%s"' % v.replace("\\", "\\\\").replace('"', '\\"')
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua(x) for x in v) + " }"
    if isinstance(v, dict):
        return "{ " + ", ".join("%s = %s" % (k if str(k).isidentifier() else "[%s]" % (k if isinstance(k, int) else lua(k)), lua(x)) for k, x in v.items()) + " }"
    raise TypeError(type(v))


def reducir(im, k):
    a = np.asarray(im.convert("RGBA")).astype(np.float32) / 255.0
    pm = a.copy()
    pm[:, :, :3] *= pm[:, :, 3:4]
    w, h = max(1, round(im.width * k)), max(1, round(im.height * k))
    r = np.stack([np.asarray(Image.fromarray(pm[:, :, c], "F").resize((w, h), Image.LANCZOS)) for c in range(4)], axis=2)
    al = np.clip(r[:, :, 3:4], 0, 1)
    rgb = np.where(al > 1e-4, r[:, :, :3] / np.maximum(al, 1e-4), 0)
    return Image.fromarray((np.concatenate([np.clip(rgb, 0, 1), al], axis=2) * 255 + 0.5).astype(np.uint8), "RGBA")


def sprites_de(d):
    """Cuadros y tiempos de la línea 'Sprite = Wait, #8, 27-021-1U1, #14, 27-021-1U2...' ([(nombre, retardo)]; sin retardo = 1)."""
    t = d["sprite"]
    if not t.lower().startswith("wait"):
        return []
    out, ret = [], 0
    for tok in [x.strip() for x in t.split(",")][1:]:
        if tok.startswith("#"):
            try:
                ret = int(tok[1:])
            except ValueError:
                pass
        elif re.fullmatch(r"[0-9A-Za-z]+-[0-9A-Za-z]+-[0-9A-Za-z]+", tok):
            out.append((tok, ret))
    return out


def sin_costura(t):
    """Hace repetible una textura HxWx3 (float32): mezcla con ella misma desplazada medio periodo, con una ventana sen^2 que vale 1 en el centro y 0 en los bordes, así los bordes opuestos coinciden."""
    H, W = t.shape[:2]
    w = lambda n: np.sin(np.pi * (np.arange(n) + .5) / n) ** 2
    M = (w(H)[:, None] * w(W)[None, :])[..., None]
    R = np.roll(t, (H // 2, W // 2), (0, 1))
    return M * t + (1 - M) * R


def costura(t):
    """Medida de la costura (H, V): |última columna - primera| medio / diferencia media entre columnas vecinas (y lo mismo en filas)."""
    t = t.astype(np.float32)
    h = np.abs(t[:, -1] - t[:, 0]).mean() / max(1e-6, np.abs(np.diff(t, axis=1)).mean())
    v = np.abs(t[-1] - t[0]).mean() / max(1e-6, np.abs(np.diff(t, axis=0)).mean())
    return h, v


def hornear(num):
    ruta = os.path.join(MAPAS, "map%03d.mpc" % num)
    if not os.path.exists(ruta):          # (mapas enviados desde el editor: ya están junto a los datos del juego)
        ruta = os.path.join(DATOS, "map%03d.mpc" % num)
    m = mpc.leer(ruta)
    W, H = m["w"], m["h"]
    pak = mpc.archivos_pak(r"brush/brush\.b[0-9a-f]{2}$|setting/(mapobj|server|npc|common|house)\.obd$")
    defs = mpc.definiciones_objetos(pak)
    os.makedirs(DATOS, exist_ok=True)
    os.makedirs(ARTE, exist_ok=True)
    if os.path.abspath(ruta) != os.path.abspath(os.path.join(DATOS, "map%03d.mpc" % num)):
        shutil.copyfile(ruta, os.path.join(DATOS, "map%03d.mpc" % num))

    # ------------------------------------------------------------------ suelo: cada tileset de pincel es una textura continua (16x16 tiles de 32 px = 512x512; la 8x8 es de 256x256 y se repite)
    # que se muestrea por la posición de la casilla ((x mod 16) * 32, (y mod 16) * 32); el byte 1 de la celda NO es un índice de tile sino el atributo del terreno (0 libre, 1 obstáculo, 2 agua/risco...)
    usados = sorted({int(t) for t in m["celdas"][:, :, 0].flatten()})
    LADO, borde = 512, PAD
    celda_at = LADO + 2 * borde
    cols = 4
    filas = (len(usados) + cols - 1) // cols
    atlas = Image.new("RGBA", (cols * celda_at, filas * celda_at), (0, 0, 0, 0))
    tilesets = {}
    for k, t in enumerate(usados):
        pal, px = mpc.tileset(t, pak)
        lado_tiles = int(round(len(px) ** 0.5))
        tex0 = pal[px.reshape(lado_tiles, lado_tiles, 32, 32).transpose(0, 2, 1, 3).reshape(lado_tiles * 32, lado_tiles * 32)]
        tex = np.clip(sin_costura(tex0.astype(np.float32)) + 0.5, 0, 255).astype(np.uint8)     # repetible: sus bordes opuestos no coinciden en el original
        reps = LADO // tex.shape[0]
        tex = np.tile(tex, (reps, reps, 1))                         # (la de 8x8 se repite 2x2: el periodo sigue dividiendo a 16)
        marco = np.pad(tex, ((borde, borde), (borde, borde), (0, 0)), mode="wrap")     # borde del lado contrario: sin costuras al filtrar
        x, y = (k % cols) * celda_at, (k // cols) * celda_at
        atlas.paste(Image.fromarray(marco, "RGB"), (x, y))
        medio = tex0.reshape(-1, 3).mean(0)                          # (la clase y el color salen de la textura original)
        clase, _ = R.clase_tile(medio)
        tilesets[t] = dict(clase=clase, color=[int(v) for v in medio], x=x + borde, y=y + borde)
    atlas.convert("RGB").save(os.path.join(ARTE, "map%03d_suelo.png" % num), optimize=True)
    paso = celda_at

    # ------------------------------------------------------------------ objetos
    man = {}
    for l in open(os.path.join(SPRITES, "manifest.jsonl"), encoding="utf-8"):
        r = json.loads(l)
        if r["file"].startswith("shape/stage/"):
            man[r["file"].lower()] = r
    ids = sorted({o["id"] for o in m["objetos"]})
    objetos, inertes, marcos = {}, [], []
    for sid in ids:
        d = defs.get(sid)
        if d is None or d["fuente"] != "setting/mapobj.obd" or "HIDE" in d["flags"] or "SKIP_RENDER" in d["flags"]:
            inertes.append(sid)           # marcas y generadores del servidor, NPC, luces: no se dibujan ni se conectan
            continue
        carpeta = d["directorio"].replace(chr(92), "/").strip("/")
        cuadros = []
        for nombre, ret in sprites_de(d):
            f = man.get("shape/%s/%s.png" % (carpeta, nombre.lower()))
            if f is not None:
                cuadros.append((nombre, ret, f))
        if not cuadros:
            inertes.append(sid)
            continue
        fr = []
        for nombre, ret, f in cuadros:
            im = Image.open(os.path.join(SPRITES, f["file"])).convert("RGBA")
            red = reducir(im, ESC_OBJ)
            fr.append(dict(nombre=nombre, ret=ret, im=red, ox=f["ox"] * ESC_OBJ, oy=f["oy"] * ESC_OBJ, w=f["w"]))
        # sombra: FAO guarda la sombra de cada pieza en otro sprite (el mismo nombre acabado en US en vez de U0): una silueta negra con el mismo ancla
        sombra = None
        if "SHADOW" in d["flags"] and len(fr) == 1 and fr[0]["nombre"].upper().endswith("U0"):
            nom_s = fr[0]["nombre"][:-2] + "US"
            fs = man.get("shape/%s/%s.png" % (carpeta, nom_s.lower()))
            if fs is not None:
                sombra = dict(im=reducir(Image.open(os.path.join(SPRITES, fs["file"])).convert("RGBA"), ESC_OBJ), ox=fs["ox"] * ESC_OBJ, oy=fs["oy"] * ESC_OBJ)
        ancho = fr[0]["w"]
        bloquea = R.objeto_bloquea(d)
        objetos[sid] = dict(n=d["nombre"], c=d["proceso"].replace("SP_CLASS_MAPOBJ_", ""), b=bloquea, huella=R.huella(ancho) if bloquea else 0,
                            p=R.es_plano(d), z="ZBUFFER" in d["flags"], mezcla="add" if ("WHITELIGHT" in d["flags"] or "ALPHA" in d["flags"]) else "normal", cuadros=len(fr), _fr=fr, _sombra=sombra)
        for k, f in enumerate(fr):
            marcos.append((sid, k, f["im"], f["ox"], f["oy"]))
        if sombra:
            marcos.append((sid, -1, sombra["im"], sombra["ox"], sombra["oy"]))
    # estantes
    x = y = alto_fila = 0
    colocados = []
    for sid, k, im, ox, oy in marcos:
        if x + im.width + PAD > ANCHO_ATLAS:
            x, y, alto_fila = 0, y + alto_fila + PAD, 0
        colocados.append((sid, k, im, x, y, ox, oy))
        x += im.width + PAD
        alto_fila = max(alto_fila, im.height)
    alto = y + alto_fila + PAD
    atl = Image.new("RGBA", (ANCHO_ATLAS, max(4, alto)), (0, 0, 0, 0))
    for sid, k, im, x, y, ox, oy in colocados:
        atl.alpha_composite(im, (x, y))
        o = objetos[sid]
        if k < 0:
            o["s"] = [x, y, im.width, im.height, round(ox, 1), round(oy, 1)]
        else:
            o.setdefault("f", []).append([x, y, im.width, im.height, round(ox, 1), round(oy, 1), o["_fr"][k]["ret"]])
    atl.save(os.path.join(ARTE, "map%03d_objetos.png" % num), optimize=True)
    for o in objetos.values():
        del o["_fr"]
        del o["_sombra"]

    # ------------------------------------------------------------------ escena de FAO (nombre, música, clima)
    nombre = "map%03d" % num
    musica = clima = None
    stage = os.path.join(mpc.DOWNLOADS, "setting", "eng", "stage.xml")
    if os.path.exists(stage):
        t = open(stage, encoding="utf-8").read()
        mm = re.search(r'編號="%d" 名稱="([^"]*)"[^>]*?配樂檔1="([^"]*)"[^>]*?天氣="(\d+)"' % num, t)
        if mm:
            nombre, musica, clima = mm.group(1), mm.group(2).replace(chr(92), "/"), int(mm.group(3))
    datos = dict(
        id=num, nombre=nombre, musica=musica, clima=clima, ancho=W, alto=H,
        atlasSuelo=dict(archivo="map%03d_suelo.png" % num, lado=LADO, ancho=cols * celda_at, alto=filas * celda_at),
        atlasObjetos=dict(archivo="map%03d_objetos.png" % num, esc=ESC_OBJ, ancho=ANCHO_ATLAS, alto=max(4, alto)),
        tilesets=tilesets, objetos=objetos, inertes=inertes,
    )
    with open(os.path.join(DATOS, "map%03d_datos.lua" % num), "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERADO por herramientas/generar_mapa/hornear_mpc.py (arte y datos de Free Angels Online: material de prototipo, no publicar sin sustituirlos). No editar a mano.\n")
        f.write("-- tiles[tileset*256 + índice] = { clase, bloquea, índice en el atlas del suelo, color medio }\n")
        f.write("-- objetos[id] = { n nombre, c clase de FAO, b bloquea, z tiene ZBUFFER (se ordena con los personajes por profundidad), p plana (se dibuja en la capa del suelo, bajo los personajes), huella (casillas a lo ancho), mezcla, cuadros, f = { {x, y, w, h, ox, oy, retardo}... } en el atlas, s = su sombra {x, y, w, h, ox, oy} si la tiene }\n")
        f.write("-- inertes = ids del .mpc que no se dibujan ni se conectan (marcas y generadores del servidor, NPC, luces)\n")
        f.write("return " + lua(datos) + "\n")
    print("map%03d: %d celdas, %d tilesets, %d objetos (%d tipos dibujables, %d ids inertes), atlas suelo %dx%d, atlas objetos %dx%d" % (
        num, W * H, len(usados), len(m["objetos"]), len(objetos), len(inertes), atlas.width, atlas.height, atl.width, atl.height))
    return datos


if __name__ == "__main__":
    for n in ([int(a) for a in sys.argv[1:]] or [2]):
        hornear(n)
