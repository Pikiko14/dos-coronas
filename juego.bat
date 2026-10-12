@echo off
rem Abre solo el juego (proyecto juego\). Hace falta un servidor en marcha:
rem el de esta maquina (servidor.bat) o el que diga juego\.env.
setlocal
cd /d "%~dp0"

set "LOVE="
where love >nul 2>nul && set "LOVE=love"
if not defined LOVE if exist "%~dp0..\love\love.exe" set "LOVE=%~dp0..\love\love.exe"
if not defined LOVE (
  echo No se encontro LOVE en el PATH ni en ..\love\love.exe
  pause
  exit /b 1
)

start "" "%LOVE%" "%~dp0juego"
exit /b 0
