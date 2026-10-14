-- Sockets TCP no bloqueantes para el juego y para el cliente de PostgreSQL, con dos implementaciones por FFI según el
-- sistema: Windows (Winsock, el desarrollo y el cliente) y Linux (el servidor de la beta). El resto del código
-- (red.lua y pg.lua) solo usa esta interfaz y no sabe en qué sistema corre:
--   S.disponible()                      ¿hay sockets en este sistema?
--   S.abrir()                           socket nuevo (o nil)
--   S.cerrar(s)
--   S.nobloqueo(s) / S.sinDemora(s)     modo no bloqueante y TCP_NODELAY
--   S.escuchar(s, puerto)               enlaza a 0.0.0.0 y escucha: true, o nil y el error
--   S.aceptar(s)                        conexión nueva (o nil si no hay ninguna)
--   S.iniciarConexion(s, host, puerto)  "listo" | "pendiente" | "error"
--   S.conexionLista(s)                  true | false (aún no) | nil, código (falló)
--   S.enviar(s, texto)                  n enviados | nil, "espera" (buffer lleno, reintenta) | nil, "error", código
--   S.recibir(s, buf, max)              n > 0 | 0 (la otra parte cerró) | nil, "espera" | nil, "error", código
--   S.esperar(s, escribir, ms)          espera hasta ms milisegundos a que se pueda escribir (o leer)
local okffi, ffi = pcall(require, "ffi")

local S = {}

if not okffi then
  function S.disponible() return false end
  return S
end

-- ====================================================================================================== Windows
if ffi.os == "Windows" then
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
  local WSAEWOULDBLOCK, WSAEALREADY, WSAENOBUFS = 10035, 10037, 10055
  local iniciado = false

  function S.disponible()
    if iniciado then return true end
    local datos = ffi.new("WSADATA")
    iniciado = ws2.WSAStartup(0x0202, datos) == 0
    return iniciado
  end

  local function valido(s)
    if s == nil then return false end
    -- INVALID_SOCKET es -1. Comparar el cdata tal cual falla: no cabe en un número de Lua.
    return ffi.cast("intptr_t", s) ~= -1
  end

  function S.abrir()
    local s = ws2.socket(2, 1, 6)
    if not valido(s) then return nil end
    return s
  end

  function S.cerrar(s) if s ~= nil then ws2.closesocket(s) end end

  function S.nobloqueo(s)
    local nb = ffi.new("unsigned long[1]", 1)
    ws2.ioctlsocket(s, FIONBIO, nb)
  end

  function S.sinDemora(s)
    local uno = ffi.new("int[1]", 1)
    ws2.setsockopt(s, 6, 1, ffi.cast("const char *", uno), 4)
  end

  local function direccion(host, puerto)
    local addr = ffi.new("sockaddr_in")
    addr.sin_family = 2
    addr.sin_port = ws2.htons(puerto)
    addr.sin_addr = ws2.inet_addr(host)
    return addr
  end

  function S.escuchar(s, puerto)
    local addr = direccion("0.0.0.0", puerto)
    if ws2.bind(s, addr, ffi.sizeof(addr)) ~= 0 then return nil, "puerto ocupado" end
    ws2.listen(s, 8)
    return true
  end

  function S.aceptar(s)
    local nuevo = ws2.accept(s, nil, nil)
    if not valido(nuevo) then return nil end
    return nuevo
  end

  function S.iniciarConexion(s, host, puerto)
    local addr = direccion(host, puerto)
    if ws2.connect(s, addr, ffi.sizeof(addr)) == 0 then return "listo" end
    local err = ws2.WSAGetLastError()
    if err == WSAEWOULDBLOCK then return "pendiente" end
    return "error", err
  end

  local function errorSocket(s)
    local valor = ffi.new("int[1]")
    local largo = ffi.new("int[1]", 4)
    if ws2.getsockopt(s, 0xffff, 0x1007, ffi.cast("char *", valor), largo) ~= 0 then
      return ws2.WSAGetLastError()
    end
    return tonumber(valor[0]) or 0
  end

  function S.conexionLista(s)
    if not valido(s) then return nil, 10038 end
    local set = ffi.new("fd_set")
    set.fd_count = 1
    set.fd_array[0] = s
    local tv = ffi.new("timeval")
    if ws2.select(0, nil, set, nil, tv) <= 0 then return false end
    local fallo = errorSocket(s)
    if fallo ~= 0 and fallo ~= WSAEWOULDBLOCK and fallo ~= 10036 then return nil, fallo end
    return true
  end

  function S.enviar(s, texto)
    if not valido(s) then return nil, "error", 10038 end
    -- ffi.copy con un string copia también el \0 final: el buffer necesita un byte más
    local buf = ffi.new("char[?]", #texto + 1)
    ffi.copy(buf, texto, #texto)
    local n = ws2.send(s, buf, #texto, 0)
    if n < 0 then
      local err = ws2.WSAGetLastError()
      if err == WSAEWOULDBLOCK or err == WSAENOBUFS then return nil, "espera" end
      return nil, "error", err
    end
    return n
  end

  function S.recibir(s, buf, max)
    local n = ws2.recv(s, buf, max, 0)
    if n >= 0 then return n end
    local err = ws2.WSAGetLastError()
    if err == WSAEWOULDBLOCK or err == 0 then return nil, "espera" end
    return nil, "error", err
  end

  function S.esperar(s, escribir, ms)
    local set = ffi.new("fd_set")
    set.fd_count = 1
    set.fd_array[0] = s
    local tv = ffi.new("timeval")
    tv.tv_sec = math.floor(ms / 1000)
    tv.tv_usec = (ms % 1000) * 1000
    local r
    if escribir then r = ws2.select(0, nil, set, nil, tv) else r = ws2.select(0, set, nil, nil, tv) end
    return r > 0
  end

  return S
end

-- ======================================================================================================== Linux
if ffi.os ~= "Linux" then
  function S.disponible() return false end
  return S
end

ffi.cdef[[
int socket(int domain, int type, int protocol);
int close(int fd);
int bind(int fd, const void *addr, unsigned int len);
int listen(int fd, int backlog);
int accept(int fd, void *addr, unsigned int *len);
int connect(int fd, const void *addr, unsigned int len);
long send(int fd, const void *buf, unsigned long len, int flags);
long recv(int fd, void *buf, unsigned long len, int flags);
int ioctl(int fd, unsigned long request, ...);
int getsockopt(int fd, int level, int optname, void *optval, unsigned int *optlen);
int setsockopt(int fd, int level, int optname, const void *optval, unsigned int optlen);
unsigned short htons(unsigned short hostshort);
unsigned int inet_addr(const char *cp);
typedef struct sockaddr_in_l {
  unsigned short sin_family;
  unsigned short sin_port;
  unsigned int sin_addr;
  char sin_zero[8];
} sockaddr_in_l;
typedef struct pollfd_l {
  int fd;
  short events;
  short revents;
} pollfd_l;
int poll(pollfd_l *fds, unsigned long nfds, int timeout);
]]

local EINTR, EAGAIN, EALREADY, EINPROGRESS, ENOBUFS, ENOMEM = 4, 11, 114, 115, 105, 12
local FIONBIO = 0x5421
local MSG_NOSIGNAL = 0x4000      -- escribir en un socket cerrado no mata el proceso con SIGPIPE
local POLLIN, POLLOUT = 0x001, 0x004

function S.disponible() return true end

function S.abrir()
  local s = ffi.C.socket(2, 1, 6)
  if s < 0 then return nil end
  return s
end

function S.cerrar(s) if s then ffi.C.close(s) end end

function S.nobloqueo(s)
  local nb = ffi.new("int[1]", 1)
  ffi.C.ioctl(s, FIONBIO, nb)
end

function S.sinDemora(s)
  local uno = ffi.new("int[1]", 1)
  ffi.C.setsockopt(s, 6, 1, uno, 4)
end

local function direccion(host, puerto)
  local addr = ffi.new("sockaddr_in_l")
  addr.sin_family = 2
  addr.sin_port = ffi.C.htons(puerto)
  addr.sin_addr = ffi.C.inet_addr(host)
  return addr
end

function S.escuchar(s, puerto)
  -- reutilizar el puerto al reiniciar el servicio sin esperar a que caduquen las conexiones viejas
  local uno = ffi.new("int[1]", 1)
  ffi.C.setsockopt(s, 1, 2, uno, 4)
  local addr = direccion("0.0.0.0", puerto)
  if ffi.C.bind(s, addr, ffi.sizeof(addr)) ~= 0 then return nil, "puerto ocupado" end
  ffi.C.listen(s, 64)
  return true
end

function S.aceptar(s)
  local nuevo = ffi.C.accept(s, nil, nil)
  if nuevo < 0 then return nil end
  return nuevo
end

function S.iniciarConexion(s, host, puerto)
  local addr = direccion(host, puerto)
  if ffi.C.connect(s, addr, ffi.sizeof(addr)) == 0 then return "listo" end
  local err = ffi.errno()
  if err == EINPROGRESS or err == EINTR then return "pendiente" end
  return "error", err
end

function S.conexionLista(s)
  local pfd = ffi.new("pollfd_l[1]")
  pfd[0].fd, pfd[0].events = s, POLLOUT
  if ffi.C.poll(pfd, 1, 0) <= 0 then return false end
  local valor = ffi.new("int[1]")
  local largo = ffi.new("unsigned int[1]", 4)
  if ffi.C.getsockopt(s, 1, 4, valor, largo) ~= 0 then return nil, ffi.errno() end
  local fallo = tonumber(valor[0]) or 0
  if fallo ~= 0 and fallo ~= EINPROGRESS and fallo ~= EALREADY then return nil, fallo end
  return true
end

function S.enviar(s, texto)
  local n = tonumber(ffi.C.send(s, texto, #texto, MSG_NOSIGNAL))
  if n < 0 then
    local err = ffi.errno()
    if err == EAGAIN or err == EINTR or err == ENOBUFS or err == ENOMEM then return nil, "espera" end
    return nil, "error", err
  end
  return n
end

function S.recibir(s, buf, max)
  local n = tonumber(ffi.C.recv(s, buf, max, 0))
  if n >= 0 then return n end
  local err = ffi.errno()
  if err == EAGAIN or err == EINTR then return nil, "espera" end
  return nil, "error", err
end

function S.esperar(s, escribir, ms)
  local pfd = ffi.new("pollfd_l[1]")
  pfd[0].fd, pfd[0].events = s, escribir and POLLOUT or POLLIN
  return ffi.C.poll(pfd, 1, ms) > 0
end

return S
