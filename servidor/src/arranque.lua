-- Raíz de composición: único sitio donde se conectan los adaptadores con los
-- puertos de la aplicación. main.lua lo llama antes que nada.
local Puertos = require("src.aplicacion.puertos")

local Arranque = {}

function Arranque.iniciar()
  Puertos.registrar("almacen", function()
    return require("src.infraestructura.persistencia")()
  end)
end

return Arranque
