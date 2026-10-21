-- Programación de los eventos de guerra: los lanza el servidor, no los jugadores.
--   * Captura del estandarte: cada N horas (por defecto 4) a horas en punto (0, 4, 8...).
--   * Batalla por cristales: una vez al día, a la hora que diga la configuración (21:00).
-- Unos minutos antes se abre la inscripción con un aviso; a la hora se juega si hay jugadores
-- suficientes en cada corona y, si no, se cancela y se espera a la siguiente edición.
-- Todos los jugadores pueden participar en cada edición. Sin programación (mundos locales y
-- pruebas) todo funciona como antes: la cola empieza sola al juntarse jugadores.
local Datos = require("compartido.dominio.datos")

local M = {}
require("compartido.dominio.configuracion").aplicar(M, "programacion")



function M.instalar(Mundo)
  function Mundo:reloj()
    return (self.relojEventos or os.time)()
  end

  -- Activa la programación (la llama el servidor al arrancar).
  function Mundo:programarEventos(cfg)
    local c = {}
    for k, v in pairs(M.POR_DEFECTO) do c[k] = v end
    for k, v in pairs(cfg or {}) do c[k] = v end
    c.estandarteCadaHoras = math.max(1, math.min(24, math.floor(c.estandarteCadaHoras)))
    self.horarioEventos = c
    self.eventos = {}
  end

  -- Primera edición de un evento que empieza estrictamente después de "desde" (hora Unix).
  function Mundo:proximaEdicion(modo, desde)
    local c = self.horarioEventos
    local d = os.date("*t", desde)
    if modo == "estandarte" then
      local h = d.hour - d.hour % c.estandarteCadaHoras
      for _ = 1, 40 do
        local t = os.time({ year = d.year, month = d.month, day = d.day, hour = h, min = 0, sec = 0 })
        if t > desde then return t end
        h = h + c.estandarteCadaHoras
      end
    end
    local t = os.time({ year = d.year, month = d.month, day = d.day, hour = c.batallaHora, min = c.batallaMinuto, sec = 0 })
    if t <= desde then
      t = os.time({ year = d.year, month = d.month, day = d.day + 1, hour = c.batallaHora, min = c.batallaMinuto, sec = 0 })
    end
    return t
  end

  -- Identificador de una edición: sirve para no repetir en la misma.
  local function claveDe(modo, t)
    if modo == "estandarte" then return "estandarte@" .. os.date("%Y%m%d%H", t) end
    return "batalla@" .. os.date("%Y%m%d", t)
  end

  local function estado(self, modo)
    local ev = self.eventos[modo]
    if not ev then
      local t = self:proximaEdicion(modo, self:reloj())
      ev = { proxima = t, clave = claveDe(modo, t), avisado = false }
      self.eventos[modo] = ev
    end
    return ev
  end

  -- La edición en curso (si el evento está en marcha) o la siguiente.
  function Mundo:claveEdicion(modo)
    if not self.horarioEventos or modo == "moba" then return modo end
    local ev = estado(self, modo)
    local inst = self.instancia[modo]
    if ev.activa and inst and inst.activa and not inst.fin then return ev.activa end
    return ev.clave
  end

  -- Datos de la próxima edición para el panel.
  function Mundo:programaDe(modo)
    if not self.horarioEventos or modo == "moba" then return nil end         -- (el asedio no tiene horario: empieza cuando hay jugadores)
    local ev = estado(self, modo)
    return { proxima = ev.proxima, hora = os.date("%H:%M", ev.proxima), restan = math.max(0, ev.proxima - self:reloj()) }
  end

  local function avanzar(self, modo, ev)
    local t = self:proximaEdicion(modo, self:reloj())
    ev.proxima, ev.clave, ev.avisado = t, claveDe(modo, t), false
  end

  local function soltarCola(self, modo, motivo)
    for _, e in pairs(self.entidades) do
      if e.kind == "jugador" and e.colaGuerra == modo then
        e.colaGuerra = nil
        self:mensaje("sistema", "", motivo, e)
      end
    end
  end

  -- Se llama en cada tick; actúa una vez por segundo.
  function Mundo:actualizarProgramacion(dt)
    if not self.horarioEventos then return end
    self._progT = (self._progT or 0) + dt
    if self._progT < 1 then return end
    self._progT = 0
    local ahora = self:reloj()
    local c = self.horarioEventos
    local min = Datos.JUGADORES_EVENTO
    for _, modo in ipairs(M.MODOS) do
      local ev = estado(self, modo)
      local inst = self.instancia[modo]
      if ev.activa and not (inst.activa and not inst.fin) then ev.activa = nil end
      if not ev.avisado and ahora >= ev.proxima - c.avisoMinutos * 60 and ahora < ev.proxima then
        ev.avisado = true
        self:avisoEvento("mundo", "", self:nombreEvento(modo) .. " empieza a las " .. os.date("%H:%M", ev.proxima) ..
          ". Apúntate con el Heraldo de cualquier ciudad (hacen falta " .. min .. " jugadores por corona).", nil)
      end
      if ahora >= ev.proxima then
        if inst.activa and not inst.fin then
          -- el anterior sigue en marcha: se pierde esta edición
          soltarCola(self, modo, self:nombreEvento(modo) .. " no pudo empezar: el anterior sigue en marcha.")
        else
          local n = self:contarCola(modo)
          if n.albor >= min and n.umbra >= min then
            ev.activa = ev.clave
            self:empezarEvento(modo)
          else
            soltarCola(self, modo, "No hubo jugadores suficientes para " .. self:nombreEvento(modo) .. ". Queda para la próxima edición.")
            self:avisoEvento("mundo", "", self:nombreEvento(modo) .. " cancelada: faltaron jugadores. Próxima edición: " ..
              os.date("%H:%M", self:proximaEdicion(modo, ahora)) .. ".", nil)
          end
        end
        avanzar(self, modo, ev)
      end
    end
  end
end

return M
