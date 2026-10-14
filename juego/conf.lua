function love.conf(t)
  t.identity = "doscoronas"
  t.window.title = "Dos Coronas"
  t.window.icon = "arte/icono.png"      -- la corona del juego en la ventana y la barra de tareas
  t.window.width = 1280
  t.window.height = 720
  t.window.resizable = true
  t.window.minwidth = 1024
  t.window.minheight = 600
  t.window.vsync = 1
  t.window.highdpi = false
  local prueba = false
  if arg then
    for _, v in pairs(arg) do
      if v == "--test" or v == "--foto" or v == "--bot" then prueba = true end
    end
  end
  t.console = prueba
  if prueba then
    t.window.vsync = 0
  end
end
