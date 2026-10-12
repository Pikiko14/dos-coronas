-- Adaptador de archivo para el puerto de almacén: guarda todo en cuentas.json
-- (carpeta de guardado de LÖVE). Sirve para jugar sin base de datos.
local Util = require("compartido.dominio.util")
local Credenciales = require("src.aplicacion.credenciales")
local aleatorio = require("src.infraestructura.aleatorio")

local M = { nombre = "archivo" }

local usuarioValido, nombreValido = Credenciales.usuarioValido, Credenciales.nombreValido

local function salNueva()
  return aleatorio(16)
end

local function tokenNuevo()
  return aleatorio(24)
end
local ARCHIVO = "cuentas.json"
local PERSONAJES_MAX = 4
local almacen

local function leerAlmacen()
  if almacen then return almacen end
  almacen = {
    sigCuenta = 1, sigPj = 1, cuentas = {}, personajes = {},
    eventos = {}, sesiones = {}, intentos = {},
  }
  if love and love.filesystem and love.filesystem.getInfo(ARCHIVO) then
    local texto = love.filesystem.read(ARCHIVO)
    local d = texto and Util.jsonDec(texto)
    if type(d) == "table" then
      for k in pairs(almacen) do
        if d[k] ~= nil then almacen[k] = d[k] end
      end
    end
  end
  return almacen
end

local function volcarAlmacen()
  if not (love and love.filesystem) then return true end
  local ok, err = love.filesystem.write(ARCHIVO, Util.jsonEnc(almacen))
  if not ok then return nil, "No se pudo guardar: " .. tostring(err) end
  return true
end

local function buscar(lista, campo, valor)
  for i, f in ipairs(lista) do
    if f[campo] == valor then return f, i end
  end
end

local function abrirSesionLocal(a, cuentaId)
  local token = tokenNuevo()
  a.sesiones[token] = { cuenta = cuentaId, expira = os.time() + 12 * 3600 }
  return token
end

function M.registrar(usuario, clave)
  if not usuarioValido(usuario) then return nil, "El usuario usa 3 a 16 letras, números o _." end
  if type(clave) ~= "string" or #clave < 4 or #clave > 64 then return nil, "La clave necesita entre 4 y 64 caracteres." end
  local a = leerAlmacen()
  if buscar(a.cuentas, "usuario", usuario) then return nil, "Ese usuario ya está registrado." end
  local sal = salNueva()
  local id = a.sigCuenta
  a.sigCuenta = id + 1
  a.cuentas[#a.cuentas + 1] = { id = id, usuario = usuario, sal = sal, clave = Credenciales.cifrar(clave, sal) }
  local token = abrirSesionLocal(a, id)
  local ok, err = volcarAlmacen()
  if not ok then return nil, err end
  return id, token
end

function M.entrar(usuario, clave)
  if not usuarioValido(usuario) then return nil, "Usuario o clave incorrectos." end
  local a = leerAlmacen()
  local ahora = os.time()
  local intento = a.intentos[usuario]
  if intento and (intento.fallos or 0) >= 5 and (intento.hasta or 0) > ahora then
    return nil, "Demasiados intentos. Espera un minuto."
  end
  local fila = buscar(a.cuentas, "usuario", usuario)
  local acepta = false
  if fila then acepta = Credenciales.acepta(fila.clave, fila.sal, clave or "") end
  if not acepta then
    local fallos = ((intento and intento.fallos) or 0) + 1
    a.intentos[usuario] = { fallos = fallos, hasta = fallos >= 5 and (ahora + 60) or 0 }
    volcarAlmacen()
    return nil, "Usuario o clave incorrectos."
  end
  a.intentos[usuario] = nil
  local token = abrirSesionLocal(a, fila.id)
  local ok, err = volcarAlmacen()
  if not ok then return nil, err end
  return fila.id, token
end

function M.listar(cuentaId)
  local lista = {}
  for _, p in ipairs(leerAlmacen().personajes) do
    if p.cuenta == tonumber(cuentaId) then
      lista[#lista + 1] = { id = p.id, nombre = p.nombre, faccion = p.faccion, clase = p.clase, nivel = p.nivel or 1 }
    end
  end
  return lista
end

function M.crearPersonaje(cuentaId, nombre, faccion, clase)
  if not nombreValido(nombre) then return nil, "El nombre del personaje usa 3 a 16 letras." end
  if faccion ~= "albor" and faccion ~= "umbra" then return nil, "Elige una facción." end
  if clase ~= "guerrero" and clase ~= "mago" and clase ~= "cazador" and clase ~= "clerigo" then
    return nil, "Elige un oficio."
  end
  local a = leerAlmacen()
  local cuenta = tonumber(cuentaId)
  if not cuenta or not buscar(a.cuentas, "id", cuenta) then return nil, "Sesión no válida." end
  local propios = 0
  for _, p in ipairs(a.personajes) do
    if p.cuenta == cuenta then propios = propios + 1 end
    if p.nombre:lower() == nombre:lower() then return nil, "Ese nombre ya existe." end
  end
  if propios >= PERSONAJES_MAX then return nil, "Esta cuenta ya tiene 4 personajes." end
  local id = a.sigPj
  a.sigPj = id + 1
  a.personajes[#a.personajes + 1] = {
    id = id, cuenta = cuenta, nombre = nombre, faccion = faccion, clase = clase,
    nivel = 1, xp = 0, oro = 140, x = 0, y = 0, hp = 1, mp = 1, datos = {},
  }
  local ok, err = volcarAlmacen()
  if not ok then return nil, err end
  return id
end

function M.cargar(personajeId)
  local a = leerAlmacen()
  local p = buscar(a.personajes, "id", tonumber(personajeId))
  if not p then return nil, "No está ese personaje." end
  local datos = Util.jsonDec(Util.jsonEnc(p.datos or {})) or {}
  datos.nombre, datos.faccion, datos.clase = p.nombre, p.faccion, p.clase
  datos.nivel, datos.xp, datos.oro = p.nivel or 1, p.xp or 0, p.oro or 0
  datos.x, datos.y, datos.hp, datos.mp = p.x, p.y, p.hp, p.mp
  datos.dbId = p.id
  local hoy = os.date("%Y-%m-%d")
  datos.eventosDia = {}
  for _, tipo in ipairs({ "batalla", "estandarte" }) do
    if a.eventos[p.id .. "|" .. tipo .. "|" .. hoy] then datos.eventosDia[tipo] = hoy end
  end
  return datos
end

function M.cuentaDeToken(token)
  if type(token) ~= "string" or #token < 16 then return nil, "Falta la sesión." end
  local a = leerAlmacen()
  local ses = a.sesiones[token]
  if not ses or (ses.expira or 0) <= os.time() then return nil, "La sesión caducó. Entra de nuevo." end
  local cuenta = buscar(a.cuentas, "id", ses.cuenta)
  if not cuenta then return nil, "La sesión caducó. Entra de nuevo." end
  return cuenta.id, cuenta.usuario
end

function M.cargarAutorizado(token, personajeId)
  local cuentaId, err = M.cuentaDeToken(token)
  if not cuentaId then return nil, err end
  local pid = tonumber(personajeId)
  if not pid then return nil, "Falta el personaje." end
  local p = buscar(leerAlmacen().personajes, "id", pid)
  if not p or p.cuenta ~= cuentaId then return nil, "Ese personaje no es de esta cuenta." end
  return M.cargar(pid)
end

function M.guardar(p, exportado)
  if not p or not p.dbId then return nil, "Sin personaje." end
  local fila = buscar(leerAlmacen().personajes, "id", tonumber(p.dbId))
  if not fila then return nil, "No está ese personaje." end
  fila.nivel, fila.xp, fila.oro = math.floor(p.nivel or 1), math.floor(p.xp or 0), math.floor(p.oro or 0)
  fila.x, fila.y = tonumber(p.x or 0), tonumber(p.y or 0)
  fila.hp, fila.mp = math.floor(p.hp or 1), math.floor(p.mp or 1)
  fila.datos = Util.jsonDec(Util.jsonEnc(exportado or {})) or {}
  return volcarAlmacen()
end

function M.marcarEvento(personajeId, tipo)
  local idn = tonumber(personajeId)
  if not idn then return nil, "Sin personaje." end
  leerAlmacen().eventos[idn .. "|" .. tostring(tipo) .. "|" .. os.date("%Y-%m-%d")] = true
  return volcarAlmacen()
end

function M.borrarUsuario(usuario)
  local a = leerAlmacen()
  local fila, i = buscar(a.cuentas, "usuario", usuario)
  if not fila then return true end
  table.remove(a.cuentas, i)
  for j = #a.personajes, 1, -1 do
    if a.personajes[j].cuenta == fila.id then table.remove(a.personajes, j) end
  end
  for token, ses in pairs(a.sesiones) do
    if ses.cuenta == fila.id then a.sesiones[token] = nil end
  end
  a.intentos[usuario] = nil
  return volcarAlmacen()
end

return M
