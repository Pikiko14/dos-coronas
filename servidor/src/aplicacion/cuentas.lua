-- Caso de uso "cuentas": registrar, entrar, personajes y progreso diario.
-- Habla con el almacén a través del puerto; no sabe si detrás hay PostgreSQL
-- o un archivo.
local Puertos = require("src.aplicacion.puertos")
local Credenciales = require("src.aplicacion.credenciales")

local Cuentas = {}

-- Utilidades de credenciales, para quien las necesite (pruebas incluidas).
Cuentas.sha256 = Credenciales.sha256
Cuentas.pbkdf2 = Credenciales.pbkdf2
Cuentas.cifrar = Credenciales.cifrar
Cuentas.acepta = Credenciales.acepta
Cuentas.ITER = Credenciales.ITER

for _, metodo in ipairs(Puertos.CONTRATO.almacen) do
  Cuentas[metodo] = function(...)
    return Puertos.almacen()[metodo](...)
  end
end

-- Nombre del almacén en uso ("postgres" o "archivo").
function Cuentas.modo()
  return Puertos.almacen().nombre
end

return Cuentas
