-- Pruebas del juego (cliente): arte, capturas de pantalla, cliente de red de
-- prueba y juego automático. Se ejecutan con love juego --test | --foto | --bot | --auto
local Atlas = require("src.presentacion.render.atlas")
local Mundo = require("compartido.dominio.mundo")
local Datos = require("compartido.dominio.datos")
local Util = require("compartido.dominio.util")
local Red = require("compartido.infraestructura.red")
local Interfaz = require("src.presentacion.interfaz")
local Config = require("src.infraestructura.config")
local Log = require("compartido.infraestructura.log")

local Pruebas = {}

local function fallar(lista, nombre, cond, extra)
  if cond then return end
  lista[#lista + 1] = nombre .. (extra and (": " .. extra) or "")
end

function Pruebas.correr()
  local errores = {}
  local function paso(nombre, fn)
    local ok, err = pcall(fn)
    if not ok then errores[#errores + 1] = nombre .. " EX " .. tostring(err) end
  end
  paso("json", function()
    local t = { a = "Curación", n = 3, lista = { 1, 2 }, ok = true }
    local d = Util.jsonDec(Util.jsonEnc(t))
    fallar(errores, "json acento", d and d.a == "Curación")
  end)
  paso("iconos de objetos", function()
    fallar(errores, "láminas de objetos", Atlas.imgs.equipment ~= nil and Atlas.imgs.tiles ~= nil)
    for id, it in pairs(Datos.items) do
      if not Atlas.quad(it.hoja, it.sprite) then errores[#errores + 1] = "sin icono: " .. id break end
    end
  end)
  paso("personajes", function()
    local Personajes = require("src.presentacion.render.personajes")
    for _, m in ipairs(Datos.monstruos) do
      local def = Personajes.monstruos[m.id]
      fallar(errores, "sprite de " .. m.id, def ~= nil and def.hoja ~= nil)
    end
    for clase in pairs(Datos.clases) do
      for _, fac in ipairs({ "albor", "umbra" }) do
        fallar(errores, "sprite de " .. clase .. "/" .. fac, Personajes.clases[clase] and Personajes.clases[clase][fac])
      end
    end
    local Arte = require("src.presentacion.render.arte")
    for _, def in pairs(Personajes.monstruos) do Arte.img(def.hoja) end
  end)
  paso("efectos", function()
    local Efectos = require("src.presentacion.render.efectos")
    local n = 0
    for tipo in pairs(Efectos.def) do
      n = n + 1
      local ok, err = pcall(Efectos.icono, tipo, 0, 0, 32)
      fallar(errores, "efecto " .. tipo, ok, tostring(err))
    end
    fallar(errores, "hay efectos", n >= 20)
    for _, id in ipairs({ "golpe", "tajo", "grito", "carga", "misil", "fuego", "escudo", "nova", "disparo",
      "lluvia", "trampa", "preciso", "curar", "bendicion", "castigo", "consagrar" }) do
      fallar(errores, "efecto del poder " .. id, Efectos.def[id] ~= nil)
    end
  end)
  paso("objetos y terreno", function()
    local Objetos = require("src.presentacion.render.objetos")
    for _, nombre in ipairs({ "arbol", "arbol_pino", "arbol_seco", "farol", "pozo", "estatua_albor",
      "estatua_umbra", "columna_albor", "columna_umbra", "bandera_albor", "bandera_umbra", "altar_cristal", "restos" }) do
      fallar(errores, "objeto " .. nombre, Objetos.existe(nombre))
    end
    local Terreno = require("src.presentacion.render.terreno")
    local mundo = Mundo.nuevo()
    local mapa = mundo.mapas.mundo
    local c = mapa.ciudades[1]
    local ok, err = pcall(function()
      Terreno.dibujar(mapa, c.x * 32, c.y * 32, 640, 480, 0)
    end)
    fallar(errores, "terreno de una ciudad", ok, tostring(err))
    Terreno.olvidar(mapa)
  end)
  paso("interfaz: clics", function()
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Clic", faccion = "albor", clase = "mago" })
    Interfaz.escala = 1
    Interfaz.panel = nil
    Interfaz.hud(mundo, pj, 1280, 720)
    local lado, consola = Interfaz.medidas()
    local yTab = 720 - consola + 12
    for i, canal in ipairs({ "todo", "mundo", "faccion", "sistema" }) do
      local id = Interfaz.consumir(8 + (i - 1) * 76 + 36, yTab)
      fallar(errores, "pestaña del chat " .. canal, id == "canal_" .. canal, tostring(id))
    end
    fallar(errores, "la entrada del chat recibe el clic", Interfaz.consumir(200, 720 - 14) == "foco_chat")
    local lista = {}
    for i = 1, 4 do lista[i] = Interfaz.consumir(1280 - lado + 20 + (i - 1) * 40, 8) end
    local ayuda = Interfaz.consumir(1280 - lado + 118, 160)
    fallar(errores, "los botones del panel lateral reciben clics", ayuda ~= nil and ayuda ~= "panel", tostring(ayuda))
    fallar(errores, "el hueco de la barra de poderes responde", Interfaz.consumir((1280 - lado) / 2 - 130, 720 - consola - 34) == "hab_1")
  end)
  local texto = (#errores == 0) and "OK\n" or ("FALLOS " .. #errores .. "\n" .. table.concat(errores, "\n"))
  Log.volcar("prueba_resultado.txt", texto)
  print(texto)
  love.event.quit(#errores == 0 and 0 or 1)
end

-- Cliente de prueba por red: necesita un servidor en marcha (servidor.bat).
function Pruebas.bot()
  local errores, notas = {}, {}
  local function nota(t) notas[#notas + 1] = t end
  local cli = Red.conectar(Config.red.host, Config.red.puerto)
  fallar(errores, "conecta al servidor", cli ~= nil)
  local snaps, ultimoSnap, miId, token, personaje = 0, nil, nil, nil, nil
  local posFinal
  local usuario
  local function esperar(tipo, segundos)
    local limite = love.timer.getTime() + (segundos or 5)
    while love.timer.getTime() < limite do
      love.timer.sleep(0.02)
      local msgs, err = cli:actualizar()
      if err then return nil, "cerrado" end
      for _, m in ipairs(msgs or {}) do
        if m.t == "snap" then snaps = snaps + 1 ultimoSnap = m.snap end
        if m.t == tipo then return m end
        if m.t == "no" then return nil, m.error end
      end
    end
    return nil, "tiempo agotado esperando " .. tipo
  end
  if cli then
    usuario = "bot" .. string.format("%06d", os.time() % 1000000)
    cli:enviar({ t = "cuenta", a = "registrar", usuario = usuario, clave = "clave12" })
    local ses, e1 = esperar("sesion")
    fallar(errores, "registro por red", ses ~= nil, tostring(e1))
    if ses then
      token = ses.token
      cli:enviar({ t = "cuenta", a = "crear", token = token, nombre = "Bot" .. string.format("%04d", os.time() % 10000), faccion = "albor", clase = "clerigo" })
      local cre, e2 = esperar("sesion")
      fallar(errores, "creacion de personaje por red", cre and cre.creado ~= nil, tostring(e2))
      personaje = cre and cre.creado
    end
    if personaje then
      cli:enviar({ t = "hola", token = token, personaje = personaje })
      local ok, e3 = esperar("ok")
      fallar(errores, "entrada al mundo", ok ~= nil, tostring(e3))
      miId = ok and ok.id
    end
    if miId then
      local function yo()
        for _, e in ipairs((ultimoSnap and ultimoSnap.ents) or {}) do
          if e.id == miId then return e end
        end
      end
      esperar("nada", 0.6)
      local p0 = yo()
      fallar(errores, "foto con mi personaje", p0 ~= nil)
      if p0 then
        nota(string.format("inicio %.2f,%.2f", p0.x, p0.y))
        local vistos, ultimoX = 0, p0.y
        cli:enviar({ t = "act", a = "deseo", p = { x = 0, y = -1 } })
        local fin = love.timer.getTime() + 2.5
        while love.timer.getTime() < fin do
          love.timer.sleep(0.02)
          local msgs = cli:actualizar() or {}
          for _, m in ipairs(msgs) do if m.t == "snap" then snaps = snaps + 1 ultimoSnap = m.snap end end
          local pp = yo()
          if pp and pp.y ~= ultimoX then vistos = vistos + 1 ultimoX = pp.y end
        end
        cli:enviar({ t = "act", a = "deseo", p = { x = 0, y = 0 } })
        esperar("nada", 0.8)
        local p1 = yo()
        nota(string.format("fin %.2f,%.2f  cambios de posicion %d  fotos %d", p1.x, p1.y, vistos, snaps))
        posFinal = { x = p1.x, y = p1.y }
        fallar(errores, "camina por el servidor", p0.y - p1.y >= 3, tostring(p0.y - p1.y))
        fallar(errores, "movimiento fluido (muchas fotos con cambios)", vistos >= 8, tostring(vistos))
        fallar(errores, "queda centrado en casilla", math.abs((p1.y % 1) - 0.5) < 0.02, tostring(p1.y))
        local tu = ultimoSnap and ultimoSnap.tu
        fallar(errores, "datos propios en la foto", tu and tu.nivel == 1 and tu.hpMax ~= nil)
        -- un poder sin objetivo (CuraciÃ³n, el poder inicial del clÃ©rigo): el efecto, el enfriamiento y el reloj deben llegar por red
        cli:enviar({ t = "act", a = "habilidad", p = { slot = 1 } })
        local vioEfecto = false
        local limite = love.timer.getTime() + 1.2
        while love.timer.getTime() < limite do
          love.timer.sleep(0.02)
          for _, m in ipairs(cli:actualizar() or {}) do
            if m.t == "snap" then
              snaps = snaps + 1
              ultimoSnap = m.snap
              for _, fx in ipairs(m.snap.efectos or {}) do
                if fx.tipo == "curar" then vioEfecto = true end
              end
            end
          end
        end
        fallar(errores, "el efecto del poder llega al cliente", vioEfecto)
        local tu2 = ultimoSnap and ultimoSnap.tu
        local resta = tu2 and tu2.cds and tu2.cds.curar and ultimoSnap.tiempo and (tu2.cds.curar - ultimoSnap.tiempo)
        nota("enfriamiento de CuraciÃ³n visto: " .. tostring(resta and string.format("%.1f", resta)) .. " s")
        fallar(errores, "reloj del servidor y enfriamiento coherentes", resta and resta > 0.2 and resta < 2.2, tostring(resta))
        fallar(errores, "el Ã¡rbol llega al cliente con el poder inicial", tu2 and tu2.habilidades and tu2.habilidades.curar == 1)
        cli:enviar({ t = "act", a = "chat", p = { texto = "hola desde el bot" } })
        esperar("nada", 0.5)
        local oyo = false
        for _, m in ipairs((ultimoSnap and ultimoSnap.msgs) or {}) do
          if m.texto == "hola desde el bot" then oyo = true end
        end
        fallar(errores, "el chat vuelve en la foto", oyo)
      end
    end
    cli:cerrar()
    -- Volver a entrar: el servidor debe haber guardado al ver cerrarse la conexión.
    if posFinal and usuario and personaje then
      love.timer.sleep(1.0)
      local c2 = Red.conectar(Config.red.host, Config.red.puerto)
      fallar(errores, "segunda conexión", c2 ~= nil)
      if c2 then
        local function esperarEn(tipo, segundos, alRecibir)
          local limite = love.timer.getTime() + segundos
          while love.timer.getTime() < limite do
            love.timer.sleep(0.02)
            local msgs, err = c2:actualizar()
            if err then return nil end
            for _, m in ipairs(msgs or {}) do
              if alRecibir then alRecibir(m) end
              if m.t == tipo then return m end
              if m.t == "no" then return nil, m.error end
            end
          end
        end
        c2:enviar({ t = "cuenta", a = "entrar", usuario = usuario, clave = "clave12" })
        local ses2, e1 = esperarEn("sesion", 5)
        fallar(errores, "volver a iniciar sesión", ses2 ~= nil, tostring(e1))
        if ses2 then
          c2:enviar({ t = "hola", token = ses2.token, personaje = personaje })
          local ok2, e2 = esperarEn("ok", 5)
          fallar(errores, "volver a entrar al mundo", ok2 ~= nil, tostring(e2))
          if ok2 then
            local nueva
            esperarEn("nada", 1.0, function(m)
              if m.t == "snap" then
                for _, e in ipairs(m.snap.ents or {}) do
                  if e.id == ok2.id then nueva = e end
                end
              end
            end)
            fallar(errores, "foto tras volver a entrar", nueva ~= nil)
            if nueva then
              nota(string.format("guardado %.1f,%.1f  al volver %.1f,%.1f", posFinal.x, posFinal.y, nueva.x, nueva.y))
              fallar(errores, "al volver aparece donde se quedó (no en el inicio)",
                math.abs(nueva.x - posFinal.x) < 1.5 and math.abs(nueva.y - posFinal.y) < 1.5)
            end
          end
        end
        c2:cerrar()
      end
    end
  end
  local texto = (#errores == 0 and "OK\n" or ("FALLOS " .. #errores .. "\n" .. table.concat(errores, "\n") .. "\n")) .. table.concat(notas, "\n") .. "\n"
  Log.volcar("prueba_bot.txt", texto)
  print(texto)
  love.event.quit(#errores == 0 and 0 or 1)
end

-- Juega solo (registro, personaje y paseo) con la ventana dibujando de verdad.
-- Sirve para reproducir cierres y fallos que solo salen jugando. Necesita servidor.
local autoEstado = { t = 0, paso = "inicio" }
function Pruebas.auto(app, dt)
  local Entrada = require("src.presentacion.entrada")
  local a = autoEstado
  a.t = a.t + dt
  if a.paso == "inicio" and app.estado == "menu" and a.t > 0.5 then
    app.cuenta = { modo = "crear", usuario = "auto" .. string.format("%06d", os.time() % 1000000), clave = "clave12", error = "" }
    app.estado = "cuenta"
    Log.info("auto: enviando cuenta")
    Entrada.manejar(app, "cuenta_ok")
    Log.info("auto: cuenta enviada")
    a.paso = "cuenta"
  elseif a.paso == "cuenta" and app.estado == "personajes" then
    app.creacion = { nombre = "Auto" .. string.format("%04d", os.time() % 10000), faccion = "albor", clase = "guerrero", error = "" }
    app.estado = "crear"
    Log.info("auto: creando personaje")
    Entrada.manejar(app, "crear_entrar")
    Log.info("auto: personaje enviado")
    a.paso = "entrando"
  elseif a.paso == "entrando" and app.estado == "juego" and app.jugador then
    Log.info("auto: dentro del juego")
    a.paso = "juego"
    a.desde = a.t
    Entrada.auto = { x = 0, y = 0 }
  elseif a.paso == "juego" then
    local k = math.floor((a.t - a.desde) / 1.3) % 8
    local dirs = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 }, { 1, -1 }, { 1, 1 }, { -1, 1 }, { -1, -1 } }
    local d = dirs[k + 1]
    local n = math.sqrt(d[1] * d[1] + d[2] * d[2])
    Entrada.auto.x, Entrada.auto.y = d[1] / n, d[2] / n
    if math.floor((a.t - a.desde) * 2) % 9 == 0 then Entrada.tecla(app, "tab") end
    if math.floor((a.t - a.desde) * 3) % 11 == 0 then Entrada.tecla(app, tostring(1 + math.floor(a.t) % 4)) end
    if a.t - a.desde > (a.duracion or 60) then
      Log.volcar("prueba_auto.txt", "OK sobrevivio " .. math.floor(a.t - a.desde) .. " s\n")
      love.event.quit(0)
    end
  end
  if a.t > 25 and a.paso ~= "juego" then
    Log.volcar("prueba_auto.txt", "FALLO: no llego a jugar, paso=" .. a.paso .. " estado=" .. tostring(app.estado) .. "\n")
    love.event.quit(1)
  end
end

-- Hoja con todos los objetos del mapa sobre hierba, para revisar que no salgan cortados.
function Pruebas.dibujarObjetos(w, h)
  local Objetos = require("src.presentacion.render.objetos")
  local Arte = require("src.presentacion.render.arte")
  local a2 = Arte.img("Tilesets/Outside_A2.png")
  love.graphics.setColor(1, 1, 1, 1)
  for y = 0, math.ceil(h / 32) do
    for x = 0, math.ceil(w / 32) do
      love.graphics.draw(a2, Arte.quad(a2, 0, 0, 32, 32), x * 32, y * 32)
    end
  end
  love.graphics.setFont(Interfaz.fuente)
  local x, y = 60, 120
  for _, o in ipairs(Objetos.catalogo()) do
    for v = 0, o.n - 1 do
      Objetos.dibujar(o.nombre, v, x, y)
      love.graphics.setColor(0, 0, 0, 0.7)
      love.graphics.rectangle("fill", x - 44, y + 4, 88, 16)
      love.graphics.setColor(1, 1, 1)
      love.graphics.printf(o.nombre .. (o.n > 1 and ("#" .. v) or ""), x - 44, y + 4, 88, "center")
      x = x + 100
      if x > w - 60 then
        x = 60
        y = y + 130
      end
    end
  end
end

function Pruebas.prepararFoto(app)
  Log.asegurar("capturas")
  app.mundo = Mundo.nuevo()
  app.jugador = app.mundo:crearPersonaje({ nombre = "Liora", faccion = "albor", clase = "clerigo" })
  app.mundo:spawnMonstruo("gato", app.jugador.x + 2, app.jugador.y + 0.2, { x = app.jugador.x, y = app.jugador.y })
  app.mundo:spawnMonstruo("jabali", app.jugador.x + 3.2, app.jugador.y + 1, { x = app.jugador.x, y = app.jugador.y })
  app.mundo:spawnMonstruo("cuervo", app.jugador.x - 2, app.jugador.y + 1, { x = app.jugador.x, y = app.jugador.y })
  app.mundo:spawnMonstruo("gargola", app.jugador.x + 4, app.jugador.y - 1, { x = app.jugador.x, y = app.jugador.y })
  for _, e in pairs(app.mundo.entidades) do
    if e.kind == "bot" and e.faccion == "albor" then
      e.x, e.y = app.jugador.x - 1.2, app.jugador.y + 0.4
      break
    end
  end
  app.estado = "juego"
  app.rol = "local"
  app.foto = { paso = "menu", espera = 0 }
end

local function avanzarFoto(app)
  local foto = app.foto
  if foto.paso == "menu" then
    foto.paso = "cuenta"
    app.estado = "cuenta"
    app.cuenta = { modo = "entrar", usuario = "liora", clave = "••••••", error = "" }
  elseif foto.paso == "cuenta" then
    foto.paso = "personajes"
    app.estado = "personajes"
    app.sesion = {
      cuentaId = 1, usuario = "liora", error = "",
      personajes = {
        { id = 1, nombre = "Liora", faccion = "albor", clase = "clerigo", nivel = 7 },
        { id = 2, nombre = "Kael", faccion = "umbra", clase = "guerrero", nivel = 3 },
      },
    }
  elseif foto.paso == "personajes" then
    foto.paso = "crear"
    app.estado = "crear"
    app.creacion = { nombre = "Aria", faccion = "umbra", clase = "mago", error = "" }
  elseif foto.paso == "crear" then
    foto.paso = "ciudad"
    app.estado = "juego"
    Interfaz.panel = nil
  elseif foto.paso == "ciudad" then
    foto.paso = "costa"
    local mapa = app.mundo.mapas.mundo
    local hallado
    for y = 200, 330 do
      for x = 5, mapa.w - 6 do
        if mapa.suelo[x] and mapa.suelo[x][y] == "agua" and mapa.suelo[x - 1] and mapa.suelo[x - 1][y] == "arena" then
          hallado = { x = x - 4, y = y }
          break
        end
      end
      if hallado then break end
    end
    if hallado then app.jugador.x, app.jugador.y = hallado.x + 0.5, hallado.y + 0.5 end
  elseif foto.paso == "costa" then
    foto.paso = "bosque"
    local mapa = app.mundo.mapas.mundo
    for _, p in ipairs(mapa.props) do
      if p.tipo == "arbol_pino" then
        app.jugador.x, app.jugador.y = p.x + 2.5, p.y + 0.5
        break
      end
    end
  elseif foto.paso == "bosque" then
    foto.paso = "montana"
    local mapa = app.mundo.mapas.mundo
    for _, p in ipairs(mapa.props) do
      if p.tipo == "montana_albor" then
        app.jugador.x, app.jugador.y = p.x + 3.5, p.y + 4.5
        break
      end
    end
  elseif foto.paso == "montana" then
    foto.paso = "poderes"
    local j = app.jugador
    local tipos = { "golpe", "tajo", "grito", "escudo", "curar", "bendicion", "consagrar",
      "castigo", "fuego", "nova", "lluvia", "trampa", "preciso", "carga" }
    for i, t in ipairs(tipos) do
      local col = (i - 1) % 7
      local fila = math.floor((i - 1) / 7)
      app.mundo:efecto(t, j.x - 3 + col, j.y - 1.5 + fila * 3, 1.4)
    end
  elseif foto.paso == "poderes" then
    foto.paso = "estados"
    local j = app.jugador
    j.estadosResta = { quemar = 3, veneno = 5, lentitud = 2, aturdir = 1 }
    local lista = { "quemar", "sangrar", "veneno", "drenar_vida", "drenar_mana", "lentitud", "aturdir" }
    local i = 0
    for _, e in pairs(app.mundo.entidades) do
      if e.kind == "monstruo" then
        i = i + 1
        e.est = { lista[i], lista[i + 3] }
      end
    end
    local fx = { "aliento", "pisoton", "maldicion", "drenar_vida", "drenar_mana" }
    for k, t in ipairs(fx) do app.mundo:efecto(t, j.x - 4 + k * 1.7, j.y - 2.2, 1.4) end
  elseif foto.paso == "estados" then
    app.jugador.estadosResta = nil
    for _, e in pairs(app.mundo.entidades) do e.est = nil end
    foto.paso = "objetos"
  elseif foto.paso == "objetos" then
    foto.paso = "equipo"
    Interfaz.panel = "equipo"
  elseif foto.paso == "equipo" then
    foto.paso = "arbol"
    Interfaz.panel = "arbol"
    local j = app.jugador
    j.nivel = 8
    j.habilidades = { curar = 3, bendicion = 1, castigo = 2, fe = 1 }
  elseif foto.paso == "arbol" then
    foto.paso = "batalla"
    Interfaz.panel = nil
    app.jugador.nivel = 1
    app.jugador.habilidades = nil
    app.mundo.tiempo = app.mundo.tiempo + 8
    app.jugador.ultimoGolpe = 0
    local mundoFoto = app.mundo
    for i = 1, 2 do
      mundoFoto:crearPersonaje({ nombre = "Alba" .. i, faccion = "albor", clase = "clerigo" })
    end
    local umbras = {}
    for i = 1, 3 do
      umbras[i] = mundoFoto:crearPersonaje({ nombre = "Umbra" .. i, faccion = "umbra", clase = "guerrero" })
    end
    mundoFoto:accion(app.jugador.id, "guerra", { modo = "batalla" })
    for _, e in pairs(mundoFoto.entidades) do
      if e.kind == "jugador" and e.id ~= app.jugador.id and e.faccion == "albor" and e.colaGuerra ~= "batalla" and e.modo ~= "batalla" then
        mundoFoto:accion(e.id, "guerra", { modo = "batalla" })
      end
    end
    for _, e in ipairs(umbras) do
      mundoFoto:accion(e.id, "guerra", { modo = "batalla" })
    end
  elseif foto.paso == "batalla" then
    foto.paso = "casa"
    local j = app.jugador
    j.modo, j.casaId = "casa", "demo"
    j.casas = { demo = { muebles = { cama = true, cofre = true, mesa = true, estandarte = true }, cofre = {} } }
    local sal = app.mundo.mapas.casa.salida
    j.x, j.y = sal.x, sal.y - 4
  elseif foto.paso == "casa" then
    foto.paso = "fin"
    love.event.quit(0)
  end
  foto.espera = 0
end

function Pruebas.tickFoto(app, dt)
  local foto = app.foto
  if not foto then return end
  foto.espera = foto.espera + dt
  if foto.espera > 0.35 and not app.capturando and foto.paso ~= "fin" then
    app.capturando = true
    local nombre = foto.paso
    if nombre ~= "equipo" and nombre ~= "arbol" then Interfaz.panel = nil end
    Log.info(string.format("foto %s fps=%d panel=%s", nombre, love.timer.getFPS(), tostring(Interfaz.panel)))
    love.graphics.captureScreenshot(function(img)
      local fd = img:encode("png")
      Log.volcar("capturas/" .. nombre .. ".png", fd:getString())
      app.capturando = false
      avanzarFoto(app)
    end)
  end
end

return Pruebas
