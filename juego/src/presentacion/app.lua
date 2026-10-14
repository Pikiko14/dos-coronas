local Datos = require("compartido.dominio.datos")
local Atlas = require("src.presentacion.render.atlas")
local Mundo = require("compartido.dominio.mundo")
local Interfaz = require("src.presentacion.interfaz")
local Sonido = require("src.presentacion.sonido")
local Log = require("compartido.infraestructura.log")
local Menu = require("src.presentacion.estados.menu")
local Cuenta = require("src.presentacion.estados.cuenta")
local Personajes = require("src.presentacion.estados.personajes")
local Crear = require("src.presentacion.estados.crear")
local Juego = require("src.presentacion.estados.juego")
local Pruebas = require("src.pruebas.pruebas")
local Ajustes = require("src.presentacion.ajustes")
local Config = require("src.infraestructura.config")

local App = {
  estado = "cargando",
  fase = 0,
  mundo = nil,
  jugador = nil,
  zoom = Datos.ZOOM,
  rol = "local",
  cliente = nil,
  miId = nil,
  creacion = { nombre = "", faccion = nil, clase = nil, error = "" },
  cuenta = { modo = "entrar", usuario = "", clave = "", error = "" },
  sesion = { cuentaId = nil, usuario = "", personajes = {}, error = "" },
  ipUnirse = Config.red.host,
  fuente = nil,
  grande = nil,
  foto = nil,
  capturando = false,
}

local function bandera(nombre)
  if not arg then return false end
  for _, v in pairs(arg) do
    if v == nombre then return true end
  end
  return false
end

App.modoTest = bandera("--test")
App.modoFoto = bandera("--foto")
App.modoBot = bandera("--bot")
App.modoAuto = bandera("--auto")

App.modulos = {
  menu = Menu,
  cuenta = Cuenta,
  personajes = Personajes,
  crear = Crear,
  juego = Juego,
  conectando = { actualizar = Juego.esperar, dibujar = Juego.dibujarEspera },
}

function App.actuar(nombre, datos)
  local jugador = App.jugador
  if not jugador then return end
  if App.rol == "cliente" and App.cliente then
    App.cliente:enviar({ t = "act", a = nombre, p = datos or {} })
    return
  end
  local r = App.mundo:accion(jugador.id, nombre, datos)
  if r and r.panel ~= nil then
    Interfaz.panel = r.panel
    Interfaz.ciudad = r.ciudad
    if r.tienda then Interfaz.tienda = r.tienda end
  elseif r and r.panel == nil and nombre == "interactuar" then
    Interfaz.panel = nil
  end
end

function App.cargar()
  love.graphics.setBackgroundColor(0.05, 0.05, 0.07)
  local ruta = "arte/fuentes/SourceSans3-Regular.ttf"
  if love.filesystem.getInfo(ruta) then
    App.fuente = love.graphics.newFont(ruta, 16)
    App.grande = love.graphics.newFont(ruta, 48)
  else
    Log.error("No está la fuente en " .. ruta .. ". Uso la fuente de LÖVE.")
    App.fuente = love.graphics.newFont(16)
    App.grande = love.graphics.newFont(32)
  end
  love.graphics.setFont(App.fuente)
  Interfaz.iniciar(App.fuente, App.grande)
  Sonido.iniciar()
  Ajustes.cargar(not App.modoTest and not App.modoFoto)
  Log.info("arranque " .. (App.modoTest and "test" or App.modoFoto and "foto" or App.modoBot and "bot" or App.modoAuto and "auto" or "cliente"))
end

function App.actualizar(dt)
  dt = math.min(dt or 0, 0.05)
  if App.fase == 0 then App.fase = 1 return end
  if App.fase == 1 then
    Atlas.cargar()
    Sonido.iniciar()
    if App.modoTest then Pruebas.correr() return end
    if App.modoBot then Pruebas.bot() return end
    if App.modoFoto then Pruebas.prepararFoto(App) App.fase = 2 return end
    App.estado = "menu"
    App.fase = 2
    return
  end
  local mod = App.modulos[App.estado]
  if mod and mod.actualizar then mod.actualizar(App, dt) end
  if App.foto then Pruebas.tickFoto(App, dt) end
  if App.modoAuto then Pruebas.auto(App, dt) end
end

function App.dibujar()
  Interfaz.escala = 1
  local w, h = love.graphics.getDimensions()
  if App.estado == "cargando" or App.fase < 2 then
    Menu.cargando()
    return
  end
  if App.foto and App.foto.paso == "menu" then
    Menu.dibujar(App, w, h)
    return
  end
  if App.foto and App.foto.paso == "objetos" then
    Pruebas.dibujarObjetos(w, h)
    return
  end
  local mod = App.modulos[App.estado]
  if mod and mod.dibujar then mod.dibujar(App, w, h) end
  require("src.presentacion.ayudas").cursor(Interfaz)
end

function App.salir()
end

function App.fallo(msg)
  local tr = debug.traceback(tostring(msg), 2)
  Log.error(tr)
  Log.volcar("error_log.txt", tr)
  if App.modoTest or App.modoFoto then
    Log.volcar("prueba_resultado.txt", "EXCEPCION\n" .. tr)
    return function() return 1 end
  end
  return function()
    love.graphics.clear(0.1, 0.05, 0.05)
    love.graphics.setColor(1, 0.85, 0.7)
    love.graphics.printf(tr, 24, 24, 900, "left")
    love.graphics.present()
    for _, e in ipairs({ love.event.wait() }) do
      if e == "quit" or e == "keypressed" then return 1 end
    end
  end
end

return App
