-- Credenciales: hash de claves (PBKDF2-HMAC-SHA256) y reglas de usuario y nombre.
-- No depende de LÖVE, de la red ni de la base de datos.
local C = {}

local bit = require("bit")
local band, bxor, rrotate, rshift = bit.band, bit.bxor, bit.ror, bit.rshift
local K = {
  0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
}

function C.sha256(msg)
  local bytes = { msg:byte(1, #msg) }
  local bitlen = #msg * 8
  bytes[#bytes + 1] = 0x80
  while (#bytes % 64) ~= 56 do bytes[#bytes + 1] = 0 end
  for i = 7, 0, -1 do
    bytes[#bytes + 1] = math.floor(bitlen / (256 ^ i)) % 256
  end
  local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
  local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
  local function add(a, b) return band(a + b, 0xffffffff) end
  for bloque = 1, #bytes, 64 do
    local w = {}
    for i = 0, 15 do
      local o = bloque + i * 4
      w[i] = bytes[o] * 16777216 + bytes[o + 1] * 65536 + bytes[o + 2] * 256 + bytes[o + 3]
    end
    for i = 16, 63 do
      local s0 = bxor(rrotate(w[i - 15], 7), rrotate(w[i - 15], 18), rshift(w[i - 15], 3))
      local s1 = bxor(rrotate(w[i - 2], 17), rrotate(w[i - 2], 19), rshift(w[i - 2], 10))
      w[i] = add(add(add(w[i - 16], s0), w[i - 7]), s1)
    end
    local a, b, c, d, e, f, g, hh = h0, h1, h2, h3, h4, h5, h6, h7
    for i = 0, 63 do
      local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
      local ch = bxor(bit.band(e, f), bit.band(bit.bnot(e), g))
      local t1 = add(add(add(add(hh, S1), ch), K[i + 1]), w[i])
      local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
      local maj = bxor(bit.band(a, b), bit.band(a, c), bit.band(b, c))
      local t2 = add(S0, maj)
      hh, g, f, e, d, c, b, a = g, f, e, add(d, t1), c, b, a, add(t1, t2)
    end
    h0, h1, h2, h3 = add(h0, a), add(h1, b), add(h2, c), add(h3, d)
    h4, h5, h6, h7 = add(h4, e), add(h5, f), add(h6, g), add(h7, hh)
  end
  local function hex(n)
    n = band(n, 0xffffffff)
    if n < 0 then n = n + 4294967296 end
    return string.format("%08x", n)
  end
  return hex(h0) .. hex(h1) .. hex(h2) .. hex(h3) .. hex(h4) .. hex(h5) .. hex(h6) .. hex(h7)
end

C.ITER = 32

local function dehex(h)
  local t = {}
  for i = 1, #h, 2 do
    t[#t + 1] = string.char(tonumber(h:sub(i, i + 1), 16) or 0)
  end
  return table.concat(t)
end

local function ahex(s)
  local t = {}
  for i = 1, #s do t[i] = string.format("%02x", s:byte(i)) end
  return table.concat(t)
end

local function xorbytes(a, b)
  local t = {}
  for i = 1, #a do t[i] = string.char(bxor(a:byte(i), b:byte(i))) end
  return table.concat(t)
end

local function hmac(clave, msg)
  local key = clave
  if #key > 64 then key = dehex(C.sha256(key)) end
  if #key < 64 then key = key .. string.rep("\0", 64 - #key) end
  local ip, op = {}, {}
  for i = 1, 64 do
    local b = key:byte(i)
    ip[i] = string.char(bxor(b, 0x36))
    op[i] = string.char(bxor(b, 0x5c))
  end
  local interno = dehex(C.sha256(table.concat(ip) .. msg))
  return dehex(C.sha256(table.concat(op) .. interno))
end

function C.pbkdf2(clave, sal, iter)
  iter = math.max(1, math.floor(tonumber(iter) or 1))
  local u = hmac(clave, (sal or "") .. string.char(0, 0, 0, 1))
  local t = u
  for _ = 2, iter do
    u = hmac(clave, u)
    t = xorbytes(t, u)
  end
  return ahex(t)
end

function C.cifrar(clave, sal)
  local n = C.ITER
  return "pbkdf2$" .. n .. "$" .. C.pbkdf2(clave, sal, n)
end

function C.acepta(guardada, sal, clave)
  guardada = guardada or ""
  if guardada:sub(1, 7) == "pbkdf2$" then
    local iter, hex = guardada:match("^pbkdf2$(%d+)$([0-9a-f]+)$")
    if not iter then return false, false end
    return C.pbkdf2(clave or "", sal or "", tonumber(iter)) == hex, false
  end
  if C.sha256((sal or "") .. ":" .. (clave or "")) == guardada then return true, true end
  return false, false
end

function C.usuarioValido(usuario)
  if type(usuario) ~= "string" or #usuario < 3 or #usuario > 16 then return false end
  for i = 1, #usuario do
    local c = usuario:byte(i)
    local letra = (c >= 65 and c <= 90) or (c >= 97 and c <= 122)
    local digito = c >= 48 and c <= 57
    if not (letra or digito or c == 95) then return false end
  end
  return true
end

function C.nombreValido(nombre)
  if type(nombre) ~= "string" then return false end
  local n = 0
  local i = 1
  while i <= #nombre do
    local c = nombre:byte(i)
    if c < 128 then
      local letra = (c >= 65 and c <= 90) or (c >= 97 and c <= 122)
      local digito = c >= 48 and c <= 57
      if not (letra or digito or c == 32) then return false end
      i = i + 1
    elseif c >= 194 and c <= 223 and i + 1 <= #nombre then
      i = i + 2
    else
      return false
    end
    n = n + 1
  end
  return n >= 3 and n <= 16
end

return C
