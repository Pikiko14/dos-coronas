-- Encantamiento: cada pieza de equipo puede subir de +0 a +MAX. Cada nivel suma un
-- porcentaje a sus cifras (ataque, defensa, vida, maná...). Subir cuesta oro y polvo
-- arcano (que sueltan las criaturas). Los primeros niveles son seguros; después se puede
-- fallar, y a partir de +7 un fallo hace perder un nivel.
local E = {}
require("compartido.dominio.configuracion").aplicar(E, "encanto")


-- Probabilidad de subir de +n a +(n+1), con n = 0..9.
local PROB = { 1.0, 1.0, 1.0, 0.8, 0.65, 0.5, 0.4, 0.3, 0.2, 0.12 }

function E.mult(enc)
  return 1 + E.PCT * (enc or 0)
end

function E.prob(enc)
  return PROB[(enc or 0) + 1] or 0
end

-- Un fallo en este nivel hace bajar la pieza.
function E.bajaAlFallar(enc)
  return (enc or 0) >= 6
end

-- Coste de intentar subir de +enc a +(enc+1).
function E.coste(it, enc)
  enc = enc or 0
  local sig = enc + 1
  return {
    oro = math.floor((it.precio or 40) * 0.12 * sig * (1 + enc * 0.2)),
    polvo = sig + math.floor(enc / 2),
  }
end

-- Se puede encantar equipo (no mochilas, pociones ni material).
function E.encantable(it)
  return it ~= nil and it.hueco ~= nil and it.hueco ~= "mochila" and not it.cura and not it.mana
end

-- Cifra de una pieza con su encantamiento (las cifras de velocidad no cambian).
function E.valor(it, campo, enc)
  local v = it[campo]
  if not v then return nil end
  if campo == "spd" then return v end
  return v * E.mult(enc)
end

return E
