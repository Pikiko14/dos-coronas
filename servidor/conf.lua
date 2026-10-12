-- Servidor sin ventana: solo consola, red, archivos y reloj.
function love.conf(t)
  t.identity = "doscoronas"
  t.console = true
  t.window = nil
  t.modules.window = false
  t.modules.graphics = false
  t.modules.audio = false
  t.modules.sound = false
  t.modules.font = false
  t.modules.image = false
  t.modules.video = false
  t.modules.joystick = false
  t.modules.keyboard = false
  t.modules.mouse = false
  t.modules.touch = false
  t.modules.physics = false
  t.modules.thread = false
end
