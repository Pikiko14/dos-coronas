local Interfaz = require("src.presentacion.interfaz")

local Cuenta = {}

function Cuenta.dibujar(app, w, h)
  Interfaz.cuenta(app.cuenta, w, h)
end

return Cuenta
