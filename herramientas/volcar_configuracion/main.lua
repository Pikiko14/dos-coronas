-- Vuelca a texto, de forma canónica (claves ordenadas, sin funciones), todas las tablas de datos de los
-- módulos de dominio. Sirve para comprobar que mover la configuración a XML no cambia nada:
--     ..\love\lovec.exe herramientas\volcar_configuracion  <salida.txt>
-- Compara dos volcados con cualquier diff.
package.path = "C:/Users/User/juegos/dos-coronas/?.lua;" .. package.path

local MODULOS = {
  "datos", "items", "arbol", "estados", "mall", "monturas", "mascotas", "oficios", "balance", "encanto",
  "gremios", "subastas", "grupos", "comercio", "caravanas", "programacion", "ley", "mazmorras", "admin",
}

local function clave(k) return type(k) == "number" and string.format("%020.6f", k) or tostring(k) end

local function volcar(v, sangria, salida, vistos)
  local tp = type(v)
  if tp == "number" then salida[#salida + 1] = string.format("%.14g", v) return end
  if tp == "string" then salida[#salida + 1] = string.format("%q", v) return end
  if tp == "boolean" then salida[#salida + 1] = tostring(v) return end
  if tp ~= "table" then salida[#salida + 1] = "<" .. tp .. ">" return end
  if vistos[v] then salida[#salida + 1] = "<ciclo>" return end
  vistos[v] = true
  local ks = {}
  for k, x in pairs(v) do
    if type(x) ~= "function" and k ~= "_zonas" and k ~= "_bloques" then ks[#ks + 1] = k end
  end
  table.sort(ks, function(a, b) return clave(a) < clave(b) end)
  salida[#salida + 1] = "{"
  for _, k in ipairs(ks) do
    salida[#salida + 1] = "\n" .. string.rep(" ", sangria + 2) .. clave(k) .. " = "
    volcar(v[k], sangria + 2, salida, vistos)
  end
  salida[#salida + 1] = "\n" .. string.rep(" ", sangria) .. "}"
  vistos[v] = nil
end

function love.load(arg)
  local destino = (arg and arg[1]) or (os.getenv("TEMP") .. "/volcado_config.txt")
  local partes = {}
  for _, nombre in ipairs(MODULOS) do
    local ok, mod = pcall(require, "compartido.dominio." .. nombre)
    partes[#partes + 1] = "== " .. nombre .. " " .. (ok and "" or ("(no se pudo cargar: " .. tostring(mod) .. ")")) .. "\n"
    if ok and type(mod) == "table" then
      local s = {}
      volcar(mod, 0, s, {})
      partes[#partes + 1] = table.concat(s) .. "\n"
    end
  end
  -- el mapa del mundo no se vuelca (es enorme y no es configuración)
  local f = assert(io.open(destino, "wb"))
  f:write(table.concat(partes))
  f:close()
  love.event.quit()
end
