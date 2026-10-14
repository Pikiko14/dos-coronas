-- Carga el código compartido. Primero busca una copia dentro de este proyecto
-- (compartido/, la deja construir.bat al empaquetar) y, si no hay, usa la
-- carpeta hermana ../compartido del repositorio.
do
  local base = love.filesystem.getSource():gsub("\\", "/")
  table.insert(package.loaders, function(nombre)
    if nombre:sub(1, 11) ~= "compartido." then return nil end
    local rel = nombre:gsub("%.", "/")
    for _, ruta in ipairs({ base .. "/../" .. rel .. ".lua", base .. "/../" .. rel .. "/init.lua" }) do
      local f = io.open(ruta, "rb")
      if f then
        local fuente = f:read("*a")
        f:close()
        local fn, err = loadstring(fuente, "@" .. ruta)
        if not fn then error(err) end
        return fn
      end
    end
    return "\n\tno existe " .. nombre .. " ni dentro del proyecto ni en ../compartido"
  end)
end


-- Parche de actualización: el juego descarga el código nuevo (actualizacion_<build>.zip) a la carpeta de datos y aquí se
-- monta ANTES de cargar nada de src/, de modo que sus archivos tapan a los del paquete instalado. Solo se aplica si es más
-- nuevo que el paquete, si su sha256 coincide y si el arranque anterior con él llegó a dibujar (si no, se descarta).
-- En desarrollo (love juego) no se monta, salvo con DOSCORONAS_PARCHE=1.
do
  local fs = love.filesystem
  local base = 0
  local okV, fV = pcall(fs.load, "version.lua")
  if okV and fV then
    local ok2, t = pcall(fV)
    if ok2 and type(t) == "table" then base = tonumber(t.build) or 0 end
  end
  local aplicar = fs.isFused() or os.getenv("DOSCORONAS_PARCHE") == "1"
  local info = fs.getInfo("actualizacion.txt")
  if aplicar and info then
    local datos = {}
    for k, v in (fs.read("actualizacion.txt") or ""):gmatch("(%w+)=([^\r\n]*)") do datos[k] = v end
    local n, zip = tonumber(datos.build) or 0, datos.archivo
    local function descartar()
      fs.remove("actualizacion.txt")
      fs.remove("actualizacion_intento")
      if zip and zip:match("^actualizacion_%d+%.zip$") then fs.remove(zip) end
    end
    if fs.getInfo("actualizacion_intento") then
      descartar()   -- el arranque anterior con este parche no llegó a dibujar nada
    elseif n > base and zip and zip:match("^actualizacion_%d+%.zip$") and fs.getInfo(zip) then
      local okH, hash = pcall(function()
        return love.data.encode("string", "hex", love.data.hash("sha256", fs.newFileData(zip)))
      end)
      if okH and hash == datos.sha256 then
        fs.write("actualizacion_intento", tostring(n))
        if not fs.mount(zip, "", false) then fs.remove("actualizacion_intento") end
      else
        descartar()
      end
    else
      descartar()   -- parche igual o más viejo que el paquete (se instaló uno nuevo)
    end
  end
end

require("src.principal")

-- el arranque se da por bueno cuando llega a dibujar un cuadro: se borra la marca del parche
do
  local dibujar = love.draw
  love.draw = function()
    dibujar()
    if love.filesystem.getInfo("actualizacion_intento") then love.filesystem.remove("actualizacion_intento") end
  end
end
