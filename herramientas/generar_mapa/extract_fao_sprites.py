"""Extrae los sprites de los .pak de Free Angels Online a PNG y escribe su manifest.jsonl (carpeta fao-sprites).

Uso:  python -X utf8 herramientas/generar_mapa/extract_fao_sprites.py [carpeta_de_salida] [carpeta_con_los_pak]
      por defecto: C:/Users/User/Downloads/fao-sprites y C:/Users/User/Downloads (variables FAO_SPRITES y FAO_DESCARGAS)

Para cada .shp de shape/ (todos los directorios) escribe <salida>/<ruta del .shp sin extensión>.png y una línea en manifest.jsonl:
  {"file": "shape/stage/21/21-001-1u0.png", "w": ancho, "h": alto, "ox": ancla x, "oy": ancla y}
(ox, oy = posición del origen del sprite dentro de la imagen, en píxeles desde la esquina superior izquierda; los .spr, que son varios .shp con una paleta
compartida, se guardan cuadro a cuadro como <ruta>_<n>.png). Los .pak se leen juntos (data1.pak y update*.pak; gana el más nuevo).
Este módulo también ofrece open_pak / read_entry, que usaba herramientas/generar_mapa/mpc.py.

Formatos (ingeniería inversa de angel.exe; ver fao-visor/fao_visor.py):
  .pak = zip sin cabeceras locales; directorio central con zlib (1er byte ^0x7a), EOCD ^ (0xb1+3*i); datos = deflate crudo.
  .spr = 'EWSP' (varios .SHP + paleta RGB565 compartida);  .shp = 'TLHS' (filas -> tramos; paleta o RGB565 / BGR565).
Arte de un juego ajeno (FAO): prototipo, no se publica."""
import glob
import json
import mmap
import os
import re
import struct
import sys
import zlib
from multiprocessing import Pool

from PIL import Image

DESCARGAS = os.environ.get("FAO_DESCARGAS", r"C:\Users\User\Downloads")
SALIDA = os.environ.get("FAO_SPRITES", os.path.join(DESCARGAS, "fao-sprites"))


# ------------------------------------------------------------------------------------------------------------------ .pak
def open_pak(path):
    f = open(path, "rb")
    m = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
    n = len(m)
    e = bytes(a ^ ((0xb1 + 3 * i) & 255) for i, a in enumerate(m[n - 18:n]))
    cdsz, _, _, _, cdoff, _ = struct.unpack("<IHHIIH", e)
    blob = bytearray(m[cdoff + 4:cdoff + 4 + cdsz])
    blob[0] ^= 0x7a
    cd = zlib.decompress(bytes(blob))
    ents, p = [], 0
    while p < len(cd):
        (_, _, _, _, meth, _, _, _, cs, us, nl, xl, cl, _, _, _, lo) = struct.unpack("<IHHHHHHIIIHHHHHII", cd[p:p + 46])
        nombre = cd[p + 46:p + 46 + nl].decode("latin1").replace(chr(92), "/")
        ents.append((nombre, meth, cs, us, lo))
        p += 46 + nl + xl + cl
    return m, ents


def read_entry(m, meth, cs, lo):
    raw = bytes(m[lo:lo + cs])
    return zlib.decompress(raw, -15) if meth == 8 else raw


def _orden(p):
    n = os.path.basename(p).lower()
    if n == "data1.pak":
        return -1
    mm = re.match(r"update(\d*)\.pak", n)
    return int(mm.group(1) or 1) if mm else 500


def indice():
    """ruta en minúsculas -> (archivo pak, nombre, método, tamaño comprimido, offset); gana el update más nuevo."""
    idx = {}
    for p in sorted(glob.glob(os.path.join(DESCARGAS, "*.pak")), key=_orden):
        if os.path.getsize(p) < 1000 or "music" in p.lower():
            continue
        try:
            m, ents = open_pak(p)
        except Exception:
            continue
        for nombre, meth, cs, us, lo in ents:
            if not nombre.endswith("/"):
                idx[nombre.lower()] = (p, nombre, meth, cs, lo)
        m.close()
    return idx


# ------------------------------------------------------------------------------------------------------------------ imágenes
def _c565(v, bgr=False):
    r, g, b = (v >> 11 & 31) * 255 // 31, (v >> 5 & 63) * 255 // 63, (v & 31) * 255 // 31
    return (b, g, r) if bgr else (r, g, b)


def decode_shp(b, pal=None):
    if b[:4] != b"TLHS" or len(b) < 96:
        return None
    h = struct.unpack("<20I", b[:80])
    typ, fl, w, hh = h[2], h[3], h[5], h[6]
    ox, oy = struct.unpack("<ii", b[28:36])
    if not (0 < w <= 4096 and 0 < hh <= 4096) or len(b) < 80 + 4 * hh:
        return None
    filas = struct.unpack("<%dI" % hh, b[80:80 + 4 * hh])
    im = Image.new("RGBA", (w, hh), (0, 0, 0, 0))
    px = im.load()
    L = len(b)
    paletado = fl == 768 and typ == 2
    if paletado and h[16] and h[16] + 512 <= L:
        pal = [_c565(b[h[16] + 2 * i] | b[h[16] + 2 * i + 1] << 8) for i in range(256)]
    bgr = typ == 4
    for y, o in enumerate(filas):
        while o + 8 <= L:
            cnt, x, off = struct.unpack("<HHI", b[o:o + 8])
            o += 8
            if x == 0xffff or (cnt == 0 and off == 0):
                break
            for i in range(cnt):
                if x + i >= w:
                    break
                if paletado:
                    if off + i < L and pal and b[off + i] < len(pal):
                        px[x + i, y] = pal[b[off + i]] + (255,)
                else:
                    p = off + 2 * i
                    if p + 2 <= L:
                        px[x + i, y] = _c565(b[p] | b[p + 1] << 8, bgr) + (255,)
    return im, (ox, oy)


def frames_spr(b):
    """[(imagen, (ox, oy))] de un .spr ('EWSP')."""
    if b[:4] != b"EWSP":
        return []
    cnt = struct.unpack("<I", b[8:12])[0]
    pal_off = 80 + 12 * cnt
    name_off0 = struct.unpack("<I", b[80:84])[0]
    pal = [_c565(b[pal_off + 2 * i] | b[pal_off + 2 * i + 1] << 8) for i in range(max(0, (name_off0 - pal_off) // 2))]
    res = []
    for i in range(cnt):
        off, size, _ = struct.unpack("<III", b[84 + 12 * i:96 + 12 * i])
        r = decode_shp(b[off:off + size], pal)
        if r:
            res.append(r)
    return res


# ------------------------------------------------------------------------------------------------------------------ extracción
_mapas = {}


def _datos(pak, meth, cs, lo):
    if pak not in _mapas:
        f = open(pak, "rb")
        _mapas[pak] = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
    return read_entry(_mapas[pak], meth, cs, lo)


def _extraer(args):
    clave, (pak, nombre, meth, cs, lo), salida = args
    try:
        b = _datos(pak, meth, cs, lo)
        base = os.path.splitext(clave)[0]
        res = []
        if clave.endswith(".shp"):
            r = decode_shp(b)
            frames = [(base + ".png", r)] if r else []
        else:
            frames = [("%s_%d.png" % (base, i), r) for i, r in enumerate(frames_spr(b))]
        for ruta, r in frames:
            destino = os.path.join(salida, ruta.replace("/", os.sep))
            os.makedirs(os.path.dirname(destino), exist_ok=True)
            r[0].save(destino, optimize=False, compress_level=3)
            res.append(dict(file=ruta, w=r[0].width, h=r[0].height, ox=r[1][0], oy=r[1][1]))
        return res
    except Exception:
        return []


def main():
    salida = sys.argv[1] if len(sys.argv) > 1 else SALIDA
    if len(sys.argv) > 2:
        global DESCARGAS
        DESCARGAS = sys.argv[2]
    os.makedirs(salida, exist_ok=True)
    idx = indice()
    # todos los .shp de shape/ y el .spr suelto de shape/stage (los .spr de personajes y criaturas se hornean con las herramientas de cada uno)
    tareas = [(k, v, salida) for k, v in idx.items() if k.startswith("shape/") and (k.endswith(".shp") or (k.endswith(".spr") and k.startswith("shape/stage/")))]
    print(len(tareas), "archivos a extraer a", salida)
    n = 0
    with open(os.path.join(salida, "manifest.jsonl"), "w", encoding="utf-8", newline="\n") as man, Pool(max(1, (os.cpu_count() or 4) - 1)) as pool:
        for res in pool.imap_unordered(_extraer, tareas, chunksize=64):
            for r in res:
                man.write(json.dumps(r, ensure_ascii=False) + "\n")
            n += 1
            if n % 5000 == 0:
                print(n, "de", len(tareas), flush=True)
    print("listo:", n, "archivos procesados")


if __name__ == "__main__":
    main()
