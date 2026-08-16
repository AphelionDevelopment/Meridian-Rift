<#
	Prints one test's current status/message/runtimes from the last data\unit_tests.json.

	Why this exists: this exact `Get-Content | ConvertFrom-Json | ...` one-liner got hand-typed
	repeatedly across the Phase 2/3 sessions to read a single test's failure message. Pure ergonomics -
	no new capability over reading the JSON file directly.
#>

[CmdletBinding()]
param(
	# The test path to look up, e.g. /datum/unit_test/dogmos_turf_registration.
	[Parameter(Mandatory)]
	[string]$TestPath
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')

$GameRepo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ResultsPath = Join-Path $GameRepo 'data\unit_tests.json'

if (-not (Test-Path $ResultsPath)) {
	Write-Warning "No $ResultsPath - run run_tests.ps1 first."
	exit 1
}

$json = Read-JsonSafely $ResultsPath
$property = $json.PSObject.Properties[$TestPath]
$entry = if ($property) { $property.Value } else { $null }

if (-not $entry) {
	Write-Warning "No entry for '$TestPath' in $ResultsPath - check the path is exact (case-sensitive type path, e.g. /datum/unit_test/dogmos_turf_registration)."
	exit 1
}

$statusName = switch ($entry.status) {
	0 { 'PASSED' }
	1 { 'FAILED' }
	2 { 'SKIPPED' }
	default { "unknown ($($entry.status))" }
}

Write-Host "$TestPath" -ForegroundColor Cyan
Write-Host "status: $statusName   runtimes: $($entry.runtimes)"
if ($entry.message) {
	Write-Host ''
	Write-Host $entry.message
}
