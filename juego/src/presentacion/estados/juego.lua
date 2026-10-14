local Dibujo = require("src.presentacion.render.dibujo")
local Interfaz = require("src.presentacion.interfaz")
local Sonido = require("src.presentacion.sonido")
local Entrada = require("src.presentacion.entrada")
local Red = require("compartido.infraestructura.red")
local Datos = require("compartido.dominio.datos")
local Config = require("src.infraestructura.config")
local Log = require("compartido.infraestructura.log")

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
local function mezclar(app, snap)
  local ahora = love.timer.getTime()
  -- tiempo real entre fotos (suavizado): es lo que dura el deslizamiento
  if app._ultimaFoto then
    local dtFoto = math.max(0.06, math.min(0.25, ahora - app._ultimaFoto))
    app._intervalo = (app._intervalo or dtFoto) * 0.8 + dtFoto * 0.2
  end
  app._ultimaFoto = ahora
  local antes = {}
  for id, e in pairs(app.mundo.entidades) do
    antes[id] = e.x and { x = e.x, y = e.y, hasta = e._movHasta }
  end
  app.mundo:aplicarFoto(snap, app.miId)
  for id, e in pairs(app.mundo.entidades) do
    local a = antes[id]
    local sx, sy = e.x, e.y
    e._movHasta = a and a.hasta or 0
    if a and sx then
      local ddx, ddy = a.x - sx, a.y - sy
      local d2 = ddx * ddx + ddy * ddy
      if d2 < 9 then
        e._ox, e._oy, e._mx, e._my, e._t = a.x, a.y, sx, sy, 0
        e.x, e.y = a.x, a.y
        -- se mueve mientras el servidor diga que anda o la posición cambie
        if e.mov or d2 > 0.0004 then e._movHasta = ahora + 0.22 end
      end
    end
  end
  app.jugador = app.mundo.entidades[app.miId]
end

local function enviarDeseo(app, dt)
  if not app.cliente or not app.jugador then return end
  local x, y = Entrada.deseo()
  app._acumDeseo = (app._acumDeseo or 0) + dt
  local cambio = app._ux ~= x or app._uy ~= y
  if not cambio and not (app._acumDeseo >= 0.05 and (x ~= 0 or y ~= 0)) then return end
  app._acumDeseo = 0
  app._ux, app._uy = x, y
  app.marcaPing = app.marcaPing or love.timer.getTime()
  app.cliente:enviar({ t = "act", a = "deseo", p = { x = x, y = y } })
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
  for _, e in pairs(app.mundo.entidades) do
    if e._mx then
      e._t = math.min(1, (e._t or 0) + dt / dur)
      e.x = e._ox + (e._mx - e._ox) * e._t
      e.y = e._oy + (e._my - e._oy) * e._t
    end
    -- el cliente lleva su propio ciclo de caminar: el del servidor llega a saltos
    e.mov = ahora < (e._movHasta or 0)
    if e.mov then e.anim = (e.anim or 0) + dt * 8 end
  end
end

function Juego.tickCliente(app, dt)
  if not app.cliente or not app.mundo or app.rol ~= "cliente" then return end
  local msgs, err, codigo = app.cliente:actualizar()
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
        if msg.tienda then Interfaz.tienda = msg.tienda end
      end
    end
    if msg.t == "snap" and app.miId then
      if app.marcaPing then app.ping = love.timer.getTime() - app.marcaPing end
      app.marcaPing = love.timer.getTime()
      mezclar(app, msg.snap)
      for _, nombre in ipairs(app.mundo.sonidosRed or {}) do Sonido.tocar(nombre) end
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
    for _, s in ipairs(app.mundo.sonidos) do Sonido.tocar(s) end
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

function Juego.dibujar(app, w, h)
  if app.foto and app.foto.paso == "menu" then
    Interfaz.menu(false, w, h)
    return
  end
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
        "FPS %d   entes %d   ping %d ms   piso %d",
        love.timer.getFPS(), n, math.floor((app.ping or 0) * 1000), app.jugador.z or 0
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
      if app.marcaPing then app.ping = love.timer.getTime() - app.marcaPing end
      app.marcaPing = love.timer.getTime()
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
  app.cliente:enviar({ t = "hola", token = app.sesion.token, personaje = app.personajeRed })
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
