-- Adaptador de archivo para el puerto de almacén: guarda todo en cuentas.json
-- (carpeta de guardado de LÖVE). Sirve para jugar sin base de datos.
local Util = require("compartido.dominio.util")
local Credenciales = require("src.aplicacion.credenciales")
local aleatorio = require("src.infraestructura.aleatorio")
local Sanciones = require("compartido.dominio.sanciones")

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
    sigCuenta = 1, sigPj = 1, cuentas = {}, personajes = {}, gremios = {}, subastas = {}, buzones = {},
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
  if fila.ban then
    if Sanciones.vigente(fila.ban) then return nil, Sanciones.mensaje(fila.ban) end
    fila.ban = nil
  end
  local token = abrirSesionLocal(a, fila.id)
  local ok, err = volcarAlmacen()
  if not ok then return nil, err end
  return fila.id, token
end

function M.listar(cuentaId)
  local lista = {}
  for _, p in ipairs(leerAlmacen().personajes) do
    if p.cuenta == tonumber(cuentaId) then
      -- addon = el último que tenía puesto: la selección de personaje lo dibuja con su aspecto
      lista[#lista + 1] = { id = p.id, nombre = p.nombre, faccion = p.faccion, clase = p.clase, genero = p.genero or "h", nivel = p.nivel or 1, addon = p.datos and p.datos.addonActivo or nil }
    end
  end
  return lista
end

function M.crearPersonaje(cuentaId, nombre, faccion, clase, genero)
  if not nombreValido(nombre) then return nil, "El nombre del personaje usa 3 a 16 letras." end
  if faccion ~= "albor" and faccion ~= "umbra" then return nil, "Elige una facción." end
  if not require("compartido.dominio.datos").claseValida(clase, faccion) then
    return nil, "Elige un oficio de tu facción."
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
    id = id, cuenta = cuenta, nombre = nombre, faccion = faccion, clase = clase, genero = genero == "m" and "m" or "h",
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
  datos.nombre, datos.faccion, datos.clase, datos.genero = p.nombre, p.faccion, p.clase, p.genero or "h"
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
  if cuenta.ban and Sanciones.vigente(cuenta.ban) then return nil, Sanciones.mensaje(cuenta.ban) end
  return cuenta.id, cuenta.usuario, cuenta.rol
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

-- Gremios (ver el puerto almacén): una lista dentro de cuentas.json.
function M.cargarGremios()
  local copia = {}
  for _, g in ipairs(leerAlmacen().gremios or {}) do
    local miembros = {}
    for _, m in ipairs(g.miembros or {}) do miembros[#miembros + 1] = { id = m.id, nombre = m.nombre, rango = m.rango } end
    copia[#copia + 1] = { id = g.id, nombre = g.nombre, etiqueta = g.etiqueta, faccion = g.faccion, miembros = miembros }
  end
  return copia
end

function M.guardarGremio(g)
  local a = leerAlmacen()
  a.gremios = a.gremios or {}
  local fila = { id = g.id, nombre = g.nombre, etiqueta = g.etiqueta, faccion = g.faccion, miembros = {} }
  for dbId, m in pairs(g.miembros) do fila.miembros[#fila.miembros + 1] = { id = dbId, nombre = m.nombre, rango = m.rango } end
  table.sort(fila.miembros, function(x, y) return x.id < y.id end)
  local _, i = buscar(a.gremios, "id", g.id)
  if i then a.gremios[i] = fila else a.gremios[#a.gremios + 1] = fila end
  return volcarAlmacen()
end

function M.borrarGremio(id)
  local a = leerAlmacen()
  local _, i = buscar(a.gremios or {}, "id", id)
  if i then table.remove(a.gremios, i) end
  return volcarAlmacen()
end

-- Subastas y buzones (ver el puerto almacén). Los buzones se guardan como lista { id, entregas }.
function M.cargarSubastas()
  local a = leerAlmacen()
  local lista = {}
  for _, s in ipairs(a.subastas or {}) do
    local c = {}
    for k, v in pairs(s) do c[k] = v end
    lista[#lista + 1] = c
  end
  local buzones = {}
  for _, b in ipairs(a.buzones or {}) do buzones[b.id] = b.lista end
  return lista, buzones
end

function M.guardarSubasta(s)
  local a = leerAlmacen()
  a.subastas = a.subastas or {}
  local fila = {}
  for k, v in pairs(s) do fila[k] = v end
  local _, i = buscar(a.subastas, "id", s.id)
  if i then a.subastas[i] = fila else a.subastas[#a.subastas + 1] = fila end
  return volcarAlmacen()
end

function M.borrarSubasta(id)
  local a = leerAlmacen()
  local _, i = buscar(a.subastas or {}, "id", id)
  if i then table.remove(a.subastas, i) end
  return volcarAlmacen()
end

function M.guardarBuzon(dbId, lista)
  local a = leerAlmacen()
  a.buzones = a.buzones or {}
  local _, i = buscar(a.buzones, "id", dbId)
  if #lista == 0 then
    if i then table.remove(a.buzones, i) end
  else
    local fila = { id = dbId, lista = lista }
    if i then a.buzones[i] = fila else a.buzones[#a.buzones + 1] = fila end
  end
  return volcarAlmacen()
end

-- Roles (GM y CM) y baneos por cuenta. El usuario se busca sin distinguir mayúsculas.
local function cuentaDe(a, usuario)
  usuario = tostring(usuario or ""):lower()
  for _, c in ipairs(a.cuentas) do
    if c.usuario:lower() == usuario then return c end
  end
end

function M.rolDeCuenta(cuentaId)
  local c = buscar(leerAlmacen().cuentas, "id", tonumber(cuentaId))
  return c and c.rol or nil
end

function M.fijarRol(usuario, rol)
  if not Sanciones.rolValido(rol) then return nil, "Rol desconocido: usa gm, cm o ninguno." end
  local c = cuentaDe(leerAlmacen(), usuario)
  if not c then return nil, "No existe esa cuenta." end
  c.rol = rol
  local ok, err = volcarAlmacen()
  if not ok then return nil, err end
  return c.usuario
end

function M.listarRoles()
  local lista = {}
  for _, c in ipairs(leerAlmacen().cuentas) do
    if c.rol then lista[#lista + 1] = { usuario = c.usuario, rol = c.rol } end
  end
  table.sort(lista, function(x, y) return x.usuario < y.usuario end)
  return lista
end

-- hasta: segundos Unix en que acaba el baneo (0 = permanente).
function M.banear(usuario, hasta, motivo, por)
  local c = cuentaDe(leerAlmacen(), usuario)
  if not c then return nil, "No existe esa cuenta." end
  c.ban = { hasta = math.floor(tonumber(hasta) or 0), motivo = tostring(motivo or ""), por = tostring(por or ""), desde = os.time() }
  for token, ses in pairs(leerAlmacen().sesiones) do
    if ses.cuenta == c.id then leerAlmacen().sesiones[token] = nil end
  end
  local ok, err = volcarAlmacen()
  if not ok then return nil, err end
  return c.usuario
end

function M.desbanear(usuario)
  local c = cuentaDe(leerAlmacen(), usuario)
  if not c then return nil, "No existe esa cuenta." end
  if not c.ban then return nil, "Esa cuenta no está baneada." end
  c.ban = nil
  local ok, err = volcarAlmacen()
  if not ok then return nil, err end
  return c.usuario
end

function M.estadoBan(cuentaId)
  local c = buscar(leerAlmacen().cuentas, "id", tonumber(cuentaId))
  if not c or not c.ban then return nil end
  if not Sanciones.vigente(c.ban) then c.ban = nil volcarAlmacen() return nil end
  return c.ban
end

function M.listarBaneos()
  local lista = {}
  for _, c in ipairs(leerAlmacen().cuentas) do
    if c.ban and Sanciones.vigente(c.ban) then
      lista[#lista + 1] = { usuario = c.usuario, hasta = c.ban.hasta, motivo = c.ban.motivo, por = c.ban.por }
    end
  end
  table.sort(lista, function(x, y) return x.usuario < y.usuario end)
  return lista
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
