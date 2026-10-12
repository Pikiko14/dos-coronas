local B = {}

B.XP_BASE = 40
B.XP_POR_NIVEL = 32
B.NIVEL_SLOT = { 1, 1, 4, 8 }

B.XP_CORTE = 7

function B.xpPara(nivel)
  nivel = math.max(1, math.floor(tonumber(nivel) or 1))
  return math.floor(48 + nivel * 22 + nivel * nivel * 8)
end

function B.xpMonstruo(nivelJugador, nivelMonstruo, elite)
  local nj = math.max(1, math.floor(tonumber(nivelJugador) or 1))
  local nm = math.max(1, math.floor(tonumber(nivelMonstruo) or 1))
  if nj >= nm * B.XP_CORTE then return 0 end
  local base = 10 + nm * 6
  if elite then base = base * 4 end
  local diff = nm - nj
  local mul = diff >= 0 and (1 + diff * 0.18) or math.max(0.2, 1 + diff * 0.1)
  return math.max(1, math.floor(base * mul))
end

-- Daño de un golpe -----------------------------------------------------
-- Cada golpe se tira entre un mínimo y un máximo que salen del ataque de quien
-- golpea (su nivel, su equipo y sus mejoras ya cuentan en el ataque):
--   mínimo = ataque x DANO_MIN x poder del golpe
--   máximo = ataque x DANO_MAX x poder del golpe
-- La tirada es la media de dos dados, así que lo normal queda hacia el centro y
-- los extremos salen menos. Un golpe crítico (CRITICO_PROB) hace CRITICO_MUL veces
-- el máximo. Después la defensa del objetivo lo reduce: defensa / (defensa + 40).
B.DANO_MIN = 0.6
B.DANO_MAX = 1.2
B.CRITICO_PROB = 0.08
B.CRITICO_MUL = 1.5

function B.reduccion(defensa)
  defensa = math.max(0, tonumber(defensa) or 0)
  return defensa / (defensa + 40)
end

-- Mínimo y máximo (enteros) que haría un golpe sin crítico contra una defensa.
function B.rangoDano(atk, defensa, coef)
  local k = (1 - B.reduccion(defensa)) * (coef or 1)
  local mn = math.max(1, math.floor((atk or 0) * B.DANO_MIN * k + 0.5))
  local mx = math.max(mn, math.floor((atk or 0) * B.DANO_MAX * k + 0.5))
  return mn, mx
end

-- Tira un golpe. Devuelve el daño (entero, al menos 1) y si fue crítico.
-- azar: función que da un número en [0, 1); por defecto math.random.
function B.tirarDano(atk, defensa, coef, azar)
  azar = azar or math.random
  atk = math.max(0, tonumber(atk) or 0)
  local k = coef or 1
  local mn, mx = atk * B.DANO_MIN * k, atk * B.DANO_MAX * k
  local base = mn + (mx - mn) * ((azar() + azar()) / 2)
  local critico = azar() < B.CRITICO_PROB
  if critico then base = mx * B.CRITICO_MUL end
  local dano = math.floor(base * (1 - B.reduccion(defensa)) + 0.5)
  return math.max(1, dano), critico
end

function B.slotDisponible(nivel, slot)
  local need = B.NIVEL_SLOT[slot] or 99
  return (tonumber(nivel) or 1) >= need
end

B.BOTIN = {
  gato = { { id = "pocion_vida", p = 0.4 } },
  rata = { { id = "pocion_vida", p = 0.35 } },
  jabali = { { id = "pocion_vida", p = 0.3 }, { id = "pocion_mana", p = 0.15 } },
  cuervo = { { id = "pocion_mana", p = 0.25 } },
}

function B.tirar(mon)
  local tabla = (mon and mon.botin) or (mon and B.BOTIN[mon.id]) or {
    { id = "pocion_vida", p = 0.35 },
  }
  local lista = {}
  for _, it in ipairs(tabla) do
    if math.random() < (it.p or 1) then
      lista[#lista + 1] = { id = it.id, cant = it.cant or 1 }
    end
  end
  return lista
end

return B
