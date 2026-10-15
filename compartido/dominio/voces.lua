-- Voz de cada criatura: a qué familia de sonidos pertenece (el cliente sintetiza los gruñidos, quejidos y muertes de cada familia).
-- Familias: bestia, pequeno, insecto, no_muerto, demonio, dragon, constructo, planta, humanoide.
local M = {}

M.FAMILIAS = { "bestia", "pequeno", "insecto", "no_muerto", "demonio", "dragon", "constructo", "planta", "humanoide" }

local VOZ = {
  -- bestias
  gato = "pequeno", jabali = "bestia", jabali_fuego = "bestia", oso = "bestia", elefante = "bestia", jefe_manada = "bestia",
  oso_gigante = "bestia", quimera = "bestia", gallina = "pequeno",
  -- pequeñas y voladoras
  cuervo = "pequeno", aguila = "insecto", arpia = "pequeno", rata = "pequeno",
  -- insectos y arácnidos
  escarabajo = "insecto", reina_avispa = "insecto", saurio = "insecto", escorpion_carmesi = "insecto",
  -- no muertos y espectros
  espectro = "no_muerto", alma = "no_muerto", alma_verde = "no_muerto", alma_hielo = "no_muerto", esqueleto = "no_muerto",
  esqueleto_real = "no_muerto", rey_espectral = "no_muerto", liche = "no_muerto", caballero = "no_muerto", ojo_abismo = "no_muerto",
  medusa = "no_muerto", medusa_abisal = "no_muerto",
  -- demonios
  demonio_musgo = "demonio", demonio_marea = "demonio", demonio_foso = "demonio", demonio_rey = "demonio", gargola = "demonio",
  -- dragones y serpientes
  dragon = "dragon", dragon_brasas = "dragon", hidra = "dragon", hidra_ceniza = "dragon",
  -- constructos y gigantes de piedra
  automata = "constructo", golem = "constructo", titan = "constructo", coloso = "constructo", behemot = "constructo",
  gigante_guerra = "constructo",
  -- plantas
  planta_roja = "planta", flor_sangrienta = "planta", calabaza = "planta", limo = "pequeno",
  -- humanoides
  troll = "humanoide", cultista = "humanoide", bruja = "humanoide", bandido = "humanoide", asaltante = "humanoide",
  saqueador = "humanoide", sectario_mayor = "humanoide",
}

function M.de(monstruoId) return VOZ[monstruoId] or "bestia" end

return M
