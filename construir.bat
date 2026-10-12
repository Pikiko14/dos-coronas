@echo off
rem Genera dist\servidor.love y dist\juego.love (ver construir.ps1).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0construir.ps1"
pause
