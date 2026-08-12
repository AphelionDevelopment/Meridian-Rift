<#
	Compiles, boots DreamDaemon directly, and reports where initialisation got to.

	Why this exists: `dm-test` runs DreamDaemon in a way that discards its stderr, so a Rust panic or
	an access violation shows up only as an opaque exit code and a log that stops mid-sentence. Booting
	it directly with stderr redirected is the only way to see the actual message, and it answers
	"did initialisation survive?" in about a minute instead of a ~10 minute test cycle.

	Exit codes worth knowing:
	  still running     booted past SSair - whatever was under test worked
	  -1073741819       0xC0000005 access violation - byondapi ABI mismatch for this BYOND build
	  -1073740791       0xC0000409 Rust abort() - a real panic, message printed below
#>

[CmdletBinding()]
param(
	# Seconds to let it boot before concluding it survived initialisation.
	[int]$TimeoutSeconds = 220,
	# Skip the DM compile and boot whatever .dmb is already built.
	[switch]$SkipCompile
)

$ErrorActionPreference = 'Stop'

$GameRepo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Dm = 'C:\Program Files (x86)\BYOND\bin\dm.exe'
$DreamDaemon = 'C:\Program Files (x86)\BYOND\bin\dreamdaemon.exe'
$LogDir = 'boot_probe'

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

	Write-Host "=== Booting (up to ${TimeoutSeconds}s) ===" -ForegroundColor Cyan
	$proc = Start-Process -FilePath $DreamDaemon `
		-ArgumentList 'tgstation.dmb', '-close', '-trusted', '-verbose', '-params', "log-directory=$LogDir" `
		-NoNewWindow -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr

	$proc | Wait-Process -Timeout $TimeoutSeconds -ErrorAction SilentlyContinue

	$survived = -not $proc.HasExited
	if ($survived) {
		$proc | Stop-Process -Force
	}

	$runtimeLog = Join-Path $GameRepo "data\logs\$LogDir\runtime.log"
	$lastSubsystem = $null
	if (Test-Path $runtimeLog) {
		$lastSubsystem = Select-String -Path $runtimeLog -Pattern 'Initialized (.+) subsystem' |
			Select-Object -Last 1 | ForEach-Object { $_.Line.Trim() }
	}

	Write-Host ''
	Write-Host '=== Result ===' -ForegroundColor Cyan
	if ($survived) {
		Write-Host 'BOOTED - survived initialisation.' -ForegroundColor Green
	} else {
		$code = $proc.ExitCode
		$meaning = switch ($code) {
			-1073741819 { 'access violation (0xC0000005) - byondapi ABI mismatch for this BYOND build' }
			-1073740791 { 'Rust abort() (0xC0000409) - a panic; see the message below' }
			default     { 'see logs' }
		}
		Write-Host "DIED - exit code $code : $meaning" -ForegroundColor Red
	}

	if ($lastSubsystem) {
		Write-Host "Last subsystem initialised: $lastSubsystem"
	}

	# Atmospherics is the subsystem this project keeps breaking, so answer that directly rather than
	# making the reader infer it from the last-initialised line.
	if (Test-Path $runtimeLog) {
		$atmos = Select-String -Path $runtimeLog -Pattern 'Initialized Atmospherics subsystem' |
			Select-Object -Last 1
		if ($atmos) {
			Write-Host "Atmospherics: OK - $($atmos.Line.Trim())" -ForegroundColor Green
		} else {
			Write-Host 'Atmospherics: DID NOT INITIALISE' -ForegroundColor Red
		}
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

	if (-not $survived) { exit 1 }
}
finally {
	Pop-Location
}
