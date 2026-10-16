-- Actualizaciones del juego sin volver a descargarlo a mano. Al arrancar pregunta a <url>/version.txt y hace lo que toque:
--   * PARCHE (lo normal, ~0,3 MB): baja actualizacion_<build>.zip (código y arte nuevo o cambiado), lo guarda en la carpeta de
--     datos (actualizacion_<build>.zip + actualizacion.txt) y reinicia; main.lua lo monta encima del juego instalado.
--   * PAQUETE COMPLETO (cuando el parche no basta: .exe, DLL, main.lua, archivos que borrar...): si el build instalado es menor
--     que "minimo" baja completo_<build>.zip entero (~85 MB, con barra de progreso), cierra el juego, un script lo instala encima y
--     lo vuelve a abrir. Solo en Windows y con el juego instalado.
-- Todo va en un hilo (HTTP con luasocket, que viene con LÖVE) para no congelar el menú, y se comprueba el sha256 de lo bajado.
-- Estados: "inactivo" (sin servidor de actualizaciones), "buscando", "descargando", "completo", "listo", "aplicando", "al_dia", "error".
local Config = require("src.infraestructura.config")
local Log = require("compartido.infraestructura.log")

local A = {
  estado = "inactivo",
  nombre = "",
  version = { build = 0, nombre = "" },
  espera = 0,
  recibido = 0,
  total = 0,
}

local HILO = [[
require("love.filesystem")
require("love.data")
local http = require("socket.http")
local ltn12 = require("ltn12")
local url, build, nombreCanal = ...
local canal = love.thread.getChannel(nombreCanal)
http.TIMEOUT = 15

local function pedir(ruta)
  local partes = {}
  local ok, codigo = http.request({ url = url .. ruta, sink = ltn12.sink.table(partes) })
  if not ok or codigo ~= 200 then return nil, tostring(codigo) end
  return table.concat(partes)
end

-- Baja un archivo grande directamente a disco (sin tenerlo entero en memoria mientras llega), avisando del avance.
local function bajarAArchivo(ruta, destino, total)
  local f = love.filesystem.newFile(destino, "w")
  if not f then return nil, "no se pudo crear el archivo" end
  local recibido, aviso = 0, 0
  local function sumidero(trozo)
    if trozo and #trozo > 0 then
      f:write(trozo)
      recibido = recibido + #trozo
      if recibido - aviso >= math.max(65536, math.floor((total or 0) / 200)) then
        aviso = recibido
        canal:push({ estado = "progreso", recibido = recibido, total = total })
      end
    end
    return 1
  end
  local ok, codigo = http.request({ url = url .. ruta, sink = sumidero })
  f:close()
  if not ok or codigo ~= 200 then love.filesystem.remove(destino) return nil, tostring(codigo) end
  return recibido
end

local function sha256Archivo(ruta)
  return love.data.encode("string", "hex", love.data.hash("sha256", love.filesystem.newFileData(ruta)))
end

local texto, err = pedir("version.txt")
if not texto then canal:push({ estado = "error", texto = "sin respuesta (" .. tostring(err) .. ")" }) return end
local d = {}
for k, v in texto:gmatch("(%w+)=([^\r\n]*)") do d[k] = v end
local remoto = tonumber(d.build) or 0
local minimo = tonumber(d.minimo) or 0
if remoto <= build then canal:push({ estado = "al_dia" }) return end
local nombre = d.nombre or ("build " .. remoto)

if build < minimo then
  -- hace falta el paquete completo
  if not (d.completo and d.completo:match("^completo_%d+%.zip$") and d.shacompleto and #d.shacompleto == 64) then
    canal:push({ estado = "error", texto = "falta el paquete completo en el servidor" })
    return
  end
  local total = tonumber(d.tamanocompleto) or 0
  canal:push({ estado = "completo", nombre = nombre, total = total, descarga = d.completo })
  local bytes, err2 = bajarAArchivo(d.completo, d.completo, total)
  if not bytes then canal:push({ estado = "error", texto = "descarga fallida (" .. tostring(err2) .. ")" }) return end
  if sha256Archivo(d.completo) ~= d.shacompleto then
    love.filesystem.remove(d.completo)
    canal:push({ estado = "error", texto = "el paquete bajado no coincide con su sha256" })
    return
  end
  canal:push({ estado = "completo_listo", nombre = nombre, archivo = d.completo })
  return
end

if not (d.archivo and d.archivo:match("^actualizacion_%d+%.zip$") and d.sha256 and #d.sha256 == 64) then
  canal:push({ estado = "error", texto = "manifiesto no válido" })
  return
end
-- tamaño del parche: el del manifiesto o, si no lo trae, el que dice el servidor (Content-Length de un HEAD)
local totalParche = tonumber(d.tamano) or 0
if totalParche == 0 then
  local _, _, cab = http.request({ url = url .. d.archivo, method = "HEAD" })
  totalParche = tonumber(cab and (cab["content-length"] or cab["Content-Length"])) or 0
end
canal:push({ estado = "descargando", nombre = nombre, total = totalParche, descarga = d.archivo })
local bytes3, err3 = bajarAArchivo(d.archivo, d.archivo, totalParche)
if not bytes3 then canal:push({ estado = "error", texto = "descarga fallida (" .. tostring(err3) .. ")" }) return end
canal:push({ estado = "progreso", recibido = bytes3, total = totalParche > 0 and totalParche or bytes3 })
if sha256Archivo(d.archivo) ~= d.sha256 then
  love.filesystem.remove(d.archivo)
  canal:push({ estado = "error", texto = "la descarga no coincide con su sha256" })
  return
end
love.filesystem.write("actualizacion.txt", "build=" .. remoto .. "\narchivo=" .. d.archivo .. "\nsha256=" .. d.sha256 .. "\nnombre=" .. nombre .. "\n")
canal:push({ estado = "listo", nombre = nombre })
]]

-- Script que instala el paquete completo: espera a que el juego se cierre, descomprime el zip encima de la carpeta del juego,
-- borra el zip y los parches viejos, y vuelve a abrir el juego. Si algo falla deja el motivo en actualizar_log.txt.
local SCRIPT = [[
param([string]$Zip, [string]$Destino, [string]$Exe, [string]$Datos)
$ErrorActionPreference = "Stop"
$log = Join-Path $Datos "actualizar_log.txt"
try {
  for ($i = 0; $i -lt 120; $i++) {
    try { $f = [System.IO.File]::Open($Exe, "Open", "ReadWrite", "None"); $f.Close(); break } catch { Start-Sleep -Milliseconds 500 }
  }
  $tmp = Join-Path $env:TEMP ("doscoronas_" + [guid]::NewGuid().ToString("N"))
  Expand-Archive -LiteralPath $Zip -DestinationPath $tmp -Force
  if (-not (Test-Path (Join-Path $tmp "DosCoronas.exe"))) { throw "El paquete no trae DosCoronas.exe" }
  & robocopy $tmp $Destino /E /R:5 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy falló ($LASTEXITCODE)" }
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item $Zip -Force -ErrorAction SilentlyContinue
  Get-ChildItem $Datos -Filter "actualizacion*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
  if (Test-Path $log) { Remove-Item $log -Force }
} catch {
  ("{0} {1}" -f (Get-Date -Format s), $_.Exception.Message) | Out-File $log -Encoding utf8
}
Start-Process -FilePath $Exe
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

-- Instala el paquete completo ya descargado: lanza el script oculto y cierra el juego (el script lo vuelve a abrir).
local function aplicarCompleto()
  local fs = love.filesystem
  local okFFI, ffi = pcall(require, "ffi")
  if not okFFI or not fs.isFused() or package.config:sub(1, 1) ~= "\\" then
    A.estado, A.error = "error", "el paquete completo solo se instala en el juego de Windows (descárgalo de la web)"
    return
  end
  local datos = fs.getSaveDirectory():gsub("/", "\\")
  local exe = fs.getSource():gsub("/", "\\")
  local destino = fs.getSourceBaseDirectory():gsub("/", "\\")
  local zip = datos .. "\\" .. A.archivoCompleto
  local script = datos .. "\\actualizar_completo.ps1"
  if not fs.write("actualizar_completo.ps1", "\239\187\191" .. SCRIPT) then
    A.estado, A.error = "error", "no se pudo escribir el instalador"
    return
  end
  ffi.cdef([[
    void* ShellExecuteA(void* hwnd, const char* op, const char* archivo, const char* args, const char* dir, int mostrar);
  ]])
  local args = string.format('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%s" -Zip "%s" -Destino "%s" -Exe "%s" -Datos "%s"',
    script, zip, destino, exe, datos)
  local r = ffi.load("shell32").ShellExecuteA(nil, "open", "powershell.exe", args, nil, 0)
  if tonumber(ffi.cast("intptr_t", r)) <= 32 then
    A.estado, A.error = "error", "no se pudo lanzar el instalador"
    return
  end
  A.estado = "aplicando"
  Log.info("actualización: instalando el paquete completo y cerrando")
  love.event.quit()
end

function A.actualizar(dt)
  if A.canal then
    local canal = love.thread.getChannel(A.canal)
    local m = canal:pop()
    while m do
      if m.estado == "progreso" then
        A.recibido, A.total = m.recibido, m.total
        local ahora = love.timer.getTime()
        -- velocidad de bajada (suavizada)
        if A.muestraT and ahora - A.muestraT >= 0.4 then
          local v = (m.recibido - (A.muestraB or 0)) / (ahora - A.muestraT)
          A.velocidad = A.velocidad and (A.velocidad * 0.6 + v * 0.4) or v
          A.muestraT, A.muestraB = ahora, m.recibido
        elseif not A.muestraT then
          A.muestraT, A.muestraB = ahora, m.recibido
        end
      else
        A.estado = m.estado
        if m.nombre then A.nombre = m.nombre end
        if m.descarga then A.descarga, A.desde, A.recibido = m.descarga, love.timer.getTime(), 0 end
        if m.total then A.total = m.total end
        if m.archivo then A.archivoCompleto = m.archivo end
        if m.estado == "error" then
          A.error = m.texto
          Log.error("actualización: " .. tostring(m.texto))
        else
          Log.info("actualización: " .. m.estado .. (m.nombre and (" " .. m.nombre) or ""))
        end
      end
      m = canal:pop()
    end
    if A.hilo and A.hilo:getError() then
      A.estado, A.error = "error", A.hilo:getError()
      Log.error("actualización: " .. tostring(A.error))
      A.hilo = nil
    end
  end
  -- (prueba) DC_CAPTURA_ACT=<segundos>: guarda una captura de la pantalla de descarga en la carpeta de datos
  local cap = os.getenv("DC_CAPTURA_ACT")
  if cap and A.bloquea() and not A.capturada then
    A.tCaptura = (A.tCaptura or 0) + (dt or 0)
    if A.tCaptura >= (tonumber(cap) or 3) then
      A.capturada = true
      love.graphics.captureScreenshot("descarga_actualizacion.png")
    end
  end
  if A.estado == "completo_listo" and not A.aplicado then
    A.aplicado = true
    if A.modoPrueba then return end
    aplicarCompleto()
  end
  if A.estado == "listo" then
    A.espera = A.espera + (dt or 0)
    if A.espera >= 1.5 and not A.reiniciando then
      A.reiniciando = true
      love.event.quit("restart")
    end
  end
end

-- Mientras baja o aplica una actualización el menú no responde.
function A.bloquea()
  local e = A.estado
  return e == "descargando" or e == "listo" or e == "completo" or e == "completo_listo" or e == "aplicando"
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
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, w, h)
    local f = love.graphics.getFont()
    local e = A.estado
    local titulo = (e == "listo") and "Actualización lista"
      or (e == "completo" and "Descargando la versión nueva")
      or ((e == "completo_listo" or e == "aplicando") and "Instalando la versión nueva")
      or "Descargando actualización"
    love.graphics.setColor(1, 0.9, 0.55, 1)
    love.graphics.printf(titulo .. (A.nombre ~= "" and (": " .. A.nombre) or ""), 0, h / 2 - f:getHeight() * 2.2, w, "center")
    love.graphics.setColor(0.85, 0.88, 0.95, 1)
    local sub = (e == "listo") and "Reiniciando el juego..."
      or ((e == "completo_listo" or e == "aplicando") and "El juego se cerrará y volverá a abrirse solo.")
      or "Un momento, no cierres el juego."
    love.graphics.printf(sub, 0, h / 2 - f:getHeight() * 0.8, w, "center")
    if e == "completo" or e == "descargando" then
      local bw = math.min(420, w - 80)
      local bx, by = (w - bw) / 2, h / 2 + f:getHeight() * 1.0
      love.graphics.setColor(0.12, 0.15, 0.28, 1)
      love.graphics.rectangle("fill", bx, by, bw, 16, 6, 6)
      love.graphics.setColor(0.95, 0.75, 0.2, 1)
      local texto
      if A.total > 0 then
        local frac = math.max(0, math.min(1, A.recibido / A.total))
        love.graphics.rectangle("fill", bx, by, bw * frac, 16, 6, 6)
        texto = string.format("%d%%  (%.1f de %.1f MB)", math.floor(frac * 100), A.recibido / 1048576, A.total / 1048576)
        if A.velocidad and A.velocidad > 1024 then
          texto = texto .. string.format("   %.1f MB/s", A.velocidad / 1048576)
          local resta = (A.total - A.recibido) / A.velocidad
          if resta >= 1 and resta < 3600 then texto = texto .. string.format("   quedan %d s", math.ceil(resta)) end
        end
      else
        -- tamaño desconocido: franja que va y viene, y lo que lleva bajado
        local x = (love.timer.getTime() * 0.8 % 1)
        local ancho = bw * 0.25
        love.graphics.rectangle("fill", bx + (bw - ancho) * (0.5 - 0.5 * math.cos(x * math.pi * 2)), by, ancho, 16, 6, 6)
        texto = string.format("%.1f MB descargados", A.recibido / 1048576)
      end
      love.graphics.setColor(0.85, 0.88, 0.95, 1)
      love.graphics.printf(texto, 0, by + 22, w, "center")
      if A.descarga then
        love.graphics.setColor(0.6, 0.65, 0.78, 0.9)
        love.graphics.printf("Archivo: " .. A.descarga, 0, by + 44, w, "center")
      end
    end
  elseif A.estado == "error" and A.error and (A.version.build or 0) > 0 then
    love.graphics.setColor(0.95, 0.6, 0.5, 0.85)
    love.graphics.printf("No se pudo actualizar: " .. tostring(A.error), 12, h - 28, w - 24, "right")
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return A
