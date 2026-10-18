"""Hornea los efectos de poder de FAO (carpetas de Downloads con sheets/ y efecto.json) a juego/arte/fao_efectos/ y escribe
juego/src/presentacion/render/efectos_fao_datos.lua (celdas y anclas por secuencia). Arte de un juego ajeno (FAO): prototipo.
Cada entrada: (carpeta, prefijo de los archivos). El prefijo evita choques de nombres (AIR, SWORD...). Uso: python -X utf8 herramientas/generar_efectos_fao.py"""
import json
import os
import shutil

DESCARGAS = os.environ.get("FAO_EFECTOS", r"C:\Users\User\Downloads")
RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FUENTES = [
    (os.path.join("fao-efectos-dc", "panther_killing"), ""),
    (os.path.join("fao-efectos-dc", "blizzard_burst"), ""),
    (os.path.join("fao-espada", "128_Revolving_Swords"), "tajo_"),
    (os.path.join("fao-espada", "001_Slicing_Chop"), "golpe_"),
]

salida = ["-- Datos de los efectos de FAO (GENERADO por herramientas/generar_efectos_fao.py desde los efecto.json): por secuencia, cuadros, celda y ancla (origin) en px nativos de FAO.",
          "-- Arte de un juego ajeno (FAO): prototipo.", "return {"]
for carpeta, prefijo in FUENTES:
    base = os.path.join(DESCARGAS, carpeta)
    j = json.load(open(os.path.join(base, "efecto.json"), encoding="utf-8"))
    for nombre, s in (j.get("sequences") or j.get("secuencias")).items():
        clave = prefijo + nombre
        shutil.copy(os.path.join(base, s["sheet"]), os.path.join(RAIZ, "juego", "arte", "fao_efectos", clave + ".png"))
        salida.append('  %s = { n = %d, w = %d, h = %d, ox = %d, oy = %d },' % (clave, s["frames"], s["cell"][0], s["cell"][1], s["origin"][0], s["origin"][1]))
salida.append("}")
open(os.path.join(RAIZ, "juego", "src", "presentacion", "render", "efectos_fao_datos.lua"), "w", encoding="utf-8", newline="\n").write("\n".join(salida) + "\n")
print("ok")
