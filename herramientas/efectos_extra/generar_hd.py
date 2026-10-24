"""Efectos de los poderes del guerrero, el mago y el cazador (paquetes guerrero_sprites, mago_sprites y arquero_hd: <poder>/01.png..08.png de 640x640 + animaciones.json)
como extras: herramientas/efectos_extra/<id>/efecto.json + sheets/fx.png. Cada hoja se recorta a lo visible (la unión de sus 8 cuadros) para que pese poco en memoria.
Uso: python -I -X utf8 herramientas/efectos_extra/generar_hd.py [carpeta que contiene los tres paquetes]
Después: python -I -X utf8 herramientas/efectos_extra/fusionar.py <todos los ids> (los imprime este script).
Los ids de los poderes se conservan (barra, árbol y guardados); cada uno lleva el arte del sprite que le toca (ver el comentario de cada fila)."""
import json
import os
import sys

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
FUENTE = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\User\Downloads\jar"
CELDA = 640


def L(w, t0, ms, sc, modo="once", **k):
    d = dict(s="fx", w=w, t0=t0, ms=ms, sc=sc, a=1.0, modo=modo, mezcla="alpha")        # (mezcla normal: el arte trae sus colores y su transparencia; sumada se vería lavada)
    d.update(k)
    return d


def vuelo(sc, t1, **k):
    return [L("C", 0.0, 0.05, sc, "vuelo", t1=t1, giro="libre", **k)]     # la flecha/el proyectil apunta hacia donde va


# (clase, paquete, id del poder, nombre, carpeta, origen, capas, duración, golpes)   origen: centro | suelo (el ancla del paquete) | base (de pie sobre el suelo)
EFECTOS = [
    ("guerrero", "guerrero_sprites", "golpe", "Corte ígneo", "01_corte_igneo", "centro", [L("T", 0.05, 0.09, 0.65)], 0.9, [0.3]),
    ("guerrero", "guerrero_sprites", "tajo", "Torbellino de acero", "04_torbellino_acero", "centro", [L("C", 0.0, 0.1, 1.4)], 1.0, [0.3]),
    ("guerrero", "guerrero_sprites", "grito", "Barrera de escudo", "05_barrera_escudo", "centro", [L("C", 0.0, 0.13, 0.75, "hold", t1=1.3)], 1.3, []),
    ("guerrero", "guerrero_sprites", "carga", "Estocada de trueno", "07_estocada_trueno", "centro", vuelo(0.65, 0.35), 0.6, [0.35]),
    ("guerrero", "guerrero_sprites", "pantera", "Corte glacial", "02_corte_glacial", "centro", [L("T", 0.05, 0.09, 0.7)], 0.9, [0.3]),
    ("guerrero", "guerrero_sprites", "furia", "Furia carmesí", "06_furia_carmesi", "suelo", [L("GC", 0.0, 0.12, 0.75)], 1.1, []),
    ("guerrero", "guerrero_sprites", "golpe_terrestre", "Golpe titán", "03_golpe_titan", "suelo", [L("GT", 0.0, 0.1, 0.9)], 1.0, [0.4]),
    ("guerrero", "guerrero_sprites", "salto_impacto", "Pisotón sísmico", "08_pisoton_sismico", "suelo", [L("GT", 0.35, 0.1, 1.0)], 1.4, [0.6]),
    ("guerrero", "guerrero_sprites", "estocada_lineal", "Hachas gemelas", "09_hachas_gemelas", "centro", [L("T", 0.1, 0.09, 0.7)], 0.95, [0.3]),
    ("guerrero", "guerrero_sprites", "ejecucion", "Espada celestial", "10_espada_celestial", "suelo", [L("GT", 0.0, 0.11, 0.85)], 1.1, [0.5]),

    ("mago", "mago_sprites", "misil", "Orbe arcano", "06_orbe_arcano", "centro", [L("C", 0.0, 0.05, 0.5, "vuelo", t1=0.45)], 0.55, [0.45]),
    ("mago", "mago_sprites", "fuego", "Bola de fuego", "01_bola_fuego", "centro", vuelo(0.55, 0.55), 0.65, [0.55]),
    ("mago", "mago_sprites", "escudo", "Sanación", "07_sanacion", "suelo", [L("GT", 0.0, 0.12, 0.8)], 1.1, []),
    ("mago", "mago_sprites", "nova", "Ventisca", "05_ventisca", "suelo", [L("GT", 0.0, 0.11, 1.0)], 1.0, [0.4]),
    ("mago", "mago_sprites", "rayo_hielo", "Lanza de hielo", "02_lanza_hielo", "centro", vuelo(0.6, 0.45), 0.55, [0.45]),
    ("mago", "mago_sprites", "rayo_arcano", "Rayo arcano", "03_rayo_arcano", "suelo", [L("GT", 0.0, 0.1, 0.85)], 0.9, [0.3]),
    ("mago", "mago_sprites", "lluvia_fuego", "Dragón de agua", "10_dragon_agua", "centro", [L("GT", 0.0, 0.12, 1.3, off=[0, -30])], 1.1, [0.4]),
    ("mago", "mago_sprites", "teletransporte", "Teletransporte", "08_teletransporte", "base", [L("GT", 0.0, 0.1, 0.8)], 0.9, []),
    ("mago", "mago_sprites", "torbellino", "Pozo de gravedad", "09_pozo_gravedad", "centro", [L("GT", 0.0, 0.12, 1.2, "loop", t1=1.3, off=[0, -20])], 1.6, [0.45, 0.8, 1.15, 1.5]),
    # el meteorito trae dos mitades en una hoja: cuadros 1-4 la roca cayendo en diagonal (cae desde arriba a la izquierda) y 5-8 la explosión en el suelo
    ("mago", "mago_sprites", "meteoro", "Meteorito", "04_meteorito", "partido",
     [L("T", 0.0, 0.1, 0.9, "caida", t1=0.45, off=[-260, -260], s="caida"), L("GT", 0.45, 0.1, 1.1, s="impacto")], 1.2, [0.45]),

    # clérigo: los instantáneos (proyectiles, golpes) duran lo que su secuencia; los que se quedan (escudo, santuario, tormenta) mantienen o repiten sus cuadros mientras duran
    ("clerigo", "clerigo_sprites", "curar", "Cura divina", "01_cura_divina", "suelo", [L("GT", 0.0, 0.12, 0.8)], 1.1, [0.3]),
    ("clerigo", "clerigo_sprites", "bendicion", "Lanza de serafín", "09_lanza_serafin", "centro", vuelo(0.7, 0.45), 0.55, [0.45]),
    ("clerigo", "clerigo_sprites", "castigo", "Bendición sagrada", "02_bendicion_sagrada", "centro", [L("C", 0.0, 0.05, 0.55, "vuelo", t1=0.4)], 0.5, [0.4]),
    ("clerigo", "clerigo_sprites", "consagrar", "Luz purificadora", "04_luz_purificadora", "suelo", [L("GC", 0.0, 0.11, 1.0)], 1.0, [0.4]),
    ("clerigo", "clerigo_sprites", "sanacion", "Santuario", "08_santuario", "suelo", [L("GC", 0.0, 0.12, 1.0, "hold", t1=2.0)], 2.0, [0.4]),
    ("clerigo", "clerigo_sprites", "juicio", "Martillo de justicia", "05_martillo_justicia", "suelo", [L("GT", 0.0, 0.11, 0.85)], 1.0, [0.5]),
    ("clerigo", "clerigo_sprites", "escudo_divino", "Escudo de fe", "03_escudo_fe", "centro", [L("T", 0.0, 0.12, 0.7, "hold", t1=2.5)], 2.5, []),
    ("clerigo", "clerigo_sprites", "cadena_sanacion", "Cadena de luz", "06_cadena_luz", "suelo", [L("GT", 0.0, 0.12, 0.9)], 1.0, [0.3]),
    ("clerigo", "clerigo_sprites", "tormenta_divina", "Juicio celestial", "10_juicio_celestial", "suelo", [L("GT", 0.0, 0.12, 1.0, "loop", t1=1.4)], 1.6, [0.1, 0.45, 0.8]),
    ("clerigo", "clerigo_sprites", "resurreccion", "Resurrección", "07_resurreccion", "suelo", [L("GT", 0.0, 0.14, 0.9)], 1.2, [0.7]),

    ("cazador", "arquero_hd", "disparo", "Flecha de viento", "05_flecha_viento", "centro", vuelo(0.6, 0.4), 0.6, [0.4]),
    ("cazador", "arquero_hd", "lluvia", "Lluvia de flechas", "07_lluvia_flechas", "suelo", [L("GT", 0.05, 0.13, 0.9)], 1.2, [0.5, 0.8]),
    ("cazador", "arquero_hd", "trampa", "Trampa de espinas", "08_trampa_espinas", "suelo", [L("GC", 0.05, 0.14, 0.7)], 1.2, []),
    ("cazador", "arquero_hd", "preciso", "Flecha lunar", "06_flecha_lunar", "centro", vuelo(0.7, 0.45), 0.6, [0.45]),
    ("cazador", "arquero_hd", "flecha_veneno", "Disparo venenoso", "04_disparo_venenoso", "centro", vuelo(0.6, 0.45), 0.6, [0.45]),
    ("cazador", "arquero_hd", "paso_agil", "Flecha relámpago", "03_flecha_relampago", "centro", vuelo(0.6, 0.4), 0.6, [0.4]),
    ("cazador", "arquero_hd", "disparo_multiple", "Flecha fénix", "10_flecha_fenix", "centro", vuelo(0.75, 0.5), 0.65, [0.5]),
    ("cazador", "arquero_hd", "disparo_explosivo", "Disparo explosivo", "09_disparo_explosivo", "centro", [L("T", 0.3, 0.09, 0.9)], 1.2, [0.4]),
    ("cazador", "arquero_hd", "disparo_helado", "Flecha glacial", "02_flecha_glacial", "centro", vuelo(0.65, 0.45), 0.6, [0.45]),
    ("cazador", "arquero_hd", "marca_cazador", "Flecha ígnea", "01_flecha_ignea", "centro", vuelo(0.6, 0.45), 0.6, [0.45]),
]
ANCLAS, MS = {}, {}
PRESENTES = {e[1] for e in EFECTOS if os.path.exists(os.path.join(FUENTE, e[1], "animaciones.json"))}      # (solo se regeneran los paquetes que están en la carpeta)
EFECTOS = [e for e in EFECTOS if e[1] in PRESENTES]
for paquete in sorted(PRESENTES):
    j = json.load(open(os.path.join(FUENTE, paquete, "animaciones.json")))
    MS[paquete] = j["suggested_frame_ms"]
    for s in j["spells"]:
        ANCLAS[(paquete, s["name"])] = s["anchor"]

for clase, paquete, pid, nombre, carpeta, origen, capas, dur, golpes in EFECTOS:
    fr = [Image.open(os.path.join(FUENTE, paquete, carpeta, "%02d.png" % (i + 1))).convert("RGBA") for i in range(8)]
    cajas = [f.getchannel("A").point(lambda v: 255 if v > 12 else 0).getbbox() for f in fr]
    cajas = [c for c in cajas if c]
    x0, y0 = max(0, min(c[0] for c in cajas) - 4), max(0, min(c[1] for c in cajas) - 4)
    x1, y1 = min(CELDA, max(c[2] for c in cajas) + 4), min(CELDA, max(c[3] for c in cajas) + 4)
    w, h = x1 - x0, y1 - y0
    d = os.path.join(AQUI, pid, "sheets")
    os.makedirs(d, exist_ok=True)
    for viejo in os.listdir(d):                                  # (se borra el arte antiguo del poder: solo queda la hoja nueva)
        os.remove(os.path.join(d, viejo))
    if origen == "partido":
        secs = {}
        for nombre_s, rango_f in (("caida", range(0, 4)), ("impacto", range(4, 8))):
            cj = [c for c in (fr[i].getchannel("A").point(lambda v: 255 if v > 12 else 0).getbbox() for i in rango_f) if c]
            sx0, sy0 = max(0, min(c[0] for c in cj) - 4), max(0, min(c[1] for c in cj) - 4)
            sx1, sy1 = min(CELDA, max(c[2] for c in cj) + 4), min(CELDA, max(c[3] for c in cj) + 4)
            sw, sh = sx1 - sx0, sy1 - sy0
            hj = Image.new("RGBA", (sw * 4, sh), (0, 0, 0, 0))
            for k, i in enumerate(rango_f):
                hj.paste(fr[i].crop((sx0, sy0, sx1, sy1)), (k * sw, 0))
            hj.save(os.path.join(d, nombre_s + ".png"), optimize=True)
            secs[nombre_s] = dict(sheet="sheets/%s.png" % nombre_s, frames=4, cell=[sw, sh], origin=[sw // 2, sh // 2 if nombre_s == "caida" else int(sh * 0.62)],
                                  ms_per_frame=float(sum(MS[paquete]) / 8))
        j = dict(id_dos_coronas=pid, clase=clase, nombre=nombre, poder_fao="(secuencia propia: paquete %s)" % paquete, secuencias=secs,
                 composicion=dict(inferida=False, duracion_s=dur, golpes_s=golpes, capas=capas),
                 nota="%s/%s (cuadros 1-4 caída, 5-8 impacto)." % (paquete, carpeta))
        json.dump(j, open(os.path.join(AQUI, pid, "efecto.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
        print(pid, "caida+impacto")
        continue
    hoja = Image.new("RGBA", (w * 8, h), (0, 0, 0, 0))
    for i, f in enumerate(fr):
        hoja.paste(f.crop((x0, y0, x1, y1)), (i * w, 0))
    hoja.save(os.path.join(d, "fx.png"), optimize=True)
    ax, ay = ANCLAS[(paquete, carpeta)]
    if origen == "suelo":
        org = [ax - x0, ay - y0]                     # el ancla del paquete: el suelo del efecto
    elif origen == "base":
        org = [w // 2, int(h * 0.97)]                # un portal de pie sobre el suelo
    else:
        org = [w // 2, h // 2]
    sec = dict(sheet="sheets/fx.png", frames=8, cell=[w, h], origin=org, ms_per_frame=float(sum(MS[paquete]) / 8))
    j = dict(id_dos_coronas=pid, clase=clase, nombre=nombre, poder_fao="(secuencia propia: paquete %s)" % paquete, secuencias=dict(fx=sec),
             composicion=dict(inferida=False, duracion_s=dur, golpes_s=golpes, capas=capas),
             nota="%s/%s (640x640, recortado a %dx%d)." % (paquete, carpeta, w, h))
    json.dump(j, open(os.path.join(AQUI, pid, "efecto.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print(pid, w, h, org)
print("IDS:", " ".join(e[2] for e in EFECTOS))
