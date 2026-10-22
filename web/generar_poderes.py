"""Reescribe en web/js/app.js la lista de poderes de cada clase (poderes: [[nombre, descripción, "maná · enfriamiento"], ...]) a partir de los datos del juego
(compartido/datos/habilidades.xml: orden de la barra y datos de cada poder). Así la portada no se desfasa cuando cambian los poderes.
Uso: python -X utf8 web/generar_poderes.py"""
import json
import os
import re

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
XML = os.path.join(RAIZ, "compartido", "datos", "habilidades.xml")
JS = os.path.join(RAIZ, "web", "js", "app.js")

texto = open(XML, encoding="utf-8").read()
# (el XML del juego lo lee un analizador propio y tiene comentarios que ElementTree no acepta: se leen los atributos con expresiones regulares)
poderes = {}
for m in re.finditer(r"<habilidad\s([^>]*?)/?>", texto):
    at = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
    poderes[at["id"]] = at
barra = {}
for m in re.finditer(r'<barra>(.*?)</barra>', texto, re.S):
    for c in re.finditer(r'<(\w+) lista="([^"]*)"/>', m.group(1)):
        barra[c.group(1)] = c.group(2).split(",")


def num(v):
    v = float(v)
    return ("%g" % v).replace(".", ",")


def entrada(h):
    return [h["nombre"], h.get("desc", ""), "%s maná · %s s" % (h.get("mana", "0"), num(h.get("cd", "0")))]


s = open(JS, encoding="utf-8", newline="").read()
nl = "\r\n" if "\r\n" in s else "\n"
s = s.replace("\r\n", "\n")
for clase, ids in barra.items():
    lista = json.dumps([entrada(poderes[i]) for i in ids], ensure_ascii=False)
    patron = re.compile(r'(\{ id: "%s",.*?\n\s*poderes: )\[\[.*?\]\](\s*\})' % clase, re.S)
    nuevo, n = patron.subn(lambda m: m.group(1) + lista + m.group(2), s, count=1)
    if n != 1:
        raise SystemExit("no encuentro los poderes de " + clase)
    s = nuevo
s = s.replace("Los seis poderes (teclas 1 a 6)", "Los diez poderes (teclas 1 a 6, Z, X, V y F)")
open(JS, "w", encoding="utf-8", newline="").write(s.replace("\n", nl) if nl == "\r\n" else s)
print("poderes actualizados:", {c: len(i) for c, i in barra.items()})
