# Build using permanent stage-specific SDC; no constraint files are modified.
# Run: powershell -ExecutionPolicy Bypass -File .\build_operating.ps1
param([string]$QuartusBin = 'F:\altera\quartus\bin64')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
function Invoke-QuartusStep {
    param([string]$Executable, [string[]]$ToolArguments, [string]$Log)
    & (Join-Path $QuartusBin $Executable) @ToolArguments *> $Log
    if ($LASTEXITCODE -ne 0) { throw "$Executable failed; see $Log" }
    Write-Host "Completed: $Log"
}
try {
    # ntt.sdc selects 5 ns in the fitter and 6.756757 ns in final STA.
    Invoke-QuartusStep 'quartus_map.exe' @('ntt','-c','ntt') 'operating148_aggressive_map.log'
    Invoke-QuartusStep 'quartus_fit.exe' @('ntt','-c','ntt') 'operating148_aggressive_fit.log'
    Invoke-QuartusStep 'quartus_sta.exe' @('ntt','-c','ntt') 'operating148_aggressive_sta.log'
    Invoke-QuartusStep 'quartus_sta.exe' @('-t','report_paths.tcl') 'operating148_aggressive_paths.log'
    Invoke-QuartusStep 'quartus_sta.exe' @('-t','report_clock_check.tcl','ntt_benchmark_200mhz.sdc') 'operating148_aggressive_benchmark200.log'
    # Quartus returning zero alone does not establish timing closure.
    $summary = Get-Content -Raw 'output_files/ntt.sta.summary'
    $slacks = [regex]::Matches($summary, '(?m)^Slack\s*:\s*(-?[0-9.]+)')
    $tns = [regex]::Matches($summary, '(?m)^TNS\s*:\s*(-?[0-9.]+)')
    if ($slacks.Count -ne 20 -or $tns.Count -ne 20) { throw 'Expected 20 timing checks across four corners.' }
    foreach ($item in $slacks) {
        if ([double]::Parse($item.Groups[1].Value, [cultureinfo]::InvariantCulture) -le 0) { throw 'Nonpositive operating timing slack; review ntt.sta.summary.' }
    }
    foreach ($item in $tns) {
        if ([double]::Parse($item.Groups[1].Value, [cultureinfo]::InvariantCulture) -ne 0) { throw 'Operating timing TNS is nonzero; review ntt.sta.summary.' }
    }
    Write-Host 'OPERATING_TIMING_PASS: all 20 internal timing checks positive; all TNS zero.'
} finally {
    Pop-Location
}
