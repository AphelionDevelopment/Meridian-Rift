<#
	Compiles, boots DreamDaemon directly, and reports whether initialisation actually completed.

	Why this exists: `dm-test` runs DreamDaemon in a way that discards its stderr, so a Rust panic or
	an access violation shows up only as an opaque exit code and a log that stops mid-sentence. Booting
	it directly with stderr redirected is the only way to see the actual message.

	2026-08-13 postmortem, read before touching the success criterion again: this script used to treat
	"the process is still alive when the timer expires" as success. DreamDaemon under -close never
	exits on its own, so that criterion could only ever be failed by a hard crash - a hung boot, a
	boot spewing tens of thousands of runtime errors, and a genuinely clean boot were all
	indistinguishable at T+timeout. It reported "BOOTED" for 220 seconds of an init-order bug that
	left every turf with empty air. Success is now polled for directly: the "Initializations complete
	within" marker that the Master controller itself writes (code\controllers\master.dm), plus a
	separate, unmasked check for new runtime-error signatures. A red line that cannot change the exit
	code is worse than no check - it looks like verification without being any.

	Exit codes:
	  0   booted clean, no new runtime errors
	  1   process died (see the crash-code table below)
	  2   timed out - init never completed within TimeoutSeconds
	  3   booted, but logged runtime errors not in runtime_baseline.json
	  4   Dogmos wrote a panic to dogmos_panic.log (rayon can swallow a worker-thread panic even
	      when the process survives - see src\lib.rs's diagnostic hook in the fork)
#>

[CmdletBinding()]
param(
	# Seconds to wait for the "Initializations complete" marker before concluding the boot hung.
	[int]$TimeoutSeconds = 220,
	# Skip the DM compile and boot whatever .dmb is already built.
	[switch]$SkipCompile,
	# Record whatever runtime-error signatures this run produced as the new baseline, instead of
	# diffing against it. Only meaningful to run right after confirming a clean boot by hand - see
	# the plan's verification sequence.
	[switch]$UpdateRuntimeBaseline
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

$GameRepo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Dm = 'C:\Program Files (x86)\BYOND\bin\dm.exe'
$DreamDaemon = 'C:\Program Files (x86)\BYOND\bin\dreamdaemon.exe'
$LogDir = 'boot_probe'
$InitMarker = 'Initializations complete within'
$RuntimeBaseline = Join-Path $PSScriptRoot 'runtime_baseline.json'

Push-Location $GameRepo
try {
	if (-not $SkipCompile) {
		Write-Host '=== Compiling ===' -ForegroundColor Cyan
		$compile = & $Dm tgstation.dme 2>&1
		$result = $compile | Select-String 'errors,' | Select-Object -Last 1
		Write-Host $result
		if ($result -notmatch '^\s*tgstation\.dmb - 0 errors') {
			throw 'Compile failed - fix that before probing the boot.'
		}
	}

	$stdout = Join-Path $env:TEMP 'dogmos_boot_probe_out.txt'
	$stderr = Join-Path $env:TEMP 'dogmos_boot_probe_err.txt'
	Remove-Item $stdout, $stderr -ErrorAction SilentlyContinue
	Remove-Item (Join-Path $GameRepo "data\logs\$LogDir") -Recurse -Force -ErrorAction SilentlyContinue
	# A panic from a PRIOR run must never be attributed to this one.
	Remove-Item (Join-Path $GameRepo 'dogmos_panic.log') -ErrorAction SilentlyContinue

	Write-Host "=== Booting (up to ${TimeoutSeconds}s, polling for '$InitMarker') ===" -ForegroundColor Cyan
	$proc = Start-Process -FilePath $DreamDaemon `
		-ArgumentList 'tgstation.dmb', '-close', '-trusted', '-verbose', '-params', "log-directory=$LogDir" `
		-NoNewWindow -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr

	$runtimeLog = Join-Path $GameRepo "data\logs\$LogDir\runtime.log"
	$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
	$outcome = 'TIMEOUT'
	while ((Get-Date) -lt $deadline) {
		if ($proc.HasExited) { $outcome = 'DIED'; break }
		if ((Read-LogSafely $runtimeLog) -match [regex]::Escape($InitMarker)) { $outcome = 'INITIALISED'; break }
		Start-Sleep -Milliseconds 2000
	}

	# Stop BEFORE reading logs for real, so buffered writes land and nothing holds the file open.
	if (-not $proc.HasExited) {
		$proc | Stop-Process -Force
		Start-Sleep -Milliseconds 500
	}

	$logText = Read-LogSafely $runtimeLog
	$exitCode = 0

	Write-Host ''
	Write-Host '=== Result ===' -ForegroundColor Cyan
	switch ($outcome) {
		'INITIALISED' {
			$line = ($logText -split "`r?`n" | Where-Object { $_ -match [regex]::Escape($InitMarker) } | Select-Object -Last 1)
			Write-Host "INITIALISED - $($line.Trim())" -ForegroundColor Green
		}
		'DIED' {
			$code = $proc.ExitCode
			$meaning = switch ($code) {
				-1073741819 { 'access violation (0xC0000005) - byondapi ABI mismatch for this BYOND build' }
				-1073740791 { 'Rust abort() (0xC0000409) - a panic; see stderr below' }
				default     { 'see logs' }
			}
			Write-Host "DIED - exit code $code : $meaning" -ForegroundColor Red
			$exitCode = 1
		}
		'TIMEOUT' {
			Write-Host "HUNG - ${TimeoutSeconds}s elapsed with no '$InitMarker' in runtime.log." -ForegroundColor Red
			$lastSubsystem = ($logText -split "`r?`n" | Where-Object { $_ -match 'Initialized (.+) subsystem' } | Select-Object -Last 1)
			if ($lastSubsystem) { Write-Host "Last subsystem initialised: $($lastSubsystem.Trim())" }
			$exitCode = 2
		}
	}

	# Runtime errors are a SEPARATE signal from "did it boot". A run can reach the marker and still
	# have logged dozens of runtimes along the way - that was exactly the init-order bug's signature
	# (turf air silently empty, "Invalid gas ID" logged per turf, boot eventually completing anyway).
	$sigs = Get-RuntimeSignatures $logText

	if ($UpdateRuntimeBaseline) {
		ConvertTo-Json -InputObject @($sigs | Select-Object -Unique | Sort-Object) | Set-Content $RuntimeBaseline -Encoding utf8
		Write-Host "Runtime baseline updated: $(@($sigs | Select-Object -Unique).Count) signatures." -ForegroundColor Yellow
	} else {
		$rt = Compare-ToBaseline $sigs $RuntimeBaseline
		Write-Host "Runtime errors: $($sigs.Count) total, $(@($rt.All).Count) distinct."
		if ($rt.New.Count -gt 0) {
			Write-Host ''
			Write-Host 'NEW RUNTIME ERRORS:' -ForegroundColor Red
			$rt.New | ForEach-Object { Write-Host "  x$($_.Count)  $($_.Sig)" -ForegroundColor Red }
			if ($exitCode -eq 0) { $exitCode = 3 }
		}
		if ($rt.Fixed.Count -gt 0) {
			Write-Host 'No longer occurring (baseline may be stale):' -ForegroundColor Yellow
			$rt.Fixed | ForEach-Object { Write-Host "  $_" }
		}
	}

	# Dogmos writes panics here even when rayon swallows them on a worker thread and the process
	# survives - see the diagnostic panic hook installed in the fork's src\lib.rs.
	$panicLog = Join-Path $GameRepo 'dogmos_panic.log'
	if ((Test-Path $panicLog) -and (Get-Item $panicLog).Length -gt 0) {
		Write-Host ''
		Write-Host '=== dogmos_panic.log ===' -ForegroundColor Red
		Get-Content $panicLog -Tail 40
		if ($exitCode -eq 0) { $exitCode = 4 }
	}

	foreach ($stream in @(@{ Name = 'stderr'; Path = $stderr }, @{ Name = 'stdout'; Path = $stdout })) {
		if ((Test-Path $stream.Path) -and (Get-Item $stream.Path).Length -gt 0) {
			Write-Host ''
			Write-Host "=== $($stream.Name) ===" -ForegroundColor Yellow
			Get-Content $stream.Path -Tail 25
		}
	}

	Write-Host ''
	Write-Host "Full logs: data\logs\$LogDir\"

	exit $exitCode
}
finally {
	Pop-Location
}
