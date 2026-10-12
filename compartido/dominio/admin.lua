-- Comandos de administración: los escribe en el chat un jugador marcado como admin (p.admin = true).
-- Solo el servidor marca a un admin (cuentas listadas en su .env); el cliente no puede.
--   /admin ayuda                         lista de comandos
--   /admin mob <id> [cantidad] [nivel]   invoca criaturas a tu lado  (/admin mobs: ids)
--   /admin item <id> [cantidad] [jugador] da objetos                 (/admin items [texto]: ids)
--   /admin oro|xp|nivel|monedas <n> [jugador]  da oro, experiencia, monedas del mall o fija el nivel
--   /admin curar|revivir [jugador]       restaura vida y maná / revive
--   /admin tp <x> <y> | tp <jugador> | traer <jugador> | ciudad <id>
--   /admin limpiar [radio]               quita las criaturas cercanas
--   /admin evento <estandarte|batalla> <iniciar|fin|estado> [todos]
--   /admin anuncio <texto>               aviso a todo el mundo
--   /admin dios                          invulnerable (activar/desactivar)
--   /admin jugadores                     quién está conectado
local Datos = require("compartido.dominio.datos")
local Util = require("compartido.dominio.util")

local M = {}

M.MAX_CRIATURAS = 20
M.MAX_OBJETOS = 999

local AYUDA = {
  "Admin: /admin mob <id> [cant] [nivel] | mobs",
  "/admin item <id> [cant] [jugador] | items [texto]",
  "/admin oro|xp|nivel|monedas <n> [jugador] | curar|revivir [jugador]",
  "/admin tp <x> <y> | tp <jugador> | traer <jugador> | ciudad <id>",
  "/admin limpiar [radio] | anuncio <texto> | dios | jugadores",
  "/admin evento <estandarte|batalla> <iniciar|fin|estado> [todos]",
}

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
    self:mensaje("mundo", "", self:nombreEvento(modo) .. " empieza (lanzada por un administrador).", nil)
    decir(self, p, "Evento iniciado con " .. n .. " jugador(es)." .. (n == 0 and " Nadie en cola: usa «todos» para meter a todos." or ""))
  end

  -- Punto de entrada: texto completo escrito en el chat (empieza por /admin).
  function Mundo:comandoAdmin(p, texto)
    if not p.admin then
      decir(self, p, "No tienes permiso para usar comandos de administrador.")
      return
    end
    local resto = texto:gsub("^/admin%s*", "")
    local nombre, params = resto:match("^(%S+)%s*(.*)$")
    nombre = (nombre or "ayuda"):lower()
    local f = comandos[nombre]
    if not f then return decir(self, p, "Comando desconocido: " .. nombre .. ". Prueba /admin ayuda.") end
    local a = {}
    for t in (params or ""):gmatch("%S+") do a[#a + 1] = t end
    local ok, err = pcall(f, self, p, a, params or "")
    if not ok then decir(self, p, "Error en el comando: " .. tostring(err)) end
  end
end

return M
