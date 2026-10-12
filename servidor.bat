@echo off
rem Abre el servidor de Dos Coronas (proyecto servidor\, sin ventana, solo consola).
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

"%LOVE%" "%~dp0servidor"
pause
