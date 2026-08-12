<#
	Runs the DM unit test suite the way it actually has to be run, and reports failures
	diffed against a known baseline.

	Why this exists - two traps cost real time during Phase 0, and both fail SILENTLY:

	1. Juke's short flags take an attached value. `-D FOO` discards FOO and treats it as a
	   target name; only `--define=FOO` works.
	2. UNIT_TEST_BASIC is defined as UNIT_TEST_DEBUG_MAP_ONLY, so default-flagged tests only run
	   on the primary unit test map (runtimestation_minimal). A bare `dm-test` runs 14 map tests,
	   skips everything else, writes "Success!" to clean_run.lk, and looks like a pass.

	The MinimumTests guard below exists specifically to catch trap 2 recurring.
#>

[CmdletBinding()]
param(
	# A run recording fewer tests than this almost certainly hit the silent-skip trap.
	[int]$MinimumTests = 400,
	# Update the baseline to whatever this run produced, instead of comparing against it.
	[switch]$UpdateBaseline
)

$ErrorActionPreference = 'Stop'

$GameRepo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$BaselinePath = Join-Path $PSScriptRoot 'test_baseline.json'
$ResultsPath = Join-Path $GameRepo 'data\unit_tests.json'

$UNIT_TEST_PASSED = 0
$UNIT_TEST_FAILED = 1

Push-Location $GameRepo
try {
	# Default-flagged tests only run on the primary unit test map. Set it the way CI does.
	Copy-Item '_maps\runtimestation_minimal.json' 'data\next_map.json' -Force

	# Delete prior results first. Without this, a run that crashes before reaching the tests leaves
	# the PREVIOUS run's results in place and every check below happily passes against them.
	Remove-Item $ResultsPath -ErrorAction SilentlyContinue
	Remove-Item 'data\logs\ci\clean_run.lk' -ErrorAction SilentlyContinue

	Write-Host '=== Running dm-test on runtimestation_minimal ===' -ForegroundColor Cyan

	& cmd /c 'tools\build\build.bat dm-test --define=MINIMAL_CENTCOM --define=SKIP_LAVALAND --define=SKIP_SPACE_LEVELS'

	if (-not (Test-Path $ResultsPath)) {
		throw "No $ResultsPath produced - the run never reached the unit tests. Check data\logs\ci\runtime.log for where initialisation stopped; a hard crash (e.g. a Rust access violation) leaves no DM runtime behind."
	}

	# Note: clean_run.lk is NOT a completion signal - it is tg's "the run was clean" marker, absent
	# whenever tests failed or runtimes were logged. With a non-empty baseline it never appears, so it
	# cannot be used to detect an abnormal exit. Freshness is guaranteed by deleting the results above;
	# completeness is checked by the test count below.
	if (Test-Path 'data\logs\ci\clean_run.lk') {
		Write-Host 'clean_run.lk present: the run was clean by tg standards (no failures, no runtimes).'
	}

	$results = Get-Content $ResultsPath -Raw | ConvertFrom-Json
	$all = @($results.PSObject.Properties)
	Write-Host "Tests recorded: $($all.Count)"

	if ($all.Count -lt $MinimumTests) {
		throw "Only $($all.Count) tests recorded (expected >= $MinimumTests). The suite was silently skipped - check the map and define syntax, do NOT trust this run."
	}

	$failed = @($all | Where-Object { $_.Value.status -eq $UNIT_TEST_FAILED } | ForEach-Object { $_.Name } | Sort-Object)

	if ($UpdateBaseline) {
		# -InputObject keeps a 1-element result an array rather than collapsing it to a scalar.
		ConvertTo-Json -InputObject $failed | Set-Content $BaselinePath -Encoding utf8
		Write-Host "Baseline updated: $($failed.Count) known failures written to $BaselinePath" -ForegroundColor Yellow
		return
	}

	$baseline = @()
	if (Test-Path $BaselinePath) {
		# Assign before wrapping: in PS 5.1, @(... | ConvertFrom-Json) yields a 1-element array
		# containing the whole Object[], not the elements. Wrapping a variable behaves correctly,
		# and also normalises the single-entry case where ConvertFrom-Json returns a bare string.
		$parsedBaseline = Get-Content $BaselinePath -Raw | ConvertFrom-Json
		$baseline = @($parsedBaseline)
	} else {
		Write-Warning "No baseline at $BaselinePath - every failure will be reported as new. Run with -UpdateBaseline to record one."
	}

	$new = @($failed | Where-Object { $baseline -notcontains $_ })
	$fixed = @($baseline | Where-Object { $failed -notcontains $_ })

	Write-Host ''
	Write-Host "=== Results ===" -ForegroundColor Cyan
	Write-Host "passed:          $(@($all | Where-Object { $_.Value.status -eq $UNIT_TEST_PASSED }).Count)"
	Write-Host "failed:          $($failed.Count) ($($baseline.Count) known)"

	if ($fixed.Count -gt 0) {
		Write-Host ''
		Write-Host "No longer failing (baseline may be stale):" -ForegroundColor Yellow
		$fixed | ForEach-Object { Write-Host "  $_" }
	}

	if ($new.Count -gt 0) {
		Write-Host ''
		Write-Host "NEW FAILURES:" -ForegroundColor Red
		$new | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
		Write-Host ''
		Write-Host "Details: data\logs\ci\tests.log" -ForegroundColor Red
		exit 1
	}

	Write-Host ''
	Write-Host 'No new failures.' -ForegroundColor Green
}
finally {
	Pop-Location
}
