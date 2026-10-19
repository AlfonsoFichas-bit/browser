@echo off
set "PATH=C:\msys64\ucrt64\bin;%PATH%"
if "%~1"=="" (
    start "" "%~dp0baobabs\builddir\src\baobabs.exe"
) else (
    start "" "%~dp0baobabs\builddir\src\baobabs.exe" "%~1"
)
