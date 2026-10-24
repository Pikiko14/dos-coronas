-- Herramienta sin ventana: la usa herramientas/empaquetar.py para compilar el Lua del juego a bytecode con el LuaJIT de LÖVE.
function love.conf(t)
  t.identity = "doscoronas_compilar"
  t.console = false
  for _, m in ipairs({ "window", "graphics", "audio", "sound", "image", "joystick", "mouse", "keyboard", "touch", "video", "font", "thread", "physics", "timer", "event" }) do
    t.modules[m] = false
  end
end
