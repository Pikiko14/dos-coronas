-- Ajustes del juego que el servidor toma de su configuración (.env): tiempos de los eventos, reglas
-- de subastas, gremios, oficios, balance... Se aplican a las constantes de los módulos del dominio
-- antes de crear el mundo. aplicar() devuelve una función que los deja como estaban (para las
-- pruebas) y la lista de los que cambiaron respecto a los valores por defecto.
local Balance = require("compartido.dominio.balance")
local Datos = require("compartido.dominio.datos")
local Subastas = require("compartido.dominio.subastas")
local Gremios = require("compartido.dominio.gremios")
local Caravanas = require("compartido.dominio.caravanas")
local Oficios = require("compartido.dominio.oficios")
local Ley = require("compartido.dominio.ley")
local Mascotas = require("compartido.dominio.mascotas")

local A = {}

-- Lista de horas "1,6,12,24" -> { 1, 6, 12, 24 } (solo valores razonables).
local function horas(texto)
  local lista = {}
  for n in tostring(texto or ""):gmatch("%d+") do
    n = tonumber(n)
    if n >= 1 and n <= 720 then lista[#lista + 1] = n end
  end
  return #lista > 0 and lista or nil
end
A.horas = horas

function A.aplicar(cfg)
  local guardado, cambios = {}, {}
  local function fijar(tabla, clave, valor, nombre)
    if valor == nil then return end
    local antes = tabla[clave]
    guardado[#guardado + 1] = { tabla, clave, antes }
    tabla[clave] = valor
    if antes ~= valor then cambios[#cambios + 1] = nombre .. " = " .. tostring(valor) end
  end
  local j = cfg and cfg.juego or {}
  local e = cfg and cfg.eventos or {}
  fijar(Balance, "XP_DIFICULTAD", j.xpDificultad, "dificultad de experiencia")
  fijar(Balance, "NIVEL_PASO", j.nivelPaso, "diferencia de nivel")
  fijar(Balance, "XP_MULTIPLICADOR", j.xpMultiplicador, "multiplicador de experiencia")
  fijar(Datos, "MONSTRUO_HP", j.monstruoVida, "vida de criaturas")
  fijar(Datos, "MONSTRUO_ATK", j.monstruoAtaque, "ataque de criaturas")
  fijar(Datos, "RESPAWN_MONSTRUO", j.respawnMonstruo, "reaparición de criaturas")
  fijar(Datos, "RESPAWN_ELITE", j.respawnElite, "reaparición de élites")
  fijar(Datos, "JUGADORES_EVENTO", e.minJugadores, "jugadores mínimos por evento")
  fijar(Datos.EVENTO_DURACION, "batalla", e.duracionBatalla, "duración de la batalla")
  fijar(Datos.EVENTO_DURACION, "estandarte", e.duracionEstandarte, "duración del estandarte")
  fijar(Subastas, "COMISION", j.subastaComision, "comisión de subastas")
  fijar(Subastas, "IMPUESTO", j.subastaImpuesto, "impuesto de subastas")
  fijar(Subastas, "MAX_POR_JUGADOR", j.subastaMaxPorJugador, "subastas por jugador")
  fijar(Subastas, "DURACIONES", horas(j.subastaDuraciones), "duraciones de subasta")
  fijar(Subastas, "SUBIDA_MINIMA", j.subastaSubidaMinima, "subida mínima de puja")
  fijar(Subastas, "TIEMPO_EXTRA", j.subastaTiempoExtra, "tiempo extra de subasta")
  fijar(Gremios, "NIVEL_MINIMO", j.gremioNivelMinimo, "nivel para fundar gremio")
  fijar(Gremios, "COSTE", j.gremioCoste, "coste de gremio")
  fijar(Gremios, "MAX_MIEMBROS", j.gremioMaxMiembros, "miembros por gremio")
  fijar(Gremios, "BONO_POR_COMPANERO", j.gremioBonoXp, "bono de experiencia de gremio")
  fijar(Gremios, "TOPE_COMPANEROS", j.gremioTopeCompaneros, "tope de compañeros de gremio")
  fijar(Caravanas, "INTERVALO", j.caravanaIntervalo, "salida de caravanas")
  fijar(Caravanas, "MAX", j.caravanaMax, "caravanas a la vez")
  fijar(Caravanas, "VELOCIDAD", j.caravanaVelocidad, "velocidad de caravanas")
  fijar(Oficios, "COSTE_CAMBIO", j.oficioCosteCambio, "coste de cambiar de oficio")
  fijar(Ley, "BUSCADO_SEG", j.buscadoSeg, "búsqueda tras un robo")
  fijar(Ley, "BUSCADO_FALLO_SEG", j.buscadoFalloSeg, "búsqueda tras un robo fallido")
  fijar(Mascotas, "DESCANSO_SEG", j.mascotaDescanso, "descanso de mascotas")
  local function restaurar()
    for i = #guardado, 1, -1 do
      local g = guardado[i]
      g[1][g[2]] = g[3]
    end
  end
  return restaurar, cambios
end

return A
