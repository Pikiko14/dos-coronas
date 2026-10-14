local Util = require("compartido.dominio.util")
local Red = { lista = false }

-- Los sockets los pone sockets.lua: Winsock en Windows (desarrollo y cliente) y la libc en Linux (servidor de la beta).
local Sock = require("compartido.infraestructura.sockets")
local okffi, ffi = pcall(require, "ffi")

local function enviarRaw(sock, texto, cola)
  if not sock or not texto or #texto == 0 then return true end
  local n, tipo, cod = Sock.enviar(sock, texto)
  if not n then
    if tipo == "espera" then
      if #cola < 24 then cola[#cola + 1] = texto end
      return true
    end
    return false, cod
  end
  if n < #texto then cola[#cola + 1] = texto:sub(n + 1) end
  return true
end

local function bombear(sock, estado)
  if estado.cola and #estado.cola > 24 then
    local queda = {}
    for i = #estado.cola - 4, #estado.cola do queda[#queda + 1] = estado.cola[i] end
    estado.cola = queda
  end
  if estado.cola and #estado.cola > 0 then
    local pendiente = table.concat(estado.cola)
    estado.cola = {}
    local bien, cod = enviarRaw(sock, pendiente, estado.cola)
    if not bien then return false, cod end
  end
  local buf = ffi.new("char[8192]")
  while true do
    local n, tipo, err = Sock.recibir(sock, buf, 8191)
    if n and n > 0 then
      estado.buffer = (estado.buffer or "") .. ffi.string(buf, n)
      if #estado.buffer > 800000 then estado.buffer = estado.buffer:sub(-200000) end
    elseif n == 0 then
      return false, 0
    elseif tipo == "espera" then
      break
    else
      return false, err
    end
  end
  return true
end

local function sacarLineas(estado)
  local out = {}
  local buf = estado.buffer or ""
  while true do
    local i = buf:find("\n", 1, true)
    if not i then break end
    local linea = buf:sub(1, i - 1)
    buf = buf:sub(i + 1)
    if linea ~= "" then
      local datos = Util.jsonDec(linea)
      if datos then out[#out + 1] = datos end
    end
  end
  estado.buffer = buf
  return out
end

function Red.disponible()
  return okffi and Sock.disponible()
end

function Red.escuchar(puerto)
  if not Red.disponible() then return nil, "sin red" end
  local s = Sock.abrir()
  if not s then return nil, "socket" end
  Sock.nobloqueo(s)
  local ok, err = Sock.escuchar(s, puerto)
  if not ok then
    Sock.cerrar(s)
    return nil, err or "puerto ocupado"
  end
  local srv = { sock = s, clientes = {}, log = {} }
  function srv:cerrar()
    for _, c in ipairs(self.clientes) do Sock.cerrar(c.sock) end
    Sock.cerrar(self.sock)
  end
  function srv:puedeEnviar(id)
    for _, c in ipairs(self.clientes) do
      if c.id == id then return not c.cola or #c.cola == 0 end
    end
    return false
  end
  function srv:enviar(id, tabla)
    for _, c in ipairs(self.clientes) do
      if c.id == id then
        c.cola = c.cola or {}
        enviarRaw(c.sock, Util.jsonEnc(tabla) .. "\n", c.cola)
      end
    end
  end
  -- Manda un último mensaje a una conexión y la cierra en cuanto se vacía su cola (o tras unos intentos).
  function srv:desconectar(id, tabla)
    for _, c in ipairs(self.clientes) do
      if c.id == id then
        if tabla then
          c.cola = c.cola or {}
          enviarRaw(c.sock, Util.jsonEnc(tabla) .. "\n", c.cola)
        end
        c.cerrar = 0
      end
    end
  end
  function srv:actualizar()
    local eventos = {}
    while true do
      local nuevo = Sock.aceptar(self.sock)
      if not nuevo then break end
      Sock.nobloqueo(nuevo)
      Sock.sinDemora(nuevo)
      self.seq = (self.seq or 0) + 1
      local id = "c" .. self.seq
      self.clientes[#self.clientes + 1] = { id = id, sock = nuevo, buffer = "", cola = {} }
      eventos[#eventos + 1] = { tipo = "conecta", id = id }
    end
    local vivos = {}
    for _, c in ipairs(self.clientes) do
      local bien, cod = bombear(c.sock, c)
      if bien and c.cerrar then
        c.cerrar = c.cerrar + 1
        if #(c.cola or {}) == 0 or c.cerrar > 20 then bien, cod = false, "expulsado" end
      end
      if not bien then
        Sock.cerrar(c.sock)
        eventos[#eventos + 1] = { tipo = "cierra", id = c.id, codigo = cod }
      else
        for _, msg in ipairs(sacarLineas(c)) do
          eventos[#eventos + 1] = { tipo = "msg", id = c.id, msg = msg }
        end
        vivos[#vivos + 1] = c
      end
    end
    self.clientes = vivos
    return eventos
  end
  return srv
end

function Red.conectar(host, puerto)
  if not Red.disponible() then return nil, "sin red" end
  local s = Sock.abrir()
  if not s then return nil, "socket" end
  Sock.nobloqueo(s)
  Sock.sinDemora(s)
  Sock.iniciarConexion(s, host, puerto)
  local cli = { sock = s, buffer = "", cola = {}, listo = false }
  function cli:enviar(tabla)
    local texto = Util.jsonEnc(tabla) .. "\n"
    if not self.listo then
      self.cola[#self.cola + 1] = texto
      return true
    end
    return enviarRaw(self.sock, texto, self.cola)
  end
  function cli:actualizar()
    if not self.listo then
      local ok, fallo = Sock.conexionLista(self.sock)
      if ok == nil then return nil, "cerrado", fallo end
      if not ok then return {} end
      self.listo = true
    end
    local bien, cod = bombear(self.sock, self)
    if not bien then return nil, "cerrado", cod end
    return sacarLineas(self)
  end
  function cli:cerrar()
    Sock.cerrar(self.sock)
  end
  return cli
end

return Red
