local Red = require("compartido.infraestructura.red")

local Pg = {}
local Sock = require("compartido.infraestructura.sockets")
local okffi, ffi = pcall(require, "ffi")

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
  local s = Sock.abrir()
  if not s then return nil, "No se pudo abrir el socket de Postgres." end
  Sock.nobloqueo(s)
  local resultado, err0 = Sock.iniciarConexion(s, host, puerto)
  if resultado == "error" or (resultado == "pendiente" and not Sock.esperar(s, true, 3000)) then
    Sock.cerrar(s)
    return nil, "Postgres no responde en " .. host .. ":" .. puerto .. "."
  end
  if resultado == "pendiente" then
    -- la espera terminó: comprobar que la conexión de verdad se hizo
    local ok = Sock.conexionLista(s)
    if not ok then
      Sock.cerrar(s)
      return nil, "Postgres no responde en " .. host .. ":" .. puerto .. "."
    end
  end
  local buf = ""
  local function recvRaw()
    local raw = ffi.new("char[8192]")
    local n, tipo = Sock.recibir(s, raw, 8191)
    if not n and tipo == "espera" then
      if not Sock.esperar(s, false, 3000) then return nil end
      n = Sock.recibir(s, raw, 8191)
    end
    if not n or n <= 0 then return nil end
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
      local n, tipo = Sock.enviar(s, resto)
      if not n and tipo == "espera" then
        if not Sock.esperar(s, true, 3000) then return false end
        n, tipo = Sock.enviar(s, resto)
      end
      if not n or n <= 0 then return false end
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
          Sock.cerrar(s)
          return nil, "Postgres pide una autenticación que este cliente no soporta (solo trust o password)."
        end
      elseif tipo == "E" then
        local texto = textoPg(cuerpo, "M") or "Error de Postgres."
        Sock.cerrar(s)
        return nil, texto
      elseif tipo == "Z" then
        break
      end
    end
    return true
  end
  local listo, err = arranque()
  if not listo then return nil, err end
  local conn = { sock = s }
  function conn:cerrar()
    if self.sock then Sock.cerrar(self.sock) self.sock = nil end
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
