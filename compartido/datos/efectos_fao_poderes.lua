-- GENERADO por herramientas/generar_efectos_fao_poderes.py desde fao-clases-dc: por poder, duración (s), instantes de golpe y capas con su timeline.
-- capa: s secuencia, w (C/T pecho del lanzador/objetivo, GC/GT suelo, proj viaja de la mano al pecho del objetivo), t0/t1 (s), ms por cuadro (s), sc escala, a opacidad, off desplazamiento (px de FAO),
--       flip, modo (once, loop, hold, step, proj), dur (step), th (ángulo de referencia del step), dir (elige el cuadro por dirección), mezcla (add | alpha).
-- Arte y datos de un juego ajeno (FAO): prototipo.
return {
  alzar_esqueletos = { clase = "nigromante", dur = 3, golpes = {  }, capas = {
    { s = "alzar_esqueletos__G20001", w = "GC", t0 = 0.35, ms = 0.0167, sc = 0.7, a = 1, modo = "once", off = { 90, 8 }, dir = false, mezcla = "add" },
    { s = "alzar_esqueletos__G50001", w = "GC", t0 = 0.55, ms = 0.0167, sc = 0.7, a = 1, modo = "once", off = { 150, 22 }, dir = false, mezcla = "add" },
    { s = "alzar_esqueletos__1190001", w = "GC", t0 = 0.35, ms = 0.0667, sc = 1, a = 1, modo = "once", off = { 90, 4 }, dir = false, mezcla = "add" },
    { s = "alzar_esqueletos__b01", w = "GC", t0 = 0.5, ms = 0.05, sc = 1, a = 1, modo = "once", off = { 150, 20 }, dir = false, mezcla = "add" },
  } },
  barrido = { clase = "lancero", dur = 1.8, golpes = { 0.5 }, capas = {
    { s = "barrido__s4240105", w = "C", t0 = 0.2, ms = 0.05, sc = 1.2, a = 1, modo = "once", dir = false, mezcla = "add" },
    { s = "barrido__s4220303", w = "GC", t0 = 0.3, ms = 0.05, sc = 0.9, a = 1, modo = "once", dir = false, mezcla = "add" },
    { s = "barrido__s4270103", w = "GC", t0 = 0.55, ms = 0.05, sc = 1, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  bendicion = { clase = "clerigo", dur = 1.1, golpes = { 0.4 }, capas = {
    { s = "bendicion__fx", w = "GT", t0 = 0.1, ms = 0.06, sc = 0.8, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  cadena_sanacion = { clase = "clerigo", dur = 1, golpes = { 0.3 }, capas = {
    { s = "cadena_sanacion__fx", w = "T", t0 = 0, ms = 0.06, sc = 0.8, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  carga = { clase = "guerrero", dur = 0.9, golpes = { 0.45 }, capas = {
    { s = "carga__fx", w = "T", t0 = 0, ms = 0.035, sc = 0.7, a = 1, modo = "estela", t1 = 0.45, dir = false, mezcla = "add" },
  } },
  castigo = { clase = "clerigo", dur = 0.9, golpes = { 0.3 }, capas = {
    { s = "castigo__fx", w = "GT", t0 = 0.05, ms = 0.05, sc = 0.75, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  consagrar = { clase = "clerigo", dur = 1.2, golpes = { 0.5 }, capas = {
    { s = "consagrar__fx", w = "GC", t0 = 0.05, ms = 0.07, sc = 0.95, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  curar = { clase = "clerigo", dur = 1.05, golpes = { 0.3 }, capas = {
    { s = "curar__fx", w = "GT", t0 = 0.05, ms = 0.06, sc = 0.8, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  disparo = { clase = "cazador", dur = 0.75, golpes = { 0.4 }, capas = {
    { s = "disparo__fx", w = "T", t0 = 0, ms = 0.035, sc = 0.7, a = 1, modo = "estela", t1 = 0.4, dir = false, mezcla = "add" },
  } },
  disparo_explosivo = { clase = "cazador", dur = 1.3, golpes = { 0.4 }, capas = {
    { s = "disparo_explosivo__fx", w = "GT", t0 = 0.3, ms = 0.06, sc = 0.9, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  disparo_helado = { clase = "cazador", dur = 0.8, golpes = { 0.45 }, capas = {
    { s = "disparo_helado__fx", w = "T", t0 = 0, ms = 0.04, sc = 0.9, a = 1, modo = "estela", t1 = 0.45, dir = false, mezcla = "add" },
  } },
  disparo_multiple = { clase = "cazador", dur = 0.8, golpes = { 0.45 }, capas = {
    { s = "disparo_multiple__fx", w = "T", t0 = 0, ms = 0.04, sc = 1, a = 1, modo = "estela", t1 = 0.45, dir = false, mezcla = "add" },
  } },
  drenar = { clase = "nigromante", dur = 2.1, golpes = { 0.8 }, capas = {
    { s = "drenar__1250010", w = "T", t0 = 0.25, ms = 0.08, sc = 0.55, a = 1, modo = "loop", t1 = 1.4, dir = false, mezcla = "add" },
    { s = "drenar__1160001", w = "T", t0 = 0.3, ms = 0.08, sc = 1, a = 1, modo = "once", dir = false, mezcla = "add" },
    { s = "drenar__a010301", w = "C", t0 = 1.1, ms = 0.1, sc = 1, a = 1, modo = "once", dir = false, mezcla = "add" },
    { s = "drenar__N270003", w = "C", t0 = 1.25, ms = 0.1, sc = 1, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  ejecucion = { clase = "guerrero", dur = 1, golpes = { 0.5 }, capas = {
    { s = "ejecucion__fx", w = "GT", t0 = 0, ms = 0.06, sc = 1, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  embestida = { clase = "lancero", dur = 2.2, golpes = { 0.75 }, capas = {
    { s = "embestida__S3930105", w = "proj", t0 = 0.25, ms = 0.0667, sc = 0.8, a = 0.85, modo = "proj", t1 = 0.72, dir = true, mezcla = "add" },
    { s = "embestida__S3930305", w = "proj", t0 = 0.25, ms = 0.0667, sc = 0.8, a = 0.6, modo = "proj", t1 = 0.72, off = { -20, 0 }, dir = true, mezcla = "add" },
  } },
  escudo = { clase = "mago", dur = 0.9, golpes = {  }, capas = {
    { s = "escudo__cupula", w = "C", t0 = 0, ms = 0.09, sc = 1.2, a = 1, modo = "once", off = { 0, 4 }, dir = false, mezcla = "add" },
  } },
  escudo_divino = { clase = "clerigo", dur = 1.05, golpes = { 0.2 }, capas = {
    { s = "escudo_divino__fx", w = "T", t0 = 0, ms = 0.065, sc = 0.7, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  espectro = { clase = "nigromante", dur = 3.2, golpes = {  }, capas = {
    { s = "espectro__s2370101", w = "GC", t0 = 0.4, ms = 0.0667, sc = 0.6, a = 1, modo = "once", off = { 110, 10 }, dir = false, mezcla = "add" },
    { s = "espectro__s237011", w = "GC", t0 = 0.4, ms = 0.1, sc = 0.6, a = 1, modo = "once", off = { 110, 10 }, dir = false, mezcla = "add" },
    { s = "espectro__s238011", w = "GC", t0 = 1, ms = 0.0167, sc = 0.55, a = 1, modo = "once", off = { 110, 10 }, dir = false, mezcla = "add" },
    { s = "espectro__s236011", w = "GC", t0 = 0.3, ms = 0.0167, sc = 0.6, a = 1, modo = "once", off = { 110, 10 }, dir = false, mezcla = "add" },
  } },
  espinas = { clase = "nigromante", dur = 3, golpes = { 0.9, 1.4 }, capas = {
    { s = "espinas__s094011", w = "GT", t0 = 0.25, ms = 0.0667, sc = 0.7, a = 1, modo = "loop", t1 = 2.7, dir = false, mezcla = "alpha" },
    { s = "espinas__s094011", w = "GT", t0 = 0.45, ms = 0.0667, sc = 0.45, a = 0.8, modo = "loop", t1 = 2.7, dir = false, mezcla = "alpha" },
  } },
  estocada = { clase = "lancero", dur = 1.4, golpes = { 0.4 }, capas = {
    { s = "estocada__s4180103", w = "T", t0 = 0.22, ms = 0.0333, sc = 1, a = 0.95, modo = "step", off = { -30, 0 }, dur = 0.0333, th = 0, dir = true, mezcla = "add" },
    { s = "estocada__s4180203", w = "T", t0 = 0.2533, ms = 0.0333, sc = 1, a = 0.95, modo = "step", off = { -30, 0 }, dur = 0.0333, th = 0, dir = true, mezcla = "add" },
    { s = "estocada__s4180303", w = "T", t0 = 0.2867, ms = 0.0333, sc = 1, a = 0.95, modo = "step", off = { -30, 0 }, dur = 0.0333, th = 0, dir = true, mezcla = "add" },
    { s = "estocada__s4180403", w = "T", t0 = 0.32, ms = 0.0333, sc = 1, a = 0.95, modo = "step", off = { -30, 0 }, dur = 0.0333, th = 0, dir = true, mezcla = "add" },
    { s = "estocada__s4180503", w = "T", t0 = 0.3533, ms = 0.0333, sc = 1, a = 0.95, modo = "step", off = { -30, 0 }, dur = 0.0333, th = 0, dir = true, mezcla = "add" },
    { s = "estocada__s4180603", w = "T", t0 = 0.3867, ms = 0.0333, sc = 1, a = 0.95, modo = "step", off = { -30, 0 }, dur = 0.0333, th = 0, dir = true, mezcla = "add" },
  } },
  estocada_lineal = { clase = "guerrero", dur = 0.75, golpes = { 0.4 }, capas = {
    { s = "estocada_lineal__fx", w = "T", t0 = 0.05, ms = 0.03, sc = 0.8, a = 1, modo = "estela", t1 = 0.4, dir = false, mezcla = "add" },
  } },
  flecha_veneno = { clase = "cazador", dur = 0.8, golpes = { 0.45 }, capas = {
    { s = "flecha_veneno__fx", w = "T", t0 = 0, ms = 0.04, sc = 0.8, a = 1, modo = "estela", t1 = 0.45, dir = false, mezcla = "add" },
  } },
  fuego = { clase = "mago", dur = 0.85, golpes = { 0.55 }, capas = {
    { s = "fuego__carga", w = "C", t0 = 0, ms = 0.06, sc = 0.8, a = 1, modo = "once", dir = false, mezcla = "add" },
    { s = "fuego__estela", w = "T", t0 = 0.3, ms = 0.05, sc = 0.9, a = 1, modo = "estela", t1 = 0.56, dir = false, mezcla = "add" },
    { s = "fuego__impacto", w = "T", t0 = 0.55, ms = 0.08, sc = 1.4, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  furia = { clase = "guerrero", dur = 1, golpes = {  }, capas = {
    { s = "furia__fx", w = "C", t0 = 0, ms = 0.06, sc = 0.7, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  golpe = { clase = "guerrero", dur = 0.95, golpes = { 0.35 }, capas = {
    { s = "golpe__fx", w = "T", t0 = 0.1, ms = 0.05, sc = 0.8, a = 1, modo = "once", off = { 0, -8 }, dir = false, mezcla = "add" },
  } },
  golpe_terrestre = { clase = "guerrero", dur = 1.05, golpes = { 0.5 }, capas = {
    { s = "golpe_terrestre__fx", w = "GT", t0 = 0.05, ms = 0.06, sc = 0.9, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  grito = { clase = "guerrero", dur = 1.1, golpes = {  }, capas = {
    { s = "grito__fx", w = "GC", t0 = 0.05, ms = 0.065, sc = 0.95, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  jabalina = { clase = "lancero", dur = 1.627, golpes = { 0.527 }, capas = {
    { s = "jabalina__spear", w = "proj", t0 = 0.25, ms = 0.08, sc = 0.7, a = 1, modo = "proj", t1 = 0.4767, dir = false, mezcla = "add" },
    { s = "jabalina__hit", w = "T", t0 = 0.4767, ms = 0.06, sc = 0.9, a = 1, modo = "once", dir = false, mezcla = "add" },
    { s = "jabalina__wave", w = "GT", t0 = 0.5067, ms = 0.05, sc = 0.8, a = 0.9, modo = "once", dir = false, mezcla = "add" },
  } },
  juicio = { clase = "clerigo", dur = 1.05, golpes = { 0.5 }, capas = {
    { s = "juicio__fx", w = "GT", t0 = 0.05, ms = 0.06, sc = 0.9, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  lluvia = { clase = "cazador", dur = 1.2, golpes = { 0.5, 0.8 }, capas = {
    { s = "lluvia__fx", w = "GT", t0 = 0.05, ms = 0.07, sc = 0.9, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  lluvia_fuego = { clase = "mago", dur = 1.1, golpes = { 0.5, 0.8 }, capas = {
    { s = "lluvia_fuego__caida", w = "GT", t0 = 0, ms = 0.07, sc = 1.6, a = 1, modo = "once", off = { 0, -10 }, dir = false, mezcla = "add" },
    { s = "lluvia_fuego__suelo", w = "GT", t0 = 0.49, ms = 0.12, sc = 1.6, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  maldecir = { clase = "nigromante", dur = 3, golpes = { 0.7 }, capas = {
    { s = "maldecir__Ini", w = "T", t0 = 0.2, ms = 0.05, sc = 0.9, a = 1, modo = "once", dir = false, mezcla = "add" },
    { s = "maldecir__Line", w = "T", t0 = 0.55, ms = 0.08, sc = 0.9, a = 1, modo = "once", dir = false, mezcla = "add" },
    { s = "maldecir__Bu", w = "GT", t0 = 0.8, ms = 0.1, sc = 0.8, a = 1, modo = "once", dir = false, mezcla = "add" },
    { s = "maldecir__Ms", w = "T", t0 = 1.3, ms = 0.1, sc = 1, a = 1, modo = "once", off = { 0, -60 }, dir = false, mezcla = "add" },
  } },
  marca_cazador = { clase = "cazador", dur = 1.2, golpes = { 0.3 }, capas = {
    { s = "marca_cazador__fx", w = "GT", t0 = 0.05, ms = 0.07, sc = 0.85, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  meteoro = { clase = "mago", dur = 1.3, golpes = { 0.5 }, capas = {
    { s = "meteoro__caida", w = "T", t0 = 0, ms = 0.1, sc = 1.2, a = 1, modo = "caida", t1 = 0.5, off = { -90, -300 }, dir = false, mezcla = "add" },
    { s = "meteoro__impacto", w = "GT", t0 = 0.5, ms = 0.12, sc = 1.5, a = 1, modo = "once", off = { 0, -10 }, dir = false, mezcla = "add" },
  } },
  misil = { clase = "mago", dur = 0.8, golpes = { 0.42 }, capas = {
    { s = "misil__orbe", w = "C", t0 = 0.05, ms = 0.07, sc = 0.8, a = 1, modo = "proj", t1 = 0.42, dir = false, mezcla = "add" },
    { s = "misil__impacto", w = "T", t0 = 0.42, ms = 0.07, sc = 1.1, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  muro_lanzas = { clase = "lancero", dur = 3.2, golpes = {  }, capas = {
    { s = "muro_lanzas__Effect", w = "C", t0 = 0.2, ms = 0.08, sc = 1, a = 1, modo = "once", dir = false, mezcla = "add" },
    { s = "muro_lanzas__Scale", w = "C", t0 = 0.45, ms = 0.12, sc = 0.65, a = 1, modo = "loop", t1 = 2.9, off = { 0, -10 }, dir = false, mezcla = "add" },
  } },
  nova = { clase = "mago", dur = 0.95, golpes = { 0.35 }, capas = {
    { s = "nova__hielo", w = "GT", t0 = 0, ms = 0.09, sc = 1.4, a = 1, modo = "once", off = { 0, -6 }, dir = false, mezcla = "add" },
  } },
  pantera = { clase = "guerrero", dur = 0.9, golpes = { 0.5 }, capas = {
    { s = "pantera__fx", w = "T", t0 = 0.1, ms = 0.04, sc = 0.9, a = 1, modo = "estela", t1 = 0.5, dir = false, mezcla = "add" },
  } },
  paso_agil = { clase = "cazador", dur = 1, golpes = {  }, capas = {
    { s = "paso_agil__fx", w = "C", t0 = 0, ms = 0.06, sc = 0.8, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  preciso = { clase = "cazador", dur = 0.8, golpes = { 0.45 }, capas = {
    { s = "preciso__fx", w = "T", t0 = 0, ms = 0.04, sc = 0.9, a = 1, modo = "estela", t1 = 0.45, dir = false, mezcla = "add" },
  } },
  rayo_arcano = { clase = "mago", dur = 0.9, golpes = { 0.5 }, capas = {
    { s = "rayo_arcano__carga", w = "C", t0 = 0, ms = 0.09, sc = 0.9, a = 1, modo = "once", dir = false, mezcla = "add" },
    { s = "rayo_arcano__haz", w = "T", t0 = 0.2, ms = 0.05, sc = 1, a = 1, modo = "estela", t1 = 0.6, dir = false, mezcla = "add" },
    { s = "rayo_arcano__impacto", w = "T", t0 = 0.5, ms = 0.08, sc = 1.4, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  rayo_hielo = { clase = "mago", dur = 0.95, golpes = { 0.5 }, capas = {
    { s = "rayo_hielo__chispa", w = "C", t0 = 0, ms = 0.12, sc = 0.9, a = 1, modo = "once", dir = false, mezcla = "add" },
    { s = "rayo_hielo__lanza", w = "T", t0 = 0.15, ms = 0.05, sc = 0.9, a = 1, modo = "estela", t1 = 0.5, dir = false, mezcla = "add" },
    { s = "rayo_hielo__impacto", w = "T", t0 = 0.5, ms = 0.08, sc = 1.2, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  resurreccion = { clase = "clerigo", dur = 1.2, golpes = { 0.5 }, capas = {
    { s = "resurreccion__fx", w = "GT", t0 = 0, ms = 0.07, sc = 0.85, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  salto_impacto = { clase = "guerrero", dur = 1.15, golpes = { 0.6 }, capas = {
    { s = "salto_impacto__fx", w = "GT", t0 = 0, ms = 0.07, sc = 0.9, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  sanacion = { clase = "clerigo", dur = 1.2, golpes = { 0.5 }, capas = {
    { s = "sanacion__fx", w = "GC", t0 = 0.05, ms = 0.07, sc = 1, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  tajo = { clase = "guerrero", dur = 1.05, golpes = { 0.35 }, capas = {
    { s = "tajo__fx", w = "GC", t0 = 0.05, ms = 0.06, sc = 0.8, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  teletransporte = { clase = "mago", dur = 0.85, golpes = {  }, capas = {
    { s = "teletransporte__portal", w = "GT", t0 = 0, ms = 0.07, sc = 1.3, a = 1, modo = "once", off = { 0, -10 }, dir = false, mezcla = "add" },
  } },
  toque_necro = { clase = "nigromante", dur = 1.647, golpes = { 0.447 }, capas = {
    { s = "toque_necro__s2040105", w = "proj", t0 = 0.22, ms = 0.1333, sc = 0.9, a = 1, modo = "proj", t1 = 0.4467, dir = true, mezcla = "alpha" },
    { s = "toque_necro__s204013", w = "T", t0 = 0.4467, ms = 0.1333, sc = 1, a = 1, modo = "step", dur = 0.1333, th = 0, dir = true, mezcla = "add" },
    { s = "toque_necro__s204023", w = "T", t0 = 0.5801, ms = 0.1333, sc = 1, a = 1, modo = "step", dur = 0.1333, th = 0, dir = true, mezcla = "add" },
    { s = "toque_necro__s204033", w = "T", t0 = 0.7134, ms = 0.1333, sc = 1, a = 1, modo = "step", dur = 0.1333, th = 0, dir = true, mezcla = "add" },
    { s = "toque_necro__s204043", w = "T", t0 = 0.8467, ms = 0.1333, sc = 1, a = 1, modo = "step", dur = 0.1333, th = 0, dir = true, mezcla = "add" },
    { s = "toque_necro__s204053", w = "T", t0 = 0.9801, ms = 0.1333, sc = 1, a = 1, modo = "step", dur = 0.1333, th = 0, dir = true, mezcla = "add" },
    { s = "toque_necro__s204063", w = "T", t0 = 1.1134, ms = 0.1333, sc = 1, a = 1, modo = "step", dur = 0.1333, th = 0, dir = true, mezcla = "add" },
  } },
  torbellino = { clase = "mago", dur = 1.6, golpes = { 0.45, 0.8, 1.15, 1.5 }, capas = {
    { s = "torbellino__giro", w = "GT", t0 = 0, ms = 0.15, sc = 1.1, a = 1, modo = "loop", t1 = 1.3, off = { 0, -6 }, dir = false, mezcla = "add" },
    { s = "torbellino__fin", w = "GT", t0 = 1.3, ms = 0.3, sc = 1.1, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  tormenta_divina = { clase = "clerigo", dur = 1.2, golpes = { 0.5, 0.75, 1 }, capas = {
    { s = "tormenta_divina__fx", w = "GT", t0 = 0.05, ms = 0.07, sc = 1, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  tormenta_lanzas = { clase = "lancero", dur = 3, golpes = { 0.9, 1.2, 1.5 }, capas = {
    { s = "tormenta_lanzas__G0109", w = "GT", t0 = 0.2, ms = 0.03, sc = 0.9, a = 1, modo = "once", off = { -70, -25 }, dir = false, mezcla = "add" },
    { s = "tormenta_lanzas__G0109", w = "GT", t0 = 0.33, ms = 0.03, sc = 0.9, a = 1, modo = "once", off = { -17, 12 }, dir = false, mezcla = "add" },
    { s = "tormenta_lanzas__G0109", w = "GT", t0 = 0.46, ms = 0.03, sc = 0.9, a = 1, modo = "once", off = { 36, -1 }, dir = false, mezcla = "add" },
    { s = "tormenta_lanzas__G0109", w = "GT", t0 = 0.59, ms = 0.03, sc = 0.9, a = 1, modo = "once", off = { -51, -14 }, dir = false, mezcla = "add" },
    { s = "tormenta_lanzas__G0109", w = "GT", t0 = 0.72, ms = 0.03, sc = 0.9, a = 1, modo = "once", off = { 2, 23 }, dir = false, mezcla = "add" },
    { s = "tormenta_lanzas__G0109", w = "GT", t0 = 0.85, ms = 0.03, sc = 0.9, a = 1, modo = "once", off = { 55, 10 }, dir = false, mezcla = "add" },
    { s = "tormenta_lanzas__G0109", w = "GT", t0 = 0.98, ms = 0.03, sc = 0.9, a = 1, modo = "once", off = { -32, -3 }, dir = false, mezcla = "add" },
    { s = "tormenta_lanzas__G0109", w = "GT", t0 = 1.11, ms = 0.03, sc = 0.9, a = 1, modo = "once", off = { 21, -16 }, dir = false, mezcla = "add" },
    { s = "tormenta_lanzas__S0109", w = "GT", t0 = 0.55, ms = 0.05, sc = 1, a = 0.95, modo = "once", off = { -75, -30 }, dir = false, mezcla = "add" },
    { s = "tormenta_lanzas__S0209", w = "GT", t0 = 0.69, ms = 0.05, sc = 1, a = 0.95, modo = "once", off = { -14, -1 }, dir = false, mezcla = "add" },
    { s = "tormenta_lanzas__S0309", w = "GT", t0 = 0.83, ms = 0.05, sc = 1, a = 0.95, modo = "once", off = { 47, 28 }, dir = false, mezcla = "add" },
    { s = "tormenta_lanzas__S0409", w = "GT", t0 = 0.97, ms = 0.05, sc = 1, a = 0.95, modo = "once", off = { -42, -3 }, dir = false, mezcla = "add" },
    { s = "tormenta_lanzas__S0509", w = "GT", t0 = 1.11, ms = 0.05, sc = 1, a = 0.95, modo = "once", off = { 19, 26 }, dir = false, mezcla = "add" },
    { s = "tormenta_lanzas__S0609", w = "GT", t0 = 1.25, ms = 0.05, sc = 1, a = 0.95, modo = "once", off = { -70, -5 }, dir = false, mezcla = "add" },
    { s = "tormenta_lanzas__S0709", w = "GT", t0 = 1.39, ms = 0.05, sc = 1, a = 0.95, modo = "once", off = { -9, 24 }, dir = false, mezcla = "add" },
    { s = "tormenta_lanzas__S0809", w = "GT", t0 = 1.53, ms = 0.05, sc = 1, a = 0.95, modo = "once", off = { 52, -7 }, dir = false, mezcla = "add" },
    { s = "tormenta_lanzas__S0909", w = "GT", t0 = 1.67, ms = 0.05, sc = 1, a = 0.95, modo = "once", off = { -37, 22 }, dir = false, mezcla = "add" },
    { s = "tormenta_lanzas__S1009", w = "GT", t0 = 1.81, ms = 0.05, sc = 1, a = 0.95, modo = "once", off = { 24, -9 }, dir = false, mezcla = "add" },
    { s = "tormenta_lanzas__S1109", w = "GT", t0 = 1.95, ms = 0.05, sc = 1, a = 0.95, modo = "once", off = { -65, 20 }, dir = false, mezcla = "add" },
  } },
  trampa = { clase = "cazador", dur = 1.2, golpes = {  }, capas = {
    { s = "trampa__fx", w = "GC", t0 = 0.05, ms = 0.07, sc = 0.8, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
}
