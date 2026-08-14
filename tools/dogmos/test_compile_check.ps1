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
param()

$ErrorActionPreference = 'Stop'

$GameRepo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Dm = 'C:\Program Files (x86)\BYOND\bin\dm.exe'
$ScratchDme = 'tgstation.synccheck.dme'

Push-Location $GameRepo
try {
	Copy-Item 'tgstation.dme' $ScratchDme -Force
	try {
		Write-Host '=== Compiling with -DCBT -DCIBUILDING (syntax check only, no DreamDaemon) ===' -ForegroundColor Cyan
		$output = & $Dm '-DCBT' '-DCIBUILDING' $ScratchDme 2>&1
		$output | ForEach-Object { Write-Host $_ }
		$result = $output | Select-String 'errors,' | Select-Object -Last 1

		if ($result -notmatch '^\s*tgstation\.synccheck\.dmb - 0 errors') {
			Write-Host ''
			Write-Host 'Compile failed - see the error(s) above.' -ForegroundColor Red
			exit 1
		}

		Write-Host ''
		Write-Host 'Clean compile under CIBUILDING/UNIT_TESTS.' -ForegroundColor Green
		exit 0
	} finally {
		Remove-Item $ScratchDme -ErrorAction SilentlyContinue
		Remove-Item 'tgstation.synccheck.dmb' -ErrorAction SilentlyContinue
		Remove-Item 'tgstation.synccheck.rsc' -ErrorAction SilentlyContinue
	}
} finally {
	Pop-Location
}
