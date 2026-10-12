-- Elige el adaptador de almacén según la configuración. En modo "auto" se usa
-- PostgreSQL si responde y, si no, el archivo local.
local Config = require("src.infraestructura.config")
local Postgres = require("src.infraestructura.persistencia.postgres")
local Archivo = require("src.infraestructura.persistencia.archivo")
local Log = require("compartido.infraestructura.log")

return function()
  local pedido = Config.almacen
  if pedido == "archivo" then return Archivo end
  if pedido == "postgres" then return Postgres end
  local conn = Postgres.abrir()
  if conn then
    conn:cerrar()
    return Postgres
  end
  Log.warn("PostgreSQL no responde: se usa el almacén local (cuentas.json)")
  print("[almacén] PostgreSQL no responde: se usa el almacén local (cuentas.json).")
  return Archivo
end
