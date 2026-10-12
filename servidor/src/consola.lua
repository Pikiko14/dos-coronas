-- Ejecución del servidor en consola: abre el transporte, hace avanzar el
-- servicio y escribe en pantalla lo que pasa. La lógica está en
-- aplicacion/servicio_servidor.lua.
local Servicio = require("src.aplicacion.servicio_servidor")
local Red = require("compartido.infraestructura.red")
local Log = require("compartido.infraestructura.log")
local Config = require("src.infraestructura.config")

local Consola = {}

local estado = { mundo = nil, servidor = nil }

local function nota(texto)
  print(os.date("%H:%M:%S ") .. texto)
end

function Consola.cargar()
  nota("Dos Coronas — servidor")
  nota("Configuración: " .. (Config.origen or "valores por defecto (no hay .env)"))
  estado.mundo = Servicio.crearMundo()
  local srv, err = Red.escuchar(Config.red.puerto)
  if not srv then
    nota("No se pudo abrir el puerto " .. Config.red.puerto .. ": " .. tostring(err))
    Log.error("puerto " .. Config.red.puerto .. ": " .. tostring(err))
    love.event.quit(1)
    return
  end
  srv.vinculo = {}
  srv.tasa = {}
  estado.servidor = srv
  nota("Escuchando en el puerto " .. Config.red.puerto)
  nota("Almacén de cuentas: " .. require("src.aplicacion.cuentas").modo())
  Log.info("arranque servidor en el puerto " .. Config.red.puerto)
end

-- Apagado ordenado: detener.bat deja un archivo detener.txt junto al servidor; al
-- verlo, el servidor guarda a todos y se cierra (cerrar la ventana a la fuerza no
-- da tiempo a guardar lo posterior al último guardado).
local ARCHIVO_DETENER = "detener.txt"
local espera = 0

local function pedidoDeDetener(dt)
  espera = espera + dt
  if espera < 1 then return false end
  espera = 0
  local ruta = Log.carpeta() .. "/" .. ARCHIVO_DETENER
  local f = io.open(ruta, "rb")
  if not f then return false end
  f:close()
  os.remove(ruta)
  return true
end

function Consola.actualizar(dt)
  if not estado.mundo then return end
  if pedidoDeDetener(dt) then
    nota("Apagado pedido: guardando a todos los jugadores...")
    love.event.quit(0)
    return
  end
  Servicio.actualizar({
    mundo = estado.mundo,
    servidor = estado.servidor,
    config = Config.servidor,
    nota = nota,
  }, dt)
end

function Consola.cerrar()
  if estado.mundo then Servicio.guardarTodos(estado.mundo) end
  if estado.servidor then estado.servidor:cerrar() end
  nota("Servidor detenido")
end

return Consola
