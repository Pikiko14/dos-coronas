local Interfaz = require("src.presentacion.interfaz")

local Crear = {}

function Crear.dibujar(app, w, h)
  Interfaz.crear(app.creacion, w, h)
end

return Crear
