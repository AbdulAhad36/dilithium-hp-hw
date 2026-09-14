param(
    [string]$Ucdb = (Join-Path $PSScriptRoot 'keccak_cov.ucdb'),
    [int]$Lane = 0,
    [string]$Vcover = 'C:\questasim64_2024.1\win64\vcover.exe'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Ucdb)) {
    throw "Coverage database not found: $Ucdb"
}

if (-not (Test-Path -LiteralPath $Vcover)) {
    throw "Questa vcover executable not found: $Vcover"
}

$laneScope = "/tb_top/dut/g_lane[$Lane]."

Write-Host "`n=== Functional coverage: implemented covergroup ===" -ForegroundColor Cyan
& $Vcover report -cvg -summary $Ucdb
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "`n=== RTL code coverage: complete lane $Lane hierarchy ===" -ForegroundColor Cyan
& $Vcover report "-instance=$laneScope" -code bcesft $Ucdb
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "`nNote: the focused Stage 1/2/3 suite's 71.53% is functional coverage."
Write-Host "It is not the complete lane's RTL code-coverage percentage."
