local Interfaz = require("src.presentacion.interfaz")

local Menu = {}

function Menu.dibujar(app, w, h)
  local form = app and app.cuenta
  if form then Interfaz.portada(form, w, h, "entrar")
  else Interfaz.menu(false, w, h) end
end

function Menu.cargando()
  love.graphics.setColor(0.9, 0.85, 0.7)
  love.graphics.print("Forjando el mundo con las láminas...", 40, 40)
end

return Menu
