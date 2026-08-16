<#
	Summarizes a round's atmos-relevant telemetry from its log directory - built in response to the
	first live playtest after Phase 3 landed, which surfaced a real regression (turfs resistant to gas/
	heat exchange, non-functional breaches) that only showed up over a long real round, not in any unit
	test. Manually grepping/importing the perf CSV and skimming the atmos/runtime logs by hand each time
	doesn't scale - this exists so that check is one command.

	What it reports:
	1. Atmos MC cost/count trend from the perf-*.csv (air_turf_cost, air_turf_count, etc.) - specifically
	   flags monotonic growth in air_turf_count (SSair.active_turfs), since that list is known to never
	   shrink (an accepted-at-the-time, now-confirmed-costly tradeoff from the SSAIR_ACTIVETURFS cutover)
	   and its growth is the direct driver of process_active_turfs()'s own cost.
	2. Any runtime.log line mentioning atmos-relevant keywords (dogmos, atmos, turf gas/heat, superconduct).
	3. A quick tally of atmos.html gas-transfer log lines, since "opened a canister" followed by a
	   near-identical remaining-moles reading on every subsequent open is the signature of gas transfer
	   having effectively stalled.

	Usage: analyze_round_log.ps1 -LogDir "data\logs\2026\08\14\round-19.55.49"
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[string]$LogDir
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $LogDir)) {
	throw "Log directory not found: $LogDir"
}

Write-Host "=== Round log analysis: $LogDir ===" -ForegroundColor Cyan

# --- 1. Perf CSV: atmos cost/count trend --------------------------------------------------------
$csvFile = Get-ChildItem $LogDir -Filter 'perf-*.csv' | Select-Object -First 1
if ($csvFile) {
	$csv = @(Import-Csv $csvFile.FullName)
	if ($csv.Count -eq 0) {
		Write-Host ''
		Write-Host "Perf CSV is empty: $($csvFile.FullName)" -ForegroundColor Yellow
	} else {
	$atmosCostCols = @('air_turf_cost', 'air_eg_cost', 'air_highpressure_cost', 'air_hotspots_cost', 'air_superconductivity_cost', 'air_pipenets_cost')
	# air_eg_count/air_delta_count are stale DM-list lengths (excited_groups is a roundstart-only
	# snapshot post-cutover; high_pressure_delta drains within the cycle it's populated) - kept for
	# backward compatibility with older logs, but air_low_pressure_count/air_high_pressure_count/
	# air_group_processed/air_equalize_processed are Rust's own real per-cycle counters and are what
	# actually answers "is Dogmos doing real work" (added 2026-08-15, absent from logs before that).
	$atmosCountCols = @('air_turf_count', 'air_eg_count', 'air_hotspot_count', 'air_delta_count', 'air_superconductive_count', 'air_low_pressure_count', 'air_high_pressure_count', 'air_group_processed', 'air_equalize_processed', 'air_space_boundary_count')

	Write-Host ''
	Write-Host "--- Atmos MC telemetry ($($csv.Count) samples, time $($csv[0].time) to $($csv[-1].time)) ---" -ForegroundColor Cyan

	foreach ($col in $atmosCostCols + $atmosCountCols) {
		if (-not ($csv[0].PSObject.Properties.Name -contains $col)) { continue }
		$values = $csv | ForEach-Object { [double]$_.$col }
		$first = $values[0]
		$last = $values[-1]
		$max = ($values | Measure-Object -Maximum).Maximum
		$isCount = $col -in $atmosCountCols

		$growthNote = ''
		if ($isCount) {
			$everDecreased = $false
			for ($i = 1; $i -lt $values.Count; $i++) {
				if ($values[$i] -lt $values[$i - 1]) { $everDecreased = $true; break }
			}
			$growthPct = if ($first -gt 0) { (($last - $first) / $first) * 100 } else { $null }
			if ($null -ne $growthPct -and $growthPct -gt 20 -and -not $everDecreased) {
				$growthNote = " -- MONOTONIC GROWTH: never shrinks over the session, this list is a known unbounded-cost risk"
			} elseif ($null -ne $growthPct -and $growthPct -gt 20) {
				$growthNote = " -- NET GROWTH, but the series decreased at least once"
			}
		}

		$color = if ($growthNote) { 'Red' } else { 'Gray' }
		Write-Host ("  {0,-30} first={1,10:N3}  last={2,10:N3}  max={3,10:N3}{4}" -f $col, $first, $last, $max, $growthNote) -ForegroundColor $color
	}

	# Explicit monotonicity check on air_turf_count - the specific signal that caught the 2026-08-14
	# regression (active_turfs growing 1693 -> 3817 over one session, ~2.25x, while never decreasing).
	if ($csv[0].PSObject.Properties.Name -contains 'air_turf_count') {
		$counts = $csv | ForEach-Object { [double]$_.air_turf_count }
		$everDecreased = $false
		for ($i = 1; $i -lt $counts.Count; $i++) {
			if ($counts[$i] -lt $counts[$i - 1]) { $everDecreased = $true; break }
		}
		Write-Host ''
		if (-not $everDecreased -and $counts[-1] -gt $counts[0]) {
			Write-Host "  air_turf_count NEVER decreased across the whole session ($($counts[0]) -> $($counts[-1])) - active_turfs is not being shrunk. This directly inflates process_active_turfs()'s own legacy-walk cost every cycle." -ForegroundColor Red
		} else {
			Write-Host "  air_turf_count is not monotonically growing this session." -ForegroundColor Green
		}
	}
	}
} else {
	Write-Host ''
	Write-Host "No perf-*.csv found in $LogDir - MC telemetry unavailable for this round." -ForegroundColor Yellow
}

# --- 2. runtime.log: atmos-relevant lines --------------------------------------------------------
$runtimeLog = Join-Path $LogDir 'runtime.log'
if (Test-Path $runtimeLog) {
	$pattern = 'dogmos|atmos|turf.*(gas|heat)|superconduct|TurfHeat|TurfGases'
	$hits = @(Select-String -Path $runtimeLog -Pattern $pattern -CaseSensitive:$false)
	Write-Host ''
	Write-Host "--- runtime.log: atmos-relevant lines ($($hits.Count)) ---" -ForegroundColor Cyan
	if ($hits.Count -gt 0) {
		$hits | Select-Object -First 20 | ForEach-Object { Write-Host "  $($_.Line.Trim())" -ForegroundColor Yellow }
		if ($hits.Count -gt 20) { Write-Host "  ... and $($hits.Count - 20) more" -ForegroundColor DarkGray }
	} else {
		Write-Host "  none - no atmos-related runtime errors this round (does not mean atmos is working correctly, only that it isn't crashing)." -ForegroundColor Gray
	}
}

# --- 3. atmos.html: gas-transfer stall signature -------------------------------------------------
$atmosHtml = Join-Path $LogDir 'atmos.html'
if (Test-Path $atmosHtml) {
	$lines = Get-Content $atmosHtml -Raw
	$openedCount = ([regex]::Matches($lines, '<b>opened</b>')).Count
	$closedCount = ([regex]::Matches($lines, '<b>closed</b>')).Count
	Write-Host ''
	Write-Host "--- atmos.html: canister/valve activity ---" -ForegroundColor Cyan
	Write-Host "  $openedCount 'opened' events, $closedCount 'closed' events logged."
	if ($openedCount -gt 0) {
		Write-Host "  Read the file directly to check for near-identical remaining-moles readings across repeated" -ForegroundColor Gray
		Write-Host "  open/close cycles on the same canister - that pattern (a huge reservoir barely draining despite" -ForegroundColor Gray
		Write-Host "  repeated valve opens) is the signature of gas transfer having effectively stalled." -ForegroundColor Gray
	}
}

Write-Host ''
Write-Host "=== Done ===" -ForegroundColor Cyan
