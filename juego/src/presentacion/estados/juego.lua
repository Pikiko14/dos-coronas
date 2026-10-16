local Dibujo = require("src.presentacion.render.dibujo")
local Interfaz = require("src.presentacion.interfaz")
local Sonido = require("src.presentacion.sonido")
local Entrada = require("src.presentacion.entrada")
local Red = require("compartido.infraestructura.red")
local Datos = require("compartido.dominio.datos")
local Config = require("src.infraestructura.config")
local Ajustes = require("src.presentacion.ajustes")
local Log = require("compartido.infraestructura.log")
local Eco = require("src.presentacion.eco")

local Juego = {}

function Juego.soltar(app)
  if app.cliente then app.cliente:cerrar() end
  app.cliente = nil
  app.mundo = nil
  app.jugador = nil
  app.miId = nil
  app.rol = "local"
  app.espera = nil
  app.origen = nil
end

local function cortar(app, texto)
  local espera, origen = app.espera, app.origen
  local conToken = app.sesion and app.sesion.token
  Juego.soltar(app)
  if espera == "personajes" or not conToken then
    app.estado = "cuenta"
    if app.cuenta then app.cuenta.error = texto end
    return
  end
  if origen == "crear" then
    app.estado = "crear"
    if app.creacion then app.creacion.error = texto end
    return
  end
  app.estado = "personajes"
  if app.sesion then app.sesion.error = texto end
end

function Juego.abrir(app, ip)
  ip = (type(ip) == "string" and ip ~= "") and ip or Config.red.host
  if app.cliente and app.ipUnirse == ip then return true end
  if app.cliente then app.cliente:cerrar() end
  app.ipUnirse = ip
  app.cliente = Red.conectar(ip, Config.red.puerto)
  app.mundo = nil
  app.jugador = nil
  app.miId = nil
  if not app.cliente then
    app.rol = "local"
    return false
  end
  app.rol = "cliente"
  return true
end

-- El servidor manda el estado cada 0.1 s; entre foto y foto cada criatura
-- se desliza de su sitio anterior al nuevo para que el paso se vea continuo.
-- Pone una entidad en marcha hacia la posición que dice el servidor (e.sx, e.sy, o e.x/e.y en la foto completa). a: dónde se veía antes
-- ({ x, y, hasta }, nil si es nueva).
local function deslizar(app, id, e, a, ahora)
  local sx, sy = e.sx or e.x, e.sy or e.y
  e._movHasta = a and a.hasta or e._movHasta or 0
  local pr = app._pred
  if id == app.miId and sx then
    -- velocidad real del propio personaje medida en las fotos (la usa la predicción): solo si se movió en dos fotos seguidas
    local s0 = app._srv
    local dtF = s0 and (ahora - s0.t) or 0
    if s0 and dtF > 0.03 and dtF < 0.4 then
      local v = math.sqrt((sx - s0.x) ^ 2 + (sy - s0.y) ^ 2) / dtF
      if v > 1.5 and v < 30 and s0.v then app._velProp = (app._velProp or v) * 0.75 + v * 0.25
      elseif v < 0.3 then app._velProp = nil end
      s0 = { x = sx, y = sy, t = ahora, v = v > 1.5 }
    else
      s0 = { x = sx, y = sy, t = ahora }
    end
    app._srv = s0
  end
  if id == app.miId and pr and pr.activo and a then
    -- el propio personaje se mueve por predicción: la foto del servidor solo sirve para corregir
    e.x, e.y, e._mx = a.x, a.y, nil
    e._movHasta = ahora + 0.22
  elseif a and sx then
    local ddx, ddy = a.x - sx, a.y - sy
    local d2 = ddx * ddx + ddy * ddy
    if d2 < 9 then
      e._ox, e._oy, e._mx, e._my, e._t = a.x, a.y, sx, sy, 0
      e.x, e.y = a.x, a.y
      -- se mueve mientras el servidor diga que anda o la posición cambie
      if e.mov or d2 > 0.0004 then e._movHasta = ahora + 0.22 end
    else
      e.x, e.y, e._mx = sx, sy, nil      -- salto grande (teletransporte): sin deslizar
    end
  elseif sx then
    e.x, e.y = sx, sy
  end
end

local function mezclar(app, snap)
  local ahora = love.timer.getTime()
  -- tiempo real entre fotos (suavizado): es lo que dura el deslizamiento
  if app._ultimaFoto then
    local dtFoto = math.max(0.06, math.min(0.25, ahora - app._ultimaFoto))
    app._intervalo = (app._intervalo or dtFoto) * 0.8 + dtFoto * 0.2
  end
  app._ultimaFoto = ahora
  local ents = app.mundo.entidades
  if snap.delta then
    -- foto diferencial: solo las entidades que traen posición nueva necesitan ponerse en marcha
    local antes = {}
    for _, e in ipairs(snap.nuevos or {}) do
      local v = ents[e.id]
      if v and v.x then antes[e.id] = { x = v.x, y = v.y, hasta = v._movHasta } end
    end
    if snap.reset then
      for id, v in pairs(ents) do if v.x and not antes[id] then antes[id] = { x = v.x, y = v.y, hasta = v._movHasta } end end
    end
    app.mundo:aplicarFoto(snap, app.miId)
    ents = app.mundo.entidades
    for _, e in ipairs(snap.nuevos or {}) do
      local v = ents[e.id]
      if v then deslizar(app, e.id, v, antes[e.id], ahora) end
    end
    for _, m in ipairs(snap.mods or {}) do
      if m.x ~= nil or m.y ~= nil then
        local v = ents[m.id]
        if v then deslizar(app, m.id, v, v.x and { x = v.x, y = v.y, hasta = v._movHasta } or nil, ahora) end
      end
    end
  else
    local antes = {}
    for id, e in pairs(ents) do
      antes[id] = e.x and { x = e.x, y = e.y, hasta = e._movHasta }
    end
    app.mundo:aplicarFoto(snap, app.miId)
    for id, e in pairs(app.mundo.entidades) do
      e._movHasta = nil
      deslizar(app, id, e, antes[id], ahora)
    end
  end
  app.jugador = app.mundo.entidades[app.miId]
end

Juego._mezclar = mezclar      -- (para las pruebas)

local function enviarDeseo(app, dt)
  if not app.cliente or not app.jugador then return end
  local x, y = Entrada.deseo()
  app._acumDeseo = (app._acumDeseo or 0) + dt
  local cambio = app._ux ~= x or app._uy ~= y
  if not cambio and not (app._acumDeseo >= 0.05 and (x ~= 0 or y ~= 0)) then return end
  app._acumDeseo = 0
  app._ux, app._uy = x, y
  app.cliente:enviar({ t = "act", a = "deseo", p = { x = x, y = y } })
end

local function signo(v) return v > 0.05 and 1 or (v < -0.05 and -1 or 0) end

-- Predicción del movimiento propio: mientras mantienes las teclas, el personaje avanza ya en tu pantalla con las mismas reglas de
-- pasos y colisiones del servidor (sobre un "fantasma" que copia el resto de datos del jugador) y las fotos del servidor solo lo
-- corrigen: si se separa demasiado (algo le impidió el paso allí) se vuelve a la posición del servidor. Sin teclas, el fantasma
-- termina su casilla y entrega el control cuando el servidor lo alcanza.
function Juego.predecirPropio(app, dt, dx, dy)
  local j, mundo, s = app.jugador, app.mundo, app._srv
  if app._predOff or not j or not mundo or not s then app._pred = nil return end
  dx, dy = signo(dx or 0), signo(dy or 0)
  local posible = j.vivo ~= false and j.modo == "mundo" and (j.z or 0) == 0
  local pr = app._pred
  if not pr then
    if not posible or (dx == 0 and dy == 0) then return end
    pr = { activo = true, x = j.x, y = j.y, parado = 0 }
    setmetatable(pr, { __index = function(_, k) local q = app.jugador return q and q[k] end })
    app._pred = pr
  end
  local err = math.sqrt((pr.x - s.x) ^ 2 + (pr.y - s.y) ^ 2)
  if not posible or err > 2.5 then
    j._ox, j._oy, j._mx, j._my, j._t = pr.x, pr.y, s.x, s.y, 0
    j.x, j.y = pr.x, pr.y
    app._pred = nil
    return
  end
  -- ritmo: el que mide el servidor; se afloja o aprieta un poco para mantener la ventaja justa sobre la foto (medio ping)
  local spd = app._velProp or j.spd or 4
  local ventaja = spd * ((app.ping or 0.15) / 2 + (app._intervalo or 0.1) / 2)
  spd = spd * math.max(0.8, math.min(1.2, 1 + 0.5 * (ventaja - err) / math.max(ventaja, 0.5)))
  local ok, motivo = pcall(mundo.avanzar, mundo, pr, dt, dx, dy, spd)
  if not ok then
    Log.warn("predicción desactivada: " .. tostring(motivo))
    app._predOff = true
    app._pred = nil
    return
  end
  j.x, j.y, j.dir, j._mx = pr.x, pr.y, pr.dir or j.dir, nil
  if pr.mov then j._movHasta = love.timer.getTime() + 0.22 end
  if dx == 0 and dy == 0 and not pr.tramo then
    pr.parado = pr.parado + dt
    if err < 0.3 or pr.parado > 1 then
      j._ox, j._oy, j._mx, j._my, j._t = pr.x, pr.y, s.x, s.y, 0
      app._pred = nil
    end
  else
    pr.parado = 0
  end
end

function Juego.predecir(app, dt)
  if app.rol ~= "cliente" or not app.mundo then return end
  local ahora = love.timer.getTime()
  local mundo = app.mundo
  -- reloj, efectos y números avanzan entre foto y foto con el tiempo real
  mundo.tiempo = mundo.tiempo + dt
  for _, fx in ipairs(mundo.efectos) do fx.t = fx.t + dt end
  for _, n in ipairs(mundo.numeros) do
    n.vida = n.vida - dt
    n.y = n.y - dt * 0.4
  end
  local dur = app._intervalo or 0.1
  if app.estado == "juego" then
    local dx, dy = Entrada.deseo()
    Juego.predecirPropio(app, dt, dx, dy)
  end
  for _, e in pairs(app.mundo.entidades) do
    if e._mx and not (e.id == app.miId and app._pred) then
      e._t = math.min(1, (e._t or 0) + dt / dur)
      e.x = e._ox + (e._mx - e._ox) * e._t
      e.y = e._oy + (e._my - e._oy) * e._t
    end
    -- el cliente lleva su propio ciclo de caminar: el del servidor llega a saltos
    e.mov = ahora < (e._movHasta or 0)
    if e.mov then e.anim = (e.anim or 0) + dt * 8 end
  end
  Eco.actualizar(app, dt)
end

function Juego.tickCliente(app, dt)
  if not app.cliente or not app.mundo or app.rol ~= "cliente" then return end
  local msgs, err, codigo = app.cliente:actualizar()
  -- latencia real: cada segundo se manda un "ping" con un número y el servidor lo devuelve; el ping es lo que tarda la vuelta
  app._pingT = (app._pingT or 0) + dt
  if app._pingT >= 1 and app.estado == "juego" then
    app._pingT = 0
    app._pingN = (app._pingN or 0) + 1
    app._pingEnv = app._pingEnv or {}
    app._pingEnv[app._pingN] = love.timer.getTime()
    app._pingEnv[app._pingN - 5] = nil
    app.cliente:enviar({ t = "ping", n = app._pingN })
  end
  if err then
    Log.warn("conexion cerrada codigo " .. tostring(codigo or "?"))
    cortar(app, "Se cortó la conexión con el servidor.")
    return
  end
  for _, msg in ipairs(msgs or {}) do
    if msg.t == "no" then
      cortar(app, msg.error or "El servidor rechazó la entrada.")
      return
    end
    if msg.t == "ok" then app.miId = msg.id end
    if msg.t == "pong" then
      local t0 = app._pingEnv and app._pingEnv[msg.n]
      if t0 then
        local rtt = love.timer.getTime() - t0
        -- jitter: cuánto se separa cada medida de la media (si sube, la red va a tirones aunque el ping medio sea bueno)
        if app.ping then app.jitter = (app.jitter or 0) * 0.75 + math.abs(rtt - app.ping) * 0.25 end
        app.ping = app.ping and (app.ping * 0.6 + rtt * 0.4) or rtt
        app._pingEnv[msg.n] = nil
      end
    end
    if msg.t == "panel" then
      if msg.panel == "gremio" then
        -- el servidor responde también a las consultas de actualización: no reabren un panel cerrado
        if msg.datos then
          Interfaz.datosGremio = msg.datos
          if Interfaz.panel == "gremio" or Interfaz.pidiendoGremio then Interfaz.panel = "gremio" end
          Interfaz.pidiendoGremio = nil
        else
          Interfaz.panel = "gremio"
          app.actuar("gremio_info")
        end
      elseif msg.panel == "oficios" or msg.panel == "mercancias" or msg.panel == "establo" or msg.panel == "subastas" then
        -- estos paneles piden sus datos al servidor; las respuestas posteriores solo los actualizan
        if msg.datos then
          Interfaz.datosPanel[msg.panel] = msg.datos
          if Interfaz.panel == msg.panel then Interfaz.pidiendoPanel = nil end
        else
          Interfaz.panel = msg.panel
          Interfaz.datosPanel[msg.panel] = nil
          app.actuar(({ oficios = "oficio_info", mercancias = "mercancia_info", establo = "montura_info", subastas = "subasta_info" })[msg.panel],
            { cat = Interfaz.subCat, pagina = Interfaz.subPag })
        end
      else
        Interfaz.panel = msg.panel
        Interfaz.ciudad = msg.ciudad
        Interfaz.npcMision = msg.npc
        if msg.tienda then Interfaz.tienda = msg.tienda end
      end
    end
    if msg.t == "snap" and app.miId then
      mezclar(app, msg.snap)
      for _, ev in ipairs(app.mundo.sonidosRed or {}) do
        if not Eco.sonidoRepetido(app, ev) then Sonido.evento(ev, app.jugador) end
      end
      app.mundo.sonidosRed = {}
    end
  end
  enviarDeseo(app, dt)
end

function Juego.actualizar(app, dt)
  if app.mundo and app.rol ~= "cliente" then
    if app.jugador then
      local x, y = Entrada.deseo()
      app.jugador.deseoX, app.jugador.deseoY = x, y
    end
    app.mundo:actualizar(dt)
    for _, ev in ipairs(app.mundo.sonidos) do Sonido.evento(ev, app.jugador) end
    app.mundo.sonidos = {}
  end
  -- con el panel de gremio abierto se pide la lista al servidor cada par de segundos
  if app.estado == "juego" and app.rol == "cliente" and Interfaz.panel == "gremio" then
    Interfaz.sondeoGremio = (Interfaz.sondeoGremio or 0) + dt
    if Interfaz.sondeoGremio > 2 then
      Interfaz.sondeoGremio = 0
      app.actuar("gremio_info")
    end
  end
  Juego.tickCliente(app, dt)
  Juego.predecir(app, dt)
  if app.jugador and app.jugador.zona and app.estado == "juego" then
    Sonido.ambiente(app.jugador.zona)
  end
end

-- Al entrar al mundo (o al aparecer lejos: viaje, barco...) se construyen de golpe los bloques de terreno de alrededor, con una
-- barra de progreso, para que los primeros pasos no tengan tirones. Devuelve true mientras dura la carga.
local Terreno = require("src.presentacion.render.terreno")
local RADIO_CARGA = 2
function Juego.precargarMundo(app, w, h)
  local j, mundo = app.jugador, app.mundo
  if not j or not mundo or j.modo ~= "mundo" or (j.z or 0) ~= 0 then app.cargandoMundo = nil return false end
  local mapa = mundo.mapas.mundo
  local bx, by = math.floor((j.x or 0) / 16), math.floor((j.y or 0) / 16)
  local c = app.cargandoMundo
  if not c then
    -- solo se abre la pantalla de carga si falta suelo bajo los pies (entrada o salto lejano), no al caminar
    if #Terreno.faltantes(mapa, bx, by, 1, true) == 0 then return false end
    c = { total = #Terreno.faltantes(mapa, bx, by, RADIO_CARGA), t0 = love.timer.getTime() }
    app.cargandoMundo = c
  end
  local lista = Terreno.faltantes(mapa, bx, by, RADIO_CARGA)
  if #lista == 0 then
    Log.info(string.format("mundo: terreno preparado en %.2f s (%d bloques)", love.timer.getTime() - c.t0, c.total))
    app.cargandoMundo = nil
    return false
  end
  local t0 = love.timer.getTime()
  for _, b in ipairs(lista) do
    Terreno.construirYa(mapa, b[1], b[2], b[3])
    if love.timer.getTime() - t0 > 0.03 then break end
  end
  c.total = math.max(c.total, #lista)
  local hecho = math.max(0, c.total - #lista + 1)
  love.graphics.setColor(0.03, 0.04, 0.09, 1)
  love.graphics.rectangle("fill", 0, 0, w, h)
  local f = love.graphics.getFont()
  love.graphics.setColor(1, 0.9, 0.55)
  local t = "Preparando el mundo..."
  love.graphics.print(t, w / 2 - f:getWidth(t) / 2, h / 2 - 34)
  local bw = math.min(360, w - 80)
  love.graphics.setColor(0.12, 0.15, 0.28)
  love.graphics.rectangle("fill", w / 2 - bw / 2, h / 2, bw, 14, 6, 6)
  love.graphics.setColor(0.95, 0.75, 0.2)
  love.graphics.rectangle("fill", w / 2 - bw / 2, h / 2, bw * math.min(1, hecho / math.max(1, c.total)), 14, 6, 6)
  return true
end

function Juego.dibujar(app, w, h)
  if app.foto and app.foto.paso == "menu" then
    Interfaz.menu(false, w, h)
    return
  end
  if app.mundo and app.jugador and not app.foto and Juego.precargarMundo(app, w, h) then return end
  if app.mundo and app.jugador then
    local mx, my = love.mouse.getPosition()
    local s = math.max(1, math.min(1.6, h / 720))
    Interfaz.escala = s
    local lado, consola = Interfaz.medidas()
    Dibujo.fijarVista(0, 0, w - lado * s, h - consola * s)
    local cam = Dibujo.camara(app.jugador, app.zoom, app.mundo:mapaDe(app.jugador))
    Dibujo.apuntando = app.apuntando
    Dibujo.escena(app.mundo, app.jugador, cam, mx, my)
    love.graphics.push()
    love.graphics.scale(s, s)
    Interfaz.hud(app.mundo, app.jugador, w / s, h / s)
    love.graphics.pop()
    if app.depurar then
      local n = 0
      for _ in pairs(app.mundo.entidades) do n = n + 1 end
      love.graphics.setColor(1, 0.95, 0.8)
      love.graphics.print(string.format(
        "FPS %d   entes %d   ping %d ms (±%d)   piso %d",
        love.timer.getFPS(), n, math.floor((app.ping or 0) * 1000), math.floor((app.jitter or 0) * 1000), app.jugador.z or 0
      ), 16, h - 28)
    end
  end
end

local pedirHola

function Juego.esperar(app, dt)
  if not app.cliente then
    cortar(app, "No se pudo conectar con el servidor. Cierra el juego y vuelve a abrirlo con jugar.bat.")
    return
  end
  local msgs, err = app.cliente:actualizar()
  if err then
    cortar(app, "No se pudo conectar con el servidor. Cierra el juego y vuelve a abrirlo con jugar.bat.")
    return
  end
  for _, msg in ipairs(msgs or {}) do
    if msg.t == "no" then
      cortar(app, msg.error or "El servidor rechazó la entrada.")
      return
    end
    if msg.t == "sesion" and type(msg.token) == "string" then
      app.sesion = {
        cuentaId = msg.cuenta, usuario = msg.usuario or "",
        personajes = msg.personajes or {}, error = "", token = msg.token,
      }
      Ajustes.usarUsuario(msg.usuario)   -- las teclas son de cada cuenta
      if app.espera == "mundo" then
        local pid = tonumber(msg.creado) or app.personajeRed
        if not pid then
          app.espera = nil
          app.origen = nil
          app.estado = "personajes"
          return
        end
        app.personajeRed = pid
        pedirHola(app)
        return
      end
      app.espera = nil
      app.origen = nil
      if not app.mundo then app.mundo = require("compartido.dominio.mundo").nuevo() end
      app.estado = "personajes"
      return
    end
    if msg.t == "ok" then
      app.miId = msg.id
      if not app.mundo then app.mundo = require("compartido.dominio.mundo").nuevo() end
      app.estado = "juego"
      app.rol = "cliente"
    end
    if msg.t == "snap" and app.mundo and app.miId then
      mezclar(app, msg.snap)
    end
  end
  if app.estado == "conectando" and love.timer.getTime() - (app.conectaDesde or 0) > 3 then
    cortar(app, "No se pudo conectar con el servidor. Cierra el juego y vuelve a abrirlo con jugar.bat.")
  end
end

function Juego.dibujarEspera(app, w, h)
  local texto = app.espera == "mundo" and "Entrando al mundo…" or "El servidor está comprobando la cuenta…"
  love.graphics.setColor(0.07, 0.06, 0.09)
  love.graphics.rectangle("fill", 0, 0, w, h)
  love.graphics.setColor(0.95, 0.86, 0.55)
  love.graphics.printf(texto, 0, h / 2 - 12, w, "center")
end

function pedirHola(app)
  app.origen = nil
  app.espera = "mundo"
  app.estado = "conectando"
  app.rol = "cliente"
  app.jugador = nil
  app.miId = nil
  if not app.mundo then app.mundo = require("compartido.dominio.mundo").nuevo() end
  app.conectaDesde = love.timer.getTime()
  app.cliente:enviar({ t = "hola", token = app.sesion.token, personaje = app.personajeRed, proto = 2 })   -- proto 2: fotos diferenciales
  Interfaz.foco = nil
end

function Juego.entrar(app, ip)
  if not app.sesion or not app.sesion.token or not app.personajeRed then
    app.estado = "personajes"
    if app.sesion then app.sesion.error = "Entra de nuevo: el servidor aún no ha validado la cuenta." end
    return
  end
  if not Juego.abrir(app, ip or app.ipUnirse) then
    app.estado = "personajes"
    app.sesion.error = "No se pudo conectar con el servidor. Cierra el juego y vuelve a abrirlo con jugar.bat."
    return
  end
  pedirHola(app)
end

function Juego.conectar(app, ip)
  Juego.entrar(app, ip)
end

function Juego.pedirCuenta(app, ip, msg, espera, origen)
  if not Juego.abrir(app, ip) then
    app.estado = espera == "personajes" and "cuenta" or (origen == "crear" and "crear" or "personajes")
    local texto = "No se pudo conectar con el servidor. Cierra el juego y vuelve a abrirlo con jugar.bat."
    if app.estado == "cuenta" and app.cuenta then app.cuenta.error = texto
    elseif app.estado == "crear" and app.creacion then app.creacion.error = texto
    elseif app.sesion then app.sesion.error = texto end
    return
  end
  app.espera = espera
  app.origen = origen
  app.estado = "conectando"
  app.conectaDesde = love.timer.getTime()
  app.cliente:enviar(msg)
  if app.cuenta then app.cuenta.clave = "" end
  Interfaz.foco = nil
end

return Juego
