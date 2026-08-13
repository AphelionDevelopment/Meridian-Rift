<#
	Shared helpers for boot_probe.ps1 and run_tests.ps1. Dot-source this, don't run it directly.

	Why this exists: both scripts need the same two things - a way to read a runtime.log that
	DreamDaemon may still hold open, and a way to turn a pile of "runtime error:" lines into a
	stable, diffable signature list so new errors can be told apart from known ones, the same way
	test_baseline.json already does for test failures.
#>

# runtime.log is held open by DreamDaemon while it's running. Get-Content can fail on the lock;
# open it explicitly for shared read instead of failing outright.
function Read-LogSafely([string]$Path) {
	if (-not (Test-Path $Path)) { return '' }
	try {
		$fs = [System.IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
		try {
			$reader = New-Object System.IO.StreamReader($fs)
			return $reader.ReadToEnd()
		} finally {
			$fs.Dispose()
		}
	} catch {
		return ''
	}
}

# runtime.log lines look like: "[hh:mm:ss.fff] RUNTIME: runtime error: <message>\n - Location: ...".
# Strip the timestamp/prefix, then strip refs and numbers so the same bug hitting two different
# objects (different refs, different coordinates) collapses to one signature instead of one per
# instance.
function Get-RuntimeSignatures([string]$LogText) {
	$sigs = @()
	if (-not $LogText) { return $sigs }
	foreach ($line in ($LogText -split "`r?`n")) {
		if ($line -notmatch 'runtime error:') { continue }
		$msg = $line -replace '^.*?(runtime error:)', '$1'
		$msg = $msg -replace '\[0x[0-9a-fA-F]+\]', '[ref]'
		$msg = $msg -replace '\(/[^)]*\)', ''
		$msg = $msg -replace '\d+', 'N'
		$sigs += $msg.Trim()
	}
	return $sigs
}

# Normalizes a test failure message for COMPARISON only (the raw message is still what gets stored,
# for human readability). Same idea as Get-RuntimeSignatures: strip timestamps, refs, and hard-delete
# /del counts that change every run without indicating a different failure, so a test whose failure
# reason hasn't actually changed doesn't get flagged as "reason changed" on every re-run.
function Get-NormalizedTestMessage([string]$Message) {
	if (-not $Message) { return $Message }
	$msg = $Message -replace '\[\d{2}:\d{2}:\d{2}(\.\d+)?\]', '[time]'
	$msg = $msg -replace '\[0x[0-9a-fA-F]+\]', '[ref]'
	$msg = $msg -replace '\(\d+\)', '(N)'
	$msg = $msg -replace 'out of a total del count of \d+', 'out of a total del count of N'
	$msg = $msg -replace '\(\d+,\s*\d+,\s*\d+\)', '(N,N,N)'
	return $msg
}

# Diffs a list of signatures (as produced by Get-RuntimeSignatures) against a baseline JSON file.
# Same shape as the test_baseline.json diffing in run_tests.ps1, so runtimes get the same
# new-vs-known treatment test failures already get.
function Compare-ToBaseline($Signatures, [string]$BaselinePath) {
	$known = @()
	if (Test-Path $BaselinePath) {
		$parsed = Get-Content $BaselinePath -Raw | ConvertFrom-Json
		$known = @($parsed)
	}
	$counts = @($Signatures | Group-Object | ForEach-Object { [pscustomobject]@{ Sig = $_.Name; Count = $_.Count } })
	return [pscustomobject]@{
		All   = $counts
		New   = @($counts | Where-Object { $known -notcontains $_.Sig })
		Fixed = @($known | Where-Object { $Signatures -notcontains $_ })
	}
}
