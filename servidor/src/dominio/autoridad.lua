local Datos = require("compartido.dominio.datos")
local Util = require("compartido.dominio.util")
local Balance = require("compartido.dominio.balance")
local Arbol = require("compartido.dominio.arbol")

local A = {}

local ACCIONES = {
  deseo = true, destino = true, objetivo = true, habilidad = true, chat = true,
  equipar = true, desequipar = true, pocion = true, autopocion = true, comprar = true, vender = true,
  interactuar = true, guerra = true, salir_guerra = true, viaje = true,
  casa_comprar = true, casa_entrar = true, casa_salir = true, mueble = true, mueble_mover = true, mueble_rotar = true,
  cofre_guardar = true, cofre_sacar = true,
  mision_aceptar = true, mision_entregar = true, mision_abandonar = true,
  comercio_invitar = true, comercio_oro = true, comercio_item = true, comercio_responder = true, comercio_quitar = true,
  comercio_ok = true, comercio_no = true, mover_bolsa = true, mirar = true,
  aprender = true, olvidar = true, encantar = true, mascota_adoptar = true, mascota_invocar = true,
  gremio_info = true, gremio_crear = true, gremio_invitar = true, gremio_responder = true, gremio_salir = true,
  gremio_expulsar = true, gremio_rango = true, gremio_disolver = true,
  mall_comprar = true, mall_addon_comprar = true, mall_addon = true, mall_montura_comprar = true, mall_mascota_comprar = true, oficio_elegir = true, oficio_alternar = true, oficio_info = true, mercancia_info = true, mercancia_comprar = true, mercancia_vender = true,
  diaria_reclamar = true, robar = true, perista_vender = true, montura_comprar = true, montura_alternar = true, montura_info = true, escoltar = true,
  grupo_invitar = true, grupo_responder = true, grupo_salir = true, grupo_expulsar = true, grupo_lider = true, grupo_disolver = true,
  subasta_info = true, subasta_publicar = true, subasta_pujar = true, subasta_comprar = true, subasta_cancelar = true, subasta_cobrar = true,
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
    if not slot or slot < 1 or slot > 10 then return false end
    slot = math.floor(slot)
    local limpio = { slot = slot }
    -- poderes de área (meteoro...): se puede apuntar a un punto, siempre dentro de su alcance
    local x, y = tonumber(datos.x), tonumber(datos.y)
    if x and y and finito(x) and finito(y) and pj and pj.x then
      local idh = Datos.barra[pj.clase] and Datos.barra[pj.clase][slot]
      local h = idh and Arbol.efectiva(idh, math.max(1, Arbol.rango(pj, idh) or 1))
      if h and h.tipo == "punto" then
        local dx, dy = x - pj.x, y - pj.y
        local d = math.sqrt(dx * dx + dy * dy)
        local max = (h.rango or 6) + 0.3
        if d > max then x, y = pj.x + dx / d * max, pj.y + dy / d * max end
        limpio.x, limpio.y = x, y
      end
    end
    return true, limpio
  end
  if nombre == "gremio_crear" then
    if type(datos.nombre) ~= "string" or #datos.nombre > 40 or type(datos.etiqueta) ~= "string" or #datos.etiqueta > 8 then return false end
    return true, { nombre = datos.nombre, etiqueta = datos.etiqueta }
  end
  -- los jugadores del mundo se identifican con ids de texto ("e12"); los miembros de un gremio, con su
  -- número en la base de datos
  local function idEntidad(v)
    if type(v) ~= "string" or #v > 16 or not v:match("^e%d+$") then return nil end
    return v
  end
  if nombre == "viaje" then
    if type(datos.destino) ~= "string" or #datos.destino > 24 or not datos.destino:match("^[%w_]+$") then return false end
    return true, { destino = datos.destino }
  end
  if nombre == "gremio_invitar" then
    local id = idEntidad(datos.id)
    if not id then return false end
    return true, { id = id }
  end
  if nombre == "gremio_expulsar" or nombre == "gremio_rango" then
    local id = tonumber(datos.id)
    if not id or not finito(id) then return false end
    return true, { id = id, sube = datos.sube and true or false }
  end
  if nombre == "gremio_responder" or nombre == "grupo_responder" then return true, { acepta = datos.acepta and true or false } end
  if nombre == "grupo_invitar" or nombre == "grupo_expulsar" or nombre == "grupo_lider" then
    local id = idEntidad(datos.id)
    if not id then return false end
    return true, { id = id }
  end
  if nombre:sub(1, 8) == "subasta_" then
    local function num(v, max)
      v = tonumber(v)
      if not v or not finito(v) or v < 0 or v > (max or 1e9) then return nil end
      return math.floor(v)
    end
    local limpio = { cat = type(datos.cat) == "string" and #datos.cat <= 12 and datos.cat or "todo", pagina = num(datos.pagina, 1000) or 1 }
    if nombre == "subasta_publicar" then
      limpio.idx, limpio.cant, limpio.salida = num(datos.idx, 64), num(datos.cant, 9999), num(datos.salida, 1e8)
      limpio.compra, limpio.horas = num(datos.compra, 1e8) or 0, num(datos.horas, 48)
      if not (limpio.idx and limpio.cant and limpio.salida and limpio.horas) then return false end
    elseif nombre == "subasta_pujar" then
      limpio.id, limpio.oferta = num(datos.id, 1e12), num(datos.oferta, 1e9)
      if not (limpio.id and limpio.oferta) then return false end
    elseif nombre == "subasta_comprar" or nombre == "subasta_cancelar" then
      limpio.id = num(datos.id, 1e12)
      if not limpio.id then return false end
    end
    return true, limpio
  end
  if nombre == "mall_comprar" or nombre == "mall_addon_comprar" or nombre == "mall_addon" or nombre == "mall_montura_comprar" or nombre == "mall_mascota_comprar" then
    if type(datos.id) ~= "string" or #datos.id > 24 then return false end
    return true, { id = datos.id }
  end
  if nombre == "oficio_elegir" then
    if type(datos.job) ~= "string" or #datos.job > 12 then return false end
    return true, { job = datos.job }
  end
  if nombre == "mercancia_comprar" or nombre == "mercancia_vender" then
    local cant = tonumber(datos.cant)
    if type(datos.bien) ~= "string" or #datos.bien > 16 or not cant or not finito(cant) or cant < 1 or cant > 200 then return false end
    return true, { bien = datos.bien, cant = math.floor(cant) }
  end
  if nombre == "montura_comprar" or nombre == "montura_alternar" then
    if datos.especie ~= nil and (type(datos.especie) ~= "string" or #datos.especie > 16) then return false end
    return true, { especie = datos.especie }
  end
  if nombre == "robar" or nombre == "escoltar" then
    local id = tonumber(datos.id)
    if not id or not finito(id) then return false end
    return true, { id = id }
  end
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
  if nombre == "autopocion" then
    if datos.cual ~= nil and datos.cual ~= "vida" and datos.cual ~= "mana" then return false end
    local umbral = tonumber(datos.umbral)
    if umbral ~= nil then
      if not finito(umbral) then return false end
      local pasos = math.floor(umbral * 10 + 0.5)
      if pasos < 2 or pasos > 9 then return false end
      umbral = pasos / 10
    end
    return true, { cual = datos.cual == "mana" and "mana" or "vida", on = datos.on and true or false, umbral = umbral }
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
    if datos.modo ~= "batalla" and datos.modo ~= "estandarte" and datos.modo ~= "moba" then return false end
    -- solo se ingresa hablando con el Heraldo de una ciudad (o en el portal de la Cicatriz)
    local m = mundo and mundo.mapas and mundo.mapas.mundo
    local cerca = mundo and mundo.npcCerca and mundo:npcCerca(pj, "heraldo")
    if not cerca and m and pj.modo == "mundo" and m.portal then
      local dx, dy = pj.x - m.portal.x, pj.y - m.portal.y
      cerca = dx * dx + dy * dy < 2.5 * 2.5
    end
    if not cerca then
      mundo:mensaje("sistema", "", "Para ingresar a un evento habla con el Heraldo de una ciudad.", pj)
      return false
    end
    return true, { modo = datos.modo }
  end
  if nombre == "mueble_mover" then
    if type(datos.tipo) ~= "string" or #datos.tipo > 24 or not datos.tipo:match("^[%w_]+$") then return false end
    local x, y = tonumber(datos.x), tonumber(datos.y)
    if not finito(x) or not finito(y) then return false end
    return true, { tipo = datos.tipo, x = x, y = y }
  end
  if nombre == "mueble_rotar" then
    if type(datos.tipo) ~= "string" or #datos.tipo > 24 or not datos.tipo:match("^[%w_]+$") then return false end
    return true, { tipo = datos.tipo }
  end
  if nombre == "mover_bolsa" then
    local a, b = tonumber(datos.a), tonumber(datos.b)
    if not a or not b or a < 1 or b < 1 or a > Datos.BOLSA or b > Datos.BOLSA then return false end -- el tope real lo pone la mochila
    return true, { a = math.floor(a), b = math.floor(b) }
  end
  if nombre == "comercio_oro" then
    local oro = tonumber(datos.oro)
    if not oro or not finito(oro) or oro < 0 or oro > 1e9 then return false end
    return true, { oro = math.floor(oro) }
  end
  if nombre == "comercio_item" or nombre == "comercio_quitar" then
    local i = tonumber(datos.i)
    if not i or not finito(i) or i < 1 or i > 200 then return false end
    return true, { i = math.floor(i) }
  end
  if nombre == "comercio_responder" then return true, { acepta = datos.acepta == true } end
  return true, datos
end

return A
