$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepositoryRoot = Resolve-Path (Join-Path $ScriptRoot '..\..\..')
. (Join-Path $ScriptRoot 'lib.ps1')

$script:Passed = 0
$script:Failed = 0

function Assert-Equal {
	param(
		$Actual,
		$Expected,
		[Parameter(Mandatory)][string]$Message
	)

	if ($Actual -ne $Expected) {
		throw "$Message Expected '$Expected', got '$Actual'."
	}
}

function Assert-True {
	param(
		[bool]$Condition,
		[Parameter(Mandatory)][string]$Message
	)

	if (-not $Condition) {
		throw $Message
	}
}

function Assert-Contains {
	param(
		[Parameter(Mandatory)][string]$Text,
		[Parameter(Mandatory)][string]$Expected,
		[Parameter(Mandatory)][string]$Message
	)

	if (-not $Text.Contains($Expected)) {
		throw "$Message Missing '$Expected'."
	}
}

function Assert-ThrowsCode {
	param(
		[Parameter(Mandatory)][scriptblock]$Action,
		[Parameter(Mandatory)][string]$Code
	)

	try {
		& $Action
	} catch {
		if ($_.Exception.Message -notmatch [regex]::Escape($Code)) {
			throw "Expected error code '$Code', got '$($_.Exception.Message)'."
		}
		return
	}

	throw "Expected error code '$Code', but no error was thrown."
}

function Invoke-Test {
	param(
		[Parameter(Mandatory)][string]$Name,
		[Parameter(Mandatory)][scriptblock]$Action
	)

	try {
		& $Action
		$script:Passed += 1
		Write-Host "PASS $Name"
	} catch {
		$script:Failed += 1
		Write-Host "FAIL $Name`n$($_.Exception.Message)" -ForegroundColor Red
	}
}

function New-TestRepository {
	param(
		[Parameter(Mandatory)][string]$Root,
		[string]$BuildTarget = 'build'
	)

	New-Item -ItemType Directory -Path (Join-Path $Root 'tools\build') -Force | Out-Null
	Set-Content -LiteralPath (Join-Path $Root 'BUILD.cmd') -Encoding ASCII -Value @"
@echo off
call "%~dp0\tools\build\build.bat" --wait-on-error $BuildTarget %*
"@
	Set-Content -LiteralPath (Join-Path $Root 'RIFT_BUILD.cmd') -Encoding ASCII -Value @'
@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\build\rift\invoke.ps1"
exit /b %ERRORLEVEL%
'@
	Set-Content -LiteralPath (Join-Path $Root 'tools\build\build.bat') -Encoding ASCII -Value @'
@echo off
exit /b 7
'@
	Set-Content -LiteralPath (Join-Path $Root 'dependencies.sh') -Encoding ASCII -Value @'
export BYOND_MAJOR=516
export BYOND_MINOR=1685
export BUN_VERSION=1.3.5
export PYTHON_VERSION=3.11.0
export CUTTER_VERSION=v5.0.1
'@
}

$TestDrive = Join-Path ([System.IO.Path]::GetTempPath()) ("meridian-rift-wrapper-tests-{0}" -f [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $TestDrive | Out-Null

try {
	Invoke-Test 'current repository build contract' {
		$contract = Test-RiftBuildContract -RepositoryRoot $RepositoryRoot
		Assert-Equal $contract.delegate 'tools/build/build.bat' 'The delegate changed.'
		Assert-Equal $contract.target 'build' 'The target changed.'
		Assert-Equal $contract.human_wait_on_error $true 'The human build should retain wait-on-error.'
		Assert-Equal $contract.wrapper_wait_on_error $false 'The agent wrapper must remain non-interactive.'
	}

	Invoke-Test 'invalid build mode is rejected' {
		Assert-ThrowsCode {
			Assert-RiftBuildMode -Mode 'internet'
		} 'invalid_build_mode'
	}

	Invoke-Test 'literal dependency pins are parsed' {
		$fixture = Join-Path $TestDrive 'literal-pins'
		New-TestRepository -Root $fixture
		$pins = Get-RiftDependencyPins -RepositoryRoot $fixture
		Assert-Equal $pins.BYOND_MAJOR '516' 'BYOND_MAJOR was not parsed.'
		Assert-Equal $pins.BYOND_MINOR '1685' 'BYOND_MINOR was not parsed.'
		Assert-Equal $pins.BUN_VERSION '1.3.5' 'BUN_VERSION was not parsed.'
		Assert-Equal $pins.PYTHON_VERSION '3.11.0' 'PYTHON_VERSION was not parsed.'
		Assert-Equal $pins.CUTTER_VERSION 'v5.0.1' 'CUTTER_VERSION was not parsed.'
	}

	Invoke-Test 'computed dependency pin is rejected' {
		$fixture = Join-Path $TestDrive 'computed-pins'
		New-TestRepository -Root $fixture
		(Get-Content -Raw -LiteralPath (Join-Path $fixture 'dependencies.sh')).Replace(
			'export BUN_VERSION=1.3.5',
			'export BUN_VERSION=${BUN_CHANNEL}'
		) | Set-Content -LiteralPath (Join-Path $fixture 'dependencies.sh') -Encoding ASCII
		Assert-ThrowsCode {
			Get-RiftDependencyPins -RepositoryRoot $fixture
		} 'invalid_dependency_pin'
	}

	Invoke-Test 'drifted human build target is rejected without execution' {
		$fixture = Join-Path $TestDrive 'drifted-contract'
		New-TestRepository -Root $fixture -BuildTarget 'lint'
		$marker = Join-Path $fixture 'unexpected-execution.txt'
		Add-Content -LiteralPath (Join-Path $fixture 'BUILD.cmd') -Encoding ASCII -Value "echo executed>$marker"
		Assert-ThrowsCode {
			Test-RiftBuildContract -RepositoryRoot $fixture
		} 'build_contract_mismatch'
		Assert-True (-not (Test-Path -LiteralPath $marker)) 'Contract validation executed BUILD.cmd content.'
	}

	Invoke-Test 'missing offline prerequisites fail closed' {
		$fixture = Join-Path $TestDrive 'missing-prerequisites'
		New-TestRepository -Root $fixture
		Assert-ThrowsCode {
			Test-RiftOfflinePrerequisites -RepositoryRoot $fixture
		} 'offline_preflight_failed'
	}

	Invoke-Test 'offline child environment is isolated' {
		$configRoot = Join-Path $TestDrive 'offline-environment'
		$config = New-RiftOfflineEnvironment -TemporaryRoot $configRoot
		Assert-Equal $config.variables.PIP_NO_INDEX '1' 'Pip network access was not disabled.'
		Assert-Equal $config.variables.PIP_DISABLE_PIP_VERSION_CHECK '1' 'Pip version checks were not disabled.'
		Assert-Equal $config.variables.PIP_REQUIRE_VIRTUALENV '0' 'Pip virtualenv compatibility changed.'
		Assert-Equal $config.variables.XDG_CONFIG_HOME $configRoot 'Bun did not receive the isolated config root.'
		$bunfig = Get-Content -Raw -LiteralPath $config.bunfig
		Assert-Contains $bunfig 'offline = true' 'Bun offline mode was not configured.'
		Assert-Contains $bunfig 'frozenLockfile = true' 'Bun lockfile enforcement was not configured.'
		Assert-Contains $bunfig 'telemetry = false' 'Bun telemetry was not disabled.'
	}

	Invoke-Test 'delegate failure code is preserved and temporary state is cleaned' {
		$fixture = Join-Path $TestDrive 'delegate-failure'
		New-TestRepository -Root $fixture
		Set-Content -LiteralPath (Join-Path $fixture 'tgstation.dmb') -Encoding ASCII -Value 'stale dmb'
		Set-Content -LiteralPath (Join-Path $fixture 'tgstation.rsc') -Encoding ASCII -Value 'stale rsc'
		Set-Content -LiteralPath (Join-Path $fixture 'preserve.dmb') -Encoding ASCII -Value 'unrelated artifact'
		$temporaryParent = Join-Path $TestDrive 'delegate-temporary'
		New-Item -ItemType Directory -Path $temporaryParent | Out-Null
		$oldTemp = $env:TEMP
		$oldTmp = $env:TMP
		try {
			$env:TEMP = $temporaryParent
			$env:TMP = $temporaryParent
			$code = Invoke-RiftBuild -RepositoryRoot $fixture -NetworkMode 'allow' -ForceRebuild $true
			Assert-Equal $code 7 'The delegate exit code was not preserved.'
			Assert-True (-not (Test-Path -LiteralPath (Join-Path $fixture 'tgstation.dmb'))) 'Force rebuild preserved the canonical DMB.'
			Assert-True (-not (Test-Path -LiteralPath (Join-Path $fixture 'tgstation.rsc'))) 'Force rebuild preserved the canonical RSC.'
			Assert-True (Test-Path -LiteralPath (Join-Path $fixture 'preserve.dmb')) 'Force rebuild removed a non-canonical artifact.'
			$leftovers = @(Get-ChildItem -LiteralPath $temporaryParent -Filter 'meridian-rift-build-*' -Force)
			Assert-Equal $leftovers.Count 0 'Temporary build state was not cleaned.'
		} finally {
			$env:TEMP = $oldTemp
			$env:TMP = $oldTmp
		}
	}
} finally {
	Remove-Item -LiteralPath $TestDrive -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "$script:Passed passed; $script:Failed failed"
if ($script:Failed -ne 0) {
	exit 1
}
