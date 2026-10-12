local Log = {}

function Log.carpeta()
  if love and love.filesystem and love.filesystem.getSource then
    return (love.filesystem.getSource() or "."):gsub("\\", "/")
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
  local destino = (Log.carpeta() .. "/" .. sub):gsub("/", "\\")
  os.execute('mkdir "' .. destino .. '" 2>nul')
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
