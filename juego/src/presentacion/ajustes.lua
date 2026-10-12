local Util = require("compartido.dominio.util")
local Sonido = require("src.presentacion.sonido")

local A = {
  volumen = 0.8,
  completo = false,
  ancho = 1280,
  alto = 720,
  teclas = { interactuar = "e", bolsa = "i" },
  esperando = nil,
  ultimoUsuario = "",   -- el último usuario con el que se entró (se recuerda en el formulario)
}

function A.cargar(aplicar)
  if love.filesystem.getInfo("ajustes.json") then
    local bruto = love.filesystem.read("ajustes.json")
    local t = bruto and Util.jsonDec(bruto)
    if type(t) == "table" then
      A.volumen = tonumber(t.volumen) or A.volumen
      if A.volumen < 0 then A.volumen = 0 end
      if A.volumen > 1 then A.volumen = 1 end
      A.completo = t.completo and true or false
      if type(t.ultimoUsuario) == "string" and #t.ultimoUsuario <= 16 then A.ultimoUsuario = t.ultimoUsuario end
      A.ancho = tonumber(t.ancho) or A.ancho
      A.alto = tonumber(t.alto) or A.alto
      if type(t.teclas) == "table" then
        if type(t.teclas.interactuar) == "string" then A.teclas.interactuar = t.teclas.interactuar end
        if type(t.teclas.bolsa) == "string" then A.teclas.bolsa = t.teclas.bolsa end
      end
    end
  end
  Sonido.volumen = A.volumen
  if aplicar then A.aplicarVentana() end
end

function A.guardar()
  Sonido.volumen = A.volumen
  love.filesystem.write("ajustes.json", Util.jsonEnc({
    volumen = A.volumen,
    completo = A.completo,
    ancho = A.ancho,
    alto = A.alto,
    ultimoUsuario = A.ultimoUsuario,
    teclas = { interactuar = A.teclas.interactuar, bolsa = A.teclas.bolsa },
  }))
end

function A.aplicarVentana()
  love.window.setMode(A.ancho, A.alto, { fullscreen = A.completo, resizable = true })
end

return A
