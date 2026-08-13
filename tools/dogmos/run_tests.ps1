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

	2026-08-13 postmortem, read before touching the exit-code handling again: this script used to
	pipe build.bat's output away without ever checking $LASTEXITCODE, and had no timeout at all - a
	run that hung (which one genuinely did, for 38 minutes of CPU with zero log growth) blocked the
	terminal indefinitely with no way to tell "still working" from "stuck" apart from watching the
	clock. Both are fixed below: a hard timeout that kills the run and fails loudly, and an
	independent check that initialisation actually completed (the same marker boot_probe.ps1 polls
	for) rather than trusting a downstream file's mere existence.

	The test-failure baseline is keyed on (test name, failure MESSAGE), not just test name. A test
	already failing for reason A must not silently absorb a new failure for reason B - that is
	exactly how /datum/unit_test/create_and_destroy's hard-delete assertions (the Phase 2 Del()
	milestone gate) could go silently blind while "still baselined" reads as fine.
#>

[CmdletBinding()]
param(
	# A run recording fewer tests than this almost certainly hit the silent-skip trap.
	[int]$MinimumTests = 400,
	# Seconds to let the whole dm-test run take before concluding it hung and killing it.
	[int]$TimeoutSeconds = 1800,
	# Update the test-failure baseline to whatever this run produced, instead of comparing against it.
	[switch]$UpdateBaseline,
	# Update the runtime-error baseline to whatever this run produced, instead of comparing against it.
	[switch]$UpdateRuntimeBaseline
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

$GameRepo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$BaselinePath = Join-Path $PSScriptRoot 'test_baseline.json'
$RuntimeBaselinePath = Join-Path $PSScriptRoot 'runtime_baseline.json'
$ResultsPath = Join-Path $GameRepo 'data\unit_tests.json'
$CiRuntimeLog = Join-Path $GameRepo 'data\logs\ci\runtime.log'
$InitMarker = 'Initializations complete within'

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
	Remove-Item $CiRuntimeLog -ErrorAction SilentlyContinue
	Remove-Item (Join-Path $GameRepo 'dogmos_panic.log') -ErrorAction SilentlyContinue

	Write-Host "=== Running dm-test on runtimestation_minimal (timeout ${TimeoutSeconds}s) ===" -ForegroundColor Cyan

	# Start-Process + Wait-Process so a hang is a failure instead of a blocked terminal. build.bat
	# spawns DreamDaemon as a child process; killing just the batch leaves DreamDaemon running, so
	# both get swept on timeout.
	$build = Start-Process -FilePath 'cmd.exe' -PassThru -NoNewWindow -ArgumentList @(
		'/c', 'tools\build\build.bat', 'dm-test',
		'--define=MINIMAL_CENTCOM', '--define=SKIP_LAVALAND', '--define=SKIP_SPACE_LEVELS'
	)
	$build | Wait-Process -Timeout $TimeoutSeconds -ErrorAction SilentlyContinue
	$timedOut = -not $build.HasExited
	if ($timedOut) {
		Get-Process dreamdaemon, dreammaker -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
		$build | Stop-Process -Force -ErrorAction SilentlyContinue
	}
	$buildExit = if ($timedOut) { 'TIMEOUT' } else { $build.ExitCode }
	Write-Host "build.bat exit: $buildExit (diagnostic only - see the note on clean_run.lk below)"

	if ($timedOut) {
		throw "dm-test did not finish within ${TimeoutSeconds}s and was killed. Check data\logs\ci\runtime.log for where it stopped."
	}

	# --- Signal 1: did the run actually complete? -------------------------------------------------
	if (-not (Test-Path $ResultsPath)) {
		throw "No $ResultsPath produced (build.bat exit $buildExit) - the run never reached the unit tests. Check data\logs\ci\runtime.log; a hard crash (e.g. a Rust access violation) leaves no DM runtime behind."
	}

	$ciLog = Read-LogSafely $CiRuntimeLog
	if ($ciLog -notmatch [regex]::Escape($InitMarker)) {
		throw "data\logs\ci\runtime.log has no '$InitMarker' marker - initialisation never finished, so the unit test results are from a broken world and must not be trusted."
	}

	# Note on clean_run.lk: tools\build\build.ts only writes it when GLOB.total_runtimes == 0 AND no
	# test failed (code\game\world.dm FinishTestRun()). With any baselined failure it never appears,
	# so build.bat's own exit code is *expected* to be non-zero here - that is normal, not a signal
	# to gate on. It conflates "tests failed" with "runtimes happened", which is exactly the two
	# things this script needs to tell apart below. Do not start trusting it as a shortcut.
	if (Test-Path 'data\logs\ci\clean_run.lk') {
		Write-Host 'clean_run.lk present: no test failures and no runtimes at all.' -ForegroundColor Green
	}

	$results = Get-Content $ResultsPath -Raw | ConvertFrom-Json
	$all = @($results.PSObject.Properties)
	Write-Host "Tests recorded: $($all.Count)"

	if ($all.Count -lt $MinimumTests) {
		throw "Only $($all.Count) tests recorded (expected >= $MinimumTests). The suite was silently skipped - check the map and define syntax, do NOT trust this run."
	}

	# --- Signal 2: test failures, at (name, message) granularity -----------------------------------
	$failedEntries = @($all | Where-Object { $_.Value.status -eq $UNIT_TEST_FAILED })
	$failed = @($failedEntries | ForEach-Object { $_.Name } | Sort-Object)

	if ($UpdateBaseline) {
		$baselineObj = [ordered]@{}
		foreach ($entry in ($failedEntries | Sort-Object Name)) {
			$baselineObj[$entry.Name] = $entry.Value.message
		}
		ConvertTo-Json -InputObject $baselineObj | Set-Content $BaselinePath -Encoding utf8
		Write-Host "Baseline updated: $($failedEntries.Count) known failures written to $BaselinePath" -ForegroundColor Yellow
	}

	$baseline = [ordered]@{}
	if (Test-Path $BaselinePath) {
		$parsed = Get-Content $BaselinePath -Raw | ConvertFrom-Json
		# Old format was a bare array of test names with no message. Accept it as "message unknown" so
		# a first run against the old baseline still reports sensibly instead of erroring.
		if ($parsed -is [array]) {
			foreach ($name in $parsed) { $baseline[$name] = $null }
		} else {
			$parsed.PSObject.Properties | ForEach-Object { $baseline[$_.Name] = $_.Value }
		}
	} elseif (-not $UpdateBaseline) {
		Write-Warning "No baseline at $BaselinePath - every failure will be reported as new. Run with -UpdateBaseline to record one."
	}

	# A test is a NEW failure if it wasn't failing before, OR it was failing but for a DIFFERENT
	# reason - a still-baselined name whose message changed must not hide behind the old entry.
	# Compared normalized (timestamps/refs/counts stripped) so a test whose failure reason hasn't
	# actually changed isn't flagged just because a timestamp, mob ref, or del count differs run to run.
	$new = @()
	$reasonChanged = @()
	foreach ($entry in $failedEntries) {
		if (-not $baseline.Contains($entry.Name)) {
			$new += $entry.Name
		} elseif ($null -ne $baseline[$entry.Name] -and (Get-NormalizedTestMessage $baseline[$entry.Name]) -ne (Get-NormalizedTestMessage $entry.Value.message)) {
			$reasonChanged += $entry.Name
		}
	}
	$fixed = @($baseline.Keys | Where-Object { $failed -notcontains $_ })

	Write-Host ''
	Write-Host '=== Test results ===' -ForegroundColor Cyan
	Write-Host "passed:          $(@($all | Where-Object { $_.Value.status -eq $UNIT_TEST_PASSED }).Count)"
	Write-Host "failed:          $($failed.Count) ($($baseline.Count) known)"

	if ($fixed.Count -gt 0) {
		Write-Host ''
		Write-Host 'No longer failing (baseline may be stale):' -ForegroundColor Yellow
		$fixed | ForEach-Object { Write-Host "  $_" }
	}

	$hadTestRegression = $false
	if ($new.Count -gt 0) {
		Write-Host ''
		Write-Host 'NEW FAILURES:' -ForegroundColor Red
		$new | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
		$hadTestRegression = $true
	}
	if ($reasonChanged.Count -gt 0) {
		Write-Host ''
		Write-Host 'FAILURE REASON CHANGED (still baselined by name, but not by why):' -ForegroundColor Red
		foreach ($name in $reasonChanged) {
			$current = ($failedEntries | Where-Object { $_.Name -eq $name }).Value.message
			Write-Host "  $name" -ForegroundColor Red
			Write-Host "    was: $($baseline[$name])" -ForegroundColor DarkGray
			Write-Host "    now: $current" -ForegroundColor Red
		}
		$hadTestRegression = $true
	}
	if ($hadTestRegression) {
		Write-Host ''
		Write-Host 'Details: data\logs\ci\tests.log' -ForegroundColor Red
	}

	# --- Signal 3: runtimes, measured independently of test pass/fail -----------------------------
	$sigs = Get-RuntimeSignatures $ciLog
	$hadNewRuntimes = $false

	if ($UpdateRuntimeBaseline) {
		ConvertTo-Json -InputObject @($sigs | Select-Object -Unique | Sort-Object) | Set-Content $RuntimeBaselinePath -Encoding utf8
		Write-Host "Runtime baseline updated: $(@($sigs | Select-Object -Unique).Count) signatures." -ForegroundColor Yellow
	} else {
		$rt = Compare-ToBaseline $sigs $RuntimeBaselinePath
		Write-Host ''
		Write-Host "runtimes:        $($sigs.Count) total, $(@($rt.All).Count) distinct"

		# Per-test attribution - see the "runtimes" field RunUnitTest now records in unit_tests.json.
		$noisy = @($all | Where-Object { $_.Value.runtimes -gt 0 } | Sort-Object { -$_.Value.runtimes })
		if ($noisy.Count -gt 0) {
			Write-Host 'Tests that logged runtimes:' -ForegroundColor Yellow
			$noisy | ForEach-Object { Write-Host "  x$($_.Value.runtimes)  $($_.Name)" }
		}

		if ($rt.New.Count -gt 0) {
			Write-Host ''
			Write-Host 'NEW RUNTIME ERRORS:' -ForegroundColor Red
			$rt.New | ForEach-Object { Write-Host "  x$($_.Count)  $($_.Sig)" -ForegroundColor Red }
			Write-Host 'Details: data\logs\ci\runtime.log' -ForegroundColor Red
			$hadNewRuntimes = $true
		}
		if ($rt.Fixed.Count -gt 0) {
			Write-Host 'No longer occurring (baseline may be stale):' -ForegroundColor Yellow
			$rt.Fixed | ForEach-Object { Write-Host "  $_" }
		}
	}

	# Dogmos writes panics here even when rayon swallows them on a worker thread and the run
	# otherwise completes - see the diagnostic panic hook installed in the fork's src\lib.rs.
	$panicLog = Join-Path $GameRepo 'dogmos_panic.log'
	$hadPanic = $false
	if ((Test-Path $panicLog) -and (Get-Item $panicLog).Length -gt 0) {
		Write-Host ''
		Write-Host '=== dogmos_panic.log ===' -ForegroundColor Red
		Get-Content $panicLog -Tail 40
		$hadPanic = $true
	}

	if ($hadTestRegression -or $hadNewRuntimes -or $hadPanic) {
		exit 1
	}

	Write-Host ''
	Write-Host 'No new failures, no new runtimes.' -ForegroundColor Green
}
finally {
	Pop-Location
}
