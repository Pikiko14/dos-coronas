"""Hornea las monturas FAO (../arte-fuente/monturas-todas/monturas/<id>/1x/{Wait,Run}.png) para el juego.

Uso:  python herramientas/generar_mobs/monturas.py
Salida: juego/arte/monstruos/mnt_<id>/{wait,run}.png (las cinco direcciones: cuadro = paso * 5 + hoja, ver fao_hojas.py),
        juego/src/presentacion/render/montura_anim_datos.lua (tamaño y asiento del jinete) y compartido/datos/monturas_fao.fragmento.txt
        (las líneas XML de las monturas del Item Mall, para monturas.xml y mall.xml)."""
import os, json, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import fao_hojas

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FUENTE = os.path.join(RAIZ, "..", "arte-fuente", "monturas-todas")
SALIDA = os.path.join(RAIZ, "juego", "arte", "monstruos")
ALTURAS = json.load(open(os.path.join(FUENTE, "alturas_jinete.json"), encoding="utf-8"))
LUA = os.path.join(RAIZ, "juego", "src", "presentacion", "render", "montura_anim_datos.lua")
LUA_ASIENTO = os.path.join(RAIZ, "juego", "src", "presentacion", "render", "montura_asiento_datos.lua")
PAD = 3
PASOS = {"wait": 3, "run": 6}
BAKE = 1.0                    # tamaño del horneado respecto al original (a tamaño completo: las monturas se ven nítidas)
ESCALA = 0.5                  # en pantalla, a zoom 2 una montura horneada a BAKE 1 se ve a la mitad de su tamaño original
MIN_ALTO = 1                 # altura mínima en pantalla (px) de una montura: las más pequeñas (hámsteres, cerditos) se amplían hasta ella para que el
                              # jinete, que no se reduce, no sea más grande que su montura
MAX_AMPLIAR = 1.0             # lo máximo que se amplía una montura (se hornea más grande: no se pierde nitidez)
PELVIS = 36                   # altura de la cadera del jinete sentado sobre su origen (px del original; medida en la hoja montada)
CADERA_REL = 0.45             # altura a la que queda la cadera del jinete, como fracción de la altura de la montura
HOMOGENEO = 0.8               # 1 = todas las monturas con la cadera exactamente a CADERA_REL; 0 = las alturas originales de FAO sin tocar
MAX_CORR = 70                 # lo máximo (px horneados) que se corrige el asiento de una montura

NOMBRES = {
    "001": "Corcel blanco", "002": "Gallo de monta", "005": "Burro", "006": "Lobo blanco", "007": "Hámster de cofia", "008": "Zorro rojo",
    "009": "Jabalí ámbar", "026": "Corcel granate", "027": "Bisonte pardo", "028": "Hámster pardo", "029": "Corcel de nieve",
    "030": "Caballo castaño", "031": "Rana azul", "032": "Conejo escarlata", "033": "Jabalí dorado", "034": "Hámster del huevo",
    "035": "Lobo de melena", "036": "Gallo rojo", "037": "Cerdito rosa", "038": "Corcel borgoña", "039": "Hámster tostado",
    "040": "Lobo Aullador", "103": "Tortuga viajera", "104": "León dorado", "105": "Autómata azul", "143": "Escarabajo real",
    "144": "Escarabajo de acero", "145": "Foca blanca", "146": "Foca madre", "167": "Mono frutal", "176": "Vagoneta dorada",
    "197": "Avestruz gris", "198": "Avestruz violeta", "199": "Genio de oro", "200": "Genio dorado", "201": "Barco de nubes",
    "202": "Tiburón submarino", "203": "Águila parda", "204": "Águila blanca", "225": "Oca gigante", "226": "Espíritus de la noche",
    "227": "Oso polar", "239": "Centauro dorado", "250": "Carnero lanudo", "253": "Carro de guerra", "260": "Behemot rojizo",
    "261": "Pterodáctilo verde", "264": "Lobo de carga", "269": "Tortuga estrella", "270": "Raptor rojo", "271": "Raptor carmesí",
    "284": "Oso boxeador", "294": "Dragoncito azul", "295": "Dragón negro y azul", "296": "Alpaca rosa", "297": "Alpaca navideña",
    "298": "Dragón dorado", "299": "Dragón de jade", "300": "Mantarraya blanca", "301": "Mantarraya real", "306": "Pingüino viajero",
    "308": "Pez globo buceador", "309": "Pez globo acorazado", "310": "Elefante naval", "311": "Elefante real", "312": "Hámster soldado",
    "313": "Hámster aviador", "314": "Luciérnaga", "335": "Nave dorada", "356": "Mapache", "357": "Mapache de cristal",
    "358": "Husky gris", "359": "Husky festivo", "373": "Delfín azul", "374": "Delfín capitán", "375": "Sandía guerrera",
    "376": "Conejo del bosque", "377": "Peluche gris", "378": "Peluche de feria", "392": "Peluche rosa", "393": "Peluche de caramelo",
    "403": "Cerdo alado", "404": "Cerdo platillo", "405": "Cerdo de fuego", "406": "Cerdo nabo", "407": "Cerdo turquesa",
    "416": "Gato buhonero", "445": "Cabra montesa", "448": "Ciervo rosa", "449": "Oveja dorada", "450": "Oveja florida",
    "451": "Lobo de espinas", "452": "Bestia de lava", "472": "Pollito blanco", "473": "Pollito mago", "474": "Yeti", "475": "Yeti nevado",
    "476": "Cachorro refrescante", "477": "Perro aviador", "494": "Gato de ensueño", "495": "Gata hechicera", "496": "Orbe rojo",
    "497": "Orbe violeta", "498": "Jabalí del nido", "499": "Jabalí del nido violeta", "571": "Mecha azul", "572": "Mecha cañón",
    "573": "Espíritu de hielo", "574": "Pingüino rey", "584": "Gato morado", "619": "Cangrejo ermitaño", "620": "Cangrejo turquesa",
    "621": "Burro azul", "622": "Burro sheriff", "649": "Conejo orejudo", "650": "Conejo explorador", "651": "Búfalo azul",
    "652": "Búfalo de hielo", "734": "Tortuga turquesa",
}


def alto_original(im, pasos):
    """Alto (px) del cuerpo de la montura en la espera de frente-izquierda, en el arte original."""
    alfa = np.asarray(im)[:, :, 3] > 10
    w = im.width // (pasos * 5)
    filas = np.where(alfa[:, 3 * w:4 * w].any(1))[0]
    return int(filas.max() - filas.min() + 1) if len(filas) else im.height


def hornear():
    meta = json.load(open(os.path.join(FUENTE, "monturas.json"), encoding="utf-8"))
    datos = {}
    asiento = {}          # montura -> animación -> lista plana [dx, dy] por cuadro (paso * 5 + hoja)
    for idn in sorted(meta):
        d = os.path.join(FUENTE, "monturas", idn, "1x")
        sal = os.path.join(SALIDA, "mnt_" + idn)
        os.makedirs(sal, exist_ok=True)
        alto = None
        # Las monturas más pequeñas (hámsteres, cerditos) se amplían hasta MIN_ALTO en pantalla, para que el jinete (que no se reduce) no sea más grande que ellas.
        # Se hornean más grandes (no se pierde nitidez) y se dibujan a la misma escala que las demás.
        orig = alto_original(Image.open(os.path.join(d, "Wait.png")).convert("RGBA"), PASOS["wait"])
        bake = min(MAX_AMPLIAR, max(BAKE, MIN_ALTO / max(1.0, orig * ESCALA)))
        # Altura del jinete sobre esta montura: dato original del cliente (setting/chardef.xml, <騎乘 高度=...>, copiado en alturas_jinete.json). En FAO el
        # jinete comparte el origen de la montura y se sube (positivo) o se baja (negativo) esa altura: los cerdos -25, el avestruz +23, el raptor +52.
        altura = ALTURAS["monturas"].get(idn, {}).get("altura", 0)
        for anim, pasos in PASOS.items():
            im = Image.open(os.path.join(d, anim.capitalize() + ".png")).convert("RGBA")
            anclas = meta[idn]["animaciones"][anim.capitalize()]["anclas"]
            # las cinco direcciones (cuadro = paso * 5 + hoja, ver fao_hojas.py); el asiento del jinete es dónde cae el origen (los pies) de las
            # hojas del personaje montado respecto al punto de dibujo de la montura (centro y base de la casilla), subido la altura de arriba
            tira, cw, ch, alto_c, plano = fao_hojas.hornear(im, pasos, bake, PAD, anclas)
            for j in range(1, len(plano), 2):
                plano[j] = round(plano[j] - altura, 1)
            asiento.setdefault(idn, {})[anim] = plano
            if anim == "wait":
                alto = alto_c
                alfa_t = np.asarray(tira)[:, :, 3] > 10
                techos, suelos = [], []
                for hoja in (2, 3, 4):                     # espalda-izquierda, izquierda y frente-izquierda
                    for p_ in range(pasos):
                        ys_ = np.where(alfa_t[:, (p_ * 5 + hoja) * cw:(p_ * 5 + hoja + 1) * cw].any(1))[0]
                        if len(ys_):
                            techos.append(ys_.min()); suelos.append(ys_.max())
                caja = (float(np.mean(techos)), float(np.mean(suelos)), ch - PAD) if techos else None
            fao_hojas.guardar(tira, os.path.join(sal, anim + ".png"))
        # Homogeneidad: la altura de jinete original de FAO deja la cadera entre el 15 % y el 107 % de la altura de cada montura (pájaros y alados
        # flotando, cerditos hundidos). Se acerca la cadera de TODAS a una misma fracción de su altura (HOMOGENEO = 1 las pone todas igual;
        # menos, conserva algo de la variación original), con la misma corrección en todos los cuadros para no perder el vaivén.
        if caja:
            techo, suelo, base_y = caja
            alto_m = max(1.0, suelo - techo)
            dys = [asiento[idn]["wait"][(p_ * 5 + h_) * 2 + 1] for h_ in (2, 3, 4) for p_ in range(PASOS["wait"])]
            rel = (PELVIS - sum(dys) / len(dys) + (base_y - suelo)) / alto_m
            objetivo = CADERA_REL + (1 - HOMOGENEO) * (rel - CADERA_REL)
            corr = max(-MAX_CORR, min(MAX_CORR, (rel - objetivo) * alto_m))      # positivo = más abajo
            for anim_ in ("wait", "run"):
                pl = asiento[idn][anim_]
                for j in range(1, len(pl), 2):
                    pl[j] = round(pl[j] + corr, 1)
        pant = round(alto * ESCALA)
        datos[idn] = dict(alto=pant, altura=max(8, min(30, round(pant * 0.45))))
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERADO por herramientas/generar_mobs/monturas.py: tamaño y asiento del jinete de cada montura FAO. No editar a mano.\nreturn {\n")
        for k, v in datos.items():
            f.write('  mnt_%s = { carpeta = "mnt_%s", alto = %d, escala = %.4f, dirs5 = true, pad = %d, altura = %d },\n' % (k, k, v["alto"], ESCALA, PAD, v["altura"]))
        f.write("}\n")
    with open(LUA_ASIENTO, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERADO por herramientas/generar_mobs/monturas.py: asiento del jinete (origen de las hojas del personaje montado) en cada cuadro\n"
                "-- de cada montura FAO, en píxeles de la tira horneada respecto al centro y la base de su casilla: pares dx, dy por cuadro (paso * 5 + hoja).\n"
                "-- No editar a mano.\nreturn {\n")
        for k, v in asiento.items():
            f.write("  mnt_%s = {\n" % k)
            for anim, plano in v.items():
                f.write("    %s = { %s },\n" % (anim, ", ".join("%g" % x for x in plano)))
            f.write("  },\n")
        f.write("}\n")
    return meta


def generar_xml(meta):
    mon, mall = [], []
    for idn in sorted(meta):
        m = meta[idn]
        nombre = NOMBRES.get(idn, "Montura " + idn)
        vel = round(min(0.56, 0.30 + m["velocidad_original"] * 0.004), 2)
        precio = max(500, int(round((500 + m["nivel_original"] * 4) / 50.0)) * 50)
        mon.append('  <montura id="mnt_%s" nombre="%s" nivel="1" carga="0" desc="Montura exclusiva del Item Mall." mall="true" precio="0" vel="%s" vida="600"/>' % (idn, nombre, vel))
        mall.append('  <montura id="mnt_%s" nombre="%s" desc="Exclusiva del Item Mall: sin oficio y se pelea montado. Velocidad +%d%%." precio="%d"/>' % (idn, nombre, round(vel * 100), precio))
    ruta = os.path.join(RAIZ, "compartido", "datos", "monturas_fao.fragmento.txt")
    open(ruta, "w", encoding="utf-8", newline="\n").write("\n".join(mon) + "\n###MALL###\n" + "\n".join(mall) + "\n")


if __name__ == "__main__":
    generar_xml(hornear())
    print("listo")
