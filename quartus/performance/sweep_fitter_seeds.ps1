param(
    [int[]]$Seeds = (6..10),
    [string]$QuartusBin = 'F:\altera\quartus\bin64'
)

$ErrorActionPreference = 'Stop'
$fit = Join-Path $QuartusBin 'quartus_fit.exe'
$sta = Join-Path $QuartusBin 'quartus_sta.exe'
$project = 'keccak_performance'
$resultsDir = Join-Path $PSScriptRoot 'seed_sweep'

foreach ($tool in $fit, $sta) {
    if (-not (Test-Path -LiteralPath $tool)) {
        throw "Quartus executable not found: $tool"
    }
}

New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null
$results = @()


Push-Location $PSScriptRoot
try {
    foreach ($seed in $Seeds) {
        Write-Host "Running fitter seed $seed..." -ForegroundColor Cyan
        $fitLog = Join-Path $resultsDir "seed_$($seed)_fit.log"
        $staLog = Join-Path $resultsDir "seed_$($seed)_sta.log"

        & $fit --read_settings_files=off --write_settings_files=off "--seed=$seed" $project -c $project *> $fitLog
        if ($LASTEXITCODE -ne 0) {
            throw "Fitter failed for seed $seed. See $fitLog"
        }

        & $sta $project -c $project *> $staLog
        if ($LASTEXITCODE -ne 0) {
            throw "Timing analysis failed for seed $seed. See $staLog"
        }

        $fitSummary = Get-Content 'output_files/keccak_performance.fit.summary' -Raw
        $staSummary = Get-Content 'output_files/keccak_performance.sta.summary' -Raw
        $almMatch = [regex]::Match($fitSummary, 'Logic utilization \(in ALMs\)\s*:\s*([\d,]+)')
        $slow85 = [regex]::Match(
            $staSummary,
            "(?s)Slow 1100mV 85C Model Setup 'clk'.*?Slack\s*:\s*(-?\d+\.\d+)"
        )
        $slow0 = [regex]::Match(
            $staSummary,
            "(?s)Slow 1100mV 0C Model Setup 'clk'.*?Slack\s*:\s*(-?\d+\.\d+)"
        )

        if (-not ($almMatch.Success -and $slow85.Success -and $slow0.Success)) {
            throw "Could not parse reports for seed $seed"
        }

        $result = [pscustomobject]@{
            Seed = $seed
            ALMs = [int]($almMatch.Groups[1].Value -replace ',', '')
            Slow85SlackNs = [double]$slow85.Groups[1].Value
            Slow0SlackNs = [double]$slow0.Groups[1].Value
            WorstSlackNs = [Math]::Min(
                [double]$slow85.Groups[1].Value,
                [double]$slow0.Groups[1].Value
            )
        }
        $results += $result
        $result | Format-Table -AutoSize

        Copy-Item 'output_files/keccak_performance.fit.summary' (
            Join-Path $resultsDir "seed_$($seed).fit.summary"
        )
        Copy-Item 'output_files/keccak_performance.sta.summary' (
            Join-Path $resultsDir "seed_$($seed).sta.summary"
        )
    }

    $csv = Join-Path $resultsDir 'results.csv'
    $results | Sort-Object WorstSlackNs -Descending | Export-Csv -NoTypeInformation $csv
    Write-Host "Seed sweep results: $csv" -ForegroundColor Green
    $results | Sort-Object WorstSlackNs -Descending | Format-Table -AutoSize
} finally {
    Pop-Location
}
