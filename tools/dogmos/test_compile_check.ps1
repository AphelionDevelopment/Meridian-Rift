<#
	Fast syntax/compile-only check for code gated behind CIBUILDING/UNIT_TESTS (mainly
	code/modules/unit_tests/), without running DreamDaemon at all.

	Why this exists: a plain `dm.exe tgstation.dme` never even sees unit test files - they're only
	included in the CIBUILDING build. run_tests.ps1's own compile step catches syntax errors in them,
	but only after also running the full ~10-12 minute dm-test DreamDaemon cycle. A string-interpolation
	syntax error in dogmos_turf_adjacency_sync.dm cost exactly that gap once. `dm.exe` has supported -D
	defines directly since BYOND 1597 (tools/build/lib/byond.ts:169,219 already relies on this under the
	hood), so the same compile DmTestTarget does can be run standalone in ~2 minutes.

	This only checks compilation. It says nothing about whether a test PASSES - that still needs
	run_tests.ps1 (optionally with -Focus for one test) or boot_probe.ps1.

	Exit codes: 0 compiled clean, 1 compile failed (see output for the error).
#>

[CmdletBinding()]
param(
	# Seconds to allow DreamMaker to compile before treating it as a hung compiler process.
	[int]$TimeoutSeconds = 300,
	# DreamMaker executable, resolved as a relative path or command on PATH.
	[string]$DmPath = 'dm.exe'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

if ($TimeoutSeconds -le 0) { throw '-TimeoutSeconds must be greater than zero.' }

$GameRepo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Dm = Resolve-ToolPath $DmPath 'DreamMaker'
$ScratchDme = 'tgstation.synccheck.dme'
$compileProc = $null
$stdout = Join-Path $env:TEMP ("dogmos_compile_check_{0}_{1}.out" -f $PID, ([guid]::NewGuid().ToString('N')))
$stderr = Join-Path $env:TEMP ("dogmos_compile_check_{0}_{1}.err" -f $PID, ([guid]::NewGuid().ToString('N')))
$exitCode = 1

Push-Location $GameRepo
try {
	Copy-Item 'tgstation.dme' $ScratchDme -Force
	try {
		Write-Host '=== Compiling with -DCBT -DCIBUILDING (syntax check only, no DreamDaemon) ===' -ForegroundColor Cyan
		Remove-Item $stdout, $stderr -ErrorAction SilentlyContinue
		$compileProc = Start-Process -FilePath $Dm -ArgumentList @('-DCBT', '-DCIBUILDING', $ScratchDme) `
			-WorkingDirectory $GameRepo -NoNewWindow -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
		$compileProc | Wait-Process -Timeout $TimeoutSeconds -ErrorAction SilentlyContinue
		$timedOut = -not $compileProc.HasExited
		if ($timedOut) {
			$compileProc | Stop-Process -Force -ErrorAction SilentlyContinue
			$compileProc | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue
		}

		$compileOutput = @((Read-LogSafely $stdout), (Read-LogSafely $stderr)) -join "`n"
		$compileOutput -split "`r?`n" | Where-Object { $_ } | ForEach-Object { Write-Host $_ }
		$result = $compileOutput -split "`r?`n" | Select-String 'errors,' | Select-Object -Last 1
		$compileExit = if ($timedOut) { $null } else { $compileProc.ExitCode }

		if ($timedOut) {
			Write-Host ''
			Write-Host "Compile timed out after ${TimeoutSeconds}s." -ForegroundColor Red
		} elseif ($compileExit -ne 0 -or $result -notmatch '^\s*tgstation\.synccheck\.dmb - 0 errors') {
			Write-Host ''
			Write-Host 'Compile failed - see the error(s) above.' -ForegroundColor Red
		} else {
			Write-Host ''
			Write-Host 'Clean compile under CIBUILDING/UNIT_TESTS.' -ForegroundColor Green
			$exitCode = 0
		}
	} finally {
		if ($null -ne $compileProc -and -not $compileProc.HasExited) {
			$compileProc | Stop-Process -Force -ErrorAction SilentlyContinue
		}
		Remove-Item $ScratchDme -ErrorAction SilentlyContinue
		Remove-Item 'tgstation.synccheck.dmb' -ErrorAction SilentlyContinue
		Remove-Item 'tgstation.synccheck.rsc' -ErrorAction SilentlyContinue
		Remove-Item $stdout, $stderr -ErrorAction SilentlyContinue
	}
} finally {
	Pop-Location
}

exit $exitCode
