local U = {}

function U.clamp(v, a, b)
  if v < a then return a end
  if v > b then return b end
  return v
end

function U.dist(ax, ay, bx, by)
  local dx, dy = ax - bx, ay - by
  return math.sqrt(dx * dx + dy * dy)
end

function U.signo(v)
  if v > 0.15 then return 1 end
  if v < -0.15 then return -1 end
  return 0
end

function U.limpiar(s)
  return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function U.popUtf8(s)
  local i = #s
  while i > 0 do
    local b = s:byte(i)
    i = i - 1
    if b < 128 or b >= 192 then break end
  end
  return s:sub(1, i)
end

function U.rng(seed)
  local s = seed % 4294967296
  local r = {}
  local function mul32(a, b)
    local alo, blo = a % 65536, b % 65536
    local ahi, bhi = (a - alo) / 65536, (b - blo) / 65536
    local low = alo * blo
    local mid = alo * bhi + ahi * blo
    return (low + (mid % 65536) * 65536) % 4294967296
  end
  function r:next()
    s = (mul32(s, 1664525) + 1013904223) % 4294967296
    return s / 4294967296
  end
  function r:int(a, b)
    return a + math.floor(self:next() * (b - a + 1))
  end
  function r:float(a, b)
    return a + self:next() * (b - a)
  end
  function r:chance(p)
    return self:next() < p
  end
  return r
end

local function esc(s)
  return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t") .. '"'
end

local function esArray(t)
  local n, maxk = 0, 0
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then return false end
    n = n + 1
    if k > maxk then maxk = k end
  end
  return n == maxk
end

function U.jsonEnc(v)
  local tv = type(v)
  if v == nil then return "null" end
  if tv == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "0" end
    if v == math.floor(v) then return string.format("%d", v) end
    return string.format("%.3f", v)
  end
  if tv == "boolean" then return v and "true" or "false" end
  if tv == "string" then return esc(v) end
  if tv == "table" then
    if esArray(v) then
      local p = {}
      for i = 1, #v do p[i] = U.jsonEnc(v[i]) end
      return "[" .. table.concat(p, ",") .. "]"
    end
    local p = {}
    for k, val in pairs(v) do
      if type(val) ~= "function" then
        p[#p + 1] = esc(tostring(k)) .. ":" .. U.jsonEnc(val)
      end
    end
    table.sort(p)
    return "{" .. table.concat(p, ",") .. "}"
  end
  return "null"
end

function U.jsonDec(s)
  local i, n = 1, #s
  local function peek() return s:sub(i, i) end
  local function skip()
    while true do
      local c = peek()
      if c == " " or c == "\n" or c == "\r" or c == "\t" then i = i + 1 else break end
    end
  end
  local function parse()
    skip()
    local c = peek()
    if c == "{" then return parseObj() end
    if c == "[" then return parseArr() end
    if c == '"' then return parseStr() end
    if s:sub(i, i + 3) == "true" then i = i + 4 return true end
    if s:sub(i, i + 4) == "false" then i = i + 5 return false end
    if s:sub(i, i + 3) == "null" then i = i + 4 return nil end
    return parseNum()
  end
  function parseStr()
    i = i + 1
    local out = {}
    while i <= n do
      local c = s:sub(i, i)
      if c == '"' then i = i + 1 break end
      if c == "\\" then
        local e = s:sub(i + 1, i + 1)
        if e == "n" then out[#out + 1] = "\n"; i = i + 2
        elseif e == "r" then out[#out + 1] = "\r"; i = i + 2
        elseif e == "t" then out[#out + 1] = "\t"; i = i + 2
        elseif e == "u" then
          local cp = tonumber(s:sub(i + 2, i + 5), 16) or 63
          if cp < 128 then out[#out + 1] = string.char(cp)
          elseif cp < 2048 then
            out[#out + 1] = string.char(192 + math.floor(cp / 64), 128 + cp % 64)
          else
            out[#out + 1] = string.char(224 + math.floor(cp / 4096), 128 + math.floor(cp / 64) % 64, 128 + cp % 64)
          end
          i = i + 6
        else
          out[#out + 1] = e
          i = i + 2
        end
      else
        out[#out + 1] = c
        i = i + 1
      end
    end
    return table.concat(out)
  end
  function parseNum()
    local st = i
    while i <= n and s:sub(i, i):match("[%d%.eE+%-]") do i = i + 1 end
    return tonumber(s:sub(st, i - 1)) or 0
  end
  function parseArr()
    i = i + 1
    local t = {}
    skip()
    if peek() == "]" then i = i + 1 return t end
    while true do
      t[#t + 1] = parse()
      skip()
      if peek() == "," then i = i + 1
      elseif peek() == "]" then i = i + 1 break
      else break end
    end
    return t
  end
  function parseObj()
    i = i + 1
    local t = {}
    skip()
    if peek() == "}" then i = i + 1 return t end
    while true do
      skip()
      local k = parseStr()
      skip()
      if peek() == ":" then i = i + 1 end
      t[k] = parse()
      skip()
      if peek() == "," then i = i + 1
      elseif peek() == "}" then i = i + 1 break
      else break end
    end
    return t
  end
  local ok, res = pcall(parse)
  if not ok then return nil, res end
  return res
end

return U
