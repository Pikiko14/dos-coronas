local Interfaz = require("src.presentacion.interfaz")

local Menu = {}

function Menu.dibujar(_, w, h)
  Interfaz.menu(false, w, h)
end

function Menu.cargando()
  love.graphics.setColor(0.9, 0.85, 0.7)
  love.graphics.print("Forjando el mundo con las láminas...", 40, 40)
end

return Menu
