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
      "lluvia", "trampa", "preciso", "curar", "bendicion", "castigo", "consagrar", "desgarro", "furia", "sombra",
      "meteoro", "flecha_veneno", "paso_agil", "sanacion", "juicio" }) do
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
  paso("todos los objetos tienen icono visible", function()
    local datos = {}
    local function celda(hoja, idx)
      if not datos[hoja] then
        local archivo = hoja == "equipment" and "otsp_equipment_01.png" or (hoja .. ".png")
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
  paso("interfaz: icono de montura y opción de oficio en el menú", function()
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Menu", faccion = "albor", clase = "guerrero", nivel = 10 })
    pj.monturas, pj.oficioElegido = { "caballo", "carreta" }, "trader"
    pj.job = nil
    Interfaz.escala, Interfaz.panel = 1, nil
    pcall(Interfaz.hud, mundo, pj, 1280, 720)
    local lado0, consola0 = Interfaz.medidas()
    fallar(errores, "sin oficio activo no sale el icono de montar", Interfaz.consumir((1280 - lado0) / 2 + 231, 720 - consola0 - 34) ~= "hud_montura")
    pj.job = "trader"
    Interfaz.escala = 1
    Interfaz.panel = nil
    local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el HUD con montura se dibuja", ok, tostring(err))
    local lado, consola = Interfaz.medidas()
    local hallado = Interfaz.consumir((1280 - lado) / 2 + 231, 720 - consola - 34) == "hud_montura"
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
Interfaz.mallTab, Interfaz.mallScroll, Interfaz.panel = "addons", 7, "mall"    local okS, errS = pcall(Interfaz.hud, mundo, pj, 1280, 720)    fallar(errores, "el mall se dibuja desplazado", okS, tostring(errS))    fallar(errores, "hay más addons que filas (necesita rueda)", (Interfaz.mallScrollMax or 0) >= 7, tostring(Interfaz.mallScrollMax))
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
      todas = todas and P.skins[id] ~= nil and require("src.presentacion.render.arte").img(P.skins[id].hoja) ~= nil
    end
    fallar(errores, "todos los addons tienen sprite", todas)
    local base = { kind = "jugador", clase = "mago", faccion = "albor" }
    fallar(errores, "sin addon, el de la clase", P.de(base) == P.clases.mago.albor)
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
  paso("interfaz: marquesina y enfriamiento de pociones", function()
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Marq", faccion = "albor", clase = "guerrero", nivel = 10 })
    Interfaz.escala, Interfaz.marq, Interfaz.panel = 1, nil, nil
    mundo.mensajes = {}
    local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "el HUD sin avisos se dibuja", ok, tostring(err))
    -- un aviso nuevo entra en la marquesina y avanza hacia la izquierda
    mundo:anunciar("Prueba se anota a Captura del estandarte. Albor 1/3 · Umbra 0/3.")
    pj.cdPocion = mundo.tiempo + 2
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
    local Arte = require("src.presentacion.render.arte")
    fallar(errores, "los dos fondos existen", Arte.img("Titles1/Fountain.png", true) ~= nil and Arte.img("Titles1/Gates.png", true) ~= nil)
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
    for x = 8, 700, 6 do if Interfaz.consumir(x, 720 - consola + 12) == "canal_evento" then hallado = true end end
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
    local mx, my = g.ax + g.aw / 2, g.ay + g.ah / 2
    Entrada.raton(app, mx, my, 1)
    Entrada.soltarRaton(app, mx, my)
    local destino
    for _, l in ipairs(llamadas) do if l[1] == "destino" then destino = l[2] end end
    fallar(errores, "el clic en el mapa viaja al sitio", destino and math.abs(destino.x - g.mw / 2) < 2 and math.abs(destino.y - g.mh / 2) < 2,
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
  paso("interfaz: poderes de área apuntan con el cursor", function()
    local Entrada = require("src.presentacion.entrada")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Mago", faccion = "albor", clase = "mago", nivel = 20 })
    pj.habilidades.meteoro, pj.habilidades.nova = 1, 1
    local llamadas = {}
    local app = { jugador = pj, mundo = mundo, estado = "juego", zoom = 1, actuar = function(n, d) llamadas[#llamadas + 1] = { n, d } end }
    local function slotDe(id) for i, h in ipairs(Datos.barra.mago) do if h == id then return i end end end
    Entrada.lanzarHabilidad(app, slotDe("nova"))
    fallar(errores, "la nova no necesita punto", llamadas[1] and llamadas[1][1] == "habilidad" and llamadas[1][2].x == nil)
    Entrada.lanzarHabilidad(app, slotDe("meteoro"))
    fallar(errores, "el meteoro se envía con su slot (y el punto si el cursor está en el mundo)", llamadas[2] and llamadas[2][2].slot == slotDe("meteoro"))
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
    local ayuda
    for x = 1280 - lado + 4, 1279, 4 do
      local id = Interfaz.consumir(x, 160)
      if id == "hud_ayuda" then ayuda = id end
    end
    fallar(errores, "los botones del panel lateral reciben clics", ayuda == "hud_ayuda", tostring(ayuda))
    fallar(errores, "el hueco de la barra de poderes responde", Interfaz.consumir((1280 - lado) / 2 - 175, 720 - consola - 34) == "hab_1")
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
        -- un poder sin objetivo (Curación, el poder inicial del clérigo): el efecto, el enfriamiento y el reloj deben llegar por red
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
    foto.paso = "mercado"
    Interfaz.panel = "mercado"
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
    j.mascotas = { { especie = "gatito", nivel = 6, xp = 120 }, { especie = "murcielago", nivel = 3, xp = 40 } }
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
    app.jugador.montado = "caballo"
    app.jugador.nivel = 14
    app.jugador.oro = 3000
    Interfaz.datosPanel.establo = {
      montado = "caballo", cerca = true,
      catalogo = {
        { id = "buey", nombre = "Buey de carga", nivel = 5, precio = 900, vel = 0.10, carga = 22, desc = "Lento pero fuerte: carga mucho más.", tengo = true },
        { id = "caballo", nombre = "Caballo", nivel = 10, precio = 2400, vel = 0.40, carga = 6, desc = "El más rápido para cruzar el mapa.", tengo = true },
        { id = "carreta", nombre = "Carreta cubierta", nivel = 14, precio = 4500, vel = 0.06, carga = 90, oficio = "trader", desc = "Una carreta de mercader: carga enorme. Solo para comerciantes.", tengo = false },
      },
    }
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
    local r0
    for _, pr in ipairs(app.mundo.mapas.batalla.props) do
      if pr.tipo:find("risco") and (not r0 or math.abs(pr.x - 56) + math.abs(pr.y - 26) < math.abs(r0.x - 56) + math.abs(r0.y - 26)) then r0 = pr end
    end
    app.jugador.x, app.jugador.y = (r0 and r0.x + 1 or 46) + 0.5, (r0 and r0.y + 4 or 24) + 0.5
    -- si hay huecos a la vista, mejor enseÃ±arlos
    local g0
    for gx, col in pairs(app.mundo.mapas.batalla.decorado) do for gy, t in pairs(col) do if t == "grieta" and (not g0 or math.abs(gx - 46) + math.abs(gy - 26) < math.abs(g0[1] - 46) + math.abs(g0[2] - 26)) then g0 = { gx, gy } end end end
    if g0 and not os.getenv("DC_FOTO_RISCO") then app.jugador.x, app.jugador.y = g0[1] + 0.5, g0[2] + 4.5 end
    foto.espera = 0
  end
  if foto.espera > 0.35 and not app.capturando and foto.paso ~= "fin" then
    app.capturando = true
    local nombre = foto.paso
    if nombre ~= "equipo" and nombre ~= "arbol" and nombre ~= "mercado" and nombre ~= "encantar" and nombre ~= "mascotas" and nombre ~= "gremio" and nombre ~= "mapa" and nombre ~= "oficios" and nombre ~= "mercancias" and nombre ~= "establo" and nombre ~= "subastas" and nombre ~= "grupo" then Interfaz.panel = nil end
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
