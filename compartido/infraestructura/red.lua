local Util = require("compartido.dominio.util")
local Red = { lista = false }

local okffi, ffi = pcall(require, "ffi")
if not okffi then
  function Red.disponible() return false end
  return Red
end

ffi.cdef[[
typedef unsigned long long UINT_PTR;
typedef UINT_PTR SOCKET;
typedef struct WSAData {
  unsigned short wVersion;
  unsigned short wHighVersion;
  unsigned short iMaxSockets;
  unsigned short iMaxUdpDg;
  char resto[512];
} WSADATA;
int WSAStartup(unsigned short wVersionRequested, WSADATA *lpWSAData);
int WSACleanup(void);
int WSAGetLastError(void);
SOCKET socket(int af, int type, int protocol);
int closesocket(SOCKET s);
int bind(SOCKET s, const void *name, int namelen);
int listen(SOCKET s, int backlog);
SOCKET accept(SOCKET s, void *addr, int *addrlen);
int connect(SOCKET s, const void *name, int namelen);
int send(SOCKET s, const char *buf, int len, int flags);
int recv(SOCKET s, char *buf, int len, int flags);
int ioctlsocket(SOCKET s, long cmd, unsigned long *argp);
int getsockopt(SOCKET s, int level, int optname, char *optval, int *optlen);
int setsockopt(SOCKET s, int level, int optname, const char *optval, int optlen);
unsigned short htons(unsigned short hostshort);
unsigned long inet_addr(const char *cp);
typedef struct sockaddr_in {
  short sin_family;
  unsigned short sin_port;
  unsigned long sin_addr;
  char sin_zero[8];
} sockaddr_in;
typedef struct timeval {
  long tv_sec;
  long tv_usec;
} timeval;
typedef struct fd_set {
  unsigned int fd_count;
  unsigned long long fd_array[64];
} fd_set;
int select(int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, const timeval *timeout);
]]

local ws2 = ffi.load("ws2_32")
-- 0x8004667E no cabe en un long con signo; este valor conserva esos bits.
local FIONBIO = -2147195266
local SOL_SOCKET = 0xffff
local SO_ERROR = 0x1007
local iniciado = false

local function asegurar()
  if iniciado then return true end
  local datos = ffi.new("WSADATA")
  local r = ws2.WSAStartup(0x0202, datos)
  iniciado = r == 0
  return iniciado
end

local function nobloqueo(s)
  local nb = ffi.new("unsigned long[1]", 1)
  ws2.ioctlsocket(s, FIONBIO, nb)
end

local function valido(s)
  if s == nil then return false end
  -- INVALID_SOCKET es -1. Comparar el cdata tal cual falla: no cabe en un número de Lua.
  return ffi.cast("intptr_t", s) ~= -1
end

local function sinDemora(s)
  local uno = ffi.new("int[1]", 1)
  ws2.setsockopt(s, 6, 1, ffi.cast("const char *", uno), 4)
end

local function errorSocket(s)
  if not valido(s) then return 10038 end
  local valor = ffi.new("int[1]")
  local largo = ffi.new("int[1]", 4)
  if ws2.getsockopt(s, SOL_SOCKET, SO_ERROR, ffi.cast("char *", valor), largo) ~= 0 then
    return ws2.WSAGetLastError()
  end
  return tonumber(valor[0]) or 0
end

local function handshake(s)
  local set = ffi.new("fd_set")
  set.fd_count = 1
  set.fd_array[0] = s
  local tv = ffi.new("timeval")
  if ws2.select(0, nil, set, nil, tv) <= 0 then return false end
  local fallo = errorSocket(s)
  if fallo ~= 0 and fallo ~= 10035 and fallo ~= 10036 then return false, fallo end
  return true
end

local function enviarRaw(sock, texto, cola)
  if not valido(sock) or not texto or #texto == 0 then return true end
  -- ffi.copy con un string copia también el \0 final: el buffer necesita un byte más
  local buf = ffi.new("char[?]", #texto + 1)
  ffi.copy(buf, texto, #texto)
  local n = ws2.send(sock, buf, #texto, 0)
  if n < 0 then
    local err = ws2.WSAGetLastError()
    if err == 10035 or err == 10055 then
      if #cola < 24 then cola[#cola + 1] = texto end
      return true
    end
    return false, err
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
    local n = ws2.recv(sock, buf, 8191, 0)
    if n > 0 then
      estado.buffer = (estado.buffer or "") .. ffi.string(buf, n)
      if #estado.buffer > 800000 then estado.buffer = estado.buffer:sub(-200000) end
    elseif n == 0 then
      return false, 0
    else
      local err = ws2.WSAGetLastError()
      if err == 10035 or err == 0 then break end
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
  return asegurar()
end

function Red.escuchar(puerto)
  if not asegurar() then return nil, "sin red" end
  local s = ws2.socket(2, 1, 6)
  if not valido(s) then return nil, "socket" end
  nobloqueo(s)
  local addr = ffi.new("sockaddr_in")
  addr.sin_family = 2
  addr.sin_port = ws2.htons(puerto)
  addr.sin_addr = ws2.inet_addr("0.0.0.0")
  if ws2.bind(s, addr, ffi.sizeof(addr)) ~= 0 then
    ws2.closesocket(s)
    return nil, "puerto ocupado"
  end
  ws2.listen(s, 8)
  local srv = { sock = s, clientes = {}, log = {} }
  function srv:cerrar()
    for _, c in ipairs(self.clientes) do ws2.closesocket(c.sock) end
    ws2.closesocket(self.sock)
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
      local nuevo = ws2.accept(self.sock, nil, nil)
      if not valido(nuevo) then break end
      nobloqueo(nuevo)
      sinDemora(nuevo)
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
        ws2.closesocket(c.sock)
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
  if not asegurar() then return nil, "sin red" end
  local s = ws2.socket(2, 1, 6)
  if not valido(s) then return nil, "socket" end
  nobloqueo(s)
  sinDemora(s)
  local addr = ffi.new("sockaddr_in")
  addr.sin_family = 2
  addr.sin_port = ws2.htons(puerto)
  addr.sin_addr = ws2.inet_addr(host)
  ws2.connect(s, addr, ffi.sizeof(addr))
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
      local ok, fallo = handshake(self.sock)
      if fallo then return nil, "cerrado", fallo end
      if not ok then return {} end
      self.listo = true
    end
    local bien, cod = bombear(self.sock, self)
    if not bien then return nil, "cerrado", cod end
    return sacarLineas(self)
  end
  function cli:cerrar()
    ws2.closesocket(self.sock)
  end
  return cli
end

return Red
