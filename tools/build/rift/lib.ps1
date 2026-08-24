$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

function New-RiftBuildError {
	param(
		[Parameter(Mandatory)][string]$Code,
		[Parameter(Mandatory)][string]$Message
	)

	return [System.InvalidOperationException]::new("[$Code] $Message")
}

function Resolve-RiftRepositoryRoot {
	param([Parameter(Mandatory)][string]$RepositoryRoot)

	try {
		return (Resolve-Path -LiteralPath $RepositoryRoot -ErrorAction Stop).Path.TrimEnd('\', '/')
	} catch {
		throw (New-RiftBuildError -Code 'invalid_repository_root' -Message "Repository root does not exist: $RepositoryRoot")
	}
}

function Assert-RiftBuildMode {
	param([Parameter(Mandatory)][string]$Mode)

	if ($Mode -cne 'offline' -and $Mode -cne 'allow') {
		throw (New-RiftBuildError -Code 'invalid_build_mode' -Message "Expected 'offline' or 'allow', got '$Mode'.")
	}
}

function Test-RiftBuildContract {
	param([Parameter(Mandatory)][string]$RepositoryRoot)

	$root = Resolve-RiftRepositoryRoot -RepositoryRoot $RepositoryRoot
	$humanBuildPath = Join-Path $root 'BUILD.cmd'
	$wrapperPath = Join-Path $root 'RIFT_BUILD.cmd'
	if (-not (Test-Path -LiteralPath $humanBuildPath -PathType Leaf)) {
		throw (New-RiftBuildError -Code 'build_contract_mismatch' -Message 'BUILD.cmd is missing.')
	}

	$humanBuildLines = @(
		Get-Content -LiteralPath $humanBuildPath |
			ForEach-Object { $_.Trim().Replace('/', '\') } |
			Where-Object { $_ -ne '' }
	)
	$expectedHumanBuildLines = @(
		'@echo off',
		'call "%~dp0\tools\build\build.bat" --wait-on-error build %*'
	)
	$humanBuildMatches = $humanBuildLines.Count -eq $expectedHumanBuildLines.Count
	if ($humanBuildMatches) {
		for ($index = 0; $index -lt $expectedHumanBuildLines.Count; $index += 1) {
			if ($humanBuildLines[$index] -cne $expectedHumanBuildLines[$index]) {
				$humanBuildMatches = $false
				break
			}
		}
	}
	if (-not $humanBuildMatches) {
		throw (New-RiftBuildError -Code 'build_contract_mismatch' -Message 'BUILD.cmd no longer delegates to tools/build/build.bat --wait-on-error build %*.')
	}

	$wrapperWaitsOnError = $false
	if (Test-Path -LiteralPath $wrapperPath -PathType Leaf) {
		$wrapperBuild = Get-Content -Raw -LiteralPath $wrapperPath
		$wrapperWaitsOnError = $wrapperBuild -match '(?i)--wait-on-error'
		if ($wrapperWaitsOnError) {
			throw (New-RiftBuildError -Code 'build_contract_mismatch' -Message 'RIFT_BUILD.cmd must not use --wait-on-error.')
		}
	}

	return [pscustomobject]@{
		delegate = 'tools/build/build.bat'
		target = 'build'
		human_wait_on_error = $true
		wrapper_wait_on_error = $wrapperWaitsOnError
	}
}

function Get-RiftDependencyPins {
	param([Parameter(Mandatory)][string]$RepositoryRoot)

	$root = Resolve-RiftRepositoryRoot -RepositoryRoot $RepositoryRoot
	$dependenciesPath = Join-Path $root 'dependencies.sh'
	if (-not (Test-Path -LiteralPath $dependenciesPath -PathType Leaf)) {
		throw (New-RiftBuildError -Code 'invalid_dependency_pin' -Message 'dependencies.sh is missing.')
	}

	$required = @('BYOND_MAJOR', 'BYOND_MINOR', 'BUN_VERSION', 'PYTHON_VERSION', 'CUTTER_VERSION')
	$values = @{}
	foreach ($line in Get-Content -LiteralPath $dependenciesPath) {
		if ($line -notmatch '^export ([A-Z][A-Z0-9_]*)=(.*)$') {
			continue
		}
		$name = $Matches[1]
		if ($required -notcontains $name) {
			continue
		}
		$value = $Matches[2]
		if ($values.ContainsKey($name) -or $value -notmatch '^[A-Za-z0-9][A-Za-z0-9._+:/-]*$') {
			throw (New-RiftBuildError -Code 'invalid_dependency_pin' -Message "Dependency pin '$name' must be a single literal value.")
		}
		$values[$name] = $value
	}

	foreach ($name in $required) {
		if (-not $values.ContainsKey($name)) {
			throw (New-RiftBuildError -Code 'invalid_dependency_pin' -Message "Required dependency pin '$name' is missing.")
		}
	}

	return [pscustomobject]$values
}

function Invoke-RiftBunOfflineDryRun {
	param(
		[Parameter(Mandatory)][string]$BunPath,
		[Parameter(Mandatory)][string]$WorkingDirectory
	)

	Push-Location -LiteralPath $WorkingDirectory
	try {
		$output = @(& $BunPath install --offline --frozen-lockfile --dry-run 2>&1)
		$exitCode = $LASTEXITCODE
		if ($exitCode -ne 0) {
			$detail = ($output | ForEach-Object { $_.ToString() }) -join [System.Environment]::NewLine
			throw (New-RiftBuildError -Code 'offline_preflight_failed' -Message "Bun offline dependency resolution failed in '$WorkingDirectory' with exit code $exitCode. $detail")
		}
	} finally {
		Pop-Location
	}
}

function Test-RiftOfflinePrerequisites {
	param(
		[Parameter(Mandatory)][string]$RepositoryRoot,
		[string]$BootstrapCache
	)

	$root = Resolve-RiftRepositoryRoot -RepositoryRoot $RepositoryRoot
	$pins = Get-RiftDependencyPins -RepositoryRoot $root
	if ([string]::IsNullOrWhiteSpace($BootstrapCache)) {
		if (-not [string]::IsNullOrWhiteSpace($env:TG_BOOTSTRAP_CACHE)) {
			$BootstrapCache = $env:TG_BOOTSTRAP_CACHE
		} else {
			$BootstrapCache = Join-Path $root 'tools\bootstrap\.cache'
		}
	}
	if (-not [System.IO.Path]::IsPathRooted($BootstrapCache)) {
		$BootstrapCache = Join-Path $root $BootstrapCache
	}
	$cache = [System.IO.Path]::GetFullPath($BootstrapCache)

	$bunPath = Join-Path $cache ("bun-v{0}-x64\bun.exe" -f $pins.BUN_VERSION)
	$pythonRoot = Join-Path $cache ("python-{0}" -f $pins.PYTHON_VERSION)
	$pythonPath = Join-Path $pythonRoot 'python.exe'
	$pipPath = Join-Path $pythonRoot 'Scripts\pip.exe'
	$requirementsSource = Join-Path $root 'tools\requirements.txt'
	$requirementsMarker = Join-Path $pythonRoot 'requirements.txt'
	$cutterVersion = $pins.CUTTER_VERSION.Replace('.', '-')
	$cutterPath = Join-Path $root ("tools\icon_cutter\cache\hypnagogic{0}.exe" -f $cutterVersion)
	$rootLockfile = Join-Path $root 'bun.lock'
	$tguiRoot = Join-Path $root 'tgui'
	$tguiLockfile = Join-Path $tguiRoot 'bun.lock'

	$requiredFiles = @(
		@{ path = $bunPath; label = 'pinned Bun executable' },
		@{ path = $pythonPath; label = 'pinned Python executable' },
		@{ path = $pipPath; label = 'pip marker' },
		@{ path = $requirementsSource; label = 'requirements source' },
		@{ path = $requirementsMarker; label = 'requirements marker' },
		@{ path = $cutterPath; label = 'pinned icon cutter executable' },
		@{ path = $rootLockfile; label = 'root Bun lockfile' },
		@{ path = $tguiLockfile; label = 'TGUI Bun lockfile' }
	)
	$missing = @()
	foreach ($requiredFile in $requiredFiles) {
		if (-not (Test-Path -LiteralPath $requiredFile.path -PathType Leaf)) {
			$missing += "$($requiredFile.label): $($requiredFile.path)"
		}
	}
	if ($missing.Count -ne 0) {
		throw (New-RiftBuildError -Code 'offline_preflight_failed' -Message ("Missing offline prerequisites: {0}" -f ($missing -join '; ')))
	}

	$sourceHash = (Get-FileHash -LiteralPath $requirementsSource -Algorithm SHA256).Hash
	$markerHash = (Get-FileHash -LiteralPath $requirementsMarker -Algorithm SHA256).Hash
	if ($sourceHash -ne $markerHash) {
		throw (New-RiftBuildError -Code 'offline_preflight_failed' -Message 'The cached Python requirements marker does not match tools/requirements.txt.')
	}

	Invoke-RiftBunOfflineDryRun -BunPath $bunPath -WorkingDirectory $root
	Invoke-RiftBunOfflineDryRun -BunPath $bunPath -WorkingDirectory $tguiRoot

	return [pscustomobject]@{
		pins = $pins
		bootstrap_cache = $cache
		bun = $bunPath
		python = $pythonPath
		pip = $pipPath
		icon_cutter = $cutterPath
	}
}

function New-RiftOfflineEnvironment {
	param([Parameter(Mandatory)][string]$TemporaryRoot)

	New-Item -ItemType Directory -Path $TemporaryRoot -Force | Out-Null
	$bunfigPath = Join-Path $TemporaryRoot 'bunfig.toml'
	Set-Content -LiteralPath $bunfigPath -Encoding ASCII -Value @'
telemetry = false
env = false

[install]
offline = true
frozenLockfile = true
'@

	return [pscustomobject]@{
		bunfig = $bunfigPath
		variables = @{
			XDG_CONFIG_HOME = $TemporaryRoot
			PIP_NO_INDEX = '1'
			PIP_DISABLE_PIP_VERSION_CHECK = '1'
			PIP_REQUIRE_VIRTUALENV = '0'
		}
	}
}

function Remove-RiftBuildArtifacts {
	param([Parameter(Mandatory)][string]$RepositoryRoot)

	$root = Resolve-RiftRepositoryRoot -RepositoryRoot $RepositoryRoot
	$rootPrefix = $root + [System.IO.Path]::DirectorySeparatorChar
	foreach ($name in @('tgstation.dmb', 'tgstation.rsc')) {
		$artifact = [System.IO.Path]::GetFullPath((Join-Path $root $name))
		if (-not $artifact.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
			throw (New-RiftBuildError -Code 'artifact_path_escape' -Message "Refusing to remove path outside repository root: $artifact")
		}
		if (Test-Path -LiteralPath $artifact -PathType Leaf) {
			Remove-Item -LiteralPath $artifact -Force
		}
	}
}

function Invoke-RiftBuild {
	param(
		[Parameter(Mandatory)][string]$RepositoryRoot,
		[ValidateSet('offline', 'allow')][string]$NetworkMode,
		[bool]$ForceRebuild
	)

	Assert-RiftBuildMode -Mode $NetworkMode
	$root = Resolve-RiftRepositoryRoot -RepositoryRoot $RepositoryRoot
	Test-RiftBuildContract -RepositoryRoot $root | Out-Null

	$temporaryParent = $env:TEMP
	if ([string]::IsNullOrWhiteSpace($temporaryParent)) {
		$temporaryParent = [System.IO.Path]::GetTempPath()
	}
	$temporaryRoot = Join-Path $temporaryParent ("meridian-rift-build-{0}" -f [guid]::NewGuid().ToString('N'))
	New-Item -ItemType Directory -Path $temporaryRoot | Out-Null

	$environmentNames = @('XDG_CONFIG_HOME', 'PIP_NO_INDEX', 'PIP_DISABLE_PIP_VERSION_CHECK', 'PIP_REQUIRE_VIRTUALENV')
	$previousEnvironment = @{}
	foreach ($name in $environmentNames) {
		$previousEnvironment[$name] = [System.Environment]::GetEnvironmentVariable($name, 'Process')
	}

	$pushedLocation = $false
	try {
		if ($NetworkMode -ceq 'offline') {
			Test-RiftOfflinePrerequisites -RepositoryRoot $root | Out-Null
			$offlineEnvironment = New-RiftOfflineEnvironment -TemporaryRoot $temporaryRoot
			foreach ($name in $offlineEnvironment.variables.Keys) {
				[System.Environment]::SetEnvironmentVariable($name, $offlineEnvironment.variables[$name], 'Process')
			}
		}

		if ($ForceRebuild) {
			Remove-RiftBuildArtifacts -RepositoryRoot $root
		}

		$delegatePath = Join-Path $root 'tools\build\build.bat'
		if (-not (Test-Path -LiteralPath $delegatePath -PathType Leaf)) {
			throw (New-RiftBuildError -Code 'build_contract_mismatch' -Message 'The fixed build delegate is missing.')
		}
		$commandProcessor = $env:ComSpec
		if ([string]::IsNullOrWhiteSpace($commandProcessor)) {
			$commandProcessor = 'cmd.exe'
		}

		Push-Location -LiteralPath $root
		$pushedLocation = $true
		& $commandProcessor /d /s /c ('"{0}" build' -f $delegatePath)
		return $LASTEXITCODE
	} finally {
		if ($pushedLocation) {
			Pop-Location
		}
		foreach ($name in $environmentNames) {
			[System.Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process')
		}
		if (Test-Path -LiteralPath $temporaryRoot) {
			Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
		}
	}
}
