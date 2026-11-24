@echo off
rem NEXUS Native - actualiza esta carpeta con la ultima version de GitHub.
rem Doble clic o:  SINCRONIZAR.bat            (aplicar)
rem                SINCRONIZAR.bat --dry-run  (solo ver el plan)
setlocal
cd /d "%~dp0"
if "%NEXUS_GITHUB_TOKEN%"=="" (
  set /p NEXUS_GITHUB_TOKEN=Token de GitHub (Enter si el repo es publico): 
)
python "%~dp0tools\sync_nexus.py" --target "%~dp0" %*
set RESULT=%ERRORLEVEL%
echo.
if not "%RESULT%"=="0" echo La sincronizacion termino con errores (codigo %RESULT%).
pause
endlocal
