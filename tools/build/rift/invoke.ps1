$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

if ($args.Count -ne 0) {
	Write-Error '[unexpected_arguments] RIFT_BUILD.cmd does not accept caller-controlled arguments.'
	exit 2
}

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepositoryRoot = (Resolve-Path (Join-Path $ScriptRoot '..\..\..')).Path
. (Join-Path $ScriptRoot 'lib.ps1')

try {
	$networkMode = $env:MERIDIAN_RIFT_BUILD_NETWORK
	if ([string]::IsNullOrWhiteSpace($networkMode)) {
		$networkMode = 'offline'
	}
	Assert-RiftBuildMode -Mode $networkMode

	$forceValue = $env:MERIDIAN_RIFT_FORCE_REBUILD
	if ([string]::IsNullOrWhiteSpace($forceValue)) {
		$forceValue = '0'
	}
	if ($forceValue -cne '0' -and $forceValue -cne '1') {
		throw (New-RiftBuildError -Code 'invalid_force_rebuild' -Message "Expected '0' or '1', got '$forceValue'.")
	}

	$exitCode = Invoke-RiftBuild `
		-RepositoryRoot $RepositoryRoot `
		-NetworkMode $networkMode `
		-ForceRebuild ($forceValue -ceq '1')
	exit $exitCode
} catch {
	[Console]::Error.WriteLine($_.Exception.Message)
	exit 2
}
