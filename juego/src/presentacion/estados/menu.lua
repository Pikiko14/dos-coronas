local Interfaz = require("src.presentacion.interfaz")

local Menu = {}

function Menu.dibujar(app, w, h)
  local form = app and app.cuenta
  if form then Interfaz.portada(form, w, h, "entrar")
  else Interfaz.menu(false, w, h) end
end

function Menu.cargando()
  love.graphics.setColor(0.9, 0.85, 0.7)
  local P = require("src.presentacion.render.propias")
  local detalle = (P.totalWarm and P.totalWarm > 0) and ("  Preparando personajes " .. P.hechosWarm .. "/" .. P.totalWarm) or ""
  love.graphics.print("Forjando el mundo con las láminas..." .. detalle, 40, 40)
end

return Menu
