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
    local silvestres = 0
    for _, m in ipairs(Datos.monstruos) do if not m.noCampamento then silvestres = silvestres + 1 end end
    fallar(errores, "30 monstruos", silvestres == 30, tostring(silvestres))
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
    -- en campo abierto (las ciudades son zonas seguras)
    local pu0 = mundo.mapas.mundo.puestos[1]
    dueno.x, dueno.y = pu0.x + 8.5, pu0.y + 8.5
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
  paso("mapa ampliado y PNJ repartidos", function()
    local Mapa = require("compartido.dominio.mapa")
    local mundo = Mundo.nuevo()
    local mapa = mundo.mapas.mundo
    fallar(errores, "el mapa es más grande que antes", mapa.w >= 1100 and mapa.h >= 800, mapa.w .. "x" .. mapa.h)
    -- las ciudades están más lejos que en el mapa viejo (la menor distancia entre dos era ~95)
    local minimo = math.huge
    for i, a in ipairs(mapa.ciudades) do
      for j = i + 1, #mapa.ciudades do
        local b = mapa.ciudades[j]
        minimo = math.min(minimo, math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2))
      end
    end
    fallar(errores, "las ciudades están más separadas", minimo > 140, string.format("%.0f", minimo))
    fallar(errores, "hay puestos repartidos", #mapa.puestos >= 18, tostring(#mapa.puestos))
    local roles = {}
    for _, n in ipairs(mapa.npcsMapa) do
      roles[n.rol] = (roles[n.rol] or 0) + 1
      fallar(errores, "PNJ " .. n.nombre .. " en suelo transitable", Mapa.transitable(mapa, math.floor(n.x), math.floor(n.y)))
    end
    for _, rol in ipairs({ "mercado", "comercio", "heraldo", "mayordomo", "encargos", "encantador", "criador", "gremio", "oficios", "establo", "capitan", "contacto" }) do
      fallar(errores, "hay PNJ de " .. rol, (roles[rol] or 0) >= 2, tostring(roles[rol]))
    end
    -- en las ciudades no se amontonan en el centro de la plaza
    local lejos = 0
    for _, c in ipairs(mapa.ciudades) do
      local cx, cy = c.x + c.w / 2, c.y + c.h / 2
      for _, n in ipairs(c.npcs) do
        if n.rol ~= "guardia" and math.abs(n.x - cx) + math.abs(n.y - cy) > 6 then lejos = lejos + 1 end
      end
    end
    fallar(errores, "los PNJ de ciudad se reparten por las avenidas", lejos >= #mapa.ciudades * 9, tostring(lejos))
    -- los puestos se alcanzan por tierra
    local a = mapa.ciudades[1]
    local alcanzados = 0
    for _, pu in ipairs(mapa.puestos) do
      local ruta = Mapa.buscar(mapa, a.x + a.w / 2, a.y + a.h + 2, pu.x, pu.y)
      if ruta and #ruta > 0 then alcanzados = alcanzados + 1 end
    end
    fallar(errores, "los puestos son alcanzables", alcanzados >= #mapa.puestos - 2, alcanzados .. "/" .. #mapa.puestos)
  end)
  paso("oficios, comercio, robos y recompensas", function()
    local mundo = Mundo.nuevo()
    local function npcDe(rol, ciudadId)
      for _, e in pairs(mundo.entidades) do
        if e.kind == "npc" and e.rol == rol then
          local ci = mundo:ciudadEn(e.x, e.y)
          if (not ciudadId) or (ci and ci.id == ciudadId) then return e end
        end
      end
    end
    local function irA(p, e) p.x, p.y, p.z = e.x + 1, e.y, 0 p.tramo = nil end
    local mapa = mundo.mapas.mundo
    -- elegir oficio
    local t = mundo:crearPersonaje({ nombre = "Mercader1", faccion = "albor", clase = "guerrero", nivel = 12 })
    t.oro = 50000
    local maestro = npcDe("oficios", mapa.ciudades[1].id)
    irA(t, maestro)
    fallar(errores, "hay maestro de oficios", maestro ~= nil)
    fallar(errores, "elige comerciante gratis", mundo:elegirOficio(t, "trader", "ciudad") == nil and t.oficioElegido == "trader" and t.job == nil and mundo:alternarOficio(t) == nil and t.job == "trader" and t.oro == 50000)
    fallar(errores, "el ladrón no se aprende en la ciudad", mundo:elegirOficio(t, "thief", "ciudad") ~= nil)
    -- comprar y vender entre dos ciudades
    local a, b, bien
    for _, ca in ipairs(mapa.ciudades) do
      for _, cb in ipairs(mapa.ciudades) do
        if ca ~= cb and not bien then
          local sa, sb = mundo:sitioPorId(ca.id), mundo:sitioPorId(cb.id)
          for _, g in ipairs(sa.perfil.produce) do
            for _, d in ipairs(sb.perfil.demanda) do if g == d then a, b, bien = ca, cb, g end end
          end
        end
      end
    end
    fallar(errores, "hay un par de ciudades con comercio provechoso", bien ~= nil)
    if bien then
      local nA = npcDe("comercio", a.id)
      local nB = npcDe("comercio", b.id)
      irA(t, nA)
      local sitioA = mundo:sitioCerca(t)
      fallar(errores, "el mercader mayor da su sitio", sitioA and sitioA.id == a.id, sitioA and sitioA.id)
      local antes = mundo:precioBien(sitioA, bien, true)
      local oro0 = t.oro
      fallar(errores, "compra", mundo:comprarBien(t, bien, 10) == nil and t.carga[bien] == 10)
      fallar(errores, "la compra sube el precio", mundo:precioBien(sitioA, bien, true) > antes)
      fallar(errores, "ir cargado frena", t.penalCarga > 0)
      irA(t, nB)
      fallar(errores, "vende en otra ciudad", mundo:venderBien(t, bien, 10) == nil and not t.carga[bien])
      fallar(errores, "gana oro con el viaje", t.oro > oro0, oro0 .. " -> " .. t.oro)
      fallar(errores, "gana experiencia de oficio", t.oficios.trader.xp > 0 or t.oficios.trader.nivel > 1)
      irA(t, nA)
      fallar(errores, "no carga más de lo que cabe", mundo:comprarBien(t, bien, 1000) == nil and mundo:pesoCarga(t) == mundo:capacidadCarga(t))
      fallar(errores, "ya no cabe más", mundo:comprarBien(t, bien, 1) ~= nil)
      mundo:venderBien(t, bien, t.carga[bien])
    end
    local x = mundo:crearPersonaje({ nombre = "Normal", faccion = "albor", clase = "mago" })
    irA(x, npcDe("comercio", a.id))
    fallar(errores, "solo los comerciantes comercian", mundo:comprarBien(x, "trigo", 1) ~= nil)
    -- robo: fuera de la ciudad
    local afuera = mapa.puestos[1]
    local ladron = mundo:crearPersonaje({ nombre = "Sombra", faccion = "albor", clase = "cazador", nivel = 12 })
    ladron.oro = 5000
    local hunter = mundo:crearPersonaje({ nombre = "Cazador1", faccion = "albor", clase = "guerrero", nivel = 12 })
    local contacto = npcDe("contacto")
    irA(ladron, contacto)
    fallar(errores, "un ladrón se hace en un refugio", mundo:elegirOficio(ladron, "thief", "ladron") == nil and ladron.job == nil and mundo:alternarOficio(ladron) == nil and ladron.job == "thief")
    fallar(errores, "el cazarrecompensas se hace en su campamento", mundo:elegirOficio(hunter, "hunter", "capitan") == nil and mundo:alternarOficio(hunter) == nil and hunter.job == "hunter")
    local victima = mundo:crearPersonaje({ nombre = "Mercader2", faccion = "albor", clase = "mago", nivel = 12 })
    victima.job, victima.oficios = "trader", { trader = { nivel = 1, xp = 0 } }
    victima.carga = { vino = 12, gemas = 4 }
    mundo:recalcularCarga(victima)
    for _, e in pairs({ ladron, victima, hunter }) do e.x, e.y, e.z, e.modo = afuera.x + 8.5, afuera.y + 8.5, 0, "mundo" end
    hunter.x = afuera.x + 40
    victima.x = ladron.x + 1
    fallar(errores, "el punto de prueba está fuera de ciudades", not mundo:ciudadEn(ladron.x, ladron.y))
    fallar(errores, "el ladrón empieza un robo", mundo:iniciarRobo(ladron, victima.id) == nil and ladron.robo ~= nil)
    local azarOriginal = math.random
    math.random = function(a2) if a2 then return 1 end return 0 end
    local ok2, err2 = pcall(function() for _ = 1, 60 do mundo:actualizar(0.1) end end)
    math.random = azarOriginal
    fallar(errores, "el robo se resuelve sin errores", ok2, tostring(err2))
    local robado = 0
    for _, c in pairs(ladron.cargaRobada or {}) do robado = robado + c end
    fallar(errores, "el ladrón se lleva mercancía", robado > 0, tostring(robado))
    fallar(errores, "al comerciante le falta", mundo:pesoCarga(victima) < 16)
    fallar(errores, "el ladrón queda buscado", mundo:esBuscado(ladron) and (ladron.recompensa or 0) > 0)
    fallar(errores, "la víctima puede defenderse", mundo:puedeDanar(victima, ladron) and mundo:puedeDanar(ladron, victima))
    fallar(errores, "el cazarrecompensas puede herir al buscado", mundo:puedeDanar(hunter, ladron))
    local otro = mundo:crearPersonaje({ nombre = "Pasante", faccion = "albor", clase = "guerrero" })
    fallar(errores, "otro jugador de su corona no puede", not mundo:puedeDanar(otro, ladron))
    -- no se roba dentro de una ciudad
    local ciudad = mapa.ciudades[1]
    local dentro1 = mundo:crearPersonaje({ nombre = "Mercader3", faccion = "albor", clase = "mago" })
    dentro1.job, dentro1.oficios, dentro1.carga = "trader", { trader = { nivel = 1, xp = 0 } }, { vino = 5 }
    dentro1.x, dentro1.y = ciudad.spawn.x, ciudad.spawn.y
    ladron.robo, ladron.x, ladron.y = nil, ciudad.spawn.x + 1, ciudad.spawn.y
    fallar(errores, "en la ciudad no se roba", mundo:iniciarRobo(ladron, dentro1.id) ~= nil)
    -- el contacto compra lo robado
    irA(ladron, contacto)
    local oroAntes = ladron.oro
    fallar(errores, "el contacto compra lo robado", mundo:venderRobado(ladron) == nil and ladron.oro > oroAntes and mundo:pesoCarga(ladron) == 0)
    -- recompensa
    ladron.cargaRobada = { vino = 5 }
    mundo:recalcularCarga(ladron)
    ladron.buscado, ladron.recompensa = mundo.tiempo + 100, 300
    local oroH = hunter.oro
    mundo:danar(ladron, 99999, hunter)
    fallar(errores, "el cazarrecompensas cobra la recompensa", hunter.oro >= oroH + 300, oroH .. " -> " .. hunter.oro)
    fallar(errores, "el buscado pierde lo robado y la búsqueda", not mundo:esBuscado(ladron) and mundo:pesoCarga(ladron) == 0)
    -- un robo fallido no da nada pero marca como buscado
    mundo:revivir(ladron)
    ladron.job = "thief"
    victima.carga = { vino = 12 }
    mundo:recalcularCarga(victima)
    ladron.x, ladron.y, victima.x, victima.y = afuera.x + 8.5, afuera.y + 8.5, afuera.x + 9.5, afuera.y + 8.5
    mundo:iniciarRobo(ladron, victima.id)
    math.random = function(a2) if a2 then return 1 end return 0.9999 end
    pcall(function() for _ = 1, 60 do mundo:actualizar(0.1) end end)
    math.random = azarOriginal
    fallar(errores, "un robo fallido no da nada pero busca", mundo:pesoCarga(ladron) == 0 and mundo:esBuscado(ladron))
  end)
  paso("caravanas, bandidos y monturas", function()
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local mapa = mundo.mapas.mundo
    local a, b = mapa.ciudades[1], mapa.ciudades[2]
    local c = mundo:salirCaravana(a, b)
    fallar(errores, "sale una caravana con ruta y carga", c and #c.ruta >= 4 and c.valor > 0 and next(c.carga) ~= nil)
    -- la caravana recorre el camino de verdad hasta el destino
    local hunter = mundo:crearPersonaje({ nombre = "Escolta", faccion = "albor", clase = "guerrero", nivel = 12 })
    hunter.job, hunter.oficios = "hunter", { hunter = { nivel = 1, xp = 0 } }
    hunter.x, hunter.y = c.x + 1, c.y
    fallar(errores, "el cazarrecompensas se une a la escolta", mundo:escoltarCaravana(hunter, c.id) == nil)
    local oro0 = hunter.oro
    c.emboscada = nil
    local llego = false
    for _ = 1, 9000 do
      mundo:actualizar(0.1)
      if c.borrar then llego = true break end
      hunter.x, hunter.y = c.x + 1, c.y
    end
    fallar(errores, "la caravana llega a su destino", llego, string.format("paso %d de %d, en %.0f,%.0f", c.paso, #c.ruta, c.x, c.y))
    fallar(errores, "la escolta cobra", hunter.oro > oro0, oro0 .. " -> " .. hunter.oro)
    -- emboscada: los bandidos van a por la caravana
    local c2 = mundo:salirCaravana(a, b)
    mundo:emboscar(c2)
    local bandidos = 0
    for _, e in pairs(mundo.entidades) do if e.bandido then bandidos = bandidos + 1 end end
    fallar(errores, "salen bandidos", bandidos >= 2, tostring(bandidos))
    local hp0 = c2.hp
    for _ = 1, 150 do mundo:actualizar(0.1) end
    fallar(errores, "los bandidos atacan a la caravana", c2.hp < hp0 or c2.borrar, hp0 .. " -> " .. c2.hp)
    fallar(errores, "los jugadores no pueden herir caravanas", not mundo:puedeDanar(hunter, c2))
    -- si cae, deja mercancías que recoge un comerciante
    local c3 = mundo:salirCaravana(a, b)
    c3.hp = 1
    local bandido = mundo:spawnMonstruo("bandido", c3.x + 1, c3.y, { x = c3.x, y = c3.y })
    mundo:danar(c3, 99999, bandido)
    local botin
    for _, e in pairs(mundo.entidades) do if e.kind == "loot" and e.bienes then botin = e end end
    fallar(errores, "la caravana destruida deja mercancías", botin ~= nil)
    local t = mundo:crearPersonaje({ nombre = "Recoge", faccion = "albor", clase = "mago", nivel = 12 })
    t.job, t.oficios = "trader", { trader = { nivel = 1, xp = 0 } }
    if botin then
      t.x, t.y = botin.x, botin.y
      mundo:recoger(t, botin)
      fallar(errores, "el comerciante recoge la carga", mundo:pesoCarga(t) > 0, tostring(mundo:pesoCarga(t)))
    end
    -- monturas
    local m = mundo:crearPersonaje({ nombre = "Jinete", faccion = "albor", clase = "cazador", nivel = 15 })
    m.oro = 20000
    fallar(errores, "compra un caballo", mundo:comprarMontura(m, "caballo") == nil)
    fallar(errores, "no repite", mundo:comprarMontura(m, "caballo") ~= nil)
    fallar(errores, "la carreta es de comerciantes", mundo:comprarMontura(m, "carreta") ~= nil)
    local vel0, car0 = mundo:bonoMontura(m)
    fallar(errores, "sin montar no hay bono", vel0 == 0 and car0 == 0)
    fallar(errores, "monta", mundo:alternarMontura(m, "caballo") == nil and m.montado == "caballo")
    local vel, car = mundo:bonoMontura(m)
    fallar(errores, "el caballo da velocidad", vel >= 0.3 and car > 0)
    mundo:alternarMontura(m)
    fallar(errores, "baja", m.montado == nil)
    -- dentro de una casa se baja solo
    mundo:alternarMontura(m, "caballo")
    m.modo = "casa"
    mundo:actualizar(0.1)
    fallar(errores, "se baja sola en una casa", m.montado == nil)
    m.modo = "mundo"
    -- una montura de carga sube la capacidad del comerciante y frena menos
    local mc = mundo:crearPersonaje({ nombre = "Carretero", faccion = "albor", clase = "mago", nivel = 20 })
    mc.oro = 20000
    mc.job, mc.oficios = "trader", { trader = { nivel = 1, xp = 0 } }
    mundo:recalcularCarga(mc)
    local base = mundo:capacidadCarga(mc)
    fallar(errores, "compra la carreta", mundo:comprarMontura(mc, "carreta") == nil)
    mundo:alternarMontura(mc, "carreta")
    fallar(errores, "la carreta carga mucho más", mundo:capacidadCarga(mc) >= base + 80, base .. " -> " .. mundo:capacidadCarga(mc))
    mc.carga = { vino = base }
    mundo:recalcularCarga(mc)
    local montado = mc.penalCarga
    mundo:alternarMontura(mc)
    mc.carga = { vino = base }
    mundo:recalcularCarga(mc)
    fallar(errores, "ir montado reduce el freno de la carga", montado < mc.penalCarga, montado .. " vs " .. mc.penalCarga)
  end)
  paso("casa de subastas", function()
    local Subastas = require("compartido.dominio.subastas")
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local reloj = 1000000
    mundo.relojSubastas = function() return reloj end
    local function jug(nombre, dbId)
      local e = mundo:crearPersonaje({ nombre = nombre, faccion = "albor", clase = "guerrero", nivel = 10 })
      e.dbId, e.oro = dbId, 10000
      return e
    end
    local v, a, b = jug("Vende", 201), jug("Pujo1", 202), jug("Pujo2", 203)
    v.bolsa = { { id = "guerrero_arma_2", cant = 1, enc = 3 }, { id = "pocion_vida", cant = 10 } }
    -- publicar
    fallar(errores, "elige objeto válido", mundo:publicarSubasta(v, 9, 1, 100, nil, 6) ~= nil)
    fallar(errores, "precio de salida válido", mundo:publicarSubasta(v, 1, 1, 0, nil, 6) ~= nil)
    fallar(errores, "la compra supera a la salida", mundo:publicarSubasta(v, 1, 1, 100, 50, 6) ~= nil)
    fallar(errores, "duración válida", mundo:publicarSubasta(v, 1, 1, 100, nil, 5) ~= nil)
    local oro0 = v.oro
    fallar(errores, "publica con compra", mundo:publicarSubasta(v, 1, 1, 100, 500, 6) == nil)
    fallar(errores, "cobra comisión y retira el objeto", v.oro == oro0 - math.max(5, math.floor(100 * Subastas.COMISION)) and #v.bolsa == 1)
    fallar(errores, "publica parte de una pila", mundo:publicarSubasta(v, 1, 4, 20, nil, 1) == nil and v.bolsa[1].cant == 6)
    local primera, segunda
    for id, s in pairs(mundo.subastas) do if s.item == "guerrero_arma_2" then primera = s else segunda = s end end
    fallar(errores, "el encantamiento viaja con el objeto", primera.enc == 3)
    fallar(errores, "dura lo que dijo", primera.termina - primera.creada == 6 * 3600)
    -- pujar
    fallar(errores, "no se puja por lo propio", mundo:pujarSubasta(v, primera.id, 200) ~= nil)
    fallar(errores, "puja mínima", mundo:pujarSubasta(a, primera.id, 99) ~= nil)
    fallar(errores, "puja", mundo:pujarSubasta(a, primera.id, 100) == nil and a.oro == 9900 and primera.postor == 202)
    fallar(errores, "el mejor postor no puja otra vez", mundo:pujarSubasta(a, primera.id, 200) ~= nil)
    fallar(errores, "la siguiente puja sube un 5%", mundo:pujarSubasta(b, primera.id, 104) ~= nil and mundo:pujarSubasta(b, primera.id, 105) == nil)
    fallar(errores, "al ser superado recupera el oro", a.oro == 10000 and b.oro == 9895)
    fallar(errores, "sin oro no puja", (function() b.oro = 1 return mundo:pujarSubasta(b, primera.id, 500) end)() ~= nil)
    b.oro = 9895
    -- antibotes: pujar al final alarga
    reloj = primera.termina - 30
    fallar(errores, "puja de última hora", mundo:pujarSubasta(a, primera.id, 120) == nil)
    fallar(errores, "alarga la subasta", primera.termina >= reloj + Subastas.TIEMPO_EXTRA)
    -- comprar ya
    local oroB = b.oro
    fallar(errores, "compra inmediata", mundo:comprarSubasta(b, primera.id) == nil and mundo.subastas[primera.id] == nil)
    fallar(errores, "paga el precio de compra", b.oro == oroB - 500)
    fallar(errores, "el anterior postor recupera su puja", a.oro == 10000)
    local bz = mundo.buzones[203]
    fallar(errores, "el comprador tiene el objeto en el buzón", bz and bz[1].item == "guerrero_arma_2" and bz[1].enc == 3)
    local bv = mundo.buzones[201]
    local neto = 500 - math.floor(500 * Subastas.IMPUESTO)
    fallar(errores, "el vendedor cobra menos el impuesto", bv and bv[1].oro == neto, tostring(bv and bv[1].oro))
    -- recoger el buzón
    fallar(errores, "recoge el buzón", mundo:cobrarBuzon(b) == nil and mundo:contarBuzon(b) == 0)
    local tiene = false
    for _, s in ipairs(b.bolsa) do if s.id == "guerrero_arma_2" and s.enc == 3 then tiene = true end end
    fallar(errores, "el objeto llega con su +3", tiene)
    local oroV = v.oro
    mundo:cobrarBuzon(v)
    fallar(errores, "el vendedor recibe el oro", v.oro == oroV + neto)
    fallar(errores, "buzón vacío", mundo:cobrarBuzon(v) ~= nil)
    -- sin pujas el objeto vuelve
    reloj = reloj + 10
    reloj = segunda.termina + 1
    mundo._subT = 10
    mundo:actualizarSubastas(1)
    fallar(errores, "la subasta sin pujas termina", mundo.subastas[segunda.id] == nil)
    fallar(errores, "el objeto vuelve a su dueño", mundo:contarBuzon(v) == 1)
    mundo:cobrarBuzon(v)
    local pociones = 0
    for _, s in ipairs(v.bolsa) do if s.id == "pocion_vida" then pociones = pociones + s.cant end end
    fallar(errores, "recupera las pociones", pociones == 10, tostring(pociones))
    -- ganar al terminar el tiempo
    mundo:publicarSubasta(v, 1, 1, 50, nil, 1)
    local s3
    for _, s in pairs(mundo.subastas) do s3 = s end
    mundo:pujarSubasta(a, s3.id, 60)
    reloj = s3.termina + 1
    mundo._subT = 10
    mundo:actualizarSubastas(1)
    fallar(errores, "gana el mejor postor", mundo.subastas[s3.id] == nil and mundo:contarBuzon(a) == 1 and mundo:contarBuzon(v) >= 1)
    -- cancelar
    mundo:cobrarBuzon(a)
    mundo:cobrarBuzon(v)
    v.bolsa = { { id = "pocion_mana", cant = 3 } }
    mundo:publicarSubasta(v, 1, 3, 10, nil, 12)
    local s4
    for _, s in pairs(mundo.subastas) do s4 = s end
    fallar(errores, "otro no cancela", mundo:cancelarSubasta(a, s4.id) ~= nil)
    mundo:pujarSubasta(a, s4.id, 10)
    fallar(errores, "con pujas no se cancela", mundo:cancelarSubasta(v, s4.id) ~= nil)
    s4.postor = nil
    fallar(errores, "sin pujas se cancela", mundo:cancelarSubasta(v, s4.id) == nil and mundo:contarBuzon(v) == 1)
    -- límite por jugador
    v.bolsa = {}
    for i = 1, 10 do v.bolsa[i] = { id = "guerrero_arma_" .. (i % 4 + 1), cant = 1 } end
    v.oro = 100000
    local publicadas = 0
    for _ = 1, 10 do if mundo:publicarSubasta(v, 1, 1, 10, nil, 1) == nil then publicadas = publicadas + 1 end end
    fallar(errores, "máximo de subastas por jugador", publicadas == Subastas.MAX_POR_JUGADOR, tostring(publicadas))
    -- lo que ve el panel: categorías y páginas
    local info = mundo:infoSubastas(a, "arma", 1)
    fallar(errores, "el panel filtra por categoría", info.total == publicadas and #info.lista <= Subastas.POR_PAGINA)
    fallar(errores, "el panel pagina", info.paginas == math.ceil(publicadas / Subastas.POR_PAGINA))
    fallar(errores, "otras categorías vacías", mundo:infoSubastas(a, "armadura", 1).total == 0)
    fallar(errores, "mis subastas", #mundo:infoSubastas(v, "todo", 1).mias == publicadas)
    -- el almacén guarda subastas y buzones
    local usuario = "su" .. string.format("%06d", os.time() % 1000000)
    Cuentas.borrarUsuario(usuario)
    local idCuenta = Cuentas.registrar(usuario, "clave12")
    local p1 = idCuenta and Cuentas.crearPersonaje(idCuenta, "SubUno" .. string.format("%03d", os.time() % 1000), "albor", "guerrero")
    local p2 = idCuenta and Cuentas.crearPersonaje(idCuenta, "SubDos" .. string.format("%03d", os.time() % 1000), "albor", "mago")
    fallar(errores, "personajes de prueba", p1 ~= nil and p2 ~= nil)
    if p1 and p2 then
      local id = 800000 + os.time() % 90000
      local s = { id = id, vendedor = p1, vendedorNombre = "SubUno", item = "guerrero_arma_3", cant = 1, enc = 2, salida = 90, compra = 400,
        oferta = 120, postor = p2, postorNombre = "SubDos", creada = os.time(), termina = os.time() + 3600 }
      local ok, err = Cuentas.guardarSubasta(s)
      fallar(errores, "guarda la subasta", ok, tostring(err))
      s.oferta = 150
      Cuentas.guardarSubasta(s)
      local ok2 = Cuentas.guardarBuzon(p2, { { item = "pocion_vida", cant = 3, oro = 0, nota = "prueba" }, { oro = 77, nota = "oro" } })
      fallar(errores, "guarda el buzón", ok2)
      local lista, buzones = Cuentas.cargarSubastas()
      local hallada
      for _, x in ipairs(lista or {}) do if x.id == id then hallada = x end end
      fallar(errores, "recupera la subasta con su puja", hallada and hallada.oferta == 150 and hallada.postor == p2 and hallada.enc == 2 and hallada.compra == 400)
      fallar(errores, "recupera el buzón", buzones and buzones[p2] and #buzones[p2] == 2 and buzones[p2][2].oro == 77)
      local m2 = Mundo.nuevo()
      m2:cargarSubastas(lista, buzones)
      fallar(errores, "el mundo retoma las subastas", m2.subastas[id] ~= nil and m2.siguienteSubasta > id)
      Cuentas.borrarSubasta(id)
      Cuentas.guardarBuzon(p2, {})
      local l2, b2 = Cuentas.cargarSubastas()
      local sigue = false
      for _, x in ipairs(l2 or {}) do if x.id == id then sigue = true end end
      fallar(errores, "borrar quita la subasta y el buzón", not sigue and not (b2 and b2[p2]))
    end
    Cuentas.borrarUsuario(usuario)
  end)
  paso("eventos programados por el servidor", function()
    local Programacion = require("compartido.dominio.programacion")
    local function hora(h, m, dia)
      return os.time({ year = 2030, month = 3, day = dia or 10, hour = h, min = m or 0, sec = 0 })
    end
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local reloj = hora(10, 30)
    mundo.relojEventos = function() return reloj end
    mundo:programarEventos({ estandarteCadaHoras = 4, batallaHora = 21, batallaMinuto = 0, avisoMinutos = 5 })
    -- próximas ediciones
    fallar(errores, "estandarte: a las 10:30 toca a las 12", mundo:proximaEdicion("estandarte", hora(10, 30)) == hora(12))
    fallar(errores, "estandarte: justo a las 12 toca a las 16", mundo:proximaEdicion("estandarte", hora(12)) == hora(16))
    fallar(errores, "estandarte: de noche pasa al día siguiente", mundo:proximaEdicion("estandarte", hora(23, 59)) == hora(0, 0, 11))
    fallar(errores, "batalla: antes de las 21 es hoy", mundo:proximaEdicion("batalla", hora(15)) == hora(21))
    fallar(errores, "batalla: después de las 21 es mañana", mundo:proximaEdicion("batalla", hora(21, 1)) == hora(21, 0, 11))
    fallar(errores, "el panel sabe la hora", mundo:programaDe("estandarte").hora == "12:00" and mundo:programaDe("batalla").hora == "21:00")
    local function equipo(cuantos, faccion, pref)
      local lista = {}
      for i = 1, cuantos do
        lista[i] = mundo:crearPersonaje({ nombre = pref .. i, faccion = faccion, clase = "guerrero", nivel = 10 })
        lista[i].ultimoGolpe = -100
      end
      return lista
    end
    local albor, umbra = equipo(3, "albor", "Al"), equipo(3, "umbra", "Um")
    local function seg(n) for _ = 1, n do mundo:actualizar(1) end end
    -- inscripción: queda apuntado pero NO empieza solo aunque haya jugadores de sobra
    for _, e in ipairs(albor) do fallar(errores, "se apunta " .. e.nombre, mundo:entrarGuerra(e, "estandarte") == nil) end
    for _, e in ipairs(umbra) do mundo:entrarGuerra(e, "estandarte") end
    fallar(errores, "con la programación no empieza solo", not mundo.instancia.estandarte.activa and albor[1].colaGuerra == "estandarte")
    -- aviso antes de la hora
    local avisos = 0
    local function contarAvisos()
      avisos = 0
      for _, m in ipairs(mundo.mensajes) do
        if m.canal == "mundo" and m.texto:find("empieza a las 12:00", 1, true) then avisos = avisos + 1 end
      end
    end
    reloj = hora(11, 53)
    seg(3)
    contarAvisos()
    fallar(errores, "aún no avisa fuera del margen", avisos == 0)
    reloj = hora(11, 56)
    seg(3)
    contarAvisos()
    fallar(errores, "avisa a todos al abrir la inscripción", avisos == 1, tostring(avisos))
    seg(3)
    contarAvisos()
    fallar(errores, "el aviso sale una sola vez", avisos == 1)
    -- a la hora: lo lanza el servidor
    reloj = hora(12, 0)
    seg(2)
    fallar(errores, "a las 12 empieza el estandarte", mundo.instancia.estandarte.activa and albor[1].modo == "estandarte" and umbra[2].modo == "estandarte")
    fallar(errores, "la próxima edición pasa a las 16", mundo:programaDe("estandarte").hora == "16:00")
    fallar(errores, "se marca la edición en la que juegan", albor[1].eventosDia["estandarte@2030031012"] ~= nil)
    -- no se repite la misma edición pero un recién llegado puede entrar con el evento en marcha
    local tarde = mundo:crearPersonaje({ nombre = "Tarde", faccion = "albor", clase = "mago", nivel = 10 })
    tarde.ultimoGolpe = -100
    fallar(errores, "entra tarde en el campo", mundo:entrarGuerra(tarde, "estandarte") == nil and tarde.modo == "estandarte")
    mundo:cerrarInstancia("estandarte", "albor")
    fallar(errores, "los jugadores vuelven al mundo", albor[1].modo == "mundo")
    local err = mundo:entrarGuerra(albor[1], "estandarte")
    fallar(errores, "la nueva edición aún no ha abierto: queda inscrito para la 16:00", err == nil and albor[1].colaGuerra == "estandarte")
    albor[1].colaGuerra = nil
    -- cuatro horas después, otra edición: se puede volver a jugar
    reloj = hora(16, 0)
    for _, e in ipairs(albor) do e.colaGuerra = nil end
    for _, e in ipairs(umbra) do e.colaGuerra = nil end
    for _, e in ipairs(albor) do mundo:entrarGuerra(e, "estandarte") end
    for _, e in ipairs(umbra) do mundo:entrarGuerra(e, "estandarte") end
    seg(2)
    fallar(errores, "a las 16 se juega otra edición", mundo.instancia.estandarte.activa and albor[2].modo == "estandarte")
    fallar(errores, "la siguiente es a las 20", mundo:programaDe("estandarte").hora == "20:00")
    mundo:cerrarInstancia("estandarte", "umbra")
    -- sin jugadores suficientes se cancela y se suelta la cola
    local solo = mundo:crearPersonaje({ nombre = "Solo", faccion = "albor", clase = "mago", nivel = 10 })
    solo.ultimoGolpe = -100
    mundo:entrarGuerra(solo, "estandarte")
    reloj = hora(20, 0)
    seg(2)
    fallar(errores, "sin suficientes no empieza", not mundo.instancia.estandarte.activa)
    fallar(errores, "se suelta la cola", solo.colaGuerra == nil)
    fallar(errores, "pasa a la siguiente edición", mundo:programaDe("estandarte").hora == "00:00")
    -- batalla por cristales: una vez al día a las 21
    reloj = hora(21, 0)
    for _, e in ipairs(albor) do e.colaGuerra = nil mundo:entrarGuerra(e, "batalla") end
    for _, e in ipairs(umbra) do e.colaGuerra = nil mundo:entrarGuerra(e, "batalla") end
    seg(2)
    fallar(errores, "a las 21 empieza la batalla por cristales", mundo.instancia.batalla.activa and albor[1].modo == "batalla")
    fallar(errores, "la siguiente batalla es mañana a las 21", mundo:programaDe("batalla").hora == "21:00" and mundo.eventos.batalla.proxima == hora(21, 0, 11))
    fallar(errores, "la batalla se marca por día", albor[1].eventosDia["batalla@20300310"] ~= nil)
    -- sin programación todo sigue como antes (mundos locales y pruebas)
    local Servicio = require("src.aplicacion.servicio_servidor")
    local cfgEv = {}
    for k, v in pairs(Config.eventos) do cfgEv[k] = v end
    cfgEv.activos = true
    local real = Servicio.crearMundo({ eventos = cfgEv })
    fallar(errores, "el servidor programa los eventos con su configuración",
      real.horarioEventos and real.horarioEventos.estandarteCadaHoras == Config.eventos.estandarteCadaHoras and real.horarioEventos.batallaHora == Config.eventos.batallaHora,
      tostring(real.horarioEventos and real.horarioEventos.estandarteCadaHoras))
    fallar(errores, "el servidor sin opciones no programa", Servicio.crearMundo().horarioEventos == nil)
    local viejo = Mundo.nuevo()
    fallar(errores, "sin programación no hay horario", viejo.horarioEventos == nil and viejo:programaDe("estandarte") == nil and viejo:claveEdicion("batalla") == "batalla")
  end)
  paso("ajustes del juego desde el .env", function()
    local Balance = require("compartido.dominio.balance")
    local Subastas = require("compartido.dominio.subastas")
    local Gremios = require("compartido.dominio.gremios")
    local Ajustes = require("src.aplicacion.ajustes")
    local Servicio = require("src.aplicacion.servicio_servidor")
    -- valores por defecto que lee la configuración
    fallar(errores, "la configuración del juego se lee (números dentro de rango)", type(Config.juego.xpDificultad) == "number" and Config.juego.xpDificultad >= 0.1 and type(Config.juego.monstruoVida) == "number")
    fallar(errores, "la configuración de subastas y gremios se lee", type(Config.juego.subastaComision) == "number" and Config.juego.subastaComision <= 0.5 and type(Config.juego.gremioCoste) == "number")
    fallar(errores, "la configuración de eventos se lee", Config.eventos.minJugadores >= 1 and Config.eventos.duracionBatalla >= 30 and type(Config.juego.xpMultiplicador) == "number")
    -- lista de horas
    local h = Ajustes.horas("2, 48 ,x,0,9999")
    fallar(errores, "las duraciones se leen de una lista", h and #h == 2 and h[1] == 2 and h[2] == 48)
    fallar(errores, "una lista mala no cambia nada", Ajustes.horas("abc") == nil)
    -- aplicar valores propios al crear el mundo
    local gato0 = Datos.statsMonstruo(Datos.monstruo("gato")).hp
    local xp0 = Balance.xpPara(1)
    local mundo = Servicio.crearMundo({ ajustes = {
      juego = { xpDificultad = 3.6, monstruoVida = 6, subastaComision = 0.1, subastaDuraciones = "2,48", gremioCoste = 99,
        caravanaIntervalo = 10, respawnMonstruo = 5, mascotaDescanso = 7, oficioCosteCambio = 1, xpMultiplicador = 2 },
      eventos = { minJugadores = 2, duracionBatalla = 600, duracionEstandarte = 120 },
    } })
    fallar(errores, "sube la dificultad de experiencia", Balance.xpPara(1) == xp0 * 2, xp0 .. " -> " .. Balance.xpPara(1))
    fallar(errores, "las criaturas nacen con la vida nueva", math.abs(Datos.statsMonstruo(Datos.monstruo("gato")).hp - gato0 * 2) <= 1)
    fallar(errores, "subastas ajustadas", Subastas.COMISION == 0.1 and #Subastas.DURACIONES == 2 and Subastas.DURACIONES[2] == 48)
    fallar(errores, "gremios ajustados", Gremios.COSTE == 99)
    fallar(errores, "eventos ajustados", Datos.JUGADORES_EVENTO == 2 and mundo.instancia.batalla.duracion == 600 and mundo.instancia.estandarte.duracion == 120)
    fallar(errores, "informa de lo que cambió", mundo.ajustesCambiados and #mundo.ajustesCambiados >= 8)
    -- el cliente recibe la experiencia que pide el servidor
    local p = mundo:crearPersonaje({ nombre = "Ajuste", faccion = "albor", clase = "mago" })
    fallar(errores, "la foto lleva la experiencia del siguiente nivel", mundo:foto(p.id).tu.xpSig == Balance.xpPara(1))
    -- experiencia doble desde el .env
    local xpAntes = p.xp
    mundo:ganarXp(p, 10)
    fallar(errores, "con x2 se gana el doble de experiencia", p.xp - xpAntes == 20, tostring(p.xp - xpAntes))
    -- restaurar deja todo como estaba
    mundo.restaurarAjustes()
    fallar(errores, "se restauran los valores", Balance.xpPara(1) == xp0 and Subastas.COMISION == 0.05 and Gremios.COSTE == 1500
      and Datos.JUGADORES_EVENTO == 3 and #Subastas.DURACIONES == 4 and Balance.XP_MULTIPLICADOR == 1)
  end)
  paso("montado no se combate", function()
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local pu = mundo.mapas.mundo.puestos[1]
    local p = mundo:crearPersonaje({ nombre = "Jinete", faccion = "albor", clase = "guerrero", nivel = 12 })
    p.x, p.y, p.z, p.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
    local m = mundo:spawnMonstruo("gato", p.x + 1, p.y, { x = p.x, y = p.y })
    m.hp, m.hpMax, m.agresivo, m.cds = 9999, 9999, false, { auto = 1e9 }
    p.monturas, p.montado = { "buey" }, "buey"
    p.objetivo = m.id
    p.cds.auto, p.gcd = 0, 0
    mundo:autoataque(p)
    fallar(errores, "montado no hay ataque automático", m.hp == 9999)
    p.mp = p.mpMax
    local err = mundo:usarHabilidad(p, 1)
    fallar(errores, "montado no se usan poderes", err ~= nil and m.hp == 9999 and (p.cds.auto or 0) <= mundo.tiempo)
    mundo:alternarMontura(p)
    fallar(errores, "al bajar se puede pelear", p.montado == nil)
    p.cds.auto, p.gcd = 0, 0
    mundo:autoataque(p)
    fallar(errores, "a pie sí ataca", m.hp < 9999 or (p.cds.auto or 0) > mundo.tiempo)
  end)
  paso("activar el oficio", function()
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local pu = mundo.mapas.mundo.puestos[1]
    local p = mundo:crearPersonaje({ nombre = "Activo", faccion = "albor", clase = "guerrero", nivel = 12 })
    p.x, p.y, p.z, p.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
    fallar(errores, "sin oficio no se activa", mundo:alternarOficio(p) ~= nil and p.job == nil)
    p.oficioElegido, p.oficios = "trader", { trader = { nivel = 1, xp = 0 } }
    fallar(errores, "elegido pero inactivo no comercia", mundo:comprarBien(p, "trigo", 1) == "Activa tu oficio con la tecla Y.")
    fallar(errores, "se activa", mundo:alternarOficio(p) == nil and p.job == "trader")
    fallar(errores, "la foto lleva el oficio activo", (function()
      for _, e in ipairs(mundo:foto(p.id).ents) do if e.id == p.id then return e.job == "trader" end end
      return false
    end)())
    p.carga = { trigo = 3 }
    mundo:recalcularCarga(p)
    fallar(errores, "con carga no se desactiva", mundo:alternarOficio(p) ~= nil and p.job == "trader")
    p.carga = {}
    mundo:recalcularCarga(p)
    fallar(errores, "sin carga se desactiva", mundo:alternarOficio(p) == nil and p.job == nil and p.oficioElegido == "trader")
    -- se guarda el oficio elegido; al volver empieza desactivado, salvo con carga
    local otra = mundo:crearPersonaje({ nombre = "Activo2", faccion = "albor", clase = "guerrero" })
    mundo:aplicarGuardado(otra, mundo:exportar(p))
    fallar(errores, "al volver el oficio está desactivado", otra.oficioElegido == "trader" and otra.job == nil)
    p.carga = { trigo = 2 }
    local tercera = mundo:crearPersonaje({ nombre = "Activo3", faccion = "albor", clase = "guerrero" })
    mundo:aplicarGuardado(tercera, mundo:exportar(p))
    fallar(errores, "con carga vuelve activo para poder venderla", tercera.job == "trader")
  end)
  paso("botín por separado y mercancía del comerciante muerto", function()
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local pu = mundo.mapas.mundo.puestos[1]
    local function jug(nombre, faccion, job)
      local e = mundo:crearPersonaje({ nombre = nombre, faccion = faccion, clase = "guerrero", nivel = 14 })
      e.x, e.y, e.z, e.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
      e.job, e.oficioElegido, e.oficios = job, job, { [job or "trader"] = { nivel = 1, xp = 0 } }
      return e
    end
    -- una criatura suelta cada objeto por separado
    local cazador = jug("Caza", "albor", nil)
    local piezas = 0
    for _ = 1, 40 do
      local m = mundo:spawnMonstruo("troll", cazador.x + 1, cazador.y, { x = cazador.x, y = cazador.y })
      m.hp = 1
      mundo:danar(m, 99999, cazador)
    end
    local sueltos, conVarios = 0, false
    for _, o in pairs(mundo.entidades) do
      if o.kind == "loot" then
        sueltos = sueltos + 1
        if #o.items > 1 then conVarios = true end
      end
    end
    fallar(errores, "cada objeto cae en su propio sitio", sueltos > 40 and not conVarios, tostring(sueltos))
    for _, o in pairs(mundo.entidades) do if o.kind == "loot" then o.borrar = true end end
    mundo:actualizar(0.1)
    -- el comerciante muere cargado
    local t = jug("Mercader", "albor", "trader")
    t.carga = { trigo = 5, vino = 2 }
    mundo:recalcularCarga(t)
    local asesino = jug("Ladron", "umbra", "thief")
    asesino.x, asesino.y = t.x + 3, t.y
    mundo:morir(t, asesino)
    local fardos, total = 0, 0
    for _, o in pairs(mundo.entidades) do
      if o.kind == "loot" and o.bienes then
        fardos = fardos + 1
        for _, c in pairs(o.bienes) do total = total + c end
      end
    end
    fallar(errores, "la mercancía cae al suelo", fardos == 2 and total == 7 and next(t.carga) == nil, fardos .. "/" .. total)
    fallar(errores, "al comerciante no le queda carga", (t.pesoCarga or 0) == 0)
    -- el ladrón la recoge: va a su carga robada
    for _, o in pairs(mundo.entidades) do
      if o.kind == "loot" and o.bienes then asesino.x, asesino.y = o.x, o.y; mundo:recoger(asesino, o) end
    end
    local robado = 0
    for _, c in pairs(asesino.cargaRobada or {}) do robado = robado + c end
    fallar(errores, "el ladrón carga lo caído", robado == 7 or robado == (asesino.capacidadCarga or 0), tostring(robado))
    -- quien no es comerciante ni ladrón no puede cargarla
    local t2 = jug("Mercader2", "albor", "trader")
    t2.carga = { hierro = 3 }
    mundo:recalcularCarga(t2)
    mundo:morir(t2, nil)
    local pasante = jug("Pasante", "albor", nil)
    for _, o in pairs(mundo.entidades) do
      if o.kind == "loot" and o.bienes and o.bienes.hierro then pasante.x, pasante.y = o.x, o.y; mundo:recoger(pasante, o) end
    end
    fallar(errores, "otro oficio no la carga", next(pasante.carga or {}) == nil and next(pasante.cargaRobada or {}) == nil)
  end)
  paso("comandos de administrador", function()
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local afuera = mundo.mapas.mundo.puestos[1]
    local function jug(nombre, faccion)
      local e = mundo:crearPersonaje({ nombre = nombre, faccion = faccion, clase = "guerrero", nivel = 12 })
      e.x, e.y, e.z, e.modo = afuera.x + 8.5, afuera.y + 8.5, 0, "mundo"
      return e
    end
    local adm, rival, normal = jug("Admi", "albor"), jug("Otro", "umbra"), jug("Normal", "albor")
    adm.admin = true
    local function cuentaMobs(id) local n = 0 for _, m in pairs(mundo.entidades) do if m.kind == "monstruo" and m.monstruo == id then n = n + 1 end end return n end
    mundo:decir(normal, "/admin mob gato 3")
    fallar(errores, "un jugador normal no puede", cuentaMobs("gato") == 0)
    mundo:decir(adm, "/admin mob gato 3 7")
    fallar(errores, "invoca criaturas con nivel", cuentaMobs("gato") == 3)
    mundo:decir(adm, "/admin mob gato 500")
    fallar(errores, "tope de invocación", cuentaMobs("gato") <= 3 + require("compartido.dominio.admin").MAX_CRIATURAS)
    mundo:decir(adm, "/admin mob noexiste")
    mundo:decir(adm, "/admin item pocion_vida 5 Normal")
    local tiene = 0
    for _, s in ipairs(normal.bolsa) do if s.id == "pocion_vida" then tiene = tiene + s.cant end end
    local idPocion = Datos.item("pocion_vida") and true or false
    fallar(errores, "da objetos a otro jugador", not idPocion or tiene >= 5, tostring(tiene))
    mundo:decir(adm, "/admin oro 250")
    fallar(errores, "da oro", adm.oro >= 250)
    mundo:decir(adm, "/admin nivel 25")
    fallar(errores, "fija el nivel", adm.nivel == 25)
    mundo:decir(adm, "/admin tp 100 100")
    fallar(errores, "se teletransporta", math.floor(adm.x) >= 99 and math.floor(adm.x) <= 102)
    mundo:decir(adm, "/admin traer Otro")
    fallar(errores, "trae a un jugador", math.abs(rival.x - adm.x) < 3)
    mundo:decir(adm, "/admin dios")
    local hp = adm.hp
    mundo:danar(adm, 30, nil)
    fallar(errores, "invulnerable", adm.hp == hp)
    mundo:decir(adm, "/admin dios")
    mundo:decir(adm, "/admin limpiar 60")
    local vivos = 0
    for _, m in pairs(mundo.entidades) do if m.kind == "monstruo" and m.vivo and not m.borrar and require("compartido.dominio.util").dist(m.x, m.y, adm.x, adm.y) <= 60 then vivos = vivos + 1 end end
    fallar(errores, "limpia criaturas", vivos == 0, tostring(vivos))
    -- evento sin esperar a nadie
    mundo:decir(adm, "/admin evento estandarte iniciar todos")
    fallar(errores, "inicia el evento", mundo.instancia.estandarte.activa and adm.modo == "estandarte" and rival.modo == "estandarte")
    mundo:decir(adm, "/admin evento estandarte fin")
    fallar(errores, "termina el evento", mundo.instancia.estandarte.fin ~= nil)
    mundo:decir(adm, "/admin anuncio hola a todos")
    local visto = false
    for _, m in ipairs(mundo.mensajes) do if m.texto == "hola a todos" and m.canal == "mundo" then visto = true end end
    fallar(errores, "anuncia", visto)
    local ok = pcall(function() mundo:decir(adm, "/admin cosa rara") mundo:decir(adm, "/admin") mundo:decir(adm, "/admin item") mundo:decir(adm, "/admin oro x") end)
    fallar(errores, "los comandos mal escritos no rompen", ok)
    -- el servidor marca admins por cuenta
    local Servicio = require("src.aplicacion.servicio_servidor")
    local m2 = Servicio.crearMundo({ admin = { usuarios = { jefe = true } } })
    fallar(errores, "el servidor guarda las cuentas admin", m2.admins.jefe == true and Servicio.crearMundo().admins.jefe == nil)
  end)
  paso("ciudades seguras y pérdida de experiencia al morir", function()
    local Balance = require("compartido.dominio.balance")
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local ciudad = mundo.mapas.mundo.ciudades[1]
    local afuera = mundo.mapas.mundo.puestos[1]
    local function jug(nombre, faccion, nivel)
      local e = mundo:crearPersonaje({ nombre = nombre, faccion = faccion, clase = "guerrero", nivel = nivel })
      e.modo, e.z = "mundo", 0
      return e
    end
    local function en(e, x, y) e.x, e.y = x, y end
    local a, rival = jug("SegA", ciudad.faccion, 12), jug("SegR", ciudad.faccion == "albor" and "umbra" or "albor", 12)
    en(a, ciudad.spawn.x, ciudad.spawn.y)
    en(rival, ciudad.spawn.x + 1, ciudad.spawn.y)
    fallar(errores, "toda ciudad es santuario, también para la otra corona", mundo:enSantuario(a) and mundo:enSantuario(rival))
    fallar(errores, "no se hiere a un rival dentro de la ciudad", not mundo:puedeDanar(a, rival) and not mundo:puedeDanar(rival, a))
    local fuera = jug("SegF", rival.faccion, 12)
    en(fuera, afuera.x + 8.5, afuera.y + 8.5)
    local g2 = jug("SegG2", ciudad.faccion, 12)
    en(g2, afuera.x + 9.5, afuera.y + 8.5)
    fallar(errores, "fuera de la ciudad sí hay combate", mundo:puedeDanar(fuera, g2))
    local troll = mundo:spawnMonstruo("troll", ciudad.spawn.x + 2, ciudad.spawn.y, { x = ciudad.spawn.x, y = ciudad.spawn.y })
    fallar(errores, "las criaturas no hieren dentro de la ciudad", not mundo:puedeDanar(troll, a))
    -- el buscado por robo sí puede ser perseguido
    mundo:marcarBuscado(rival, 60)
    local guardia = { kind = "guardia", faccion = ciudad.faccion, vivo = true, x = a.x, y = a.y, modo = "mundo", z = 0 }
    fallar(errores, "los guardias persiguen al buscado en la ciudad", mundo:puedeDanar(guardia, rival))
    fallar(errores, "pero no a un inocente", not mundo:puedeDanar(guardia, a))
    -- pérdida de experiencia
    local v = jug("Vet", ciudad.faccion, 15)
    en(v, afuera.x + 8.5, afuera.y + 8.5)
    v.xp = 100000
    local pierde = math.floor(require("compartido.dominio.datos").xpPara(15) * Balance.MUERTE_XP_PERDIDA)
    mundo:morir(v, nil)
    fallar(errores, "sobre el nivel 10 se pierde experiencia al morir", v.xp == 100000 - pierde and v.nivel == 15, tostring(v.xp))
    local nov = jug("Novato", ciudad.faccion, 10)
    en(nov, afuera.x + 8.5, afuera.y + 8.5)
    nov.xp = 50
    mundo:morir(nov, nil)
    fallar(errores, "hasta el nivel 10 no se pierde nada", nov.xp == 50)
    local pobre = jug("Pobre", ciudad.faccion, 20)
    en(pobre, afuera.x + 8.5, afuera.y + 8.5)
    pobre.xp = 3
    mundo:morir(pobre, nil)
    fallar(errores, "la experiencia no baja de cero ni de nivel", pobre.xp == 0 and pobre.nivel == 20)
  end)

  paso("grupos, experiencia compartida y encuentros", function()
    local Grupos = require("compartido.dominio.grupos")
    local Encuentros = require("compartido.dominio.encuentros")
    local Balance = require("compartido.dominio.balance")
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local mapa = mundo.mapas.mundo
    local afuera = mapa.puestos[1]
    local function jug(nombre, faccion, nivel)
      local e = mundo:crearPersonaje({ nombre = nombre, faccion = faccion or "albor", clase = "guerrero", nivel = nivel or 10 })
      e.x, e.y, e.z, e.modo = afuera.x + 8.5, afuera.y + 8.5, 0, "mundo"
      return e
    end
    local a, b, c, d, e5, e6 = jug("G1"), jug("G2"), jug("G3"), jug("G4"), jug("G5"), jug("G6")
    local rival = jug("Rival", "umbra")
    fallar(errores, "máximo de 5 en un grupo", Grupos.MAX == 5)
    -- invitar y aceptar
    fallar(errores, "no se invita a la otra corona", mundo:invitarGrupo(a, rival.id) ~= nil)
    fallar(errores, "invita", mundo:invitarGrupo(a, b.id) == nil and b.invitacionGrupo ~= nil)
    fallar(errores, "acepta y se crea el grupo", mundo:responderInvitacionGrupo(b, true) == nil and a.grupoId == b.grupoId and a.grupoId ~= nil)
    fallar(errores, "el que invitó es el líder", mundo:grupoDe(a).lider == a.id)
    fallar(errores, "un miembro no invita", mundo:invitarGrupo(b, c.id) ~= nil)
    fallar(errores, "no se invita a quien ya tiene grupo", mundo:invitarGrupo(a, b.id) ~= nil)
    for _, x in ipairs({ c, d, e5 }) do
      mundo:invitarGrupo(a, x.id)
      mundo:responderInvitacionGrupo(x, true)
    end
    fallar(errores, "grupo de cinco", #mundo:grupoDe(a).miembros == 5)
    fallar(errores, "el sexto no entra", mundo:invitarGrupo(a, e6.id) ~= nil)
    -- invitaciones que caducan o se rechazan
    mundo:salirGrupo(e5)
    mundo:invitarGrupo(a, e5.id)
    mundo.tiempo = mundo.tiempo + Grupos.INVITACION_SEG + 5
    fallar(errores, "la invitación caduca", mundo:responderInvitacionGrupo(e5, true) ~= nil and e5.grupoId == nil)
    mundo:invitarGrupo(a, e5.id)
    fallar(errores, "rechazar no entra", mundo:responderInvitacionGrupo(e5, false) == nil and e5.grupoId == nil)
    -- reparto de experiencia entre tres cerca (d y c salen del grupo para fijar el caso)
    mundo:salirGrupo(d)
    mundo:salirGrupo(c)
    mundo:invitarGrupo(a, c.id)
    mundo:responderInvitacionGrupo(c, true)
    for _, x in ipairs({ a, b, c }) do x.xp, x.oro, x.misiones = 0, 0, {} end
    b.misiones = { q = { aceptada = true, entregada = false, monstruo = "gato", cantidad = 5, progreso = 0, titulo = "t" } }
    local gato = mundo:spawnMonstruo("troll", a.x + 1, a.y, { x = a.x, y = a.y })
    gato.nivel = 10
    local base = Balance.xpMonstruo(10, 10, false)
    local esperado = math.floor(base * (1 + Grupos.BONO_XP) / 3 + 0.5)
    gato.hp = 1
    mundo:danar(gato, 99999, a)
    fallar(errores, "cada uno recibe su parte con el 10% extra", a.xp == esperado and b.xp == esperado and c.xp == esperado,
      a.xp .. "/" .. b.xp .. "/" .. c.xp .. " (esperado " .. esperado .. ")")
    fallar(errores, "el grupo gana en total más que uno solo, pero cada uno menos", a.xp * 3 > base and a.xp < base)
    fallar(errores, "el oro también se reparte", a.oro > 0 and a.oro == b.oro and b.oro == c.oro)
    -- los que están lejos no cuentan
    for _, x in ipairs({ a, b, c }) do x.xp = 0 end
    c.x = a.x + 200
    local gato2 = mundo:spawnMonstruo("troll", a.x + 1, a.y, { x = a.x, y = a.y })
    gato2.nivel, gato2.hp = 10, 1
    mundo:danar(gato2, 99999, a)
    local esperado2 = math.floor(base * (1 + Grupos.BONO_XP) / 2 + 0.5)
    fallar(errores, "solo reparten los que están cerca", a.xp == esperado2 and b.xp == esperado2 and c.xp == 0, a.xp .. "/" .. b.xp .. "/" .. c.xp)
    c.x = a.x
    -- el botín es del grupo
    local botin
    for _, o in pairs(mundo.entidades) do if o.kind == "loot" then botin = o end end
    fallar(errores, "el botín lleva la marca del grupo", botin and botin.grupo == a.grupoId)
    -- solo (sin compañeros cerca) todo es como siempre
    local solo = jug("Solitario")
    solo.xp = 0
    local gato3 = mundo:spawnMonstruo("troll", solo.x + 1, solo.y, { x = solo.x, y = solo.y })
    gato3.nivel, gato3.hp = 10, 1
    mundo:danar(gato3, 99999, solo)
    fallar(errores, "sin grupo se lleva toda la experiencia", solo.xp == base, solo.xp .. " vs " .. base)
    -- chat de grupo
    mundo:decir(a, "/p al ataque")
    local function ve(p, texto) for _, m in ipairs(mundo:foto(p.id).msgs) do if m.texto == texto then return true end end return false end
    fallar(errores, "el grupo ve su chat", ve(b, "al ataque") and ve(a, "al ataque"))
    fallar(errores, "los demás no", not ve(solo, "al ataque"))
    -- la foto lleva el grupo
    local tu = mundo:foto(a.id).tu
    fallar(errores, "la foto trae el grupo", tu.grupo and #tu.grupo.miembros == 3 and tu.grupo.lider == a.id)
    -- líder: pasar el mando, expulsar, salir
    fallar(errores, "pasa el mando", mundo:ascenderGrupo(a, b.id) == nil and mundo:grupoDe(a).lider == b.id)
    fallar(errores, "solo el líder expulsa", mundo:expulsarGrupo(a, c.id) ~= nil)
    fallar(errores, "el líder expulsa", mundo:expulsarGrupo(b, c.id) == nil and c.grupoId == nil)
    fallar(errores, "un grupo de dos sigue", mundo:grupoDe(a) ~= nil and #mundo:grupoDe(a).miembros == 2)
    fallar(errores, "al irse el líder el grupo de dos se disuelve", mundo:salirGrupo(b) == nil and a.grupoId == nil and b.grupoId == nil)
    -- si alguien se desconecta se le quita del grupo
    mundo:invitarGrupo(a, b.id)
    mundo:responderInvitacionGrupo(b, true)
    mundo:invitarGrupo(a, c.id)
    mundo:responderInvitacionGrupo(c, true)
    c.borrar = true
    mundo._grupoT = 5
    mundo:actualizarGrupos(1)
    fallar(errores, "el desconectado sale del grupo", #mundo:grupoDe(a).miembros == 2)
    mundo.entidades[c.id] = nil
    -- encuentros: criaturas de grupo y gigantes
    local normal = Datos.statsMonstruo({ nivel = 12 }).hp
    fallar(errores, "los jefes de grupo tienen mucha más vida", Datos.statsMonstruo({ nivel = 12, hpMul = 3.5 }).hp >= normal * 3)
    fallar(errores, "los gigantes aún más", Datos.statsMonstruo({ nivel = 12, tam = 2, hpMul = 4.5 }).hp >= normal * 7)
    local g = mundo:grupoDe(a)
    g.proximoEncuentro = 0
    local f = jug("G7")
    mundo:invitarGrupo(a, f.id)
    mundo:responderInvitacionGrupo(f, true)
    g.proximoEncuentro = 0
    local azar = math.random
    math.random = function(x, y) if x then return y or 1 end return 0.99 end
    mundo._encT = 10
    local ok = pcall(function() mundo:actualizarEncuentros(1) end)
    math.random = azar
    fallar(errores, "el encuentro se crea sin errores", ok)
    local principal
    for _, m in pairs(mundo.entidades) do
      if m.kind == "monstruo" and m.categoria then principal = m end
    end
    fallar(errores, "sale una criatura de grupo", principal and principal.categoria == "party" and principal.xpMul == 4 and principal.efimero ~= nil)
    fallar(errores, "con su nivel fijado al del grupo", principal and principal.nivel >= 10 and principal.nivel <= 12)
    fallar(errores, "el grupo sabe cuál es su encuentro", g.encuentro and #g.encuentro >= 1)
    -- con el grupo grande y suerte sale un gigante
    local grande = jug("G8")
    local grande2 = jug("G9")
    for _, x in ipairs({ grande, grande2 }) do mundo:invitarGrupo(a, x.id) mundo:responderInvitacionGrupo(x, true) end
    for _, m in pairs(mundo.entidades) do if m.kind == "monstruo" then m.borrar = true end end
    mundo:actualizar(0.1)
    g.encuentro, g.proximoEncuentro = nil, 0
    math.random = function(x, y) if x then return y or 1 end return 0.01 end
    mundo._encT = 10
    pcall(function() mundo:actualizarEncuentros(1) end)
    math.random = azar
    local gigante
    for _, m in pairs(mundo.entidades) do
      if m.kind == "monstruo" and m.categoria == "gigante" then gigante = m end
    end
    fallar(errores, "con un grupo grande puede salir un gigante", gigante and gigante.xpMul == 10 and gigante.tam == 2)
    fallar(errores, "el gigante es mucho más fuerte que su nivel", gigante and gigante.hpMax >= Datos.statsMonstruo({ nivel = gigante.nivel }).hp * 7)
    -- la recompensa de un gigante: experiencia repartida y botín bueno
    if gigante then
      for _, x in ipairs(mundo:miembrosGrupo(g)) do x.xp = 0 end
      local lider = mundo.entidades[g.lider]
      gigante.hp = 1
      mundo:danar(gigante, 99999, lider)
      local ganada = lider.xp
      local solo2 = Balance.xpMonstruo(lider.nivel, gigante.nivel, false) * 10
      fallar(errores, "el gigante da mucha experiencia, repartida", ganada > 0 and ganada < solo2, ganada .. " vs " .. solo2)
      local polvo = false
      for _, o in pairs(mundo.entidades) do
        if o.kind == "loot" then for _, it in ipairs(o.items) do if it.id == "polvo_arcano" and it.cant >= 3 then polvo = true end end end
      end
      fallar(errores, "el gigante suelta botín bueno", polvo)
    end
    -- en una ciudad no salen encuentros
    local ciudad = mapa.ciudades[1]
    for _, x in ipairs(mundo:miembrosGrupo(g)) do x.x, x.y = ciudad.spawn.x, ciudad.spawn.y end
    for _, m in pairs(mundo.entidades) do if m.kind == "monstruo" then m.borrar = true end end
    mundo:actualizar(0.1)
    g.encuentro, g.proximoEncuentro = nil, 0
    mundo._encT = 10
    mundo:actualizarEncuentros(1)
    local hay = false
    for _, m in pairs(mundo.entidades) do if m.kind == "monstruo" and m.categoria then hay = true end end
    fallar(errores, "dentro de la ciudad no salen", not hay)
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
    mago.x, mago.y = mundo.mapas.mundo.puestos[1].x + 8.5, mundo.mapas.mundo.puestos[1].y + 8.5
    local victima = mundo:spawnMonstruo("oso", mago.x + 2, mago.y, { x = mago.x, y = mago.y })
    victima.hp, victima.hpMax = 5000, 5000
    victima.agresivo, victima.def, victima.mdef = false, 0, 0
    victima.cds = victima.cds or {}
    victima.cds.auto = 1e9 -- no devuelve golpes: la prueba mide los estados
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
    for _, m in pairs(mundo.entidades) do if m.kind == "monstruo" and m ~= victima then m.borrar = true end end
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
        pj.job, pj.oficioElegido, pj.oficios = "trader", "trader", { trader = { nivel = 3, xp = 40 }, thief = { nivel = 2, xp = 5 } }
        pj.carga, pj.cargaRobada = { vino = 7 }, { gemas = 2 }
        pj.monturas, pj.monturaPreferida = { "buey", "caballo" }, "caballo"
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
          fallar(errores, "recupera el oficio y su nivel", otra.oficioElegido == "trader" and otra.job == "trader" and otra.oficios.trader.nivel == 3 and otra.oficios.trader.xp == 40
            and otra.oficios.thief and otra.oficios.thief.nivel == 2)
          fallar(errores, "recupera la carga y lo robado", otra.carga.vino == 7 and otra.cargaRobada.gemas == 2)
          fallar(errores, "recupera las monturas", #otra.monturas == 2 and otra.monturaPreferida == "caballo")
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
    -- en campo abierto: dentro de la ciudad las criaturas no atacan
    local pu = mundo.mapas.mundo.puestos[1]
    cx, cy = pu.x + 14, pu.y + 6
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
