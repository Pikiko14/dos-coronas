local Red = require("compartido.infraestructura.red")

local Pg = {}
local okffi, ffi = pcall(require, "ffi")
if okffi then
  pcall(function()
    ffi.cdef[[
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
  end)
end

local FIONBIO = -2147195266

local function i32(n)
  n = math.floor(n)
  if n < 0 then n = n + 4294967296 end
  local b1 = math.floor(n / 16777216) % 256
  local b2 = math.floor(n / 65536) % 256
  local b3 = math.floor(n / 256) % 256
  local b4 = n % 256
  return string.char(b1, b2, b3, b4)
end

local function u32(s, i)
  local a, b, c, d = s:byte(i, i + 3)
  return ((a or 0) * 16777216) + ((b or 0) * 65536) + ((c or 0) * 256) + (d or 0)
end

local function textoPg(cuerpo, letra)
  local busco = letra:byte()
  local i = 1
  while i <= #cuerpo do
    local codigo = cuerpo:byte(i)
    local fin = cuerpo:find("\0", i + 1, true)
    if not fin then break end
    if codigo == busco then return cuerpo:sub(i + 1, fin - 1) end
    i = fin + 1
  end
end

local function u16(s, i)
  local a, b = s:byte(i, i + 1)
  return ((a or 0) * 256) + (b or 0)
end

function Pg.literal(v)
  if v == nil then return "NULL" end
  if type(v) == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "0" end
    return tostring(v)
  end
  if type(v) == "boolean" then return v and "TRUE" or "FALSE" end
  return "'" .. tostring(v):gsub("'", "''") .. "'"
end

function Pg.conectar(host, puerto, usuario, base, clave)
  if not okffi or not Red.disponible() then return nil, "Sin red para la base de datos." end
  local ws2 = ffi.load("ws2_32")
  local s = ws2.socket(2, 1, 6)
  if s == nil or tonumber(s) == tonumber(ffi.cast("unsigned long long", -1)) then
    return nil, "No se pudo abrir el socket de Postgres."
  end
  local nb = ffi.new("unsigned long[1]", 1)
  ws2.ioctlsocket(s, FIONBIO, nb)
  local function esperar(leer, ms)
    local set = ffi.new("fd_set")
    set.fd_count = 1
    set.fd_array[0] = s
    local tv = ffi.new("timeval")
    tv.tv_sec = math.floor(ms / 1000)
    tv.tv_usec = (ms % 1000) * 1000
    local r = leer and ws2.select(0, set, nil, nil, tv) or ws2.select(0, nil, set, nil, tv)
    return r > 0
  end
  local addr = ffi.new("sockaddr_in")
  addr.sin_family = 2
  addr.sin_port = ws2.htons(puerto)
  addr.sin_addr = ws2.inet_addr(host)
  if ws2.connect(s, addr, ffi.sizeof(addr)) ~= 0 then
    local err = ws2.WSAGetLastError()
    if err ~= 10035 or not esperar(false, 3000) then
      ws2.closesocket(s)
      return nil, "Postgres no responde en " .. host .. ":" .. puerto .. "."
    end
  end
  local buf = ""
  local function recvRaw()
    local raw = ffi.new("char[8192]")
    local n = ws2.recv(s, raw, 8191, 0)
    if n < 0 and ws2.WSAGetLastError() == 10035 then
      if not esperar(true, 3000) then return nil end
      n = ws2.recv(s, raw, 8191, 0)
    end
    if n <= 0 then return nil end
    return ffi.string(raw, n)
  end
  local function pull(n)
    while #buf < n do
      local chunk = recvRaw()
      if not chunk then return nil, "La base cortó la conexión." end
      buf = buf .. chunk
    end
    local trozo = buf:sub(1, n)
    buf = buf:sub(n + 1)
    return trozo
  end
  local function enviar(texto)
    local off = 1
    while off <= #texto do
      local resto = texto:sub(off)
      local raw = ffi.new("char[?]", #resto + 1)
      ffi.copy(raw, resto, #resto)
      local n = ws2.send(s, raw, #resto, 0)
      if n < 0 and ws2.WSAGetLastError() == 10035 then
        if not esperar(false, 3000) then return false end
        n = ws2.send(s, raw, #resto, 0)
      end
      if n <= 0 then return false end
      off = off + n
    end
    return true
  end
  local function mensaje()
    local head, err = pull(5)
    if not head then return nil, err end
    local tipo = head:sub(1, 1)
    local len = u32(head, 2)
    local cuerpo = ""
    if len > 4 then
      cuerpo, err = pull(len - 4)
      if not cuerpo then return nil, err end
    end
    return tipo, cuerpo
  end
  local function arranque()
    local function cstr(t) return t .. "\0" end
    local params = cstr("user") .. cstr(usuario) .. cstr("database") .. cstr(base) .. cstr("client_encoding") .. cstr("UTF8") .. "\0"
    local body = i32(196608) .. params
    if not enviar(i32(#body + 4) .. body) then return nil, "No se pudo saludar a Postgres." end
    while true do
      local tipo, cuerpo = mensaje()
      if not tipo then return nil, cuerpo end
      if tipo == "R" then
        local auth = u32(cuerpo, 1)
        if auth == 3 then
          local pass = cstr(clave or "")
          enviar("p" .. i32(#pass + 4) .. pass)
        elseif auth ~= 0 then
          ws2.closesocket(s)
          return nil, "Postgres pide una autenticación que este cliente no soporta (solo trust o password)."
        end
      elseif tipo == "E" then
        local texto = textoPg(cuerpo, "M") or "Error de Postgres."
        ws2.closesocket(s)
        return nil, texto
      elseif tipo == "Z" then
        break
      end
    end
    return true
  end
  local listo, err = arranque()
  if not listo then return nil, err end
  local conn = { sock = s, ws2 = ws2 }
  function conn:cerrar()
    if self.sock then self.ws2.closesocket(self.sock) self.sock = nil end
  end
  function conn:consulta(sql)
    local payload = sql .. "\0"
    if not enviar("Q" .. i32(#payload + 4) .. payload) then return nil, "No se pudo consultar." end
    local filas, campos, errorPg = {}, nil, nil
    while true do
      local tipo, cuerpo = mensaje()
      if not tipo then return nil, cuerpo end
      if tipo == "T" then
        campos = {}
        local n = u16(cuerpo, 1)
        local i = 3
        for _ = 1, n do
          local cero = cuerpo:find("\0", i, true)
          campos[#campos + 1] = cuerpo:sub(i, cero - 1)
          i = cero + 1 + 18
        end
      elseif tipo == "D" then
        local n = u16(cuerpo, 1)
        local i = 3
        local fila = {}
        for c = 1, n do
          local len = u32(cuerpo, i)
          i = i + 4
          if len >= 2147483648 then
            fila[campos[c] or c] = nil
          else
            fila[campos[c] or c] = cuerpo:sub(i, i + len - 1)
            i = i + len
          end
        end
        filas[#filas + 1] = fila
      elseif tipo == "E" then
        errorPg = textoPg(cuerpo, "M") or "Error de Postgres."
      elseif tipo == "Z" then
        break
      end
    end
    if errorPg then return nil, errorPg end
    return filas
  end
  return conn
end

return Pg
