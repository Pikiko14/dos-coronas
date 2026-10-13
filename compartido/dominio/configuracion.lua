-- Carga la configuración del juego desde compartido/datos/*.xml (items, poderes, mascotas, monturas,
-- criaturas...). Cada archivo se lee una vez; los cargadores devuelven las mismas tablas de Lua que
-- antes estaban escritas en el código, así el resto del juego no cambia.
--
-- Los archivos se buscan igual que el código compartido: primero ../compartido/datos junto al proyecto
-- (en el repositorio) y, si no, dentro del paquete .love (compartido/datos).
local X = require("compartido.dominio.xml")

local C = {}
C.CARPETA = "compartido/datos/"

local cache = {}

local function leerArchivo(nombre)
  local ruta = C.CARPETA .. nombre .. ".xml"
  local contenido
  if love and love.filesystem and love.filesystem.getSource then
    local base = love.filesystem.getSource():gsub("\\", "/")
    -- junto al proyecto (juego/ y servidor/) y, para las herramientas (herramientas/x/), un nivel mas arriba
    for _, subida in ipairs({ "/../", "/../../" }) do
      local f = io.open(base .. subida .. ruta, "rb")
      if f then
        contenido = f:read("*a")
        f:close()
        break
      end
    end
    if not contenido then contenido = love.filesystem.read(ruta) end
  else
    local f = io.open(ruta, "rb")
    if f then contenido = f:read("*a") f:close() end
  end
  if not contenido then error("falta el archivo de configuración " .. ruta, 0) end
  -- quita la marca de orden de bytes de UTF-8 si la hay
  if contenido:sub(1, 3) == "\239\187\191" then contenido = contenido:sub(4) end
  return contenido, ruta
end

-- Elemento raíz de compartido/datos/<nombre>.xml (se guarda en caché).
function C.raiz(nombre)
  if cache[nombre] then return cache[nombre] end
  local contenido, ruta = leerArchivo(nombre)
  local raiz = X.leer(contenido, ruta)
  raiz.archivo = ruta
  cache[nombre] = raiz
  return raiz
end

function C.olvidar() cache = {} end

local function aviso(raiz, el, msg)
  error(raiz.archivo .. ":" .. el.linea .. ": " .. msg, 0)
end

-- Tabla completa del archivo (la raíz convertida con las reglas de xml.lua).
function C.tabla(nombre)
  local raiz = C.raiz(nombre)
  return X.aTabla(raiz, raiz.archivo)
end

-- Registros <tag ... /> directos bajo la raíz, en orden, como lista de tablas. Un hijo con otro nombre es un
-- error (así un typo en una etiqueta no pasa en silencio).
function C.lista(nombre, tag)
  local raiz = C.raiz(nombre)
  local lista = {}
  for _, el in ipairs(raiz.hijos) do
    if el.tag ~= tag then aviso(raiz, el, "se esperaba <" .. tag .. "> y hay <" .. el.tag .. ">") end
    lista[#lista + 1] = X.aTabla(el, raiz.archivo)
  end
  return lista
end

-- Registros <tag id="..." .../> como mapa id -> tabla. conservarId = false quita el campo id de la tabla
-- (cuando el código nunca lo tuvo dentro del registro).
function C.mapa(nombre, tag, conservarId, otros)
  local raiz = C.raiz(nombre)
  local mapa = {}
  for _, el in ipairs(raiz.hijos) do
    if el.tag ~= tag then
      -- otras etiquetas permitidas del archivo (secciones que lee C.seccion)
      if not (otros and otros[el.tag]) then aviso(raiz, el, "se esperaba <" .. tag .. "> y hay <" .. el.tag .. ">") end
    else
      local reg = X.aTabla(el, raiz.archivo)
      local id = reg.id
      if id == nil then aviso(raiz, el, "<" .. tag .. "> sin atributo id") end
      if mapa[id] ~= nil then aviso(raiz, el, "id repetido: " .. tostring(id)) end
      if conservarId == false then reg.id = nil end
      mapa[id] = reg
    end
  end
  return mapa
end

-- Para archivos con varias clases de registro (mall.xml...): solo los <tag>, el resto de etiquetas se ignora.
-- registros: lista en orden; mapaOrden: mapa id -> tabla y la lista de ids en el orden del archivo.
function C.registros(nombre, tag)
  local raiz = C.raiz(nombre)
  local lista = {}
  for _, el in ipairs(raiz.hijos) do
    if el.tag == tag then lista[#lista + 1] = X.aTabla(el, raiz.archivo) end
  end
  return lista
end

function C.mapaOrden(nombre, tag, conservarId)
  local raiz = C.raiz(nombre)
  local mapa, orden = {}, {}
  for _, el in ipairs(raiz.hijos) do
    if el.tag == tag then
      local reg = X.aTabla(el, raiz.archivo)
      local id = reg.id
      if id == nil then aviso(raiz, el, "<" .. tag .. "> sin atributo id") end
      if mapa[id] ~= nil then aviso(raiz, el, "id repetido: " .. tostring(id)) end
      if conservarId == false then reg.id = nil end
      mapa[id] = reg
      orden[#orden + 1] = id
    end
  end
  return mapa, orden
end

-- Hijo único de la raíz con ese nombre, convertido a tabla (o nil).
function C.seccion(nombre, tag)
  local raiz = C.raiz(nombre)
  for _, el in ipairs(raiz.hijos) do
    if el.tag == tag then
      if #el.hijos == 0 and #el.orden == 1 and el.attrs.lista ~= nil then
        return X.aTabla({ tag = "x", attrs = {}, orden = {}, hijos = { el } }, raiz.archivo)[tag]
      end
      return X.aTabla(el, raiz.archivo)
    end
  end
end

-- Copia a un módulo los ajustes de su sección de constantes.xml (precios, tiempos, límites...). Los valores
-- del XML son los únicos: el código ya no los repite. Una sección que no existe es un error.
local constantesCache
function C.aplicar(modulo, seccion)
  if not constantesCache then constantesCache = C.tabla("constantes") end
  local ajustes = constantesCache[seccion]
  if ajustes == nil then error("constantes.xml: falta la sección <" .. seccion .. ">", 0) end
  for k, v in pairs(ajustes) do
    -- cada módulo recibe su propia copia de las tablas (el servidor modifica algunas en marcha)
    if type(v) == "table" then
      local copia = {}
      local function copiar(a, b) for kk, vv in pairs(a) do if type(vv) == "table" then b[kk] = {} copiar(vv, b[kk]) else b[kk] = vv end end end
      copiar(v, copia)
      modulo[k] = copia
    else
      modulo[k] = v
    end
  end
  return modulo
end

-- Comprobación de campos: reglas = { campo = "numero"|"texto"|"booleano"|"tabla"|"cualquiera", ... }; los
-- campos con el prefijo "?" son opcionales. Lanza un error con el id del registro y el campo.
function C.validar(archivo, tipo, id, reg, reglas)
  for campo, regla in pairs(reglas) do
    local opcional = campo:sub(1, 1) == "?"
    local nom = opcional and campo:sub(2) or campo
    local v = reg[nom]
    if v == nil then
      if not opcional then error(archivo .. ": " .. tipo .. " '" .. tostring(id) .. "': falta el campo " .. nom, 0) end
    else
      local ok = true
      if regla == "numero" then ok = type(v) == "number"
      elseif regla == "texto" then ok = type(v) == "string"
      elseif regla == "booleano" then ok = type(v) == "boolean"
      elseif regla == "tabla" then ok = type(v) == "table" end
      if not ok then
        error(archivo .. ": " .. tipo .. " '" .. tostring(id) .. "': el campo " .. nom .. " debe ser " .. regla .. " y es " .. tostring(v), 0)
      end
    end
  end
end

return C
