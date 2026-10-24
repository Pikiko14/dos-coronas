-- GENERADO por herramientas/generar_efectos_fao_poderes.py desde fao-clases-dc: por poder, duración (s), instantes de golpe y capas con su timeline.
-- capa: s secuencia, w (C/T pecho del lanzador/objetivo, GC/GT suelo, proj viaja de la mano al pecho del objetivo), t0/t1 (s), ms por cuadro (s), sc escala, a opacidad, off desplazamiento (px de FAO),
--       flip, modo (once, loop, hold, step, proj), dur (step), th (ángulo de referencia del step), dir (elige el cuadro por dirección), mezcla (add | alpha).
-- Arte y datos de un juego ajeno (FAO): prototipo.
return {
  alzar_esqueletos = { clase = "nigromante", dur = 1.15, golpes = {  }, capas = {
    { s = "alzar_esqueletos__fx", w = "GC", t0 = 0, ms = 0.13, sc = 0.8, a = 1, modo = "once", dir = false, mezcla = "alpha" },
  } },
  barrido = { clase = "lancero", dur = 0.95, golpes = { 0.3 }, capas = {
    { s = "barrido__fx", w = "GC", t0 = 0.05, ms = 0.055, sc = 0.85, a = 1, modo = "once", dir = false, mezcla = "add" },
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
  drenar = { clase = "nigromante", dur = 1, golpes = { 0.45 }, capas = {
    { s = "drenar__fx", w = "GT", t0 = 0, ms = 0.11, sc = 0.85, a = 1, modo = "once", dir = false, mezcla = "alpha" },
  } },
  ejecucion = { clase = "guerrero", dur = 1, golpes = { 0.5 }, capas = {
    { s = "ejecucion__fx", w = "GT", t0 = 0, ms = 0.06, sc = 1, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  embestida = { clase = "lancero", dur = 0.8, golpes = { 0.4 }, capas = {
    { s = "embestida__fx", w = "T", t0 = 0, ms = 0.03, sc = 0.9, a = 1, modo = "estela", t1 = 0.4, dir = false, mezcla = "add" },
  } },
  escudo = { clase = "mago", dur = 0.9, golpes = {  }, capas = {
    { s = "escudo__cupula", w = "C", t0 = 0, ms = 0.09, sc = 1.2, a = 1, modo = "once", off = { 0, 4 }, dir = false, mezcla = "add" },
  } },
  escudo_divino = { clase = "clerigo", dur = 1.05, golpes = { 0.2 }, capas = {
    { s = "escudo_divino__fx", w = "T", t0 = 0, ms = 0.065, sc = 0.7, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  escudo_huesos = { clase = "nigromante", dur = 1, golpes = {  }, capas = {
    { s = "escudo_huesos__fx", w = "C", t0 = 0, ms = 0.12, sc = 0.7, a = 1, modo = "once", dir = false, mezcla = "alpha" },
  } },
  espinas = { clase = "nigromante", dur = 1, golpes = { 0.35 }, capas = {
    { s = "espinas__fx", w = "GT", t0 = 0, ms = 0.1, sc = 0.85, a = 1, modo = "once", dir = false, mezcla = "alpha" },
  } },
  estocada = { clase = "lancero", dur = 0.55, golpes = { 0.2 }, capas = {
    { s = "estocada__fx", w = "T", t0 = 0, ms = 0.025, sc = 0.8, a = 1, modo = "estela", t1 = 0.3, dir = false, mezcla = "add" },
  } },
  estocada_lineal = { clase = "guerrero", dur = 0.75, golpes = { 0.4 }, capas = {
    { s = "estocada_lineal__fx", w = "T", t0 = 0.05, ms = 0.03, sc = 0.8, a = 1, modo = "estela", t1 = 0.4, dir = false, mezcla = "add" },
  } },
  explosion_cadaverica = { clase = "nigromante", dur = 0.9, golpes = { 0.4 }, capas = {
    { s = "explosion_cadaverica__fx", w = "GT", t0 = 0, ms = 0.1, sc = 0.9, a = 1, modo = "once", dir = false, mezcla = "alpha" },
  } },
  fisura_del_lancero = { clase = "lancero", dur = 1, golpes = { 0.4 }, capas = {
    { s = "fisura_del_lancero__fx", w = "GT", t0 = 0, ms = 0.06, sc = 0.95, a = 1, modo = "once", dir = false, mezcla = "add" },
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
  jabalina = { clase = "lancero", dur = 1.1, golpes = { 0.5 }, capas = {
    { s = "jabalina__fx", w = "GT", t0 = 0.1, ms = 0.06, sc = 0.8, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  juicio = { clase = "clerigo", dur = 1.05, golpes = { 0.5 }, capas = {
    { s = "juicio__fx", w = "GT", t0 = 0.05, ms = 0.06, sc = 0.9, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  juicio_final = { clase = "lancero", dur = 1.3, golpes = { 0.5, 0.8, 1.1 }, capas = {
    { s = "juicio_final__fx", w = "GT", t0 = 0.05, ms = 0.075, sc = 1, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  lanza_osea = { clase = "nigromante", dur = 0.55, golpes = { 0.36 }, capas = {
    { s = "lanza_osea__fx", w = "C", t0 = 0, ms = 0.05, sc = 0.65, a = 1, modo = "vuelo", t1 = 0.36, giro = "libre", dir = false, mezcla = "alpha" },
  } },
  lluvia = { clase = "cazador", dur = 1.2, golpes = { 0.5, 0.8 }, capas = {
    { s = "lluvia__fx", w = "GT", t0 = 0.05, ms = 0.07, sc = 0.9, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  lluvia_fuego = { clase = "mago", dur = 1.1, golpes = { 0.5, 0.8 }, capas = {
    { s = "lluvia_fuego__caida", w = "GT", t0 = 0, ms = 0.07, sc = 1.6, a = 1, modo = "once", off = { 0, -10 }, dir = false, mezcla = "add" },
    { s = "lluvia_fuego__suelo", w = "GT", t0 = 0.49, ms = 0.12, sc = 1.6, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  lluvia_profana = { clase = "nigromante", dur = 1.45, golpes = { 0.4, 0.8, 1.2 }, capas = {
    { s = "lluvia_profana__fx", w = "GT", t0 = 0, ms = 0.13, sc = 0.9, a = 1, modo = "loop", t1 = 1.25, dir = false, mezcla = "alpha" },
  } },
  maldecir = { clase = "nigromante", dur = 1.1, golpes = { 0.4 }, capas = {
    { s = "maldecir__fx", w = "GT", t0 = 0, ms = 0.11, sc = 0.8, a = 1, modo = "once", dir = false, mezcla = "alpha" },
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
  muro_lanzas = { clase = "lancero", dur = 1.15, golpes = {  }, capas = {
    { s = "muro_lanzas__fx", w = "GC", t0 = 0, ms = 0.07, sc = 0.85, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  nova = { clase = "mago", dur = 0.95, golpes = { 0.35 }, capas = {
    { s = "nova__hielo", w = "GT", t0 = 0, ms = 0.09, sc = 1.4, a = 1, modo = "once", off = { 0, -6 }, dir = false, mezcla = "add" },
  } },
  nova_oscura = { clase = "nigromante", dur = 0.9, golpes = { 0.3 }, capas = {
    { s = "nova_oscura__fx", w = "GC", t0 = 0, ms = 0.1, sc = 1, a = 1, modo = "once", dir = false, mezcla = "alpha" },
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
  pulso_terrestre = { clase = "lancero", dur = 1, golpes = { 0.35 }, capas = {
    { s = "pulso_terrestre__fx", w = "GC", t0 = 0, ms = 0.06, sc = 0.95, a = 1, modo = "once", dir = false, mezcla = "add" },
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
  toque_necro = { clase = "nigromante", dur = 0.62, golpes = { 0.42 }, capas = {
    { s = "toque_necro__fx", w = "C", t0 = 0, ms = 0.05, sc = 0.55, a = 1, modo = "vuelo", t1 = 0.42, giro = "espejo", dir = false, mezcla = "alpha" },
  } },
  torbellino = { clase = "mago", dur = 1.6, golpes = { 0.45, 0.8, 1.15, 1.5 }, capas = {
    { s = "torbellino__giro", w = "GT", t0 = 0, ms = 0.15, sc = 1.1, a = 1, modo = "loop", t1 = 1.3, off = { 0, -6 }, dir = false, mezcla = "add" },
    { s = "torbellino__fin", w = "GT", t0 = 1.3, ms = 0.3, sc = 1.1, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  torbellino_lanzas = { clase = "lancero", dur = 1.7, golpes = { 0.4, 0.8, 1.2, 1.6 }, capas = {
    { s = "torbellino_lanzas__fx", w = "GC", t0 = 0, ms = 0.1, sc = 0.85, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  tormenta_divina = { clase = "clerigo", dur = 1.2, golpes = { 0.5, 0.75, 1 }, capas = {
    { s = "tormenta_divina__fx", w = "GT", t0 = 0.05, ms = 0.07, sc = 1, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  tormenta_lanzas = { clase = "lancero", dur = 1.2, golpes = { 0.5 }, capas = {
    { s = "tormenta_lanzas__fx", w = "GT", t0 = 0.05, ms = 0.07, sc = 0.95, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
  trampa = { clase = "cazador", dur = 1.2, golpes = {  }, capas = {
    { s = "trampa__fx", w = "GC", t0 = 0.05, ms = 0.07, sc = 0.8, a = 1, modo = "once", dir = false, mezcla = "add" },
  } },
}
