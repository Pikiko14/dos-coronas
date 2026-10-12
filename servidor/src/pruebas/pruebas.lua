-- Pruebas del servidor: dominio, cuentas, red, servicio y configuración.
-- Se ejecutan con: love servidor --test
local Datos = require("compartido.dominio.datos")
local Mundo = require("compartido.dominio.mundo")
local Util = require("compartido.dominio.util")
local Cuentas = require("src.aplicacion.cuentas")
local Red = require("compartido.infraestructura.red")
local Log = require("compartido.infraestructura.log")
local Config = require("src.infraestructura.config")
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
    fallar(errores, "json lista", d and d.lista and d.lista[2] == 2)
  end)
  paso("datos", function()
    fallar(errores, "30 monstruos", #Datos.monstruos == 30, tostring(#Datos.monstruos))
    fallar(errores, "10 ciudades", #Datos.ciudades == 10)
    fallar(errores, "mapa extenso", Datos.MAPA_W >= 700 and Datos.MAPA_H >= 500)
    fallar(errores, "nivel maximo", Datos.NIVEL_MAX == 30)
    fallar(errores, "4 clases", Datos.clases.clerigo and Datos.clases.guerrero and Datos.clases.mago and Datos.clases.cazador)
  end)  paso("mundo", function()
    local mundo = Mundo.nuevo()
    fallar(errores, "ciudades mapa", #mundo.mapas.mundo.ciudades == 10)
    fallar(errores, "campamentos", #mundo.mapas.mundo.campamentos >= 20, tostring(#mundo.mapas.mundo.campamentos))
    local biomaOk = true
    for _, camp in ipairs(mundo.mapas.mundo.campamentos) do
      local mon = Datos.monstruo(camp.monstruo)
      local tx, ty = math.floor(camp.x), math.floor(camp.y)
      local b = mundo.mapas.mundo.bioma[tx] and mundo.mapas.mundo.bioma[tx][ty]
      if mon and mon.bioma and b ~= mon.bioma then biomaOk = false break end
    end
    fallar(errores, "monstruo en su bioma", biomaOk)
    local jugador = mundo:crearPersonaje({ nombre = "Prueba", faccion = "albor", clase = "clerigo" })
    local sx, sy = jugador.x, jugador.y
    fallar(errores, "escaleras", #(mundo.mapas.mundo.escaleras or {}) >= 2)
    local esc
    for _, s in ipairs(mundo.mapas.mundo.escaleras or {}) do
      if s.de == 0 then esc = s break end
    end
    if esc then
      jugador.x, jugador.y, jugador.z = esc.x + 0.5, esc.y + 0.5, 0
      jugador.escaleraEn = 0
      mundo:pisarEscalera(jugador)
      fallar(errores, "sube de piso", jugador.z == 1)
    end
    jugador.x, jugador.y, jugador.z = sx, sy, 0
    mundo:fijarDestino(jugador, jugador.x + 40, jugador.y + 8)
    fallar(errores, "ruta limitada", jugador.camino and #jugador.camino <= 80, tostring(jugador.camino and #jugador.camino))
    jugador.camino = nil
    jugador.hp = 10
    mundo:accion(jugador.id, "habilidad", { slot = 1 })
    fallar(errores, "clerigo cura", jugador.hp > 10, tostring(jugador.hp))
    local gato = mundo:spawnMonstruo("gato", jugador.x + 1, jugador.y, { x = jugador.x, y = jugador.y })
    fallar(errores, "spawn gato", gato ~= nil)
    mundo:danar(gato, 99999, jugador)
    fallar(errores, "gato muere", gato.vivo == false)
    fallar(errores, "xp", jugador.xp > 0)
    jugador.nivel = 5
    mundo:darItem(jugador, "clerigo_arma_2", 1)
    local idx = #jugador.bolsa
    mundo:accion(jugador.id, "equipar", { i = idx })
    fallar(errores, "equipo visible", jugador.equipo.arma == "clerigo_arma_2")
    mundo:accion(jugador.id, "chat", { texto = "hola guerra" })
    fallar(errores, "chat", #mundo.mensajes > 0)
    local bot
    for _, e in pairs(mundo.entidades) do
      if e.kind == "bot" and e.faccion == "albor" then bot = e break end
    end
    if not bot then
      bot = mundo:crearPersonaje({
        kind = "bot", nombre = "Donato", faccion = "albor", clase = "guerrero", nivel = 4, oro = 80,
      })
    end
    fallar(errores, "hay bot", bot ~= nil)
    if bot then
      bot.x, bot.y = jugador.x, jugador.y
      mundo:accion(jugador.id, "comercio_invitar", { id = bot.id })
      fallar(errores, "sesion trade", jugador.sesion ~= nil)
      mundo:accion(jugador.id, "comercio_oro", { oro = 40 })
      mundo:accion(jugador.id, "comercio_ok")
      fallar(errores, "trade cierra", jugador.sesion == nil)
    end
    mundo.tiempo = 30
    jugador.oro = 5000
    local auroria
    for _, c in ipairs(mundo.mapas.mundo.ciudades) do if c.id == "auroria" then auroria = c end end
    local par = auroria.parcelas[1]
    jugador.x, jugador.y = auroria.spawn.x, auroria.spawn.y
    mundo:accion(jugador.id, "casa_comprar", { id = par.id })
    fallar(errores, "compra casa", par.dueno == jugador.id)
    jugador.x, jugador.y = par.x + 0.5, par.y + 1.2
    mundo:accion(jugador.id, "casa_entrar", { id = par.id })
    fallar(errores, "entrar casa", jugador.modo == "casa")
    mundo:accion(jugador.id, "mueble", { tipo = "cama" })
    fallar(errores, "cama", jugador.casas[par.id].muebles.cama == true)
    mundo:accion(jugador.id, "casa_salir")
    local extras = {}
    for i = 1, 2 do
      extras[#extras + 1] = mundo:crearPersonaje({ nombre = "Alba" .. i, faccion = "albor", clase = "guerrero" })
    end
    for i = 1, 3 do
      extras[#extras + 1] = mundo:crearPersonaje({ nombre = "Umbra" .. i, faccion = "umbra", clase = "guerrero" })
    end
    mundo:accion(jugador.id, "guerra", { modo = "batalla" })
    fallar(errores, "espera equipo", jugador.modo ~= "batalla" and jugador.colaGuerra == "batalla")
    for i = 1, #extras - 1 do
      mundo:accion(extras[i].id, "guerra", { modo = "batalla" })
    end
    fallar(errores, "faltan jugadores", jugador.modo ~= "batalla")
    mundo:accion(extras[#extras].id, "guerra", { modo = "batalla" })
    fallar(errores, "entra batalla", jugador.modo == "batalla")
    local botsCampo = 0
    for _, e in pairs(mundo.entidades) do
      if e.modo == "batalla" and e.kind == "bot" then botsCampo = botsCampo + 1 end
    end
    fallar(errores, "evento sin bots", botsCampo == 0)
    local estatua
    for _, e in pairs(mundo.entidades) do
      if e.kind == "estatua" and e.faccion == "umbra" and e.vivo then estatua = e break end
    end
    fallar(errores, "hay estatua", estatua ~= nil)
    if estatua then
      mundo:danar(estatua, 999999, jugador)
      fallar(errores, "estatua cae", estatua.vivo == false)
      local tiene = false
      for _, s in ipairs(jugador.bolsa) do if s.id == "cristal" then tiene = true end end
      fallar(errores, "cristal enemigo", tiene)
    end
    mundo:accion(jugador.id, "salir_guerra")
    mundo:accion(jugador.id, "guerra", { modo = "batalla" })
    fallar(errores, "batalla una vez al dia", jugador.modo ~= "batalla")
    mundo.tiempo = mundo.tiempo + 8
    jugador.ultimoGolpe = 0
    mundo:accion(jugador.id, "guerra", { modo = "estandarte" })
    for _, e in ipairs(extras) do
      mundo:accion(e.id, "guerra", { modo = "estandarte" })
    end
    fallar(errores, "entra estandarte", jugador.modo == "estandarte")
    local bandera
    for _, e in pairs(mundo.entidades) do
      if e.kind == "bandera" and e.faccion == "umbra" then bandera = e break end
    end
    fallar(errores, "hay estandarte", bandera ~= nil)
    if bandera then
      jugador.x, jugador.y = bandera.x, bandera.y
      mundo:tocarBandera(jugador)
      fallar(errores, "toma estandarte", jugador.llevaBandera == "umbra")
    end
    for _ = 1, 5 do mundo:actualizar(0.05) end
  end)
  paso("cuentas", function()
    fallar(errores, "sha256", Cuentas.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", Cuentas.sha256("abc"))
    local vector = Cuentas.pbkdf2("password", "salt", 1)
    fallar(errores, "pbkdf2", vector == "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b", vector)
    local okVieja, migrar = Cuentas.acepta(Cuentas.sha256("abc123:clave12"), "abc123", "clave12")
    fallar(errores, "clave antigua", okVieja and migrar)
    local okNueva, mig2 = Cuentas.acepta(Cuentas.cifrar("clave12", "abc123"), "abc123", "clave12")
    fallar(errores, "clave nueva", okNueva and not mig2)
    local usuario = "qa" .. string.format("%06d", os.time() % 1000000)
    Cuentas.borrarUsuario(usuario)
    local id, err = Cuentas.registrar(usuario, "clave12")
    fallar(errores, "registro", id ~= nil, usuario .. " " .. tostring(err))
    local otra = Cuentas.registrar(usuario, "clave12")
    fallar(errores, "usuario unico", otra == nil)
    local mala = Cuentas.entrar(usuario, "nope")
    fallar(errores, "clave mala", mala == nil)
    local entra = Cuentas.entrar(usuario, "clave12")
    fallar(errores, "login", entra == id)
    local pid, errPj = Cuentas.crearPersonaje(id, "Liora", "albor", "clerigo")
    fallar(errores, "crear pj", pid ~= nil, tostring(errPj))
    local marca = Cuentas.marcarEvento(pid, "batalla")
    fallar(errores, "marca evento", marca == true)
    local cargado = Cuentas.cargar(pid)
    fallar(errores, "evento del dia", cargado and cargado.eventosDia and cargado.eventosDia.batalla == os.date("%Y-%m-%d"))
    for _ = 1, 5 do Cuentas.entrar(usuario, "nope") end
    local idb, msgb = Cuentas.entrar(usuario, "clave12")
    fallar(errores, "tope de intentos", idb == nil and type(msgb) == "string" and msgb:find("Espera") ~= nil, tostring(msgb))
    Cuentas.borrarUsuario(usuario)
  end)
  paso("red", function()
    fallar(errores, "ffi red", Red.disponible() == true)
    local srv = Red.escuchar(30556)
    fallar(errores, "escucha", srv ~= nil)
    local fantasma = false
    if srv then
      for _, e in ipairs(srv:actualizar()) do
        if e.tipo == "conecta" then fantasma = true end
      end
    end
    fallar(errores, "sin conexion fantasma", fantasma == false)
    local cli = srv and Red.conectar("127.0.0.1", 30556)
    fallar(errores, "conecta", cli ~= nil)
    if srv and cli then
      local recibio = false
      for _ = 1, 40 do
        love.timer.sleep(0.03)
        cli:enviar({ t = "hola", nombre = "Remoto", faccion = "umbra", clase = "mago" })
        local ev = srv:actualizar()
        for _, e in ipairs(ev) do
          if e.tipo == "msg" and e.msg.t == "hola" and e.msg.nombre == "Remoto" then recibio = true end
        end
        cli:actualizar()
        if recibio then break end
      end
      fallar(errores, "mensaje hola", recibio)
      cli:cerrar()
      srv:cerrar()
    end
  end)
  paso("sesion", function()
    local Servidor = require("src.aplicacion.servicio_servidor")
    local Autoridad = require("src.dominio.autoridad")
    local Balance = require("compartido.dominio.balance")
    local Tiled = require("src.infraestructura.mapas.tiled")
    fallar(errores, "curva xp", Balance.xpPara(1) == Datos.xpPara(1) and Balance.xpPara(2) > Balance.xpPara(1) and Balance.xpPara(10) > Balance.xpPara(2) * 2)
    fallar(errores, "sin exp si septuplica", Balance.xpMonstruo(14, 2) == 0 and Balance.xpMonstruo(13, 2) > 0)
    fallar(errores, "exp segun nivel", Balance.xpMonstruo(5, 8) > Balance.xpMonstruo(8, 5) and Balance.xpMonstruo(8, 5) > 0)
    fallar(errores, "slot por nivel", Balance.slotDisponible(1, 4) == false and Balance.slotDisponible(8, 4) == true)
    local botin = Balance.tirar({ id = "x", botin = { { id = "pocion_vida", p = 1 } } })
    fallar(errores, "tabla de botin", botin[1] and botin[1].id == "pocion_vida")
    fallar(errores, "deseo fuera", Autoridad.aceptar(nil, { clase = "mago", nivel = 1, x = 1, y = 1 }, "deseo", { x = 5, y = 0 }) == false)
    fallar(errores, "deseo vale", Autoridad.aceptar(nil, { clase = "mago", nivel = 1, x = 1, y = 1 }, "deseo", { x = 0.2, y = 0 }) == true)
    local srv = { vinculo = {}, enviados = {} }
    function srv:enviar(_, msg) self.enviados[#self.enviados + 1] = msg end
    local mundo = Mundo.nuevo()
    Servidor.tratar(srv, mundo, 7, { t = "hola" })
    fallar(errores, "hola sin token", srv.enviados[1] and srv.enviados[1].t == "no")
    local usuario = "qs" .. string.format("%06d", os.time() % 1000000)
    local nombre = "Neria" .. string.format("%03d", os.time() % 1000)
    Cuentas.borrarUsuario(usuario)
    local id, token = Cuentas.registrar(usuario, "clave12")
    local pid = id and Cuentas.crearPersonaje(id, nombre, "umbra", "mago")
    fallar(errores, "token", token ~= nil and pid ~= nil, tostring(token))
    local caja = { vinculo = {}, enviados = {} }
    function caja:enviar(_, msg) self.enviados[#self.enviados + 1] = msg end
    Servidor.tratar(caja, mundo, 9, { t = "cuenta", a = "entrar", usuario = usuario, clave = "no" })
    fallar(errores, "servidor rechaza clave", caja.enviados[1] and caja.enviados[1].t == "no")
    Servidor.tratar(caja, mundo, 9, { t = "cuenta", a = "entrar", usuario = usuario, clave = "clave12" })
    local ses = caja.enviados[#caja.enviados]
    fallar(errores, "servidor abre sesion", ses and ses.t == "sesion" and type(ses.token) == "string" and ses.usuario == usuario)
    local nombre2 = "Vera" .. string.format("%03d", (os.time() + 17) % 1000)
    Servidor.tratar(caja, mundo, 9, {
      t = "cuenta", a = "crear", token = ses and ses.token, nombre = nombre2, faccion = "albor", clase = "guerrero",
    })
    local cre = caja.enviados[#caja.enviados]
    fallar(errores, "servidor crea personaje", cre and cre.t == "sesion" and tonumber(cre.creado) ~= nil)
    if token and pid then
      Servidor.tratar(srv, mundo, 7, { t = "hola", token = token, personaje = pid })
      local ultimo = srv.enviados[#srv.enviados]
      fallar(errores, "hola con token", ultimo and ultimo.t == "ok" and ultimo.nombre == nombre, ultimo and (ultimo.error or ultimo.t))
      local pj = srv.vinculo[7] and mundo.entidades[srv.vinculo[7]]
      fallar(errores, "personaje real", pj and pj.nombre == nombre and pj.dbId == pid)
    end
    local falso = { tasa = {} }
    local admitidos = 0
    for _ = 1, 41 do
      if Servidor.permite(falso, 1, 10) then admitidos = admitidos + 1 end
    end
    fallar(errores, "limite de tasa", admitidos == 40, tostring(admitidos))
    local viejo = Cuentas.guardar
    Cuentas.guardar = function() return nil, "caido" end
    local pj = { dbId = pid or 1, nombre = nombre, oro = 12, kind = "jugador", nivel = 1, xp = 0, x = 3, y = 4, hp = 10, mp = 10 }
    local okG = Servidor.guardarUno({ exportar = function() return { clase = "mago" } end }, pj)
    fallar(errores, "reintento no borra", okG == false and pj.oro == 12 and pj.pendienteGuardar == true)
    Cuentas.guardar = viejo
    local mapaT, errT = Tiled.desdeArchivo("mapas/atalaya.lua")
    fallar(errores, "tiled", mapaT and mapaT.w == 8 and mapaT.suelo[1] and mapaT.suelo[1][1] == "hierba", tostring(errT))
    Cuentas.borrarUsuario(usuario)
  end)
  paso("daño", function()
    local Balance = require("compartido.dominio.balance")
    local function secuencia(...)
      local v, i = { ... }, 0
      return function() i = i + 1 return v[(i - 1) % #v + 1] end
    end
    local mn, mx = Balance.rangoDano(100, 0, 1)
    fallar(errores, "rango sin defensa: 45 a 90", mn == 45 and mx == 90, mn .. "-" .. mx)
    local dmn, dmx = Balance.rangoDano(100, 40, 1)
    fallar(errores, "con defensa 40 el rango se reduce a la mitad", dmn == 23 and dmx == 45, dmn .. "-" .. dmx)
    local cm, cmx = Balance.rangoDano(100, 0, 2)
    fallar(errores, "el poder del golpe multiplica el rango", cm == 90 and cmx == 180, cm .. "-" .. cmx)
    local bajo, c1 = Balance.tirarDano(100, 0, 1, secuencia(0, 0, 0.99))
    fallar(errores, "tirada mínima = mínimo", bajo == 45 and not c1, tostring(bajo))
    local alto, c2 = Balance.tirarDano(100, 0, 1, secuencia(0.999, 0.999, 0.99))
    fallar(errores, "tirada máxima = máximo", alto == 90 and not c2, tostring(alto))
    local medio = Balance.tirarDano(100, 0, 1, secuencia(0.5, 0.5, 0.99))
    fallar(errores, "tirada media = punto medio", medio == 68, tostring(medio))
    local crit, c3 = Balance.tirarDano(100, 0, 1, secuencia(0.5, 0.5, 0.01))
    fallar(errores, "crítico = 1,5 x el máximo", c3 == true and crit == 135, tostring(crit))
    fallar(errores, "nunca menos de 1", Balance.tirarDano(0, 500, 1, secuencia(0, 0, 0.99)) == 1)
    fallar(errores, "más ataque, más daño", Balance.rangoDano(200, 0, 1) > Balance.rangoDano(100, 0, 1))
    local minimo, maximo, suma, distintos, vistos = math.huge, 0, 0, 0, {}
    local n, criticos = 4000, 0
    for _ = 1, n do
      local d, c = Balance.tirarDano(100, 0, 1)
      if d < minimo then minimo = d end
      if d > maximo then maximo = d end
      suma = suma + d
      if c then criticos = criticos + 1 end
      if not vistos[d] then vistos[d] = true distintos = distintos + 1 end
    end
    fallar(errores, "los golpes varían de verdad", distintos >= 25, tostring(distintos))
    fallar(errores, "ningún golpe baja del mínimo", minimo >= 45, tostring(minimo))
    fallar(errores, "ningún golpe pasa del máximo del crítico", maximo <= 135, tostring(maximo))
    fallar(errores, "media cerca del 90% del ataque", suma / n > 62 and suma / n < 75, tostring(suma / n))
    fallar(errores, "críticos cerca del 8%", criticos > n * 0.04 and criticos < n * 0.13, tostring(criticos))
    -- en el mundo: un guerrero contra un muñeco sin defensa
    local mundo = Mundo.nuevo()
    local j = mundo:crearPersonaje({ nombre = "Pega", faccion = "albor", clase = "guerrero" })
    local gato = mundo:spawnMonstruo("gato", j.x + 1, j.y, { x = j.x, y = j.y })
    gato.def, gato.hp, gato.hpMax = 0, 1e9, 1e9
    local golpes = {}
    for _ = 1, 300 do
      local antes = gato.hp
      mundo:golpear(j, gato, 1)
      golpes[gato.hp - antes] = true
    end
    local cuantos = 0
    for _ in pairs(golpes) do cuantos = cuantos + 1 end
    fallar(errores, "en el mundo cada golpe pega distinto", cuantos >= 8, tostring(cuantos))
    local a, b = Balance.rangoDano(j.atk, 0, 1)
    for k in pairs(golpes) do
      if -k < a or -k > math.floor(b * Balance.CRITICO_MUL + 1) then errores[#errores + 1] = "golpe fuera de rango: " .. k break end
    end
  end)
  paso("montañas entre zonas y ciudades conectadas", function()
    local Mapa = require("compartido.dominio.mapa")
    local mapa = Mundo.nuevo().mapas.mundo
    local picos = 0
    for _, p in ipairs(mapa.props) do
      if p.tipo == "montana_albor" or p.tipo == "montana_umbra" then
        picos = picos + 1
        for dy = 0, 1 do
          for dx = 0, 1 do
            fallar(errores, "pico bloquea su casilla", mapa.bloque[p.x + dx][p.y + dy] and mapa.suelo[p.x + dx][p.y + dy] == "montana")
          end
        end
      end
    end
    fallar(errores, "hay montañas (" .. picos .. ")", picos >= 20)
    local ciudades = mapa.ciudades
    for i = 2, #ciudades do
      local a, b = ciudades[1], ciudades[i]
      local ruta = Mapa.buscar(mapa, a.x + a.w / 2, a.y + a.h + 2, b.x + b.w / 2, b.y + b.h + 2)
      fallar(errores, "ruta de " .. a.nombre .. " a " .. b.nombre, ruta ~= nil and #ruta > 0)
    end
  end)
  paso("árbol de poderes: aprender, mejorar y reiniciar", function()
    local Arbol = require("compartido.dominio.arbol")
    local mundo = Mundo.nuevo()
    for clase, nodos in pairs(Arbol.arboles) do
      local activas, ids = 0, {}
      for _, n in ipairs(nodos) do
        fallar(errores, clase .. " nodo repetido " .. n.id, not ids[n.id])
        ids[n.id] = true
        if n.tipo == "activa" then
          activas = activas + 1
          fallar(errores, clase .. " " .. n.id .. " existe y es del oficio", Datos.habilidades[n.id] and Datos.habilidades[n.id].clase == clase)
          fallar(errores, clase .. " " .. n.id .. " ocupa su casilla de la barra", Datos.barra[clase][n.slot] == n.id)
        end
        if n.requiere then fallar(errores, clase .. " " .. n.id .. " pide un nodo que existe", ids[n.requiere[1]]) end
      end
      fallar(errores, clase .. " tiene seis poderes", activas == 6)
    end
    local m = mundo:crearPersonaje({ nombre = "Arbolito", faccion = "albor", clase = "guerrero" })
    fallar(errores, "empieza con el poder inicial", Arbol.rango(m, "golpe") == 1 and Arbol.rango(m, "tajo") == 0)
    fallar(errores, "nivel 1: sin puntos", Arbol.puntos(m) == 0)
    fallar(errores, "sin puntos no aprende", mundo:aprenderHabilidad(m, "vigor") ~= nil)
    fallar(errores, "sin conocer el poder no lo usa", mundo:usarHabilidad(m, 2) ~= nil and (m.cds.tajo or 0) == 0)
    m.nivel = 5
    mundo:recalcular(m)
    fallar(errores, "nivel 5: cuatro puntos", Arbol.puntos(m) == 4, tostring(Arbol.puntos(m)))
    fallar(errores, "no se salta requisitos", mundo:aprenderHabilidad(m, "tajo") ~= nil)
    fallar(errores, "mejora golpe a rango 2", mundo:aprenderHabilidad(m, "golpe") == nil and m.habilidades.golpe == 2)
    fallar(errores, "ahora aprende tajo", mundo:aprenderHabilidad(m, "tajo") == nil and m.habilidades.tajo == 1)
    fallar(errores, "pide nivel para grito", mundo:aprenderHabilidad(m, "grito") ~= nil)
    local hpAntes = m.hpMax
    fallar(errores, "aprende la pasiva vigor", mundo:aprenderHabilidad(m, "vigor") == nil)
    fallar(errores, "la pasiva sube la vida", m.hpMax > hpAntes, hpAntes .. " -> " .. m.hpMax)
    fallar(errores, "se gastaron tres puntos", Arbol.puntos(m) == 1, tostring(Arbol.puntos(m)))
    -- los poderes altos piden nivel para aprenderse; mejorarlos solo cuesta puntos
    local mg = mundo:crearPersonaje({ nombre = "Magote", faccion = "albor", clase = "mago" })
    mg.nivel = 6
    mundo:aprenderHabilidad(mg, "misil")
    mundo:aprenderHabilidad(mg, "misil")
    fallar(errores, "Bola de fuego no se aprende antes del nivel 7", mundo:aprenderHabilidad(mg, "fuego") == "Necesitas nivel 7.")
    mg.nivel = 7
    fallar(errores, "Bola de fuego se aprende en el nivel 7", mundo:aprenderHabilidad(mg, "fuego") == nil)
    mg.nivel = 20
    fallar(errores, "subir de rango no pide más nivel", mundo:aprenderHabilidad(mg, "fuego") == nil and mg.habilidades.fuego == 2)
    -- el rango mejora el poder: más daño y menos enfriamiento
    local a, b = Arbol.efectiva("tajo", 1), Arbol.efectiva("tajo", 5)
    fallar(errores, "rango 5 pega más y enfría antes", b.coef > a.coef and b.cd < a.cd)
    m.mp = m.mpMax
    local previo = mundo:usarHabilidad(m, 2)
    fallar(errores, "usa tajo con su rango", previo == nil and (m.cds.tajo or 0) > 0)
    fallar(errores, "el enfriamiento sale del rango", math.abs((m.cds.tajo - mundo.tiempo) - Arbol.efectiva("tajo", 1).cd) < 0.01)
    -- exportar y volver a cargar conserva el árbol
    local ex = mundo:exportar(m)
    local otro = mundo:crearPersonaje({ nombre = "Arbolito2", faccion = "albor", clase = "guerrero" })
    mundo:aplicarGuardado(otro, ex)
    fallar(errores, "el guardado conserva los rangos", otro.habilidades.golpe == 2 and otro.habilidades.tajo == 1 and otro.habilidades.vigor == 1)
    fallar(errores, "y los puntos que quedan", Arbol.puntos(otro) == 1)
    -- guardado antiguo sin árbol: solo el poder inicial y todos los puntos libres
    local viejo = mundo:crearPersonaje({ nombre = "Viejito", faccion = "albor", clase = "mago" })
    mundo:aplicarGuardado(viejo, { clase = "mago", nivel = 7, equipo = {}, bolsa = {} })
    fallar(errores, "guardado sin árbol: puntos libres", Arbol.puntos(viejo) == 6 and Arbol.rango(viejo, "misil") == 1)
    -- reiniciar cuesta oro y devuelve los puntos
    m.oro = 0
    fallar(errores, "reiniciar pide oro", mundo:reiniciarHabilidades(m) ~= nil)
    m.oro = 1000
    fallar(errores, "reinicia", mundo:reiniciarHabilidades(m) == nil and Arbol.puntos(m) == 4 and m.habilidades.tajo == nil)
    -- la autoridad deja pasar el nombre y rechaza basura
    local Autoridad = require("src.dominio.autoridad")
    fallar(errores, "autoridad acepta aprender", Autoridad.aceptar(mundo, m, "aprender", { id = "tajo" }) == true)
    fallar(errores, "autoridad rechaza id absurdo", Autoridad.aceptar(mundo, m, "aprender", { id = {} }) == false)
  end)
  paso("encantamiento de equipo", function()
    local Encanto = require("compartido.dominio.encanto")
    local mundo = Mundo.nuevo()
    local g = mundo:crearPersonaje({ nombre = "Encanta", faccion = "albor", clase = "guerrero", nivel = 10 })
    g.oro = 100000
    mundo:darItem(g, "polvo_arcano", 99)
    local atkAntes = g.atk
    local azar = math.random
    math.random = function(a) if a then return 1 end return 0 end
    local ok, err = pcall(function() return mundo:encantar(g, "equipo", "arma") end)
    math.random = azar
    fallar(errores, "encantar sin error", ok and err == nil, tostring(err))
    fallar(errores, "sube a +1", g.encantos and g.encantos.arma == 1)
    fallar(errores, "el encantamiento sube el ataque", g.atk > atkAntes, atkAntes .. " -> " .. g.atk)
    fallar(errores, "cuesta oro y polvo", g.oro < 100000 and mundo:contarItem(g, "polvo_arcano") < 99)
    -- los primeros niveles no fallan; a partir de +7 un fallo baja un nivel
    fallar(errores, "los tres primeros son seguros", Encanto.prob(0) == 1 and Encanto.prob(2) == 1)
    fallar(errores, "la probabilidad baja", Encanto.prob(9) < Encanto.prob(4) and Encanto.prob(4) < 1)
    g.encantos.arma = 7
    mundo:recalcular(g)
    math.random = function(a) if a then return 1 end return 0.999 end
    ok = pcall(function() mundo:encantar(g, "equipo", "arma") end)
    math.random = azar
    fallar(errores, "un fallo alto baja un nivel", ok and g.encantos.arma == 6, tostring(g.encantos.arma))
    g.encantos.arma = 3
    math.random = function(a) if a then return 1 end return 0.999 end
    ok = pcall(function() mundo:encantar(g, "equipo", "arma") end)
    math.random = azar
    fallar(errores, "un fallo bajo no quita nivel", ok and g.encantos.arma == 3)
    -- falta de material u oro
    g.oro = 0
    fallar(errores, "sin oro no encanta", mundo:encantar(g, "equipo", "arma") ~= nil)
    g.oro = 100000
    for i = #g.bolsa, 1, -1 do if g.bolsa[i].id == "polvo_arcano" then table.remove(g.bolsa, i) end end
    fallar(errores, "sin polvo no encanta", mundo:encantar(g, "equipo", "arma") ~= nil)
    -- al desequipar y volver a equipar la pieza conserva su nivel
    mundo:desequipar(g, "arma")
    local idx
    for i, s in ipairs(g.bolsa) do if s.id == "guerrero_arma_3" then idx = i end end
    fallar(errores, "la pieza guardada lleva su +3", idx and g.bolsa[idx].enc == 3)
    if idx then mundo:equipar(g, idx) end
    fallar(errores, "al equiparla vuelve el +3", g.encantos.arma == 3)
    -- a lo máximo no se pasa
    g.encantos.arma = Encanto.MAX
    mundo:darItem(g, "polvo_arcano", 99)
    fallar(errores, "no pasa del máximo", mundo:encantar(g, "equipo", "arma") ~= nil)
  end)
  paso("mascotas", function()
    local Mascotas = require("compartido.dominio.mascotas")
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local function avanzar(seg) for _ = 1, math.floor(seg / 0.1) do mundo:actualizar(0.1) end end
    local dueno = mundo:crearPersonaje({ nombre = "Criador", faccion = "albor", clase = "guerrero", nivel = 12 })
    dueno.oro = 20000
    fallar(errores, "adopta un gatito", mundo:adoptarMascota(dueno, "gatito") == nil and dueno.mascotas[1].nivel == 1)
    fallar(errores, "no repite especie", mundo:adoptarMascota(dueno, "gatito") ~= nil)
    fallar(errores, "pide nivel", mundo:adoptarMascota(dueno, "avispa") ~= nil)
    fallar(errores, "cuesta oro", dueno.oro == 20000 - Mascotas.especies.gatito.precio)
    fallar(errores, "la invoca", mundo:invocarMascota(dueno, 1) == nil and dueno.mascotaId and mundo.entidades[dueno.mascotaId].kind == "mascota")
    local pet = mundo.entidades[dueno.mascotaId]
    -- sigue al dueño
    avanzar(2)
    fallar(errores, "la mascota está junto a su dueño", math.abs(pet.x - dueno.x) < 4 and math.abs(pet.y - dueno.y) < 4)
    -- pelea a su lado y el dueño se lleva la experiencia
    local blanco = mundo:spawnMonstruo("gato", dueno.x + 1.2, dueno.y, { x = dueno.x, y = dueno.y })
    blanco.hp, blanco.hpMax, blanco.agresivo, blanco.atk, blanco.matk = 400, 400, false, 0, 0
    dueno.objetivo = blanco.id
    local antes = blanco.hp
    avanzar(8)
    fallar(errores, "la mascota ataca", blanco.hp < antes, tostring(blanco.hp))
    local presa = mundo:spawnMonstruo("gargola", dueno.x + 1.2, dueno.y, { x = dueno.x, y = dueno.y })
    presa.hp = 1
    local xpAntes = dueno.mascotas[1].xp
    mundo:danar(presa, 5, dueno)
    fallar(errores, "la mascota gana experiencia", dueno.mascotas[1].xp > xpAntes or dueno.mascotas[1].nivel > 1)
    -- no pasa del nivel del dueño
    dueno.mascotas[1].nivel = dueno.nivel
    local lv = dueno.mascotas[1].nivel
    mundo:mascotaGanaXp(dueno, 100000)
    fallar(errores, "no supera al dueño", dueno.mascotas[1].nivel == lv)
    -- el limo guardián reduce el daño
    mundo:adoptarMascota(dueno, "limo")
    mundo:invocarMascota(dueno, 2)
    fallar(errores, "el limo da protección", (dueno.mascotaBono or 0) > 0.05, tostring(dueno.mascotaBono))
    fallar(errores, "solo una mascota fuera a la vez", not mundo.entidades[pet.id] or pet.borrar)
    dueno.hp = dueno.hpMax
    local golpe = Mascotas.proteccion("limo", 1)
    mundo:danar(dueno, 100, nil)
    fallar(errores, "el daño baja con el limo", dueno.hpMax - dueno.hp < 100 and dueno.hpMax - dueno.hp >= 100 * (1 - golpe - 0.2), tostring(dueno.hpMax - dueno.hp))
    -- en guerra no hay mascotas; al volver regresa
    dueno.modo = "batalla"
    avanzar(0.5)
    fallar(errores, "en la guerra se retira", dueno.mascotaId == nil)
    dueno.modo = "mundo"
    avanzar(3)
    fallar(errores, "al volver reaparece", dueno.mascotaId ~= nil and mundo.entidades[dueno.mascotaId] ~= nil)
    -- se guarda y se recupera
    local ex = mundo:exportar(dueno)
    local otro = mundo:crearPersonaje({ nombre = "Criador2", faccion = "albor", clase = "guerrero", nivel = 12 })
    mundo:aplicarGuardado(otro, ex)
    fallar(errores, "el guardado conserva las mascotas", #otro.mascotas == 2 and otro.mascotaActiva == 2)
    -- las criaturas hostiles pueden herirlas; los jugadores no
    local e = mundo.entidades[dueno.mascotaId]
    fallar(errores, "una criatura puede herir a la mascota", mundo:puedeDanar(blanco, e))
    fallar(errores, "los jugadores no pueden herirla", not mundo:puedeDanar(dueno, e))
    local hp0 = e.hp
    mundo:golpear(blanco, e, 1)
    blanco.atk = 100
    mundo:golpear(blanco, e, 1)
    fallar(errores, "la mascota pierde vida", e.hp < hp0, hp0 .. " -> " .. e.hp)
    -- si cae, se va y vuelve tras el descanso
    mundo:danar(e, 99999, blanco)
    fallar(errores, "al caer se retira", dueno.mascotaId == nil and (dueno.mascotaDescanso or 0) > mundo.tiempo)
    avanzar(5)
    fallar(errores, "no vuelve antes de tiempo", dueno.mascotaId == nil)
    dueno.mascotaDescanso = 0
    avanzar(3)
    fallar(errores, "vuelve tras descansar", dueno.mascotaId ~= nil)
    e = mundo.entidades[dueno.mascotaId]
    fallar(errores, "vuelve con la vida llena", e and e.hp == e.hpMax)
    -- guardarla
    mundo:invocarMascota(dueno, 2)
    fallar(errores, "se guarda al llamarla otra vez", dueno.mascotaId == nil and dueno.mascotaActiva == nil)
  end)
  paso("gremios", function()
    local Gremios = require("compartido.dominio.gremios")
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local function jug(nombre, dbId, faccion)
      local e = mundo:crearPersonaje({ nombre = nombre, faccion = faccion or "albor", clase = "guerrero", nivel = 10 })
      e.dbId = dbId
      e.x, e.y = 50.5, 50.5
      return e
    end
    local a, b, c, rival = jug("Lider", 101), jug("Amigo", 102), jug("Otro", 103), jug("Rival", 104, "umbra")
    a.oro = 5000
    fallar(errores, "nombre válido", Gremios.nombreValido("Los Cuervos") and Gremios.nombreValido("Ñandú Rojo") and not Gremios.nombreValido("ab") and not Gremios.nombreValido("x!y"))
    fallar(errores, "etiqueta válida", Gremios.etiquetaValida("LC") and Gremios.etiquetaValida("A1b2") and not Gremios.etiquetaValida("A") and not Gremios.etiquetaValida("ABCDE"))
    a.nivel = 3
    fallar(errores, "pide nivel", mundo:crearGremio(a, "Los Cuervos", "LC") ~= nil)
    a.nivel = 10
    fallar(errores, "pide nombre válido", mundo:crearGremio(a, "x", "LC") ~= nil)
    fallar(errores, "funda el gremio", mundo:crearGremio(a, "Los Cuervos", "lc") == nil and a.gremioRango == "lider" and a.gremioEtiqueta == "LC")
    fallar(errores, "cuesta oro", a.oro == 5000 - Gremios.COSTE)
    fallar(errores, "no se repite el nombre", mundo:crearGremio(c, "los cuervos", "XX") ~= nil)
    -- invitar y aceptar
    fallar(errores, "un miembro raso no invita", (function() b.gremioId, b.gremioRango = nil, nil return mundo:invitarGremio(b, c.id) end)() ~= nil)
    fallar(errores, "el líder invita", mundo:invitarGremio(a, b.id) == nil and b.invitacionGremio ~= nil)
    fallar(errores, "no invita a la otra corona", mundo:invitarGremio(a, rival.id) ~= nil)
    fallar(errores, "acepta y entra", mundo:responderInvitacionGremio(b, true) == nil and b.gremioId == a.gremioId and b.gremioRango == "miembro")
    fallar(errores, "no puede invitar a quien ya tiene gremio", mundo:invitarGremio(a, b.id) ~= nil)
    mundo:invitarGremio(a, c.id)
    fallar(errores, "rechazar no entra", mundo:responderInvitacionGremio(c, false) == nil and c.gremioId == nil)
    mundo:invitarGremio(a, c.id)
    mundo.tiempo = mundo.tiempo + Gremios.INVITACION_SEG + 5
    fallar(errores, "la invitación caduca", mundo:responderInvitacionGremio(c, true) ~= nil and c.gremioId == nil)
    -- rangos
    fallar(errores, "el líder ascende a oficial", mundo:cambiarRangoGremio(a, 102, true) == nil and b.gremioRango == "oficial")
    fallar(errores, "el oficial invita", mundo:invitarGremio(b, c.id) == nil)
    fallar(errores, "otro entra", mundo:responderInvitacionGremio(c, true) == nil)
    fallar(errores, "el oficial no expulsa al líder", mundo:expulsarGremio(b, 101) ~= nil)
    fallar(errores, "el oficial expulsa a un miembro", mundo:expulsarGremio(b, 103) == nil and c.gremioId == nil)
    -- chat: solo lo ve el gremio; los avisos de sistema son de cada uno
    mundo:decir(a, "/g hola gremio")
    local fa, fb, fc = mundo:foto(a.id), mundo:foto(b.id), mundo:foto(c.id)
    local function ve(f, texto) for _, m in ipairs(f.msgs) do if m.texto == texto then return true end end return false end
    fallar(errores, "el gremio ve su chat", ve(fa, "hola gremio") and ve(fb, "hola gremio"))
    fallar(errores, "los de fuera no lo ven", not ve(fc, "hola gremio"))
    mundo:mensaje("sistema", "", "secreto de c", c)
    fallar(errores, "los avisos de sistema son privados", ve(mundo:foto(c.id), "secreto de c") and not ve(mundo:foto(a.id), "secreto de c"))
    mundo:decir(c, "/g intruso")
    fallar(errores, "sin gremio no se puede hablar en el gremio", not ve(mundo:foto(a.id), "intruso"))
    -- bono de experiencia por compañeros cerca
    fallar(errores, "bono con un compañero", math.abs(mundo:bonoGremio(a) - 1.05) < 1e-6, tostring(mundo:bonoGremio(a)))
    b.x = 200
    fallar(errores, "sin compañeros cerca no hay bono", mundo:bonoGremio(a) == 1)
    b.x = 50.5
    -- la foto lleva el gremio al cliente
    fallar(errores, "la foto trae el gremio", fa.tu.gremioNombre == "Los Cuervos" and fa.tu.gremioRango == "lider")
    local info = mundo:resumenGremio(a)
    fallar(errores, "resumen del gremio", info and #info.miembros == 2 and info.miembros[1].rango == "lider")
    -- si se va el líder, manda el oficial
    fallar(errores, "el líder se va", mundo:salirGremio(a) == nil and a.gremioId == nil)
    fallar(errores, "el oficial queda de líder", b.gremioRango == "lider")
    -- disolver
    fallar(errores, "solo el líder disuelve", mundo:disolverGremio(a) ~= nil)
    fallar(errores, "el líder disuelve", mundo:disolverGremio(b) == nil and b.gremioId == nil and next(mundo.gremios) == nil)
    -- el almacén (PostgreSQL o archivo) guarda y devuelve los gremios
    local usuario = "gr" .. string.format("%06d", os.time() % 1000000)
    Cuentas.borrarUsuario(usuario)
    local idCuenta = Cuentas.registrar(usuario, "clave12")
    local p1 = idCuenta and Cuentas.crearPersonaje(idCuenta, "GrUno" .. string.format("%03d", os.time() % 1000), "albor", "guerrero")
    local p2 = idCuenta and Cuentas.crearPersonaje(idCuenta, "GrDos" .. string.format("%03d", os.time() % 1000), "albor", "mago")
    fallar(errores, "personajes de prueba", p1 ~= nil and p2 ~= nil)
    if p1 and p2 then
      local idG = 900000 + os.time() % 90000
      local g = { id = idG, nombre = "Prueba " .. idG, etiqueta = "T" .. (idG % 1000), faccion = "albor",
        miembros = { [p1] = { nombre = "GrUno", rango = "lider" }, [p2] = { nombre = "GrDos", rango = "oficial" } } }
      local ok, err = Cuentas.guardarGremio(g)
      fallar(errores, "guarda el gremio", ok, tostring(err))
      local lista = Cuentas.cargarGremios() or {}
      local hallado
      for _, x in ipairs(lista) do if x.id == idG then hallado = x end end
      fallar(errores, "lo vuelve a cargar con sus miembros", hallado and #hallado.miembros == 2 and hallado.etiqueta == g.etiqueta, tostring(hallado))
      local m = Mundo.nuevo()
      m:cargarGremios(lista)
      fallar(errores, "el mundo recupera el gremio y su índice", m.gremios[idG] and m.gremioDe[p1] == idG and m.siguienteGremio > idG)
      g.miembros[p2].rango = "miembro"
      Cuentas.guardarGremio(g)
      local otra = Cuentas.cargarGremios() or {}
      local rango
      for _, x in ipairs(otra) do if x.id == idG then for _, mm in ipairs(x.miembros) do if mm.id == p2 then rango = mm.rango end end end end
      fallar(errores, "los cambios de rango se guardan", rango == "miembro", tostring(rango))
      Cuentas.borrarGremio(idG)
      local final = Cuentas.cargarGremios() or {}
      local sigue = false
      for _, x in ipairs(final) do if x.id == idG then sigue = true end end
      fallar(errores, "borrar el gremio lo quita", not sigue)
    end
    Cuentas.borrarUsuario(usuario)
  end)
  paso("equilibrio de combate por nivel", function()
    local Calibracion = require("src.pruebas.calibracion")
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    for _, clase in ipairs({ "guerrero", "mago", "cazador", "clerigo" }) do
      local igual = Calibracion.duelo(mundo, clase, 10, Calibracion.monstruoDeNivel(10))
      fallar(errores, clase .. " gana a una criatura de su nivel", igual.gano)
      fallar(errores, clase .. " no la mata al instante ni tarda una eternidad", igual.t > 5 and igual.t < 60, string.format("%.1f s", igual.t))
      fallar(errores, clase .. " sufre algo contra su nivel", igual.perdida > 0.03, string.format("%.0f%%", igual.perdida * 100))
      local alta = Calibracion.duelo(mundo, clase, 8, Calibracion.monstruoDeNivel(21))
      fallar(errores, clase .. " nivel 8 no puede con una criatura de nivel 21", not alta.gano)
    end
  end)
  paso("estados alterados y poderes de criaturas", function()
    local Estados = require("compartido.dominio.estados")
    local Arbol = require("compartido.dominio.arbol")
    local mundo = Mundo.nuevo()
    local function avanzar(seg) for _ = 1, math.floor(seg / 0.1) do mundo:actualizar(0.1) end end
    local mago = mundo:crearPersonaje({ nombre = "Estado1", faccion = "albor", clase = "mago", nivel = 10 })
    local victima = mundo:spawnMonstruo("oso", mago.x + 2, mago.y, { x = mago.x, y = mago.y })
    victima.hp, victima.hpMax = 5000, 5000
    victima.agresivo, victima.def, victima.mdef = false, 0, 0
    victima.atk, victima.matk = 0, 0 -- que no pegue de vuelta: aquí solo se miden los estados
    victima.golpe, victima.poderes = nil, nil
    victima.cds.auto = 1e9
    victima.x, victima.y = mago.x + 3, mago.y
    -- daño por tics
    local antes = victima.hp
    fallar(errores, "quemar se aplica", mundo:aplicarEstado(victima, "quemar", 3, nil, mago))
    avanzar(3.5)
    fallar(errores, "quemar hace daño con el tiempo", victima.hp < antes - 3, tostring(antes - victima.hp))
    fallar(errores, "el estado termina", victima.estados == nil or victima.estados.quemar == nil)
    -- el veneno ignora la defensa; el sangrado no
    victima.def = 500
    local a = victima.hp
    mundo:aplicarEstado(victima, "veneno", 2, nil, mago)
    avanzar(2.5)
    local venenoDano = a - victima.hp
    a = victima.hp
    mundo:aplicarEstado(victima, "sangrar", 2, nil, mago)
    avanzar(2.5)
    fallar(errores, "el veneno traspasa la defensa", venenoDano > (a - victima.hp), venenoDano .. " vs " .. (a - victima.hp))
    victima.def = 0
    -- drenar vida cura a quien lo aplica
    mago.hp = mago.hpMax - 50
    local h0 = mago.hp
    mundo:aplicarEstado(victima, "drenar_vida", 3, nil, mago)
    avanzar(3.5)
    fallar(errores, "drenar vida cura al que drena", mago.hp > h0, h0 .. " -> " .. mago.hp)
    -- drenar maná: pasa del objetivo a la fuente
    local alvo = mundo:crearPersonaje({ nombre = "Estado2", faccion = "umbra", clase = "mago" })
    alvo.x, alvo.y = mago.x + 1, mago.y
    local m0 = alvo.mp
    mundo:aplicarEstado(alvo, "drenar_mana", 3, nil, victima)
    avanzar(3.5)
    fallar(errores, "drenar maná quita maná", alvo.mp < m0 - 5 or alvo.mp < alvo.mpMax - 5, m0 .. " -> " .. alvo.mp)
    fallar(errores, "los monstruos no tienen maná que drenar", mundo:aplicarEstado(victima, "drenar_mana", 3, nil, mago) == false)
    -- lentitud y aturdimiento (el elite aguanta mejor)
    mundo:aplicarEstado(victima, "lentitud", 3, 0.5, mago)
    fallar(errores, "lentitud frena", victima.lentitud and victima.lentitud.mul == 0.5)
    victima.aturdido = 0
    mundo:aplicarEstado(victima, "aturdir", 1, nil, mago)
    fallar(errores, "aturdir inmoviliza", victima.aturdido >= 1)
    local elite = mundo:spawnMonstruo("behemot", mago.x + 8, mago.y, { x = mago.x, y = mago.y })
    mundo:aplicarEstado(elite, "aturdir", 1, nil, mago)
    fallar(errores, "el elite resiste el aturdimiento", elite.aturdido < 0.6, tostring(elite.aturdido))
    -- morir limpia los estados
    mundo:morir(victima, mago)
    fallar(errores, "al morir se limpian", victima.estados == nil and victima.lentitud == nil)
    -- snapshot: la lista visible llega a los clientes
    local viva = mundo:spawnMonstruo("gato", mago.x + 4, mago.y, { x = mago.x, y = mago.y })
    mundo:aplicarEstado(viva, "sangrar", 3, nil, mago)
    fallar(errores, "los estados visibles viajan en la foto", mundo:compactar(viva).est[1] == "sangrar")
    local foto = mundo:foto(mago.id)
    fallar(errores, "el jugador recibe sus estados", foto.tu.estadosResta ~= nil)
    -- el poder de un mago puede aplicar estado con su rango
    mago.habilidades = { misil = 1, fuego = 3 }
    local ef = Arbol.efectiva("fuego", 3).estado
    fallar(errores, "fuego quema", ef and ef.tipo == "quemar")
    fallar(errores, "más rango, más probabilidad", ef.prob > Arbol.efectiva("fuego", 1).estado.prob)
    local azarOriginal = math.random
    math.random = function(a) if a then return 1 end return 0 end
    local blanco = mundo:spawnMonstruo("gato", mago.x + 3, mago.y, { x = mago.x, y = mago.y })
    blanco.hp, blanco.hpMax, blanco.agresivo = 9999, 9999, false
    mago.objetivo = blanco.id
    mago.mp, mago.cds = mago.mpMax, {}
    mago.aturdido, mago.estados = 0, nil
    local ok, err = pcall(function()
      local e = mundo:usarHabilidad(mago, 2)
      avanzar(1.5)
      return e
    end)
    math.random = azarOriginal
    if not ok then fallar(errores, "usar bola de fuego", false, tostring(err)) err = nil end
    fallar(errores, "bola de fuego deja quemado al objetivo", err == nil and blanco.estados and blanco.estados.quemar ~= nil, tostring(err))
    -- efectos de las criaturas: golpe y poderes
    local rata = mundo:spawnMonstruo("rata", mago.x - 3, mago.y, { x = mago.x, y = mago.y })
    rata.golpe = { { tipo = "veneno", prob = 1 } }
    mago.estados = nil
    mundo:alGolpear(rata, mago)
    fallar(errores, "el golpe de la rata envenena", mago.estados and mago.estados.veneno ~= nil)
    local espectro = mundo:spawnMonstruo("espectro", mago.x - 4, mago.y, { x = mago.x, y = mago.y })
    espectro.cds.drenaje = 0
    mago.estados = nil
    mundo:poderesMonstruo(espectro, mago, 4)
    fallar(errores, "el espectro drena maná", mago.estados and mago.estados.drenar_mana ~= nil)
    -- cada criatura trae lo suyo y todo lo que nombra existe
    local combos, conEfectos = {}, 0
    for _, m in ipairs(Datos.monstruos) do
      local clave = {}
      for _, g in ipairs(m.golpe or {}) do
        fallar(errores, m.id .. " golpe conocido " .. g.tipo, Estados.def[g.tipo] ~= nil)
        clave[#clave + 1] = g.tipo
      end
      for _, p in ipairs(m.poderes or {}) do
        fallar(errores, m.id .. " poder conocido " .. p, Estados.poderes[p] ~= nil)
        clave[#clave + 1] = "P" .. p
      end
      if #clave > 0 then conEfectos = conEfectos + 1 end
      combos[table.concat(clave, "+")] = true
    end
    local distintos = 0
    for _ in pairs(combos) do distintos = distintos + 1 end
    fallar(errores, "casi todas las criaturas tienen efectos (" .. conEfectos .. ")", conEfectos >= #Datos.monstruos - 2)
    fallar(errores, "no todas tienen lo mismo (" .. distintos .. " combinaciones)", distintos >= 14)
  end)
  paso("la mochila decide los espacios de la bolsa", function()
    local mundo = Mundo.nuevo()
    local e = mundo:crearPersonaje({ nombre = "Mochi", faccion = "albor", clase = "guerrero", nivel = 15 })
    e.bolsa = {}
    fallar(errores, "sin mochila hay " .. Datos.BOLSA_BASE, Datos.capacidadBolsa(e.equipo) == Datos.BOLSA_BASE)
    for _ = 1, Datos.BOLSA_BASE do mundo:darItem(e, "guerrero_arma_2", 1) end
    fallar(errores, "la bolsa básica se llena", not mundo:darItem(e, "guerrero_arma_2", 1) and #e.bolsa == Datos.BOLSA_BASE)
    e.bolsa[#e.bolsa] = { id = "mochila_3", cant = 1 } -- la mochila ocupa el último espacio
    local err = mundo:equipar(e, #e.bolsa)
    fallar(errores, "se pone la mochila", err == nil and e.equipo.mochila == "mochila_3", tostring(err))
    fallar(errores, "ahora caben 20", Datos.capacidadBolsa(e.equipo) == 20)
    for _ = 1, 13 do mundo:darItem(e, "guerrero_arma_2", 1) end
    fallar(errores, "llena hasta 20", #e.bolsa == 20, tostring(#e.bolsa))
    fallar(errores, "no se la quita con la bolsa llena", mundo:desequipar(e, "mochila") ~= nil and e.equipo.mochila == "mochila_3")
    -- un guardado antiguo con 15 objetos y sin mochila recibe una que los aguante
    local viejo = mundo:crearPersonaje({ nombre = "Viejo", faccion = "albor", clase = "guerrero" })
    local lleno = {}
    for i = 1, 15 do lleno[i] = { id = "pocion_vida", cant = 1 } end
    mundo:aplicarGuardado(viejo, { clase = "guerrero", nivel = 1, equipo = {}, bolsa = lleno })
    fallar(errores, "el guardado antiguo recibe mochila", Datos.capacidadBolsa(viejo.equipo) >= 15 and viejo.equipo.mochila ~= nil)
  end)
  paso("ataque y defensa mágicos", function()
    local Balance = require("compartido.dominio.balance")
    local mundo = Mundo.nuevo()
    local function nuevo(clase, nivel)
      local e = mundo:crearPersonaje({ nombre = "T" .. clase, faccion = "albor", clase = clase, nivel = nivel or 1 })
      for hueco in pairs(e.equipo) do e.equipo[hueco] = nil end
      mundo:recalcular(e)
      return e
    end
    local g, m, c, k = nuevo("guerrero", 10), nuevo("mago", 10), nuevo("clerigo", 10), nuevo("cazador", 10)
    for _, e in ipairs({ g, m, c, k }) do
      fallar(errores, e.clase .. " tiene los cuatro atributos", e.atk and e.matk and e.def and e.mdef)
      Log.info(string.format("balance nv10 %-8s vida %3d  atq %5.1f  mag %5.1f  def %5.1f  res %5.1f",
        e.clase, e.hpMax, e.atk, e.matk, e.def, e.mdef))
    end
    -- el mago es el daño mágico; el clérigo, menos; guerrero y cazador, casi nada
    fallar(errores, "mago pega más fuerte con magia que el clérigo", m.matk > c.matk, m.matk .. " vs " .. c.matk)
    fallar(errores, "el clérigo pega más con magia que guerrero y cazador", c.matk > g.matk and c.matk > k.matk)
    fallar(errores, "el clérigo es bastante más flojo que el mago", c.matk <= m.matk * 0.75, c.matk .. " vs " .. m.matk)
    -- y al revés con el daño físico
    fallar(errores, "guerrero y cazador pegan más fuerte físico que mago y clérigo",
      g.atk > m.atk * 2 and g.atk > c.atk * 2 and k.atk > m.atk * 2 and k.atk > c.atk * 2)
    -- defensas
    fallar(errores, "el mago tiene poca defensa física y más defensa mágica", m.def < g.def and m.mdef > m.def)
    fallar(errores, "el guerrero resiste mejor lo físico que lo mágico", g.def > g.mdef)
    fallar(errores, "el guerrero aguanta más físico que el mago", g.def > m.def and g.def > c.def)
    fallar(errores, "mago y clérigo resisten magia mejor que el guerrero", m.mdef > g.mdef and c.mdef > g.mdef)
    -- DPS del ataque básico y del primer poder: el mago supera al clérigo
    local function dps(e, idPoder)
      local h = Datos.habilidades[idPoder]
      local atk = (h.dano == "magico") and e.matk or e.atk
      local mn, mx = Balance.rangoDano(atk, 0, h.coef)
      return ((mn + mx) / 2) / h.cd
    end
    Log.info(string.format("balance DPS nv10: guerrero golpe %.1f | cazador disparo %.1f | mago misil %.1f | clerigo castigo %.1f",
      dps(g, "golpe"), dps(k, "disparo"), dps(m, "misil"), dps(c, "castigo")))
    fallar(errores, "el DPS del mago supera al del clérigo", dps(m, "misil") > dps(c, "castigo") * 1.2,
      string.format("%.1f vs %.1f", dps(m, "misil"), dps(c, "castigo")))
    -- el tipo de daño elige qué se compara
    local blanco = mundo:spawnMonstruo("gato", m.x + 1, m.y, { x = m.x, y = m.y })
    blanco.hp, blanco.hpMax = 1e9, 1e9
    blanco.def, blanco.mdef = 0, 200
    local function media(origen, tipo)
      local suma = 0
      for _ = 1, 200 do
        local antes = blanco.hp
        mundo:golpear(origen, blanco, 1, nil, tipo)
        suma = suma + (antes - blanco.hp)
      end
      return suma / 200
    end
    local fisico, magico = media(g, "fisico"), media(g, "magico")
    fallar(errores, "con mdef alta, un golpe mágico pega mucho menos que uno físico", magico < fisico * 0.3, fisico .. " vs " .. magico)
    blanco.def, blanco.mdef = 200, 0
    local magico2 = media(m, "magico")
    local fisico2 = media(m, "fisico")
    fallar(errores, "con def alta, la magia atraviesa y lo físico no", magico2 > fisico2 * 3, magico2 .. " vs " .. fisico2)
    -- el ataque básico sigue al oficio
    fallar(errores, "el básico del mago es mágico y el del guerrero físico",
      mundo:tipoDanoBasico(m) == "magico" and mundo:tipoDanoBasico(g) == "fisico" and mundo:tipoDanoBasico(c) == "magico")
    -- monstruos: físicos y mágicos con su perfil
    local fis = mundo:spawnMonstruo("troll", m.x + 2, m.y, { x = m.x, y = m.y })
    local mag = mundo:spawnMonstruo("liche", m.x + 3, m.y, { x = m.x, y = m.y })
    fallar(errores, "un monstruo físico pega con atk y se defiende con def", fis.tipoDano == "fisico" and fis.atk > fis.matk and fis.def > fis.mdef)
    fallar(errores, "un monstruo mágico pega con matk y resiste con mdef", mag.tipoDano == "magico" and mag.matk > mag.atk and mag.mdef > mag.def)
    -- el equipo de oficios mágicos sube lo mágico
    local arma = Datos.item("mago_arma_2")
    local espada = Datos.item("guerrero_arma_2")
    fallar(errores, "el bastón da ataque mágico y la espada físico", arma.matk and arma.matk > (arma.atk or 0) and espada.atk > (espada.matk or 0))
    fallar(errores, "el peto del mago protege más de la magia que el del guerrero", Datos.item("mago_pecho_2").mdef > Datos.item("guerrero_pecho_2").mdef)
    mundo:darItem(m, "mago_arma_2", 1)
    m.nivel = 10
    local antes = m.matk
    mundo:accion(m.id, "equipar", { i = #m.bolsa })
    fallar(errores, "equipar un bastón sube el ataque mágico", m.matk > antes, antes .. " -> " .. m.matk)
  end)
  paso("volver a entrar conserva el progreso", function()
    local Servicio = require("src.aplicacion.servicio_servidor")
    local mundo = Servicio.crearMundo()
    local usuario = "qr" .. string.format("%06d", os.time() % 1000000)
    Cuentas.borrarUsuario(usuario)
    local id, token = Cuentas.registrar(usuario, "clave12")
    local pid = id and Cuentas.crearPersonaje(id, "Vuelve" .. string.format("%03d", os.time() % 1000), "albor", "guerrero")
    fallar(errores, "cuenta de prueba", pid ~= nil)
    if pid then
      local function transporte(eventos)
        local t = { vinculo = {}, tasa = {}, clientes = {}, enviados = {} }
        function t:actualizar() local e = eventos eventos = {} return e end
        function t:enviar(_, msg) self.enviados[#self.enviados + 1] = msg end
        function t:puedeEnviar() return true end
        return t
      end
      local t1 = transporte({})
      Servicio.tratar(t1, mundo, 5, { t = "hola", token = token, personaje = pid })
      local pj = t1.vinculo[5] and mundo.entidades[t1.vinculo[5]]
      fallar(errores, "entra la primera vez", pj ~= nil)
      if pj then
        pj.nivel, pj.xp, pj.oro = 4, 55, 321
        mundo:recalcular(pj)
        pj.x, pj.y = 210.5, 236.5
        mundo:darItem(pj, "guerrero_arma_2", 1)
        pj.encantos = { arma = 4 }
        pj.mascotas = { { especie = "murcielago", nivel = 3, xp = 11 }, { especie = "gatito", nivel = 2, xp = 5 } }
        pj.mascotaActiva = 2
        pj.habilidades.vigor = 2
        pj.habilidades.golpe = 2
        pj.equipo.mochila = "mochila_2"
        mundo:aceptarMision(pj, "q_auroria")
        pj.misiones.q_auroria.progreso = 3
        pj.caceria = { gato = 5 }
        pj.casas = { ["9_9"] = { muebles = { cama = true }, cofre = { { id = "pocion_vida", cant = 2 } } } }
        local salida = transporte({ { tipo = "cierra", id = 5 } })
        salida.vinculo[5] = pj.id
        Servicio.actualizar({ mundo = mundo, servidor = salida, config = { guardado_segundos = 99999 } }, 0.05)
        mundo:actualizar(0.05)
        local t2 = transporte({})
        Servicio.tratar(t2, mundo, 6, { t = "hola", token = token, personaje = pid })
        local otra = t2.vinculo[6] and mundo.entidades[t2.vinculo[6]]
        fallar(errores, "entra la segunda vez", otra ~= nil)
        if otra then
          fallar(errores, "recupera el nivel", otra.nivel == 4, tostring(otra.nivel))
          fallar(errores, "recupera la experiencia", otra.xp == 55, tostring(otra.xp))
          fallar(errores, "recupera el oro", otra.oro == 321, tostring(otra.oro))
          fallar(errores, "recupera la posición", math.abs(otra.x - 210.5) < 0.1 and math.abs(otra.y - 236.5) < 0.1, otra.x .. "," .. otra.y)
          local tiene = false
          for _, s in ipairs(otra.bolsa) do if s.id == "guerrero_arma_2" then tiene = true end end
          fallar(errores, "recupera la bolsa", tiene)
          fallar(errores, "recupera la mochila puesta", otra.equipo.mochila == "mochila_2", tostring(otra.equipo.mochila))
          fallar(errores, "recupera el progreso de la misión",
            otra.misiones.q_auroria and otra.misiones.q_auroria.progreso == 3 and otra.misiones.q_auroria.aceptada
              and otra.misiones.q_auroria.cantidad == 6)
          fallar(errores, "recupera la cacería", otra.caceria.gato == 5)
          fallar(errores, "recupera las mascotas", otra.mascotas and #otra.mascotas == 2 and otra.mascotas[1].especie == "murcielago"
            and otra.mascotas[1].nivel == 3 and otra.mascotas[2].xp == 5 and otra.mascotaActiva == 2)
          fallar(errores, "recupera el encantamiento del arma", otra.encantos and otra.encantos.arma == 4,
            tostring(otra.encantos and otra.encantos.arma))
          fallar(errores, "recupera el árbol de poderes", otra.habilidades and otra.habilidades.vigor == 2
            and otra.habilidades.golpe == 2, tostring(otra.habilidades and otra.habilidades.vigor))
          local casa = otra.casas["9_9"]
          fallar(errores, "recupera la casa con muebles y cofre",
            casa and casa.muebles.cama and casa.cofre[1] and casa.cofre[1].id == "pocion_vida" and casa.cofre[1].cant == 2)
          otra.borrar = true
        end
      end
    end
    Cuentas.borrarUsuario(usuario)
  end)
  paso("los hechos importantes se guardan en segundos", function()
    local Servicio = require("src.aplicacion.servicio_servidor")
    local mundo = Servicio.crearMundo()
    local usuario = "qi" .. string.format("%06d", os.time() % 1000000)
    Cuentas.borrarUsuario(usuario)
    local id, token = Cuentas.registrar(usuario, "clave12")
    local pid = id and Cuentas.crearPersonaje(id, "Hecho" .. string.format("%03d", os.time() % 1000), "umbra", "cazador")
    fallar(errores, "cuenta de prueba", pid ~= nil)
    if pid then
      local t = { vinculo = {}, tasa = {}, clientes = {}, enviados = {} }
      function t:actualizar() return {} end
      function t:enviar(_, msg) self.enviados[#self.enviados + 1] = msg end
      function t:puedeEnviar() return true end
      Servicio.tratar(t, mundo, 5, { t = "hola", token = token, personaje = pid })
      local pj = t.vinculo[5] and mundo.entidades[t.vinculo[5]]
      fallar(errores, "entra", pj ~= nil)
      if pj then
        local cfg = { guardado_segundos = 99999, reintento_segundos = 5 }
        mundo:ganarXp(pj, 100000)
        local nivelNuevo = pj.nivel
        fallar(errores, "sube de nivel", nivelNuevo > 1, tostring(nivelNuevo))
        Servicio.actualizar({ mundo = mundo, servidor = t, config = cfg }, 1)
        local antes = Cuentas.cargar(pid)
        fallar(errores, "no se guarda al instante, sino en la ronda", antes and antes.nivel == 1, antes and tostring(antes.nivel))
        Servicio.actualizar({ mundo = mundo, servidor = t, config = cfg }, 5)
        local despues = Cuentas.cargar(pid)
        fallar(errores, "tras la ronda el nivel ya está guardado", despues and despues.nivel == nivelNuevo, despues and tostring(despues.nivel))
        pj.oro = pj.oro + 100
        mundo:darItem(pj, "cazador_arma_2", 1)
        mundo:equipar(pj, #pj.bolsa)
        Servicio.actualizar({ mundo = mundo, servidor = t, config = cfg }, 6)
        local equipo = Cuentas.cargar(pid)
        fallar(errores, "equipar se guarda", equipo and equipo.equipo and equipo.equipo.arma == "cazador_arma_2")
        pj.borrar = true
      end
    end
    Cuentas.borrarUsuario(usuario)
  end)
  paso("guardado automatico", function()
    local Servicio = require("src.aplicacion.servicio_servidor")
    local mundo = Servicio.crearMundo()
    local usuario = "qg" .. string.format("%06d", os.time() % 1000000)
    Cuentas.borrarUsuario(usuario)
    local id, token = Cuentas.registrar(usuario, "clave12")
    local sufijo = string.format("%03d", os.time() % 1000)
    local pid1 = id and Cuentas.crearPersonaje(id, "Guarda" .. sufijo, "albor", "guerrero")
    local pid2 = id and Cuentas.crearPersonaje(id, "Cierra" .. sufijo, "umbra", "mago")
    fallar(errores, "cuenta y personajes de prueba", pid1 ~= nil and pid2 ~= nil)
    if pid1 and pid2 then
      local function transporte(eventos)
        local t = { vinculo = {}, tasa = {}, clientes = {}, enviados = {} }
        function t:actualizar()
          local e = eventos
          eventos = {}
          return e
        end
        function t:enviar(_, msg) self.enviados[#self.enviados + 1] = msg end
        function t:puedeEnviar() return true end
        return t
      end
      -- Un jugador que se desconecta se guarda al instante, sin esperar al guardado general.
      local t1 = transporte({})
      Servicio.tratar(t1, mundo, 5, { t = "hola", token = token, personaje = pid1 })
      local pj1 = t1.vinculo[5] and mundo.entidades[t1.vinculo[5]]
      fallar(errores, "el primer jugador entra", pj1 ~= nil)
      if pj1 then
        pj1.oro, pj1.nivel = 777, 3
        local desconecta = transporte({ { tipo = "cierra", id = 5 } })
        desconecta.vinculo[5] = pj1.id
        Servicio.actualizar({ mundo = mundo, servidor = desconecta, config = { guardado_segundos = 99999 } }, 0.05)
        local datos = Cuentas.cargar(pid1)
        fallar(errores, "al desconectarse se guarda su oro", datos and datos.oro == 777, datos and tostring(datos.oro))
        fallar(errores, "al desconectarse se guarda su nivel", datos and datos.nivel == 3, datos and tostring(datos.nivel))
        fallar(errores, "al desconectarse sale del mundo", pj1.borrar == true)
      end
      -- El guardado general recoge a todos los conectados cuando toca.
      local t2 = transporte({})
      Servicio.tratar(t2, mundo, 6, { t = "hola", token = token, personaje = pid2 })
      local pj2 = t2.vinculo[6] and mundo.entidades[t2.vinculo[6]]
      fallar(errores, "el segundo jugador entra", pj2 ~= nil)
      if pj2 then
        pj2.oro = 555
        local cfg = { guardado_segundos = 600 }
        Servicio.actualizar({ mundo = mundo, servidor = t2, config = cfg }, 1)
        local antes = Cuentas.cargar(pid2)
        fallar(errores, "antes de tiempo no hay guardado general", antes and antes.oro ~= 555, antes and tostring(antes.oro))
        Servicio.actualizar({ mundo = mundo, servidor = t2, config = cfg }, 600)
        local despues = Cuentas.cargar(pid2)
        fallar(errores, "a los 10 min se guarda a todos", despues and despues.oro == 555, despues and tostring(despues.oro))
        pj2.borrar = true
      end
    end
    fallar(errores, "el guardado general es de varios minutos o más", Config.servidor.guardado_segundos >= 5)
    Cuentas.borrarUsuario(usuario)
  end)
  paso("config .env", function()
    local Env = require("compartido.infraestructura.env")
    local v = Env.parsear('# comentario\nA=1\n  B = dos palabras  # nota\nexport C="con # almohadilla"\nD=\'simple\'\n\nVACIA=\n')
    fallar(errores, "env: valor simple", v.A == "1")
    fallar(errores, "env: espacios y comentario final", v.B == "dos palabras", tostring(v.B))
    fallar(errores, "env: comillas y export", v.C == "con # almohadilla", tostring(v.C))
    fallar(errores, "env: comillas simples", v.D == "simple")
    fallar(errores, "env: vacía", v.VACIA == "")
    fallar(errores, "env: ignora comentarios", v["# comentario"] == nil)
    fallar(errores, "config: puerto válido", type(Config.red.puerto) == "number" and Config.red.puerto > 0)
    fallar(errores, "config: almacén válido", Config.almacen == "auto" or Config.almacen == "postgres" or Config.almacen == "archivo")
    fallar(errores, "config: tasa", Config.servidor.tasa_mensajes >= 5 and Config.servidor.fotos_por_segundo >= 2)
  end)
  paso("arquitectura", function()
    -- El dominio no debe conocer a LÖVE ni a las capas de fuera.
    local function leer(ruta)
      local f = io.open(ruta, "rb")
      if not f then return nil end
      local t = f:read("*a")
      f:close()
      return t
    end
    local base = Log.carpeta() .. "/../compartido/dominio/"
    for _, nombre in ipairs({ "mundo", "mapa", "datos", "balance", "util" }) do
      local t = leer(base .. nombre .. ".lua")
      fallar(errores, "dominio/" .. nombre .. " existe", t ~= nil)
      if t then
        fallar(errores, "dominio/" .. nombre .. " sin love", not t:find("love%.%a"))
        fallar(errores, "dominio/" .. nombre .. " sin capas externas",
          not t:find('require%("src%.'))
      end
    end
    local autoridad = leer(Log.carpeta() .. "/src/dominio/autoridad.lua")
    fallar(errores, "autoridad existe y no usa love", autoridad ~= nil and not autoridad:find("love%.%a"))
    local Puertos = require("src.aplicacion.puertos")
    local almacen = Puertos.almacen()
    for _, m in ipairs(Puertos.CONTRATO.almacen) do
      fallar(errores, "almacén implementa " .. m, type(almacen[m]) == "function")
    end
  end)
  paso("movimiento", function()
    local mundo = Mundo.nuevo()
    local c
    for _, ci in ipairs(mundo.mapas.mundo.ciudades) do if ci.id == "auroria" then c = ci end end
    local cx, cy = c.x + math.floor(c.w / 2), c.y + math.floor(c.h / 2)
    local j = mundo:crearPersonaje({ nombre = "Paso", faccion = "albor", clase = "guerrero" })
    local function poner(x, y)
      j.x, j.y, j.tramo, j.camino, j.persigue, j.objetivo = x + 0.5, y + 0.5, nil, nil, false, nil
      j.deseoX, j.deseoY = 0, 0
    end
    local function correr(seg) for _ = 1, math.floor(seg / 0.05) do mundo:actualizar(0.05) end end
    poner(cx - 6, cy + 2)
    j.deseoX = 1
    correr(1.5)
    fallar(errores, "avanza varias casillas", j.x > cx - 6 + 0.5 + 4, tostring(j.x))
    j.deseoX = 0
    correr(0.5)
    fallar(errores, "queda centrado en la casilla", math.abs((j.x % 1) - 0.5) < 0.001 and math.abs(j.y - (cy + 2.5)) < 0.001, tostring(j.x) .. "," .. tostring(j.y))
    poner(cx - 6, cy + 2)
    local t0 = j.x
    j.deseoX, j.deseoY = 1, 1
    correr(1.0)
    local dx, dy = j.x - t0, j.y - (cy + 2.5)
    fallar(errores, "diagonal avanza igual en x e y", math.abs(dx - dy) < 0.01 and dx > 2, dx .. "," .. dy)
    poner(cx - 6, cy + 2)
    local otro = mundo:crearPersonaje({ kind = "bot", nombre = "Estorbo", faccion = "albor", clase = "guerrero" })
    otro.x, otro.y = cx - 5 + 0.5, cy + 2 + 0.5
    j.deseoX = 1
    correr(1.0)
    fallar(errores, "no atraviesa a otra criatura", math.floor(j.x) == cx - 6, tostring(j.x))
    mundo.entidades[otro.id] = nil
    poner(cx - 6, cy + 2)
    mundo:accion(j.id, "destino", { x = cx + 5.5, y = cy + 2.5 })
    correr(4)
    fallar(errores, "clic para mover llega", math.floor(j.x) == cx + 5 and math.floor(j.y) == cy + 2, tostring(j.x) .. "," .. tostring(j.y))
    poner(cx - 6, cy + 2)
    local gato = mundo:spawnMonstruo("gato", cx - 2.5, cy + 2.5, { x = cx - 2.5, y = cy + 2.5 })
    gato.agresivo = true
    correr(5)
    local gx, gy = mundo:casilla(gato)
    local jx, jy = mundo:casilla(j)
    fallar(errores, "monstruo llega pero no entra en tu casilla",
      not (gx == jx and gy == jy) and math.max(math.abs(gx - jx), math.abs(gy - jy)) <= 2, gx .. "," .. gy .. " vs " .. jx .. "," .. jy)
    mundo:danar(gato, 99999, j)
    poner(cx - 6, cy + 2)
    local presa = mundo:spawnMonstruo("gato", cx - 1.5, cy + 2.5, { x = cx - 1.5, y = cy + 2.5 })
    j.objetivo, j.persigue = presa.id, true
    local mato = false
    for _ = 1, 400 do
      mundo:actualizar(0.05)
      if not presa.vivo then mato = true break end
    end
    fallar(errores, "persigue y mata al objetivo", mato)
    local n = 0
    for _ in pairs(mundo.entidades) do n = n + 1 end
    local t0 = love.timer.getTime()
    for _ = 1, 100 do mundo:actualizar(0.05) end
    local ms = (love.timer.getTime() - t0) * 1000 / 100
    Log.info(string.format("servidor: %d entes, %.2f ms por tick", n, ms))
    -- tamaño real de lo que se manda a cada jugador (ciudad y campo abierto)
    local lugares = { { "ciudad", j.x, j.y } }
    for _, camp in ipairs(mundo.mapas.mundo.campamentos) do
      if camp.cantidad >= 2 then lugares[#lugares + 1] = { "campamento", camp.x, camp.y } break end
    end
    for _, l in ipairs(lugares) do
      j.x, j.y = l[2], l[3]
      local bytes = #Util.jsonEnc({ t = "snap", snap = mundo:foto(j.id) })
      Log.info(string.format("tamano foto %s: %d bytes", l[1], bytes))
    end
    fallar(errores, "el mundo cabe en un tick de 50 ms", ms < 20, string.format("%.1f ms con %d entes", ms, n))
  end)
  paso("red y paneles", function()
    local Servidor = require("src.aplicacion.servicio_servidor")
    local mundo = Mundo.nuevo()
    local usuario = "qp" .. string.format("%06d", os.time() % 1000000)
    Cuentas.borrarUsuario(usuario)
    local id, token = Cuentas.registrar(usuario, "clave12")
    local pid = id and Cuentas.crearPersonaje(id, "Panel" .. string.format("%03d", os.time() % 1000), "albor", "mago")
    fallar(errores, "cuenta de prueba", pid ~= nil)
    if pid then
      local srv = { vinculo = {}, enviados = {} }
      function srv:enviar(_, msg) self.enviados[#self.enviados + 1] = msg end
      Servidor.tratar(srv, mundo, 5, { t = "hola", token = token, personaje = pid })
      local pj = srv.vinculo[5] and mundo.entidades[srv.vinculo[5]]
      fallar(errores, "entra al mundo", pj ~= nil)
      if pj then
        local merc
        for _, e in pairs(mundo.entidades) do
          if e.kind == "npc" and e.rol == "mercado" and e.faccion == pj.faccion then merc = e break end
        end
        pj.x, pj.y = merc.x + 1, merc.y
        Servidor.tratar(srv, mundo, 5, { t = "act", a = "interactuar", p = {} })
        local ult = srv.enviados[#srv.enviados]
        fallar(errores, "el servidor manda el panel del mercader", ult and ult.t == "panel" and ult.panel == "mercado", ult and tostring(ult.panel))
        local snap = Util.jsonDec(Util.jsonEnc(mundo:foto(pj.id)))
        local cli = Mundo.nuevo()
        cli:aplicarFoto(snap, pj.id)
        fallar(errores, "el cliente recibe la foto", cli.entidades[pj.id] ~= nil and cli.entidades[pj.id].nombre == pj.nombre)
        fallar(errores, "resumen de guerra por red", type(cli:resumenEvento("batalla").cola) == "table")
        pj.borrar = true
      end
    end
    Cuentas.borrarUsuario(usuario)
  end)
  local texto = (#errores == 0) and "OK\n" or ("FALLOS " .. #errores .. "\n" .. table.concat(errores, "\n"))
  Log.volcar("prueba_resultado.txt", texto)
  print(texto)
  if #errores > 0 then Log.error("pruebas: " .. #errores .. " fallos") else Log.info("pruebas OK") end
  love.event.quit(#errores == 0 and 0 or 1)
end

return Pruebas
