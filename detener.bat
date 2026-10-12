@echo off
rem Apaga el servidor de Dos Coronas guardando antes a todos los jugadores conectados.
rem (Cerrar la ventana del servidor a la fuerza no guarda lo posterior al ultimo guardado.)
if not exist "%~dp0servidor" (
  echo No encuentro la carpeta servidor.
  pause
  exit /b 1
)
echo detener > "%~dp0servidor\detener.txt"
echo Pedido enviado: el servidor guarda a todos y se cierra en unos segundos.
timeout /t 3 /nobreak >nul
