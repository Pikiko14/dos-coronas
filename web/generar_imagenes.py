"""Prepara las imágenes de la web a partir de lo que exporta el propio juego.

Antes: `lovec juego --foto` (capturas en juego/capturas/) y `lovec juego --web` (sprites en juego/capturas/web/).
Uso:   python -X utf8 web/generar_imagenes.py

Deja en web/img/:
  capturas/*.jpg            las capturas elegidas (1280 px de ancho, JPEG)
  criaturas/<id>.png        un cuadro de espera de cada criatura de nivel alto (juego/arte/monstruos/<id>/wait.png)
  sprites/montura_*.png     las monturas que se pueden conseguir
  equipo_escalones.png      el equipo de las seis clases en los diez escalones (juego/capturas/equipos_wait_d0.png)
"""
import os
import re
import shutil

from PIL import Image

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
CAP = os.path.join(RAIZ, "juego", "capturas")
WEB_SPR = os.path.join(CAP, "web")
IMG = os.path.join(RAIZ, "web", "img")

CAPTURAS = ["ciudad", "poderes", "arbol", "equipo", "mzjefe", "batalla", "mascotas", "mall_mascotas", "establo", "casa", "subastas", "mercado", "encantar", "estados", "crear"]


def capturas():
    os.makedirs(os.path.join(IMG, "capturas"), exist_ok=True)
    for n in CAPTURAS:
        p = os.path.join(CAP, n + ".png")
        if not os.path.exists(p):
            print("falta", p)
            continue
        im = Image.open(p).convert("RGB")
        if im.width > 1280:
            im = im.resize((1280, round(im.height * 1280 / im.width)), Image.LANCZOS)
        im.save(os.path.join(IMG, "capturas", n + ".jpg"), quality=84, optimize=True)


def ids_altos():
    t = open(os.path.join(RAIZ, "compartido", "datos", "monstruos.xml"), encoding="utf-8").read()
    t = t[t.index("<!-- ALTOS"):]
    return re.findall(r'<monstruo\s+id="(\w+)"', t)


def criaturas():
    os.makedirs(os.path.join(IMG, "criaturas"), exist_ok=True)
    for idm in ids_altos():
        p = os.path.join(RAIZ, "juego", "arte", "monstruos", idm, "wait.png")
        if not os.path.exists(p):
            print("falta", p)
            continue
        im = Image.open(p).convert("RGBA")
        im = im.crop((0, 0, im.width // 6, im.height))         # primer cuadro (3 pasos x 2 direcciones)
        bb = im.getchannel("A").point(lambda v: 255 if v > 10 else 0).getbbox()
        if bb:
            im = im.crop(bb)
        im.thumbnail((200, 170), Image.LANCZOS)
        lienzo = Image.new("RGBA", (220, 180), (0, 0, 0, 0))
        lienzo.alpha_composite(im, ((220 - im.width) // 2, 180 - 6 - im.height))
        lienzo.save(os.path.join(IMG, "criaturas", idm + ".png"), optimize=True)


def monturas():
    t = open(os.path.join(RAIZ, "compartido", "datos", "monturas.xml"), encoding="utf-8").read()
    ids = [m.group(1) for m in re.finditer(r'<montura\s+id="(\w+)"', t)]
    for i in ids:
        for origen in (os.path.join(WEB_SPR, "montura_%s.png" % i), os.path.join(IMG, "sprites", "montura_%s.png" % i)):
            if os.path.exists(origen):
                destino = os.path.join(IMG, "sprites", "montura_%s.png" % i)
                if os.path.abspath(origen) != os.path.abspath(destino):
                    shutil.copyfile(origen, destino)
                break


def equipo():
    im = Image.open(os.path.join(CAP, "equipos_wait_d0.png")).convert("RGBA")
    fondo = im.getpixel((2, 2))[:3]                              # (la captura tiene fondo liso: se vuelve transparente)
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, _ = px[x, y]
            if abs(r - fondo[0]) < 5 and abs(g - fondo[1]) < 5 and abs(b - fondo[2]) < 5:
                px[x, y] = (0, 0, 0, 0)
    ancho, alto = im.width // 10, im.height // 12
    filas = [0, 2, 4, 6, 8, 10]                                 # una por clase (guerrero, lancero, cazador, mago, clérigo, nigromante)
    cw, ch, esc = 60, 76, 3                                     # casilla de cada figura (se recorta cada una y se centra)
    sal = Image.new("RGBA", (cw * 10, ch * len(filas)), (0, 0, 0, 0))
    for k, f in enumerate(filas):
        for c in range(10):
            celda = im.crop((c * ancho, f * alto, (c + 1) * ancho, (f + 1) * alto))
            bb = celda.getchannel("A").point(lambda v: 255 if v > 10 else 0).getbbox()
            if not bb:
                continue
            fig = celda.crop(bb)
            sal.alpha_composite(fig, (c * cw + (cw - fig.width) // 2, k * ch + ch - 4 - fig.height))
    sal = sal.resize((sal.width * esc, sal.height * esc), Image.NEAREST)
    sal.save(os.path.join(IMG, "equipo_escalones.png"), optimize=True)


if __name__ == "__main__":
    capturas()
    criaturas()
    monturas()
    equipo()
    print("listo")
