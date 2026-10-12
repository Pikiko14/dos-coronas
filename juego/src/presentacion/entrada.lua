local Interfaz = require("src.presentacion.interfaz")
local Sonido = require("src.presentacion.sonido")
local Util = require("compartido.dominio.util")
local Dibujo = require("src.presentacion.render.dibujo")
local Ajustes = require("src.presentacion.ajustes")
local Config = require("src.infraestructura.config")

local Entrada = {}

function Entrada.deseo()
  if Entrada.auto then return Entrada.auto.x, Entrada.auto.y end
  if Interfaz.foco then return 0, 0 end
  local x, y = 0, 0
  if love.keyboard.isDown("w", "up") then y = y - 1 end
  if love.keyboard.isDown("s", "down") then y = y + 1 end
  if love.keyboard.isDown("a", "left") then x = x - 1 end
  if love.keyboard.isDown("d", "right") then x = x + 1 end
  local d = math.sqrt(x * x + y * y)
  if d > 0 then x, y = x / d, y / d end
  return x, y
end

function Entrada.manejar(app, id)
  if not id or id == "panel" then return end
  Sonido.tocar("click")
  local cuenta, sesion, creacion = app.cuenta, app.sesion, app.creacion
  if id == "menu_salir" then love.event.quit() return end
  if id == "menu_entrar" or id == "menu_registro" then
    app.cuenta = {
      modo = id == "menu_registro" and "crear" or "entrar",
      usuario = "", clave = "", error = "",
    }
    app.estado = "cuenta"
    Interfaz.foco = "usuario"
    return
  end
  if id == "cuenta_volver" or id == "cuenta_salir" then
    require("src.presentacion.estados.juego").soltar(app)
    app.sesion = { cuentaId = nil, usuario = "", personajes = {}, error = "" }
    app.estado = "menu"
    Interfaz.foco = nil
    return
  end
  if id == "foco_usuario" then Interfaz.foco = "usuario" return end
  if id == "foco_clave" then Interfaz.foco = "clave" return end
  if id == "cuenta_ok" then
    cuenta = app.cuenta
    require("src.presentacion.estados.juego").pedirCuenta(app, Config.red.host, {
      t = "cuenta",
      a = cuenta.modo == "crear" and "registrar" or "entrar",
      usuario = cuenta.usuario,
      clave = cuenta.clave,
    }, "personajes")
    return
  end
  if id == "pj_nuevo" then
    if not sesion.cuentaId then app.estado = "cuenta" return end
    app.creacion = { nombre = "", faccion = nil, clase = nil, error = "" }
    app.estado = "crear"
    Interfaz.foco = "nombre"
    return
  end
  if id:sub(1, 3) == "pj_" and id ~= "pj_nuevo" then
    if not sesion.token then sesion.error = "Entra de nuevo: el servidor aún no ha validado la cuenta." return end
    app.personajeRed = tonumber(id:sub(4))
    require("src.presentacion.estados.juego").entrar(app, Config.red.host)
    return
  end
  if id == "crear_volver" then
    app.estado = sesion.cuentaId and "personajes" or "menu"
    Interfaz.foco = nil
    return
  end
  if id == "foco_nombre" then Interfaz.foco = "nombre" return end
  if id == "foco_chat" then Interfaz.foco = "chat" Interfaz.texto = "" return end
  if id:sub(1, 8) == "faccion_" then creacion.faccion = id:sub(9) return end
  if id:sub(1, 6) == "clase_" then creacion.clase = id:sub(7) return end
  if id == "crear_entrar" then
    creacion = app.creacion
    if not sesion.cuentaId then app.cuenta.error = "Regístrate para jugar." app.estado = "cuenta" return end
    if creacion.faccion and creacion.clase then
      local nombre = creacion.nombre ~= "" and creacion.nombre or "Aventurero"
      require("src.presentacion.estados.juego").pedirCuenta(app, Config.red.host, {
        t = "cuenta", a = "crear", token = sesion.token,
        nombre = nombre, faccion = creacion.faccion, clase = creacion.clase,
      }, "mundo", "crear")
    end
    return
  end
  if id == "cerrar" then Interfaz.panel = nil return end
  if id == "hud_bolsa" then Interfaz.panel = "bolsa" return end
  if id == "hud_equipo" then Interfaz.panel = "equipo" return end
  if id == "hud_arbol" then Interfaz.panel = Interfaz.panel == "arbol" and nil or "arbol" return end
  if id:sub(1, 13) == "masc_adoptar_" then app.actuar("mascota_adoptar", { especie = id:sub(14) }) return end
  if id:sub(1, 9) == "masc_inv_" then app.actuar("mascota_invocar", { idx = tonumber(id:sub(10)) }) return end
  if id == "foco_gremio_nombre" then Interfaz.foco = "gremio_nombre" return end
  if id == "foco_gremio_tag" then Interfaz.foco = "gremio_tag" return end
  if id == "gr_crear" then
    app.actuar("gremio_crear", { nombre = Interfaz.gremioNombre or "", etiqueta = Interfaz.gremioTag or "" })
    Interfaz.foco = nil
    return
  end
  if id == "gr_acepta" then app.actuar("gremio_responder", { acepta = true }) return end
  if id == "gr_rechaza" then app.actuar("gremio_responder", { acepta = false }) return end
  if id == "gr_salir" then Interfaz.confirmaDisolver = nil app.actuar("gremio_salir") return end
  if id == "gr_disolver" then
    if Interfaz.confirmaDisolver then Interfaz.confirmaDisolver = nil app.actuar("gremio_disolver")
    else Interfaz.confirmaDisolver = true end
    return
  end
  if id == "gr_invitar" then
    local o = app.jugador and app.jugador.objetivo
    if o then app.actuar("gremio_invitar", { id = o }) end
    return
  end
  if id:sub(1, 8) == "gr_sube_" then app.actuar("gremio_rango", { id = tonumber(id:sub(9)), sube = true }) return end
  if id:sub(1, 8) == "gr_baja_" then app.actuar("gremio_rango", { id = tonumber(id:sub(9)), sube = false }) return end
  if id:sub(1, 7) == "gr_exp_" then app.actuar("gremio_expulsar", { id = tonumber(id:sub(8)) }) return end
  if id == "enc_go" then
    local donde, ref = tostring(Interfaz.encSel or ""):match("^(%a+)_(.+)$")
    if donde then app.actuar("encantar", { donde = donde, ref = ref }) end
    return
  end
  if id:sub(1, 4) == "enc_" then Interfaz.encSel = id:sub(5) return end
  if id == "arbol_reset" then app.actuar("olvidar") return end
  if id:sub(1, 4) == "arb_" then app.actuar("aprender", { id = id:sub(5) }) return end
  if id == "hud_mapa" then Interfaz.panel = "mapa" return end
  if id == "hud_guerra" then Interfaz.panel = "guerra" return end
  if id == "hud_ayuda" then Interfaz.panel = "ayuda" return end
  if id == "hud_menu" then Interfaz.panel = "menu" return end
  if id:sub(1, 3) == "bl_" then
    local objetivo = id:sub(4)
    local jugador, mundo = app.jugador, app.mundo
    local e = mundo and mundo.entidades[objetivo]
    if e and jugador then
      local hostil = mundo:puedeDanar(jugador, e)
      app.actuar("objetivo", { id = objetivo, persigue = hostil })
    end
    return
  end
  if id == "hud_comercio" then
    local jugador, mundo = app.jugador, app.mundo
    local obj = jugador and jugador.objetivo and mundo.entidades[jugador.objetivo]
    if obj and (obj.kind == "jugador" or obj.kind == "bot") then
      app.actuar("comercio_invitar", { id = obj.id })
      Interfaz.panel = "comercio"
    else
      mundo:mensaje("sistema", "", "Selecciona a un aventurero cercano y pulsa T.", jugador)
    end
    return
  end
  if id:sub(1, 4) == "hab_" then app.actuar("habilidad", { slot = tonumber(id:sub(5)) }) return end
  if id == "poc_vida" then app.actuar("pocion", { id = "pocion_vida" }) return end
  if id == "poc_mana" then app.actuar("pocion", { id = "pocion_mana" }) return end
  if id:sub(1, 6) == "canal_" then Interfaz.canal = id:sub(7) return end
  if id:sub(1, 6) == "bolsa_" then
    local i = tonumber(id:sub(7))
    Interfaz.sel = i
    if Interfaz.panel == "mercado" then
      app.actuar("vender", { i = i })
    elseif Interfaz.panel == "comercio" then
      app.actuar("comercio_item", { i = i })
    elseif Interfaz.arrastre and Interfaz.arrastre ~= i then
      app.actuar("mover_bolsa", { a = Interfaz.arrastre, b = i })
      Interfaz.arrastre = nil
    elseif Interfaz.arrastre == i then
      app.actuar("equipar", { i = i })
      Interfaz.arrastre = nil
    else
      Interfaz.arrastre = i
    end
    return
  end
  if id:sub(1, 6) == "equip_" then app.actuar("desequipar", { hueco = id:sub(7) }) return end
  if id:sub(1, 7) == "compra_" then app.actuar("comprar", { id = id:sub(8) }) return end
  if id == "vender_sel" and Interfaz.sel then app.actuar("vender", { i = Interfaz.sel }) return end
  if id == "guerra_batalla" then app.actuar("guerra", { modo = "batalla" }) Interfaz.panel = nil return end
  if id == "guerra_estandarte" then app.actuar("guerra", { modo = "estandarte" }) Interfaz.panel = nil return end
  if id == "guerra_salir" then app.actuar("salir_guerra") Interfaz.panel = nil return end
  if id:sub(1, 13) == "casa_comprar_" then app.actuar("casa_comprar", { id = id:sub(14) }) return end
  if id:sub(1, 12) == "casa_entrar_" then app.actuar("casa_entrar", { id = id:sub(13) }) Interfaz.panel = "casa" return end
  if id == "casa_salir" then app.actuar("casa_salir") Interfaz.panel = nil return end
  if id:sub(1, 7) == "mueble_" then app.actuar("mueble", { tipo = id:sub(8) }) return end
  if id:sub(1, 10) == "mision_ok_" then app.actuar("mision_aceptar", { id = id:sub(11) }) return end
  if id:sub(1, 11) == "mision_fin_" then app.actuar("mision_entregar", { id = id:sub(12) }) return end
  local jugador, mundo = app.jugador, app.mundo
  if id == "oro_10" then app.actuar("comercio_oro", { oro = ((jugador.sesion and mundo.sesiones[jugador.sesion] and mundo.sesiones[jugador.sesion].oferta[jugador.id].oro) or 0) + 10 }) return end
  if id == "oro_50" then app.actuar("comercio_oro", { oro = ((jugador.sesion and mundo.sesiones[jugador.sesion] and mundo.sesiones[jugador.sesion].oferta[jugador.id].oro) or 0) + 50 }) return end
  if id == "comercio_ok" then app.actuar("comercio_ok") return end
  if id == "comercio_no" then app.actuar("comercio_no") Interfaz.panel = nil return end
  if id == "ajustes" then Interfaz.panel = "ajustes" return end
  if id == "aj_vol_mas" then Ajustes.volumen = math.min(1, (Ajustes.volumen or 0) + 0.1) Sonido.volumen = Ajustes.volumen Ajustes.guardar() return end
  if id == "aj_vol_menos" then Ajustes.volumen = math.max(0, (Ajustes.volumen or 0) - 0.1) Sonido.volumen = Ajustes.volumen Ajustes.guardar() return end
  if id == "aj_1280" then Ajustes.ancho, Ajustes.alto, Ajustes.completo = 1280, 720, false Ajustes.aplicarVentana() Ajustes.guardar() return end
  if id == "aj_1600" then Ajustes.ancho, Ajustes.alto, Ajustes.completo = 1600, 900, false Ajustes.aplicarVentana() Ajustes.guardar() return end
  if id == "aj_completo" then Ajustes.completo = not Ajustes.completo Ajustes.aplicarVentana() Ajustes.guardar() return end
  if id == "aj_tecla_interactuar" then Ajustes.esperando = "interactuar" return end
  if id == "aj_tecla_bolsa" then Ajustes.esperando = "bolsa" return end
  if id == "salir_menu" then
    if app.rol == "cliente" then require("src.presentacion.estados.juego").soltar(app) end
    app.sesion = { cuentaId = nil, usuario = "", personajes = {}, error = "" }
    app.estado = "menu"
    Interfaz.panel = nil
    return
  end
end

-- Tab: pasa al siguiente enemigo cercano (el más próximo primero) y lo persigue.
function Entrada.siguienteObjetivo(app)
  local mundo, jugador = app.mundo, app.jugador
  if not mundo or not jugador then return end
  local lista = {}
  for _, e in pairs(mundo.entidades) do
    if e.id ~= jugador.id and mundo:mismoLugar(jugador, e) and mundo:puedeDanar(jugador, e) and e.kind ~= "puerta" and e.kind ~= "estatua" then
      local d = Util.dist(jugador.x, jugador.y, e.x, e.y)
      if d < 12 then lista[#lista + 1] = { e = e, d = d } end
    end
  end
  if #lista == 0 then return end
  table.sort(lista, function(a, b) if a.d == b.d then return a.e.id < b.e.id end return a.d < b.d end)
  local sigue = 1
  for i, it in ipairs(lista) do
    if it.e.id == jugador.objetivo then sigue = i % #lista + 1 break end
  end
  app.actuar("objetivo", { id = lista[sigue].e.id, persigue = true })
end

function Entrada.clicMundo(app, mx, my, boton)
  local mundo, jugador = app.mundo, app.jugador
  if not mundo or not jugador then return end
  if not Dibujo.dentroVista(mx, my) then return end
  local cam = Dibujo.camara(jugador, app.zoom, mundo:mapaDe(jugador))
  local x, y = Dibujo.pantallaAMundo(cam, mx, my)
  local ent = mundo:objetivoCercano(jugador, x, y, false)
  if ent and love.keyboard.isDown("lshift", "rshift") then
    app.actuar("mirar", { id = ent.id })
    return
  end
  if ent and (boton == 1 or boton == 2) then
    local hostil = mundo:puedeDanar(jugador, ent)
    app.actuar("objetivo", { id = ent.id, persigue = hostil or boton == 2 })
    if not hostil and ent.kind == "npc" then app.actuar("interactuar") end
    return
  end
  app.actuar("objetivo", { id = nil, persigue = false })
  app.actuar("destino", { x = x, y = y })
end

function Entrada.raton(app, mx, my, boton)
  local estado = app.estado
  if estado == "menu" or estado == "crear" or estado == "cuenta" or estado == "personajes" or (estado == "juego" and app.jugador) then
    local id = Interfaz.consumir(mx, my)
    if id then Entrada.manejar(app, id) return end
  end
  if estado == "juego" and app.jugador then
    Entrada.clicMundo(app, mx, my, boton)
  end
end

function Entrada.rueda(app, dy)
  if Interfaz.panel == "mercado" then
    Interfaz.scroll = math.max(0, Interfaz.scroll - dy)
  else
    app.zoom = math.max(1, math.min(3, app.zoom + dy * 0.25))
  end
end

function Entrada.texto(app, t)
  if Interfaz.foco == "nombre" then
    if #app.creacion.nombre < 16 then app.creacion.nombre = app.creacion.nombre .. t end
  elseif Interfaz.foco == "usuario" then
    if #app.cuenta.usuario < 16 and t:match("^[%w_]$") then app.cuenta.usuario = app.cuenta.usuario .. t end
  elseif Interfaz.foco == "clave" then
    if #app.cuenta.clave < 64 and t:byte() >= 32 then app.cuenta.clave = app.cuenta.clave .. t end
  elseif Interfaz.foco == "chat" then
    if #Interfaz.texto < 120 then Interfaz.texto = Interfaz.texto .. t end
  elseif Interfaz.foco == "gremio_nombre" then
    Interfaz.gremioNombre = Interfaz.gremioNombre or ""
    if #Interfaz.gremioNombre < 24 and t:byte() >= 32 then Interfaz.gremioNombre = Interfaz.gremioNombre .. t end
  elseif Interfaz.foco == "gremio_tag" then
    Interfaz.gremioTag = Interfaz.gremioTag or ""
    if #Interfaz.gremioTag < 4 and t:match("^%w$") then Interfaz.gremioTag = Interfaz.gremioTag .. t:upper() end
  end
end

function Entrada.tecla(app, tecla)
  if tecla == "escape" then
    if Ajustes.esperando then Ajustes.esperando = nil return end
    if app.estado == "cuenta" then app.estado = "menu" Interfaz.foco = nil return end
    if app.estado == "conectando" then
      local espera, origen = app.espera, app.origen
      local token = app.sesion and app.sesion.token
      require("src.presentacion.estados.juego").soltar(app)
      if espera == "personajes" or not token then app.estado = "cuenta"
      elseif origen == "crear" then app.estado = "crear"
      else app.estado = "personajes" end
      return
    end
    if app.estado == "personajes" then
      require("src.presentacion.estados.juego").soltar(app)
      app.sesion = { cuentaId = nil, usuario = "", personajes = {}, error = "" }
      app.estado = "menu"
      Interfaz.foco = nil
      return
    end
    if Interfaz.foco then Interfaz.foco = nil return end
    if Interfaz.panel then Interfaz.panel = nil return end
    if app.estado == "juego" and app.jugador and app.jugador.objetivo then
      app.actuar("objetivo", { id = nil, persigue = false })
      return
    end
    if app.estado == "juego" then Interfaz.panel = "menu" return end
  end
  if tecla == "backspace" then
    if Interfaz.foco == "nombre" then app.creacion.nombre = Util.popUtf8(app.creacion.nombre)
    elseif Interfaz.foco == "usuario" then app.cuenta.usuario = Util.popUtf8(app.cuenta.usuario or "")
    elseif Interfaz.foco == "clave" then app.cuenta.clave = Util.popUtf8(app.cuenta.clave or "")
    elseif Interfaz.foco == "chat" then Interfaz.texto = Util.popUtf8(Interfaz.texto or "")
    elseif Interfaz.foco == "gremio_nombre" then Interfaz.gremioNombre = Util.popUtf8(Interfaz.gremioNombre or "")
    elseif Interfaz.foco == "gremio_tag" then Interfaz.gremioTag = Util.popUtf8(Interfaz.gremioTag or "") end
    return
  end
  if tecla == "return" or tecla == "kpenter" then
    if app.estado == "cuenta" then Entrada.manejar(app, "cuenta_ok") return end
    if app.estado == "crear" then Entrada.manejar(app, "crear_entrar") return end
    if app.estado == "juego" and Interfaz.foco == "chat" then
      app.actuar("chat", { texto = Interfaz.texto })
      Interfaz.texto = ""
      Interfaz.foco = nil
      return
    end
    if app.estado == "juego" and (Interfaz.foco == "gremio_nombre" or Interfaz.foco == "gremio_tag") then
      Interfaz.foco = nil
      return
    end
    if app.estado == "juego" and not Interfaz.foco then
      Interfaz.foco = "chat"
      Interfaz.texto = ""
      return
    end
  end
  if app.estado == "juego" and Ajustes.esperando and tecla ~= "escape" and tecla ~= "f3" and tecla ~= "f11" then
    Ajustes.teclas[Ajustes.esperando] = tecla
    Ajustes.esperando = nil
    Ajustes.guardar()
    return
  end
  if tecla == "tab" and app.estado == "juego" and not Interfaz.foco then Entrada.siguienteObjetivo(app) return end
  if tecla == "f3" and app.estado == "juego" then app.depurar = not app.depurar return end
  if tecla == "f11" then
    Ajustes.completo = not Ajustes.completo
    Ajustes.aplicarVentana()
    Ajustes.guardar()
    return
  end
  if app.estado ~= "juego" or Interfaz.foco then return end
  local bolsa = (Ajustes.teclas and Ajustes.teclas.bolsa) or "i"
  local interactuar = (Ajustes.teclas and Ajustes.teclas.interactuar) or "e"
  if tecla == bolsa then Interfaz.panel = Interfaz.panel == "bolsa" and nil or "bolsa" end
  if tecla == "p" then Interfaz.panel = Interfaz.panel == "equipo" and nil or "equipo" end
  if tecla == "n" then
    local p = app.jugador
    local idx = p and (p.mascotaActiva or (p.mascotas and #p.mascotas > 0 and 1))
    if idx then app.actuar("mascota_invocar", { idx = idx }) end
  end
  if tecla == "g" then
    if Interfaz.panel == "gremio" then Interfaz.panel = nil
    else
      Interfaz.pidiendoGremio = true
      app.actuar("gremio_info")
    end
  end
  if tecla == "k" then Interfaz.panel = Interfaz.panel == "arbol" and nil or "arbol" end
  if tecla == "m" then Interfaz.panel = Interfaz.panel == "mapa" and nil or "mapa" end
  if tecla == "b" then Interfaz.panel = Interfaz.panel == "guerra" and nil or "guerra" end
  if tecla == interactuar then app.actuar("interactuar") end
  if tecla == "t" then Entrada.manejar(app, "hud_comercio") end
  if tecla == "f1" then Interfaz.panel = "ayuda" end
  if tecla == "1" or tecla == "2" or tecla == "3" or tecla == "4" or tecla == "5" or tecla == "6" then
    app.actuar("habilidad", { slot = tonumber(tecla) })
  end
  if tecla == "7" then app.actuar("pocion", { id = "pocion_vida" }) end
  if tecla == "8" then app.actuar("pocion", { id = "pocion_mana" }) end
end

return Entrada
