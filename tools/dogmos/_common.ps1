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
	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
	try {
		$fs = [System.IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
		try {
			$reader = New-Object System.IO.StreamReader($fs)
			try {
				return $reader.ReadToEnd()
			} finally {
				$reader.Dispose()
			}
		} finally {
			$fs.Dispose()
		}
	} catch {
		return ''
	}
}

# Read a JSON artifact with an actionable error instead of letting ConvertFrom-Json report only a
# parser offset. Empty files commonly mean the producer crashed before writing its final output.
function Read-JsonSafely([string]$Path) {
	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
	$text = Read-LogSafely $Path
	if (-not $text -or -not $text.Trim()) {
		throw "JSON artifact is empty: $Path"
	}
	try {
		return $text | ConvertFrom-Json
	} catch {
		throw "JSON artifact is malformed: $Path ($($_.Exception.Message))"
	}
}

# Resolve a developer-supplied executable path or a command on PATH. Project tooling must not
# encode a machine-specific installation path; callers can pass a relative checkout path when a
# tool is vendored, or configure PATH for system-installed tools such as BYOND.
function Resolve-ToolPath([string]$Path, [string]$Label) {
	if (-not $Path) { throw "$Label path is empty." }
	if (Test-Path -LiteralPath $Path -PathType Leaf) {
		return (Resolve-Path -LiteralPath $Path).Path
	}
	$command = Get-Command $Path -CommandType Application -ErrorAction SilentlyContinue
	if ($command) { return $command.Source }
	throw "$Label not found: $Path. Put it on PATH or pass a valid relative/absolute path."
}

# Capture the process IDs that existed before a probe so timeout cleanup cannot kill an unrelated
# server owned by another task or by the developer. Child DreamDaemon processes are identified by
# name after the run starts and only newly-created IDs are eligible for cleanup.
function Get-ProcessIds([string[]]$Names) {
	return @(Get-Process -Name $Names -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
}

function Stop-NewProcesses([string[]]$Names, [int[]]$ExistingIds) {
	$newProcesses = @(Get-Process -Name $Names -ErrorAction SilentlyContinue | Where-Object { $ExistingIds -notcontains $_.Id })
	foreach ($process in $newProcesses) {
		$process | Stop-Process -Force -ErrorAction SilentlyContinue
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
		$parsed = Read-JsonSafely $BaselinePath
		$known = @($parsed)
	}
	$counts = @($Signatures | Group-Object | ForEach-Object { [pscustomobject]@{ Sig = $_.Name; Count = $_.Count } })
	return [pscustomobject]@{
		All   = $counts
		New   = @($counts | Where-Object { $known -notcontains $_.Sig })
		Fixed = @($known | Where-Object { $Signatures -notcontains $_ })
	}
}
