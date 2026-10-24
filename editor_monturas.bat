@echo off
rem Editor visual del asiento del jinete: arrastra al personaje sobre cada montura y guarda (no necesita servidor).
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
start "" "%LOVE%" "%~dp0juego" --monturas
exit /b 0
