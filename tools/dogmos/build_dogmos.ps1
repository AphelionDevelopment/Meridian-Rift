<#
	Builds Dogmos from the sibling fork, regenerates bindings.dm, and vendors the DLL.

	Run from anywhere. Does NOT need an elevated shell.

	Why this exists: a plain `cargo build` in this repo's tooling fails two ways that are easy to
	forget - the shell environment predates the rustup install (so cargo is not on PATH), and
	byondapi-sys refuses to compile for the x86_64 host, so every cargo command needs an explicit
	--target.
#>

[CmdletBinding()]
param(
	# Skip regenerating bindings.dm. Faster when only the DM side changed.
	[switch]$SkipBindings,
	# Skip copying dogmos.dll into the game repo.
	[switch]$SkipVendor
)

$ErrorActionPreference = 'Stop'

$DogmosRepo = 'C:\Users\Zoe\Documents\GitHub\aphelion-dogmos'
$GameRepo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Target = 'i686-pc-windows-msvc'

# The tool shell may predate the toolchain install, so rebuild the environment from the registry.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
$env:LIBCLANG_PATH = [Environment]::GetEnvironmentVariable('LIBCLANG_PATH', 'Machine')

if (-not (Test-Path $DogmosRepo)) {
	throw "Dogmos fork not found at $DogmosRepo. Clone https://github.com/AphelionDevelopment/aphelion-dogmos there."
}

Push-Location $DogmosRepo
try {
	$branch = (git rev-parse --abbrev-ref HEAD)

	# The fork's checkout has been switched out from under this twice now. On master the crate is
	# still named "auxmos", so an unguarded build there produces the wrong library - or, worse,
	# succeeds against upstream code that has none of our fixes.
	$expectedBranch = 'dogmos'
	if ($branch -ne $expectedBranch) {
		throw "Fork is on branch '$branch', expected '$expectedBranch'. Run: git -C `"$DogmosRepo`" checkout $expectedBranch"
	}
	$crateName = (Select-String -Path (Join-Path $DogmosRepo 'Cargo.toml') -Pattern '^name = "(.+)"' |
		Select-Object -First 1).Matches.Groups[1].Value
	if ($crateName -ne 'dogmos') {
		throw "Cargo.toml declares crate '$crateName', expected 'dogmos'. The checkout is not our fork's work."
	}

	Write-Host "=== Building Dogmos ($branch) for $Target ===" -ForegroundColor Cyan

	cargo build --release --target $Target
	if ($LASTEXITCODE -ne 0) { throw "cargo build failed with exit code $LASTEXITCODE" }

	if (-not $SkipBindings) {
		Write-Host '=== Regenerating bindings.dm ===' -ForegroundColor Cyan
		# Must pass --target: byondapi-sys hard-errors on non-x86 targets, and the host is x86_64.
		cargo test --target $Target generate_binds
		if ($LASTEXITCODE -ne 0) { throw "bindings generation failed with exit code $LASTEXITCODE" }

		$bindings = Join-Path $DogmosRepo 'bindings.dm'
		$procCount = (Select-String -Path $bindings -Pattern '^/(proc|datum|turf)').Count
		Write-Host "bindings.dm: $procCount bound procs"
	}

	if (-not $SkipVendor) {
		$built = Join-Path $DogmosRepo "target\$Target\release\dogmos.dll"
		$vendored = Join-Path $GameRepo 'dogmos.dll'
		Copy-Item $built $vendored -Force
		Write-Host "vendored -> $vendored ($((Get-Item $vendored).Length) bytes)" -ForegroundColor Green
	}
}
finally {
	Pop-Location
}

Write-Host 'Done.' -ForegroundColor Green
