@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "RIFT_NETWORK=%MERIDIAN_RIFT_BUILD_NETWORK%"
if not defined RIFT_NETWORK set "RIFT_NETWORK=offline"
:detect_network
if "%~1"=="" goto launch
set "RIFT_ARGUMENT=%~1"
if /I "%RIFT_ARGUMENT%"=="--network" goto detect_network_value
if /I "%RIFT_ARGUMENT:~0,10%"=="--network=" set "RIFT_NETWORK=%RIFT_ARGUMENT:~10%"
shift /1
goto detect_network

:detect_network_value
shift /1
if "%~1"=="" exit /b 2
set "RIFT_NETWORK=%~1"
shift /1
goto detect_network

:launch
if /I not "%RIFT_NETWORK%"=="offline" if /I not "%RIFT_NETWORK%"=="allow" (
	>&2 echo [usage_error] network mode must be offline or allow
	exit /b 2
)
pushd "%~dp0" || exit /b 3
set "RIFT_CACHE=%TG_BOOTSTRAP_CACHE%"
if not defined RIFT_CACHE set "RIFT_CACHE=tools\bootstrap\.cache"
for %%I in ("%RIFT_CACHE%") do set "RIFT_CACHE=%%~fI"
popd
set "TG_BOOTSTRAP_CACHE=%RIFT_CACHE%"
if /I "%RIFT_NETWORK%"=="allow" goto bootstrap

for /f "tokens=2 delims==" %%V in ('findstr /B /C:"export BUN_VERSION=" "%~dp0dependencies.sh"') do set "RIFT_BUN_VERSION=%%V"
if not defined RIFT_BUN_VERSION (
	>&2 echo [offline_preflight_failed] BUN_VERSION is missing
	exit /b 3
)
set "RIFT_BUN=%RIFT_CACHE%\bun-v%RIFT_BUN_VERSION%-x64\bun.exe"
if not exist "%RIFT_BUN%" (
	>&2 echo [offline_preflight_failed] pinned Bun is absent
	exit /b 3
)
"%RIFT_BUN%" "%~dp0tools\rift\rift.ts" %*
exit /b %ERRORLEVEL%

:bootstrap
"%~dp0tools\bootstrap\javascript.bat" "%~dp0tools\rift\rift.ts" %*
