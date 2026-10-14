local Log = {}

function Log.carpeta()
  if love and love.filesystem and love.filesystem.getSource then
    local fuente = (love.filesystem.getSource() or "."):gsub("\\", "/")
    -- empaquetado (servidor.love) la fuente es el archivo: los registros van a la carpeta que lo contiene
    if fuente:lower():sub(-5) == ".love" and love.filesystem.getSourceBaseDirectory then
      local base = (love.filesystem.getSourceBaseDirectory() or "."):gsub("\\", "/")
      return base
    end
    return fuente
  end
  return "."
end

local function anexar(nivel, msg)
  local linea = os.date("%Y-%m-%d %H:%M:%S") .. " [" .. nivel .. "] " .. tostring(msg) .. "\n"
  local f = io.open(Log.carpeta() .. "/log.txt", "a")
  if f then f:write(linea) f:close() end
end

function Log.info(msg) anexar("info", msg) end
function Log.warn(msg) anexar("warn", msg) end
function Log.error(msg) anexar("error", msg) end

function Log.asegurar(sub)
  if love and love.filesystem and love.filesystem.createDirectory then
    love.filesystem.createDirectory(sub)
  end
  -- en Windows el mkdir del sistema (en Linux basta con love.filesystem.createDirectory)
  if package.config:sub(1, 1) == "\\" then
    local destino = (Log.carpeta() .. "/" .. sub):gsub("/", "\\")
    os.execute('mkdir "' .. destino .. '" 2>nul')
  end
end

function Log.volcar(nombre, texto)
  if love and love.filesystem and love.filesystem.write then
    local padre = nombre:match("^(.+)/[^/]+$")
    if padre then love.filesystem.createDirectory(padre) end
    love.filesystem.write(nombre, texto)
  end
  local ruta = Log.carpeta() .. "/" .. nombre
  local f = io.open(ruta, "wb")
  if not f then
    anexar("error", "No pude escribir " .. ruta)
    return false
  end
  f:write(texto)
  f:close()
  return true
end

return Log
