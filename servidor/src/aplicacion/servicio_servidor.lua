-- Servicio del servidor de juego: casos de uso que no dependen de la pantalla.
--   * atiende los mensajes de los clientes (cuentas, entrada al mundo, acciones)
--   * valida lo que llega con las reglas del dominio (Autoridad)
--   * hace avanzar el mundo, manda el estado a cada jugador y guarda el progreso
-- El transporte (sockets) y el almacén se le dan hechos; no sabe cómo funcionan.
local Mundo = require("compartido.dominio.mundo")
local Autoridad = require("src.dominio.autoridad")
local Cuentas = require("src.aplicacion.cuentas")
local Ajustes = require("src.aplicacion.ajustes")
local Log = require("compartido.infraestructura.log")

local Servicio = {}

local TASA_POR_DEFECTO = 40

-- Mundo nuevo con el puerto de progreso diario enchufado al almacén.
function Servicio.crearMundo(opciones)
  -- reglas del .env (antes de crear el mundo: la vida de las criaturas, por ejemplo, se fija al crearlas)
  local restaurar, cambios
  if opciones and opciones.ajustes then restaurar, cambios = Ajustes.aplicar(opciones.ajustes) end
  local mundo = Mundo.nuevo()
  mundo.restaurarAjustes, mundo.ajustesCambiados = restaurar, cambios
  -- los eventos de guerra los lanza el servidor a sus horas
  if opciones and opciones.eventos and opciones.eventos.activos then mundo:programarEventos(opciones.eventos) end
  -- cuentas de administrador (comandos /admin del chat)
  mundo.admins = (opciones and opciones.admin and opciones.admin.usuarios) or {}
  if opciones and opciones.admin and opciones.admin.primero and (opciones.admin.clave or "") ~= "" then
    local id, err = Cuentas.registrar(opciones.admin.primero, opciones.admin.clave)
    if id then Log.info("cuenta de administrador creada: " .. opciones.admin.primero)
    elseif not tostring(err):find("registrado") then Log.warn("cuenta de administrador: " .. tostring(err)) end
  end
  -- roles del personal y baneos: el dominio los pide por estos enchufes (el almacén y la red los resuelven)
  mundo.hooks = {
    fijarRol = function(...) return Cuentas.fijarRol(...) end,
    listarRoles = function() return Cuentas.listarRoles() end,
    banear = function(...) return Cuentas.banear(...) end,
    desbanear = function(...) return Cuentas.desbanear(...) end,
    listarBaneos = function() return Cuentas.listarBaneos() end,
    -- expulsa al jugador (entidad): le avisa y cierra su conexión; se guarda su progreso antes
    expulsar = function(e, motivo)
      local srv = mundo._servidor
      if not srv then return end
      for idCon, pid in pairs(srv.vinculo or {}) do
        if pid == e.id then
          Servicio.guardarUno(mundo, e)
          srv:desconectar(idCon, { t = "no", error = motivo })
        end
      end
    end,
  }
  mundo.puertos.marcarEvento = function(...) return Cuentas.marcarEvento(...) end
  -- los gremios se cargan al arrancar y cada cambio se guarda al momento
  mundo.puertos.guardarGremio = function(g)
    local ok, err = Cuentas.guardarGremio(g)
    if not ok then Log.warn("guardado del gremio " .. tostring(g.nombre) .. ": " .. tostring(err)) end
  end
  mundo.puertos.borrarGremio = function(id)
    local ok, err = Cuentas.borrarGremio(id)
    if not ok then Log.warn("borrado del gremio " .. tostring(id) .. ": " .. tostring(err)) end
  end
  mundo:cargarGremios(Cuentas.cargarGremios() or {})
  -- subastas y buzones: se cargan al arrancar y cada cambio se guarda al momento
  local subastas, buzones = Cuentas.cargarSubastas()
  mundo:cargarSubastas(subastas or {}, buzones or {})
  mundo.puertos.guardarSubasta = function(s)
    local ok, err = Cuentas.guardarSubasta(s)
    if not ok then Log.warn("guardado de la subasta " .. tostring(s.id) .. ": " .. tostring(err)) end
  end
  mundo.puertos.borrarSubasta = function(id)
    local ok, err = Cuentas.borrarSubasta(id)
    if not ok then Log.warn("borrado de la subasta " .. tostring(id) .. ": " .. tostring(err)) end
  end
  mundo.puertos.guardarBuzon = function(dbId, lista)
    local ok, err = Cuentas.guardarBuzon(dbId, lista)
    if not ok then Log.warn("guardado del buzón " .. tostring(dbId) .. ": " .. tostring(err)) end
  end
  mundo.puertos.guardarJugador = function(p)
    if p.remoto then Servicio.guardarUno(mundo, p) end
  end
  return mundo
end

-- Limita los mensajes por segundo de cada conexión.
function Servicio.permite(srv, id, tiempo, limite)
  srv.tasa = srv.tasa or {}
  local t = srv.tasa[id]
  if not t or tiempo - t.ventana >= 1 then
    t = { ventana = tiempo, n = 0 }
    srv.tasa[id] = t
  end
  t.n = t.n + 1
  return t.n <= (limite or TASA_POR_DEFECTO)
end

function Servicio.guardarUno(mundo, pj)
  if not pj or not pj.dbId or pj.kind ~= "jugador" then return true end
  local ok, err = Cuentas.guardar(pj, mundo:exportar(pj))
  if not ok then
    pj.pendienteGuardar = true
    Log.warn("guardado " .. tostring(pj.nombre) .. ": " .. tostring(err))
    return false
  end
  pj.pendienteGuardar = nil
  return true
end

function Servicio.guardarTodos(mundo)
  if not mundo then return end
  for _, e in pairs(mundo.entidades) do
    if e.kind == "jugador" and e.dbId and e.remoto then
      Servicio.guardarUno(mundo, e)
    end
  end
end

local function textoCorto(v, max)
  if type(v) ~= "string" or #v == 0 or #v > max then return nil end
  return v
end

local function responderSesion(servidor, idCon, token, usuario, cuentaId, creado)
  local lista = Cuentas.listar(cuentaId) or {}
  servidor:enviar(idCon, {
    t = "sesion", token = token, usuario = usuario or "",
    cuenta = cuentaId, personajes = lista, creado = creado,
  })
end

-- Atiende un mensaje de un cliente. servidor: transporte con enviar() y vinculo.
function Servicio.tratar(servidor, mundo, idCon, msg)
  if type(msg) ~= "table" then return end
  if msg.t == "cuenta" then
    if servidor.vinculo[idCon] then
      servidor:enviar(idCon, { t = "no", error = "Ya estás dentro del mundo." })
      return
    end
    local accion = msg.a
    if accion == "entrar" or accion == "registrar" then
      local usuario = textoCorto(msg.usuario, 16)
      local clave = textoCorto(msg.clave, 64)
      local idCuenta, extra
      if accion == "registrar" then
        idCuenta, extra = Cuentas.registrar(usuario or "", clave or "")
      else
        idCuenta, extra = Cuentas.entrar(usuario or "", clave or "")
      end
      if not idCuenta then
        servidor:enviar(idCon, { t = "no", error = extra or "No se pudo entrar." })
        return
      end
      responderSesion(servidor, idCon, extra, usuario, idCuenta)
      return
    end
    if accion == "crear" then
      local cuentaId, usuario = Cuentas.cuentaDeToken(msg.token)
      if not cuentaId then
        servidor:enviar(idCon, { t = "no", error = usuario or "Sesión no válida." })
        return
      end
      local pid, err = Cuentas.crearPersonaje(cuentaId, msg.nombre, msg.faccion, msg.clase)
      if not pid then
        servidor:enviar(idCon, { t = "no", error = err or "No se pudo crear el personaje." })
        return
      end
      responderSesion(servidor, idCon, msg.token, usuario, cuentaId, pid)
      return
    end
    servidor:enviar(idCon, { t = "no", error = "Petición de cuenta desconocida." })
    return
  end
  if msg.t == "hola" then
    if servidor.vinculo[idCon] then return end
    local datos, err = Cuentas.cargarAutorizado(msg.token, msg.personaje)
    if not datos then
      servidor:enviar(idCon, { t = "no", error = err or "Sesión no válida." })
      return
    end
    for _, e in pairs(mundo.entidades) do
      if e.kind == "jugador" and e.dbId == datos.dbId and not e.borrar then
        servidor:enviar(idCon, { t = "no", error = "Ese personaje ya está en el mundo." })
        return
      end
    end
    local pj = mundo:crearPersonaje({
      nombre = datos.nombre,
      faccion = datos.faccion,
      clase = datos.clase,
    })
    -- la cuenta decide si es del personal: GM o CM por su rol guardado, o GM si está en el .env (solo el servidor lo marca)
    local _, usuario, rolCuenta = Cuentas.cuentaDeToken(msg.token)
    if usuario and mundo.admins and mundo.admins[tostring(usuario):lower()] then rolCuenta = "gm" end
    pj.staff = rolCuenta
    pj.admin = rolCuenta and true or nil
    pj.cuentaUsuario = usuario
    pj.remoto = true
    pj.dbId = datos.dbId
    pj.eventosDia = datos.eventosDia
    -- Siempre se aplica lo guardado: un personaje nuevo solo trae los valores iniciales.
    mundo:aplicarGuardado(pj, datos)
    mundo:avisoDiaria(pj)
    servidor.vinculo[idCon] = pj.id
    servidor:enviar(idCon, { t = "ok", id = pj.id, nombre = pj.nombre })
    return
  end
  if msg.t == "act" then
    local pid = servidor.vinculo[idCon]
    local pj = pid and mundo.entidades[pid]
    if not pj then return end
    local ok, limpio = Autoridad.aceptar(mundo, pj, msg.a, msg.p)
    if not ok then return end
    local r = mundo:accion(pid, msg.a, limpio)
    if r and (msg.a == "interactuar" or r.panel ~= nil) then
      servidor:enviar(idCon, { t = "panel", panel = r.panel, ciudad = r.ciudad, datos = r.datos, tienda = r.tienda })
    end
  end
end

-- Un fotograma del servidor.
-- ctx = { mundo, servidor (transporte), nota (función de aviso), config }
function Servicio.actualizar(ctx, dt)
  local mundo, servidor = ctx.mundo, ctx.servidor
  local cfg = ctx.config or {}
  if mundo then mundo._servidor = servidor end
  local nota = ctx.nota or function() end
  if mundo then
    mundo:actualizar(dt)
  end
  if not servidor or not mundo then return end
  for _, ev in ipairs(servidor:actualizar()) do
    if ev.tipo == "conecta" then
      nota("Conexión " .. ev.id)
    elseif ev.tipo == "cierra" then
      local pid = servidor.vinculo[ev.id]
      local pj = pid and mundo.entidades[pid]
      if pj then
        Servicio.guardarUno(mundo, pj)
        pj.borrar = true
      end
      servidor.vinculo[ev.id] = nil
      servidor.tasa[ev.id] = nil
      local aviso = "Se fue " .. ev.id .. (ev.codigo and (" (" .. ev.codigo .. ")") or "")
      nota(aviso)
      Log.warn(aviso)
    elseif ev.tipo == "msg" then
      if Servicio.permite(servidor, ev.id, mundo.tiempo, cfg.tasa_mensajes) then
        Servicio.tratar(servidor, mundo, ev.id, ev.msg)
        if ev.msg and ev.msg.t == "cuenta" then
          local u = ev.msg.usuario
          if type(u) ~= "string" or #u > 16 then u = "" end
          nota("Cuenta " .. tostring(ev.msg.a or "") .. " " .. u)
        elseif ev.msg and ev.msg.t == "hola" then
          local pj = servidor.vinculo[ev.id] and mundo.entidades[servidor.vinculo[ev.id]]
          if pj then
            nota(pj.nombre .. " entra como " .. pj.clase)
          else
            nota("Entrada rechazada en " .. ev.id)
          end
        end
      end
    end
  end
  servidor._acum = (servidor._acum or 0) + dt
  servidor._guardar = (servidor._guardar or 0) + dt
  if servidor._acum > 1 / (cfg.fotos_por_segundo or 15) then
    servidor._acum = 0
    for _, c in ipairs(servidor.clientes) do
      local pid = servidor.vinculo[c.id]
      if pid and servidor:puedeEnviar(c.id) then
        servidor:enviar(c.id, { t = "snap", snap = mundo:foto(pid) })
      end
    end
    -- los sonidos de este intervalo ya viajaron en las fotos
    mundo.sonidos = {}
  end
  if servidor._guardar > (cfg.guardado_segundos or 20) then
    servidor._guardar = 0
    Servicio.guardarTodos(mundo)
  end
  servidor._reintento = (servidor._reintento or 0) + dt
  if servidor._reintento > (cfg.reintento_segundos or 5) then
    servidor._reintento = 0
    for _, e in pairs(mundo.entidades) do
      if e.pendienteGuardar and e.kind == "jugador" and e.dbId then
        Servicio.guardarUno(mundo, e)
      end
    end
  end
end

return Servicio
