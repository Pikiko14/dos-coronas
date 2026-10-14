-- Funciones de LÖVE del juego (love.load, love.draw, el ratón...). Vive dentro de src/ para que un parche de actualización
-- pueda cambiarlo; main.lua solo prepara el arranque y lo carga.
local App = require("src.presentacion.app")
local Entrada = require("src.presentacion.entrada")
local Actualizacion = require("src.infraestructura.actualizacion")

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
  if Actualizacion.bloquea() then return end
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
  if Actualizacion.bloquea() then return end
  Entrada.texto(App, t)
end

function love.keypressed(tecla)
  if Actualizacion.bloquea() then return end
  Entrada.tecla(App, tecla)
end

function love.quit()
  App.salir()
end

function love.errorhandler(msg)
  return App.fallo(msg)
end
