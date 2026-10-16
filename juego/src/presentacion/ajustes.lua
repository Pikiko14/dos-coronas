local Util = require("compartido.dominio.util")
local Sonido = require("src.presentacion.sonido")

local A = {
  volumen = 0.8,
  completo = false,
  ancho = 1280,
  alto = 720,
  teclas = {},             -- acción -> tecla del usuario con la sesión iniciada (ver A.usarUsuario)
  teclasUsuario = {},      -- usuario (en minúsculas) -> sus teclas: cada cuenta guarda las suyas
  usuarioTeclas = nil,
  barrasUsuario = {},      -- usuario -> clase -> orden de los 6 poderes en la barra (arrastrando se reordenan)
  esperando = nil,
  teclasPantalla = false, -- isométrico: true = W/A/S/D van derechas en la pantalla; false = siguen las diagonales del rombo
  personajesCapas = true, -- personajes por capas (arte/fao); false = los personajes antiguos
  casasIso = true,        -- casas isométricas en las ciudades (false: las antiguas, dibujadas por código)
  graficos = "alto",      -- efectos de ambiente: alto, medio, bajo, apagado
  ultimoUsuario = "",   -- el último usuario con el que se entró (se recuerda en el formulario)
}

-- Acciones con tecla configurable y su tecla por defecto. Los poderes van por POSICIÓN en la barra (ordenados por nivel), no por poder.
A.ACCIONES = {
  { "poder1", "Poder 1", "1" }, { "poder2", "Poder 2", "2" }, { "poder3", "Poder 3", "3" }, { "poder4", "Poder 4", "4" },
  { "poder5", "Poder 5", "5" }, { "poder6", "Poder 6", "6" }, { "pocion_vida", "Poción de vida", "7" }, { "pocion_mana", "Poción de maná", "8" },
  { "interactuar", "Interactuar", "e" }, { "bolsa", "Bolsa", "i" },
}
-- Teclas que el juego ya usa para otra cosa (movimiento, paneles, chat...): no se pueden asignar.
A.RESERVADAS = {}
for _, k in ipairs({ "w", "a", "s", "d", "up", "down", "left", "right", "tab", "escape", "return", "kpenter", "backspace", "c", "p", "n", "j", "o", "l", "y",
  "u", "r", "b", "g", "k", "m", "q", "t", "f1", "f2", "f3", "f11" }) do A.RESERVADAS[k] = true end

local function porDefecto()
  local t = {}
  for _, a in ipairs(A.ACCIONES) do t[a[1]] = a[3] end
  return t
end

function A.nombreTecla(k)
  if not k or k == "" then return "—" end
  if k == "space" then return "Espacio" end
  return #k == 1 and k:upper() or k
end

-- Carga las teclas de un usuario (cada cuenta tiene las suyas; sin guardado, las de por defecto). Se llama al iniciar sesión.
function A.usarUsuario(usuario)
  usuario = tostring(usuario or ""):lower()
  A.usuarioTeclas = usuario ~= "" and usuario or nil
  local t = porDefecto()
  local guardado = usuario ~= "" and A.teclasUsuario[usuario]
  if not guardado and A.heredadas then
    for k, v in pairs(A.heredadas) do t[k] = v end
  end
  if type(guardado) == "table" then
    for _, a in ipairs(A.ACCIONES) do
      if type(guardado[a[1]]) == "string" then t[a[1]] = guardado[a[1]] end
    end
  end
  A.teclas = t
end

-- Asigna una tecla a una acción. Devuelve nil si va bien o el motivo si no se puede. Si otra acción ya la usaba, intercambian las teclas.
function A.asignarTecla(accion, tecla)
  if not tecla or tecla == "" then return "Tecla no válida." end
  if A.RESERVADAS[tecla] then return "Esa tecla ya la usa el juego (" .. A.nombreTecla(tecla) .. ")." end
  local previa = A.teclas[accion]
  for _, a in ipairs(A.ACCIONES) do
    if a[1] ~= accion and A.teclas[a[1]] == tecla then A.teclas[a[1]] = previa end
  end
  A.teclas[accion] = tecla
  return nil
end

function A.restablecerTeclas()
  A.teclas = porDefecto()
  if A.usuarioTeclas then A.barrasUsuario[A.usuarioTeclas] = nil end
end

-- Orden en que se muestran los 6 poderes: el que el jugador arrastró o, por defecto, de menor a mayor nivel. Lista de posiciones de la barra del servidor.
function A.orden(clase)
  local u = A.usuarioTeclas and A.barrasUsuario[A.usuarioTeclas]
  local o = u and u[clase]
  if type(o) == "table" and #o == 6 then
    local visto, bien = {}, true
    for _, v in ipairs(o) do
      if type(v) ~= "number" or v < 1 or v > 6 or visto[v] then bien = false end
      visto[v or 0] = true
    end
    if bien then return o end
  end
  return require("compartido.dominio.arbol").ordenBarra(clase)
end

-- Cambia de sitio dos poderes de la barra (por su posición real en la barra del servidor). Se guarda por usuario.
function A.intercambiarPoderes(clase, slotA, slotB)
  if slotA == slotB or not A.usuarioTeclas then return false end
  local o = {}
  for i, v in ipairs(A.orden(clase)) do o[i] = v end
  local ia, ib
  for i, v in ipairs(o) do
    if v == slotA then ia = i end
    if v == slotB then ib = i end
  end
  if not ia or not ib then return false end
  o[ia], o[ib] = o[ib], o[ia]
  A.barrasUsuario[A.usuarioTeclas] = A.barrasUsuario[A.usuarioTeclas] or {}
  A.barrasUsuario[A.usuarioTeclas][clase] = o
  return true
end

function A.cargar(aplicar)
  if love.filesystem.getInfo("ajustes.json") then
    local bruto = love.filesystem.read("ajustes.json")
    local t = bruto and Util.jsonDec(bruto)
    if type(t) == "table" then
      A.volumen = tonumber(t.volumen) or A.volumen
      if A.volumen < 0 then A.volumen = 0 end
      if A.volumen > 1 then A.volumen = 1 end
      A.completo = t.completo and true or false
      if t.casasIso == false then A.casasIso = false end
      if t.graficos == "alto" or t.graficos == "medio" or t.graficos == "bajo" or t.graficos == "apagado" then A.graficos = t.graficos end
      -- la misión que seguías en el mapa se recuerda entre sesiones
      if type(t.misionSeguida) == "string" and #t.misionSeguida <= 40 then require("compartido.dominio.misiones").seguida = t.misionSeguida end
      if type(t.ultimoUsuario) == "string" and #t.ultimoUsuario <= 16 then A.ultimoUsuario = t.ultimoUsuario end
      A.ancho = tonumber(t.ancho) or A.ancho
      A.alto = tonumber(t.alto) or A.alto
      if type(t.teclasUsuario) == "table" then
        for u, tt in pairs(t.teclasUsuario) do
          if type(u) == "string" and #u <= 16 and type(tt) == "table" then
            local limpio = {}
            for _, a in ipairs(A.ACCIONES) do
              if type(tt[a[1]]) == "string" and #tt[a[1]] <= 16 then limpio[a[1]] = tt[a[1]] end
            end
            A.teclasUsuario[u] = limpio
          end
        end
      end
      if type(t.barrasUsuario) == "table" then
        for u, porClase in pairs(t.barrasUsuario) do
          if type(u) == "string" and #u <= 16 and type(porClase) == "table" then
            A.barrasUsuario[u] = {}
            for clase, o in pairs(porClase) do
              if type(clase) == "string" and #clase <= 16 and type(o) == "table" then
                local lista = {}
                for i = 1, 6 do lista[i] = tonumber(o[i]) end
                A.barrasUsuario[u][clase] = lista
              end
            end
          end
        end
      end
      -- guardados antiguos: las teclas de interactuar y bolsa eran de la instalación; pasan a ser el punto de partida de cada cuenta nueva
      if type(t.teclas) == "table" then
        for _, k in ipairs({ "interactuar", "bolsa" }) do
          if type(t.teclas[k]) == "string" then A.heredadas = A.heredadas or {} A.heredadas[k] = t.teclas[k] end
        end
      end
    end
  end
  Sonido.volumen = A.volumen
  if aplicar then A.aplicarVentana() end
end

function A.guardar()
  Sonido.volumen = A.volumen
  if A.usuarioTeclas then
    local copia = {}
    for k, v in pairs(A.teclas) do copia[k] = v end
    A.teclasUsuario[A.usuarioTeclas] = copia
  end
  love.filesystem.write("ajustes.json", Util.jsonEnc({
    volumen = A.volumen,
    completo = A.completo,
    graficos = A.graficos,
    casasIso = A.casasIso,
    misionSeguida = require("compartido.dominio.misiones").seguida,
    ancho = A.ancho,
    alto = A.alto,
    ultimoUsuario = A.ultimoUsuario,
    teclasUsuario = A.teclasUsuario,
    barrasUsuario = A.barrasUsuario,
  }))
end

A.usarUsuario("")   -- sin sesión: teclas por defecto

function A.aplicarVentana()
  love.window.setMode(A.ancho, A.alto, { fullscreen = A.completo, resizable = true })
end

return A
