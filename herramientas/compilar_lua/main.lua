-- Uso: love herramientas/compilar_lua <lista.txt> <resultado.txt>
-- lista.txt: una línea por archivo, "ruta_real<TAB>nombre_en_el_paquete". Cada archivo se sustituye por su bytecode (con números de línea, para que los
-- errores sigan diciendo archivo:línea). resultado.txt dice "OK n" o el primer error.
function love.load(arg)
  local lista, resultado = arg[1], arg[2]
  local n, fallo = 0, nil
  for linea in io.lines(lista) do
    local ruta, nombre = linea:match("^(.-)\t(.+)$")
    if ruta then
      local f = assert(io.open(ruta, "rb"))
      local fuente = f:read("*a")
      f:close()
      fuente = fuente:gsub("^\239\187\191", "")                  -- (BOM)
      local fn, err = loadstring(fuente, "@" .. nombre)
      if not fn then fallo = nombre .. ": " .. tostring(err) break end
      local o = assert(io.open(ruta, "wb"))
      o:write(string.dump(fn, false))
      o:close()
      n = n + 1
    end
  end
  local r = assert(io.open(resultado, "wb"))
  r:write(fallo and ("ERROR " .. fallo) or ("OK " .. n))
  r:close()
  os.exit(fallo and 1 or 0)
end
