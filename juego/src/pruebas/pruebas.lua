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
  -- Pasos de los mapas de FAO antiguos (granja_de_pinchos, riprap...; se quitaron todos): se saltan mientras no estén en mapas_fao/indice.lua.
  local hayMapasFao = require("compartido.dominio.mapas_fao").MAPAS.granja_de_pinchos ~= nil
  local function pasoFao(nombre, fn) if hayMapasFao then paso(nombre, fn) end end
  local function pasoMoba(nombre, fn) if hayMapasFao or require("compartido.dominio.mapas_fao").MAPAS.asedio then paso(nombre, fn) end end
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
      "lluvia", "trampa", "preciso", "curar", "bendicion", "castigo", "consagrar", "pantera", "furia",
      "meteoro", "flecha_veneno", "paso_agil", "sanacion", "juicio", "rayo_hielo", "rayo_arcano", "lluvia_fuego", "teletransporte", "torbellino",
      "estocada", "barrido", "muro_lanzas", "embestida", "jabalina", "tormenta_lanzas",
      "toque_necro", "espinas", "maldecir", "alzar_esqueletos", "drenar" }) do
      fallar(errores, "efecto del poder " .. id, Efectos.def[id] ~= nil)
    end
  end)
  paso("rendimiento: el terreno con plantas vivas no se come el cuadro", function()
    local Terreno = require("src.presentacion.render.terreno")
    local Objetos = require("src.presentacion.render.objetos")
    local mundo = Mundo.nuevo()
    local mapa = mundo.mapas.mundo
    -- una zona con muchos árboles y matas
    local mejor, n0 = nil, -1
    for _, pu in ipairs(mapa.puestos) do
      local n = 0
      for _, pr in ipairs(mapa.props) do if math.abs(pr.x - pu.x) < 20 and math.abs(pr.y - pu.y) < 12 and pr.tipo:find("arbol") then n = n + 1 end end
      if n > n0 then mejor, n0 = pu, n end
    end
    local cv = love.graphics.newCanvas(1280, 720)
    local function medir(etiqueta)
      love.graphics.setCanvas({ cv, stencil = true })
      local t0 = love.timer.getTime()
      for i = 1, 40 do
        love.graphics.clear(0, 0, 0, 1)
        Terreno.dibujar(mapa, (mejor.x - 20) * 32, (mejor.y - 11) * 32, 1280, 720, 0)
        for _, pr in ipairs(mapa.props) do
          if math.abs(pr.x - mejor.x) < 21 and math.abs(pr.y - mejor.y) < 12 then
            Objetos.dibujar(pr.tipo, 0, (pr.x - mejor.x + 20) * 32 + 16, (pr.y - mejor.y + 11) * 32 + 32, nil, nil, pr.x * 0.35 + pr.y * 0.2)
          end
        end
      end
      love.graphics.setCanvas()
      local ms = (love.timer.getTime() - t0) / 40 * 1000
      Log.info(string.format("rendimiento %s: %.2f ms por cuadro (%d arboles cerca)", etiqueta, ms, n0))
      return ms
    end
    medir("calentar")
    local ms = medir("terreno+props")
    fallar(errores, "terreno y objetos de un bosque en menos de 8 ms por cuadro", ms < 8, string.format("%.2f ms", ms))
  end)
  paso("predicción del movimiento propio: avanza al instante, se queda en su casilla y entrega el control", function()
    local Juego = require("src.presentacion.estados.juego")
    local mundo = Mundo.nuevo()
    local c = mundo.mapas.mundo.ciudades[1]
    local x0, y0 = c.spawn.x, c.spawn.y
    local j = { id = 7, kind = "jugador", modo = "mundo", z = 0, vivo = true, x = x0, y = y0, spd = 4, faccion = c.faccion, nombre = "t" }
    mundo.entidades[7] = j
    local app = { jugador = j, mundo = mundo, miId = 7, _srv = { x = x0, y = y0, t = 0 }, ping = 0.15 }
    for _ = 1, 30 do Juego.predecirPropio(app, 1 / 60, 1, 0) end      -- medio segundo hacia +x
    local recorrido = j.x - x0
    fallar(errores, "avanza sin esperar al servidor (medio segundo a 4 casillas/s)", app._pred ~= nil and recorrido > 0.8 and recorrido < 3.2, string.format("%.2f casillas", recorrido))
    -- el servidor llega a la misma posición y las teclas se sueltan: termina la casilla y entrega el control
    for _ = 1, 120 do
      app._srv = { x = app._pred and app._pred.x or j.x, y = app._pred and app._pred.y or j.y, t = 0 }
      Juego.predecirPropio(app, 1 / 60, 0, 0)
    end
    fallar(errores, "al soltar las teclas entrega el control al servidor", app._pred == nil)
    fallar(errores, "queda centrado en una casilla", math.abs((j.x % 1) - 0.5) < 0.01 and math.abs((j.y % 1) - 0.5) < 0.01, j.x .. "," .. j.y)
    -- si el servidor lo deja muy lejos (no le dejó pasar), vuelve a su posición
    app._pred = nil
    j.x, j.y = x0, y0
    app._srv = { x = x0, y = y0, t = 0 }
    Juego.predecirPropio(app, 1 / 60, 1, 0)
    app._srv = { x = x0 - 5, y = y0, t = 0 }
    Juego.predecirPropio(app, 1 / 60, 1, 0)
    fallar(errores, "si el servidor lo corrige lejos, abandona la predicción", app._pred == nil and j._mx == x0 - 5)
  end)
  paso("eco instantáneo de poderes: se ve al lanzar, el servidor no lo duplica y se corta si lo rechaza", function()
    local Eco = require("src.presentacion.eco")
    local mundo = Mundo.nuevo()
    local c = mundo.mapas.mundo.ciudades[1]
    local pj = mundo:crearPersonaje({ nombre = "Mago", faccion = "albor", clase = "mago", nivel = 20 })
    pj.habilidades.fuego, pj.habilidades.nova = 1, 1
    pj.mp, pj.mpMax, pj.cds = 9999, 9999, {}
    pj.x, pj.y = c.spawn.x, c.spawn.y
    local mob = { id = 900, kind = "monstruo", faccion = "bestia", x = pj.x + 4, y = pj.y, vivo = true, hp = 100, hpMax = 100, modo = "mundo", z = 0, nivel = 1 }
    mundo.entidades[900] = mob
    pj.objetivo = 900
    local app = { jugador = pj, mundo = mundo, miId = pj.id, rol = "cliente", ping = 0.15 }
    local function slotDe(id) for i, h in ipairs(Datos.barra.mago) do if h == id then return i end end end
    local dibujo = Eco.lanzar(app, { slot = slotDe("nova") })
    Eco.actualizar(app, 0.016)
    local nfx = 0
    for _, fx in ipairs(mundo.efectos) do if fx._eco and fx.tipo == "nova" then nfx = nfx + 1 end end
    fallar(errores, "la nova se dibuja al instante", dibujo == true and nfx == 1, tostring(dibujo) .. "/" .. nfx)
    fallar(errores, "el maná y el enfriamiento se adelantan", pj.cds.nova and pj.cds.nova > mundo.tiempo)
    fallar(errores, "en enfriamiento no hay eco", Eco.lanzar(app, { slot = slotDe("nova") }) == false)
    -- llega la foto con el efecto del servidor: se descarta (no se ve doble) y cuenta como confirmación
    mundo.efectos = { { tipo = "nova", x = mob.x + 0.1, y = mob.y, t = 0.1, dur = 1.4 } }
    Eco.actualizar(app, 0.016)
    local propios, ajenos = 0, 0
    for _, fx in ipairs(mundo.efectos) do if fx._eco then propios = propios + 1 else ajenos = ajenos + 1 end end
    fallar(errores, "el efecto del servidor no se duplica", propios == 1 and ajenos == 0, propios .. "/" .. ajenos)
    -- proyectil: vuela al instante hacia el objetivo y el del servidor se oculta
    app._ecoGcd = 0
    -- la bola de fuego es un efecto de capas de FAO (carga, estela e impacto en un solo efecto): el eco crea ese efecto y ningún proyectil
    pj.habilidades.misil = 1
    pj.cds = {}
    local okf = Eco.lanzar(app, { slot = slotDe("fuego") })
    Eco.actualizar(app, 0.016)
    local fxf = 0
    for _, fx in ipairs(mundo.efectos) do if fx._eco and fx.tipo == "fuego" and fx.x0 == pj.x then fxf = fxf + 1 end end
    fallar(errores, "la bola de fuego se ve al instante como efecto de capas (con su origen)", okf == true and fxf == 1, tostring(okf) .. "/" .. fxf)
    app._ecoGcd = 0
    pj.cds = {}
    local ok = Eco.lanzar(app, { slot = slotDe("misil") })
    Eco.actualizar(app, 0.05)
    local pr, fxm = nil, 0
    for _, e in pairs(mundo.entidades) do if e._eco and e.kind == "proyectil" then pr = e end end
    for _, fx in ipairs(mundo.efectos) do if fx._eco and fx.tipo == "misil" then fxm = fxm + 1 end end
    -- el misil arcano también es un efecto de capas (el orbe viaja dentro de él): sin proyectil de eco
    fallar(errores, "el misil sale al instante como efecto de capas", ok == true and pr == nil and fxm == 1, tostring(ok) .. "/" .. fxm)
    -- el servidor rechaza: sin confirmación el eco se corta
    local app2 = { jugador = pj, mundo = mundo, miId = pj.id, rol = "cliente", ping = 0.05 }
    pj.cds = {}
    mundo.efectos = {}
    Eco.lanzar(app2, { slot = slotDe("nova") })
    app2._eco.sup[1].limite = love.timer.getTime() - 1       -- ya pasó el plazo
    Eco.actualizar(app2, 0.016)
    local quedan = 0
    for _, fx in ipairs(mundo.efectos) do if fx._eco and fx.tipo == "nova" then quedan = quedan + 1 end end
    fallar(errores, "sin confirmación del servidor el eco se corta", quedan == 0, tostring(quedan))
  end)
  paso("fotos diferenciales en el cliente: entran, se deslizan hacia la posición nueva, cambian campos y salen", function()
    local Juego = require("src.presentacion.estados.juego")
    local mundo = Mundo.nuevo()
    local app = { mundo = mundo, miId = 1, rol = "cliente", estado = "juego" }
    local ya = love.timer.getTime
    mundo.entidades = {}
    Juego._mezclar(app, { delta = 1, reset = 1, nuevos = {
      { id = 1, kind = "jugador", nombre = "Yo", x = 50, y = 50, hp = 100, hpMax = 100, vivo = true, dir = 1 },
      { id = 7, kind = "monstruo", nombre = "Gato", x = 52, y = 50, hp = 10, hpMax = 10, vivo = true, dir = 1 },
    } })
    fallar(errores, "la foto con reset trae las entidades", mundo.entidades[7] and mundo.entidades[7].x == 52 and app.jugador == mundo.entidades[1])
    -- el monstruo avanza: la posición que se ve sigue donde estaba y el destino es la nueva
    Juego._mezclar(app, { delta = 1, mods = { { id = 7, x = 53, dir = 4 } } })
    local m = mundo.entidades[7]
    fallar(errores, "una diferencia no mueve de golpe lo que se ve", m.x == 52 and m._mx == 53 and m.sx == 53 and m.dir == 4)
    Juego.predecir(app, 0.05)
    fallar(errores, "se desliza hacia la posición nueva", m.x > 52 and m.x < 53, tostring(m.x))
    -- sin diferencias nuevas, el deslizamiento acaba solo
    for _ = 1, 10 do Juego.predecir(app, 0.05) end
    fallar(errores, "y llega a ella sin más fotos", math.abs(m.x - 53) < 0.001, tostring(m.x))
    -- cambian campos sueltos y se quita uno
    Juego._mezclar(app, { delta = 1, mods = { { id = 7, hp = 4, burbuja = "hola" } } })
    fallar(errores, "los campos que cambian se aplican", m.hp == 4 and m.burbuja == "hola" and m.x == 53 and m.hpMax == 10)
    Juego._mezclar(app, { delta = 1, mods = { { id = 7, ["~"] = { "burbuja" } } } })
    fallar(errores, "los campos quitados desaparecen", m.burbuja == nil)
    -- la parte propia llega por diferencias
    Juego._mezclar(app, { delta = 1, tu = { oro = 55, bolsa = { { id = "x", cant = 1 } } } })
    Juego._mezclar(app, { delta = 1, tu = { oro = 60 } })
    fallar(errores, "la parte propia se completa con diferencias", mundo.entidades[1].oro == 60 and mundo.entidades[1].bolsa[1].id == "x")
    -- sale de la vista
    Juego._mezclar(app, { delta = 1, sal = { 7 } })
    fallar(errores, "las que salen se quitan", mundo.entidades[7] == nil and mundo.entidades[1] ~= nil)
  end)
  paso("medidor de daño del jefe: se dibuja en el HUD con su ranking", function()
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Yo", faccion = "albor", clase = "mago", nivel = 20 })
    pj.medidor = { n = "Gorila del Bosque", hp = 700, hpMax = 1000, f = { { "Fuerte", 15200, 62, 0 }, { "Yo", 6000, 25, 1 }, { "Otro", 3000, 13, 0 } } }
    Interfaz.escala = 1
    Interfaz.panel = nil
    local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el HUD con medidor de daño se dibuja", ok, tostring(err))
    pj.medidor = nil
    ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "y sin medidor también", ok, tostring(err))
  end)
  paso("teclado: poderes ordenados por nivel, teclas por usuario y asignación con intercambio", function()
    local Arbol = require("compartido.dominio.arbol")
    local Entrada = require("src.presentacion.entrada")
    local Ajustes = require("src.presentacion.ajustes")
    -- no se toca el ajustes.json real: guardar solo anota las teclas del usuario en memoria
    local guardarReal, teclasReales = Ajustes.guardar, Ajustes.teclasUsuario
    Ajustes.guardar = function()
      if Ajustes.usuarioTeclas then
        local c = {}
        for k, v in pairs(Ajustes.teclas) do c[k] = v end
        Ajustes.teclasUsuario[Ajustes.usuarioTeclas] = c
      end
    end
    -- el orden de la barra sube de nivel: cada poder tiene un nivel igual o mayor que el anterior
    for _, clase in ipairs(Datos.ORDEN_CLASES) do
      local orden, barra, ant = Arbol.ordenBarra(clase), Datos.barra[clase], 0
      local ok = #orden == #barra
      for _, slot in ipairs(orden) do
        local n = Arbol.nodo(clase, barra[slot])
        if not n or n.nivel < ant then ok = false end
        ant = n and n.nivel or ant
      end
      fallar(errores, "la barra de " .. clase .. " va de menor a mayor nivel", ok)
    end
    local cazador = Arbol.ordenBarra("cazador")
    fallar(errores, "en el cazador el poder del nivel 3 (trampa) va antes que el del 7 (lluvia)", cazador[2] == 3 and cazador[3] == 2, table.concat(cazador, ","))
    -- por usuario: cada cuenta guarda las suyas
    Ajustes.teclasUsuario = {}
    Ajustes.usarUsuario("Ana")
    fallar(errores, "de partida, las de siempre", Ajustes.teclas.poder1 == "1" and Ajustes.teclas.pocion_mana == "8" and Ajustes.teclas.bolsa == "i")
    fallar(errores, "se puede asignar una libre", Ajustes.asignarTecla("poder1", "x") == nil and Ajustes.teclas.poder1 == "x")
    fallar(errores, "una que ya usa el juego se rechaza", Ajustes.asignarTecla("poder2", "w") ~= nil and Ajustes.teclas.poder2 == "2")
    fallar(errores, "si otra acción la tenía, intercambian", Ajustes.asignarTecla("poder3", "x") == nil and Ajustes.teclas.poder3 == "x" and Ajustes.teclas.poder1 == "3")
    Ajustes.guardar()
    Ajustes.usarUsuario("Beto")
    fallar(errores, "otra cuenta no hereda las de Ana", Ajustes.teclas.poder3 == "3" and Ajustes.teclas.poder1 == "1")
    Ajustes.usarUsuario("ana")
    fallar(errores, "al volver Ana recupera las suyas (sin distinguir mayúsculas)", Ajustes.teclas.poder3 == "x" and Ajustes.teclas.poder1 == "3")
    -- la tecla asignada lanza el poder de esa posición
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Teclas", faccion = "albor", clase = "cazador", nivel = 20 })
    pj.habilidades.trampa, pj.habilidades.lluvia, pj.mp, pj.mpMax, pj.cds = 1, 1, 999, 999, {}, {}
    local llamadas = {}
    local app = { jugador = pj, mundo = mundo, estado = "juego", zoom = 1, actuar = function(n, d) llamadas[#llamadas + 1] = { n, d } end }
    Interfaz.foco, Interfaz.panel = nil, nil
    Ajustes.usarUsuario("Carla")
    Ajustes.asignarTecla("poder2", "h")
    Entrada.tecla(app, "h")
    local slotEsperado = Ajustes.orden("cazador")[2]
    fallar(errores, "la tecla de la posición 2 lanza el poder de esa posición", llamadas[1] and llamadas[1][1] == "habilidad" and llamadas[1][2].slot == slotEsperado, llamadas[1] and tostring(llamadas[1][2].slot) or "nada")
    llamadas = {}
    Entrada.tecla(app, "2")
    fallar(errores, "la antigua ya no hace nada", #llamadas == 0)
    -- arrastrar un poder a otra casilla los intercambia (y las teclas siguen a la posición)
    local o0 = {}
    for i, v in ipairs(Ajustes.orden("cazador")) do o0[i] = v end
    fallar(errores, "intercambiar dos poderes", Ajustes.intercambiarPoderes("cazador", o0[1], o0[4]) == true)
    local o1 = Ajustes.orden("cazador")
    fallar(errores, "queda cada uno en el sitio del otro", o1[1] == o0[4] and o1[4] == o0[1] and o1[2] == o0[2])
    llamadas = {}
    Ajustes.asignarTecla("poder1", "x")
    Entrada.tecla(app, "x")
    fallar(errores, "la tecla de la posición 1 lanza ahora el poder que estaba en la 4", llamadas[1] and llamadas[1][2].slot == o0[4], llamadas[1] and tostring(llamadas[1][2].slot) or "nada")
    Ajustes.usarUsuario("Otro")
    fallar(errores, "el orden es de cada cuenta", Ajustes.orden("cazador")[1] == o0[1])
    Ajustes.usarUsuario("Carla")
    Ajustes.restablecerTeclas()
    fallar(errores, "restablecer devuelve el orden por nivel", Ajustes.orden("cazador")[1] == o0[1])
    -- con el ratón: pulsar un poder, arrastrarlo a otra casilla y soltar los intercambia; un clic corto lo lanza
    Interfaz.escala, Interfaz.panel = 1, nil
    pcall(Interfaz.hud, mundo, pj, 1280, 720)
    -- (la barra va de 6 en 6 por fila: 6 poderes arriba y los demás abajo)
    local function casilla(i) return 480 + ((i - 1) % 6) * 54 + 25, 720 - 50 - 10 - (1 - math.floor((i - 1) / 6)) * 54 + 25 end
    local antes = {}
    for i, v in ipairs(Ajustes.orden("cazador")) do antes[i] = v end
    local x1, y1 = casilla(1)
    local x3, y3 = casilla(3)
    Entrada.raton(app, x1, y1, 1)
    Entrada.moverRaton(app, x3, y3, 100, 0)
    Entrada.soltarRaton(app, x3, y3)
    local despues = Ajustes.orden("cazador")
    fallar(errores, "arrastrar con el ratón intercambia las casillas 1 y 3", despues[1] == antes[3] and despues[3] == antes[1], table.concat(despues, ","))
    llamadas = {}
    pcall(Interfaz.hud, mundo, pj, 1280, 720)      -- el HUD se redibuja cada cuadro con el orden nuevo
    Entrada.raton(app, x1, y1, 1)
    fallar(errores, "pulsar solo no lanza todavía", #llamadas == 0)
    Entrada.soltarRaton(app, x1, y1)
    -- (los poderes de área sobre un punto, como la lluvia de flechas, entran en modo apuntar en vez de lanzarse al momento)
    fallar(errores, "un clic corto lanza el poder de la casilla", (llamadas[1] and llamadas[1][1] == "habilidad" and llamadas[1][2].slot == despues[1])
      or (app.apuntando and app.apuntando.slot == despues[1]), llamadas[1] and tostring(llamadas[1][2].slot) or "nada")
    app.apuntando = nil
    -- el panel de teclado se dibuja y sus botones responden
    Interfaz.escala, Interfaz.panel = 1, "teclado"
    local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el panel de teclado se dibuja", ok, tostring(err))
    Interfaz.panel = nil
    Ajustes.guardar, Ajustes.teclasUsuario, Ajustes.barrasUsuario = guardarReal, teclasReales, {}
    Ajustes.usarUsuario("")
  end)
  paso("rendimiento: memoria que genera el HUD y el dibujo por cuadro", function()
    local Misiones = require("compartido.dominio.misiones")
    local Dibujo = require("src.presentacion.render.dibujo")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Medidor", faccion = "albor", clase = "guerrero", nivel = 12 })
    for _, c in ipairs(mundo.mapas.mundo.ciudades) do if c.id == "auroria" then pj.x, pj.y = c.x + c.w / 2, c.y + c.h / 2 + 6 end end
    pj.misiones = { q_auroria = { aceptada = true, entregada = false, progreso = 2 } }
    Misiones.seguida = "q_auroria"
    Interfaz.escala, Interfaz.panel = 1, nil
    local cv = love.graphics.newCanvas(1280, 720)
    love.graphics.setCanvas({ cv, stencil = true })
    for _ = 1, 30 do Interfaz.hud(mundo, pj, 1280, 720) end
    collectgarbage() collectgarbage()
    local m0 = collectgarbage("count")
    collectgarbage("stop")
    for _ = 1, 120 do Interfaz.hud(mundo, pj, 1280, 720) end
    local kb = (collectgarbage("count") - m0) / 120
    collectgarbage("restart")
    love.graphics.setCanvas()
    Misiones.seguida = nil
    Log.info(string.format("rendimiento hud: %.1f KB de basura por cuadro", kb))
    fallar(errores, "el HUD no genera basura de más por cuadro", kb < 40, string.format("%.1f KB", kb))
    -- marcas de PNJ
    collectgarbage() collectgarbage()
    m0 = collectgarbage("count")
    collectgarbage("stop")
    for i = 1, 200 do Misiones.marcaNpc(pj, "c_auroria") end
    local kb2 = (collectgarbage("count") - m0) / 200
    collectgarbage("restart")
    Log.info(string.format("rendimiento marcaNpc: %.2f KB por llamada", kb2))
  end)
  paso("carga previa del mundo: se construye el terreno de alrededor antes de jugar", function()
    local Juego = require("src.presentacion.estados.juego")
    local Terreno = require("src.presentacion.render.terreno")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Cargador", faccion = "albor", clase = "guerrero" })
    local app = { mundo = mundo, jugador = pj }
    local mapa = mundo.mapas.mundo
    local bx, by = math.floor(pj.x / 16), math.floor(pj.y / 16)
    fallar(errores, "al principio falta el suelo bajo los pies", #Terreno.faltantes(mapa, bx, by, 1, true) > 0)
    local cv = love.graphics.newCanvas(1280, 720)
    love.graphics.setCanvas({ cv, stencil = true })
    local cuadros = 0
    while Juego.precargarMundo(app, 1280, 720) and cuadros < 400 do cuadros = cuadros + 1 end
    love.graphics.setCanvas()
    fallar(errores, "la carga termina", cuadros < 400 and app.cargandoMundo == nil, tostring(cuadros))
    fallar(errores, "tras la carga hay suelo en 5 x 5 bloques", #Terreno.faltantes(mapa, bx, by, 2) == 0)
    fallar(errores, "con el terreno hecho no vuelve a abrirse la carga", Juego.precargarMundo(app, 1280, 720) == false)
  end)
  paso("sonido: todos los efectos se sintetizan bien (poderes, voces de criaturas y muerte)", function()
    local Sintesis = require("src.presentacion.sintesis")
    local Sonido = require("src.presentacion.sonido")
    local Voces = require("compartido.dominio.voces")
    local t0 = love.timer.getTime()
    local cat = Sintesis.catalogo()
    local esperados = { "corte", "lanza", "grito", "magia", "fuego", "hielo", "flecha", "cura", "sagrado", "oscuro", "muerte_jugador" }
    for _, f in ipairs(Voces.FAMILIAS) do
      for _, p in ipairs({ "ataque_", "herido_", "muerte_" }) do esperados[#esperados + 1] = p .. f end
    end
    local peor
    for _, nombre in ipairs(esperados) do
      local gen = cat[nombre]
      fallar(errores, "existe el sonido " .. nombre, gen ~= nil)
      if gen then
        local ok, datos = pcall(gen)
        fallar(errores, nombre .. " se genera", ok, tostring(datos))
        if ok then
          local n, pico, suma, nan = datos:getSampleCount(), 0, 0, false
          for i = 0, n - 1 do
            local v = datos:getSample(i)
            if v ~= v then nan = true end
            pico = math.max(pico, math.abs(v))
            suma = suma + v * v
          end
          local rms = math.sqrt(suma / n)
          fallar(errores, nombre .. " tiene señal audible y sin NaN", not nan and pico > 0.1 and rms > 0.02, string.format("pico %.2f rms %.3f", pico, rms))
          fallar(errores, nombre .. " dura entre 0,1 y 2,6 s", datos:getDuration() >= 0.1 and datos:getDuration() <= 2.6, tostring(datos:getDuration()))
        end
      end
    end
    Log.info(string.format("sonido: %d efectos sintetizados en %.2f s (prueba)", #esperados, love.timer.getTime() - t0))
    -- sin audio activo (pruebas) tocar no hace nada ni falla
    fallar(errores, "sin audio no se toca nada", Sonido.evento({ n = "magia", x = 1, y = 1 }, { x = 1, y = 1 }) == false)
  end)
  paso("selección de personaje: se dibuja con su último addon", function()
    Interfaz.escala = 1
    local lista = {
      { id = 1, nombre = "Con addon", faccion = "albor", clase = "lancero", nivel = 9, addon = "skin_enmascarado" },
      { id = 2, nombre = "Sin addon", faccion = "umbra", clase = "mago", nivel = 3 },
      { id = 3, nombre = "Addon raro", faccion = "albor", clase = "guerrero", nivel = 1, addon = "skin_que_no_existe" },
    }
    local ok, err = pcall(Interfaz.personajes, lista, "prueba", 1280, 720, "")
    fallar(errores, "la selección dibuja addons (y tolera uno desconocido)", ok, tostring(err))
  end)
  paso("todos los poderes tienen su efecto dibujable y los proyectiles su sprite", function()
    local Efectos = require("src.presentacion.render.efectos")
    local sin = {}
    for id, h in pairs(Datos.habilidades) do
      if not h.proyectil and not Efectos.def[id] then sin[#sin + 1] = id end
      if not h.proyectil then
        local ok, err = pcall(function()
          love.graphics.push()
          Efectos.cuadro(id, 0.2, 0.5, 100, 100, 1, 1, 0.7)
          Efectos.cuadro(id, 0.8, 0.5, 100, 100, 1, 1, -2)
          love.graphics.pop()
        end)
        if not ok then sin[#sin + 1] = id .. " (" .. tostring(err) .. ")" end
      end
    end
    fallar(errores, "todos los poderes tienen su efecto", #sin == 0, table.concat(sin, ","))
    local Arte = require("src.presentacion.render.arte")
    for _, tipo in ipairs({ "misil", "fuego", "sagrado", "flecha", "sombra", "lanza", "necro" }) do
      local ok = pcall(Arte.img, "Animations/Proyectil_" .. tipo .. ".png", true)
      fallar(errores, "existe el sprite del proyectil " .. tipo, ok)
      fallar(errores, "el impacto del proyectil " .. tipo .. " tiene efecto", Efectos.def[tipo] ~= nil or tipo == "misil")
    end
  end)
  paso("objetos y terreno", function()
    local Objetos = require("src.presentacion.render.objetos")
    for _, nombre in ipairs({ "arbol", "arbol_pino", "arbol_seco", "farol", "pozo", "estatua_albor",
      "estatua_umbra", "columna_albor", "columna_umbra", "bandera_albor", "bandera_umbra", "altar_cristal", "restos", "huevo" }) do
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
  paso("todos los objetos tienen icono visible", function()
    local datos = {}
    local function celda(hoja, idx)
      if not datos[hoja] then
        local archivo = ({ equipment = "otsp_equipment_01.png", extra = "equipo_extra.png", altos = "equipo_altos.png", fao = "equipo_fao.png" })[hoja] or (hoja .. ".png")
        datos[hoja] = love.image.newImageData(love.filesystem.newFileData(Atlas.carpeta .. "/" .. archivo))
      end
      local d = datos[hoja]
      local cols = math.floor(d:getWidth() / 32)
      local cx, cy = (idx % cols) * 32, math.floor(idx / cols) * 32
      if cy + 32 > d:getHeight() then return false end
      local n = 0
      for y = cy, cy + 31 do
        for x = cx, cx + 31 do
          local r, g, b, a = d:getPixel(x, y)
          if a > 0.1 and not (r > 0.95 and g < 0.05 and b > 0.95) then n = n + 1 end
        end
      end
      return n > 20
    end
    local vacios = {}
    for id, it in pairs(Datos.items) do
      if not it.hoja or not it.sprite or not celda(it.hoja, it.sprite) then vacios[#vacios + 1] = id .. "@" .. tostring(it.sprite) end
    end
    table.sort(vacios)
    fallar(errores, "objetos sin icono visible", #vacios == 0, table.concat(vacios, ", "))
  end)
  paso("dibujo del botín en el suelo", function()
    local Dibujo = require("src.presentacion.render.dibujo")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Suelo", faccion = "albor", clase = "guerrero" })
    local ejemplos = {
      { id = "e17", kind = "loot", x = 5, y = 5, vivo = true, item = "pocion_vida" },
      { id = "e18", kind = "loot", x = 5, y = 5, vivo = true, bien = "trigo" },
      { id = "e19", kind = "loot", x = 5, y = 5, vivo = true, oroSuelo = true },
      { id = "e20", kind = "loot", x = 5, y = 5, vivo = true },
    }
    for i, e in ipairs(ejemplos) do
      local ok, err = pcall(Dibujo.entidad, e, 100, 100, mundo, pj)
      fallar(errores, "se dibuja el botín " .. i, ok, tostring(err))
    end
  end)
  paso("monturas nuevas: sprites, efectos y paneles de diaria y personal", function()
    local Monturas = require("compartido.dominio.monturas")
    local Personajes = require("src.presentacion.render.personajes")
    local Propias = require("src.presentacion.render.propias")
    local nuevas = { "mnt_001", "mnt_104", "mnt_203" }
    for id, d in pairs(Monturas.especies) do
      for _, fac in ipairs({ "albor", "umbra" }) do
        local def = Personajes.monturaDe(id, fac)
        fallar(errores, "la montura " .. id .. " tiene dibujo (" .. fac .. ")", def ~= nil)
        if def and def.generada then fallar(errores, "su hoja " .. def.generada .. " se genera", Propias.hoja(def.generada) ~= nil) end
      end
    end
    for _, id in ipairs(nuevas) do
      fallar(errores, id .. " es una montura de las listas", Monturas.especies[id] ~= nil)
      for dir = 1, 4 do
        local ok, err = pcall(Personajes.dibujar, Personajes.monturaDe(id, "albor"), dir, true, 0.3, 100, 100)
        fallar(errores, id .. " se dibuja hacia " .. dir, ok, tostring(err))
      end
    end
    local mall = require("compartido.dominio.mall")
    local enMall = 0
    for _, id in ipairs(mall.ORDEN_MONTURAS) do enMall = enMall + 1 end
    fallar(errores, "el mall tiene las 8 monturas de pago de FAO", enMall == 8, tostring(enMall))
    -- recompensa diaria y etiqueta del personal
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Gm", faccion = "albor", clase = "guerrero", nivel = 10 })
    pj.staff, pj.diaria = "gm", mundo:estadoDiaria(pj)
    Interfaz.escala, Interfaz.panel = 1, "diaria"
    local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el panel de la recompensa diaria se dibuja", ok, tostring(err))
    local ok2, err2 = pcall(require("src.presentacion.render.dibujo").entidad, { id = "e1", kind = "jugador", nombre = "Gm", staff = "gm", x = 5, y = 5, vivo = true, faccion = "albor", clase = "guerrero" }, 100, 100, mundo, pj)
    fallar(errores, "el jugador con etiqueta GM se dibuja", ok2, tostring(err2))
    Interfaz.panel = nil
  end)
  paso("interfaz: icono de montura y opción de oficio en el menú", function()
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Menu", faccion = "albor", clase = "guerrero", nivel = 10 })
    pj.monturas, pj.oficioElegido = { "caballo", "carreta" }, "trader"
    pj.job = nil
    Interfaz.escala, Interfaz.panel = 1, nil
    pcall(Interfaz.hud, mundo, pj, 1280, 720)
    local lado0, consola0 = Interfaz.medidas()
    fallar(errores, "con monturas el icono sale siempre, aunque no haya oficio activo", Interfaz.consumir(1148, 688) == "hud_monturas")
    -- la colección de monturas se dibuja con normales, del mall y de transporte, y con el estado de cada una
    pj.monturas = { "caballo", "mnt_001", "mnt_104", "carreta" }
    pj.monturasEstado = { caballo = { hp = 300, max = 350 }, carreta = { caida = 40, hp = 0, max = 1100 } }
    Interfaz.panel = "montura"
    local okCol, errCol = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "la colección de monturas se dibuja", okCol, tostring(errCol))
    Interfaz.panel = nil
    pj.monturas = { "caballo", "carreta" }
    pj.job = "trader"
    Interfaz.escala = 1
    Interfaz.panel = nil
    local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el HUD con montura se dibuja", ok, tostring(err))
    local lado, consola = Interfaz.medidas()
    local hallado = Interfaz.consumir(1148, 688) == "hud_monturas"
    fallar(errores, "el icono de montura responde al clic", hallado)
    pj.montado = "caballo"
    ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el HUD montado se dibuja", ok, tostring(err))
    for _, estado in ipairs({ false, true }) do
      pj.job = estado and "trader" or nil
      Interfaz.panel = "menu"
      ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
      fallar(errores, "el menú con oficio se dibuja", ok, tostring(err))
    end
    Interfaz.panel = nil
  end)
  paso("interfaz: item mall y skins", function()
    local Dibujo = require("src.presentacion.render.dibujo")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Mall", faccion = "albor", clase = "mago", nivel = 10 })
    pj.mall = { monedas = 120, bonos = { exp = 3500, atk = 90 }, addons = { "skin_rey" }, addonActivo = "skin_rey" }
    Interfaz.escala = 1
    for _, tab in ipairs({ "objetos", "addons" }) do
      Interfaz.mallTab = tab
      Interfaz.panel = "mall"
      local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
      fallar(errores, "el mall se dibuja en " .. tab, ok, tostring(err))
    end
    Interfaz.panel = nil
    local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "los bonos activos se dibujan en el HUD", ok, tostring(err))
    pj.addon = "skin_marea"
    ok, err = pcall(Dibujo.entidad, pj, 200, 200, mundo, pj)
    fallar(errores, "la skin se dibuja", ok, tostring(err))
    local it = Datos.item("pergamino_atk")
    fallar(errores, "los pergaminos tienen tinte", it and it.tinte and it.mall == true)
    local exp = Datos.item("tarjeta_exp")
    fallar(errores, "la experiencia doble usa el icono x2", exp and exp.hoja == "bonos" and exp.sprite == 0)
Interfaz.mallTab, Interfaz.mallScroll, Interfaz.panel = "addons", 1, "mall"    local okS, errS = pcall(Interfaz.hud, mundo, pj, 1280, 720)    fallar(errores, "el mall se dibuja desplazado", okS, tostring(errS))    fallar(errores, "hay más apariencias que filas (necesita rueda)", (Interfaz.mallScrollMax or 0) >= 1, tostring(Interfaz.mallScrollMax))
    Interfaz.mallTab, Interfaz.mallScroll = "objetos", 1
    local okO, errO = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "los objetos del mall también se desplazan", okO and Interfaz.mallScrollMax >= 1, tostring(errO))    Interfaz.mallScroll, Interfaz.panel = 0, nil
  end)
  paso("dibujo del cuerpo caído", function()
    local Dibujo = require("src.presentacion.render.dibujo")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Mira", faccion = "albor", clase = "guerrero" })
    for _, job in ipairs({ "trader", "hunter", "thief" }) do
      local cuerpo = { id = "e90", kind = "cuerpo", nombre = "X", faccion = "umbra", clase = "mago", job = job, dir = 1, x = 5, y = 5, vivo = true }
      local ok, err = pcall(Dibujo.entidad, cuerpo, 100, 100, mundo, pj)
      fallar(errores, "se dibuja el cuerpo " .. job, ok, tostring(err))
    end
  end)
  paso("skins: el addon cambia el sprite y el oficio activo manda", function()
    local P = require("src.presentacion.render.personajes")
    local Mall = require("compartido.dominio.mall")
    local todas = true
    for _, id in ipairs(Mall.ORDEN_ADDONS) do
      local def = P.skins[id]
      if id:sub(1, 3) ~= "pd_" then todas = todas and def ~= nil and ((def.generada and require("src.presentacion.render.propias").hoja(def.generada) ~= nil) or (def.hoja and require("src.presentacion.render.arte").img(def.hoja) ~= nil)) end    -- (las apariencias PD se dibujan por capas, no con hoja propia)
    end
    fallar(errores, "todos los addons tienen sprite", todas)
    local base = { kind = "jugador", clase = "mago", faccion = "albor" }
    require("src.presentacion.render.fao").forzar(false)
    fallar(errores, "sin addon, el de la clase", P.de(base) == P.clases.mago.albor)
    require("src.presentacion.render.fao").forzar(nil)
    base.addon = "skin_rey"
    fallar(errores, "con addon, el sprite único", P.de(base) == P.skins.skin_rey)
    base.job = "thief"
    fallar(errores, "con oficio activo, el del oficio", P.de(base) == P.oficios.thief)
    fallar(errores, "el cuerpo conserva la skin", P.de({ kind = "cuerpo", clase = "mago", faccion = "albor", addon = "skin_marea" }) == P.skins.skin_marea)
  end)
  paso("interfaz: mapa con zoom y zonas", function()
    local Entrada = require("src.presentacion.entrada")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Mapa", faccion = "albor", clase = "guerrero", nivel = 10 })
    local app = { jugador = pj, mundo = mundo, estado = "juego", zoom = 1 }
    Interfaz.escala = 1
    Interfaz.mapaZoom, Interfaz.mapaCx, Interfaz.mapaCy, Interfaz.mapaTab = 1, nil, nil, "zonas"
    Interfaz.panel = "mapa"
    local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el mapa se dibuja", ok, tostring(err))
    local g = Interfaz.mapaGeom
    fallar(errores, "el mapa tiene su zona de arrastre", g and Interfaz.consumir(g.ax + 10, g.ay + 10) == "mapa_area")
    -- zoom con los botones y la rueda
    Entrada.manejar(app, "mapa_mas")
    fallar(errores, "el botón + acerca", Interfaz.mapaZoom > 1.4)
    local z1 = Interfaz.mapaZoom
    Interfaz.mapaZoomar(1.25, g.ax + 50, g.ay + 50)
    fallar(errores, "la rueda acerca hacia el cursor", Interfaz.mapaZoom > z1)
    Entrada.manejar(app, "mapa_menos")
    Entrada.manejar(app, "mapa_menos")
    Entrada.manejar(app, "mapa_menos")
    fallar(errores, "no se aleja más del mapa entero", Interfaz.mapaZoom == 1)
    for _ = 1, 20 do Interfaz.mapaZoomar(1.5, g.ax + 10, g.ay + 10) end
    fallar(errores, "el zoom tiene tope", Interfaz.mapaZoom <= 8)
    -- arrastrar mueve la vista sin salirse del mapa
    local cx0 = Interfaz.mapaCx
    Interfaz.mapaArrastre = true
    Entrada.moverRaton(app, 0, 0, 80, 40)
    fallar(errores, "arrastrar mueve la vista", Interfaz.mapaCx < cx0)
    Entrada.moverRaton(app, 0, 0, -99999, -99999)
    fallar(errores, "la vista no se sale del mapa", Interfaz.mapaCx <= Datos.MAPA_W and Interfaz.mapaCy <= Datos.MAPA_H)
    Entrada.soltarRaton()
    fallar(errores, "soltar termina el arrastre", Interfaz.mapaArrastre == false)
    -- clic en una zona de la lista centra el mapa en ella
    ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    Entrada.manejar(app, "mapa_zona_1")
    local zona = require("compartido.dominio.mapa").zonas(mundo.mapas.mundo)[1]
    fallar(errores, "clic en una zona la centra", Interfaz.mapaZoom >= 3 and math.abs(Interfaz.mapaCx - zona.x) < Datos.MAPA_W / 2)
    -- todas las pestañas se dibujan, con zoom alto (muestra nombres) y la ciudad abierta
    for _, tab in ipairs({ "zonas", "ciudades", "pnj" }) do
      Interfaz.mapaTab = tab
      ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
      fallar(errores, "pestaña " .. tab, ok, tostring(err))
    end
    pj.z = 1
    ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el mapa arriba de una zona elevada", ok, tostring(err))
    Interfaz.panel, Interfaz.mapaZoom, Interfaz.mapaCx, Interfaz.mapaCy = nil, 1, nil, nil
  end)
  paso("interfaz: vida de la montura", function()
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Jinete2", faccion = "albor", clase = "guerrero", nivel = 12 })
    pj.monturas, pj.montado, pj.monturaHp, pj.monturaHpMax = { "buey" }, "buey", 200, 500
    pj.hp = pj.hpMax - 5
    Interfaz.escala = 1
    for _, panel in ipairs({ false, "montura" }) do
      Interfaz.panel = panel or nil
      local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
      fallar(errores, "el HUD con vida de montura se dibuja", ok, tostring(err))
    end
    Interfaz.panel = nil
    local Dibujo = require("src.presentacion.render.dibujo")
    local ok, err = pcall(Dibujo.entidad, { id = "e5", kind = "jugador", clase = "guerrero", faccion = "albor", nombre = "J", x = 5, y = 5, vivo = true,
      montado = "caballo", monturaFrac = 0.4, hp = 50, hpMax = 100 }, 100, 100, mundo, pj)
    fallar(errores, "el jinete con montura herida se dibuja", ok, tostring(err))
  end)
  paso("animación de ataque: criaturas y addons se mueven y vuelven a su sitio", function()
    local Dibujo = require("src.presentacion.render.dibujo")
    local reloj = 50
    Dibujo.relojAtaque = function() return reloj end
    local ok, err = pcall(function()
      for _, base in ipairs({
        { kind = "monstruo", monstruo = "seta_azul", dir = 3 },
        { kind = "jugador", clase = "guerrero", faccion = "albor", addon = "skin_hoplita", dir = 1 },
        { kind = "jugador", clase = "mago", faccion = "umbra", dir = 4, atqL = true },
      }) do
        local e = { id = "t_" .. tostring(base.kind) .. tostring(base.addon or base.clase or base.monstruo), vivo = true, hp = 10, hpMax = 10, atqN = 1, atqX = 1, atqY = 0 }
        for k, v in pairs(base) do e[k] = v end
        reloj = 50
        local st = Dibujo.estadoAtaque(e)
        fallar(errores, "el ataque arranca al ver atqN nuevo", st ~= nil)
        reloj = 50.2
        fallar(errores, "sigue en marcha a mitad del ataque", Dibujo.estadoAtaque(e) ~= nil)
        pcall(love.graphics.push)
        Dibujo.entidad(e, 100, 100, { tiempo = 0, entidades = {} }, nil)
        pcall(love.graphics.pop)
        reloj = 51
        fallar(errores, "el ataque termina", Dibujo.estadoAtaque(e) == nil)
        e.atqN = 2
        reloj = 52
        fallar(errores, "un atqN nuevo vuelve a animar", Dibujo.estadoAtaque(e) ~= nil)
      end
    end)
    Dibujo.relojAtaque = nil
    fallar(errores, "la animación de ataque se dibuja sin errores", ok, tostring(err))
  end)
  paso("interfaz: marquesina y enfriamiento de pociones", function()
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Marq", faccion = "albor", clase = "guerrero", nivel = 10 })
    Interfaz.escala, Interfaz.marq, Interfaz.panel = 1, nil, nil
    mundo.mensajes = {}
    local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el HUD sin avisos se dibuja", ok, tostring(err))
    -- un aviso nuevo entra en la marquesina y avanza hacia la izquierda
    mundo:anunciar("Prueba se anota a Captura del estandarte. Albor 1/3 · Umbra 0/3.")
    pj.cdPociones = { pocion_vida = mundo.tiempo + 2 }
    local xs = {}
    for i = 1, 3 do
      ok, err = pcall(function()
        Interfaz.hud(mundo, pj, 1280, 720)
        Interfaz.marquesina(mundo, pj, 1280, 0.5)
      end)
      fallar(errores, "la marquesina se dibuja", ok, tostring(err))
      xs[i] = Interfaz.marq.actual and Interfaz.marq.actual.x
    end
    fallar(errores, "el texto avanza de derecha a izquierda", xs[1] and xs[2] and xs[3] and xs[1] > xs[2] and xs[2] > xs[3], tostring(xs[1]) .. "," .. tostring(xs[3]))
    fallar(errores, "empieza por el borde derecho", xs[1] > 640)
    -- al terminar de cruzar desaparece y deja pasar al siguiente
    mundo:anunciar("Otro aviso")
    for _ = 1, 80 do pcall(Interfaz.marquesina, mundo, pj, 1280, 0.5) end
    fallar(errores, "no se repiten los avisos ya mostrados", Interfaz.marq.actual == nil and #Interfaz.marq.cola == 0)
    Interfaz.marq = nil
  end)
  paso("interfaz: fondos de inicio de sesión y registro", function()
    for _, modo in ipairs({ "entrar", "crear" }) do
      local ok, err = pcall(Interfaz.cuenta, { modo = modo, usuario = "", clave = "", error = "" }, 1280, 720)
      fallar(errores, "la pantalla de " .. modo .. " se dibuja", ok, tostring(err))
    end
  end)
  paso("interfaz: pestaña de eventos del chat", function()
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Pest", faccion = "albor", clase = "guerrero" })
    mundo.mensajes = {}
    mundo:mensaje("mundo", "Z", "charla", nil)
    mundo:avisoEvento("mundo", "", "La batalla empieza a las 21:00", nil)
    Interfaz.escala, Interfaz.panel = 1, nil
    for _, canal in ipairs({ "todo", "evento", "mundo" }) do
      Interfaz.canal = canal
      local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
      fallar(errores, "el chat se dibuja en la pestaña " .. canal, ok, tostring(err))
    end
    local lado, consola = Interfaz.medidas()
    local hallado = false
    for x = 8, 700, 6 do if Interfaz.consumir(x, 720 - Interfaz.CHAT_ALTO + 12) == "canal_evento" then hallado = true end end
    fallar(errores, "la pestaña Eventos recibe clics", hallado)
    Interfaz.canal = "todo"
  end)
  paso("interfaz: tecla M y viaje con clic en el mapa", function()
    local Entrada = require("src.presentacion.entrada")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Viaja", faccion = "albor", clase = "guerrero", nivel = 10 })
    local llamadas = {}
    local app = { jugador = pj, mundo = mundo, estado = "juego", zoom = 1, actuar = function(n, d) llamadas[#llamadas + 1] = { n, d } end }
    Interfaz.escala, Interfaz.panel, Interfaz.foco = 1, nil, nil
    Entrada.tecla(app, "m")
    fallar(errores, "M abre el mapa", Interfaz.panel == "mapa")
    Entrada.tecla(app, "m")
    fallar(errores, "M lo cierra", Interfaz.panel == nil)
    Entrada.tecla(app, "m")
    local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el mapa se dibuja", ok, tostring(err))
    local g = Interfaz.mapaGeom
    -- clic corto en el centro del mapa: manda al personaje a ese sitio
    local esc = Interfaz.escala or 1
    local sc = g.s0 * (Interfaz.mapaZoom or 1)
    local wx, wy = pj.x + 30, pj.y - 20
    local mx = (g.ax + g.aw / 2) + (wx - Interfaz.mapaCx) * sc * esc
    local my = (g.ay + g.ah / 2) + (wy - Interfaz.mapaCy) * sc * esc
    Entrada.raton(app, mx, my, 1)
    Entrada.soltarRaton(app, mx, my)
    local destino
    for _, l in ipairs(llamadas) do if l[1] == "destino" then destino = l[2] end end
    fallar(errores, "el clic en el mapa viaja al sitio", destino and math.abs(destino.x - wx) < 2 and math.abs(destino.y - wy) < 2,
      destino and (destino.x .. "," .. destino.y) or "sin destino")
    fallar(errores, "queda marcado el destino", Interfaz.mapaDestino ~= nil)
    ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el mapa dibuja la cruz del destino", ok, tostring(err))
    -- arrastrar no viaja
    llamadas = {}
    Entrada.raton(app, mx, my, 1)
    Entrada.moverRaton(app, mx + 40, my + 20, 40, 20)
    Entrada.soltarRaton(app, mx + 40, my + 20)
    local viajo = false
    for _, l in ipairs(llamadas) do if l[1] == "destino" then viajo = true end end
    fallar(errores, "arrastrar el mapa no viaja", not viajo)
    -- el mar y otros continentes no se alcanzan a pie
    Interfaz.mapaDestino = nil
    llamadas = {}
    local cx2, cy2 = mundo.mapas.mundo.w / 2, mundo.mapas.mundo.h / 2
    local mx2 = (g.ax + g.aw / 2) + (cx2 - Interfaz.mapaCx) * sc * esc
    local my2 = (g.ay + g.ah / 2) + (cy2 - Interfaz.mapaCy) * sc * esc
    Entrada.raton(app, mx2, my2, 1)
    Entrada.soltarRaton(app, mx2, my2)
    local fue = false
    for _, l in ipairs(llamadas) do if l[1] == "destino" then fue = true end end
    fallar(errores, "no se viaja a pie a otro continente", not fue and Interfaz.aviso and Interfaz.aviso:find("otro continente"), tostring(Interfaz.aviso))
    Interfaz.panel, Interfaz.mapaDestino = nil, nil
  end)
  paso("interfaz: alertas de invitación y ventana de comercio", function()
    local Entrada = require("src.presentacion.entrada")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Yo", faccion = "albor", clase = "guerrero", nivel = 12 })
    local otro = mundo:crearPersonaje({ nombre = "Otro", faccion = "albor", clase = "guerrero", nivel = 12 })
    local llamadas = {}
    local app = { jugador = pj, mundo = mundo, estado = "juego", zoom = 1, actuar = function(n, d) llamadas[#llamadas + 1] = { n, d } end }
    Interfaz.escala, Interfaz.panel, Interfaz.foco = 1, nil, nil
    local function clic(id)
      llamadas = {}
      Entrada.manejar(app, id)
      return llamadas[1]
    end
    local function hallar(id, x0, y0, x1, y1)
      for y = y0, y1, 4 do for x = x0, x1, 4 do if Interfaz.consumir(x, y) == id then return x, y end end end
    end
    -- alertas: cada invitación sale encima de todo con sus dos botones
    for _, caso in ipairs({
      { campo = "invComercio", valor = { de = "Otro", hasta = mundo.tiempo + 20 }, si = "com_acepta", no = "com_rechaza", accion = "comercio_responder" },
      { campo = "invGremio", valor = { de = "Otro", nombre = "Probados", hasta = mundo.tiempo + 20 }, si = "gr_acepta", no = "gr_rechaza", accion = "gremio_responder" },
      { campo = "invGrupo", valor = { nombre = "Otro" }, si = "gp_acepta", no = "gp_rechaza", accion = "grupo_responder" },
    }) do
      pj.invComercio, pj.invGremio, pj.invGrupo = nil, nil, nil
      pj[caso.campo] = caso.valor
      local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
      fallar(errores, "se dibuja la alerta " .. caso.campo, ok, tostring(err))
      local xs, ys = hallar(caso.si, 300, 200, 1000, 500)
      local xn, yn = hallar(caso.no, 300, 200, 1000, 500)
      fallar(errores, "la alerta " .. caso.campo .. " tiene Aceptar y Rechazar", xs and xn)
      Entrada.manejar(app, caso.si)
      local l = llamadas[#llamadas]
      fallar(errores, "Aceptar manda la respuesta", true)
      local lc = clic(caso.si)
      fallar(errores, "Aceptar de " .. caso.campo, lc and lc[1] == caso.accion and lc[2].acepta == true)
      lc = clic(caso.no)
      fallar(errores, "Rechazar de " .. caso.campo, lc and lc[1] == caso.accion and lc[2].acepta == false)
      -- la alerta tapa lo de debajo: un clic fuera no atraviesa
      fallar(errores, "la alerta es modal", Interfaz.consumir(40, 300) == "alerta_fondo")
    end
    pj.invComercio, pj.invGremio, pj.invGrupo = nil, nil, nil
    -- comercio: se abre solo, con lista desplazable, oro validado y bolsa propia
    pj.oro = 250
    pj.bolsa = {}
    for i = 1, 10 do pj.bolsa[i] = { id = i % 2 == 0 and "pocion_vida" or "pocion_mana", cant = i } end
    local items = {}
    for i = 1, 14 do items[i] = { id = "pocion_vida", cant = i } end
    mundo.sesiones = { s1 = { id = "s1", a = pj.id, b = otro.id, oferta = {
      [pj.id] = { oro = 50, items = items, ok = false },
      [otro.id] = { oro = 0, items = {}, ok = true },
    } } }
    pj.sesion = "s1"
    mundo.entidades[otro.id] = otro
    local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el comercio se abre al empezar el trato", ok and Interfaz.panel == "comercio", tostring(err))
    local bx, by = hallar("com_bolsa_3", 40, 300, 1240, 700)
    fallar(errores, "tu bolsa está dentro de la ventana", bx ~= nil)
    local lc = clic("com_bolsa_3")
    fallar(errores, "clic en la bolsa ofrece el objeto", lc and lc[1] == "comercio_item" and lc[2].i == 3)
    fallar(errores, "hay botón de quitar por objeto", hallar("com_quitar_1", 40, 150, 900, 450) ~= nil)
    lc = clic("com_quitar_2")
    fallar(errores, "quitar devuelve el objeto", lc and lc[1] == "comercio_quitar" and lc[2].i == 2)
    -- la lista se desplaza con la rueda (14 objetos, caben 6)
    local primero = Interfaz.comListaA ~= nil
    fallar(errores, "la lista tiene zona de rueda", primero)
    Interfaz.comScrollA = 8
    ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "la lista se dibuja desplazada", ok and Interfaz.comScrollA == 8, tostring(err))
    fallar(errores, "al bajar aparecen los últimos", hallar("com_quitar_14", 40, 150, 900, 450) ~= nil and hallar("com_quitar_1", 40, 150, 900, 450) == nil)
    Interfaz.comScrollA = 99
    pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el desplazamiento tiene tope", Interfaz.comScrollA == 8, tostring(Interfaz.comScrollA))
    -- oro: solo cifras y nunca más de lo que tienes (250 + 50 ya ofrecidos = 300)
    Interfaz.foco, Interfaz.comOro = "com_oro", ""
    for _, c in ipairs({ "a", "-", "9", "9", "9", "9" }) do Entrada.texto(app, c) end
    fallar(errores, "solo admite cifras y se limita a lo que tienes", Interfaz.comOro == "300", Interfaz.comOro)
    Interfaz.comOro = "120"
    llamadas = {}
    Entrada.tecla(app, "return")
    local l2 = llamadas[1]
    fallar(errores, "Intro envía el oro", l2 and l2[1] == "comercio_oro" and l2[2].oro == 120 and Interfaz.foco == nil)
    Interfaz.comOro = "999999"
    Entrada.fijarOroComercio(app)
    fallar(errores, "aunque se fuerce un valor, se recorta al máximo", llamadas[#llamadas][2].oro == 300, tostring(llamadas[#llamadas][2].oro))
    lc = clic("com_oro_todo")
    fallar(errores, "el botón Todo ofrece todo", lc and lc[1] == "comercio_oro" and lc[2].oro == 300)
    -- al terminar el trato se cierra la ventana
    pj.sesion = nil
    pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "la ventana se cierra al terminar", Interfaz.panel == nil)
    Interfaz.panel, Interfaz.foco, Interfaz.comSesionAbierta = nil, nil, nil
  end)
  paso("campo de batalla: sprites propios y login", function()
    local Terreno = require("src.presentacion.render.terreno")
    local Campo = require("src.presentacion.render.campo")
    local Objetos = require("src.presentacion.render.objetos")
    local mundo = Mundo.nuevo()
    mundo:usarBatallaClasica()
    local mapa = mundo.mapas.batalla
    local ok, err = pcall(function()
      Terreno.dibujar(mapa, 20 * 32, 12 * 32, 1280, 720, 0)
      Terreno.dibujar(mapa, 60 * 32, 30 * 32, 1280, 720, 0)
    end)
    fallar(errores, "el terreno del campo de batalla se dibuja con sus decoraciones", ok, tostring(err))
    local tipos = {}
    for _, col in pairs(mapa.decorado) do for _, t in pairs(col) do tipos[t] = (tipos[t] or 0) + 1 end end
    fallar(errores, "hay variedad de decoración (no se ve plano)", (tipos.piedra or 0) > 0 and (tipos.grieta or 0) > 0 and (tipos.mancha or 0) > 20
      and (tipos.guijarros or 0) > 10 and (tipos.grietita or 0) > 5 and (tipos.brasas or 0) > 3, require("compartido.infraestructura.log") and "")
    local props = 0
    for _, p in ipairs(mapa.props) do
      if Objetos.personalizados[p.tipo] then
        props = props + 1
        local ok2, err2 = pcall(Objetos.personalizados[p.tipo], p, 100, 100)
        fallar(errores, "el risco se dibuja", ok2, tostring(err2))
      end
    end
    fallar(errores, "hay riscos con sprite propio", props > 10)
    local ok3, err3 = pcall(function()
      for _, t in ipairs({ "piedra", "mancha", "brasas", "guijarros", "grietita", "restos", "grieta" }) do
        Campo.decoracion(mapa, t, 30, 20, 100, 100)
      end
    end)
    fallar(errores, "todas las decoraciones se pintan", ok3, tostring(err3))
    -- login: se recuerda el usuario y Tab salta de campo
    local Entrada = require("src.presentacion.entrada")
    local Ajustes = require("src.presentacion.ajustes")
    local app = { estado = "menu", cuenta = { modo = "entrar", usuario = "", clave = "", error = "" }, actuar = function() end,
      sesion = { personajes = {} } }
    Ajustes.ultimoUsuario = "Recordado"
    Entrada.manejar(app, "menu_entrar")
    fallar(errores, "el login recuerda el último usuario y va a la clave", app.cuenta.usuario == "Recordado" and Interfaz.foco == "clave")
    Entrada.tecla(app, "tab")
    fallar(errores, "Tab pasa de la clave al usuario", Interfaz.foco == "usuario")
    Entrada.tecla(app, "tab")
    fallar(errores, "y de vuelta a la clave", Interfaz.foco == "clave")
    Entrada.manejar(app, "menu_registro")
    fallar(errores, "el registro empieza vacío", app.cuenta.usuario == "" and Interfaz.foco == "usuario")
    Interfaz.foco = nil
  end)
  paso("interfaz: los poderes de área se apuntan en la zona habilitada", function()
    local Entrada = require("src.presentacion.entrada")
    local Dibujo = require("src.presentacion.render.dibujo")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Mago", faccion = "albor", clase = "mago", nivel = 20 })
    pj.habilidades.meteoro, pj.habilidades.nova = 1, 1
    pj.mp, pj.mpMax, pj.cds = 9999, 9999, {}
    local llamadas = {}
    local app = { jugador = pj, mundo = mundo, estado = "juego", zoom = 1, actuar = function(n, d) llamadas[#llamadas + 1] = { n, d } end }
    local function slotDe(id) for i, h in ipairs(Datos.barra.mago) do if h == id then return i end end end
    Entrada.lanzarHabilidad(app, slotDe("nova"))
    fallar(errores, "la nova (ventisca) se apunta en una zona sin lanzarse", #llamadas == 0 and app.apuntando and app.apuntando.slot == slotDe("nova") and app.apuntando.aoe > 2)
    app.apuntando = nil
    llamadas = {}
    Entrada.lanzarHabilidad(app, slotDe("meteoro"))
    fallar(errores, "el meteoro entra en modo apuntar sin lanzarse", #llamadas == 0 and app.apuntando and app.apuntando.slot == slotDe("meteoro")
      and app.apuntando.rango > 5 and app.apuntando.aoe > 2)
    -- la zona habilitada y el área bajo el cursor se dibujan
    Dibujo.apuntando = app.apuntando
    local cam = Dibujo.camara(pj, 1, mundo:mapaDe(pj))
    local mx, my = 300, 300
    local ok, err = pcall(Dibujo.escena, mundo, pj, cam, mx, my)
    fallar(errores, "la zona de apuntado se dibuja", ok, tostring(err))
    local dueno = mundo:crearPersonaje({ nombre = "Dueno", faccion = "albor", clase = "guerrero", nivel = 10, oro = 150000 })
    local auroria
    for _, c in ipairs(mundo.mapas.mundo.ciudades) do if c.id == "auroria" then auroria = c end end
    local par = auroria.parcelas[1]
    dueno.x, dueno.y = auroria.spawn.x, auroria.spawn.y
    mundo:accion(dueno.id, "casa_comprar", { id = par.id })
    local camCasa = Dibujo.camara(dueno, 1, mundo:mapaDe(dueno))
    ok, err = pcall(Dibujo.escena, mundo, dueno, camCasa, 200, 200)
    fallar(errores, "la casa propia se tiñe en la calle", ok, tostring(err))
    dueno.x, dueno.y = par.x + 0.5, par.y + 1.2
    mundo:accion(dueno.id, "casa_entrar", { id = par.id })
    mundo:accion(dueno.id, "mueble", { tipo = "mesa" })
    Dibujo.muebleElegido = "mesa"
    camCasa = Dibujo.camara(dueno, 1, mundo:mapaDe(dueno))
    ok, err = pcall(Dibujo.escena, mundo, dueno, camCasa, 200, 200)
    fallar(errores, "el interior dibuja la puerta y los muebles", ok and mundo:interior(dueno).puerta ~= nil, tostring(err))
    Dibujo.muebleElegido = nil
    -- vista isométrica: la proyección y su inversa coinciden, el ratón apunta a la casilla que se ve y las teclas van según la pantalla
    local Iso = require("src.presentacion.render.iso")
    local camI = Dibujo.camara(pj, 1.5, mundo:mapaDe(pj))
    for _, par in ipairs({ { 10.5, 20.5 }, { 120.25, 7.75 }, { 0, 0 } }) do
      local gx, gy = Iso.suelo(par[1], par[2])
      local bx, by = Iso.inversa(gx, gy)
      fallar(errores, "la proyección tiene inversa", math.abs(bx - par[1]) < 1e-6 and math.abs(by - par[2]) < 1e-6)
      local sx, sy = Dibujo.mundoAPantalla(camI, par[1], par[2])
      local wx, wy = Dibujo.pantallaAMundo(camI, sx, sy)
      fallar(errores, "el ratón apunta a la casilla dibujada", math.abs(wx - par[1]) < 1e-6 and math.abs(wy - par[2]) < 1e-6)
    end
    if Iso.activo() then
      fallar(errores, "x crece hacia abajo a la derecha", select(1, Iso.suelo(11, 10)) > select(1, Iso.suelo(10, 10)) and select(2, Iso.suelo(11, 10)) > select(2, Iso.suelo(10, 10)))
      fallar(errores, "y crece hacia abajo a la izquierda", select(1, Iso.suelo(10, 11)) < select(1, Iso.suelo(10, 10)) and select(2, Iso.suelo(10, 11)) > select(2, Iso.suelo(10, 10)))
      fallar(errores, "mirada según la pantalla", Iso.dirPantalla(1, 1) == 1 and Iso.dirPantalla(-1, -1) == 2 and Iso.dirPantalla(1, -1) == 3 and Iso.dirPantalla(-1, 1) == 4)
    end
    -- ambiente gráfico: cada nivel de calidad, hora y clima dibuja sin errores, también dentro de la casa y en la mazmorra
    local Ambiente = require("src.presentacion.render.ambiente")
    local Ajustes = require("src.presentacion.ajustes")
    local previoGraficos, previoHora, previoClima = Ajustes.graficos, Ambiente.horaFija, Ambiente.climaFijo
    for _, nivel in ipairs(Ambiente.NIVELES) do
      for _, hora in ipairs({ 2, 7, 12, 19, 22 }) do
        for _, clima in ipairs({ "despejado", "lluvia", "nieve", "tormenta", "niebla" }) do
          Ajustes.graficos, Ambiente.horaFija, Ambiente.climaFijo = nivel, hora, clima
          local camA = Dibujo.camara(pj, 1, mundo:mapaDe(pj))
          local okA, errA = pcall(Dibujo.escena, mundo, pj, camA, 300, 300)
          fallar(errores, "ambiente " .. nivel .. " " .. hora .. "h " .. clima, okA, tostring(errA))
        end
      end
    end
    Ajustes.graficos, Ambiente.horaFija, Ambiente.climaFijo = "alto", 21, "despejado"
    camCasa = Dibujo.camara(dueno, 1, mundo:mapaDe(dueno))
    local okC, errC = pcall(Dibujo.escena, mundo, dueno, camCasa, 200, 200)
    fallar(errores, "ambiente dentro de la casa", okC, tostring(errC))
    Ajustes.graficos, Ambiente.horaFija, Ambiente.climaFijo = previoGraficos, previoHora, previoClima
    fallar(errores, "la calidad gráfica cambia de nivel en nivel", (function()
      Ajustes.graficos = "alto"
      local a = Ambiente.siguienteNivel()
      local b = Ambiente.siguienteNivel()
      local c = Ambiente.siguienteNivel()
      local d = Ambiente.siguienteNivel()
      Ajustes.graficos = previoGraficos
      return a == "medio" and b == "bajo" and c == "apagado" and d == "alto"
    end)())
    -- el punto de impacto nunca sale de la zona habilitada
    local ix, iy, fuera = Dibujo.puntoApuntado(app.apuntando, pj, cam, 5, 5)
    local d = math.sqrt((ix - pj.x) ^ 2 + (iy - pj.y) ^ 2)
    fallar(errores, "el punto de impacto se limita al alcance", d <= app.apuntando.rango + 0.01, tostring(d))
    -- clic izquierdo lanza el poder; clic derecho o Esc lo cancelan
    Entrada.clicMundo(app, 300, 300, 1)
    local l = llamadas[#llamadas]
    fallar(errores, "el clic lanza el poder con su punto", l and l[1] == "habilidad" and l[2].slot == slotDe("meteoro") and app.apuntando == nil)
    llamadas = {}
    Entrada.lanzarHabilidad(app, slotDe("meteoro"))
    Entrada.clicMundo(app, 300, 300, 2)
    fallar(errores, "el clic derecho cancela", app.apuntando == nil and #llamadas == 0)
    Entrada.lanzarHabilidad(app, slotDe("meteoro"))
    Entrada.tecla(app, "escape")
    fallar(errores, "Esc cancela", app.apuntando == nil and #llamadas == 0)
    -- pulsar otra vez la tecla lo lanza
    Entrada.lanzarHabilidad(app, slotDe("meteoro"))
    Entrada.lanzarHabilidad(app, slotDe("meteoro"))
    fallar(errores, "pulsar de nuevo el poder lo lanza", llamadas[1] and llamadas[1][1] == "habilidad" and app.apuntando == nil)
    -- en enfriamiento no se entra en modo apuntar (el servidor avisará)
    llamadas = {}
    pj.cds[Datos.barra.mago[slotDe("meteoro")]] = mundo.tiempo + 20
    Entrada.lanzarHabilidad(app, slotDe("meteoro"))
    fallar(errores, "en enfriamiento no se apunta", app.apuntando == nil and llamadas[1] and llamadas[1][1] == "habilidad")
    Dibujo.apuntando = nil
  end)  paso("skins de jinetes con casillas de 48 px", function()
    local P = require("src.presentacion.render.personajes")
    local Arte = require("src.presentacion.render.arte")
    local grandes = 0
    for id, def in pairs(P.skins) do
      if def.celda == 48 then
        grandes = grandes + 1
        -- (con arma dibujada por código la hoja es la generada: 3 x 4 cuadros de 48 px)
        if def.hoja then
          local img = Arte.img(def.hoja)
          local bloqueW, bloqueH = 48 * 3, 48 * 4
          local dentro = (def.idx % 4 + 1) * bloqueW <= img:getWidth() and (math.floor(def.idx / 4) + 1) * bloqueH <= img:getHeight()
          fallar(errores, id .. " está dentro de la hoja", dentro)
        end
        local ok, err = pcall(P.dibujar, def, 1, false, 0, 100, 100)
        fallar(errores, id .. " se dibuja", ok, tostring(err))
        fallar(errores, id .. " devuelve el alto del cuadro", select(2, pcall(P.dibujar, def, 3, true, 0.3, 100, 100)) == 48)
      end
    end
    fallar(errores, "hay 8 skins de jinete", grandes == 8, tostring(grandes))
  end)
  paso("todas las criaturas tienen sprite", function()
    local P = require("src.presentacion.render.personajes")
    local Arte = require("src.presentacion.render.arte")
    local MobAnim = require("src.presentacion.render.mob_anim")
    local faltan = {}
    local CUADROS = { wait = 15, run = 30, att = 20, hurt = 10, dead = 30 }
    for _, m in ipairs(Datos.monstruos) do
      local d = P.monstruos[m.id]
      local def = MobAnim.DEFS[m.id]
      if not d or not d.anim or not def then faltan[#faltan + 1] = m.id .. "(sin dibujo)"
      else
        -- las cinco tiras existen y su ancho es múltiplo de sus cuadros (y de 5 direcciones si las trae)
        for tipo, n in pairs(CUADROS) do
          local ruta = "arte/monstruos/" .. def.carpeta .. "/" .. tipo .. ".png"
          if not love.filesystem.getInfo(ruta) then faltan[#faltan + 1] = m.id .. "(" .. tipo .. ")"
          else
            local w = love.graphics.newImage(ruta):getWidth()
            local celdas = def.dirs2 and (n * 2 / 5) or n
            if w % celdas ~= 0 then faltan[#faltan + 1] = m.id .. "(" .. tipo .. " ancho)" end
          end
        end
        -- cada estado y cada dirección se dibujan sin error
        for _, estado in ipairs({ "wait", "run", "att", "hurt" }) do
          for dir = 1, 4 do
            local ok = pcall(MobAnim.dibujar, m.id, estado, 0.5, 100, 100, dir, nil, 0)
            if not ok then faltan[#faltan + 1] = m.id .. "(" .. estado .. dir .. ")" end
          end
        end
        if not pcall(MobAnim.muerto, m.id, 0.5, 100, 100, 1, 1) then faltan[#faltan + 1] = m.id .. "(muerto)" end
        if not (def.alto and def.alto >= 20 and def.escala and def.escala > 0.1 and def.escala < 3) then faltan[#faltan + 1] = m.id .. "(tamaño)" end
      end
    end
    fallar(errores, "cada criatura tiene sus cinco animaciones y se dibuja en cualquier estado y dirección", #faltan == 0, table.concat(faltan, ", "))
    -- los jefes del mundo llevan aura y son más grandes que cualquier criatura normal
    local mayorNormal = 0
    for _, m in ipairs(Datos.monstruos) do
      if not m.elite and not m.categoria and not m.id:find("^jefe_") and MobAnim.DEFS[m.id] then mayorNormal = math.max(mayorNormal, MobAnim.DEFS[m.id].alto) end
    end
    local pequenos = {}
    for _, m in ipairs(Datos.monstruos) do
      if m.jefeMundo and not (MobAnim.DEFS[m.id].aura and MobAnim.DEFS[m.id].alto >= mayorNormal + 20) then pequenos[#pequenos + 1] = m.id end
    end
    fallar(errores, "los jefes del mundo llevan aura y se ven mayores que las criaturas normales", #pequenos == 0, table.concat(pequenos, ", "))
  end)
  paso("interfaz: los botones del mall mandan la acción correcta", function()
    local Entrada = require("src.presentacion.entrada")
    local Mall = require("compartido.dominio.mall")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Compra", faccion = "albor", clase = "guerrero", nivel = 10 })
    local llamadas = {}
    local app = { jugador = pj, mundo = mundo, estado = "juego", actuar = function(n, d) llamadas[#llamadas + 1] = { n, d } end }
    local function clic(id) llamadas = {} Entrada.manejar(app, id) return llamadas[1] end
    local l = clic("mall_buy_pergamino_atk")
    fallar(errores, "comprar un objeto", l and l[1] == "mall_comprar" and l[2].id == "pergamino_atk")
    l = clic("mall_ad_buy_skin_rey")
    fallar(errores, "comprar un addon manda mall_addon_comprar con su id", l and l[1] == "mall_addon_comprar" and l[2].id == "skin_rey", l and (l[1] .. "/" .. tostring(l[2].id)) or "nada")
    l = clic("mall_ad_skin_rey")
    fallar(errores, "poner o quitar un addon manda mall_addon", l and l[1] == "mall_addon" and l[2].id == "skin_rey")
    local bien = true
    for _, id in ipairs(Mall.ORDEN_ADDONS) do
      local c = clic("mall_ad_buy_" .. id)
      if not (c and c[1] == "mall_addon_comprar" and c[2].id == id) or #id > 24 then bien = false end
    end
    fallar(errores, "cada addon se compra desde su botón con el id completo", bien)
  end)
  -- Apariencias (PD de FAO): 10 sets completos, cada uno con las seis ranuras (cabeza, pecho, manos, pies, espalda y arma de cada familia) para los dos géneros.
  -- Con DC_PRUEBA_APARIENCIAS=1 guarda juego/capturas/apariencias.png (una fila por set, los seis oficios) y apariencias_mall.png (la pestaña del Item Mall).
  paso("apariencias PD: sets completos, dibujo en los seis oficios y pestaña del mall", function()
    local Fao = require("src.presentacion.render.fao")
    local Mall = require("compartido.dominio.mall")
    local datosAp = require("src.presentacion.render.fao_datos_apariencias")
    local ids = {}
    for _, id in ipairs(Mall.ORDEN_ADDONS) do if id:sub(1, 3) == "pd_" then ids[#ids + 1] = id end end
    fallar(errores, "hay 30 sets de apariencia en el mall con precio", #ids == 30 and Mall.ADDONS[ids[1]].precio > 0, tostring(#ids))
    local famil = { "espada", "hacha", "lanza", "arco", "baston", "maza", "baculo" }
    for _, id in ipairs(ids) do
      local set = datosAp.sets[id]
      fallar(errores, id .. " tiene datos", set ~= nil)
      for _, g in ipairs({ "h", "m" }) do
        local f = set and set[g] or {}
        local completo = f.cabeza and f.pecho and f.piernas and f.pies and f.espalda and f.arma
        for _, fam in ipairs(famil) do completo = completo and f.arma and f.arma[fam] end
        fallar(errores, id .. " (" .. g .. ") tiene todas las ranuras", completo and true or false)
      end
    end
    Fao.forzar(nil)
    fallar(errores, "las capas de FAO están activas", Fao.activo())
    local clases = { "guerrero", "lancero", "cazador", "mago", "clerigo", "nigromante" }
    local vista = os.getenv("DC_PRUEBA_APARIENCIAS") ~= nil
    local CW, CH = 220, 260
    local cv = love.graphics.newCanvas(CW * #clases, CH * #ids)
    local ok, err = pcall(function()
      love.graphics.setCanvas({ cv, stencil = true })
      love.graphics.clear(0.25, 0.3, 0.38, 1)
      for r, id in ipairs(ids) do
        for c, clase in ipairs(clases) do
          local e = { id = "ap", kind = "jugador", clase = clase, genero = (c % 2 == 0) and "m" or "h", addon = id, x = 5, y = 5, vivo = true, dir = 1, equipo = {} }
          e._f8 = (c % 3 == 0) and 6 or 2          -- (algunos de espaldas, para ver las alas y la capa por delante)
          love.graphics.push()
          love.graphics.translate((c - 0.5) * CW, r * CH - 20)
          love.graphics.scale(2.4, 2.4)
          Fao.dibujar(e, false, 0, 0, nil, 1, { anim = "wait", paso = 0, d5 = (c % 3 == 0) and 1 or 0 })
          love.graphics.pop()
        end
      end
      love.graphics.setCanvas()
    end)
    love.graphics.setCanvas()
    fallar(errores, "los sets se dibujan en los seis oficios y los dos géneros", ok, tostring(err))
    if vista then Log.volcar("capturas/apariencias.png", cv:newImageData():encode("png"):getString()) end
    -- la pestaña del Item Mall
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Moda", faccion = "albor", clase = "guerrero", nivel = 20 })
    pj.mall = { monedas = 3000, addons = { ids[1] }, addonActivo = ids[1] }
    local pan = love.graphics.newCanvas(1280, 720)
    love.graphics.push("all")
    love.graphics.setCanvas({ pan, stencil = true })
    love.graphics.clear(0.1, 0.1, 0.12, 1)
    local Interfaz = require("src.presentacion.interfaz")
    Interfaz.escala, Interfaz.panel, Interfaz.mallTab, Interfaz.mallScroll = 1, "mall", "addons", 0
    local okm, errm = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    love.graphics.pop()
    fallar(errores, "la pestaña Apariencia se dibuja: " .. tostring(errm), okm)
    if vista then Log.volcar("capturas/apariencias_mall.png", pan:newImageData():encode("png"):getString()) end
    Interfaz.panel = nil
  end)
  -- Los diez efectos de las clases con paquete HD (nigromante, guerrero, mago y cazador) sobre un fondo liso, con el lanzador a la izquierda y un blanco a la
  -- derecha. Con DC_PRUEBA_NECRO=1 guarda juego/capturas/<clase>_poderes.png (una fila por poder, cuatro instantes).
  for _, clase in ipairs({ "nigromante", "guerrero", "mago", "cazador" }) do
  paso(clase .. ": los diez efectos de capas se dibujan", function()
    local Capas = require("src.presentacion.render.efectos_fao_capas")
    local Poderes = require("compartido.datos.efectos_fao_poderes")
    local Fao = require("src.presentacion.render.fao")
    local vista = os.getenv("DC_PRUEBA_NECRO") ~= nil
    local CW, CH = 380, 250
    local cv = love.graphics.newCanvas(CW * 4, CH * #Datos.barra[clase])
    local ok, err = pcall(function()
      love.graphics.setCanvas(cv)
      love.graphics.clear(0.36, 0.52, 0.3, 1)
      for fila, id in ipairs(Datos.barra[clase]) do
        fallar(errores, id .. " tiene capas de efecto", Poderes[id] ~= nil and #Poderes[id].capas >= 1)
        for k, frac in ipairs({ 0.15, 0.3, 0.5, 0.75 }) do
          local ox, oy = (k - 1) * CW, (fila - 1) * CH
          love.graphics.push("all")
          love.graphics.setScissor(ox, oy, CW, CH)
          love.graphics.translate(ox, oy)
          local sx, sy = 270, 190
          local fx = { x = 14, y = 10, x0 = 9, y0 = 10 }
          local t = Poderes[id].dur * frac
          Capas.dibujar(id, fx, t, sx, sy, "suelo")
          love.graphics.setColor(1, 1, 1, 1)
          Fao.retrato(clase, "h", nil, 90, 190, 1.6)
          love.graphics.setColor(0.8, 0.4, 0.4, 1)
          love.graphics.ellipse("fill", sx, sy - 14, 12, 18)
          Capas.dibujar(id, fx, t, sx, sy, "cuerpo")
          love.graphics.pop()
        end
      end
      love.graphics.setCanvas()
    end)
    love.graphics.setCanvas()
    fallar(errores, "los efectos de " .. clase .. " se dibujan: " .. tostring(err), ok)
    if vista then Log.volcar("capturas/" .. clase .. "_poderes.png", cv:newImageData():encode("png"):getString()) end
  end)
  end
  -- Panel Personaje con el muñeco: una casilla por tipo de pieza y la ficha de la pieza bajo el ratón. Con DC_PRUEBA_PERSONAJE=1 guarda juego/capturas/personaje_panel.png
  -- (con la ficha del arma de calidad definitiva) y personaje_panel_sin_ficha.png.
  paso("panel del personaje: casillas por tipo de pieza y ficha al pasar el ratón", function()
    local Interfaz = require("src.presentacion.interfaz")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Hullalok", faccion = "umbra", clase = "cazador", nivel = 14 })
    pj.mall = { monedas = 1682, addons = {} }
    for hueco, id in pairs({ arma = "cazador_arma_3_s", cabeza = "cazador_cabeza_3", pecho = "cazador_pecho_3_b", piernas = "cazador_piernas_3", pies = "cazador_pies_3",
      anillo = "anillo_1", amuleto = "amuleto_1", mochila = "mochila_2" }) do
      if Datos.item(id) then pj.equipo[hueco] = id end
    end
    pj.encantos = { arma = 3 }
    mundo:recalcular(pj)
    local vista = os.getenv("DC_PRUEBA_PERSONAJE") ~= nil
    local viejo = love.mouse.getPosition
    local function foto(nombre, mx, my)
      love.mouse.getPosition = function() return mx, my end
      local cv = love.graphics.newCanvas(1280, 720)
      love.graphics.push("all")
      love.graphics.setCanvas({ cv, stencil = true })
      love.graphics.clear(0.18, 0.2, 0.16, 1)
      Interfaz.escala, Interfaz.panel = 1, "equipo"
      local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
      love.graphics.pop()
      love.mouse.getPosition = viejo
      fallar(errores, "el panel del personaje se dibuja (" .. nombre .. "): " .. tostring(err), ok)
      if vista then Log.volcar("capturas/" .. nombre .. ".png", cv:newImageData():encode("png"):getString()) end
    end
    foto("personaje_panel_sin_ficha", 5, 5)
    -- las casillas del muñeco: 9 y cada una quita su pieza
    local n = 0
    for _, hueco in ipairs({ "cabeza", "pecho", "piernas", "pies", "arma", "escudo", "anillo", "amuleto", "mochila" }) do
      local hallada = false
      for yy = 130, 600, 6 do
        for xx = 480, 940, 6 do
          if Interfaz.consumir(xx, yy) == "equip_" .. hueco then hallada = true end
        end
      end
      if hallada then n = n + 1 end
    end
    fallar(errores, "el muñeco ofrece una casilla por cada tipo de pieza", n == 9, tostring(n))
    -- el ratón sobre la casilla del arma (derecha, arriba)
    local armaX, armaY
    for yy = 130, 460, 4 do
      for xx = 700, 940, 4 do
        if not armaX and Interfaz.consumir(xx, yy) == "equip_arma" then armaX, armaY = xx, yy end
      end
    end
    foto("personaje_panel", armaX or 800, armaY or 160)
    -- ropero de apariencias: seis ranuras, cada una con la pieza de un set distinto
    pj.mall = { monedas = 1682, addons = { "pd_marfil", "pd_zafiro", "pd_dorado" }, aparienciaSlots = { cabeza = "pd_marfil", pecho = "pd_zafiro", arma = "pd_dorado" } }
    Interfaz.personajeTab, Interfaz.ropero = "apariencia", "pecho"
    foto("personaje_ropero_sin_ratón", 5, 5)
    local ranuras = 0
    for _, r in ipairs({ "cabeza", "pecho", "piernas", "pies", "espalda", "arma" }) do
      local hallada = false
      for yy = 130, 600, 6 do
        for xx = 480, 940, 6 do
          if Interfaz.consumir(xx, yy) == "apar_slot_" .. r then hallada = true end
        end
      end
      if hallada then ranuras = ranuras + 1 end
    end
    fallar(errores, "el ropero tiene seis ranuras", ranuras == 6, tostring(ranuras))
    -- las pestañas del panel no se confunden con los botones "pj_<id>" del selector (entrar con ese personaje)
    local tabApar
    for yy = 130, 200, 3 do for xx = 500, 940, 3 do if not tabApar and (Interfaz.consumir(xx, yy) or ""):find("apariencia", 1, true) and Interfaz.consumir(xx, yy):sub(1, 3) ~= "pj_" then tabApar = Interfaz.consumir(xx, yy) end end end
    fallar(errores, "la pestaña Apariencia no usa un id de personaje del selector", tabApar == "ptab_apariencia", tostring(tabApar))
    local fx, fy
    for yy = 130, 600, 3 do
      for xx = 500, 940, 3 do
        if not fx and Interfaz.consumir(xx, yy) == "apar_poner_pecho_pd_dorado" then fx, fy = xx, yy end
      end
    end
    fallar(errores, "la lista del pecho ofrece cada set que tiene", fx ~= nil)
    foto("personaje_ropero", fx or 700, fy or 300)
    -- un clic en un set manda poner esa pieza en esa ranura
    local Entrada = require("src.presentacion.entrada")
    local llamadas = {}
    local app = { jugador = pj, mundo = mundo, estado = "juego", zoom = 1, actuar = function(n, d) llamadas[#llamadas + 1] = { n, d } end }
    Entrada.manejar(app, "apar_poner_pecho_pd_dorado")
    fallar(errores, "elegir un set manda apariencia_poner con ranura y set", llamadas[1] and llamadas[1][1] == "apariencia_poner" and llamadas[1][2].ranura == "pecho" and llamadas[1][2].set == "pd_dorado")
    Entrada.manejar(app, "apar_quitar_pecho")
    fallar(errores, "quitar manda apariencia_quitar", llamadas[2] and llamadas[2][1] == "apariencia_quitar" and llamadas[2][2].ranura == "pecho")
    Interfaz.personajeTab, Interfaz.ropero = "equipo", nil
    Interfaz.panel = nil
  end)
  paso("skins exclusivas dibujadas por código", function()
    local P = require("src.presentacion.render.personajes")
    local Propias = require("src.presentacion.render.propias")
    local Mall = require("compartido.dominio.mall")
    for _, id in ipairs({ "hada_cristal", "caballero_solar" }) do
      local h = Propias.hoja(id)
      fallar(errores, id .. ": la hoja es de 96x128", h and h:getWidth() == 96 and h:getHeight() == 128)
      -- tiene dibujo en cada uno de los 12 cuadros (4 direcciones x 3 pasos)
      local datos = h:newImageData()
      local vacios = 0
      for fila = 0, 3 do
        for col = 0, 2 do
          local n = 0
          for y = fila * 32, fila * 32 + 31 do
            for x = col * 32, col * 32 + 31 do
              local _, _, _, a = datos:getPixel(x, y)
              if a > 0.5 then n = n + 1 end
            end
          end
          if n < 150 then vacios = vacios + 1 end
        end
      end
      fallar(errores, id .. ": los 12 cuadros tienen personaje", vacios == 0, vacios .. " vacíos")
    end
    for _, id in ipairs({ "skin_hada_cristal", "skin_caballero_solar" }) do
      fallar(errores, id .. " está en el mall con precio", Mall.ADDONS[id] and Mall.ADDONS[id].precio > 0 and P.skins[id] and P.skins[id].generada ~= nil)
      for dir = 1, 4 do
        local ok, err = pcall(P.dibujar, P.skins[id], dir, dir % 2 == 0, 0.3, 100, 100)
        fallar(errores, id .. " se dibuja en la dirección " .. dir, ok, tostring(err))
      end
    end
    -- los diez addons de clase (guerrero, mago, cazador, clérigo, lancero y nigromante): tienda, precio y dibujo
    local DE_CLASE = { "skin_gladiador", "skin_barbaro", "skin_archimago", "skin_hechicero_fuego", "skin_montaraz",
      "skin_arquero_elfico", "skin_sacerdotisa_alba", "skin_hoplita", "skin_senor_huesos", "skin_dama_lich" }
    for _, id in ipairs(DE_CLASE) do
      fallar(errores, id .. " está en el mall con precio", Mall.ADDONS[id] and Mall.ADDONS[id].precio > 0 and P.skins[id] and P.skins[id].generada ~= nil)
      for dir = 1, 4 do
        local ok, err = pcall(P.dibujar, P.skins[id], dir, dir % 2 == 0, 0.3, 100, 100)
        fallar(errores, id .. " se dibuja en la dirección " .. dir, ok, tostring(err))
      end
    end
    local primeras = Mall.ORDEN_ADDONS[1] == "skin_hada_cristal" and Mall.ORDEN_ADDONS[2] == "skin_caballero_solar"
    fallar(errores, "salen las primeras de la lista", primeras)
  end)
  paso("interfaz: pestaña de forja con polvos de encantamiento", function()
    local Entrada = require("src.presentacion.entrada")
    local Mall = require("compartido.dominio.mall")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Forja", faccion = "albor", clase = "guerrero", nivel = 12 })
    pj.mall = { monedas = 500, addons = {} }
    local llamadas = {}
    local app = { jugador = pj, mundo = mundo, estado = "juego", zoom = 1, actuar = function(n, d) llamadas[#llamadas + 1] = { n, d } end }
    Interfaz.escala = 1
    Entrada.manejar(app, "mall_tab_forja")
    fallar(errores, "la pestaña Forja se abre", Interfaz.mallTab == "forja")
    Interfaz.panel = "mall"
    local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el mall muestra la forja", ok, tostring(err))
    local x1 = nil
    for y = 100, 400, 4 do for x = 300, 1000, 4 do if Interfaz.consumir(x, y) == "mall_buy_polvos_10" then x1 = x end end end
    fallar(errores, "la forja vende polvos de encantamiento", x1 ~= nil)
    local x2 = nil
    for y = 100, 600, 4 do for x = 300, 1000, 4 do if Interfaz.consumir(x, y) == "mall_buy_pergamino_atk" then x2 = x end end end
    fallar(errores, "los pergaminos de atributos no están en la forja", x2 == nil)
    Entrada.manejar(app, "mall_tab_obj")
    pcall(Interfaz.hud, mundo, pj, 1280, 720)
    -- los pergaminos de forja se retiraron del juego: no se venden y el panel de encantos se dibuja sin ellos
    local xf = nil
    for y = 100, 600, 4 do for x = 300, 1000, 4 do if Interfaz.consumir(x, y) == "mall_buy_pergamino_forja" then xf = x end end end
    fallar(errores, "ya no se venden pergaminos de forja", xf == nil)
    Interfaz.panel, Interfaz.encSel = "encantar", "equipo_arma"
    ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el panel de encantos se dibuja", ok, tostring(err))
    Interfaz.panel, Interfaz.mallTab = nil, "objetos"
  end)
  paso("misiones: tablón, diario, rastreador y marcas en el mapa", function()
    local Misiones = require("compartido.dominio.misiones")
    local Entrada = require("src.presentacion.entrada")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Diario", faccion = "albor", clase = "guerrero", nivel = 12 })
    local llamadas = {}
    local app = { jugador = pj, mundo = mundo, estado = "juego", zoom = 1, actuar = function(n, d) llamadas[#llamadas + 1] = { n, d } end }
    Interfaz.escala = 1
    -- tablón de Auroria
    Interfaz.panel, Interfaz.npcMision, Interfaz.misSel = "misiones", "c_auroria", nil
    local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el tablón se dibuja", ok, tostring(err))
    Entrada.manejar(app, "mision_sel_q_auroria")
    pcall(Interfaz.hud, mundo, pj, 1280, 720)
    local hallado
    for y = 100, 650, 6 do for x = 300, 1000, 6 do local id = Interfaz.consumir(x, y) if id == "mision_ok_q_auroria" then hallado = id end end end
    local vistos = {}
    for y = 60, 700, 6 do for x = 200, 1100, 6 do local id = Interfaz.consumir(x, y) if id and not vistos[id] then vistos[id] = true end end end
    local lista = {}
    for id in pairs(vistos) do lista[#lista + 1] = id end
    table.sort(lista)
    fallar(errores, "hay botón de aceptar la primera misión", hallado == "mision_ok_q_auroria", table.concat(lista, " "):sub(1, 400))
    Entrada.manejar(app, "mision_ok_q_auroria")
    fallar(errores, "aceptar manda la acción y sigue la misión", llamadas[1] and llamadas[1][1] == "mision_aceptar" and Misiones.seguida == "q_auroria")
    -- con la misión en curso: diario y rastreador
    pj.misiones.q_auroria = { aceptada = true, entregada = false, progreso = 2 }
    Interfaz.panel = "diario"
    ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el diario se dibuja", ok, tostring(err))
    Entrada.manejar(app, "mision_sel_q_auroria")
    Entrada.manejar(app, "mision_aband_q_auroria")
    fallar(errores, "abandonar pide confirmar", Interfaz.misAband == "q_auroria" and #llamadas == 1)
    Entrada.manejar(app, "mision_aband_q_auroria")
    fallar(errores, "y al confirmar la abandona", llamadas[2] and llamadas[2][1] == "mision_abandonar" and Misiones.seguida == nil)
    Misiones.seguida = "q_auroria"
    Interfaz.panel = nil
    pj.x, pj.y, pj.modo, pj.z = 200, 300, "mundo", 0
    ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el rastreador y el minimapa con marca se dibujan", ok, tostring(err))
    Interfaz.panel = "mapa"
    ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el mapa del mundo con las marcas se dibuja", ok, tostring(err))
    Entrada.manejar(app, "mision_mapa_q_auroria")
    fallar(errores, "ver en el mapa abre el mapa", Interfaz.panel == "mapa")
    -- la flecha y la marca "!" sobre los PNJ
    Interfaz.panel = nil
    local Dibujo = require("src.presentacion.render.dibujo")
    local okF, errF = pcall(function()
      love.graphics.push()
      Dibujo.flechaMision(pj, 100, 100)
      love.graphics.pop()
    end)
    fallar(errores, "la flecha de misión se dibuja", okF, tostring(errF))
    fallar(errores, "el PNJ de Auroria marca para el jugador", Dibujo.marcaNpc(pj, "c_auroria") ~= nil)
    Misiones.seguida = nil
    -- los PNJ de los puestos tienen aspecto y icono propios
    local P = require("src.presentacion.render.personajes")
    fallar(errores, "los PNJ de misiones tienen sprite", P.de({ kind = "npc", rol = "misiones", id = "x1" }) ~= nil and Interfaz.ICONO_NPC.misiones ~= nil)
  end)
  -- Criaturas de nivel 31 a 50 (arte nuevo de FAO): se dibujan en todas sus animaciones. Con DC_PRUEBA_PODERES_FAO=1 guarda juego/capturas/criaturas_altas.png
  paso("criaturas de nivel 31 a 50: arte propio y todas las animaciones", function()
    local MobAnim = require("src.presentacion.render.mob_anim")
    local lista = {}
    for _, m in ipairs(Datos.monstruos) do if m.nivel > 30 then lista[#lista + 1] = m end end
    fallar(errores, "hay 26 criaturas de nivel 31 a 50", #lista == 26, tostring(#lista))
    local carpetas = {}
    local CW, CH = 120, 130
    local cv = love.graphics.newCanvas(CW * 9, CH * 3)
    love.graphics.push("all")
    love.graphics.setCanvas({ cv, stencil = true })
    love.graphics.clear(0.24, 0.4, 0.24, 1)
    for i, m in ipairs(lista) do
      local d = MobAnim.DEFS[m.id]
      fallar(errores, m.id .. " tiene dibujo", d ~= nil)
      if d then
        carpetas[d.carpeta] = (carpetas[d.carpeta] or 0) + 1
        for _, estado in ipairs({ "wait", "run", "att", "hurt", "dead" }) do
          local ok, err = pcall(MobAnim.dibujar, m.id, estado, 0.5, ((i - 1) % 9) * CW + CW / 2, math.floor((i - 1) / 9) * CH + CH - 16, 1, nil, i, nil)
          fallar(errores, m.id .. " se dibuja en " .. estado, ok, tostring(err))
        end
      end
    end
    love.graphics.pop()
    for car, n in pairs(carpetas) do fallar(errores, "el dibujo " .. car .. " no se repite", n == 1) end
    if os.getenv("DC_PRUEBA_PODERES_FAO") then Log.volcar("capturas/criaturas_altas.png", cv:newImageData():encode("png"):getString()) end
  end)
  -- Hoja de comprobación visual del equipo FAO: DC_PRUEBA_EQUIPOS=1 la guarda en capturas/equipos_<animación>.png (6 clases x 2 géneros en filas,
  -- los 10 escalones en columnas) y avisa de las combinaciones que no dibujan nada.
  if os.getenv("DC_PRUEBA_EQUIPOS") then
    paso("equipo FAO: hojas de comprobación por animación", function()
      local Fao = require("src.presentacion.render.fao")
      Fao.forzar(nil)
      local I = require("compartido.dominio.items")
      local clases = { "guerrero", "lancero", "cazador", "mago", "clerigo", "nigromante" }
      local CW, CH = 96, 104
      for _, anim in ipairs({ "wait", "run", "att", "cast", "dead" }) do
        for _, dir in ipairs({ 0, 4 }) do
          local cv = love.graphics.newCanvas(CW * 10, CH * 12)
          love.graphics.push("all")
          love.graphics.setCanvas({ cv, stencil = true })
          love.graphics.clear(0.23, 0.27, 0.34, 1)
          for f, clase in ipairs(clases) do
            for g, gen in ipairs({ "h", "m" }) do
              for tier = 1, 10 do
                local fila = (f - 1) * 2 + g - 1
                local e = { kind = "jugador", id = 3, clase = clase, gen = gen, equipo = I.equipoDe(clase, tier), x = 10, y = 10, dir = 1 }
                local ok, err = pcall(Fao.dibujar, e, anim == "run", (tier - 1) * CW + CW / 2, fila * CH + CH - 14, nil, 1, { anim = anim, paso = 1, d5 = dir })
                if not ok then fallar(errores, "equipo " .. clase .. "/" .. gen .. "/" .. tier .. "/" .. anim, false, tostring(err)) end
              end
            end
          end
          love.graphics.pop()
          local datosImg = cv:newImageData()
          Log.volcar("capturas/equipos_" .. anim .. "_d" .. dir .. ".png", datosImg:encode("png"):getString())
        end
      end
    end)
  end
  if os.getenv("DC_PRUEBA_CAMINAR") then
    paso("equipo FAO: ciclo de caminar (6 pasos x 5 direcciones)", function()
      local Fao = require("src.presentacion.render.fao")
      Fao.forzar(nil)
      local I = require("compartido.dominio.items")
      local clase, gen, tier = os.getenv("DC_PRUEBA_CAMINAR"), os.getenv("DC_GEN") or "h", tonumber(os.getenv("DC_TIER") or "3")
      local CW, CH = 100, 110
      local cv = love.graphics.newCanvas(CW * 6, CH * 5)
      love.graphics.push("all")
      love.graphics.setCanvas({ cv, stencil = true })
      love.graphics.clear(0.23, 0.27, 0.34, 1)
      for d5 = 0, 4 do
        for p = 0, 5 do
          local e = { kind = "jugador", id = 3, clase = clase, gen = gen, equipo = I.equipoDe(clase, tier), x = 10, y = 10, dir = 1 }
          Fao.dibujar(e, true, p * CW + CW / 2, d5 * CH + CH - 14, nil, 1, { anim = "run", paso = p, d5 = d5 })
        end
      end
      love.graphics.pop()
      Log.volcar("capturas/caminar_" .. clase .. ".png", cv:newImageData():encode("png"):getString())
    end)
  end
  -- Jinete sentado sobre las monturas de FAO por el camino real del juego (Dibujo.entidad): DC_PRUEBA_MONTADO=<clase> (DC_GEN, DC_TIER) guarda
  -- capturas/montado_<clase>.png: una fila por montura, cuatro direcciones del mundo y tres instantes de la carrera en cada una.
  if os.getenv("DC_PRUEBA_MONTADO") then
    paso("equipo FAO: jinete montado en varias monturas", function()
      local Fao = require("src.presentacion.render.fao")
      Fao.forzar(nil)
      fallar(errores, "hay hojas del jinete montado", Fao.tieneMontado())
      local I = require("compartido.dominio.items")
      local Dibujo = require("src.presentacion.render.dibujo")
      local clase, gen, tier = os.getenv("DC_PRUEBA_MONTADO"), os.getenv("DC_GEN") or "h", tonumber(os.getenv("DC_TIER") or "8")
      local monturas = { "mnt_001", "mnt_006", "mnt_002", "mnt_104", "mnt_198", "mnt_201", "mnt_144", "mnt_250" }
      local CW, CH = 100, 120
      local cv = love.graphics.newCanvas(CW * 12, CH * #monturas)
      love.graphics.push("all")
      love.graphics.setCanvas({ cv, stencil = true })
      love.graphics.clear(0.23, 0.27, 0.34, 1)
      for fila, mid in ipairs(monturas) do
        for dir = 1, 4 do
          for t = 1, 3 do
            love.timer.sleep(0.11)
            local e = { kind = "jugador", id = 4000 + fila, clase = clase, gen = gen, equipo = I.equipoDe(clase, tier), x = 10, y = 10, dir = dir,
                        montado = mid, mov = true, vivo = true, faccion = "albor", velx = 0, vely = 0 }
            local ok, err = pcall(Dibujo.entidad, e, ((dir - 1) * 3 + t - 1) * CW + CW / 2, (fila - 1) * CH + CH - 22, nil, nil)
            if not ok then fallar(errores, "montado " .. mid .. " dir " .. dir, false, tostring(err)) end
          end
        end
      end
      love.graphics.pop()
      Log.volcar("capturas/montado_" .. clase .. ".png", cv:newImageData():encode("png"):getString())
    end)
  end
  -- Validación completa del jinete montado: DC_PRUEBA_MONTADO_TODO=1. Recorre TODAS las monturas de FAO x 8 direcciones x 6 clases x 2 géneros x 2 escalones de
  -- equipo (el 1 y el 8) por el camino real de dibujo, comprobando que no falla y que en cada combinación se pinta algo en la casilla (el jinete y la montura).
  if os.getenv("DC_PRUEBA_MONTADO_TODO") then
    paso("equipo FAO: todas las monturas x direcciones x clases x géneros x equipo", function()
      local Fao = require("src.presentacion.render.fao")
      Fao.forzar(nil)
      local I = require("compartido.dominio.items")
      local Dibujo = require("src.presentacion.render.dibujo")
      local MobAnim = require("src.presentacion.render.mob_anim")
      local ids = {}
      for k in pairs(MobAnim.DEFS) do if k:sub(1, 4) == "mnt_" then ids[#ids + 1] = k end end
      table.sort(ids)
      local clases = { "guerrero", "lancero", "cazador", "mago", "clerigo", "nigromante" }
      local W, H = 160, 180
      local cv = love.graphics.newCanvas(W, H)
      local total, vacias, fallos = 0, {}, 0
      for _, mid in ipairs(ids) do
        for oc = 0, 7 do
          for _, clase in ipairs(clases) do
            for _, gen in ipairs({ "h", "m" }) do
              for _, tier in ipairs({ 1, 8 }) do
                love.graphics.push("all")
                love.graphics.setCanvas({ cv, stencil = true })
                love.graphics.clear(0, 0, 0, 0)
                local e = { kind = "jugador", id = 20000 + total, clase = clase, gen = gen, equipo = I.equipoDe(clase, tier), x = 10, y = 10, dir = 1,
                            montado = mid, mov = (total % 2 == 0), vivo = true, faccion = "albor", velx = 0, vely = 0, _f8 = oc }
                local ok, err = pcall(Dibujo.entidad, e, W / 2, H - 50, nil, nil)
                love.graphics.pop()
                total = total + 1
                if not ok then
                  fallos = fallos + 1
                  if fallos <= 5 then fallar(errores, "montado " .. mid .. "/" .. oc .. "/" .. clase .. "/" .. gen .. "/" .. tier, false, tostring(err)) end
                elseif total % 7 == 0 then
                  -- (se comprueba una de cada siete combinaciones que la casilla no quedó vacía)
                  local d = cv:newImageData()
                  local n = 0
                  for y = 0, H - 1, 3 do for x = 0, W - 1, 3 do local _, _, _, a = d:getPixel(x, y) if a > 0.1 then n = n + 1 end end end
                  if n < 12 then vacias[#vacias + 1] = mid .. "/" .. oc .. "/" .. clase .. "/" .. gen .. "/" .. tier end
                end
              end
            end
          end
        end
      end
      fallar(errores, "monturas: ninguna combinación falla (" .. total .. " dibujos)", fallos == 0, tostring(fallos))
      fallar(errores, "monturas: ninguna casilla queda vacía", #vacias == 0, table.concat(vacias, ", ", 1, math.min(#vacias, 8)))
    end)
  end
  -- Un jinete sobre CADA montura de FAO: DC_PRUEBA_MONTADO_TODAS=<clase> y DC_OCTANTE (por defecto 3, de lado) -> capturas/montadas_todas_<octante>.png
  -- (10 monturas por fila, con el número de cada una escrito debajo).
  if os.getenv("DC_PRUEBA_MONTADO_TODAS") then
    paso("equipo FAO: el jinete sobre todas las monturas", function()
      local Fao = require("src.presentacion.render.fao")
      Fao.forzar(nil)
      local I = require("compartido.dominio.items")
      local Dibujo = require("src.presentacion.render.dibujo")
      local MobAnim = require("src.presentacion.render.mob_anim")
      local clase = os.getenv("DC_PRUEBA_MONTADO_TODAS")
      if clase == "1" or clase == "" then clase = "mago" end
      local oc = tonumber(os.getenv("DC_OCTANTE") or "3")
      local ids = {}
      for k in pairs(MobAnim.DEFS) do if k:sub(1, 4) == "mnt_" then ids[#ids + 1] = k end end
      table.sort(ids)
      local CW, CH, COLS = 150, 150, 10
      local filas = math.ceil(#ids / COLS)
      local cv = love.graphics.newCanvas(CW * COLS, CH * filas)
      love.graphics.push("all")
      love.graphics.setCanvas({ cv, stencil = true })
      love.graphics.clear(0.23, 0.27, 0.34, 1)
      for n, mid in ipairs(ids) do
        local x, y = ((n - 1) % COLS) * CW, math.floor((n - 1) / COLS) * CH
        local e = { kind = "jugador", id = 9800 + n, clase = clase, gen = os.getenv("DC_GEN") or "h", equipo = I.equipoDe(clase, 8), x = 10, y = 10, dir = 1,
                    montado = mid, mov = false, vivo = true, faccion = "albor", velx = 0, vely = 0, _f8 = oc }
        local ok, err = pcall(Dibujo.entidad, e, x + CW / 2, y + CH - 40, nil, nil)
        if not ok then fallar(errores, "montada " .. mid, false, tostring(err)) end
        love.graphics.setColor(1, 1, 0.4, 1)
        love.graphics.print(mid:sub(5), x + 4, y + 2)
      end
      love.graphics.pop()
      Log.volcar("capturas/montadas_todas_" .. oc .. ".png", cv:newImageData():encode("png"):getString())
    end)
  end
  -- Todas las clases, géneros y escalones de equipo montados: DC_PRUEBA_MONTADO_EQUIPOS=<montura> (por defecto mnt_001) y DC_OCTANTE (por defecto 3, de lado)
  -- -> capturas/montado_equipos_<octante>.png (12 filas = 6 clases x 2 géneros, 8 columnas = escalones). Avisa de las combinaciones que no dibujan nada.
  if os.getenv("DC_PRUEBA_MONTADO_EQUIPOS") then
    paso("equipo FAO: todas las clases y escalones sobre una montura", function()
      local Fao = require("src.presentacion.render.fao")
      Fao.forzar(nil)
      local I = require("compartido.dominio.items")
      local Dibujo = require("src.presentacion.render.dibujo")
      local mid = os.getenv("DC_PRUEBA_MONTADO_EQUIPOS")
      if mid == "1" or mid == "" then mid = "mnt_001" end
      local oc = tonumber(os.getenv("DC_OCTANTE") or "3")
      local clases = { "guerrero", "lancero", "cazador", "mago", "clerigo", "nigromante" }
      local CW, CH = 110, 120
      local cv = love.graphics.newCanvas(CW * 8, CH * 12)
      love.graphics.push("all")
      love.graphics.setCanvas({ cv, stencil = true })
      love.graphics.clear(0.23, 0.27, 0.34, 1)
      for f, clase in ipairs(clases) do
        for g, gen in ipairs({ "h", "m" }) do
          for tier = 1, 8 do
            local fila = (f - 1) * 2 + g - 1
            local e = { kind = "jugador", id = 9500 + fila * 10 + tier, clase = clase, gen = gen, equipo = I.equipoDe(clase, tier), x = 10, y = 10, dir = 1,
                        montado = mid, mov = true, vivo = true, faccion = "albor", velx = 0, vely = 0, _f8 = oc }
            local ok, err = pcall(Dibujo.entidad, e, (tier - 1) * CW + CW / 2, fila * CH + CH - 22, nil, nil)
            if not ok then fallar(errores, "montado " .. clase .. "/" .. gen .. "/" .. tier, false, tostring(err)) end
          end
        end
      end
      love.graphics.pop()
      Log.volcar("capturas/montado_equipos_" .. oc .. ".png", cv:newImageData():encode("png"):getString())
    end)
  end
  -- PNJ y monturas de cinco direcciones caminando hacia las 8 direcciones de pantalla: DC_PRUEBA_DIRECCIONES=1 -> capturas/direcciones.png
  -- (columnas = octante 0 derecha, 1 abajo-derecha, 2 abajo, 3 abajo-izquierda, 4 izquierda, 5 arriba-izquierda, 6 arriba, 7 arriba-derecha; filas: guardia,
  -- PNJ de misiones y un mago montado en tres monturas). Comprueba que se dibuja algo en cada casilla.
  if os.getenv("DC_PRUEBA_DIRECCIONES") then
    paso("PNJ y monturas: caminan hacia las 8 direcciones", function()
      local Fao = require("src.presentacion.render.fao")
      Fao.forzar(nil)
      local I = require("compartido.dominio.items")
      local Dibujo = require("src.presentacion.render.dibujo")
      local filas = {
        { kind = "guardia", faccion = "albor" }, { kind = "npc", rol = "misiones" }, { kind = "npc", rol = "mercado" },
        { kind = "jugador", clase = "mago", montado = "mnt_001" }, { kind = "jugador", clase = "guerrero", montado = "mnt_006" },
        { kind = "jugador", clase = "cazador", montado = "mnt_201" }, { kind = "jugador", clase = "mago", montado = "mnt_104" },
      }
      local CW, CH = 100, 110
      local cv = love.graphics.newCanvas(CW * 8, CH * #filas)
      love.graphics.push("all")
      love.graphics.setCanvas({ cv, stencil = true })
      love.graphics.clear(0.23, 0.27, 0.34, 1)
      for r, f in ipairs(filas) do
        for oc = 0, 7 do
          local e = { kind = f.kind, id = 8000 + r * 10 + oc, nombre = "Prueba", clase = f.clase, gen = "h", faccion = f.faccion or "albor", rol = f.rol, montado = f.montado,
                      equipo = f.clase and I.equipoDe(f.clase, 8) or nil, x = 10, y = 10, dir = 1, vivo = true, mov = true, velx = 0, vely = 0, _f8 = oc }
          local ok, err = pcall(Dibujo.entidad, e, oc * CW + CW / 2, (r - 1) * CH + CH - 20, nil, nil)
          if not ok then fallar(errores, "direcciones " .. (f.montado or f.rol or f.kind) .. " " .. oc, false, tostring(err)) end
        end
      end
      love.graphics.pop()
      Log.volcar("capturas/direcciones.png", cv:newImageData():encode("png"):getString())
    end)
  end
  -- Ciclo de correr en las 8 direcciones de pantalla (con las volteadas): DC_PRUEBA_OCTANTES=<clase> -> capturas/octantes_<clase>.png
  -- (filas = octante 0 derecha, 1 abajo-derecha, 2 abajo, 3 abajo-izquierda, 4 izquierda, 5 arriba-izquierda, 6 arriba, 7 arriba-derecha).
  if os.getenv("DC_PRUEBA_OCTANTES") then
    paso("equipo FAO: correr en los 8 octantes (incluye las hojas volteadas)", function()
      local Fao = require("src.presentacion.render.fao")
      Fao.forzar(nil)
      local I = require("compartido.dominio.items")
      local clase, gen, tier = os.getenv("DC_PRUEBA_OCTANTES"), os.getenv("DC_GEN") or "h", tonumber(os.getenv("DC_TIER") or "3")
      local CW, CH = 100, 110
      local cv = love.graphics.newCanvas(CW * 6, CH * 8)
      love.graphics.push("all")
      love.graphics.setCanvas({ cv, stencil = true })
      love.graphics.clear(0.23, 0.27, 0.34, 1)
      for oc = 0, 7 do
        for p = 0, 5 do
          local e = { kind = "jugador", id = 9000 + oc, clase = clase, gen = gen, equipo = I.equipoDe(clase, tier), x = 10, y = 10, dir = 1, _f8 = oc }
          Fao.dibujar(e, true, p * CW + CW / 2, oc * CH + CH - 14, nil, 1, { anim = "run", paso = p })
        end
      end
      love.graphics.pop()
      Log.volcar("capturas/octantes_" .. clase .. ".png", cv:newImageData():encode("png"):getString())
    end)
  end
  paso("personajes por capas: la dirección no parpadea al caminar", function()
    local Fao = require("src.presentacion.render.fao")
    Fao.forzar(nil)
    if os.getenv("DC_FAO") == "0" then return end
    -- Camino con posiciones a saltos (como llegan del servidor: 3 cuadros quietos y un salto) y temblor lateral. Se cuentan los cambios de
    -- octante: en un tramo recto no debe haber ninguno y en un zigzag solo los giros de verdad.
    local recorridos = 0
    local function recorrer(tramos)
      recorridos = recorridos + 1
      local id = 7000 + recorridos      -- (la dirección se guarda por id, fuera de la entidad: cada recorrido es un sujeto nuevo)
      local e = { id = id, nombre = "Zig", x = 50, y = 50, dir = 1 }
      local cambios, previo, x, y, n = 0, Fao.direccion(e, nil), 50, 50, 0
      local log = {}
      for _, tr in ipairs(tramos) do
        for i = 1, tr.pasos do
          x, y = x + tr.dx * 0.25, y + tr.dy * 0.25
          -- el servidor mueve el punto cada 3 cuadros; entre medias se repite la posición anterior
          for f = 1, 3 do
            n = n + 1
            local temblor = ((n * 7919) % 11 - 5) * 0.004
            local nx, ny = (f == 3) and x + temblor or e.x or x, (f == 3) and y - temblor or e.y or y
            if f == 3 then
              -- como en Mundo:aplicarFoto: cada foto REEMPLAZA la entidad por una tabla nueva (sin ningún estado de dibujo) y con la dirección
              -- cardinal del mundo, que en una diagonal alterna de eje a cada casilla
              e = { id = id, nombre = "Zig", x = nx, y = ny, dir = (tr.dx ~= 0 and tr.dy ~= 0) and (i % 2 == 0 and 3 or 1) or (tr.dx ~= 0 and 3 or 1) }
            else
              e.x, e.y = nx, ny
            end
            local oc = Fao.direccion(e, nil)
            if oc ~= previo then cambios = cambios + 1 log[#log + 1] = oc previo = oc end
          end
        end
      end
      return cambios, log
    end
    local rectos = recorrer({ { dx = 1, dy = 0, pasos = 40 } })
    fallar(errores, "tramo recto: la dirección no alterna", rectos <= 1, tostring(rectos))
    local diag = recorrer({ { dx = 1, dy = 1, pasos = 40 } })
    fallar(errores, "tramo en diagonal: la dirección no alterna", diag <= 1, tostring(diag))
    local zig = recorrer({ { dx = 1, dy = 0, pasos = 16 }, { dx = 0, dy = 1, pasos = 16 }, { dx = 1, dy = 0, pasos = 16 }, { dx = 0, dy = 1, pasos = 16 } })
    fallar(errores, "zigzag: solo cambia en los giros", zig <= 5, tostring(zig))
  end)

  paso("personajes por capas: cada clase, género y escalón se dibuja", function()
    local Fao = require("src.presentacion.render.fao")
    Fao.forzar(nil)
    if os.getenv("DC_FAO") == "0" then return end      -- (DC_FAO=0: se usan los personajes antiguos y no hay capas que probar)
    fallar(errores, "los personajes por capas están activos", Fao.activo())
    local I = require("compartido.dominio.items")
    local cv = love.graphics.newCanvas(300, 200)
    for _, clase in ipairs({ "guerrero", "lancero", "cazador", "mago", "clerigo", "nigromante" }) do
      for _, gen in ipairs({ "h", "m" }) do
        for _, tier in ipairs({ 1, 4, 8 }) do
          for _, estado in ipairs({ "wait", "run", "att", "cast", "sht", "hurt", "dead" }) do
            local e = { kind = "jugador", id = 7, clase = clase, gen = gen, faccion = "albor", equipo = I.equipoDe(clase, tier), x = 10, y = 10, dir = 3 }
            love.graphics.push("all")
            love.graphics.setCanvas({ cv, stencil = true })
            local ok, err = pcall(Fao.dibujar, e, estado == "run", 100, 100, nil, 1, { anim = estado, paso = 0 })
            love.graphics.pop()
            fallar(errores, "se dibuja " .. clase .. "/" .. gen .. "/" .. tier .. "/" .. estado, ok, tostring(err))
          end
        end
      end
    end
  end)
  paso("sprites de clases y monturas por código", function()
    require("src.presentacion.render.fao").forzar(false)
    local Propias = require("src.presentacion.render.propias")
    local Personajes = require("src.presentacion.render.personajes")
    local cv = love.graphics.newCanvas(300, 200)
    for _, clase in ipairs({ "guerrero", "mago", "cazador", "clerigo" }) do
      for _, faccion in ipairs({ "albor", "umbra" }) do
        local def = Personajes.de({ kind = "jugador", clase = clase, faccion = faccion })
        fallar(errores, "clase " .. clase .. "/" .. faccion .. " usa su sprite propio", def and def.generada == "clase_" .. clase .. "_" .. faccion)
        local h = Propias.hoja(def.generada)
        fallar(errores, "hoja de " .. def.generada, h ~= nil and h:getWidth() == 96 and h:getHeight() == 128)
        love.graphics.push("all")
        love.graphics.setCanvas({ cv, stencil = true })
        local ok, err = pcall(Personajes.dibujar, def, 2, true, 0.3, 100, 100)
        love.graphics.pop()
        fallar(errores, "se dibuja " .. def.generada, ok, tostring(err))
      end
    end
    for _, esp in ipairs({ "mnt_001", "mnt_006", "mnt_027", "mnt_008" }) do
      for _, faccion in ipairs({ "albor", "umbra" }) do
        local def = Personajes.monturaDe(esp, faccion)
        fallar(errores, "montura " .. esp .. "/" .. faccion, def and def.anim ~= nil and def.altura ~= nil)
        love.graphics.push("all")
        love.graphics.setCanvas({ cv, stencil = true })
        local ok, err = pcall(Personajes.dibujar, def, 3, true, 0.5, 100, 100)
        love.graphics.pop()
        fallar(errores, "se dibuja " .. esp, ok, tostring(err))
      end
    end
    fallar(errores, "las monturas de carga siguen con su hoja", Personajes.monturaDe("buey", "albor").hoja ~= nil)
    require("src.presentacion.render.fao").forzar(nil)
  end)
  paso("ayudas de interfaz: números, avisos [E] y motivos", function()
    local Ayudas = require("src.presentacion.ayudas")
    fallar(errores, "números con puntos de miles", Ayudas.num(0) == "0" and Ayudas.num(999) == "999" and Ayudas.num(1000) == "1.000"
      and Ayudas.num(1234567) == "1.234.567" and Ayudas.num(nil) == "0" and Ayudas.num(12500.7) == "12.500")
    local mundo = Mundo.nuevo()
    local p = mundo:crearPersonaje({ nombre = "Guia", faccion = "albor", clase = "guerrero", nivel = 12 })
    -- junto a un PNJ sale el aviso de hablar con él
    local npc
    for _, e in pairs(mundo.entidades) do if e.kind == "npc" and e.rol == "mercado" and e.faccion == "albor" then npc = e break end end
    p.x, p.y, p.z, p.modo = npc.x + 1, npc.y, 0, "mundo"
    local t = Ayudas.interaccion(mundo, p)
    fallar(errores, "aviso junto a un PNJ", t and t:find("^%[E%] Hablar con") and t:find(npc.nombre, 1, true) ~= nil, tostring(t))
    p.x, p.y = npc.x + 30, npc.y + 30
    -- junto a la puerta de una mazmorra
    local z = mundo.mapas.mundo.mazmorras[1]
    p.x, p.y = z.x + 0.5, z.y + 1.5
    t = Ayudas.interaccion(mundo, p)
    fallar(errores, "aviso de la puerta de mazmorra", t and t:find("Entrar en " .. z.nombre, 1, true) ~= nil, tostring(t))
    p.nivel = 1
    t = Ayudas.interaccion(mundo, p)
    fallar(errores, "avisa si falta nivel", t and t:find("nivel insuficiente", 1, true) ~= nil, tostring(t))
    -- dentro: salida y cofre
    mundo.entidades[p.id].nivel = 30
    p.nivel = 30
    mundo:interactuar(p)
    t = Ayudas.interaccion(mundo, p)
    fallar(errores, "aviso de salida dentro de la mazmorra", t and t:find("Salir de", 1, true) ~= nil, tostring(t))
    -- botón desactivado con motivo: la pista sale al pasar el ratón
    Interfaz.limpiar()
    Interfaz.pista = nil
    local mx, my = love.mouse.getPosition()
    Interfaz.boton(mx - 10, my - 10, 60, 30, "Comprar", "x", false, "Necesitas nivel 5.")
    fallar(errores, "el botón desactivado explica el motivo", Interfaz.pista == "Necesitas nivel 5.", tostring(Interfaz.pista))
    Interfaz.pista = nil
  end)
  paso("interfaz: el dragon del Item Mall", function()
    local Entrada = require("src.presentacion.entrada")
    local Propias = require("src.presentacion.render.propias")
    local Personajes = require("src.presentacion.render.personajes")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Dragonero", faccion = "umbra", clase = "mago", nivel = 10 })
    pj.mall = { monedas = 2000, bonos = {}, addons = {} }
    local llamadas = {}
    local app = { jugador = pj, mundo = mundo, estado = "juego", zoom = 1, actuar = function(n, d) llamadas[#llamadas + 1] = { n, d } end }
    Interfaz.escala, Interfaz.panel, Interfaz.mallTab = 1, "mall", "objetos"
    Interfaz.hud(mundo, pj, 1280, 720)
    local tab
    for y = 80, 120, 4 do for x = 640, 1000, 4 do if Interfaz.consumir(x, y) == "mall_tab_mont" then tab = true end end end
    fallar(errores, "el mall tiene la pestana de monturas", tab)
    Entrada.manejar(app, "mall_tab_mont")
    fallar(errores, "la pestana se abre", Interfaz.mallTab == "monturas")
    local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "la pestana de monturas se dibuja", ok, tostring(err))
    local compra
    for y = 110, 330, 4 do for x = 440, 1000, 4 do
      local id = Interfaz.consumir(x, y)
      if id == "mall_mt_buy_mnt_039" then compra = true end
    end end
    fallar(errores, "ofrece comprar el dragon con monedas", compra)
    llamadas = {}
    Entrada.manejar(app, "mall_mt_buy_mnt_039")
    fallar(errores, "comprar manda la accion", llamadas[1] and llamadas[1][1] == "mall_montura_comprar" and llamadas[1][2].id == "mnt_039")
    -- sin monedas el boton no responde; con el dragon ya comprado dice que la tienes
    pj.mall.monedas = 5
    Interfaz.hud(mundo, pj, 1280, 720)
    local hay = false
    for y = 110, 260, 4 do for x = 640, 1000, 4 do if Interfaz.consumir(x, y) == "mall_mt_buy_mnt_039" then hay = true end end end
    fallar(errores, "sin monedas no se puede comprar", not hay)
    pj.monturas = { "mnt_104" }
    ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "con el dragon comprado se dibuja", ok, tostring(err))
    -- el sprite del dragon, en las dos facciones, con cada clase encima
    local cv = love.graphics.newCanvas(400, 300)
    for _, f in ipairs({ "albor", "umbra" }) do
      local d = Personajes.monturaDe("mnt_104", f)
      fallar(errores, "el dragon es grande y el jinete va alto", d.anim and d.altura and d.altura >= 8)
      for _, clase in ipairs({ "guerrero", "mago", "cazador", "clerigo" }) do
        for dir = 1, 4 do
          love.graphics.push("all")
          love.graphics.setCanvas({ cv, stencil = true })
          local ok2, err2 = pcall(function()
            Personajes.dibujar(d, dir, true, 0.3, 100, 100)
            Personajes.dibujar(Personajes.clases[clase][f], dir, false, 0, 100, 100 - d.altura)
          end)
          love.graphics.pop()
          fallar(errores, "se dibuja el dragon con " .. clase .. " " .. f, ok2, tostring(err2))
        end
      end
    end
    -- con el dragon montado y sin oficio, el HUD ofrece montar/bajar
    pj.montado = "mnt_104"
    ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el HUD con el dragon se dibuja", ok, tostring(err))
    Interfaz.panel, Interfaz.mallTab = nil, "objetos"
  end)
  paso("todas las monturas se ven bien con todos los addons del servidor", function()
    local Personajes = require("src.presentacion.render.personajes")
    local Dibujo = require("src.presentacion.render.dibujo")
    local Mall = require("compartido.dominio.mall")
    local Monturas = require("compartido.dominio.monturas")
    local mundo = Mundo.nuevo()
    local cv = love.graphics.newCanvas(300, 300)
    local n = 0
    local ids = {}
    for id in pairs(Mall.ADDONS) do if id:sub(1, 3) ~= "pd_" then ids[#ids + 1] = id end end
    table.sort(ids)
    local monturas = {}
    for id in pairs(Monturas.especies) do monturas[#monturas + 1] = id end
    table.sort(monturas)
    for _, addon in ipairs(ids) do
      fallar(errores, "el addon " .. addon .. " tiene sprite", Personajes.skins[addon] ~= nil)
      for _, faccion in ipairs({ "albor", "umbra" }) do
        local e = { id = "x", kind = "jugador", clase = "mago", faccion = faccion, addon = addon, x = 10, y = 10, vivo = true, dir = 1 }
        -- a pie se ve el addon; montado, nunca un jinete que ya trae su caballo
        local a_pie = Personajes.jineteDe(e)
        fallar(errores, addon .. " a pie conserva su aspecto", a_pie == Personajes.skins[addon])
        e.montado = "caballo"
        local montado = Personajes.jineteDe(e)
        fallar(errores, addon .. " montado no lleva otro caballo debajo", montado and montado.celda == nil)
        for _, montura in ipairs(monturas) do
          e.montado = montura
          for dir = 1, 4 do
            e.dir = dir
            love.graphics.push("all")
            love.graphics.setCanvas({ cv, stencil = true })
            local ok, err = pcall(Dibujo.entidad, e, 150, 150, mundo, e)
            love.graphics.pop()
            fallar(errores, "se dibuja " .. addon .. " sobre " .. montura .. " mirando " .. dir, ok, tostring(err))
            n = n + 1
          end
        end
      end
    end
    fallar(errores, "se probaron todas las combinaciones", n >= #ids * #monturas * 8, tostring(n))
  end)
  paso("interfaz: la cuadra separa transporte y monturas normales por pestanas", function()
    local Entrada = require("src.presentacion.entrada")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Cuadra", faccion = "albor", clase = "guerrero", nivel = 30 })
    pj.oro = 100000
    local info = mundo:infoMonturas(pj)
    info.cerca = true
    Interfaz.datosPanel.establo = info
    local app = { jugador = pj, mundo = mundo, estado = "juego", zoom = 1, actuar = function() end }
    Interfaz.escala, Interfaz.panel = 1, "establo"
    local function botones()
      Interfaz.hud(mundo, pj, 1280, 720)
      local ids = {}
      for y = 150, 460, 4 do for x = 400, 900, 4 do
        local id = Interfaz.consumir(x, y)
        if id and (id:sub(1, 7) == "mt_buy_" or id:sub(1, 7) == "mt_alt_") then ids[id:sub(8)] = true end
      end end
      return ids
    end
    Entrada.manejar(app, "est_tab_transporte")
    local a = botones()
    fallar(errores, "la pestana de transporte muestra buey, caballo y carreta", a.buey and a.caballo and a.carreta)
    Entrada.manejar(app, "est_tab_normales")
    local b = botones()
    fallar(errores, "la pestana normal vende las gratuitas", b.mnt_001 and not b.buey and not b.caballo)
    fallar(errores, "el dragon no sale en la cuadra", not a.dragon and not b.dragon)
    Interfaz.establoTab = "transporte"
    Interfaz.hud(mundo, pj, 1280, 720)
    local tabs = {}
    for y = 110, 160, 4 do for x = 400, 900, 4 do
      local id = Interfaz.consumir(x, y)
      if id and id:sub(1, 8) == "est_tab_" then tabs[id] = true end
    end end
    fallar(errores, "las dos pestanas reciben clics", tabs.est_tab_transporte and tabs.est_tab_normales)
    Interfaz.panel, Interfaz.datosPanel.establo = nil, nil
  end)
  paso("interfaz: coordenadas junto al minimapa y vida de montura solo con oficio", function()
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Coord", faccion = "albor", clase = "guerrero", nivel = 12 })
    pj.x, pj.y = 305.7, 278.2
    pj.monturas, pj.montado = { "buey", "mnt_001" }, "buey"
    Interfaz.escala, Interfaz.panel = 1, nil
    local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el HUD con coordenadas se dibuja", ok, tostring(err))
    local hay = false
    for x = 1040, 1135, 4 do if Interfaz.consumir(x, 28) == "panel" then hay = true end end
    fallar(errores, "hay un recuadro de coordenadas a la izquierda del minimapa", hay)
    -- montura de oficio con el oficio activo: barra de vida bajo el icono
    pj.job, pj.monturaHp, pj.monturaHpMax = "trader", 300, 500
    ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "con oficio y montura de oficio se dibuja la vida", ok, tostring(err))
    -- montura normal sin oficio: sin vida
    pj.job, pj.montado, pj.monturaHp, pj.monturaHpMax = nil, "mnt_001", nil, nil
    ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "una montura normal se dibuja sin vida", ok, tostring(err))
  end)
  paso("interfaz: ningun texto del Item Mall se sale de su fila y el zoom del mapa va a la esquina derecha", function()
    local Mall = require("compartido.dominio.mall")
    local f = Interfaz.fuente
    local alto = f:getHeight()
    local function lineas(texto, ancho) local _, l = f:getWrap(texto, ancho) return #l end
    for _, o in ipairs(Mall.OBJETOS) do
      fallar(errores, "el texto de " .. o.id .. " cabe en dos lineas", lineas(o.texto, 330) <= 2, tostring(lineas(o.texto, 330)))
      fallar(errores, "el nombre de " .. o.id .. " cabe", f:getWidth(o.nombre) < 320)
    end
    for id, a in pairs(Mall.ADDONS) do
      fallar(errores, "la descripcion de " .. id .. " cabe en dos lineas", lineas(a.desc, 320) <= 2, tostring(lineas(a.desc, 320)))
      fallar(errores, "el nombre de " .. id .. " cabe", f:getWidth(a.nombre .. "   (puesto)") < 400)
    end
    for id, d in pairs(Mall.MONTURAS) do
      fallar(errores, "la descripcion de la montura " .. id .. " cabe en dos lineas", lineas(d.desc, 360) <= 2, tostring(lineas(d.desc, 360)))
    end
    fallar(errores, "dos lineas caben en el recuadro de una fila", 28 + 2 * alto <= 72, tostring(28 + 2 * alto))
    -- mapa: los botones de zoom estan en la esquina superior derecha del mapa y responden
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Zoom", faccion = "albor", clase = "guerrero", nivel = 10 })
    Interfaz.escala, Interfaz.panel = 1, "mapa"
    Interfaz.hud(mundo, pj, 1280, 720)
    local g = Interfaz.mapaGeom
    local hallados = {}
    for y = g.ay + 4, g.ay + 40, 4 do for x = g.ax, g.ax + g.aw, 4 do
      local id = Interfaz.consumir(x, y)
      if id and id:sub(1, 5) == "mapa_" and id ~= "mapa_area" then hallados[id] = x end
    end end
    fallar(errores, "los tres botones del zoom responden", hallados.mapa_mas and hallados.mapa_menos and hallados.mapa_centrar)
    fallar(errores, "estan en la mitad derecha del mapa", hallados.mapa_mas and hallados.mapa_mas > g.ax + g.aw / 2, tostring(hallados.mapa_mas))
    fallar(errores, "y Centrar es el de mas a la derecha", hallados.mapa_centrar and hallados.mapa_centrar > hallados.mapa_menos and hallados.mapa_menos > hallados.mapa_mas)
    Interfaz.panel = nil
  end)
  -- Mapa de FAO (.mpc) en el cliente: carga y dibujo del suelo/objetos, sin errores y con tiempos razonables. Con DC_PRUEBA_MAPA_FAO=1 además guarda juego/capturas/mapa_fao.png con zonas
  -- del mapa (costa, bosque, camino de tierra) dibujadas con el personaje FAO de pie y caminando, y un mapa completo con las casillas bloqueadas marcadas (mapa_fao_bloqueo.png).
  pasoFao("mapa de FAO (.mpc): el cliente lo dibuja (suelo y objetos) y la memoria y el tiempo son razonables", function()
    local Dibujo = require("src.presentacion.render.dibujo")
    local Terreno = require("src.presentacion.render.terreno")
    local MapaMpc = require("src.presentacion.render.mapa_mpc")
    local Mapa = require("compartido.dominio.mapa")
    local mundo = Mundo.nuevo()
    local mapa = mundo.mapas.riprap
    local m = mapa.mpc
    local pj = mundo:crearPersonaje({ nombre = "Isleño", faccion = "albor", clase = "guerrero", nivel = 10 })
    mundo:entrarMapaFao(pj, "riprap")
    -- zonas: costa (arena transitable con agua profunda a 5 casillas al oeste), bosque (hierba con muchos objetos que bloquean cerca), camino (tierra)
    local function contar(x, y, r, sub)
      local n = 0
      for _, o in ipairs(m.objetos) do
        local d = m.defs[o.id]
        if d and d.b and math.abs(o.x / 64 - x) < r and math.abs(o.y / 64 - y) < r and (not sub or d.n:find(sub, 1, true)) then n = n + 1 end
      end
      return n
    end
    local zonas = {}
    for y = 10, mapa.h - 10 do
      for x = 10, mapa.w - 10 do
        local libre = Mapa.transitable(mapa, x, y)
        local ts = m.tilesets[m.ts[(y * 2) * m.fw + x * 2 + 1]]
        if libre and not zonas.costa and mapa.suelo[x][y] ~= "agua" and mapa.bloque[x - 2] and mapa.bloque[x - 2][y] and mapa.suelo[x - 2][y] == "agua" then zonas.costa = { x, y } end
        if libre and not zonas.palmeral and mapa.suelo[x][y] == "hierba" and contar(x, y, 6, "椰子樹") >= 3 then zonas.palmeral = { x, y } end
        if libre and not zonas.rocas and contar(x, y, 4, "礁岩") >= 2 then zonas.rocas = { x, y } end
        if libre and not zonas.camino and ts and ts.color[1] > 236 and ts.color[2] < 204 and ts.color[3] < 138 and mapa.suelo[x + 2][y] == "tierra" then zonas.camino = { x, y } end
      end
    end
    fallar(errores, "hay costa, palmeral y camino donde dibujar", zonas.costa and zonas.palmeral and zonas.camino, "costa=" .. tostring(zonas.costa) .. " palmeral=" .. tostring(zonas.palmeral) .. " camino=" .. tostring(zonas.camino))
    local CW, CH = 560, 360
    local vista = os.getenv("DC_PRUEBA_MAPA_FAO") ~= nil
    local orden = {}
    for _, n in ipairs({ "costa", "palmeral", "rocas", "camino" }) do if zonas[n] then orden[#orden + 1] = n end end
    local cv = love.graphics.newCanvas(CW * 2, CH * #orden)
    local celda = love.graphics.newCanvas(CW, CH)
    local memAntes = love.graphics.getStats().texturememory
    local t0 = love.timer.getTime()
    local primero
    for fila, nombre in ipairs(orden) do
      local z = zonas[nombre]
      if z then
        for col = 1, 2 do
          pj.x, pj.y = z[1] + 0.5, z[2] + 0.5
          pj.mov, pj.dir, pj.anim = col == 2, 3, col * 3
          pj.velx, pj.vely = col == 2 and 0.5 or 0, 0
          love.graphics.push("all")
          love.graphics.setCanvas({ celda, stencil = true })
          love.graphics.clear(0, 0, 0, 1)
          Dibujo.fijarVista(0, 0, CW, CH)
          local cam = Dibujo.camara(pj, 1.6, mapa)
          local tt = love.timer.getTime()
          local ok, err = pcall(Dibujo.escena, mundo, pj, cam, -1, -1)
          primero = primero or (love.timer.getTime() - tt)
          if col == 2 then
            -- casillas bloqueadas por objetos (rojo) y por el agua (azul oscuro) sobre la escena, para comprobar a ojo que las colisiones coinciden con lo que se ve
            love.graphics.push()
            love.graphics.translate(0, 0)
            love.graphics.scale(cam.zoom, cam.zoom)
            local Iso = require("src.presentacion.render.iso")
            Iso.empujar(cam)
            for x = math.floor(pj.x) - 14, math.floor(pj.x) + 14 do
              for y = math.floor(pj.y) - 14, math.floor(pj.y) + 14 do
                if mapa.bloque[x] and mapa.bloque[x][y] then
                  if mapa.suelo[x][y] == "agua" then love.graphics.setColor(0, 0, 0.4, 0.35) else love.graphics.setColor(1, 0.1, 0.1, 0.55) end
                  love.graphics.rectangle("fill", x * 32, y * 32, 32, 32)
                end
              end
            end
            Iso.sacar()
            love.graphics.pop()
          end
          Dibujo.fijarVista(nil)
          love.graphics.pop()
          fallar(errores, "se dibuja la escena en " .. nombre .. ": " .. tostring(err), ok)
          love.graphics.push("all")
          love.graphics.setCanvas({ cv, stencil = true })
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(celda, (col - 1) * CW, (fila - 1) * CH)
          love.graphics.pop()
        end
      end
    end
    local seg = love.timer.getTime() - t0
    local img = love.graphics.getStats().texturememory - memAntes
    Log.info(string.format("mapa FAO: %d objetos dibujables; primera escena %.0f ms, todas %.0f ms, memoria de texturas añadida %.0f MB", #m.objetos, (primero or 0) * 1000, seg * 1000, img / 1048576))
    fallar(errores, "las escenas del mapa de FAO se hornean y dibujan en menos de 6 s (medido " .. string.format("%.2f", seg) .. " s)", seg < 6)
    fallar(errores, "la memoria de texturas que añade el mapa no se dispara (< 400 MB, medido " .. string.format("%.0f", img / 1048576) .. " MB)", img < 400 * 1048576)
    -- DC_PRUEBA_MAPA_FAO=grid: 12 puntos repartidos por todo el mapa (la misma vista del juego, zoom 1,6) para revisar el renderizado en conjunto
    if os.getenv("DC_PRUEBA_MAPA_FAO") == "grid" then
      local puntos = {}
      -- puntos de interés: junto a los riscos (tilesets 0x35 / 0x36), bosques densos, la isla del noroeste, el borde del mapa y el puente
      local function buscar(cond)
        for y = 3, mapa.h - 4, 3 do
          for x = 3, mapa.w - 4, 3 do
            if Mapa.transitable(mapa, x, y) and cond(x, y) and not (puntos._v and puntos._v[x .. "," .. y]) then return x, y end
          end
        end
      end
      local function junto(x, y, ts)
        for dx = -3, 3 do for dy = -3, 3 do
          local cx, cy = math.max(0, math.min(mapa.w - 1, x + dx)), math.max(0, math.min(mapa.h - 1, y + dy))
          if m.ts[cy * mapa.w + cx + 1] == ts then return true end
        end end
        return false
      end
      local function lista(cond, n)
        local hechos, out = {}, {}
        for y = 3, mapa.h - 4, 4 do
          for x = 3, mapa.w - 4, 4 do
            if #out < n and Mapa.transitable(mapa, x, y) and cond(x, y) then
              local lejos = true
              for _, o in ipairs(out) do if math.abs(o[1] - x) < 25 and math.abs(o[2] - y) < 25 then lejos = false end end
              if lejos then out[#out + 1] = { x, y } end
            end
          end
        end
        return out
      end
      for _, p in ipairs(lista(function(x, y) return junto(x, y, 0x35) or junto(x, y, 0x36) end, 3)) do puntos[#puntos + 1] = { p[1] / mapa.w, p[2] / mapa.h } end
      for _, p in ipairs(lista(function(x, y) return contar(x, y, 7) >= 8 end, 4)) do puntos[#puntos + 1] = { p[1] / mapa.w, p[2] / mapa.h } end
      for _, p in ipairs(lista(function(x, y) return x < 90 and y < 40 end, 2)) do puntos[#puntos + 1] = { p[1] / mapa.w, p[2] / mapa.h } end
      for _, p in ipairs(lista(function(x, y) return x > mapa.w - 10 or y > mapa.h - 10 or y < 8 end, 3)) do puntos[#puntos + 1] = { p[1] / mapa.w, p[2] / mapa.h } end
      local GW, GH = 420, 300
      local grid = love.graphics.newCanvas(GW * 4, GH * 3)
      local celdaG = love.graphics.newCanvas(GW, GH)
      for k, fr in ipairs(puntos) do
        local bx, by = math.floor(fr[1] * mapa.w), math.floor(fr[2] * mapa.h)
        local hallado
        for r = 0, 20 do
          for dy = -r, r do for dx = -r, r do
            if not hallado and Mapa.transitable(mapa, bx + dx, by + dy) then hallado = { bx + dx, by + dy } end
          end end
          if hallado then break end
        end
        if hallado then
          pj.x, pj.y, pj.mov, pj.velx = hallado[1] + 0.5, hallado[2] + 0.5, false, 0
          love.graphics.push("all")
          love.graphics.setCanvas({ celdaG, stencil = true })
          love.graphics.clear(0, 0, 0, 1)
          Dibujo.fijarVista(0, 0, GW, GH)
          local cam = Dibujo.camara(pj, 1.6, mapa)
          pcall(Dibujo.escena, mundo, pj, cam, -1, -1)
          Dibujo.fijarVista(nil)
          love.graphics.pop()
          love.graphics.push("all")
          love.graphics.setCanvas(grid)
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(celdaG, ((k - 1) % 4) * GW, math.floor((k - 1) / 4) * GH)
          love.graphics.setColor(1, 1, 0.4)
          love.graphics.print(hallado[1] .. "," .. hallado[2], ((k - 1) % 4) * GW + 4, math.floor((k - 1) / 4) * GH + 4)
          love.graphics.pop()
        end
      end
      Log.volcar("capturas/mapa_fao_grid.png", grid:newImageData():encode("png"):getString())
    end
    -- DC_PRUEBA_MAPA_FAO=catalogo: todos los tipos de objeto del mapa (primer cuadro) con su id, para revisar uno a uno cómo se dibujan
    if os.getenv("DC_PRUEBA_MAPA_FAO") == "catalogo" then
      local ids = {}
      for id in pairs(m.defs) do ids[#ids + 1] = id end
      table.sort(ids)
      local CW2, CH2, COLS = 150, 150, 10
      local filas2 = math.ceil(#ids / COLS)
      local cat = love.graphics.newCanvas(CW2 * COLS, CH2 * filas2)
      love.graphics.push("all")
      love.graphics.setCanvas({ cat, stencil = true })
      love.graphics.clear(0.30, 0.45, 0.30, 1)
      for k, id in ipairs(ids) do
        local cx, cy = ((k - 1) % COLS) * CW2, math.floor((k - 1) / COLS) * CH2
        love.graphics.push()
        love.graphics.setScissor(cx, cy, CW2, CH2)
        love.graphics.setColor(0.25, 0.4, 0.25, 1)
        love.graphics.rectangle("line", cx + 0.5, cy + 0.5, CW2 - 1, CH2 - 1)
        MapaMpc.dibujarObjeto(mapa, { id = id, x = 0, y = 0 }, cx + CW2 / 2, cy + CH2 - 30, 0)
        love.graphics.setColor(1, 1, 0.4)
        love.graphics.print(id .. (m.defs[id].mezcla == "add" and " +" or "") .. (m.defs[id].b and " B" or ""), cx + 3, cy + 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.sub(m.defs[id].c, 1, 22) .. " x" .. #m.defs[id].f, cx + 3, cy + CH2 - 14)
        love.graphics.setScissor()
        love.graphics.pop()
      end
      love.graphics.pop()
      Log.volcar("capturas/mapa_fao_catalogo.png", cat:newImageData():encode("png"):getString())
    end
    -- el minimapa del HUD funciona dentro del mapa de FAO (antes ponía "sin mapa")
    do
      local Interfaz = require("src.presentacion.interfaz")
      pj.x, pj.y = zonas.costa[1] + 0.5, zonas.costa[2] + 0.5
      local mini = love.graphics.newCanvas(900, 300)
      love.graphics.push("all")
      love.graphics.setCanvas({ mini, stencil = true })
      love.graphics.clear(0.2, 0.25, 0.3, 1)
      local okm, errm = pcall(Interfaz.flotantes, mundo, pj, 900, 300)
      love.graphics.pop()
      fallar(errores, "el HUD con el minimapa se dibuja dentro del mapa de FAO: " .. tostring(errm), okm)
      if vista then Log.volcar("capturas/mapa_fao_minimapa.png", mini:newImageData():encode("png"):getString()) end
    end
    if vista then
      Log.info("mapa FAO capturas: " .. #m.objetos)
      Log.volcar("capturas/mapa_fao.png", cv:newImageData():encode("png"):getString())
      -- mapa completo con el bloqueo: 4 px por casilla; rojo = bloqueada por el agua profunda, amarillo = por un objeto
      local S = 8
      local datos = love.image.newImageData(mapa.w * S, mapa.h * S)
      for x = 0, mapa.w - 1 do
        for y = 0, mapa.h - 1 do
          local c = m.tilesets[m.ts[(y * 2) * m.fw + x * 2 + 1]].color
          local r, g, b = c[1] / 255, c[2] / 255, c[3] / 255
          if mapa.bloque[x][y] then r, g, b = r * 0.5 + 0.5, g * 0.4, b * 0.4 end
          for dx = 0, S - 1 do for dy = 0, S - 1 do datos:setPixel(x * S + dx, y * S + dy, r, g, b, 1) end end
        end
      end
      Log.volcar("capturas/mapa_fao_bloqueo.png", datos:encode("png"):getString())
    end
  end)
  -- Efectos de FAO de la pantera (guerrero) y la nova (mago): se lanzan por el servidor y se dibujan en una escena real. Con DC_PRUEBA_EFECTOS_FAO=1 guarda
  -- juego/capturas/efectos_fao.png (pantera arriba, nova abajo, cuatro instantes cada una).
  paso("efectos de FAO: pantera y nova se lanzan y se dibujan en la escena", function()
    local Dibujo = require("src.presentacion.render.dibujo")
    local Iso = require("src.presentacion.render.iso")
    local Mapa = require("compartido.dominio.mapa")
    local vista = os.getenv("DC_PRUEBA_EFECTOS_FAO") ~= nil
    local mosaico = vista and love.graphics.newCanvas(1920, 810) or nil
    for fila, caso in ipairs({ { clase = "guerrero", poder = "pantera", dist = 0.8, ts = { 0.15, 0.3, 0.5, 0.7 } }, { clase = "guerrero", poder = "tajo", dist = 1.6, ts = { 0.1, 0.3, 0.6, 0.9 }, extra = { { 2.2, -1 }, { -1.5, 1.2 } }, fuera = { { 3.6, 0.5 }, { -3.2, -2 } } },
      { clase = "mago", poder = "nova", dist = 4, ts = { 0.3, 0.6, 0.9, 1.2 } } }) do
      local mundo = Mundo.nuevo()
      local pj = mundo:crearPersonaje({ nombre = "Lanzador", faccion = "albor", clase = caso.clase, nivel = 30 })
      local c = mundo.mapas.mundo.ciudades[1]
      pj.x, pj.y = c.spawn.x, c.spawn.y
      -- un claro de hierba lejos de las ciudades (que no haya muros ni guardias en la foto)
      local mapa0 = mundo.mapas.mundo
      for r = 14, 60, 2 do
        local hallado
        for dx = -r, r, 2 do
          for _, dy in ipairs({ -r, r }) do
            local x, y = math.floor(c.spawn.x + dx), math.floor(c.spawn.y + dy)
            local libre = x > 8 and y > 8 and x < mapa0.w - 8 and y < mapa0.h - 8
            for i = -6, 6, 2 do for j = -6, 6, 2 do
              if libre and not (Mapa.transitable(mapa0, x + i, y + j) and mapa0.suelo[x + i][y + j] == "hierba") then libre = false end
            end end
            if libre then hallado = { x + 0.5, y + 0.5 } break end
          end
          if hallado then break end
        end
        if hallado then pj.x, pj.y = hallado[1], hallado[2] break end
      end
      local rival = { id = 900, kind = "monstruo", faccion = "bestia", nombre = "Rival", x = pj.x + caso.dist, y = pj.y + (caso.dist > 0 and 1.5 or 2),
        vivo = true, hp = 100000, hpMax = 100000, modo = "mundo", z = 0, nivel = 1 }
      mundo.entidades[900] = rival
      -- tajo: enemigos dentro y fuera del radio real (rango en habilidades.xml), para comprobar que el anillo dibujado coincide con a quién golpea
      local dentro, fuera = { rival }, {}
      for i, o in ipairs(caso.extra or {}) do
        local m = { id = 910 + i, kind = "monstruo", faccion = "bestia", nombre = "Dentro", x = pj.x + o[1], y = pj.y + o[2], vivo = true, hp = 100000, hpMax = 100000, modo = "mundo", z = 0, nivel = 1 }
        mundo.entidades[m.id] = m
        dentro[#dentro + 1] = m
      end
      for i, o in ipairs(caso.fuera or {}) do
        local m = { id = 920 + i, kind = "monstruo", faccion = "bestia", nombre = "Fuera", x = pj.x + o[1], y = pj.y + o[2], vivo = true, hp = 100000, hpMax = 100000, modo = "mundo", z = 0, nivel = 1 }
        mundo.entidades[m.id] = m
        fuera[#fuera + 1] = m
      end
      local slot
      for i, id in ipairs(Datos.barra[caso.clase]) do if id == caso.poder then slot = i end end
      fallar(errores, caso.poder .. " está en la barra de " .. caso.clase, slot ~= nil)
      pj.habilidades = pj.habilidades or {}
      pj.habilidades[caso.poder] = 1
      pj.mp, pj.mpMax = 999, 999
      pj.objetivo = rival.id
      local res = mundo:usarHabilidad(pj, slot or 1)
      fallar(errores, caso.poder .. " se lanza sin error", res == nil, tostring(res))
      local fx
      for _, e in ipairs(mundo.efectos) do if e.tipo == caso.poder then fx = e end end
      fallar(errores, caso.poder .. " crea su efecto", fx ~= nil)
      if caso.poder == "tajo" then
        local golpeados, intactos = 0, 0
        for _, m in ipairs(dentro) do if m.hp < m.hpMax then golpeados = golpeados + 1 end end
        for _, m in ipairs(fuera) do if m.hp == m.hpMax then intactos = intactos + 1 end end
        fallar(errores, "el tajo golpea a los " .. #dentro .. " enemigos dentro del radio", golpeados == #dentro, golpeados .. "/" .. #dentro)
        fallar(errores, "y no a los " .. #fuera .. " de fuera", intactos == #fuera, intactos .. "/" .. #fuera)
      end
      if fx then
        fallar(errores, caso.poder .. " dura lo que su animación", fx.dur >= 0.9, tostring(fx.dur))
        if caso.poder == "pantera" then
          fallar(errores, "la pantera sabe de dónde sale (y adónde va)", fx.x0 == pj.x and fx.y0 == pj.y and fx.x == rival.x and fx.y == rival.y)
          local snap = mundo:efectosCercanos(pj)
          local visto
          for _, e in ipairs(snap) do if e.tipo == "pantera" then visto = e end end
          fallar(errores, "el efecto llega al cliente con su origen", visto and visto.x0 == pj.x)
        end
      end
      Interfaz.escala = 1
      local cv = love.graphics.newCanvas(1280, 720)
      for k, tt in ipairs(caso.ts) do
        if fx then fx.t = tt end
        love.graphics.push("all")
        love.graphics.setCanvas({ cv, stencil = true })
        love.graphics.clear(0, 0, 0, 1)
        local cam = Dibujo.camara(pj, 2, mundo:mapaDe(pj))
        local ok, err = pcall(Dibujo.escena, mundo, pj, cam, 0, 0)
        love.graphics.pop()
        fallar(errores, "la escena con " .. caso.poder .. " se dibuja en t=" .. tt, ok, tostring(err))
        if mosaico then
          love.graphics.push("all")
          love.graphics.setCanvas(mosaico)
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(cv, love.graphics.newQuad(400, 225, 480, 270, 1280, 720), (k - 1) * 480, (fila - 1) * 270)
          love.graphics.pop()
        end
      end
    end
    if mosaico then Log.volcar("capturas/efectos_fao.png", mosaico:newImageData():encode("png"):getString()) end
  end)
  -- Golpe (Slicing Chop): el guerrero golpea a un enemigo desde las 8 direcciones; con DC_PRUEBA_EFECTOS_FAO=1 guarda juego/capturas/efectos_golpe.png (una fila por dirección, cuatro instantes).
  paso("efectos de FAO: el golpe se dibuja orientado en las 8 direcciones", function()
    local Dibujo = require("src.presentacion.render.dibujo")
    local Mapa = require("compartido.dominio.mapa")
    local vista = os.getenv("DC_PRUEBA_EFECTOS_FAO") ~= nil
    local CW, CH = 260, 190
    local mosaico = vista and love.graphics.newCanvas(CW * 4, CH * 8) or nil
    local dirs = { { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, 0 }, { -1, -1 }, { 0, -1 }, { 1, -1 } }
    local cv = love.graphics.newCanvas(1280, 720)
    for fila, d in ipairs(dirs) do
      local mundo = Mundo.nuevo()
      local pj = mundo:crearPersonaje({ nombre = "Lanzador", faccion = "albor", clase = "guerrero", nivel = 30 })
      local c = mundo.mapas.mundo.ciudades[1]
      pj.x, pj.y = c.spawn.x, c.spawn.y
      local mapa0 = mundo.mapas.mundo
      for r = 14, 60, 2 do
        local hallado
        for dx = -r, r, 2 do
          for _, dy in ipairs({ -r, r }) do
            local x, y = math.floor(c.spawn.x + dx), math.floor(c.spawn.y + dy)
            local libre = x > 8 and y > 8 and x < mapa0.w - 8 and y < mapa0.h - 8
            for i = -4, 4, 2 do for j = -4, 4, 2 do
              if libre and not (Mapa.transitable(mapa0, x + i, y + j) and mapa0.suelo[x + i][y + j] == "hierba") then libre = false end
            end end
            if libre then hallado = { x + 0.5, y + 0.5 } break end
          end
          if hallado then break end
        end
        if hallado then pj.x, pj.y = hallado[1], hallado[2] break end
      end
      local largo = math.sqrt(d[1] * d[1] + d[2] * d[2])
      local rival = { id = 900, kind = "monstruo", faccion = "bestia", nombre = "Rival", x = pj.x + d[1] / largo * 1.2, y = pj.y + d[2] / largo * 1.2,
        vivo = true, hp = 100000, hpMax = 100000, modo = "mundo", z = 0, nivel = 1 }
      mundo.entidades[900] = rival
      pj.mp, pj.mpMax, pj.objetivo = 999, 999, 900
      local res = mundo:usarHabilidad(pj, 1)
      fallar(errores, "el golpe se lanza sin error desde la dirección " .. fila, res == nil, tostring(res))
      local fx
      for _, e in ipairs(mundo.efectos) do if e.tipo == "golpe" then fx = e end end
      fallar(errores, "el golpe crea su efecto con el origen del atacante", fx ~= nil and fx.x0 == pj.x and fx.dur >= 0.8)
      fallar(errores, "el golpe hizo daño", rival.hp < rival.hpMax)
      for k, tt in ipairs({ 0.05, 0.2, 0.35, 0.6 }) do
        if fx then fx.t = tt end
        love.graphics.push("all")
        love.graphics.setCanvas({ cv, stencil = true })
        love.graphics.clear(0, 0, 0, 1)
        local cam = Dibujo.camara(pj, 2, mundo:mapaDe(pj))
        local ok, err = pcall(Dibujo.escena, mundo, pj, cam, 0, 0)
        love.graphics.pop()
        fallar(errores, "la escena con el golpe se dibuja", ok, tostring(err))
        if mosaico then
          love.graphics.push("all")
          love.graphics.setCanvas(mosaico)
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(cv, love.graphics.newQuad(640 - CW / 2, 340 - CH / 2, CW, CH, 1280, 720), (k - 1) * CW, (fila - 1) * CH)
          love.graphics.pop()
        end
      end
    end
    if mosaico then Log.volcar("capturas/efectos_golpe.png", mosaico:newImageData():encode("png"):getString()) end
  end)
  -- Criaturas de los campamentos del editor dentro de los mapas de FAO: el cliente las dibuja con su animación de siempre. Con DC_PRUEBA_CRIATURAS_FAO=1 guarda juego/capturas/criaturas_fao.png
  -- (una fila por mapa: llegada, pelea, muerte y reaparición).
  pasoFao("criaturas en mapas de FAO: se dibujan, pelean y reaparecen dentro del mapa", function()
    local Dibujo = require("src.presentacion.render.dibujo")
    local vista = os.getenv("DC_PRUEBA_CRIATURAS_FAO") ~= nil
    local CW, CH = 480, 300
    local mosaico = vista and love.graphics.newCanvas(CW * 4, CH * 2) or nil
    local cv = love.graphics.newCanvas(1280, 720)
    local function foto(mundo, pj, col, fila)
      love.graphics.push("all")
      love.graphics.setCanvas({ cv, stencil = true })
      love.graphics.clear(0, 0, 0, 1)
      local cam = Dibujo.camara(pj, 2, mundo:mapaDe(pj))
      local ok, err = pcall(Dibujo.escena, mundo, pj, cam, 0, 0)
      love.graphics.pop()
      fallar(errores, "la escena del mapa de FAO con criaturas se dibuja", ok, tostring(err))
      if mosaico then
        love.graphics.push("all")
        love.graphics.setCanvas(mosaico)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(cv, love.graphics.newQuad(640 - CW / 2, 360 - CH / 2, CW, CH, 1280, 720), (col - 1) * CW, (fila - 1) * CH)
        love.graphics.pop()
      end
    end
    for fila, nombre in ipairs({ "granja_de_pinchos", "pozo_sin_fondo" }) do
      local mundo = Mundo.nuevo()
      local pj = mundo:crearPersonaje({ nombre = "Cazador", faccion = "albor", clase = "guerrero", nivel = 3 })
      pj.hp, pj.hpMax, pj.mp, pj.mpMax = 99999, 99999, 999, 999
      mundo:entrarMapaFao(pj, nombre)
      local mapa = mundo.mapas[nombre]
      local camp = mapa.campamentos[3]
      pj.x, pj.y = camp.x - 2.5, camp.y
      local mob
      for _, e in pairs(mundo.entidades) do
        if e.kind == "monstruo" and e.modo == nombre and (not mob or Util.dist(e.x, e.y, camp.x, camp.y) < Util.dist(mob.x, mob.y, camp.x, camp.y)) then mob = e end
      end
      fallar(errores, nombre .. ": hay criaturas junto al campamento", mob ~= nil)
      if mob then
        mob.agresivo = true
        local visibles = 0
        for _, e in ipairs(mundo:visibles(pj)) do if e.kind == "monstruo" then visibles = visibles + 1 end end
        fallar(errores, nombre .. ": el servidor manda las criaturas del mapa al jugador de dentro", visibles >= camp.cantidad, tostring(visibles))
        foto(mundo, pj, 1, fila)
        pj.x, pj.y = mob.x - 1, mob.y
        pj.objetivo = mob.id
        mob.hp, mob.hpMax = 1e7, 1e7
        for _ = 1, 25 do mundo:actualizar(0.1) end
        foto(mundo, pj, 2, fila)
        mob.hp = 1
        pj.cds = {}
        mundo:usarHabilidad(pj, 1)
        mundo:actualizar(0.05)
        fallar(errores, nombre .. ": muere", not mob.vivo)
        foto(mundo, pj, 3, fila)
        mob.respawn = mundo.tiempo + 0.2
        pj.objetivo = nil
        for _ = 1, 15 do mundo:actualizar(0.1) end
        fallar(errores, nombre .. ": reaparece", mob.vivo)
        foto(mundo, pj, 4, fila)
      end
    end
    if mosaico then Log.volcar("capturas/criaturas_fao.png", mosaico:newImageData():encode("png"):getString()) end
  end)
  -- Mapa 257 (Mariam Waterway) en el cliente: el jugador sobre los tablones se dibuja encima de ellos, la barca y las mesas bloquean y los objetos altos se atenúan si tapan al personaje.
  -- Con DC_PRUEBA_BARCA=1 guarda juego/capturas/mapa_fao_barca.png (arriba: en 29,34 sobre los tablones; en medio: junto a la barca, parado por ella; abajo: detrás de un objeto alto).
  pasoFao("mapa de FAO 257: tablones bajo el jugador, la barca lo detiene y el objeto alto se atenúa", function()
    local Dibujo = require("src.presentacion.render.dibujo")
    local Mapa = require("compartido.dominio.mapa")
    local MapaMpc = require("src.presentacion.render.mapa_mpc")
    local mundo = Mundo.nuevo()
    local mapa = mundo.mapas.canal_mariam
    local pj = mundo:crearPersonaje({ nombre = "Marinero", faccion = "albor", clase = "guerrero", nivel = 10 })
    pj.hp, pj.hpMax = 99999, 99999
    mundo:entrarMapaFao(pj, "canal_mariam")
    local vista = os.getenv("DC_PRUEBA_BARCA") ~= nil
    local CW, CH = 640, 400
    local mosaico = vista and love.graphics.newCanvas(CW * 2, CH * 2) or nil
    local cv = love.graphics.newCanvas(1280, 720)
    local function foto(col, fila)
      love.graphics.push("all")
      love.graphics.setCanvas({ cv, stencil = true })
      love.graphics.clear(0, 0, 0, 1)
      local cam = Dibujo.camara(pj, 2, mundo:mapaDe(pj))
      local ok, err = pcall(Dibujo.escena, mundo, pj, cam, 0, 0)
      love.graphics.pop()
      fallar(errores, "la escena del mapa 257 se dibuja", ok, tostring(err))
      if mosaico then
        love.graphics.push("all")
        love.graphics.setCanvas(mosaico)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(cv, love.graphics.newQuad(640 - CW / 2, 360 - CH / 2, CW, CH, 1280, 720), (col - 1) * CW, (fila - 1) * CH)
        love.graphics.pop()
      end
    end
    -- 1. sobre los tablones de 29,34 (el jugador tiene que verse entero, no tapado)
    pj.x, pj.y = 29.5, 34.5
    foto(1, 1)
    -- 2. caminando hacia la barca desde el norte hasta que lo detiene
    local barca
    for _, o in ipairs(mapa.mpc.objetos) do if o.id == 10756 then barca = o end end
    local gx, gy = math.floor(barca.x / 64), math.floor((barca.y - 1) / 64)
    pj.x, pj.y, pj.camino = gx + 0.5, gy - 2.5, nil
    pj.deseoX, pj.deseoY = 0, 1
    for _ = 1, 60 do mundo:actualizar(0.1) end
    pj.deseoX, pj.deseoY = 0, 0
    fallar(errores, "el jugador queda parado delante de la barca, no encima", not Mapa.bloqueado(mapa, pj.x, pj.y) and pj.y < barca.y / 64, string.format("%.1f,%.1f barca y=%.1f", pj.x, pj.y, barca.y / 64))
    foto(2, 1)
    -- 3. detrás de un objeto alto con z (barca u objeto grande): se atenúa y se ve al jugador
    local tapado = 0
    local m = require("src.presentacion.render.iso")
    pj.x, pj.y = barca.x / 64, barca.y / 64 - 1.6
    local sx, sy = barca.x / 64 * 0, 0
    for _, o in ipairs(mapa.mpc.objetos) do
      local d = mapa.mpc.defs[o.id]
      if d and d.z and not d.p and d.f[1][4] >= 80 then
        local jx, jy = o.x / 64, o.y / 64 - 1.2
        -- el torso del personaje (en píxeles de pantalla cenitales, 32 por casilla) dentro del sprite del objeto
        local px, py = jx * 32, jy * 32 - 20
        if MapaMpc.tapa(mapa, o, o.x / 64 * 32, o.y / 64 * 32, px, py) then tapado = tapado + 1 end
      end
    end
    fallar(errores, "los objetos altos con z atenúan cuando tapan al personaje", tapado > 20, tostring(tapado))
    local suelo = 0
    for _, o in ipairs(mapa.mpc.objetos) do
      local d = mapa.mpc.defs[o.id]
      if d and d.p and MapaMpc.tapa(mapa, o, o.x / 64 * 32, o.y / 64 * 32, o.x / 64 * 32, o.y / 64 * 32 - 20) then suelo = suelo + 1 end
    end
    fallar(errores, "las piezas de suelo nunca atenúan ni tapan", suelo == 0, tostring(suelo))
    foto(1, 2)
    -- 4. una mesa/puesto: bloquea
    local mesa
    for _, o in ipairs(mapa.mpc.objetos) do if o.id == 7523 or (mapa.mpc.defs[o.id] and mapa.mpc.defs[o.id].n:find("攤位", 1, true)) then mesa = o break end end
    fallar(errores, "hay un puesto/mesa en el mapa 257 y sus casillas están bloqueadas", mesa ~= nil and mapa.bloque[math.floor(mesa.x / 64)][math.floor((mesa.y - 1) / 64)])
    pj.x, pj.y = (mesa and mesa.x / 64 or 26) , (mesa and mesa.y / 64 + 1.5 or 36)
    foto(2, 2)
    if mosaico then Log.volcar("capturas/mapa_fao_barca.png", mosaico:newImageData():encode("png"):getString()) end
    -- los demás mapas siguen cargando
    for nombre in pairs(require("compartido.dominio.mapas_fao").MAPAS) do
      fallar(errores, "el mapa " .. nombre .. " carga", mundo.mapas[nombre] ~= nil and mundo.mapas[nombre].fao == true)
    end
  end)
  -- Portal de un continente a un mapa de FAO y montura dentro del mapa. Con DC_PRUEBA_PORTAL=1 guarda juego/capturas/portal_fao.png (portal en el mundo, montado dentro del mapa de FAO).
  pasoFao("portales: el portal se dibuja en el continente y la montura se ve dentro del mapa de FAO", function()
    local Dibujo = require("src.presentacion.render.dibujo")
    local mundo = Mundo.nuevo()
    local portal
    for _, e in pairs(mundo.entidades) do if e.kind == "portal" and e.faccion == "albor" and e.mapaFao == "granja_de_pinchos" then portal = e end end
    fallar(errores, "hay un portal de Albor a la granja de pinchos", portal ~= nil)
    local pj = mundo:crearPersonaje({ nombre = "Jinete", faccion = "albor", clase = "guerrero", nivel = 20 })
    pj.monturas = { "mnt_001" }
    pj.x, pj.y = portal.x - 2.5, portal.y + 0.5
    mundo:alternarMontura(pj, "mnt_001")
    local vista = os.getenv("DC_PRUEBA_PORTAL") ~= nil
    local CW, CH = 640, 400
    local mosaico = vista and love.graphics.newCanvas(CW * 2, CH) or nil
    local cv = love.graphics.newCanvas(1280, 720)
    local function foto(col)
      love.graphics.push("all")
      love.graphics.setCanvas({ cv, stencil = true })
      love.graphics.clear(0, 0, 0, 1)
      local cam = Dibujo.camara(pj, 2, mundo:mapaDe(pj))
      local ok, err = pcall(Dibujo.escena, mundo, pj, cam, 0, 0)
      love.graphics.pop()
      fallar(errores, "la escena con el portal / el jinete se dibuja", ok, tostring(err))
      if mosaico then
        love.graphics.push("all")
        love.graphics.setCanvas(mosaico)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(cv, love.graphics.newQuad(640 - CW / 2, 360 - CH / 2, CW, CH, 1280, 720), (col - 1) * CW, 0)
        love.graphics.pop()
      end
    end
    for _ = 1, 3 do mundo:actualizar(0.1) end
    foto(1)
    mundo:entrarMapaFao(pj, "granja_de_pinchos")
    for _ = 1, 20 do mundo:actualizar(0.1) end
    fallar(errores, "dentro del mapa de FAO sigue montado", pj.montado == "mnt_001")
    foto(2)
    if mosaico then Log.volcar("capturas/portal_fao.png", mosaico:newImageData():encode("png"):getString()) end
    -- el mapa principal (M) y el minimapa muestran los portales con el nombre del mapa al que llevan
    mundo:salirMapaFao(pj)
    pj.x, pj.y = portal.x - 4, portal.y
    local Interfaz = require("src.presentacion.interfaz")
    Interfaz.escala, Interfaz.panel, Interfaz.mapaZoom, Interfaz.mapaTab = 1, "mapa", 2, "pnj"
    local pan = love.graphics.newCanvas(1280, 720)
    love.graphics.push("all")
    love.graphics.setCanvas({ pan, stencil = true })
    love.graphics.clear(0.1, 0.1, 0.12, 1)
    local okm, errm = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    love.graphics.pop()
    fallar(errores, "el panel del mapa con los portales se dibuja: " .. tostring(errm), okm)
    local propios = 0
    for _, pt in ipairs(mundo.portalesFao) do if pt.faccion == pj.faccion then propios = propios + 1 end end
    fallar(errores, "el mundo tiene los portales del continente del jugador para el mapa", propios >= 5, tostring(propios))
    if vista then Log.volcar("capturas/portal_fao_mapa.png", pan:newImageData():encode("png"):getString()) end
    Interfaz.panel = nil
  end)
  -- Efectos de capas de FAO de los poderes de guerrero, lancero, cazador, clérigo y nigromante: cada poder se lanza por el servidor y se dibuja en una escena real en cuatro instantes. Con
  -- DC_PRUEBA_PODERES_FAO=1 guarda juego/capturas/poderes_fao_<clase>.png (una fila por poder).
  paso("efectos de FAO de las demás clases: los 27 poderes se lanzan y se dibujan", function()
    local Dibujo = require("src.presentacion.render.dibujo")
    local Mapa = require("compartido.dominio.mapa")
    local Efectos = require("src.presentacion.render.efectos")
    local Poderes = require("compartido.datos.efectos_fao_poderes")
    local vista = os.getenv("DC_PRUEBA_PODERES_FAO") ~= nil
    local CW, CH = 520, 300
    local cv = love.graphics.newCanvas(1280, 720)
    local total = 0
    for _, clase in ipairs({ "guerrero", "lancero", "cazador", "clerigo", "nigromante", "mago" }) do
      local mosaico = vista and love.graphics.newCanvas(CW * 4, CH * #Datos.barra[clase]) or nil
      for fila, id in ipairs(Datos.barra[clase]) do
        if Poderes[id] then
          total = total + 1
          local mundo = Mundo.nuevo()
          local pj = mundo:crearPersonaje({ nombre = "Lanzador", faccion = "albor", clase = clase, nivel = 30 })
          local c = mundo.mapas.mundo.ciudades[1]
          pj.x, pj.y = c.spawn.x, c.spawn.y
          local mapa0 = mundo.mapas.mundo
          for r = 14, 60, 2 do
            local hallado
            for dx = -r, r, 2 do
              for _, dy in ipairs({ -r, r }) do
                local x, y = math.floor(c.spawn.x + dx), math.floor(c.spawn.y + dy)
                local libre = x > 8 and y > 8 and x < mapa0.w - 8 and y < mapa0.h - 8
                for i = -6, 6, 2 do for j = -6, 6, 2 do
                  if libre and not (Mapa.transitable(mapa0, x + i, y + j) and mapa0.suelo[x + i][y + j] == "hierba") then libre = false end
                end end
                if libre then hallado = { x + 0.5, y + 0.5 } break end
              end
              if hallado then break end
            end
            if hallado then pj.x, pj.y = hallado[1], hallado[2] break end
          end
          local dd = math.min(4, ((Datos.habilidades[id] and Datos.habilidades[id].rango) or 4) * 0.85)
          local rival = { id = 900, kind = "monstruo", faccion = "bestia", nombre = "Rival", x = pj.x + dd * 0.95, y = pj.y + dd * 0.3, vivo = true, hp = 1e7, hpMax = 1e7, modo = "mundo", z = 0, nivel = 1 }
          mundo.entidades[900] = rival
          pj.habilidades = pj.habilidades or {}
          pj.habilidades[id] = 1
          pj.hp, pj.hpMax, pj.mp, pj.mpMax, pj.objetivo, pj.cds = 99999, 99999, 9999, 9999, 900, {}
          if id == "resurreccion" then
            local c = mundo:crearPersonaje({ nombre = "Caido", faccion = pj.faccion, clase = "guerrero", nivel = 10 })
            c.x, c.y, c.modo = pj.x + 1, pj.y, pj.modo
            mundo:morir(c, nil)
          end
          local res = mundo:usarHabilidad(pj, fila, rival.x, rival.y)
          fallar(errores, id .. " se lanza (" .. tostring(res) .. ")", res == nil or res == "Te acercas.")
          local fx
          for _, e in ipairs(mundo.efectos) do if e.tipo == id then fx = e end end
          fallar(errores, id .. " crea su efecto de FAO con su duración", fx ~= nil and math.abs(fx.dur - Poderes[id].dur) < 0.01, fx and tostring(fx.dur) or "sin efecto")
          fallar(errores, id .. " tiene definición en el cliente", Efectos.def[id] and Efectos.def[id].capas == true)
          local ok0, err0 = pcall(Efectos.icono, id, 0, 0, 40)
          fallar(errores, "miniatura de " .. id, ok0, tostring(err0))
          if fx then
            local dur = Poderes[id].dur
            for k, frac in ipairs({ 0.12, 0.25, 0.4, 0.65 }) do
              fx.t = dur * frac
              love.graphics.push("all")
              love.graphics.setCanvas({ cv, stencil = true })
              love.graphics.clear(0, 0, 0, 1)
              local cam = Dibujo.camara(pj, 2, mundo:mapaDe(pj))
              local ok, err = pcall(Dibujo.escena, mundo, pj, cam, 0, 0)
              love.graphics.pop()
              fallar(errores, "la escena con " .. id .. " se dibuja en t=" .. string.format("%.2f", fx.t), ok, tostring(err))
              if mosaico then
                love.graphics.push("all")
                love.graphics.setCanvas(mosaico)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(cv, love.graphics.newQuad(640 - 120, 360 - 130, CW, CH, 1280, 720), (k - 1) * CW, (fila - 1) * CH)
                love.graphics.pop()
              end
            end
          end
        end
      end
      if mosaico then Log.volcar("capturas/poderes_fao_" .. clase .. ".png", mosaico:newImageData():encode("png"):getString()) end
    end
    fallar(errores, "se probaron los 60 poderes (las seis clases)", total == 60, tostring(total))
  end)
  -- Asedio (MOBA) en el cliente: se dibujan nexos, torres, esbirros y el marcador, el panel de guerra tiene su botón y el minimapa los marca. Con DC_PRUEBA_MOBA=1 guarda juego/capturas/moba.png
  -- (escena junto a una torre con esbirros, y el panel de guerra con el asedio).
  paso("mascotas: todas las formas y los paneles se dibujan sin errores", function()
    local I = require("src.presentacion.interfaz")
    local Personajes = require("src.presentacion.render.personajes")
    local cv = love.graphics.newCanvas(1400, 260)
    love.graphics.setCanvas({ cv, stencil = true })
    love.graphics.clear(0.15, 0.3, 0.15, 1)
    local ok, err = pcall(function()
      local x = 70
      for _, id in ipairs({ "osito_1", "osito_2", "osito_3", "dragon_1", "dragon_2", "dragon_3", "angel_1", "angel_2", "angel_3", "demonio_1", "demonio_2", "demonio_3" }) do
        local def = Personajes.de({ kind = "mascota", especie = id })
        fallar(errores, "la forma " .. id .. " tiene dibujo animado", def ~= nil and def.anim ~= nil)
        Personajes.dibujar(def, 1, false, 0, x, 200)
        x = x + 110
      end
    end)
    love.graphics.setCanvas()
    fallar(errores, "se dibuja sin errores", ok, tostring(err))
    if os.getenv("DC_PRUEBA_MASCOTAS") then Log.volcar("capturas/mascotas_formas.png", cv:newImageData():encode("png"):getString()) end
    -- los tres sitios donde se ven: tus mascotas (N), la tienda del mercado y el Item Mall
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Cria", faccion = "albor", clase = "guerrero", nivel = 30 })
    pj.oro, pj.monedas = 5000, 3000
    pj.mall = { monedas = 3000, addons = {} }
    pj.mascotas = { { especie = "osito_2", nivel = 14, xp = 100 }, { especie = "dragon_1", nivel = 5, xp = 30 }, { especie = "perro_rastreador", nivel = 1, xp = 0 } }
    pj.mascotaActiva = 1
    local function foto(nombre, preparar)
      local c2 = love.graphics.newCanvas(1280, 720)
      love.graphics.push("all")
      love.graphics.setCanvas({ c2, stencil = true })
      love.graphics.clear(0.2, 0.3, 0.2, 1)
      preparar()
      local ok2, err2 = pcall(I.hud, mundo, pj, 1280, 720)
      love.graphics.pop()
      fallar(errores, "se dibuja " .. nombre, ok2, tostring(err2))
      if os.getenv("DC_PRUEBA_MASCOTAS") then Log.volcar("capturas/mascotas_" .. nombre .. ".png", c2:newImageData():encode("png"):getString()) end
    end
    I.escala = 1
    foto("hud", function() I.panel = nil end)
    foto("lista", function() I.panel = "mascotas" end)
    foto("tienda", function() I.panel, I.tienda, I.mercadoTab, I.scroll = "mercado", "mercado", "mascotas", 0 end)
    foto("mall", function() I.panel, I.mallTab, I.mallScroll = "mall", "mascotas", 0 end)
    foto("mall_objetos", function() I.panel, I.mallTab, I.mallScroll = "mall", "objetos", 0 end)
    foto("mall_monturas", function() I.panel, I.mallTab, I.mallScroll = "mall", "monturas", 0 end)
    foto("mall_addons", function() I.panel, I.mallTab, I.mallScroll = "mall", "addons", 0 end)
    I.panel = nil
  end)
  pasoMoba("asedio (MOBA): escena, marcador, minimapa y panel de guerra", function()
    local Dibujo = require("src.presentacion.render.dibujo")
    local mundo = Mundo.nuevo()
    local vista = os.getenv("DC_PRUEBA_MOBA") ~= nil
    fallar(errores, "el cliente calcula la arena del asedio cuando la necesita", mundo:asegurarArenaMoba() and mundo.mapas.moba ~= nil)
    if not mundo.mapas.moba then return end
    local equipo = {}
    for i = 1, 2 do
      for _, f in ipairs({ "albor", "umbra" }) do
        local p = mundo:crearPersonaje({ nombre = f .. i, faccion = f, clase = i == 1 and "guerrero" or "mago", nivel = 20 })
        p.hp, p.hpMax, p.ultimoGolpe = 5000, 5000, -99
        mundo:entrarGuerra(p, "moba")
        equipo[#equipo + 1] = p
      end
    end
    local pj = equipo[1]
    local tuMoba = mundo:construirTu(pj)         -- (lo que el servidor le manda al cliente: nivel de desbloqueo de cada poder)
    pj.mobaNiveles, pj.xpSig = tuMoba.mobaNiveles, tuMoba.xpSig
    for _ = 1, 140 do mundo:actualizar(0.1) end
    -- junto a la primera torre de Albor, con esbirros por el camino
    local torre
    for _, e in pairs(mundo.entidades) do if e.torre and e.faccion == "albor" and (not torre or e.x < torre.x) then torre = e end end
    fallar(errores, "hay torres en el asedio", torre ~= nil)
    if not torre then return end
    -- se pone al jugador junto a un esbirro propio (si hay) para verlos avanzar; si no, junto a la torre
    local esb
    for _, e in pairs(mundo.entidades) do if e.moba and e.kind == "monstruo" and e.faccion == "albor" and e.vivo and (not esb or e.x > esb.x) then esb = e end end
    fallar(errores, "hay esbirros de Albor en el camino", esb ~= nil)
    if esb then pj.x, pj.y = esb.x - 2.5, esb.y else pj.x, pj.y = torre.x - 3, torre.y end
    local Interfaz = require("src.presentacion.interfaz")
    Interfaz.escala, Interfaz.panel = 1, nil
    local cv = love.graphics.newCanvas(1280, 720)
    love.graphics.push("all")
    love.graphics.setCanvas({ cv, stencil = true })
    love.graphics.clear(0, 0, 0, 1)
    local cam = Dibujo.camara(pj, 2, mundo:mapaDe(pj))
    local ok, err = pcall(Dibujo.escena, mundo, pj, cam, 0, 0)
    fallar(errores, "la escena del asedio se dibuja: " .. tostring(err), ok)
    love.graphics.setCanvas({ cv, stencil = true })
    local ok2, err2 = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el marcador y el minimapa del asedio se dibujan: " .. tostring(err2), ok2)
    love.graphics.pop()
    local pan = love.graphics.newCanvas(1280, 720)
    love.graphics.push("all")
    love.graphics.setCanvas({ pan, stencil = true })
    love.graphics.clear(0.1, 0.1, 0.12, 1)
    Interfaz.panel = "guerra"
    local ok3, err3 = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    love.graphics.pop()
    Interfaz.panel = nil
    fallar(errores, "el panel de guerra con el asedio se dibuja: " .. tostring(err3), ok3)
    -- pantalla de «has caído» y tarjeta de cola (quien espera en el mundo)
    local caido = love.graphics.newCanvas(1280, 720)
    love.graphics.push("all")
    love.graphics.setCanvas({ caido, stencil = true })
    love.graphics.clear(0.1, 0.12, 0.1, 1)
    pj.vivo, pj.hp, pj.respawnResta = false, 0, 4
    local ok4, err4 = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    love.graphics.pop()
    pj.vivo, pj.hp, pj.respawnResta = true, 5000, nil
    fallar(errores, "la pantalla de «has caído» se dibuja: " .. tostring(err4), ok4)
    local cola = love.graphics.newCanvas(1280, 720)
    local espera = mundo:crearPersonaje({ nombre = "Esperando", faccion = "umbra", clase = "mago", nivel = 20 })
    espera.ultimoGolpe = -99
    mundo:entrarGuerra(espera, "batalla")
    love.graphics.push("all")
    love.graphics.setCanvas({ cola, stencil = true })
    love.graphics.clear(0.1, 0.12, 0.1, 1)
    local ok5, err5 = pcall(Interfaz.hud, mundo, espera, 1280, 720)
    love.graphics.pop()
    fallar(errores, "la tarjeta de cola se dibuja: " .. tostring(err5), ok5 and espera.colaGuerra == "batalla")
    if vista then
      local mosaico = love.graphics.newCanvas(2560, 1440)
      love.graphics.push("all")
      love.graphics.setCanvas(mosaico)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(cv, 0, 0)
      love.graphics.draw(pan, 1280, 0)
      love.graphics.draw(caido, 0, 720)
      love.graphics.draw(cola, 1280, 720)
      love.graphics.pop()
      Log.volcar("capturas/moba.png", mosaico:newImageData():encode("png"):getString())
    end
  end)
  paso("sprites de hechizos: cada poder de cada clase tiene su hoja generada", function()
    local Efectos = require("src.presentacion.render.efectos")
    local Dibujo = require("src.presentacion.render.dibujo")
    local Arte = require("src.presentacion.render.arte")
    local cv = love.graphics.newCanvas(300, 300)
    local n = 0
    for _, clase in ipairs({ "guerrero", "mago", "cazador", "clerigo" }) do
      for _, id in ipairs(Datos.barra[clase]) do
        local d = Efectos.def[id]
        -- la pantera y la nova (ventisca) son compuestos con sprites de FAO (efectos_fao.lua); el resto usa una hoja de hechizo propia
        fallar(errores, id .. " (" .. clase .. ") usa una hoja de hechizo propia", d and (d.fao or d[1] == "Hechizo_" .. id), d and d[1] or "sin efecto")
        if not (d and d.fao) then
          local img = Arte.img("Animations/Hechizo_" .. id .. ".png", true)
          fallar(errores, "la hoja de " .. id .. " mide 5x3 cuadros de 192", img:getWidth() == 960 and img:getHeight() == 576)
        end
        for _, tt in ipairs({ 0, 0.2, 0.5, 0.8, 1 }) do
          love.graphics.push("all")
          love.graphics.setCanvas({ cv, stencil = true })
          local ok, err = pcall(Efectos.cuadro, id, tt, 1, 150, 150)
          love.graphics.pop()
          fallar(errores, "se dibuja " .. id .. " en t=" .. tt, ok, tostring(err))
          n = n + 1
        end
        -- la miniatura de la barra de poderes
        love.graphics.push("all")
        love.graphics.setCanvas({ cv, stencil = true })
        local ok2, err2 = pcall(Efectos.icono, id, 10, 10, 40)
        love.graphics.pop()
        fallar(errores, "miniatura de " .. id, ok2, tostring(err2))
      end
    end
    -- impactos de proyectil y proyectiles en vuelo
    for _, tipo in ipairs({ "misil", "fuego", "flecha", "sagrado", "sombra" }) do
      local img = Arte.img("Animations/Proyectil_" .. tipo .. ".png", true)
      if tipo == "flecha" then
        fallar(errores, "proyectil flecha de 6 cuadros del mismo tamaño", img:getWidth() % 6 == 0 and img:getHeight() <= 64)
      else
        fallar(errores, "proyectil " .. tipo .. " de 4 cuadros", img:getWidth() == 256 and img:getHeight() == 64)
      end
      fallar(errores, "impacto de " .. tipo, Efectos.def[tipo] ~= nil)
      love.graphics.push("all")
      love.graphics.setCanvas({ cv, stencil = true })
      local ok, err = pcall(Dibujo.proyectil, { tipo = tipo, x = 0, y = 0, tx = 5, ty = 2 }, 150, 150)
      love.graphics.pop()
      fallar(errores, "se dibuja el proyectil " .. tipo, ok, tostring(err))
    end
    fallar(errores, "se probaron los 40 poderes", n == 40 * 5, tostring(n))
  end)
  paso("chat: barra de desplazamiento y rueda", function()
    local Entrada = require("src.presentacion.entrada")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Lector", faccion = "albor", clase = "mago" })
    for k = 1, 60 do mundo:mensaje("mundo", "Alguien", "mensaje numero " .. k, nil) end
    Interfaz.escala = 1
    Interfaz.panel = nil
    Interfaz.chatScroll = 0
    Interfaz.hud(mundo, pj, 1280, 720)
    fallar(errores, "con muchos mensajes hay barra", Interfaz.chatBarra ~= nil and (Interfaz.chatMax or 0) > 20, tostring(Interfaz.chatMax))
    local b = Interfaz.chatBarra
    fallar(errores, "se puede pulsar", Interfaz.consumir(b.x + 9, b.y + b.h / 2) == "chat_barra")
    Interfaz.chatDesdeRaton(b.y)
    fallar(errores, "arriba del todo es lo más antiguo", Interfaz.chatScroll == Interfaz.chatMax, tostring(Interfaz.chatScroll))
    Interfaz.chatDesdeRaton(b.y + b.h)
    fallar(errores, "abajo del todo es lo último", Interfaz.chatScroll == 0)
    -- la rueda sobre el chat sube y baja
    local lado, consola = Interfaz.medidas()
    love.mouse.setPosition(300, 720 - Interfaz.CHAT_ALTO / 2)
    Entrada.rueda({ estado = "juego", zoom = 1 }, 1)
    fallar(errores, "la rueda sube el chat", (Interfaz.chatScroll or 0) > 0, tostring(Interfaz.chatScroll))
    Entrada.tecla({ estado = "juego" }, "pagedown")
    Entrada.tecla({ estado = "juego" }, "pagedown")
    fallar(errores, "AvPág baja", (Interfaz.chatScroll or 0) == 0)
    Interfaz.hud(mundo, pj, 1280, 720)
    -- en "Todo" no salen los avisos del sistema: solo en su pestaña, que muestra un punto cuando llega alguno
    Interfaz.canal = "todo"
    mundo:mensaje("sistema", "", "aviso de sistema de prueba", pj)
    Interfaz.hud(mundo, pj, 1280, 720)
    fallar(errores, "la pestaña del sistema avisa de lo nuevo", Interfaz.sistemaNuevo == true)
    Interfaz.canal = "sistema"
    Interfaz.hud(mundo, pj, 1280, 720)
    Interfaz.hud(mundo, pj, 1280, 720)
    fallar(errores, "al abrirla se da por visto", Interfaz.sistemaNuevo == false)
    Interfaz.canal = "todo"
  end)
  paso("interfaz: la barra y el árbol de poderes de cada clase se dibujan (DC_PRUEBA_PODERES_FAO=1 guarda capturas/arbol_<clase>.png)", function()
    local cv = love.graphics.newCanvas(1280, 720)
    for _, clase in ipairs({ "mago", "guerrero", "cazador", "clerigo", "lancero", "nigromante" }) do
      local mundo = Mundo.nuevo()
      local pj = mundo:crearPersonaje({ nombre = "Arbol" .. clase, faccion = clase == "nigromante" and "umbra" or "albor", clase = clase, nivel = 30 })
      local n = 0
      for _, id in ipairs(Datos.barra[clase]) do
        n = n + 1
        pj.habilidades[id] = n <= 3 and 5 or (n <= 6 and 2 or (n == 7 and 1 or 0))
      end
      Interfaz.escala, Interfaz.arbolSel = 1, nil
      for k, panel in ipairs({ false, "arbol" }) do
        Interfaz.panel = panel or nil
        love.graphics.push("all")
        love.graphics.setCanvas({ cv, stencil = true })
        love.graphics.clear(0.2, 0.3, 0.2, 1)
        local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
        love.graphics.pop()
        fallar(errores, "el HUD de " .. clase .. " se dibuja (" .. tostring(panel) .. ")", ok, tostring(err))
        if panel and os.getenv("DC_PRUEBA_PODERES_FAO") then Log.volcar("capturas/arbol_" .. clase .. ".png", cv:newImageData():encode("png"):getString()) end
      end
      Interfaz.panel = nil
      -- el panel no registra más de un rectángulo por poder
      local vistos = {}
      for _, r in ipairs(Interfaz.rects) do if r.id:sub(1, 4) == "arb_" then vistos[r.id] = (vistos[r.id] or 0) + 1 end end
    end
  end)
  paso("Item Mall: pestaña de mascotas recolectoras y flecha del arquero (DC_PRUEBA_PODERES_FAO=1 guarda capturas/mall_mascotas.png)", function()
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Mall", faccion = "albor", clase = "cazador", nivel = 20 })
    pj.monedas = 5000
    pj.mall = { monedas = 5000, addons = {} }
    pj.mascotas = { { especie = "perro_rastreador", nivel = 1, xp = 0 } }
    Interfaz.escala, Interfaz.panel, Interfaz.mallTab, Interfaz.mallScroll = 1, "mall", "mascotas", 0
    local cv = love.graphics.newCanvas(1280, 720)
    love.graphics.push("all")
    love.graphics.setCanvas({ cv, stencil = true })
    love.graphics.clear(0.2, 0.3, 0.2, 1)
    local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    love.graphics.pop()
    fallar(errores, "la pestaña de mascotas del mall se dibuja", ok, tostring(err))
    local botones = {}
    for _, r in ipairs(Interfaz.rects) do botones[r.id] = true end
    fallar(errores, "hay botones para comprar las que faltan", botones.mall_ma_buy_dragon_1 and botones.mall_ma_buy_angel_1 and botones.mall_ma_buy_demonio_1 and botones.mall_tab_obj)
    Interfaz.mallTab, Interfaz.panel = nil, nil
    if os.getenv("DC_PRUEBA_PODERES_FAO") then
      Log.volcar("capturas/mall_mascotas.png", cv:newImageData():encode("png"):getString())
      -- la flecha del ataque básico, en grande sobre fondo de hierba
      local Dibujo = require("src.presentacion.render.dibujo")
      local c2 = love.graphics.newCanvas(300, 120)
      love.graphics.push("all")
      love.graphics.setCanvas(c2)
      love.graphics.clear(0.25, 0.45, 0.22, 1)
      love.graphics.scale(3, 3)
      Dibujo.proyectil({ tipo = "flecha", x = 0, y = 0, tx = 6, ty = 0 }, 50, 30)
      love.graphics.pop()
      Log.volcar("capturas/flecha_arquero.png", c2:newImageData():encode("png"):getString())
    end
  end)
  paso("interfaz: clics", function()
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Clic", faccion = "albor", clase = "mago" })
    Interfaz.escala = 1
    Interfaz.panel = nil
    Interfaz.hud(mundo, pj, 1280, 720)
    local lado, consola = Interfaz.medidas()
    local yTab = 720 - Interfaz.CHAT_ALTO + 12
    for i, canal in ipairs({ "todo", "mundo", "faccion", "sistema" }) do
      local id = Interfaz.consumir(8 + (i - 1) * 48 + 22, yTab)
      fallar(errores, "pestaña del chat " .. canal, id == "canal_" .. canal, tostring(id))
    end
    fallar(errores, "la entrada del chat recibe el clic", Interfaz.consumir(200, 720 - 14) == "foco_chat")
    local lista = {}
    for i = 1, 4 do lista[i] = Interfaz.consumir(1280 - lado + 20 + (i - 1) * 40, 8) end
    local ayuda
    for x = 1280 - 140, 1279, 4 do
      local id = Interfaz.consumir(x, 155)
      if id == "hud_ayuda" then ayuda = id end
    end
    fallar(errores, "los botones del minimapa reciben clics", ayuda == "hud_ayuda", tostring(ayuda))
    fallar(errores, "el hueco de la barra de poderes responde", Interfaz.consumir(480 + 25, 720 - consola - 89) == "hab_1" and Interfaz.consumir(480 + 25, 720 - consola - 34) == "hab_7")
  end)
  paso("interfaz: clic derecho sobre un jugador abre el menú de trato, gremio y grupo", function()
    local Dibujo = require("src.presentacion.render.dibujo")
    local Entrada = require("src.presentacion.entrada")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Yo", faccion = "albor", clase = "guerrero", nivel = 10 })
    local otro = mundo:crearPersonaje({ nombre = "Amigo", faccion = "albor", clase = "mago", nivel = 10 })
    local rival = mundo:crearPersonaje({ nombre = "Rival", faccion = "umbra", clase = "mago", nivel = 10 })
    local llamadas = {}
    local app = { jugador = pj, mundo = mundo, estado = "juego", zoom = 1, actuar = function(n, d) llamadas[#llamadas + 1] = { n, d } end }
    Interfaz.escala, Interfaz.panel, Interfaz.menuJugador = 1, nil, nil
    Dibujo.fijarVista(0, 0, 1280, 570)
    local cam = Dibujo.camara(pj, 1, mundo:mapaDe(pj))
    local x, y = Dibujo.pantallaAMundo(cam, 300, 300)
    otro.x, otro.y, otro.z, otro.modo = x, y, pj.z or 0, pj.modo
    rival.x, rival.y = x + 40, y + 40
    Entrada.clicMundo(app, 300, 300, 2)
    fallar(errores, "el clic derecho abre el menú del jugador", Interfaz.menuJugador and Interfaz.menuJugador.id == otro.id)
    fallar(errores, "elige al jugador como objetivo sin perseguirlo", llamadas[1] and llamadas[1][1] == "objetivo" and llamadas[1][2].id == otro.id and not llamadas[1][2].persigue)
    pj.gremioNombre = "Probados"
    Interfaz.hud(mundo, pj, 1280, 720)
    local m = Interfaz.menuJugador
    local ids = {}
    for yy = m.y, m.y + 200, 4 do
      local id = Interfaz.consumir(m.x + 6 + 100, yy)
      if id and id:sub(1, 4) == "ctx_" then ids[id] = true end
    end
    fallar(errores, "el menú ofrece tratar, gremio, grupo y mirar", ids.ctx_trato and ids.ctx_gremio and ids.ctx_grupo and ids.ctx_mirar)
    llamadas = {}
    Entrada.menuJugador(app, "ctx_trato")
    fallar(errores, "tratar manda la invitación de comercio", llamadas[1] and llamadas[1][1] == "comercio_invitar" and llamadas[1][2].id == otro.id and Interfaz.menuJugador == nil)
    Interfaz.menuJugador = { id = otro.id, x = 300, y = 300 }
    llamadas = {}
    Entrada.menuJugador(app, "ctx_gremio")
    fallar(errores, "el menú invita al gremio", llamadas[1] and llamadas[1][1] == "gremio_invitar" and llamadas[1][2].id == otro.id)
    Interfaz.menuJugador = { id = otro.id, x = 300, y = 300 }
    llamadas = {}
    Entrada.menuJugador(app, "ctx_grupo")
    fallar(errores, "el menú invita al grupo", llamadas[1] and llamadas[1][1] == "grupo_invitar" and llamadas[1][2].id == otro.id)
    -- Esc cierra el menú
    Interfaz.menuJugador = { id = otro.id, x = 300, y = 300 }
    Entrada.tecla(app, "escape")
    fallar(errores, "Esc cierra el menú", Interfaz.menuJugador == nil)
    -- sin gremio o con un rival de otra corona, esas opciones no responden
    pj.gremioNombre = nil
    Interfaz.menuJugador = { id = rival.id, x = 300, y = 300 }
    Interfaz.hud(mundo, pj, 1280, 720)
    local sinGremio = false
    for yy = 300, 500, 4 do
      local id = Interfaz.consumir(300 + 6 + 100, yy)
      if id == "ctx_gremio" or id == "ctx_grupo" then sinGremio = true end
    end
    fallar(errores, "sin gremio o de otra corona no se puede invitar", not sinGremio)
    Interfaz.menuJugador = nil
    -- la bolsa ya no está en el lateral: no hay casillas de bolsa fuera del panel de bolsa
    Interfaz.panel = nil
    Interfaz.hud(mundo, pj, 1280, 720)
    local hayBolsa = false
    for yy = 0, 720, 6 do for xx = 0, 1280, 6 do
      local id = Interfaz.consumir(xx, yy)
      if id and id:sub(1, 6) == "bolsa_" then hayBolsa = true end
    end end
    fallar(errores, "el HUD no dibuja la bolsa (se abre con I)", not hayBolsa)
    Interfaz.panel = "bolsa"
    Interfaz.hud(mundo, pj, 1280, 720)
    local hayBolsa2 = false
    for yy = 0, 720, 6 do for xx = 0, 1280, 6 do
      local id = Interfaz.consumir(xx, yy)
      if id and id:sub(1, 6) == "bolsa_" then hayBolsa2 = true end
    end end
    fallar(errores, "con I se ve la bolsa", hayBolsa2)
    Entrada.tecla(app, "escape")
    fallar(errores, "Esc cierra el panel", Interfaz.panel == nil)
    Interfaz.panel = nil
    Entrada.tecla(app, "c")
    fallar(errores, "C abre el panel del personaje", Interfaz.panel == "equipo")
    local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el panel del personaje se dibuja", ok, tostring(err))
    Interfaz.panel = nil
    -- el juego ocupa todo el ancho
    local lado = Interfaz.medidas()
    fallar(errores, "sin panel lateral: el juego ocupa toda la pantalla", lado == 0)
  end)
  paso("interfaz: la enfermera y los maestros tienen pestañas distintas", function()
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Tienda", faccion = "albor", clase = "guerrero", nivel = 12 })
    pj.oro = 99999
    Interfaz.escala, Interfaz.panel, Interfaz.scroll = 1, "mercado", 0
    local function contarPestanas()
      local pestanas = {}
      for x = 320, 960, 4 do
        local id = Interfaz.consumir(x, 116)
        if id and id:sub(1, 9) == "merc_tab_" then pestanas[id] = true end
      end
      local n = 0
      for _ in pairs(pestanas) do n = n + 1 end
      return n
    end
    Interfaz.tienda = "mercado"
    for _, tab in ipairs({ "pociones", "mascotas", "vender" }) do
      Interfaz.mercadoTab = tab
      local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
      fallar(errores, "la enfermera dibuja " .. tab, ok, tostring(err))
    end
    Interfaz.mercadoTab = "pociones"
    Interfaz.hud(mundo, pj, 1280, 720)
    fallar(errores, "la enfermera tiene pociones, mascotas y vender", contarPestanas() == 3, tostring(contarPestanas()))
    Interfaz.tienda = "maestro_guerrero"
    for _, tab in ipairs({ "armas", "armadura", "escudos", "accesorios", "mochilas", "vender" }) do
      Interfaz.mercadoTab = tab
      local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
      fallar(errores, "el maestro dibuja " .. tab, ok, tostring(err))
    end
    Interfaz.mercadoTab = "armadura"
    Interfaz.hud(mundo, pj, 1280, 720)
    fallar(errores, "el maestro tiene armadura, armas y el resto del equipo", contarPestanas() == 6, tostring(contarPestanas()))
    local armas = Interfaz.listaItemsClase(pj, "armas")
    local armadura = Interfaz.listaItemsClase(pj, "armadura")
    local pociones = Interfaz.listaItemsClase(pj, "pociones")
    local bajas = Interfaz.listaItemsClase({ clase = "guerrero", nivel = 1 }, "pociones")
    local altas = Interfaz.listaItemsClase({ clase = "guerrero", nivel = 22 }, "pociones")
    local solo = #armas > 0 and #armadura > 0 and #pociones == 5 and #bajas == 3 and #altas == 7
    for _, id in ipairs(armas) do solo = solo and Datos.item(id).hueco == "arma" end
    for _, id in ipairs(armadura) do local hh = Datos.item(id).hueco solo = solo and (hh == "cabeza" or hh == "pecho" or hh == "piernas" or hh == "pies") end
    fallar(errores, "cada pestaña lista solo lo suyo", solo, #bajas .. "/" .. #pociones .. "/" .. #altas)
    -- vender: la bolsa se lista en la pestaña y cada fila vende con su casilla
    pj.bolsa = { { id = "pocion_vida", cant = 3 } }
    Interfaz.mercadoTab = "vender"
    Interfaz.hud(mundo, pj, 1280, 720)
    local vende = false
    for yy = 140, 200, 4 do for xx = 780, 900, 4 do
      if Interfaz.consumir(xx, yy) == "bolsa_1" then vende = true end
    end end
    fallar(errores, "la pestaña Vender ofrece la bolsa", vende)
    Interfaz.panel, Interfaz.mercadoTab, Interfaz.tienda = nil, "pociones", nil
  end)
  paso("interfaz: el barquero ofrece los puertos y el mapa nombra los continentes", function()
    local Entrada = require("src.presentacion.entrada")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Marino", faccion = "albor", clase = "guerrero", nivel = 10 })
    local origen
    for _, pu in ipairs(mundo.mapas.mundo.puertos) do if pu.id == "puerto_sol" then origen = pu end end
    pj.x, pj.y, pj.oro = origen.x, origen.y, 1000
    local llamadas = {}
    local app = { jugador = pj, mundo = mundo, estado = "juego", zoom = 1, actuar = function(n, d) llamadas[#llamadas + 1] = { n, d } end }
    Interfaz.escala, Interfaz.panel = 1, "viaje"
    local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el panel del barquero se dibuja", ok, tostring(err))
    local ids = {}
    for y = 100, 520, 4 do for x = 400, 900, 4 do
      local id = Interfaz.consumir(x, y)
      if id and id:sub(1, 6) == "viaje_" then ids[id] = true end
    end end
    fallar(errores, "ofrece los otros dos puertos", ids.viaje_puerto_sombra and ids.viaje_cicatriz and not ids.viaje_puerto_sol)
    Entrada.manejar(app, "viaje_cicatriz")
    fallar(errores, "navegar manda la acción y cierra el panel", llamadas[1] and llamadas[1][1] == "viaje" and llamadas[1][2].destino == "cicatriz" and Interfaz.panel == nil)
    -- sin dinero el botón no responde y explica por qué
    pj.oro = 5
    Interfaz.panel = "viaje"
    Interfaz.hud(mundo, pj, 1280, 720)
    local hay = false
    for y = 100, 520, 4 do for x = 400, 900, 4 do
      if Interfaz.consumir(x, y) == "viaje_puerto_sombra" then hay = true end
    end end
    fallar(errores, "sin oro no se puede navegar", not hay)
    -- lejos de un puerto el panel pide acercarse
    pj.x, pj.y = origen.x + 60, origen.y + 60
    ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "lejos del puerto el panel se dibuja", ok, tostring(err))
    -- el mapa del mundo con los continentes
    Interfaz.panel = "mapa"
    ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el mapa con nombres de continentes se dibuja", ok, tostring(err))
    Interfaz.panel = nil
  end)
  paso("interfaz: alforjas de la montura", function()
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Alforja", faccion = "albor", clase = "guerrero", nivel = 10 })
    pj.job, pj.monturas, pj.montado = "trader", { "buey" }, "buey"
    pj.carga, pj.cargaRobada = { trigo = 4, gemas = 2 }, { vino = 1 }
    pj.capacidadCarga, pj.pesoCarga = 40, 7
    for _, montado in ipairs({ true, false }) do
      if not montado then pj.montado = nil end
      Interfaz.escala = 1
      Interfaz.panel = "montura"
      local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
      fallar(errores, "el panel de la montura se dibuja" .. (montado and " montado" or " a pie"), ok, tostring(err))
    end
    Interfaz.panel = nil
local P = require("src.presentacion.render.personajes")    local ok3 = true    for _, j in ipairs({ "trader", "hunter", "thief" }) do      ok3 = ok3 and P.de({ kind = "jugador", clase = "mago", faccion = "umbra", job = j }) == P.oficios[j]    end    fallar(errores, "cada oficio activo tiene su aspecto", ok3 and P.de({ kind = "jugador", clase = "mago", faccion = "umbra" }) ~= P.oficios.trader)
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
  -- DC_BOT_PROTO=2: el bot habla con fotos diferenciales; se aplican a un mundo de cliente y se reconstruye una foto completa equivalente
  local proto = os.getenv("DC_BOT_PROTO") == "2" and 2 or nil
  local mundoBot, tuAcum, mensajesAcum = nil, {}, {}
  local function tomar(snap)
    if not snap.delta then return snap end
    mundoBot = mundoBot or require("compartido.dominio.mundo").nuevo()
    mundoBot:aplicarFoto(snap, miId)
    local ents = {}
    for _, e in pairs(mundoBot.entidades) do ents[#ents + 1] = { id = e.id, x = e.sx or e.x, y = e.sy or e.y, hp = e.hp, nombre = e.nombre } end
    for k, v in pairs(snap.tu or {}) do if k ~= "~" then tuAcum[k] = v end end
    for _, m in ipairs(snap.msgs or {}) do mensajesAcum[#mensajesAcum + 1] = m end
    return { ents = ents, tu = tuAcum, msgs = mensajesAcum, efectos = snap.efectos, tiempo = snap.tiempo, delta = true }
  end
  local posFinal
  local usuario
  -- los mensajes que llegan juntos se atienden todos: si no, la primera foto (que llega pegada al "ok") se perdería
  local pendientes = {}
  local function vaciar()
    while #pendientes > 0 do
      local m = table.remove(pendientes, 1)
      if m.t == "snap" then snaps = snaps + 1 ultimoSnap = tomar(m.snap) end
    end
  end
  local function esperar(tipo, segundos)
    local limite = love.timer.getTime() + (segundos or 5)
    while love.timer.getTime() < limite do
      love.timer.sleep(0.02)
      local msgs, err = cli:actualizar()
      if err then return nil, "cerrado" end
      for _, m in ipairs(msgs or {}) do pendientes[#pendientes + 1] = m end
      while #pendientes > 0 do
        local m = table.remove(pendientes, 1)
        if m.t == "snap" then snaps = snaps + 1 ultimoSnap = tomar(m.snap) end
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
      cli:enviar({ t = "hola", token = token, personaje = personaje, proto = proto })
      local ok, e3 = esperar("ok")
      fallar(errores, "entrada al mundo", ok ~= nil, tostring(e3))
      miId = ok and ok.id
      vaciar()
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
          for _, m in ipairs(msgs) do if m.t == "snap" then snaps = snaps + 1 ultimoSnap = tomar(m.snap) end end
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
        -- un poder sin objetivo (Curación, el poder inicial del clérigo): el efecto, el enfriamiento y el reloj deben llegar por red
        cli:enviar({ t = "act", a = "habilidad", p = { slot = 1 } })
        local vioEfecto = false
        local limite = love.timer.getTime() + 1.2
        while love.timer.getTime() < limite do
          love.timer.sleep(0.02)
          for _, m in ipairs(cli:actualizar() or {}) do
            if m.t == "snap" then
              snaps = snaps + 1
              ultimoSnap = tomar(m.snap)
              for _, fx in ipairs(m.snap.efectos or {}) do
                if fx.tipo == "curar" then vioEfecto = true end
              end
            end
          end
        end
        fallar(errores, "el efecto del poder llega al cliente", vioEfecto)
        local tu2 = ultimoSnap and ultimoSnap.tu
        local resta = tu2 and tu2.cds and tu2.cds.curar and ultimoSnap.tiempo and (tu2.cds.curar - ultimoSnap.tiempo)
        nota("enfriamiento de Curación visto: " .. tostring(resta and string.format("%.1f", resta)) .. " s")
        fallar(errores, "reloj del servidor y enfriamiento coherentes", resta and resta > 0.2 and resta < 2.2, tostring(resta))
        fallar(errores, "el árbol llega al cliente con el poder inicial", tu2 and tu2.habilidades and tu2.habilidades.curar == 1)
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
  app.mundo:spawnMonstruo("seta_azul", app.jugador.x + 2, app.jugador.y + 0.2, { x = app.jugador.x, y = app.jugador.y })
  app.mundo:spawnMonstruo("pinguino_aprendiz", app.jugador.x + 3.2, app.jugador.y + 1, { x = app.jugador.x, y = app.jugador.y })
  app.mundo:spawnMonstruo("larva_verde", app.jugador.x - 2, app.jugador.y + 1, { x = app.jugador.x, y = app.jugador.y })
  app.mundo:spawnMonstruo("girasol_lancero", app.jugador.x + 4, app.jugador.y - 1, { x = app.jugador.x, y = app.jugador.y })
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

-- DC_FOTO_CASAS=1: solo fotos de casas (exterior albor, exterior umbra e interior)
local function fotoCasas(app)
  local foto = app.foto
  local function junto(ciudadId, n)
    for _, c in ipairs(app.mundo.mapas.mundo.ciudades) do
      if c.id == ciudadId then
        local casas = {}
        for _, e in ipairs(app.mundo.mapas.mundo.edificios) do
          if not e.tienda and e.x >= c.x and e.x <= c.x + c.w and e.y >= c.y and e.y <= c.y + c.h then casas[#casas + 1] = e end
        end
        local e = casas[n] or casas[1]
        app.jugador.x, app.jugador.y = e.x + e.w / 2, e.y + e.h + 2.5
      end
    end
  end
  app.estado = "juego"
  Interfaz.panel = nil
  if os.getenv("DC_ZOOM") then app.zoom = tonumber(os.getenv("DC_ZOOM")) end
  if foto.paso == "menu" and os.getenv("DC_FOTO_CLASES") then
    foto.paso = "clases"
    local m, j = app.mundo, app.jugador
    for _, c in ipairs(m.mapas.mundo.ciudades) do
      if c.id == "auroria" then j.x, j.y = c.plaza.x + 0.5, c.plaza.y + 4.5 end
    end
    local tier = tonumber(os.getenv("DC_FOTO_CLASES")) or 1
    local I = require("compartido.dominio.items")
    local lista = { "guerrero", "lancero", "cazador", "mago", "clerigo", "nigromante" }
    for i, cl in ipairs(lista) do
      for g = 1, 2 do
        local e = m:crearPersonaje({ nombre = cl .. g, faccion = i % 2 == 0 and "umbra" or "albor", clase = cl, genero = g == 1 and "h" or "m", nivel = 1 })
        e.x, e.y = j.x + (i - 3.5) * 1.5 + (g - 1.5) * 0.6, j.y - 2 + (g - 1) * 1.8
        e.equipo = I.equipoDe(cl, tier)
        e.modo = "mundo"
        e.dir = tonumber(os.getenv("DC_DIR") or "1") or 1
        if g == 2 and i % 2 == 0 then e.mov = true end
      end
    end
  elseif foto.paso == "clases" then
    foto.paso = "fin"
    love.event.quit(0)
  elseif foto.paso == "menu" and os.getenv("DC_FOTO_MALL") then
    foto.paso = "mall"
    if os.getenv("DC_VENTANA") then local a, b = os.getenv("DC_VENTANA"):match("(%d+)x(%d+)") love.window.setMode(tonumber(a), tonumber(b), { fullscreen = os.getenv("DC_PANTALLA") == "1", resizable = true }) end
    Interfaz.panel = "mall"
    Interfaz.mallTab = os.getenv("DC_FOTO_MALL")
    Interfaz.mallScroll = 0
    if os.getenv("DC_MALL_UMBRA") then app.jugador.faccion = "umbra" end
    if os.getenv("DC_MALL_MONTADO") then app.jugador.montado = "mnt_104" end
  elseif foto.paso == "mall" then
    foto.paso = "fin"
    love.event.quit(0)
  elseif foto.paso == "menu" and os.getenv("DC_FOTO_MOBS") then
    -- DC_FOTO_MOBS=<página>: una cuadrícula de 6 x 4 criaturas (en orden de monstruos.xml), cada fila mirando a una dirección y las columnas
    -- impares andando; DC_FOTO_MOBS=jefes enseña los 10 jefes del mundo y los 3 de mazmorra
    foto.paso = "mobs"
    local m, j = app.mundo, app.jugador
    for _, c in ipairs(m.mapas.mundo.ciudades) do
      if c.id == "auroria" then j.x, j.y = c.x + c.w / 2 + 0.5, c.y + c.h + 16 end
    end
    local lista = {}
    local sel = os.getenv("DC_FOTO_MOBS")
    for _, d in ipairs(Datos.monstruos) do
      if sel == "jefes" then
        if d.jefeMundo or d.id:find("^jefe_") and not d.categoria then lista[#lista + 1] = d.id end
      elseif not d.jefeMundo and not (d.id:find("^jefe_") and not d.categoria) then lista[#lista + 1] = d.id end
    end
    local pagina = tonumber(sel) or 1
    local COLS, FILAS = 8, 3
    local PORPAG = COLS * FILAS
    local ini = sel == "jefes" and 0 or (pagina - 1) * PORPAG
    -- sin las criaturas del mundo: solo la cuadrícula, repartida sobre la pantalla (no sobre el mundo, que en isométrica es en diagonal)
    for id, e in pairs(m.entidades) do if e.kind == "monstruo" or e.kind == "guardia" or e.kind == "npc" then m.entidades[id] = nil end end
    local Iso = require("src.presentacion.render.iso")
    local gx, gy = Iso.suelo(j.x, j.y)
    local cols = sel == "jefes" and 7 or COLS
    for k = 1, PORPAG do
      local id = lista[ini + k]
      if id then
        local col, fila = (k - 1) % cols, math.floor((k - 1) / cols)
        local x, y = Iso.inversa(gx + (col - (cols - 1) / 2) * (sel == "jefes" and 170 or 150), gy - 10 + (fila - 1) * (sel == "jefes" and 150 or 120))
        local e = m:spawnMonstruo(id, x, y, { x = x, y = y })
        if e then
          e.dir = fila % 4 + 1
          e.mov = col % 2 == 1
          e.hp = e.hpMax
          e.agresivo = false
        end
      end
    end
    if os.getenv("DC_MEDIDOR") then
      j.medidor = { n = "Gorila del Bosque", hp = 7000, hpMax = 10000, f = { { "Fuerte", 15200, 62, 0 }, { "Liora", 6000, 25, 1 }, { "Otro", 2400, 10, 0 }, { "Cuarto", 700, 3, 0 } } }
    end
    require("compartido.infraestructura.log").info("MOBS página " .. tostring(sel) .. ": " .. #lista .. " criaturas")
  elseif foto.paso == "mobs" then
    foto.paso = "fin"
    love.event.quit(0)
  elseif foto.paso == "menu" and os.getenv("DC_FOTO_MONTURAS") then
    -- DC_FOTO_MONTURAS=mnt_001,mnt_203,...: cada montura en una fila con un jinete guerrero encima, mirando a las 4 direcciones (quieto) y otra vez andando
    foto.paso = "monturas"
    local m, j = app.mundo, app.jugador
    for _, c in ipairs(m.mapas.mundo.ciudades) do
      if c.id == "auroria" then j.x, j.y = c.x + c.w / 2 + 0.5, c.y + c.h + 16 end
    end
    for id, e in pairs(m.entidades) do if e.kind == "monstruo" or e.kind == "guardia" or e.kind == "npc" then m.entidades[id] = nil end end
    local Iso = require("src.presentacion.render.iso")
    local gx, gy = Iso.suelo(j.x, j.y)
    local ids = {}
    for id in os.getenv("DC_FOTO_MONTURAS"):gmatch("[^,]+") do ids[#ids + 1] = id end
    for fila, id in ipairs(ids) do
      for col = 0, 7 do
        local x, y = Iso.inversa(gx + (col - 3.5) * 110, gy - 10 + (fila - (#ids + 1) / 2) * 120)
        local e = { id = "fm" .. fila .. "_" .. col, kind = "jugador", nombre = id, clase = ({ "guerrero", "mago", "cazador", "clerigo" })[col % 4 + 1],
          faccion = "albor", montado = id, dir = col % 4 + 1, mov = col >= 4, x = x, y = y, vivo = true, hp = 100, hpMax = 100 }
        m.entidades[e.id] = e
      end
    end
  elseif foto.paso == "monturas" then
    foto.paso = "fin"
    love.event.quit(0)
  elseif foto.paso == "menu" and os.getenv("DC_FOTO_FUEGO") then
    foto.paso = "fuego"
    local j = app.jugador
    for _, c in ipairs(app.mundo.mapas.mundo.ciudades) do
      if c.id == "auroria" then j.x, j.y = c.x + c.w / 2 - 3.5, c.y + c.h / 2 + 5.5 end
    end
    local m = app.mundo
    m:efecto("fuego", j.x + 2.2, j.y, 5)
    m:efecto("nova", j.x - 2.5, j.y + 0.8, 5)
    m:efecto("curar", j.x - 1, j.y - 1.8, 5)
    local id = m:idNuevo()
    m.entidades[id] = { id = id, kind = "proyectil", x = j.x + 0.6, y = j.y - 0.5, modo = "mundo", tx = j.x + 60, ty = j.y - 0.5, tipo = "fuego", vivo = true, vida = 9, coef = 1 }
  elseif foto.paso == "fuego" then
    foto.paso = "fin"
    love.event.quit(0)
  elseif foto.paso == "menu" then
    foto.paso = "lago"
    for _, c in ipairs(app.mundo.mapas.mundo.ciudades) do
      if c.id == "auroria" then app.jugador.x, app.jugador.y = c.x + c.w / 2 - 17, c.y + c.h - 8.5 end
    end
  elseif foto.paso == "lago" then foto.paso = "casa_albor" junto("auroria", 3)
  elseif foto.paso == "casa_albor" then foto.paso = "casa_umbra" app.jugador.modo = "mundo" junto("nocturnia", 3)
  elseif foto.paso == "casa_umbra" then
    foto.paso = "casa_dentro"
    local j = app.jugador
    j.modo, j.casaId = "casa", "demo"
    j.casas = { demo = { muebles = { cama = true, cofre = true, mesa = true, estandarte = true }, cofre = {} } }
    local sal = app.mundo.mapas.casa.salida
    j.x, j.y = sal.x - 6, 4.5
  else foto.paso = "fin" love.event.quit(0) end
  foto.espera = 0
end

-- DC_FOTO_MUROS=1: muros de la ciudad (esquina y puerta) y un bosque, para revisar el arte de mapa
local function fotoMuros(app)
  local foto = app.foto
  app.estado = "juego"
  Interfaz.panel = nil
  if os.getenv("DC_ZOOM") then app.zoom = tonumber(os.getenv("DC_ZOOM")) end
  local j, m = app.jugador, app.mundo
  local ciudad
  if os.getenv("DC_MONTADO") then j.montado = os.getenv("DC_MONTADO") end   -- DC_MONTADO=mnt_104: el jugador de las fotos va montado
  for _, c in ipairs(m.mapas.mundo.ciudades) do if c.id == (os.getenv("DC_CIUDAD") or "auroria") then ciudad = c end end
  local pasos = { menu = "muro_esquina", muro_esquina = "muro_puerta", muro_puerta = "muro_sur", muro_sur = "muro_este", muro_este = "ciudad_centro", ciudad_centro = "bosque", bosque = "fin" }
  foto.paso = pasos[foto.paso] or "fin"
  if foto.paso == "muro_esquina" then j.x, j.y = ciudad.x + 5, ciudad.y + 5
  elseif foto.paso == "muro_puerta" then
    local ac = ciudad.acceso == "norte" and ciudad.y + 4 or ciudad.y + ciudad.h - 4
    j.x, j.y = ciudad.x + math.floor(ciudad.w / 2) + 0.5, ac
  elseif foto.paso == "muro_sur" then j.x, j.y = ciudad.x + ciudad.w / 2 + 0.5, ciudad.y + ciudad.h - 7
  elseif foto.paso == "muro_este" then j.x, j.y = ciudad.x + ciudad.w - 7, ciudad.y + ciudad.h / 2 + 0.5
  elseif foto.paso == "ciudad_centro" then
    j.x, j.y = ciudad.plaza.x + 0.5, ciudad.plaza.y + 3.5
    if os.getenv("DC_MAESTROS") then
      -- DC_MAESTROS=1: la cámara en la fila de maestros de la ciudad
      if os.getenv("DC_MAESTROS") == "edificio" then
        for _, ed in ipairs(m.mapas.mundo.edificios) do
          if ed.tienda == "maestros" and ed.puertaX > ciudad.x and ed.puertaX < ciudad.x + ciudad.w and ed.puertaY > ciudad.y and ed.puertaY < ciudad.y + ciudad.h then j.x, j.y = ed.puertaX + 0.5, ed.puertaY + 3 end
        end
      end
      for _, n in ipairs(ciudad.npcs) do if n.rol == (os.getenv("DC_MAESTROS") == "1" and "maestro_mago" or os.getenv("DC_MAESTROS")) then j.x, j.y = n.x, n.y + 3 end end
    end
  elseif foto.paso == "bosque" then
    local mejor, n0 = nil, -1
    for _, pu in ipairs(m.mapas.mundo.puestos) do
      local n = 0
      for _, pr in ipairs(m.mapas.mundo.props) do if math.abs(pr.x - pu.x) < 12 and math.abs(pr.y - pu.y) < 8 and pr.tipo:find("arbol") then n = n + 1 end end
      if n > n0 then mejor, n0 = pu, n end
    end
    j.x, j.y = mejor.x, mejor.y
  elseif foto.paso == "fin" then love.event.quit(0) end
  foto.espera = 0
end

-- DC_FOTO_MAPAS=1: una vista de cada mapa que no es el mundo abierto (mazmorras, batalla, estandarte), para revisar su arte
local function fotoMapas(app)
  local foto = app.foto
  app.estado = "juego"
  Interfaz.panel = nil
  if os.getenv("DC_ZOOM") then app.zoom = tonumber(os.getenv("DC_ZOOM")) end
  local j, m = app.jugador, app.mundo
  local orden = { "mz1", "mz2", "mz3", "batalla", "estandarte", "jardin_amanecer", "necropolis_ocaso" }
  local sig = { menu = orden[1] }
  for i, n in ipairs(orden) do sig[n] = orden[i + 1] or "fin" end
  foto.paso = sig[foto.paso] or "fin"
  if foto.paso == "fin" then love.event.quit(0) foto.espera = 0 return end
  local mapa = m.mapas[foto.paso]
  j.modo, j.z = foto.paso, 0
  local pos = (os.getenv("DC_JEFE") and mapa.jefe) or mapa.entrada or (mapa.spawns and (mapa.spawns.albor or mapa.spawns.umbra)) or { x = mapa.w / 2, y = mapa.h / 2 }
  local dx, dy = tonumber(os.getenv("DC_DX") or "0") or 0, tonumber(os.getenv("DC_DY") or "0") or 0
  j.x, j.y = pos.x + dx, pos.y + dy
  foto.espera = 0
end

local function avanzarFoto(app)
  local foto = app.foto
  if os.getenv("DC_FOTO_MAPAS") then return fotoMapas(app) end
  if os.getenv("DC_FOTO_MUROS") then return fotoMuros(app) end
  if os.getenv("DC_FOTO_CASAS") then return fotoCasas(app) end
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
    -- la foto de la ciudad se toma en la plaza de su capital, para ver el mobiliario
    for _, c in ipairs(app.mundo.mapas.mundo.ciudades) do
      if c.id == "auroria" then app.jugador.x, app.jugador.y = c.x + c.w / 2 - 3.5, c.y + c.h / 2 + 5.5 end
    end
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
    foto.paso = "mzpuerta"
    local z = app.mundo.mapas.mundo.mazmorras[1]
    app.jugador.x, app.jugador.y = z.x + 0.5, z.y + 2.5
  elseif foto.paso == "mzpuerta" then
    foto.paso = "mzsala"
    local m = app.mundo.mapas.mz1
    app.jugador.modo, app.jugador.x, app.jugador.y = "mz1", m.entrada.x, m.entrada.y
  elseif foto.paso == "mzsala" then
    foto.paso = "mzjefe"
    local m = app.mundo.mapas.mz1
    app.jugador.x, app.jugador.y = m.grupos[1].x, m.grupos[1].y + 4
  elseif foto.paso == "mzjefe" then
    foto.paso = "mzfin"
    local m = app.mundo.mapas.mz1
    app.jugador.x, app.jugador.y = m.jefe.x, m.jefe.y + 5
    local id = app.mundo:idNuevo()
    app.mundo.entidades[id] = { id = id, kind = "cofre_mz", nombre = "Cofre", x = m.jefe.x + 2, y = m.jefe.y + 3, z = 0, modo = "mz1", vivo = true, hasta = 1e9, reclamado = {}, mz = "mz1" }
  elseif foto.paso == "mzfin" then
    foto.paso = "terr_nieve"
    app.jugador.modo = "mundo"
    local function sitio(tipo)
      local mapa = app.mundo.mapas.mundo
      local mejor
      for y = 40, mapa.h - 40, 5 do
        for x = 40, mapa.w - 40, 5 do
          if mapa.suelo[x][y] == tipo and mapa.suelo[x + 5][y] == tipo and mapa.suelo[x - 5][y] == tipo and mapa.suelo[x][y + 5] == tipo then
            local vecinos = {}
            for dy = -9, 9, 3 do for dx = -9, 9, 3 do vecinos[mapa.suelo[x + dx][y + dy] or "?"] = true end end
            local n = 0
            for _ in pairs(vecinos) do n = n + 1 end
            if not mejor or n > mejor.n then mejor = { x = x, y = y, n = n } end
          end
        end
      end
      return mejor
    end
    app.sitios = { nieve = sitio("nieve"), roca = sitio("roca"), pantano = sitio("pantano"), agua = sitio("agua") }
    local s = app.sitios.nieve
    if s then app.jugador.x, app.jugador.y = s.x + 0.5, s.y + 0.5 end
  elseif foto.paso == "terr_nieve" then
    foto.paso = "terr_roca"
    local s = app.sitios.roca
    if s then app.jugador.x, app.jugador.y = s.x + 0.5, s.y + 0.5 end
  elseif foto.paso == "terr_roca" then
    foto.paso = "terr_pantano"
    local s = app.sitios.pantano
    if s then app.jugador.x, app.jugador.y = s.x + 0.5, s.y + 0.5 end
  elseif foto.paso == "terr_pantano" then
    foto.paso = "terr_costa"
    local mapa = app.mundo.mapas.mundo
    local p = mapa.puertos[1]
    app.jugador.x, app.jugador.y = p.x, p.y
    app.jugador.montado = "mnt_104"
  elseif foto.paso == "terr_costa" then
    foto.paso = "poderes"
    app.jugador.montado = nil
    app.jugador.modo = "mundo"; app.jugador.x, app.jugador.y = app.mundo.mapas.mundo.mazmorras[1].x + 0.5, app.mundo.mapas.mundo.mazmorras[1].y + 3
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
    foto.paso = "mercado"
    Interfaz.panel = "mercado"
    Interfaz.mercadoTab = "armas"
    app.jugador.habilidades = nil
    app.jugador.nivel = 9
    Interfaz.scroll = 0
  elseif foto.paso == "mercado" then
    foto.paso = "encantar"
    Interfaz.panel = "encantar"
    Interfaz.encSel = nil
    local j = app.jugador
    j.encantos = { arma = 3, pecho = 1 }
    j.oro = 500
    app.mundo:darItem(j, "polvo_arcano", 12)
  elseif foto.paso == "encantar" then
    foto.paso = "mascotas"
    Interfaz.panel = "mascotas"
    local j = app.jugador
    j.encantos = nil
    j.nivel = 14
    j.oro = 3000
    j.mascotas = { { especie = "osito_1", nivel = 6, xp = 120 }, { especie = "dragon_1", nivel = 3, xp = 40 } }
    j.mascotaActiva = 1
  elseif foto.paso == "mascotas" then
    foto.paso = "gremio"
    Interfaz.panel = "gremio"
    Interfaz.datosGremio = {
      id = 1, nombre = "Los Cuervos", etiqueta = "LC", max = 25,
      miembros = {
        { id = 1, nombre = "Liora", rango = "lider", conectado = true, nivel = 14 },
        { id = 2, nombre = "Kael", rango = "oficial", conectado = true, nivel = 12 },
        { id = 3, nombre = "Mira", rango = "miembro", conectado = false },
        { id = 4, nombre = "Dante", rango = "miembro", conectado = true, nivel = 9 },
      },
    }
    app.jugador.gremioRango = "lider"
    app.jugador.invGremio = { de = "Kael", nombre = "Los Lobos" }
  elseif foto.paso == "gremio" then
    foto.paso = "mapa"
    Interfaz.panel = "mapa"
    Interfaz.datosGremio = nil
  elseif foto.paso == "mapa" then
    foto.paso = "tablon"
    local Misiones = require("compartido.dominio.misiones")
    -- el jugador a unos pasos del tablón de Auroria, con una misión de cada tipo en curso
    local tablon
    for _, e in pairs(app.mundo.entidades) do if e.kind == "npc" and e.qid == "c_auroria" then tablon = e end end
    if tablon then app.jugador.x, app.jugador.y = tablon.x + 1, tablon.y end
    app.jugador.nivel = 12
    app.jugador.invGremio, app.jugador.gremioRango = nil, nil
    app.jugador.misiones = {
      q_auroria = { aceptada = true, entregada = false, progreso = 3 },
      ca_1 = { aceptada = true, entregada = false, progreso = 0 },
      ce_1 = { aceptada = true, entregada = false, progreso = 5 },
    }
    Misiones.seguida = "q_auroria"
    Interfaz.panel, Interfaz.npcMision, Interfaz.misSel = "misiones", "c_auroria", "q_auroria"
  elseif foto.paso == "tablon" then
    foto.paso = "diario"
    Interfaz.panel, Interfaz.misSelDiario = "diario", "ce_1"
    require("compartido.dominio.misiones").seguida = "ce_1"
  elseif foto.paso == "diario" then
    foto.paso = "mapamision"
    Interfaz.panel = "mapa"
  elseif foto.paso == "mapamision" then
    require("compartido.dominio.misiones").seguida = nil
    foto.paso = "oficios"
    Interfaz.panel = "oficios"
    local j = app.jugador
    j.job = "trader"
    j.oficios = { trader = { nivel = 3, xp = 120 } }
    j.capacidadCarga, j.pesoCarga = 32, 14
    j.buscadoResta, j.recompensa = 90, 420
    Interfaz.datosPanel.oficios = {
      lugar = "capitan", job = "trader", coste = 300,
      oficios = { trader = { nivel = 3, xp = 120, sig = 1050 }, hunter = { nivel = 1, xp = 0, sig = 250 } },
      buscados = { { id = 9, nombre = "Sombra", x = 412, y = 301, recompensa = 420 } },
      buscado = { resta = 90, recompensa = 420 },
    }
  elseif foto.paso == "oficios" then
    foto.paso = "mercancias"
    Interfaz.panel = "mercancias"
    Interfaz.datosPanel.mercancias = {
      sitio = "Auroria", job = "trader", nivel = 3, peso = 14, capacidad = 32,
      bienes = {
        { id = "trigo", nombre = "Trigo", compra = 19, venta = 17, tengo = 0, etiqueta = "sobra" },
        { id = "pescado", nombre = "Pescado", compra = 40, venta = 35, tengo = 0 },
        { id = "madera", nombre = "Madera", compra = 47, venta = 41, tengo = 6 },
        { id = "tela", nombre = "Telas", compra = 74, venta = 64, tengo = 0 },
        { id = "vino", nombre = "Vino", compra = 142, venta = 124, tengo = 8, etiqueta = "falta" },
        { id = "hierro", nombre = "Hierro", compra = 126, venta = 110, tengo = 0 },
        { id = "especias", nombre = "Especias", compra = 88, venta = 76, tengo = 0, etiqueta = "sobra" },
        { id = "gemas", nombre = "Gemas", compra = 274, venta = 240, tengo = 0 },
      },
    }
  elseif foto.paso == "mercancias" then
    foto.paso = "establo"
    Interfaz.panel = "establo"
    app.jugador.invGremio = nil
    app.jugador.montado = "mnt_001"
    app.jugador.nivel = 14
    app.jugador.oro = 3000
    local Mont = require("compartido.dominio.monturas")
    local cat = {}
    for k, id in ipairs(Mont.orden) do
      local d = Mont.especies[id]
      cat[#cat + 1] = { id = id, nombre = d.nombre, nivel = d.nivel, precio = d.precio, vel = d.vel, carga = d.carga, oficio = d.oficio, requiereOficio = d.requiereOficio and true or false, desc = d.desc, tengo = k % 3 == 1 }
    end
    Interfaz.datosPanel.establo = { montado = "mnt_001", cerca = true, catalogo = cat }
    Interfaz.establoTab = "normales"
  elseif foto.paso == "establo" then
    foto.paso = "subastas"
    Interfaz.panel = "subastas"
    Interfaz.subCat = "todo"
    Interfaz.subSel = 2
    Interfaz.datosPanel.subastas = {
      cat = "todo", pagina = 1, paginas = 2, total = 11, cerca = true, comision = 0.05, impuesto = 0.08, duraciones = { 1, 6, 12, 24 }, maxPropias = 8,
      mias = { { id = 9, item = "pocion_vida", cant = 5, salida = 40, oferta = 0, resta = 5400 } },
      buzon = { { item = "cazador_arma_3", cant = 1, enc = 2, oro = 0, nota = "Ganas la subasta." }, { oro = 460, nota = "Vendes." } },
      lista = {
        { id = 1, item = "guerrero_arma_4", cant = 1, enc = 3, vendedor = "Kael", salida = 500, compra = 1800, oferta = 640, postor = "Mira", resta = 1500, minima = 672 },
        { id = 2, item = "mago_pecho_5", cant = 1, vendedor = "Liora", salida = 900, oferta = 0, resta = 7300, minima = 900 },
        { id = 3, item = "anillo_3", cant = 1, enc = 1, vendedor = "Dante", salida = 120, compra = 600, oferta = 130, postor = "Tú", lider = true, resta = 20000, minima = 137 },
        { id = 4, item = "polvo_arcano", cant = 40, vendedor = "Ana", salida = 200, oferta = 0, resta = 43000, minima = 200 },
      },
    }
  elseif foto.paso == "subastas" then
    foto.paso = "grupo"
    Interfaz.panel = "grupo"
    local j = app.jugador
    j.grupo = {
      lider = j.id, max = 5, bono = 0.1,
      miembros = {
        { id = j.id, nombre = "Liora", nivel = 14, clase = "clerigo", hp = 142, hpMax = 142, x = 10, y = 10, cerca = true },
        { id = 77, nombre = "Kael", nivel = 13, clase = "guerrero", hp = 210, hpMax = 340, x = 12, y = 10, cerca = true },
        { id = 78, nombre = "Mira", nivel = 15, clase = "mago", hp = 120, hpMax = 150, x = 400, y = 300, cerca = false },
      },
    }
    j.invGrupo = { nombre = "Dante" }
  elseif foto.paso == "grupo" then
    foto.paso = "batalla"
    Interfaz.panel = nil
    app.jugador.grupo, app.jugador.invGrupo = nil, nil
    local j = app.jugador
    j.montado, j.job, j.oficios, j.buscadoResta = nil, nil, nil, nil
    Interfaz.datosGremio = nil
    app.jugador.gremioRango = nil
    app.jugador.invGremio = nil
    Interfaz.panel = nil
    app.jugador.mascotas = nil
    app.jugador.mascotaActiva = nil
    app.jugador.nivel = 1
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
  if foto.paso == "batalla" and app.jugador and app.jugador.modo == "batalla" and not foto.vista then
    -- vista del campo abierto (rocas, crestas, huecos y marcas del suelo) en vez de la base
    foto.vista = true
    app.mundo:usarBatallaClasica()
    local r0
    for _, pr in ipairs(app.mundo.mapas.batalla.props) do
      if pr.tipo:find("risco") and (not r0 or math.abs(pr.x - 56) + math.abs(pr.y - 26) < math.abs(r0.x - 56) + math.abs(r0.y - 26)) then r0 = pr end
    end
    app.jugador.x, app.jugador.y = (r0 and r0.x + 1 or 46) + 0.5, (r0 and r0.y + 4 or 24) + 0.5
    -- si hay huecos a la vista, mejor enseñarlos
    local g0
    for gx, col in pairs(app.mundo.mapas.batalla.decorado) do for gy, t in pairs(col) do if t == "grieta" and (not g0 or math.abs(gx - 46) + math.abs(gy - 26) < math.abs(g0[1] - 46) + math.abs(g0[2] - 26)) then g0 = { gx, gy } end end end
    if g0 and not os.getenv("DC_FOTO_RISCO") then app.jugador.x, app.jugador.y = g0[1] + 0.5, g0[2] + 4.5 end
    foto.espera = 0
  end
  if foto.espera > 0.35 and not app.capturando and foto.paso ~= "fin" then
    app.capturando = true
    local nombre = foto.paso
    if nombre ~= "mall" and nombre ~= "clases" and nombre ~= "equipo" and nombre ~= "arbol" and nombre ~= "mercado" and nombre ~= "encantar" and nombre ~= "mascotas" and nombre ~= "gremio" and nombre ~= "mapa" and nombre ~= "tablon" and nombre ~= "diario" and nombre ~= "mapamision" and nombre ~= "oficios" and nombre ~= "mercancias" and nombre ~= "establo" and nombre ~= "subastas" and nombre ~= "grupo" then Interfaz.panel = nil end
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
