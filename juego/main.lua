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

local App = require("src.presentacion.app")
local Entrada = require("src.presentacion.entrada")

function love.load()
  App.cargar()
end

function love.update(dt)
  App.actualizar(dt)
end

function love.draw()
  App.dibujar()
end

function love.mousepressed(x, y, boton)
  Entrada.raton(App, x, y, boton)
end

function love.mousemoved(x, y, dx, dy)
  Entrada.moverRaton(App, x, y, dx, dy)
end

function love.mousereleased(x, y)
  Entrada.soltarRaton(App, x, y)
end

function love.wheelmoved(_, dy)
  Entrada.rueda(App, dy)
end

function love.textinput(t)
  Entrada.texto(App, t)
end

function love.keypressed(tecla)
  Entrada.tecla(App, tecla)
end

function love.quit()
  App.salir()
end

function love.errorhandler(msg)
  return App.fallo(msg)
end
