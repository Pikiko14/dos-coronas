"""Lectura de los .pak de Free Angels Online (data1.pak + update*.pak) y extracción de hojas de animación para el horneado.

Formatos (ingeniería inversa de angel.exe, ver también fao-visor/fao_visor.py):
  .pak = zip sin cabeceras locales; directorio central con zlib (1er byte ^0x7a), EOCD ^ (0xb1+3*i); datos = deflate crudo.
  .spr = 'EWSP' (varios .SHP + paleta RGB565 compartida);  .shp = 'TLHS' (filas -> tramos; paleta o RGB565 / BGR565).
Carpeta de los .pak: variable FAO_PAK (por defecto C:/Users/User/Downloads). Arte de un juego ajeno (FAO): prototipo, no se publica."""
import glob
import mmap
import os
import re
import struct
import zlib

from PIL import Image

CARPETA = os.environ.get("FAO_PAK", r"C:\Users\User\Downloads")
_indice = None
_mapas = {}


def _abrir(path):
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


def _orden(p):
    n = os.path.basename(p).lower()
    if n == "data1.pak":
        return -1
    mm = re.match(r"update(\d*)\.pak", n)
    return int(mm.group(1) or 1) if mm else 500


def indice():
    """ruta en minúsculas -> (pak, nombre, método, tamaño comprimido, tamaño, offset); gana el update más nuevo."""
    global _indice
    if _indice is None:
        _indice = {}
        for p in sorted(glob.glob(os.path.join(CARPETA, "*.pak")), key=_orden):
            if os.path.getsize(p) < 1000:
                continue
            try:
                m, ents = _abrir(p)
            except Exception:
                continue
            _mapas[os.path.basename(p)] = m
            for nombre, meth, cs, us, lo in ents:
                if not nombre.endswith("/"):
                    _indice[nombre.lower()] = (os.path.basename(p), nombre, meth, cs, us, lo)
    return _indice


def datos(clave):
    pak, _, meth, cs, _, lo = indice()[clave.lower()]
    raw = bytes(_mapas[pak][lo:lo + cs])
    return zlib.decompress(raw, -15) if meth == 8 else raw


def _c565(v, bgr=False):
    r, g, b = (v >> 11 & 31) * 255 // 31, (v >> 5 & 63) * 255 // 63, (v & 31) * 255 // 31
    return (b, g, r) if bgr else (r, g, b)


def decodificar_shp(b, pal=None):
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


def cuadros_spr(clave):
    """Lista de (imagen RGBA o None, (ox, oy)) de un .spr, en el orden del archivo."""
    b = datos(clave)
    if b[:4] != b"EWSP":
        return []
    cnt = struct.unpack("<I", b[8:12])[0]
    pal_off = 80 + 12 * cnt
    name_off0 = struct.unpack("<I", b[80:84])[0]
    pal = [_c565(b[pal_off + 2 * i] | b[pal_off + 2 * i + 1] << 8) for i in range(max(0, (name_off0 - pal_off) // 2))]
    res = []
    for i in range(cnt):
        off, size, _ = struct.unpack("<III", b[84 + 12 * i:96 + 12 * i])
        r = decodificar_shp(b[off:off + size], pal)
        res.append((r[0], r[1]) if r else (None, (0, 0)))
    return res


def hoja(clave):
    """Tira horizontal con todos los cuadros de un .spr, cada uno en una celda del mismo tamaño con el origen (los pies) en el mismo sitio.
    Devuelve (imagen, ancho de celda, cuadros)."""
    cuadros = cuadros_spr(clave)
    validos = [(im, o) for im, o in cuadros if im is not None]
    if not validos:
        return None
    izq = max(o[0] for im, o in validos)
    der = max(im.width - o[0] for im, o in validos)
    arr = max(o[1] for im, o in validos)
    aba = max(im.height - o[1] for im, o in validos)
    cw, ch = izq + der, arr + aba
    tira = Image.new("RGBA", (cw * len(cuadros), ch), (0, 0, 0, 0))
    for i, (im, o) in enumerate(cuadros):
        if im is not None:
            tira.alpha_composite(im, (i * cw + izq - o[0], arr - o[1]))
    return tira, cw, len(cuadros)


def hojas_criatura(codigo, destino):
    """Escribe destino/<código>_<anim>.png para wait, run, att, hurt y dead de la criatura m####. Las celdas de todas las animaciones comparten
    tamaño y origen. Devuelve el número de cuadros de cada una."""
    os.makedirs(destino, exist_ok=True)
    claves = {}
    for k in indice():
        m = re.match(r"shape/mon/%s/(\d+)_(\w+)\.spr$" % re.escape(codigo.lower()), k)
        if m:
            claves[m.group(2)] = k
    todas = {a: cuadros_spr(claves[a]) for a in ("wait", "run", "att", "hurt", "dead") if a in claves}
    cuenta = {}
    for anim, cs in todas.items():
        # celda propia de cada animación (el juego lee el tamaño de cada tira); el origen (los pies) va en el centro: así se dibuja centrada
        validos = [(im, o) for im, o in cs if im is not None]
        izq = max(o[0] for im, o in validos)
        der = max(im.width - o[0] for im, o in validos)
        arr = max(o[1] for im, o in validos)
        aba = max(im.height - o[1] for im, o in validos)
        mitad = max(izq, der)
        cw, ch = 2 * mitad, arr + aba
        tira = Image.new("RGBA", (cw * len(cs), ch), (0, 0, 0, 0))
        for i, (im, o) in enumerate(cs):
            if im is not None:
                tira.alpha_composite(im, (i * cw + mitad - o[0], arr - o[1]))
        tira.save(os.path.join(destino, "%s_%s.png" % (codigo.lower(), anim)))
        cuenta[anim] = len(cs)
    return cuenta
