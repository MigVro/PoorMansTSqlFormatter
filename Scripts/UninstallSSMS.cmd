@echo off
setlocal
set "EXT_ID=9dddad8b-2f6c-4754-878b-d745a9757336"
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

set "SSMS="
for /f "usebackq delims=" %%i in (`"%VSWHERE%" -products Microsoft.VisualStudio.Product.Ssms -prerelease -property installationPath`) do set "SSMS=%%i"
if not defined SSMS (echo SSMS 22 not found via vswhere.& exit /b 1)

powershell -NoProfile -Command "if (Get-Process Ssms -ErrorAction SilentlyContinue | Where-Object { $_.Path -like ($env:SSMS + '*') }) { exit 1 }"
if errorlevel 1 (echo Close SSMS 22 first.& exit /b 1)

"%SSMS%\Common7\IDE\VSIXInstaller.exe" /quiet /uninstall:%EXT_ID%
echo VSIXInstaller exit code: %errorlevel%
