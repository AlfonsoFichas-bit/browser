@echo off
title REPARAR PATH de sistema (Baobabs / MSYS2)
echo.
echo Esto restaura el PATH de sistema desde el backup y pone
echo MSYS2 ucrt64 en el indice 0, con validaciones antes/despues.
echo Se pedira confirmacion de Usuario (UAC).
echo.
set "PS5=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%PS5%' -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%~dp0repair-path.ps1'"
