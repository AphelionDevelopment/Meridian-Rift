@echo off
setlocal

if not defined MERIDIAN_MCP_REPO (
	if defined DM_MCP_REPO (
		set "MERIDIAN_MCP_REPO=%DM_MCP_REPO%"
	) else (
		>&2 echo MERIDIAN_MCP_REPO is not configured.
		exit /b 1
	)
)

set "MERIDIAN_MCP_BINARY=%MERIDIAN_MCP_REPO%\target\release\meridian-mcp.exe"
if not exist "%MERIDIAN_MCP_BINARY%" (
	>&2 echo meridian-mcp release binary not found: "%MERIDIAN_MCP_BINARY%"
	exit /b 1
)

"%MERIDIAN_MCP_BINARY%"
exit /b %ERRORLEVEL%
