"""Reglas con las que Dos Coronas interpreta un .mpc de FAO. La colisión sale del atributo de cada celda (byte 1: 0 libre, el resto bloquea; ver mpc.py); estas reglas solo clasifican el color de
los tilesets (para minimapa y ambiente) y deciden qué objetos cierran además su casilla. Material de un juego ajeno (FAO), solo prototipo.

TILES (por color medio del tile de 32x32, ya que no hay una tabla de tipos de suelo en los archivos de datos del cliente):
  agua profunda  azul dominante (b - r >= UMBRAL_AGUA): NO transitable
  agua somera / orilla / arena / hierba / tierra / roca: transitables
OBJETOS (por el nombre y la clase de setting/mapobj.obd, que sí están en el cliente):
  bloquean: árboles y palmeras (clase 11TREE o "樹"), rocas y riscos (石頭, 巨石, 礁岩, 山洞), cajas, barriles, cofres, puestos, cráneos grandes, muebles de interior
  no bloquean: flores y hierbas (12FLOWER), conchas, bordes de hierba y de piedra (邊條, 邊), puentes (木橋), luces, mariposas, destellos del agua, marcas del servidor
  una pieza ocupa un cuadrado de n x n casillas centrado en su punto de apoyo (n = el 30 % del ancho del sprite en casillas, mínimo 1: un tronco 1, una roca grande 2)
"""
import re

UMBRAL_AGUA = 90          # b - r del color medio del tile
NO_BLOQUEAN = ("花", "草", "葉", "蒲公英", "針葉球", "幸運草", "貝殼", "邊條", "邊", "橋", "光", "蝴蝶", "小鳥", "水中", "植物", "蘆葦", "星草", "草皮")
BLOQUEAN = ("樹", "石頭", "石", "岩", "礁", "山洞", "木箱", "木桶", "寶箱", "攤販", "櫃子", "骷髏", "木桌", "桶", "箱")
# (los "(X)" del nombre son piezas marcadas como descartadas en FAO: se dibujan igual, que el mapa las usa)

# Piezas planas (suelo): las que FAO no ordena con los personajes. Sin z-buffer (bordes, césped, tablas) siempre; los tableros de los puentes llevan z-buffer en algunos mapas
# (橋, 橋面, 木板) pero se pisan igual: van bajo los personajes. Sus pilares, barandillas y soportes sí se ordenan.
PLANOS = ("橋面", "橋", "木板", "棧道", "浮空橋")
NO_PLANOS = ("柱", "欄", "墩", "架")


def es_plano(d):
    """¿La pieza se dibuja en la capa del suelo (bajo personajes y demás objetos)? d = {nombre, proceso, flags,...}."""
    if d is None or "11TREE" in d["proceso"] or "HITTEST" in d["flags"]:
        return False
    if any(k in d["nombre"] for k in NO_PLANOS):
        return False
    if "ZBUFFER" not in d["flags"]:
        return True
    return any(k in d["nombre"] for k in PLANOS)


def clase_tile(rgb):
    """('agua'|'agua_somera'|'arena'|'hierba'|'tierra'|'roca', bloquea) por el color medio (r, g, b)."""
    r, g, b = [float(v) for v in rgb]
    if b - r >= UMBRAL_AGUA:
        return "agua", True
    if b - r >= 30 and g >= r:
        return "agua_somera", False
    if g > r + 15 and g > b + 25:
        return "hierba", False
    if abs(r - g) < 16 and abs(g - b) < 24 and r < 200:
        return "roca", False
    if r > 225 and g > 200 and b > 120:
        return "arena", False
    return "tierra", False


def objeto_bloquea(d):
    """¿Bloquea el paso un objeto de mapobj.obd? d = {nombre, proceso, flags, directorio, sprite}."""
    if d is None:
        return False
    nombre, proceso = d["nombre"], d["proceso"]
    if "ZBUFFER" not in d["flags"] and "HITTEST" not in d["flags"] and "11TREE" not in proceso:
        # (las piezas de suelo y los adornos planos no llevan z-buffer)
        return False
    if "矮樹叢" in nombre:
        return False          # (matorrales bajos: se cruzan)
    if "11TREE" in proceso and "(X)" not in nombre:
        return True
    if any(k in nombre for k in NO_BLOQUEAN):
        return False
    return any(k in nombre for k in BLOQUEAN)


def huella(ancho_sprite_px):
    """Casillas que ocupa a lo ancho una pieza que bloquea: un tronco o una roca ocupan una parte del ancho del sprite (el 30 %), como mínimo una casilla."""
    return max(1, int(round(ancho_sprite_px * 0.3 / 32)))
