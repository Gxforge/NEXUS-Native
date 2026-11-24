@echo off
rem NEXUS Native - actualiza esta carpeta con la ultima version de GitHub.
rem   Doble clic            -> ventana con barra de progreso
rem   SINCRONIZAR.bat --dry-run     -> ventana mostrando solo el plan
rem   SINCRONIZAR.bat --no-gui -y   -> consola
setlocal
cd /d "%~dp0"
if "%NEXUS_GITHUB_TOKEN%"=="" (
  set /p NEXUS_GITHUB_TOKEN=Token de GitHub (Enter si el repo es publico): 
)
if "%~1"=="" (
  python "%~dp0tools\sync_nexus.py" --gui --target "%~dp0"
) else (
  python "%~dp0tools\sync_nexus.py" --target "%~dp0" %*
)
set RESULT=%ERRORLEVEL%
echo.
if not "%RESULT%"=="0" echo Termino con errores (codigo %RESULT%).
pause
endlocal
