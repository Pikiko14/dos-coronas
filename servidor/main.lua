-- Servidor de Dos Coronas: proceso de consola, sin ventana ni gráficos.
--
-- Carga el código compartido. Primero busca una copia dentro de este proyecto
-- (compartido/, la deja construir.bat al empaquetar) y, si no hay, usa la
-- carpeta hermana ../compartido del repositorio.
do
  local base = love.filesystem.getSource():gsub("\\", "/")
  table.insert(package.loaders, function(nombre)
    if nombre:sub(1, 11) ~= "compartido." then return nil end
    local rel = nombre:gsub("%.", "/")
    for _, ruta in ipairs({ base .. "/../" .. rel .. ".lua", base .. "/../" .. rel .. "/init.lua" }) do
      local f = io.open(ruta, "rb")
      if f then
        local fuente = f:read("*a")
        f:close()
        local fn, err = loadstring(fuente, "@" .. ruta)
        if not fn then error(err) end
        return fn
      end
    end
    return "\n\tno existe " .. nombre .. " ni dentro del proyecto ni en ../compartido"
  end)
end

require("src.arranque").iniciar()

local function bandera(nombre)
  for _, v in pairs(arg or {}) do
    if v == nombre then return true end
  end
  return false
end

local modoTest = bandera("--test")
local modoCalibrar = bandera("--calibrar")
local Consola = not (modoTest or modoCalibrar) and require("src.consola") or nil
local probado = false

function love.load()
  if Consola then Consola.cargar() end
end

function love.update(dt)
  if modoCalibrar then
    if not probado then
      probado = true
      require("src.pruebas.calibracion").correr()
      love.event.quit(0)
    end
    return
  end
  if modoTest then
    if not probado then
      probado = true
      require("src.pruebas.pruebas").correr()
    end
    return
  end
  Consola.actualizar(math.min(dt or 0, 0.05))
end

function love.quit()
  if Consola then Consola.cerrar() end
end

function love.errorhandler(msg)
  local tr = debug.traceback(tostring(msg), 2)
  print("ERROR: " .. tr)
  local ok, Log = pcall(require, "compartido.infraestructura.log")
  if ok then
    Log.error(tr)
    Log.volcar("error_log.txt", tr)
    if modoTest then Log.volcar("prueba_resultado.txt", "EXCEPCION\n" .. tr) end
  end
  return function() return 1 end
end
