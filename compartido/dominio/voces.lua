-- Voz de cada criatura: a qué familia de sonidos pertenece (el cliente sintetiza los gruñidos, quejidos y muertes de cada familia).
-- Familias: bestia, pequeno, insecto, no_muerto, demonio, dragon, constructo, planta, humanoide.
local M = {}

M.FAMILIAS = { "bestia", "pequeno", "insecto", "no_muerto", "demonio", "dragon", "constructo", "planta", "humanoide" }

local VOZ = {
  -- bestias
  leon_crin = "bestia", ogro_palido = "humanoide", jefe_manada = "bestia", oso_gigante = "bestia", centauro = "bestia", yeti = "bestia",
  bestia_espectral = "bestia", jefe_wyvern_carmesi = "dragon", jefe_rey_esqueleto = "no_muerto", bestia_cornuda = "bestia", jefe_gorila_bosque = "bestia", jefe_gorila_ceniza = "bestia",
  jefe_senor_astado = "bestia", cocodrilo_arena = "bestia", cocodrilo_verde = "bestia",
  -- pequeñas y voladoras
  seta_azul = "pequeno", hongo_palido = "pequeno", hongo_rojo = "pequeno", rana_hojas = "pequeno", sapo_dorado = "pequeno", sapo = "pequeno",
  pinguino_aprendiz = "pequeno", pinguino_centinela = "pequeno", duende_bruma = "pequeno", murcielago_purpura = "pequeno",
  limo = "pequeno", espantapajaros = "pequeno", diablillo_azul = "pequeno", diablillo_acorazado = "pequeno", espiritu_cristal = "pequeno",
  -- insectos y arácnidos
  larva_verde = "insecto", larva_espinosa = "insecto", libelula_cian = "insecto", polilla_rosa = "insecto", escarabajo_dorado = "insecto",
  escarabajo_ciervo = "insecto", arana_azul = "insecto", cangrejo_calabaza = "insecto", cangrejo_espinoso = "insecto", cangrejo_loto = "insecto",
  escorpion_hielo = "insecto", tortuga_espinosa = "insecto", tortuga_coral = "insecto", anquilosaurio = "dragon",
  -- no muertos y espectros
  esqueleto = "no_muerto", esqueleto_soldado = "no_muerto", esqueleto_arquero = "no_muerto", momia = "no_muerto", vampiro = "no_muerto",
  espiritu_velo = "no_muerto", dama_velo = "no_muerto", reina_velo = "no_muerto", medusa_violeta = "no_muerto", calamar_espectral = "no_muerto",
  calamar_puas = "no_muerto", lancero_dorado = "humanoide", reina_espejos = "no_muerto", jefe_rey_momia = "no_muerto",
  jefe_soberano_eclipse = "no_muerto", reina_avispa = "no_muerto",
  -- demonios
  diablillo_lancero = "demonio", jefe_diablo_brasas = "demonio",
  -- dragones y serpientes
  jefe_basilisco_dorado = "dragon", jefe_dragon_sombra = "dragon", jefe_estegosaurio_musgo = "dragon", jefe_estegosaurio_venenoso = "dragon",
  medusa_guerrera = "dragon", elemental_brasas = "dragon",
  -- constructos y gigantes de piedra
  golem_musgo = "constructo", golem_trepador = "constructo", golem_cristal = "constructo", coloso = "constructo", gigante_guerra = "constructo",
  troll_acorazado = "constructo", troll_escarcha = "constructo", jefe_orco_glacial = "constructo",
  -- criaturas de nivel 31-50 (altos.py)
  minotauro_guerra = "bestia", diablo_acorazado = "demonio", lancero_sombras = "humanoide", reptil_huesos = "no_muerto", duende_guerra = "humanoide",
  titan_hielo = "constructo", golem_amatista = "constructo", demonio_astado = "demonio", ent_ardiente = "planta", golem_escarcha = "constructo",
  golem_cristal_oro = "constructo", samurai_dorado = "humanoide", barbaro_ancestral = "humanoide", sacerdotisa_felina = "humanoide",
  monje_carmesi = "humanoide", samurai_espectral = "no_muerto", lancero_esqueleto = "no_muerto", verdugo_esqueleto = "no_muerto",
  golem_musgo_antiguo = "constructo", espectro_hielo = "no_muerto",
  jefe_dragon_pardo = "dragon", jefe_dragon_carmesi = "dragon", jefe_dragon_abisal = "dragon", jefe_gorila_ancestral = "bestia",
  jefe_maestro_forja = "constructo", jefe_behemot_abismo = "bestia",
  -- plantas
  ent = "planta", calabaza = "planta", hongo = "planta", girasol_lancero = "planta", flor_lanza = "planta", rabano_guerrero = "planta",
  planta_jarro = "planta",
  -- humanoides
  troll_cavernario = "humanoide", ogro_hacha = "humanoide", bandido = "humanoide", asaltante = "humanoide", saqueador = "humanoide",
  sectario_mayor = "humanoide",
}

function M.de(monstruoId) return VOZ[monstruoId] or "bestia" end

return M
