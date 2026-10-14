-- Sanciones de cuenta: baneos (temporales o permanentes) y roles del personal (GM y CM).
-- Funciones puras que comparten los almacenes y los comandos del chat.
local S = {}

-- Roles del personal, de más a menos poder.
S.ROLES = { gm = 3, cm = 2 }

-- Un baneo es { hasta = segundos Unix (0 = permanente), motivo = texto, por = quién lo puso }.
function S.vigente(ban, ahora)
  if type(ban) ~= "table" then return false end
  local hasta = tonumber(ban.hasta) or 0
  return hasta == 0 or hasta > (ahora or os.time())
end

function S.mensaje(ban)
  local motivo = (ban.motivo and ban.motivo ~= "") and ban.motivo or "sin motivo indicado"
  local hasta = tonumber(ban.hasta) or 0
  if hasta == 0 then return "Cuenta suspendida de forma permanente. Motivo: " .. motivo .. "." end
  return "Cuenta suspendida hasta " .. os.date("%Y-%m-%d %H:%M", hasta) .. ". Motivo: " .. motivo .. "."
end

-- Duración escrita por una persona: 30m, 2h, 3d o perm. Devuelve segundos (0 = permanente) o nil si no se entiende.
function S.duracion(texto)
  texto = tostring(texto or ""):lower()
  if texto == "perm" or texto == "permanente" then return 0 end
  local n, u = texto:match("^(%d+)([mhd]?)$")
  n = tonumber(n)
  if not n or n <= 0 then return nil end
  if u == "m" then return n * 60 end
  if u == "d" then return n * 86400 end
  return n * 3600
end

function S.textoDuracion(segundos)
  if segundos == 0 then return "permanente" end
  if segundos % 86400 == 0 then return (segundos / 86400) .. " d" end
  if segundos % 3600 == 0 then return (segundos / 3600) .. " h" end
  return math.floor(segundos / 60) .. " min"
end

function S.rolValido(rol)
  return rol == nil or rol == "gm" or rol == "cm"
end

return S
