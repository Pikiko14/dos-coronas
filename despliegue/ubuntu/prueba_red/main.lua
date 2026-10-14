-- Prueba de la capa de red (compartido/infraestructura/red.lua + sockets.lua) en el sistema donde se ejecute:
-- levanta un servidor en un puerto local, conecta un cliente, se mandan mensajes en los dos sentidos, comprueba
-- que se detecta el cierre y que un puerto ocupado se rechaza. Sirve para validar Linux sin el resto del juego.
--     love despliegue/ubuntu/prueba_red            (desde la raíz del repositorio)
-- Termina con código 0 e imprime "OK" si todo va bien, o con 1 e imprime los fallos.
local RAIZ = love.filesystem.getSource():gsub("\\", "/")
-- carpeta del repositorio: dos niveles por encima de despliegue/ubuntu/prueba_red
local repo = RAIZ:gsub("/despliegue/ubuntu/prueba_red/?$", "")
package.path = repo .. "/?.lua;" .. package.path

local Red = require("compartido.infraestructura.red")
local errores = {}
local function fallar(msg) errores[#errores + 1] = msg end

local PUERTO = 39555 + math.random(0, 300)
local srv, cli, estado = nil, nil, "inicio"
local t0 = love.timer.getTime()
local recibidoServidor, recibidoCliente, cerrado = false, false, false
local idCliente
local mitad = 0

function love.load()
  if not Red.disponible() then fallar("Red.disponible() es falso en este sistema") estado = "fin" return end
  local e
  srv, e = Red.escuchar(PUERTO)
  if not srv then fallar("no se pudo escuchar: " .. tostring(e)) estado = "fin" return end
  -- un segundo servidor en el mismo puerto debe rechazarse
  local otro, motivo = Red.escuchar(PUERTO)
  if otro then fallar("se pudo escuchar dos veces en el mismo puerto") otro:cerrar() end
  cli, e = Red.conectar("127.0.0.1", PUERTO)
  if not cli then fallar("no se pudo conectar: " .. tostring(e)) estado = "fin" return end
  cli:enviar({ t = "hola", n = 1, texto = "ñandú ✓" })
  estado = "ping"
end

function love.update()
  if estado == "fin" then return end
  local ev = srv:actualizar()
  for _, e in ipairs(ev) do
    if e.tipo == "conecta" then idCliente = e.id end
    if e.tipo == "msg" and e.msg.t == "hola" then
      recibidoServidor = e.msg.texto == "ñandú ✓" and e.msg.n == 1
      -- respuesta grande para probar la cola y el envío por trozos
      local grande = string.rep("x", 200000)
      srv:enviar(e.id, { t = "eco", datos = grande })
    end
    if e.tipo == "cierra" then cerrado = true end
  end
  local lineas, razon = cli:actualizar()
  if not lineas then
    if estado ~= "cerrando" then fallar("el cliente perdió la conexión: " .. tostring(razon)) estado = "fin" end
  else
    for _, m in ipairs(lineas) do
      if m.t == "eco" and #m.datos == 200000 then recibidoCliente = true end
    end
  end
  if estado == "ping" and recibidoServidor and recibidoCliente then
    estado = "cerrando"
    cli:cerrar()
    mitad = love.timer.getTime()
  end
  if estado == "cerrando" and cerrado then estado = "fin" end
  if love.timer.getTime() - t0 > 15 or (estado == "cerrando" and love.timer.getTime() - mitad > 5) then
    if not recibidoServidor then fallar("el servidor no recibió el mensaje del cliente") end
    if not recibidoCliente then fallar("el cliente no recibió la respuesta de 200 KB") end
    if estado == "cerrando" and not cerrado then fallar("el servidor no detectó el cierre del cliente") end
    estado = "fin"
  end
end

function love.draw() end

function love.run()
  if love.load then love.load() end
  -- LÖVE 11: love.run devuelve la función que se llama en cada vuelta; al devolver un valor, termina con él
  return function()
    love.event.pump()
    for name in love.event.poll() do if name == "quit" then estado = "fin" end end
    love.update()
    love.timer.sleep(0.005)
    if estado ~= "fin" then return nil end
    if srv then srv:cerrar() end
    if #errores == 0 then
      print("OK  (" .. love.system.getOS() .. ", puerto " .. PUERTO .. ")")
      return 0
    end
    for _, e in ipairs(errores) do print("FALLO: " .. e) end
    return 1
  end
end
