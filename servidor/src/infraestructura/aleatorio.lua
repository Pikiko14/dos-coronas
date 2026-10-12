-- Bytes aleatorios en hexadecimal para sales y tokens de sesión.
-- Bytes aleatorios en hexadecimal. Usa el generador del sistema (RtlGenRandom) y, si no
-- está, el de LÖVE. No sirve math.random: Mundo.nuevo() lo siembra con una constante.
local okFfi, ffi = pcall(require, "ffi")
local sistema
if okFfi then
  pcall(function()
    ffi.cdef[[ int SystemFunction036(void *buffer, unsigned long largo); ]]
    sistema = ffi.load("advapi32")
  end)
end

local function aleatorio(n)
  if sistema then
    local buf = ffi.new("uint8_t[?]", n)
    if sistema.SystemFunction036(buf, n) ~= 0 then
      local t = {}
      for i = 0, n - 1 do t[#t + 1] = string.format("%02x", buf[i]) end
      return table.concat(t)
    end
  end
  local t = {}
  for _ = 1, n do t[#t + 1] = string.format("%02x", love.math.random(0, 255)) end
  return table.concat(t)
end

return aleatorio
