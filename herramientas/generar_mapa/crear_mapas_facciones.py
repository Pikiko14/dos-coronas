"""Crea con el editor de mapas (fao-editor-mapas) dos mapas de FAO para las facciones y los envía a Dos Coronas:

  61  jardin_amanecer   Jardines del Amanecer (Albor, la luz): praderas con flores, plaza con fuente, caminos de arena, lago y bosque de cerezos.
  62  necropolis_ocaso  Necrópolis del Ocaso (Umbra): plaza ritual con altar, cementerio, cripta, estanque espectral y riscos de piedra oscura.

Uso:  python -X utf8 herramientas/generar_mapa/crear_mapas_facciones.py [albor|umbra|todos] [--sin-enviar]
Necesita el editor (carpeta fao-editor-mapas, por defecto en Descargas), los .pak de FAO en Descargas, Pillow y numpy.
Escribe vistas previas en <editor>/salida/previa_<nombre>.png. Los mapas salen siempre iguales (semilla fija)."""
import io, json, math, os, random, sys

EDITOR = os.environ.get("FAO_EDITOR", r"C:\Users\User\Downloads\fao-editor-mapas")
DESCARGAS = os.environ.get("FAO_DESCARGAS", r"C:\Users\User\Downloads")
sys.path.insert(0, EDITOR)
args = [a for a in sys.argv[1:] if not a.startswith("--")]
ENVIAR = "--sin-enviar" not in sys.argv
sys.argv = ["x", DESCARGAS]
import numpy as np
from PIL import Image
import editor_mapas as E

W, H = 200, 130            # celdas de 32 px (un mapa de 100 x 65 casillas del juego)
CX, CY = 100, 62           # centro


# ------------------------------------------------------------------ utilidades
def ruido(seed, escala, w=W, h=H):
    """Ruido suave en [0, 1] (valores aleatorios en una rejilla gruesa, interpolados)."""
    rng = np.random.RandomState(seed)
    gw, gh = int(w / escala) + 3, int(h / escala) + 3
    g = rng.rand(gh, gw)
    ys, xs = np.mgrid[0:h, 0:w]
    fx, fy = xs / escala, ys / escala
    x0, y0 = fx.astype(int), fy.astype(int)
    tx, ty = fx - x0, fy - y0
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = g[y0, x0] * (1 - tx) + g[y0, x0 + 1] * tx
    b = g[y0 + 1, x0] * (1 - tx) + g[y0 + 1, x0 + 1] * tx
    return a * (1 - ty) + b * ty


class Mapa:
    def __init__(self, nombre, num, base, semilla):
        self.nombre, self.num = nombre, num
        self.rng = random.Random(semilla)
        self.sem = semilla
        self.ts = np.full((H, W), base, dtype=np.uint8)
        self.attr = np.zeros((H, W), dtype=np.uint8)
        self.objetos = []                                  # [id, x_px, y_px]
        self.camino = np.zeros((H, W), dtype=bool)         # caminos y plazas (nada bloquea ahí)
        self.agua = np.zeros((H, W), dtype=bool)
        self.occ = np.zeros((H, W), dtype=bool)            # sitio ya ocupado por objetos grandes
        self.camps = []
        self.puntos = []

    # --- terreno
    def disco(self, cx, cy, r, ts, mascara=None, borde=0.0, semilla=0):
        ys, xs = np.mgrid[0:H, 0:W]
        d = np.hypot(xs - cx, ys - cy)
        if borde:
            d = d + (ruido(semilla + 7, 6) - 0.5) * borde
        m = d < r
        self.ts[m] = ts
        if mascara is not None:
            mascara[m] = True
        return m

    def elipse(self, cx, cy, rx, ry, ts, mascara=None, borde=0.0, semilla=0):
        ys, xs = np.mgrid[0:H, 0:W]
        d = np.hypot((xs - cx) / rx, (ys - cy) / ry) * ((rx + ry) / 2)
        if borde:
            d = d + (ruido(semilla + 11, 7) - 0.5) * borde
        m = d < (rx + ry) / 2
        self.ts[m] = ts
        if mascara is not None:
            mascara[m] = True
        return m

    def sendero(self, pts, ancho, ts, pasos=160):
        """Camino que pasa por los puntos (curva suave de Catmull-Rom)."""
        P = [pts[0]] + list(pts) + [pts[-1]]
        ys, xs = np.mgrid[0:H, 0:W]
        for i in range(1, len(P) - 2):
            p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
            for k in range(pasos // max(1, len(pts) - 1)):
                t = k / (pasos // max(1, len(pts) - 1))
                x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t * t + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t ** 3)
                y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t * t + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t ** 3)
                x0, x1, y0, y1 = int(max(0, x - ancho)), int(min(W, x + ancho + 1)), int(max(0, y - ancho)), int(min(H, y + ancho + 1))
                sub = np.hypot(xs[y0:y1, x0:x1] - x, ys[y0:y1, x0:x1] - y) < ancho / 2 + (ruido(self.sem + 3, 5)[y0:y1, x0:x1] - 0.5) * 1.6
                self.ts[y0:y1, x0:x1][sub] = ts
                self.camino[y0:y1, x0:x1][sub] = True

    # --- objetos
    def libre(self, cx, cy, r, margen_camino=0):
        x0, x1, y0, y1 = int(cx - r), int(cx + r) + 1, int(cy - r), int(cy + r) + 1
        if x0 < 2 or y0 < 2 or x1 > W - 2 or y1 > H - 2:
            return False
        if self.occ[y0:y1, x0:x1].any() or self.agua[y0:y1, x0:x1].any():
            return False
        if margen_camino:
            a, b, c, d = max(0, x0 - margen_camino), min(W, x1 + margen_camino), max(0, y0 - margen_camino), min(H, y1 + margen_camino)
            if self.camino[c:d, a:b].any():
                return False
        return True

    def poner(self, oid, cx, cy, r=0, bloquea=False, ancho=1, marca=True):
        """Pone un objeto con la base en la celda (cx, cy) (decimales vale). r = radio que reserva; bloquea = cierra su casilla (atributo 1)."""
        self.objetos.append([oid, int(round(cx * 32)), int(round(cy * 32))])
        if r:
            x0, x1, y0, y1 = max(0, int(cx - r)), min(W, int(cx + r) + 1), max(0, int(cy - r)), min(H, int(cy + r) + 1)
            self.occ[y0:y1, x0:x1] = True
        if bloquea:
            x0, x1 = int(math.floor(cx - ancho / 2)), int(math.ceil(cx + ancho / 2))
            for yy in (int(cy) - 1, int(cy)):
                for xx in range(x0, max(x1, x0 + 1)):
                    if 0 <= xx < W and 0 <= yy < H and self.attr[yy, xx] == 0:
                        self.attr[yy, xx] = 1

    def esparcir(self, ids, n, zona, r, bloquea=False, ancho=1, margen_camino=0, intentos=40, pesos=None, ruido_min=None):
        """Reparte n objetos al azar dentro de la máscara `zona` sin que se pisen."""
        puestos = 0
        ys, xs = np.nonzero(zona)
        if len(xs) == 0:
            return 0
        for _ in range(n * intentos):
            if puestos >= n:
                break
            k = self.rng.randrange(len(xs))
            cx, cy = xs[k] + self.rng.random(), ys[k] + self.rng.random()
            if ruido_min is not None and ruido_min[int(cy), int(cx)] < 0.5:
                continue
            if not self.libre(cx, cy, r, margen_camino):
                continue
            oid = self.rng.choices(ids, weights=pesos)[0] if pesos else self.rng.choice(ids)
            self.poner(oid, cx, cy, r, bloquea, ancho)
            puestos += 1
        return puestos

    def anillo(self, ids, cx, cy, radio, n, r=1, fase=0, bloquea=False, ancho=1, y_extra=0):
        for i in range(n):
            a = fase + i * 2 * math.pi / n
            self.poner(self.rng.choice(ids) if isinstance(ids, list) else ids, cx + math.cos(a) * radio, cy + math.sin(a) * radio * 0.92 + y_extra, r, bloquea, ancho)

    def agua_en(self, mascara, profunda=True):
        self.agua |= mascara
        if profunda:
            self.attr[mascara & (self.attr == 0)] = 2

    def borde_bosque(self, ancho_base, variacion, hueco=None):
        """Máscara del borde del mapa (grosor variable) menos huecos."""
        ys, xs = np.mgrid[0:H, 0:W]
        d = np.minimum.reduce([xs, ys, W - 1 - xs, H - 1 - ys]).astype(float)
        grosor = ancho_base + (ruido(self.sem + 21, 9) - 0.5) * variacion
        m = d < grosor
        if hueco is not None:
            m &= ~hueco
        return m


# ------------------------------------------------------------------ exportar y vista previa
def previa(m, ruta, escala=0.5):
    celda = int(32 * escala)
    img = np.zeros((H * celda, W * celda, 3), dtype=np.uint8)
    cache = {}
    for ty in range(H):
        for tx in range(W):
            n = int(m.ts[ty, tx])
            if n not in cache:
                t = E.tileset(n)
                cache[n] = np.asarray(t[0].resize((16 * celda, 16 * celda), Image.BILINEAR)) if t else np.zeros((16 * celda, 16 * celda, 3), np.uint8)
            tex = cache[n]
            u, v = (tx % 16) * celda, (ty % 16) * celda
            img[ty * celda:(ty + 1) * celda, tx * celda:(tx + 1) * celda] = tex[v:v + celda, u:u + celda]
    im = Image.fromarray(img, "RGB").convert("RGBA")
    for oid, x, y in sorted(m.objetos, key=lambda o: o[2]):
        r = E.sprite_obj(oid)
        if not r:
            continue
        sp = Image.open(io.BytesIO(r[0])).convert("RGBA")
        meta = r[1]
        w2, h2 = max(1, int(sp.width * escala)), max(1, int(sp.height * escala))
        sp = sp.resize((w2, h2), Image.BILINEAR)
        px, py = int((x - meta["ox"]) * escala), int((y - meta["oy"]) * escala)
        if 0 <= px < im.width - w2 and 0 <= py < im.height - h2:
            im.alpha_composite(sp, (px, py))
    im.convert("RGB").save(ruta)


def exportar(m, nombre_cmd, titulo):
    mp = E.nuevo_mapa(W, H, int(m.ts[0, 0]), nombre_cmd)
    cel = bytearray(W * H * 6)
    usados = sorted(set(int(v) for v in np.unique(m.ts)))
    for y in range(H):
        for x in range(W):
            i = (y * W + x) * 6
            cel[i] = int(m.ts[y, x])
            cel[i + 1] = int(m.attr[y, x])
    mp["celdas"] = bytes(cel)
    mp["tilesets"] = usados
    mp["objetos"] = [[oid, x, y, 0, 0, 192, "00" * 50] for oid, x, y in m.objetos if E.sprite_obj(oid)]
    mp["puntos"] = [dict(id=pid, puntos=[[int(a), int(b)] for a, b in pts]) for pid, pts in m.puntos]
    j = E.mapa_json(mp, nombre_cmd, "nuevo")
    j["campamentos"] = m.camps
    prev = os.path.join(E.SALIDA, "previa_" + nombre_cmd + ".png")
    previa(m, prev)
    print(titulo, "->", len(mp["objetos"]), "objetos;", len(m.camps), "campamentos; vista previa", prev)
    if ENVIAR:
        r = E.a_dos_coronas(j, m.num, nombre_cmd)
        print(r["salida"][-700:])
        if not r["ok"]:
            raise SystemExit("falló el horneado")
    return j


def zona_entrada(m, cx, cy, ancho=14, alto=7):
    """Punto 31 (entrada y salida): rectángulo de ancho x alto celdas centrado en (cx, cy), en píxeles."""
    x0, x1, y0, y1 = (cx - ancho / 2) * 32, (cx + ancho / 2) * 32, (cy - alto / 2) * 32, (cy + alto / 2) * 32
    m.puntos.append((31, [(x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0 + 1, y0 + 1)]))


def campamentos(m, lista, lejos_de, min_dist, n_max=14, separacion=22, zona=None):
    """Campamentos repartidos en suelo libre, lejos de la entrada y entre sí. lista = [(monstruo, cantidad, radio, nivel|None)]"""
    puestos = []
    ys, xs = np.nonzero(~(m.camino | m.agua | m.occ) & (zona if zona is not None else True))
    intentos = 0
    while len(puestos) < n_max and intentos < 4000:
        intentos += 1
        k = m.rng.randrange(len(xs))
        cx, cy = int(xs[k]), int(ys[k])
        if cx < 12 or cy < 12 or cx > W - 12 or cy > H - 12:
            continue
        if math.hypot(cx - lejos_de[0], cy - lejos_de[1]) < min_dist or math.hypot(cx - CX, cy - CY) < 24:
            continue
        if any(math.hypot(cx - px, cy - py) < separacion for px, py in puestos):
            continue
        if m.attr[cy - 3:cy + 4, cx - 3:cx + 4].any() or m.agua[cy - 4:cy + 5, cx - 4:cx + 5].any():
            continue
        puestos.append((cx, cy))
        mon, cant, rad, niv = lista[(len(puestos) - 1) % len(lista)]
        c = dict(monstruo=mon, cantidad=cant, radio=rad, x=cx / 2 + 0.25, y=cy / 2 + 0.25)
        if niv:
            c["nivel"] = niv
        m.camps.append(c)
    return puestos


# ------------------------------------------------------------------ ALBOR: Jardines del Amanecer
def jardin():
    m = Mapa("jardin_amanecer", 61, 0, 6101)
    n1, n2, n3 = ruido(6102, 14), ruido(6103, 9), ruido(6104, 5)
    # hierba: manchas de otro verde y de hojas
    # lago al noreste, con orilla de arena
    arena = np.zeros((H, W), bool)
    m.elipse(152, 32, 26, 17, 47, arena, 5, 1)
    lago = m.elipse(152, 32, 22, 13, 3, None, 4, 2)
    m.agua_en(lago)
    m.camino |= arena & ~lago                                  # la orilla queda libre de árboles
    m.ts[lago & (ruido(6120, 4) > 0.8)] = 11
    # plaza: adoquín rosado en el centro, piedra clara y aro de adoquín
    m.disco(CX, CY, 19, 2, m.camino, 1.5, 1)
    m.disco(CX, CY, 16, 5, None, 1.5, 2)
    m.disco(CX, CY, 7.5, 4, None, 0.8, 3)
    # caminos de arena
    m.sendero([(CX, CY + 16), (CX - 3, 84), (CX + 3, 98), (CX, 112), (CX, H - 2)], 6, 1)           # sur: la entrada
    m.sendero([(CX + 18, CY - 2), (126, 56), (138, 52), (146, 46)], 5, 1)                           # este: al lago
    m.sendero([(CX - 18, CY), (80, 58), (62, 64), (44, 62), (26, 56)], 5, 1)                         # oeste: a la arboleda
    m.sendero([(CX, CY - 18), (CX + 3, 42), (CX - 4, 28), (CX, 14)], 5, 1)                           # norte: al mirador
    # el aro de la plaza y los bordes del camino con adoquín
    ys, xs = np.mgrid[0:H, 0:W]
    ring = (np.hypot(xs - CX, ys - CY) > 17) & (np.hypot(xs - CX, ys - CY) < 19.5)
    m.ts[ring] = 33
    # ---- árboles: borde del mapa (con hueco en la entrada) y arboledas
    entrada = np.hypot(xs - CX, ys - (H - 6)) < 13
    borde = m.borde_bosque(11, 9, entrada)
    arboles = [5208, 5210, 5214, 5223, 5226, 5228, 5231, 5236]
    m.esparcir(arboles, 150, borde & ~m.camino, 3.2, True, 2)
    m.esparcir([5217, 5216, 5220], 5, borde & ~m.camino, 4, True, 2)              # alguno otoñal, para romper el verde
    # cerezos y melocotoneros: alrededor de la plaza, en grupos
    cerezos = [5298, 5300, 5301]
    for ang in np.linspace(0, 2 * math.pi, 9)[:-1]:
        gx, gy = CX + math.cos(ang) * 34 + m.rng.uniform(-3, 3), CY + math.sin(ang) * 26 + m.rng.uniform(-3, 3)
        zona = (np.hypot(xs - gx, ys - gy) < 7) & ~m.camino
        m.esparcir(cerezos + [5310, 5312], 4, zona, 3.4, True, 2, 1)
    # bosquecillos sueltos en la pradera
    for gx, gy in ((40, 30), (62, 96), (140, 100), (170, 78), (26, 100), (125, 20)):
        zona = (np.hypot(xs - gx, ys - gy) < 9) & ~m.camino
        m.esparcir(arboles, 6, zona, 3.4, True, 2, 1)
    # ---- mobiliario de la plaza
    m.poner(12339, CX, CY + 5.5, 6, True, 8)                                     # fuente
    for dx, dy, oid in ((-11, -3, 7212), (11, -3, 7213), (-11, 8, 7212), (11, 8, 7213)):
        m.poner(oid, CX + dx, CY + dy, 2, True, 2)
    m.poner(8017, CX, CY - 12.5, 3, True, 3)                                      # emblema dorado
    for dx, dy in ((-6, 15), (6, 15), (-15, 5), (15, 5)):
        m.poner(7173, CX + dx, CY + dy, 2, False)
    m.poner(5992, CX - 14, CY - 8, 3, True, 3)
    m.poner(5993, CX + 14, CY - 8, 3, True, 3)
    m.poner(10404, CX - 14, CY + 12, 3, True, 3)
    m.poner(7179, CX - 3.5, CY - 5, 1, True)
    m.poner(7180, CX + 3.5, CY - 5, 1, True)
    # farolas con estandarte a lo largo de los caminos
    for t in range(18, 52, 8):
        for lado in (-4.5, 4.5):
            m.poner(7154, CX + lado + (math.sin(t / 12.0) * 3 if t > 24 else 0), CY + t + 2, 1.5, True)
    for x in (CX + 24, CX + 34, CX - 24, CX - 34):
        m.poner(7154, x, CY + 3.6, 1.5, True)
    # entrada: arco, estandartes y farolas
    m.poner(8800, CX, H - 15, 3, True, 7)
    m.poner(9721, CX - 7, H - 11, 2, True)
    m.poner(9721, CX + 7, H - 11, 2, True)
    zona_entrada(m, CX, H - 6)
    # mirador al norte, templete junto al lago, pozos y casas del árbol
    m.poner(8538, CX, 20, 5, True, 6)
    m.poner(8538, 138, 41, 5, True, 6)
    m.poner(7173, 141, 48, 2, False)
    m.poner(7167, 60, 60, 3, True, 2)
    m.poner(7168, 150, 74, 3, True, 2)
    m.poner(12835, 28, 40, 6, True, 3)
    m.poner(12104, 46, 62, 3, False)
    m.poner(8771, 168, 52, 4, True, 3)
    # ---- la hierba y las flores (campos de flores donde el ruido es alto)
    libre = ~(m.camino | m.agua | m.occ)
    flores = [5400, 5401, 5402, 5403, 5404, 5405, 5409, 5410, 5411, 5412, 5414, 5415, 5417, 5419, 5421, 5423, 5425, 5427, 5429, 5431, 5433, 5435, 5437, 5439]
    pesos = None
    m.esparcir(flores, 520, libre, 1.1, False, 1, 0, 30, pesos, n3 * 0.5 + n2 * 0.6)
    m.esparcir(flores, 110, libre & (n1 < 0.5), 1.1, False, 1, 1)
    m.esparcir([5019, 5020, 5035, 5051, 5081, 5074, 5077], 360, libre, 0.8)
    # flores y cañas de la orilla
    orilla = arena & ~lago
    m.esparcir([5025, 5027, 5409, 5404], 36, orilla, 1.2)
    ys2, xs2 = np.nonzero(lago)
    for _ in range(40):
        k = m.rng.randrange(len(xs2))
        m.poner(9753, xs2[k] + 0.5, ys2[k] + 0.5)
    for _ in range(26):
        k = m.rng.randrange(len(xs2))
        if lago[max(0, ys2[k] - 1):ys2[k] + 2, max(0, xs2[k] - 1):xs2[k] + 2].all():
            m.poner(m.rng.choice([5053, 5055]), xs2[k] + 0.5, ys2[k] + 0.5)
    # mariposas y pájaros
    zl = np.nonzero(libre & (n1 > 0.4))
    for _ in range(14):
        k = m.rng.randrange(len(zl[0]))
        m.poner(9731, zl[1][k] + 0.5, zl[0][k] + 0.5)
    # ---- criaturas amables del jardín
    camps = [("seta_azul", 3, 4, None), ("larva_verde", 3, 4, None), ("polilla_rosa", 3, 4, None), ("libelula_cian", 3, 5, None),
             ("rabano_guerrero", 3, 4, None), ("girasol_lancero", 2, 4, None), ("flor_lanza", 2, 4, None), ("pinguino_aprendiz", 3, 4, None)]
    campamentos(m, camps, (CX, H - 6), 40, 12, 24)
    return exportar(m, "jardin_amanecer", "Jardines del Amanecer")


# ------------------------------------------------------------------ UMBRA: Necrópolis del Ocaso
def necropolis():
    m = Mapa("necropolis_ocaso", 62, 21, 6201)
    n1, n2, n3 = ruido(6202, 14), ruido(6203, 9), ruido(6204, 5)
    ys, xs = np.mgrid[0:H, 0:W]
    # estanque espectral al este
    ori = np.zeros((H, W), bool)
    m.elipse(156, 64, 24, 15, 46, ori, 5, 1)
    est = m.elipse(156, 64, 20, 11, 179, None, 4, 2)
    m.agua_en(est)
    m.camino |= ori & ~est
    # plaza ritual: losas oscuras con aro y dado central
    m.disco(CX, CY, 18, 22, m.camino, 1.5, 1)
    m.disco(CX, CY, 14.5, 23, None, 1, 2)
    m.disco(CX, CY, 7, 227, None, 0.8, 3)
    # cementerio al oeste: terreno morado y caminos de losas
    cem = np.zeros((H, W), bool)
    m.elipse(44, 62, 30, 28, 21, cem, 6, 5)
    # caminos
    m.sendero([(CX, CY + 15), (CX + 4, 84), (CX - 3, 98), (CX, 112), (CX, H - 2)], 6, 22)
    m.sendero([(CX + 17, CY), (126, 63), (134, 64)], 5, 22)
    m.sendero([(CX - 17, CY), (82, 60), (66, 62), (50, 60), (40, 62)], 5, 22)
    m.sendero([(CX, CY - 17), (CX - 3, 40), (CX + 3, 28), (CX, 21)], 5, 22)
    # ---- murallas de roca: riscos y árboles muertos alrededor, con hueco en la entrada
    entrada = np.hypot(xs - CX, ys - (H - 6)) < 13
    borde = m.borde_bosque(12, 10, entrada)
    riscos = [6200, 6201, 6202, 6215, 6216, 6219, 6220]
    m.esparcir(riscos, 70, borde & ~m.camino, 5, True, 4)
    m.esparcir([14031, 14032, 14033, 14034, 6001, 6003, 6004, 6011, 6082], 36, borde & ~m.camino, 3, True, 3)
    m.esparcir([14026, 14027, 14028, 14029, 14030], 70, borde & ~m.camino, 3.2, True, 2)
    m.esparcir([5532, 5535, 5540], 14, borde & ~m.camino, 2.5, True, 2)
    # riscos sueltos y árboles muertos por el campo
    libre0 = ~(m.camino | m.agua | m.occ | cem)
    m.esparcir(riscos[:3], 8, libre0, 6, True, 4, 3)
    m.esparcir([14026, 14027, 14028, 14029, 14030], 30, libre0, 3.5, True, 2, 3)
    m.esparcir([14031, 14033, 6001, 6082], 14, libre0, 3, True, 3, 2)
    # ---- plaza ritual
    m.poner(13451, CX, CY + 3.5, 6, True, 7)                                       # altar de cristal oscuro
    for dx, dy, oid in ((-17, 0, 7239), (17, 0, 7240), (0, -15, 7241), (0, 16, 7242)):
        m.poner(oid, CX + dx, CY + dy + 2, 2.5, True, 2)
    m.anillo([8204, 8205, 8206], CX, CY, 13, 14, 1, 0.3)
    m.anillo([6645, 6649, 6657], CX, CY, 15.5, 6, 2, 0.5, False)
    for dx, dy in ((-8.5, -10.5), (8.5, -10.5), (-8.5, 10.5), (8.5, 10.5)):
        m.poner(8248, CX + dx, CY + dy + 3, 1.5, True)
    m.poner(8249, CX, CY - 20, 3, True, 3)
    # ---- entrada: pilares, gárgolas y candelabros
    for dx in (-8.5, 8.5):
        m.poner(6027 if dx < 0 else 6028, CX + dx, H - 16, 2.5, True, 2)
        m.poner(8248, CX + dx * 0.55, H - 22, 1.5, True)
    m.poner(7241, CX - 4.5, H - 12, 2, True, 2)
    m.poner(7242, CX + 4.5, H - 12, 2, True, 2)
    zona_entrada(m, CX, H - 6)
    for t in range(22, 50, 7):
        m.poner(8248, CX - 5 + (t % 2) * 10 + math.sin(t / 10.0) * 3, CY + t + 2, 1.5, True)
    # ---- cripta al norte
    m.poner(10420, CX, 17, 7, True, 8)
    for dx in (-12, 12):
        m.poner(6026, CX + dx, 22, 2.5, True, 2)
        m.poner(6064, CX + dx * 1.25, 27, 2.5, False)
    m.poner(8250, CX - 6, 26, 3, True, 3)
    m.poner(8250, CX + 6, 26, 3, True, 3)
    m.poner(12117, CX - 20, 22, 5, True, 5)
    m.poner(12118, CX + 20, 22, 5, True, 5)
    # ---- cementerio: filas de tumbas con velas
    cruces = [8207, 8208, 8209, 8210, 8215, 8216, 8213, 8214]
    for fila in range(5):
        for col in range(7):
            gx, gy = 22 + col * 8 + (fila % 2) * 4 + m.rng.uniform(-1, 1), 40 + fila * 9 + m.rng.uniform(-1, 1)
            if not m.libre(gx, gy, 2.2) or math.hypot(gx - 44, gy - 62) > 29 or abs(gy - 61) < 3.5 and gx > 36:
                continue
            m.poner(m.rng.choice(cruces + [8204, 8211, 8212, 8200, 8201, 8202, 8203, 10421, 10422]), gx, gy, 2.2, True, 2)
            if m.rng.random() < 0.45:
                m.poner(m.rng.choice([8205, 8206]), gx + m.rng.uniform(-2, 2), gy + 1.6, 0.8)
    m.poner(8434, 44, 62, 4, True, 3)                                                # hoguera central del camposanto
    m.poner(8602, 24, 24, 5, True, 4)
    # ---- estanque: cristales azules, setas brillantes y luces
    for _ in range(14):
        a = m.rng.uniform(0, 2 * math.pi)
        px, py = 156 + math.cos(a) * 25, 64 + math.sin(a) * 15.5
        if m.libre(px, py, 2.2):
            m.poner(m.rng.choice([6644, 6648, 6652, 6656, 6647]), px, py, 2.2, True, 2)
    for _ in range(10):
        a = m.rng.uniform(0, 2 * math.pi)
        px, py = 156 + math.cos(a) * 27, 64 + math.sin(a) * 17
        if m.libre(px, py, 2):
            m.poner(m.rng.choice([5505, 5514, 5531]), px, py, 2)
    m.poner(7587, 128, 72, 3, True, 2)
    m.poner(7588, 128, 54, 3, True, 2)
    ye, xe = np.nonzero(est)
    for _ in range(46):
        k = m.rng.randrange(len(xe))
        m.poner(m.rng.choice([9748, 9749, 9753]), xe[k] + 0.5, ye[k] + 0.5)
    # ---- detalles por el campo
    libre = ~(m.camino | m.agua | m.occ)
    m.esparcir([6047, 6051, 6059, 6063, 6064, 6065], 40, libre & (n1 > 0.3), 1.6)
    m.esparcir([8205, 8206, 8201, 8203], 40, libre, 1.2, False, 1, 0)
    m.esparcir([6644, 6648, 6652, 6656, 6645, 6649], 24, libre & (n3 > 0.55), 2, True, 2)
    m.esparcir([5505, 5514, 5531, 5535, 5532], 34, libre & (n2 > 0.5), 1.8, False, 1, 0)
    m.esparcir([9750, 9751, 5019, 5020, 5052], 180, libre, 0.8)
    zl = np.nonzero(libre & (n1 > 0.3))
    for _ in range(40):
        k = m.rng.randrange(len(zl[0]))
        m.poner(9748, zl[1][k] + 0.5, zl[0][k] + 0.5)
    m.esparcir([6092], 3, libre, 5, False, 1, 4)
    # ---- criaturas de la noche
    camps = [("esqueleto", 3, 4, None), ("murcielago_purpura", 3, 5, None), ("esqueleto_soldado", 3, 4, None), ("espiritu_velo", 2, 4, None),
             ("momia", 2, 4, None), ("dama_velo", 2, 4, None), ("esqueleto_arquero", 3, 5, None), ("vampiro", 2, 4, None)]
    campamentos(m, camps, (CX, H - 6), 40, 12, 24)
    m.camps.append(dict(monstruo="jefe_rey_esqueleto", cantidad=1, radio=3, x=CX / 2 + 0.25, y=33.25, jefe=True))
    return exportar(m, "necropolis_ocaso", "Necrópolis del Ocaso")


if __name__ == "__main__":
    E.cargar()
    E.cargar_defs()
    quien = args[0] if args else "todos"
    if quien in ("albor", "todos"):
        jardin()
    if quien in ("umbra", "todos"):
        necropolis()
