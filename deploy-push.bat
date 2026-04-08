@echo off
setlocal
cd /d "%~dp0"

git add .
if errorlevel 1 exit /b 1

git commit -m "deploy: prisma + server update"
if errorlevel 1 exit /b 1

git push origin main
if errorlevel 1 exit /b 1

echo Done.
endlocal
