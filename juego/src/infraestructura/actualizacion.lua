-- Actualizaciones del juego sin volver a descargarlo: al arrancar pregunta al servidor si hay un parche más nuevo
-- (<url>/version.txt: build, nombre, archivo, sha256) y, si lo hay, lo baja a la carpeta de datos del juego
-- (actualizacion_<build>.zip + actualizacion.txt) y reinicia. main.lua lo monta en el siguiente arranque.
-- La descarga va en un hilo (HTTP con luasocket, que viene con LÖVE) para no congelar el menú.
-- Estados: "inactivo" (sin servidor de actualizaciones), "buscando", "descargando", "listo", "al_dia", "error".
local Config = require("src.infraestructura.config")
local Log = require("compartido.infraestructura.log")

local A = {
  estado = "inactivo",
  nombre = "",
  version = { build = 0, nombre = "" },
  espera = 0,
}

local HILO = [[
require("love.filesystem")
require("love.data")
local http = require("socket.http")
local ltn12 = require("ltn12")
local url, build, nombreCanal = ...
local canal = love.thread.getChannel(nombreCanal)
http.TIMEOUT = 8

local function pedir(ruta)
  local partes = {}
  local ok, codigo = http.request({ url = url .. ruta, sink = ltn12.sink.table(partes) })
  if not ok or codigo ~= 200 then return nil, tostring(codigo) end
  return table.concat(partes)
end

local texto, err = pedir("version.txt")
if not texto then canal:push({ estado = "error", texto = "sin respuesta (" .. tostring(err) .. ")" }) return end
local d = {}
for k, v in texto:gmatch("(%w+)=([^\r\n]*)") do d[k] = v end
local remoto = tonumber(d.build) or 0
if remoto <= build then canal:push({ estado = "al_dia" }) return end
if not (d.archivo and d.archivo:match("^actualizacion_%d+%.zip$") and d.sha256 and #d.sha256 == 64) then
  canal:push({ estado = "error", texto = "manifiesto no válido" })
  return
end
canal:push({ estado = "descargando", nombre = d.nombre or ("build " .. remoto) })
local zip, err2 = pedir(d.archivo)
if not zip then canal:push({ estado = "error", texto = "descarga fallida (" .. tostring(err2) .. ")" }) return end
local hash = love.data.encode("string", "hex", love.data.hash("sha256", zip))
if hash ~= d.sha256 then canal:push({ estado = "error", texto = "la descarga no coincide con su sha256" }) return end
if not love.filesystem.write(d.archivo, zip) then canal:push({ estado = "error", texto = "no se pudo guardar" }) return end
love.filesystem.write("actualizacion.txt", "build=" .. remoto .. "\narchivo=" .. d.archivo .. "\nsha256=" .. d.sha256 .. "\nnombre=" .. (d.nombre or "") .. "\n")
canal:push({ estado = "listo", nombre = d.nombre or ("build " .. remoto) })
]]

local function versionActual()
  local ok, f = pcall(love.filesystem.load, "version.lua")
  if ok and f then
    local ok2, t = pcall(f)
    if ok2 and type(t) == "table" then return t end
  end
  return { build = 0, nombre = "" }
end

function A.url()
  local u = os.getenv and os.getenv("DOSCORONAS_ACTUALIZACIONES")
  if not u or u == "" then u = Config.actualizaciones end
  if not u or u == "" then return nil end
  if u:sub(-1) ~= "/" then u = u .. "/" end
  return u
end

-- Lanza la comprobación (una sola vez por arranque). Sin dirección de actualizaciones no hace nada.
function A.iniciar()
  A.version = versionActual()
  local url = A.url()
  if not url or A.hilo then return end
  A.canal = "actualizacion_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000000))
  local ok, err = pcall(function()
    A.hilo = love.thread.newThread(HILO)
    A.hilo:start(url, A.version.build or 0, A.canal)
  end)
  if not ok then
    Log.error("actualización: no se pudo lanzar el hilo: " .. tostring(err))
    A.estado = "error"
    return
  end
  A.estado = "buscando"
  Log.info("actualización: comprobando " .. url .. " (build " .. tostring(A.version.build) .. ")")
end

function A.actualizar(dt)
  if A.canal then
    local canal = love.thread.getChannel(A.canal)
    local m = canal:pop()
    while m do
      A.estado = m.estado
      if m.nombre then A.nombre = m.nombre end
      if m.estado == "error" then
        A.error = m.texto
        Log.error("actualización: " .. tostring(m.texto))
      else
        Log.info("actualización: " .. m.estado .. (m.nombre and (" " .. m.nombre) or ""))
      end
      m = canal:pop()
    end
    if A.hilo and A.hilo:getError() then
      A.estado, A.error = "error", A.hilo:getError()
      Log.error("actualización: " .. tostring(A.error))
      A.hilo = nil
    end
  end
  if A.estado == "listo" then
    A.espera = A.espera + (dt or 0)
    if A.espera >= 1.5 and not A.reiniciando then
      A.reiniciando = true
      love.event.quit("restart")
    end
  end
end

-- Mientras baja o aplica un parche el menú no responde (son unos segundos).
function A.bloquea()
  return A.estado == "descargando" or A.estado == "listo"
end

function A.dibujar(w, h)
  if (A.version.nombre or "") ~= "" then
    love.graphics.setColor(0.6, 0.65, 0.75, 0.7)
    love.graphics.print(A.version.nombre .. " (" .. tostring(A.version.build) .. ")", 8, h - 24)
  end
  if A.estado == "buscando" then
    love.graphics.setColor(0.7, 0.75, 0.85, 0.8)
    love.graphics.printf("Buscando actualizaciones...", 0, h - 28, w - 12, "right")
  elseif A.bloquea() then
    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, 0, w, h)
    local f = love.graphics.getFont()
    love.graphics.setColor(1, 0.9, 0.55, 1)
    local titulo = A.estado == "listo" and "Actualización lista" or "Descargando actualización"
    love.graphics.printf(titulo .. (A.nombre ~= "" and (": " .. A.nombre) or ""), 0, h / 2 - f:getHeight() * 1.5, w, "center")
    love.graphics.setColor(0.85, 0.88, 0.95, 1)
    love.graphics.printf(A.estado == "listo" and "Reiniciando el juego..." or "Un momento, no cierres el juego.", 0, h / 2 + f:getHeight() * 0.2, w, "center")
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return A
