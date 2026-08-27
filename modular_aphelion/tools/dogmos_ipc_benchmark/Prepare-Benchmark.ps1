[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
	[string]$ShimPath,

	[Parameter(Mandatory)]
	[ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
	[string]$ServicePath,

	[string]$OutputDirectory = (Join-Path $PSScriptRoot 'build'),

	[ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
	[string]$DreamMakerPath = 'C:\Program Files (x86)\BYOND\bin\dm.exe'
)

$ErrorActionPreference = 'Stop'

function Get-PeMachine {
	param(
		[Parameter(Mandatory)]
		[string]$Path
	)

	$stream = [System.IO.File]::OpenRead($Path)
	try {
		$reader = [System.IO.BinaryReader]::new($stream)
		if ($reader.ReadUInt16() -ne 0x5A4D) {
			throw "$Path is not a PE file."
		}
		$stream.Position = 0x3C
		$peOffset = $reader.ReadUInt32()
		$stream.Position = $peOffset
		if ($reader.ReadUInt32() -ne 0x00004550) {
			throw "$Path has no PE signature."
		}
		return $reader.ReadUInt16()
	} finally {
		$stream.Dispose()
	}
}

$resolvedShim = (Resolve-Path -LiteralPath $ShimPath).Path
$resolvedService = (Resolve-Path -LiteralPath $ServicePath).Path
if ((Get-PeMachine -Path $resolvedShim) -ne 0x014C) {
	throw 'dogmos_byond.dll must be an i686 PE image.'
}
if ((Get-PeMachine -Path $resolvedService) -ne 0x8664) {
	throw 'dogmosd.exe must be an x86_64 PE image.'
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$resolvedOutput = (Resolve-Path -LiteralPath $OutputDirectory).Path
foreach ($sourceName in @(
	'dogmos_ipc_benchmark.dme',
	'dogmos_ipc_benchmark.dm',
	'dogmos_ipc_benchmark_bindings.dm'
)) {
	Copy-Item -LiteralPath (Join-Path $PSScriptRoot $sourceName) -Destination $resolvedOutput -Force
}
Copy-Item -LiteralPath $resolvedShim -Destination (Join-Path $resolvedOutput 'dogmos_byond.dll') -Force
Copy-Item -LiteralPath $resolvedService -Destination (Join-Path $resolvedOutput 'dogmosd.exe') -Force

$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $DreamMakerPath
$startInfo.WorkingDirectory = $resolvedOutput
$startInfo.ArgumentList.Add((Join-Path $resolvedOutput 'dogmos_ipc_benchmark.dme'))
$startInfo.UseShellExecute = $false
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$compiler = [System.Diagnostics.Process]::Start($startInfo)
$standardOutput = $compiler.StandardOutput.ReadToEnd()
$standardError = $compiler.StandardError.ReadToEnd()
$compiler.WaitForExit()
Write-Output $standardOutput
Write-Output $standardError
if ($compiler.ExitCode -ne 0) {
	throw "DreamMaker exited with code $($compiler.ExitCode)."
}
Write-Output "DREAMMAKER_EXIT=$($compiler.ExitCode)"

foreach ($artifactName in @('dogmos_byond.dll', 'dogmosd.exe', 'dogmos_ipc_benchmark.dmb')) {
	$artifact = Join-Path $resolvedOutput $artifactName
	$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $artifact
	Write-Output "$artifactName $($hash.Hash)"
}
