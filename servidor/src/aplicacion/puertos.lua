-- Puertos: lo que la aplicación necesita del exterior. Las implementaciones
-- (adaptadores) se enchufan una vez al arrancar, en src/arranque.lua.
local P = {}

-- Contrato del puerto "almacen": cuentas, sesiones y personajes.
P.CONTRATO = {
  almacen = {
    "registrar", "entrar", "listar", "crearPersonaje", "cargar",
    "cuentaDeToken", "cargarAutorizado", "guardar", "marcarEvento", "borrarUsuario",
    "cargarGremios", "guardarGremio", "borrarGremio",
    "cargarSubastas", "guardarSubasta", "borrarSubasta", "guardarBuzon",
  },
}

local fabricas = {}
local instancias = {}

-- fabrica: función sin argumentos que devuelve el adaptador.
function P.registrar(nombre, fabrica)
  fabricas[nombre] = fabrica
  instancias[nombre] = nil
end

local function obtener(nombre)
  local ya = instancias[nombre]
  if ya then return ya end
  local fabrica = fabricas[nombre]
  if not fabrica then error("Falta el adaptador del puerto '" .. nombre .. "'. ¿Se llamó a arranque?") end
  local adaptador = fabrica()
  for _, metodo in ipairs(P.CONTRATO[nombre] or {}) do
    if type(adaptador[metodo]) ~= "function" then
      error("El adaptador de '" .. nombre .. "' no implementa " .. metodo)
    end
  end
  instancias[nombre] = adaptador
  return adaptador
end

function P.almacen()
  return obtener("almacen")
end

return P
