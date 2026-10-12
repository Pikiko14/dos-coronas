-- Encuentros de grupo: cuando un grupo de jugadores caza junto en campo abierto, de vez en cuando
-- sale a su paso una criatura de grupo (jefes "party") o, si el grupo es grande, un gigante.
-- Son fuertes (pensados para varios jugadores), dan mucha experiencia, que se reparte, y mejor botín.
-- Desaparecen solas si nadie las derrota en unos minutos.
local Util = require("compartido.dominio.util")
local Datos = require("compartido.dominio.datos")

local M = {}

M.ACTIVO = true
M.INTERVALO = 150          -- segundos medios entre encuentros de un mismo grupo
M.DURACION = 300           -- cuánto duran si nadie las derrota
M.MAX_A_LA_VEZ = 10        -- encuentros simultáneos en todo el servidor
-- probabilidad de gigante según el tamaño del grupo (si no, sale una criatura party)
M.PROB_GIGANTE = { [2] = 0, [3] = 0.15, [4] = 0.35, [5] = 0.5 }

local PARTY = { "jefe_manada", "sectario_mayor", "reina_avispa" }
local GIGANTES = { "oso_gigante", "coloso", "gigante_guerra" }

function M.instalar(Mundo)
  -- Criatura normal con el nivel más cercano (para la escolta del jefe).
  local function escoltaDe(nivel)
    local mejor
    for _, m in ipairs(Datos.monstruos) do
      if not m.elite and not m.noCampamento and (not mejor or math.abs(m.nivel - nivel) < math.abs(mejor.nivel - nivel)) then
        mejor = m
      end
    end
    return mejor
  end

  local function sitioLibre(self, cx, cy)
    for _ = 1, 14 do
      local ang = math.random() * math.pi * 2
      local d = 9 + math.random() * 5
      local x, y = cx + math.cos(ang) * d, cy + math.sin(ang) * d
      local tx, ty = math.floor(x), math.floor(y)
      if require("compartido.dominio.mapa").transitable(self.mapas.mundo, tx, ty) and not self:ciudadEn(x, y) then
        return x, y
      end
    end
  end

  local function vivo(self, id)
    local e = self.entidades[id]
    return e and e.vivo and not e.borrar
  end

  -- Hace aparecer el encuentro de un grupo. Devuelve la lista de criaturas o nil.
  function Mundo:crearEncuentro(g, afuera)
    local n = #afuera
    local cx, cy, suma = 0, 0, 0
    for _, e in ipairs(afuera) do
      cx, cy, suma = cx + e.x, cy + e.y, suma + (e.nivel or 1)
    end
    cx, cy = cx / n, cy / n
    local nivel = math.max(3, math.min(Datos.NIVEL_MAX, math.floor(suma / n)))
    local x, y = sitioLibre(self, cx, cy)
    if not x then return nil end
    local gigante = math.random() < (M.PROB_GIGANTE[math.min(5, n)] or 0)
    local lista = {}
    local function nacer(id, niv, ex, ey)
      local m = self:spawnMonstruo(id, ex, ey, { x = ex, y = ey }, niv)
      if not m then return end
      self:colocarCerca(m, ex, ey)
      m.efimero = self.tiempo + M.DURACION
      m.agresivo = true
      local objetivo = afuera[math.random(#afuera)]
      m.objetivo, m.amenaza = objetivo.id, objetivo.id
      lista[#lista + 1] = m.id
      return m
    end
    local principal
    if gigante then
      principal = nacer(GIGANTES[math.random(#GIGANTES)], math.min(Datos.NIVEL_MAX, nivel + 2), x, y)
    else
      principal = nacer(PARTY[math.random(#PARTY)], math.min(Datos.NIVEL_MAX, nivel + 1), x, y)
      local esc = escoltaDe(nivel)
      for i = 1, 2 do
        if esc then nacer(esc.id, nivel, x + (i == 1 and 1.5 or -1.5), y + 1) end
      end
    end
    if not principal then return nil end
    for _, e in ipairs(self:miembrosGrupo(g)) do
      self:mensaje("sistema", "", gigante and ("¡Algo enorme se acerca: " .. principal.nombre .. "!")
        or ("¡Aparece " .. principal.nombre .. " con su escolta!"), e)
    end
    return lista
  end

  function Mundo:actualizarEncuentros(dt)
    if not M.ACTIVO then return end
    self._encT = (self._encT or 0) + dt
    if self._encT < 5 then return end
    self._encT = 0
    self:iniciarGrupos()
    local activos = 0
    for _, g in pairs(self.grupos) do
      if g.encuentro then
        local queda = false
        for _, id in ipairs(g.encuentro) do if vivo(self, id) then queda = true end end
        if queda then activos = activos + 1
        else
          g.encuentro = nil
          g.proximoEncuentro = self.tiempo + M.INTERVALO * (0.8 + math.random() * 0.6)
        end
      end
    end
    for _, g in pairs(self.grupos) do
      if not g.encuentro and activos < M.MAX_A_LA_VEZ then
        -- cuenta a los que cazan en campo abierto
        local afuera = {}
        for _, e in ipairs(self:miembrosGrupo(g)) do
          if e.vivo and e.modo == "mundo" and (e.z or 0) == 0 and not self:ciudadEn(e.x, e.y) then afuera[#afuera + 1] = e end
        end
        if #afuera >= 2 then
          g.proximoEncuentro = g.proximoEncuentro or (self.tiempo + M.INTERVALO * (0.4 + math.random() * 0.6))
          if self.tiempo >= g.proximoEncuentro then
            local lista = self:crearEncuentro(g, afuera)
            if lista then
              g.encuentro = lista
              activos = activos + 1
            else
              g.proximoEncuentro = self.tiempo + 30
            end
          end
        else
          g.proximoEncuentro = nil
        end
      end
    end
  end
end

return M
