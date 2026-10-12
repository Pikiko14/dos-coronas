local Datos = require("compartido.dominio.datos")
local Util = require("compartido.dominio.util")
local Balance = require("compartido.dominio.balance")

local A = {}

local ACCIONES = {
  deseo = true, destino = true, objetivo = true, habilidad = true, chat = true,
  equipar = true, desequipar = true, pocion = true, comprar = true, vender = true,
  interactuar = true, guerra = true, salir_guerra = true,
  casa_comprar = true, casa_entrar = true, casa_salir = true, mueble = true,
  cofre_guardar = true, cofre_sacar = true,
  mision_aceptar = true, mision_entregar = true,
  comercio_invitar = true, comercio_oro = true, comercio_item = true,
  comercio_ok = true, comercio_no = true, mover_bolsa = true, mirar = true,
  aprender = true, olvidar = true, encantar = true, mascota_adoptar = true, mascota_invocar = true,
  gremio_info = true, gremio_crear = true, gremio_invitar = true, gremio_responder = true, gremio_salir = true,
  gremio_expulsar = true, gremio_rango = true, gremio_disolver = true,
}

local function finito(n)
  return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function A.aceptar(mundo, pj, nombre, datos)
  if not ACCIONES[nombre] or not pj then return false end
  datos = datos or {}
  if nombre == "deseo" then
    local x, y = tonumber(datos.x) or 0, tonumber(datos.y) or 0
    if not finito(x) or not finito(y) then return false end
    if x * x + y * y > 1.05 then return false end
    return true, { x = x, y = y }
  end
  if nombre == "destino" then
    local x, y = tonumber(datos.x), tonumber(datos.y)
    if not finito(x) or not finito(y) then return false end
    if mundo and mundo.mapaDe then
      local mapa = mundo:mapaDe(pj)
      if mapa and (x < -2 or y < -2 or x > mapa.w + 2 or y > mapa.h + 2) then return false end
    end
    return true, { x = x, y = y }
  end
  if nombre == "habilidad" then
    local slot = tonumber(datos.slot)
    if not slot or slot < 1 or slot > 6 then return false end
    return true, { slot = math.floor(slot) }
  end
  if nombre == "gremio_crear" then
    if type(datos.nombre) ~= "string" or #datos.nombre > 40 or type(datos.etiqueta) ~= "string" or #datos.etiqueta > 8 then return false end
    return true, { nombre = datos.nombre, etiqueta = datos.etiqueta }
  end
  if nombre == "gremio_invitar" or nombre == "gremio_expulsar" or nombre == "gremio_rango" then
    local id = tonumber(datos.id)
    if not id or not finito(id) then return false end
    return true, { id = id, sube = datos.sube and true or false }
  end
  if nombre == "gremio_responder" then return true, { acepta = datos.acepta and true or false } end
  if nombre == "mascota_adoptar" then
    if type(datos.especie) ~= "string" or #datos.especie > 24 then return false end
    return true, { especie = datos.especie }
  end
  if nombre == "mascota_invocar" then
    local i = tonumber(datos.idx)
    if not i or i < 1 or i > 12 then return false end
    return true, { idx = math.floor(i) }
  end
  if nombre == "encantar" then
    if datos.donde == "equipo" then
      if type(datos.ref) ~= "string" or #datos.ref > 12 then return false end
      return true, { donde = "equipo", ref = datos.ref }
    elseif datos.donde == "bolsa" then
      local i = tonumber(datos.ref)
      if not i or i < 1 or i > Datos.BOLSA then return false end
      return true, { donde = "bolsa", ref = math.floor(i) }
    end
    return false
  end
  if nombre == "aprender" then
    if type(datos.id) ~= "string" or #datos.id > 24 then return false end
    return true, { id = datos.id }
  end
  if nombre == "chat" then
    local t = tostring(datos.texto or "")
    if #t > 120 then return false end
    return true, { texto = t }
  end
  if nombre == "objetivo" then
    local id = datos.id
    if id and mundo and mundo.entidades and mundo.entidades[id] then
      local o = mundo.entidades[id]
      if Util.dist(pj.x, pj.y, o.x, o.y) > 18 then return false end
    end
    return true, { id = id, persigue = datos.persigue and true or false }
  end
  if nombre == "mirar" then
    local o = mundo and mundo.entidades and mundo.entidades[datos.id]
    if not o or not mundo:mismoLugar(pj, o) or Util.dist(pj.x, pj.y, o.x, o.y) > 18 then return false end
    return true, { id = datos.id }
  end
  if nombre == "comercio_invitar" then
    local otro = mundo and mundo.entidades and mundo.entidades[datos.id]
    if not otro or not mundo:mismoLugar(pj, otro) then return false end
    if Util.dist(pj.x, pj.y, otro.x, otro.y) > 4 then return false end
    return true, { id = datos.id }
  end
  if nombre == "guerra" then
    if datos.modo ~= "batalla" and datos.modo ~= "estandarte" then return false end
    return true, { modo = datos.modo }
  end
  if nombre == "mover_bolsa" then
    local a, b = tonumber(datos.a), tonumber(datos.b)
    if not a or not b or a < 1 or b < 1 or a > Datos.BOLSA or b > Datos.BOLSA then return false end -- el tope real lo pone la mochila
    return true, { a = math.floor(a), b = math.floor(b) }
  end
  if nombre == "comercio_oro" then
    local oro = tonumber(datos.oro) or 0
    if not finito(oro) or oro < 0 or oro > 1000000 then return false end
    return true, { oro = math.floor(oro) }
  end
  return true, datos
end

return A
