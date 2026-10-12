local Interfaz = require("src.presentacion.interfaz")

local Personajes = {}

function Personajes.dibujar(app, w, h)
  Interfaz.personajes(app.sesion.personajes, app.sesion.usuario, w, h, app.sesion.error)
end

return Personajes
