-- XML mínimo para la configuración del juego (compartido/datos/*.xml): lector, escritor y conversión
-- entre elementos y tablas de Lua.
--
-- Qué admite: elementos con atributos (comillas simples o dobles), elementos vacíos (<a/>), comentarios
-- (<!-- -->), cabecera <?xml ...?>, texto dentro de un elemento, <![CDATA[ ]]> y las entidades
-- &lt; &gt; &amp; &quot; &apos;. Los errores dicen archivo y línea.
--
-- Conversión elemento <-> tabla (la usan los cargadores de datos):
--   * Cada atributo es un campo: "true"/"false" son booleanos, los números son números y lo demás texto
--     (un texto que parecería un número o un booleano se escribe con el prefijo "s:").
--   * Un hijo con el atributo lista="a,b,c" (y nada más) es una lista de valores: <poderes lista="a,b"/>.
--   * Un hijo <i .../> es un elemento de la lista del padre (cada <i> es una tabla con su estructura).
--   * Cualquier otro hijo es un campo del padre cuyo valor es la tabla del hijo.
--   * El texto de un elemento sin atributos ni hijos es su valor ("<desc>hola</desc>" no se usa; los textos
--     largos van en atributos).
local X = {}

local ENTIDADES = { lt = "<", gt = ">", amp = "&", quot = '"', apos = "'" }

local function desescapar(s)
  return (s:gsub("&(#?%w+);", function(e)
    if ENTIDADES[e] then return ENTIDADES[e] end
    if e:sub(1, 2) == "#x" then return utf8 and utf8.char and utf8.char(tonumber(e:sub(3), 16)) or "?" end
    if e:sub(1, 1) == "#" then return string.char(tonumber(e:sub(2)) or 63) end
    return "&" .. e .. ";"
  end))
end

local function escapar(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("\n", "&#10;"))
end

-- ------------------------------------------------------------------------------------- lector
-- Devuelve el elemento raíz: { tag, attrs = {nombre = texto}, orden = {nombres de atributos en orden},
-- hijos = {...}, texto, linea }.
function X.leer(fuente, nombre)
  nombre = nombre or "xml"
  local pos, linea = 1, 1
  local n = #fuente
  local function fallo(msg, l) error(nombre .. ":" .. (l or linea) .. ": " .. msg, 0) end
  local function avanzar(hasta)
    local trozo = fuente:sub(pos, hasta - 1)
    for _ in trozo:gmatch("\n") do linea = linea + 1 end
    pos = hasta
  end
  local function saltarEspacios()
    local _, e = fuente:find("^[ \t\r\n]*", pos)
    avanzar(e + 1)
  end
  -- cabecera y comentarios iniciales
  local function saltarMisc()
    while true do
      saltarEspacios()
      if fuente:sub(pos, pos + 3) == "<!--" then
        local _, e = fuente:find("-->", pos + 4, true)
        if not e then fallo("comentario sin cerrar") end
        avanzar(e + 1)
      elseif fuente:sub(pos, pos + 1) == "<?" then
        local _, e = fuente:find("?>", pos + 2, true)
        if not e then fallo("cabecera <? sin cerrar") end
        avanzar(e + 1)
      else
        return
      end
    end
  end

  local function leerElemento()
    if fuente:sub(pos, pos) ~= "<" then fallo("se esperaba '<'") end
    local lineaIni = linea
    local _, e, tag = fuente:find("^<([%a_\128-\255][%w_%.%-:\128-\255]*)", pos)   -- (los bytes altos son UTF-8: los .mpc de FAO traen etiquetas en chino)
    if not tag then fallo("nombre de elemento no válido") end
    avanzar(e + 1)
    local el = { tag = tag, attrs = {}, orden = {}, hijos = {}, linea = lineaIni }
    -- atributos
    while true do
      saltarEspacios()
      local c = fuente:sub(pos, pos)
      if c == "/" then
        if fuente:sub(pos, pos + 1) ~= "/>" then fallo("'/' inesperada dentro de <" .. tag .. ">") end
        avanzar(pos + 2)
        return el
      elseif c == ">" then
        avanzar(pos + 1)
        break
      elseif c == "" then
        fallo("el elemento <" .. tag .. "> no se cierra", lineaIni)
      else
        local _, e2, nom = fuente:find("^([%a_\128-\255][%w_%.%-:\128-\255]*)", pos)
        if not nom then fallo("atributo no válido dentro de <" .. tag .. ">") end
        avanzar(e2 + 1)
        saltarEspacios()
        if fuente:sub(pos, pos) ~= "=" then fallo("falta '=' en el atributo " .. nom) end
        avanzar(pos + 1)
        saltarEspacios()
        local q = fuente:sub(pos, pos)
        if q ~= '"' and q ~= "'" then fallo("el valor del atributo " .. nom .. " debe ir entre comillas") end
        local fin = fuente:find(q, pos + 1, true)
        if not fin then fallo("comillas sin cerrar en el atributo " .. nom) end
        local valor = desescapar(fuente:sub(pos + 1, fin - 1))
        if el.attrs[nom] ~= nil then fallo("atributo repetido: " .. nom) end
        el.attrs[nom] = valor
        el.orden[#el.orden + 1] = nom
        avanzar(fin + 1)
      end
    end
    -- contenido
    local texto = {}
    while true do
      if pos > n then fallo("el elemento <" .. tag .. "> no se cierra", lineaIni) end
      local lt = fuente:find("<", pos, true)
      if not lt then fallo("el elemento <" .. tag .. "> no se cierra", lineaIni) end
      if lt > pos then texto[#texto + 1] = fuente:sub(pos, lt - 1) avanzar(lt) end
      if fuente:sub(pos, pos + 3) == "<!--" then
        local _, e3 = fuente:find("-->", pos + 4, true)
        if not e3 then fallo("comentario sin cerrar") end
        avanzar(e3 + 1)
      elseif fuente:sub(pos, pos + 8) == "<![CDATA[" then
        local _, e3 = fuente:find("]]>", pos + 9, true)
        if not e3 then fallo("CDATA sin cerrar") end
        texto[#texto + 1] = fuente:sub(pos + 9, e3 - 3)
        avanzar(e3 + 1)
      elseif fuente:sub(pos, pos + 1) == "</" then
        local _, e3, cierre = fuente:find("^</([%a_\128-\255][%w_%.%-:\128-\255]*)%s*>", pos)
        if not cierre then fallo("cierre no válido") end
        if cierre ~= tag then fallo("se cierra </" .. cierre .. "> pero estaba abierto <" .. tag .. ">") end
        avanzar(e3 + 1)
        break
      else
        el.hijos[#el.hijos + 1] = leerElemento()
      end
    end
    local t = table.concat(texto):gsub("^%s+", ""):gsub("%s+$", "")
    if t ~= "" then el.texto = desescapar(t) end
    return el
  end

  saltarMisc()
  if pos > n then fallo("el archivo está vacío") end
  local raiz = leerElemento()
  saltarMisc()
  if pos <= n then fallo("hay contenido después del elemento raíz") end
  return raiz
end

-- ---------------------------------------------------------------------------------- conversión
local function valor(txt, ctx)
  if txt == "true" then return true end
  if txt == "false" then return false end
  if txt:sub(1, 2) == "s:" then return txt:sub(3) end
  if txt:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*$") or txt:match("^%-?%.%d+$") then
    local num = tonumber(txt)
    if num then return num end
  end
  return txt
end
X.valor = valor

local function aLista(txt)
  local lista = {}
  if txt == "" then return lista end
  for item in (txt .. ","):gmatch("(.-),") do
    item = item:gsub("^%s+", ""):gsub("%s+$", "")
    lista[#lista + 1] = valor(item)
  end
  return lista
end

-- Elemento -> tabla (ver las reglas arriba). nombre se usa en los errores.
function X.aTabla(el, nombre)
  local t = {}
  for _, a in ipairs(el.orden) do t[a] = valor(el.attrs[a]) end
  for _, h in ipairs(el.hijos) do
    if h.tag == "i" then
      if #h.hijos == 0 and #h.orden == 1 and h.attrs.lista ~= nil then
        t[#t + 1] = aLista(h.attrs.lista)
      else
        t[#t + 1] = X.aTabla(h, nombre)
      end
    elseif #h.hijos == 0 and #h.orden == 1 and h.attrs.lista ~= nil then
      if t[h.tag] ~= nil then error((nombre or "xml") .. ":" .. h.linea .. ": campo repetido: " .. h.tag, 0) end
      t[h.tag] = aLista(h.attrs.lista)
    else
      if t[h.tag] ~= nil then error((nombre or "xml") .. ":" .. h.linea .. ": campo repetido: " .. h.tag, 0) end
      t[h.tag] = X.aTabla(h, nombre)
    end
  end
  if el.texto and #el.orden == 0 and #el.hijos == 0 then return valor(el.texto) end
  return t
end

-- ---------------------------------------------------------------------------------- escritor
local function numTxt(v)
  if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%d", v) end
  local s = string.format("%.14g", v)
  if tonumber(s) ~= v then s = string.format("%.17g", v) end
  return s
end

local function escalarTxt(v)
  local tp = type(v)
  if tp == "boolean" then return tostring(v) end
  if tp == "number" then return numTxt(v) end
  if tp == "string" then
    if v == "true" or v == "false" or v:sub(1, 2) == "s:" or valor(v) ~= v then return "s:" .. v end
    return v
  end
  error("valor no escribible en XML: " .. tp)
end
X.escalarTxt = escalarTxt

local function esEscalar(v) local tp = type(v) return tp == "string" or tp == "number" or tp == "boolean" end

-- ¿Es una lista de valores simples? (índices 1..n y nada más)
local function listaSimple(t)
  local n = #t
  if n == 0 then return false end
  local cuenta = 0
  for k in pairs(t) do cuenta = cuenta + 1 end
  if cuenta ~= n then return false end
  for i = 1, n do if not esEscalar(t[i]) then return false end end
  return true
end

-- orden preferido de los atributos al escribir
local PRIMEROS = { "id", "nombre", "clase", "nivel", "tipo" }

local function claves(t)
  local ks = {}
  for k in pairs(t) do
    if type(k) == "string" then ks[#ks + 1] = k
    elseif type(k) ~= "number" then error("clave no escribible en XML: " .. tostring(k)) end
  end
  local pref = {}
  for i, k in ipairs(PRIMEROS) do pref[k] = i end
  table.sort(ks, function(a, b)
    local pa, pb = pref[a] or 100, pref[b] or 100
    if pa ~= pb then return pa < pb end
    return a < b
  end)
  return ks
end

-- Escribe la tabla t como elemento <tag>. sangria: nivel de sangrado. Devuelve el texto.
function X.escribir(tag, t, sangria, salida)
  sangria = sangria or 0
  salida = salida or {}
  local pad = string.rep("  ", sangria)
  local attrs, hijos = {}, {}
  for _, k in ipairs(claves(t)) do
    local v = t[k]
    if esEscalar(v) then
      attrs[#attrs + 1] = k .. '="' .. escapar(escalarTxt(v)) .. '"'
    elseif type(v) == "table" then
      hijos[#hijos + 1] = { k, v }
    else
      error("valor no escribible en XML (" .. k .. "): " .. type(v))
    end
  end
  local items = {}
  for i = 1, #t do items[#items + 1] = t[i] end
  for k in pairs(t) do
    if type(k) == "number" and (k < 1 or k > #t or k ~= math.floor(k)) then error("clave numérica no escribible: " .. k) end
  end
  local linea = pad .. "<" .. tag
  if #attrs > 0 then linea = linea .. " " .. table.concat(attrs, " ") end
  if #hijos == 0 and #items == 0 then
    salida[#salida + 1] = linea .. "/>"
    return salida
  end
  salida[#salida + 1] = linea .. ">"
  for _, h in ipairs(hijos) do
    local k, v = h[1], h[2]
    if next(v) == nil then
      salida[#salida + 1] = pad .. "  <" .. k .. "/>"
    elseif listaSimple(v) then
      local partes = {}
      for i = 1, #v do partes[i] = escalarTxt(v[i]) end
      salida[#salida + 1] = pad .. "  <" .. k .. ' lista="' .. escapar(table.concat(partes, ",")) .. '"/>'
    else
      X.escribir(k, v, sangria + 1, salida)
    end
  end
  for _, it in ipairs(items) do
    if esEscalar(it) then error("lista mixta no escribible bajo <" .. tag .. ">") end
    if listaSimple(it) then
      local partes = {}
      for i = 1, #it do partes[i] = escalarTxt(it[i]) end
      salida[#salida + 1] = pad .. "  <i lista=\"" .. escapar(table.concat(partes, ",")) .. "\"/>"
    else
      X.escribir("i", it, sangria + 1, salida)
    end
  end
  salida[#salida + 1] = pad .. "</" .. tag .. ">"
  return salida
end

return X
