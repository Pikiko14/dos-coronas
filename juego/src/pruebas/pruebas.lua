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
      "meteoro", "flecha_veneno", "paso_agil", "sanacion", "juicio",
      "estocada", "barrido", "muro_lanzas", "embestida", "jabalina", "tormenta_lanzas",
      "toque_necro", "espinas", "maldecir", "alzar_esqueletos", "drenar", "espectro" }) do
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
        local archivo = ({ equipment = "otsp_equipment_01.png", extra = "equipo_extra.png" })[hoja] or (hoja .. ".png")
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
    local Fx = require("src.presentacion.render.monturas_fx")
    local nuevas = { "unicornio", "lobo_ascua", "lobo_escarcha", "toro_trueno", "pegaso",
      "fenix", "corcel_astral", "dragon_hielo", "dragon_sombra", "gargola_oro" }
    for id, d in pairs(Monturas.especies) do
      for _, fac in ipairs({ "albor", "umbra" }) do
        local def = Personajes.monturaDe(id, fac)
        fallar(errores, "la montura " .. id .. " tiene dibujo (" .. fac .. ")", def ~= nil)
        if def and def.generada then fallar(errores, "su hoja " .. def.generada .. " se genera", Propias.hoja(def.generada) ~= nil) end
      end
    end
    for _, id in ipairs(nuevas) do
      fallar(errores, id .. " es una montura de las listas", Monturas.especies[id] ~= nil)
      fallar(errores, id .. " tiene efectos", Fx.tiene(id))
      for dir = 1, 4 do
        local ok, err = pcall(function()
          Fx.detras(id, 100, 100, dir, 1.3, 1)
          Fx.delante(id, 100, 100, dir, 1.3, 1, 40)
        end)
        fallar(errores, id .. " dibuja sus efectos hacia " .. dir, ok, tostring(err))
      end
    end
    local mall = require("compartido.dominio.mall")
    local enMall = 0
    for _, id in ipairs(mall.ORDEN_MONTURAS) do enMall = enMall + 1 end
    fallar(errores, "el mall tiene seis monturas (el dragón y cinco nuevas)", enMall == 6, tostring(enMall))
    local gratis = 0
    for _, id in ipairs(Monturas.orden) do if Monturas.especies[id].precio >= 5000 and not Monturas.especies[id].requiereOficio then gratis = gratis + 1 end end
    fallar(errores, "la cuadra suma cinco monturas nuevas de oro", gratis >= 5)
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
    fallar(errores, "con monturas el icono sale siempre, aunque no haya oficio activo", Interfaz.consumir((1280 - lado0) / 2 + 231, 720 - consola0 - 34) == "hud_montura")
    -- la colección de monturas se dibuja con normales, del mall y de transporte, y con el estado de cada una
    pj.monturas = { "caballo", "corcel_real", "dragon", "carreta" }
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
    local exp = Datos.item("tarjeta_exp")
    fallar(errores, "la experiencia doble usa el icono x2", exp and exp.hoja == "bonos" and exp.sprite == 0)
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
      local def = P.skins[id]
      todas = todas and def ~= nil and ((def.generada and require("src.presentacion.render.propias").hoja(def.generada) ~= nil) or (def.hoja and require("src.presentacion.render.arte").img(def.hoja) ~= nil))
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
  paso("animación de ataque: criaturas y addons se mueven y vuelven a su sitio", function()
    local Dibujo = require("src.presentacion.render.dibujo")
    local reloj = 50
    Dibujo.relojAtaque = function() return reloj end
    local ok, err = pcall(function()
      for _, base in ipairs({
        { kind = "monstruo", monstruo = "gato", dir = 3 },
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
    fallar(errores, "la nova se lanza al momento", llamadas[1] and llamadas[1][1] == "habilidad" and llamadas[1][2].x == nil and app.apuntando == nil)
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
    local faltan = {}
    for _, m in ipairs(Datos.monstruos) do
      if not m.noCampamento then
        local d = P.monstruos[m.id]
        if not d or not Arte.img(d.hoja) then faltan[#faltan + 1] = m.id
        else
          local ok = pcall(P.dibujar, d, 1, true, 0.2, 100, 100, d.tinte)
          if not ok then faltan[#faltan + 1] = m.id .. "(dibujo)" end
        end
      end
    end
    fallar(errores, "cada criatura se dibuja", #faltan == 0, table.concat(faltan, ", "))
    local dragon = P.monstruos.dragon
    local hoja = Arte.img(dragon.hoja)
    fallar(errores, "el dragón joven usa el cuadro de 80 de su lámina", dragon.celda == 80 and dragon.fila == 1
      and hoja:getWidth() == dragon.celda * 3 and hoja:getHeight() >= (dragon.fila + 1) * dragon.celda)
    local alto = P.dibujar(dragon, 1, false, 0, 100, 100)
    fallar(errores, "el dragón joven se dibuja entero", alto == 80, tostring(alto))
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
  paso("sprites de clases y monturas por código", function()
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
    for _, esp in ipairs({ "corcel_real", "lobo_guerra", "bisonte_guerra", "corcel_fuego" }) do
      for _, faccion in ipairs({ "albor", "umbra" }) do
        local def = Personajes.monturaDe(esp, faccion)
        fallar(errores, "montura " .. esp .. "/" .. faccion, def and def.generada and Propias.hoja(def.generada) ~= nil)
        love.graphics.push("all")
        love.graphics.setCanvas({ cv, stencil = true })
        local ok, err = pcall(Personajes.dibujar, def, 3, true, 0.5, 100, 100)
        love.graphics.pop()
        fallar(errores, "se dibuja " .. esp, ok, tostring(err))
      end
    end
    fallar(errores, "las monturas de carga siguen con su hoja", Personajes.monturaDe("buey", "albor").hoja ~= nil)
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
    for y = 110, 260, 4 do for x = 640, 1000, 4 do
      local id = Interfaz.consumir(x, y)
      if id == "mall_mt_buy_dragon" then compra = true end
    end end
    fallar(errores, "ofrece comprar el dragon con monedas", compra)
    llamadas = {}
    Entrada.manejar(app, "mall_mt_buy_dragon")
    fallar(errores, "comprar manda la accion", llamadas[1] and llamadas[1][1] == "mall_montura_comprar" and llamadas[1][2].id == "dragon")
    -- sin monedas el boton no responde; con el dragon ya comprado dice que la tienes
    pj.mall.monedas = 5
    Interfaz.hud(mundo, pj, 1280, 720)
    local hay = false
    for y = 110, 260, 4 do for x = 640, 1000, 4 do if Interfaz.consumir(x, y) == "mall_mt_buy_dragon" then hay = true end end end
    fallar(errores, "sin monedas no se puede comprar", not hay)
    pj.monturas = { "dragon" }
    ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
    fallar(errores, "con el dragon comprado se dibuja", ok, tostring(err))
    -- el sprite del dragon, en las dos facciones, con cada clase encima
    local cv = love.graphics.newCanvas(400, 300)
    for _, f in ipairs({ "albor", "umbra" }) do
      fallar(errores, "hoja del dragon " .. f, Propias.hoja("montura_dragon_" .. f) ~= nil)
      local d = Personajes.monturaDe("dragon", f)
      fallar(errores, "el dragon es grande y el jinete va alto", d.escala and d.escala > 1.2 and d.altura and d.altura > 14)
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
    pj.montado = "dragon"
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
    for id in pairs(Mall.ADDONS) do ids[#ids + 1] = id end
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
    fallar(errores, "la pestana de transporte muestra buey, caballo y carreta", a.buey and a.caballo and a.carreta and not a.corcel_real and not a.lobo_guerra)
    Entrada.manejar(app, "est_tab_normales")
    local b = botones()
    fallar(errores, "la pestana normal muestra las de viaje", b.corcel_real and b.lobo_guerra and b.bisonte_guerra and b.corcel_fuego and not b.buey and not b.caballo)
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
    pj.monturas, pj.montado = { "buey", "corcel_real" }, "buey"
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
    pj.job, pj.montado, pj.monturaHp, pj.monturaHpMax = nil, "corcel_real", nil, nil
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
  paso("sprites de hechizos: cada poder de cada clase tiene su hoja generada", function()
    local Efectos = require("src.presentacion.render.efectos")
    local Dibujo = require("src.presentacion.render.dibujo")
    local Arte = require("src.presentacion.render.arte")
    local cv = love.graphics.newCanvas(300, 300)
    local n = 0
    for _, clase in ipairs({ "guerrero", "mago", "cazador", "clerigo" }) do
      for _, id in ipairs(Datos.barra[clase]) do
        local d = Efectos.def[id]
        fallar(errores, id .. " (" .. clase .. ") usa una hoja de hechizo propia", d and d[1] == "Hechizo_" .. id, d and d[1] or "sin efecto")
        local img = Arte.img("Animations/Hechizo_" .. id .. ".png", true)
        fallar(errores, "la hoja de " .. id .. " mide 5x3 cuadros de 192", img:getWidth() == 960 and img:getHeight() == 576)
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
      fallar(errores, "proyectil " .. tipo .. " de 4 cuadros", img:getWidth() == 256 and img:getHeight() == 64)
      fallar(errores, "impacto de " .. tipo, Efectos.def[tipo] ~= nil)
      love.graphics.push("all")
      love.graphics.setCanvas({ cv, stencil = true })
      local ok, err = pcall(Dibujo.proyectil, { tipo = tipo, x = 0, y = 0, tx = 5, ty = 2 }, 150, 150)
      love.graphics.pop()
      fallar(errores, "se dibuja el proyectil " .. tipo, ok, tostring(err))
    end
    fallar(errores, "se probaron los 24 poderes", n == 24 * 5, tostring(n))
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
    love.mouse.setPosition(300, 720 - consola / 2)
    Entrada.rueda({ estado = "juego" }, 1)
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
  paso("interfaz: clics", function()
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Clic", faccion = "albor", clase = "mago" })
    Interfaz.escala = 1
    Interfaz.panel = nil
    Interfaz.hud(mundo, pj, 1280, 720)
    local lado, consola = Interfaz.medidas()
    local yTab = 720 - consola + 12
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
    fallar(errores, "el hueco de la barra de poderes responde", Interfaz.consumir((1280 - lado) / 2 - 175, 720 - consola - 34) == "hab_1")
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
  paso("interfaz: el boticario y el armero tienen pestañas distintas", function()
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
    for _, tab in ipairs({ "pociones", "vender" }) do
      Interfaz.mercadoTab = tab
      local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
      fallar(errores, "la clériga dibuja " .. tab, ok, tostring(err))
    end
    Interfaz.mercadoTab = "pociones"
    Interfaz.hud(mundo, pj, 1280, 720)
    fallar(errores, "la clériga solo tiene pociones y vender", contarPestanas() == 2, tostring(contarPestanas()))
    Interfaz.tienda = "armero"
    for _, tab in ipairs({ "armas", "armadura", "escudos", "accesorios", "mochilas", "vender" }) do
      Interfaz.mercadoTab = tab
      local ok, err = pcall(Interfaz.hud, mundo, pj, 1280, 720)
      fallar(errores, "el armero dibuja " .. tab, ok, tostring(err))
    end
    Interfaz.mercadoTab = "armadura"
    Interfaz.hud(mundo, pj, 1280, 720)
    fallar(errores, "el armero tiene armadura, armas y el resto del equipo", contarPestanas() == 6, tostring(contarPestanas()))
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
  if foto.paso == "menu" and os.getenv("DC_FOTO_FUEGO") then
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

local function avanzarFoto(app)
  local foto = app.foto
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
    app.jugador.montado = "dragon"
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
    app.jugador.montado = "corcel_real"
    app.jugador.nivel = 14
    app.jugador.oro = 3000
    local Mont = require("compartido.dominio.monturas")
    local cat = {}
    for k, id in ipairs(Mont.orden) do
      local d = Mont.especies[id]
      cat[#cat + 1] = { id = id, nombre = d.nombre, nivel = d.nivel, precio = d.precio, vel = d.vel, carga = d.carga, oficio = d.oficio, requiereOficio = d.requiereOficio and true or false, desc = d.desc, tengo = k % 3 == 1 }
    end
    Interfaz.datosPanel.establo = { montado = "corcel_real", cerca = true, catalogo = cat }
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
    if nombre ~= "equipo" and nombre ~= "arbol" and nombre ~= "mercado" and nombre ~= "encantar" and nombre ~= "mascotas" and nombre ~= "gremio" and nombre ~= "mapa" and nombre ~= "tablon" and nombre ~= "diario" and nombre ~= "mapamision" and nombre ~= "oficios" and nombre ~= "mercancias" and nombre ~= "establo" and nombre ~= "subastas" and nombre ~= "grupo" then Interfaz.panel = nil end
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
