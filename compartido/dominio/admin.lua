-- Comandos de administración: los escribe en el chat un jugador marcado como admin (p.admin = true).
-- Solo el servidor marca a un admin (cuentas listadas en su .env); el cliente no puede.
--   /admin ayuda                         lista de comandos
--   /admin mob <id> [cantidad] [nivel]   invoca criaturas a tu lado  (/admin mobs: ids)
--   /admin item <id> [cantidad] [jugador] da objetos                 (/admin items [texto]: ids)
--   /admin oro|xp|nivel|monedas <n> [jugador]  da oro, experiencia, monedas del mall o fija el nivel
--   /admin curar|revivir [jugador]       restaura vida y maná / revive
--   /admin tp <x> <y> | tp <jugador> | traer <jugador> | ciudad <id>
--   /admin mapa <nombre|salir>           (nombres: ver MapasFao.MAPAS) entra en un mapa aparte de Free Angels Online (prueba) o vuelve al mundo
--   /admin limpiar [radio]               quita las criaturas cercanas
--   /admin evento <estandarte|batalla> <iniciar|fin|estado> [todos]
--   /admin anuncio <texto>               aviso a todo el mundo
--   /admin dios                          invulnerable (activar/desactivar)
--   /admin jugadores                     quién está conectado
--   /admin kick <jugador> [motivo]       expulsa a un jugador
--   /admin silenciar <jugador> <minutos> silencia el chat (0 lo quita)
--   /admin ban <usuario|jugador> <30m|2h|3d|perm> <motivo>   banea la cuenta  (/admin desban <usuario> | baneos)
--   /admin rol <usuario> <gm|cm|ninguno> asigna el rol de la cuenta            (/admin roles)
-- Roles: GM puede todo; CM (gestor de comunidad) puede moderar y ayudar (ver CM_PUEDE) pero no repartir objetos,
-- oro ni experiencia, ni invocar criaturas, ni cambiar roles; sus baneos duran 72 horas como máximo.
local Datos = require("compartido.dominio.datos")
local Util = require("compartido.dominio.util")

local M = {}

M.MAX_CRIATURAS = 20
M.MAX_OBJETOS = 999

local AYUDA = {
  "Admin: /admin mob <id> [cant] [nivel] | mobs",
  "/admin item <id> [cant] [jugador] | items [texto]",
  "/admin oro|xp|nivel|monedas <n> [jugador] | curar|revivir [jugador]",
  "/admin tp <x> <y> | tp <jugador> | traer <jugador> | ciudad <id> | mapa <nombre|salir>",
  "/admin limpiar [radio] | anuncio <texto> | dios | jugadores",
  "/admin evento <estandarte|batalla> <iniciar|fin|estado> [todos]",
  "/admin kick <jugador> [motivo] | silenciar <jugador> <min> | ban <usuario> <30m|2h|3d|perm> <motivo> | desban <usuario> | baneos",
  "/admin rol <usuario> <gm|cm|ninguno> | roles   (solo GM)",
}

-- Comandos que solo puede usar un GM; el resto también los puede usar un CM.
local SOLO_GM = {
  mob = true, mobs = true, item = true, items = true, oro = true, xp = true, nivel = true, monedas = true,
  dios = true, rol = true, mapa = true,
}
M.SOLO_GM = SOLO_GM
M.MAX_BAN_CM = 72 * 3600

function M.instalar(Mundo)
  local function jugadorPorNombre(self, nombre)
    nombre = nombre:lower()
    for _, e in pairs(self.entidades) do
      if (e.kind == "jugador") and not e.borrar and e.nombre:lower() == nombre then return e end
    end
  end

  -- Objetivo del comando: el jugador nombrado o, si no hay nombre, el propio admin.
  local function objetivo(self, p, nombre)
    if not nombre then return p end
    local e = jugadorPorNombre(self, nombre)
    if not e then self:mensaje("sistema", "", "No hay ningún jugador conectado llamado " .. nombre .. ".", p) end
    return e
  end

  local function decir(self, p, texto) self:mensaje("sistema", "", texto, p) end

  -- Lista larga en varios avisos (el chat tiene poco ancho).
  local function lista(self, p, titulo, ids)
    table.sort(ids)
    local linea = titulo .. ": "
    for _, id in ipairs(ids) do
      if #linea + #id > 90 then decir(self, p, linea) linea = "" end
      linea = linea .. id .. " "
    end
    decir(self, p, linea)
  end

  local function mover(self, e, x, y)
    e.modo, e.z = "mundo", 0
    e.x, e.y = x, y
    e.camino, e.tramo, e.persigue, e.objetivo = nil, nil, false, nil
    self:colocarCerca(e, x, y)
  end

  local comandos = {}

  function comandos.ayuda(self, p)
    for _, l in ipairs(AYUDA) do decir(self, p, l) end
  end

  function comandos.mobs(self, p)
    local ids = {}
    for _, m in ipairs(Datos.monstruos) do ids[#ids + 1] = m.id end
    lista(self, p, "Criaturas", ids)
  end

  function comandos.mob(self, p, a)
    local def = a[1] and Datos.monstruo(a[1])
    if not def then return decir(self, p, "Uso: /admin mob <id> [cantidad] [nivel]. Mira /admin mobs.") end
    local n = math.max(1, math.min(M.MAX_CRIATURAS, math.floor(tonumber(a[2]) or 1)))
    local nivel = tonumber(a[3])
    if nivel then nivel = math.max(1, math.min(Datos.NIVEL_MAX, math.floor(nivel))) end
    for i = 1, n do
      local x, y = p.x + 2 + (i % 5), p.y + math.floor(i / 5) - 1
      local m = self:spawnMonstruo(def.id, x, y, { x = x, y = y }, nivel)
      if m then
        self:colocarCerca(m, x, y)
        -- invocada: no reaparece tras morir
        m.efimero = self.tiempo + 1800
      end
    end
    decir(self, p, n .. " × " .. def.nombre .. (nivel and (" nivel " .. nivel) or "") .. " invocada(s).")
  end

  function comandos.items(self, p, a)
    local filtro = (a[1] or ""):lower()
    local ids = {}
    for id in pairs(Datos.items) do
      if filtro == "" or id:find(filtro, 1, true) then ids[#ids + 1] = id end
    end
    lista(self, p, "Objetos (" .. #ids .. ")", ids)
  end

  function comandos.item(self, p, a)
    local it = a[1] and Datos.item(a[1])
    if not it then return decir(self, p, "Uso: /admin item <id> [cantidad] [jugador]. Mira /admin items.") end
    local cant = math.max(1, math.min(M.MAX_OBJETOS, math.floor(tonumber(a[2]) or 1)))
    local e = objetivo(self, p, a[3])
    if not e then return end
    if not self:darItem(e, a[1], cant) then return decir(self, p, "La bolsa de " .. e.nombre .. " está llena.") end
    self:marcarProgreso(e)
    decir(self, p, cant .. " × " .. (it.nombre or a[1]) .. " para " .. e.nombre .. ".")
    if e ~= p then decir(self, e, "Un administrador te da " .. cant .. " × " .. (it.nombre or a[1]) .. ".") end
  end

  function comandos.oro(self, p, a)
    local n = tonumber(a[1])
    local e = n and objetivo(self, p, a[2])
    if not n then return decir(self, p, "Uso: /admin oro <cantidad> [jugador]") end
    if not e then return end
    e.oro = math.max(0, (e.oro or 0) + math.floor(n))
    self:marcarProgreso(e)
    decir(self, p, e.nombre .. " tiene ahora " .. e.oro .. " de oro.")
  end

  function comandos.monedas(self, p, a)
    local n = tonumber(a[1])
    local e = n and objetivo(self, p, a[2])
    if not n then return decir(self, p, "Uso: /admin monedas <cantidad> [jugador]") end
    if not e then return end
    e.monedas = math.max(0, (e.monedas or 0) + math.floor(n))
    self:marcarProgreso(e)
    decir(self, p, e.nombre .. " tiene ahora " .. e.monedas .. " monedas Corona.")
    if e ~= p then decir(self, e, "Un administrador te da " .. math.floor(n) .. " monedas Corona. Tienes " .. e.monedas .. ".") end
  end

  function comandos.xp(self, p, a)
    local n = tonumber(a[1])
    local e = n and objetivo(self, p, a[2])
    if not n then return decir(self, p, "Uso: /admin xp <cantidad> [jugador]") end
    if not e then return end
    self:ganarXp(e, math.max(0, math.floor(n)))
    self:marcarProgreso(e)
    decir(self, p, e.nombre .. ": nivel " .. e.nivel .. ", experiencia " .. math.floor(e.xp or 0) .. ".")
  end

  function comandos.nivel(self, p, a)
    local n = tonumber(a[1])
    local e = n and objetivo(self, p, a[2])
    if not n then return decir(self, p, "Uso: /admin nivel <1-" .. Datos.NIVEL_MAX .. "> [jugador]") end
    if not e then return end
    e.nivel = math.max(1, math.min(Datos.NIVEL_MAX, math.floor(n)))
    e.xp = 0
    self:recalcular(e)
    e.hp, e.mp = e.hpMax, e.mpMax
    self:marcarProgreso(e)
    decir(self, p, e.nombre .. " es ahora nivel " .. e.nivel .. ".")
  end

  function comandos.curar(self, p, a)
    local e = objetivo(self, p, a[1])
    if not e then return end
    self:limpiarEstados(e)
    e.hp, e.mp = e.hpMax, e.mpMax
    decir(self, p, e.nombre .. " queda curado.")
  end

  function comandos.revivir(self, p, a)
    local e = objetivo(self, p, a[1])
    if not e then return end
    if e.vivo then return decir(self, p, e.nombre .. " está vivo.") end
    self:revivir(e)
    decir(self, p, e.nombre .. " revive.")
  end

  function comandos.tp(self, p, a)
    if p.modo ~= "mundo" then return decir(self, p, "Solo en el mundo abierto.") end
    local x, y = tonumber(a[1]), tonumber(a[2])
    if x and y then
      local mapa = self.mapas.mundo
      if x < 1 or y < 1 or x >= mapa.w - 1 or y >= mapa.h - 1 then return decir(self, p, "Fuera del mapa.") end
      mover(self, p, x + 0.5, y + 0.5)
      return decir(self, p, "Teletransportado a " .. math.floor(x) .. "," .. math.floor(y) .. ".")
    end
    local e = a[1] and jugadorPorNombre(self, a[1])
    if not e then return decir(self, p, "Uso: /admin tp <x> <y> | tp <jugador>") end
    if e.modo ~= "mundo" then return decir(self, p, e.nombre .. " no está en el mundo abierto.") end
    mover(self, p, e.x, e.y)
    decir(self, p, "Junto a " .. e.nombre .. ".")
  end

  function comandos.mapa(self, p, a)
    local nombre = a[1]
    if nombre == "salir" then
      if not self:enMapaFao(p) then return decir(self, p, "No estás en un mapa de FAO.") end
      return self:salirMapaFao(p)
    end
    local err = nombre and self:entrarMapaFao(p, nombre)
    if not nombre or err then return decir(self, p, err or ("Uso: /admin mapa <" .. table.concat(require("compartido.dominio.mapas_fao").nombres(), "|") .. "|salir>")) end
  end

  function comandos.traer(self, p, a)
    local e = a[1] and jugadorPorNombre(self, a[1])
    if not e then return decir(self, p, "Uso: /admin traer <jugador>") end
    if p.modo ~= "mundo" or e.modo ~= "mundo" then return decir(self, p, "Los dos deben estar en el mundo abierto.") end
    mover(self, e, p.x, p.y)
    decir(self, p, e.nombre .. " está contigo.")
  end

  function comandos.ciudad(self, p, a)
    if p.modo ~= "mundo" then return decir(self, p, "Solo en el mundo abierto.") end
    local ids = {}
    for _, c in ipairs(self.mapas.mundo.ciudades) do
      ids[#ids + 1] = c.id
      if c.id == a[1] then
        mover(self, p, c.spawn.x, c.spawn.y)
        return decir(self, p, "Estás en " .. c.id .. ".")
      end
    end
    lista(self, p, "Ciudades", ids)
  end

  function comandos.limpiar(self, p, a)
    local radio = math.max(2, math.min(60, tonumber(a[1]) or 20))
    local n = 0
    for _, e in pairs(self.entidades) do
      if e.kind == "monstruo" and e.vivo and self:mismoLugar(p, e) and Util.dist(e.x, e.y, p.x, p.y) <= radio then
        n = n + 1
        if e.efimero then e.borrar = true
        else
          e.vivo, e.hp, e.objetivo = false, 0, nil
          e.respawn = self.tiempo + (e.elite and Datos.RESPAWN_ELITE or Datos.RESPAWN_MONSTRUO)
        end
      end
    end
    decir(self, p, n .. " criatura(s) retirada(s).")
  end

  function comandos.anuncio(self, p, a, resto)
    if resto == "" then return decir(self, p, "Uso: /admin anuncio <texto>") end
    self:mensaje("mundo", "[Admin]", resto, p)
    self.mensajes[#self.mensajes].marquesina = true
  end

  function comandos.dios(self, p)
    p.invulnerable = not p.invulnerable or nil
    decir(self, p, p.invulnerable and "Invulnerable: sí." or "Invulnerable: no.")
  end

  function comandos.jugadores(self, p)
    local n = 0
    for _, e in pairs(self.entidades) do
      if e.kind == "jugador" and not e.borrar then
        n = n + 1
        decir(self, p, string.format("%s (%s, %s, nv %d) en %s %d,%d", e.nombre, e.faccion, e.clase, e.nivel, e.modo, e.x, e.y))
      end
    end
    if n == 0 then decir(self, p, "Nadie conectado.") end
  end

  function comandos.evento(self, p, a)
    local modo, accion = a[1], a[2] or "estado"
    if modo ~= "estandarte" and modo ~= "batalla" then
      return decir(self, p, "Uso: /admin evento <estandarte|batalla> <iniciar|fin|estado> [todos]")
    end
    local inst = self.instancia[modo]
    local activo = inst.activa and not inst.fin
    if accion == "estado" then
      local r = self:resumenEvento(modo)
      return decir(self, p, string.format("%s: %s. En cola Albor %d, Umbra %d; dentro Albor %d, Umbra %d.",
        self:nombreEvento(modo), activo and "en marcha" or "parado", r.cola.albor, r.cola.umbra, r.dentro.albor, r.dentro.umbra))
    end
    if accion == "fin" then
      if not activo then return decir(self, p, "No está en marcha.") end
      local pa, pu = inst.puntos.albor, inst.puntos.umbra
      self:cerrarInstancia(modo, pa > pu and "albor" or pu > pa and "umbra" or nil)
      return decir(self, p, "Evento terminado.")
    end
    if accion ~= "iniciar" then return decir(self, p, "Acciones: iniciar, fin, estado.") end
    if activo then return decir(self, p, "Ya está en marcha.") end
    -- sin mínimo de jugadores y sin gastar la edición programada
    self:reiniciarInstancia(modo)
    if self.eventos then
      self.eventos[modo] = self.eventos[modo] or {}
      self.eventos[modo].activa = "admin@" .. modo .. "@" .. os.time()
    end
    local n = 0
    for _, e in pairs(self.entidades) do
      if e.kind == "jugador" and e.vivo and not e.borrar and e.modo ~= modo
        and (e.colaGuerra == modo or (a[3] == "todos" and e.modo == "mundo")) then
        self:meterEnCampo(e, modo)
        n = n + 1
      end
    end
    self:avisoEvento("mundo", "", self:nombreEvento(modo) .. " empieza (lanzada por un administrador).", nil)
    decir(self, p, "Evento iniciado con " .. n .. " jugador(es)." .. (n == 0 and " Nadie en cola: usa «todos» para meter a todos." or ""))
  end

  -- ---------------------------------------------------------------------------- moderación y roles
  local Sanciones = require("compartido.dominio.sanciones")

  -- Rol efectivo de un jugador conectado: el de su cuenta o, para las cuentas del .env, GM.
  local function rolDe(p)
    return p.staff or (p.admin and "gm") or nil
  end

  local function hooks(self, p)
    if not self.hooks then
      decir(self, p, "Esto solo está disponible en el servidor.")
      return nil
    end
    return self.hooks
  end

  -- Usuario de cuenta al que apunta un nombre: el del jugador conectado con ese nombre o el propio texto.
  local function usuarioDe(self, nombre)
    local e = jugadorPorNombre(self, nombre)
    if e and e.cuentaUsuario then return e.cuentaUsuario, e end
    return nombre, e
  end

  -- Rol de una cuenta por su usuario (consulta el almacén; las cuentas del .env cuentan como GM).
  local function rolDeUsuario(self, usuario)
    if self.admins and self.admins[tostring(usuario):lower()] then return "gm" end
    local h = self.hooks
    for _, r in ipairs((h and h.listarRoles and h.listarRoles()) or {}) do
      if r.usuario:lower() == tostring(usuario):lower() then return r.rol end
    end
  end

  -- ¿Puede quien manda sancionar a esa cuenta? Un CM no toca al personal; un GM no toca a otros GM.
  local function puedeSancionar(self, p, usuario)
    local mio, suyo = rolDe(p), rolDeUsuario(self, usuario)
    if not suyo then return true end
    if mio == "gm" and suyo ~= "gm" then return true end
    return false
  end

  function comandos.kick(self, p, a, resto)
    local h = hooks(self, p)
    if not h then return end
    local e = a[1] and jugadorPorNombre(self, a[1])
    if not e then return decir(self, p, "Uso: /admin kick <jugador> [motivo]  (el jugador debe estar conectado).") end
    if e == p then return decir(self, p, "No puedes expulsarte a ti mismo.") end
    if e.cuentaUsuario and not puedeSancionar(self, p, e.cuentaUsuario) then
      return decir(self, p, "No puedes sancionar a alguien del personal.")
    end
    local motivo = resto:match("^%S+%s+(.+)$") or "sin motivo indicado"
    if h.expulsar then h.expulsar(e, "Te han expulsado del servidor. Motivo: " .. motivo) end
    decir(self, p, e.nombre .. " expulsado.")
  end

  function comandos.silenciar(self, p, a)
    local e = a[1] and jugadorPorNombre(self, a[1])
    local min = tonumber(a[2])
    if not e or not min or min < 0 then return decir(self, p, "Uso: /admin silenciar <jugador> <minutos>  (0 quita el silencio).") end
    if e.cuentaUsuario and not puedeSancionar(self, p, e.cuentaUsuario) then
      return decir(self, p, "No puedes sancionar a alguien del personal.")
    end
    if min == 0 then
      e.silenciadoHasta = nil
      decir(self, e, "Ya puedes hablar de nuevo.")
      return decir(self, p, e.nombre .. " ya no está silenciado.")
    end
    e.silenciadoHasta = os.time() + math.floor(min * 60)
    decir(self, e, "Un moderador te ha silenciado durante " .. math.floor(min) .. " minuto(s).")
    decir(self, p, e.nombre .. " silenciado " .. math.floor(min) .. " minuto(s).")
  end

  function comandos.ban(self, p, a, resto)
    local h = hooks(self, p)
    if not h then return end
    local dur = Sanciones.duracion(a[2])
    if not a[1] or not dur then
      return decir(self, p, "Uso: /admin ban <usuario|jugador> <30m|2h|3d|perm> <motivo>")
    end
    local usuario, enLinea = usuarioDe(self, a[1])
    if rolDe(p) ~= "gm" and (dur == 0 or dur > M.MAX_BAN_CM) then
      return decir(self, p, "Un CM puede banear como mucho 72 horas.")
    end
    if not puedeSancionar(self, p, usuario) then return decir(self, p, "No puedes sancionar a alguien del personal.") end
    local motivo = resto:match("^%S+%s+%S+%s+(.+)$") or "sin motivo indicado"
    local hasta = dur == 0 and 0 or (os.time() + dur)
    local ok, err = h.banear(usuario, hasta, motivo, p.nombre)
    if not ok then return decir(self, p, tostring(err or "No se pudo banear.")) end
    -- los personajes de esa cuenta que estén conectados salen al momento
    local fuera = 0
    for _, e in pairs(self.entidades) do
      if e.kind == "jugador" and not e.borrar and e.cuentaUsuario and e.cuentaUsuario:lower() == ok:lower() then
        if h.expulsar then h.expulsar(e, Sanciones.mensaje({ hasta = hasta, motivo = motivo })) end
        fuera = fuera + 1
      end
    end
    decir(self, p, "Cuenta " .. ok .. " baneada (" .. Sanciones.textoDuracion(dur) .. "). Motivo: " .. motivo ..
      (fuera > 0 and (" Expulsado(s): " .. fuera .. ".") or ""))
  end

  function comandos.desban(self, p, a)
    local h = hooks(self, p)
    if not h then return end
    if not a[1] then return decir(self, p, "Uso: /admin desban <usuario>") end
    local ok, err = h.desbanear(a[1])
    if not ok then return decir(self, p, tostring(err or "No se pudo quitar el baneo.")) end
    decir(self, p, "Baneo de " .. ok .. " retirado.")
  end

  function comandos.baneos(self, p)
    local h = hooks(self, p)
    if not h then return end
    local lista = h.listarBaneos() or {}
    if #lista == 0 then return decir(self, p, "No hay cuentas baneadas.") end
    for _, b in ipairs(lista) do
      decir(self, p, b.usuario .. ": " .. ((tonumber(b.hasta) or 0) == 0 and "permanente" or ("hasta " .. os.date("%Y-%m-%d %H:%M", b.hasta))) ..
        " — " .. tostring(b.motivo or "") .. " (por " .. tostring(b.por or "?") .. ")")
    end
  end

  function comandos.rol(self, p, a)
    local h = hooks(self, p)
    if not h then return end
    local rol = a[2] and a[2]:lower()
    if rol == "ninguno" or rol == "nada" or rol == "jugador" then rol = nil
    elseif rol ~= "gm" and rol ~= "cm" then rol = false end
    if not a[1] or rol == false then return decir(self, p, "Uso: /admin rol <usuario> <gm|cm|ninguno>") end
    if self.admins and self.admins[a[1]:lower()] then
      return decir(self, p, "Esa cuenta es GM por la configuración del servidor (.env): no se cambia aquí.")
    end
    local ok, err = h.fijarRol(a[1], rol)
    if not ok then return decir(self, p, tostring(err or "No se pudo cambiar el rol.")) end
    -- si está conectada, el cambio vale al instante
    for _, e in pairs(self.entidades) do
      if e.kind == "jugador" and not e.borrar and e.cuentaUsuario and e.cuentaUsuario:lower() == ok:lower() then
        e.staff = rol
        e.admin = rol and true or nil
        decir(self, e, rol and ("Ahora eres " .. rol:upper() .. ".") or "Ya no tienes permisos de personal.")
      end
    end
    decir(self, p, ok .. ": " .. (rol and rol:upper() or "sin rol") .. ".")
  end

  function comandos.roles(self, p)
    local h = hooks(self, p)
    if not h then return end
    local lista = h.listarRoles() or {}
    for usuario in pairs(self.admins or {}) do lista[#lista + 1] = { usuario = usuario, rol = "gm (.env)" } end
    if #lista == 0 then return decir(self, p, "Nadie tiene rol de personal.") end
    for _, r in ipairs(lista) do decir(self, p, r.usuario .. ": " .. r.rol:upper()) end
  end

  -- Punto de entrada: texto completo escrito en el chat (empieza por /admin).
  function Mundo:comandoAdmin(p, texto)
    local rol = rolDe(p)
    if not rol then
      decir(self, p, "No tienes permiso para usar comandos de administrador.")
      return
    end
    local resto = texto:gsub("^/admin%s*", "")
    local nombre, params = resto:match("^(%S+)%s*(.*)$")
    nombre = (nombre or "ayuda"):lower()
    local f = comandos[nombre]
    if not f then return decir(self, p, "Comando desconocido: " .. nombre .. ". Prueba /admin ayuda.") end
    if rol ~= "gm" and SOLO_GM[nombre] then
      return decir(self, p, "El comando " .. nombre .. " es solo para GM.")
    end
    local a = {}
    for t in (params or ""):gmatch("%S+") do a[#a + 1] = t end
    local ok, err = pcall(f, self, p, a, params or "")
    if not ok then decir(self, p, "Error en el comando: " .. tostring(err)) end
  end
end

return M
