-- Lector de archivos .env: líneas CLAVE=valor, comentarios con # y valores
-- entre comillas simples o dobles. No evalúa nada ni expande variables.
local Env = {}

local function recortar(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function Env.parsear(texto)
  local valores = {}
  for linea in (texto or ""):gmatch("[^\r\n]+") do
    linea = recortar(linea)
    if linea ~= "" and linea:sub(1, 1) ~= "#" then
      linea = linea:gsub("^export%s+", "")
      local clave, valor = linea:match("^([%w_%.]+)%s*=%s*(.*)$")
      if clave then
        local comilla = valor:match("^([\"'])")
        if comilla then
          local cierre = valor:find(comilla, 2, true)
          valor = cierre and valor:sub(2, cierre - 1) or valor:sub(2)
        else
          valor = recortar((valor:gsub("%s+#.*$", "")))
        end
        valores[clave] = valor
      end
    end
  end
  return valores
end

local function leer(ruta)
  if love and love.filesystem and love.filesystem.getInfo(ruta) then
    local texto = love.filesystem.read(ruta)
    if texto then return texto end
  end
  -- Carpeta del ejecutable o del proyecto: así el .env se encuentra aunque el
  -- juego se abra desde un acceso directo (con otro directorio de trabajo).
  local carpetas = { "" }
  if love and love.filesystem and love.filesystem.getSourceBaseDirectory then
    local base = love.filesystem.getSourceBaseDirectory()
    if base and base ~= "" then carpetas[#carpetas + 1] = base:gsub("\\", "/") .. "/" end
  end
  for _, carpeta in ipairs(carpetas) do
    local f = io.open(carpeta .. ruta, "rb")
    if f then
      local texto = f:read("*a")
      f:close()
      return texto
    end
  end
end

-- Devuelve la tabla de valores y la ruta usada (o nil si no hay archivo).
function Env.cargar(ruta)
  local texto = leer(ruta or ".env")
  if not texto then return {}, nil end
  texto = texto:gsub("^\239\187\191", "") -- quita el BOM de UTF-8
  return Env.parsear(texto), ruta or ".env"
end

return Env
