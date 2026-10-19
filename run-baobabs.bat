@echo off
set "PATH=C:\msys64\ucrt64\bin;%PATH%"
cd /d "%~dp0baobabs\builddir\src"
if "%~1"=="" (
    start "" "baobabs.exe"
) else (
    start "" "baobabs.exe" "%~1"
)
