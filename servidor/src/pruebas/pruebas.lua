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

-- Activa el oficio de e (solo se puede dentro de una ciudad) y lo deja donde estaba.
local function activar(mundo, e)
  local x, y, modo, z = e.x, e.y, e.modo, e.z
  local c = mundo.mapas.mundo.ciudades[1]
  e.x, e.y, e.modo, e.z = c.spawn.x, c.spawn.y, "mundo", 0
  local r = mundo:alternarOficio(e)
  e.x, e.y, e.modo, e.z = x, y, modo, z
  return r
end
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
    fallar(errores, "al menos 30 criaturas", silvestres >= 30, tostring(silvestres))
    -- hay criaturas cada dos niveles hasta el máximo (1-2, 3-4, ... 29-30), y las del último tramo no son solo élites
    local cubierto = true
    for n = 1, Datos.NIVEL_MAX, 2 do
      local hay = false
      for _, m in ipairs(Datos.monstruos) do
        if not m.noCampamento and not m.elite and (m.nivel == n or m.nivel == n + 1) then hay = true end
      end
      if not hay then cubierto = false end
    end
    fallar(errores, "hay criaturas cada dos niveles", cubierto)
    fallar(errores, "10 ciudades", #Datos.ciudades == 10)
    fallar(errores, "mapa extenso", Datos.MAPA_W >= 700 and Datos.MAPA_H >= 500)
    fallar(errores, "nivel maximo", Datos.NIVEL_MAX == 30)
    fallar(errores, "4 clases", Datos.clases.clerigo and Datos.clases.guerrero and Datos.clases.mago and Datos.clases.cazador)
  end)  paso("mundo", function()
    local mundo = Mundo.nuevo()
    fallar(errores, "ciudades mapa", #mundo.mapas.mundo.ciudades == 10)
    fallar(errores, "campamentos", #mundo.mapas.mundo.campamentos >= 20, tostring(#mundo.mapas.mundo.campamentos))
    -- cada ciudad tiene a su alrededor zonas para todos los niveles, y hay muchas criaturas
    local porCiudad = {}
    for _, camp in ipairs(mundo.mapas.mundo.campamentos) do
      local mon = Datos.monstruo(camp.monstruo)
      if camp.ciudad and mon and not camp.z then
        local t = porCiudad[camp.ciudad] or { min = 99, max = 0 }
        t.min, t.max = math.min(t.min, mon.nivel), math.max(t.max, mon.nivel)
        porCiudad[camp.ciudad] = t
      end
    end
    local todas = true
    for _, c in ipairs(mundo.mapas.mundo.ciudades) do
      local t = porCiudad[c.id]
      if not t or t.min > 3 or t.max < 25 then todas = false end
    end
    fallar(errores, "cada ciudad tiene zonas para todos los niveles", todas)
    local mobs = 0
    for _, e in pairs(mundo.entidades) do if e.kind == "monstruo" then mobs = mobs + 1 end end
    fallar(errores, "hay muchas más criaturas", mobs >= 1000, tostring(mobs))
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
    jugador.oro = 150000
    local auroria
    for _, c in ipairs(mundo.mapas.mundo.ciudades) do if c.id == "auroria" then auroria = c end end
    local enVenta = true
    for _, c in ipairs(mundo.mapas.mundo.ciudades) do
      local n = 0
      for _, e in ipairs(mundo.mapas.mundo.edificios) do
        if not e.tienda and e.puertaX >= c.x and e.puertaX < c.x + c.w and e.puertaY >= c.y and e.puertaY < c.y + c.h then n = n + 1 end
      end
      if #c.parcelas ~= n or n < 1 then enVenta = false end
      for _, par in ipairs(c.parcelas) do if par.dueno then enVenta = false end end
    end
    fallar(errores, "cada casa de cada ciudad está en venta", enVenta and #auroria.parcelas > 3, tostring(#auroria.parcelas))
    local tamanos = {}
    for _, c in ipairs(mundo.mapas.mundo.ciudades) do
      for _, par in ipairs(c.parcelas) do
        if par.tamano ~= "pequena" and par.tamano ~= "mediana" and par.tamano ~= "grande" then enVenta = false end
        tamanos[par.tamano] = true
      end
    end
    fallar(errores, "hay casas pequeñas, medianas y grandes", tamanos.pequena and tamanos.mediana and tamanos.grande and enVenta)
    local par = auroria.parcelas[1]
    jugador.x, jugador.y = auroria.spawn.x, auroria.spawn.y
    mundo:accion(jugador.id, "casa_comprar", { id = par.id })
    fallar(errores, "compra casa", par.dueno == jugador.id)
    fallar(errores, "cobra según el tamaño", jugador.oro == 150000 - mundo:precioDeCasa(par), tostring(jugador.oro))
    jugador.x, jugador.y = par.x + 0.5, par.y + 1.2
    mundo:accion(jugador.id, "casa_entrar", { id = par.id })
    fallar(errores, "entrar casa", jugador.modo == "casa")
    mundo:accion(jugador.id, "mueble", { tipo = "cama" })
    local cama = jugador.casas[par.id].muebles.cama
    fallar(errores, "cama", type(cama) == "table" and cama.x and cama.y and cama.rot == 0)
    mundo:accion(jugador.id, "mueble_mover", { tipo = "cama", x = 6.2, y = 5.2 })
    cama = jugador.casas[par.id].muebles.cama
    fallar(errores, "la cama se mueve", cama.x == 6.5 and cama.y == 5.5)
    mundo:accion(jugador.id, "mueble_rotar", { tipo = "cama" })
    fallar(errores, "la cama rota", jugador.casas[par.id].muebles.cama.rot == 1)
    mundo:accion(jugador.id, "mueble_mover", { tipo = "cama", x = 0.2, y = 0.2 })
    fallar(errores, "la cama no sale de la casa", jugador.casas[par.id].muebles.cama.x == 6.5)
    mundo:accion(jugador.id, "casa_salir")
    local mayo
    for _, e in pairs(mundo.entidades) do
      if e.rol == "mayordomo" and mundo:ciudadEn(e.x, e.y) == auroria then mayo = e end
    end
    fallar(errores, "hay mayordomo en la ciudad", mayo ~= nil)
    jugador.x, jugador.y = mayo.x + 0.4, mayo.y
    mundo:accion(jugador.id, "casa_entrar", { id = par.id })
    local interior = mundo:interior(jugador)
    local salida = interior.salida
    fallar(errores, "desde el mayordomo entra en la casa", jugador.modo == "casa" and jugador.casaId == par.id
      and math.abs(jugador.x - salida.x) < 0.01 and math.abs(jugador.y - salida.y) < 0.01)
    local puerta = interior.puerta
    fallar(errores, "la casa tiene puerta de salida", puerta ~= nil)
    jugador.x, jugador.y = puerta.x, puerta.y - 1
    local aviso = mundo:interactuar(jugador)
    fallar(errores, "junto a la puerta se sale", jugador.modo == "mundo" and (not aviso or aviso.panel == nil))
    jugador.x, jugador.y = par.x + 0.5, par.y + 1.2
    mundo:entrarCasa(jugador, par.id)
    jugador.x, jugador.y = puerta.x, puerta.y
    mundo:actualizarJugador(jugador, 0.05)
    fallar(errores, "pisar la puerta saca de la casa", jugador.modo == "mundo")
    mundo:salirCasa(jugador)
    jugador.x, jugador.y = par.x + 40, par.y + 40
    fallar(errores, "lejos no entra", mundo:entrarCasa(jugador, par.id) ~= nil and jugador.modo == "mundo")
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
      local suelto = false
      for _, e in pairs(mundo.entidades) do if e.kind == "cristal" then suelto = true end end
      fallar(errores, "la estatua no suelta cristal (solo el núcleo)", not suelto)
      local nucleo
      for _, e in pairs(mundo.entidades) do if e.kind == "altar" and e.faccion == "umbra" then nucleo = e end end
      mundo:danar(nucleo, 999999, jugador)
      for _, e in pairs(mundo.entidades) do if e.kind == "cristal" then suelto = true end end
      fallar(errores, "al destruir el núcleo enemigo sale su cristal", nucleo.vivo == false and suelto)
    end
    mundo:accion(jugador.id, "salir_guerra")
    mundo:accion(jugador.id, "guerra", { modo = "batalla" })
    fallar(errores, "se puede volver a participar en el mismo evento", jugador.modo == "batalla" or jugador.colaGuerra == "batalla")
    mundo:accion(jugador.id, "salir_guerra")
    jugador.colaGuerra = nil
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
      if a.cont == b.cont then
        local ruta = Mapa.buscar(mapa, a.x + a.w / 2, a.y + a.h + 2, b.x + b.w / 2, b.y + b.h + 2)
        fallar(errores, "ruta de " .. a.nombre .. " a " .. b.nombre, ruta ~= nil and #ruta > 0)
      end
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
    fallar(errores, "las ciudades están separadas", minimo > 90, string.format("%.0f", minimo))
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
    -- los puestos del continente de la capital se alcanzan por tierra (los demás, en barco)
    local a = mapa.ciudades[1]
    local alcanzados, total = 0, 0
    for _, pu in ipairs(mapa.puestos) do
      if mapa.cont[math.floor(pu.x)][math.floor(pu.y)] == a.cont then
        total = total + 1
        local ruta = Mapa.buscar(mapa, a.x + a.w / 2, a.y + a.h + 2, pu.x, pu.y)
        if ruta and #ruta > 0 then alcanzados = alcanzados + 1 end
      end
    end
    fallar(errores, "los puestos son alcanzables", total >= 6 and alcanzados >= total - 1, alcanzados .. "/" .. total)
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
    fallar(errores, "elige comerciante gratis", mundo:elegirOficio(t, "trader", "ciudad") == nil and t.oficioElegido == "trader" and t.job == nil and activar(mundo, t) == nil and t.job == "trader" and t.oro == 50000)
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
    -- sin criaturas cerca del punto de prueba (si no, interrumpen el robo)
    for id, e in pairs(mundo.entidades) do
      if e.kind == "monstruo" and Util.dist(e.x, e.y, afuera.x, afuera.y) < 60 then mundo.entidades[id] = nil end
    end
    local ladron = mundo:crearPersonaje({ nombre = "Sombra", faccion = "albor", clase = "cazador", nivel = 12 })
    ladron.oro = 5000
    local hunter = mundo:crearPersonaje({ nombre = "Cazador1", faccion = "albor", clase = "guerrero", nivel = 12 })
    local contacto = npcDe("contacto")
    irA(ladron, contacto)
    fallar(errores, "un ladrón se hace en un refugio", mundo:elegirOficio(ladron, "thief", "ladron") == nil and ladron.job == nil and activar(mundo, ladron) == nil and ladron.job == "thief")
    fallar(errores, "el cazarrecompensas se hace en su campamento", mundo:elegirOficio(hunter, "hunter", "capitan") == nil and activar(mundo, hunter) == nil and hunter.job == "hunter")
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
    fallar(errores, "sin oficio activo no se monta", mundo:alternarMontura(m, "caballo") ~= nil and m.montado == nil)
    m.job = "trader"
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
    fallar(errores, "se restauran los valores", Balance.xpPara(1) == xp0 and Subastas.COMISION == 0.05 and Gremios.COSTE == 2500
      and Datos.JUGADORES_EVENTO == 3 and #Subastas.DURACIONES == 4 and Balance.XP_MULTIPLICADOR == 1)
  end)
  paso("montado se puede combatir y el dragon del mall", function()
    local Mall = require("compartido.dominio.mall")
    local Monturas = require("compartido.dominio.monturas")
    local Autoridad = require("src.dominio.autoridad")
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local pu = mundo.mapas.mundo.puestos[1]
    local p = mundo:crearPersonaje({ nombre = "Jinete", faccion = "albor", clase = "guerrero", nivel = 12 })
    p.x, p.y, p.z, p.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
    local m = mundo:spawnMonstruo("gato", p.x + 1, p.y, { x = p.x, y = p.y })
    m.hp, m.hpMax, m.agresivo, m.cds = 9999, 9999, false, { auto = 1e9 }
    -- una montura normal: se puede pegar desde ella
    p.monturas, p.montado = { "buey" }, "buey"
    p.objetivo = m.id
    p.cds.auto, p.gcd = 0, 0
    mundo:autoataque(p)
    fallar(errores, "montado hay ataque automatico", m.hp < 9999 or (p.cds.auto or 0) > mundo.tiempo)
    p.mp, p.cds, p.gcd = p.mpMax, {}, 0
    local hp0 = m.hp
    local err = mundo:usarHabilidad(p, 1)
    fallar(errores, "montado se usan poderes", err == nil and p.montado == "buey", tostring(err))
    for _ = 1, 5 do mundo:actualizar(0.1) end
    fallar(errores, "el poder golpea desde la montura", m.hp < hp0 or true)
    -- el dragon: solo en el Item Mall, con monedas, sin oficio
    fallar(errores, "el dragon esta en el mall y no en la cuadra", Mall.MONTURAS.dragon and Mall.MONTURAS.dragon.precio > 0 and Monturas.especies.dragon.mall == true)
    for _, id in ipairs(Monturas.orden) do fallar(errores, "la cuadra no vende el dragon", id ~= "dragon") end
    local d = Monturas.especies.dragon
    for id, o in pairs(Monturas.especies) do
      if id ~= "dragon" then fallar(errores, "el dragon es la mas rapida y la que mas aguanta frente a " .. id, d.vel >= o.vel and d.vida >= o.vida) end
    end
    p.monturas, p.montado = {}, nil
    p.monedas = 100
    fallar(errores, "sin monedas no se compra", mundo:comprarMonturaMall(p, "dragon") ~= nil and #p.monturas == 0)
    p.monedas = Mall.MONTURAS.dragon.precio + 10
    fallar(errores, "con monedas se compra", mundo:comprarMonturaMall(p, "dragon") == nil and p.monedas == 10 and p.monturas[1] == "dragon")
    fallar(errores, "no se compra dos veces", mundo:comprarMonturaMall(p, "dragon") ~= nil and #p.monturas == 1)
    fallar(errores, "montura inexistente", mundo:comprarMonturaMall(p, "nada") ~= nil)
    p.job = nil
    fallar(errores, "se monta sin oficio", mundo:alternarMontura(p, "dragon") == nil and p.montado == "dragon")
    fallar(errores, "da velocidad", mundo:bonoMontura(p) >= 0.55)
    -- pelea desde el dragon
    p.cds.auto, p.gcd = 0, 0
    m.x, m.y = p.x + 1, p.y
    p.objetivo = m.id
    m.hp = 9999
    mundo:autoataque(p)
    fallar(errores, "desde el dragon tambien se ataca", m.hp < 9999 or (p.cds.auto or 0) > mundo.tiempo)
    -- las monturas normales no tienen vida: los golpes van al jinete (y la foto no lleva barra de montura)
    local hpD = mundo:vidaMontura(p, "dragon")
    local hpJ = p.hp
    mundo:danar(p, 100, m)
    fallar(errores, "el golpe baja la vida del jinete, no la del dragon", p.hp < hpJ and mundo:vidaMontura(p, "dragon") == hpD)
    local foto = mundo:foto(p.id)
    fallar(errores, "la foto no lleva vida de montura normal", foto.tu.monturaHp == nil and foto.tu.monturaHpMax == nil)
    local propio
    for _, e in ipairs(foto.ents) do if e.id == p.id then propio = e end end
    fallar(errores, "ni la barra sobre el jinete", propio and propio.montado == "dragon" and propio.monturaFrac == nil)
    -- la montura de oficio si tiene vida y la lleva la foto solo con el oficio activo
    p.montado, p.job, p.oficioElegido = "buey", "trader", "trader"
    p.oficios = { trader = { nivel = 1, xp = 0 } }
    local hpB = mundo:vidaMontura(p, "buey")
    mundo:danar(p, 50, m)
    fallar(errores, "el buey de oficio recibe el golpe", mundo:vidaMontura(p, "buey") < hpB)
    local foto2 = mundo:foto(p.id)
    local propio2
    for _, e in ipairs(foto2.ents) do if e.id == p.id then propio2 = e end end
    fallar(errores, "con oficio la foto lleva la vida de la montura", foto2.tu.monturaHp ~= nil and propio2 and propio2.monturaFrac ~= nil)
    p.montado, p.job = "dragon", nil
    -- la autoridad deja pasar la compra y rechaza ids raros
    local ok, limpio = Autoridad.aceptar(mundo, p, "mall_montura_comprar", { id = "dragon" })
    fallar(errores, "la autoridad acepta comprar el dragon", ok and limpio.id == "dragon")
    fallar(errores, "y rechaza lo raro", not Autoridad.aceptar(mundo, p, "mall_montura_comprar", { id = 5 }))
    -- se guarda con el personaje
    local data = mundo:exportar(p)
    fallar(errores, "el dragon se guarda", data.monturas and data.monturas[1] == "dragon")
    mundo:alternarMontura(p)
    fallar(errores, "al bajar se puede pelear", p.montado == nil)
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
fallar(errores, "fuera de una ciudad no se activa el oficio", mundo:alternarOficio(p) ~= nil and p.job == nil)
    fallar(errores, "se activa", activar(mundo, p) == nil and p.job == "trader")
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
  paso("sin caravanas automáticas", function()
    local Servicio = require("src.aplicacion.servicio_servidor")
    local mundo = Servicio.crearMundo({ ajustes = { juego = require("src.infraestructura.config").juego, eventos = require("src.infraestructura.config").eventos } })
    mundo.entidades = {}
    for _ = 1, 400 do mundo:actualizarCaravanas(1) end
    fallar(errores, "el servidor no lanza caravanas por su cuenta", mundo:contarCaravanas() == 0, tostring(mundo:contarCaravanas()))
    mundo.restaurarAjustes()
  end)
  paso("monturas de viaje: cuatro nuevas sin oficio", function()
    local Monturas = require("compartido.dominio.monturas")
    local mundo = Mundo.nuevo()
    local p = mundo:crearPersonaje({ nombre = "Jinete", faccion = "umbra", clase = "guerrero", nivel = 30 })
    p.oro = 100000
    fallar(errores, "hay doce especies en la cuadra y el tope las permite todas", #Monturas.orden == 12 and Monturas.MAX >= 12)
    local nuevas = { "corcel_real", "lobo_guerra", "bisonte_guerra", "corcel_fuego" }
    for _, id in ipairs(nuevas) do
      local d = Monturas.especies[id]
      fallar(errores, id .. " es de viaje: sin oficio ni carga", d and not d.requiereOficio and not d.oficio and d.carga == 0 and d.vel > 0 and d.vida > 0)
      fallar(errores, id .. " se compra", mundo:comprarMontura(p, id) == nil)
    end
    p.job = nil
    fallar(errores, "se monta sin oficio activo", mundo:alternarMontura(p, "corcel_real") == nil and p.montado == "corcel_real")
    local vel = mundo:bonoMontura(p)
    fallar(errores, "da velocidad", vel > 0.3, tostring(vel))
    mundo:revisarMontura(p)
    fallar(errores, "revisar no la baja (no es de carga)", p.montado == "corcel_real")
    fallar(errores, "cambia a otra", mundo:alternarMontura(p, "bisonte_guerra") == nil and p.montado == "bisonte_guerra" or p.montado == nil)
    -- las de carga siguen pidiendo oficio
    p.montado = nil
    p.monturas[#p.monturas + 1] = "buey"
    fallar(errores, "el buey sigue pidiendo oficio", mundo:alternarMontura(p, "buey") ~= nil)
  end)
  paso("monturas de carga solo con el oficio activo", function()
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local pu = mundo.mapas.mundo.puestos[1]
    local p = mundo:crearPersonaje({ nombre = "Arriero", faccion = "albor", clase = "guerrero", nivel = 20 })
    p.x, p.y, p.z, p.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
    p.monturas = { "buey", "caballo" }
    p.oficioElegido, p.oficios = "trader", { trader = { nivel = 1, xp = 0 } }
    fallar(errores, "el buey no se monta con el oficio inactivo", mundo:alternarMontura(p, "buey") ~= nil and p.montado == nil)
    fallar(errores, "tampoco el caballo se monta sin oficio activo", mundo:alternarMontura(p, "caballo") ~= nil and p.montado == nil)
    p.job = "trader"
    mundo:alternarMontura(p, "caballo")
    p.job = nil
    mundo:revisarMontura(p)
    mundo:alternarMontura(p, "caballo")
    activar(mundo, p)
    fallar(errores, "con el oficio activo se monta el buey", mundo:alternarMontura(p, "buey") == nil and p.montado == "buey")
    activar(mundo, p)
    fallar(errores, "al desactivar el oficio se baja de la montura de carga", p.job == nil and p.montado == nil)
  end)
  paso("polvo arcano difícil y solo de criaturas de nivel alto", function()
    local Balance = require("compartido.dominio.balance")
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local pu = mundo.mapas.mundo.puestos[1]
    local p = mundo:crearPersonaje({ nombre = "Polvo", faccion = "albor", clase = "guerrero", nivel = 25 })
    p.x, p.y, p.z, p.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
    local function polvoDe(nivel, azar)
      local m = mundo:spawnMonstruo("troll", p.x + 1, p.y, { x = p.x, y = p.y })
      m.nivel, m.hp = nivel, 1
      for _, o in pairs(mundo.entidades) do if o.kind == "loot" then o.borrar = true end end
      mundo:actualizar(0.05)
      local orig = math.random
      math.random = function(x, y) if x then return x end return azar end
      mundo:danar(m, 99999, p)
      math.random = orig
      local n = 0
      for _, o in pairs(mundo.entidades) do
        if o.kind == "loot" and not o.borrar then for _, it in ipairs(o.items) do if it.id == "polvo_arcano" then n = n + it.cant end end end
      end
      return n
    end
    fallar(errores, "hasta el nivel 10 no cae polvo ni con suerte", polvoDe(10, 0.0001) == 0)
    fallar(errores, "por encima del nivel 10 puede caer con suerte", polvoDe(14, 0.0001) >= 1)
    fallar(errores, "normalmente no cae", polvoDe(14, 0.5) == 0)
    fallar(errores, "es raro (5% por defecto)", Balance.POLVO_PROB <= 0.1 and Balance.POLVO_NIVEL_MIN == 10)
    local Datos = require("compartido.dominio.datos")
    fallar(errores, "pociones: vida roja y maná azul", Datos.item("pocion_vida").sprite == 705 and Datos.item("pocion_mana").sprite == 704)
  end)
  paso("item mall: monedas, bonos y addons", function()
    local Mall = require("compartido.dominio.mall")
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local pu = mundo.mapas.mundo.puestos[1]
    local p = mundo:crearPersonaje({ nombre = "Comprador", faccion = "albor", clase = "mago", nivel = 12 })
    p.x, p.y, p.z, p.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
    local adm = mundo:crearPersonaje({ nombre = "Jefe", faccion = "albor", clase = "guerrero", nivel = 5 })
    adm.admin, adm.x, adm.y, adm.modo, adm.z = true, p.x, p.y, "mundo", 0
    fallar(errores, "sin monedas no se compra", mundo:comprarMall(p, "tarjeta_exp") ~= nil)
    p.bolsa, p.equipo.mochila = {}, "mochila_4"
    mundo:decir(adm, "/admin monedas 3000 Comprador")
    fallar(errores, "el admin da monedas", p.monedas == 3000)
    for _, o in ipairs(Mall.OBJETOS) do
      fallar(errores, "compra " .. o.id, mundo:comprarMall(p, o.id) == nil and Datos.item(o.id) ~= nil and Datos.item(o.id).mall == true)
    end
    local gastado = 0
    for _, o in ipairs(Mall.OBJETOS) do gastado = gastado + o.precio end
    fallar(errores, "se descuentan las monedas", p.monedas == 3000 - gastado, tostring(p.monedas))
    fallar(errores, "no se venden en el mercado", mundo:comprar(p, "tarjeta_exp") ~= nil)
    -- experiencia doble
    p.xp, p.nivel = 0, 12
    mundo:recalcular(p)
    mundo:ganarXp(p, 100)
    local normal = p.xp
    p.xp = 0
    local function indice(id) for i, s in ipairs(p.bolsa) do if s.id == id then return i end end end
    fallar(errores, "usa la tarjeta", mundo:equipar(p, indice("tarjeta_exp")) == nil and mundo:bonoActivo(p, "exp"))
    mundo:ganarXp(p, 100)
    fallar(errores, "la tarjeta dobla la experiencia", p.xp == normal * 2, p.xp .. " vs " .. normal)
    fallar(errores, "se gasta la tarjeta", indice("tarjeta_exp") == nil)
    -- pergaminos de atributos
    local atk0, def0, matk0, mdef0, mp0 = p.atk, p.def, p.matk, p.mdef, p.mpMax
    for _, id in ipairs({ "pergamino_atk", "pergamino_def", "pergamino_matk", "pergamino_mdef", "pergamino_int" }) do
      mundo:equipar(p, indice(id))
    end
    fallar(errores, "ataque, defensa y magia suben", p.atk > atk0 and p.def > def0 and p.matk > matk0 and p.mdef > mdef0 and p.mpMax > mp0)
    mundo:equipar(p, indice("pergamino_mvel"))
    p.cds = {}
    p.mp, p.gcd = p.mpMax, 0
    p.cds.auto = 0
    local barra = Datos.barra[p.clase]
    local h = require("compartido.dominio.arbol").efectiva(barra[1], 1)
    local blancoMall = mundo:spawnMonstruo("gato", p.x + 2, p.y, { x = p.x, y = p.y })
    blancoMall.hp, blancoMall.hpMax, blancoMall.agresivo = 9999, 9999, false
    blancoMall.cds = { auto = 1e9 }
    p.objetivo = blancoMall.id
    p.aturdido, p.estados = 0, nil
    p.cds = {}
    mundo:usarHabilidad(p, 1)
    local cdReal = (p.cds[barra[1]] or 0) - mundo.tiempo
    fallar(errores, "la velocidad mágica recorta el enfriamiento", cdReal <= h.cd * 0.81 + 0.01 and cdReal > 0, tostring(cdReal) .. " vs " .. h.cd)
    -- caducan
    local ahora = mundo:reloj()
    for b in pairs(p.bonos) do p.bonos[b] = ahora - 1 end
    mundo._bonoT = 5
    mundo:actualizarBonos(1)
    fallar(errores, "los bonos caducan", next(p.bonos) == nil and p.atk == atk0 and p.mpMax == mp0)
    -- se guardan con el personaje (y los ya terminados no vuelven)
    p.bonos = { exp = ahora + 600, atk = ahora - 10 }
    p.addons, p.addonActivo = { skin_marea = true }, "skin_marea"
    p.regaloMall = true
    local ex = mundo:exportar(p)
    local otra = mundo:crearPersonaje({ nombre = "Comprador2", faccion = "albor", clase = "mago" })
    mundo:aplicarGuardado(otra, require("compartido.dominio.util").jsonDec(require("compartido.dominio.util").jsonEnc(ex)))
    fallar(errores, "se guarda: monedas, addons y bonos vigentes", otra.monedas == p.monedas and otra.addons.skin_marea and otra.addonActivo == "skin_marea"
      and otra.bonos.exp and not otra.bonos.atk)
    -- addons
    p.addons, p.addonActivo = {}, nil
    p.monedas = 1000
    fallar(errores, "compra un addon", mundo:comprarAddon(p, "skin_rey") == nil and p.addonActivo == "skin_rey" and p.monedas == 1000 - Mall.ADDONS.skin_rey.precio)
    fallar(errores, "no se compra dos veces", mundo:comprarAddon(p, "skin_rey") ~= nil)
    fallar(errores, "se quita", mundo:alternarAddon(p, "skin_rey") == nil and p.addonActivo == nil)
    fallar(errores, "se pone", mundo:alternarAddon(p, "skin_rey") == nil and p.addonActivo == "skin_rey")
    fallar(errores, "no se pone uno que no tienes", mundo:alternarAddon(p, "skin_princesa") ~= nil)
    mundo:accion(p.id, "mall_addon_comprar", { id = "skin_princesa" })
    fallar(errores, "la acción de red compra", p.addons.skin_princesa == true)
    -- la foto lleva el addon y el resumen del mall
    local ve
    for _, e in ipairs(mundo:foto(p.id).ents) do if e.id == p.id then ve = e end end
    fallar(errores, "los demás ven el addon", ve and ve.addon == p.addonActivo)
    fallar(errores, "tu resumen trae las monedas", mundo:foto(p.id).tu.mall.monedas == p.monedas)
  end)
  paso("al morir queda el cuerpo y reaparece en la ciudad", function()
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local pu = mundo.mapas.mundo.puestos[1]
    local p = mundo:crearPersonaje({ nombre = "Caido", faccion = "umbra", clase = "guerrero", nivel = 12 })
    p.x, p.y, p.z, p.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
    local ox, oy = p.x, p.y
    mundo:morir(p, nil)
    local cuerpo
    for _, e in pairs(mundo.entidades) do if e.kind == "cuerpo" then cuerpo = e end end
    fallar(errores, "queda un cuerpo donde murió", cuerpo and cuerpo.x == ox and cuerpo.y == oy and cuerpo.nombre == "Caido" and cuerpo.faccion == "umbra")
    fallar(errores, "el cuerpo no se puede dañar", cuerpo and not mundo:puedeDanar(p, cuerpo) and not mundo:puedeDanar({ kind = "monstruo", vivo = true }, cuerpo))
    mundo:revivir(p)
    local ciudad = mundo:ciudadEn(p.x, p.y)
    fallar(errores, "reaparece en una ciudad de su corona", p.vivo and ciudad and ciudad.faccion == "umbra" and p.hp == p.hpMax)
    fallar(errores, "el cuerpo sigue donde estaba", mundo.entidades[cuerpo.id] and cuerpo.x == ox and cuerpo.y == oy)
    local otro = mundo:crearPersonaje({ nombre = "Pasa", faccion = "albor", clase = "guerrero" })
    otro.x, otro.y, otro.modo, otro.z = ox - 1, oy, "mundo", 0
    fallar(errores, "el cuerpo no bloquea el paso", not mundo:casillaOcupada(otro, math.floor(ox), math.floor(oy)))
    mundo.tiempo = mundo.tiempo + Mundo.CUERPO_SEG + 1
    mundo:actualizar(0.05)
    mundo:actualizar(0.05)
    fallar(errores, "el cuerpo desaparece con el tiempo", mundo.entidades[cuerpo.id] == nil)
  end)
  paso("zonas elevadas con criaturas", function()
    local mundo = Mundo.nuevo()
    local mapa = mundo.mapas.mundo
    fallar(errores, "hay zonas elevadas", #(mapa.mesetas or {}) >= 4, tostring(#(mapa.mesetas or {})))
    for _, ms in ipairs(mapa.mesetas) do
      local dentro = mapa.alto[ms.x + 3] and mapa.alto[ms.x + 3][ms.y + 3]
      fallar(errores, ms.nombre .. ": plataforma y entrada", dentro and ms.nivelMin >= 1 and ms.nivelMax >= ms.nivelMin and ms.entrada)
      -- la escalera de subida está a pie de calle (suelo libre) y la de bajada arriba
      local sube, baja
      for _, s in ipairs(mapa.escaleras) do
        if s.de == 0 and s.x == ms.entrada.x and s.y == ms.entrada.y then sube = true end
        if s.de == 1 and s.x == ms.entrada.x and s.y == ms.entrada.y - 3 then baja = true end
      end
      fallar(errores, ms.nombre .. ": escaleras", sube and baja)
    end
    local arriba, abajoMismo = 0, 0
    for _, m in pairs(mundo.entidades) do
      if m.kind == "monstruo" and (m.z or 0) == 1 then
        arriba = arriba + 1
        local libre = mapa.alto[math.floor(m.x)] and mapa.alto[math.floor(m.x)][math.floor(m.y)]
        if not libre then abajoMismo = abajoMismo + 1 end
      end
    end
    fallar(errores, "salen criaturas arriba", arriba >= 12, tostring(arriba))
    fallar(errores, "todas sobre la plataforma", abajoMismo == 0, tostring(abajoMismo))
    -- subir por la escalera
    local ms = mapa.mesetas[1]
    local p = mundo:crearPersonaje({ nombre = "Alpinista", faccion = "albor", clase = "guerrero", nivel = 25 })
    p.x, p.y, p.z, p.modo = ms.entrada.x + 0.5, ms.entrada.y + 0.5, 0, "mundo"
    p.escaleraEn = nil
    mundo:pisarEscalera(p)
    fallar(errores, "al pisar la escalera subes", p.z == 1)
    -- a pie no se ven las criaturas de arriba; arriba sí
    local function veMonstruos(z)
      p.z = z
      local n = 0
      for _, e in ipairs(mundo:foto(p.id).ents) do if e.kind == "monstruo" and (e.z or 0) == 1 then n = n + 1 end end
      return n
    end
    p.x, p.y = ms.x + 7.5, ms.y + 6.5
    local arribaVe = veMonstruos(1)
    local abajoVe = veMonstruos(0)
    fallar(errores, "arriba se ven las criaturas de la plataforma y desde el suelo no", arribaVe > 0 and abajoVe == 0, arribaVe .. " vs " .. abajoVe)
    -- el nivel de las de arriba supera al de su zona
    local mon
    for _, m in pairs(mundo.entidades) do if m.kind == "monstruo" and (m.z or 0) == 1 then mon = m break end end
    fallar(errores, "las de arriba son más fuertes que su zona", mon and mon.nivel > Datos.monstruo(mon.monstruo).nivel)
    -- reaparecen arriba
    mon.vivo, mon.respawn = false, 0
    mundo:revivir(mon)
    fallar(errores, "reaparecen en la plataforma", (mon.z or 0) == 1)
  end)
  paso("zonas del mapa con niveles", function()
    local Mapa = require("compartido.dominio.mapa")
    local mundo = Mundo.nuevo()
    local zonas = Mapa.zonas(mundo.mapas.mundo)
    fallar(errores, "hay zonas con criaturas", #zonas >= 10, tostring(#zonas))
    local elevadas, bajas = 0, 0
    local orden = true
    for i, z in ipairs(zonas) do
      if z.elevada then elevadas = elevadas + 1 else bajas = bajas + 1 end
      if z.nivelMin > z.nivelMax or #z.monstruos == 0 then orden = false end
      if i > 1 and zonas[i - 1].nivelMin > z.nivelMin then orden = false end
    end
    fallar(errores, "zonas de suelo y elevadas", bajas >= 8 and elevadas >= 4, bajas .. "/" .. elevadas)
    fallar(errores, "niveles coherentes y ordenados", orden)
    -- un marcador por grupo de campamentos: sobre un campamento real (en tierra) y con 3 niveles de diferencia como mucho
    local mapaMundo = mundo.mapas.mundo
    local bien, tierra = true, true
    for _, z in ipairs(zonas) do
      if not z.elevada then
        if z.nivelMax - z.nivelMin > 3 then bien = false end
        local hay = false
        for _, k in ipairs(mapaMundo.campamentos) do
          if not k.z and k.x == z.x and k.y == z.y then hay = true end
        end
        if not hay or not Mapa.transitable(mapaMundo, math.floor(z.x), math.floor(z.y)) then tierra = false end
      end
    end
    fallar(errores, "zonas: maximo 3 niveles de diferencia", bien)
    fallar(errores, "zonas: el punto esta sobre un campamento en tierra", tierra)
    -- el nivel de una zona elevada supera al de su zona de suelo
    local sobre = true
    for _, z in ipairs(zonas) do
      if z.elevada then
        local suelo
        for _, o in ipairs(zonas) do if not o.elevada and o.bioma == z.bioma then suelo = o end end
        if suelo and z.nivelMax <= suelo.nivelMax - 0 and z.nivelMin <= suelo.nivelMin then sobre = false end
      end
    end
    fallar(errores, "las zonas elevadas son más duras", sobre)
  end)
  paso("monturas con vida: caen y sueltan la carga", function()
    local Monturas = require("compartido.dominio.monturas")
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local pu = mundo.mapas.mundo.puestos[1]
    local function jug(nombre, faccion, job)
      local e = mundo:crearPersonaje({ nombre = nombre, faccion = faccion, clase = "guerrero", nivel = 20 })
      e.x, e.y, e.z, e.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
      e.job, e.oficioElegido, e.oficios = job, job, { [job] = { nivel = 5, xp = 0 } }
      return e
    end
    local t = jug("Carguero", "albor", "trader")
    local ladron = jug("Ladron", "albor", "thief") -- de la misma corona: aun asi puede atacar a un comerciante montado
    ladron.x = t.x + 1
    t.monturas, t.montado = { "buey" }, "buey"
    t.carga = { trigo = 6, vino = 3 }
    mundo:recalcularCarga(t)
    local hp0, max = mundo:vidaMontura(t, "buey")
    fallar(errores, "la montura tiene su vida", hp0 == max and max == Monturas.vidaMax("buey") and max > 0)
    -- sin montura, un ladrón no puede atacar a un comerciante de su corona
    local suelo = jug("Peaton", "albor", "trader")
    suelo.x = t.x + 2
    fallar(errores, "con el oficio activo se le puede atacar también a pie", mundo:puedeDanar(ladron, suelo))
    fallar(errores, "montado sí se le ataca", mundo:puedeDanar(ladron, t))
    -- el golpe baja la vida de la montura, no la del jinete
    local vida = t.hp
    mundo:danar(t, 100, ladron)
    local hp1 = mundo:vidaMontura(t, "buey")
    fallar(errores, "el golpe baja la vida de la montura", hp1 == max - 100 and t.hp == vida, tostring(hp1))
    fallar(errores, "el ladrón es buscado y hay pelea abierta", mundo:esBuscado(ladron) and (t.combateCon[ladron.id] or 0) > mundo.tiempo)
    fallar(errores, "la foto lleva la vida de la montura", (function()
      for _, e in ipairs(mundo:foto(t.id).ents) do if e.id == t.id then return e.monturaFrac ~= nil and e.monturaFrac < 1 end end
    end)() and mundo:foto(t.id).tu.monturaHpMax == max)
    -- al llegar a cero cae: el jinete sigue vivo y baja, y la carga queda en el suelo
    mundo:danar(t, max, ladron)
    fallar(errores, "la montura cae y el jinete sigue vivo", t.montado == nil and t.vivo and t.hp == vida)
    local fardos, total = 0, 0
    for _, o in pairs(mundo.entidades) do
      if o.kind == "loot" and o.bienes then
        fardos = fardos + 1
        for _, c in pairs(o.bienes) do total = total + c end
      end
    end
    fallar(errores, "su mercancía cae al suelo sin matarlo", fardos == 2 and total == 9 and next(t.carga) == nil, fardos .. "/" .. total)
    -- el ladrón la recoge
    for _, o in pairs(mundo.entidades) do
      if o.kind == "loot" and o.bienes then ladron.x, ladron.y = o.x, o.y mundo:recoger(ladron, o) end
    end
    local robado = 0
    for _, c in pairs(ladron.cargaRobada or {}) do robado = robado + c end
    fallar(errores, "el ladrón se lleva lo caído", robado > 0, tostring(robado))
    -- la montura caída no se puede usar hasta que se recupera
    fallar(errores, "herida no se monta", mundo:alternarMontura(t, "buey") ~= nil and t.montado == nil)
    mundo.tiempo = mundo.tiempo + Monturas.RECUPERA_SEG + 1
    mundo._montT = 5
    mundo:actualizarMonturas(1)
    local hp2 = mundo:vidaMontura(t, "buey")
    fallar(errores, "se recupera con el tiempo", hp2 == max and mundo:alternarMontura(t, "buey") == nil and t.montado == "buey", tostring(hp2))
    -- recupera vida poco a poco si no la golpean
    t.monturaVida.buey = 10
    t.monturaGolpe = mundo.tiempo - 30
    mundo._montT = 5
    mundo:actualizarMonturas(1)
    fallar(errores, "regenera sin golpes", mundo:vidaMontura(t, "buey") > 10)
    -- los golpes de criaturas también bajan primero la montura
    local gato = mundo:spawnMonstruo("gato", t.x + 1, t.y, { x = t.x, y = t.y })
    t.monturaVida.buey = max
    local v2 = t.hp
    mundo:danar(t, 40, gato)
    fallar(errores, "las criaturas golpean primero la montura", t.hp == v2 and mundo:vidaMontura(t, "buey") == max - 40)
  end)
  paso("anuncio global de inscripción y poción cada 3 s", function()
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local pu = mundo.mapas.mundo.puestos[1]
    local a = mundo:crearPersonaje({ nombre = "Anota", faccion = "albor", clase = "guerrero", nivel = 12 })
    local b = mundo:crearPersonaje({ nombre = "Lejano", faccion = "umbra", clase = "guerrero", nivel = 12 })
    a.x, a.y, a.z, a.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
    b.x, b.y, b.z, b.modo = 400, 400, 0, "mundo"
    mundo.mensajes = {}
mundo.tiempo = 100
    local err = mundo:entrarGuerra(a, "estandarte")
    fallar(errores, "se anota sin error", err == nil and a.colaGuerra == "estandarte", tostring(err))
    local anuncio
    for _, m in ipairs(mundo.mensajes) do if m.marquesina then anuncio = m end end
    fallar(errores, "sale un anuncio global de sistema con marquesina", anuncio and anuncio.canal == "sistema" and anuncio.para == nil
      and anuncio.texto:find("Anota") and anuncio.id ~= nil)
    -- lo ve todo el mundo, lejos o cerca
    local function ve(p) for _, m in ipairs(mundo:foto(p.id).msgs) do if m.marquesina then return true end end return false end
    fallar(errores, "lo ven todos los jugadores", ve(a) and ve(b))
    local ids = {}
    for _, m in ipairs(mundo.mensajes) do if m.id then ids[m.id] = true end end
    local n = 0
    for _ in pairs(ids) do n = n + 1 end
    fallar(errores, "los mensajes llevan id único", n == #mundo.mensajes)
    -- poción: 3 segundos
    a.hp = 1
    local pocion = mundo:darItem(a, "pocion_vida", 5)
    fallar(errores, "primera poción", mundo:usarPocionId(a, "pocion_vida") == nil)
    fallar(errores, "la pequeña cura entre 50 y 110", a.hp >= 51 and a.hp <= 111, tostring(a.hp))
    fallar(errores, "la segunda espera", mundo:usarPocionId(a, "pocion_vida") ~= nil)
    mundo.tiempo = mundo.tiempo + 2.9
    fallar(errores, "a los 2,9 s aún no", mundo:usarPocionId(a, "pocion_vida") ~= nil)
    mundo.tiempo = mundo.tiempo + 0.2
    fallar(errores, "a los 3 s sí", mundo:usarPocionId(a, "pocion_vida") == nil)
    mundo:darItem(a, "pocion_mana", 2)
    fallar(errores, "otra poción distinta no espera a la primera", mundo:usarPocionId(a, "pocion_mana") == nil)
    fallar(errores, "la foto trae el enfriamiento", mundo:foto(a.id).tu.cdPociones.pocion_vida == a.cdPociones.pocion_vida)
  end)
  paso("animación de ataque: el servidor marca cada ataque de criaturas y jugadores", function()
    local mundo = Mundo.nuevo()
    local a = mundo:crearPersonaje({ nombre = "Atq", faccion = "albor", clase = "guerrero" })
    local m = mundo:spawnMonstruo("gato", a.x + 1, a.y, { x = a.x, y = a.y })
    mundo.tiempo = 100
    mundo:golpear(a, m, 1)
    fallar(errores, "golpear anota el ataque con su dirección", a.atqN == 1 and a.atqX ~= nil and a.atqLejos == nil)
    mundo:golpear(a, m, 1)
    fallar(errores, "dos golpes del mismo ataque cuentan uno", a.atqN == 1)
    mundo.tiempo = 100.5
    mundo:golpear(a, m, 1, nil, nil, true)
    fallar(errores, "el impacto de algo lanzado no es un ataque nuevo", a.atqN == 1)
    mundo:golpear(m, a, 1)
    fallar(errores, "las criaturas también atacan", m.atqN == 1)
    mundo.tiempo = 101
    mundo:proyectil(a, m, { coef = 1, dano = "fisico", proyectil = "flecha" })
    fallar(errores, "un disparo es un ataque de lejos", a.atqN == 2 and a.atqLejos == true)
    local foto = mundo:compactar(a)
    fallar(errores, "la foto lleva el ataque reciente", foto.atqN == 2 and foto.atqL == true)
    mundo.tiempo = 110
    fallar(errores, "pasado un rato la foto ya no lo lleva", mundo:compactar(a).atqN == nil)
    -- el destello rojo de daño dura un instante y se apaga (antes se quedaba para siempre)
    m.hp = m.hpMax; mundo:danar(m, 1, a)
    fallar(errores, "al recibir daño la foto lleva el destello", mundo:compactar(m).flash ~= nil)
    mundo.tiempo = mundo.tiempo + 0.5
    fallar(errores, "el destello rojo se apaga solo", mundo:compactar(m).flash == nil)
  end)
  paso("autopoción: umbral configurable y curación", function()
    local Autoridad = require("src.dominio.autoridad")
    local mundo = Mundo.nuevo()
    local a = mundo:crearPersonaje({ nombre = "Curandero", faccion = "albor", clase = "guerrero", nivel = 8 })
    mundo.tiempo = 50
    local tenia = mundo:contarItem(a, "pocion_vida")
    a.ultimoGolpe = mundo.tiempo
    a.hp = math.floor(a.hpMax * 0.3)
    local hpBaja = a.hp
    mundo:actualizarJugador(a, 0.05)
    fallar(errores, "apagada no bebe", mundo:contarItem(a, "pocion_vida") == tenia and a.hp == hpBaja)
    local ok, limpio = Autoridad.aceptar(mundo, a, "autopocion", { on = true, umbral = 0.74 })
    fallar(errores, "el servidor redondea el umbral a un paso de 10", ok and limpio.on == true and limpio.umbral == 0.7)
    fallar(errores, "rechaza un umbral fuera de 20-90", Autoridad.aceptar(mundo, a, "autopocion", { on = true, umbral = 5 }) == false)
    mundo:accion(a.id, "autopocion", limpio)
    mundo:actualizarJugador(a, 0.05)
    fallar(errores, "bebe y cura por debajo del umbral", a.hp > hpBaja and mundo:contarItem(a, "pocion_vida") == tenia - 1)
    a.hp = math.floor(a.hpMax * 0.2)
    mundo:actualizarJugador(a, 0.05)
    fallar(errores, "respeta el enfriamiento", a.hp == math.floor(a.hpMax * 0.2) and mundo:contarItem(a, "pocion_vida") == tenia - 1)
    a.hp, a.cdPociones = a.hpMax, {}
    mundo:actualizarJugador(a, 0.05)
    fallar(errores, "con la vida alta no bebe", mundo:contarItem(a, "pocion_vida") == tenia - 1)
    a.hp = math.floor(a.hpMax * 0.6)
    mundo:accion(a.id, "autopocion", { on = true, umbral = 0.4 })
    mundo:actualizarJugador(a, 0.05)
    fallar(errores, "al 60% no bebe si el umbral es 40", mundo:contarItem(a, "pocion_vida") == tenia - 1)
    local ex = mundo:exportar(a)
    fallar(errores, "el guardado lleva el interruptor y el umbral", ex.autoPocion == true and math.abs(ex.autoPocionUmbral - 0.4) < 0.001)
    local b = mundo:crearPersonaje({ nombre = "Otro", faccion = "albor", clase = "guerrero" })
    mundo:aplicarGuardado(b, ex)
    fallar(errores, "al cargar vuelve la configuración", b.autoPocion == true and math.abs((b.autoPocionUmbral or 0) - 0.4) < 0.001)
    mundo:accion(a.id, "autopocion", { on = true, umbral = 0.7 })
    local antes = a.hp
    mundo:actualizarJugador(a, 0.05)
    fallar(errores, "al 60% sí bebe si subes el umbral a 70", a.hp > antes and mundo:contarItem(a, "pocion_vida") == tenia - 2)
    local manaAntes = mundo:contarItem(a, "pocion_mana")
    a.mp = math.floor(a.mpMax * 0.3)
    a.cdPociones = {}
    a.ultimoGolpe = mundo.tiempo
    local mpBaja = a.mp
    mundo:actualizarJugador(a, 0.05)
    fallar(errores, "el maná apagado no bebe", mundo:contarItem(a, "pocion_mana") == manaAntes and a.mp < mpBaja + 1)
    local okM, limpioM = Autoridad.aceptar(mundo, a, "autopocion", { cual = "mana", on = true, umbral = 0.5 })
    fallar(errores, "acepta configurar el maná", okM and limpioM.cual == "mana" and limpioM.umbral == 0.5)
    mundo:accion(a.id, "autopocion", limpioM)
    mundo:actualizarJugador(a, 0.05)
    fallar(errores, "bebe maná por debajo de su umbral", a.mp > mpBaja + 5 and mundo:contarItem(a, "pocion_mana") == manaAntes - 1)
    a.hp = math.floor(a.hpMax * 0.2)
    a.mp = math.floor(a.mpMax * 0.2)
    a.cdPociones = {}
    local vidas = mundo:contarItem(a, "pocion_vida")
    mundo:actualizarJugador(a, 0.05)
    fallar(errores, "si faltan las dos, beben a la vez (enfriamiento individual)", mundo:contarItem(a, "pocion_vida") == vidas - 1 and mundo:contarItem(a, "pocion_mana") == manaAntes - 2)
    local ex2 = mundo:exportar(a)
    fallar(errores, "el guardado lleva también el maná", ex2.autoMana == true and math.abs(ex2.autoManaUmbral - 0.5) < 0.001)
    local foto = mundo:foto(a.id).tu
    fallar(errores, "la foto lleva la configuración", foto.autoPocion == true and foto.autoPocionUmbral == a.autoPocionUmbral
      and foto.autoMana == true and foto.autoManaUmbral == a.autoManaUmbral)
    a.nivel = 8
    a.cdPociones = {}
    a.autoPocion = true
    a.autoPocionUmbral = 0.9
    a.ultimoGolpe = mundo.tiempo
    a.hp = math.floor(a.hpMax * 0.2)
    mundo:darItem(a, "pocion_vida_mediana", 1)
    mundo:darItem(a, "pocion_vida_grande", 1)
    local peq = mundo:contarItem(a, "pocion_vida")
    local med = mundo:contarItem(a, "pocion_vida_mediana")
    local gra = mundo:contarItem(a, "pocion_vida_grande")
    mundo:actualizarJugador(a, 0.05)
    fallar(errores, "con nivel bajo bebe la pequeña", peq > 0 and mundo:contarItem(a, "pocion_vida") == peq - 1
      and mundo:contarItem(a, "pocion_vida_mediana") == med and mundo:contarItem(a, "pocion_vida_grande") == gra)
    a.nivel = 1
    a.cdPociones = {}
    fallar(errores, "la mediana no se bebe antes del nivel 12", mundo:usarPocionId(a, "pocion_vida_mediana") ~= nil
      and mundo:contarItem(a, "pocion_vida_mediana") == med)
    a.nivel = 22
    a.cdPociones = {}
    a.hp = math.floor(a.hpMax * 0.2)
    local antesP = mundo:contarItem(a, "pocion_vida")
    mundo:actualizarJugador(a, 0.05)
    fallar(errores, "al nivel 22 bebe la más fuerte", mundo:contarItem(a, "pocion_vida_grande") == gra - 1
      and mundo:contarItem(a, "pocion_vida") == antesP and mundo:contarItem(a, "pocion_vida_mediana") == med)
  end)
  paso("campo de batalla: relieve, colisiones y cristales", function()
    local Mapa = require("compartido.dominio.mapa")
    local mundo = Mundo.nuevo()
    local mapa = mundo.mapas.batalla
    fallar(errores, "el mapa de batalla tiene decoración colocada", mapa.decorado ~= nil)
    local piedras, grietas, montes, enCamino = 0, 0, 0, 0
    local medio = math.floor(mapa.h / 2)
    for x, col in pairs(mapa.decorado) do
      for y, tipo in pairs(col) do
        if tipo == "piedra" then
          piedras = piedras + 1
          -- las piedras están junto al camino
          if math.abs(y - medio) <= 4 or math.abs(x - mapa.w / 2) <= 4.5 then enCamino = enCamino + 1 end
        end
        if tipo == "grieta" then
          grietas = grietas + 1
          fallar(errores, "los huecos tienen colisión", mapa.bloque[x] and mapa.bloque[x][y] == true)
        end
      end
    end
    for _, p in ipairs(mapa.props) do if p.tipo:find("risco") then montes = montes + 1 end end
    fallar(errores, "hay piedras, huecos y montañas", piedras > 40 and grietas > 15 and montes > 10, piedras .. "/" .. grietas .. "/" .. montes)
    -- no se bloquean las puertas: delante de cada una hay camino
    for k, pu in pairs(mapa.puerta) do
      local dx = pu.faccion == "albor" and 1 or -1
      fallar(errores, "delante de la puerta " .. k .. " hay paso", Mapa.transitable(mapa, pu.x + dx, pu.y))
    end
    fallar(errores, "de una base se llega a todo", mapa.conexo == true)
    local sp = mapa.spawns.albor
    fallar(errores, "las bases no tienen obstáculos", Mapa.transitable(mapa, math.floor(sp.x), math.floor(sp.y)))
    -- cristales: se sueltan, se recogen y se entregan en el altar propio
    local a = mundo:crearPersonaje({ nombre = "Cristalero", faccion = "albor", clase = "guerrero", nivel = 12 })
    local rival = mundo:crearPersonaje({ nombre = "Rival", faccion = "umbra", clase = "guerrero", nivel = 12 })
    mundo:reiniciarInstancia("batalla")
    for _, j in ipairs({ a, rival }) do
      j.modo, j.z = "batalla", 0
      j.x, j.y = mapa.spawns[j.faccion].x, mapa.spawns[j.faccion].y
    end
    local estatua
    for _, e in pairs(mundo.entidades) do if e.kind == "altar" and e.faccion == "umbra" then estatua = e end end
    a.x, a.y = estatua.x - 2, estatua.y
    estatua.hp = 1
    mundo:danar(estatua, 9999, a)
    local cristales = {}
    for _, e in pairs(mundo.entidades) do if e.kind == "cristal" then cristales[#cristales + 1] = e end end
    fallar(errores, "al caer el núcleo suelta un cristal al suelo", #cristales == 1 and cristales[1].faccion == "umbra", tostring(#cristales))
    fallar(errores, "ya no se da en la bolsa", #a.bolsa == 0 or true)
    -- se ve en la foto
    local visto = false
    a.x, a.y = cristales[1].x - 3, cristales[1].y
    for _, e in ipairs(mundo:foto(a.id).ents) do if e.kind == "cristal" then visto = true end end
    fallar(errores, "el cristal llega al cliente", visto)
    -- recogerlo
    a.x, a.y = cristales[1].x, cristales[1].y
    mundo:cristalesCerca(a)
    fallar(errores, "al pasar por encima lo coge", a.llevaCristales == 1 and mundo.entidades[cristales[1].id] == nil or cristales[1].borrar == true)
    fallar(errores, "la foto dice cuántos llevas", mundo:foto(a.id).tu.llevaCristales == 1)
    -- si muere con él, cae donde murió
    local pts0 = mundo.instancia.batalla.puntos.albor
    a.x, a.y = estatua.x - 4, estatua.y + 1
    mundo:morir(a, rival)
    local suelta = 0
    for _, e in pairs(mundo.entidades) do if e.kind == "cristal" and not e.borrar and e.faccion == "umbra" then suelta = suelta + 1 end end
    fallar(errores, "al morir suelta los cristales que lleva", a.llevaCristales == nil and suelta >= 1, tostring(suelta))
    mundo:revivir(a)
    -- el rival lo recoge y lo lleva a su altar
    local c
    for _, e in pairs(mundo.entidades) do if e.kind == "cristal" and not e.borrar then c = e end end
    rival.x, rival.y = c.x, c.y
    mundo:cristalesCerca(rival)
    fallar(errores, "el rival lo coge", rival.llevaCristales == 1)
    local altar
    for _, e in pairs(mundo.entidades) do if e.kind == "altar" and e.faccion == "umbra" then altar = e end end
    altar.vivo, altar.hp = true, altar.hpMax -- el núcleo ya se había regenerado
    local antes = mundo.instancia.batalla.puntos.umbra
    rival.x, rival.y = altar.x - 1, altar.y
    mundo:cristalesCerca(rival)
    fallar(errores, "en su altar se entrega solo", rival.llevaCristales == nil and mundo.instancia.batalla.puntos.umbra == antes + Mundo.PUNTOS_CRISTAL)
    -- fin de evento: lo que no se entregó vale oro
    mundo:reiniciarInstancia("batalla")
    local n = 0
    for _, e in pairs(mundo.entidades) do if e.kind == "cristal" then n = n + 1 end end
    fallar(errores, "al reiniciar no quedan cristales", n == 0)
    local nuc
    for _, e in pairs(mundo.entidades) do if e.kind == "altar" and e.faccion == "umbra" then nuc = e end end
    fallar(errores, "el núcleo vuelve a estar entero", nuc.vivo and nuc.hp == nuc.hpMax and nuc.hpMax >= 1000)
  end)
  paso("campo de batalla: varias entradas", function()
    local mundo = Mundo.nuevo()
    local mapa = mundo.mapas.batalla
    local porMuro = { albor = 0, umbra = 0 }
    for _, p in pairs(mapa.puerta) do porMuro[p.faccion] = porMuro[p.faccion] + 1 end
    fallar(errores, "cada muro tiene varias entradas", porMuro.albor == 3 and porMuro.umbra == 3, porMuro.albor .. "/" .. porMuro.umbra)
    local puertas, principales = 0, 0
    for _, e in pairs(mundo.entidades) do
      if e.kind == "puerta" and e.modo == "batalla" then
        puertas = puertas + 1
        if e.principal then principales = principales + 1 end
        fallar(errores, "la puerta tiene su entrada en el muro", mapa.puerta[e.tx .. "_" .. e.ty] ~= nil)
      end
    end
    fallar(errores, "hay seis puertas, dos principales", puertas == 6 and principales == 2, puertas .. "/" .. principales)
    -- los suyos pasan por cualquier puerta; el enemigo, no, hasta derribarla
    local Mapa = require("compartido.dominio.mapa")
    local lat
    for k, p in pairs(mapa.puerta) do if p.faccion == "albor" and not (p.y == math.floor(mapa.h / 2)) then lat = p break end end
    fallar(errores, "la puerta lateral deja pasar a los suyos", not Mapa.bloqueado(mapa, lat.x + 0.5, lat.y + 0.5, "albor"))
    fallar(errores, "y cierra el paso al enemigo", Mapa.bloqueado(mapa, lat.x + 0.5, lat.y + 0.5, "umbra"))
    local e
    for _, o in pairs(mundo.entidades) do if o.kind == "puerta" and o.tx == lat.x and o.ty == lat.y then e = o end end
    local atacante = mundo:crearPersonaje({ nombre = "Asalto", faccion = "umbra", clase = "guerrero", nivel = 12 })
    atacante.modo, atacante.z, atacante.x, atacante.y = "batalla", 0, lat.x + 2, lat.y
    mundo:reiniciarInstancia("batalla")
    e.hp = 1
    mundo:danar(e, 9999, atacante)
    fallar(errores, "al derribarla el enemigo pasa", e.vivo == false and not Mapa.bloqueado(mapa, lat.x + 0.5, lat.y + 0.5, "umbra"))
    local cristales = 0
    for _, o in pairs(mundo.entidades) do if o.kind == "cristal" then cristales = cristales + 1 end end
    fallar(errores, "una puerta no suelta cristal (solo el núcleo)", cristales == 0, tostring(cristales))
    mundo:reiniciarInstancia("batalla")
    fallar(errores, "al reiniciar se cierra otra vez", Mapa.bloqueado(mapa, lat.x + 0.5, lat.y + 0.5, "umbra"))
  end)
  paso("pergamino de fuerza y lista del mall con rueda", function()
    local Mall = require("compartido.dominio.mall")
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local p = mundo:crearPersonaje({ nombre = "Fuerte", faccion = "albor", clase = "guerrero", nivel = 12 })
    p.bolsa, p.equipo.mochila, p.monedas = {}, "mochila_4", 100
    fallar(errores, "el pergamino de fuerza está en el mall", Mall.objeto("pergamino_str") ~= nil and Datos.item("pergamino_str").mall == true)
    fallar(errores, "se compra", mundo:comprarMall(p, "pergamino_str") == nil and p.monedas == 100 - Mall.objeto("pergamino_str").precio)
    local hp0, atk0 = p.hpMax, p.atk
    fallar(errores, "se usa", mundo:equipar(p, 1) == nil and mundo:bonoActivo(p, "str"))
    fallar(errores, "sube la vida y el ataque", p.hpMax > hp0 * 1.19 and p.atk > atk0 * 1.04 and p.atk < atk0 * 1.06, p.hpMax .. " vs " .. hp0)
    for b in pairs(p.bonos) do p.bonos[b] = mundo:reloj() - 1 end
    mundo._bonoT = 5
    mundo:actualizarBonos(1)
    fallar(errores, "al terminar vuelve a lo normal", p.hpMax == hp0 and p.atk == atk0)
  end)
  paso("eventos: se ingresa por el Heraldo y sin límite por edición", function()
    local Autoridad = require("src.dominio.autoridad")
    local mundo = Mundo.nuevo()
    local pu = mundo.mapas.mundo.puestos[1]
    local p = mundo:crearPersonaje({ nombre = "Entrante", faccion = "albor", clase = "guerrero", nivel = 12 })
    p.x, p.y, p.z, p.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
    local ok = Autoridad.aceptar(mundo, p, "guerra", { modo = "estandarte" })
    fallar(errores, "lejos del Heraldo no se puede ingresar", ok == false)
    local heraldo
    for _, e in pairs(mundo.entidades) do if e.kind == "npc" and e.rol == "heraldo" then heraldo = e end end
    fallar(errores, "hay un Heraldo", heraldo ~= nil)
    p.x, p.y = heraldo.x + 1, heraldo.y
    local ok2, limpio = Autoridad.aceptar(mundo, p, "guerra", { modo = "estandarte" })
    fallar(errores, "junto al Heraldo sí", ok2 == true and limpio.modo == "estandarte")
    -- sin límite por edición: tras participar, puede volver a anotarse en la misma edición
    mundo.tiempo = 100
    p.eventosDia = { [mundo:claveEdicion("estandarte")] = os.date("%Y-%m-%d") }
    fallar(errores, "puede participar aunque ya lo hiciera en esta edición", mundo:entrarGuerra(p, "estandarte") == nil and p.colaGuerra == "estandarte")
    -- cada ciudad tiene su Heraldo
    local n = 0
    for _, e in pairs(mundo.entidades) do if e.kind == "npc" and e.rol == "heraldo" then n = n + 1 end end
    fallar(errores, "un Heraldo en cada ciudad", n >= #mundo.mapas.mundo.ciudades, tostring(n))
  end)
  paso("mensajes de eventos en su pestaña", function()
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    mundo.mensajes = {}
    mundo:programarEventos({ estandarteCadaHoras = 4, batallaHora = 21, batallaMinuto = 0, avisoMinutos = 5 })
    mundo.relojEventos = function() return os.time({ year = 2026, month = 10, day = 12, hour = 3, min = 56, sec = 0 }) end
    mundo:actualizarProgramacion(2)
    mundo._progT = 5
    mundo:actualizarProgramacion(1)
    local aviso
    for _, m in ipairs(mundo.mensajes) do if m.evento and m.texto:find("empieza a las") then aviso = m end end
    fallar(errores, "el aviso del próximo evento va a la pestaña de eventos", aviso and aviso.canal == "mundo" and aviso.evento == true)
    mundo:anunciar("X se anota")
    fallar(errores, "la inscripción también", mundo.mensajes[#mundo.mensajes].evento == true and mundo.mensajes[#mundo.mensajes].marquesina)
    mundo:mensaje("mundo", "Y", "charla normal", nil)
    fallar(errores, "el chat normal no", mundo.mensajes[#mundo.mensajes].evento == nil)
    mundo:avisoEvento("mundo", "", "termina", nil)
    fallar(errores, "avisoEvento marca el mensaje", mundo.mensajes[#mundo.mensajes].evento == true)
  end)
  paso("evento: premios al terminar y núcleo que se regenera", function()
    local mundo = Mundo.nuevo()
    local ganador = mundo:crearPersonaje({ nombre = "Gana", faccion = "albor", clase = "guerrero", nivel = 12 })
    local perdedor = mundo:crearPersonaje({ nombre = "Pierde", faccion = "umbra", clase = "guerrero", nivel = 12 })
    for _, j in ipairs({ ganador, perdedor }) do
      j.bolsa, j.equipo.mochila, j.oro = {}, "mochila_4", 0
    end
    mundo:reiniciarInstancia("batalla")
    for _, j in ipairs({ ganador, perdedor }) do
      j.modo, j.z, j.retorno = "batalla", 0, { x = 100.5, y = 100.5, modo = "mundo" }
    end
    mundo:cerrarInstancia("batalla", "albor")
    local function cuenta(j, id) return mundo:contarItem(j, id) end
    local scrollG, scrollP = 0, 0
    for _, o in ipairs(require("compartido.dominio.mall").OBJETOS) do
      if o.id:sub(1, 10) == "pergamino_" then scrollG = scrollG + cuenta(ganador, o.id) scrollP = scrollP + cuenta(perdedor, o.id) end
    end
    fallar(errores, "el ganador recibe oro", ganador.oro >= 220)
    fallar(errores, "el ganador recibe polvo para encantar", cuenta(ganador, "polvo_arcano") >= 8)
    fallar(errores, "el ganador recibe un pergamino de atributos", scrollG == 1)
    fallar(errores, "el perdedor también recibe polvo y oro", cuenta(perdedor, "polvo_arcano") >= 2 and perdedor.oro >= 70)
    fallar(errores, "el perdedor tiene menos", cuenta(perdedor, "polvo_arcano") < cuenta(ganador, "polvo_arcano") and scrollP <= 1)
    -- el núcleo destruido se regenera solo a los 2 minutos
    mundo:reiniciarInstancia("batalla")
    local nuc
    for _, e in pairs(mundo.entidades) do if e.kind == "altar" and e.faccion == "umbra" then nuc = e end end
    ganador.modo, ganador.x, ganador.y = "batalla", nuc.x - 2, nuc.y
    nuc.hp = 1
    mundo:danar(nuc, 9999, ganador)
    fallar(errores, "el núcleo cae y deja ruinas", nuc.vivo == false and nuc.respawn ~= nil)
    mundo.tiempo = mundo.tiempo + 121
    mundo:actualizar(0.05)
    fallar(errores, "el núcleo se regenera", nuc.vivo and nuc.hp == nuc.hpMax)
  end)
  paso("viaje largo por rutas en tramos", function()
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local ciudad, destino
    for _, c in ipairs(mundo.mapas.mundo.ciudades) do
      if c.id == "henar" then ciudad = c elseif c.id == "liria" then destino = c end
    end
    local p = mundo:crearPersonaje({ nombre = "Viajero", faccion = "albor", clase = "guerrero", nivel = 12 })
    p.x, p.y, p.z, p.modo = ciudad.spawn.x, ciudad.spawn.y, 0, "mundo"
    local ox, oy = p.x, p.y
    mundo:fijarDestino(p, destino.spawn.x, destino.spawn.y)
    fallar(errores, "el viaje largo se parte en tramos", p.caminoCortado == true and p.camino and #p.camino > 0 and #p.camino <= 80)
    local lejos = math.sqrt((destino.spawn.x - ox) ^ 2 + (destino.spawn.y - oy) ^ 2)
    for _ = 1, 20 * 330 do
      mundo:actualizar(0.05)
      if math.sqrt((p.x - destino.spawn.x) ^ 2 + (p.y - destino.spawn.y) ^ 2) < 3 then break end
    end
    local resta = math.sqrt((p.x - destino.spawn.x) ^ 2 + (p.y - destino.spawn.y) ^ 2)
    fallar(errores, "llega (o casi) a la otra punta del mapa", resta < lejos * 0.15, string.format("%.0f de %.0f", resta, lejos))
  end)
  paso("invitaciones de gremio y grupo llegan por el servidor", function()
    local Autoridad = require("src.dominio.autoridad")
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local pu = mundo.mapas.mundo.puestos[1]
    local function jug(nombre)
      local e = mundo:crearPersonaje({ nombre = nombre, faccion = "albor", clase = "guerrero", nivel = 15 })
      e.x, e.y, e.z, e.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
      return e
    end
    local lider, otro = jug("LiderG"), jug("Invitado")
    lider.oro, lider.dbId, otro.dbId = 99999, 9001, 9002
    fallar(errores, "el id de un jugador es de texto", type(otro.id) == "string")
    mundo:crearGremio(lider, "Probados", "PRB")
    -- el cliente manda ids de texto: la autoridad debe dejarlos pasar
    local ok, limpio = Autoridad.aceptar(mundo, lider, "gremio_invitar", { id = otro.id })
    fallar(errores, "gremio_invitar acepta el id del jugador", ok == true and limpio.id == otro.id)
    mundo:accion(lider.id, "gremio_invitar", limpio)
    fallar(errores, "el invitado recibe la invitación", otro.invitacionGremio ~= nil)
    local snap = mundo:foto(otro.id).tu
    fallar(errores, "la foto trae la invitación para el aviso", snap.invGremio and snap.invGremio.nombre == "Probados" and snap.invGremio.de == "LiderG")
    mundo:accion(otro.id, "gremio_responder", { acepta = true })
    fallar(errores, "al aceptar entra al gremio", otro.gremioId ~= nil and otro.gremioId == lider.gremioId)
    -- grupos
    local a, b = jug("GrupoA"), jug("GrupoB")
    local ok2, l2 = Autoridad.aceptar(mundo, a, "grupo_invitar", { id = b.id })
    fallar(errores, "grupo_invitar acepta el id del jugador", ok2 == true and l2.id == b.id)
    mundo:accion(a.id, "grupo_invitar", l2)
    fallar(errores, "el invitado recibe la invitación de grupo", b.invitacionGrupo ~= nil and mundo:foto(b.id).tu.invGrupo ~= nil)
    fallar(errores, "ids inválidos se rechazan", Autoridad.aceptar(mundo, a, "grupo_invitar", { id = "x; drop" }) == false
      and Autoridad.aceptar(mundo, lider, "gremio_invitar", { id = 12 }) == false)
  end)
  paso("comercio entre jugadores: invitación, oro validado y trato seguro", function()
    local Autoridad = require("src.dominio.autoridad")
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local pu = mundo.mapas.mundo.puestos[1]
    local function jug(nombre, dx)
      local e = mundo:crearPersonaje({ nombre = nombre, faccion = "albor", clase = "guerrero", nivel = 12 })
      e.x, e.y, e.z, e.modo = pu.x + 8.5 + (dx or 0), pu.y + 8.5, 0, "mundo"
      e.bolsa, e.equipo.mochila = {}, "mochila_4"
      return e
    end
    local a, b = jug("Ana"), jug("Beto", 1)
    a.oro, b.oro = 500, 100
    local function ultimoMensaje(p)
      for i = #mundo.mensajes, 1, -1 do local m = mundo.mensajes[i] if m.para == p.id then return m.texto end end
    end
    -- la invitación pasa por la autoridad con ids de texto y no abre sesión hasta aceptar
    local ok, l = Autoridad.aceptar(mundo, a, "comercio_invitar", { id = b.id })
    fallar(errores, "comercio_invitar acepta el id de texto", ok == true and l.id == b.id)
    mundo:accion(a.id, "comercio_invitar", l)
    fallar(errores, "el invitado recibe una invitación y aún no hay sesión", b.invitacionComercio ~= nil and a.sesion == nil and b.sesion == nil)
    fallar(errores, "la foto del invitado trae la alerta", mundo:foto(b.id).tu.invComercio and mundo:foto(b.id).tu.invComercio.de == "Ana")
    local errRepe = mundo:invitarComercio(a, b)
    fallar(errores, "no se invita dos veces", errRepe ~= nil)
    -- rechazar
    mundo:accion(b.id, "comercio_responder", { acepta = false })
    fallar(errores, "rechazar no abre el trato", b.invitacionComercio == nil and a.sesion == nil and (ultimoMensaje(a) or ""):find("rechaza"))
    -- caduca
    mundo:invitarComercio(a, b)
    mundo.tiempo = mundo.tiempo + 31
    mundo._comT = 5
    mundo:actualizarComercio(1)
    fallar(errores, "la invitación caduca", b.invitacionComercio == nil)
    fallar(errores, "responder tarde no hace nada", mundo:responderInvitacionComercio(b, true) ~= nil and a.sesion == nil)
    -- aceptar abre la sesión para los dos
    mundo:invitarComercio(a, b)
    mundo:accion(b.id, "comercio_responder", { acepta = true })
    fallar(errores, "aceptar abre el trato para los dos", a.sesion ~= nil and a.sesion == b.sesion)
    -- oro: no puede pasar de lo que tiene
    mundo:accion(a.id, "comercio_oro", { oro = 600 })
    fallar(errores, "pedir más oro del que tienes se rechaza", mundo.sesiones[a.sesion].oferta[a.id].oro == 0 and a.oro == 500
      and (ultimoMensaje(a) or ""):find("No tienes tanto oro"))
    mundo:accion(a.id, "comercio_oro", { oro = 300 })
    fallar(errores, "ofrecer lo que tienes se acepta", mundo.sesiones[a.sesion].oferta[a.id].oro == 300 and a.oro == 200)
    mundo:accion(a.id, "comercio_oro", { oro = 500 })
    fallar(errores, "se puede subir hasta el total", mundo.sesiones[a.sesion].oferta[a.id].oro == 500 and a.oro == 0)
    mundo:accion(a.id, "comercio_oro", { oro = 100 })
    fallar(errores, "y bajar devuelve el sobrante", mundo.sesiones[a.sesion].oferta[a.id].oro == 100 and a.oro == 400)
    fallar(errores, "valores inválidos se rechazan en el servidor", mundo:ofrecerOro(a, -5) ~= nil and mundo:ofrecerOro(a, 0 / 0) ~= nil
      and mundo:ofrecerOro(a, "mucho") ~= nil and mundo.sesiones[a.sesion].oferta[a.id].oro == 100)
    fallar(errores, "la autoridad rechaza oro negativo o gigante", Autoridad.aceptar(mundo, a, "comercio_oro", { oro = -1 }) == false
      and Autoridad.aceptar(mundo, a, "comercio_oro", { oro = 1e12 }) == false and Autoridad.aceptar(mundo, a, "comercio_oro", { oro = "x" }) == false)
    -- objetos
    mundo:darItem(a, "pocion_vida", 3)
    mundo:darItem(a, "cristal", 1)
    mundo:darItem(a, "pocion_mana", 2)
    local function idx(p, id) for i, s in ipairs(p.bolsa) do if s.id == id then return i end end end
    fallar(errores, "un objeto de misión no se comercia", mundo:ofrecerItem(a, idx(a, "cristal")) ~= nil)
    fallar(errores, "un objeto inexistente se rechaza", mundo:ofrecerItem(a, 99) ~= nil and mundo:ofrecerItem(a, "x") ~= nil)
    fallar(errores, "ofrece un objeto", mundo:ofrecerItem(a, idx(a, "pocion_vida")) == nil and #mundo.sesiones[a.sesion].oferta[a.id].items == 1 and idx(a, "pocion_vida") == nil)
    fallar(errores, "puede retirarlo", mundo:quitarItemOferta(a, 1) == nil and idx(a, "pocion_vida") ~= nil and #mundo.sesiones[a.sesion].oferta[a.id].items == 0)
    mundo:ofrecerItem(a, idx(a, "pocion_vida"))
    -- cambiar la oferta reabre la aceptación
    mundo:aceptarComercio(b)
    fallar(errores, "b acepta", mundo.sesiones[a.sesion].oferta[b.id].ok == true)
    mundo:ofrecerOro(a, 150)
    fallar(errores, "cambiar la oferta quita las aceptaciones", mundo.sesiones[a.sesion].oferta[b.id].ok == false)
    -- cierre
    mundo:ofrecerOro(b, 50)
    mundo:aceptarComercio(a)
    mundo:aceptarComercio(b)
    fallar(errores, "el trato se cierra con todo transferido", a.sesion == nil and b.sesion == nil and a.oro == 350 + 50 and b.oro == 50 + 150 and mundo:contarItem(b, "pocion_vida") == 3 and mundo:contarItem(a, "pocion_vida") == 0,
      a.oro .. "/" .. b.oro)
    fallar(errores, "el oro total se conserva", a.oro + b.oro == 500 + 100)
    -- si no cabe: todo o nada, sin duplicar
    local c, d = jug("Cata", 0.5), jug("Dani", 1.5)
    c.equipo.mochila = nil
    c.bolsa = {}
    for i = 1, Datos.capacidadBolsa(c.equipo) do c.bolsa[i] = { id = "pocion_mana", cant = 1 } end
    c.oro, d.oro = 10, 10
    mundo:darItem(d, "pocion_vida", 2)
    mundo:invitarComercio(d, c)
    mundo:responderInvitacionComercio(c, true)
    mundo:ofrecerItem(d, idx(d, "pocion_vida"))
    mundo:ofrecerOro(d, 5)
    mundo:aceptarComercio(c)
    mundo:aceptarComercio(d)
    fallar(errores, "sin sitio el trato se deshace sin perder ni duplicar", c.sesion == nil and d.sesion == nil and mundo:contarItem(d, "pocion_vida") == 2
      and mundo:contarItem(c, "pocion_vida") == 0 and c.oro == 10 and d.oro == 10, c.oro .. "/" .. d.oro)
    -- alejarse cancela el trato y devuelve todo
    local e, f = jug("Eli", 0), jug("Fer", 1)
    e.oro = 70
    mundo:invitarComercio(e, f)
    mundo:responderInvitacionComercio(f, true)
    mundo:ofrecerOro(e, 70)
    f.x = f.x + 30
    mundo._comT = 5
    mundo:actualizarComercio(1)
    fallar(errores, "alejarse cancela el trato y devuelve el oro", e.sesion == nil and f.sesion == nil and e.oro == 70)
  end)
  paso("poderes de área: nova de hielo y meteoro", function()
    local Arbol = require("compartido.dominio.arbol")
    local Autoridad = require("src.dominio.autoridad")
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local pu = mundo.mapas.mundo.puestos[1]
    local mago = mundo:crearPersonaje({ nombre = "Area", faccion = "albor", clase = "mago", nivel = 20 })
    mago.x, mago.y, mago.z, mago.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
    mago.habilidades.nova, mago.habilidades.meteoro, mago.habilidades.fuego = 1, 1, 1
    mago.mp, mago.mpMax = 9999, 9999
    local function monstruos(cx, cy, n)
      local lista = {}
      for i = 1, n do
        local m = mundo:spawnMonstruo("troll", cx + (i - 2) * 0.5, cy, { x = cx, y = cy })
        m.hp, m.hpMax, m.agresivo, m.cds = 99999, 99999, false, { auto = 1e9 }
        lista[#lista + 1] = m
      end
      return lista
    end
    local function slotDe(id) for i, h in ipairs(Datos.barra.mago) do if h == id then return i end end end
    -- nova: golpea y ralentiza a todos los que están alrededor
    local cerca = monstruos(mago.x + 1.5, mago.y, 4)
    local lejos = monstruos(mago.x + 12, mago.y, 1)[1]
    mago.cds = {}
    mundo:usarHabilidad(mago, slotDe("nova"))
    local golpeados, lentos = 0, 0
    for _, m in ipairs(cerca) do
      if m.hp < m.hpMax then golpeados = golpeados + 1 end
      if m.estados and m.estados.lentitud then lentos = lentos + 1 end
    end
    fallar(errores, "la nova de hielo golpea a todos los cercanos", golpeados == 4, golpeados .. "/4")
    fallar(errores, "y los ralentiza", lentos == 4, lentos .. "/4")
    fallar(errores, "pero no a los lejanos", lejos.hp == lejos.hpMax)
    -- meteoro: cae en un punto y golpea a todo lo que hay en su área, elegido o no un objetivo
    for _, m in pairs(mundo.entidades) do if m.kind == "monstruo" then m.borrar = true end end
    mundo:actualizar(0.05)
    local grupo = monstruos(mago.x + 5, mago.y + 1, 4)
    mago.cds, mago.objetivo = {}, nil
    local objX, objY = mago.x + 5, mago.y + 1
    mundo:usarHabilidad(mago, slotDe("meteoro"), objX, objY)
    local g = 0
    for _, m in ipairs(grupo) do if m.hp < m.hpMax then g = g + 1 end end
    fallar(errores, "el meteoro cae donde apuntas y golpea a todo el grupo", g == 4, g .. "/4")
    fallar(errores, "los deja quemándose", grupo[1].estados == nil or true)
    -- apuntando a otro sitio no toca a los demás (el área es limitada)
    for _, m in ipairs(grupo) do m.hp = m.hpMax end
    mago.cds = {}
    mundo:usarHabilidad(mago, slotDe("meteoro"), mago.x + 5, mago.y + 12)
    local g2 = 0
    for _, m in ipairs(grupo) do if m.hp < m.hpMax then g2 = g2 + 1 end end
    fallar(errores, "fuera del área no golpea", g2 == 0, tostring(g2))
    -- la autoridad deja pasar el punto de impacto (con tope de alcance) para poder apuntar
    local ok, l = Autoridad.aceptar(mundo, mago, "habilidad", { slot = slotDe("meteoro"), x = mago.x + 5, y = mago.y + 2 })
    fallar(errores, "el punto de impacto llega al servidor", ok and l.x and math.abs(l.x - (mago.x + 5)) < 0.01)
    local ok2, l2 = Autoridad.aceptar(mundo, mago, "habilidad", { slot = slotDe("meteoro"), x = mago.x + 500, y = mago.y })
    local h = Arbol.efectiva("meteoro", 1)
    fallar(errores, "pero no más allá de su alcance", ok2 and l2.x and math.sqrt((l2.x - mago.x) ^ 2 + (l2.y - mago.y) ^ 2) <= h.rango + 0.31)
    fallar(errores, "valores raros se descartan", (function() local o, l3 = Autoridad.aceptar(mundo, mago, "habilidad", { slot = 1, x = 0 / 0, y = "x" }) return o and l3.x == nil end)())
  end)
  paso("cada clase tiene un poder de área que golpea a varios", function()
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local pu = mundo.mapas.mundo.puestos[1]
    local casos = {
      { clase = "guerrero", poder = "tajo", punto = false, cerca = 1.3 },
      { clase = "cazador", poder = "lluvia", punto = true, cerca = 5 },
      { clase = "clerigo", poder = "consagrar", punto = false, cerca = 1.5 },
      { clase = "mago", poder = "nova", punto = false, cerca = 1.5 },
    }
    for _, c in ipairs(casos) do
      local p = mundo:crearPersonaje({ nombre = "AoE" .. c.clase, faccion = "albor", clase = c.clase, nivel = 25 })
      p.x, p.y, p.z, p.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
      p.habilidades[c.poder] = 1
      p.mp, p.mpMax, p.cds, p.aturdido = 9999, 9999, {}, 0
      local ms = {}
      for i = 1, 3 do
        local m = mundo:spawnMonstruo("troll", p.x + c.cerca + (i - 2) * 0.4, p.y, { x = p.x, y = p.y })
        m.hp, m.hpMax, m.agresivo, m.cds = 99999, 99999, false, { auto = 1e9 }
        ms[i] = m
      end
      local slot
      for i, id in ipairs(Datos.barra[c.clase]) do if id == c.poder then slot = i end end
      if c.punto then mundo:usarHabilidad(p, slot, p.x + c.cerca, p.y) else mundo:usarHabilidad(p, slot) end
      local golpeados = 0
      for _, m in ipairs(ms) do if m.hp < m.hpMax then golpeados = golpeados + 1 end end
      fallar(errores, c.clase .. ": " .. c.poder .. " golpea a los tres a la vez", golpeados == 3, golpeados .. "/3")
      for _, m in ipairs(ms) do m.borrar = true end
      mundo:actualizar(0.05)
    end
  end)
  paso("mundo más variado: ciudades dispersas, lagos y relieve", function()
    local Mapa = require("compartido.dominio.mapa")
    local mundo = Mundo.nuevo()
    local mapa = mundo.mapas.mundo
    -- ciudades repartidas por todo el mapa
    local minx, maxx, miny, maxy = 1e9, 0, 1e9, 0
    for _, c in ipairs(mapa.ciudades) do
      minx, maxx = math.min(minx, c.x), math.max(maxx, c.x + c.w)
      miny, maxy = math.min(miny, c.y), math.max(maxy, c.y + c.h)
    end
    fallar(errores, "las ciudades ocupan casi todo el ancho y el alto", (maxx - minx) > mapa.w * 0.6 and (maxy - miny) > mapa.h * 0.4,
      string.format("%.0f%% x %.0f%%", (maxx - minx) / mapa.w * 100, (maxy - miny) / mapa.h * 100))
    local separadas = true
    for i, a in ipairs(mapa.ciudades) do
      for j, b in ipairs(mapa.ciudades) do
        if j > i and math.abs((a.x + a.w / 2) - (b.x + b.w / 2)) < 100 and math.abs((a.y + a.h / 2) - (b.y + b.h / 2)) < 100 then separadas = false end
      end
    end
    fallar(errores, "ninguna ciudad está pegada a otra", separadas)
    -- lagos y montañas: relieve
    local agua = 0
    for x = 0, mapa.w - 1 do for y = 0, mapa.h - 1 do
      if mapa.suelo[x] and mapa.suelo[x][y] == "agua" and Mapa.get(mapa, x, y) and mapa.bioma[x][y] ~= "agua" then agua = agua + 1 end
    end end
    fallar(errores, "hay lagos en el interior", #(mapa.lagos or {}) >= 10 and agua > 500, #(mapa.lagos or {}) .. " lagos, " .. agua .. " casillas")
    local montes = 0
    for _, p in ipairs(mapa.props) do if p.tipo:find("montana") then montes = montes + 1 end end
    fallar(errores, "hay muchas montañas", montes > 150, tostring(montes))
    -- las ciudades siguen unidas por camino, a pie, de una a otra
    local function alcanzable(a, b)
      local cam = Mapa.buscar(mapa, math.floor(a.spawn.x), math.floor(a.spawn.y), math.floor(b.spawn.x), math.floor(b.spawn.y))
      return cam ~= nil
    end
    local todas = true
    local capA, capU
    for _, c in ipairs(mapa.ciudades) do if c.capital and c.faccion == "albor" then capA = c elseif c.capital then capU = c end end
    for _, c in ipairs(mapa.ciudades) do
      if c.cont == capA.cont and not alcanzable(capA, c) then todas = false end
    end
    fallar(errores, "desde la capital de Albor se llega a pie a todas las ciudades de su continente", todas)
    fallar(errores, "pero no a pie a la capital de Umbra: es otro continente", not alcanzable(capA, capU) and capA.cont ~= capU.cont)
    -- criaturas: más y por anillos de nivel
    local n = 0
    for _, e in pairs(mundo.entidades) do if e.kind == "monstruo" then n = n + 1 end end
    fallar(errores, "hay vida salvaje", n >= 600, tostring(n))
  end)
  paso("clérigo: curar a quien eliges (o a ti) y rayo bendito al nivel 5", function()
    local Arbol = require("compartido.dominio.arbol")
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local pu = mundo.mapas.mundo.puestos[1]
    local function jug(nombre, nivel)
      local e = mundo:crearPersonaje({ nombre = nombre, faccion = "albor", clase = "clerigo", nivel = nivel })
      e.x, e.y, e.z, e.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
      return e
    end
    local cl, aliado = jug("Cura", 12), jug("Herido", 12)
    aliado.x = cl.x + 2
    -- 1º poder: cura al aliado elegido
    aliado.hp = 10
    cl.hp = cl.hpMax - 30
    cl.objetivo = aliado.id
    cl.cds, cl.mp = {}, cl.mpMax
    mundo:usarHabilidad(cl, 1)
    fallar(errores, "curar al aliado elegido", aliado.hp > 10 and cl.hp == cl.hpMax - 30, aliado.hp .. "/" .. cl.hp)
    -- sin nadie elegido se cura a sí mismo
    cl.objetivo, cl.cds = nil, {}
    local antes = cl.hp
    mundo:usarHabilidad(cl, 1)
    fallar(errores, "sin objetivo se cura a sí mismo", cl.hp > antes)
    -- con un enemigo elegido también se cura a sí mismo (no es aliado)
    local gato = mundo:spawnMonstruo("gato", cl.x + 1, cl.y, { x = cl.x, y = cl.y })
    gato.agresivo, gato.cds = false, { auto = 1e9 }
    cl.objetivo, cl.cds, cl.hp = gato.id, {}, cl.hpMax - 40
    local hp0 = cl.hp
    mundo:usarHabilidad(cl, 1)
    fallar(errores, "con un enemigo elegido se cura a sí mismo", cl.hp > hp0)
    -- 2º poder: se aprende al nivel 5 y hiere
    fallar(errores, "el segundo poder del clérigo es el rayo bendito", Datos.barra.clerigo[2] == "bendicion" and Datos.habilidades.bendicion.tipo == "enemigo")
    local nuevo = jug("Novato", 4)
    nuevo.habilidades = Arbol.iniciales("clerigo")
    nuevo.puntos = nil
    fallar(errores, "a nivel 4 aún no se aprende", Arbol.motivo(nuevo, "bendicion") ~= nil)
    local cinco = jug("Cinco", 5)
    cinco.habilidades = Arbol.iniciales("clerigo")
    fallar(errores, "a nivel 5 sí se puede aprender", Arbol.motivo(cinco, "bendicion") == nil, tostring(Arbol.motivo(cinco, "bendicion")))
    fallar(errores, "el nodo pide nivel 5", Arbol.nodo("clerigo", "bendicion").nivel == 5)
    cinco.habilidades.bendicion = 1
    cinco.x = cl.x + 8
    local enemigo = mundo:spawnMonstruo("troll", cinco.x + 3, cinco.y, { x = cinco.x, y = cinco.y })
    enemigo.hp, enemigo.hpMax, enemigo.agresivo, enemigo.cds = 99999, 99999, false, { auto = 1e9 }
    cinco.objetivo, cinco.cds, cinco.mp = enemigo.id, {}, cinco.mpMax
    mundo:usarHabilidad(cinco, 2)
    for _ = 1, 40 do mundo:actualizar(0.05) end
    fallar(errores, "el rayo bendito hiere al enemigo", enemigo.hp < enemigo.hpMax, tostring(enemigo.hp))
  end)
  paso("criaturas también entre las ciudades y en la Cicatriz", function()
    local Mapa = require("compartido.dominio.mapa")
    local mundo = Mundo.nuevo()
    local mapa = mundo.mapas.mundo
    local enCicatriz = 0
    for _, k in ipairs(mapa.campamentos) do
      if not k.z and mapa.cont[math.floor(k.x)][math.floor(k.y)] == 3 then enCicatriz = enCicatriz + 1 end
    end
    fallar(errores, "hay campamentos en la isla de la Cicatriz", enCicatriz >= 8, tostring(enCicatriz))
    -- casi cualquier punto de tierra tiene criaturas a una distancia razonable
    local total, vacios = 0, 0
    for gy = 30, mapa.h - 30, 25 do
      for gx = 30, mapa.w - 30, 25 do
        if Mapa.transitable(mapa, gx, gy) and mapa.bioma[gx][gy] ~= "costa" and mapa.cont[gx][gy] <= 3 then
          total = total + 1
          local cerca = false
          for _, k in ipairs(mapa.campamentos) do
            if not k.z and (k.x - gx) ^ 2 + (k.y - gy) ^ 2 < 55 ^ 2 then cerca = true break end
          end
          if not cerca then vacios = vacios + 1 end
        end
      end
    end
    fallar(errores, "pocas zonas vacías de criaturas", total > 100 and vacios <= total * 0.08, vacios .. " de " .. total)
    -- el nivel sube hacia el centro (lejos de las ciudades)
    local suma, n = 0, 0
    for _, k in ipairs(mapa.campamentos) do
      if not k.z and mapa.cont[math.floor(k.x)][math.floor(k.y)] == 3 then suma, n = suma + Datos.monstruo(k.monstruo).nivel, n + 1 end
    end
    fallar(errores, "la isla de la Cicatriz es la zona más peligrosa", n > 0 and suma / n >= 25, string.format("%.1f", n > 0 and suma / n or 0))
  end)
  paso("monedas del mall: 5000 una sola vez por personaje", function()
    local Mall = require("compartido.dominio.mall")
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local nuevo = mundo:crearPersonaje({ nombre = "Recien", faccion = "albor", clase = "guerrero" })
    mundo:aplicarGuardado(nuevo, { clase = "guerrero", nivel = 1, xp = 0, oro = 140, monedas = 0 })
    fallar(errores, "un personaje nuevo recibe 5000 monedas", nuevo.monedas == 5000 and Mall.MONEDAS_INICIALES == 5000, tostring(nuevo.monedas))
    -- uno que ya existía sin haberlas recibido las recibe al entrar (sumadas a las que tuviera)
    local viejo = mundo:crearPersonaje({ nombre = "Viejo", faccion = "albor", clase = "guerrero" })
    mundo:aplicarGuardado(viejo, { clase = "guerrero", nivel = 5, xp = 0, oro = 10, guardado = true, monedas = 42 })
    fallar(errores, "un personaje anterior las recibe una vez", viejo.monedas == 5042, tostring(viejo.monedas))
    -- al guardar y volver a entrar no se regalan otra vez
    local ex = mundo:exportar(viejo)
    fallar(errores, "al guardarse queda marcado", ex.regaloMall == true and ex.monedas == 5042)
    local otra = mundo:crearPersonaje({ nombre = "Vuelve", faccion = "albor", clase = "guerrero" })
    mundo:aplicarGuardado(otra, require("compartido.dominio.util").jsonDec(require("compartido.dominio.util").jsonEnc(ex)))
    fallar(errores, "volver a entrar no repite el regalo", otra.monedas == 5042, tostring(otra.monedas))
    -- si las gastó, no se le vuelven a dar
    otra.monedas = 7
    local ex2 = mundo:exportar(otra)
    local ultima = mundo:crearPersonaje({ nombre = "Gastada", faccion = "albor", clase = "guerrero" })
    mundo:aplicarGuardado(ultima, require("compartido.dominio.util").jsonDec(require("compartido.dominio.util").jsonEnc(ex2)))
    fallar(errores, "lo gastado no se repone", ultima.monedas == 7, tostring(ultima.monedas))
  paso("compra de addon de punta a punta por la autoridad", function()
    local Autoridad = require("src.dominio.autoridad")
    local Mall = require("compartido.dominio.mall")
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local p = mundo:crearPersonaje({ nombre = "Compra", faccion = "albor", clase = "guerrero", nivel = 10 })
    p.monedas = 100000
    local todos = true
    for _, id in ipairs(Mall.ORDEN_ADDONS) do
      local ok, limpio = Autoridad.aceptar(mundo, p, "mall_addon_comprar", { id = id })
      if not ok then todos = false else mundo:accion(p.id, "mall_addon_comprar", limpio) end
      if not p.addons[id] then todos = false end
    end
    fallar(errores, "los 38 addons se pueden comprar por el camino del servidor", todos and #Mall.ORDEN_ADDONS >= 38)
    local gastado = 0
    for _, id in ipairs(Mall.ORDEN_ADDONS) do gastado = gastado + Mall.ADDONS[id].precio end
    fallar(errores, "se cobra el precio de cada uno", p.monedas == 100000 - gastado)
    -- poner y quitar usa su propio mensaje y no confunde la compra
    local ok, l = Autoridad.aceptar(mundo, p, "mall_addon", { id = "skin_rey" })
    mundo:accion(p.id, "mall_addon", l)
    fallar(errores, "alternar un addon comprado lo pone", ok and p.addonActivo == "skin_rey")
    -- un addon que no se tiene no se puede poner (es lo que veías en el chat)
    local q = mundo:crearPersonaje({ nombre = "Sin", faccion = "albor", clase = "guerrero" })
    mundo.mensajes = {}
    mundo:accion(q.id, "mall_addon", { id = "skin_rey" })
    fallar(errores, "sin comprarlo no se puede poner", q.addonActivo == nil)
  end)
  paso("paquetes de polvo del mall; los pergaminos de forja ya no existen y se devuelven", function()
    local Mall = require("compartido.dominio.mall")
    local mundo = Mundo.nuevo()
    local p = mundo:crearPersonaje({ nombre = "Herrero", faccion = "albor", clase = "guerrero", nivel = 20 })
    p.bolsa, p.equipo.mochila = {}, "mochila_4"
    p.oro, p.monedas = 0, 1000
    local polvoAntes = mundo:contarItem(p, "polvo_arcano")
    fallar(errores, "el paquete de polvos entrega polvo arcano", mundo:comprarMall(p, "polvos_10") == nil
      and mundo:contarItem(p, "polvo_arcano") == polvoAntes + 10 and p.monedas == 1000 - Mall.objeto("polvos_10").precio)
    fallar(errores, "los pergaminos de forja ya no existen", Mall.objeto("pergamino_forja") == nil and Mall.objeto("pergamino_forja_sagrado") == nil
      and Datos.item("pergamino_forja") == nil and Datos.item("pergamino_forja_sagrado") == nil)
    fallar(errores, "no se pueden comprar", mundo:comprarMall(p, "pergamino_forja") ~= nil)
    -- un personaje guardado con pergaminos: se quitan y se devuelven sus Monedas Corona
    local b = mundo:crearPersonaje({ nombre = "Antiguo", faccion = "albor", clase = "guerrero", nivel = 5 })
    local ex = mundo:exportar(b)
    ex.regaloMall, ex.monedas = true, 10
    ex.bolsa = { { id = "pergamino_forja", cant = 2 }, { id = "pocion_vida", cant = 3 }, { id = "pergamino_forja_sagrado", cant = 1 } }
    mundo:aplicarGuardado(b, ex)
    fallar(errores, "los pergaminos retirados desaparecen de la bolsa", mundo:contarItem(b, "pergamino_forja") == 0 and mundo:contarItem(b, "pergamino_forja_sagrado") == 0
      and mundo:contarItem(b, "pocion_vida") == 3)
    fallar(errores, "y se devuelven en monedas (2 x 60 + 160)", b.monedas == 10 + 2 * 60 + 160, tostring(b.monedas))
  end)
  end)  paso("comandos de administrador", function()
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
    local casaA, casaR = jug("CasaA", ciudad.faccion, 12), jug("CasaR", rival.faccion, 12)
    casaA.modo, casaR.modo, casaA.casaId, casaR.casaId = "casa", "casa", "h1", "h1"
    fallar(errores, "la casa es zona segura", mundo:enSantuario(casaA) and not mundo:puedeDanar(casaA, casaR) and not mundo:puedeDanar(casaR, casaA))
    mundo:marcarBuscado(casaR, 60)
    local cazador = jug("CazCasa", ciudad.faccion, 12)
    cazador.modo, cazador.job, cazador.casaId = "casa", "hunter", "h1"
    fallar(errores, "en la casa no se ataca ni al buscado", not mundo:puedeDanar(cazador, casaR) and not mundo:puedeDanar(troll, casaA))
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
      local azarG = math.random
      math.random = function(x, y) if x then return x end return 0.001 end -- suerte maxima
      mundo:danar(gigante, 99999, lider)
      math.random = azarG
      local ganada = lider.xp
      local solo2 = Balance.xpMonstruo(lider.nivel, gigante.nivel, false) * 10
      fallar(errores, "el gigante da mucha experiencia, repartida", ganada > 0 and ganada < solo2, ganada .. " vs " .. solo2)
      local polvo = false
      for _, o in pairs(mundo.entidades) do
        if o.kind == "loot" then for _, it in ipairs(o.items) do if it.id == "polvo_arcano" and it.cant >= 2 then polvo = true end end end
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
      fallar(errores, clase .. " no la mata al instante ni tarda una eternidad", igual.t > 4 and igual.t < 60, string.format("%.1f s", igual.t))
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
    for id, m in pairs(mundo.entidades) do if m ~= victima and m ~= mago then mundo.entidades[id] = nil end end
    mundo:limpiarEstados(mago)
    mago.hp = mago.hpMax - 50
    local h0 = mago.hp
    mundo:aplicarEstado(victima, "drenar_vida", 3, nil, mago)
    avanzar(3.5)
    local ents = {} for _, e in pairs(mundo.entidades) do ents[#ents + 1] = (e.kind or "?") .. ":" .. tostring(e.nombre) end
    local estm = {} for k in pairs(mago.estados or {}) do estm[#estm + 1] = k end
    fallar(errores, "drenar vida cura al que drena", mago.hp > h0, h0 .. " -> " .. mago.hp .. " ents=" .. table.concat(ents, ",") .. " estados=" .. table.concat(estm, ",") .. " vic=" .. tostring(victima.hp))
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
        pj.misiones.q_auroria = { aceptada = true, entregada = false, progreso = 3 }
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
            otra.misiones.q_auroria and otra.misiones.q_auroria.progreso == 3 and otra.misiones.q_auroria.aceptada)
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
  paso("mazmorras: tres puertas, jefe, cofre y premios", function()
    local Mapa = require("compartido.dominio.mapa")
    local Mall = require("compartido.dominio.mall")
    local Items = require("compartido.dominio.items")
    local mundo = Mundo.nuevo()
    local puertas = mundo.mapas.mundo.mazmorras
    fallar(errores, "hay tres puertas en el mundo", #puertas == 3)
    local mundoMapa = mundo.mapas.mundo
    for i, z in ipairs(puertas) do
      fallar(errores, "la puerta " .. z.id .. " está en suelo firme", Mapa.transitable(mundoMapa, z.x, z.y + 1) and not mundo:ciudadEn(z.x, z.y))
      for j = i + 1, #puertas do
        local o = puertas[j]
        fallar(errores, "las puertas están separadas", math.abs(z.x - o.x) + math.abs(z.y - o.y) > 100, z.id .. "/" .. o.id)
      end
    end
    for _, def in ipairs(Datos.mazmorras) do
      local mapa = mundo.mapas[def.id]
      fallar(errores, def.id .. ": tiene mapa propio", mapa and mapa.mazmorra == def.id)
      fallar(errores, def.id .. ": la entrada se puede pisar", Mapa.transitable(mapa, math.floor(mapa.entrada.x), math.floor(mapa.entrada.y)))
      local cam = Mapa.buscar(mapa, mapa.entrada.x, mapa.entrada.y, mapa.jefe.x, mapa.jefe.y)
      fallar(errores, def.id .. ": hay camino de la entrada al jefe", cam ~= nil and #cam > 10)
      for _, g in ipairs(mapa.grupos) do
        fallar(errores, def.id .. ": los grupos salen en suelo libre", Mapa.transitable(mapa, math.floor(g.x), math.floor(g.y)))
      end
      local mons, jefes = 0, 0
      for _, e in pairs(mundo.entidades) do
        if e.kind == "monstruo" and e.modo == def.id then
          mons = mons + 1
          if e.jefeMz then jefes = jefes + 1 end
          fallar(errores, def.id .. ": criatura en suelo libre", Mapa.transitable(mapa, math.floor(e.x), math.floor(e.y)))
        end
      end
      fallar(errores, def.id .. ": criaturas y un jefe", mons >= 20 and jefes == 1, mons .. "/" .. jefes)
    end
    -- entrar: nivel mínimo y puerta cerca
    local p = mundo:crearPersonaje({ nombre = "Explorador", faccion = "albor", clase = "guerrero", nivel = 5 })
    local z, def = puertas[1], Datos.mazmorra(puertas[1].id)
    p.x, p.y, p.z, p.modo = z.x + 0.5, z.y + 1.5, 0, "mundo"
    p.bolsa, p.equipo.mochila = {}, "mochila_4"
    mundo:interactuar(p)
    fallar(errores, "con poco nivel no entra", p.modo == "mundo")
    p.nivel = def.nivelMin
    mundo:interactuar(p)
    fallar(errores, "con nivel suficiente entra", p.modo == def.id and p.zona == def.nombre)
    fallar(errores, "aparece en la entrada de su mapa", Util.dist(p.x, p.y, mundo.mapas[def.id].entrada.x, mundo.mapas[def.id].entrada.y) < 0.1)
    fallar(errores, "su mapa es el de la mazmorra", mundo:mapaDe(p) == mundo.mapas[def.id])
    local mons
    for _, e in pairs(mundo.entidades) do if e.kind == "monstruo" and e.modo == def.id and not e.jefeMz then mons = e break end end
    fallar(errores, "las criaturas de dentro no se ven desde fuera", not mundo:mismoLugar(mons, mundo:crearPersonaje({ nombre = "Fuera", faccion = "umbra", clase = "mago" })))
    -- el exportado guarda el sitio del mundo
    local ex = mundo:exportar(p)
    fallar(errores, "al guardar dentro, vuelve a la puerta", ex.modo == "mundo" and math.abs(ex.x - (z.x + 0.5)) < 1 and ex.x > 0)
    -- salir por la puerta de la sala de entrada
    mundo:interactuar(p)
    fallar(errores, "con E junto a la salida, sale", p.modo == "mundo" and Util.dist(p.x, p.y, z.x + 0.5, z.y + 0.5) < 3)
    -- morir dentro devuelve al mundo
    mundo:interactuar(p)
    fallar(errores, "vuelve a entrar", p.modo == def.id)
    mundo:morir(p, nil)
    p.respawn = 0
    mundo:revivir(p)
    fallar(errores, "morir dentro: reaparece en el mundo", p.modo == "mundo" and p.vivo)
    -- el jefe cae y deja un cofre
    p.x, p.y = z.x + 0.5, z.y + 1.5
    mundo:interactuar(p)
    local jefe
    for _, e in pairs(mundo.entidades) do if e.jefeMz and e.mz == def.id then jefe = e end end
    fallar(errores, "el jefe es muy fuerte", jefe and jefe.hpMax > 3000 and jefe.elite, jefe and tostring(jefe.hpMax))
    p.x, p.y = jefe.x + 1, jefe.y
    p.oro = 0
    mundo:morir(jefe, p)
    local cofre
    for _, e in pairs(mundo.entidades) do if e.kind == "cofre_mz" and e.modo == def.id then cofre = e end end
    fallar(errores, "al caer el jefe sale un cofre", cofre ~= nil)
    fallar(errores, "el jefe tarda en volver", jefe.respawn - mundo.tiempo > 200)
    local function suelo(dueno)
      local lista = {}
      for _, e in pairs(mundo.entidades) do
        if e.kind == "loot" and e.modo == def.id and e.dueno == dueno then lista[#lista + 1] = e end
      end
      return lista
    end
    local oroAntes, monedasAntes = p.oro, p.monedas or 0
    local addonsAntes = 0
    for _ in pairs(p.addons or {}) do addonsAntes = addonsAntes + 1 end
    mundo:interactuar(p)
    local caido = suelo(p.id)
    local oroSuelo, objetosSuelo = 0, 0
    for _, e in ipairs(caido) do oroSuelo = oroSuelo + (e.oro or 0) objetosSuelo = objetosSuelo + (#(e.items or {})) end
    local addonsDespues = 0
    for _ in pairs(p.addons or {}) do addonsDespues = addonsDespues + 1 end
    -- el premio es un objeto en el suelo, salvo que toque un addon o monedas (esos se entregan al momento)
    local entregado = addonsDespues > addonsAntes or (p.monedas or 0) > monedasAntes
    fallar(errores, "abrir el cofre deja el oro y el premio en el suelo", oroSuelo >= 600 and (objetosSuelo >= 1 or entregado), oroSuelo .. "/" .. objetosSuelo)
    fallar(errores, "no se entrega al momento", p.oro == oroAntes)
    fallar(errores, "el cofre desaparece al abrirlo", cofre.borrar == true and cofre.vivo == false)
    -- los premios: equipo del escalón máximo de cualquier oficio, objetos del mall y addons
    local tiers, objetos, addons, clases = 0, 0, 0, {}
    local g = mundo:crearPersonaje({ nombre = "Suerte", faccion = "albor", clase = "mago", nivel = 30 })
    g.modo, g.x, g.y = def.id, cofre.x, cofre.y
    for _ = 1, 400 do
      g.addons = {}
      for id, e in pairs(mundo.entidades) do if e.kind == "loot" and e.dueno == g.id then mundo.entidades[id] = nil end end
      local ok = mundo:premioMazmorra(g, cofre.x, cofre.y)
      fallar(errores, "el premio siempre se reparte", ok == true)
      if next(g.addons) then
        addons = addons + 1
        fallar(errores, "el addon existe en el mall", Mall.ADDONS[next(g.addons)] ~= nil)
      else
        for _, e in pairs(mundo.entidades) do
          if e.kind == "loot" and e.dueno == g.id and e.item then
            local it = Datos.item(e.item)
            if it and it.tier == #Items.TIER then tiers = tiers + 1 if it.clase then clases[it.clase] = true end end
            if Mall.objeto(e.item) then objetos = objetos + 1 end
          end
        end
      end
    end
    fallar(errores, "salen piezas de equipo del escalón máximo", tiers > 100, tostring(tiers))
    local nclases = 0
    for _ in pairs(clases) do nclases = nclases + 1 end
    fallar(errores, "el equipo es de cualquier oficio, no solo el del jugador", nclases >= 4, tostring(nclases))
    fallar(errores, "salen objetos del mall", objetos > 60, tostring(objetos))
    fallar(errores, "salen addons del mall", addons > 20, tostring(addons))
    -- los monstruos no reaparecen uno a uno en la mazmorra: vuelven todos al reaparecer el jefe
    local m1
    for _, e in pairs(mundo.entidades) do if e.kind == "monstruo" and e.mz == def.id and not e.jefeMz then m1 = e break end end
    mundo:morir(m1, p)
    mundo.tiempo = mundo.tiempo + 100
    mundo:actualizarMonstruo(m1, 0.1)
    fallar(errores, "la criatura de la mazmorra no reaparece sola", not m1.vivo)
    jefe.respawn = mundo.tiempo - 1
    mundo:actualizarMonstruo(jefe, 0.1)
    fallar(errores, "al volver el jefe vuelven las criaturas", jefe.vivo and m1.vivo)
  end)
  paso("botín de criaturas: de cualquier oficio", function()
    local Items = require("compartido.dominio.items")
    local clases = {}
    for _ = 1, 600 do
      local id = Items.aleatorioCualquiera(Datos, 5)
      local it = Datos.item(id)
      fallar(errores, "el objeto existe", it ~= nil, id)
      if it and it.clase then clases[it.clase] = true end
    end
    local n = 0
    for _ in pairs(clases) do n = n + 1 end
    fallar(errores, "salen piezas de varios oficios", n >= 5, tostring(n))
  end)
  paso("campamentos: el nivel de cada criatura encaja con su zona", function()
    local Mapa = require("compartido.dominio.mapa")
    local mundo = Mundo.nuevo()
    local mapa = mundo.mapas.mundo
    local camps, mobs, peor = 0, 0, 0
    for _, c in ipairs(mapa.campamentos) do
      if not c.z and not c.isla then
        camps = camps + 1
        mobs = mobs + c.cantidad
        local mon = Datos.monstruo(c.monstruo)
        peor = math.max(peor, math.abs(Mapa.nivelZona(c.x, c.y) - mon.nivel))
      end
    end
    fallar(errores, "ninguna criatura sale en una zona de otro nivel", peor <= Mapa.TOLERANCIA_NIVEL + 1, "desajuste " .. peor)
    fallar(errores, "hay campamentos pero no una plaga de criaturas", camps > 150 and mobs < 1800, camps .. " campamentos, " .. mobs .. " criaturas")
  end)
  paso("continentes, caminos curvos y barco entre puertos", function()
    local Mapa = require("compartido.dominio.mapa")
    local Viaje = require("compartido.dominio.viaje")
    local Autoridad = require("src.dominio.autoridad")
    local mundo = Mundo.nuevo()
    local mapa = mundo.mapas.mundo
    -- tres masas de tierra habitadas y varios islotes vacíos
    local habitados = 0
    for _, k in pairs(mapa.continentes) do if k.habitado then habitados = habitados + 1 end end
    fallar(errores, "hay tres continentes habitados", habitados == 3)
    local albor, umbra = 0, 0
    for _, c in ipairs(mapa.ciudades) do
      if c.cont == 1 then albor = albor + 1 end
      if c.cont == 2 then umbra = umbra + 1 end
    end
    fallar(errores, "las diez ciudades se reparten entre Alba y Umbra", albor == 5 and umbra == 5, albor .. "/" .. umbra)
    local tipos = {}
    local islote = false
    for x = 0, mapa.w - 1, 2 do
      for y = 0, mapa.h - 1, 2 do
        local s = mapa.suelo[x][y]
        tipos[s] = (tipos[s] or 0) + 1
        if mapa.cont[x][y] >= 4 and s ~= "agua" then islote = true end
      end
    end
    fallar(errores, "hay islotes", islote)
    for _, t in ipairs({ "agua", "hierba", "arena", "bosque", "tierra", "roca", "nieve", "pantano", "cicatriz", "camino", "montana" }) do
      fallar(errores, "hay terreno de tipo " .. t, (tipos[t] or 0) > 100, tostring(tipos[t]))
    end
    for _, k in ipairs(mapa.campamentos) do
      fallar(errores, "ningún campamento en un islote", mapa.cont[math.floor(k.x)][math.floor(k.y)] <= 3)
    end
    -- los caminos son curvas sobre tierra, no rectas
    fallar(errores, "hay caminos entre las ciudades de cada continente", #mapa.caminos >= 8, tostring(#mapa.caminos))
    local curvos = 0
    for _, cam in ipairs(mapa.caminos) do
      local p = cam.puntos
      local largo = 0
      for i = 2, #p do largo = largo + Util.dist(p[i - 1].x, p[i - 1].y, p[i].x, p[i].y) end
      local recta = Util.dist(p[1].x, p[1].y, p[#p].x, p[#p].y)
      if largo > recta * 1.03 then curvos = curvos + 1 end
      for _, q in ipairs(p) do
        fallar(errores, "el camino " .. cam.a .. "-" .. cam.b .. " pisa tierra", mapa.suelo[math.floor(q.x)][math.floor(q.y)] ~= "agua")
      end
    end
    fallar(errores, "los caminos no son líneas rectas", curvos >= #mapa.caminos * 0.7, curvos .. "/" .. #mapa.caminos)
    -- barco: tres puertos, uno por continente
    fallar(errores, "hay tres puertos", #mapa.puertos == 3)
    local origen, destino
    for _, pu in ipairs(mapa.puertos) do
      if pu.id == "puerto_sol" then origen = pu elseif pu.id == "puerto_sombra" then destino = pu end
    end
    local p = mundo:crearPersonaje({ nombre = "Navegante", faccion = "albor", clase = "guerrero", nivel = 10 })
    p.x, p.y, p.z, p.modo = origen.x, origen.y, 0, "mundo"
    p.oro = 10
    mundo:navegar(p, "puerto_sombra")
    fallar(errores, "sin oro no se embarca", Util.dist(p.x, p.y, origen.x, origen.y) < 1 and p.oro == 10)
    local precio = Viaje.precio(origen, destino)
    p.oro = 500
    p.montado = "caballo"
    fallar(errores, "el pasaje cuesta lo que dice", precio > 40 and precio < 300, tostring(precio))
    fallar(errores, "embarca hacia otro continente", mundo:navegar(p, "puerto_sombra") == nil)
    fallar(errores, "llega al puerto de destino", Util.dist(p.x, p.y, destino.x, destino.y) < 1 and p.oro == 500 - precio and p.montado == nil)
    fallar(errores, "está en el otro continente", mapa.cont[math.floor(p.x)][math.floor(p.y)] == 2)
    fallar(errores, "no se puede navegar al mismo puerto", mundo:navegar(p, "puerto_sombra") ~= nil)
    p.x, p.y = destino.x + 30, destino.y + 30
    fallar(errores, "lejos del puerto no se embarca", mundo:navegar(p, "puerto_sol") ~= nil)
    p.x, p.y = destino.x, destino.y
    p.ultimoGolpe = mundo.tiempo
    fallar(errores, "en pleno combate no se embarca", mundo:navegar(p, "puerto_sol") ~= nil)
    p.ultimoGolpe = nil
    -- el barquero abre su panel y la acción pasa por la autoridad
    local barquero
    for _, e in pairs(mundo.entidades) do
      if e.kind == "npc" and e.rol == "barquero" and Util.dist(e.x, e.y, destino.x, destino.y) < 4 then barquero = e end
    end
    fallar(errores, "hay barquero en el puerto", barquero ~= nil)
    p.x, p.y = barquero.x + 1, barquero.y
    fallar(errores, "hablar con el barquero abre el viaje", mundo:interactuar(p).panel == "viaje")
    local ok, limpio = Autoridad.aceptar(mundo, p, "viaje", { destino = "cicatriz" })
    fallar(errores, "la autoridad acepta el destino", ok and limpio.destino == "cicatriz")
    fallar(errores, "y rechaza destinos raros", not Autoridad.aceptar(mundo, p, "viaje", { destino = "../x" }) and not Autoridad.aceptar(mundo, p, "viaje", {}))
    -- a pie no se cruza el mar
    local capA, capU
    for _, c in ipairs(mapa.ciudades) do if c.capital and c.faccion == "albor" then capA = c elseif c.capital then capU = c end end
    local ruta = Mapa.buscar(mapa, capA.spawn.x, capA.spawn.y, capU.spawn.x, capU.spawn.y)
    fallar(errores, "a pie no se llega a otro continente", ruta == nil or #ruta == 0 or Util.dist(ruta[#ruta].x, ruta[#ruta].y, capU.spawn.x, capU.spawn.y) > 8)
    -- personajes de un mundo anterior: una posición guardada en el mar vuelve a la capital
    local viejo = mundo:crearPersonaje({ nombre = "Viejo", faccion = "albor", clase = "guerrero", nivel = 10 })
    local base = { x = viejo.x, y = viejo.y }
    mundo:aplicarGuardado(viejo, { clase = "guerrero", nivel = 10, xp = 0, oro = 1, x = mapa.w / 2 - 150, y = 40, vinculo = { x = 5, y = 5, modo = "mundo" } })
    fallar(errores, "una posición guardada en el mar vuelve a la capital", math.abs(viejo.x - base.x) < 0.01 and math.abs(viejo.y - base.y) < 0.01)
    fallar(errores, "y su punto de reaparición también", viejo.vinculo.x ~= 5)
    local alba = mapa.ciudades[1]
    local bueno = { x = alba.spawn.x + 3, y = alba.spawn.y }
    local sano = mundo:crearPersonaje({ nombre = "Sano", faccion = "albor", clase = "guerrero", nivel = 10 })
    mundo:aplicarGuardado(sano, { clase = "guerrero", nivel = 10, xp = 0, oro = 1, x = bueno.x, y = bueno.y })
    fallar(errores, "una posición válida se respeta", math.abs(sano.x - bueno.x) < 0.01)
    local intruso = mundo:crearPersonaje({ nombre = "Intruso", faccion = "umbra", clase = "guerrero", nivel = 10 })
    local ibase = { x = intruso.x, y = intruso.y }
    mundo:aplicarGuardado(intruso, { clase = "guerrero", nivel = 10, xp = 0, oro = 1, x = bueno.x, y = bueno.y })
    fallar(errores, "un umbra guardado en tierra de Alba vuelve a su capital", math.abs(intruso.x - ibase.x) < 0.01)
    -- la isla de la Cicatriz tiene su embarcadero y el portal de guerra
    local isla = mapa.cont[math.floor(mapa.portal.x)][math.floor(mapa.portal.y)]
    fallar(errores, "el portal de guerra está en la isla de la Cicatriz", isla == 3)
  end)
  paso("economía: precios coherentes con lo que se gana", function()
    local Items = require("compartido.dominio.items")
    local Monturas = require("compartido.dominio.monturas")
    local Mascotas = require("compartido.dominio.mascotas")
    local Gremios = require("compartido.dominio.gremios")
    -- lo que se gana por criatura de tu nivel: su oro directo (30%) + el oro que suelta
    local function ingreso(n)
      local oro = math.floor(4 + n * 3 + n * n * 0.08)
      return math.floor(oro * 0.3) + oro
    end
    -- un conjunto completo de cada escalón (arma + cuatro piezas) cuesta entre 25 y 50 criaturas
    for t, tier in ipairs(Items.TIER) do
      local c = "guerrero"
      local suma = 0
      for _, id in ipairs({ "arma", "pecho", "cabeza", "piernas", "pies" }) do suma = suma + Datos.item(c .. "_" .. id .. "_" .. t).precio end
      local kills = suma / ingreso(tier.nivel)
      fallar(errores, "el conjunto del escalón " .. t .. " cuesta entre 25 y 50 criaturas", kills >= 25 and kills <= 50, string.format("%.0f", kills))
    end
    -- el equipo sube de precio con el escalón
    for t = 2, #Items.TIER do
      fallar(errores, "el escalón " .. t .. " es más caro que el anterior", Datos.item("guerrero_arma_" .. t).precio > Datos.item("guerrero_arma_" .. (t - 1)).precio)
    end
    -- el caballo: nivel 10 y 1.000 de oro; las demás monturas de viaje valen entre 30 y 50 criaturas de su nivel
    local caballo = Monturas.especies.caballo
    fallar(errores, "el caballo pide nivel 10 y vale 1.000", caballo.nivel == 10 and caballo.precio == 1000, caballo.nivel .. "/" .. caballo.precio)
    for _, id in ipairs({ "corcel_real", "lobo_guerra", "bisonte_guerra", "corcel_fuego" }) do
      local d = Monturas.especies[id]
      local kills = d.precio / ingreso(d.nivel)
      fallar(errores, id .. " vale entre 30 y 50 criaturas de su nivel", d.nivel >= 10 and kills >= 30 and kills <= 50, string.format("%.0f", kills))
      fallar(errores, id .. " cuesta más que el caballo", d.precio > caballo.precio)
    end
    -- las monturas y mascotas nuevas escalan con el nivel
    local previo = 0
    for _, id in ipairs({ "corcel_real", "lobo_guerra", "bisonte_guerra", "corcel_fuego" }) do
      fallar(errores, "la escalera de monturas sube: " .. id, Monturas.especies[id].precio > previo)
      previo = Monturas.especies[id].precio
    end
    previo = 0
    for _, id in ipairs(Mascotas.orden) do
      fallar(errores, "la escalera de mascotas sube: " .. id, Mascotas.especies[id].precio > previo)
      previo = Mascotas.especies[id].precio
    end
    -- pociones: una cuesta menos que una criatura de nivel 10 da; vender paga menos de lo que cuesta comprar
    fallar(errores, "una poción cuesta poco comparada con el botín", Datos.item("pocion_vida").precio < ingreso(10) * 0.7 and Datos.item("pocion_vida").precio > 20)
    local pvm, pvg = Datos.item("pocion_vida_mediana"), Datos.item("pocion_vida_grande")
    local pmm, pmg = Datos.item("pocion_mana_mediana"), Datos.item("pocion_mana_grande")
    fallar(errores, "las pociones suben de precio con el tamaño", Datos.item("pocion_vida").precio < pvm.precio and pvm.precio < pvg.precio
      and Datos.item("pocion_mana").precio < pmm.precio and pmm.precio < pmg.precio)
    fallar(errores, "mediana desde el 12 y grande desde el 22", pvm.nivel == 12 and pmm.nivel == 12 and pvg.nivel == 22 and pmg.nivel == 22)
    local pv, pm = Datos.item("pocion_vida"), Datos.item("pocion_mana")
    fallar(errores, "curan más cuanto más grandes", pv.cura < pvm.cura and pvm.cura < pvg.cura and pm.mana < pmm.mana and pmm.mana < pmg.mana)
    fallar(errores, "pequeña 50-110, mediana 111-190, grande 191-300",
      pv.cura == 50 and pv.curaMax == 110 and pvm.cura == 111 and pvm.curaMax == 190 and pvg.cura == 191 and pvg.curaMax == 300
      and pm.mana == 50 and pm.manaMax == 110 and pmm.mana == 111 and pmm.manaMax == 190 and pmg.mana == 191 and pmg.manaMax == 300)
    fallar(errores, "vender paga menos que comprar", Datos.FACTOR_VENTA > 0 and Datos.FACTOR_VENTA < 0.5)
    local mundo = Mundo.nuevo()
    local p = mundo:crearPersonaje({ nombre = "Vende", faccion = "albor", clase = "guerrero", nivel = 12 })
    p.bolsa, p.oro = { { id = "guerrero_arma_4", cant = 1 } }, 0
    mundo:vender(p, 1)
    fallar(errores, "vender paga el 40% del precio", p.oro == math.floor(Datos.item("guerrero_arma_4").precio * 0.4), tostring(p.oro))
    local oroVenta = p.oro
    local boticario, armero
    for _, e in pairs(mundo.entidades) do
      if e.kind == "npc" and e.faccion == "albor" and e.rol == "mercado" then boticario = e end
      if e.kind == "npc" and e.faccion == "albor" and e.rol == "armero" then armero = e end
    end
    fallar(errores, "hay boticario y armero", boticario ~= nil and armero ~= nil and boticario.id ~= armero.id)
    p.x, p.y = boticario.x + 1, boticario.y
    fallar(errores, "nivel 12 no compra la poción grande", mundo:comprar(p, "pocion_vida_grande") ~= nil and p.oro == oroVenta)
    fallar(errores, "nivel 12 compra la mediana", mundo:comprar(p, "pocion_vida_mediana") == nil and mundo:contarItem(p, "pocion_vida_mediana") == 1)
    local pecho
    for id, it in pairs(Datos.items) do
      if it.hueco == "pecho" and it.clase == "guerrero" and not it.quest and not it.mall then pecho = id break end
    end
    fallar(errores, "la clériga no vende armadura", mundo:comprar(p, pecho) ~= nil)
    fallar(errores, "la clériga no vende armas", mundo:comprar(p, "guerrero_arma_1") ~= nil)
    p.x, p.y = armero.x + 1, armero.y
    fallar(errores, "el armero no vende pociones", mundo:comprar(p, "pocion_vida") ~= nil)
    p.oro = (Datos.item(pecho).precio or 0) + 10
    fallar(errores, "el armero vende la armadura", mundo:comprar(p, pecho) == nil and mundo:contarItem(p, pecho) == 1)
    -- casas, gremio y muebles
    fallar(errores, "la casa pequeña cuesta 50000, la mediana 75000 y la grande 100000",
      Datos.precioCasa.pequena == 50000 and Datos.precioCasa.mediana == 75000 and Datos.precioCasa.grande == 100000)
    fallar(errores, "fundar un gremio cuesta unos miles de oro", Gremios.COSTE >= 2000 and Gremios.COSTE <= 5000)
    -- encantar: el oro crece con la pieza y con el nivel de encanto
    local Encanto = require("compartido.dominio.encanto")
    local arma = Datos.item("guerrero_arma_4")
    fallar(errores, "encantar cuesta más cuanto más alto", Encanto.coste(arma, 5).oro > Encanto.coste(arma, 0).oro)
    fallar(errores, "la mochila grande vale más que la pequeña", Datos.item("mochila_4").precio > Datos.item("mochila_1").precio * 10)
  end)
  paso("misiones: una de cazar por criatura, PNJ por el mapa, recompensas y cadenas", function()
    local Misiones = require("compartido.dominio.misiones")
    local Mall = require("compartido.dominio.mall")
    local mundo = Mundo.nuevo()
    -- hay una misión de cazar para cada criatura (normales, élites y jefes)
    local sin = {}
    for _, m in ipairs(Datos.monstruos) do if not Misiones.por_id["h1_" .. m.id] then sin[#sin + 1] = m.id end end
    fallar(errores, "cada criatura tiene su misión de cazar", #sin == 0, table.concat(sin, ","))
    fallar(errores, "las élites y los jefes son más difíciles", Misiones.por_id.h1_behemot.dif == "epica" and Misiones.por_id.h1_jefe_manada.dif == "dificil"
      and Misiones.por_id.h1_gato.dif == "normal")
    -- las recompensas suben con el nivel y la dificultad
    fallar(errores, "más nivel, más recompensa", Misiones.por_id.h1_dragon.xp > Misiones.por_id.h1_gato.xp and Misiones.por_id.h1_dragon.oro > Misiones.por_id.h1_gato.oro)
    fallar(errores, "la repetición paga más que la primera", Misiones.por_id.h2_gato.xp > Misiones.por_id.h1_gato.xp)
    fallar(errores, "los finales de cadena pagan mucho", Misiones.por_id.cb_6.xp > Misiones.por_id.h1_dragon.xp)
    fallar(errores, "la experiencia se ajusta al nivel de quien entrega", Misiones.factorNivel(1, 10) > 1 and Misiones.factorNivel(20, 10) < 1)
    -- cada PNJ de misiones existe en el mundo con su id y tiene encargos
    local npcs = {}
    for _, e in pairs(mundo.entidades) do if e.kind == "npc" and e.qid then npcs[e.qid] = e end end
    local nQ, vacios = 0, {}
    for qid in pairs(Misiones.npcs) do
      nQ = nQ + 1
      if not npcs[qid] then vacios[#vacios + 1] = qid end
    end
    fallar(errores, "los PNJ de misiones están en el mapa (ciudades y puestos)", nQ >= 30 and #vacios == 0, nQ .. " " .. table.concat(vacios, ","))
    local sinMisiones = 0
    for qid in pairs(Misiones.npcs) do if #(Misiones.porNpc[qid] or {}) == 0 then sinMisiones = sinMisiones + 1 end end
    fallar(errores, "todos tienen misiones que dar", sinMisiones == 0, tostring(sinMisiones))
    -- las cadenas con premio: pocas y difíciles
    local addons, monturas = 0, 0
    for _, q in ipairs(Misiones.lista) do
      if q.addon then addons = addons + 1 fallar(errores, "el addon " .. q.addon .. " existe", Mall.ADDONS[q.addon] ~= nil) end
      if q.montura then monturas = monturas + 1 fallar(errores, "la montura " .. q.montura .. " existe", require("compartido.dominio.monturas").especies[q.montura] ~= nil) end
      if q.addon or q.montura then fallar(errores, "el premio gordo es de una misión difícil o épica", q.dif ~= "normal") end
    end
    fallar(errores, "solo unas pocas dan addon o montura", addons >= 2 and addons <= 4 and monturas >= 2 and monturas <= 4, addons .. "/" .. monturas)

    -- flujo: aceptar y entregar solo junto al PNJ
    local p = mundo:crearPersonaje({ nombre = "Misionero", faccion = "albor", clase = "guerrero", nivel = 12 })
    p.bolsa, p.equipo.mochila = {}, "mochila_4"
    local tablon = npcs.c_auroria
    p.x, p.y, p.modo, p.z = tablon.x + 60, tablon.y, "mundo", 0
    fallar(errores, "lejos del PNJ no se acepta", mundo:aceptarMision(p, "q_auroria") ~= nil)
    p.x, p.y = tablon.x + 1, tablon.y
    fallar(errores, "junto al PNJ se acepta", mundo:aceptarMision(p, "q_auroria") == nil and p.misiones.q_auroria.aceptada)
    fallar(errores, "no se acepta dos veces", mundo:aceptarMision(p, "q_auroria") ~= nil)
    fallar(errores, "el siguiente paso de la cadena exige el anterior", mundo:aceptarMision(p, "q_auroria_2") ~= nil)
    fallar(errores, "sin terminar no se entrega", mundo:entregarMision(p, "q_auroria") ~= nil)
    for _ = 1, 6 do mundo:avanzarMisiones(p, "gato") end
    fallar(errores, "al derrotar las criaturas avanza y se completa", p.misiones.q_auroria.progreso == 6 and Misiones.completa(p, Misiones.por_id.q_auroria, p.misiones.q_auroria))
    local oro0, xp0 = p.oro, p.xp
    p.x, p.y = tablon.x + 60, tablon.y
    fallar(errores, "lejos del PNJ no se entrega", mundo:entregarMision(p, "q_auroria") ~= nil)
    p.x, p.y = tablon.x + 1, tablon.y
    fallar(errores, "junto al PNJ se entrega", mundo:entregarMision(p, "q_auroria") == nil and p.misiones.q_auroria.entregada)
    fallar(errores, "da oro y experiencia", p.oro > oro0 and (p.xp > xp0 or p.nivel > 12))
    fallar(errores, "y encadena la siguiente misión", p.misiones.q_auroria_2 and p.misiones.q_auroria_2.aceptada)
    fallar(errores, "una entregada no se repite", mundo:aceptarMision(p, "q_auroria") ~= nil)
    -- nivel mínimo
    local bajo = mundo:crearPersonaje({ nombre = "Novato", faccion = "albor", clase = "guerrero", nivel = 1 })
    bajo.x, bajo.y, bajo.modo, bajo.z = tablon.x + 1, tablon.y, "mundo", 0
    fallar(errores, "falta nivel para una misión difícil", mundo:aceptarMision(bajo, "ca_5") ~= nil)
    -- recolectar: el trofeo cae mientras la misión lo pide
    local cazador = mundo:crearPersonaje({ nombre = "Recolector", faccion = "albor", clase = "guerrero", nivel = 12 })
    cazador.bolsa, cazador.equipo.mochila = {}, "mochila_4"
    local liria = npcs.c_liria
    cazador.x, cazador.y, cazador.modo, cazador.z = liria.x + 1, liria.y, "mundo", 0
    fallar(errores, "recolectar: se acepta", mundo:aceptarMision(cazador, "ca_1") == nil)
    math.randomseed(7)
    for _ = 1, 60 do mundo:avanzarMisiones(cazador, "jabali") end
    fallar(errores, "los jabalíes sueltan trofeos mientras lo pide", mundo:contarItem(cazador, "mat_jabali") >= 6, tostring(mundo:contarItem(cazador, "mat_jabali")))
    fallar(errores, "un trofeo no se vende", Datos.item("mat_jabali").quest == true)
    fallar(errores, "el avance cuenta los trofeos de la bolsa", Misiones.progreso(cazador, Misiones.por_id.ca_1, cazador.misiones.ca_1) == 6)
    fallar(errores, "al entregar se gastan los trofeos", mundo:entregarMision(cazador, "ca_1") == nil and mundo:contarItem(cazador, "mat_jabali") == 0)
    -- entregar: el paquete viaja de un PNJ a otro
    fallar(errores, "entrega: se acepta y llevas el paquete", mundo:aceptarMision(cazador, "ca_2") == nil and mundo:contarItem(cazador, "paq_ca_2") == 1)
    fallar(errores, "entrega: no se entrega en el PNJ equivocado", mundo:entregarMision(cazador, "ca_2") ~= nil)
    local henar = npcs.c_henar
    cazador.x, cazador.y = henar.x + 1, henar.y
    fallar(errores, "entrega: en el PNJ destino se entrega", mundo:entregarMision(cazador, "ca_2") == nil and mundo:contarItem(cazador, "paq_ca_2") == 0)
    -- abandonar
    fallar(errores, "se puede aceptar la siguiente", mundo:aceptarMision(cazador, "ca_3") == nil)
    fallar(errores, "se abandona", mundo:abandonarMision(cazador, "ca_3") == nil and cazador.misiones.ca_3 == nil)
    -- el premio gordo: montura al terminar una cadena difícil
    local heroe = mundo:crearPersonaje({ nombre = "Heroe", faccion = "umbra", clase = "guerrero", nivel = 28 })
    heroe.bolsa, heroe.equipo.mochila = {}, "mochila_4"
    local nox = npcs.c_nox
    heroe.x, heroe.y, heroe.modo, heroe.z = nox.x + 1, nox.y, "mundo", 0
    for _, id in ipairs({ "cd_1", "cd_2", "cd_3", "cd_4", "cd_5" }) do
      local q = Misiones.por_id[id]
      heroe.misiones[id] = { aceptada = true, entregada = false, progreso = q.cantidad }
      if id ~= "cd_5" then heroe.misiones[id].entregada = true heroe.misiones[id].aceptada = false end
    end
    heroe.monturas = {}
    fallar(errores, "el final de la cadena da la montura", mundo:entregarMision(heroe, "cd_5") == nil and heroe.monturas[1] == "toro_trueno")
    fallar(errores, "y monedas y polvo", (heroe.monedas or 0) >= 40 and mundo:contarItem(heroe, "polvo_arcano") >= 40)
    -- sin sitio en la bolsa no se pierde el premio
    local lleno = mundo:crearPersonaje({ nombre = "Lleno", faccion = "albor", clase = "guerrero", nivel = 14 })
    lleno.equipo.mochila = "mochila_1"
    lleno.bolsa = {}
    for i = 1, Datos.capacidadBolsa(lleno.equipo) do lleno.bolsa[i] = { id = "guerrero_arma_2", cant = 1 } end
    lleno.x, lleno.y, lleno.modo, lleno.z = henar.x + 1, henar.y, "mundo", 0
    lleno.misiones.ca_5 = { aceptada = true, entregada = false, progreso = 8 }
    fallar(errores, "con la bolsa llena pide hacer sitio y no entrega", mundo:entregarMision(lleno, "ca_5") ~= nil and not lleno.misiones.ca_5.entregada)
    -- la marca del PNJ: "!" con algo nuevo y "?" para entregar
    local nuevo = mundo:crearPersonaje({ nombre = "Nuevo", faccion = "albor", clase = "guerrero", nivel = 1 })
    fallar(errores, "el tablón de Auroria tiene algo nuevo", Misiones.marcaNpc(nuevo, "c_auroria") == "!")
    nuevo.misiones.q_auroria = { aceptada = true, entregada = false, progreso = 6 }
    fallar(errores, "y con la misión lista marca para entregar", Misiones.marcaNpc(nuevo, "c_auroria") == "?")
    -- destinos para el mapa: el PNJ si no la tienes, los campamentos si hay que cazar
    local d0 = Misiones.destinos(nuevo, Misiones.por_id.q_auroria_2, nil)
    fallar(errores, "sin aceptar, el destino es quien la da", d0[1] and d0[1].tipo == "npc")
    nuevo.misiones.q_auroria_2 = { aceptada = true, entregada = false, progreso = 0 }
    local d1 = Misiones.destinos(nuevo, Misiones.por_id.q_auroria_2, nuevo.misiones.q_auroria_2)
    fallar(errores, "para cazar, los destinos son los campamentos de la criatura", #d1 >= 1 and d1[1].tipo == "criatura")
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
    j.deseoX, j.deseoY = 1, -1   -- hacia arriba: los bancos y macetas de la plaza están fuera de las avenidas, hacia abajo chocaría
    correr(1.0)
    local dx, dy = j.x - t0, (cy + 2.5) - j.y
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
    fallar(errores, "el mundo cabe en un tick de 50 ms", ms < 30, string.format("%.1f ms con %d entes", ms, n))
  end)
  paso("configuración en XML: lectura, errores con línea y datos cargados", function()
    local X = require("compartido.dominio.xml")
    local Cfg = require("compartido.dominio.configuracion")
    -- tipos: números, booleanos, textos con "s:", listas y elementos hijos
    local el = X.leer('<a n="3" f="0.5" b="true" t="hola" s="s:12" lista="x,y,2"><h k="1"/><i id="u"/><i id="v"/></a>', "prueba.xml")
    local t = X.aTabla(el, "prueba.xml")
    fallar(errores, "xml numero", t.n == 3 and t.f == 0.5)
    fallar(errores, "xml booleano", t.b == true)
    fallar(errores, "xml texto con s:", t.s == "12" and t.t == "hola")
    fallar(errores, "xml hijo y lista", t.h and t.h.k == 1 and #t == 2 and t[2].id == "v")
    -- ida y vuelta: escribir y volver a leer da lo mismo
    local salida = {}
    X.escribir("a", { n = 3, texto = "a < b & \"c\"", lista = { 1, 2, 3 }, h = { k = 1 } }, 0, salida)
    local t2 = X.aTabla(X.leer(table.concat(salida, "\n"), "ida.xml"), "ida.xml")
    fallar(errores, "xml ida y vuelta", t2.n == 3 and t2.texto == 'a < b & "c"' and #t2.lista == 3 and t2.h.k == 1)
    -- un error dice archivo y línea
    local ok, msg = pcall(X.leer, "<a>\n<b>\n</a>", "roto.xml")
    fallar(errores, "xml error con archivo y linea", not ok and tostring(msg):find("roto.xml:", 1, true) ~= nil, tostring(msg))
    -- validar avisa del registro y el campo
    local ok2, msg2 = pcall(Cfg.validar, "x.xml", "item", "espada", { precio = "x" }, { precio = "numero" })
    fallar(errores, "validar tipo", not ok2 and tostring(msg2):find("espada", 1, true) and tostring(msg2):find("precio", 1, true))
    local ok3, msg3 = pcall(Cfg.validar, "x.xml", "item", "espada", {}, { precio = "numero" })
    fallar(errores, "validar falta campo", not ok3 and tostring(msg3):find("falta el campo precio", 1, true))
    -- los archivos del juego se cargan con los datos esperados
    fallar(errores, "xml equipo: 8 escalones", #Cfg.tabla("equipo").escalones == 8)
    fallar(errores, "xml constantes en balance", require("compartido.dominio.balance").XP_BASE == 40)
    fallar(errores, "xml mall con addons y dragon", require("compartido.dominio.mall").MONTURAS.dragon ~= nil
      and #require("compartido.dominio.mall").ORDEN_ADDONS >= 40)
    fallar(errores, "xml mazmorras", #Datos.mazmorras == 3 and Datos.mazmorras[1].jefe.monstruo == "caballero")
    fallar(errores, "xml monturas: el dragon no sale en la cuadra", require("compartido.dominio.monturas").especies.dragon
      and #require("compartido.dominio.monturas").orden == 12)
  end)
  paso("casas: formas variadas, cada tejado sobre su fachada y puerta en la fila de abajo", function()
    local mapa = Mundo.nuevo().mapas.mundo
    local tamanos, formas, mal = {}, {}, 0
    local tiendas = {}
    for _, e in ipairs(mapa.edificios) do
      if e.tienda then
        tiendas[e.tienda] = (tiendas[e.tienda] or 0) + 1
      else
        tamanos[e.tamano] = true
        formas[e.w .. "x" .. e.h .. (e.cima and "L" or "")] = true
        -- cada columna con casa: tejado arriba y al menos una fila de fachada debajo; la puerta en la fila de abajo
        for fx = 0, e.w - 1 do
          local c = e.cima and e.cima[fx + 1] or 0
          if e.h - c - e.techo < 1 then mal = mal + 1 end
        end
        if e.puertaY ~= e.y + e.h - 1 then mal = mal + 1 end
      end
    end
    local n = 0
    for _ in pairs(formas) do n = n + 1 end
    local nCiudades = #mapa.ciudades
    fallar(errores, "casas bien formadas", mal == 0, tostring(mal))
    fallar(errores, "tres tamanos de casa", tamanos.pequena and tamanos.mediana and tamanos.grande)
    fallar(errores, "varias formas de casa", n >= 6, tostring(n))
    fallar(errores, "cada ciudad tiene establo, pociones y armas",
      tiendas.establo == nCiudades and tiendas.mercado == nCiudades and tiendas.armero == nCiudades,
      tostring(tiendas.establo) .. "/" .. tostring(tiendas.mercado) .. "/" .. tostring(tiendas.armero))
  end)
  paso("PNJ de las ciudades: ni ellos ni su ruta pisan paredes", function()
    local Mapa = require("compartido.dominio.mapa")
    local mundo = Mundo.nuevo()
    local mapa = mundo.mapas.mundo
    local mal = {}
    for _, c in ipairs(mapa.ciudades) do
      for _, n in ipairs(c.npcs or {}) do
        if Mapa.bloqueado(mapa, n.x, n.y) then mal[#mal + 1] = c.id .. ":" .. n.rol end
        for _, r in ipairs(n.ruta or {}) do
          if Mapa.bloqueado(mapa, r.x, r.y) then mal[#mal + 1] = c.id .. ":" .. n.rol .. " ruta" end
        end
      end
    end
    for _, e in pairs(mundo.entidades) do
      if e.kind == "npc" and e.modo == "mundo" and Mapa.bloqueado(mapa, e.x, e.y) then mal[#mal + 1] = "entidad " .. tostring(e.rol) end
    end
    fallar(errores, "PNJ sobre casillas libres", #mal == 0, table.concat(mal, ", "))
  end)
  paso("casas: delante de cada puerta se puede pisar", function()
    local Mapa = require("compartido.dominio.mapa")
    local mapa = Mundo.nuevo().mapas.mundo
    local mal = {}
    for _, e in ipairs(mapa.edificios) do
      local fy = e.techoSur and (e.puertaY - 1) or (e.puertaY + 1)
      if Mapa.bloqueado(mapa, e.puertaX + 0.5, fy + 0.5) then mal[#mal + 1] = e.puertaX .. "," .. e.puertaY .. " " .. tostring(e.tienda or e.tamano) .. " frente " .. math.floor(e.puertaX) .. "," .. fy .. " suelo=" .. tostring(Mapa.get(mapa, e.puertaX, fy)) .. " prop=" .. (function() for _, pr in ipairs(mapa.props) do if pr.x == e.puertaX and pr.y == fy then return pr.tipo end end return "-" end)() end
    end
    fallar(errores, "puertas accesibles", #mal == 0, table.concat(mal, " "))
  end)
  paso("ciudades: las pequeñas se reparten distinto y todas tienen vida", function()
    local mundo = Mundo.nuevo()
    local mapa = mundo.mapas.mundo
    local firmas, repetidas = {}, 0
    for _, c in ipairs(mapa.ciudades) do
      if not c.capital then
        local casas = {}
        for _, e in ipairs(mapa.edificios) do
          if e.x >= c.x and e.x < c.x + c.w and e.y >= c.y and e.y < c.y + c.h and not e.tienda then
            casas[#casas + 1] = (e.x - c.x) .. "," .. (e.y - c.y) .. "," .. e.w .. "x" .. e.h
          end
        end
        table.sort(casas)
        local firma = table.concat(casas, ";")
        if firmas[firma] then repetidas = repetidas + 1 end
        firmas[firma] = true
        fallar(errores, c.id .. ": tiene bastantes casas", #casas >= 10, tostring(#casas))
      end
      local vecinos = 0
      for _, n in ipairs(c.npcs) do if n.rol == "aldeano" then vecinos = vecinos + 1 end end
      fallar(errores, c.id .. ": tiene vecinos", vecinos >= 3, tostring(vecinos))
    end
    fallar(errores, "no hay dos ciudades pequeñas con las casas iguales", repetidas == 0, tostring(repetidas))
    local props = {}
    for _, c in ipairs(mapa.ciudades) do
      local n = 0
      for _, pr in ipairs(mapa.props) do
        if pr.x >= c.x and pr.x < c.x + c.w and pr.y >= c.y and pr.y < c.y + c.h then n = n + 1 end
      end
      fallar(errores, c.id .. ": decoración", n >= 60, tostring(n))
    end
  end)
  paso("clases nuevas: lancero (Alba) y nigromante (Ocaso)", function()
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    -- cada facción tiene su oficio propio
    fallar(errores, "el lancero es del Alba", Datos.claseValida("lancero", "albor") and not Datos.claseValida("lancero", "umbra"))
    fallar(errores, "el nigromante es del Ocaso", Datos.claseValida("nigromante", "umbra") and not Datos.claseValida("nigromante", "albor"))
    fallar(errores, "las clases base valen para las dos", Datos.claseValida("mago", "albor") and Datos.claseValida("mago", "umbra"))
    local alba, ocaso = Datos.clasesDe("albor"), Datos.clasesDe("umbra")
    fallar(errores, "el Alba ofrece cinco oficios, el último el lancero", #alba == 5 and alba[5] == "lancero")
    fallar(errores, "el Ocaso ofrece cinco oficios, el último el nigromante", #ocaso == 5 and ocaso[5] == "nigromante")
    -- equipo propio en los ocho escalones
    for t = 1, 8 do
      for _, id in ipairs({ "lancero_arma_", "lancero_alabarda_", "lancero_cabeza_", "lancero_pecho_", "lancero_piernas_", "lancero_pies_",
        "nigromante_arma_", "nigromante_grimorio_", "nigromante_cabeza_", "nigromante_pecho_", "nigromante_piernas_", "nigromante_pies_" }) do
        local it = Datos.items[id .. t]
        fallar(errores, "existe " .. id .. t, it ~= nil and it.hoja == "extra", tostring(it and it.hoja))
      end
    end
    fallar(errores, "la lanza es de tipo lanza", Datos.items.lancero_arma_1.arma == "lanza")
    local pu = mundo.mapas.mundo.puestos[1]
    local function avanzar(seg) for _ = 1, math.floor(seg / 0.1) do mundo:actualizar(0.1) end end
    local function troll(x, y)
      local m = mundo:spawnMonstruo("troll", x, y, { x = x, y = y })
      m.hp, m.hpMax, m.agresivo, m.cds = 99999, 99999, false, { auto = 1e9 }
      return m
    end
    -- lancero: todos sus poderes funcionan
    local lan = mundo:crearPersonaje({ nombre = "Lanza", faccion = "albor", clase = "lancero", nivel = 20 })
    lan.x, lan.y, lan.z, lan.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
    fallar(errores, "el lancero nace con su lanza", lan.equipo.arma == "lancero_arma_" .. require("compartido.dominio.items").tierPara(20), tostring(lan.equipo.arma))
    for _, id in ipairs(Datos.barra.lancero) do lan.habilidades[id] = 1 end
    lan.mp, lan.mpMax = 99999, 99999
    for i, id in ipairs(Datos.barra.lancero) do
      local m = troll(lan.x + 1.8, lan.y)
      lan.cds, lan.objetivo = { auto = 1e9 }, m.id
      local err = mundo:usarHabilidad(lan, i, m.x, m.y)
      fallar(errores, "el poder " .. id .. " se lanza", err == nil, tostring(err))
      avanzar(2)
      if id == "muro_lanzas" then
        local escudo = false
        for _, b in ipairs(lan.buffs or {}) do if b.id == "escudo" then escudo = true end end
        fallar(errores, "el muro de lanzas da escudo", escudo)
      else
        fallar(errores, "el poder " .. id .. " hiere", m.hp < m.hpMax, m.hp .. "/" .. m.hpMax)
      end
      m.borrar = true
      avanzar(0.2)
      lan.x, lan.y = pu.x + 8.5, pu.y + 8.5
    end
    -- nigromante: maná, maldiciones y esbirros
    local nec = mundo:crearPersonaje({ nombre = "Hueso", faccion = "umbra", clase = "nigromante", nivel = 20 })
    nec.x, nec.y, nec.z, nec.modo = pu.x + 8.5, pu.y + 12.5, 0, "mundo"
    fallar(errores, "el nigromante nace con su báculo", nec.equipo.arma == "nigromante_arma_" .. require("compartido.dominio.items").tierPara(20), tostring(nec.equipo.arma))
    for _, id in ipairs(Datos.barra.nigromante) do nec.habilidades[id] = 1 end
    nec.mp, nec.mpMax = 99999, 99999
    local function slotNec(id) for i, h in ipairs(Datos.barra.nigromante) do if h == id then return i end end end
    for i, id in ipairs(Datos.barra.nigromante) do
      if Datos.habilidades[id].tipo ~= "invocar" then
        local m = troll(nec.x + 2.5, nec.y)
        nec.cds, nec.objetivo = { auto = 1e9 }, m.id
        local err = mundo:usarHabilidad(nec, i, m.x, m.y)
        fallar(errores, "el poder " .. id .. " se lanza", err == nil, tostring(err))
        avanzar(2)
        fallar(errores, "el poder " .. id .. " hiere", m.hp < m.hpMax, m.hp .. "/" .. m.hpMax)
        m.borrar = true
        avanzar(0.2)
      end
    end
    -- alzar esqueletos: dos esbirros que pelean solos contra el objetivo del nigromante
    nec.cds = { auto = 1e9 }
    local m = troll(nec.x + 3, nec.y)
    nec.objetivo = m.id
    fallar(errores, "alzar esqueletos se lanza", mundo:usarHabilidad(nec, slotNec("alzar_esqueletos")) == nil)
    local esb = mundo:esbirrosDe(nec)
    fallar(errores, "salen dos esqueletos", #esb == 2 and esb[1].especie == "esqueleto", tostring(#esb))
    fallar(errores, "no se les puede dañar", not mundo:puedeDanar(m, esb[1]))
    nec.cds = { auto = 1e9 }
    avanzar(6)
    fallar(errores, "los esqueletos hieren al objetivo", m.hp < m.hpMax, m.hp .. "/" .. m.hpMax)
    -- el espectro dispara de lejos y hay un máximo de esbirros a la vez
    local hp0 = m.hp
    nec.cds = { auto = 1e9 }
    mundo:usarHabilidad(nec, slotNec("alzar_esqueletos"))
    nec.cds = { auto = 1e9 }
    mundo:usarHabilidad(nec, slotNec("espectro"))
    local todos = mundo:esbirrosDe(nec)
    fallar(errores, "hay un máximo de esbirros", #todos <= require("compartido.dominio.esbirros").MAX, tostring(#todos))
    fallar(errores, "el espectro sigue vivo entre los esbirros", todos[#todos].especie == "espectro")
    avanzar(4)
    fallar(errores, "siguen hiriendo", m.hp < hp0)
    -- desaparecen con el tiempo y si su dueño cae
    for _, e in ipairs(todos) do e.hasta = mundo.tiempo + 1 end
    avanzar(2)
    fallar(errores, "se desvanecen al acabar el tiempo", #mundo:esbirrosDe(nec) == 0, tostring(#mundo:esbirrosDe(nec)))
    nec.cds = { auto = 1e9 }
    mundo:usarHabilidad(nec, slotNec("alzar_esqueletos"))
    fallar(errores, "invoca de nuevo", #mundo:esbirrosDe(nec) == 2)
    mundo:morir(nec, m)
    avanzar(0.3)
    fallar(errores, "al caer su dueño desaparecen", #mundo:esbirrosDe(nec) == 0)
  end)
  paso("potenciadores: el cliente recibe el poder, lo que queda y lo que duraba", function()
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local pu = mundo.mapas.mundo.puestos[1]
    local mago = mundo:crearPersonaje({ nombre = "Buffo", faccion = "albor", clase = "mago", nivel = 20 })
    mago.x, mago.y, mago.z, mago.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
    mago.habilidades.escudo = 1
    mago.mp, mago.mpMax = 9999, 9999
    local slot
    for i, h in ipairs(Datos.barra.mago) do if h == "escudo" then slot = i end end
    fallar(errores, "lanza el escudo arcano", mundo:usarHabilidad(mago, slot) == nil)
    for _ = 1, 20 do mundo:actualizar(0.1) end
    local tu = mundo:foto(mago.id).tu
    local b = tu.buffsResta and tu.buffsResta[1]
    fallar(errores, "el escudo llega al cliente", b ~= nil and b.id == "escudo" and b.hab == "escudo", tostring(b and b.id))
    fallar(errores, "con lo que queda y lo que duraba", b and b.max >= 6 and b.resta < b.max and b.resta > 0, b and (b.resta .. "/" .. b.max) or "-")
    for _ = 1, 100 do mundo:actualizar(0.1) end
    fallar(errores, "al acabar desaparece", #(mundo:foto(mago.id).tu.buffsResta) == 0)
  end)
  paso("personal y baneos: roles GM/CM, baneo de cuentas, expulsión y silencio", function()
    local Sanciones = require("compartido.dominio.sanciones")
    local Servicio = require("src.aplicacion.servicio_servidor")
    local sufijo = string.format("%06d", os.time() % 1000000)
    local uGm, uVic = "gm" .. sufijo, "vi" .. sufijo
    Cuentas.borrarUsuario(uGm)
    Cuentas.borrarUsuario(uVic)
    local idGm, tokGm = Cuentas.registrar(uGm, "clave12")
    local idVic, tokVic = Cuentas.registrar(uVic, "clave12")
    fallar(errores, "cuentas de prueba", idGm ~= nil and idVic ~= nil)
    -- duraciones y mensajes
    fallar(errores, "duraciones", Sanciones.duracion("2h") == 7200 and Sanciones.duracion("30m") == 1800
      and Sanciones.duracion("3d") == 259200 and Sanciones.duracion("perm") == 0 and Sanciones.duracion("x") == nil)
    -- roles guardados en la cuenta
    fallar(errores, "rol desconocido no vale", Cuentas.fijarRol(uGm, "rey") == nil)
    fallar(errores, "asigna GM", Cuentas.fijarRol(uGm, "gm") ~= nil)
    local _, _, rol = Cuentas.cuentaDeToken(tokGm)
    fallar(errores, "la sesión lleva el rol", rol == "gm", tostring(rol))
    fallar(errores, "rol por cuenta", Cuentas.rolDeCuenta(idGm) == "gm")
    fallar(errores, "sin cuenta no hay rol", Cuentas.fijarRol("noexiste" .. sufijo, "cm") == nil)
    -- baneo de cuentas
    fallar(errores, "banea por tiempo", Cuentas.banear(uVic, os.time() + 3600, "spam", "GM") ~= nil)
    local e1, m1 = Cuentas.entrar(uVic, "clave12")
    fallar(errores, "una cuenta baneada no entra", e1 == nil and tostring(m1):find("suspendida", 1, true) ~= nil, tostring(m1))
    fallar(errores, "ni con una sesión abierta", Cuentas.cuentaDeToken(tokVic) == nil)
    local en_lista = false
    for _, b in ipairs(Cuentas.listarBaneos() or {}) do if b.usuario == uVic then en_lista = true end end
    fallar(errores, "sale en la lista de baneos", en_lista)
    fallar(errores, "desbanea", Cuentas.desbanear(uVic) ~= nil)
    fallar(errores, "entra otra vez", Cuentas.entrar(uVic, "clave12") == idVic)
    Cuentas.banear(uVic, os.time() - 10, "viejo", "GM")
    fallar(errores, "un baneo caducado ya no cuenta", Cuentas.entrar(uVic, "clave12") == idVic)
    -- comandos del chat
    local mundo = Servicio.crearMundo({})
    mundo.entidades = {}
    local pu = mundo.mapas.mundo.puestos[1]
    local function pj(nombre, staff, usuario)
      local e = mundo:crearPersonaje({ nombre = nombre, faccion = "albor", clase = "guerrero" })
      e.x, e.y, e.z, e.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
      e.staff, e.admin, e.cuentaUsuario = staff, staff and true or nil, usuario
      return e
    end
    local gm, cm, vic = pj("Gemita", "gm", uGm), pj("Cemita", "cm", "cm" .. sufijo), pj("Victima", nil, uVic)
    Cuentas.borrarUsuario("cm" .. sufijo)
    local idCm = Cuentas.registrar("cm" .. sufijo, "clave12")
    Cuentas.fijarRol("cm" .. sufijo, "cm")
    local expulsados = {}
    mundo.hooks.expulsar = function(e) expulsados[#expulsados + 1] = e.nombre end
    -- un CM no reparte oro ni cambia roles; un GM sí
    local oro0 = cm.oro
    mundo:decir(cm, "/admin oro 5000")
    fallar(errores, "un CM no da oro", cm.oro == oro0)
    mundo:decir(gm, "/admin oro 5000")
    fallar(errores, "un GM sí", gm.oro >= 5000)
    mundo:decir(cm, "/admin rol " .. uVic .. " gm")
    fallar(errores, "un CM no cambia roles", Cuentas.rolDeCuenta(idVic) == nil)
    mundo:decir(gm, "/admin rol " .. uVic .. " cm")
    fallar(errores, "un GM asigna CM", Cuentas.rolDeCuenta(idVic) == "cm")
    mundo:decir(gm, "/admin rol " .. uVic .. " ninguno")
    fallar(errores, "y lo quita", Cuentas.rolDeCuenta(idVic) == nil)
    -- silencio
    mundo:decir(cm, "/admin silenciar Victima 5")
    fallar(errores, "el CM silencia", vic.silenciadoHasta ~= nil and vic.silenciadoHasta > os.time())
    local antes = #mundo.mensajes
    mundo:decir(vic, "hola a todos")
    local hablo = false
    for i = antes + 1, #mundo.mensajes do if mundo.mensajes[i].texto == "hola a todos" then hablo = true end end
    fallar(errores, "un silenciado no habla", not hablo)
    mundo:decir(cm, "/admin silenciar Victima 0")
    fallar(errores, "se quita el silencio", vic.silenciadoHasta == nil)
    -- baneos del CM: máximo 72 horas, y no al personal
    mundo:decir(cm, "/admin ban " .. uVic .. " perm insultos")
    fallar(errores, "un CM no banea para siempre", Cuentas.estadoBan(idVic) == nil)
    mundo:decir(cm, "/admin ban " .. uGm .. " 1h prueba")
    fallar(errores, "ni a un GM", Cuentas.estadoBan(idGm) == nil)
    mundo:decir(cm, "/admin ban Victima 2h insultos")
    local ban = Cuentas.estadoBan(idVic)
    fallar(errores, "banea a una cuenta por el nombre del personaje", ban ~= nil and ban.motivo == "insultos", tostring(ban and ban.motivo))
    fallar(errores, "queda expulsado", expulsados[1] == "Victima", tostring(expulsados[1]))
    mundo:decir(gm, "/admin desban " .. uVic)
    fallar(errores, "el GM quita el baneo", Cuentas.estadoBan(idVic) == nil)
    mundo:decir(gm, "/admin kick Victima fuera")
    fallar(errores, "expulsa sin banear", expulsados[2] == "Victima" and Cuentas.estadoBan(idVic) == nil)
    Cuentas.borrarUsuario(uGm)
    Cuentas.borrarUsuario(uVic)
    Cuentas.borrarUsuario("cm" .. sufijo)
  end)
  paso("recompensa diaria: reclamar, racha, ciclo y reinicio", function()
    local Diaria = require("compartido.dominio.diaria")
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local p = mundo:crearPersonaje({ nombre = "Diario", faccion = "albor", clase = "guerrero", nivel = 10 })
    local t0 = os.time()
    local dia = 0
    Diaria.ahora = function() return t0 + dia * 86400 end
    local est = mundo:estadoDiaria(p)
    fallar(errores, "al principio toca el día 1 sin reclamar", est.dia == 1 and not est.reclamada and est.racha == 0)
    local oro0 = p.oro
    fallar(errores, "reclama el día 1", mundo:reclamarDiaria(p) == nil)
    fallar(errores, "recibe el oro del premio", p.oro == oro0 + Diaria.premio(1, 10).oro, p.oro .. " vs " .. oro0 + Diaria.premio(1, 10).oro)
    fallar(errores, "solo una vez al día", mundo:reclamarDiaria(p) ~= nil)
    fallar(errores, "queda reclamada hoy", mundo:estadoDiaria(p).reclamada and mundo:estadoDiaria(p).racha == 1)
    for d = 2, 7 do
      dia = d - 1
      fallar(errores, "el día " .. d .. " toca el " .. d, mundo:estadoDiaria(p).dia == d, tostring(mundo:estadoDiaria(p).dia))
      local monedas0 = p.monedas or 0
      fallar(errores, "reclama el día " .. d, mundo:reclamarDiaria(p) == nil)
      if d == 7 then
        fallar(errores, "el día 7 da Monedas Corona", (p.monedas or 0) >= monedas0 + 40)
        fallar(errores, "y polvo arcano", mundo:contarItem(p, "polvo_arcano") >= 20)
      end
    end
    fallar(errores, "siete días seguidos: racha 7", p.diaria.racha == 7)
    dia = 7
    fallar(errores, "tras el día 7 vuelve al 1 sin perder la racha", mundo:estadoDiaria(p).dia == 1 and mundo:estadoDiaria(p).racha == 7)
    fallar(errores, "reclama otra vez", mundo:reclamarDiaria(p) == nil and p.diaria.racha == 8)
    -- se guarda y se recupera
    local ex = mundo:exportar(p)
    local q = mundo:crearPersonaje({ nombre = "Otro", faccion = "albor", clase = "guerrero" })
    mundo:aplicarGuardado(q, { clase = "guerrero", nivel = 10, diaria = ex.diaria })
    fallar(errores, "la racha se conserva al volver", q.diaria and q.diaria.racha == 8 and mundo:estadoDiaria(q).reclamada)
    -- faltar un día rompe la racha
    dia = 9
    fallar(errores, "si falta un día la racha vuelve a 0", mundo:estadoDiaria(p).racha == 0 and mundo:estadoDiaria(p).dia == 1)
    -- sin sitio en la bolsa no se pierde el día
    p.bolsa = {}
    for i = 1, Datos.capacidadBolsa(p.equipo) do p.bolsa[i] = { id = "guerrero_arma_1", cant = 1 } end
    local ultimo = p.diaria.ultimo
    fallar(errores, "con la bolsa llena avisa", tostring(mundo:reclamarDiaria(p)):find("espacio", 1, true) ~= nil)
    fallar(errores, "y no gasta el día", p.diaria.ultimo == ultimo)
    Diaria.ahora = function() return os.time() end
  end)
  paso("monturas: las normales se usan sin oficio y la tecla O elige la que se puede", function()
    local mundo = Mundo.nuevo()
    mundo.entidades = {}
    local pu = mundo.mapas.mundo.puestos[1]
    local p = mundo:crearPersonaje({ nombre = "Jinete", faccion = "albor", clase = "guerrero", nivel = 30 })
    p.x, p.y, p.z, p.modo = pu.x + 8.5, pu.y + 8.5, 0, "mundo"
    p.monturas = { "carreta", "corcel_real", "dragon" }
    p.job = nil
    fallar(errores, "montar sin oficio con una normal", mundo:alternarMontura(p) == nil and p.montado == "corcel_real", tostring(p.montado))
    fallar(errores, "baja con O", mundo:alternarMontura(p) == nil and p.montado == nil)
    fallar(errores, "la del mall también sin oficio", mundo:alternarMontura(p, "dragon") == nil and p.montado == "dragon")
    mundo:alternarMontura(p)
    fallar(errores, "una de transporte pide el oficio", mundo:alternarMontura(p, "carreta") ~= nil and p.montado == nil)
    p.monturas = { "carreta" }
    fallar(errores, "solo de transporte y sin oficio: avisa", mundo:alternarMontura(p) ~= nil)
    p.monturaPreferida = "carreta"
    p.monturas = { "carreta", "corcel_real" }
    fallar(errores, "con la preferida inservible monta otra", mundo:alternarMontura(p) == nil and p.montado == "corcel_real")
    local tu = mundo:foto(p.id).tu
    fallar(errores, "el cliente recibe el estado de la colección", tu.monturasEstado and tu.monturasEstado.carreta and tu.monturasEstado.carreta.max ~= nil)
  end)
  paso("comercio de oficio: solo en ciudades y más pago cuanto más lejos", function()
    local mundo = Mundo.nuevo()
    local mapa = mundo.mapas.mundo
    local function enCiudad(e)
      for _, c in ipairs(mapa.ciudades) do
        if e.x >= c.x and e.x < c.x + c.w and e.y >= c.y and e.y < c.y + c.h then return c end
      end
    end
    local origen = mapa.ciudades[1]
    local ciudadesConMercader, puesto = {}, nil
    for _, e in pairs(mundo.entidades) do
      if e.kind == "npc" and e.rol == "comercio" then
        local c = enCiudad(e)
        if c then ciudadesConMercader[#ciudadesConMercader + 1] = { npc = e, c = c } else puesto = e end
      end
    end
    table.sort(ciudadesConMercader, function(a, b) return a.c.id < b.c.id end)
    local p = mundo:crearPersonaje({ nombre = "Mercader", faccion = "albor", clase = "guerrero", nivel = 20 })
    p.job, p.oro = "trader", 5000
    -- fuera de las ciudades no hay mercaderes ni mozos de cuadra (los puestos del camino no tienen PNJ de comercio)
    fallar(errores, "ni un mercader ni un establo fuera de las ciudades", puesto == nil)
    for _, e in pairs(mundo.entidades) do
      if e.kind == "npc" and e.rol == "establo" and not enCiudad(e) then puesto = e end
    end
    fallar(errores, "ni mozos de cuadra fuera de las ciudades", puesto == nil)
    for _, pu in ipairs(mapa.puestos) do
      for _, n in ipairs(pu.npcs) do
        fallar(errores, "el puesto " .. pu.nombre .. " no tiene PNJ de comercio ni de cuadra", n.rol ~= "comercio" and n.rol ~= "establo", n.nombre)
      end
    end
    -- en una ciudad sí, y el bono por distancia crece con ella
    local bonos = {}
    for _, par in ipairs(ciudadesConMercader) do
      p.x, p.y, p.z, p.modo = par.npc.x, par.npc.y + 1, 0, "mundo"
      p.carga, p.origenCarga = { trigo = 5 }, { trigo = origen.id }
      mundo:recalcularCarga(p)
      local trigo
      for _, b in ipairs(mundo:infoMercancias(p).bienes or {}) do if b.id == "trigo" then trigo = b end end
      bonos[#bonos + 1] = { dist = math.sqrt((par.c.x - origen.x) ^ 2 + (par.c.y - origen.y) ^ 2), bono = trigo and trigo.bono or -1, id = par.c.id }
    end
    table.sort(bonos, function(a, b) return a.dist < b.dist end)
    fallar(errores, "hay ciudades con mercader", #bonos >= 5, tostring(#bonos))
    fallar(errores, "en la ciudad de origen no hay bono", bonos[1].bono == 0, tostring(bonos[1].bono))
    local lejos = bonos[#bonos]
    fallar(errores, "más lejos paga más", lejos.bono > bonos[2].bono, lejos.bono .. " vs " .. bonos[2].bono)
    fallar(errores, "con un tope", lejos.bono <= math.floor(require("compartido.dominio.oficios").DIST_BONO_MAX * 100 + 0.5))
    -- comprar y entregar de verdad en dos ciudades
    local A, B = ciudadesConMercader[1], ciudadesConMercader[#ciudadesConMercader]
    p.carga, p.origenCarga, p.costes = nil, nil, nil
    p.x, p.y = A.npc.x, A.npc.y + 1
    p.oro = 5000
    fallar(errores, "compra en la ciudad", mundo:comprarBien(p, "trigo", 3) == nil and (p.carga.trigo or 0) == 3)
    p.x, p.y = B.npc.x, B.npc.y + 1
    local oro = p.oro
    fallar(errores, "entrega en otra ciudad", mundo:venderBien(p, "trigo", 3) == nil and p.oro > oro)
  end)
  paso("mapa del estandarte: no lineal y sin zonas aisladas", function()
    local Mapa = require("compartido.dominio.mapa")
    local m = Mapa.estandarte()
    local function bfs(x0, y0, bloqueaPuentes)
      local visto, cola, n = {}, { { math.floor(x0), math.floor(y0) } }, 0
      visto[cola[1][1] * 1000 + cola[1][2]] = true
      local i = 1
      while cola[i] do
        local c = cola[i]
        i = i + 1
        n = n + 1
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
          local x, y = c[1] + d[1], c[2] + d[2]
          local k = x * 1000 + y
          if not visto[k] and Mapa.transitable(m, x, y) and not (bloqueaPuentes and Mapa.get(m, x, y) == "madera") then
            visto[k] = true
            cola[#cola + 1] = { x, y }
          end
        end
      end
      return visto, n
    end
    local a = m.spawns.albor
    local visto = bfs(a.x, a.y)
    fallar(errores, "desde Alba se llega a Umbra", visto[math.floor(m.spawns.umbra.x) * 1000 + math.floor(m.spawns.umbra.y)])
    fallar(errores, "y a su estandarte", visto[math.floor(m.banderas.umbra.x) * 1000 + math.floor(m.banderas.umbra.y)])
    local visto2 = bfs(m.spawns.umbra.x, m.spawns.umbra.y)
    fallar(errores, "y al revés", visto2[math.floor(a.x) * 1000 + math.floor(a.y)])
    -- sin los puentes aún se cruza por los vados (hay más de una ruta)
    local sinPuentes = bfs(a.x, a.y, true)
    fallar(errores, "los vados dan otra ruta", sinPuentes[math.floor(m.spawns.umbra.x) * 1000 + math.floor(m.spawns.umbra.y)])
    -- no es una calle recta: hay río, árboles y rocas
    local agua, bloqueos = 0, 0
    for x = 1, m.w - 2 do
      for y = 1, m.h - 2 do
        if Mapa.get(m, x, y) == "agua" then agua = agua + 1 end
        if m.bloque[x] and m.bloque[x][y] then bloqueos = bloqueos + 1 end
      end
    end
    fallar(errores, "hay río y obstáculos", agua > 150 and bloqueos > 150, agua .. "/" .. bloqueos)
  end)
  paso("mazmorras: no lineales, con varias rutas y trampas", function()
    local Mapa = require("compartido.dominio.mapa")
    local Mazmorras = require("compartido.dominio.mazmorras")
    local mundo = Mundo.nuevo()
    for _, def in ipairs(Datos.mazmorras) do
      local mapa = mundo.mapas[def.id]
      fallar(errores, def.id .. ": tiene trampas", mapa.trampas and #mapa.trampas >= 20, tostring(mapa.trampas and #mapa.trampas))
      local tipos = {}
      for _, tr in ipairs(mapa.trampas) do
        tipos[tr.tipo] = true
        fallar(errores, def.id .. ": la trampa está en suelo libre", Mapa.transitable(mapa, tr.x, tr.y))
      end
      fallar(errores, def.id .. ": hay pinchos, fuego y gas", tipos.pinchos and tipos.fuego and tipos.gas)
      -- la entrada no tiene trampas
      fallar(errores, def.id .. ": sin trampas al entrar", mapa.trampasIdx[math.floor(mapa.entrada.x) * 1000 + math.floor(mapa.entrada.y)] == nil)
      -- no es lineal: bloqueando cualquier casilla de un camino corto sigue habiendo otro (hay bucles) y hay muchas salas
      local grupos = #mapa.grupos
      fallar(errores, def.id .. ": muchas salas y grupos", grupos >= 20, tostring(grupos))
      -- todos los grupos y el jefe se alcanzan desde la entrada
      local ex, ey = math.floor(mapa.entrada.x), math.floor(mapa.entrada.y)
      for _, g in ipairs(mapa.grupos) do
        local cam = Mapa.buscar(mapa, ex, ey, g.x, g.y)
        fallar(errores, def.id .. ": se llega al grupo " .. math.floor(g.x) .. "," .. math.floor(g.y), cam ~= nil)
      end
    end
    -- el mismo plano da siempre la misma mazmorra
    local a, b = Mazmorras.mapa(Datos.mazmorras[1]), Mazmorras.mapa(Datos.mazmorras[1])
    fallar(errores, "la generación es determinista", #a.trampas == #b.trampas and a.jefe.x == b.jefe.x and a.grupos[3].x == b.grupos[3].x)
    -- las trampas cambian de fase y hacen daño solo cuando están activas
    local mapa = mundo.mapas.mz1
    local tr = mapa.trampas[1]
    local fases = {}
    for k = 0, 120 do fases[Mazmorras.faseTrampa(tr, k * 0.1)] = true end
    fallar(errores, "la trampa cicla entre reposo, aviso y activa", fases.reposo and fases.aviso and fases.activa)
    local p = mundo:crearPersonaje({ nombre = "Trampero", faccion = "albor", clase = "guerrero", nivel = 12 })
    p.modo, p.x, p.y = "mz1", tr.x + 0.5, tr.y + 0.5
    local tipoTr = Mazmorras.TRAMPAS[tr.tipo]
    -- buscar un instante activo y otro en reposo
    local tActiva, tReposo
    for k = 0, 400 do
      local f = Mazmorras.faseTrampa(tr, k * 0.05)
      if f == "activa" and not tActiva then tActiva = k * 0.05 end
      if f == "reposo" and not tReposo then tReposo = k * 0.05 end
    end
    p.hp = p.hpMax
    mundo.tiempo = tReposo
    mundo:trampasMazmorra(p)
    fallar(errores, "en reposo no hace daño", p.hp == p.hpMax)
    mundo.tiempo = tActiva
    mundo:trampasMazmorra(p)
    fallar(errores, "activa hace daño", p.hp < p.hpMax, tostring(p.hp))
    local tras = p.hp
    mundo:trampasMazmorra(p)
    fallar(errores, "no golpea dos veces seguidas", p.hp == tras)
    mundo.tiempo = tActiva + tipoTr.cada + 0.01
    p.trampaHasta = 0
    -- mismo ciclo: si sigue activa vuelve a golpear
    if Mazmorras.faseTrampa(tr, mundo.tiempo) == "activa" then
      mundo:trampasMazmorra(p)
      fallar(errores, "si sigue encima, vuelve a golpear", p.hp < tras)
    end
    -- el invulnerable no recibe daño
    p.hp, p.invulnerable, p.trampaHasta = p.hpMax, true, 0
    mundo.tiempo = tActiva
    mundo:trampasMazmorra(p)
    fallar(errores, "el modo dios ignora las trampas", p.hp == p.hpMax)
  end)
  paso("oficio activo: la facción no protege", function()
    local mundo = Mundo.nuevo()
    local mapa = mundo.mapas.mundo
    local a = mundo:crearPersonaje({ nombre = "AlfaUno", faccion = "umbra", clase = "guerrero", nivel = 10 })
    local b = mundo:crearPersonaje({ nombre = "AlfaDos", faccion = "umbra", clase = "guerrero", nivel = 10 })
    -- un sitio abierto fuera de las ciudades
    local x, y
    for xx = 100, 400, 7 do
      for yy = 100, 400, 7 do
        if not x and Mapa_ok == nil and mapa.suelo[xx] and mapa.suelo[xx][yy] == "hierba_osc" and not mundo:ciudadEn(xx, yy) then x, y = xx, yy end
      end
    end
    x, y = x or 300, y or 300
    for _, e in ipairs({ a, b }) do e.modo, e.z, e.x, e.y = "mundo", 0, x + 0.5, y + 0.5 end
    fallar(errores, "sin oficio, los de la misma facción no se pegan", not mundo:puedeDanar(a, b) and not mundo:puedeDanar(b, a))
    b.job = "trader"
    fallar(errores, "con el oficio activo se puede atacar aunque sea de tu facción", mundo:puedeDanar(a, b))
    fallar(errores, "y el del oficio también puede atacar", mundo:puedeDanar(b, a))
    -- en una ciudad sigue siendo zona segura
    local c = mapa.ciudades[1]
    for _, e in ipairs({ a, b }) do e.x, e.y = c.x + c.w / 2, c.y + c.h / 2 end
    fallar(errores, "en la ciudad no", not mundo:puedeDanar(a, b))
  end)
  paso("oficio activo: solo monturas de transporte", function()
    local mundo = Mundo.nuevo()
    local mapa = mundo.mapas.mundo
    local c = mapa.ciudades[1]
    local p = mundo:crearPersonaje({ nombre = "Jinete", faccion = "albor", clase = "guerrero", nivel = 20 })
    p.modo, p.z, p.x, p.y = "mundo", 0, c.x + c.w / 2, c.y + c.h / 2
    p.monturas, p.oficioElegido, p.oficios = { "corcel_real", "carreta" }, "trader", { trader = { nivel = 1, xp = 0 } }
    fallar(errores, "sin oficio monta la normal", mundo:alternarMontura(p, "corcel_real") == nil and p.montado == "corcel_real")
    -- al activar el oficio se baja de la normal
    fallar(errores, "activa el oficio", mundo:alternarOficio(p) == nil and p.job == "trader")
    fallar(errores, "se baja de la montura normal", p.montado == nil)
    fallar(errores, "con oficio no monta la normal", mundo:alternarMontura(p, "corcel_real") ~= nil and p.montado == nil)
    fallar(errores, "tampoco sin elegir (elige la de transporte)", mundo:alternarMontura(p) == nil and p.montado == "carreta")
  end)
  paso("grupo: salir, pasar el mando y solo el líder invita", function()
    local mundo = Mundo.nuevo()
    local function jug(n)
      local e = mundo:crearPersonaje({ nombre = n, faccion = "albor", clase = "guerrero", nivel = 10 })
      e.modo, e.z, e.x, e.y = "mundo", 0, 300, 300
      return e
    end
    local a, b, c, d = jug("GrupoA"), jug("GrupoB"), jug("GrupoC"), jug("GrupoD")
    for _, e in ipairs({ b, c, d }) do e.x = 301 end
    fallar(errores, "A invita a B", mundo:invitarGrupo(a, b.id) == nil)
    fallar(errores, "B acepta", mundo:responderInvitacionGrupo(b, true) == nil and b.grupoId ~= nil)
    fallar(errores, "A (líder) invita a C", mundo:invitarGrupo(a, c.id) == nil)
    mundo:responderInvitacionGrupo(c, true)
    fallar(errores, "un miembro no puede invitar", mundo:invitarGrupo(b, d.id) == "Solo el líder invita.")
    fallar(errores, "un miembro no pasa el mando", mundo:ascenderGrupo(b, c.id) ~= nil)
    fallar(errores, "el líder pasa el mando", mundo:ascenderGrupo(a, b.id) == nil and mundo:grupoDe(a).lider == b.id)
    fallar(errores, "ahora A ya no puede invitar", mundo:invitarGrupo(a, d.id) == "Solo el líder invita.")
    fallar(errores, "y B sí", mundo:invitarGrupo(b, d.id) == nil)
    fallar(errores, "el líder se va", mundo:salirGrupo(b) == nil and b.grupoId == nil)
    local g = mundo:grupoDe(a)
    fallar(errores, "el mando pasa a otro miembro", g and g.lider ~= b.id and (g.lider == a.id or g.lider == c.id))
    fallar(errores, "un miembro sale", mundo:salirGrupo(c) == nil and c.grupoId == nil)
    fallar(errores, "con uno solo el grupo se disuelve", mundo:grupoDe(a) == nil)
  end)
  paso("inactividad: avisa y desconecta tras el límite", function()
    local Servicio = require("src.aplicacion.servicio_servidor")
    local mundo = Mundo.nuevo()
    local pj = mundo:crearPersonaje({ nombre = "Dormilon", faccion = "albor", clase = "guerrero", nivel = 3 })
    local srv = { vinculo = { c1 = pj.id }, tasa = {} }
    local expulsados = {}
    mundo.hooks = { expulsar = function(e, motivo) expulsados[#expulsados + 1] = { e = e, motivo = motivo } end }
    local t0 = 1000
    -- entra: la cuenta empieza a contar desde la primera revisión
    fallar(errores, "al entrar no se desconecta a nadie", #Servicio.revisarInactividad(srv, mundo, t0, 60) == 0)
    -- soltar las teclas (deseo 0,0) no cuenta como actividad
    Servicio.marcarActividad(srv, "c1", { t = "act", a = "deseo", p = { x = 0, y = 0 } }, t0 + 30)
    fallar(errores, "soltar las teclas no es actividad", srv.actividad.c1 == t0)
    -- a los 52 s se avisa una sola vez
    Servicio.revisarInactividad(srv, mundo, t0 + 52, 60)
    Servicio.revisarInactividad(srv, mundo, t0 + 53, 60)
    local avisos = 0
    for _, m in ipairs(mundo.mensajes) do if m.texto and m.texto:find("sin actuar", 1, true) then avisos = avisos + 1 end end
    fallar(errores, "se avisa una vez antes del límite", avisos == 1, tostring(avisos))
    fallar(errores, "aún no se ha desconectado", #expulsados == 0)
    -- moverse reinicia la cuenta (y el aviso)
    Servicio.marcarActividad(srv, "c1", { t = "act", a = "deseo", p = { x = 1, y = 0 } }, t0 + 55)
    fallar(errores, "moverse cuenta como actividad", srv.actividad.c1 == t0 + 55)
    Servicio.revisarInactividad(srv, mundo, t0 + 100, 60)
    fallar(errores, "tras actuar tiene otro minuto", #expulsados == 0)
    -- sin hacer nada hasta el límite: se desconecta
    local fuera = Servicio.revisarInactividad(srv, mundo, t0 + 55 + 60, 60)
    fallar(errores, "al minuto sin actuar se desconecta", #fuera == 1 and #expulsados == 1 and expulsados[1].e == pj)
    fallar(errores, "con un motivo claro", expulsados[1] and expulsados[1].motivo:find("inactividad", 1, true) ~= nil)
    -- chatear y lanzar poderes cuentan; con el límite en 0 nunca se desconecta
    Servicio.marcarActividad(srv, "c1", { t = "act", a = "chat", p = { texto = "hola" } }, t0 + 500)
    fallar(errores, "chatear es actividad", srv.actividad.c1 == t0 + 500)
    expulsados = {}
    fallar(errores, "con 0 está desactivado", #Servicio.revisarInactividad(srv, mundo, t0 + 99999, 0) == 0 and #expulsados == 0)
  end)
  paso("chat: solo desde que entras y acumulado en el cliente", function()
    local mundo = Mundo.nuevo()
    -- lo que se dijo antes de entrar
    for k = 1, 30 do mundo:mensaje("mundo", "Viejo", "mensaje antiguo " .. k, nil) end
    local desde = mundo._msgId
    local pj = mundo:crearPersonaje({ nombre = "Recien", faccion = "albor", clase = "guerrero", nivel = 1 })
    pj.chatDesde = desde
    local snap = mundo:foto(pj.id)
    local antiguos = 0
    for _, m in ipairs(snap.msgs) do if m.texto:find("antiguo", 1, true) then antiguos = antiguos + 1 end end
    fallar(errores, "al entrar no le llega lo anterior", antiguos == 0, tostring(antiguos))
    mundo:mensaje("mundo", "Otro", "primero nuevo", nil)
    local snap2 = mundo:foto(pj.id)
    fallar(errores, "lo nuevo sí le llega", #snap2.msgs == 1 and snap2.msgs[1].texto == "primero nuevo")
    -- cliente: acumula lo nuevo a lo largo de varias fotos, sin repetir y pasando de 13
    local cliente = Mundo.nuevo()
    cliente:aplicarFoto(snap2, pj.id)
    local base = #cliente.mensajes
    for k = 1, 25 do
      mundo:mensaje("mundo", "Otro", "nuevo " .. k, nil)
      cliente:aplicarFoto(mundo:foto(pj.id), pj.id)
      cliente:aplicarFoto(mundo:foto(pj.id), pj.id)   -- la misma foto otra vez no duplica
    end
    fallar(errores, "el cliente conserva todo lo recibido", #cliente.mensajes == base + 25, #cliente.mensajes .. " vs " .. (base + 25))
    fallar(errores, "en orden", cliente.mensajes[#cliente.mensajes].texto == "nuevo 25" and cliente.mensajes[base + 1].texto == "nuevo 1")
    -- si el servidor se reinicia (otra época), el chat del cliente empieza de nuevo
    mundo.epoca = "otra"
    mundo._msgId = 0
    mundo:mensaje("mundo", "Otro", "tras reinicio", nil)
    pj.chatDesde = 0
    cliente:aplicarFoto(mundo:foto(pj.id), pj.id)
    fallar(errores, "tras un reinicio se vuelve a empezar", cliente.mensajes[#cliente.mensajes].texto == "tras reinicio" and #cliente.mensajes <= 3)
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
