"""Lector de mapas de Free Angels Online (.mpc) y de los datos que los acompañan (data1.pak/update*.pak). Es la versión en Python del formato; el juego lo lee con
compartido/dominio/mapa_mpc.lua (mismas reglas). Material de un juego ajeno (FAO): solo para prototipo.

Formato (little-endian), descifrado con map002.mpc (516113 bytes):
  cabecera 96 bytes = 24 u32:  [0] 'MAP\\0'  [1] ancho en celdas  [2] alto  [3] versión 0x00010005  [4] [5] tamaño de celda en px (32, 32)
     [6] [7]   objetos: desplazamiento y NÚMERO de registros (registros de 74 bytes)
     [8] [9]   eventos: desplazamiento y bytes (u32 longitud + XML UTF-8 de <事件> con disparadores y acciones)
     [10]      1 (versión de la sección de eventos)
     [13] [14] lista de tilesets: desplazamiento y número de bytes (un byte por tileset, en decimal: brush/brush.bNN con NN en hexadecimal)
     [15] [16] diálogos: desplazamiento y bytes (u32 longitud + XML UTF-8 de <對話>)
     [17] [18] rutas: desplazamiento y bytes
     [19] [20] puntos: desplazamiento y NÚMERO de registros hasta el final del archivo
  cuadrícula en 96: ancho*alto celdas de 6 bytes: byte0 = tileset de pincel (brush/brush.bNN: una textura continua de 16x16 tiles de 32 px que se muestrea por la posición de la casilla),
     byte1 = ATRIBUTO DEL TERRENO (0 libre, 1 obstáculo: árboles, rocas, cajas; 2 agua o risco; 3 y 10 casos sueltos; es la colisión), byte2 = 0,
     byte3 = 0 o 31..44 (una zona de ~700 celdas en el mar de map002; sin uso conocido), byte4 = byte5 = 0
  objetos (74 bytes): u32 id (Sequence de setting/mapobj.obd, npc.obd o server.obd), u32 x px, u32 y px (el punto de apoyo del sprite en el suelo; x/32, y/32 = casilla),
     u32 0/50/80/400, u32 0/1/2 (bandera de espejo/animación), u32 byte bajo 0xC0 (transparencia 192) y encima un valor (paleta/tinte), y ceros
  rutas: u32 n; n * { u32 id, u32 1, u32 puntos, u32 0, puntos * (u32 x, u32 y, u32 tipo, u32 0, u32 0, u32 0)... } (hipótesis: rutas de patrulla)
  puntos: registros { u32 id, u32 n, n * (u32 x, u32 y) } hasta el final (ids 1-2: triángulos en el borde del mapa = salidas, eventos 1 y 2; 31-44: puntos sueltos;
     71-83: polígonos = zonas)
"""
import collections
import glob
import json
import os
import re
import struct
import sys
import zlib

import numpy as np

DOWNLOADS = os.environ.get("FAO_DESCARGAS", r"C:\Users\User\Downloads")


def leer(ruta):
    d = open(ruta, "rb").read()
    h = struct.unpack("<24I", d[:96])
    assert d[:4] == b"MAP\x00", "no es un .mpc"
    w, hh = h[1], h[2]
    celdas = np.frombuffer(d[96:96 + w * hh * 6], dtype=np.uint8).reshape(hh, w, 6).astype(np.int32)
    tilesets = list(d[h[13]:h[13] + h[14]])
    objetos = []
    for i in range(h[7]):
        r = d[h[6] + i * 74:h[6] + (i + 1) * 74]
        id_, x, y, a, b, c = struct.unpack("<6I", r[:24])
        objetos.append(dict(id=id_, x=x, y=y, a=a, espejo=b, c=c))
    ln = struct.unpack("<I", d[h[8]:h[8] + 4])[0]
    eventos = d[h[8] + 4:h[8] + 4 + ln].decode("utf-8", errors="replace")
    ln2 = struct.unpack("<I", d[h[15]:h[15] + 4])[0]
    dialogos = d[h[15] + 4:h[15] + 4 + ln2].decode("utf-8", errors="replace")
    # rutas
    rs = d[h[17]:h[17] + h[18]]
    n = struct.unpack("<I", rs[:4])[0]
    rutas, p = [], 4
    for _ in range(n):
        id_, uno, npts, cero = struct.unpack("<4I", rs[p:p + 16])
        p += 16
        pts = []
        for _ in range(npts):
            x, y, t, _a, _b, _c = struct.unpack("<6I", rs[p:p + 24])
            p += 24
            pts.append((x, y, t))
        rutas.append(dict(id=id_, puntos=pts))
    # puntos
    ps, p = d[h[19]:], 0
    puntos = []
    for _ in range(h[20]):
        id_, npts = struct.unpack("<2I", ps[p:p + 8])
        p += 8
        pts = []
        for _ in range(npts):
            pts.append(struct.unpack("<2I", ps[p:p + 8]))
            p += 8
        puntos.append(dict(id=id_, puntos=pts))
    return dict(w=w, h=hh, celda=h[4], celdas=celdas, tilesets=tilesets, objetos=objetos, eventos=eventos, dialogos=dialogos, rutas=rutas, puntos=puntos,
                cabecera=h, bytes=len(d), resto=len(ps) - p)


# ---------------------------------------------------------------------------------------------------------------- .pak
sys.path.insert(0, os.path.join(DOWNLOADS, "fao-sprites"))


def _pak():
    import extract_fao_sprites as x
    return x


def _orden(p):
    n = os.path.basename(p).lower()
    if n == "data1.pak":
        return -1
    m = re.match(r"update(\d*)\.pak", n)
    return int(m.group(1) or 1) if m else 999


_cache = {}


def archivos_pak(patron):
    """{nombre en minúsculas: bytes} de los archivos de los .pak que casan con el patrón (los update*.pak sobrescriben a data1.pak)."""
    x = _pak()
    clave = patron
    if clave in _cache:
        return _cache[clave]
    mejor = {}
    for p in sorted(glob.glob(os.path.join(DOWNLOADS, "*.pak")), key=_orden):
        if "music" in p.lower():
            continue
        m, ents = x.open_pak(p)
        for n, meth, cs, us, lo in ents:
            if re.search(patron, n.lower()):
                mejor[n.lower()] = x.read_entry(m, meth, cs, lo)
    _cache[clave] = mejor
    return mejor


def tileset(n, pak):
    """(paleta Nx3 uint8, tiles Nx32x32 uint8) del tileset de pincel brush/brush.bNN."""
    b = pak["brush/brush.b%02x" % n]
    pal = np.frombuffer(b[52:52 + 512], dtype="<u2").astype(np.int32)
    r, g, bl = ((pal >> 11) & 31) * 255 // 31, ((pal >> 5) & 63) * 255 // 63, (pal & 31) * 255 // 31
    pal = np.stack([r, g, bl], 1).astype(np.uint8)
    nt = (len(b) - 564) // 1024
    px = np.frombuffer(b[564:564 + nt * 1024], dtype=np.uint8).reshape(nt, 32, 32)
    return pal, px


def definiciones_objetos(pak):
    """{Sequence: {nombre, proceso, flags, directorio, sprite}} de setting/mapobj.obd + server.obd + npc.obd (scripts de sprites de FAO, texto cp950)."""
    out = {}
    for arch in ("setting/mapobj.obd", "setting/server.obd", "setting/npc.obd", "setting/common.obd", "setting/house.obd"):
        if arch not in pak:
            continue
        t = pak[arch].decode("cp950", errors="replace")
        for bloque in re.split(r"\r?\n\[OBJECT\]\r?\n", t)[1:]:
            d = {}
            for l in bloque.split("\n"):
                l = l.strip()
                if "=" in l and not l.startswith("//") and not l.startswith("["):
                    k, v = l.split("=", 1)
                    d.setdefault(k.strip(), []).append(v.split("//")[0].strip())
            if "Sequence" in d:
                try:
                    sid = int(d["Sequence"][0], 0)
                except ValueError:
                    continue
                out.setdefault(sid, dict(
                    nombre=d.get("Name", [""])[0], proceso=d.get("Process", [""])[0], flags=d.get("Flags", [""])[0],
                    directorio=d.get("Directory", [""])[0], sprite=d.get("Sprite", [""])[0], fuente=arch))
    return out
